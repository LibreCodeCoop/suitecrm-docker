#!/bin/bash

# Clone SuiteCRM repository, if needed
if [ ! -f "LICENSE.txt" ]; then
    curl -L https://suitecrm.com/download/142/suite84/562972/suitecrm-8-4-0.zip|busybox unzip -
    find . -type d -not -perm 2755 -exec chmod 2755 {} \;
    find . -type f -not -perm 0644 -exec chmod 0644 {} \;
    chmod +x bin/console
    chown -R www-data:www-data .
fi

# Fix SuiteCRM 8.4.0 bugs for PHP 8.3
# Bug #1: Remove duplicate static variable in AOW_WorkFlow (line 644)
if [ -f "public/legacy/modules/AOW_WorkFlow/aow_utils.php" ]; then
    count=$(grep -c "static \$sfh" public/legacy/modules/AOW_WorkFlow/aow_utils.php || echo "0")
    if [ "$count" -eq 2 ]; then
        sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php
        echo "Fixed: Removed duplicate static variable in AOW_WorkFlow/aow_utils.php"
    fi
fi

# Bug #2: Remove duplicate static variable in InlineEditing (line 294)
if [ -f "public/legacy/include/InlineEditing/InlineEditing.php" ]; then
    count=$(grep -c "static \$sfh" public/legacy/include/InlineEditing/InlineEditing.php || echo "0")
    if [ "$count" -eq 2 ]; then
        sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php
        echo "Fixed: Removed duplicate static variable in InlineEditing/InlineEditing.php"
    fi
fi

# Bug #3: Fix incorrect RewriteBase in .htaccess
if [ -f "public/legacy/.htaccess" ]; then
    if grep -q "RewriteBase localhostlegacy/" public/legacy/.htaccess; then
        sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess
        echo "Fixed: Corrected RewriteBase in public/legacy/.htaccess"
    fi
fi

apache2-foreground
