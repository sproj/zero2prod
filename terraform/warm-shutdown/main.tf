provider "aws" {
  region  = var.aws_region
  profile = "fargate-deployer"
}

# Retrieve application layer outputs
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket = "zero2prod-terraform-state"
    key    = "application/terraform.tfstate"
    region = var.aws_region
  }
}

# Retrieve foundation layer outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "zero2prod-terraform-state"
    key    = "foundation/terraform.tfstate"
    region = var.aws_region
  }
}

# Scale down the service to zero using a null_resource
resource "null_resource" "scale_service" {
  triggers = {
    service_name = data.terraform_remote_state.application.outputs.service_name
    cluster_name = data.terraform_remote_state.foundation.outputs.ecs_cluster_name
  }

  provisioner "local-exec" {
    command = "aws ecs update-service --cluster ${data.terraform_remote_state.foundation.outputs.ecs_cluster_name} --service ${data.terraform_remote_state.application.outputs.service_name} --desired-count 0 --profile fargate-deployer"
  }
}