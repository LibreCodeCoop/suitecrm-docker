#!/bin/sh
if [ ! -f "SuiteCRM/LICENSE.txt" ]; then
    export COMPOSER_ALLOW_SUPERUSER=1
    composer global require hirak/prestissimo

    git clone --progress -b "${SUITECRM_VERSION}" --single-branch --depth 1 https://github.com/salesagility/SuiteCRM /tmp/suitecrm
    rsync -r /tmp/suitecrm/ SuiteCRM
    rm -rf /tmp/suitecrm
    cd SuiteCRM
    composer install
    chown -R www-data:www-data .
    chmod -R 755 .
    chmod -R 775 custom modules themes data upload
    # cache
    chmod 775 config_override.php 2>/dev/null
fi
php-fpm
