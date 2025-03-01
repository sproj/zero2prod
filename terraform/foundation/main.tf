provider "aws" {
  region  = var.aws_region
  profile = "infrastructure-admin"
}

# Create a security group for the application
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-sg"
  description = "Security group for ${var.environment} application"
  vpc_id      = aws_vpc.main.id
  
  # Allow inbound traffic to your application port from anywhere
  # This is a starting point - you'll want to restrict this further
  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow inbound traffic to application port"
  }
  
  # Allow all outbound traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Define common tags to be used across all resources
locals {
  common_tags = {
    Project     = "zero2prod"
    Environment = var.environment
    Managed     = "terraform"
    Layer       = "foundation"
  }
}