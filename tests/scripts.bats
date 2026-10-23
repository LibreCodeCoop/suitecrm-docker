#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/project/scripts" "$TEST_ROOT/bin"
  cp "$REPO_ROOT/install.sh" "$REPO_ROOT/SUITECRM_VERSION" "$TEST_ROOT/project/"
  cp "$REPO_ROOT/scripts/upgrade-suitecrm.sh" "$TEST_ROOT/project/scripts/"

  export TEST_CALLS="$TEST_ROOT/calls"
  export TEST_UPGRADED="$TEST_ROOT/upgraded"
  export TARGET_VERSION
  TARGET_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/SUITECRM_VERSION")"
  TARGET_VERSION="${TARGET_VERSION#v}"
  export CURRENT_VERSION=0.0.1
  : > "$TEST_CALLS"

  cat > "$TEST_ROOT/bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$TEST_CALLS"
case " $* " in
  *" suitecrm:version "*)
    if [[ -f "$TEST_UPGRADED" ]]; then
      printf '%s\n' "$TARGET_VERSION"
    else
      printf '%s\n' "$CURRENT_VERSION"
    fi
    ;;
  *" suitecrm:app:upgrade-finalize "*)
    [[ "${FAIL_FINALIZE:-0}" == 1 ]] && exit 25
    touch "$TEST_UPGRADED"
    ;;
  *" suitecrm:app:upgrade "*)
    if [[ "${FAIL_UPGRADE:-0}" == 1 ]]; then exit 26; fi
    ;;
  *" sh -c "*)
    if [[ "${ALLOW_PROD:-1}" == 0 ]]; then exit 27; fi
    ;;
  *" ps --status running "*)
    [[ "${EMPTY_SERVICE:-0}" == 1 ]] || echo synthetic-running-container
    ;;
esac
MOCK

  cat > "$TEST_ROOT/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$TEST_CALLS"
while (($#)); do
  if [[ "$1" == "--output" ]]; then
    printf 'synthetic package\n' > "$2"
    exit 0
  fi
  shift
done
exit 30
MOCK

  cat > "$TEST_ROOT/bin/unzip" <<'MOCK'
#!/usr/bin/env bash
printf 'unzip %s\n' "$*" >> "$TEST_CALLS"
[[ -f "${@: -1}" ]]
MOCK

  chmod +x "$TEST_ROOT/bin/"*
  export PATH="$TEST_ROOT/bin:$PATH"
}

teardown() {
  [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]] && rm -rf -- "$TEST_ROOT"
}

run_upgrade() {
  run bash "$TEST_ROOT/project/scripts/upgrade-suitecrm.sh" "$@"
}

@test "upgrade refuses to run without an explicit verified-backup confirmation" {
  run_upgrade
  [ "$status" -ne 0 ]
  [[ "$output" == *"verified file and database backups"* ]]
  [ ! -s "$TEST_CALLS" ]
}

@test "upgrade rejects an invalid SuiteCRM release identifier before running commands" {
  printf '%s\n' 'invalid;version' > "$TEST_ROOT/project/SUITECRM_VERSION"
  run_upgrade --backup-confirmed
  [ "$status" -ne 0 ]
  [ ! -s "$TEST_CALLS" ]
}

@test "upgrade rejects a stopped web service" {
  export EMPTY_SERVICE=1
  run_upgrade --backup-confirmed
  [ "$status" -ne 0 ]
  [[ "$output" == *"not running"* ]]
  ! grep -q '^curl ' "$TEST_CALLS"
}

@test "upgrade skips download and migration if current version already matches" {
  export CURRENT_VERSION="$TARGET_VERSION"
  run_upgrade --backup-confirmed
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already at target version"* ]]
  ! grep -q '^curl ' "$TEST_CALLS"
  ! grep -q 'suitecrm:app:upgrade' "$TEST_CALLS"
  ! grep -q 'compose restart' "$TEST_CALLS"
}

@test "upgrade completes both migration phases and checks installed version" {
  run_upgrade --backup-confirmed
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed application version: $TARGET_VERSION"* ]]
  grep -q 'suitecrm:app:upgrade --no-interaction' "$TEST_CALLS"
  grep -q 'suitecrm:app:upgrade-finalize --no-interaction' "$TEST_CALLS"
  grep -q 'compose restart php' "$TEST_CALLS"
  grep -q -- '--user www-data php php bin/console suitecrm:version' "$TEST_CALLS"
  ! grep -q 'app:version:status' "$TEST_CALLS"
}

@test "failed upgrade does not finalize or restart the service" {
  export FAIL_UPGRADE=1
  run_upgrade --backup-confirmed
  [ "$status" -ne 0 ]
  ! grep -q 'suitecrm:app:upgrade-finalize' "$TEST_CALLS"
  ! grep -q 'compose restart' "$TEST_CALLS"
}

@test "failed finalization does not report success or restart the service" {
  export FAIL_FINALIZE=1
  run_upgrade --backup-confirmed
  [ "$status" -ne 0 ]
  ! grep -q 'compose restart' "$TEST_CALLS"
}

@test "upgrade refuses nonproduction environment before downloading" {
  export ALLOW_PROD=0
  run_upgrade --backup-confirmed
  [ "$status" -ne 0 ]
  ! grep -q '^curl ' "$TEST_CALLS"
}

@test "installer refuses missing database credentials without invoking Docker" {
  printf '%s\n' 'MYSQL_ROOT_PASSWORD=' 'MYSQL_PASSWORD=' > "$TEST_ROOT/project/.env"
  run bash "$TEST_ROOT/project/install.sh"
  [ "$status" -ne 0 ]
  [ ! -s "$TEST_CALLS" ]
}

@test "installer starts a development database explicitly and then background services" {
  printf '%s\n' 'MYSQL_ROOT_PASSWORD=synthetic' 'MYSQL_PASSWORD=synthetic' > "$TEST_ROOT/project/.env"
  run bash "$TEST_ROOT/project/install.sh"
  [ "$status" -eq 0 ]
  grep -q 'compose --profile dev-db up -d --wait mysql' "$TEST_CALLS"
  grep -q 'compose up -d php' "$TEST_CALLS"
  grep -q 'suitecrm:app:install' "$TEST_CALLS"
  grep -q 'compose --profile background up -d messenger scheduler' "$TEST_CALLS"
}
