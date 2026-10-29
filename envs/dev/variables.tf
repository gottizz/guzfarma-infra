variable "project" {
  description = "Nombre corto del proyecto."
  type        = string
  default     = "guzfarma"
}

variable "environment" {
  description = "Nombre del entorno."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

# --- Interruptores de costo (en dev conviene apagarlos mientras se prueba) ---

variable "single_nat_gateway" {
  description = "true = una sola NAT Gateway (ahorra ~32 USD/mes)."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Crear los Interface Endpoints (cada uno cobra por hora y por AZ)."
  type        = bool
  default     = false
}

variable "db_multi_az" {
  description = "Standby de RDS en la otra AZ (duplica el costo de la base)."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protección contra borrado de la base."
  type        = bool
  default     = false
}

# --- Datos que cada grupo debe completar en terraform.tfvars ---

variable "ses_sender_email" {
  description = "Correo remitente de las confirmaciones (se verifica en SES)."
  type        = string
}

variable "admin_email" {
  description = "Correo que recibe alertas de stock y alarmas."
  type        = string
}

variable "lab_role_arn" {
  description = "ARN del rol existente si la cuenta no permite crear roles IAM (AWS Academy: LabRole). null = crear roles."
  type        = string
  default     = null
}
