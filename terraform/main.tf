provider "aws" {
  region = var.aws_region
  
  # If you're using named profiles, you can specify it here
  profile = "fargate-deployer"
}

# Optionally, you can setup backend configuration for state storage
# For example, using S3:
# terraform {
#   backend "s3" {
#     bucket = "your-terraform-state-bucket"
#     key    = "zero2prod/terraform.tfstate"
#     region = "us-east-1"
#   }
# }