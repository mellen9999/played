#!/usr/bin/env bash
# minimal smoke test for the sanitizer — sources played and exercises edge cases
set -euo pipefail

# extract _safe_component without running main
SCRIPT="$(dirname "$0")/../bin/played"

# run safe_component via a subshell that exits before main
out() {
  PLAYED_TEST=1 bash -c "
    set +e
    source '$SCRIPT' 2>/dev/null
    _safe_component \"\$1\"
  " _ "$1"
}

# stub: source-and-call won't work because main runs at import. patch by
# extracting the function via awk and evaluating it directly.
extract_fn() {
  awk -v name="$1" '
    $0 ~ "^"name"\\(\\) \\{" {flag=1}
    flag {print}
    flag && $0 ~ "^\\}" {flag=0; exit}
  ' "$SCRIPT"
}

eval "$(extract_fn _safe_component)"
eval "$(extract_fn _clean_title)"

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" == "$want" ]]; then
    printf '  ok   %s\n' "$msg"
  else
    printf '  FAIL %s\n        got:  %q\n        want: %q\n' "$msg" "$got" "$want"
    exit 1
  fi
}

echo "_safe_component:"
assert_eq "$(_safe_component "Flume")"          "flume"          "basic"
assert_eq "$(_safe_component "Foo Fighters")"   "foo_fighters"   "spaces"
assert_eq "$(_safe_component "../etc/passwd")"  "etcpasswd"      "path traversal"
assert_eq "$(_safe_component "..")"             "_"              "lone dotdot"
assert_eq "$(_safe_component "")"               "_"              "empty"
assert_eq "$(_safe_component ".hidden")"        "hidden"         "leading dot"
assert_eq "$(_safe_component "-flag")"          "flag"           "leading dash"
assert_eq "$(_safe_component $'a\nb')"          "a_b"            "newline"
assert_eq "$(_safe_component $'a\tb')"          "a_b"            "tab"
assert_eq "$(_safe_component "CON")"            "_con"           "windows reserved"
assert_eq "$(_safe_component "a/b\\c")"         "abc"            "slashes"

echo "_clean_title:"
assert_eq "$(_clean_title "Skin (Official Audio)")"        "Skin"        "official audio"
assert_eq "$(_clean_title "Hot Blooded (Lyric Video)")"    "Hot Blooded" "lyric video"
assert_eq "$(_clean_title "Track [PREMIERE]")"             "Track"       "premiere"
assert_eq "$(_clean_title "Track #edm #house")"            "Track"       "hashtags"

echo "all tests passed"
