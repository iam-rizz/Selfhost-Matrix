# 🏃 Sliding Sync Proxy Guide

## What is Sliding Sync?

Sliding Sync adalah protokol baru untuk sync Matrix yang **10x lebih cepat** dari sync lama.

**Benefits:**
- ✅ **Instant room switching** — No loading delay
- ✅ **Faster initial sync** — 10x faster first load
- ✅ **Reduced bandwidth** — Only sync what's needed
- ✅ **Better mobile experience** — Less battery drain
- ✅ **Required for Element X** — Next-gen Matrix client

## How It Works

### Old Sync (v2)
```
Client: "Give me everything"
Server: *sends 100MB of data*
Client: *waits 30 seconds*
```

### Sliding Sync (v3)
```
Client: "Give me room list"
Server: *sends 10KB*
Client: *instant display*

Client: "Now give me messages for room A"
Server: *sends only room A data*
```

## Architecture

```
Element Web/Mobile
        ↓
  Sliding Sync Proxy (port 8009)
        ↓
    Synapse (port 8008)
        ↓
  PostgreSQL (syncv3 database)
```

## Configuration

### Database

Sliding Sync needs its own PostgreSQL database:

```sql
CREATE DATABASE syncv3;
GRANT ALL PRIVILEGES ON DATABASE syncv3 TO synapse;
```

**Auto-created** by `postgres/init-syncv3.sql` on first run.

### Environment Variables

```bash
SYNCV3_SERVER=http://synapse:8008
SYNCV3_DB=postgresql://user:pass@postgres:5432/syncv3
SYNCV3_SECRET=random-secret-key
SYNCV3_BINDADDR=0.0.0.0:8009
```

### Traefik Routing

Sliding Sync intercepts specific API path:

```yaml
traefik.http.routers.sliding-sync.rule=
  Host(`chat.domain.com`) && 
  PathPrefix(`/_matrix/client/unstable/org.matrix.msc3575`)
```

**Path:** `/_matrix/client/unstable/org.matrix.msc3575/sync`

## Element Configuration

Enable Sliding Sync in `element/config.json`:

```json
{
  "setting_defaults": {
    "feature_sliding_sync": true
  }
}
```

**Verify in Element:**
1. Open Element
2. Settings → Labs
3. Should see "Sliding Sync: Enabled"

## Testing

### Check Endpoint

```bash
# Test sliding sync endpoint
curl https://chat.yourdomain.com/_matrix/client/unstable/org.matrix.msc3575/sync \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Performance Comparison

**Without Sliding Sync:**
- Initial sync: ~30 seconds
- Room switch: 2-3 seconds
- Bandwidth: ~100MB

**With Sliding Sync:**
- Initial sync: ~3 seconds (10x faster)
- Room switch: Instant
- Bandwidth: ~10MB

## Monitoring

### Logs

```bash
# View sliding sync logs
docker compose logs sliding-sync

# Follow logs
docker compose logs -f sliding-sync
```

### Database Size

```bash
# Check syncv3 database size
docker exec matrix-postgres psql -U synapse -c "
  SELECT pg_size_pretty(pg_database_size('syncv3'));
"
```

### Metrics

Sliding Sync doesn't expose Prometheus metrics yet (as of 2024).

**Workaround:** Monitor via logs and database size.

## Troubleshooting

### Sliding Sync Not Working

```bash
# Check service is running
docker compose ps sliding-sync

# Check logs for errors
docker compose logs sliding-sync

# Verify database connection
docker exec matrix-sliding-sync env | grep SYNCV3_DB
```

### Element Not Using Sliding Sync

1. **Check Element config** — `feature_sliding_sync: true`
2. **Clear browser cache** — Hard refresh (Ctrl+Shift+R)
3. **Check network tab** — Should see requests to `org.matrix.msc3575`

### Database Connection Errors

```bash
# Check PostgreSQL is running
docker compose ps postgres

# Verify syncv3 database exists
docker exec matrix-postgres psql -U synapse -l | grep syncv3

# Test connection
docker exec matrix-postgres psql -U synapse -d syncv3 -c "SELECT 1;"
```

## Performance Tuning

### Database Optimization

```sql
-- Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_room_id ON syncv3_rooms(room_id);
CREATE INDEX IF NOT EXISTS idx_user_id ON syncv3_users(user_id);
```

### Memory Limits

```yaml
# docker-compose.yml
sliding-sync:
  deploy:
    resources:
      limits:
        memory: 512M
      reservations:
        memory: 256M
```

## Client Support

### Supported Clients

- ✅ **Element Web** — Enable in settings
- ✅ **Element X** — Native support (required)
- ✅ **Element Android** — Beta support
- ✅ **Element iOS** — Beta support

### Not Supported (Yet)

- ❌ FluffyChat
- ❌ Nheko
- ❌ SchildiChat (old version)

## Migration

### From Old Sync

No migration needed! Sliding Sync works alongside old sync.

**Clients auto-detect** and use Sliding Sync if available.

### Rollback

To disable Sliding Sync:

1. **Remove from Element config:**
   ```json
   "setting_defaults": {
     "feature_sliding_sync": false
   }
   ```

2. **Stop service:**
   ```bash
   docker compose stop sliding-sync
   ```

Clients will fall back to old sync automatically.

## Resources

- [Sliding Sync Spec (MSC3575)](https://github.com/matrix-org/matrix-spec-proposals/pull/3575)
- [Sliding Sync Proxy Repo](https://github.com/matrix-org/sliding-sync)
- [Element X Announcement](https://element.io/blog/element-x/)
