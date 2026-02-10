#!/bin/bash
set -e

# Stoat Deploy Script
# Can run from:
#   - Local machine: ./deploy.sh --push (build & push to GHCR)
#   - VPS: ./deploy.sh (build from source & restart)

GHCR_IMAGE="ghcr.io/cjunks94/stoat-web"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Modes
MODE="vps"  # vps, push, pull
BUILD_WEB=true
BUILD_VOICE=false
RESTART_ALL=false
PULL_REPO=true

show_help() {
    echo "Usage: ./deploy.sh [options]"
    echo ""
    echo "Local machine options (build & push to GHCR):"
    echo "  --push          Build locally and push to GHCR"
    echo ""
    echo "VPS options (default):"
    echo "  --web           Rebuild web frontend from source (default)"
    echo "  --voice         Rebuild voice-ingress service"
    echo "  --all           Rebuild all and restart everything"
    echo "  --pull          Pull image from GHCR (after local --push)"
    echo "  --restart       Just restart services (no rebuild)"
    echo "  --no-git        Skip git pull"
    echo ""
    echo "  -h, --help      Show this help"
    echo ""
    echo "Workflows:"
    echo "  VPS build:    ./deploy.sh                  # Build on VPS from GitHub source"
    echo "  Local build:  ./deploy.sh --push           # Build locally, push to GHCR"
    echo "              then on VPS: ./deploy.sh --pull  # Pull from GHCR and restart"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --push) MODE="push"; shift ;;
        --pull) MODE="pull"; shift ;;
        --web) BUILD_WEB=true; shift ;;
        --voice) BUILD_VOICE=true; shift ;;
        --all) BUILD_WEB=true; BUILD_VOICE=true; RESTART_ALL=true; shift ;;
        --restart) BUILD_WEB=false; BUILD_VOICE=false; shift ;;
        --no-git) PULL_REPO=false; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) error "Unknown option: $1. Use --help for usage." ;;
    esac
done

# === LOCAL: Build and push to GHCR ===
if [ "$MODE" = "push" ]; then
    log "Building web frontend locally..."
    docker build -t "$GHCR_IMAGE:latest" -f Dockerfile.web .

    log "Pushing to GHCR..."
    docker push "$GHCR_IMAGE:latest"

    log "Done! Now run on VPS: ./deploy.sh --pull"
    exit 0
fi

# === VPS: Pull from GHCR ===
if [ "$MODE" = "pull" ]; then
    log "Pulling latest image from GHCR..."
    docker pull "$GHCR_IMAGE:latest"

    log "Restarting web service..."
    docker compose up -d web

    log "Deployment complete!"
    docker compose ps | grep web
    exit 0
fi

# === VPS: Build from source ===
log "Starting VPS deployment..."

# Pull latest repo changes
if [ "$PULL_REPO" = true ]; then
    log "Pulling latest repo changes..."
    git pull
fi

# Build web frontend
if [ "$BUILD_WEB" = true ]; then
    log "Building web frontend (this may take a few minutes)..."
    docker compose build web --no-cache
fi

# Build voice-ingress
if [ "$BUILD_VOICE" = true ]; then
    log "Building voice-ingress..."
    docker compose build voice-ingress --no-cache
fi

# Restart services
if [ "$RESTART_ALL" = true ]; then
    log "Restarting all services..."
    docker compose up -d
else
    if [ "$BUILD_WEB" = true ]; then
        log "Restarting web service..."
        docker compose up -d web
    fi
    if [ "$BUILD_VOICE" = true ]; then
        log "Restarting voice-ingress service..."
        docker compose up -d voice-ingress
    fi
fi

log "Deployment complete!"
echo ""
docker compose ps | grep -E "web|voice"
