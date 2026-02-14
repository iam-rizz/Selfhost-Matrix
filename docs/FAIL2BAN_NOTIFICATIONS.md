# 🚨 Enhanced Fail2ban Telegram Notifications

## Features

The enhanced Telegram notification system provides:

### 🎨 Rich Formatting
- **Severity indicators**: 🔴 Critical (SSH), 🟠 High (Matrix), 🟡 Medium (Others)
- **Service-specific emojis**: 🔐 SSH, 💬 Matrix, 🛡️ Others
- **Professional layout**: Clean separators and organized information

### 🌍 IP Geolocation
Automatically looks up banned IP information:
- **City, Region, Country**: Geographic location
- **ISP/Organization**: Network provider (e.g., DigitalOcean, AWS)
- **Timezone**: Local timezone of the IP
- **Threat level**: Security threat indicator (if available)

### 📊 Detailed Information
Each ban notification includes:
- Service/jail name
- Banned IP address with geolocation
- ISP/Organization name
- Server hostname
- Timestamp with timezone
- Ban duration in seconds

## Example Notifications

### Ban Alert (SSH)
```
🔴 SECURITY ALERT - IP BANNED
━━━━━━━━━━━━━━━━━━━━
🔐 Service: sshd
🚫 Banned IP: 165.232.94.12
🌍 Location: Amsterdam, North Holland, The Netherlands
🏢 ISP/Org: DigitalOcean, LLC
⏰ Timezone: Europe/Amsterdam
🖥️ Server: matrix-server
📅 Time: 2026-02-14 23:48:09 WIB
⏳ Ban Duration: 3600 seconds
━━━━━━━━━━━━━━━━━━━━
⚡ Automatic protection by Fail2ban
```

### Ban Alert (Matrix)
```
🟠 SECURITY ALERT - IP BANNED
━━━━━━━━━━━━━━━━━━━━
💬 Service: matrix-synapse
🚫 Banned IP: 192.168.1.100
🌍 Location: Jakarta, Jakarta, Indonesia
🏢 ISP/Org: PT Telkom Indonesia
⏰ Timezone: Asia/Jakarta
🖥️ Server: matrix-server
📅 Time: 2026-02-14 23:50:00 WIB
⏳ Ban Duration: 3600 seconds
━━━━━━━━━━━━━━━━━━━━
⚡ Automatic protection by Fail2ban
```

### Unban Alert
```
✅ IP UNBANNED
━━━━━━━━━━━━━━━━━━━━
🔐 Service: sshd
🔓 Unbanned IP: 165.232.94.12
🌍 Location: Amsterdam, The Netherlands
🖥️ Server: matrix-server
📅 Time: 2026-02-14 00:48:09 WIB
━━━━━━━━━━━━━━━━━━━━
♻️ Ban period expired
```

### Service Start
```
🟢 Fail2ban Started
━━━━━━━━━━━━━━━━━━━━
Jail: sshd
Server: matrix-server
Time: 2026-02-14 23:45:00 WIB
━━━━━━━━━━━━━━━━━━━━
✅ Protection active
```

## Severity Levels

| Emoji | Level | Services | Description |
|-------|-------|----------|-------------|
| 🔴 | Critical | SSH | Direct server access attempts |
| 🟠 | High | Matrix Synapse | Application-level attacks |
| 🟡 | Medium | Others | General protection |

## Service Emojis

| Emoji | Service | Description |
|-------|---------|-------------|
| 🔐 | sshd | SSH authentication |
| 💬 | matrix-synapse | Matrix login attempts |
| 🛡️ | default | Other services |

## Requirements

The enhanced notifications require:
- `curl` — For Telegram API calls
- `jq` — For JSON parsing
- Internet access to `ipapi.co` for geolocation

These are automatically installed by `setup.sh`.

## Configuration

Set in `.env`:
```bash
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=123456789
```

## Geolocation API

Uses **ipapi.co** free tier:
- **Limit**: 1,000 requests/day
- **No API key** required
- **Fallback**: Shows "Unknown" if API fails

For high-traffic servers, consider:
- Self-hosted GeoIP database
- Paid ipapi.co plan (30,000 req/month)
- Alternative: ip-api.com, ipgeolocation.io

## Testing

Test the notification:
```bash
# Manually trigger a ban
sudo fail2ban-client set sshd banip 1.2.3.4

# Check if notification sent
sudo tail -f /var/log/fail2ban.log | grep telegram

# Unban to test unban notification
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

## Troubleshooting

### No notifications received

```bash
# Check Telegram bot token
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe"

# Check chat ID
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates"

# Test manual notification
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$TELEGRAM_CHAT_ID" \
  -d "text=Test from Fail2ban"
```

### Geolocation not showing

```bash
# Test ipapi.co manually
curl -s "https://ipapi.co/8.8.8.8/json/" | jq .

# Check jq is installed
which jq || sudo apt install jq -y
```

## Privacy Note

IP geolocation data is fetched from ipapi.co in real-time. No data is stored locally. If privacy is a concern, you can:
1. Remove geolocation lookup from `actionban`
2. Use local GeoIP database (MaxMind GeoLite2)
3. Disable external API calls

## Credits

- **Fail2ban**: https://www.fail2ban.org/
- **ipapi.co**: https://ipapi.co/
- **Telegram Bot API**: https://core.telegram.org/bots/api
