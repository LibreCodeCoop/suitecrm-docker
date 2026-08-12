#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

service="${SUITECRM_SERVICE:-php}"
volume_path="${SUITECRM_VOLUME_PATH:-volumes/suitecrm}"
backup_confirmed=false

usage() {
    cat <<'EOF'
Usage: scripts/upgrade-suitecrm.sh --backup-confirmed

The target version is read from SUITECRM_VERSION. Before running this command,
create and verify backups of both the SuiteCRM files and its database.

Optional environment variables:
  BACKUP_COMMAND         Command to create and verify backups before upgrading.
  SUITECRM_SERVICE       Compose web service name (default: php).
  SUITECRM_VOLUME_PATH   Host path mounted at /var/www/html.
EOF
}

while (($#)); do
    case "$1" in
        --backup-confirmed) backup_confirmed=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

target_tag="$(tr -d '[:space:]' < SUITECRM_VERSION)"
if [[ ! "$target_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version in SUITECRM_VERSION: ${target_tag}" >&2
    exit 1
fi
target_version="${target_tag#v}"

if [[ -n "${BACKUP_COMMAND:-}" ]]; then
    echo "Running the configured backup command..."
    bash -Eeuo pipefail -c "$BACKUP_COMMAND"
    backup_confirmed=true
fi

if [[ "$backup_confirmed" != true ]]; then
    echo "Upgrade refused: verified file and database backups are required." >&2
    echo "Use BACKUP_COMMAND or pass --backup-confirmed after checking existing backups." >&2
    exit 1
fi

docker compose ps --status running "$service" >/dev/null
docker compose exec -T "$service" test -x bin/console

if ! docker compose exec -T "$service" sh -c \
    'grep -Eq "^APP_ENV=prod$" .env .env.local 2>/dev/null'; then
    echo "Upgrade refused: APP_ENV=prod was not found in .env or .env.local." >&2
    exit 1
fi

echo "Current application version:"
docker compose exec -T "$service" php bin/console app:version:status || true
echo "Target application version: ${target_version}"

package_dir="${volume_path}/tmp/package/upgrade"
package_file="${package_dir}/${target_version}.zip"
mkdir -p "$package_dir"

echo "Downloading the pre-built SuiteCRM ${target_version} release package..."
curl --fail --location --retry 3 \
    "https://github.com/SuiteCRM/SuiteCRM-Core/releases/download/${target_tag}/SuiteCRM-${target_version}.zip" \
    --output "${package_file}.part"
unzip -tq "${package_file}.part"
mv "${package_file}.part" "$package_file"

docker compose exec -T --user root "$service" \
    chown -R www-data:www-data /var/www/html

echo "Running the application upgrade..."
docker compose exec -T "$service" php bin/console suitecrm:app:upgrade \
    --no-interaction -t "$target_version"

echo "Finalizing the application upgrade..."
docker compose exec -T "$service" php bin/console suitecrm:app:upgrade-finalize \
    --no-interaction -m merge -t "$target_version"

docker compose exec -T --user root "$service" \
    chown -R www-data:www-data /var/www/html
docker compose exec -T --user root "$service" \
    rm -f "/var/www/html/tmp/package/upgrade/${target_version}.zip"

docker compose restart "$service"

echo "Checking Doctrine migrations..."
docker compose exec -T "$service" php bin/console doctrine:migrations:status --no-interaction

echo "Installed application version:"
docker compose exec -T "$service" php bin/console app:version:status

cat <<'EOF'

Upgrade finished. Complete the operational checks:
  - authenticate in the web interface;
  - inspect application and container logs;
  - open Admin > Migrations and review pending manual migration tasks;
  - ensure the Messenger worker is running before starting those tasks.
EOF
