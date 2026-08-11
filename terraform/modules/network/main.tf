resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

# ============================================================
# PUBLIC SUBNETS
# ============================================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
  }
}

# ============================================================
# PRIVATE SUBNETS
# ============================================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# ============================================================
# PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-public-route-table"
  }
}

# ============================================================
# INTERNET ROUTE
# ============================================================

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# ============================================================
# PUBLIC SUBNETS -> PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# ELASTIC IPs FOR NAT GATEWAYS
# ============================================================

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
  }
}

# ============================================================
# NAT GATEWAYS
# ============================================================

resource "aws_nat_gateway" "nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.vpc_name}-nat-${var.availability_zones[count.index]}"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

# ============================================================
# PRIVATE ROUTE TABLES
# ============================================================

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-route-table-${var.availability_zones[count.index]}"
  }
}

# ============================================================
# PRIVATE INTERNET ROUTES VIA NAT GATEWAYS
# ============================================================

resource "aws_route" "private_nat" {
  count = 2

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

# ============================================================
# PRIVATE SUBNETS -> PRIVATE ROUTE TABLES
# ============================================================

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}