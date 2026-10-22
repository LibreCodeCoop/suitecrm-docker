FROM php:8.3.36-apache@sha256:756c2884677bedea30afaa95811b42cd3ff251203291c5820c1ad209e86c9fb4



RUN apt-get update \
    && apt-get install -y \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

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

COPY .docker/php/config/php.ini /usr/local/etc/php/conf.d/

RUN a2enmod rewrite
COPY .docker/php/config/apache/httpd.conf /etc/apache2/sites-enabled/000-default.conf

COPY .docker/php/scripts/entrypoint.sh /var/www/scripts/
COPY SUITECRM_VERSION /etc/suitecrm-version

RUN suitecrm_version="$(tr -d '[:space:]' < /etc/suitecrm-version)" \
    && suitecrm_version_number="${suitecrm_version#v}" \
    && mkdir -p /opt/suitecrm \
    && curl --fail --location \
        "https://github.com/SuiteCRM/SuiteCRM-Core/releases/download/v${suitecrm_version_number}/SuiteCRM-${suitecrm_version_number}.zip" \
        --output /tmp/suitecrm.zip \
    && unzip -tq /tmp/suitecrm.zip \
    && unzip -q /tmp/suitecrm.zip -d /opt/suitecrm \
    && rm /tmp/suitecrm.zip

WORKDIR /var/www/html

ENTRYPOINT ["bash", "/var/www/scripts/entrypoint.sh"]
CMD ["apache2-foreground"]
