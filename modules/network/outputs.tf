# Contrato del módulo: los demás módulos dependen de estos nombres.
# No cambiar los nombres sin avisar al grupo. Reemplazar cada `null` por el valor real.

output "vpc_id" {
  description = "ID de la VPC."
  value       = null # TODO: aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC."
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas [A, B]."
  value       = [] # TODO: aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "IDs de las subredes privadas de aplicación [A, B]."
  value       = [] # TODO: aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "IDs de las subredes privadas de base de datos [A, B]."
  value       = [] # TODO: aws_subnet.db[*].id
}

output "app_route_table_ids" {
  description = "Tablas de rutas de las subredes de app (para el S3 Gateway Endpoint)."
  value       = [] # TODO: aws_route_table.app[*].id
}

output "db_route_table_ids" {
  description = "Tablas de rutas de las subredes de db (para el S3 Gateway Endpoint de RMAN)."
  value       = [] # TODO: aws_route_table.db[*].id
}
