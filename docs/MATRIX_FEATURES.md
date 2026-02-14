# 💬 Matrix Features & Capabilities

## What is Matrix?

**Matrix** adalah protokol komunikasi **open-source, terdesentralisasi** untuk real-time messaging, VoIP, dan IoT. Seperti email, tapi untuk chat — siapa pun bisa menjalankan server sendiri dan tetap berkomunikasi dengan server lain.

## Core Concepts

### 1. Homeserver

**Homeserver** adalah server Matrix yang menyimpan data user dan room.

- User terdaftar di satu homeserver (contoh: `@rizz:two.web.id`)
- Bisa chat dengan user di homeserver lain (federation)
- Setiap homeserver punya database sendiri

**Implementasi homeserver:**
- **Synapse** (Python) — Paling mature, production-ready
- **Dendrite** (Go) — Lebih ringan, masih beta
- **Conduit** (Rust) — Experimental, sangat ringan

### 2. Federation

**Federation** = komunikasi antar homeserver.

```
┌─────────────┐         ┌─────────────┐
│ two.web.id  │ ◄─────► │ matrix.org  │
│ Homeserver  │         │ Homeserver  │
└─────────────┘         └─────────────┘
      │                       │
  @rizz:two.web.id      @alice:matrix.org
```

**Keuntungan:**
- User di server berbeda bisa chat
- Tidak ada single point of failure
- Data privacy — pilih server yang dipercaya

**Federation Port:** 8448 (HTTPS)

### 3. Rooms

**Room** = ruang chat (seperti channel di Discord/Slack).

- **Public room** — Siapa saja bisa join
- **Private room** — Invite-only
- **Encrypted room** — End-to-end encryption (E2EE)

**Room ID format:** `!abc123:two.web.id`

**Room alias:** `#general:two.web.id` (human-readable)

### 4. Users

**User ID format:** `@username:homeserver.domain`

Contoh:
- `@rizz:two.web.id`
- `@alice:matrix.org`

**User roles dalam room:**
- **Admin** (power level 100) — Full control
- **Moderator** (power level 50) — Kick/ban users
- **User** (power level 0) — Normal user

## Key Features

### ✅ Messaging

- **Text messages** — Rich text, markdown
- **File sharing** — Images, videos, documents (max size configurable)
- **Reactions** — Emoji reactions ke messages
- **Edits** — Edit sent messages
- **Replies** — Thread-like conversations
- **Read receipts** — Lihat siapa yang sudah baca

### ✅ Voice & Video

- **1-on-1 calls** — Voice/video call langsung
- **Group calls** — Multi-user conference (via Jitsi widget)
- **Screen sharing** — Share screen saat call
- **TURN/STUN** — NAT traversal untuk koneksi stabil

**Requirement:** Coturn server (sudah included di template)

### ✅ End-to-End Encryption (E2EE)

Matrix menggunakan **Olm** dan **Megolm** protocol untuk E2EE.

**Cara kerja:**
1. Device verification — Verify device keys
2. Room encryption — Enable E2EE untuk room
3. Message encryption — Messages encrypted sebelum dikirim
4. Key backup — Backup encryption keys (optional)

**Enable E2EE:**
```yaml
# homeserver.yaml
encryption_enabled_by_default_for_room_type: all
```

**Verification methods:**
- **Emoji verification** — Compare emoji sequences
- **QR code** — Scan QR code antar device
- **Security key** — Backup key untuk recovery

### ✅ Integrations & Bots

**Dimension** = Integration manager untuk Matrix.

**Widget types:**
- **Jitsi** — Video conferencing
- **Etherpad** — Collaborative document editing
- **Custom widgets** — Embed web apps di room

**Bot examples:**
- **RSS bot** — Post RSS feed updates
- **GitHub bot** — Notify on commits/PRs
- **Moderation bot** — Auto-kick spam
- **Bridge bot** — Bridge ke Telegram/Discord/Slack

### ✅ Bridges

**Bridge** = Koneksi Matrix ke platform lain.

Popular bridges:
- **Telegram** — `mautrix-telegram`
- **WhatsApp** — `mautrix-whatsapp`
- **Discord** — `matrix-appservice-discord`
- **Slack** — `matrix-appservice-slack`
- **IRC** — `matrix-appservice-irc`

**Cara kerja:**
1. Bridge bot join room
2. Messages di Matrix → forwarded ke platform lain
3. Messages dari platform lain → forwarded ke Matrix

### ✅ Presence

**Presence** = Status online/offline user.

Status types:
- **Online** — Aktif sekarang
- **Unavailable** — Idle/away
- **Offline** — Not connected

```yaml
# homeserver.yaml
presence:
  enabled: true
```

### ✅ Push Notifications

Matrix mendukung push notifications via:
- **FCM** (Firebase Cloud Messaging) — Android
- **APNs** (Apple Push Notification) — iOS
- **Web Push** — Browser notifications

**Setup:**
```yaml
# homeserver.yaml
push:
  enabled: true
```

### ✅ Room Directory

**Room directory** = Daftar public rooms yang bisa di-browse.

```yaml
# homeserver.yaml
enable_room_list_search: true
```

**Disable untuk private server:**
```yaml
enable_room_list_search: false
allow_public_rooms_without_auth: false
```

### ✅ SSO (Single Sign-On)

Matrix mendukung SSO via:
- **SAML2**
- **OpenID Connect (OIDC)** — Google, GitHub, Keycloak
- **CAS**

**Example OIDC (Google):**
```yaml
oidc_providers:
  - idp_id: google
    idp_name: "Google"
    issuer: "https://accounts.google.com"
    client_id: "YOUR_CLIENT_ID"
    client_secret: "YOUR_CLIENT_SECRET"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        localpart_template: "{{ user.email.split('@')[0] }}"
        display_name_template: "{{ user.name }}"
```

## Advanced Features

### 1. Spaces

**Spaces** = Grouping rooms (seperti Discord servers).

```
Space: "My Community"
  ├─ #general
  ├─ #announcements
  └─ #random
```

**Create space:**
- Element → "+" → "Create Space"
- Add rooms ke space

### 2. Threads

**Threads** = Nested conversations dalam room.

- Reply to specific message
- Thread view di sidebar
- Reduce noise di main timeline

### 3. Reactions & Polls

**Reactions:**
```json
{
  "type": "m.reaction",
  "content": {
    "m.relates_to": {
      "rel_type": "m.annotation",
      "event_id": "$original_event",
      "key": "👍"
    }
  }
}
```

**Polls** (MSC3381):
- Create poll dengan multiple options
- Users vote
- Real-time results

### 4. Media Repository

Synapse menyimpan uploaded media (images, videos, files).

**Configuration:**
```yaml
# homeserver.yaml
max_upload_size: 100M

media_retention:
  local_media_lifetime: 90d
  remote_media_lifetime: 30d
```

**Storage location:** `/data/media_store`

**Cleanup old media:**
```bash
# Delete media older than 90 days
docker exec matrix-synapse synapse_media_repository_cleanup \
  --before "90 days ago"
```

### 5. URL Previews

Matrix bisa generate preview untuk URLs.

```yaml
# homeserver.yaml
url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
```

**Disable untuk security:**
```yaml
url_preview_enabled: false
```

### 6. Rate Limiting

Protect server dari abuse:

```yaml
# homeserver.yaml
rc_message:
  per_second: 0.2
  burst_count: 10

rc_login:
  per_second: 0.1
  burst_count: 3

rc_registration:
  per_second: 0.05
  burst_count: 2
```

### 7. User Directory

Search users across homeserver:

```yaml
# homeserver.yaml
user_directory:
  enabled: true
  search_all_users: false  # Only search users in same rooms
```

## Security Features

### 1. Registration

**Disable public registration:**
```yaml
enable_registration: false
```

**Enable with CAPTCHA:**
```yaml
enable_registration: true
enable_registration_captcha: true
recaptcha_public_key: "YOUR_KEY"
recaptcha_private_key: "YOUR_SECRET"
```

**Shared secret registration:**
```bash
# Create user with shared secret
docker exec -it matrix-synapse register_new_matrix_user \
  -c /data/homeserver.yaml http://localhost:8008
```

### 2. 3PID (Third-Party ID)

Require email/phone untuk registration:

```yaml
registrations_require_3pid:
  - email

email:
  smtp_host: "smtp.gmail.com"
  smtp_port: 587
  smtp_user: "your-email@gmail.com"
  smtp_pass: "your-password"
  notif_from: "Matrix <noreply@two.web.id>"
```

### 3. Admin API

Synapse punya Admin API untuk management:

**List users:**
```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "http://localhost:8008/_synapse/admin/v2/users"
```

**Deactivate user:**
```bash
curl -X POST -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "http://localhost:8008/_synapse/admin/v1/deactivate/@user:domain" \
  -d '{"erase": true}'
```

**Purge room:**
```bash
curl -X POST -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "http://localhost:8008/_synapse/admin/v1/purge_room" \
  -d '{"room_id": "!room:domain"}'
```

## Performance Optimization

### 1. Database Tuning

```yaml
# homeserver.yaml
database:
  name: psycopg2
  args:
    cp_min: 5
    cp_max: 10
    keepalives_idle: 10
    keepalives_interval: 10
    keepalives_count: 3
```

### 2. Redis Caching

```yaml
# homeserver.yaml
redis:
  enabled: true
  host: redis
  port: 6379
  password: "your-password"
```

**Cache hit rate:**
```promql
rate(synapse_util_caches_cache_hits[5m]) / 
(rate(synapse_util_caches_cache_hits[5m]) + rate(synapse_util_caches_cache_misses[5m]))
```

### 3. Worker Mode

Untuk high-traffic servers, gunakan worker mode:

```yaml
# worker.yaml
worker_app: synapse.app.generic_worker
worker_name: worker1

worker_listeners:
  - type: http
    port: 8081
    resources:
      - names: [client, federation]
```

**Benefits:**
- Horizontal scaling
- Distribute load across workers
- Separate federation traffic

## Clients

### Official Clients

- **Element Web** — Web client (included di template)
- **Element Desktop** — Electron app (Windows, Mac, Linux)
- **Element Android** — Android app
- **Element iOS** — iOS app

### Third-Party Clients

- **FluffyChat** — Flutter-based, cross-platform
- **SchildiChat** — Element fork dengan extra features
- **Nheko** — Qt-based desktop client
- **Fractal** — GNOME client (Linux)
- **Quaternion** — Qt-based client

### Bot/SDK

- **matrix-nio** (Python) — Async Python SDK
- **matrix-js-sdk** (JavaScript) — Official JS SDK
- **mautrix-python** — Bot framework
- **matrix-rust-sdk** — Rust SDK

## Use Cases

### 1. Team Communication

Replace Slack/Discord:
- Private homeserver
- Unlimited history
- No per-user pricing
- Full data control

### 2. Customer Support

- Public rooms untuk support
- Bridges ke email/Telegram
- Bot untuk auto-responses
- Searchable history

### 3. IoT & Automation

- MQTT bridge
- Home automation
- Sensor notifications
- Device control

### 4. Gaming Communities

- Voice channels (Jitsi)
- Rich embeds
- Bots untuk game stats
- Moderation tools

### 5. Education

- Class rooms
- File sharing
- Video lectures (Jitsi)
- Announcements

## Resources

- **Official Docs:** https://matrix.org/docs/
- **Synapse Docs:** https://matrix-org.github.io/synapse/
- **Element Docs:** https://element.io/help
- **Matrix Spec:** https://spec.matrix.org/
- **Community:** #matrix:matrix.org
