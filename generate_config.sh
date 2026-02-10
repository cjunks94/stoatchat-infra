#!/usr/bin/env bash

# set hostname for Caddy
echo "HOSTNAME=https://$1" > .env.web
echo "REVOLT_PUBLIC_URL=https://$1/api" >> .env.web

# hostnames
echo "[hosts]" >> Revolt.toml
echo "app = \"https://$1\"" >> Revolt.toml
echo "api = \"https://$1/api\"" >> Revolt.toml
echo "events = \"wss://$1/ws\"" >> Revolt.toml
echo "autumn = \"https://$1/autumn\"" >> Revolt.toml
echo "january = \"https://$1/january\"" >> Revolt.toml

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
echo "worldwide = \"wss://$1/livekit\"" >> Revolt.toml
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
  use_external_ip: true
redis:
  address: redis:6379
keys:
  worldwide: $LIVEKIT_SECRET
logging:
  level: info
EOF
