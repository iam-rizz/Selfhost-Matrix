# 🔧 Restart Instructions - Fix 500 Errors

## Problem
- Main Synapse still using OLD config with `stream_writers`
- Workers crashing with database serialization errors
- Getting 404 on replication endpoints

## Solution: Restart in Correct Order

```bash
cd ~/Selfhost-Matrix

# Pull latest config changes
git pull origin main

# Step 1: Stop ALL workers first
docker compose stop synapse-worker-generic synapse-worker-media synapse-worker-federation-sender

# Step 2: Restart MAIN Synapse (to load new config WITHOUT stream_writers)
docker compose restart synapse

# Step 3: Wait for main Synapse to be healthy
sleep 15
docker logs matrix-synapse --tail 20

# Step 4: Start workers (they will connect to updated main Synapse)
docker compose up -d synapse-worker-generic synapse-worker-media synapse-worker-federation-sender

# Step 5: Verify all healthy
sleep 10
docker compose ps | grep -E "synapse|worker"
```

## Expected Result

All containers should show **Up** and **(healthy)**:
```
matrix-synapse                            Up (healthy)
matrix-synapse-worker-generic             Up (healthy)
matrix-synapse-worker-media               Up (healthy)
matrix-synapse-worker-federation-sender   Up (healthy)
```

## Test

After restart, try:
1. ✅ Send message in Element
2. ✅ Make voice/video call
3. ✅ Check no 500 errors in browser console

---

**Why this order matters:**
1. Workers must stop BEFORE main Synapse restarts
2. Main Synapse needs to load new config WITHOUT stream_writers
3. Workers then connect to updated main Synapse with correct config
