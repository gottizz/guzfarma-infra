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

# Rol que RDS asume para escribir los respaldos RMAN en S3
data "aws_iam_policy_document" "rds_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_s3" {
  name               = "${local.name}-rds-s3"
  assume_role_policy = data.aws_iam_policy_document.rds_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "rds_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",

    ]
    resources = [
      aws_s3_bucket.rman.arn,
      "${aws_s3_bucket.rman.arn}/*",
    ]
  }

  statement {
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "rds_s3" {
  name   = "s3-rman"
  role   = aws_iam_role.rds_s3.id
  policy = data.aws_iam_policy_document.rds_s3.json
}

resource "aws_db_instance" "this" {
  identifier = "${local.name}-oracle"

  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  db_name           = var.db_name
  port              = var.db_port
  license_model     = "license-included"

  username                    = var.db_username
  manage_master_user_password = true

  master_user_secret_kms_key_id = var.kms_key_arn

  multi_az          = var.multi_az
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.sg_db_id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name
  option_group_name      = aws_db_option_group.this.name

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = "${local.name}-final"

  tags = local.tags
}

resource "aws_db_instance_role_association" "s3" {
  db_instance_identifier = aws_db_instance.this.identifier
  feature_name           = "S3_INTEGRATION"
  role_arn               = aws_iam_role.rds_s3.arn
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
