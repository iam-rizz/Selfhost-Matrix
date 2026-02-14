# 🔀 Traefik Reverse Proxy Guide

## Overview

Traefik adalah modern reverse proxy yang menggantikan Nginx dengan fitur:
- ✅ **Auto SSL** — Let's Encrypt otomatis, no manual certbot
- ✅ **Dynamic config** — Via Docker labels, no restart needed
- ✅ **Dashboard** — Built-in monitoring UI
- ✅ **Load balancing** — Distribute traffic ke workers
- ✅ **Metrics** — Prometheus integration

## Architecture

```
Internet (80/443/8448)
        ↓
    Traefik
        ↓
    ┌───┴───┬───────┬──────────┬─────────┐
    ↓       ↓       ↓          ↓         ↓
 Synapse Element Dimension  Jitsi  Sliding Sync
    ↓
 Workers (load balanced)
```

## Configuration

### Static Config (`traefik/traefik.yml`)

```yaml
entryPoints:
  web:           # Port 80 → redirect to HTTPS
  websecure:     # Port 443 → HTTPS
  federation:    # Port 8448 → Matrix federation

certificatesResolvers:
  letsencrypt:   # Auto SSL via HTTP challenge
```

### Dynamic Config (Docker Labels)

Setiap service punya labels untuk routing:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.NAME.rule=Host(`domain.com`)"
  - "traefik.http.routers.NAME.entrypoints=websecure"
  - "traefik.http.routers.NAME.tls.certresolver=letsencrypt"
```

## Dashboard

Access: `https://traefik.yourdomain.com/dashboard/`

**Features:**
- View all routers & services
- Check SSL certificates
- Monitor traffic
- View middleware chains

**Authentication:** Basic auth (set in `.env`)

```bash
# Generate password hash
htpasswd -nb admin your-password
# Copy output to .env TRAEFIK_DASHBOARD_PASSWORD
```

## SSL Certificates

Traefik auto-requests & renews Let's Encrypt certs.

**Storage:** `traefik-data/letsencrypt/acme.json`

**Check certs:**
```bash
# View certificate info
docker exec matrix-traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates[].domain'

# Test SSL
curl -I https://chat.yourdomain.com
```

**Manual renewal:** Not needed, auto-renews 30 days before expiry.

## Load Balancing

Traefik distributes traffic ke Synapse workers:

```yaml
# Generic worker load balancing
traefik.http.services.synapse-workers.loadbalancer.server.port=8009
traefik.http.services.synapse-workers.loadbalancer.sticky.cookie=true
```

**Sticky sessions:** Same user → same worker (via cookie)

## Routing Rules

### Synapse Main
- **Rule:** `Host(chat.domain.com)`
- **Port:** 8008
- **Handles:** Server-to-server, admin API

### Synapse Workers
- **Rule:** `Host(chat.domain.com) && PathPrefix(/_matrix/client)`
- **Port:** 8009
- **Handles:** Client requests (load balanced)

### Media Worker
- **Rule:** `Host(chat.domain.com) && PathPrefix(/_matrix/media)`
- **Port:** 8010
- **Handles:** Media uploads/downloads

### Element
- **Rule:** `Host(element.domain.com)`
- **Port:** 80

### Jitsi
- **Rule:** `Host(meet.domain.com)`
- **Port:** 80

## Monitoring

### Prometheus Metrics

Traefik exposes metrics on port 8082 (internal).

**Metrics:**
- `traefik_entrypoint_requests_total`
- `traefik_entrypoint_request_duration_seconds`
- `traefik_service_requests_total`

**Grafana dashboard:** Import ID 17346 (Traefik Official)

### Logs

**Access log:** `traefik-data/logs/access.log`
```bash
tail -f traefik-data/logs/access.log
```

**Traefik log:** `traefik-data/logs/traefik.log`
```bash
tail -f traefik-data/logs/traefik.log
```

## Troubleshooting

### Certificate Issues

```bash
# Check acme.json permissions (must be 600)
chmod 600 traefik-data/letsencrypt/acme.json

# View Traefik logs
docker compose logs traefik

# Force cert renewal (delete acme.json and restart)
rm traefik-data/letsencrypt/acme.json
docker compose restart traefik
```

### Routing Not Working

```bash
# Check Traefik dashboard for router status
# https://traefik.yourdomain.com/dashboard/

# Verify Docker labels
docker inspect matrix-synapse | grep traefik

# Check Traefik can reach service
docker exec matrix-traefik ping synapse
```

### 502 Bad Gateway

```bash
# Check backend service is running
docker compose ps

# Check service health
docker compose logs synapse

# Verify port in Traefik label matches service
```

## Migration from Nginx

1. **Keep Nginx running** (different ports)
2. **Start Traefik** alongside
3. **Test Traefik routing** via localhost
4. **Switch DNS** to Traefik
5. **Stop Nginx** after verification

**Rollback:** Just restart Nginx and stop Traefik.

## Advanced: Middlewares

### Rate Limiting

```yaml
labels:
  - "traefik.http.middlewares.ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.ratelimit.ratelimit.burst=50"
  - "traefik.http.routers.synapse.middlewares=ratelimit"
```

### IP Whitelist

```yaml
labels:
  - "traefik.http.middlewares.ipwhitelist.ipwhitelist.sourcerange=1.2.3.4/32"
  - "traefik.http.routers.dashboard.middlewares=ipwhitelist"
```

### Headers

```yaml
labels:
  - "traefik.http.middlewares.security.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.security.headers.stsIncludeSubdomains=true"
```

## Resources

- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Let's Encrypt Docs](https://letsencrypt.org/docs/)
- [Traefik + Docker Guide](https://doc.traefik.io/traefik/providers/docker/)
