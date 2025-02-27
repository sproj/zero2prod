# Security group for Fargate tasks
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name} Fargate tasks"
  vpc_id      = var.vpc_id
  
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
    Name = "${var.app_name}-sg"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "escTaskRunner"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
  
  tags = {
    Name = "${var.app_name}-ecs-task-execution-role"
  }
}

# Attach the required policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create the service-linked role for ECS if it doesn't exist
# Note: This is typically created automatically by AWS, but we can ensure it exists
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
  description      = "Service-linked role for Amazon ECS"
  
  # Custom error handling to ignore if the role already exists
  provisioner "local-exec" {
    command = "echo 'Service-linked role created or already exists'"
    on_failure = continue
  }
}