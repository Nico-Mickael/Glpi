# Initialisation certificat auto-signé + démarrage (Windows)
# Usage : powershell -ExecutionPolicy Bypass .\scripts\init-ssl.ps1
# Prérequis : openssl disponible dans le PATH

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
Set-Location $repoDir

$composeFile = "docker-compose.prod.yml"
$envFile = Join-Path $repoDir ".env"
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2]
    }
}

$certPath = Join-Path $repoDir "certs\live\$env:DOMAIN"

if (-not (Test-Path (Join-Path $certPath "fullchain.pem"))) {
    Write-Host "Generation du certificat auto-signe (usage interne)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $certPath | Out-Null
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 `
        -keyout (Join-Path $certPath "privkey.pem") `
        -out (Join-Path $certPath "fullchain.pem") `
        -subj "/CN=$env:DOMAIN" `
        -addext "subjectAltName=DNS:$env:DOMAIN,IP:$env:SERVER_IP"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR: openssl a échoué. Vérifiez son installation (sudo apt install openssl)." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Certificat deja present, demarrage direct..." -ForegroundColor Green
}

docker compose -f $composeFile up -d
Write-Host "GLPI prod demarre : https://$env:SERVER_IP`:8445 (interne)" -ForegroundColor Green