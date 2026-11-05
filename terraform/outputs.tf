output "api_url" {
  description = "URL base de la API."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "lambda_name" {
  value = aws_lambda_function.productos.function_name
}
