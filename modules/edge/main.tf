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
