# Seguridad GUZFARMA: grupos sin reglas implícitas, cifrado y endpoints.
locals {
  name             = "${var.project}-${var.environment}"
  tags             = merge(var.tags, { Module = "security" })
  parameter_prefix = "/${var.project}/${var.environment}/"
  groups = {
    vpclink   = "API Gateway VPC Link"
    alb       = "Application Load Balancer"
    app       = "ECS application"
    lambda    = "Lambda VPC"
    db        = "Oracle RDS"
    endpoints = "Private interface endpoints"
  }
  # El endpoint SMTP de SES requiere puertos SMTP específicos para enviar correo.
  # La arquitectura actual no usa SMTP desde ECS/Lambda; se conserva el contrato.
  interface_services = var.enable_interface_endpoints ? toset(var.interface_endpoint_services) : toset([])
}

data "aws_region" "current" {}
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "groups" {
  for_each               = local.groups
  name_prefix            = "${local.name}-${each.key}-"
  description            = each.value
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  tags                   = merge(local.tags, { Name = "${local.name}-${each.key}" })
  lifecycle { create_before_destroy = true }
}

# Reglas entre grupos: la definición independiente evita dependencias circulares.
locals {
  ingress_sg = {
    alb_vpclink_80   = { target = "alb", source = "vpclink", port = 80 }
    alb_vpclink_443  = { target = "alb", source = "vpclink", port = 443 }
    app_alb_80       = { target = "app", source = "alb", port = 80 }
    app_alb_8080     = { target = "app", source = "alb", port = 8080 }
    db_app           = { target = "db", source = "app", port = var.db_port }
    db_lambda        = { target = "db", source = "lambda", port = var.db_port }
    endpoints_app    = { target = "endpoints", source = "app", port = 443 }
    endpoints_lambda = { target = "endpoints", source = "lambda", port = 443 }
  }
  egress_sg = {
    vpclink_alb_80   = { source = "vpclink", target = "alb", port = 80 }
    vpclink_alb_443  = { source = "vpclink", target = "alb", port = 443 }
    alb_app_80       = { source = "alb", target = "app", port = 80 }
    alb_app_8080     = { source = "alb", target = "app", port = 8080 }
    app_db           = { source = "app", target = "db", port = var.db_port }
    lambda_db        = { source = "lambda", target = "db", port = var.db_port }
    app_endpoints    = { source = "app", target = "endpoints", port = 443 }
    lambda_endpoints = { source = "lambda", target = "endpoints", port = 443 }
  }
}
resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each                     = local.ingress_sg
  security_group_id            = aws_security_group.groups[each.value.target].id
  referenced_security_group_id = aws_security_group.groups[each.value.source].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "${each.value.source} to ${each.value.target} TCP ${each.value.port}"
}
resource "aws_vpc_security_group_egress_rule" "to_sg" {
  for_each                     = local.egress_sg
  security_group_id            = aws_security_group.groups[each.value.source].id
  referenced_security_group_id = aws_security_group.groups[each.value.target].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "${each.value.source} to ${each.value.target} TCP ${each.value.port}"
}

# ALB solo recibe HTTP(S) desde el rango administrado de CloudFront.
resource "aws_vpc_security_group_ingress_rule" "alb_cloudfront" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.groups["alb"].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  description       = "CloudFront origin-facing TCP ${each.value}"
}

# HTTPS público de salida: pasarela de pago vía NAT (y AWS si no hay endpoints).
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.groups["app"].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS outbound for payment gateway via NAT"
}

resource "aws_kms_key" "main" {
  description             = "Encryption key for ${local.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(local.tags, { Name = local.name })
}
resource "aws_kms_alias" "main" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.main.key_id
}
resource "aws_secretsmanager_secret" "payment" {
  name                    = "${local.name}/payment"
  description             = "Payment gateway credentials; populate securely outside Terraform"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 7
  tags                    = local.tags
}
# No crear aws_secretsmanager_secret_version: nunca guardar credenciales en el código.
resource "aws_ssm_parameter" "stock_minimo_default" {
  name  = "${local.parameter_prefix}stock_minimo_default"
  type  = "String"
  value = "10"
  tags  = local.tags
}
resource "aws_ssm_parameter" "timeout_pasarela_ms" {
  name  = "${local.parameter_prefix}timeout_pasarela_ms"
  type  = "String"
  value = "10000"
  tags  = local.tags
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_services
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.app_subnet_ids
  security_group_ids  = [aws_security_group.groups["endpoints"].id]
  tags                = merge(local.tags, { Name = "${local.name}-${replace(each.value, ".", "-")}" })
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.endpoint_route_table_ids
  tags              = merge(local.tags, { Name = "${local.name}-s3" })
}
