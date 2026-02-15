#!/bin/bash
###############################################################################
#  Database Restore Script                                                    #
#  Restores Matrix PostgreSQL database from backup                           #
#  Usage: ./restore-database.sh <backup-file>                                #
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠️  $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ❌ $1"
    exit 1
}

# Check arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <backup-file>"
    echo ""
    echo "Examples:"
    echo "  $0 backups/synapse_db_20260216_030001.sql.gz.gpg"
    echo "  $0 backups/synapse_db_20260216_030001.sql.gz"
    echo ""
    echo "Available backups:"
    ls -lh backups/synapse_db_*.sql.gz* 2>/dev/null || echo "  No backups found in backups/"
    exit 1
fi

BACKUP_FILE="$1"

# Validate backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    error "Backup file not found: $BACKUP_FILE"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Display warning
echo ""
echo "════════════════════════════════════════════════════════════"
echo "⚠️  DATABASE RESTORE WARNING"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "This will:"
echo "  1. Stop Synapse services"
echo "  2. Drop existing database"
echo "  3. Restore from: $(basename "$BACKUP_FILE")"
echo "  4. Restart Synapse services"
echo ""
echo "Data loss:"
echo "  - All changes after backup timestamp will be LOST"
echo "  - Current database will be REPLACED"
echo ""
echo "Safety:"
echo "  - A safety backup will be created first"
echo "  - Stored at: /tmp/pre-restore-backup-$(date +%Y%m%d_%H%M%S).sql.gz"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

read -p "Continue with restore? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
log "🔄 Starting database restore..."
log "Backup file: $BACKUP_FILE"
echo ""

# Step 1: Stop Synapse
log "⏸️  Stopping Synapse services..."
docker compose stop synapse synapse-worker-generic synapse-worker-media synapse-worker-federation-sender 2>/dev/null || warn "Some workers may not be running"

# Step 2: Prepare backup
log "📦 Preparing backup..."
TEMP_SQL="/tmp/restore-$(date +%Y%m%d_%H%M%S).sql"

if [[ "$BACKUP_FILE" == *.gpg ]]; then
    log "🔓 Decrypting with GPG..."
    if ! gpg --decrypt "$BACKUP_FILE" 2>/dev/null | gunzip > "$TEMP_SQL"; then
        error "Failed to decrypt backup. Check GPG key."
    fi
elif [[ "$BACKUP_FILE" == *.gz ]]; then
    log "📂 Extracting gzip..."
    if ! gunzip -c "$BACKUP_FILE" > "$TEMP_SQL"; then
        error "Failed to extract backup."
    fi
else
    error "Unsupported backup format. Use .sql.gz or .sql.gz.gpg"
fi

BACKUP_SIZE=$(du -h "$TEMP_SQL" | cut -f1)
log "Extracted backup size: $BACKUP_SIZE"

# Step 3: Create safety backup
SAFETY_BACKUP="/tmp/pre-restore-backup-$(date +%Y%m%d_%H%M%S).sql.gz"
log "💾 Creating safety backup..."
log "Location: $SAFETY_BACKUP"

if docker exec matrix-postgres pg_dump -U synapse synapse 2>/dev/null | gzip > "$SAFETY_BACKUP"; then
    SAFETY_SIZE=$(du -h "$SAFETY_BACKUP" | cut -f1)
    log "Safety backup created: $SAFETY_SIZE"
else
    warn "Failed to create safety backup (database may not exist yet)"
fi

# Step 4: Terminate active connections
log "🔌 Terminating active database connections..."
docker exec matrix-postgres psql -U synapse postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='synapse' AND pid <> pg_backend_pid();" 2>/dev/null || true

# Wait a moment for connections to close
sleep 2

# Step 5: Drop existing database (connect to postgres db, not synapse)
log "🗑️  Dropping existing database..."
if ! docker exec matrix-postgres psql -U synapse postgres -c "DROP DATABASE IF EXISTS synapse;" 2>/dev/null; then
    error "Failed to drop database. Check for active connections: docker exec matrix-postgres psql -U synapse postgres -c \"SELECT * FROM pg_stat_activity WHERE datname='synapse';\""
fi

# Step 6: Create new database
log "🆕 Creating new database..."
if ! docker exec matrix-postgres psql -U synapse postgres -c "CREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0;" 2>/dev/null; then
    error "Failed to create database"
fi

# Step 7: Restore database
log "📥 Restoring database (this may take several minutes)..."
START_TIME=$(date +%s)

if docker exec -i matrix-postgres psql -U synapse synapse < "$TEMP_SQL" 2>&1 | grep -v "^$"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log "Restore completed in ${DURATION} seconds"
else
    error "Failed to restore database"
fi

# Step 8: Cleanup temporary file
log "🧹 Cleaning up temporary files..."
rm -f "$TEMP_SQL"

# Step 9: Restart Synapse
log "▶️  Starting Synapse services..."
docker compose start synapse synapse-worker-generic synapse-worker-media synapse-worker-federation-sender

# Step 10: Wait for startup
log "⏳ Waiting for Synapse to start (10 seconds)..."
sleep 10

# Step 11: Verify restoration
log "✅ Verifying restoration..."
echo ""

# Check user count
USER_COUNT=$(docker exec matrix-postgres psql -U synapse synapse -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')
log "Users in database: $USER_COUNT"

# Check room count
ROOM_COUNT=$(docker exec matrix-postgres psql -U synapse synapse -t -c "SELECT COUNT(*) FROM rooms;" 2>/dev/null | tr -d ' ')
log "Rooms in database: $ROOM_COUNT"

# Check database size
DB_SIZE=$(docker exec matrix-postgres psql -U synapse -t -c "SELECT pg_size_pretty(pg_database_size('synapse'));" 2>/dev/null | tr -d ' ')
log "Database size: $DB_SIZE"

# Check Synapse health
echo ""
log "🏥 Checking Synapse health..."
sleep 5

if curl -s http://localhost:8008/health 2>/dev/null | grep -q "OK"; then
    log "✅ Synapse health check: OK"
else
    warn "Synapse health check failed. Check logs: docker logs matrix-synapse"
fi

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Database restore complete!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Restore Summary:"
echo "  Backup file:    $(basename "$BACKUP_FILE")"
echo "  Users:          $USER_COUNT"
echo "  Rooms:          $ROOM_COUNT"
echo "  Database size:  $DB_SIZE"
echo "  Duration:       ${DURATION}s"
echo ""
echo "📁 Safety backup: $SAFETY_BACKUP"
echo "   Keep this file for 24 hours in case of issues"
echo ""
echo "📋 Next steps:"
echo "  1. Check Synapse logs: docker logs -f matrix-synapse"
echo "  2. Test login: https://element.two.web.id"
echo "  3. Verify federation: curl https://two.web.id/_matrix/federation/v1/version"
echo "  4. Monitor for 24 hours"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
