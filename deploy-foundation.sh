#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-dev}
echo "Starting deployment of foundation infrastructure for environment: $ENVIRONMENT"

# Check if AWS CLI is configured properly
if ! aws sts get-caller-identity --profile infrastructure-admin &>/dev/null; then
    echo "Error: AWS CLI is not configured correctly with the infrastructure-admin profile."
    exit 1
fi

# Navigate to Terraform foundation directory
cd terraform/foundation

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate the Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan the deployment
echo "Planning foundation deployment..."
terraform plan -var-file="../environments/$ENVIRONMENT/foundation.tfvars" -out=tfplan

# Ask for confirmation before applying
read -p "Do you want to apply these foundation changes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Foundation deployment canceled."
    exit 0
fi

# Apply the Terraform plan
echo "Applying foundation Terraform configuration..."
terraform apply tfplan

echo "Foundation infrastructure deployment complete!"