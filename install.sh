#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
    echo "Missing .env. Copy .env.example to .env and configure the required passwords." >&2
    exit 1
fi

for variable in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD; do
    value="$(sed -n "s/^${variable}=//p" .env | tail -n 1)"
    if [[ -z "$value" ]]; then
        echo "${variable} must be configured in .env." >&2
        exit 1
    fi
done

echo "Starting the database and SuiteCRM web service..."
docker compose up -d mysql php

echo "Waiting for the SuiteCRM files..."
for _ in {1..60}; do
    if docker compose exec -T php test -x bin/console 2>/dev/null; then
        break
    fi
    sleep 2
done

if ! docker compose exec -T php test -x bin/console; then
    echo "SuiteCRM did not become ready. Check: docker compose logs php" >&2
    exit 1
fi

echo
echo "The SuiteCRM installer will ask for database and administrator credentials."
echo "Values entered here are not stored by this repository."
docker compose exec php php bin/console suitecrm:app:install

docker compose --profile background up -d

echo
echo "Installation complete. Verify the application, scheduler and Messenger worker:"
echo "  docker compose --profile background ps"
echo "  docker compose exec php php bin/console app:version:status"
