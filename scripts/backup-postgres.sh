#!/bin/bash
###############################################################################
#  PostgreSQL Backup Script                                                   #
#  Daily pg_dump → GPG-encrypted → /backups/ with retention                   #
#  Cron: 0 3 * * * /path/to/scripts/backup-postgres.sh                       #
###############################################################################

set -euo pipefail

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Config
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/synapse_db_${TIMESTAMP}.sql.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
CONTAINER_NAME="matrix-postgres"

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting PostgreSQL backup..."

# Dump database
docker exec "$CONTAINER_NAME" pg_dump \
    -U "${POSTGRES_USER:-synapse}" \
    -d "${POSTGRES_DB:-synapse}" \
    --no-owner \
    --no-privileges \
    | gzip > "$BACKUP_FILE"

# Encrypt with GPG if recipient is configured
if [[ -n "${GPG_RECIPIENT:-}" && "$GPG_RECIPIENT" != "CHANGE_ME"* ]]; then
    gpg --batch --yes --recipient "$GPG_RECIPIENT" \
        --encrypt "$BACKUP_FILE"
    rm -f "$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gpg"
    echo "[$(date)] Backup encrypted with GPG: $BACKUP_FILE"
else
    echo "[$(date)] Backup created (unencrypted): $BACKUP_FILE"
    echo "[$(date)] ⚠️  Set GPG_RECIPIENT in .env for encrypted backups"
fi

# Get file size
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup size: $BACKUP_SIZE"

# Clean old backups
DELETED=$(find "$BACKUP_DIR" -name "synapse_db_*" -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
echo "[$(date)] Cleaned $DELETED backup(s) older than ${RETENTION_DAYS} days"

# Send Telegram notification if configured
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "synapse_db_*" -type f | wc -l)
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=💾 <b>Matrix Backup Complete</b>
📦 Size: <code>${BACKUP_SIZE}</code>
📁 Total backups: <code>${TOTAL_BACKUPS}</code>
🗑️ Cleaned: <code>${DELETED}</code> old backup(s)
🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null
fi

echo "[$(date)] Backup complete!"
