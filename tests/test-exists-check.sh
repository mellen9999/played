#!/usr/bin/env bash
# regression: a pre-existing copy under any spelling (Breakaway.opus, a legacy
# "artist - title (official audio)" name) must be found by played's lowercase
# target, or the same song re-downloads forever. runs _existing_file from bin/played.
set -euo pipefail
PLAYED="$(dirname "$0")/../bin/played"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
eval "$(sed -n '/^_KEY_AWK=/,/^}'"'"'$/p' "$PLAYED")"
eval "$(sed -n '/^_existing_file() {/,/^}/p' "$PLAYED")"

assert_eq() {
  if [[ "$1" == "$2" ]]; then printf '  ok   %s\n' "$3"
  else printf '  FAIL %s\n        got:  %q\n        want: %q\n' "$3" "$1" "$2"; exit 1; fi
}
echo "exists_check:"
mkdir -p "$TMP/artist1" "$TMP/artist2"
touch "$TMP/artist1/Breakaway.opus" "$TMP/artist2/Artist2 - Some Song (Official Audio).opus"
assert_eq "$(_existing_file "$TMP/artist1" "artist1" "breakaway")" "$TMP/artist1/Breakaway.opus" "mixed-case copy found"
assert_eq "$(_existing_file "$TMP/artist1" "artist1" "other song")" "" "unrelated title not found"
assert_eq "$(_existing_file "$TMP/artist2" "Artist2" "Some Song")" "$TMP/artist2/Artist2 - Some Song (Official Audio).opus" "legacy prefixed copy found"
assert_eq "$(_existing_file "$TMP/missing" "x" "y")" "" "missing dir is not an error"
echo "all ok"
