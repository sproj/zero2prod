#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-dev}
echo "Starting deployment of application infrastructure for environment: $ENVIRONMENT"

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

# Validate the Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan the deployment
echo "Planning application deployment..."
terraform plan -var-file="../environments/$ENVIRONMENT/application.tfvars" -out=tfplan

# Ask for confirmation before applying
read -p "Do you want to apply these application changes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Application deployment canceled."
    exit 0
fi

# Apply the Terraform plan
echo "Applying application Terraform configuration..."
terraform apply tfplan

# Wait for services to be ready
echo "Waiting for ECS service to become stable (this may take a few minutes)..."
sleep 30

# Get the public IP of the running task
echo "Retrieving the public IP address of your application..."
eval $(terraform output -raw public_ip_command)

echo "Application deployment complete!"
echo "You can now access your application at http://$(terraform output -raw public_ip):8000"
echo "To test the health check endpoint: curl http://$(terraform output -raw public_ip):8000/health_check"