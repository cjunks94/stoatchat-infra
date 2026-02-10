#!/usr/bin/env bash

# Usage: ./generate_config.sh <domain> [--invite-only]

DOMAIN="$1"
INVITE_ONLY=false

# Parse flags
for arg in "$@"; do
  case $arg in
    --invite-only)
      INVITE_ONLY=true
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "Usage: ./generate_config.sh <domain> [--invite-only]"
  exit 1
fi

# set hostname for Caddy
echo "HOSTNAME=https://$DOMAIN" > .env.web
echo "REVOLT_PUBLIC_URL=https://$DOMAIN/api" >> .env.web

# hostnames
echo "[hosts]" >> Revolt.toml
echo "app = \"https://$DOMAIN\"" >> Revolt.toml
echo "api = \"https://$DOMAIN/api\"" >> Revolt.toml
echo "events = \"wss://$DOMAIN/ws\"" >> Revolt.toml
echo "autumn = \"https://$DOMAIN/autumn\"" >> Revolt.toml
echo "january = \"https://$DOMAIN/january\"" >> Revolt.toml

# VAPID keys
echo "" >> Revolt.toml
echo "[pushd.vapid]" >> Revolt.toml
openssl ecparam -name prime256v1 -genkey -noout -out vapid_private.pem
echo "private_key = \"$(base64 -i vapid_private.pem | tr -d '\n' | tr -d '=')\"" >> Revolt.toml
echo "public_key = \"$(openssl ec -in vapid_private.pem -outform DER|tail --bytes 65|base64|tr '/+' '_-'|tr -d '\n'|tr -d '=')\"" >> Revolt.toml
rm vapid_private.pem

# encryption key for files
echo "" >> Revolt.toml
echo "[files]" >> Revolt.toml
echo "encryption_key = \"$(openssl rand -base64 32)\"" >> Revolt.toml

# LiveKit configuration
LIVEKIT_SECRET=$(openssl rand -base64 32 | tr -d '/+=')
echo "" >> Revolt.toml
echo "[hosts.livekit]" >> Revolt.toml
echo "worldwide = \"wss://$DOMAIN/livekit\"" >> Revolt.toml
echo "" >> Revolt.toml
echo "[api.livekit.nodes.worldwide]" >> Revolt.toml
echo "url = \"http://livekit:7880\"" >> Revolt.toml
echo "lat = 0.0" >> Revolt.toml
echo "lon = 0.0" >> Revolt.toml
echo "key = \"worldwide\"" >> Revolt.toml
echo "secret = \"$LIVEKIT_SECRET\"" >> Revolt.toml

# Generate livekit.yml with matching secret
cat > livekit.yml << EOF
port: 7880
rtc:
  port_range_start: 7882
  port_range_end: 7882
  tcp_port: 7881
redis:
  address: redis:6379
keys:
  worldwide: $LIVEKIT_SECRET
logging:
  level: info
EOF

# Registration settings
echo "" >> Revolt.toml
echo "[api.registration]" >> Revolt.toml
if [ "$INVITE_ONLY" = true ]; then
  echo "invite_only = true" >> Revolt.toml
  echo ""
  echo "✓ Invite-only mode enabled"
  echo "  Create invites with: docker compose exec database mongosh --eval 'use revolt; db.invites.insertOne({ _id: \"your-code\" })'"
else
  echo "invite_only = false" >> Revolt.toml
fi

echo ""
echo "✓ Config generated for $DOMAIN"
