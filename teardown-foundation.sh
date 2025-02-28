#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-production}
echo "Preparing to tear down foundation infrastructure for environment: $ENVIRONMENT"

# Check if AWS CLI is configured properly
if ! aws sts get-caller-identity --profile infrastructure-admin &>/dev/null; then
    echo "Error: AWS CLI is not configured correctly with the infrastructure-admin profile."
    exit 1
fi

# Navigate to Terraform foundation directory
cd terraform/foundation

# check if later has been deployed before attempting teardown
if [ ! -f .terraform/terraform.tfstate ]; then
  echo "No Terraform state found. Has this layer been deployed?"
  exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create a destroy plan
echo "Creating foundation destroy plan..."
terraform plan -destroy -var-file="../environments/$ENVIRONMENT/foundation.tfvars" -out=destroy.tfplan

# Ask for confirmation before destroying
echo "ATTENTION: This will destroy ALL foundation infrastructure for the $ENVIRONMENT environment."
echo "This includes VPC, subnets, and other network resources that may be used by other applications."
read -p "Are you ABSOLUTELY SURE you want to destroy these resources? (Type 'yes-destroy-foundation' to confirm) " -r
echo
if [[ ! $REPLY == "yes-destroy-foundation" ]]; then
    echo "Foundation teardown canceled."
    exit 0
fi

# Perform the destroy operation
echo "Beginning teardown of foundation infrastructure..."
terraform apply destroy.tfplan

echo "Foundation teardown complete! All resources have been destroyed."