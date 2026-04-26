#!/usr/bin/env bash
# regression: case-insensitive existence check so legacy mixed-case files
# (Breakaway.opus from spotify-dl) are detected by played's lowercase target
# (breakaway.opus). Without this, the same song re-downloads forever.
set -euo pipefail

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# the production check, copied from bin/played
exists_check() {
  local target="$1"
  local target_dir
  target_dir=$(dirname "$target")
  find "$target_dir" -maxdepth 1 -type f -iname "$(basename "$target")" -print -quit 2>/dev/null || true
}

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" == "$want" ]]; then
    printf '  ok   %s\n' "$msg"
  else
    printf '  FAIL %s\n        got:  %q\n        want: %q\n' "$msg" "$got" "$want"
    exit 1
  fi
}

echo "exists_check:"

mkdir -p "$TMP/artist1"
touch "$TMP/artist1/Breakaway.opus"
got=$(exists_check "$TMP/artist1/breakaway.opus")
assert_eq "$got" "$TMP/artist1/Breakaway.opus" "lowercase target finds capitalized file"

mkdir -p "$TMP/artist2"
touch "$TMP/artist2/song.opus"
got=$(exists_check "$TMP/artist2/song.opus")
assert_eq "$got" "$TMP/artist2/song.opus" "exact match still works"

got=$(exists_check "$TMP/missing/anything.opus")
assert_eq "$got" "" "missing directory returns empty"

mkdir -p "$TMP/artist3"
got=$(exists_check "$TMP/artist3/nothere.opus")
assert_eq "$got" "" "missing file in existing dir returns empty"

mkdir -p "$TMP/artist4"
touch "$TMP/artist4/Track With Spaces.opus"
got=$(exists_check "$TMP/artist4/track with spaces.opus")
assert_eq "$got" "$TMP/artist4/Track With Spaces.opus" "spaces in filename"

echo "all exists-check tests passed"
