# =============================================================================
# Módulo: edge  ·  Responsable: Integrante 5
# Diagrama: Route 53, CloudFront + WAF, API Gateway + Cognito (authorizer),
#           VPC Link privado hacia el ALB, WAF regional asociado al ALB.
# =============================================================================

locals {
  name          = "${var.project}-${var.environment}"
  tags          = merge(var.tags, { Module = "edge" })
  custom_domain = var.domain_name != ""
}


# 1. USUARIOS - AMAZON COGNITO

resource "aws_cognito_user_pool" "this" {
  name = "${local.name}-users"

  mfa_configuration = "OPTIONAL"

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  software_token_mfa_configuration {
    enabled = true
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows = [
    "code"
  ]

  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile"
  ]

  supported_identity_providers = [
    "COGNITO"
  ]

  callback_urls = var.cognito_callback_urls

  access_token_validity = 60

  token_validity_units {
    access_token = "minutes"
  }

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_group" "groups" {
  for_each = toset([
    "administrador",
    "farmaceutico",
    "vendedor",
    "cliente"
  ])

  name         = each.value
  user_pool_id = aws_cognito_user_pool.this.id
}

# 2. API - API GATEWAY HTTP + VPC LINK
# =============================================================================

resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"

  tags = local.tags
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name = "${local.name}-vpc-link"

  subnet_ids = var.app_subnet_ids

  security_group_ids = [
    var.sg_vpclink_id
  ]

  tags = local.tags
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id = aws_apigatewayv2_api.this.id

  integration_type   = "HTTP_PROXY"
  integration_uri    = var.alb_listener_arn
  integration_method = "ANY"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.this.id
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id = aws_apigatewayv2_api.this.id

  authorizer_type = "JWT"
  name            = "${local.name}-cognito-authorizer"

  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    audience = [
      aws_cognito_user_pool_client.web.id
    ]

    issuer = "https://${aws_cognito_user_pool.this.endpoint}"
  }
}

resource "aws_apigatewayv2_route" "api" {
  api_id = aws_apigatewayv2_api.this.id

  route_key = "ANY /api/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.alb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.this.id

  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }

  tags = local.tags
}

# =============================================================================
# 3. BORDE - CLOUDFRONT + WAF
# =============================================================================

resource "random_password" "origin_header" {
  length  = 32
  special = false
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name  = "${local.name}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled = true

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_header.result
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = replace(
      aws_apigatewayv2_api.this.api_endpoint,
      "https://",
      ""
    )
    origin_id = "api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "api"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "POST",
      "PATCH",
      "DELETE"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = true
      headers      = ["Authorization"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.custom_domain ? false : true

    acm_certificate_arn      = local.custom_domain ? var.cloudfront_certificate_arn : null
    ssl_support_method       = local.custom_domain ? "sni-only" : null
    minimum_protocol_version = local.custom_domain ? "TLSv1.2_2021" : null
  }

  aliases = local.custom_domain ? [var.domain_name] : []

  tags = local.tags
}

resource "aws_wafv2_web_acl" "alb" {
  name  = "${local.name}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-alb-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "BlockMissingOriginHeader"
    priority = 1

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          byte_match_statement {
            search_string         = random_password.origin_header.result
            positional_constraint = "EXACTLY"

            field_to_match {
              single_header {
                name = "x-origin-verify"
              }
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block-missing-origin-header"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "alb-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "alb-sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "alb-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "alb-rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
# TODO (Integrante 5)
#
# --- Usuarios (Cognito) ---
# [ ] aws_cognito_user_pool.this            password_policy, mfa_configuration = "OPTIONAL"
#                                           (MFA obligatorio para el grupo de personal interno, RNF-14)
# [ ] aws_cognito_user_pool_client.web      sin secret, flujos de usuario y contraseña + OAuth code,
#                                           access_token_validity = 60 minutos
# [ ] aws_cognito_user_group                administrador, farmaceutico, vendedor, cliente
#
# --- API (pasos 3 y 4) ---
# [ ] aws_apigatewayv2_api.this             protocol_type = "HTTP"
# [ ] aws_apigatewayv2_vpc_link.this        subnet_ids = var.app_subnet_ids, security_group_ids = [var.sg_vpclink_id]
# [ ] aws_apigatewayv2_integration.alb      integration_type = "HTTP_PROXY", connection_type = "VPC_LINK",
#                                           integration_uri = var.alb_listener_arn, integration_method = "ANY"
# [ ] aws_apigatewayv2_authorizer.cognito   authorizer_type = "JWT", issuer = URL del user pool, audience = [client id]
# [ ] aws_apigatewayv2_route.api            route_key = "ANY /api/{proxy+}", authorization_type = "JWT"
# [ ] aws_apigatewayv2_stage.default        auto_deploy = true,
#                                           default_route_settings { throttling_rate_limit / burst_limit = var.api_throttle_* }
#
# --- Borde (pasos 1 y 2) ---
# [ ] aws_wafv2_web_acl.cloudfront          provider = aws.us_east_1, scope = "CLOUDFRONT"
#                                           reglas: AWSManagedRulesCommonRuleSet, AWSManagedRulesSQLiRuleSet,
#                                           AWSManagedRulesAmazonIpReputationList, rate_based_statement limit = var.waf_rate_limit
# [ ] aws_cloudfront_distribution.this      web_acl_id = WAF de CloudFront
#                                           origen "alb": domain_name = var.alb_dns_name (default_cache_behavior, /*)
#                                           origen "api": dominio de API Gateway (ordered_cache_behavior "/api/*", sin caché)
#                                           Agregar un encabezado secreto (custom_header) al origen ALB.
#                                           viewer_certificate: cloudfront_default_certificate si no hay dominio propio
# [ ] aws_wafv2_web_acl.alb                 scope = "REGIONAL", mismas reglas + regla que bloquea si falta
#                                           el encabezado secreto de CloudFront
# [ ] aws_wafv2_web_acl_association.alb     resource_arn = var.alb_arn
#
# --- DNS (opcional, solo con dominio propio) ---
# [ ] aws_route53_record.web                count = local.custom_domain ? 1 : 0, alias -> CloudFront
#
# Criterio de terminado: la URL de CloudFront carga la web, y /api/* sin token responde 401.
