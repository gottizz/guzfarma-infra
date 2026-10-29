# Contrato del módulo. Reemplazar cada `null` por el valor real.

output "sg_alb_id" {
  description = "SG del ALB."
  value       = null # TODO: aws_security_group.alb.id
}

output "sg_app_id" {
  description = "SG de las tareas ECS."
  value       = null # TODO: aws_security_group.app.id
}

output "sg_lambda_id" {
  description = "SG de las Lambda dentro de la VPC."
  value       = null # TODO: aws_security_group.lambda.id
}

output "sg_db_id" {
  description = "SG de RDS Oracle."
  value       = null # TODO: aws_security_group.db.id
}

output "sg_vpclink_id" {
  description = "SG del VPC Link de API Gateway."
  value       = null # TODO: aws_security_group.vpclink.id
}

output "kms_key_arn" {
  description = "ARN de la llave KMS del proyecto."
  value       = null # TODO: aws_kms_key.main.arn
}

output "payment_secret_arn" {
  description = "ARN del secreto con las credenciales de la pasarela de pago."
  value       = null # TODO: aws_secretsmanager_secret.payment.arn
}

output "ssm_parameter_prefix" {
  description = "Prefijo de los parámetros de configuración en Parameter Store."
  value       = "/${var.project}/${var.environment}/"
}
