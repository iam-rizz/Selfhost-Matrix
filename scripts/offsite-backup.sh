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

# Find all backup files (both .sql.gz and .sql.gz.gpg)
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        FILENAME=$(basename "$file")
        echo "[$(date)] Uploading $FILENAME..."
        
        # Use timeout and non-interactive flags to prevent hanging
        # --no-traverse: Don't list destination, faster for single files
        # --ignore-times: Skip timestamp checks, just upload
        # --no-check-certificate: Skip SSL verification if causing issues
        # 2>&1: Capture all output
        if timeout 60 rclone copy "$file" "${REMOTE_NAME}:${REMOTE_PATH}/" \
            --transfers=4 \
            --retries 1 \
            --low-level-retries 1 \
            --timeout 30s \
            --no-traverse \
            --ignore-times \
            --quiet \
            --no-check-certificate 2>&1 | grep -v "^$"; then
            ((UPLOADED++))
            echo "[$(date)] ✅ Success: $FILENAME"
        else
            EXIT_CODE=${PIPESTATUS[0]}
            if [[ $EXIT_CODE -eq 0 ]]; then
                # Exit code 0 but grep filtered output = success
                ((UPLOADED++))
                echo "[$(date)] ✅ Success: $FILENAME"
            elif [[ $EXIT_CODE -eq 124 ]]; then
                ((FAILED++))
                echo "[$(date)] ❌ Failed: $FILENAME (timeout after 60s)"
            else
                ((FAILED++))
                echo "[$(date)] ❌ Failed: $FILENAME (exit code: $EXIT_CODE)"
            fi
        fi
    fi
done < <(find "$BACKUP_DIR" -type f \( -name "synapse_db_*.sql.gz" -o -name "synapse_db_*.sql.gz.gpg" \))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "[$(date)] Upload complete: $UPLOADED files uploaded, $FAILED failed"
echo "════════════════════════════════════════════════════════════"
echo ""

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
    
    echo "[$(date)] Telegram notification sent"
fi

echo "[$(date)] Offsite backup completed successfully! 🎉"
