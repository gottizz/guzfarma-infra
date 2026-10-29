# =============================================================================
# Módulo: network  ·  Responsable: Integrante 1
# Diagrama: VPC 10.0.0.0/16, 2 AZ, subredes pública / app / db, IGW, NAT por AZ.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "network" })
}

# TODO (Integrante 1) - recursos a crear, en este orden:
#
# [ ] aws_vpc.this                     cidr = var.vpc_cidr, enable_dns_support y enable_dns_hostnames = true
#                                      (los endpoints privados y el endpoint de RDS necesitan DNS)
# [ ] aws_internet_gateway.this        asociado a la VPC
# [ ] aws_subnet.public[*]             count = length(var.azs), map_public_ip_on_launch = true
# [ ] aws_subnet.app[*]                privadas, una por AZ
# [ ] aws_subnet.db[*]                 privadas, una por AZ
# [ ] aws_eip.nat[*]                   1 o 2 según var.single_nat_gateway
# [ ] aws_nat_gateway.this[*]          en las subredes públicas
# [ ] aws_route_table.public           0.0.0.0/0 -> IGW, asociada a ambas subredes públicas
# [ ] aws_route_table.app[*]           una por AZ, 0.0.0.0/0 -> NAT de su misma AZ
#                                      (si single_nat_gateway = true, ambas apuntan a la NAT 0)
# [ ] aws_route_table.db[*]            sin ruta a Internet (la base no sale a Internet)
# [ ] asociaciones de cada subred con su tabla de rutas
#
# Nombres: usar tags Name = "${local.name}-<recurso>-<a|b>" para que se vean bien en la consola.
# Criterio de terminado: `terraform plan` en envs/dev muestra la VPC, 6 subredes,
# 1 IGW, 2 NAT (o 1) y las tablas de rutas; y los outputs dejan de ser null.
