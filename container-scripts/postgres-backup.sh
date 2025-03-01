#!/bin/bash
set -e

# This script can be used manually or through a cron job to backup the PostgreSQL database

# Get environment variables or use defaults
DB_USER=${POSTGRES_USER:-app}
DB_NAME=${POSTGRES_DB:-newsletter}
BACKUP_DIR=${BACKUP_DIR:-/var/lib/postgresql/backups}
S3_BUCKET=${S3_BUCKET:-""}  # Optional S3 bucket for remote backup

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Generate timestamp for the backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

# Perform the backup
echo "Creating backup of $DB_NAME database..."
pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_FILE

echo "Backup created: $BACKUP_FILE"

# Upload to S3 if a bucket is specified
if [ -n "$S3_BUCKET" ]; then
  echo "Uploading backup to S3..."
  aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/database-backups/
  
  if [ $? -eq 0 ]; then
    echo "Backup successfully uploaded to S3"
    
    # Optionally remove local file after S3 upload
    if [ "${REMOVE_LOCAL_AFTER_UPLOAD:-false}" = "true" ]; then
      rm $BACKUP_FILE
      echo "Local backup file removed"
    fi
  else
    echo "Failed to upload backup to S3"
  fi
fi

# Clean up old backups (keep last 7 days)
if [ "${CLEANUP_OLD_BACKUPS:-true}" = "true" ]; then
  echo "Cleaning up old backups..."
  find $BACKUP_DIR -name "${DB_NAME}_*.sql.gz" -type f -mtime +7 -delete
  echo "Old backups cleaned up"
fi

echo "Backup process completed"