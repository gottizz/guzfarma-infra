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

variable "app_subnet_ids" {
  description = "Subredes de app donde la Lambda stock-monitor crea sus ENI (module.network)."
  type        = list(string)
}

variable "sg_lambda_id" {
  description = "SG de las Lambda (module.security)."
  type        = string
}

variable "kms_key_arn" {
  description = "Llave KMS para cifrar colas y tópicos (module.security)."
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
  description = "Secreto de Oracle, lo lee stock-monitor (module.database)."
  type        = string
}

variable "lambdas_source_dir" {
  description = "Carpeta con el código de las Lambda (lambdas/ en la raíz del repo)."
  type        = string
}

variable "ses_sender_email" {
  description = "Correo remitente verificado en SES para las confirmaciones de pedido."
  type        = string
}

variable "admin_email" {
  description = "Correo del administrador suscrito a las alertas de stock y alarmas (SNS)."
  type        = string
}

variable "stock_check_schedule" {
  description = "Horario de stock-monitor en UTC (11:00 UTC = 06:00 Lima)."
  type        = string
  default     = "cron(0 11 * * ? *)"
}

variable "max_receive_count" {
  description = "Intentos antes de mandar un pedido a la DLQ (RNF-05)."
  type        = number
  default     = 3
}

variable "existing_role_arn" {
  description = "Rol IAM existente para las Lambda si la cuenta no permite crear roles (Learner Lab)."
  type        = string
  default     = null
}
