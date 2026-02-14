# 🏠 Matrix Server — Production-Ready Template

A complete, production-grade [Matrix](https://matrix.org) homeserver deployment template with **Synapse**, **Element Web**, monitoring, security hardening, and automated operations.

## 🧩 Architecture

```
                    Internet (80/443/8448)
                            ↓
                    ┌───────────────┐
                    │   Traefik     │  ← Auto SSL, Load Balancer
                    │ (Reverse Proxy)│    Federation (8448)
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────┴────────┐  ┌───────┴────────┐  ┌──────┴──────┐
│  Synapse Main  │  │ Synapse Workers│  │   Element   │
│  + 3 Workers   │  │ (Generic,Media,│  │   Web       │
│                │  │  Fed Sender)   │  │             │
└───────┬────────┘  └───────┬────────┘  └─────────────┘
        │                   │
        └───────────┬───────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
┌───┴────┐  ┌───────┴──────┐  ┌────┴─────┐
│Postgres│  │    Redis     │  │  Coturn  │
│  SQL   │  │   (Workers)  │  │  (TURN)  │
└────────┘  └──────────────┘  └──────────┘

Additional Services:
• Jitsi Meet (4 containers): web, prosody, jicofo, jvb
• Sliding Sync Proxy: 10x faster client sync
• Dimension: Integration manager
• Monitoring: Prometheus, Grafana, Alertmanager, Node Exporter
• Management: pgAdmin, Synapse Admin
```

**Total: 22 services, 21 running containers**

**Security:** Traefik auto-SSL + Fail2ban + UFW Firewall + Rate Limiting  
**Operations:** Automated backups + Health checks + Resource monitoring

## 📋 Services

### Core Services

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **Traefik** | `matrix-traefik` | 80, 443, 8448 | Reverse proxy + Auto SSL |
| **Synapse** | `matrix-synapse` | 8008 | Matrix homeserver (main) |
| **Synapse Worker (Generic)** | `matrix-synapse-worker-generic` | 8009 | Client/federation requests |
| **Synapse Worker (Media)** | `matrix-synapse-worker-media` | 8010 | Media uploads/downloads |
| **Synapse Worker (Fed Sender)** | `matrix-synapse-worker-federation-sender` | - | Outbound federation |
| **Element** | `matrix-element` | 8080 | Web client |
| **Dimension** | `matrix-dimension` | 8184 | Integration manager |
| **Sliding Sync** | `matrix-sliding-sync` | 8009 | Fast sync proxy |

### Video Conferencing

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **Jitsi Web** | `matrix-jitsi-web` | 80 | Jitsi web UI |
| **Jitsi Prosody** | `matrix-jitsi-prosody` | 5280 | XMPP server |
| **Jitsi Jicofo** | `matrix-jitsi-jicofo` | - | Conference focus |
| **Jitsi JVB** | `matrix-jitsi-jvb` | 10000/udp | Video bridge |

### Infrastructure

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **PostgreSQL** | `matrix-postgres` | 5432 | Database |
| **Redis** | `matrix-redis` | 6379 | Cache + worker coordination |
| **Coturn** | `matrix-coturn` | 3478, 5349 | TURN/STUN server |

### Monitoring & Management

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **Prometheus** | `matrix-prometheus` | 9090 | Metrics collection |
| **Grafana** | `matrix-grafana` | 3000 | Dashboards |
| **Alertmanager** | `matrix-alertmanager` | 9093 | Alert routing |
| **Node Exporter** | `matrix-node-exporter` | 9100 | System metrics |
| **pgAdmin** | `matrix-pgadmin` | 5050 | PostgreSQL manager |
| **Synapse Admin** | `matrix-synapse-admin` | 8888 | Admin panel |

## 🚀 Quick Start

### Prerequisites

- **Server**: Linux (Ubuntu/Debian recommended), 2+ GB RAM, 20+ GB disk
- **Docker** & **Docker Compose** v2+
- **Domain** with DNS A records for 3 subdomains pointing to your server

### 1. Clone & Configure

```bash
git clone https://github.com/iam-rizz/Selfhost-Matrix.git
cd Selfhost-Matrix

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

# Generate Traefik dashboard password (htpasswd format)
./scripts/generate-traefik-password.sh
# Follow the prompts and copy the output to your .env file
```

**Important:** Traefik dashboard password must be in **htpasswd hash format**, not plain text. See [docs/TRAEFIK_AUTH.md](docs/TRAEFIK_AUTH.md) for details.

### 3. Run Setup

```bash
chmod +x setup.sh
sudo ./setup.sh
```

The interactive setup script will:
- ✅ Validate your `.env` configuration
- ✅ Create data directories (postgres, redis, synapse, traefik, jitsi, workers, etc.)
- ✅ Substitute variables into all config templates
- ✅ Generate Synapse signing key
- ✅ Show Traefik auto-SSL information
- ✅ Optionally configure Fail2ban & UFW firewall
- ✅ Set up cron jobs for backup & monitoring

**Note:** Traefik will automatically request SSL certificates from Let's Encrypt when you start the services. No manual certbot needed!

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
├── docker-compose.yml              # All 22 services
├── setup.sh                        # Interactive bootstrap
├── README.md                       # This file
│
├── synapse/
│   ├── homeserver.yaml             # Synapse config (worker mode enabled)
│   └── log.config                  # Logging (rotating, 10MB)
│
├── workers/
│   ├── generic_worker.yaml         # Client/federation worker
│   ├── media_worker.yaml           # Media upload/download worker
│   ├── federation_sender.yaml      # Outbound federation worker
│   └── *_log.yaml                  # Worker log configs
│
├── traefik/
│   └── traefik.yml                 # Auto SSL + routing config
│
├── element/
│   └── config.json                 # Element Web config (Sliding Sync enabled)
│
├── dimension/
│   └── config.json                 # Dimension integration mgr
│
├── coturn/
│   └── turnserver.conf             # TURN/STUN server
│
├── postgres/
│   └── init-syncv3.sql             # Sliding Sync database init
│
├── nginx/                          # Legacy configs (optional, for migration)
│   ├── matrix-synapse.conf
│   ├── matrix-element.conf
│   └── matrix-dimension.conf
│
├── prometheus/
│   ├── prometheus.yml              # Scrape config (includes Traefik)
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
    ├── offsite-backup.sh           # Upload to S3/B2/Wasabi
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

### Core Guides
- **[Monitoring Guide](docs/MONITORING.md)** — Prometheus, Grafana, Alertmanager setup & queries
- **[Matrix Features](docs/MATRIX_FEATURES.md)** — Complete guide to Matrix capabilities & features
- **[Debugging Guide](docs/DEBUGGING.md)** — Start services one by one, troubleshooting & health checks

### Advanced Features
- **[Traefik Reverse Proxy](docs/TRAEFIK.md)** — Auto SSL, load balancing, dashboard & troubleshooting
- **[Sliding Sync Proxy](docs/SLIDING_SYNC.md)** — 10x faster sync for mobile clients
- **[Jitsi Meet](docs/JITSI.md)** — Self-hosted video conferencing setup & configuration
- **[Synapse Workers](docs/WORKERS.md)** — Horizontal scaling for high-traffic servers
- **[Fail2ban Notifications](docs/FAIL2BAN_NOTIFICATIONS.md)** — Enhanced Telegram alerts with geolocation

## 📜 License

MIT
