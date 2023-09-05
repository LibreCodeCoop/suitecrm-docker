FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y \
        unzip \
        busybox-static
    #     # cron
    #     busybox-static \
    # && mkdir -p /var/spool/cron/crontabs \
    # && echo '* * * * * cd /var/www/html; php -f cron.php > /dev/null 2>&1' > /var/spool/cron/crontabs/www-data

# Install PHP extensions
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync \
    && install-php-extensions \
    apcu \
    gd \
    imap \
    intl \
    ldap \
    mysqli \
    pdo_mysql \
    soap \
    xdebug \
    zip

COPY config/php.ini /usr/local/etc/php/conf.d/

# COPY config/crontab /etc/cron.d/app-cron
# RUN chmod 0644 /etc/cron.d/app-cron
# RUN crond -c /etc/cron.d

RUN a2enmod rewrite
COPY config/apache/httpd.conf /etc/apache2/sites-enabled/000-default.conf

COPY config/php.ini /usr/local/etc/php/conf.d/
COPY scripts/entrypoint.sh /var/www/scripts/

WORKDIR /var/www/html

ENTRYPOINT ["bash", "/var/www/scripts/entrypoint.sh"]
