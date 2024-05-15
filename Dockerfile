FROM php:8.1-apache-bookworm

WORKDIR /var/www/html

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        cron \
        icu-devtools \
        jq \
        libfreetype6-dev libicu-dev libjpeg62-turbo-dev libpng-dev libpq-dev \
        libsasl2-dev libssl-dev libwebp-dev libxpm-dev libzip-dev libzstd-dev \
        unzip \
        zlib1g-dev \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql zip pcntl \
    && pecl install redis \
    && docker-php-ext-enable opcache redis \
    && apt-get clean \
    && apt-get autoclean \
    && apt-mark auto '.*' > /dev/null; \
        find /usr/local -type f -executable -exec ldd '{}' ';' \
            | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
            | sort -u \
            | xargs -r dpkg-query --search \
            | cut -d: -f1 \
            | sort -u \
            | xargs -r apt-mark manual \
        ; \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN a2enmod rewrite remoteip \
    && sed -ri \
        -e "s/AccessFileName .htaccess/#AccessFileName .htaccess/" \
        -e "s/AllowOverride All/AllowOverride None/g"  \
        -e "s/ServerTokens OS/ServerTokens Prod/g" \
        -e "s/ServerSignature On/ServerSignature Off/g" \
        /etc/apache2/conf-available/*.conf

RUN curl -o /usr/local/bin/composer https://getcomposer.org/download/latest-stable/composer.phar \
    && chmod +x /usr/local/bin/composer

COPY docker/php.ini /usr/local/etc/php/conf.d/zzz.ini
COPY docker/apache.conf /etc/apache2/sites-enabled/000-default.conf
COPY --chown=www-data:www-data . .

RUN composer install -n --ignore-platform-reqs --no-dev --no-progress \
    && mv .env.example .env