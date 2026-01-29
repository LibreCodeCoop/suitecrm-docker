# SuiteCRM Docker Development Environment

Docker-based development environment for SuiteCRM 8.x with PHP 8.3, Apache, and MySQL.

## Quick Start

### Option 1: Automated Installation (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/LibreCodeCoop/suitecrm-docker
cd suitecrm-docker
```

2. Run the installation script:
```bash
./install.sh
```

The script will start the containers, verify bug fixes, and guide you through the installation.

### Option 2: Manual Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd suitecrm-docker
```

2. Start the containers:
```bash
docker compose up -d
```

   **Note**: The entrypoint script automatically fixes known SuiteCRM 8.4.0 bugs on startup.

3. Complete the installation:
```bash
docker compose exec php bin/console suitecrm:app:install \
  -U root \
  -P root \
  -H mysql \
  -Z 3306 \
  -N root \
  -u admin \
  -p admin \
  -S localhost \
  -d no \
  -W true
```

4. Access SuiteCRM at http://localhost
   - **Username**: admin
   - **Password**: admin

## Known Issues

### SuiteCRM 8.4.0 Bugs

SuiteCRM 8.4.0 contains multiple bugs when running on PHP 8.3:

**Bug #1: Duplicate Static Variable in AOW_WorkFlow**
- **File**: `public/legacy/modules/AOW_WorkFlow/aow_utils.php`
- **Issue**: Static variable `$sfh` is declared twice (lines 438 and 644)
- **Error**: `Fatal Compile Error: Duplicate declaration of static variable $sfh`
- **Symptoms**: Database failure error on initial load
- **Fix**: Remove line 644

**Bug #2: Duplicate Static Variable in InlineEditing**
- **File**: `public/legacy/include/InlineEditing/InlineEditing.php`
- **Issue**: Static variable `$sfh` is declared twice (lines 146 and 294)
- **Error**: `Fatal Compile Error: Duplicate declaration of static variable $sfh`
- **Symptoms**: "Error while fetching data" when trying to login or access GraphQL API
- **Fix**: Remove line 294

**Bug #3: Incorrect RewriteBase in .htaccess**
- **File**: `public/legacy/.htaccess`
- **Issue**: RewriteBase is set to `localhostlegacy/` instead of `/legacy/`
- **Error**: `RewriteBase: argument is not a valid URL`
- **Symptoms**: 500 Internal Server Error when accessing legacy pages
- **Fix**: Correct the RewriteBase path

All three fixes are **automatically applied** by the entrypoint script when the container starts. The fixes are idempotent - they only run if the bugs are detected and won't break already-fixed installations.

### Manual Bug Fixes (For Existing Installations)

If you have an existing SuiteCRM installation that wasn't started with the updated entrypoint, you can manually apply the fixes:

```bash
# Fix bug #1: Duplicate static variable in AOW_WorkFlow
docker compose exec php sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php

# Fix bug #2: Duplicate static variable in InlineEditing
docker compose exec php sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php

# Fix bug #3: Incorrect RewriteBase in .htaccess
docker compose exec php sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess

# Clear cache and restart
docker compose exec php bash -c "rm -rf cache/prod/* public/legacy/cache/*"
docker compose restart php
```

### Installation Lock

If the installation fails or is interrupted, you may need to unlock the installer:
```bash
docker compose exec php sed -i "s/'installer_locked' => true/'installer_locked' => false/" public/legacy/config.php
```

Then retry the installation command from step 4.

## Manual Installation via Console

To manually install or reinstall SuiteCRM:

```bash
docker compose exec php bin/console suitecrm:app:install [options]
```

### Installation Options

- `-U, --db_username`: Database username (default: root)
- `-P, --db_password`: Database password (default: root)
- `-H, --db_host`: Database host (default: mysql)
- `-Z, --db_port`: Database port (default: 3306)
- `-N, --db_name`: Database name (default: root)
- `-u, --site_username`: Admin username
- `-p, --site_password`: Admin password
- `-S, --site_host`: Site host (default: localhost)
- `-d, --demoData`: Install demo data (yes/no)
- `-W, --sys_check_option`: Ignore system check warnings (true/false)

### Example Installation Command

```bash
docker compose exec php bin/console suitecrm:app:install \
  --db_username=root \
  --db_password=root \
  --db_host=mysql \
  --db_port=3306 \
  --db_name=root \
  --site_username=admin \
  --site_password=MySecurePassword123 \
  --site_host=localhost \
  --demoData=no \
  --sys_check_option=true
```

## Architecture

### Services

- **php**: PHP 8.3 with Apache and required SuiteCRM extensions
  - Port: 80
  - Volume: `./volumes/suitecrm` → `/var/www/html`
  - Xdebug pre-configured (disabled by default)

- **mysql**: MySQL database
  - Port: 3306
  - Root password: root
  - Database: root
  - Volume: `./volumes/mysql/data` → `/var/lib/mysql`

### Environment Variables

Create a `.env` file or set in `docker-compose.yml`:

- `VERSION_SUITECRM`: SuiteCRM version to download (default: v8.8.0)
- `XDEBUG_CONFIG`: Xdebug configuration
- `TZ`: Timezone (default: America/Sao_Paulo)

## Common Commands

### Container Management

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f php

# Rebuild PHP container
docker compose build php

# Access PHP container shell
docker compose exec php bash
```

### Database Access

```bash
# MySQL CLI
docker compose exec mysql mysql -uroot -proot root

# External connection
mysql -h localhost -P 3306 -u root -proot root
```

### SuiteCRM Console

```bash
# Run console commands
docker compose exec php bin/console <command>

# Clear cache
docker compose exec php bin/console cache:clear

# List all commands
docker compose exec php bin/console list
```

### Cache Management

```bash
# Clear Symfony cache
docker compose exec php bash -c "rm -rf cache/prod/*"

# Clear legacy SuiteCRM cache
docker compose exec php bash -c "rm -rf public/legacy/cache/*"

# Restart PHP container
docker compose restart php
```

## Debugging

### Enable Xdebug

1. Edit `.docker/php/config/php.ini`:
```ini
xdebug.mode=debug
```

2. Rebuild and restart:
```bash
docker compose build php
docker compose up -d
```

3. Configure your IDE to listen on port 9003

### View Logs

```bash
# Application logs
docker compose exec php cat logs/prod/prod.log

# Installation logs
docker compose exec php cat logs/install.log

# Apache logs
docker compose logs php
```

## Troubleshooting

### Database Failure Error

If you see "Database failure. Please refer to suitecrm.log":

1. Check for the duplicate static variable bug (see Known Issues)
2. Verify database connection:
```bash
docker compose exec php php -r "new PDO('mysql:host=mysql;port=3306;dbname=root', 'root', 'root'); echo 'OK';"
```
3. Clear cache and restart

### Reset Installation

To completely reset and reinstall:

```bash
# Stop containers and remove volumes
docker compose down -v

# Remove SuiteCRM files
sudo rm -rf volumes/

# Start fresh
docker compose up -d

# Apply bug fix and install
# (Follow steps 3-4 from Quick Start)
```

## CI/CD

GitHub Actions automatically builds and publishes the Docker image to `ghcr.io` on:
- Pushes to main/master
- Tag creation (v*)
- Pull requests

## Translations
- https://crowdin.com/project/suitecrmtranslations

## License

SuiteCRM is licensed under AGPLv3. See LICENSE.txt for details.
