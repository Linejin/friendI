#!/bin/bash
set -e

# Create database and user if not exists
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create extension for UUID generation if needed
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Create additional schemas if needed
    CREATE SCHEMA IF NOT EXISTS audit;
    
    -- Grant permissions
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA public TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA audit TO $POSTGRES_USER;
    
    -- Create audit table for tracking changes (optional)
    CREATE TABLE IF NOT EXISTS audit.audit_log (
        id SERIAL PRIMARY KEY,
        table_name VARCHAR(255),
        operation VARCHAR(10),
        old_data JSONB,
        new_data JSONB,
        changed_by VARCHAR(255),
        changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
EOSQL

echo "Database initialization completed successfully!"