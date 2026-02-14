# 🏠 Matrix Server — Production-Ready Template

A complete, production-grade [Matrix](https://matrix.org) homeserver deployment template with **Synapse**, **Element Web**, monitoring, security hardening, and automated operations.

## 🧩 Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Element Web │     │  Synapse     │     │  Dimension   │
│  (Client)    │     │  (Homeserver)│     │  (Integr.)   │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────┬───────────┴────────────────────┘
                │
         ┌──────┴───────┐
         │    Nginx      │  ← SSL/TLS, Federation (8448)
         │  (Reverse     │    .well-known, Security Headers
         │   Proxy)      │
         └──────┬────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───┴───┐  ┌───┴───┐  ┌───┴───┐
│Postgre│  │ Redis │  │Coturn │
│  SQL  │  │       │  │(TURN) │
└───────┘  └───────┘  └───────┘
```

**Monitoring:** Prometheus + Grafana + Alertmanager + Node Exporter
**Security:** Fail2ban (with Telegram alerts) + UFW Firewall + Rate Limiting
**Operations:** Automated backups + Health checks + Resource monitoring

## 📋 Services

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **Synapse** | `matrix-synapse` | 8008 | Matrix homeserver |
| **Element** | `matrix-element` | 8080 | Web client |
| **Dimension** | `matrix-dimension` | 8184 | Integration manager |
| **Synapse Admin** | `matrix-synapse-admin` | 8888 | Admin panel |
| **PostgreSQL** | `matrix-postgres` | 5432 | Database |
| **pgAdmin** | `matrix-pgadmin` | 5050 | PostgreSQL manager |
| **Redis** | `matrix-redis` | 6379 | Cache |
| **Coturn** | `matrix-coturn` | 3478, 5349 | TURN/STUN server |
| **Prometheus** | `matrix-prometheus` | 9090 | Metrics |
| **Grafana** | `matrix-grafana` | 3000 | Dashboards |
| **Alertmanager** | `matrix-alertmanager` | 9093 | Alerts |
| **Node Exporter** | `matrix-node-exporter` | 9100 | System metrics |

## 🚀 Quick Start

### Prerequisites

- **Server**: Linux (Ubuntu/Debian recommended), 2+ GB RAM, 20+ GB disk
- **Docker** & **Docker Compose** v2+
- **Domain** with DNS A records for 3 subdomains pointing to your server

### 1. Clone & Configure

```bash
git clone https://github.com/YOUR_USERNAME/Matrix.org-server.git
cd Matrix.org-server

# Create your configuration
cp .env.example .env
nano .env  # Fill in your domain, passwords, and secrets
```

### 2. Generate Secrets

```bash
# Generate random secrets for .env
echo "SYNAPSE_REGISTRATION_SHARED_SECRET=$(openssl rand -hex 32)"
echo "SYNAPSE_MACAROON_SECRET_KEY=$(openssl rand -hex 32)"
echo "SYNAPSE_FORM_SECRET=$(openssl rand -hex 32)"
echo "TURN_SECRET=$(openssl rand -hex 32)"
echo "DIMENSION_API_SECRET=$(openssl rand -hex 16)"
echo "REDIS_PASSWORD=$(openssl rand -hex 16)"
```

### 3. Run Setup

```bash
chmod +x setup.sh
sudo ./setup.sh
```

The interactive setup script will:
- ✅ Validate your `.env` configuration
- ✅ Create data directories
- ✅ Substitute variables into all config templates
- ✅ Generate Synapse signing key
- ✅ Optionally install Nginx, Certbot, Fail2ban, UFW
- ✅ Obtain SSL certificates
- ✅ Start all Docker services
- ✅ Set up cron jobs for backup & monitoring

### 4. Create Admin User

```bash
docker exec -it matrix-synapse register_new_matrix_user \
    -c /data/homeserver.yaml http://localhost:8008 -a
```

### 5.## Verify Deployment

```bash
# Check all containers are running
docker compose ps

# Check Synapse health
curl http://localhost:8008/health

# View logs
docker compose logs -f synapse
```

### Access Admin Interfaces

All admin interfaces are localhost-only. Use SSH tunnel for remote access:

```bash
# SSH tunnel example (from your local machine)
ssh -L 8888:localhost:8888 -L 3000:localhost:3000 -L 5050:localhost:5050 user@your-server
```

Then access:
- **Synapse Admin**: `http://localhost:8888`
- **Grafana**: `http://localhost:3000` (user: admin, password from `.env`)
- **pgAdmin**: `http://localhost:5050` (PostgreSQL manager)
- **Prometheus**: `http://localhost:9090`

#### pgAdmin Setup

1. Login with credentials from `.env`:
   - Email: `PGADMIN_DEFAULT_EMAIL`
   - Password: `PGADMIN_DEFAULT_PASSWORD`

2. Add PostgreSQL server:
   - Right-click "Servers" → "Register" → "Server"
   - **General** tab: Name = `Matrix PostgreSQL`
   - **Connection** tab:
     - Host: `matrix-postgres`
     - Port: `5432`
     - Username: `synapse` (from `.env`)
     - Password: `POSTGRES_PASSWORD` (from `.env`)
     - Save password: ✓
# Test Federation
curl -s https://chat.YOUR_DOMAIN:8448/_matrix/federation/v1/version | jq .

# Federation Tester
# Visit: https://federationtester.matrix.org/api/report?server_name=YOUR_DOMAIN

## 📁 Project Structure

```
├── .env.example                    # Configuration template
├── .gitignore                      # Ignore secrets & data
├── docker-compose.yml              # All 11 services
├── setup.sh                        # Interactive bootstrap
├── README.md                       # This file
│
├── synapse/
│   ├── homeserver.yaml             # Synapse config
│   └── log.config                  # Logging (rotating, 10MB)
│
├── element/
│   └── config.json                 # Element Web config
│
├── dimension/
│   └── config.json                 # Dimension integration mgr
│
├── coturn/
│   └── turnserver.conf             # TURN/STUN server
│
├── nginx/
│   ├── matrix-synapse.conf         # Synapse + .well-known + 8448
│   ├── matrix-element.conf         # Element Web
│   └── matrix-dimension.conf       # Dimension
│
├── prometheus/
│   ├── prometheus.yml              # Scrape config
│   └── alert_rules.yml             # Alert definitions
│
├── alertmanager/
│   └── alertmanager.yml            # Alert routing
│
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── prometheus.yml      # Auto-provisioned datasource
│
├── fail2ban/
│   ├── filter.d/matrix-synapse.conf
│   ├── jail.d/matrix-synapse.conf
│   └── action.d/telegram.conf      # Telegram ban notifications
│
└── scripts/
    ├── backup-postgres.sh          # Daily encrypted backups
    ├── health-check.sh             # Service health monitoring
    └── monitor-resources.sh        # RAM/disk alerting
```

## 🔒 Security Features

- **TLS 1.2/1.3 only** with strong cipher suites
- **HSTS** with preload, **CSP**, **X-Frame-Options**, **X-Content-Type-Options**
- **OCSP Stapling** for SSL
- **Fail2ban** with Synapse login filter (5 retries → 1hr ban)
- **Telegram notifications** on ban/unban events
- **Rate limiting** on login (5/min), registration (3/min), messages (5/sec)
- **Public registration disabled** by default
- **UFW firewall** — only 80, 443, 8448, SSH, TURN ports exposed
- **All internal ports** bound to `127.0.0.1` — not publicly accessible
- **Encrypted backups** with GPG

## 📊 Monitoring & Alerts

### Prometheus Alert Rules

| Alert | Condition | Severity |
|---|---|---|
| SynapseDown | Unreachable > 1m | 🔴 Critical |
| SynapseHighCPU | CPU > 80% for 5m | 🟡 Warning |
| SynapseHighMemory | RAM > 2GB for 5m | 🟡 Warning |
| FederationErrors | High failure rate 10m | 🟡 Warning |
| HighDiskUsage | < 15% free | 🟡 Warning |
| HighMemoryUsage | > 85% used | 🟡 Warning |
| NodeExporterDown | Unreachable > 2m | 🔴 Critical |

### Cron Jobs

| Schedule | Script | Purpose |
|---|---|---|
| `0 3 * * *` | `backup-postgres.sh` | Daily DB backup + GPG encrypt |
| `*/5 * * * *` | `health-check.sh` | Container + API health check |
| `*/10 * * * *` | `monitor-resources.sh` | RAM/disk threshold alerts |

## 🛠️ Maintenance

### Backup & Restore

```bash
# Manual backup
./scripts/backup-postgres.sh

# Restore from encrypted backup
gpg --decrypt backups/synapse_db_YYYYMMDD_HHMMSS.sql.gz.gpg | gunzip | \
    docker exec -i matrix-postgres psql -U synapse -d synapse
```

### Offsite Backup with rclone

```bash
# Install rclone
apt install rclone -y

# Configure remote (S3, Backblaze B2, Wasabi, etc.)
rclone config

# Update .env with remote name
RCLONE_REMOTE=offsite
RCLONE_PATH=matrix-backup

# Test upload
./scripts/offsite-backup.sh

# Add to cron (daily at 4 AM)
0 4 * * * /path/to/scripts/offsite-backup.sh >> /path/to/logs/offsite.log 2>&1
```

### Update Services

```bash
docker compose pull
docker compose up -d
```

### View Logs

```bash
docker compose logs -f synapse        # Synapse logs
docker compose logs -f postgres       # PostgreSQL logs
sudo fail2ban-client status matrix-synapse  # Fail2ban status
```

### Dimension Setup

After Synapse is running, create a bot user for Dimension:

```bash
# Register the dimension user
docker exec -it matrix-synapse register_new_matrix_user \
    -c /data/homeserver.yaml http://localhost:8008

# Get access token (login as the dimension user)
curl -s -X POST "http://localhost:8008/_matrix/client/r0/login" \
    -H "Content-Type: application/json" \
    -d '{"type":"m.login.password","user":"dimension","password":"YOUR_PASSWORD"}' \
    | jq -r '.access_token'

# Update DIMENSION_ACCESS_TOKEN in .env, re-run setup.sh, restart dimension
docker compose restart dimension
```

## 📚 Documentation

- **[Monitoring Guide](docs/MONITORING.md)** — Prometheus, Grafana, Alertmanager setup & queries
- **[Matrix Features](docs/MATRIX_FEATURES.md)** — Complete guide to Matrix capabilities & features

## 📜 License

MIT
