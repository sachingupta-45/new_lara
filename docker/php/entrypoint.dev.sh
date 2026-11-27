#!/bin/sh
# Development entrypoint: prepares a fresh clone so `docker compose up` just works.
# Each step is skipped if already done, so restarts stay fast.
set -e

cd /var/www/html

# 1. Create .env from the example on a brand-new clone
if [ ! -f .env ] && [ -f .env.example ]; then
    echo "[entrypoint] Creating .env from .env.example"
    cp .env.example .env
fi

# 2. Install PHP dependencies (vendor/ lives in an empty volume on a new device)
if [ ! -f vendor/autoload.php ]; then
    echo "[entrypoint] Installing Composer dependencies"
    composer install --no-interaction --prefer-dist
fi

# 3. Generate APP_KEY if it is missing or empty in .env
if [ -f .env ] && ! grep -q '^APP_KEY=..*' .env; then
    echo "[entrypoint] Generating APP_KEY"
    php artisan key:generate --force
fi

# 4. Link public/storage -> storage/app/public
if [ ! -L public/storage ]; then
    echo "[entrypoint] Creating storage link"
    php artisan storage:link
fi

# Hand over to the container's main process (php-fpm by default)
exec "$@"
