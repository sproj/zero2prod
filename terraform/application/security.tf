# Security group for Fargate tasks
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name} Fargate tasks"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  
  # Allow inbound traffic to your application port
  ingress {
    protocol    = "tcp"
    from_port   = var.container_port
    to_port     = var.container_port
    cidr_blocks = ["${var.your_ip}/32"]
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
    Name        = "${var.app_name}-sg"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
  }
}

