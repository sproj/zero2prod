#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-production}
echo "Preparing to tear down application infrastructure for environment: $ENVIRONMENT"

# Check if AWS CLI is configured properly
if ! aws sts get-caller-identity --profile fargate-deployer &>/dev/null; then
    echo "Error: AWS CLI is not configured correctly with the fargate-deployer profile."
    exit 1
fi

# Navigate to Terraform application directory
cd terraform/application

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create a destroy plan
echo "Creating application destroy plan..."
terraform plan -destroy -var-file="../environments/$ENVIRONMENT/application.tfvars" -out=destroy.tfplan

# Ask for confirmation before destroying
echo "ATTENTION: This will destroy all application resources managed by Terraform for the $ENVIRONMENT environment."
read -p "Are you SURE you want to destroy these resources? (Type 'yes' to confirm) " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo "Application teardown canceled."
    exit 0
fi

# Perform the destroy operation
echo "Beginning teardown of application infrastructure..."
terraform apply destroy.tfplan

echo "Application teardown complete!"