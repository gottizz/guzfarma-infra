# =============================================================================
# Módulo: database  ·  Responsable: Integrante 3
# Diagrama: RDS Oracle Multi-AZ (primaria + standby) con endpoint único :1521,
#           cifrada con KMS, y bucket S3 para respaldos RMAN.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "database" })
}

# TODO (Integrante 3)
#
# --- Base de datos ---
# [ ] aws_db_subnet_group.this        subnet_ids = var.db_subnet_ids
# [ ] aws_db_parameter_group.this     family = "oracle-se2-19"
# [ ] aws_db_option_group.this        engine_name = var.engine, major_engine_version = var.engine_version
#                                     option "S3_INTEGRATION" (permite subir los respaldos RMAN a S3)
# [ ] aws_iam_role.rds_s3             rol que RDS asume para escribir en el bucket de respaldos
#     + aws_db_instance_role_association.s3   feature_name = "S3_INTEGRATION"
# [ ] aws_db_instance.this
#       engine / engine_version / instance_class / allocated_storage / db_name / port = var.*
#       license_model                     = "license-included"
#       username                          = var.db_username
#       manage_master_user_password       = true               # RDS crea y rota la contraseña en Secrets Manager
#       master_user_secret_kms_key_id     = var.kms_key_arn
#       multi_az                          = var.multi_az
#       storage_encrypted = true, kms_key_id = var.kms_key_arn
#       db_subnet_group_name, vpc_security_group_ids = [var.sg_db_id], publicly_accessible = false
#       backup_retention_period = var.backup_retention_days, backup_window, maintenance_window
#       performance_insights_enabled = true (RNF-12)
#       deletion_protection = var.deletion_protection
#       skip_final_snapshot = !var.deletion_protection
#       final_snapshot_identifier = "${local.name}-final"
#
# --- Respaldos RMAN ---
# [ ] aws_s3_bucket.rman                       "${local.name}-rman-<account_id>"
# [ ] aws_s3_bucket_versioning.rman            Enabled
# [ ] aws_s3_bucket_server_side_encryption_configuration.rman   aws:kms con var.kms_key_arn
# [ ] aws_s3_bucket_public_access_block.rman   todo en true
# [ ] aws_s3_bucket_lifecycle_configuration.rman   expirar objetos a los var.rman_retention_days días
#
# Los respaldos RMAN en sí se ejecutan desde la base con rdsadmin.rdsadmin_rman_util
# y rdsadmin.rdsadmin_s3_tasks (documentarlo en el README del módulo; no es Terraform).
#
# Criterio de terminado: plan sin errores y outputs con valores reales.
# OJO costos: Oracle Multi-AZ es lo más caro del proyecto. Aplicar, probar y destruir.
