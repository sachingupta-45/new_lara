# CRM

Laravel application running in Docker (PHP-FPM 8.4 + Nginx). You only need Docker and Git on your machine. PHP, Composer and Node run inside containers.

## Requirements

- Docker with Docker Compose v2
- Git
- On Windows: WSL 2 (Ubuntu). Clone and run everything from inside WSL, not from a Windows folder.
- A MySQL container attached to the external `central_db_network` Docker network

## Project structure

| Path | Purpose |
|---|---|
| `compose.yaml` | Base / production services (`app`, `nginx`) |
| `compose.dev.yaml` | Development overrides (live code mount, dev PHP image) |
| `docker/php/Dockerfile` | PHP image with `development` and `production` targets |
| `docker/php/entrypoint.dev.sh` | Dev startup: installs dependencies, generates `APP_KEY`, links storage |
| `docker/nginx/` | Nginx image and site config |

---

## Development setup

### 1. Clone and configure

```bash
git clone https://github.com/sachingupta-45/new_lara.git
cd new_lara
cp .env.example .env
```

Edit `.env` and set the database connection:

```env
DB_CONNECTION=mysql
DB_HOST=your_mysql_container_name
DB_PORT=3306
DB_DATABASE=crm
DB_USERNAME=your_user
DB_PASSWORD=your_password
```

To find the MySQL container name on the shared network:

```bash
docker network inspect central_db_network --format '{{range .Containers}}{{.Name}} {{end}}'
```

If the network does not exist yet:

```bash
docker network create central_db_network
```

### 2. Start the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

On first start the app container automatically:

- runs `composer install`
- generates `APP_KEY` if it is empty
- creates the `public/storage` link

Watch progress with:

```bash
docker compose -f compose.yaml -f compose.dev.yaml logs -f app
```

### 3. Run migrations

```bash
docker compose -f compose.yaml -f compose.dev.yaml exec app php artisan migrate
```

### 4. Build frontend assets

```bash
docker run --rm -v "$PWD":/app -w /app -u "$(id -u):$(id -g)" node:22-alpine \
  sh -c "npm install && npm run build"
```

Open http://localhost.

> **Tip:** To avoid typing both `-f` flags every time, run this once per terminal session:
>
> ```bash
> export COMPOSE_FILE=compose.yaml:compose.dev.yaml
> ```
>
> Then plain `docker compose up -d`, `docker compose exec app ...` etc. use the dev setup.

### Everyday commands (development)

```bash
# Start / stop
docker compose -f compose.yaml -f compose.dev.yaml up -d
docker compose -f compose.yaml -f compose.dev.yaml down

# Artisan
docker compose -f compose.yaml -f compose.dev.yaml exec app php artisan <command>

# Composer
docker compose -f compose.yaml -f compose.dev.yaml exec app composer require <package>

# Shell inside the app container
docker compose -f compose.yaml -f compose.dev.yaml exec app sh

# Logs
docker compose -f compose.yaml -f compose.dev.yaml logs -f
```

### User ID note

The dev image runs as UID/GID `1000` so files created in the container belong to you. Check yours with `id -u`. If it is not `1000`, build with:

```bash
docker compose -f compose.yaml -f compose.dev.yaml build \
  --build-arg UID=$(id -u) --build-arg GID=$(id -g)
```

---

## Production deployment

Production images contain the code and dependencies, so the server needs no PHP or Composer.

### 1. First-time setup on the server

```bash
git clone https://github.com/sachingupta-45/new_lara.git
cd new_lara
cp .env.example .env
```

Edit `.env`:

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.com

DB_CONNECTION=mysql
DB_HOST=your_mysql_container_name
DB_DATABASE=crm
DB_USERNAME=your_user
DB_PASSWORD=your_password
```

Generate the application key **once** and paste it into `.env` as `APP_KEY=base64:...`:

```bash
docker compose build app
docker compose run --rm app php artisan key:generate --show
```

> Never change `APP_KEY` after going live. It encrypts sessions and stored data, and changing it logs everyone out and makes encrypted data unreadable.

### 2. Deploy (first time and every update)

```bash
git pull
docker compose up -d --build
docker compose exec app php artisan migrate --force
docker compose exec app php artisan optimize
```

`optimize` caches config, routes and views. Run it after every deploy **and** after any change to `.env`.

### Useful production commands

```bash
docker compose ps                                    # container status
docker compose logs -f app                           # PHP logs
docker compose logs -f nginx                         # web server logs
docker compose exec app php artisan optimize:clear   # clear all caches
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `vendor/autoload.php not found` (dev) | Restart the app container; the entrypoint runs `composer install`. Check `logs -f app`. |
| `Vite manifest not found` | Build the frontend assets (development step 4). |
| `network central_db_network not found` | `docker network create central_db_network` |
| `/bin/sh^M: not found` | A `.sh` file has Windows line endings. Run `sed -i 's/\r$//' docker/php/entrypoint.dev.sh` and rebuild. |
| Permission denied on `storage/` (dev) | Your UID is not `1000`; see the user ID note above. |
| Uploaded files return 404 | Run `php artisan storage:link` inside the app container. |