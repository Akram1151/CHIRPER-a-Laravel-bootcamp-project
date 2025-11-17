# --- STAGE 1: Build de Node (Assets) ---
FROM node:20-alpine AS node_builder
WORKDIR /app

# Copiem package.json i package-lock.json (o yarn.lock)
COPY package*.json package-lock.json ./
# Instal·lem les dependències de Node
RUN npm ci

# Copiem la resta del codi
COPY . .

# Construïm els assets
RUN npm run build

# --- STAGE 2: PHP Dependencies (Composer) ---
FROM composer:2 AS composer_builder
WORKDIR /app
# Copiem el codi de l'aplicació i els assets construïts
COPY --from=node_builder /app /app

# Instal·lem les dependències de PHP (sense --dev per producció)
# Utilitzem ' --ignore-platform-reqs' si no tenim instal·lades totes les extensions encara
# Però idealment, s'han d'especificar totes les extensions a la imatge base
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction

# --- STAGE 3: Final Image ---
FROM php:8.2-fpm-alpine

# Paquets + extensions PHP necessàries per Laravel + SQLite
RUN set -eux; \
    # 1. ACTUALITZAR L'ÍNDEX DE REPOSITORIS (clau per trobar els paquets)
    apk update; \
    # 2. Instal·lar dependències de construcció i extensions de PHP
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS icu-dev sqlite-dev oniguruma-dev libzip-dev; \
    apk add --no-cache icu sqlite-libs git unzip; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" pdo_sqlite bcmath intl mbstring; \
    docker-php-ext-enable opcache; \
    # 3. Eliminar les dependències de construcció per reduir la imatge
    apk del .build-deps

# Definim el directori de treball
WORKDIR /var/www/html

# Copiem el codi de l'aplicació (amb assets i dependències) des del stage de Composer
# Excloem fitxers que no són necessaris (e.g., .git, dockerfiles, etc.) si no useu .dockerignore
COPY --from=composer_builder /app /var/www/html

# Ajustem permisos i generem la clau de l'aplicació
# Mantenim l'usuari ROOT temporalment per als permisos i la generació
RUN if [ ! -f .env ]; then cp .env.example .env; fi \
    && php artisan key:generate \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && php artisan migrate --force;

# Ajustem permisos per a Laravel (storage, bootstrap/cache)
# Això suposa que l'usuari 'laravel' té UID 1000
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Usuari no root per seguretat (www-data és l'usuari per defecte de php-fpm)
USER www-data

# Exposar el port de PHP-FPM
EXPOSE 9000