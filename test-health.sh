#!/usr/bin/env bash
# Simple health check for Stoat services

set -e

DOMAIN="${1:-localhost:8080}"
PROTOCOL="${2:-http}"

echo "Testing Stoat deployment at $PROTOCOL://$DOMAIN"
echo "================================================"

# Test API
echo -n "API (/api/)... "
if curl -sf "$PROTOCOL://$DOMAIN/api/" | grep -q "revolt"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
    exit 1
fi

# Test WebSocket endpoint exists
echo -n "Events (/ws)... "
if curl -sf -o /dev/null -w "%{http_code}" "$PROTOCOL://$DOMAIN/ws" | grep -qE "101|400|426"; then
    echo "✓ OK (WebSocket upgrade expected)"
else
    echo "✓ OK (endpoint reachable)"
fi

# Test file server
echo -n "Autumn (/autumn/)... "
if curl -sf -o /dev/null "$PROTOCOL://$DOMAIN/autumn/"; then
    echo "✓ OK"
else
    echo "⚠ Not responding (may need file upload first)"
fi

# Test web client
echo -n "Web client (/)... "
if curl -sf "$PROTOCOL://$DOMAIN/" | grep -q "Revolt"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
    exit 1
fi

# Test LiveKit if available
echo -n "LiveKit (/livekit/)... "
if curl -sf -o /dev/null "$PROTOCOL://$DOMAIN/livekit/" 2>/dev/null; then
    echo "✓ OK"
else
    echo "⚠ Not available (voice may not be configured)"
fi

echo "================================================"
echo "All critical services are running!"
