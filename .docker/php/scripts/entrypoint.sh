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

SUGAR_FOLDERS_PHP="/var/www/html/public/legacy/include/SugarFolders/SugarFolders.php"
if [ -f "$SUGAR_FOLDERS_PHP" ] && grep -q 'assigned_user_id = " . $this->db->quoted($this->currentUser->id)' "$SUGAR_FOLDERS_PHP"; then
    echo "[ENTRYPOINT] Patching Emails folder scoping"
    sed -i '/" AND assigned_user_id = " \. \$this->db->quoted(\$this->currentUser->id) \. " AND emails.deleted = 0"/c\            " AND emails.mailbox_id = " . $this->db->quoted($this->id) . " AND emails.deleted = 0";' "$SUGAR_FOLDERS_PHP"
fi

if [ -f "bin/console" ]; then
    if php bin/console doctrine:query:sql "DROP TRIGGER IF EXISTS emails_set_sent_folder_before_insert" >/dev/null 2>&1; then
        echo "[ENTRYPOINT] Dropped stale Sent-folder trigger"
    fi

    php bin/console doctrine:query:sql "UPDATE emails e JOIN folders f ON e.mailbox_id = f.id SET e.mailbox_id = f.parent_folder WHERE e.deleted = 0 AND e.type = 'out' AND f.folder_type = 'sent' AND f.parent_folder IS NOT NULL" >/dev/null 2>&1 || true
fi

exec "$@"
