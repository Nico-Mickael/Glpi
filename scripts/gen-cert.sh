#!/bin/bash
# gen-cert.sh — Génère un certificat auto-signé pour usage INTERNE
# (Pas de Let's Encrypt : le domaine ne résout pas publiquement.)
# Usage : SERVER_IP=10.85.1.14 bash scripts/gen-cert.sh
# Le certificat est valable 10 ans et inclut le domaine + l'IP dans les SAN.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

set -a; source .env; set +a
CERT_DIR="certs/live/$DOMAIN"

if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
    echo "Certificat deja present : $CERT_DIR"
    exit 0
fi

mkdir -p "$CERT_DIR"
echo "Generation du certificat auto-signe pour $DOMAIN (IP : $SERVER_IP)..."
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,IP:$SERVER_IP"

chmod 600 "$CERT_DIR/privkey.pem"
echo "Certificat genere : certs/live/$DOMAIN/"