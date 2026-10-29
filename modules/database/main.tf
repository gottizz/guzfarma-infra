# =============================================================================
# Módulo: database  ·  Responsable: Integrante 3
# Diagrama: RDS Oracle Multi-AZ (primaria + standby) con endpoint único :1521,
#           cifrada con KMS, y bucket S3 para respaldos RMAN.
# =============================================================================

locals {
  name = lower(replace("${var.project}-${var.environment}", "_", "-"))
  tags = merge(var.tags, { Module = "database" })
}

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
