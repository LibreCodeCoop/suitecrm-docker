FROM php:7.4-fpm-alpine

RUN apk add --update --no-cache \
        curl \
        curl-dev \
        dcron \
        git \
        icu-dev \
        imap-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        krb5-dev \
        libpq \
        libpng-dev \
        libressl-dev \
        libxml2-dev \
        libzip-dev \
        oniguruma-dev \
        rsync \
        tzdata \

    && docker-php-ext-configure gd \
        --with-freetype=/usr/include/ \
        --with-jpeg=/usr/include/ \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure mysqli -with-mysqli=mysqlnd \
    && docker-php-ext-configure pdo_mysql -with-pdo-mysql=mysqlnd \

    && docker-php-ext-install -j$(nproc) \
        curl \
        gd \
        imap \
        intl \  
        json \
        mbstring \
        mysqli \
        pdo \
        pdo_mysql \
        xmlrpc \
        zip

COPY --from=composer:1 /usr/bin/composer /usr/bin/composer

COPY config/php.ini /usr/local/etc/php/conf.d/

COPY config/crontab /etc/cron.d/app-cron
RUN chmod 0644 /etc/cron.d/app-cron
RUN crond -c /etc/cron.d

WORKDIR /app
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
