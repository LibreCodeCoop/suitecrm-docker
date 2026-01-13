#!/bin/bash
set -e

echo "=========================================="
echo "SuiteCRM 8.4.0 Bug Fix Script"
echo "=========================================="
echo ""

# Check if running inside container or outside
if [ -f "/var/www/html/LICENSE.txt" ]; then
    # Inside container
    WORKDIR="/var/www/html"
else
    # Outside container - use docker exec
    WORKDIR="."
    PREFIX="docker compose exec php"
fi

fix_bug_1() {
    echo "Checking Bug #1: Duplicate static variable in AOW_WorkFlow..."
    if [ -z "$PREFIX" ]; then
        count=$(grep -c "static \$sfh" public/legacy/modules/AOW_WorkFlow/aow_utils.php 2>/dev/null || echo "0")
    else
        count=$($PREFIX grep -c "static \\\$sfh" public/legacy/modules/AOW_WorkFlow/aow_utils.php 2>/dev/null || echo "0")
    fi
    
    echo "  Found $count static \$sfh declarations"
    
    if [ "$count" -ge 2 ]; then
        if [ -z "$PREFIX" ]; then
            sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php
        else
            $PREFIX sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php
        fi
        echo "  ✓ Fixed: Removed duplicate declaration"
    else
        echo "  ✓ Already fixed or not present"
    fi
}

fix_bug_2() {
    echo ""
    echo "Checking Bug #2: Duplicate static variable in InlineEditing..."
    if [ -z "$PREFIX" ]; then
        count=$(grep -c "static \$sfh" public/legacy/include/InlineEditing/InlineEditing.php 2>/dev/null || echo "0")
    else
        count=$($PREFIX grep -c "static \\\$sfh" public/legacy/include/InlineEditing/InlineEditing.php 2>/dev/null || echo "0")
    fi
    
    echo "  Found $count static \$sfh declarations"
    
    if [ "$count" -ge 2 ]; then
        if [ -z "$PREFIX" ]; then
            sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php
        else
            $PREFIX sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php
        fi
        echo "  ✓ Fixed: Removed duplicate declaration"
    else
        echo "  ✓ Already fixed or not present"
    fi
}

fix_bug_3() {
    echo ""
    echo "Checking Bug #3: Incorrect RewriteBase in .htaccess..."
    if [ -z "$PREFIX" ]; then
        if grep -q "RewriteBase localhostlegacy/" public/legacy/.htaccess 2>/dev/null; then
            sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess
            echo "  ✓ Fixed: Corrected RewriteBase path"
        else
            echo "  ✓ Already fixed or not present"
        fi
    else
        if $PREFIX grep -q "RewriteBase localhostlegacy/" public/legacy/.htaccess 2>/dev/null; then
            $PREFIX sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess
            echo "  ✓ Fixed: Corrected RewriteBase path"
        else
            echo "  ✓ Already fixed or not present"
        fi
    fi
}

# Apply all fixes
fix_bug_1
fix_bug_2
fix_bug_3

echo ""
echo "=========================================="
echo "Bug fixes complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Clear cache: docker compose exec php bash -c \"rm -rf cache/prod/* public/legacy/cache/*\""
echo "2. Restart PHP: docker compose restart php"
echo "3. Run installation if not done yet"
echo ""
