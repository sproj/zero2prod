output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.app_service.name
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.app_task.arn
}

output "security_group_id" {
  description = "The ID of the security group for the Fargate tasks"
  value       = aws_security_group.app_sg.id
}

output "public_ip_command" {
  description = "Command to get the public IP of the running task"
  value       = "aws ecs list-tasks --cluster ${data.terraform_remote_state.foundation.outputs.ecs_cluster_name} --service-name ${aws_ecs_service.app_service.name} --query 'taskArns[0]' --output text | xargs -I {} aws ecs describe-tasks --cluster ${data.terraform_remote_state.foundation.outputs.ecs_cluster_name} --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text"
}

# Output application URL (if you add an ALB later)
# output "app_url" {
#   description = "The URL of the application (if ALB is enabled)"
#   value       = var.create_alb ? aws_lb.app_lb[0].dns_name : "No ALB created"
# }