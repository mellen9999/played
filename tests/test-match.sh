#!/usr/bin/env bash
# unit test for the candidate scorer.
set -euo pipefail

MATCH="$(dirname "$0")/../lib/played-match"

assert() {
  local name="$1" expected="$2" got="$3"
  if [[ "$got" == "$expected" ]]; then
    printf '  ok   %s\n' "$name"
  else
    printf '  FAIL %s\n        got:  %q\n        want: %q\n' "$name" "$got" "$expected"
    exit 1
  fi
}

# fixture: 4 plausible candidates for "Sam Davies - Cosmos" (240s album cut)
fixture='{"id":"abc123","title":"Sam Davies - Cosmos","duration":240,"uploader":"Sam Davies - Topic","view_count":50000}
{"id":"def456","title":"Cosmos (Extended Mix)","duration":414,"uploader":"Monstercat Silk","view_count":250000}
{"id":"ghi789","title":"Sam Davies - Cosmos (Live)","duration":260,"uploader":"some random","view_count":1000}
{"id":"jkl012","title":"Cosmos by Carl Sagan","duration":300,"uploader":"Doc Channel","view_count":5000000}'

echo "scorer:"

# album cut (Topic) should pick at top
top=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 240 --threshold 70 | head -1 | cut -f3)
assert "Topic 240s album cut wins" "abc123" "$top"

# the Topic 240s candidate must score 'pick'
pick_flag=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 240 --threshold 70 | head -1 | cut -f1)
assert "winner has pick flag" "pick" "$pick_flag"

# extended mix should be rejected by duration even with high views
ext_flag=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 240 --threshold 70 | grep '^[a-z]*	[^	]*	def456' | cut -f1)
assert "extended mix flagged skip" "skip" "$ext_flag"

# wrong-song with massive views should NOT win (title penalty)
wrong=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 240 --threshold 70 | grep '^[a-z]*	[^	]*	jkl012' | cut -f1)
assert "wrong-song flagged skip" "skip" "$wrong"

# when no length is known, duration neutralizes — still picks Topic by trust+title
top_nolen=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 0 --threshold 70 | head -1 | cut -f3)
assert "no length: Topic still wins" "abc123" "$top_nolen"

# threshold tuning: at 95, even the Topic shouldn't score 'pick' for this fixture
high_thresh=$(printf '%s\n' "$fixture" | "$MATCH" --artist "Sam Davies" --title "Cosmos" --length-sec 240 --threshold 95 | head -1 | cut -f1)
assert "high threshold rejects all" "skip" "$high_thresh"

echo "all match tests passed"
