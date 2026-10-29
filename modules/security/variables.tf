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

variable "vpc_cidr" {
  description = "CIDR de la VPC (module.network)."
  type        = string
}

variable "app_subnet_ids" {
  description = "Subredes de app donde se crean los Interface Endpoints (module.network)."
  type        = list(string)
}

variable "endpoint_route_table_ids" {
  description = "Tablas de rutas de app y db para el S3 Gateway Endpoint (module.network)."
  type        = list(string)
}

variable "app_ports" {
  description = "Puertos de los contenedores: nginx (frontend) y API."
  type        = list(number)
  default     = [80, 8080]
}

variable "db_port" {
  description = "Puerto de Oracle."
  type        = number
  default     = 1521
}

variable "enable_interface_endpoints" {
  description = "Crear los Interface Endpoints (PrivateLink). Cuestan por hora y por AZ; se pueden apagar en dev."
  type        = bool
  default     = true
}

variable "interface_endpoint_services" {
  description = "Servicios con Interface Endpoint (sufijo de com.amazonaws.<región>.<servicio>)."
  type        = list(string)
  # Verificar el nombre del endpoint de SES en la región con:
  #   aws ec2 describe-vpc-endpoint-services --query "ServiceNames[?contains(@, 'email')]"
  default = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "ssm", "kms", "sqs", "sns", "email-smtp"]
}
