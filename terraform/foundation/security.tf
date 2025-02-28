# Common Security Group - For shared resources
resource "aws_security_group" "common" {
  name        = "${var.environment}-common-sg"
  description = "Common security group for ${var.environment} environment"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name        = "${var.environment}-common-sg"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# IAM Role for ECS Task Execution - Fundamental for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment}-ecs-task-execution-role"
  
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
    Name        = "${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Custom policy with all necessary permissions
resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "${var.environment}-task-execution-policy"
  description = "Permissions for ECS task execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"  # This would be more specific in the application layer
      }
    ]
  })
}

# Attach the AWS managed policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_managed_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the custom policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_custom_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}
