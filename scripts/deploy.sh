#!/bin/bash
# deploy.sh — Déploiement/synchronisation manuelle sur le serveur Debian
# Le serveur doit pouvoir : docker, docker compose v2, et le repo cloné.
# Usage : SERVER_HOST=ip.du.serveur SERVER_USER=micka DOMAIN=mon.domaine.mg bash scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-root}"
DOMAIN="${DOMAIN:-}"

if [ -z "$SERVER_HOST" ]; then
    echo "Usage: SERVER_HOST=ip.du.serveur SERVER_USER=micka DOMAIN=mon.domaine.mg bash scripts/deploy.sh" >&2
    exit 1
fi

cd "$REPO_DIR"

echo "==> Synchronisation du repo sur $SERVER_USER@$SERVER_HOST"
ssh "$SERVER_USER@$SERVER_HOST" 'mkdir -p /opt/glpi'
scp -r docker-compose.prod.yml docker-compose.yml .env docker scripts \
    "$SERVER_USER@$SERVER_HOST":/opt/glpi/ 2>/dev/null || {
        echo "Impossible de copier .env (peut-être absent localement)." >&2
        exit 1
    }

ssh "$SERVER_USER@$SERVER_HOST" "cd /opt/glpi && chmod +x scripts/init-ssl.sh && DOMAIN='$DOMAIN' bash scripts/init-ssl.sh"
echo "==> Déploiement terminé"