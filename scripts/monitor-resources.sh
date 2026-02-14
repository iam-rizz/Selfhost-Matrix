#!/bin/bash
###############################################################################
#  Resource Monitoring Script                                                 #
#  Checks RAM and disk usage, alerts via Telegram when thresholds exceeded    #
#  Cron: */10 * * * * /path/to/scripts/monitor-resources.sh                  #
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Thresholds (percentage)
RAM_THRESHOLD=85
DISK_THRESHOLD=85

ALERT=false
ALERT_MSG=""

# ──────────────────────────────────────────────
# Check RAM usage
# ──────────────────────────────────────────────
RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))

if [[ $RAM_PERCENT -ge $RAM_THRESHOLD ]]; then
    ALERT=true
    ALERT_MSG="${ALERT_MSG}\n🧠 RAM: <code>${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)</code>"
fi

# ──────────────────────────────────────────────
# Check Disk usage
# ──────────────────────────────────────────────
DISK_PERCENT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
DISK_USED=$(df -h / | awk 'NR==2{print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')

if [[ $DISK_PERCENT -ge $DISK_THRESHOLD ]]; then
    ALERT=true
    ALERT_MSG="${ALERT_MSG}\n💽 Disk: <code>${DISK_USED} / ${DISK_TOTAL} (${DISK_PERCENT}%)</code>"
fi

# ──────────────────────────────────────────────
# Check Docker disk usage
# ──────────────────────────────────────────────
DOCKER_SIZE=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "N/A")

# ──────────────────────────────────────────────
# Send alert if thresholds exceeded
# ──────────────────────────────────────────────
if [[ "$ALERT" == true ]]; then
    echo "[$(date)] RESOURCE ALERT:"
    echo -e "$ALERT_MSG"

    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            -d "text=⚠️ <b>Matrix Resource Alert</b>
$(echo -e "$ALERT_MSG")
🐳 Docker: <code>${DOCKER_SIZE}</code>
🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null
    fi
fi
