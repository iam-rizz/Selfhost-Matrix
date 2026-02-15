# 🔄 Database Restore Guide

Complete guide for restoring Matrix PostgreSQL database from backups.

---

## 📋 Table of Contents

- [Restore Scenarios](#restore-scenarios)
- [Prerequisites](#prerequisites)
- [Quick Restore (Automated)](#quick-restore-automated)
- [Manual Restore Methods](#manual-restore-methods)
- [Restore from Telegram](#restore-from-telegram)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Restore Scenarios

### 1. Data Corruption / Rollback
**When:** Database corrupted, need to rollback to previous state  
**Impact:** Downtime ~5-10 minutes  
**Data Loss:** Changes after backup timestamp

### 2. Server Migration
**When:** Moving to new server  
**Impact:** Complete migration  
**Data Loss:** None (if backup is recent)

### 3. Disaster Recovery
**When:** Server failure, data loss  
**Impact:** Full rebuild  
**Data Loss:** Depends on backup age

### 4. Testing / Development
**When:** Clone production to test environment  
**Impact:** None on production  
**Data Loss:** N/A

---

## ✅ Prerequisites

**Before starting:**
- [ ] Have backup file ready (`.sql.gz` or `.sql.gz.gpg`)
- [ ] Know backup timestamp
- [ ] Have GPG key (if backup encrypted)
- [ ] Sufficient disk space (2x backup size)
- [ ] Root/sudo access to server
- [ ] Docker Compose running

**Check backup:**
```bash
# List available backups
ls -lh backups/

# Check backup size
du -h backups/synapse_db_*.sql.gz*

# Verify GPG can decrypt (if encrypted)
gpg --list-keys
```

---

## 🚀 Quick Restore (Automated)

**Use the restore script for easiest restore:**

```bash
# Make script executable
chmod +x scripts/restore-database.sh

# Run restore
./scripts/restore-database.sh backups/synapse_db_20260216_030001.sql.gz.gpg

# Or for unencrypted backup
./scripts/restore-database.sh backups/synapse_db_20260216_030001.sql.gz
```

**What the script does:**
1. ✅ Stops Synapse services
2. ✅ Decrypts backup (if encrypted)
3. ✅ Creates safety backup of current database
4. ✅ Drops and recreates database
5. ✅ Restores from backup
6. ✅ Restarts Synapse services
7. ✅ Verifies restoration

**Output:**
```
🔄 Starting database restore...
Backup file: backups/synapse_db_20260216_030001.sql.gz.gpg
⏸️  Stopping Synapse...
📦 Preparing backup...
🔓 Decrypting...
💾 Creating safety backup...
🗑️  Dropping existing database...
📥 Restoring database...
▶️  Starting Synapse...
⏳ Waiting for Synapse to start...
✅ Verifying restore...
 user_count 
------------
          5
 room_count 
------------
         12

════════════════════════════════════════════════════════════
✅ Database restore complete!
📁 Safety backup: /tmp/pre-restore-backup.sql.gz
📊 Check logs: docker logs -f matrix-synapse
════════════════════════════════════════════════════════════
```

---

## 🔧 Manual Restore Methods

### Method 1: Full Restore (Drop & Recreate)

**Recommended for:** Clean restore, avoiding conflicts

```bash
# 1. Stop Synapse
docker compose stop synapse synapse-worker-generic synapse-worker-media synapse-worker-federation-sender

# 2. Decrypt backup (if encrypted)
gpg --decrypt backups/synapse_db_20260216_030001.sql.gz.gpg > /tmp/backup.sql.gz

# 3. Extract
gunzip /tmp/backup.sql.gz
# Result: /tmp/backup.sql

# 4. Terminate active connections
docker exec matrix-postgres psql -U synapse -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='synapse' AND pid <> pg_backend_pid();"

# 5. Drop database
docker exec matrix-postgres psql -U synapse -c "DROP DATABASE synapse;"

# 6. Recreate database
docker exec matrix-postgres psql -U synapse -c "CREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0;"

# 7. Restore
docker exec -i matrix-postgres psql -U synapse synapse < /tmp/backup.sql

# 8. Cleanup
rm /tmp/backup.sql

# 9. Restart Synapse
docker compose start synapse synapse-worker-generic synapse-worker-media synapse-worker-federation-sender

# 10. Monitor startup
docker logs -f matrix-synapse
```

---

### Method 2: In-Place Restore (Overwrite)

**Recommended for:** Quick restore, less downtime

```bash
# 1. Stop Synapse
docker compose stop synapse synapse-worker-*

# 2. Prepare backup
gpg --decrypt backups/synapse_db_*.sql.gz.gpg | gunzip > /tmp/backup.sql

# 3. Restore (overwrites existing data)
docker exec -i matrix-postgres psql -U synapse synapse < /tmp/backup.sql

# 4. Cleanup
rm /tmp/backup.sql

# 5. Restart
docker compose start synapse synapse-worker-*
```

**⚠️ Warning:** May cause conflicts if schema changed after backup.

---

### Method 3: Selective Restore (Specific Tables)

**Recommended for:** Restoring specific data only

```bash
# 1. Extract specific table from backup
pg_restore -t users /tmp/backup.sql > /tmp/users_only.sql

# 2. Restore specific table
docker exec -i matrix-postgres psql -U synapse synapse < /tmp/users_only.sql
```

---

## 📱 Restore from Telegram

### Step 1: Download from Telegram

**Option A: Download on Server (if Telegram CLI available)**
```bash
# Install telegram-cli or tdlib
# Download file directly to server
```

**Option B: Download on Local Machine**
1. Open Telegram app
2. Go to chat with backup bot
3. Find backup file
4. Click → Download
5. Save to local machine

### Step 2: Transfer to Server

```bash
# From local machine
scp synapse_db_20260216_030001.sql.gz.gpg root@your-server:/root/Selfhost-Matrix/backups/

# Or use rsync
rsync -avz --progress synapse_db_*.sql.gz.gpg root@your-server:/root/Selfhost-Matrix/backups/
```

### Step 3: Restore on Server

```bash
# SSH to server
ssh root@your-server

# Navigate to project
cd ~/Selfhost-Matrix

# Run restore script
./scripts/restore-database.sh backups/synapse_db_20260216_030001.sql.gz.gpg
```

---

## ✅ Verification

### 1. Check Database

```bash
# Database size
docker exec matrix-postgres psql -U synapse -c "\l+"

# Table count
docker exec matrix-postgres psql -U synapse synapse -c "\dt" | wc -l

# User count
docker exec matrix-postgres psql -U synapse synapse -c "SELECT COUNT(*) FROM users;"

# Room count
docker exec matrix-postgres psql -U synapse synapse -c "SELECT COUNT(*) FROM rooms;"

# Recent events
docker exec matrix-postgres psql -U synapse synapse -c "SELECT event_id, type, room_id FROM events ORDER BY stream_ordering DESC LIMIT 10;"
```

### 2. Check Synapse

```bash
# Container status
docker compose ps synapse

# Logs (should show successful startup)
docker logs matrix-synapse | tail -50

# Health endpoint
curl http://localhost:8008/health
# Should return: OK

# Version endpoint
curl https://two.web.id/_matrix/client/versions
```

### 3. Test Login

```bash
# Try login via Element
# Open: https://element.two.web.id

# Or test API
curl -X POST https://two.web.id/_matrix/client/r0/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"your-user","password":"your-pass"}'
```

---

## 🔍 Troubleshooting

### Error: "database is being accessed by other users"

**Cause:** Active connections to database

**Solution:**
```bash
# Force disconnect all users
docker exec matrix-postgres psql -U synapse -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='synapse' AND pid <> pg_backend_pid();"

# Retry drop
docker exec matrix-postgres psql -U synapse -c "DROP DATABASE synapse;"
```

---

### Error: "permission denied for database synapse"

**Cause:** Wrong user or permissions

**Solution:**
```bash
# Verify user
docker exec matrix-postgres psql -U synapse -c "\du"

# Grant permissions
docker exec matrix-postgres psql -U synapse -c "GRANT ALL PRIVILEGES ON DATABASE synapse TO synapse;"

# Retry restore
docker exec -i matrix-postgres psql -U synapse synapse < /tmp/backup.sql
```

---

### Error: "No space left on device"

**Cause:** Insufficient disk space

**Solution:**
```bash
# Check disk space
df -h

# Clean old backups
find backups/ -mtime +7 -delete

# Clean Docker
docker system prune -a

# Retry restore
```

---

### Restore Stuck / Very Slow

**Cause:** Large database, slow I/O

**Solution:**
```bash
# Check progress
docker exec matrix-postgres psql -U synapse -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active';"

# If truly stuck (>30 min for small DB)
docker compose restart postgres

# Retry restore
```

---

### Synapse Won't Start After Restore

**Check logs:**
```bash
docker logs matrix-synapse

# Common issues:
# - Schema mismatch (backup from different Synapse version)
# - Missing tables
# - Corrupted data
```

**Solution:**
```bash
# Restore from safety backup
docker exec -i matrix-postgres psql -U synapse synapse < /tmp/pre-restore-backup.sql.gz

# Or restore from older backup
./scripts/restore-database.sh backups/synapse_db_OLDER_DATE.sql.gz.gpg
```

---

## 🎯 Best Practices

### Before Restore

1. ✅ **Test backup integrity**
   ```bash
   # Test GPG decryption
   gpg --decrypt backup.sql.gz.gpg > /dev/null
   
   # Test gunzip
   gunzip -t backup.sql.gz
   ```

2. ✅ **Create safety backup**
   ```bash
   docker exec matrix-postgres pg_dump -U synapse synapse | gzip > safety-backup.sql.gz
   ```

3. ✅ **Notify users** (if production)
   - Send maintenance notification
   - Estimate downtime
   - Plan restore window

4. ✅ **Document restore time**
   - Record start time
   - Record completion time
   - Update RTO (Recovery Time Objective)

### During Restore

1. ✅ **Monitor progress**
   ```bash
   # Watch logs in separate terminal
   docker logs -f matrix-postgres
   ```

2. ✅ **Don't interrupt**
   - Let restore complete
   - Don't restart containers
   - Don't kill processes

3. ✅ **Keep safety backup**
   - Don't delete until verified
   - Keep for 24 hours minimum

### After Restore

1. ✅ **Verify thoroughly**
   - Check user count
   - Check room count
   - Test login
   - Test federation

2. ✅ **Monitor for 24 hours**
   - Watch error logs
   - Monitor resource usage
   - Check user reports

3. ✅ **Document lessons learned**
   - What caused need for restore?
   - How long did it take?
   - What can be improved?

4. ✅ **Update backup strategy**
   - Increase backup frequency?
   - Add more retention?
   - Test restores more often?

---

## 📊 Restore Time Estimates

| Database Size | Restore Time | Downtime |
|--------------|--------------|----------|
| < 100 MB | 1-2 minutes | ~5 minutes |
| 100 MB - 1 GB | 2-5 minutes | ~10 minutes |
| 1 GB - 10 GB | 5-15 minutes | ~20 minutes |
| > 10 GB | 15-60 minutes | ~1 hour |

**Factors affecting restore time:**
- Database size
- Server I/O speed
- Network speed (if downloading from Telegram)
- Encryption (GPG decryption adds time)

---

## 🔐 Security Considerations

1. **Encrypted backups**
   - Always use GPG for production
   - Store private key securely
   - Test decryption regularly

2. **Access control**
   - Limit who can restore
   - Audit restore operations
   - Log all restore attempts

3. **Data sensitivity**
   - Backups contain user messages
   - Backups contain passwords (hashed)
   - Treat backups as sensitive data

---

## 📚 Related Documentation

- [Backup Setup Guide](../README.md#backup--recovery)
- [GPG Encryption Guide](GPG_BACKUP_ENCRYPTION.md)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/backup-dump.html)

---

## ✅ Restore Checklist

**Pre-Restore:**
- [ ] Backup file available
- [ ] GPG key available (if encrypted)
- [ ] Sufficient disk space
- [ ] Users notified (if production)
- [ ] Safety backup created

**During Restore:**
- [ ] Synapse stopped
- [ ] Database dropped/recreated
- [ ] Backup restored
- [ ] No errors in logs

**Post-Restore:**
- [ ] Synapse started successfully
- [ ] User count verified
- [ ] Room count verified
- [ ] Login tested
- [ ] Federation tested
- [ ] Monitoring active

**Cleanup:**
- [ ] Temporary files deleted
- [ ] Safety backup kept (24h)
- [ ] Restore documented
- [ ] Lessons learned recorded
