# Synapse Monitoring Dashboard Setup

## ⚠️ Important: Dashboard IDs are WRONG!

**Common Mistakes:**
- ❌ Dashboard ID **14927** = JMeter (NOT Synapse!)
- ❌ Dashboard ID **3387** = Process Top (NOT Synapse!)
- ✅ **Official Synapse Dashboard** = From Synapse GitHub repo

## Official Synapse Dashboard

**Source:** Synapse GitHub Repository  
**File:** `contrib/grafana/synapse.json`  
**URL:** https://github.com/element-hq/synapse/blob/develop/contrib/grafana/synapse.json

**Data Source:** Prometheus (required)

## Automatic Setup (Recommended)

Dashboard is automatically provisioned from `grafana/provisioning/dashboards/synapse.json`

**Restart Grafana to load:**

```bash
docker compose restart grafana

# Check logs
docker logs -f matrix-grafana
```

**Access Dashboard:**

```
http://localhost:3000
→ Dashboards
→ Matrix folder
→ Synapse
```

## Manual Import

If automatic provisioning doesn't work:

1. **Download Dashboard:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/element-hq/synapse/develop/contrib/grafana/synapse.json -o synapse-dashboard.json
   ```

2. **Import to Grafana:**
   - Access: `http://localhost:3000`
   - Login with admin credentials
   - Go to: **Dashboards** → **Import**
   - Click: **Upload JSON file**
   - Select: `synapse-dashboard.json`
   - Select datasource: **Prometheus**
   - Click: **Import**

## Dashboard Features

### Overview Panels
- **Active Users:** Daily Active Users (DAU), Monthly Active Users (MAU)
- **Rooms:** Total rooms, local rooms
- **Events:** Event rate, event processing time
- **Federation:** Sent/received events, destination lag

### Performance Metrics
- **Request Rate:** HTTP requests per second
- **Response Time:** Request latency (p50, p95, p99)
- **Database:** Query time, connection pool usage
- **Cache:** Hit rate, size, evictions

### Resource Usage
- **CPU:** Process CPU usage
- **Memory:** RSS, heap size
- **Disk:** Media store size
- **Network:** Bandwidth usage

### Worker Metrics (if workers enabled)
- Generic worker stats
- Media worker stats
- Federation sender stats

## Verify Metrics Endpoint

**Check Synapse metrics:**

```bash
# Synapse main process
curl http://localhost:9000/metrics

# Should return Prometheus format metrics:
# synapse_http_server_requests_total{...}
# synapse_admin_mau:current
# etc.
```

**Check Prometheus targets:**

```bash
# Access Prometheus
http://localhost:9090/targets

# Should show:
# - synapse (localhost:9000) - UP
# - node-exporter (node-exporter:9100) - UP
```

## Troubleshooting

### Dashboard Shows "No Data"

**1. Check Prometheus datasource:**
```bash
# Grafana → Configuration → Data Sources
# Verify: URL = http://prometheus:9090
# Click: Save & Test
# Should show: "Data source is working"
```

**2. Verify Synapse metrics:**
```bash
# Check if Synapse exposes metrics
curl http://localhost:9000/metrics | head -20

# Should see metrics like:
# synapse_http_server_requests_total
# synapse_admin_mau:current
```

**3. Check Prometheus scraping:**
```bash
# Access Prometheus targets
http://localhost:9090/targets

# synapse should be UP
# If DOWN, check docker-compose.yml prometheus config
```

### Metrics Endpoint Not Accessible

**Check Synapse config:**

```yaml
# synapse/homeserver.yaml
enable_metrics: true
metrics_port: 9000
```

**Restart Synapse:**
```bash
docker compose restart synapse
```

### Wrong Dashboard Imported

**Remove wrong dashboard:**
1. Go to: Dashboards
2. Find: JMeter (14927) or Process Top (3387)
3. Click: Settings (gear icon)
4. Click: Delete

**Import correct dashboard:**
- Use file from Synapse repo
- NOT dashboard IDs from Grafana.com

## Alternative: Community Dashboards

If official dashboard doesn't work, search Grafana.com for "Matrix Synapse":

**Search:** https://grafana.com/grafana/dashboards/?search=synapse

**Note:** Most community dashboards are outdated or use different metrics.

## Custom Panels

### Useful Prometheus Queries

**Active Users (DAU):**
```promql
synapse_admin_mau:current{job="synapse"}
```

**Request Rate:**
```promql
rate(synapse_http_server_requests_total[5m])
```

**Database Query Time (p95):**
```promql
histogram_quantile(0.95, rate(synapse_storage_schedule_time_bucket[5m]))
```

**Federation Lag:**
```promql
synapse_federation_client_sent_transactions_total - synapse_federation_client_sent_transactions_total offset 1m
```

**Cache Hit Rate:**
```promql
rate(synapse_util_caches_cache_hits[5m]) / (rate(synapse_util_caches_cache_hits[5m]) + rate(synapse_util_caches_cache_misses[5m]))
```

## Quick Setup Summary

```bash
# 1. Dashboard already provisioned
# File: grafana/provisioning/dashboards/synapse.json

# 2. Restart Grafana
docker compose restart grafana

# 3. Access Grafana
http://localhost:3000

# 4. Login
User: admin
Password: <from .env GF_SECURITY_ADMIN_PASSWORD>

# 5. View Dashboard
Dashboards → Matrix → Synapse

# Done!
```

## Resources

- **Official Dashboard:** https://github.com/element-hq/synapse/blob/develop/contrib/grafana/synapse.json
- **Synapse Metrics Docs:** https://element-hq.github.io/synapse/latest/metrics-howto.html
- **Prometheus Docs:** https://prometheus.io/docs/
- **Grafana Docs:** https://grafana.com/docs/

---

**Use the OFFICIAL dashboard from Synapse repo, NOT random IDs from Grafana.com!** ✅
