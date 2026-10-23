#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  command -v docker >/dev/null 2>&1
  command -v jq >/dev/null 2>&1
}

compose_config() {
  docker compose --env-file /dev/null --project-directory "$REPO_ROOT" \
    -f "$REPO_ROOT/docker-compose.yml" "$@" config --format json
}

@test "default Compose starts only the application from a published image" {
  run compose_config
  [ "$status" -eq 0 ]
  jq -e '
    (.services | has("php") and (has("mysql") | not)
       and (has("messenger") | not) and (has("scheduler") | not))
    and (.services.php.image | startswith("ghcr.io/librecodecoop/suitecrm-docker/suite-crm:"))
    and (.services.php | has("build") | not)
    and (.services.php | has("depends_on") | not)
  ' <<< "$output"
}

@test "background services use the web image, files and user without local builds" {
  run compose_config --profile background
  [ "$status" -eq 0 ]
  jq -e '
    (.services | has("mysql") | not)
    and (.services.php.image == .services.messenger.image)
    and (.services.php.image == .services.scheduler.image)
    and (.services.messenger.user == "www-data")
    and (.services.scheduler.user == "www-data")
    and ([.services.php, .services.messenger, .services.scheduler]
         | all(has("build") | not))
    and (.services.php.volumes[0].source == .services.messenger.volumes[0].source)
    and (.services.php.volumes[0].source == .services.scheduler.volumes[0].source)
    and (.services.messenger.volumes[0].target == "/var/www/html")
    and (.services.scheduler.volumes[0].target == "/var/www/html")
  ' <<< "$output"
}

@test "Messenger consumes the internal queue" {
  run compose_config --profile background
  [ "$status" -eq 0 ]
  jq -e '
    .services.messenger.command |
      (index("messenger:consume") != null) and
      (index("internal-async") != null)
  ' <<< "$output"
}

@test "scheduler uses SuiteCRM console instead of the legacy cron entrypoint" {
  run compose_config --profile background
  [ "$status" -eq 0 ]
  jq -e '
    (.services.scheduler.command | join(" ") | contains("schedulers:run"))
    and (.services.scheduler.command | join(" ") | contains("sleep 60"))
    and (.services.scheduler.command | join(" ") | contains("legacy/cron.php") | not)
  ' <<< "$output"
}

@test "development database requires an explicit profile and has no published port" {
  run compose_config --profile dev-db
  [ "$status" -eq 0 ]
  jq -e '
    .services.mysql.image != null
    and (.services.mysql | has("ports") | not)
  ' <<< "$output"
}

@test "a local build requires the explicit build override" {
  run docker compose --env-file /dev/null --project-directory "$REPO_ROOT" \
    -f "$REPO_ROOT/docker-compose.yml" -f "$REPO_ROOT/docker-compose.build.yml" \
    --profile background config --format json
  [ "$status" -eq 0 ]
  jq -e '
    [.services.php, .services.messenger, .services.scheduler]
      | all(has("build"))
  ' <<< "$output"
}
