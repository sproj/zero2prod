# ECS Task Definition with PostgreSQL container and app container
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.environment}-${var.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = data.terraform_remote_state.foundation.outputs.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.app_task_role.arn
  
  # Container definitions containing both application and PostgreSQL
  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-container"
      image     = "${var.ecr_repository_url}:latest"
      essential = true
      
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      
      environment = [
        {
          name  = "APP_ENVIRONMENT"
          value = "production"
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://app:dummy_placeholder@localhost:5432/newsletter"
        }
      ]
      
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/${var.app_name}/DB_PASSWORD"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.terraform_remote_state.foundation.outputs.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs/${var.app_name}"
        }
      }
      
      dependsOn = [
        {
          containerName = "postgres-container"
          condition     = "START"
        }
      ]
    },
    {
      name      = "postgres-container"
      image     = "postgres:14"
      essential = true
      
      portMappings = [{
        containerPort = 5432
        hostPort      = 5432
        protocol      = "tcp"
      }]
      
      environment = [
        {
          name  = "POSTGRES_USER"
          value = "app"
        },
        {
          name  = "POSTGRES_DB"
          value = "newsletter"
        },
        {
          # Store data in the correct location for the EFS mount
          name  = "PGDATA"
          value = "/var/lib/postgresql/data/pgdata"
        }
      ]
      
      secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/${var.app_name}/DB_PASSWORD"
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "postgres-data"
          containerPath = "/var/lib/postgresql/data"
          readOnly      = false
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.terraform_remote_state.foundation.outputs.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs/postgres"
        }
      }
    }
  ])
  
  # EFS volume for PostgreSQL data
  volume {
    name = "postgres-data"
    
    efs_volume_configuration {
      file_system_id     = data.terraform_remote_state.foundation.outputs.efs_filesystem_id
      transit_encryption = "ENABLED"
      
      authorization_config {
        access_point_id = data.terraform_remote_state.foundation.outputs.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }
  
  tags = merge(local.common_tags, {
    Name        = "${var.app_name}-task-definition"
    Application = var.app_name
  })
}

# IAM role for the ECS task
resource "aws_iam_role" "app_task_role" {
  name = "${var.environment}-${var.app_name}-task-role"
  
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
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-${var.app_name}-task-role"
    Application = var.app_name
  })
}

# Policy to allow the task to access EFS
resource "aws_iam_policy" "efs_access_policy" {
  name        = "${var.environment}-${var.app_name}-efs-access"
  description = "Allow ECS tasks to access EFS file systems"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = data.terraform_remote_state.foundation.outputs.efs_filesystem_id
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn": data.terraform_remote_state.foundation.outputs.efs_access_point_id
          }
        }
      }
    ]
  })
}

# Attach EFS policy to the task role
resource "aws_iam_role_policy_attachment" "efs_access_attachment" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = aws_iam_policy.efs_access_policy.arn
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