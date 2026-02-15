# 🛡️ reCAPTCHA Setup Guide

Protect your Matrix homeserver registration from spam and bots using Google reCAPTCHA v2.

---

## 📋 Overview

**reCAPTCHA** adds a "I'm not a robot" checkbox to the registration page, preventing automated bot registrations while allowing legitimate users to sign up.

**When to use:**
- ✅ Public registration enabled
- ✅ Want to prevent spam accounts
- ✅ Reduce abuse and bot attacks

**When NOT to use:**
- ❌ Registration disabled (invite-only)
- ❌ Private server (shared secret only)

---

## 🚀 Quick Setup

### Step 1: Get reCAPTCHA Keys

1. Go to [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin)
2. Click **"+"** to create a new site
3. Fill in the form:
   - **Label**: Matrix Homeserver
   - **reCAPTCHA type**: ✅ **reCAPTCHA v2** → "I'm not a robot" Checkbox
   - **Domains**: Add your domain (e.g., `two.web.id`)
   - **Owners**: Your Google account email
4. Accept terms and click **Submit**
5. Copy your keys:
   - **Site Key** (public key)
   - **Secret Key** (private key)

---

### Step 2: Configure .env

Edit your `.env` file:

```bash
# Enable reCAPTCHA
ENABLE_REGISTRATION_CAPTCHA=true

# Add your keys from Google reCAPTCHA Admin
RECAPTCHA_PUBLIC_KEY=6LcXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
RECAPTCHA_PRIVATE_KEY=6LcYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY

# Make sure registration is enabled
SYNAPSE_ENABLE_REGISTRATION=true
```

---

### Step 3: Apply Configuration

```bash
# Re-run setup to apply changes
bash setup.sh

# Or manually update homeserver.yaml
docker compose down
bash setup.sh  # This will regenerate configs
docker compose up -d
```

---

### Step 4: Verify

1. Open Element Web: `https://element.your-domain.com`
2. Click **"Create Account"**
3. You should see the reCAPTCHA checkbox
4. Complete registration to test

---

## 🔧 Configuration Details

### homeserver.yaml

The setup script automatically configures:

```yaml
# Registration with CAPTCHA
enable_registration: true
enable_registration_captcha: true
recaptcha_public_key: "YOUR_SITE_KEY"
recaptcha_private_key: "YOUR_SECRET_KEY"
```

### Disable reCAPTCHA

To disable CAPTCHA but keep registration:

```bash
# In .env
ENABLE_REGISTRATION_CAPTCHA=false
SYNAPSE_ENABLE_REGISTRATION=true
```

Then re-run `bash setup.sh` and restart:

```bash
docker compose restart synapse
```

---

## 🎯 Best Practices

### 1. Use with Rate Limiting

reCAPTCHA works best with rate limiting (already configured):

```yaml
# homeserver.yaml (already set)
rc_registration:
  per_second: 0.05
  burst_count: 3
```

### 2. Monitor Registration Logs

Check for suspicious activity:

```bash
# View registration attempts
docker logs matrix-synapse | grep "register"

# Check CAPTCHA failures
docker logs matrix-synapse | grep "captcha"
```

### 3. Combine with Email Verification

For extra security, require email verification:

```yaml
# homeserver.yaml
registrations_require_3pid:
  - email

email:
  smtp_host: "smtp.gmail.com"
  smtp_port: 587
  smtp_user: "your-email@gmail.com"
  smtp_pass: "your-app-password"
  notif_from: "Matrix <noreply@your-domain.com>"
```

### 4. Backup Keys Securely

- Store keys in password manager
- Don't commit to public repos
- Use environment variables only

---

## 🐛 Troubleshooting

### CAPTCHA not showing

**Check Element config:**

```bash
# Element should auto-detect, but verify
docker logs matrix-element
```

**Check browser console:**

Open Developer Tools (F12) → Console → Look for reCAPTCHA errors

**Verify domain:**

Make sure your domain is added in reCAPTCHA admin panel

### "Invalid CAPTCHA" error

**Check keys:**

```bash
# Verify keys in .env
cat .env | grep RECAPTCHA
```

**Check Synapse logs:**

```bash
docker logs matrix-synapse | grep -i captcha
```

**Common causes:**
- Wrong secret key
- Domain mismatch
- reCAPTCHA v3 instead of v2

### CAPTCHA works but registration fails

**Check registration settings:**

```bash
# Verify registration is enabled
docker exec matrix-synapse grep "enable_registration" /data/homeserver.yaml
```

**Check rate limits:**

```bash
# View rate limit errors
docker logs matrix-synapse | grep "rate_limit"
```

---

## 📊 Monitoring

### Check CAPTCHA Success Rate

```bash
# View CAPTCHA verifications
docker logs matrix-synapse | grep "captcha" | tail -20
```

### Prometheus Metrics

reCAPTCHA verification is included in registration metrics:

```promql
# Registration attempts
rate(synapse_http_server_requests_total{method="POST",servlet="register"}[5m])

# Registration failures
rate(synapse_http_server_requests_total{method="POST",servlet="register",code!="200"}[5m])
```

---

## 🔐 Security Considerations

### 1. Keep Secret Key Private

- Never expose in client-side code
- Don't commit to version control
- Use `.env` file (already in `.gitignore`)

### 2. Use HTTPS Only

reCAPTCHA requires HTTPS:

```yaml
# Traefik handles this automatically
# Verify SSL is working:
curl -I https://your-domain.com
```

### 3. Monitor for Bypasses

- Check registration logs regularly
- Set up alerts for unusual patterns
- Use Fail2ban for brute force protection

### 4. Update Keys Periodically

- Rotate keys every 6-12 months
- Update in reCAPTCHA admin panel
- Update `.env` and restart

---

## 📚 Related Documentation

- [Google reCAPTCHA Docs](https://developers.google.com/recaptcha/docs/display)
- [Synapse Registration Docs](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#registration)
- [Matrix Security Best Practices](https://matrix.org/docs/guides/moderation)

---

## ✅ Checklist

- [ ] Created reCAPTCHA site in Google Admin
- [ ] Copied Site Key and Secret Key
- [ ] Added keys to `.env` file
- [ ] Set `ENABLE_REGISTRATION_CAPTCHA=true`
- [ ] Set `SYNAPSE_ENABLE_REGISTRATION=true`
- [ ] Ran `bash setup.sh` to apply config
- [ ] Restarted Synapse: `docker compose restart synapse`
- [ ] Tested registration with CAPTCHA
- [ ] Verified CAPTCHA appears on registration page
- [ ] Completed test registration successfully
- [ ] Backed up reCAPTCHA keys securely

---

## 🎉 Done!

Your Matrix homeserver is now protected with reCAPTCHA! Users will need to complete the "I'm not a robot" challenge before registering.
