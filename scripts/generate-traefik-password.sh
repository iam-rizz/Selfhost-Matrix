#!/bin/bash

###############################################################################
#  Traefik Dashboard Password Generator                                       #
#  Generates htpasswd hash for Traefik Basic Authentication                  #
###############################################################################

set -e

echo "🔐 Traefik Dashboard Password Generator"
echo "========================================"
echo ""

# Check if htpasswd is installed
if ! command -v htpasswd &> /dev/null; then
    echo "⚠️  htpasswd not found. Installing apache2-utils..."
    sudo apt update && sudo apt install apache2-utils -y
    echo "✅ apache2-utils installed"
    echo ""
fi

# Get username
read -p "Enter username [admin]: " USERNAME
USERNAME=${USERNAME:-admin}

# Get password
while true; do
    read -sp "Enter password: " PASSWORD
    echo ""
    
    if [ ${#PASSWORD} -lt 8 ]; then
        echo "❌ Password must be at least 8 characters long"
        continue
    fi
    
    read -sp "Confirm password: " PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "❌ Passwords don't match. Try again."
        echo ""
        continue
    fi
    
    break
done

# Generate hash
echo ""
echo "🔄 Generating htpasswd hash..."
HASH=$(htpasswd -nb "$USERNAME" "$PASSWORD")

# Extract only the hash part (after the colon)
HASH_ONLY=$(echo "$HASH" | cut -d: -f2)

# Escape dollar signs for Docker Compose (.env file)
ESCAPED_HASH=$(echo "$HASH_ONLY" | sed 's/\$/\$\$/g')

echo ""
echo "✅ Password hash generated successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Add these lines to your .env file:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "TRAEFIK_DASHBOARD_USER=$USERNAME"
echo "TRAEFIK_DASHBOARD_PASSWORD=$ESCAPED_HASH"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Login credentials:"
echo "   URL: https://traefik.your-domain.com/dashboard/"
echo "   Username: $USERNAME"
echo "   Password: (the password you just entered)"
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Dollar signs are already escaped ($$) for .env file"
echo "   - After updating .env, restart Traefik:"
echo "     docker compose up -d --force-recreate traefik"
echo ""
