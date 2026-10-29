# =============================================================================
# Módulo: compute  ·  Responsable: Integrante 4
# Diagrama: ECR, ALB único (nodos en ambas AZ), ECS Fargate con 2 contenedores
#           (nginx :80 + API :8080), Service Auto Scaling.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "compute" })
}

# TODO (Integrante 4)
#
# --- Imágenes ---
# [ ] aws_ecr_repository.api y aws_ecr_repository.web   image_scanning_configuration { scan_on_push = true }
#                                                       encryption_type = "KMS", kms_key = var.kms_key_arn
# [ ] aws_ecr_lifecycle_policy                          conservar las últimas 10 imágenes
#
# --- Balanceador (UN solo ALB con nodos en las 2 subredes públicas) ---
# [ ] aws_lb.this                 load_balancer_type = "application", subnets = var.public_subnet_ids,
#                                 security_groups = [var.sg_alb_id]
# [ ] aws_lb_target_group.web     port 80,   target_type = "ip", health_check path = var.health_check_path
# [ ] aws_lb_target_group.api     port 8080, target_type = "ip", health_check path = var.health_check_path,
#                                 healthy/unhealthy threshold = 2, interval = 30 (RNF-02)
# [ ] aws_lb_listener.http        puerto 80. Si var.certificate_arn != "" -> redirect a 443; si no, forward a TG-web
# [ ] aws_lb_listener.https       count = var.certificate_arn != "" ? 1 : 0, puerto 443, default -> TG-web
# [ ] aws_lb_listener_rule.api    path_pattern ["/api/*"] -> TG-api (en el listener que reciba el tráfico)
#
# --- ECS ---
# [ ] aws_cloudwatch_log_group.api y .web   "/ecs/${local.name}/<api|web>", retention = var.log_retention_days
# [ ] aws_iam_role.execution      (solo si var.existing_role_arn == null) política AmazonECSTaskExecutionRolePolicy
#                                 + permiso secretsmanager:GetSecretValue sobre var.db_secret_arn y var.payment_secret_arn
# [ ] aws_iam_role.task           permisos de la app: sqs:SendMessage en var.orders_queue_arn,
#                                 ssm:GetParametersByPath en var.ssm_parameter_prefix, kms:Decrypt
# [ ] aws_ecs_cluster.this        setting containerInsights = "enabled"
# [ ] aws_ecs_task_definition.app requires_compatibilities = ["FARGATE"], network_mode = "awsvpc",
#                                 cpu/memory = var.task_cpu / var.task_memory
#                                 contenedor "web": var.frontend_image, puerto 80
#                                 contenedor "api": var.api_image, puerto 8080,
#                                   environment: DB_HOST = var.db_address, DB_PORT, ORDERS_QUEUE_URL
#                                   secrets:     DB_SECRET  <- var.db_secret_arn, PAYMENT_SECRET <- var.payment_secret_arn
# [ ] aws_ecs_service.app         launch_type = "FARGATE", desired_count = var.min_tasks,
#                                 network_configuration { subnets = var.app_subnet_ids, security_groups = [var.sg_app_id] }
#                                 load_balancer x2 (web:80 -> TG-web, api:8080 -> TG-api)
#                                 deployment_circuit_breaker { enable = true, rollback = true }
#
# --- Auto Scaling (RNF-09) ---
# [ ] aws_appautoscaling_target.ecs        min = var.min_tasks, max = var.max_tasks
# [ ] aws_appautoscaling_policy.cpu        TargetTrackingScaling, ECSServiceAverageCPUUtilization = var.cpu_target
# [ ] aws_appautoscaling_scheduled_action  x3: viernes 18:00 Lima -> min = var.peak_min_tasks;
#                                          lunes 08:00 Lima -> min = var.min_tasks;
#                                          día 24 de cada mes -> min = var.peak_min_tasks (y volver el día 1)
#                                          (las expresiones cron van en UTC: Lima = UTC-5)
#
# Criterio de terminado: con apply, la URL del ALB muestra la página de nginx.
