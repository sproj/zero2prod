output "service_status" {
  description = "Status of the ECS service after scaling to zero"
  value       = "Scaled down to 0 tasks - infrastructure preserved"
}

output "service_name" {
  description = "The name of the ECS service that was scaled down"
  value       = data.terraform_remote_state.application.outputs.service_name
}

output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = data.terraform_remote_state.foundation.outputs.ecs_cluster_name
}