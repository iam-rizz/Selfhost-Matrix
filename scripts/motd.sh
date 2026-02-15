#!/bin/bash
###############################################################################
#  Matrix Server MOTD (Message of the Day)                                   #
#  Displays elegant system information on SSH login                          #
###############################################################################

# Colors
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Matrix theme colors
MATRIX_GREEN='\033[38;5;46m'
MATRIX_DARK='\033[38;5;22m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;33m'
PURPLE='\033[38;5;141m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
GRAY='\033[38;5;240m'

# Get system information
HOSTNAME=$(hostname)
KERNEL=$(uname -r)
UPTIME=$(uptime -p | sed 's/up //')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
MEMORY=$(free -h | awk '/^Mem:/ {printf "%s / %s (%.0f%%)", $3, $2, ($3/$2)*100}')
DISK=$(df -h / | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')
IP=$(hostname -I | awk '{print $1}')
USERS=$(who | wc -l)

# Docker stats (if available)
if command -v docker &> /dev/null; then
    CONTAINERS_RUNNING=$(docker ps -q 2>/dev/null | wc -l)
    CONTAINERS_TOTAL=$(docker ps -aq 2>/dev/null | wc -l)
    DOCKER_STATUS="${MATRIX_GREEN}${CONTAINERS_RUNNING}${RESET}${GRAY}/${RESET}${CONTAINERS_TOTAL}"
else
    DOCKER_STATUS="${GRAY}N/A${RESET}"
fi

# Synapse status (if available)
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "matrix-synapse"; then
    SYNAPSE_STATUS="${MATRIX_GREEN}●${RESET} ${BOLD}Running${RESET}"
else
    SYNAPSE_STATUS="${RED}●${RESET} ${DIM}Stopped${RESET}"
fi

# Clear screen and display MOTD
clear

echo -e "${MATRIX_GREEN}${BOLD}"
echo "    ╔═══════════════════════════════════════════════════════════╗"
echo "    ║                   MATRIX HOMESERVER                       ║"
echo "    ╚═══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}System Information${RESET}                                            ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Hostname:${RESET}     ${PURPLE}${HOSTNAME}${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}IP Address:${RESET}   ${BLUE}${IP}${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Kernel:${RESET}       ${GRAY}${KERNEL}${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Uptime:${RESET}       ${YELLOW}${UPTIME}${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}Resources${RESET}                                                     ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Load Average:${RESET} ${YELLOW}${LOAD}${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Memory:${RESET}       ${MEMORY}"
echo -e "${CYAN}║${RESET}  ${GRAY}Disk Usage:${RESET}   ${DISK}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}Services${RESET}                                                      ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}Synapse:${RESET}      ${SYNAPSE_STATUS}"
echo -e "${CYAN}║${RESET}  ${GRAY}Containers:${RESET}   ${DOCKER_STATUS}"
echo -e "${CYAN}║${RESET}  ${GRAY}Active Users:${RESET} ${MATRIX_GREEN}${USERS}${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"

echo ""
echo -e "  ${BOLD}${MATRIX_GREEN}Access Your Services:${RESET}"
echo ""

# Load domain from .env if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Display service URLs
if [[ -n "${DOMAIN:-}" ]]; then
    echo -e "  ${GRAY}Web Services:${RESET}"
    echo -e "    ${MATRIX_GREEN}•${RESET} Element:       ${BLUE}https://${ELEMENT_SUBDOMAIN:-element}.${DOMAIN}${RESET}"
    echo -e "    ${MATRIX_GREEN}•${RESET} Synapse:       ${BLUE}https://${SYNAPSE_DOMAIN:-${DOMAIN}}${RESET}"
    echo -e "    ${MATRIX_GREEN}•${RESET} Jitsi Meet:    ${BLUE}https://${JITSI_SUBDOMAIN:-meet}.${DOMAIN}${RESET}"
    echo -e "    ${MATRIX_GREEN}•${RESET} Traefik:       ${BLUE}https://traefik.${DOMAIN}/dashboard/${RESET}"
    echo ""
fi

echo -e "  ${GRAY}SSH Tunnels (run on local machine):${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} All Services:  ${YELLOW}ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -L 5050:localhost:5050 ${USER}@${IP}${RESET}"
echo ""
echo -e "  ${GRAY}Or individually:${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} Grafana:       ${YELLOW}ssh -L 3000:localhost:3000 ${USER}@${IP}${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} Prometheus:    ${YELLOW}ssh -L 9090:localhost:9090 ${USER}@${IP}${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} pgAdmin:       ${YELLOW}ssh -L 5050:localhost:5050 ${USER}@${IP}${RESET}"
echo ""
echo -e "  ${GRAY}Then access:${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} Grafana:       ${BLUE}http://localhost:3000${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} Prometheus:    ${BLUE}http://localhost:9090${RESET}"
echo -e "    ${MATRIX_GREEN}•${RESET} pgAdmin:       ${BLUE}http://localhost:5050${RESET}"
echo ""
echo -e "  ${GRAY}Documentation:${RESET} ${BLUE}https://github.com/iam-rizz/Selfhost-Matrix${RESET}"
echo ""
