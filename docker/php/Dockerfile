# ==========================================
# STAGE 1: BASE PHP ENVIRONMENT
# ==========================================
FROM php:8.4-fpm-alpine AS base

WORKDIR /var/www/html

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
        pdo_mysql \
        zip \
        bcmath \
        intl \
        pcntl \
        opcache


# ==========================================
# STAGE 2: DEVELOPMENT
# ==========================================
FROM base AS development

ARG UID=1000
ARG GID=1000

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# git/unzip for composer, shadow for usermod/groupmod
RUN apk add --no-cache git unzip shadow \
    && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini" \
    && groupmod -o -g ${GID} www-data \
    && usermod -o -u ${UID} -g ${GID} www-data \
    && mkdir -p /var/www/html/vendor /var/www/.composer \
    && chown -R www-data:www-data /var/www

COPY docker/php/entrypoint.dev.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

USER www-data
ENTRYPOINT ["entrypoint"]
CMD ["php-fpm"]


# ==========================================
# STAGE 3: VENDOR (build only, not shipped)
# ==========================================
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --no-scripts \
    --no-autoloader \
    --ignore-platform-reqs

COPY . .
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative


# ==========================================
# STAGE 4: PRODUCTION
# ==========================================
FROM base AS production

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php/opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"

COPY --chown=www-data:www-data . .
COPY --chown=www-data:www-data --from=vendor /app/vendor ./vendor

RUN mkdir -p \
        storage/app/public \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache \
    && php artisan package:discover --ansi

USER www-data
CMD ["php-fpm"]