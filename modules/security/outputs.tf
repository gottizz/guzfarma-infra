output "sg_alb_id" {
  value = aws_security_group.groups["alb"].id
}

output "sg_app_id" {
  value = aws_security_group.groups["app"].id
}

output "sg_lambda_id" {
  value = aws_security_group.groups["lambda"].id
}

output "sg_db_id" {
  value = aws_security_group.groups["db"].id
}

output "sg_vpclink_id" {
  value = aws_security_group.groups["vpclink"].id
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "payment_secret_arn" {
  value = aws_secretsmanager_secret.payment.arn
}

output "ssm_parameter_prefix" {
  value = local.parameter_prefix
}

