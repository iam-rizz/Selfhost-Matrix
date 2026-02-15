#!/bin/bash
###############################################################################
#  Offsite Backup with Telegram + rclone                                     #
#  1. Send backup files to Telegram (reliable, instant)                      #
#  2. Upload to cloud storage via rclone (background, async)                 #
#  Requires: Telegram bot configured, rclone optional                        #
#  Cron: 0 4 * * * /path/to/scripts/offsite-backup.sh                       #
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

echo "[$(date)] Starting offsite backup..."

# ──────────────────────────────────────────────
# Step 1: Send to Telegram (Primary backup)
# ──────────────────────────────────────────────
TELEGRAM_SENT=0
TELEGRAM_FAILED=0

if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    echo "[$(date)] Sending backups to Telegram..."
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            FILENAME=$(basename "$file")
            FILESIZE=$(du -h "$file" | cut -f1)
            
            echo "[$(date)] 📤 Sending $FILENAME ($FILESIZE)..."
            
            # Telegram has 50MB file limit
            if curl -s -X POST \
                "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
                -F "chat_id=${TELEGRAM_CHAT_ID}" \
                -F "document=@$file" \
                -F "caption=💾 Matrix Backup
📁 File: <code>$FILENAME</code>
📦 Size: <code>$FILESIZE</code>
🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" \
                -F "parse_mode=HTML" > /dev/null 2>&1; then
                ((TELEGRAM_SENT++))
                echo "[$(date)] ✅ Telegram: $FILENAME"
            else
                ((TELEGRAM_FAILED++))
                echo "[$(date)] ⚠️ Telegram failed: $FILENAME (file too large or network error)"
            fi
        fi
    done < <(find "$BACKUP_DIR" -type f \( -name "synapse_db_*.sql.gz" -o -name "synapse_db_*.sql.gz.gpg" \) -mtime -1)
    
    echo "[$(date)] Telegram: $TELEGRAM_SENT sent, $TELEGRAM_FAILED failed"
else
    echo "[$(date)] ⚠️ Telegram not configured, skipping..."
fi

# ──────────────────────────────────────────────
# Step 2: Upload to rclone (Secondary backup)
# ──────────────────────────────────────────────
RCLONE_UPLOADED=0
RCLONE_FAILED=0

# Check if rclone is configured
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
    echo "[$(date)] Uploading to rclone (${REMOTE_NAME}:${REMOTE_PATH})..."
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            FILENAME=$(basename "$file")
            echo "[$(date)] 📤 Uploading $FILENAME..."
            
            # Run rclone in background with timeout
            if timeout 60 rclone copy "$file" "${REMOTE_NAME}:${REMOTE_PATH}/" \
                --transfers=4 \
                --retries 1 \
                --timeout 30s \
                --no-traverse \
                --ignore-times \
                --quiet 2>&1 | grep -v "^$" || true; then
                ((RCLONE_UPLOADED++))
                echo "[$(date)] ✅ Rclone: $FILENAME"
            else
                ((RCLONE_FAILED++))
                echo "[$(date)] ⚠️ Rclone failed: $FILENAME"
            fi
        fi
    done < <(find "$BACKUP_DIR" -type f \( -name "synapse_db_*.sql.gz" -o -name "synapse_db_*.sql.gz.gpg" \) -mtime -1)
    
    echo "[$(date)] Rclone: $RCLONE_UPLOADED uploaded, $RCLONE_FAILED failed"
else
    echo "[$(date)] ⚠️ Rclone remote '${REMOTE_NAME}' not configured, skipping..."
    echo "[$(date)] Run: rclone config"
fi

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "[$(date)] Offsite Backup Summary:"
echo "  📱 Telegram: $TELEGRAM_SENT sent, $TELEGRAM_FAILED failed"
echo "  ☁️  Rclone:   $RCLONE_UPLOADED uploaded, $RCLONE_FAILED failed"
echo "════════════════════════════════════════════════════════════"
echo ""

# Send summary notification
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    TOTAL_SUCCESS=$((TELEGRAM_SENT + RCLONE_UPLOADED))
    TOTAL_FAILED=$((TELEGRAM_FAILED + RCLONE_FAILED))
    
    STATUS_EMOJI="✅"
    [[ $TOTAL_FAILED -gt 0 ]] && STATUS_EMOJI="⚠️"
    
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=${STATUS_EMOJI} <b>Offsite Backup Complete</b>

� <b>Telegram:</b> <code>${TELEGRAM_SENT}</code> sent, <code>${TELEGRAM_FAILED}</code> failed
☁️ <b>Rclone:</b> <code>${RCLONE_UPLOADED}</code> uploaded, <code>${RCLONE_FAILED}</code> failed

🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null
    
    echo "[$(date)] Summary notification sent to Telegram"
fi

echo "[$(date)] Offsite backup completed! 🎉"
