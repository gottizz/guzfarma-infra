# Contrato del módulo. Reemplazar cada `null` por el valor real.

output "alb_arn" {
  description = "ARN del ALB (para asociar el WAF regional)."
  value       = null # TODO: aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS del ALB (origen de CloudFront)."
  value       = null # TODO: aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (dimensión de las métricas de CloudWatch)."
  value       = null # TODO: aws_lb.this.arn_suffix
}

output "alb_listener_arn" {
  description = "Listener al que se conecta el VPC Link de API Gateway (el HTTPS si existe, si no el HTTP)."
  value       = null # TODO
}

output "tg_api_arn_suffix" {
  description = "Sufijo del ARN del target group de la API (métricas)."
  value       = null # TODO: aws_lb_target_group.api.arn_suffix
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS."
  value       = null # TODO: aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS."
  value       = null # TODO: aws_ecs_service.app.name
}

output "ecr_api_url" {
  description = "URL del repositorio ECR de la API (para docker push)."
  value       = null # TODO: aws_ecr_repository.api.repository_url
}

output "ecr_web_url" {
  description = "URL del repositorio ECR del frontend."
  value       = null # TODO: aws_ecr_repository.web.repository_url
}
