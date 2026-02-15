# 🔒 Security Hardening Guide

## Table of Contents

1. [Firewall Configuration](#firewall-configuration)
2. [Coturn Security (Host Mode)](#coturn-security-host-mode)
3. [SSL/TLS Configuration](#ssltls-configuration)
4. [Synapse Security](#synapse-security)
5. [Database Security](#database-security)
6. [Monitoring & Alerts](#monitoring--alerts)
7. [Regular Maintenance](#regular-maintenance)

---

## Firewall Configuration

### UFW (Uncomplicated Firewall)

**Install and Configure:**

```bash
# Install UFW
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CRITICAL: Do this first!)
sudo ufw allow 22/tcp
sudo ufw allow OpenSSH

# Allow HTTP/HTTPS (Traefik)
sudo ufw allow 80/tcp comment 'HTTP for Traefik'
sudo ufw allow 443/tcp comment 'HTTPS for Traefik'

# Allow Coturn TURN/STUN
sudo ufw allow 3478/tcp comment 'Coturn STUN TCP'
sudo ufw allow 3478/udp comment 'Coturn STUN UDP'
sudo ufw allow 5349/tcp comment 'Coturn TURNS TCP'
sudo ufw allow 5349/udp comment 'Coturn TURNS UDP'
sudo ufw allow 49152:50151/udp comment 'Coturn media relay'

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

**Expected Output:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
3478/tcp                   ALLOW       Anywhere
3478/udp                   ALLOW       Anywhere
5349/tcp                   ALLOW       Anywhere
5349/udp                   ALLOW       Anywhere
49152:50151/udp            ALLOW       Anywhere
```

### iptables (Advanced)

For more granular control:

```bash
# Rate limit SSH connections
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

# Rate limit HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# Save rules
sudo netfilter-persistent save
```

---

## Coturn Security (Host Mode)

### Why Host Mode is Secure

**Network Mode Comparison:**

| Security Feature | Bridge Mode | Host Mode |
|------------------|-------------|-----------|
| Process Isolation | ✅ Yes | ✅ Yes |
| Filesystem Isolation | ✅ Yes | ✅ Yes |
| Resource Limits | ✅ Yes | ✅ Yes |
| Network Isolation | ✅ Yes | ❌ No (shared with host) |
| Firewall Protection | Docker iptables | ✅ UFW |
| Memory Overhead | ❌ 16GB | ✅ 100MB |

**Security Maintained:**
- ✅ Process runs in container
- ✅ Filesystem is isolated
- ✅ Memory limit enforced (256MB)
- ✅ UFW firewall protects ports
- ✅ Config-based security (denied-peer-ip, quotas)

### Coturn Configuration Security

**File:** `coturn/turnserver.conf`

```conf
# Authentication
use-auth-secret
static-auth-secret=<strong-random-secret>

# Block private IP ranges (prevent SSRF)
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255

# Connection limits (prevent abuse)
user-quota=10        # Max 10 sessions per user
total-quota=100      # Max 100 total sessions

# Bandwidth limit (prevent bandwidth abuse)
max-bps=3000000      # 3 Mbps total

# Disable verbose logging (prevent memory leak)
# verbose  # DISABLED

# TLS security
no-tlsv1
no-tlsv1_1
```

**Security Benefits:**
1. **SSRF Prevention:** `denied-peer-ip` blocks connections to private networks
2. **DoS Prevention:** `user-quota` and `total-quota` limit connections
3. **Bandwidth Protection:** `max-bps` prevents bandwidth exhaustion
4. **Memory Protection:** No verbose logging prevents memory leak
5. **TLS Security:** Only TLS 1.2+ allowed

### Monitoring Coturn

```bash
# Check memory usage (should be < 100MB)
docker stats matrix-coturn --no-stream

# Check active connections
docker logs matrix-coturn | grep -i allocation

# Monitor for abuse
docker logs matrix-coturn | grep -i denied
```

---

## SSL/TLS Configuration

### Traefik TLS Settings

**File:** `traefik/traefik.yml`

```yaml
# Automatic HTTPS
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt
        options: default

# TLS options
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
```

### Certificate Management

**Automatic Renewal:**
- Traefik automatically renews certificates 30 days before expiry
- No manual intervention required

**Manual Renewal:**
```bash
# Remove certificate storage
rm traefik-data/letsencrypt/acme.json

# Restart Traefik
docker compose restart traefik

# Watch logs
docker logs -f matrix-traefik
```

**Backup Certificates:**
```bash
# Backup acme.json
cp traefik-data/letsencrypt/acme.json acme.json.backup

# Restore if needed
cp acme.json.backup traefik-data/letsencrypt/acme.json
docker compose restart traefik
```

---

## Synapse Security

### Registration Control

**Disable Public Registration:**

```bash
# Edit .env
nano .env
# Set: SYNAPSE_ENABLE_REGISTRATION=false

# Regenerate config
./setup.sh

# Restart Synapse
docker compose restart synapse
```

**Shared Secret Registration:**

Even with public registration disabled, admins can create users:

```bash
docker exec -it matrix-synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    http://localhost:8008
```

### Rate Limiting

**File:** `synapse/homeserver.yaml`

```yaml
rc_message:
  per_second: 0.2
  burst_count: 10

rc_registration:
  per_second: 0.17
  burst_count: 3

rc_login:
  address:
    per_second: 0.17
    burst_count: 3
  account:
    per_second: 0.17
    burst_count: 3
  failed_attempts:
    per_second: 0.17
    burst_count: 3
```

### Media Retention

**Automatic Cleanup:**

```bash
# Remove old cached remote media (older than 30 days)
docker exec matrix-synapse \
    curl -X POST "http://localhost:8008/_synapse/admin/v1/media/delete?before_ts=$(date -d '30 days ago' +%s)000" \
    -H "Authorization: Bearer <admin-access-token>"
```

**Get Admin Token:**

```bash
# Login as admin
curl -X POST "http://localhost:8008/_matrix/client/r0/login" \
    -H "Content-Type: application/json" \
    -d '{"type":"m.login.password","user":"admin","password":"<admin-password>"}' \
    | jq -r '.access_token'
```

---

## Database Security

### PostgreSQL Configuration

**Strong Password:**
```bash
# Generate strong password
openssl rand -hex 32

# Update .env
POSTGRES_PASSWORD=<generated-password>
```

**Network Isolation:**
- PostgreSQL only accessible within Docker network
- Not exposed to host or internet

**Backup Encryption:**

```bash
# Encrypted backup
docker exec matrix-postgres pg_dumpall -U synapse | \
    gpg --encrypt --recipient your-gpg-key > backup.sql.gpg

# Restore
gpg --decrypt backup.sql.gpg | \
    docker exec -i matrix-postgres psql -U synapse
```

### pgAdmin Access Control

**Localhost Only:**

```yaml
# docker-compose.yml
pgadmin:
  ports:
    - "127.0.0.1:5050:80"  # Only accessible from localhost
```

**Access via SSH Tunnel:**

```bash
# From local machine
ssh -L 5050:localhost:5050 user@your-server

# Then access: http://localhost:5050
```

---

## Monitoring & Alerts

### Prometheus Security

**Localhost Only:**

```yaml
# docker-compose.yml
prometheus:
  ports:
    - "127.0.0.1:9090:9090"
```

### Grafana Security

**Strong Admin Password:**

```bash
# Generate strong password
openssl rand -base64 32

# Update .env
GF_SECURITY_ADMIN_PASSWORD=<generated-password>
```

**Disable Anonymous Access:**

```yaml
# grafana/grafana.ini
[auth.anonymous]
enabled = false
```

### Alert Configuration

**File:** `alertmanager/alertmanager.yml`

```yaml
route:
  receiver: 'telegram'
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '<your-bot-token>'
        chat_id: <your-chat-id>
        parse_mode: 'HTML'
```

---

## Regular Maintenance

### Security Updates

**Weekly:**

```bash
# Update Docker images
docker compose pull

# Restart with new images
docker compose up -d

# Clean old images
docker image prune -a -f
```

**Monthly:**

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Reboot if kernel updated
sudo reboot
```

### Security Audit

**Check Open Ports:**

```bash
# From external machine
nmap -p- your-server-ip

# Should only show: 22, 80, 443, 3478, 5349, 49152-50151
```

**Check Failed Login Attempts:**

```bash
# SSH failures
sudo grep "Failed password" /var/log/auth.log | tail -20

# Synapse failures
docker logs matrix-synapse | grep -i "failed"
```

**Check Resource Usage:**

```bash
# Disk usage
df -h

# Memory usage
free -h

# Container stats
docker stats --no-stream
```

### Backup Verification

**Test Restore:**

```bash
# Restore to test environment
# Verify data integrity
# Document restore procedure
```

---

## Security Checklist

### Initial Setup
- [ ] UFW firewall enabled
- [ ] SSH key authentication (disable password auth)
- [ ] Strong passwords for all services
- [ ] SSL certificates obtained
- [ ] Public registration disabled
- [ ] Admin user created

### Regular Tasks
- [ ] Weekly Docker image updates
- [ ] Monthly system updates
- [ ] Quarterly security audit
- [ ] Backup verification
- [ ] Log review
- [ ] Certificate expiry check

### Monitoring
- [ ] Grafana dashboards configured
- [ ] Alertmanager notifications working
- [ ] Resource usage monitored
- [ ] Failed login attempts tracked

---

## Security Resources

- **Matrix Security Best Practices:** https://matrix.org/docs/guides/security
- **Docker Security:** https://docs.docker.com/engine/security/
- **Traefik Security:** https://doc.traefik.io/traefik/https/tls/
- **Coturn Security:** https://github.com/coturn/coturn/wiki/turnserver

---

**Stay Secure! 🔒**
