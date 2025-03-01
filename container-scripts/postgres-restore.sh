#!/bin/bash
set -e

# This script restores a PostgreSQL database from a backup file

# Help message
function show_help {
  echo "Usage: $0 -f [backup file] [-u database user] [-d database name]"
  echo
  echo "Options:"
  echo "  -f  Backup file to restore (required)"
  echo "  -u  Database user (default: app)"
  echo "  -d  Database name (default: newsletter)"
  echo "  -h  Show this help message"
  echo
  echo "Example:"
  echo "  $0 -f /var/lib/postgresql/backups/newsletter_20250301_120000.sql.gz -u app -d newsletter"
}

# Default values
DB_USER="app"
DB_NAME="newsletter"
BACKUP_FILE=""

# Parse command line options
while getopts "f:u:d:h" opt; do
  case $opt in
    f) BACKUP_FILE="$OPTARG" ;;
    u) DB_USER="$OPTARG" ;;
    d) DB_NAME="$OPTARG" ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done

# Check if backup file is provided
if [ -z "$BACKUP_FILE" ]; then
  echo "Error: Backup file is required"
  show_help
  exit 1
fi

# Check if the backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file does not exist: $BACKUP_FILE"
  exit 1
fi

# Confirm the restoration (this will overwrite the existing database)
echo "WARNING: This will OVERWRITE the existing database ($DB_NAME) with the backup."
echo "Are you sure you want to continue? (yes/no)"
read -r confirmation

if [ "$confirmation" != "yes" ]; then
  echo "Restoration aborted."
  exit 0
fi

# Create a temporary database for restoration to avoid conflicts
TEMP_DB="${DB_NAME}_restore_temp"

echo "Creating temporary database for restoration: $TEMP_DB"
createdb -U $DB_USER $TEMP_DB

# Restore the backup to the temporary database
echo "Restoring backup to temporary database..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
  # For gzipped backups
  gunzip -c "$BACKUP_FILE" | psql -U $DB_USER -d $TEMP_DB
else
  # For uncompressed backups
  psql -U $DB_USER -d $TEMP_DB -f "$BACKUP_FILE"
fi

# Check if restoration was successful
if [ $? -ne 0 ]; then
  echo "Error: Restoration to temporary database failed."
  echo "Cleaning up temporary database..."
  dropdb -U $DB_USER $TEMP_DB
  exit 1
fi

# Rename databases to complete the restoration
echo "Restoration to temporary database successful."
echo "Replacing the current database with the restored one..."

# Disconnect all users from the original database
psql -U $DB_USER -d postgres -c "
  SELECT pg_terminate_backend(pg_stat_activity.pid)
  FROM pg_stat_activity
  WHERE pg_stat_activity.datname IN ('$DB_NAME', '$TEMP_DB')
    AND pid <> pg_backend_pid();
"

# Rename the original database to a backup name
OLD_DB="${DB_NAME}_pre_restore_$(date +%Y%m%d_%H%M%S)"
echo "Renaming current database to: $OLD_DB"
psql -U $DB_USER -d postgres -c "ALTER DATABASE \"$DB_NAME\" RENAME TO \"$OLD_DB\";"

# Rename the temporary database to the original name
echo "Renaming restored database to: $DB_NAME"
psql -U $DB_USER -d postgres -c "ALTER DATABASE \"$TEMP_DB\" RENAME TO \"$DB_NAME\";"

echo "Restoration completed successfully!"
echo "Your previous database has been renamed to: $OLD_DB"
echo "You may verify the restoration and then drop the old database with:"
echo "  dropdb -U $DB_USER $OLD_DB"