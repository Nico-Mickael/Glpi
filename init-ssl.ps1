# Initialisation SSL Let's Encrypt pour GLPI (Windows)
# A executer une seule fois avant le premier "docker compose up -d"

$composeFile = "docker-compose.prod.yml"
$certPath = "certbot\conf\live\$env:DOMAIN"

if (Test-Path $certPath) {
    Write-Host "Certificat deja present, demarrage direct..." -ForegroundColor Green
} else {
    # Le challenge se fait en standalone sur le port 80
    Write-Host "Obtention du certificat SSL pour $env:DOMAIN (email : $env:EMAIL)..." -ForegroundColor Yellow
    docker compose -f $composeFile run --rm --service-ports --entrypoint "" certbot certonly `
        --standalone --preferred-challenges http `
        --email $env:EMAIL --agree-tos --no-eff-email `
        -d $env:DOMAIN
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR: impossible d'obtenir le certificat. Verifiez que le DNS pointe vers ce serveur." -ForegroundColor Red
        exit 1
    }
}

docker compose -f $composeFile up -d
Write-Host "GLPI prod demarre : https://$env:DOMAIN" -ForegroundColor Green