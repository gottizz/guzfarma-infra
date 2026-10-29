variable "project" {
  description = "Nombre corto del proyecto, se usa como prefijo de recursos."
  type        = string
  default     = "guzfarma"
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}
