#!/bin/bash
set -eo pipefail

# This script initializes the PostgreSQL database and runs migrations
# It is designed to be run from within the application container

echo "Starting PostgreSQL database initialization..."

# Wait for PostgreSQL to be ready
until PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is up and ready"

# Check if the database has been initialized
INITIALIZED_FLAG="/var/lib/postgresql/data/.initialized"
if [ -f "$INITIALIZED_FLAG" ]; then
  echo "Database has already been initialized, skipping initialization"
else
  echo "Initializing database..."
  
  # Create application user if not exists
  echo "Creating application user..."
  psql -v ON_ERROR_STOP=1 -h localhost -U $POSTGRES_USER -d $POSTGRES_DB <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app') THEN
        CREATE USER app WITH PASSWORD '$POSTGRES_PASSWORD';
        GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO app;
      END IF;
    END
    \$\$;
EOSQL

  # Run the migrations
  echo "Running database migrations..."
  cd /app
  sqlx database create
  sqlx migrate run
  
  # Mark the database as initialized
  touch "$INITIALIZED_FLAG"
  
  echo "Database initialization complete"
fi

# Verify database structure
echo "Verifying database structure..."
TABLES=$(psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
echo "Database contains $TABLES tables"

echo "Database initialization process complete"