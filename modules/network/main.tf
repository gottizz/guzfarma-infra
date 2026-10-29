# =============================================================================
# Módulo: network  ·  Responsable: Integrante 1
# Diagrama: VPC 10.0.0.0/16, 2 AZ, subredes pública / app / db, IGW, NAT por AZ.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "network" })

  # Sufijo de cada AZ para los nombres en la consola: a, b, ...
  az_suffix = [for az in var.azs : substr(az, -1, 1)]

  nat_count = var.single_nat_gateway ? 1 : length(var.azs)
}

# --- VPC e Internet Gateway --------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Los endpoints privados y el endpoint de RDS necesitan DNS dentro de la VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

# --- Subredes (una de cada tipo por AZ) ----------------------------------------

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name}-public-${local.az_suffix[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "app" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.name}-app-${local.az_suffix[count.index]}"
    Tier = "app"
  })
}

resource "aws_subnet" "db" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.name}-db-${local.az_suffix[count.index]}"
    Tier = "db"
  })
}

# --- NAT Gateway (1 en dev, una por AZ como en el diagrama) --------------------

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"
  tags   = merge(local.tags, { Name = "${local.name}-nat-eip-${local.az_suffix[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, { Name = "${local.name}-nat-${local.az_suffix[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

# --- Tablas de rutas -----------------------------------------------------------

# Pública: salida a Internet por el IGW, compartida por ambas subredes públicas.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.tags, { Name = "${local.name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App: una por AZ, salida a Internet por la NAT de su misma AZ
# (con single_nat_gateway = true, todas usan la NAT 0).
resource "aws_route_table" "app" {
  count = length(var.azs)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(local.tags, { Name = "${local.name}-rt-app-${local.az_suffix[count.index]}" })
}

resource "aws_route_table_association" "app" {
  count = length(var.azs)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# DB: sin ruta a Internet. Solo la ruta local de la VPC (y el S3 Gateway
# Endpoint que agrega el módulo security para RMAN).
resource "aws_route_table" "db" {
  count = length(var.azs)

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-rt-db-${local.az_suffix[count.index]}" })
}

resource "aws_route_table_association" "db" {
  count = length(var.azs)

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
}
