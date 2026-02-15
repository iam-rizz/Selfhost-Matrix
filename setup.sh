#!/bin/bash
###############################################################################
#  Matrix Server — Setup Script                                               #
#  Reads .env and substitutes __VAR__ placeholders in all config templates    #
#  Also installs system packages and configures Nginx/Fail2ban                #
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
header(){ echo -e "\n${CYAN}${BOLD}═══ $1 ═══${NC}\n"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────
header "Matrix Server Setup"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    error ".env file not found!"
    info "Copy .env.example to .env and fill in your values:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Load .env
set -a
source "$PROJECT_DIR/.env"
set +a

# Calculate Synapse domain based on USE_ROOT_DOMAIN setting
if [[ "${USE_ROOT_DOMAIN:-false}" == "true" ]]; then
    SYNAPSE_DOMAIN="${DOMAIN}"
else
    SYNAPSE_DOMAIN="${SYNAPSE_SUBDOMAIN}.${DOMAIN}"
fi

echo -e "${BOLD}Domain:${NC}     ${DOMAIN}"
echo -e "${BOLD}Synapse:${NC}    ${SYNAPSE_DOMAIN}"
echo -e "${BOLD}Element:${NC}    ${ELEMENT_SUBDOMAIN}.${DOMAIN}"
echo -e "${BOLD}Dimension:${NC}  ${DIMENSION_SUBDOMAIN}.${DOMAIN}"
echo ""

# Validate required vars
REQUIRED_VARS=(DOMAIN ELEMENT_SUBDOMAIN DIMENSION_SUBDOMAIN POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB)
# Only require SYNAPSE_SUBDOMAIN if not using root domain
if [[ "${USE_ROOT_DOMAIN:-false}" != "true" ]]; then
    REQUIRED_VARS+=(SYNAPSE_SUBDOMAIN)
fi

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" || "${!var}" == CHANGE_ME* ]]; then
        error "Required variable $var is not set or still has default value"
        exit 1
    fi
done

# ──────────────────────────────────────────────
# Step 1: Create data directories
# ──────────────────────────────────────────────
header "Creating Data Directories"

DIRS=(
    "$PROJECT_DIR/postgres-data"
    "$PROJECT_DIR/redis-data"
    "$PROJECT_DIR/synapse-data/media_store"
    "$PROJECT_DIR/synapse-data/logs"
    "$PROJECT_DIR/grafana-data"
    "$PROJECT_DIR/prometheus-data"
    "$PROJECT_DIR/pgadmin-data"
    "$PROJECT_DIR/traefik-data/letsencrypt"
    "$PROJECT_DIR/traefik-data/logs"
    "$PROJECT_DIR/jitsi-data/prosody/config"
    "$PROJECT_DIR/jitsi-data/prosody/prosody-plugins-custom"
    "$PROJECT_DIR/jitsi-data/jicofo"
    "$PROJECT_DIR/jitsi-data/jvb"
    "$PROJECT_DIR/backups"
    "$PROJECT_DIR/dimension"
    "$PROJECT_DIR/workers"
)

for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
    log "Created $dir"
done

# Fix permissions for Synapse logs directory
chmod -R 777 "$PROJECT_DIR/synapse-data/logs" 2>/dev/null || warn "Could not chmod synapse logs (may need sudo)"
log "Fixed Synapse logs permissions"

# Fix permissions for Prometheus (runs as nobody, uid 65534)
chmod -R 777 "$PROJECT_DIR/prometheus-data" 2>/dev/null || warn "Could not chmod prometheus-data"
log "Fixed Prometheus permissions"

# Fix permissions for Grafana (runs as uid 472)
if command -v chown &>/dev/null; then
    chown -R 472:472 "$PROJECT_DIR/grafana-data" 2>/dev/null || warn "Could not chown grafana-data (may need sudo)"
fi
chmod -R 777 "$PROJECT_DIR/grafana-data" 2>/dev/null || warn "Could not chmod grafana-data"
log "Fixed Grafana permissions"

# Fix permissions for pgAdmin
chmod -R 777 "$PROJECT_DIR/pgadmin-data" 2>/dev/null || warn "Could not chmod pgadmin-data"
log "Fixed pgAdmin permissions"

# Fix permissions for Dimension (needs write access to /data)
chmod -R 777 "$PROJECT_DIR/dimension" 2>/dev/null || warn "Could not chmod dimension"
log "Fixed Dimension permissions"

# ──────────────────────────────────────────────
# Step 2: Substitute variables in config files
# ──────────────────────────────────────────────
header "Configuring Templates"

substitute_vars() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        warn "File not found: $file"
        return
    fi

    sed -i \
        -e "s|__DOMAIN__|${DOMAIN}|g" \
        -e "s|__SYNAPSE_DOMAIN__|${SYNAPSE_DOMAIN}|g" \
        -e "s|__SYNAPSE_SUBDOMAIN__|${SYNAPSE_SUBDOMAIN}|g" \
        -e "s|__ELEMENT_SUBDOMAIN__|${ELEMENT_SUBDOMAIN}|g" \
        -e "s|__DIMENSION_SUBDOMAIN__|${DIMENSION_SUBDOMAIN}|g" \
        -e "s|__JITSI_SUBDOMAIN__|${JITSI_SUBDOMAIN:-meet}|g" \
        -e "s|__ACME_EMAIL__|${ACME_EMAIL}|g" \
        -e "s|__POSTGRES_USER__|${POSTGRES_USER}|g" \
        -e "s|__POSTGRES_PASSWORD__|${POSTGRES_PASSWORD}|g" \
        -e "s|__POSTGRES_DB__|${POSTGRES_DB}|g" \
        -e "s|__REDIS_PASSWORD__|${REDIS_PASSWORD:-}|g" \
        -e "s|__SYNAPSE_MAX_UPLOAD_SIZE__|${SYNAPSE_MAX_UPLOAD_SIZE:-50M}|g" \
        -e "s|__SYNAPSE_ENABLE_REGISTRATION__|${SYNAPSE_ENABLE_REGISTRATION:-false}|g" \
        -e "s|__SYNAPSE_REGISTRATION_SHARED_SECRET__|${SYNAPSE_REGISTRATION_SHARED_SECRET:-}|g" \
        -e "s|__SYNAPSE_MACAROON_SECRET_KEY__|${SYNAPSE_MACAROON_SECRET_KEY:-}|g" \
        -e "s|__SYNAPSE_FORM_SECRET__|${SYNAPSE_FORM_SECRET:-}|g" \
        -e "s|__TURN_SECRET__|${TURN_SECRET:-}|g" \
        -e "s|__TURN_MIN_PORT__|${TURN_MIN_PORT:-49152}|g" \
        -e "s|__TURN_MAX_PORT__|${TURN_MAX_PORT:-65535}|g" \
        -e "s|__DIMENSION_ACCESS_TOKEN__|${DIMENSION_ACCESS_TOKEN:-}|g" \
        -e "s|__DIMENSION_API_SECRET__|${DIMENSION_API_SECRET:-}|g" \
        -e "s|__TELEGRAM_BOT_TOKEN__|${TELEGRAM_BOT_TOKEN:-}|g" \
        -e "s|__TELEGRAM_CHAT_ID__|${TELEGRAM_CHAT_ID:-}|g" \
        "$file"
    
    log "Configured $(basename "$file")"
}

# Config files to substitute
CONFIG_FILES=(
    "$PROJECT_DIR/synapse/homeserver.yaml"
    "$PROJECT_DIR/element/config.json"
    "$PROJECT_DIR/dimension/config.yaml"
    "$PROJECT_DIR/coturn/turnserver.conf"
    "$PROJECT_DIR/traefik/traefik.yml"
    "$PROJECT_DIR/workers/generic_worker.yaml"
    "$PROJECT_DIR/workers/media_worker.yaml"
    "$PROJECT_DIR/workers/federation_sender.yaml"
    "$PROJECT_DIR/nginx/matrix-synapse.conf"
    "$PROJECT_DIR/nginx/matrix-element.conf"
    "$PROJECT_DIR/nginx/matrix-dimension.conf"
    "$PROJECT_DIR/fail2ban/action.d/telegram.conf"
)

for file in "${CONFIG_FILES[@]}"; do
    substitute_vars "$file"
done

# Update Fail2ban jail logpath
LOGPATH="$PROJECT_DIR/synapse-data/logs/homeserver.log"
sed -i "s|logpath  = /path/to/synapse-data/logs/homeserver.log|logpath  = ${LOGPATH}|g" \
    "$PROJECT_DIR/fail2ban/jail.d/matrix-synapse.conf"
log "Updated Fail2ban jail logpath"

# Export SYNAPSE_DOMAIN to .env file for docker-compose
info "Writing SYNAPSE_DOMAIN=${SYNAPSE_DOMAIN} to .env file..."
if grep -q "^SYNAPSE_DOMAIN=" "$PROJECT_DIR/.env" 2>/dev/null; then
    # Update existing line
    sed -i "s|^SYNAPSE_DOMAIN=.*|SYNAPSE_DOMAIN=${SYNAPSE_DOMAIN}|" "$PROJECT_DIR/.env"
else
    # Add new line after DIMENSION_SUBDOMAIN
    sed -i "/^DIMENSION_SUBDOMAIN=/a SYNAPSE_DOMAIN=${SYNAPSE_DOMAIN}" "$PROJECT_DIR/.env"
fi
log "SYNAPSE_DOMAIN exported to .env"

# ──────────────────────────────────────────────
# Step 3: Generate Synapse signing key
# ──────────────────────────────────────────────
header "Generating Synapse Signing Key"

if [[ ! -f "$PROJECT_DIR/synapse/signing.key" ]]; then
    # Generate signing key using Synapse container
    docker run --rm \
        -v "$PROJECT_DIR/synapse:/data" \
        -e SYNAPSE_SERVER_NAME="${DOMAIN}" \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate 2>/dev/null || true
    
    if [[ -f "$PROJECT_DIR/synapse/${DOMAIN}.signing.key" ]]; then
        mv "$PROJECT_DIR/synapse/${DOMAIN}.signing.key" "$PROJECT_DIR/synapse/signing.key"
    fi
    
    if [[ -f "$PROJECT_DIR/synapse/signing.key" ]]; then
        log "Signing key generated"
    else
        warn "Could not auto-generate signing key. It will be created on first Synapse start."
    fi
else
    log "Signing key already exists"
fi

# ──────────────────────────────────────────────
# Step 4: Install system packages
# ──────────────────────────────────────────────
header "System Packages"

echo "The following system packages are recommended:"
echo "  • fail2ban (brute-force protection)"
echo "  • ufw (firewall)"
echo "  • jq (JSON parsing for Fail2ban geolocation)"
echo ""
echo "Note: Nginx and Certbot are NOT needed — Traefik handles reverse proxy and SSL automatically!"
echo ""
read -p "Install system packages? (y/N): " INSTALL_PACKAGES

if [[ "${INSTALL_PACKAGES,,}" == "y" ]]; then
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y fail2ban ufw jq curl gpg
        log "System packages installed"
    else
        error "apt not found. Please install packages manually."
    fi
fi

# ──────────────────────────────────────────────
# Step 5: Traefik & SSL
# ──────────────────────────────────────────────
header "Traefik Reverse Proxy"

info "Traefik will automatically:"
info "  • Request SSL certificates from Let's Encrypt"
info "  • Route traffic to all services"
info "  • Load balance Synapse workers"
info ""
info "No manual Nginx or certbot configuration needed!"
info ""
info "After 'docker compose up', certificates will be auto-issued for:"
info "  • ${SYNAPSE_DOMAIN}"
info "  • ${ELEMENT_SUBDOMAIN}.${DOMAIN}"
info "  • ${DIMENSION_SUBDOMAIN}.${DOMAIN}"
info "  • ${JITSI_SUBDOMAIN:-meet}.${DOMAIN}"
info "  • traefik.${DOMAIN} (dashboard)"
info ""
warn "IMPORTANT: Ensure DNS A records point to this server BEFORE starting!"
info ""

# ──────────────────────────────────────────────
# Step 7: Configure Fail2ban
# ──────────────────────────────────────────────
header "Fail2ban Configuration"

read -p "Install Fail2ban configs? (y/N): " INSTALL_F2B

if [[ "${INSTALL_F2B,,}" == "y" ]]; then
    sudo cp "$PROJECT_DIR/fail2ban/filter.d/matrix-synapse.conf" /etc/fail2ban/filter.d/
    sudo cp "$PROJECT_DIR/fail2ban/filter.d/matrix-login.conf" /etc/fail2ban/filter.d/
    sudo cp "$PROJECT_DIR/fail2ban/jail.d/matrix-synapse.conf" /etc/fail2ban/jail.d/
    sudo cp "$PROJECT_DIR/fail2ban/action.d/telegram.conf" /etc/fail2ban/action.d/

    sudo systemctl restart fail2ban
    log "Fail2ban configured and restarted"
fi

# ──────────────────────────────────────────────
# Step 8: Configure UFW Firewall
# ──────────────────────────────────────────────
header "Firewall (UFW)"

read -p "Configure UFW firewall rules? (y/N): " SETUP_UFW

if [[ "${SETUP_UFW,,}" == "y" ]]; then
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp     # HTTP
    sudo ufw allow 443/tcp    # HTTPS
    sudo ufw allow 8448/tcp   # Matrix Federation
    sudo ufw allow 3478/tcp   # TURN
    sudo ufw allow 3478/udp   # TURN
    sudo ufw allow 5349/tcp   # TURNS
    sudo ufw allow 5349/udp   # TURNS
    sudo ufw allow 10000/udp  # Jitsi video bridge
    sudo ufw allow "${TURN_MIN_PORT:-49152}:${TURN_MAX_PORT:-65535}/udp"  # TURN relay

    sudo ufw --force enable
    log "UFW firewall configured"
fi

# ──────────────────────────────────────────────
# Step 9: Set up cron jobs
# ──────────────────────────────────────────────
header "Cron Jobs"

read -p "Install cron jobs for backup/monitoring? (y/N): " SETUP_CRON

if [[ "${SETUP_CRON,,}" == "y" ]]; then
    # Make scripts executable
    chmod +x "$PROJECT_DIR/scripts/"*.sh

    # Add cron jobs (avoid duplicates)
    CRON_JOBS=(
        "0 3 * * * $PROJECT_DIR/scripts/backup-postgres.sh >> $PROJECT_DIR/synapse-data/logs/backup.log 2>&1"
        "*/5 * * * * $PROJECT_DIR/scripts/health-check.sh >> $PROJECT_DIR/synapse-data/logs/health.log 2>&1"
        "*/10 * * * * $PROJECT_DIR/scripts/monitor-resources.sh >> $PROJECT_DIR/synapse-data/logs/monitor.log 2>&1"
    )

    EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")

    for job in "${CRON_JOBS[@]}"; do
        if ! echo "$EXISTING_CRON" | grep -qF "$job"; then
            (echo "$EXISTING_CRON"; echo "$job") | crontab -
            EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")
            log "Added cron: $(echo "$job" | cut -d' ' -f1-5) ..."
        else
            info "Cron already exists: $(echo "$job" | cut -d' ' -f1-5) ..."
        fi
    done
fi

# ──────────────────────────────────────────────
# Step 10: Start Docker Compose
# ──────────────────────────────────────────────
header "Starting Services"

read -p "Start Docker Compose services? (y/N): " START_DOCKER

if [[ "${START_DOCKER,,}" == "y" ]]; then
    cd "$PROJECT_DIR"
    docker compose up -d
    
    echo ""
    log "Services starting..."
    info "Waiting 15 seconds for services to initialize..."
    sleep 15
    
    docker compose ps
    echo ""
    
    # Quick health check
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8008/health" | grep -q "200"; then
        log "Synapse is healthy! 🎉"
    else
        warn "Synapse may still be starting up. Check logs with: docker compose logs synapse"
    fi
fi

# ──────────────────────────────────────────────
# Done!
# ──────────────────────────────────────────────
header "Setup Complete! 🚀"

echo -e "${BOLD}Next Steps:${NC}"
echo "  1. Start all services:"
echo "     docker compose up -d"
echo ""
echo "  2. Create admin user:"
echo "     docker exec -it matrix-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -a"
echo ""
echo "  3. Create Dimension bot user (for integrations):"
echo "     docker exec -it matrix-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
echo "     Then get access token and update DIMENSION_ACCESS_TOKEN in .env"
echo ""
echo "  4. Access your services:"
echo "     • Element:         https://${ELEMENT_SUBDOMAIN}.${DOMAIN}"
echo "     • Synapse:         https://${SYNAPSE_DOMAIN}"
echo "     • Jitsi Meet:      https://${JITSI_SUBDOMAIN:-meet}.${DOMAIN}"
echo "     • Traefik:         https://traefik.${DOMAIN}/dashboard/"
echo "     • Grafana:         http://localhost:3000 (SSH tunnel)"
echo "     • Prometheus:      http://localhost:9090 (SSH tunnel)"
echo "     • pgAdmin:         http://localhost:5050 (SSH tunnel)"
echo ""
echo "  5. Verify federation:"
echo "     https://federationtester.matrix.org/api/report?server_name=${DOMAIN}"
echo ""
echo "  6. Check Traefik SSL certificates:"
echo "     docker exec matrix-traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates[].domain'"
echo ""
echo -e "${GREEN}${BOLD}Happy chatting! 💬${NC}"
