# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.environment}-${var.app_name}"
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
        "awslogs-group"         = data.terraform_remote_state.foundation.outputs.cloudwatch_log_group_name
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
  }])
  
  tags = {
    Name        = "${var.app_name}-task-definition"
    Environment = var.environment
    Managed     = "terraform"
    Application = var.app_name
    Layer       = "application"
  }
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = data.terraform_remote_state.foundation.outputs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  
  network_configuration {
    subnets         = data.terraform_remote_state.foundation.outputs.public_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }
  
  # Optional service discovery integration
  service_registries {
    registry_arn = aws_service_discovery_service.app.arn
  }
  
  lifecycle {
    ignore_changes = [
      task_definition, # Allow external updates to task definition
      desired_count    # Allow manual scaling without Terraform reverting it
    ]
  }
  
  tags = merge(local.common_tags, {
    Name        = "${var.app_name}-service"
    Application = var.app_name
  })
}

# Service Discovery - register service in the foundation namespace
resource "aws_service_discovery_service" "app" {
  name = var.app_name
  
  dns_config {
    namespace_id = data.terraform_remote_state.foundation.outputs.service_discovery_namespace_id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = merge(local.common_tags, {
    Name        = "${var.app_name}-discovery"
    Application = var.app_name
  })
}