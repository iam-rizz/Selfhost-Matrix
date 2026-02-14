#!/bin/bash
###############################################################################
#  Offsite Backup with rclone                                                 #
#  Uploads encrypted backups to remote storage (S3, B2, Wasabi, etc.)         #
#  Requires: rclone configured with a remote named 'offsite'                  #
#  Cron: 0 4 * * * /path/to/scripts/offsite-backup.sh                        #
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

BACKUP_DIR="$PROJECT_DIR/backups"
REMOTE_NAME="${RCLONE_REMOTE:-offsite}"
REMOTE_PATH="${RCLONE_PATH:-matrix-backup}"

# Check if rclone is configured
if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    echo "[$(date)] ERROR: rclone remote '${REMOTE_NAME}' not configured"
    echo "[$(date)] Run: rclone config"
    exit 1
fi

echo "[$(date)] Starting offsite backup upload..."

# Upload all backup files
UPLOADED=0
FAILED=0

for file in "$BACKUP_DIR"/synapse_db_*.{sql.gz,sql.gz.gpg} 2>/dev/null; do
    if [[ -f "$file" ]]; then
        echo "[$(date)] Uploading $(basename "$file")..."
        if rclone copy "$file" "${REMOTE_NAME}:${REMOTE_PATH}/" --transfers=4 --progress; then
            ((UPLOADED++))
        else
            ((FAILED++))
        fi
    fi
done

echo "[$(date)] Upload complete: $UPLOADED files uploaded, $FAILED failed"

# Send Telegram notification
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    STATUS_EMOJI="✅"
    [[ $FAILED -gt 0 ]] && STATUS_EMOJI="⚠️"
    
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=${STATUS_EMOJI} <b>Offsite Backup Complete</b>
📤 Uploaded: <code>${UPLOADED}</code> file(s)
❌ Failed: <code>${FAILED}</code>
📍 Remote: <code>${REMOTE_NAME}:${REMOTE_PATH}</code>
🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null
fi
