#!/bin/bash

# Clone SuiteCRM repository, if needed
if [ ! -f "LICENSE.txt" ]; then
    curl -L https://suitecrm.com/download/142/suite84/562972/suitecrm-8-4-0.zip|busybox unzip -
    find . -type d -not -perm 2755 -exec chmod 2755 {} \;
    find . -type f -not -perm 0644 -exec chmod 0644 {} \;
    chmod +x bin/console
    chown -R www-data:www-data .
fi

apache2-foreground
