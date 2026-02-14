#!/bin/bash
###############################################################################
#  Health Check Script                                                        #
#  Checks all Docker containers + Synapse API responsiveness                  #
#  Cron: */5 * * * * /path/to/scripts/health-check.sh                        #
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

DOMAIN="${DOMAIN:-example.com}"
SYNAPSE_SUBDOMAIN="${SYNAPSE_SUBDOMAIN:-chat}"
SYNAPSE_URL="https://${SYNAPSE_SUBDOMAIN}.${DOMAIN}"

ALERT=false
ALERT_MSG=""

# ──────────────────────────────────────────────
# Check Docker containers
# ──────────────────────────────────────────────
EXPECTED_CONTAINERS=(
    "matrix-postgres"
    "matrix-redis"
    "matrix-synapse"
    "matrix-element"
    "matrix-dimension"
    "matrix-coturn"
    "matrix-prometheus"
    "matrix-grafana"
    "matrix-alertmanager"
    "matrix-node-exporter"
    "matrix-synapse-admin"
)

for container in "${EXPECTED_CONTAINERS[@]}"; do
    STATUS=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
    if [[ "$STATUS" != "running" ]]; then
        ALERT=true
        ALERT_MSG="${ALERT_MSG}\n❌ Container <code>${container}</code>: ${STATUS}"
    fi
done

# ──────────────────────────────────────────────
# Check Synapse API
# ──────────────────────────────────────────────
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    "${SYNAPSE_URL}/_matrix/client/versions" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" != "200" ]]; then
    ALERT=true
    ALERT_MSG="${ALERT_MSG}\n❌ Synapse API returned HTTP ${HTTP_CODE}"
fi

# ──────────────────────────────────────────────
# Check Federation
# ──────────────────────────────────────────────
FED_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    "${SYNAPSE_URL}:8448/_matrix/federation/v1/version" 2>/dev/null || echo "000")

if [[ "$FED_CODE" != "200" ]]; then
    ALERT=true
    ALERT_MSG="${ALERT_MSG}\n⚠️ Federation port 8448 returned HTTP ${FED_CODE}"
fi

# ──────────────────────────────────────────────
# Send alert if issues found
# ──────────────────────────────────────────────
if [[ "$ALERT" == true ]]; then
    echo "[$(date)] HEALTH CHECK FAILED:"
    echo -e "$ALERT_MSG"

    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "$TELEGRAM_BOT_TOKEN" != "CHANGE_ME"* ]]; then
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            -d "text=🚨 <b>Matrix Health Check FAILED</b>
$(echo -e "$ALERT_MSG")
🕐 <code>$(date '+%Y-%m-%d %H:%M:%S')</code>" > /dev/null
    fi

    exit 1
else
    echo "[$(date)] All services healthy ✅"
fi
