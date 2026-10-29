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

variable "db_subnet_ids" {
  description = "Subredes privadas de db [A, B] (module.network)."
  type        = list(string)
}

variable "sg_db_id" {
  description = "SG de la base de datos (module.security)."
  type        = string
}

variable "kms_key_arn" {
  description = "Llave KMS para cifrar la base, el secreto y el bucket de respaldos (module.security)."
  type        = string
}

variable "engine" {
  description = "Motor: Oracle Standard Edition 2 con licencia incluida."
  type        = string
  default     = "oracle-se2"
}

variable "engine_version" {
  description = "Versión de Oracle. Ver: aws rds describe-db-engine-versions --engine oracle-se2."
  type        = string
  default     = "19"
}

variable "instance_class" {
  description = "Tipo de instancia. Revisar cuáles admite oracle-se2 con license-included en la región."
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Almacenamiento inicial en GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base (SID), máximo 8 caracteres."
  type        = string
  default     = "GUZFARMA"
}

variable "db_username" {
  description = "Usuario maestro. La contraseña la genera RDS y la guarda en Secrets Manager."
  type        = string
  default     = "guzadmin"
}

variable "db_port" {
  description = "Puerto de Oracle."
  type        = number
  default     = 1521
}

variable "multi_az" {
  description = "Standby síncrona en la otra AZ (RNF-03). Se puede apagar en dev para ahorrar."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Días de backups automáticos con recuperación a un punto en el tiempo (RNF-17: 35)."
  type        = number
  default     = 35
}

variable "backup_window" {
  description = "Ventana de backup en UTC (05:00 UTC = 00:00 Lima)."
  type        = string
  default     = "05:00-06:00"
}

variable "maintenance_window" {
  description = "Ventana de mantenimiento en UTC (martes 02:00-04:00 Lima, RNF-06)."
  type        = string
  default     = "tue:07:00-tue:09:00"
}

variable "deletion_protection" {
  description = "Evita borrar la base por accidente. En dev puede ser false."
  type        = bool
  default     = true
}

variable "rman_retention_days" {
  description = "Días que se guardan los respaldos RMAN en S3 (RNF-17: 3 meses)."
  type        = number
  default     = 90
}
