# 🔄 Sliding Sync Migration Guide

## Problem: "Legacy sliding sync is no longer supported"

If you see this error when logging in or registering, it's because **Synapse now has native sliding sync built-in** and the old external proxy is deprecated.

---

## ✅ Solution: Enable Native Sliding Sync

### Step 1: Update homeserver.yaml

The configuration has been updated to enable native sliding sync:

```yaml
## Experimental Features ##
experimental_features:
  # Native Sliding Sync (MSC3575) - replaces external sliding-sync proxy
  msc3575_enabled: true
```

### Step 2: Apply Configuration

```bash
cd ~/Selfhost-Matrix
git pull origin main

# Re-run setup to apply changes
bash setup.sh

# Restart Synapse
docker compose restart synapse synapse-worker-generic synapse-worker-media synapse-worker-federation-sender
```

### Step 3: Clear Browser Data

**Important:** You must clear your browser's data for Element to use the new sliding sync:

1. Open Element Web
2. **Logout** completely
3. Clear browser cache (Ctrl+Shift+Del)
4. **Login again**

Or use incognito/private mode to test.

---

## 🔧 What Changed?

### Before (Legacy)
- External `sliding-sync` proxy container
- Separate database `syncv3`
- Traefik routes to proxy
- Element config: `feature_sliding_sync: true`

### After (Native)
- Built-in Synapse sliding sync
- No external proxy needed
- Direct Synapse API
- Element config: `feature_sliding_sync: true` (same)

---

## 🗑️ Optional: Remove Old Sliding Sync Proxy

If you want to clean up the old proxy (optional):

```bash
# Stop and remove sliding-sync container
docker compose stop sliding-sync
docker compose rm -f sliding-sync

# Remove from docker-compose.yml (optional)
# Comment out or remove the sliding-sync service section
```

**Note:** The old proxy won't interfere, so you can leave it if you want.

---

## ✅ Verification

### Check Native Sliding Sync is Enabled

```bash
# Check homeserver.yaml
docker exec matrix-synapse grep -A 3 "experimental_features" /data/homeserver.yaml

# Should show:
# experimental_features:
#   msc3575_enabled: true
```

### Test Login

1. Logout from Element
2. Clear browser cache
3. Login again
4. Should work without "legacy sliding sync" error

### Check Element Config

```bash
# Verify Element config
cat element/config.json | grep sliding

# Should show:
# "feature_sliding_sync": true
```

---

## 🐛 Troubleshooting

### Still Getting "Legacy" Error

**Solution:** Clear browser data completely

```bash
# Chrome/Edge
Ctrl+Shift+Del → Clear all data

# Firefox
Ctrl+Shift+Del → Clear all data

# Or use Incognito/Private mode
```

### Sliding Sync Not Working

**Check Synapse logs:**

```bash
docker logs matrix-synapse | grep -i "sliding\|msc3575"
```

**Verify config applied:**

```bash
docker exec matrix-synapse cat /data/homeserver.yaml | grep -A 3 experimental
```

### Element Shows "Sliding Sync: Disabled"

**Check Element config:**

```bash
cat element/config.json | jq '.setting_defaults'

# Should show:
# {
#   "feature_sliding_sync": true
# }
```

---

## 📊 Benefits of Native Sliding Sync

✅ **Faster** - No proxy overhead  
✅ **Simpler** - One less container  
✅ **More stable** - Built into Synapse  
✅ **Better maintained** - Official Synapse feature  
✅ **Lower memory** - No separate process  

---

## 🔄 Migration Checklist

- [x] Added `msc3575_enabled: true` to homeserver.yaml
- [ ] Ran `bash setup.sh` to apply config
- [ ] Restarted Synapse containers
- [ ] Logged out from Element
- [ ] Cleared browser cache
- [ ] Logged back in
- [ ] Verified no "legacy" error
- [ ] (Optional) Removed old sliding-sync container

---

## 📚 References

- [MSC3575: Sliding Sync](https://github.com/matrix-org/matrix-spec-proposals/pull/3575)
- [Synapse Sliding Sync Docs](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#experimental_features)
- [Element Sliding Sync Guide](https://element.io/blog/element-sliding-sync/)

---

**Done! Your Matrix server now uses native sliding sync.** 🚀
