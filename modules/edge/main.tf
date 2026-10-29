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
