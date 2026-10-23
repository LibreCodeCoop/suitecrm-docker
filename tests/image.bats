#!/usr/bin/env bats

setup() {
  : "${SUITECRM_TEST_IMAGE:?SUITECRM_TEST_IMAGE must name an already-built image}"
  docker image inspect "$SUITECRM_TEST_IMAGE" >/dev/null
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "built image contains the selected SuiteCRM release package" {
  expected="$(tr -d '[:space:]' < "$REPO_ROOT/SUITECRM_VERSION")"
  run docker run --rm -e "EXPECTED_VERSION=$expected" --entrypoint sh "$SUITECRM_TEST_IMAGE" -ec '
    test "$(cat /etc/suitecrm-version)" = "$EXPECTED_VERSION"
    test -f /opt/suitecrm/VERSION
    test -f /opt/suitecrm/bin/console
  '
  [ "$status" -eq 0 ]
}

@test "built PHP provides SuiteCRM extensions and sane upload limits" {
  run docker run --rm --entrypoint php "$SUITECRM_TEST_IMAGE" -r '
    foreach (["apcu", "gd", "imap", "intl", "ldap", "mysqli", "pdo_mysql", "soap", "zip"] as $name) {
      if (!extension_loaded($name)) {
        fwrite(STDERR, "Missing extension: $name\n");
        exit(1);
      }
    }
    $bytes = static function (string $value): int {
      if ($value === "-1") return PHP_INT_MAX;
      if (!preg_match("/^([0-9]+)([KMG]?)$/i", $value, $match)) return 0;
      $factor = ["", "K", "M", "G"];
      $exponent = array_search(strtoupper($match[2]), $factor, true);
      return (int) $match[1] * 1024 ** $exponent;
    };
    if ($bytes(ini_get("memory_limit")) < 256 * 1024 * 1024) exit(2);
    if ($bytes(ini_get("post_max_size")) <= $bytes(ini_get("upload_max_filesize"))) exit(3);
    if (!filter_var(ini_get("log_errors"), FILTER_VALIDATE_BOOL)) exit(4);
    if (filter_var(ini_get("display_errors"), FILTER_VALIDATE_BOOL)) exit(5);
    echo "PHP runtime OK\n";
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"PHP runtime OK"* ]]
}

@test "entrypoint installs application into a disposable empty directory" {
  run docker run --rm --entrypoint bash "$SUITECRM_TEST_IMAGE" -ec '
    scratch="$(mktemp -d)"
    cd "$scratch"
    /var/www/scripts/entrypoint.sh true
    test -f VERSION
    test -x bin/console
    test "$(stat -c %U VERSION)" = www-data
  '
  [ "$status" -eq 0 ]
}

@test "entrypoint preserves an existing installation" {
  run docker run --rm --entrypoint bash "$SUITECRM_TEST_IMAGE" -ec '
    scratch="$(mktemp -d)"
    cd "$scratch"
    touch LICENSE.txt
    printf "%s\n" existing > sentinel.txt
    /var/www/scripts/entrypoint.sh true
    test ! -e VERSION
    test "$(cat sentinel.txt)" = existing
  '
  [ "$status" -eq 0 ]
}
