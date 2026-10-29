# =============================================================================
# Módulo: database  ·  Responsable: Integrante 3
# Diagrama: RDS Oracle Multi-AZ (primaria + standby) con endpoint único :1521,
#           cifrada con KMS, y bucket S3 para respaldos RMAN.
# =============================================================================

locals {
  name = lower(replace("${var.project}-${var.environment}", "_", "-"))
  tags = merge(var.tags, { Module = "database" })
}

data "aws_caller_identity" "current" {}

# --- Base de datos -----------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = var.db_subnet_ids
  tags       = local.tags
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-oracle"
  family = "oracle-se2-19"
  tags   = local.tags
}

resource "aws_db_option_group" "this" {
  name                 = "${local.name}-oracle"
  engine_name          = var.engine
  major_engine_version = var.engine_version

  option {
    option_name = "S3_INTEGRATION"
  }

  tags = local.tags
}

# --- Respaldos RMAN ----------------------------------------------------------

resource "aws_s3_bucket" "rman" {
  bucket        = "local.name-rman-{data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "rman" {
  bucket = aws_s3_bucket.rman.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rman" {
  bucket = aws_s3_bucket.rman.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "rman" {
  bucket              = aws_s3_bucket.rman.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true

  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "rman" {
  bucket = aws_s3_bucket.rman.id

  rule {
    id     = "expirar-respaldos"
    status = "Enabled"

    filter {}

    expiration {
      days = var.rman_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.rman_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.rman]
}
