# syntax = docker/dockerfile:1

ARG UID=1000
ARG GID=1000
ARG PHP_VERSION=8.2

FROM php:${PHP_VERSION}-fpm as base

ENV UID=${UID}
ENV GID=${GID}

# Use the default production configuration
COPY resources/docker/app.ini "${PHP_INI_DIR}/conf.d/app.ini"
COPY resources/docker/opcache.ini "${PHP_INI_DIR}/conf.d/opcache.ini"
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

WORKDIR /laravel

RUN apt-get update && \
    apt-get install -y \
        libzip-dev \
        zip \
        unzip \
        libonig-dev \
        libxml2-dev \
        libpq-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        gosu \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && docker-php-ext-install -j$(nproc) gd \
        && docker-php-ext-install pdo_mysql \
        && docker-php-ext-install mysqli \
        && docker-php-ext-install opcache \
        && docker-php-ext-install zip \
        && docker-php-ext-install bcmath \
        && docker-php-ext-install mbstring \
        && docker-php-ext-install exif \
        && docker-php-ext-install pcntl \
        && docker-php-ext-install xml \
        && pecl install redis \
    	&& docker-php-ext-enable redis \
        && rm -rf /var/lib/apt/lists/*

# Install nginx
RUN apt-get update && \
    apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/* && \
    rm /etc/nginx/sites-enabled/default && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Copy nginx configuration
COPY resources/docker/h5bp /etc/nginx/h5bp
COPY resources/docker/nginx-default.conf /etc/nginx/sites-available/nginx.conf
RUN ln -s /etc/nginx/sites-available/nginx.conf /etc/nginx/sites-enabled/

# Install supervisord
RUN apt-get update && \
    apt-get install -y supervisor && \
    rm -rf /var/lib/apt/lists/*

# Copy supervisord configuration
COPY resources/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Cron
RUN apt-get update && \
    apt-get install -y cron && \
    rm -rf /var/lib/apt/lists/* && \
    service cron stop

# Throw-away build stage to reduce size of final image
FROM base as build

COPY --from=composer /usr/bin/composer /usr/bin/composer

# Compile assets...
COPY composer.json /laravel/
COPY composer.lock /laravel/
RUN mkdir -p /larave/app && mkdir -p /laravel/database && composer install --no-scripts --no-dev --no-interaction --prefer-dist

# Final stage for app image
FROM base

# Entrypoint
COPY resources/docker/start-container.sh /usr/bin/start-container
RUN chmod +x /usr/bin/start-container

# Copy built artifacts: gems, application
COPY --from=build /usr/bin/composer /usr/bin/composer
COPY --from=build /laravel/vendor /laravel/vendor

# Create the Laravel user...
RUN useradd -ms /bin/bash laravel

# Copy application code
COPY . .
RUN composer install --no-dev --no-interaction --prefer-dist

# Set permissions
RUN chown -R www-data:www-data /laravel \
    && chmod ug+rw -R storage bootstrap

EXPOSE 80

ENTRYPOINT ["/usr/bin/start-container"]
