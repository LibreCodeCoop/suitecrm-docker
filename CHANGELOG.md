# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Automatic bug fixes in entrypoint script for SuiteCRM 8.4.0 PHP 8.3 compatibility
- `install.sh` script for automated installation with bug fix verification
- Comprehensive documentation in README.md
- WARP.md file for AI-assisted development
- Manual bug fix instructions for existing installations

### Fixed
- **Bug #1**: Duplicate static variable `$sfh` in `public/legacy/modules/AOW_WorkFlow/aow_utils.php` (line 644)
  - Symptom: Database failure error on initial load
  - Fix: Remove line 644 containing duplicate declaration
  
- **Bug #2**: Duplicate static variable `$sfh` in `public/legacy/include/InlineEditing/InlineEditing.php` (line 294)
  - Symptom: "Error while fetching data" when trying to login or access GraphQL API
  - Fix: Remove line 294 containing duplicate declaration
  
- **Bug #3**: Incorrect RewriteBase in `public/legacy/.htaccess`
  - Symptom: 500 Internal Server Error when accessing legacy pages
  - Issue: RewriteBase set to `localhostlegacy/` instead of `/legacy/`
  - Fix: Correct the RewriteBase path to `/legacy/`

### Changed
- Updated entrypoint script to automatically apply all bug fixes on container startup
- Enhanced README with detailed installation instructions and troubleshooting guide
- Improved documentation structure with Quick Start options

### Technical Details

All bug fixes are:
- **Idempotent**: Safe to run multiple times without breaking already-fixed installations
- **Automatic**: Applied during container startup via entrypoint script
- **Verified**: The entrypoint script detects bugs before applying fixes

The fixes address PHP 8.3 compatibility issues in SuiteCRM 8.4.0 that cause:
1. Fatal compile errors due to duplicate static variable declarations
2. Apache configuration errors due to malformed RewriteBase directives

## [1.0.0] - Initial Release

### Features
- Docker Compose setup for SuiteCRM 8.4.0
- PHP 8.3 with Apache
- MySQL database
- Xdebug support
- Automatic SuiteCRM download and setup
- GitHub Actions CI/CD pipeline
