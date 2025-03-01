#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-production}
echo "Starting warm shutdown for environment: $ENVIRONMENT"

# Check if AWS CLI is configured properly
if ! aws sts get-caller-identity --profile fargate-deployer &>/dev/null; then
    echo "Error: AWS CLI is not configured correctly with the fargate-deployer profile."
    exit 1
fi

# Navigate to Terraform warm-shutdown directory
cd terraform/warm-shutdown

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate the Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan the deployment
echo "Planning warm shutdown..."
terraform plan -var="environment=$ENVIRONMENT" -out=tfplan

# Ask for confirmation before applying
read -p "Do you want to scale down the service to 0? This will stop all running containers but keep the infrastructure. (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Warm shutdown canceled."
    exit 0
fi

# Apply the Terraform plan
echo "Applying warm shutdown Terraform configuration..."
terraform apply tfplan

echo "Warm shutdown complete! The service has been scaled to 0 tasks."
echo "All infrastructure is preserved and can be scaled back up using the warm-startup.sh script."