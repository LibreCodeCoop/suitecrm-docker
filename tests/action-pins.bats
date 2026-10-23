#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

check_pins() {
  local file line reference count=0
  local use_ref='^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*([^[:space:]#]+)'
  local pinned_ref='^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)+@[a-f0-9]{40}[[:space:]]+#[[:space:]]+v?[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9.-]+)?[[:space:]]*$'

  for file in "$@"; do
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ $use_ref ]] || continue
      reference="${BASH_REMATCH[2]}"
      [[ "$reference" == ./* ]] && continue
      ((count += 1))
      if [[ ! "$line" =~ $pinned_ref ]]; then
        printf '%s: unpinned Action or missing version comment: %s\n' "$file" "$line" >&2
        return 1
      fi
    done < "$file"
  done

  (( count > 0 ))
}

@test "external Actions use full commit SHAs with explicit semver comments" {
  local -a files=()
  local file
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$REPO_ROOT/.github/workflows" "$REPO_ROOT/.github/actions" \
    -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)
  [ "${#files[@]}" -gt 0 ]
  check_pins "${files[@]}"
}

@test "mutable tags and missing or malformed version comments are rejected" {
  local fixture="$BATS_TEST_TMPDIR/actions.yml"
  printf '%s\n' '    - uses: actions/checkout@v4' > "$fixture"
  run check_pins "$fixture"
  [ "$status" -ne 0 ]

  printf '%s\n' '    - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262' > "$fixture"
  run check_pins "$fixture"
  [ "$status" -ne 0 ]

  printf '%s\n' '    - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # latest' > "$fixture"
  run check_pins "$fixture"
  [ "$status" -ne 0 ]
}

@test "pinned actions and relative actions are accepted" {
  local fixture="$BATS_TEST_TMPDIR/actions.yml"
  printf '%s\n' \
    '    - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0' \
    '    - uses: ./.github/actions/test' > "$fixture"
  run check_pins "$fixture"
  [ "$status" -eq 0 ]
}
