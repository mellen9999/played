#!/usr/bin/env bash
# the one identity rule: title variants a service bolts on must dedupe, real
# alternate recordings must not. runs the functions from bin/played itself.
set -euo pipefail
PLAYED="$(dirname "$0")/../bin/played"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

eval "$(sed -n '/^_KEY_AWK=/,/^}'"'"'$/p' "$PLAYED")"
eval "$(sed -n '/^_history_has() {/,/^}/p' "$PLAYED")"
eval "$(sed -n '/^_existing_file() {/,/^}/p' "$PLAYED")"
key() { awk -v s="$1" "$_KEY_AWK"'BEGIN{print key(s)}'; }

fail=0
same() { [[ "$(key "$1")" == "$(key "$2")" ]] && printf '  ok   same: %s | %s\n' "$1" "$2" || { printf '  FAIL should match: %s | %s\n' "$1" "$2"; fail=1; }; }
diff_() { [[ "$(key "$1")" != "$(key "$2")" ]] && printf '  ok   differ: %s | %s\n' "$1" "$2" || { printf '  FAIL should differ: %s | %s\n' "$1" "$2"; fail=1; }; }

echo "key:"
same "Crawling" "Crawling (Remastered)"
same "Crawling" "crawling_-_2009_remaster"
same "Hungry Like the Wolf" "Hungry Like The Wolf - 2009 Remaster"
same "Ordinary World" "Ordinary World (Official Music Video)"
same "Campioni" "CAMPIONI (OFFICIAL AUDIO)"
same "Come Undone" "come_undone"
same "Slide" "Slide [HD] (Lyrics) #rock"
same "Numb" "Numb (Remastered 2013)"
same "Twisted" "Twisted (2007 Remaster)"
diff_ "Crawling" "Crawling (Live)"
diff_ "Cosmos" "Cosmos (Extended Mix)"
diff_ "Numb" "Numb (Acoustic)"
diff_ "Slide" "Slide (feat. Someone)"
diff_ "Hanging On" "Hanging On (CRi Remix ⧸ Visualizer)"
diff_ "Alive" "Alive - Radio Edit"
same "1979" "1979 (Remastered 2012)"
diff_ "1979" "Zero"

echo "history:"
HISTORY_FILE="$TMP/history.tsv"
printf 'unknown\tLinkin Park\tCrawling\t2026-01-01T00:00:00Z\tok\n' > "$HISTORY_FILE"
printf 'youtube:abc\tDuran Duran\tOrdinary World\t2026-01-01T00:00:00Z\tok\n' >> "$HISTORY_FILE"
chk() { if _history_has "$1" "$2" "$3"; then r=has; else r=no; fi; [[ "$r" == "$4" ]] && printf '  ok   %s %s → %s\n' "$2" "$3" "$r" || { printf '  FAIL %s %s → %s (want %s)\n' "$2" "$3" "$r" "$4"; fail=1; }; }
chk "" "Linkin Park" "Crawling (Remastered)" has
chk "" "linkin park" "CRAWLING" has
chk "" "Linkin Park" "Crawling (Live)" no
chk "youtube:abc" "Nobody" "Nothing" has
chk "youtube:zzz" "Duran Duran" "Ordinary World (Official Video)" has
chk "" "Linkin Park" "Numb" no

echo "existing file:"
mkdir -p "$TMP/duran_duran"
touch "$TMP/duran_duran/Come Undone.opus" "$TMP/duran_duran/hungry_like_the_wolf_-_2009_remaster.opus" \
      "$TMP/duran_duran/Duran Duran - Save A Prayer (Official Audio).opus" "$TMP/duran_duran/.deleted.log"
ex() { got=$(_existing_file "$TMP/duran_duran" "Duran Duran" "$1"); [[ "${got##*/}" == "$2" ]] && printf '  ok   %s → %s\n' "$1" "${2:-none}" || { printf '  FAIL %s → %q (want %q)\n' "$1" "$got" "$2"; fail=1; }; }
ex "Come Undone" "Come Undone.opus"
ex "come undone (remastered)" "Come Undone.opus"
ex "Hungry Like the Wolf" "hungry_like_the_wolf_-_2009_remaster.opus"
ex "Save A Prayer" "Duran Duran - Save A Prayer (Official Audio).opus"
ex "Rio" ""
ex "Come Undone (Live)" ""
touch "$TMP/duran_duran/Duran Duran, CRi - Rio (CRi Remix ⧸ Visualizer).opus" "$TMP/duran_duran/Someone Else - Come Undone.opus"
ex "Rio" ""
mkdir -p "$TMP/mxv"; touch "$TMP/mxv/MXV & mölly & Courtney Storm - Wander.mp3"
got=$(_existing_file "$TMP/mxv" "MXV" "Wander"); [[ "${got##*/}" == "MXV & mölly & Courtney Storm - Wander.mp3" ]] && echo "  ok   collab prefix" || { echo "  FAIL collab prefix: $got"; fail=1; }

[[ $fail == 0 ]] && echo "all ok" || { echo "FAILED"; exit 1; }
