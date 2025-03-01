#!/bin/bash
set -e

# Replace the dummy placeholder with the actual password from environment variables
if [ -n "$DATABASE_PASSWORD" ]; then
  export DATABASE_URL=$(echo $DATABASE_URL | sed "s/dummy_placeholder/${DATABASE_PASSWORD}/")
  echo "Database connection string has been configured"
else
  echo "WARNING: DATABASE_PASSWORD environment variable is not set"
fi

# Wait for PostgreSQL to be ready before starting the application
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h localhost -U app -d newsletter -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is up and running!"

# Check if the database schema is initialized
TABLES=$(PGPASSWORD=$DATABASE_PASSWORD psql -h localhost -U app -d newsletter -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
if [ "$TABLES" -eq "0" ]; then
  echo "Database is empty, running migrations..."
  
  # Run migrations using sqlx CLI
  sqlx migrate run
  
  echo "Migrations completed successfully!"
fi

# Start the application
echo "Starting the application..."
exec "$@"