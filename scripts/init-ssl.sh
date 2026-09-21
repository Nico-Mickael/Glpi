# Initialisation SSL pour GLPI — usage INTERNE (auto-signe)
# A executer une seule fois avant le premier "docker compose up -d"
# Usage : bash scripts/init-ssl.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

COMPOSE_FILE="docker-compose.prod.yml"

bash scripts/gen-cert.sh
docker compose -f "$COMPOSE_FILE" up -d

set -a; source .env; set +a
echo "GLPI prod demarre : https://$(hostname -I | awk '{print $1}'):8445 (interne)"