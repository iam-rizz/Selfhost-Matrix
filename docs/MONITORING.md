# 📊 Monitoring Guide — Prometheus & Grafana

## Overview

Stack monitoring menggunakan:
- **Prometheus** — Metrics collection & alerting
- **Grafana** — Visualization & dashboards
- **Alertmanager** — Alert routing & notifications
- **Node Exporter** — System metrics (CPU, RAM, disk, network)

## Architecture

```
┌─────────────┐
│   Synapse   │ ──► Metrics endpoint :9000
└─────────────┘

┌─────────────┐
│Node Exporter│ ──► System metrics :9100
└─────────────┘
        │
        ▼
┌─────────────┐     ┌──────────────┐
│ Prometheus  │ ──► │ Alertmanager │ ──► Telegram/Webhook
└─────────────┘     └──────────────┘
        │
        ▼
┌─────────────┐
│   Grafana   │ ◄── User accesses dashboards
└─────────────┘
```

## Prometheus Setup

### 1. Access Prometheus

```bash
# Via SSH tunnel
ssh -L 9090:localhost:9090 user@your-server

# Open browser
http://localhost:9090
```

### 2. Verify Targets

Go to **Status** → **Targets**

Semua target harus **UP**:
- `synapse` — Synapse metrics
- `node-exporter` — System metrics
- `prometheus` — Self-monitoring

### 3. Query Examples

Di Prometheus UI, coba query ini:

```promql
# Total registered users
synapse_admin_mau_current

# Active users (last 30 days)
synapse_admin_mau_max

# CPU usage
rate(process_cpu_seconds_total{job="synapse"}[5m]) * 100

# Memory usage (MB)
process_resident_memory_bytes{job="synapse"} / 1024 / 1024

# Federation send rate
rate(synapse_federation_client_sent_transactions_total[5m])

# Database connections
synapse_database_connections{job="synapse"}

# Event processing rate
rate(synapse_storage_events_persisted_events_total[5m])
```

### 4. Alert Rules

Alert rules sudah dikonfigurasi di `prometheus/alert_rules.yml`:

| Alert | Trigger | Severity |
|---|---|---|
| **SynapseDown** | Synapse unreachable > 1 min | Critical |
| **SynapseHighCPU** | CPU > 80% for 5 min | Warning |
| **SynapseHighMemory** | RAM > 2GB for 5 min | Warning |
| **SynapseFederationErrors** | High failure rate 10 min | Warning |
| **HighDiskUsage** | < 15% free space | Warning |
| **HighMemoryUsage** | > 85% RAM used | Warning |
| **NodeExporterDown** | Unreachable > 2 min | Critical |

## Grafana Setup

### 1. First Login

```bash
# Via SSH tunnel
ssh -L 3000:localhost:3000 user@your-server

# Open browser
http://localhost:3000

# Login credentials (from .env)
Username: admin
Password: GF_SECURITY_ADMIN_PASSWORD
```

### 2. Verify Datasource

Prometheus datasource sudah auto-provisioned.

**Check**: Configuration → Data Sources → Prometheus
- URL: `http://prometheus:9090`
- Status: ✅ Working

### 3. Import Synapse Dashboard

Grafana Labs punya official Synapse dashboard:

1. Go to **Dashboards** → **Import**
2. Enter dashboard ID: **14927** (Synapse Dashboard by Matrix.org)
3. Select Prometheus datasource
4. Click **Import**

### 4. Create Custom Dashboard

#### Panel 1: Active Users

```promql
# Query
synapse_admin_mau_current

# Visualization: Stat
# Title: Active Users (30 days)
```

#### Panel 2: CPU Usage

```promql
# Query
rate(process_cpu_seconds_total{job="synapse"}[5m]) * 100

# Visualization: Time series
# Title: Synapse CPU Usage (%)
# Unit: percent (0-100)
```

#### Panel 3: Memory Usage

```promql
# Query
process_resident_memory_bytes{job="synapse"} / 1024 / 1024

# Visualization: Time series
# Title: Synapse Memory (MB)
# Unit: megabytes
```

#### Panel 4: Event Rate

```promql
# Query
rate(synapse_storage_events_persisted_events_total[5m])

# Visualization: Time series
# Title: Events Persisted/sec
```

#### Panel 5: Database Connections

```promql
# Query
synapse_database_connections

# Visualization: Gauge
# Title: DB Connections
# Max: 100 (from homeserver.yaml cp_max)
```

#### Panel 6: Federation Send Rate

```promql
# Query
rate(synapse_federation_client_sent_transactions_total[5m])

# Visualization: Time series
# Title: Federation Transactions/sec
```

### 5. System Metrics Dashboard

Create new dashboard untuk system metrics:

#### Disk Usage

```promql
# Query
(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Visualization: Gauge
# Title: Disk Free (%)
# Thresholds: Red < 15%, Yellow < 30%
```

#### RAM Usage

```promql
# Query
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Visualization: Gauge
# Title: RAM Usage (%)
# Thresholds: Red > 85%, Yellow > 70%
```

#### Network Traffic

```promql
# Query (Received)
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Query (Transmitted)
rate(node_network_transmit_bytes_total{device!="lo"}[5m])

# Visualization: Time series
# Title: Network Traffic
# Unit: bytes/sec
```

## Alertmanager Setup

### 1. Configure Telegram Alerts

Edit `alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'telegram'
    webhook_configs:
      - url: 'https://api.telegram.org/bot<BOT_TOKEN>/sendMessage'
        send_resolved: true
        http_config:
          follow_redirects: true
        # Custom message template
        title: '{{ .GroupLabels.alertname }}'
        text: |
          {{ range .Alerts }}
          Status: {{ .Status }}
          Severity: {{ .Labels.severity }}
          Summary: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
```

### 2. Test Alerts

```bash
# Trigger test alert
curl -X POST http://localhost:9093/api/v1/alerts -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning"
  },
  "annotations": {
    "summary": "Test alert from Alertmanager"
  }
}]'
```

## Useful Queries

### User Statistics

```promql
# Total registered users
synapse_admin_mau_current

# Daily active users
synapse_admin_mau_current_mau_by_service{job="synapse"}

# New registrations (last 24h)
increase(synapse_admin_mau_current[24h])
```

### Performance Metrics

```promql
# Request latency (p95)
histogram_quantile(0.95, rate(synapse_http_server_request_duration_seconds_bucket[5m]))

# Database query time
rate(synapse_storage_schedule_time_sum[5m]) / rate(synapse_storage_schedule_time_count[5m])

# Cache hit rate
rate(synapse_util_caches_cache_hits[5m]) / (rate(synapse_util_caches_cache_hits[5m]) + rate(synapse_util_caches_cache_misses[5m]))
```

### Federation Metrics

```promql
# Outbound federation transactions
rate(synapse_federation_client_sent_transactions_total[5m])

# Inbound federation transactions
rate(synapse_federation_server_received_pdus_total[5m])

# Federation queue size
synapse_federation_transaction_queue_pending_pdus
```

### Resource Usage

```promql
# PostgreSQL connections
synapse_database_connections

# Redis memory
redis_memory_used_bytes / 1024 / 1024

# Disk I/O
rate(node_disk_io_time_seconds_total[5m])
```

## Troubleshooting

### Prometheus Not Scraping

```bash
# Check Prometheus logs
docker compose logs prometheus

# Check Synapse metrics endpoint
curl http://localhost:9000/_synapse/metrics

# Verify Prometheus config
docker exec matrix-prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Grafana Can't Connect to Prometheus

```bash
# Check network connectivity
docker exec matrix-grafana ping prometheus

# Check Prometheus is running
docker compose ps prometheus

# Verify datasource config
cat grafana/provisioning/datasources/prometheus.yml
```

### Alerts Not Firing

```bash
# Check Alertmanager status
curl http://localhost:9093/api/v1/status

# View active alerts
curl http://localhost:9093/api/v1/alerts

# Check alert rules
docker exec matrix-prometheus promtool check rules /etc/prometheus/alert_rules.yml
```

## Best Practices

1. **Set retention period** — Default 30 days di Prometheus
2. **Create dashboards per team** — Separate admin vs ops views
3. **Use labels** — Tag alerts dengan severity, team, service
4. **Alert fatigue** — Jangan terlalu banyak alerts, fokus ke critical
5. **Regular review** — Review metrics weekly untuk trend analysis
6. **Backup Grafana** — Export dashboards as JSON
7. **Document queries** — Simpan useful queries di wiki/docs

## Advanced: Custom Exporter

Jika ingin metrics custom (misal: business metrics):

```python
# custom_exporter.py
from prometheus_client import start_http_server, Gauge
import time

# Define metric
active_rooms = Gauge('matrix_active_rooms', 'Number of active rooms')

def collect_metrics():
    # Query Synapse database
    # Update metric
    active_rooms.set(1234)

if __name__ == '__main__':
    start_http_server(8000)
    while True:
        collect_metrics()
        time.sleep(60)
```

Tambahkan ke `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'custom-metrics'
    static_configs:
      - targets: ['custom-exporter:8000']
```

## Resources

- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
- [Synapse Metrics Documentation](https://matrix-org.github.io/synapse/latest/metrics-howto.html)
- [Official Synapse Dashboard](https://grafana.com/grafana/dashboards/14927)
