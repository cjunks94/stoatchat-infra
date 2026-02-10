# Voice Channels - Investigation Notes

## Current Status: NOT WORKING

Voice channels are not fully supported in self-hosted Revolt/Stoat. The official README states:
> "This guide does not include working voice channels. A rework is currently in progress."

Related issues:
- https://github.com/revoltchat/self-hosted/issues/138
- https://github.com/revoltchat/backend/issues/313

## What Works

### Backend Infrastructure
- **LiveKit server** - Running and healthy
- **voice-ingress service** - Built from source, running
- **API configuration** - LiveKit enabled and advertised correctly
- **Database** - Voice channels can be created with correct schema

### API Response
The API correctly returns voice channel data:
```json
{
  "_id": "01KH2G3TF47HGZ2XK7NXKAT0QY",
  "channel_type": "TextChannel",
  "name": "ventrilo",
  "server": "01KH2G3DJEHGP93TFRE7GCWMJ1",
  "voice": { "max_users": 20 }
}
```

## What Doesn't Work

### Frontend (Web Client)
The pre-built Docker image (`ghcr.io/revoltchat/client:master`) does not render voice channel UI:
- No headset icon in sidebar
- No voice call card
- `channel.isVoice` returns `false` despite API returning `voice` property

## Root Cause Analysis

### How Voice Channels Work (In Theory)
1. **Channel Creation**: Use API with `type: "Voice"` (legacy enum)
2. **Database Storage**: Stored as `channel_type: "TextChannel"` with `voice: {}` object
3. **API Response**: Returns channel with `voice` property
4. **Frontend Hydration**: stoat.js SDK hydrates `voice` property
5. **UI Rendering**: `channel.isVoice` getter checks for `voice` object

### The Bug
The stoat.js SDK hydration (`packages/stoat.js/src/hydration/channel.ts`) should work:

```typescript
voice: (channel) =>
  !!channel.voice || channel.channel_type === 'DirectMessage' || channel.channel_type === 'Group' ? ({
    maxUsers: channel.voice?.max_users || undefined,
  }) : undefined,
```

And the getter (`packages/stoat.js/src/classes/Channel.ts`):

```typescript
get isVoice(): boolean {
  return (
    this.type === "DirectMessage" ||
    this.type === "Group" ||
    typeof this.#collection.getUnderlyingObject(this.id).voice === "object"
  );
}
```

**Suspected Issue**: The pre-built Docker image may use an older version of stoat.js that doesn't properly hydrate the `voice` property for TextChannels with voice enabled.

## Attempted Fixes

### 1. Manual Database Update
Changed channel to have `voice` property:
```javascript
db.channels.updateOne(
  { name: "ventrilo" },
  { $set: { channel_type: "TextChannel", voice: { max_users: 20 } } }
);
```
Result: API returns voice property, but frontend still doesn't show voice UI.

### 2. Building Web Client from Source
Attempted to build `revoltchat/frontend` from source to get latest stoat.js.

**Blockers**:
- Assets submodule uses private SSH repo (`ssh://git@github.com/stoatchat/assets`)
- Complex workspace dependencies (lingui-solid, panda CSS, etc.)
- Build fails without assets

## How to Fix (Future Work)

### Option A: Wait for Official Support
The Revolt team is actively reworking voice. Monitor:
- https://github.com/revoltchat/self-hosted/issues/138

### Option B: Fork and Fix Frontend
1. Fork `revoltchat/frontend`
2. Get access to assets or create placeholders
3. Fix stoat.js hydration if needed
4. Build and publish custom Docker image

### Option C: Patch at Runtime
Inject JavaScript to fix the hydration at runtime (hacky but possible).

### Option D: Use Alternative Clients
- Desktop app (Tauri-based)
- Mobile apps
- Third-party clients

These may have working voice support since the backend is correctly configured.

## Files Investigated

| File | Location | Purpose |
|------|----------|---------|
| `ServerSidebar.tsx` | `packages/client/src/interface/navigation/channels/` | Renders channel list with voice icon |
| `TextChannel.tsx` | `packages/client/src/interface/channels/text/` | Renders voice call card when `isVoice` |
| `ChannelPage.tsx` | `packages/client/src/interface/channels/` | Routes channel types |
| `Channel.ts` | `packages/stoat.js/src/classes/` | `isVoice` getter |
| `channel.ts` | `packages/stoat.js/src/hydration/` | Hydrates voice property |
| `state.tsx` | `packages/client/components/rtc/` | Voice/LiveKit state management |

## Infrastructure Setup (Working)

### compose.yml additions
```yaml
# LiveKit server
livekit:
  image: livekit/livekit-server:v1.8.0
  command: --config /etc/livekit.yml
  ports:
    - "7880:7880"
    - "7881:7881"
    - "7882:7882/udp"
  volumes:
    - ./livekit.yml:/etc/livekit.yml

# Voice ingress (built from source)
voice-ingress:
  build:
    context: .
    dockerfile: Dockerfile.voice-ingress
  volumes:
    - ./Revolt.toml:/Revolt.toml
```

### Revolt.toml additions
```toml
[hosts.livekit]
worldwide = "wss://chat.example.com/livekit"

[api.livekit.nodes.worldwide]
url = "http://livekit:7880"
lat = 0.0
lon = 0.0
key = "worldwide"
secret = "YOUR_SECRET"
```

### Caddyfile additions
```
handle /livekit* {
    reverse_proxy livekit:7880
}
```

## Conclusion

The backend voice infrastructure is correctly set up. The blocker is the frontend web client not rendering voice UI. This is a known limitation of self-hosted Revolt and is being actively worked on by the Revolt team.
