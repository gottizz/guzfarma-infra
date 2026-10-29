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