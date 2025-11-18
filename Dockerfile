# --- STAGE 1: PHP Dependencies (Composer) ---
FROM composer:2 AS composer_builder
WORKDIR /app

# Copiem el codi de l'aplicació
COPY . .

# Instal·lem les dependències de PHP (incloent tightenco/ziggy)
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction

# --- STAGE 2: Build de Node (Assets) ---
FROM node:20-alpine AS node_builder
WORKDIR /app

# Copiem el codi de l'aplicació (incloent el directori vendor)
COPY --from=composer_builder /app /app

# Instal·lem les dependències de Node
COPY package*.json ./
RUN npm ci

# Construïm els assets
RUN npm run build

# --- STAGE 3: Final Image ---
FROM php:8.2-fpm-alpine

# Paquets + extensions PHP necessàries per Laravel + SQLite
RUN set -eux; \
    # Canviar a un mirall alternatiu si cal
    sed -i 's|https://dl-cdn.alpinelinux.org|https://mirror.clarkson.edu|' /etc/apk/repositories; \
    # Actualitzar l'índex de repositoris amb reintents
    apk update --no-cache || (sleep 5 && apk update --no-cache); \
    # Instal·lar dependències de construcció i extensions de PHP
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS icu-dev sqlite-dev oniguruma-dev libzip-dev; \
    apk add --no-cache icu sqlite-libs git unzip; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" pdo_sqlite bcmath intl mbstring; \
    docker-php-ext-enable opcache; \
    # Eliminar les dependències de construcció per reduir la mida de la imatge
    apk del .build-deps

# Definim el directori de treball
WORKDIR /var/www/html

# Copiem el codi de l'aplicació (amb assets i dependències)
COPY --from=composer_builder /app /var/www/html
COPY --from=node_builder /app/public/build /var/www/html/public/build

# Ajustem permisos i generem la clau de l'aplicació
RUN if [ ! -f .env ]; then cp .env.example .env; fi \
    && php artisan key:generate \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && php artisan migrate --force;

# Ajustem permisos per a Laravel (storage, bootstrap/cache)
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Usuari no root per seguretat (www-data és l'usuari per defecte de php-fpm)
USER www-data

# Exposar el port de PHP-FPM
EXPOSE 9000