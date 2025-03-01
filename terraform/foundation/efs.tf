# EFS File System for PostgreSQL data persistence
resource "aws_efs_file_system" "postgres_data" {
  creation_token = "${var.environment}"
}

# Add backup for the EFS file system
resource "aws_backup_selection" "postgres_efs_backup" {
  count        = var.create_backups ? 1 : 0
  name         = "${var.environment}-postgres-efs-backup"
  iam_role_arn = aws_iam_role.backup_role[0].arn
  plan_id      = aws_backup_plan.app_backup[0].id
  
  resources = [
    aws_efs_file_system.postgres_data.arn
  ]
}

# Create a backup plan if enabled
resource "aws_backup_plan" "app_backup" {
  count = var.create_backups ? 1 : 0
  name  = "${var.environment}-${var.app_name}-backup-plan"
  
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.app_backup[0].name
    schedule          = "cron(0 0 * * ? *)"  # Daily at midnight UTC
    
    lifecycle {
      delete_after = 30  # Keep backups for 30 days
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.app_name}-backup-plan"
  })
}

resource "aws_backup_vault" "app_backup" {
  count = var.create_backups ? 1 : 0
  name  = "${var.environment}-${var.app_name}-backup-vault"
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.app_name}-backup-vault"
  })
}

resource "aws_iam_role" "backup_role" {
  count = var.create_backups ? 1 : 0
  name  = "${var.environment}-backup-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-backup-role"
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_policy" {
  count      = var.create_backups ? 1 : 0
  role       = aws_iam_role.backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Add outputs for EFS resources
output "efs_filesystem_id" {
  description = "The ID of the EFS file system for postgres data"
  value       = aws_efs_file_system.postgres_data.id
}

output "efs_access_point_id" {
  description = "The ID of the EFS access point for postgres data"
  value       = aws_efs_access_point.postgres_data.id
}

output "efs_security_group_id" {
  description = "The ID of the security group for EFS access"
  value       = aws_security_group.efs_sg.id
}-${var.app_name}-postgres-data"
  encrypted      = true
  
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.app_name}-postgres-data"
  })
}

# Security group for EFS access
resource "aws_security_group" "efs_sg" {
  name        = "${var.environment}-efs-sg"
  description = "Allow EFS access from application containers"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
    description     = "Allow NFS traffic from application security group"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-efs-sg"
  })
}

# Mount targets in each subnet to provide access to the EFS file system
resource "aws_efs_mount_target" "postgres_data" {
  count           = length(var.availability_zones)
  file_system_id  = aws_efs_file_system.postgres_data.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# Access point for PostgreSQL data to provide isolation and proper permissions
resource "aws_efs_access_point" "postgres_data" {
  file_system_id = aws_efs_file_system.postgres_data.id
  
  posix_user {
    gid = 999  # postgres group ID in default Docker postgres image
    uid = 999  # postgres user ID in default Docker postgres image
  }
  
  root_directory {
    path = "/postgres_data"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "700"
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.app_name}-postgres-access-point"
  })
}

# Create more restrictive backup policies for the EFS access point
resource "aws_efs_file_system_policy" "postgres_data" {
  file_system_id = aws_efs_file_system.postgres_data.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowAccessFromECS"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = aws_efs_file_system.postgres_data.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalArn": aws_iam_role.ecs_task_execution_role.arn
          }
        }
      }
    ]
  })
}