#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

ENVIRONMENT=${1:-production}
DESIRED_COUNT=${2:-1}
echo "Starting warm startup for environment: $ENVIRONMENT with desired count: $DESIRED_COUNT"

# Check if AWS CLI is configured properly
if ! aws sts get-caller-identity --profile fargate-deployer &>/dev/null; then
    echo "Error: AWS CLI is not configured correctly with the fargate-deployer profile."
    exit 1
fi

# Get the ECS cluster and service name from the application state
cd terraform/application
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform output -raw service_name 2>/dev/null || echo "")

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
    echo "Could not determine cluster or service name from application state."
    echo "Trying foundation and warm-shutdown state..."
    
    cd ../foundation
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    
    cd ../warm-shutdown
    SERVICE_NAME=$(terraform output -raw service_name 2>/dev/null || echo "")
    
    if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
        echo "Error: Could not determine cluster or service name. Please check your Terraform state."
        exit 1
    fi
fi

# Ask for confirmation before scaling up
read -p "Do you want to scale up the service to $DESIRED_COUNT task(s)? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Warm startup canceled."
    exit 0
fi

# Scale up the service using AWS CLI
echo "Scaling up ECS service..."
aws ecs update-service \
    --profile fargate-deployer \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count "$DESIRED_COUNT"

echo "Warm startup initiated! The service is being scaled to $DESIRED_COUNT task(s)."
echo "To check the status, run: aws ecs describe-services --profile fargate-deployer --cluster $CLUSTER_NAME --services $SERVICE_NAME"

# Wait for service to be stable
echo "Waiting for service to stabilize..."
aws ecs wait services-stable \
    --profile fargate-deployer \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME"

echo "Service is now stable with $DESIRED_COUNT task(s) running."

# Get the public IP of the running task if desired count > 0
if [ "$DESIRED_COUNT" -gt 0 ]; then
    echo "Retrieving the public IP address of your application..."
    
    cd ../application
    if terraform output -raw public_ip_command &>/dev/null; then
        public_ip_cmd=$(terraform output -raw public_ip_command)
        public_ip=$(eval $public_ip_cmd)
        echo "Application is running at: http://${public_ip}:8000"
        echo "To test the health check endpoint: curl http://${public_ip}:8000/health_check"
    else
        echo "Public IP command not available in terraform outputs."
    fi
fi