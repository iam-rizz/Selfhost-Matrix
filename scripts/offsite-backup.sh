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

echo "[$(date)] Starting offsite backup..."

# ──────────────────────────────────────────────
# Send to Telegram (send 3 most recent files)
# ──────────────────────────────────────────────
TELEGRAM_SENT=0
TELEGRAM_FAILED=0

if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    echo "[$(date)] Sending backups to Telegram..."
    
    # Get 3 most recent backup files
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            FILENAME=$(basename "$file")
            FILESIZE=$(du -h "$file" | cut -f1)
            
            echo "[$(date)] 📤 Sending $FILENAME ($FILESIZE)..."
            
            # Telegram has 50MB file limit, add timeout to prevent hanging
            if timeout 30 curl -s --max-time 25 -X POST \
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
                echo "[$(date)] ⚠️ Telegram failed: $FILENAME (timeout or network error)"
            fi
        fi
    done < <(find "$BACKUP_DIR" -type f \( -name "synapse_db_*.sql.gz" -o -name "synapse_db_*.sql.gz.gpg" \) -printf '%T@ %p\n' | sort -rn | head -3 | cut -d' ' -f2-)
    
    echo "[$(date)] Telegram: $TELEGRAM_SENT sent, $TELEGRAM_FAILED failed"
else
    echo "[$(date)] ⚠️ Telegram not configured, skipping..."
fi

# ──────────────────────────────────────────────
# Rclone disabled (user request)
# ──────────────────────────────────────────────
echo "[$(date)] Rclone upload: disabled"

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "[$(date)] Offsite Backup Summary:"
echo "  📱 Telegram: $TELEGRAM_SENT sent, $TELEGRAM_FAILED failed"
echo "  ☁️  Rclone:   disabled"
echo "════════════════════════════════════════════════════════════"
echo ""

# Send summary notification
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
    STATUS_EMOJI="✅"
    [[ $TELEGRAM_FAILED -gt 0 ]] && STATUS_EMOJI="⚠️"
    
    timeout 10 curl -s --max-time 8 -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=${STATUS_EMOJI} <b>Offsite Backup Complete</b>

📱 <b>Telegram:</b> <code>${TELEGRAM_SENT}</code> sent, <code>${TELEGRAM_FAILED}</code> failed
☁️ <b>Rclone:</b> disabled

🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null 2>&1
    
    echo "[$(date)] Summary notification sent to Telegram"
fi

echo "[$(date)] Offsite backup completed! 🎉"
