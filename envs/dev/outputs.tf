output "url_tienda" {
  description = "URL pública (CloudFront)."
  value       = module.edge.cloudfront_domain_name
}

output "url_api" {
  description = "URL de API Gateway."
  value       = module.edge.api_endpoint
}

output "alb_dns" {
  description = "DNS del ALB (para pruebas directas en dev)."
  value       = module.compute.alb_dns_name
}

output "ecr_api_url" {
  description = "Repositorio ECR de la API."
  value       = module.compute.ecr_api_url
}

output "db_endpoint" {
  description = "Endpoint único de RDS Oracle."
  value       = module.database.db_address
}

output "cognito_user_pool_id" {
  description = "User pool de Cognito."
  value       = module.edge.cognito_user_pool_id
}
