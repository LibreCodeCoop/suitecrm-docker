#!/bin/bash
. `pwd`/.env
if [ ! -d "SuiteCRM" ]; then
    export COMPOSER_ALLOW_SUPERUSER=1
    composer global require hirak/prestissimo

    git clone https://github.com/salesagility/SuiteCRM
    cd SuiteCRM
    composer install
    chown -R www-data:www-data .
    chmod -R 755 .
    chmod -R 775 custom modules themes data upload
    # cache
    # chmod 775 config_override.php 2>/dev/null
fi
cron
php-fpm