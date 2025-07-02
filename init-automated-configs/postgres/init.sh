#!/bin/sh
# PostgreSQL Initialization Script
# Runs as a sidecar container after PostgreSQL is healthy

set -e

echo "🐘 PostgreSQL Initialization Starting..."

# Wait a bit to ensure PostgreSQL is fully ready
sleep 2

# Environment variables from docker-compose
PGHOST="${POSTGRES_HOST:-postgres}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-datalive}"
PGPASSWORD="${POSTGRES_PASSWORD}"
PGDATABASE="${POSTGRES_DB:-datalive}"

# Export for psql
export PGPASSWORD

echo "📋 Connecting to PostgreSQL at $PGHOST:$PGPORT as $PGUSER"

# Test connection
if ! psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "SELECT version();" > /dev/null 2>&1; then
    echo "❌ Failed to connect to PostgreSQL"
    exit 1
fi

echo "✅ PostgreSQL connection successful"

# Check if schemas already exist
SCHEMA_EXISTS=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tA -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('rag', 'cag', 'monitoring');")

if [ "$SCHEMA_EXISTS" -eq "3" ]; then
    echo "✅ Schemas already exist, skipping initialization"
else
    echo "📊 Creating DataLive schemas and tables..."
    
    # Run initialization SQL
    if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f /init/init.sql; then
        echo "✅ PostgreSQL schemas created successfully"
    else
        echo "❌ Failed to create PostgreSQL schemas"
        exit 1
    fi
fi

# Verify tables were created
echo "🔍 Verifying database structure..."

# Check RAG tables
RAG_TABLES=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tA -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'rag';")
echo "   📄 RAG tables: $RAG_TABLES"

# Check CAG tables
CAG_TABLES=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tA -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'cag';")
echo "   💾 CAG tables: $CAG_TABLES"

# Check monitoring tables
MON_TABLES=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tA -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'monitoring';")
echo "   📊 Monitoring tables: $MON_TABLES"

echo "✅ PostgreSQL initialization completed successfully"
echo "🐘 DataLive PostgreSQL is ready!"