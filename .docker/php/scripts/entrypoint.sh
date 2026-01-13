#!/bin/bash
set -e

echo "[ENTRYPOINT] Starting SuiteCRM container..."

# Clone SuiteCRM repository, if needed
if [ ! -f "LICENSE.txt" ]; then
    echo "[ENTRYPOINT] Downloading SuiteCRM..."
    curl -L https://suitecrm.com/download/142/suite84/562972/suitecrm-8-4-0.zip|busybox unzip -
    find . -type d -not -perm 2755 -exec chmod 2755 {} \;
    find . -type f -not -perm 0644 -exec chmod 0644 {} \;
    chmod +x bin/console
    chown -R www-data:www-data .
    echo "[ENTRYPOINT] SuiteCRM download complete"
else
    echo "[ENTRYPOINT] SuiteCRM files already exist"
fi

# Wait for files to be fully available
if [ -f "LICENSE.txt" ]; then
    echo "[ENTRYPOINT] Checking for SuiteCRM 8.4.0 bugs..."
    
    # Bug #1: Remove duplicate static variable in AOW_WorkFlow (line 644)
    if [ -f "public/legacy/modules/AOW_WorkFlow/aow_utils.php" ]; then
        count=$(grep -c "static \$sfh" public/legacy/modules/AOW_WorkFlow/aow_utils.php 2>/dev/null || echo "0")
        echo "[ENTRYPOINT] Bug #1 check: Found $count static \$sfh declarations in AOW_WorkFlow"
        if [ "$count" -ge 2 ]; then
            sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php
            echo "[ENTRYPOINT] ✓ Fixed: Removed duplicate static variable in AOW_WorkFlow/aow_utils.php"
        else
            echo "[ENTRYPOINT] ✓ Bug #1: Already fixed or not present"
        fi
    fi
    
    # Bug #2: Remove duplicate static variable in InlineEditing (line 294)
    if [ -f "public/legacy/include/InlineEditing/InlineEditing.php" ]; then
        count=$(grep -c "static \$sfh" public/legacy/include/InlineEditing/InlineEditing.php 2>/dev/null || echo "0")
        echo "[ENTRYPOINT] Bug #2 check: Found $count static \$sfh declarations in InlineEditing"
        if [ "$count" -ge 2 ]; then
            sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php
            echo "[ENTRYPOINT] ✓ Fixed: Removed duplicate static variable in InlineEditing/InlineEditing.php"
        else
            echo "[ENTRYPOINT] ✓ Bug #2: Already fixed or not present"
        fi
    fi
    
    # Bug #3: Fix incorrect RewriteBase in .htaccess
    if [ -f "public/legacy/.htaccess" ]; then
        if grep -q "RewriteBase localhostlegacy/" public/legacy/.htaccess 2>/dev/null; then
            sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess
            echo "[ENTRYPOINT] ✓ Fixed: Corrected RewriteBase in public/legacy/.htaccess"
        else
            echo "[ENTRYPOINT] ✓ Bug #3: Already fixed or not present"
        fi
    fi
    
    echo "[ENTRYPOINT] Bug fixes complete"
fi

apache2-foreground
