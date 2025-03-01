# Get the AWS account ID
data "aws_caller_identity" "current" {}

# Generate a secure random password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the database password in Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.environment}/${var.app_name}/DB_PASSWORD"
  description = "Database password for ${var.app_name}"
  type        = "SecureString"
  value       = random_password.db_password.result
  
  tags = merge(local.common_tags, {
    Application = var.app_name
  })
}

# Store other application secrets as needed
resource "aws_ssm_parameter" "app_secrets" {
  for_each = {
    # Add any additional secrets your application needs
    # KEY = VALUE 
    "JWT_SECRET" = random_password.jwt_secret.result
  }
  
  name        = "/${var.environment}/${var.app_name}/${each.key}"
  description = "${each.key} for ${var.app_name}"
  type        = "SecureString"
  value       = each.value
  
  tags = merge(local.common_tags, {
    Application = var.app_name
  })
}

# Generate additional secrets
resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}