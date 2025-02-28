output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Output private subnet IDs for resources that don't need public internet access
output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "common_security_group_id" {
  description = "The ID of the common security group"
  value       = aws_security_group.common.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}
