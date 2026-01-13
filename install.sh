#!/bin/bash
set -e

echo "==================================="
echo "SuiteCRM 8.4.0 Docker Installation"
echo "==================================="
echo ""

# Start containers
echo "Starting Docker containers..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check if SuiteCRM is downloaded
echo "Checking SuiteCRM installation..."
docker compose exec php bash -c "[ -f LICENSE.txt ] && echo 'SuiteCRM files found' || echo 'Waiting for download...'"

# Wait for download to complete if needed
sleep 5

# Check if bugs were fixed
echo ""
echo "Checking bug fixes..."
docker compose exec php bash -c '
if [ -f "public/legacy/modules/AOW_WorkFlow/aow_utils.php" ]; then
    count=$(grep -c "static \$sfh" public/legacy/modules/AOW_WorkFlow/aow_utils.php)
    if [ $count -eq 1 ]; then
        echo "✓ Bug #1 fixed: AOW_WorkFlow has only one static \$sfh declaration"
    else
        echo "✗ Bug #1 NOT fixed: AOW_WorkFlow has $count static variable declarations"
    fi
fi

if [ -f "public/legacy/include/InlineEditing/InlineEditing.php" ]; then
    count=$(grep -c "static \$sfh" public/legacy/include/InlineEditing/InlineEditing.php)
    if [ $count -eq 1 ]; then
        echo "✓ Bug #2 fixed: InlineEditing has only one static \$sfh declaration"
    else
        echo "✗ Bug #2 NOT fixed: InlineEditing has $count static variable declarations"
    fi
fi

if [ -f "public/legacy/.htaccess" ]; then
    if grep -q "RewriteBase /legacy/" public/legacy/.htaccess; then
        echo "✓ Bug #3 fixed: RewriteBase is correct"
    else
        echo "✗ Bug #3 NOT fixed: RewriteBase is still incorrect"
    fi
fi'

echo ""
echo "==================================="
echo "Next Steps:"
echo "==================================="
echo ""
echo "Complete the installation by running:"
echo ""
echo "  docker compose exec php bin/console suitecrm:app:install \\"
echo "    -U root \\"
echo "    -P root \\"
echo "    -H mysql \\"
echo "    -Z 3306 \\"
echo "    -N root \\"
echo "    -u admin \\"
echo "    -p admin \\"
echo "    -S localhost \\"
echo "    -d no \\"
echo "    -W true"
echo ""
echo "Then access SuiteCRM at http://localhost"
echo "  Username: admin"
echo "  Password: admin"
echo ""
