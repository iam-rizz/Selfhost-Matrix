# 🔧 Quick Fix: "Legacy Sliding Sync" Error

## Problem
Getting "Legacy sliding sync is no longer supported" error when logging in.

## ✅ Quick Solution (Run on Server)

```bash
# SSH to server
ssh your-server

cd ~/Selfhost-Matrix

# Edit Element config directly
nano element/config.json
```

**Find this section:**
```json
"setting_defaults": {
  "feature_sliding_sync": true
}
```

**Change to:**
```json
"setting_defaults": {
  "feature_sliding_sync": false
}
```

Or **completely remove** the `setting_defaults` section:
```json
"features": {
  "feature_jitsi": true
}
// Remove these lines:
// "setting_defaults": {
//   "feature_sliding_sync": true
// }
```

**Save:** Ctrl+O, Enter, Ctrl+X

## Restart Element

```bash
docker compose restart element
```

## Clear Browser & Test

**Option 1: Incognito Mode (Fastest)**
1. Open **Incognito/Private window**
2. Go to your Element URL
3. Login
4. Should work!

**Option 2: Clear Cache**
1. Press **Ctrl+Shift+Del**
2. Select "All time"
3. Clear everything
4. Reload Element
5. Login

**Option 3: Hard Refresh**
1. Go to Element
2. Press **Ctrl+Shift+R** or **Ctrl+F5**
3. Login

---

## Why This Works

- Synapse already has **native sliding sync** enabled (msc3575)
- Element's `feature_sliding_sync: true` tries to use **old external proxy**
- Setting it to `false` makes Element use **native sync** instead
- Browser cache keeps old settings, so must clear

---

## Verify Fix

After clearing cache and logging in:
- ✅ No "legacy sliding sync" error
- ✅ Login works normally
- ✅ Sync is fast (native sliding sync active)

---

**TL;DR:**
1. Edit `element/config.json` → set `feature_sliding_sync: false`
2. Restart: `docker compose restart element`
3. Use **Incognito mode** to test
4. Done! ✅
