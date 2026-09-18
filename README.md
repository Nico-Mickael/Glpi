# GLPI - Déploiement Production

Stack Docker GLPI personnalisée avec **MariaDB 11**, **Nginx** (reverse proxy HTTPS) et **Certbot** (Let's Encrypt).

## Architecture

```
Client ──> 443 ──> nginx (TLS + reverse proxy) ──> glpi_app:80
Client ──>  80 ──> certbot (challenge ACME)      ──> glpi_bd:3306 (interne)
```

| Service   | Image                  | Rôle                          |
|-----------|------------------------|-------------------------------|
| `db`      | `mika210602/glpi_bd:1.0`  | MariaDB 11                    |
| `glpi`    | `mika210602/glpi_app:1.0` | GLPI personnalisé (Apache)    |
| `nginx`   | `nginx:stable-alpine`   | Reverse proxy + TLS           |
| `certbot` | `certbot/certbot`       | Émission/renouvellement SSL   |

## Fichiers

| Fichier                   | Description                                   |
|---------------------------|-----------------------------------------------|
| `docker-compose.yml`      | Stack de développement (port 8080)            |
| `docker-compose.prod.yml` | Stack de production (ports 80/443)            |
| `nginx/glpi.conf.template`| Config nginx (auto-substitution `${DOMAIN}`) |
| `init-ssl.ps1` / `.sh`    | Obtention du certificat + démarrage           |
| `.env`                    | Variables d'environnement (secrets)           |

---

## Prérequis

- Un serveur (Debian/Ubuntu) avec **Docker** et **Docker Compose v2**
- Un domaine pointant vers l'IP du serveur (record DNS `A`)
- Les images Docker Hub `mika210602/glpi_app:1.0` et `mika210602/glpi_bd:1.0`

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
git clone https://ton-repo/glpi.git /opt/glpi
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
| `DOMAIN`            | **Domaine public** (record DNS `A`)  |
| `EMAIL`             | Email de contact Let's Encrypt       |

> Le fichier `.env` est gitignoré : vos secrets ne sont jamais commités.

### 5. Vérifier le DNS avant le certificat

```bash
nslookup ades-solaire-glpi.org
dig +short ades-solaire-glpi.org
```

⚠️ Le résultat doit être **l'IP publique du serveur**, sinon certbot échouera.

### 6. Lancer l'init SSL + démarrage

```bash
chmod +x init-ssl.sh
./init-ssl.sh
```

Le script :
1. Obtient le certificat Let's Encrypt (challenge HTTP sur le port 80, mode standalone)
2. Démarre toute la stack

En cas d'échec du certificat, vérifiez le DNS puis relancez le script.

### 7. Vérifier le déploiement

```bash
docker compose -f docker-compose.prod.yml ps
curl -I https://ades-solaire-glpi.org
```

### 8. Terminer l'installation GLPI

Ouvrir `https://ades-solaire-glpi.org` dans le navigateur et :
- Sélectionner le serveur MySQL (`db`) : host `db`, port `3306`, base/utilisateur/mdp du `.env`

---

## Renouvellement du certificat

Automatique et sans intervention :
- **certbot** tente un renouvellement toutes les **12h** (`--webroot`)
- **nginx** recharge sa config toutes les **6h** (reprise des nouveaux certificats)

Test manuel :
```bash
docker compose -f docker-compose.prod.yml run --rm --entrypoint "" certbot renew --dry-run
```

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
docker pull mika210602/glpi_app:1.0           # nouvelle version
docker compose -f docker-compose.prod.yml up -d
```

---

## Dépannage

| Problème                          | Solution                                          |
|-----------------------------------|---------------------------------------------------|
| Certbot échoue (`DNS not found`)  | Point de DNS A vers l'IP publique, attendre TTL   |
| Nginx ne démarre pas              | Le certificat n'existe pas : relancer `init-ssl.sh` |
| `502 Bad Gateway`                 | GLPI pas encore prêt : `docker compose ... logs glpi` |
| Port 80/443 occupé                | `sudo lsof -i :80 -i :443` puis libérer le port   |
| Erreur DB à l'install GLPI        | Vérifier `db` est healthy : `docker compose ... ps` |