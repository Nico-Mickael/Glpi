# GLPI - Déploiement Production (usage interne)

Stack Docker GLPI personnalisée avec **MariaDB 11** et **Nginx** (reverse proxy HTTPS **auto-signé**, usage réseau interne d'entreprise).

## Architecture

```
Client ──> 8445 ──> nginx (TLS auto-signé) ──> glpi_app:80
Client ──> 8446 ──> nginx (HTTP)             ──> glpi_bd:3306 (interne)
```

| Service | Image                     | Rôle                     |
|---------|---------------------------|--------------------------|
| `db`    | `mika210602/glpi_bd:latest` | MariaDB 11               |
| `glpi`  | `mika210602/glpi_app:latest`| GLPI personnalisé (Apache) |
| `nginx` | `nginx:stable-alpine`      | Reverse proxy TLS (8445) |

> Pas de Let's Encrypt : le domaine ne résout pas publiquement, le certificat est **auto-signé** (généré par `scripts/gen-cert.sh`, valable 10 ans).

## Structure du projet

```
.
├── docker/
│   ├── glpi_app/            # Dockerfile GLPI (base glpi/glpi)
│   ├── glpi_bd/             # Dockerfile MariaDB (base mariadb:11)
│   └── nginx/               # glpi.conf.template (auto-substitution ${DOMAIN})
├── scripts/
│   ├── deploy.sh            # Déploiement manuel vers le serveur
│   ├── init-ssl.sh          # Génération certificat + démarrage (Linux)
│   ├── init-ssl.ps1         # Idem (Windows)
│   ├── gen-cert.sh          # Certificat auto-signé (interne)
│   └── setup-server.sh      # Préparation complète du serveur Debian
├── .github/workflows/
│   └── ci-cd.yml            # Pipeline build + push + deploy
├── certs/                   # (local, gitignoré) certificats auto-signés
├── docker-compose.yml       # Stack de développement (port 8080)
├── docker-compose.prod.yml  # Stack de production (ports 8445/8446)
├── .env                     # (local, gitignoré) variables secrètes
├── .env.example             # Template des variables
└── README.md
```

---

## Prérequis

- Un serveur (Debian/Ubuntu) avec **Docker** et **Docker Compose v2**
- Les images Docker Hub `mika210602/glpi_app:latest` et `mika210602/glpi_bd:latest`
- Routage interne : le serveur doit être joignable depuis les postes utilisateurs (IP interne, ex: `10.85.1.14`)
- Les ports **8445** (HTTPS) et **8446** (HTTP) libres sur le serveur

> Le certificat est **auto-signé** (certificat interne, pas de Let's Encrypt). Les navigateurs afficheront un avertissement de sécurité à valider une première fois — prévoir si besoin l'ajout du certificat au magasin de confiance de l'entreprise.

---

## Déploiement sur serveur Debian

### 1. Installer Docker

```bash
curl -fsSL https://get.docker.com | sh
```

### 2. Vérifier l'installation

```bash
docker --version
docker compose version   # Docker Compose v2 requis
```

### 3. Récupérer le projet

```bash
apt install -y git
git clone https://github.com/Nico-Mickael/Glpi.git /opt/glpi
cd /opt/glpi
```

### 4. Configurer `.env`

```bash
nano .env
```

| Variable            | Description                          |
|---------------------|--------------------------------------|
| `MYSQL_DATABASE`    | Nom de la base GLPI                  |
| `MYSQL_USER`        | Utilisateur MySQL                    |
| `MYSQL_PASSWORD`    | Mot de passe MySQL (car. spéciaux OK)|
| `GLPI_LANG`         | Langue (ex: `fr_FR`)                 |
| `TIMEZONE`          | Fuseau (ex: `Indian/Antananarivo`)   |
| `DOMAIN`            | Nom interne (identifie le certificat)|
| `EMAIL`             | Email de contact (non utilisé ici)   |
| `SERVER_IP`         | IP interne du serveur (ex: `10.85.1.14`) |

> Le fichier `.env` est gitignoré : vos secrets ne sont jamais commités.

### 5. Lancer la génération du certificat + démarrage

```bash
chmod +x scripts/init-ssl.sh
bash scripts/init-ssl.sh
```

Le script :
1. Génère le certificat auto-signé (10 ans, DNS `DOMAIN` + IP `SERVER_IP`)
2. Démarre toute la stack

Rejouable à volonté : si le certificat existe déjà, il est conservé.

### 6. Vérifier le déploiement

```bash
docker compose -f docker-compose.prod.yml ps
curl -k -I https://10.85.1.14:8445
```

([`-k`](commande curl) ignore le certificat auto-signé)

### 7. Terminer l'installation GLPI

Ouvrir `https://10.85.1.14:8445` (ou le domaine interne) dans le navigateur et :
- Sélectionner le serveur MySQL (`db`) : host `db`, port `3306`, base/utilisateur/mdp du `.env`

---

## Certificat auto-signé

Généré par `scripts/gen-cert.sh` (appelé par `init-ssl.sh`), dans `certs/live/$DOMAIN/` :
```bash
bash scripts/gen-cert.sh              # régénérer si besoin (détruit l'existant)
rm -rf certs && bash scripts/init-ssl.sh   # forcer une nouvelle génération
```

Le certificat est **valable 10 ans**. Pour éviter l'avertissement navigateur, distribuer le certificat aux postes (GPO / politique d'entreprise).

---

## Maintenance

### Arrêt / redémarrage sans perte de données

```bash
docker compose -f docker-compose.prod.yml down     # arrêt (les volumes sont conservés)
docker compose -f docker-compose.prod.yml up -d    # redémarrage
```

⚠️ Ne **jamais** supprimer les volumes `glpi_db_data` et `glpi_data`, sinon perte totale des données.

### Sauvegarde de la base

```bash
docker exec glpi_db sh -c 'exec mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' > backup_$(date +%Y%m%d).sql
```

### Mettre à jour GLPI

```bash
docker pull mika210602/glpi_app:latest        # nouvelle version
docker compose -f docker-compose.prod.yml up -d
```

---

## CI/CD — GitHub Actions

À chaque `push` sur `main`, le workflow `.github/workflows/ci-cd.yml` :

1. **Build** les 2 images → **push** sur Docker Hub (`mika210602/glpi_app` et `mika210602/glpi_bd`), tags `latest` + `sha`
2. **Deploy** : connexion SSH au serveur Debian → `git pull`, `docker compose pull`, `up -d`

### Dockerfiles

| Dossier      | Base            | Personnalisation              |
|--------------|-----------------|-------------------------------|
| `glpi_app/`  | `glpi/glpi:latest` | plugins/thèmes GLPI (colonne à ajouter au `Dockerfile`) |
| `glpi_bd/`   | `mariadb:11`    | fichiers `.cnf` MariaDB        |

> Tes images actuelles (`:1.0`) sont restées basées sur la structure officielle GLPI (entrypoint `/opt/glpi/entrypoint.sh`, supervisord, PHP 8.5/Apache). La CI repart de l'officiel et ton custom se déclare dans les Dockerfiles.

### Secrets GitHub à configurer

Clic sur **Settings → Secrets and variables → Actions** du repo `Nico-Mickael/Glpi` :

| Secret                | Valeur                                  |
|-----------------------|-----------------------------------------|
| `DOCKER_USERNAME`     | `mika210602`                            |
| `DOCKER_TOKEN`        | Token (Settings → Tokens → "Read, Write, Delete") |
| `SERVER_HOST`         | `10.85.1.14` (IP interne du serveur)    |
| `SERVER_USER`         | `micka` (avec accès `sudo docker`)      |
| `SERVER_SSH_KEY`      | Clé privée SSH (`-----BEGIN OPENSSH PRIVATE KEY-----...`) |

Sur le serveur : la clé publique correspondante doit être dans `~micka/.ssh/authorized_keys`, et `micka` doit pouvoir exécuter `sudo docker` (l'utilisateur devra être dans le groupe `docker`, voir Dépannage).

### Première exécution

1. Le job deploy clone le repo dans `/opt/glpi`
2. Si `.env` manque, il copie `.env.example` et **échoue volontairement** → tu rentres en SSH :
   ```bash
   sudo nano /opt/glpi/.env    # DOMAIN, EMAIL, mot de passe, SERVER_IP
   ```
3. Relance le workflow (`workflow_dispatch` ou re-push) → déploiement complet

### Déployer manuellement depuis la machine locale

```bash
SERVER_HOST=10.85.1.14 SERVER_USER=micka DOMAIN=glpi-ades-solaire.mg bash scripts/deploy.sh
```

---

## Dépannage

| Problème                          | Solution                                          |
|-----------------------------------|---------------------------------------------------|
| `permission denied ... docker.sock`| `sudo usermod -aG docker micka` puis déconnexion/reconnexion SSH |
| Nginx ne démarre pas              | Le certificat n'existe pas : relancer `scripts/init-ssl.sh` |
| `502 Bad Gateway`                 | GLPI pas encore prêt : `docker compose ... logs glpi` |
| Port 8445 déjà utilisé            | `sudo lsof -i :8445` puis libérer, ou changer le port dans `docker-compose.prod.yml` |
| Avertissement certificat (navigateur) | Normal (auto-signé). Cliquer "Continuer" ou distribuer le certificat `certs/` aux postes |
| Erreur DB à l'install GLPI        | Vérifier `db` est healthy : `docker compose ... ps` |