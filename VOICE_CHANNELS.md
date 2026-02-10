# Voice Channels - Setup Guide

## Status: WORKING ✅

Voice channels are fully functional with a custom-built web client.

## Quick Summary

The pre-built Revolt web client doesn't support voice for self-hosted instances. We solved this by:
1. Forking the frontend repo
2. Building from source with correct API URLs
3. Publishing to GitHub Container Registry

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────▶│    Caddy    │────▶│  Web Client │
└─────────────┘     └──────┬──────┘     └─────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│     API     │   │   LiveKit   │   │   Events    │
└─────────────┘   └──────┬──────┘   └─────────────┘
                         │
                         ▼
                 ┌─────────────┐
                 │voice-ingress│
                 └─────────────┘
```

## Components

| Service | Image | Purpose |
|---------|-------|---------|
| web | `ghcr.io/cjunks94/stoat-web:latest` | Custom-built frontend with voice support |
| livekit | `livekit/livekit-server:v1.8.0` | WebRTC voice/video server |
| voice-ingress | Built from `Dockerfile.voice-ingress` | Connects Revolt to LiveKit |

## Configuration Files

### compose.yml (relevant sections)

```yaml
# Web App (pre-built image with voice support)
web:
  image: ghcr.io/cjunks94/stoat-web:latest
  restart: always
  env_file: .env.web

# LiveKit: Voice/Video server
livekit:
  image: livekit/livekit-server:v1.8.0
  command: --config /etc/livekit.yml
  restart: always
  ports:
    - "7880:7880"
    - "7881:7881"
    - "7882:7882/udp"
  volumes:
    - ./livekit.yml:/etc/livekit.yml

# Voice ingress daemon
voice-ingress:
  build:
    context: .
    dockerfile: Dockerfile.voice-ingress
  volumes:
    - ./Revolt.toml:/Revolt.toml
```

### Revolt.toml (add these sections)

```toml
[hosts.livekit]
worldwide = "wss://YOUR_DOMAIN/livekit"

[api.livekit.nodes.worldwide]
url = "http://livekit:7880"
lat = 0.0
lon = 0.0
key = "worldwide"
secret = "YOUR_LIVEKIT_SECRET"
```

### livekit.yml

```yaml
port: 7880
rtc:
  port_range_start: 7882
  port_range_end: 7882
  tcp_port: 7881
redis:
  address: redis:6379
keys:
  worldwide: YOUR_LIVEKIT_SECRET
logging:
  level: info
```

### Caddyfile (add livekit route)

```
handle /livekit* {
    uri strip_prefix /livekit
    reverse_proxy livekit:7880
}
```

## Building the Web Client

The web client is pre-built and pushed to `ghcr.io/cjunks94/stoat-web:latest`.

To rebuild (if needed):

```bash
# Clone stoatchat-infra
cd stoatchat-infra

# Build with your domain
docker build -f Dockerfile.web \
  --build-arg VITE_API_URL=https://YOUR_DOMAIN/api \
  --build-arg VITE_WS_URL=wss://YOUR_DOMAIN/ws \
  --build-arg VITE_MEDIA_URL=https://YOUR_DOMAIN/autumn \
  --build-arg VITE_PROXY_URL=https://YOUR_DOMAIN/january \
  -t ghcr.io/YOUR_USER/stoat-web:latest .

# Push to registry
docker login ghcr.io -u YOUR_USER
docker push ghcr.io/YOUR_USER/stoat-web:latest
```

## Why This Works

The issue was in the pre-built Docker image:
- The `stoat.js` SDK correctly hydrates the `voice` property
- But the pre-built image had it compiled for `stoat.chat`, not self-hosted instances
- Building from source with correct `VITE_*` environment variables fixes this

## Creating Voice Channels

Use the API to create a voice-enabled channel:

```bash
curl -X POST "https://YOUR_DOMAIN/api/servers/SERVER_ID/channels" \
  -H "x-session-token: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "Voice", "name": "Voice Chat"}'
```

Or via MongoDB:
```javascript
db.channels.updateOne(
  { name: "your-channel" },
  { $set: { voice: { max_users: 20 } } }
);
```

## Verification

1. Voice channel shows headset icon in sidebar ✅
2. Clicking channel shows voice call card ✅
3. "Join" button connects to LiveKit ✅
4. Audio works between users ✅

## Troubleshooting

### Voice icon not showing
- Ensure you're using the custom web image, not the default Revolt image
- Hard refresh browser (`Ctrl+Shift+R`)

### Can't connect to call
- Check LiveKit logs: `docker compose logs livekit`
- Verify LiveKit ports are open: 7880, 7881, 7882/udp
- Check voice-ingress logs: `docker compose logs voice-ingress`

### 502 errors
- Ensure Caddyfile routes to `web:80` (not 5000)
- Check web container logs: `docker compose logs web`
