# 🔧 Debugging Guide — Starting Services One by One

## Overview

This guide shows how to start Docker Compose services individually for debugging, troubleshooting, or resource-constrained environments.

## Prerequisites

1. **Run setup.sh first:**
   ```bash
   ./setup.sh
   ```
   This substitutes all `__PLACEHOLDER__` variables in config files.

2. **Verify .env file:**
   ```bash
   # Check SYNAPSE_DOMAIN is set
   grep "SYNAPSE_DOMAIN" .env
   
   # Should show: SYNAPSE_DOMAIN=your-domain.com
   ```

---

## 🚀 Recommended Startup Order

### Phase 1: Core Infrastructure (Required)

```bash
# 1. Start PostgreSQL
docker compose up -d postgres

# Wait for healthy status
docker compose ps postgres
# STATUS should show "healthy"

# 2. Start Redis
docker compose up -d redis

# Wait for healthy status
docker compose ps redis
```

**Check logs if issues:**
```bash
docker compose logs postgres
docker compose logs redis
```

---

### Phase 2: Synapse Main (Required)

```bash
# Start Synapse
docker compose up -d synapse

# Watch logs in real-time
docker compose logs -f synapse
```

**Expected output:**
```
Synapse now listening on TCP port 8008
```

**Common errors:**

| Error | Solution |
|-------|----------|
| `Server name '__DOMAIN__' has an invalid format` | Run `./setup.sh` to substitute variables |
| `enable_registration without verification` | Already fixed in latest version |
| `Database connection failed` | Wait for PostgreSQL to be healthy |
| `Redis connection failed` | Check Redis is running |

**Verify Synapse is working:**
```bash
# Health check
curl http://localhost:8008/health
# Should return: {"status": "OK"}

# Check version
curl http://localhost:8008/_matrix/federation/v1/version
```

---

### Phase 3: Reverse Proxy (Required for HTTPS)

```bash
# Start Traefik
docker compose up -d traefik

# Check Traefik logs
docker compose logs -f traefik
```

**Expected output:**
```
Configuration loaded from file: /etc/traefik/traefik.yml
```

**Check SSL certificates:**
```bash
# Wait 30-60 seconds for certificate issuance
docker compose logs traefik | grep -i "certificate"

# Check acme.json
docker exec matrix-traefik ls -lh /letsencrypt/acme.json
```

**Verify Traefik routing:**
```bash
# Access dashboard (if enabled)
curl -u admin:password https://traefik.yourdomain.com/dashboard/

# Check Synapse via Traefik
curl https://chat.yourdomain.com/_matrix/federation/v1/version
```

---

### Phase 4: Web Client (Required for UI)

```bash
# Start Element Web
docker compose up -d element

# Check status
docker compose ps element
```

**Access Element:**
- URL: `https://element.yourdomain.com`
- Should show Element login page

---

### Phase 5: Workers (Optional — For Scaling)

Only start if you need horizontal scaling:

```bash
# Start generic worker (handles client API)
docker compose up -d synapse-worker-generic

# Start media worker (handles uploads/downloads)
docker compose up -d synapse-worker-media

# Start federation sender (handles outbound federation)
docker compose up -d synapse-worker-federation-sender

# Check all workers
docker compose ps | grep worker
```

**Verify workers:**
```bash
# Check worker logs
docker compose logs -f synapse-worker-generic

# Check Traefik routing to workers
curl https://chat.yourdomain.com/_matrix/client/versions
```

---

### Phase 6: Additional Services (Optional)

Start only if needed:

#### Sliding Sync (10x faster sync)
```bash
docker compose up -d sliding-sync
docker compose logs -f sliding-sync
```

#### Jitsi Meet (Video conferencing)
```bash
# Start all 4 Jitsi containers
docker compose up -d jitsi-web jitsi-prosody jitsi-jicofo jitsi-jvb

# Check Jitsi web
docker compose logs jitsi-web
```

**Access Jitsi:** `https://meet.yourdomain.com`

#### Dimension (Integration manager)
```bash
docker compose up -d dimension
docker compose logs -f dimension
```

#### Coturn (TURN/STUN for VoIP)
```bash
docker compose up -d coturn
docker compose logs coturn
```

---

### Phase 7: Monitoring (Optional)

```bash
# Start Prometheus
docker compose up -d prometheus

# Start Grafana
docker compose up -d grafana

# Start Alertmanager
docker compose up -d alertmanager

# Start Node Exporter
docker compose up -d node-exporter
```

**Access monitoring:**
- Prometheus: `http://localhost:9090` (SSH tunnel)
- Grafana: `http://localhost:3000` (SSH tunnel)

---

### Phase 8: Management Tools (Optional)

```bash
# Start pgAdmin (PostgreSQL manager)
docker compose up -d pgadmin

# Start Synapse Admin
docker compose up -d synapse-admin
```

**Access management:**
- pgAdmin: `http://localhost:5050` (SSH tunnel)
- Synapse Admin: `http://localhost:8888` (SSH tunnel)

---

## 🛑 Stopping Services

### Stop specific service
```bash
docker compose stop synapse
```

### Stop multiple services
```bash
docker compose stop jitsi-web jitsi-prosody jitsi-jicofo jitsi-jvb
```

### Stop all services
```bash
docker compose down
```

### Stop and remove volumes (⚠️ deletes data)
```bash
docker compose down -v
```

---

## 🔍 Debugging Commands

### Check service status
```bash
# All services
docker compose ps

# Specific service
docker compose ps synapse

# Show only running
docker compose ps --filter "status=running"
```

### View logs
```bash
# Follow logs (real-time)
docker compose logs -f synapse

# Last 100 lines
docker compose logs --tail=100 synapse

# Multiple services
docker compose logs -f synapse postgres redis

# All services
docker compose logs -f
```

### Restart service
```bash
# Restart without recreating
docker compose restart synapse

# Recreate container
docker compose up -d --force-recreate synapse
```

### Execute commands in container
```bash
# Shell access
docker compose exec synapse bash

# Run command
docker compose exec synapse ls -la /data

# Check Synapse version
docker compose exec synapse python -m synapse.app.homeserver --version
```

### Check resource usage
```bash
# CPU and RAM usage
docker stats

# Specific service
docker stats matrix-synapse
```

---

## 🐛 Common Issues & Solutions

### Issue: Service keeps restarting

```bash
# Check logs for error
docker compose logs --tail=50 synapse

# Common causes:
# 1. Config error → Run ./setup.sh
# 2. Database not ready → Wait for postgres healthy
# 3. Port conflict → Check if port already in use
```

### Issue: Cannot connect to service

```bash
# Check service is running
docker compose ps synapse

# Check port mapping
docker compose port synapse 8008

# Check network
docker network inspect matrix-network

# Test connectivity
docker compose exec synapse curl http://localhost:8008/health
```

### Issue: SSL certificate not issued

```bash
# Check Traefik logs
docker compose logs traefik | grep -i acme

# Common causes:
# 1. DNS not pointing to server
# 2. Ports 80/443 not accessible
# 3. Email not set in .env (ACME_EMAIL)

# Verify DNS
dig chat.yourdomain.com +short
# Should return your server IP

# Test port 80 from outside
curl http://your-server-ip
```

### Issue: Database connection failed

```bash
# Check PostgreSQL is healthy
docker compose ps postgres

# Check PostgreSQL logs
docker compose logs postgres

# Test connection
docker compose exec postgres psql -U synapse -d synapse -c "SELECT 1;"

# Verify credentials in .env
grep POSTGRES .env
```

---

## 📊 Minimal vs Full Setup

### Minimal (Core functionality only)
**~1.5GB RAM**
```bash
docker compose up -d postgres redis synapse traefik element
```

Services:
- PostgreSQL (database)
- Redis (cache)
- Synapse (homeserver)
- Traefik (reverse proxy)
- Element (web client)

### Standard (With monitoring)
**~2.5GB RAM**
```bash
docker compose up -d postgres redis synapse traefik element \
  prometheus grafana coturn
```

### Full (All features)
**~4GB RAM**
```bash
docker compose up -d
```

All 22 services including workers, Jitsi, Sliding Sync, monitoring, and management tools.

---

## 🔄 Restart Order (After Config Changes)

1. **Stop affected services:**
   ```bash
   docker compose stop synapse synapse-worker-generic
   ```

2. **Update config:**
   ```bash
   nano synapse/homeserver.yaml
   ```

3. **Restart services:**
   ```bash
   docker compose up -d synapse synapse-worker-generic
   ```

4. **Verify:**
   ```bash
   docker compose logs -f synapse
   ```

---

## 📝 Health Check Checklist

After starting services, verify:

- [ ] PostgreSQL: `docker compose ps postgres` → healthy
- [ ] Redis: `docker compose ps redis` → healthy
- [ ] Synapse: `curl http://localhost:8008/health` → OK
- [ ] Traefik: `curl https://chat.domain.com/_matrix/federation/v1/version` → returns version
- [ ] Element: `https://element.domain.com` → shows login page
- [ ] SSL: `curl -I https://chat.domain.com` → 200 OK with valid cert

---

## 🎯 Quick Reference

| Service | Port | Health Check |
|---------|------|--------------|
| PostgreSQL | 5432 | `docker compose ps postgres` |
| Redis | 6379 | `docker compose ps redis` |
| Synapse | 8008 | `curl http://localhost:8008/health` |
| Traefik | 80, 443, 8448 | `curl https://traefik.domain.com/dashboard/` |
| Element | 8080 | `curl http://localhost:8080` |
| Prometheus | 9090 | `curl http://localhost:9090/-/healthy` |
| Grafana | 3000 | `curl http://localhost:3000/api/health` |

---

## 💡 Pro Tips

1. **Use `--wait` flag:**
   ```bash
   docker compose up -d --wait postgres redis
   # Waits for healthy status before returning
   ```

2. **Check dependency order:**
   ```bash
   docker compose config --services
   # Shows all services in dependency order
   ```

3. **Dry run:**
   ```bash
   docker compose up --dry-run synapse
   # Shows what would happen without actually starting
   ```

4. **Resource limits:**
   ```bash
   # Check current limits
   docker compose config | grep -A 5 "resources:"
   ```

5. **Clean restart:**
   ```bash
   # Stop, remove, and recreate
   docker compose down && docker compose up -d postgres redis synapse traefik element
   ```

---

## 🆘 Emergency Commands

### Service won't stop
```bash
docker compose kill synapse
docker compose rm -f synapse
```

### Clear all containers
```bash
docker compose down --remove-orphans
```

### Reset everything (⚠️ deletes data)
```bash
docker compose down -v
rm -rf postgres-data redis-data synapse-data
./setup.sh
docker compose up -d
```

### Check disk space
```bash
docker system df
docker system prune -a  # Clean unused images
```

---

## 📚 Related Documentation

- [TRAEFIK.md](TRAEFIK.md) — Traefik configuration & troubleshooting
- [WORKERS.md](WORKERS.md) — Synapse Workers scaling guide
- [MONITORING.md](MONITORING.md) — Prometheus & Grafana setup
- [JITSI.md](JITSI.md) — Jitsi Meet video conferencing
- [SLIDING_SYNC.md](SLIDING_SYNC.md) — Fast sync proxy setup
