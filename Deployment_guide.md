# Deployment Guide: Zero2Prod with Containerized PostgreSQL on AWS

This guide outlines the process for deploying the Zero2Prod application with a containerized PostgreSQL database on AWS ECS Fargate, using EFS for database persistence.

## Overview

Our deployment architecture consists of:

1. **Application Container**: Runs the Zero2Prod Rust application
2. **PostgreSQL Container**: Runs alongside the application in the same task
3. **EFS Volume**: Provides persistent storage for PostgreSQL data
4. **Parameter Store**: Manages secrets like database passwords

This architecture is designed to be cost-effective by only incurring compute costs when the application is running, while maintaining data persistence.

## Prerequisites

- AWS CLI configured with appropriate profiles
- Terraform installed
- Docker installed
- ECR repository created for the application image

## Deployment Process

### 1. Set Up Foundation Infrastructure

The foundation layer contains the networking, EFS, and IAM resources needed by all environments.

```bash
# Add backup variable to foundation/variables.tf
echo 'variable "create_backups" {
  description = "Whether to create AWS Backup plans for resources"
  type        = bool
  default     = false
}' >> terraform/foundation/variables.tf

# Deploy foundation infrastructure
./deploy-foundation.sh production
```

### 2. Build and Push Docker Image

```bash
# Build the Docker image
docker build -t zero2prod:latest .

# Tag and push to ECR
aws ecr get-login-password --profile fargate-deployer | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<region>.amazonaws.com
docker tag zero2prod:latest <your-account-id>.dkr.ecr.<region>.amazonaws.com/learning/zero2prod:latest
docker push <your-account-id>.dkr.ecr.<region>.amazonaws.com/learning/zero2prod:latest
```

### 3. Update Terraform Variables

Create or update the `terraform/environments/production/application.tfvars` file:

```hcl
aws_region        = "eu-west-1"
environment       = "production"
app_name          = "zero2prod"
ecr_repository_url = "<your-account-id>.dkr.ecr.<region>.amazonaws.com/zero2prod"
container_port    = 8000
desired_count     = 1
cpu               = 512
memory            = 1024
your_ip           = "<your-ip-address>/32"  # For security group access
```

### 4. Deploy Application Infrastructure

```bash
./deploy-application.sh production
```

### 5. Access and Test the Application

After deployment completes, you'll see the public IP address of your application in the output:

```
Application is running at: http://<public-ip>:8000
To test the health check endpoint: curl http://<public-ip>:8000/health_check
```

## Warm Shutdown and Startup

When you're not actively using the application, you can shut it down to save costs:

```bash
# Shutdown
./warm-shutdown.sh production

# Startup when needed
./warm-startup.sh production 1
```

## Database Management

### Backup Database

```bash
# Connect to the running container
TASK_ID=$(aws ecs list-tasks --cluster <cluster-name> --service-name <service-name> --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster <cluster-name> --task $TASK_ID --container postgres-container --interactive --command "/bin/bash"

# Once connected, run the backup script
./postgres-backup.sh
```

### Restore Database

```bash
# Connect to the running container
TASK_ID=$(aws ecs list-tasks --cluster <cluster-name> --service-name <service-name> --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster <cluster-name> --task $TASK_ID --container postgres-container --interactive --command "/bin/bash"

# Once connected, run the restore script
./postgres-restore.sh -f /var/lib/postgresql/backups/<backup-file>.sql.gz
```

## Cost Management

This deployment is designed to minimize costs:

1. **Compute costs** only occur when the application is running
2. **Storage costs** for EFS are based on actual usage
3. **Parameter Store** standard tier is free
4. **Backups** can be configured as needed

Estimated monthly costs when not running: ~$0.30 for 1GB of EFS storage
Estimated costs for 40 hours of usage per month: ~$1.12 total

## Troubleshooting

### Database Connection Issues

If the application can't connect to the database:

1. Check that both containers are running:
   ```bash
   aws ecs describe-tasks --cluster <cluster-name> --tasks <task-id>
   ```

2. Check container logs:
   ```bash
   aws logs get-log-events --log-group-name <log-group> --log-stream-name <log-stream>
   ```

3. Verify EFS mount is working:
   ```bash
   # Connect to container
   aws ecs execute-command --cluster <cluster-name> --task <task-id> --container postgres-container --interactive --command "/bin/bash"
   
   # Check mount
   df -h
   ```

### Database Migration Failures

If database migrations fail during startup:

1. Check application logs for specific migration errors
2. Connect to the PostgreSQL container and verify database structure:
   ```bash
   psql -U app -d newsletter
   \dt
   ```

3. You may need to run migrations manually:
   ```bash
   cd /app
   sqlx migrate run
   ```

## Security Considerations

- Database password is stored securely in Parameter Store
- EFS data is encrypted at rest
- Application and database are isolated within the task network
- Security groups restrict access to the application

## Maintenance

- Regularly update the application image with security patches
- Consider enabling automated EFS backups in production
- Monitor EFS storage usage to control costs

## Cleanup

To completely remove the infrastructure:

```bash
# Remove application layer
./teardown-application.sh production

# Remove foundation layer
./teardown-foundation.sh production
```