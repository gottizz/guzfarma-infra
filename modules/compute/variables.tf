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

variable "vpc_id" {
  description = "ID de la VPC (module.network)."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subredes públicas para los nodos del ALB (module.network)."
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "Subredes privadas para las tareas ECS (module.network)."
  type        = list(string)
}

variable "sg_alb_id" {
  description = "SG del ALB (module.security)."
  type        = string
}

variable "sg_app_id" {
  description = "SG de las tareas (module.security)."
  type        = string
}

variable "kms_key_arn" {
  description = "Llave KMS para logs y ECR (module.security)."
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "Prefijo de Parameter Store que la API puede leer (module.security)."
  type        = string
}

variable "payment_secret_arn" {
  description = "Secreto de la pasarela de pago (module.security)."
  type        = string
}

variable "db_address" {
  description = "Endpoint único de RDS (module.database)."
  type        = string
}

variable "db_port" {
  description = "Puerto de Oracle (module.database)."
  type        = number
}

variable "db_secret_arn" {
  description = "Secreto con la contraseña de Oracle (module.database)."
  type        = string
}

variable "orders_queue_url" {
  description = "URL de la cola SQS de pedidos (module.events)."
  type        = string
}

variable "orders_queue_arn" {
  description = "ARN de la cola SQS de pedidos, para el permiso sqs:SendMessage (module.events)."
  type        = string
}

variable "frontend_image" {
  description = "Imagen del contenedor nginx. Mientras no exista la app, una imagen pública sirve para probar."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "api_image" {
  description = "Imagen del contenedor de la API (puerto 8080). Normalmente <ecr_api_url>:<tag>."
  type        = string
  default     = ""
}

variable "task_cpu" {
  description = "CPU de la tarea Fargate (1024 = 1 vCPU)."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memoria de la tarea en MiB."
  type        = number
  default     = 1024
}

variable "min_tasks" {
  description = "Mínimo de tareas (una por AZ)."
  type        = number
  default     = 2
}

variable "max_tasks" {
  description = "Máximo de tareas (RNF-09)."
  type        = number
  default     = 8
}

variable "cpu_target" {
  description = "Porcentaje de CPU objetivo del Service Auto Scaling (RNF-09)."
  type        = number
  default     = 60
}

variable "peak_min_tasks" {
  description = "Mínimo de tareas en fines de semana y última semana del mes (RNF-09)."
  type        = number
  default     = 4
}

variable "health_check_path" {
  description = "Ruta del health check del ALB."
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "Certificado ACM regional para HTTPS en el ALB. Vacío = solo listener HTTP 80 (sirve para dev)."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retención de logs en CloudWatch (RNF-18)."
  type        = number
  default     = 90
}

variable "existing_role_arn" {
  description = "Si la cuenta no permite crear roles IAM (p. ej. AWS Academy Learner Lab con LabRole), poner aquí el ARN del rol existente."
  type        = string
  default     = null
}
