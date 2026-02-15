#!/bin/bash

###############################################################################
#  Create syncv3 Database for Sliding Sync                                   #
#  Run this if database was not created during initial setup                 #
###############################################################################

set -e

echo "🔧 Creating syncv3 database for Sliding Sync..."

# Check if postgres container is running
if ! docker ps | grep -q matrix-postgres; then
    echo "❌ Error: matrix-postgres container is not running"
    echo "   Start it with: docker compose up -d postgres"
    exit 1
fi

# Create database
echo "Creating database..."
docker exec -it matrix-postgres psql -U synapse -c "CREATE DATABASE syncv3;" 2>/dev/null || {
    echo "⚠️  Database might already exist, checking..."
    docker exec -it matrix-postgres psql -U synapse -c "\l" | grep syncv3 && {
        echo "✅ Database syncv3 already exists"
    } || {
        echo "❌ Failed to create database"
        exit 1
    }
}

# Grant privileges
echo "Granting privileges..."
docker exec -it matrix-postgres psql -U synapse -c "GRANT ALL PRIVILEGES ON DATABASE syncv3 TO synapse;"

echo ""
echo "✅ syncv3 database created successfully!"
echo ""
echo "Now restart Sliding Sync:"
echo "  docker compose up -d sliding-sync"
echo ""
