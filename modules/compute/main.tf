# =============================================================================
# Módulo: compute  ·  Responsable: Integrante 4
# Diagrama: ECR, ALB único (nodos en ambas AZ), ECS Fargate con 2 contenedores
#           (nginx :80 + API :8080), Service Auto Scaling.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "compute" })

  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# =============================================================================
# 1. Imágenes (ECR)
# =============================================================================

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # dev: permite terraform destroy aunque haya imágenes

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(local.tags, { Name = "${local.name}-api" })
}

resource "aws_ecr_repository" "web" {
  name                 = "${local.name}-web"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(local.tags, { Name = "${local.name}-web" })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = {
    api = aws_ecr_repository.api.name
    web = aws_ecr_repository.web.name
  }

  repository = each.value

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar solo las ultimas 10 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

locals {
  # HTTPS solo si hay certificado ACM. El listener "principal" es el que recibe el tráfico.
  https_enabled     = var.certificate_arn != ""
  main_listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

# =============================================================================
# 2. Balanceador (un solo ALB con nodos en las 2 subredes públicas)
# =============================================================================

resource "aws_lb" "this" {
  name                       = "${local.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [var.sg_alb_id]
  drop_invalid_header_fields = true
  enable_deletion_protection = false # dev

  tags = merge(local.tags, { Name = "${local.name}-alb" })
}

# Frontend (nginx :80)
resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-web"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip" # obligatorio con Fargate (awsvpc)
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Name = "${local.name}-web" })
}

# API (:8080). RNF-02: thresholds 2 e intervalo 30 s.
resource "aws_lb_target_group" "api" {
  name                 = "${local.name}-api"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, { Name = "${local.name}-api" })
}

# Puerto 80: si hay certificado redirige a 443; si no, envía al frontend.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.web.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  tags = local.tags
}

# Puerto 443: solo si hay certificado ACM.
resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = local.tags
}

# /api/* -> TG-api, en el listener que recibe el tráfico (443 si existe, si no 80).
resource "aws_lb_listener_rule" "api" {
  listener_arn = local.main_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = local.tags
}

locals {
  # Roles: en AWS Academy no se pueden crear roles IAM -> se usa LabRole para ambos.
  create_roles       = var.existing_role_arn == null
  execution_role_arn = local.create_roles ? aws_iam_role.execution[0].arn : var.existing_role_arn
  task_role_arn      = local.create_roles ? aws_iam_role.task[0].arn : var.existing_role_arn

  # Prefijo de Parameter Store sin "/" final (ej. "/guzfarma/dev").
  ssm_path = trimsuffix(var.ssm_parameter_prefix, "/")
}

# =============================================================================
# 3. ECS Fargate
# =============================================================================

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name}/api"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.name}/web"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

# --- IAM (solo si la cuenta permite crear roles; en AWS Academy se usa LabRole) ---

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rol de ejecución: lo usa el agente de ECS para bajar la imagen, escribir logs y leer secretos.
resource "aws_iam_role" "execution" {
  count = local.create_roles ? 1 : 0

  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  count = local.create_roles ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = local.create_roles ? 1 : 0

  name = "leer-secretos"
  role = aws_iam_role.execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LeerSecretos"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn, var.payment_secret_arn]
      },
      {
        Sid      = "DescifrarSecretosEImagenes"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
    ]
  })
}

# Rol de tarea: los permisos que usa el código de la API en tiempo de ejecución.
resource "aws_iam_role" "task" {
  count = local.create_roles ? 1 : 0

  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "task_app" {
  count = local.create_roles ? 1 : 0

  name = "permisos-api"
  role = aws_iam_role.task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnviarPedidos"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = [var.orders_queue_arn]
      },
      {
        Sid    = "LeerConfiguracion"
        Effect = "Allow"
        Action = ["ssm:GetParametersByPath", "ssm:GetParameters", "ssm:GetParameter"]
        Resource = [
          "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter${local.ssm_path}",
          "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter${local.ssm_path}/*",
        ]
      },
      {
        # Decrypt: parámetros SecureString. GenerateDataKey: enviar a la cola SQS cifrada con KMS.
        Sid      = "UsarLlaveKMS"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      },
    ]
  })
}