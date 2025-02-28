output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.app_cluster.name
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.app_service.name
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.app_task.arn
}

output "public_ip_command" {
  description = "Command to get the public IP of the running task"
  value       = "aws ecs list-tasks --cluster ${aws_ecs_cluster.app_cluster.name} --service-name ${aws_ecs_service.app_service.name} --query 'taskArns[0]' --output text | xargs -I {} aws ecs describe-tasks --cluster ${aws_ecs_cluster.app_cluster.name} --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text"
}