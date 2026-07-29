#!/usr/bin/env bash
# regression: a partial yt-dlp grab exits 0 and still plays, it just stops early.
# _verify_audio is the only thing standing between that and the library, so every
# way a file can be wrong must reject — especially the ones we cannot measure.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLAYED="$HERE/../bin/played"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# extract the real function rather than copying it — a stale copy of this
# particular check would pass the tests while the library silently rots
DURATION_TOLERANCE_SEC=5
log() { :; }
eval "$(sed -n '/^_verify_audio() {/,/^}/p' "$PLAYED")"
[[ $(type -t _verify_audio) == function ]] || { echo "FAIL could not extract _verify_audio from $PLAYED"; exit 1; }

assert_verify() {
  local want="$1" msg="$2" file="$3" target="$4" got
  if _verify_audio "$file" "$target" >/dev/null 2>&1; then got=accept; else got=reject; fi
  if [[ "$got" == "$want" ]]; then
    printf '  ok   %s\n' "$msg"
  else
    printf '  FAIL %s\n        got:  %s\n        want: %s\n' "$msg" "$got" "$want"
    exit 1
  fi
}

# synthesize tones instead of shipping binary fixtures
tone() { ffmpeg -v error -f lavfi -i "sine=frequency=440:duration=$1" -c:a libopus -b:a 96k "$2" -y; }

echo "verify_audio:"

tone 120 "$TMP/full.opus"
assert_verify accept "full track, matching length"        "$TMP/full.opus" 120
assert_verify accept "full track, within tolerance"       "$TMP/full.opus" 124
assert_verify accept "no reference length, file is sound"  "$TMP/full.opus" 0

assert_verify reject "full track, outside tolerance"      "$TMP/full.opus" 140

tone 20 "$TMP/short.opus"
assert_verify reject "truncated to 20s of 120s"           "$TMP/short.opus" 120

# right length, mangled middle — the case a duration check alone cannot catch
cp "$TMP/full.opus" "$TMP/corrupt.opus"
size=$(stat -c%s "$TMP/corrupt.opus")
dd if=/dev/urandom of="$TMP/corrupt.opus" bs=1 seek=$((size / 2)) count=3000 conv=notrunc status=none
assert_verify reject "corrupt stream, correct duration"   "$TMP/corrupt.opus" 120

# unmeasurable must fail closed: an unreadable file is worse than a short one
printf 'not audio at all, but large enough to pass a size check%.0s' {1..400} > "$TMP/garbage.opus"
assert_verify reject "unreadable file fails closed"       "$TMP/garbage.opus" 120
assert_verify reject "unreadable file with no reference"  "$TMP/garbage.opus" 0

: > "$TMP/empty.opus"
assert_verify reject "zero-byte file"                     "$TMP/empty.opus" 120

head -c 500 "$TMP/full.opus" > "$TMP/tiny.opus"
assert_verify reject "truncated to a stub"                "$TMP/tiny.opus" 120

assert_verify reject "missing file"                       "$TMP/nope.opus" 120

# some ogg files carry packets with equal timestamps — 66 of them in one real
# library track — and the null muxer complains about every one while the audio
# decodes in full. treating that as corruption sends played back to youtube for
# a track it already has, forever. stub ffmpeg to make the distinction exactly.
stub_ffmpeg() {
  mkdir -p "$TMP/bin"
  { echo '#!/usr/bin/env bash'; printf 'printf %%s\\\\n "%s" >&2\nexit 0\n' "$1"; } > "$TMP/bin/ffmpeg"
  chmod +x "$TMP/bin/ffmpeg"
}

PATH="$TMP/bin:$PATH"
stub_ffmpeg "[null @ 0x1] Application provided invalid, non monotonically increasing dts to muxer in stream 0: 100 >= 100"
assert_verify accept "muxer timestamp grumble is not corruption" "$TMP/full.opus" 120

stub_ffmpeg "[opus @ 0x1] Error decoding Opus frame: corrupted stream"
assert_verify reject "a real decode error still rejects"          "$TMP/full.opus" 120
rm -rf "$TMP/bin"

echo "all verify tests passed"
