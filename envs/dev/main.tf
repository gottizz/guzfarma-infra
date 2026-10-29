# =============================================================================
# Guzfarma - entorno dev
# Une los 7 módulos. Cada módulo tiene un responsable (ver docs/division-trabajo.md).
# Responsable de este archivo y de la integración: Integrante 1.
# =============================================================================

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# 1. Red ---------------------------------------------------------- Integrante 1
module "network" {
  source = "../../modules/network"

  project            = var.project
  environment        = var.environment
  single_nat_gateway = var.single_nat_gateway
}

# 2. Seguridad ---------------------------------------------------- Integrante 2
module "security" {
  source = "../../modules/security"

  project                    = var.project
  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  vpc_cidr                   = module.network.vpc_cidr
  app_subnet_ids             = module.network.app_subnet_ids
  endpoint_route_table_ids   = concat(module.network.app_route_table_ids, module.network.db_route_table_ids)
  enable_interface_endpoints = var.enable_interface_endpoints
}

# 3. Base de datos ------------------------------------------------ Integrante 3
module "database" {
  source = "../../modules/database"

  project             = var.project
  environment         = var.environment
  db_subnet_ids       = module.network.db_subnet_ids
  sg_db_id            = module.security.sg_db_id
  kms_key_arn         = module.security.kms_key_arn
  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection

  backup_retention_days = 7 # en dev; prod usa 35 (RNF-17)
}

# 4. Eventos (SQS, Lambda, SES, SNS, EventBridge) ----------------- Integrante 3
module "events" {
  source = "../../modules/events"

  project            = var.project
  environment        = var.environment
  app_subnet_ids     = module.network.app_subnet_ids
  sg_lambda_id       = module.security.sg_lambda_id
  kms_key_arn        = module.security.kms_key_arn
  db_address         = module.database.db_address
  db_port            = module.database.db_port
  db_secret_arn      = module.database.db_secret_arn
  lambdas_source_dir = "${path.root}/../../lambdas"
  ses_sender_email   = var.ses_sender_email
  admin_email        = var.admin_email
  existing_role_arn  = var.lab_role_arn
}

# 5. Cómputo (ECR, ALB, ECS Fargate, Auto Scaling) ----------------- Integrante 4
module "compute" {
  source = "../../modules/compute"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.network.vpc_id
  public_subnet_ids    = module.network.public_subnet_ids
  app_subnet_ids       = module.network.app_subnet_ids
  sg_alb_id            = module.security.sg_alb_id
  sg_app_id            = module.security.sg_app_id
  kms_key_arn          = module.security.kms_key_arn
  ssm_parameter_prefix = module.security.ssm_parameter_prefix
  payment_secret_arn   = module.security.payment_secret_arn
  db_address           = module.database.db_address
  db_port              = module.database.db_port
  db_secret_arn        = module.database.db_secret_arn
  orders_queue_url     = module.events.orders_queue_url
  orders_queue_arn     = module.events.orders_queue_arn
  existing_role_arn    = var.lab_role_arn
}

# 6. Borde (Cognito, API Gateway, CloudFront, WAF, Route 53) ------- Integrante 5
module "edge" {
  source = "../../modules/edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project          = var.project
  environment      = var.environment
  alb_dns_name     = module.compute.alb_dns_name
  alb_arn          = module.compute.alb_arn
  alb_listener_arn = module.compute.alb_listener_arn
  app_subnet_ids   = module.network.app_subnet_ids
  sg_vpclink_id    = module.security.sg_vpclink_id
}

# 7. Monitoreo (alarmas CloudWatch) -------------------------------- Integrante 1
module "monitoring" {
  source = "../../modules/monitoring"

  project           = var.project
  environment       = var.environment
  alerts_topic_arn  = module.events.alerts_topic_arn
  alb_arn_suffix    = module.compute.alb_arn_suffix
  tg_api_arn_suffix = module.compute.tg_api_arn_suffix
  ecs_cluster_name  = module.compute.ecs_cluster_name
  ecs_service_name  = module.compute.ecs_service_name
  db_instance_id    = module.database.db_instance_id
  dlq_name          = module.events.dlq_name
  stock_lambda_name = module.events.stock_lambda_name
}
