FROM php:7.3.11-fpm

RUN apt-get update

RUN apt-get install -y \
        cron \
        git \
        libc-client-dev \
        libcurl3-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libpq-dev \
        libpng-dev \
        libssl-dev \
        libxml2-dev \
        libzip-dev \
        tzdata \

    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
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

RUN pecl install xdebug-2.8.0 \
    && docker-php-ext-enable xdebug

RUN curl https://getcomposer.org/composer.phar --output /usr/bin/composer
RUN chmod +x /usr/bin/composer

RUN cp /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN echo "America/Sao_Paulo" >  /etc/timezone

COPY config/php.ini /usr/local/etc/php/conf.d/

COPY config/crontab /etc/cron.d/app-cron
RUN chmod 0644 /etc/cron.d/app-cron
RUN crontab /etc/cron.d/app-cron

WORKDIR /app
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]