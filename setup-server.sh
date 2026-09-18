#!/bin/bash
# setup-server.sh — Déploiement automatique GLPI prod sur Debian/Ubuntu
# Mise à jour : Nettoie, installe Docker, clone le repo, vérifie le DNS, émet le SSL, démarre.

set -euo pipefail

# ===== Configuration (à adapter) =====
REPO_URL="${REPO_URL:-https://ton-repo/glpi.git}"
APP_DIR="${APP_DIR:-/opt/glpi}"
DOMAIN="${DOMAIN:-ades-solaire-glpi.org}"
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
    warn "Fichier .env manquant — création depuis un template..."
    cat > .env <<'EOF'
MYSQL_DATABASE=Glpi
MYSQL_USER=Admin-IT
MYSQL_PASSWORD=Chang3-Me-!
GLPI_LANG=fr_FR
TIMEZONE=Indian/Antananarivo
DOMAIN=exemple.org
EMAIL=admin@exemple.org
EOF
    warn "ÉDITEZ .env AVANT DE CONTINUER : nano $APP_DIR/.env"
    exit 1
fi
set -a; source .env; set +a

# ----- 4. Vérifier le DNS -----
log "Vérification du DNS pour $DOMAIN..."
IP_PUB="$(curl -fsSL --max-time 10 https://api.ipify.org || echo '')"
DNS_IP="$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || true)"
log "IP publique du serveur : ${IP_PUB:-INCONNUE}"
log "IP résolue par DNS      : ${DNS_IP:-INCONNUE}"
if [ -n "$DNS_IP" ] && [ -n "$IP_PUB" ] && [ "$DNS_IP" != "$IP_PUB" ] && [ "$DNS_IP" != "127.0.0.1" ]; then
    die "DNS INCOMPATIBLE : $DOMAIN pointe vers $DNS_IP, pas vers $IP_PUB. Corrigez le record A, puis relancez."
fi
[ -z "$DNS_IP" ] && die "DNS non résolu pour $DOMAIN. Vérifiez le record A, puis relancez."

# ----- 5. Obtenir le certificat SSL + démarrer -----
if [ -f init-ssl.sh ]; then
    chmod +x init-ssl.sh
    ./init-ssl.sh
else
    docker compose -f docker-compose.prod.yml up -d
fi

# ----- 6. Vérification finale -----
log "Création du répertoire des sauvegardes..."
mkdir -p /opt/backups

log "Vérification du déploiement..."
sleep 5
if curl -fsSI --max-time 10 "https://$DOMAIN" -o /dev/null; then
    log "=== SUCCÈS : https://$DOMAIN est accessible ==="
else
    warn "N'oubliez pas de terminer l'installation GLPI dans le navigateur sur https://$DOMAIN"
    docker compose -f docker-compose.prod.yml ps
fi