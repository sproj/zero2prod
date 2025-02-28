# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
  
  tags = {
    Name        = "${var.app_name}-logs"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name        = "${var.app_name}-cluster"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  # Reference the execution role from the foundation layer
  execution_role_arn       = data.terraform_remote_state.foundation.outputs.ecs_task_execution_role_arn
  
  container_definitions = jsonencode([{
    name      = "${var.app_name}-container"
    image     = "${var.ecr_repository_url}:latest"
    essential = true
    
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    
    # Environment variables
    environment = [
      {
        name  = "APP_ENVIRONMENT"
        value = "production"
      }
    ]
    
    # When you're ready to add secrets, you can include them here
    # secrets = [
    #   {
    #     name      = "DATABASE_URL"
    #     valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}-db-url::"
    #   }
    # ]
  }])
  
  tags = {
    Name        = "${var.app_name}-task-definition"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
  }
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  
  network_configuration {
    # Reference subnet IDs from the foundation layer
    subnets         = data.terraform_remote_state.foundation.outputs.public_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }
  
  lifecycle {
    ignore_changes = [
      task_definition, # Allow external updates to task definition
      desired_count    # Allow manual scaling without Terraform reverting it
    ]
  }
  
  tags = {
    Name        = "${var.app_name}-service"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
  }
}