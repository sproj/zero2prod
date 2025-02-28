provider "aws" {
  region  = var.aws_region
  profile = "fargate-deployer"
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

# Use foundation layer outputs
locals {
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids          = data.terraform_remote_state.foundation.outputs.public_subnet_ids
  app_security_group_id = data.terraform_remote_state.foundation.outputs.app_security_group_id
}