#!/bin/bash
# setup-server.sh — Déploiement automatique GLPI prod sur Debian/Ubuntu (usage interne)
# Installe Docker, clone le repo, génère le certificat auto-signé, démarre la stack.

set -euo pipefail

# ===== Configuration (à adapter) =====
REPO_URL="${REPO_URL:-https://ton-repo/glpi.git}"
APP_DIR="${APP_DIR:-/opt/glpi}"
DOMAIN="${DOMAIN:-glpi-ades-solaire.mg}"
FQDN_REPO="$(basename -s .git "$REPO_URL")"
# =====================================

log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
die()  { echo -e "\033[1;31m[x] $*\033[0m" >&2; exit 1; }

# ----- 1. Installer Docker -----
log "Installation de Docker..."
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
else
    warn "Docker déjà installé."
fi
command -v docker >/dev/null 2>&1 || die "Échec de l'installation de Docker."

# ----- 1b. Docker Compose v2 (plugin) -----
log "Vérification de Docker Compose..."
if ! docker compose version >/dev/null 2>&1; then
    warn "Compose v2 absent, installation du plugin..."
    apt update -qq
    apt install -y docker-compose-plugin || die "Impossible d'installer docker-compose-plugin."
fi
docker compose version

# ----- 2. Cloner le projet -----
log "Récupération du projet ($REPO_URL)..."
apt install -y git >/dev/null 2>&1 || true
if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
else
    warn "$APP_DIR existe déjà — mise à jour en cours..."
    git -C "$APP_DIR" pull --ff-only
fi
cd "$APP_DIR"

# ----- 3. Vérifier le .env -----
log "Vérification du .env..."
if [ ! -f .env ]; then
    warn "Fichier .env manquant — création depuis .env.example..."
    cp .env.example .env
    warn "ÉDITEZ .env AVANT DE CONTINUER : nano $APP_DIR/.env"
    exit 1
fi
set -a; source .env; set +a

# ----- 4. Vérifier les droits Docker -----
log "Vérification des droits Docker pour $USER..."
if ! docker info >/dev/null 2>&1; then
    warn "L'utilisateur $USER n'a pas accès au socket Docker."
    warn "Ajoutez-le au groupe docker : sudo usermod -aG docker $USER  (puis reconnexion)"
    die "Droits Docker manquants."
fi

# ----- 5. Générer le certificat + démarrer -----
if [ -f scripts/init-ssl.sh ]; then
    chmod +x scripts/init-ssl.sh
    bash scripts/init-ssl.sh
else
    bash scripts/gen-cert.sh
    docker compose -f docker-compose.prod.yml up -d
fi

# ----- 6. Vérification finale -----
log "Création du répertoire des sauvegardes..."
mkdir -p /opt/backups

log "Vérification du déploiement..."
sleep 5
if curl -fkSI --max-time 10 "https://${SERVER_IP:-10.85.1.14}:8445" -o /dev/null; then
    log "=== SUCCÈS : https://${SERVER_IP:-10.85.1.14}:8445 est accessible (interne) ==="
else
    warn "N'oubliez pas de terminer l'installation GLPI dans le navigateur sur https://${SERVER_IP:-10.85.1.14}:8445"
    docker compose -f docker-compose.prod.yml ps
fi