# 🔧 Traefik Metrics Fix & Dashboard Setup

## Issues Fixed

### 1. Traefik DOWN in Prometheus ❌ → ✅

**Problem:**
- Prometheus showing Traefik as DOWN
- Error: `dial tcp traefik:8082: connect: connection refused`

**Root Cause:**
- Traefik v3 exposes metrics on port **8080** (not 8082)
- Metrics entrypoint was not configured

**Solution:**
```yaml
# traefik/traefik.yml
entryPoints:
  metrics:
    address: ":8080"

metrics:
  prometheus:
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    entryPoint: metrics
```

```yaml
# prometheus/prometheus.yml
- job_name: "traefik"
  static_configs:
    - targets: ["traefik:8080"]  # Changed from 8082
```

---

## Grafana Dashboards Added

### 1. **Synapse** (Official)
- **Source:** Synapse GitHub repo
- **File:** `synapse.json`
- **Metrics:** DAU/MAU, requests, database, cache, federation

### 2. **Node Exporter** (ID: 1860)
- **Source:** Grafana.com
- **File:** `node-exporter.json`
- **Metrics:** CPU, memory, disk, network, system stats

### 3. **Prometheus** (ID: 3662)
- **Source:** Grafana.com
- **File:** `prometheus.json`
- **Metrics:** Prometheus stats, scrape duration, targets

### 4. **Traefik** (ID: 17346)
- **Source:** Grafana.com
- **File:** `traefik.json`
- **Metrics:** Requests, response times, errors, TLS

---

## Deployment Steps

### 1. Pull Latest Changes

```bash
cd ~/Selfhost-Matrix
git pull origin main
```

### 2. Restart Services

```bash
# Restart Traefik (to load new metrics config)
docker compose restart traefik

# Restart Prometheus (to load new scrape config)
docker compose restart prometheus

# Restart Grafana (to load new dashboards)
docker compose restart grafana
```

### 3. Verify Traefik Metrics

```bash
# Check Traefik metrics endpoint
curl http://localhost:8080/metrics

# Should return Prometheus format metrics:
# traefik_entrypoint_requests_total{...}
# traefik_router_requests_total{...}
# etc.
```

### 4. Verify Prometheus Targets

```bash
# Access Prometheus
http://localhost:9090/targets

# All targets should be UP:
# ✅ node-exporter (node-exporter:9100)
# ✅ prometheus (localhost:9090)
# ✅ synapse (synapse:9000)
# ✅ traefik (traefik:8080)  ← Should be UP now!
```

### 5. Access Grafana Dashboards

```bash
# Access Grafana
http://localhost:3000

# Login
User: admin
Password: <from .env GF_SECURITY_ADMIN_PASSWORD>

# View Dashboards
Dashboards → Browse → Matrix folder

# Available dashboards:
# - Synapse (Matrix homeserver metrics)
# - Node Exporter (System metrics)
# - Prometheus (Prometheus stats)
# - Traefik (Reverse proxy metrics)
```

---

## Dashboard Features

### Synapse Dashboard
- **Users:** Daily/Monthly active users
- **Rooms:** Total rooms, events
- **Performance:** Request rate, latency (p50, p95, p99)
- **Database:** Query time, connections
- **Cache:** Hit rate, size
- **Federation:** Sent/received events, lag

### Node Exporter Dashboard
- **CPU:** Usage per core, load average
- **Memory:** Used, cached, buffers, swap
- **Disk:** I/O, usage, latency
- **Network:** Bandwidth, packets, errors
- **System:** Uptime, processes, file descriptors

### Prometheus Dashboard
- **Targets:** Up/down status
- **Scrapes:** Duration, samples
- **Storage:** TSDB size, blocks
- **Performance:** Query duration

### Traefik Dashboard
- **Requests:** Total, rate, errors
- **Response Time:** p50, p95, p99
- **TLS:** Certificate expiry
- **Services:** Backend health
- **EntryPoints:** Traffic per entrypoint

---

## Troubleshooting

### Traefik Still DOWN

**Check metrics endpoint:**
```bash
# From inside Traefik container
docker exec matrix-traefik wget -O- http://localhost:8080/metrics

# From Prometheus container
docker exec matrix-prometheus wget -O- http://traefik:8080/metrics
```

**Check Traefik logs:**
```bash
docker logs matrix-traefik | grep -i metrics
```

### Dashboards Not Loading

**Check Grafana logs:**
```bash
docker logs matrix-grafana | grep -i dashboard
```

**Verify files exist:**
```bash
ls -la grafana/provisioning/dashboards/
# Should show:
# - synapse.json
# - node-exporter.json
# - prometheus.json
# - traefik.json
# - dashboards.yml
```

**Force reload:**
```bash
docker compose up -d --force-recreate grafana
```

---

## Quick Verification

```bash
# 1. Check all targets UP
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Expected output:
# {"job":"node-exporter","health":"up"}
# {"job":"prometheus","health":"up"}
# {"job":"synapse","health":"up"}
# {"job":"traefik","health":"up"}  ← Should be "up" now!

# 2. Check Grafana dashboards
curl -s -u admin:<password> http://localhost:3000/api/search?query=& | jq '.[].title'

# Expected output:
# "Synapse"
# "Node Exporter Full"
# "Prometheus 2.0 Stats"
# "Traefik"
```

---

## Summary

**Commit:** 5fb1371

**Files Changed:**
- `traefik/traefik.yml` - Added metrics entrypoint
- `prometheus/prometheus.yml` - Fixed Traefik target port
- `grafana/provisioning/dashboards/` - Added 4 dashboards

**Result:**
- ✅ Traefik metrics working
- ✅ All Prometheus targets UP
- ✅ 4 comprehensive dashboards available
- ✅ Full observability stack ready

**Next:** Deploy to server and verify all dashboards! 🎉
