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

variable "alerts_topic_arn" {
  description = "Tópico SNS al que se envían las alarmas (module.events)."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (module.compute)."
  type        = string
}

variable "tg_api_arn_suffix" {
  description = "Sufijo del ARN del target group de la API (module.compute)."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Cluster ECS (module.compute)."
  type        = string
}

variable "ecs_service_name" {
  description = "Servicio ECS (module.compute)."
  type        = string
}

variable "db_instance_id" {
  description = "Instancia RDS (module.database)."
  type        = string
}

variable "dlq_name" {
  description = "DLQ de pedidos (module.events)."
  type        = string
}

variable "stock_lambda_name" {
  description = "Lambda stock-monitor (module.events)."
  type        = string
}

variable "latency_p95_threshold_seconds" {
  description = "Latencia p95 máxima de la API (RNF-07 / RNF-12)."
  type        = number
  default     = 2
}

variable "error_5xx_threshold_percent" {
  description = "Porcentaje máximo de errores 5xx en 5 minutos (RNF-18)."
  type        = number
  default     = 1
}

variable "ecs_cpu_threshold" {
  description = "CPU de las tareas ECS que dispara alarma (RNF-18)."
  type        = number
  default     = 80
}

variable "rds_cpu_threshold" {
  description = "CPU de RDS que dispara alarma (RNF-12)."
  type        = number
  default     = 75
}
