# Contrato del módulo. Reemplazar cada `null` por el valor real.

output "db_address" {
  description = "Endpoint único de RDS (DNS Multi-AZ), sin puerto."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Puerto de Oracle."
  value       = var.db_port
}

output "db_name" {
  description = "Nombre de la base (SID)."
  value       = var.db_name
}

output "db_instance_id" {
  description = "Identificador de la instancia (para alarmas de CloudWatch)."
  value       = aws_db_instance.this.identifier
}

output "db_secret_arn" {
  description = "ARN del secreto que RDS creó con usuario y contraseña."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "rman_bucket_name" {
  description = "Bucket de respaldos RMAN."
  value       = aws_s3_bucket.rman.bucket
}
