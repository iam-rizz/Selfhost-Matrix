# 🔐 GPG Encryption Setup for Backups

This guide explains how to set up GPG encryption for your Matrix database backups.

## 📋 Overview

**Why GPG?**
- 🔒 Encrypt backups at rest
- 🔑 Only you can decrypt with private key
- 📦 Safe to store in public cloud
- 🛡️ Protection against data breaches

**Backup Flow:**
```
PostgreSQL → pg_dump → gzip → GPG encrypt → .sql.gz.gpg
```

---

## 🚀 Quick Setup

### 1. Generate GPG Key Pair

```bash
# Generate new key (interactive)
gpg --full-generate-key

# Choose options:
# - Key type: (1) RSA and RSA
# - Key size: 4096
# - Expiration: 0 (never expires) or 2y (2 years)
# - Real name: Matrix Backup
# - Email: admin@your-domain.com
# - Passphrase: (optional, for extra security)
```

### 2. List Your Keys

```bash
# List public keys
gpg --list-keys

# Output example:
# pub   rsa4096 2026-02-16 [SC]
#       1D6291E10970072A74B10BE050F00B0A
# uid           [ultimate] Matrix Backup <admin@two.web.id>
```

### 3. Add to .env

```bash
# Copy the key ID (40-character fingerprint or 16-character short ID)
nano .env

# Add this line:
GPG_RECIPIENT=1D6291E10970072A74B10BE050F00B0A
```

### 4. Test Backup

```bash
bash scripts/backup-postgres.sh

# Should see:
# [Date] Backup encrypted with GPG: /path/to/backup.sql.gz.gpg
```

---

## 🔧 Advanced Usage

### Export Public Key (for other servers)

```bash
# Export public key
gpg --export --armor admin@two.web.id > matrix-backup-public.key

# Import on another server
gpg --import matrix-backup-public.key
```

### Decrypt Backup

```bash
# Decrypt backup file
gpg --decrypt backups/synapse_db_20260216_030001.sql.gz.gpg > backup.sql.gz

# Extract
gunzip backup.sql.gz

# Restore to database
docker exec -i matrix-postgres psql -U synapse synapse < backup.sql
```

### Backup Private Key (IMPORTANT!)

```bash
# Export private key (KEEP SECURE!)
gpg --export-secret-keys --armor admin@two.web.id > matrix-backup-private.key

# Store in secure location:
# - Password manager
# - Encrypted USB drive
# - Hardware security key
# - Offline backup

# Import private key (for disaster recovery)
gpg --import matrix-backup-private.key
```

---

## 🔍 Troubleshooting

### Error: "No public key"

```bash
# Check if key exists
gpg --list-keys

# If not found, generate new key
gpg --full-generate-key

# Update .env with correct key ID
```

### Error: "Encryption failed"

```bash
# Verify key ID is correct
gpg --list-keys | grep -A 1 "pub"

# Test encryption manually
echo "test" | gpg --encrypt --recipient YOUR_KEY_ID

# Check GPG_RECIPIENT in .env matches key ID
```

### Backup Created Unencrypted

This is **normal** if:
- GPG_RECIPIENT not set in .env
- GPG key not found
- GPG not installed

**Solution:**
```bash
# Install GPG
sudo apt install gpg

# Generate key and configure .env
# See steps above
```

---

## 📊 Backup Comparison

| Method | Encryption | Size | Security |
|--------|-----------|------|----------|
| **Unencrypted** | ❌ None | 28KB | ⚠️ Low |
| **GPG Encrypted** | ✅ AES-256 | 28KB | 🔒 High |

**File Extensions:**
- `.sql.gz` - Unencrypted (gzip only)
- `.sql.gz.gpg` - Encrypted (gzip + GPG)

---

## 🎯 Best Practices

### 1. Key Management
- ✅ Use strong passphrase for private key
- ✅ Backup private key securely
- ✅ Set key expiration (renew periodically)
- ✅ Use separate key for backups

### 2. Security
- ✅ Never share private key
- ✅ Store private key offline
- ✅ Use hardware security key (YubiKey) for production
- ✅ Rotate keys annually

### 3. Testing
- ✅ Test encryption after setup
- ✅ Test decryption monthly
- ✅ Verify backup restoration works
- ✅ Document recovery procedure

---

## 🔄 Key Rotation

```bash
# 1. Generate new key
gpg --full-generate-key

# 2. Update .env with new key ID
GPG_RECIPIENT=NEW_KEY_ID

# 3. Keep old key for decrypting old backups
# Don't delete old private key!

# 4. Test new backup
bash scripts/backup-postgres.sh

# 5. Export and backup new private key
gpg --export-secret-keys --armor NEW_EMAIL > new-private.key
```

---

## 📚 Additional Resources

- [GPG Documentation](https://gnupg.org/documentation/)
- [GPG Best Practices](https://riseup.net/en/security/message-security/openpgp/best-practices)
- [Backup Encryption Guide](https://wiki.archlinux.org/title/GnuPG)

---

## ✅ Verification Checklist

- [ ] GPG installed (`gpg --version`)
- [ ] Key pair generated (`gpg --list-keys`)
- [ ] GPG_RECIPIENT set in .env
- [ ] Test backup creates .gpg file
- [ ] Test decryption works
- [ ] Private key backed up securely
- [ ] Recovery procedure documented
