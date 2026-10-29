variable "project" {
  description = "Nombre corto del proyecto (prefijo de recursos)."
  type        = string
}

variable "environment" {
  description = "Entorno: dev, prod."
  type        = string
}

variable "tags" {
  description = "Etiquetas extra para los recursos del módulo."
  type        = map(string)
  default     = {}
}

variable "alb_dns_name" {
  description = "DNS del ALB, origen de CloudFront para la web (module.compute)."
  type        = string
}

variable "alb_arn" {
  description = "ARN del ALB, para asociar el WAF regional (module.compute)."
  type        = string
}

variable "alb_listener_arn" {
  description = "Listener del ALB al que apunta la integración privada de API Gateway (module.compute)."
  type        = string
}

variable "app_subnet_ids" {
  description = "Subredes privadas donde se crea el VPC Link (module.network)."
  type        = list(string)
}

variable "sg_vpclink_id" {
  description = "SG del VPC Link (module.security)."
  type        = string
}

variable "domain_name" {
  description = "Dominio propio (p. ej. tienda.guzfarma.pe). Vacío = usar el dominio *.cloudfront.net."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Zona de Route 53 del dominio. Solo si domain_name no está vacío."
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "Certificado ACM en us-east-1 para el dominio propio. Solo si domain_name no está vacío."
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  description = "Máximo de solicitudes por IP cada 5 minutos (RNF-15)."
  type        = number
  default     = 1000
}

variable "api_throttle_rate" {
  description = "Solicitudes por segundo sostenidas en API Gateway (RNF-15)."
  type        = number
  default     = 100
}

variable "api_throttle_burst" {
  description = "Ráfaga máxima en API Gateway."
  type        = number
  default     = 200
}

variable "cognito_callback_urls" {
  description = "URLs de retorno del login de Cognito."
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}
