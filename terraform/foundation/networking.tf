# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Public Subnets - For resources that need public IPs
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
    Managed     = "terraform"
  }
}

# Private Subnets - For resources that don't need public IPs
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name        = "${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Private"
    Managed     = "terraform"
  }
}

# Internet Gateway - Enables public subnets to access the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Public Route Table - Routes traffic from public subnets to the internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table - Routes traffic within the VPC for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# NAT Gateway (Optional) - Allows private resources to access the internet
resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  
  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
    Managed     = "terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = {
    Name        = "${var.environment}-nat-gateway"
    Environment = var.environment
    Managed     = "terraform"
  }
  
  depends_on = [aws_internet_gateway.igw]
}

# Add a route to the NAT Gateway for private subnets if NAT Gateway is created
resource "aws_route" "private_nat" {
  count                  = var.create_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}