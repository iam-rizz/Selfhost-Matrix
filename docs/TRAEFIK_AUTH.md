# 🔐 Traefik Dashboard Authentication Guide

## Overview

Traefik dashboard menggunakan **HTTP Basic Authentication** dengan password dalam format **htpasswd hash**, bukan plain text.

---

## ⚠️ Common Mistake

**SALAH ❌:**
```bash
TRAEFIK_DASHBOARD_PASSWORD=mypassword123
TRAEFIK_DASHBOARD_PASSWORD=a09108a82d113d82e07e04606348401f  # MD5 hash
```

**BENAR ✅:**
```bash
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$xyz123$$abc...  # htpasswd hash
```

---

## 🔧 Generate Password Hash

### Method 1: Using htpasswd (Recommended)

```bash
# Install htpasswd
sudo apt install apache2-utils -y

# Generate hash (replace 'admin' and 'your_password' with your values)
htpasswd -nb admin your_password

# Output example:
# admin:$apr1$xyz123$abc...
```

**IMPORTANT:** Copy hanya bagian hash setelah `:` (tanpa username)

---

### Method 2: Using Docker

Jika tidak mau install apache2-utils:

```bash
docker run --rm httpd:alpine htpasswd -nb admin your_password
```

---

### Method 3: Online Generator

Visit: https://hostingcanada.org/htpasswd-generator/

1. Enter username: `admin`
2. Enter password: `your_password`
3. Click "Generate"
4. Copy hash yang dihasilkan

---

## 📝 Update .env File

### Step 1: Generate Hash

```bash
# Example command
htpasswd -nb admin MySecurePassword123

# Output:
admin:$apr1$xyz123$abc...def
```

### Step 2: Escape Dollar Signs

**CRITICAL:** Docker Compose requires `$` to be escaped as `$$`

**Original hash:**
```
$apr1$xyz123$abc
```

**Escaped for .env:**
```
$$apr1$$xyz123$$abc
```

### Step 3: Add to .env

```bash
# .env file
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$xyz123$$abc...def
```

---

## 🚀 Quick Setup Script

Save this as `generate-traefik-password.sh`:

```bash
#!/bin/bash

echo "🔐 Traefik Dashboard Password Generator"
echo "========================================"
echo ""

# Check if htpasswd is installed
if ! command -v htpasswd &> /dev/null; then
    echo "Installing apache2-utils..."
    sudo apt install apache2-utils -y
fi

# Get username
read -p "Enter username [admin]: " USERNAME
USERNAME=${USERNAME:-admin}

# Get password
read -sp "Enter password: " PASSWORD
echo ""

# Generate hash
HASH=$(htpasswd -nb "$USERNAME" "$PASSWORD")

# Extract only the hash part (after the colon)
HASH_ONLY=$(echo "$HASH" | cut -d: -f2)

# Escape dollar signs for Docker Compose
ESCAPED_HASH=$(echo "$HASH_ONLY" | sed 's/\$/\$\$/g')

echo ""
echo "✅ Generated! Add these to your .env file:"
echo ""
echo "TRAEFIK_DASHBOARD_USER=$USERNAME"
echo "TRAEFIK_DASHBOARD_PASSWORD=$ESCAPED_HASH"
echo ""
```

**Usage:**
```bash
chmod +x generate-traefik-password.sh
./generate-traefik-password.sh
```

---

## 🔍 Verify Configuration

### 1. Check .env File

```bash
grep TRAEFIK .env
```

Should show:
```
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$...
```

### 2. Restart Traefik

```bash
docker compose up -d --force-recreate traefik
```

### 3. Test Login

Visit: `https://traefik.your-domain.com/dashboard/`

- Username: `admin` (or your custom username)
- Password: Your original password (NOT the hash)

---

## 🐛 Troubleshooting

### Issue: "401 Unauthorized"

**Causes:**
1. Password not in htpasswd format
2. Dollar signs not escaped in .env
3. Wrong username/password combination

**Solution:**
```bash
# Regenerate password
htpasswd -nb admin your_password

# Copy hash (after the colon)
# Escape $ as $$
# Update .env
# Restart: docker compose up -d --force-recreate traefik
```

### Issue: "Cannot access dashboard"

**Check:**
```bash
# Verify Traefik is running
docker ps | grep traefik

# Check logs
docker logs matrix-traefik

# Verify DNS
dig +short traefik.your-domain.com
```

---

## 📚 Example Complete Setup

### .env file:
```bash
# === Traefik ===
ACME_EMAIL=admin@two.web.id
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$H7Kx9xyz$$AbCdEfGhIjKlMnOpQrStUv
```

### Generate command used:
```bash
htpasswd -nb admin MySecurePassword123
# Output: admin:$apr1$H7Kx9xyz$AbCdEfGhIjKlMnOpQrStUv
# Escaped: $$apr1$$H7Kx9xyz$$AbCdEfGhIjKlMnOpQrStUv
```

### Login credentials:
- URL: `https://traefik.two.web.id/dashboard/`
- Username: `admin`
- Password: `MySecurePassword123`

---

## 🔒 Security Best Practices

1. **Use Strong Passwords**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols

2. **Don't Share Credentials**
   - Keep .env file secure
   - Don't commit to Git

3. **Change Default Username**
   ```bash
   TRAEFIK_DASHBOARD_USER=your_custom_username
   ```

4. **Rotate Passwords Regularly**
   - Regenerate hash every 90 days
   - Update .env and restart Traefik

---

## 📖 References

- [Traefik Basic Auth Documentation](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
- [htpasswd Documentation](https://httpd.apache.org/docs/2.4/programs/htpasswd.html)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
