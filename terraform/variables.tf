variable "region" {
  description = "Región de AWS del laboratorio."
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string
  default     = "dev"
}

variable "prefix" {
  description = "Prefijo común de todos los recursos del laboratorio."
  type        = string
  default     = "lab09"
}

variable "log_retention_days" {
  description = "Días que se conservan los logs de la Lambda."
  type        = number
  default     = 7
}
