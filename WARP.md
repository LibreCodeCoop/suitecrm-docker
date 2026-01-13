# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Docker-based development environment for SuiteCRM 8.x. The project uses Docker Compose to orchestrate a PHP/Apache container and a MySQL database container, automatically downloading and setting up SuiteCRM on first run.

## Architecture

### Container Structure
- **php service**: PHP 8.3 with Apache, configured with SuiteCRM-required extensions (GD, IMAP, LDAP, SOAP, etc.) and Xdebug for debugging
- **mysql service**: Standard MySQL container for database storage
- **Shared network**: Both containers communicate via a custom `mysql` network

### Key Components
- `.docker/php/Dockerfile`: Builds the PHP/Apache container with all required extensions
- `.docker/php/scripts/entrypoint.sh`: Downloads and initializes SuiteCRM on first container start (checks for LICENSE.txt to determine if already installed)
- `.docker/php/config/apache/httpd.conf`: Apache virtual host configuration with DocumentRoot set to `/var/www/html/public`
- `.docker/php/config/php.ini`: PHP settings including upload limits, error reporting, and Xdebug configuration
- `volumes/suitecrm/`: Mounted SuiteCRM installation (created on first run)
- `volumes/mysql/`: Database persistence and initialization scripts

### SuiteCRM Installation Flow
The entrypoint script automatically:
1. Downloads SuiteCRM 8.4.0 (or version specified in VERSION_SUITECRM env var) on first run
2. Sets proper permissions (2755 for directories, 0644 for files)
3. Configures www-data ownership
4. Applies bug fixes for SuiteCRM 8.4.0 PHP 8.3 compatibility:
   - Removes duplicate static variable declarations
   - Fixes incorrect RewriteBase in .htaccess

## Common Commands

### Starting and Stopping
```bash
# Start all services (builds on first run)
docker compose up -d

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes database)
docker compose down -v

# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f php
docker compose logs -f mysql
```

### Rebuilding
```bash
# Rebuild PHP container after Dockerfile changes
docker compose build php

# Rebuild and restart
docker compose up -d --build
```

### Accessing Containers
```bash
# Execute commands in PHP container
docker compose exec php bash

# Execute commands in MySQL container
docker compose exec mysql bash

# Run MySQL client
docker compose exec mysql mysql -uroot -proot root
```

### SuiteCRM Console
```bash
# Access SuiteCRM console (inside PHP container)
docker compose exec php bin/console <command>
```

### Debugging
- Xdebug is pre-installed and configured
- Default configuration: `client_host=172.17.0.1 client_port=9003 start_with_request=yes`
- Xdebug mode is set to `off` by default in php.ini; change `xdebug.mode` to `debug` to enable
- IDE should listen on port 9003

## Environment Variables

Set in `.env` file or docker-compose.yml:
- `VERSION_SUITECRM`: SuiteCRM version to download (default: v8.8.0)
- `XDEBUG_CONFIG`: Xdebug configuration string
- `TZ`: Timezone (default: America/Sao_Paulo)

## Database Access

- **Host**: localhost
- **Port**: 3306
- **Root Password**: root
- **Database Name**: root
- **User**: root

For external connections, use `localhost:3306`. From PHP container, use `mysql:3306`.

## File Structure

- `.docker/php/`: PHP container build context
- `volumes/suitecrm/`: SuiteCRM application files (git-ignored)
- `volumes/mysql/data/`: MySQL data directory (git-ignored)
- `volumes/mysql/dump/`: SQL initialization scripts executed on first MySQL start

## CI/CD

GitHub Actions workflow (`.github/workflows/publish-suitecrm.yml`) automatically builds and publishes the PHP Docker image to GitHub Container Registry (ghcr.io) on:
- Pushes to main/master branch
- Tag creation (v* pattern)
- Pull requests
- Manual workflow dispatch

## URL Access

After starting services:
- **SuiteCRM**: http://localhost
- **MySQL**: localhost:3306
