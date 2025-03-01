# ECS Cluster - Shared foundation resource
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-${var.app_name}-cluster"
  })
}

# CloudWatch Log Group for application logs - shared foundation resource
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.environment}-${var.app_name}"
  retention_in_days = 30
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-${var.app_name}-logs"
  })
}

# Capacity Provider for Fargate
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# Optional - Service Discovery namespace for the cluster
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.${var.app_name}.local"
  description = "Service discovery namespace for ${var.environment} environment"
  vpc      = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-service-discovery"
  })
}

# Additional CloudWatch Log Group for container insights
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/ecs/containerinsights/${aws_ecs_cluster.main.name}/performance"
  retention_in_days = 30
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-container-insights"
  })
}