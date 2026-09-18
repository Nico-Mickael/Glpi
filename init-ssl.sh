#!/bin/bash
# Initialisation SSL Let's Encrypt pour GLPI (Linux)
# A executer une seule fois avant le premier "docker compose up -d"

COMPOSE_FILE="docker-compose.prod.yml"
set -a; source .env; set +a
CERT_DIR="certbot/conf/live/$DOMAIN"

if [ -d "$CERT_DIR" ]; then
    echo "Certificat deja present, demarrage direct..."
else
    echo "Obtention du certificat SSL pour $DOMAIN (email : $EMAIL)..."
    docker compose -f "$COMPOSE_FILE" run --rm --service-ports --entrypoint "" certbot certonly \
        --standalone --preferred-challenges http \
        --email "$EMAIL" --agree-tos --no-eff-email \
        -d "$DOMAIN" || {
            echo "ERREUR: impossible d'obtenir le certificat. Verifiez que le DNS pointe vers ce serveur." >&2
            exit 1
        }
fi

docker compose -f "$COMPOSE_FILE" up -d
echo "GLPI prod demarre : https://$DOMAIN"