# =============================================================================
# Módulo: security  ·  Responsable: Integrante 2
# Diagrama: Security Groups, KMS, Secrets Manager, Parameter Store,
#           Interface Endpoints (PrivateLink) y S3 Gateway Endpoint.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "security" })
}

data "aws_region" "current" {}

# TODO (Integrante 2)
#
# --- Security Groups (tabla "Puertos y Security Groups" del diagrama) ---
# [ ] aws_security_group.vpclink   SG del VPC Link de API Gateway. OUT 443/80 -> SG-alb
# [ ] aws_security_group.alb       IN 443 y 80 <- prefix list de CloudFront
#                                  (data "aws_ec2_managed_prefix_list" com.amazonaws.global.cloudfront.origin-facing)
#                                  IN 80/443 <- SG-vpclink.  OUT 80 y 8080 -> SG-app
# [ ] aws_security_group.app       IN 80 y 8080 <- SG-alb.  OUT 1521 -> SG-db, 443 -> SG-ep, 443 -> 0.0.0.0/0 (NAT, pasarela de pago)
# [ ] aws_security_group.lambda    sin IN.  OUT 1521 -> SG-db, 443 -> SG-ep
# [ ] aws_security_group.db        IN 1521 <- SG-app y SG-lambda. Sin salida a Internet
# [ ] aws_security_group.endpoints IN 443 <- SG-app y SG-lambda
#     Tip: crear los SG vacíos y las reglas con aws_vpc_security_group_ingress_rule /
#     aws_vpc_security_group_egress_rule para evitar referencias circulares entre SG.
#
# --- Cifrado y secretos ---
# [ ] aws_kms_key.main + aws_kms_alias.main ("alias/${local.name}")   enable_key_rotation = true
# [ ] aws_secretsmanager_secret.payment     credenciales de la pasarela de pago, kms_key_id = aws_kms_key.main.arn
#                                           (el valor real se carga a mano en la consola, NUNCA en el código)
#     La contraseña de Oracle NO va aquí: la genera RDS con manage_master_user_password
#     (ver módulo database), que además la guarda en Secrets Manager y la rota sola.
# [ ] aws_ssm_parameter.*                   bajo "/${var.project}/${var.environment}/":
#                                           stock_minimo_default, timeout_pasarela_ms = 10000, etc.
#
# --- Endpoints privados ---
# [ ] aws_vpc_endpoint.interface[each]   for_each = var.enable_interface_endpoints ? toset(var.interface_endpoint_services) : []
#                                        vpc_endpoint_type = "Interface", private_dns_enabled = true,
#                                        subnet_ids = var.app_subnet_ids, security_group_ids = [SG-endpoints]
# [ ] aws_vpc_endpoint.s3                Gateway, route_table_ids = var.endpoint_route_table_ids
#
# Criterio de terminado: plan sin errores y outputs con valores reales.
