# ⚙️ Synapse Workers Guide

## What are Workers?

Workers adalah **horizontal scaling** untuk Synapse — split workload ke multiple processes.

**Benefits:**
- ✅ **2-3x capacity** — Handle more concurrent users
- ✅ **Better performance** — Distribute CPU load
- ✅ **Separate concerns** — Isolate client/federation/media traffic
- ✅ **Fault tolerance** — One worker crash doesn't kill everything

## Architecture

```
Traefik (Load Balancer)
    ↓
┌───┴────┬──────────┬──────────────┐
↓        ↓          ↓              ↓
Main   Generic   Media    Federation
Process Worker   Worker   Sender
(8008)  (8009)   (8010)   (background)
    ↓       ↓        ↓         ↓
    └───────┴────────┴─────────┘
              ↓
          PostgreSQL
              ↓
            Redis (coordination)
```

## Worker Types

### 1. Generic Worker (Client/Federation)

**Handles:**
- Client API requests (`/_matrix/client/*`)
- Federation requests (`/_matrix/federation/*`)
- Presence updates
- Typing notifications
- Read receipts

**Port:** 8009

**Config:** `workers/generic_worker.yaml`

### 2. Media Worker

**Handles:**
- Media uploads (`POST /_matrix/media/upload`)
- Media downloads (`GET /_matrix/media/download`)
- Thumbnails (`GET /_matrix/media/thumbnail`)

**Port:** 8010

**Config:** `workers/media_worker.yaml`

**Note:** Main process has `enable_media_repo: false`

### 3. Federation Sender

**Handles:**
- Outbound federation transactions
- Sending events to other homeservers
- Retry logic for failed sends

**No HTTP port** — Background worker only

**Config:** `workers/federation_sender.yaml`

## Configuration

### Main Synapse Config

`synapse/homeserver.yaml` has worker mode enabled:

```yaml
instance_map:
  main:
    host: synapse
    port: 8008
  generic_worker1:
    host: synapse-worker-generic
    port: 8009
  media_worker:
    host: synapse-worker-media
    port: 8010

stream_writers:
  typing: generic_worker1
  to_device: generic_worker1
  account_data: generic_worker1
  receipts: generic_worker1
  presence: generic_worker1

federation_sender_instances:
  - federation_sender1

enable_media_repo: false  # Handled by media worker
```

### Worker Configs

Each worker has its own YAML file:

**Generic Worker:**
```yaml
worker_app: synapse.app.generic_worker
worker_name: generic_worker1
worker_listeners:
  - type: http
    port: 8009
    resources:
      - names: [client, federation]
```

**Media Worker:**
```yaml
worker_app: synapse.app.generic_worker
worker_name: media_worker
worker_listeners:
  - type: http
    port: 8010
    resources:
      - names: [media]
enable_media_repo: true
```

**Federation Sender:**
```yaml
worker_app: synapse.app.federation_sender
worker_name: federation_sender1
# No HTTP listener — background only
```

### Redis Coordination

Workers use Redis for inter-process communication:

```yaml
redis:
  enabled: true
  host: redis
  port: 6379
  password: "your-password"
```

**Required** for workers to coordinate.

## Load Balancing

Traefik distributes requests to workers:

### Client Requests → Generic Worker

```yaml
traefik.http.routers.synapse-worker.rule=
  Host(`chat.domain.com`) && 
  PathPrefix(`/_matrix/client`, `/_synapse/client`)

traefik.http.services.synapse-workers.loadbalancer.sticky.cookie=true
```

**Sticky sessions:** Same user → same worker (via cookie)

### Media Requests → Media Worker

```yaml
traefik.http.routers.synapse-media.rule=
  Host(`chat.domain.com`) && 
  PathPrefix(`/_matrix/media`)
```

**All media traffic** goes to media worker.

### Server API → Main Process

```yaml
traefik.http.routers.synapse.rule=
  Host(`chat.domain.com`)
```

**Fallback:** Everything else goes to main process.

## Scaling Workers

### Add More Generic Workers

1. **Create config:** `workers/generic_worker2.yaml`
   ```yaml
   worker_name: generic_worker2
   worker_listeners:
     - type: http
       port: 8011
   ```

2. **Add to docker-compose:**
   ```yaml
   synapse-worker-generic-2:
     image: matrixdotorg/synapse:latest
     command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/generic_worker2.yaml
     # ... same as generic_worker1
   ```

3. **Update instance_map:**
   ```yaml
   instance_map:
     generic_worker2:
       host: synapse-worker-generic-2
       port: 8011
   ```

4. **Traefik auto-balances** across all workers with same service name.

### Recommended Scaling

**Small server (<100 users):**
- 1 generic worker
- 1 media worker
- 1 federation sender

**Medium server (100-1000 users):**
- 2-3 generic workers
- 1-2 media workers
- 1-2 federation senders

**Large server (>1000 users):**
- 5+ generic workers
- 2-3 media workers
- 2-3 federation senders
- Consider event persister workers

## Monitoring

### Worker Logs

```bash
# Generic worker
tail -f synapse-data/logs/generic_worker.log

# Media worker
tail -f synapse-data/logs/media_worker.log

# Federation sender
tail -f synapse-data/logs/federation_sender.log
```

### Docker Stats

```bash
# CPU/RAM usage per worker
docker stats matrix-synapse matrix-synapse-worker-generic matrix-synapse-worker-media
```

### Prometheus Metrics

Workers expose metrics on their HTTP ports.

**Add to Prometheus:**
```yaml
scrape_configs:
  - job_name: 'synapse-workers'
    static_configs:
      - targets:
        - 'synapse-worker-generic:8009'
        - 'synapse-worker-media:8010'
```

**Metrics:**
- `synapse_http_server_requests_total{worker="generic_worker1"}`
- `synapse_storage_events_persisted_events_total`
- `synapse_federation_client_sent_transactions_total`

### Grafana Dashboard

Import Synapse dashboard (ID 14927) — auto-detects workers.

**Panels:**
- Worker CPU usage
- Requests per worker
- Load distribution

## Troubleshooting

### Worker Not Starting

```bash
# Check worker logs
docker compose logs synapse-worker-generic

# Common issues:
# - Config file not found
# - Redis connection failed
# - Port already in use
```

**Fix:** Verify config path in docker-compose `command`.

### Requests Not Load Balanced

```bash
# Check Traefik dashboard
https://traefik.yourdomain.com/dashboard/

# Verify worker is registered
docker exec matrix-traefik wget -O- http://synapse-worker-generic:8009/health
```

**Fix:** Check Traefik labels in docker-compose.

### Redis Connection Errors

```bash
# Check Redis is running
docker compose ps redis

# Test connection
docker exec matrix-redis redis-cli -a PASSWORD PING

# Check worker config
cat workers/generic_worker.yaml | grep redis
```

**Fix:** Verify Redis password in worker configs.

### High CPU on Main Process

**Symptom:** Main process still at 100% CPU despite workers.

**Cause:** Requests not routed to workers.

**Fix:**
1. Check Traefik routing rules
2. Verify `instance_map` in homeserver.yaml
3. Check worker listeners are correct

### Worker Crashes

```bash
# Check crash logs
docker compose logs synapse-worker-generic | grep -i error

# Common causes:
# - Out of memory
# - Database connection lost
# - Redis connection lost
```

**Fix:** Increase memory limits or check database/Redis health.

## Performance Tuning

### Worker Resource Limits

```yaml
synapse-worker-generic:
  deploy:
    resources:
      limits:
        cpus: '1'
        memory: 1G
      reservations:
        memory: 512M
```

### Database Connection Pooling

Each worker needs database connections:

```yaml
# homeserver.yaml
database:
  args:
    cp_min: 5
    cp_max: 10  # Per worker!
```

**Total connections:** `(workers + 1) * cp_max`

**PostgreSQL max_connections** should be higher:
```sql
ALTER SYSTEM SET max_connections = 200;
```

### Redis Memory

Workers use Redis for caching:

```yaml
redis:
  maxmemory: 512mb
  maxmemory-policy: allkeys-lru
```

## Advanced: Event Persister Workers

For **very high traffic** servers, separate event writing:

```yaml
# workers/event_persister.yaml
worker_app: synapse.app.generic_worker
worker_name: event_persister1
worker_listeners:
  - type: http
    port: 8012
    resources:
      - names: [replication]
```

**Update homeserver.yaml:**
```yaml
stream_writers:
  events: event_persister1
```

**Complex setup** — Only needed for >1000 concurrent users.

## Rollback to Single Process

To disable workers:

1. **Stop workers:**
   ```bash
   docker compose stop synapse-worker-generic synapse-worker-media synapse-worker-federation-sender
   ```

2. **Update homeserver.yaml:**
   ```yaml
   # Comment out worker config
   # instance_map: ...
   # stream_writers: ...
   
   # Re-enable media repo
   enable_media_repo: true
   ```

3. **Restart main process:**
   ```bash
   docker compose restart synapse
   ```

## Resources

- [Synapse Workers Docs](https://matrix-org.github.io/synapse/latest/workers.html)
- [Worker Types Reference](https://matrix-org.github.io/synapse/latest/workers.html#available-worker-applications)
- [Scaling Synapse Guide](https://matrix-org.github.io/synapse/latest/usage/administration/understanding_synapse_through_grafana_graphs.html)
