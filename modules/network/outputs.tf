# Contrato del módulo: los demás módulos dependen de estos nombres.
# No cambiar los nombres sin avisar al grupo.

output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC."
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas [A, B]."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "IDs de las subredes privadas de aplicación [A, B]."
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "IDs de las subredes privadas de base de datos [A, B]."
  value       = aws_subnet.db[*].id
}

output "app_route_table_ids" {
  description = "Tablas de rutas de las subredes de app (para el S3 Gateway Endpoint)."
  value       = aws_route_table.app[*].id
}

output "db_route_table_ids" {
  description = "Tablas de rutas de las subredes de db (para el S3 Gateway Endpoint de RMAN)."
  value       = aws_route_table.db[*].id
}
