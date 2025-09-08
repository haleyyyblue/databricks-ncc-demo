# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-igw"
  })
}

# Public Subnet (for EC2)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-public-subnet"
    Type = "Public"
  })
}

# Private Subnet 1 (for RDS)
resource "aws_subnet" "private_rds_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_rds_cidr
  availability_zone = var.availability_zones[0]

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.prefix}-private-rds-subnet-1"
    Type    = "Private"
    Purpose = "RDS"
  })
}

# Private Subnet 2 (for RDS - second AZ for DB Subnet Group)
resource "aws_subnet" "private_rds_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_rds_cidr_2
  availability_zone = var.availability_zones[1]

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.prefix}-private-rds-subnet-2"
    Type    = "Private"
    Purpose = "RDS"
  })
}

# Private Subnet 3 (for NLB)
resource "aws_subnet" "private_nlb" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_nlb_cidr
  availability_zone = var.availability_zones[0]

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.prefix}-private-nlb-subnet"
    Type    = "Private"
    Purpose = "NLB"
  })
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  depends_on = [aws_vpc.main, aws_internet_gateway.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-public-rt"
  })
}

# Elastic IP for NAT Gateway (only if NAT Gateway is enabled)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-nat-eip"
  })
}

# NAT Gateway (optional - for private subnet internet access)
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  depends_on = [
    aws_internet_gateway.main,
    aws_eip.nat
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-nat-gateway"
  })
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Add route to NAT Gateway if enabled
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-private-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_rds_1" {
  subnet_id      = aws_subnet.private_rds_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rds_2" {
  subnet_id      = aws_subnet.private_rds_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_nlb" {
  subnet_id      = aws_subnet.private_nlb.id
  route_table_id = aws_route_table.private.id
}
