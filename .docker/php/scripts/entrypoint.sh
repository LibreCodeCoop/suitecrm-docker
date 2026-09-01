#!/bin/bash
set -Eeuo pipefail

echo "[ENTRYPOINT] Starting SuiteCRM container..."

SUITECRM_VERSION="$(tr -d '[:space:]' < /etc/suitecrm-version)"

# Install the SuiteCRM package baked into the image, if needed
if [ ! -f "LICENSE.txt" ]; then
    echo "[ENTRYPOINT] Installing SuiteCRM ${SUITECRM_VERSION} from the image..."
    cp -a /opt/suitecrm/. .
    find . -type d -not -perm 2755 -exec chmod 2755 {} \;
    find . -type f -not -perm 0644 -exec chmod 0644 {} \;
    chmod +x bin/console
    chown -R www-data:www-data .
    echo "[ENTRYPOINT] SuiteCRM ${SUITECRM_VERSION} installation complete"
else
    echo "[ENTRYPOINT] Existing SuiteCRM files detected; application upgrade is not automatic"
fi

EMAILS_HEADER_JS="/var/www/html/public/legacy/modules/Emails/include/ListView/ListViewHeader.js"
if [ -f "$EMAILS_HEADER_JS" ] && grep -q "jQueryBtnEmailsCurrentFolder.remove()" "$EMAILS_HEADER_JS"; then
    echo "[ENTRYPOINT] Patching Emails folder button handling"
    sed -i '/jQueryBtnEmailsCurrentFolder.remove()/d' "$EMAILS_HEADER_JS"
fi

exec "$@"
