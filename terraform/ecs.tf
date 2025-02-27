# CloudWatch Log Group for your application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
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
    
    # Environment variables can be added here
    # environment = [
    #   {
    #     name  = "ENVIRONMENT_VARIABLE_NAME"
    #     value = "value"
    #   }
    # ]
    
    # When you're ready to add secrets, you'd include them here
    # secrets = [
    #   {
    #     name      = "SECRET_NAME"
    #     valueFrom = "arn:aws:secretsmanager:region:account:secret:path"
    #   }
    # ]
  }])
  
  tags = {
    Name = "${var.app_name}-task-definition"
  }
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-fargate-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }
  
  lifecycle {
    ignore_changes = [
      task_definition, # Allow external updates to task definition
      desired_count    # Allow manual scaling without Terraform reverting it
    ]
  }
  
  # Depends on the service-linked role being available
  depends_on = [aws_iam_service_linked_role.ecs]
  
  tags = {
    Name = "${var.app_name}-service"
  }
}