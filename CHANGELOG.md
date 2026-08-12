# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Version source of truth in `SUITECRM_VERSION`.
- Safe upgrade script with mandatory backup confirmation and post-upgrade checks.
- Optional Messenger worker and scheduler services under the `background` profile.
- Generic deployment and upgrade documentation without infrastructure credentials.
- Compose and shell syntax validation in CI.

### Changed
- SuiteCRM target version updated to 8.10.2.
- Published image now uses the stable `suite-crm:latest` name; the application
  version remains available as an OCI label.
- MySQL development image updated to 8.4 and its port is no longer exposed.
- Installation is interactive and no longer embeds example credentials.
- Entrypoint only initializes empty volumes; persisted installations must use the
  documented application upgrade flow.

### Removed
- Runtime patches that were specific to SuiteCRM 8.4.0.
- Documentation containing deployment-specific infrastructure details.

## [1.0.0] - Initial Release

### Features
- Docker Compose setup for SuiteCRM 8.4.0
- PHP 8.3 with Apache
- MySQL database
- Xdebug support
- Automatic SuiteCRM download and setup
- GitHub Actions CI/CD pipeline
