# 🎥 Jitsi Meet Self-Hosted Guide

## Overview

Jitsi Meet adalah open-source video conferencing platform yang sekarang self-hosted di server Matrix kamu.

**Benefits:**
- ✅ **Privacy** — Video calls di server sendiri
- ✅ **No limits** — Unlimited participants & duration
- ✅ **Custom branding** — Your domain, your rules
- ✅ **Better quality** — Dedicated resources
- ✅ **Matrix integration** — Start calls from Element

## Architecture

```
Jitsi Web (UI)
    ↓
Prosody (XMPP server)
    ↓
Jicofo (Conference focus)
    ↓
JVB (Video bridge) ← UDP port 10000
```

**4 containers:**
1. **jitsi-web** — Web UI & HTTP server
2. **jitsi-prosody** — XMPP signaling
3. **jitsi-jicofo** — Conference coordinator
4. **jitsi-jvb** — Video/audio routing

## Access

**URL:** `https://meet.yourdomain.com`

**No authentication** by default — anyone with link can join.

## Starting a Call

### From Element

1. Open room
2. Click **video call icon** (top right)
3. Jitsi widget opens in-room
4. Click **Join** to start call

### Direct Access

1. Go to `https://meet.yourdomain.com`
2. Enter room name
3. Click **Start meeting**

## Configuration

### Environment Variables

```bash
# .env
JITSI_SUBDOMAIN=meet
JITSI_JICOFO_SECRET=random-secret-1
JITSI_JICOFO_PASSWORD=random-password-1
JITSI_JVB_PASSWORD=random-password-2
```

**Generate secrets:**
```bash
openssl rand -hex 32
```

### Enable Authentication

Edit `jitsi-web` environment in `docker-compose.yml`:

```yaml
jitsi-web:
  environment:
    - ENABLE_AUTH=1
    - ENABLE_GUESTS=0
```

**Create user:**
```bash
docker exec jitsi-prosody prosodyctl register username meet.jitsi password
```

### Custom Branding

Create `jitsi-data/web/interface_config.js`:

```javascript
var interfaceConfig = {
  APP_NAME: 'My Video Calls',
  DEFAULT_BACKGROUND: '#1a1a1a',
  SHOW_JITSI_WATERMARK: false,
  SHOW_WATERMARK_FOR_GUESTS: false
};
```

Mount in docker-compose:
```yaml
volumes:
  - ./jitsi-data/web/interface_config.js:/config/interface_config.js
```

## Firewall Configuration

**Required ports:**
- **443/tcp** — HTTPS (via Traefik)
- **10000/udp** — Video/audio streams

**UFW example:**
```bash
sudo ufw allow 10000/udp comment 'Jitsi video bridge'
```

**Cloud firewall:** Open UDP 10000 in security group.

## Testing

### Basic Test

1. Go to `https://meet.yourdomain.com`
2. Create test room
3. Join from 2 devices
4. Check video/audio works

### Network Test

Jitsi has built-in network test:
1. Join meeting
2. Settings → More → Network test
3. Check latency & packet loss

### STUN/TURN

Jitsi uses Google STUN by default:

```yaml
JVB_STUN_SERVERS=stun.l.google.com:19302
```

**Use Coturn instead:**
```yaml
JVB_STUN_SERVERS=turn:yourdomain.com:3478
```

## Monitoring

### Logs

```bash
# Web server logs
docker compose logs jitsi-web

# Video bridge logs
docker compose logs jitsi-jvb

# XMPP logs
docker compose logs jitsi-prosody
```

### Metrics

JVB exposes Prometheus metrics on port 8080 (internal).

**Add to Prometheus:**
```yaml
scrape_configs:
  - job_name: 'jitsi-jvb'
    static_configs:
      - targets: ['jitsi-jvb:8080']
```

**Metrics:**
- `jitsi_participants` — Current participants
- `jitsi_conferences` — Active conferences
- `jitsi_videochannels` — Video streams

## Troubleshooting

### Video Not Working

**Check UDP port 10000:**
```bash
# Test from outside
nc -u -v your-server-ip 10000

# Check JVB logs
docker compose logs jitsi-jvb | grep -i error
```

**Common issue:** Firewall blocking UDP.

### Audio Issues

**Check browser permissions:**
- Chrome: Settings → Privacy → Site settings → Microphone
- Firefox: Preferences → Privacy → Permissions

**Check Prosody logs:**
```bash
docker compose logs jitsi-prosody | grep -i error
```

### Connection Failed

**Check all containers running:**
```bash
docker compose ps | grep jitsi
```

**Restart Jitsi stack:**
```bash
docker compose restart jitsi-web jitsi-prosody jitsi-jicofo jitsi-jvb
```

### High CPU Usage

**Limit video quality:**

Edit `jitsi-web` config:
```javascript
config.resolution = 720;
config.constraints.video.height.max = 720;
```

**Scale JVB:**

Add more video bridges for high load:
```yaml
jitsi-jvb-2:
  image: jitsi/jvb:stable
  # ... same config as jitsi-jvb
```

## Performance Optimization

### Video Quality Settings

**Low bandwidth:**
```javascript
config.resolution = 360;
config.startVideoMuted = 10; // Mute video for >10 participants
```

**High quality:**
```javascript
config.resolution = 1080;
config.constraints.video.height.max = 1080;
```

### Resource Limits

```yaml
jitsi-jvb:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
```

## Element Integration

### Widget Configuration

Element config already updated:

```json
{
  "integrations_jitsi_widget_url": "https://meet.yourdomain.com/"
}
```

### Start Call from Room

1. **1-on-1 call:** Click video icon → Direct call
2. **Group call:** Click video icon → Jitsi widget opens

### Permissions

Room admin can:
- Start/stop calls
- Remove participants
- Moderate (mute, kick)

## Advanced: Recording

### Enable Recording

**Requires Jibri** (recording component):

```yaml
jitsi-jibri:
  image: jitsi/jibri:stable
  # ... configuration
```

**Complex setup** — See [Jitsi Handbook](https://jitsi.github.io/handbook/docs/devops-guide/jibri).

### Alternative: OBS

Use OBS to record screen while in call.

## Security Best Practices

1. **Enable authentication** for production
2. **Use strong passwords** for Prosody users
3. **Limit room creation** to authenticated users
4. **Monitor logs** for abuse
5. **Rate limit** via Traefik middleware

## Resources

- [Jitsi Handbook](https://jitsi.github.io/handbook/)
- [Jitsi Docker Setup](https://jitsi.github.io/handbook/docs/devops-guide/docker)
- [Jitsi Community](https://community.jitsi.org/)
