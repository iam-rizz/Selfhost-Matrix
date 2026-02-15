# 🚨 Coturn Extreme Memory Usage Fix

## Problem

Coturn consuming **16GB RAM** immediately on startup, causing system to run out of memory.

**Normal usage:** 50-100MB  
**Your usage:** 16GB (160x normal!)

---

## Emergency Fix (Immediate)

### Option 1: Disable Coturn Temporarily

```bash
# Stop Coturn
docker compose stop coturn

# System should recover immediately
free -h
```

**Note:** Voice/video calls won't work without TURN server, but Matrix chat will work fine.

---

### Option 2: Use Docker Memory Limit

Add strict memory limit to prevent system crash:

```yaml
# docker-compose.yml
coturn:
  deploy:
    resources:
      limits:
        memory: 256M  # Hard limit
```

Then:
```bash
docker compose up -d coturn
docker stats matrix-coturn  # Monitor
```

If it hits 256MB limit, container will restart (but won't crash system).

---

## Root Cause Analysis

### Check Current Config

```bash
# Check port range in .env
grep TURN .env

# Check actual config
cat coturn/turnserver.conf | grep -E "min-port|max-port|verbose"

# Check container stats
docker stats matrix-coturn --no-stream
```

### Common Causes

1. **Massive Port Range (16K ports)**
   ```bash
   TURN_MIN_PORT=49152
   TURN_MAX_PORT=65535  # ← 16,383 ports!
   ```
   Each port allocates memory. 16K ports = massive overhead.

2. **Verbose Logging**
   ```conf
   verbose  # ← Logs everything, fills memory
   ```

3. **No Connection Limits**
   ```conf
   # Missing:
   user-quota=10
   total-quota=100
   ```

4. **Coturn Image Bug**
   `coturn/coturn:latest` might have memory leak bug.

---

## Permanent Fix

### Step 1: Update .env

```bash
cd ~/Selfhost-Matrix
nano .env
```

Change:
```bash
# Old (BAD)
TURN_MAX_PORT=65535

# New (GOOD)
TURN_MAX_PORT=50151  # Only 1000 ports
```

### Step 2: Regenerate Config

```bash
./setup.sh
```

This will update `coturn/turnserver.conf` with:
- Reduced port range
- Disabled verbose logging
- Added connection limits

### Step 3: Add Docker Memory Limit

Edit `docker-compose.yml`:

```yaml
coturn:
  image: coturn/coturn:latest
  container_name: matrix-coturn
  restart: unless-stopped
  deploy:
    resources:
      limits:
        memory: 256M
        cpus: '0.5'
      reservations:
        memory: 128M
        cpus: '0.25'
  # ... rest of config
```

### Step 4: Restart Coturn

```bash
docker compose up -d coturn
```

### Step 5: Monitor

```bash
# Watch memory usage (should stay < 100MB)
watch -n 2 docker stats matrix-coturn

# Check logs for errors
docker logs -f matrix-coturn
```

---

## Alternative: Use Different TURN Server

If Coturn continues to leak, consider alternatives:

### 1. eturnal (Erlang-based, very efficient)

```yaml
coturn:
  image: ghcr.io/processone/eturnal:latest
  # Much lower memory usage
```

### 2. Disable TURN Completely

If you don't need voice/video calls:

```yaml
# Comment out coturn service
# coturn:
#   image: coturn/coturn:latest
#   ...
```

Update `synapse/homeserver.yaml`:
```yaml
# Comment out TURN config
# turn_uris:
#   - "turn:..."
```

---

## Verification

After fix, verify memory usage:

```bash
# Should show ~50-100MB for coturn
docker stats --no-stream

# Total system memory
free -h

# Coturn specific
docker exec matrix-coturn ps aux
```

**Expected result:**
```
CONTAINER         MEM USAGE / LIMIT
matrix-coturn     87.5MiB / 256MiB
```

---

## Why This Happens

Coturn allocates memory for:
1. **Socket buffers** for each port (16K ports = huge overhead)
2. **Session tracking** (verbose logging stores everything)
3. **Connection state** (no limits = unlimited memory)

**Math:**
- 16,383 ports × ~1MB per port = 16GB+ memory
- With 1,000 ports × ~100KB per port = 100MB memory ✅

---

## Quick Reference

**Stop Coturn:**
```bash
docker compose stop coturn
```

**Start with limits:**
```bash
docker compose up -d coturn
```

**Monitor:**
```bash
docker stats matrix-coturn
```

**Check config:**
```bash
cat coturn/turnserver.conf
```
