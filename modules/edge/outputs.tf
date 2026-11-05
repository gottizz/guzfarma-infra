output "cloudfront_domain_name" {
  description = "Dominio de CloudFront: la URL pública de la tienda."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución (para invalidar caché)."
  value       = aws_cloudfront_distribution.this.id
}

output "api_endpoint" {
  description = "URL base de API Gateway."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "cognito_user_pool_id" {
  description = "ID del user pool de Cognito."
  value       = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  description = "ID del cliente web de Cognito."
  value       = aws_cognito_user_pool_client.web.id
}