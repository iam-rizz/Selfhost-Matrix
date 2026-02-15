# Synapse Monitoring Dashboard Setup

## Official Synapse Dashboard

**Dashboard ID:** 3387  
**Name:** Synapse  
**URL:** https://grafana.com/grafana/dashboards/3387

## Import Dashboard

### Via Grafana UI

1. Access Grafana: `http://localhost:3000`
2. Login with admin credentials
3. Go to **Dashboards** → **Import**
4. Enter dashboard ID: `3387`
5. Click **Load**
6. Select Prometheus datasource
7. Click **Import**

### Via Provisioning (Automated)

Dashboard will be automatically loaded from `grafana/provisioning/dashboards/synapse.json`

## Dashboard Features

- **Server Stats:** CPU, Memory, Disk usage
- **Synapse Metrics:**
  - Active users (DAU, MAU)
  - Rooms count
  - Events rate
  - Federation stats
- **Database Performance:**
  - Query time
  - Connection pool
  - Transaction rate
- **Cache Performance:**
  - Hit rate
  - Size
  - Evictions

## Alternative Dashboards

### 1. Synapse (ID: 3387) - Official ✅ RECOMMENDED
- Most comprehensive
- Maintained by Matrix.org
- All Synapse metrics

### 2. Matrix Synapse (ID: 10046)
- Alternative community dashboard
- Different layout
- Similar metrics

### 3. Custom Dashboard
- Create your own
- Customize panels
- Focus on specific metrics

## Prometheus Queries

### Active Users
```promql
synapse_admin_mau:current
```

### Request Rate
```promql
rate(synapse_http_server_requests_total[5m])
```

### Database Connections
```promql
synapse_database_connections
```

### Federation Lag
```promql
synapse_federation_client_sent_transactions_total
```

## Troubleshooting

### Dashboard Not Loading

**Check Prometheus datasource:**
```bash
# Access Grafana
http://localhost:3000

# Go to: Configuration → Data Sources
# Verify Prometheus URL: http://prometheus:9090
```

### No Data Showing

**Verify Synapse metrics:**
```bash
# Check Prometheus targets
http://localhost:9090/targets

# Should show synapse:9000 as UP
```

**Check Synapse metrics endpoint:**
```bash
curl http://localhost:9000/metrics
# Should return Prometheus metrics
```

### Wrong Dashboard (JMeter 14927)

**Remove wrong dashboard:**
1. Go to Dashboards
2. Find JMeter dashboard
3. Click settings (gear icon)
4. Delete dashboard

**Import correct dashboard:**
- Use ID: **3387** (Synapse)
- NOT 14927 (JMeter)

## Quick Setup

```bash
# Access Grafana
http://localhost:3000

# Login
User: admin
Password: <from GF_SECURITY_ADMIN_PASSWORD in .env>

# Import Synapse dashboard
1. Click "+" → Import
2. Enter: 3387
3. Click Load
4. Select Prometheus
5. Click Import

# Done! Dashboard ready
```
