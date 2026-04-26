# played

[![lint](https://github.com/mellen9999/played/actions/workflows/lint.yml/badge.svg)](https://github.com/mellen9999/played/actions/workflows/lint.yml)

auto-archive music you actually listen to.

`played` watches any [MPRIS](https://specifications.freedesktop.org/mpris-spec/2.2/)-compatible music player (Spotify, mpd, VLC, Mopidy, GNOME Music, …) and downloads tracks you played past a threshold (default 80%) as tagged opus files. It's a personal listening-history archiver, not a bulk ripper — only what *you* heard, only after *you* heard most of it.

```
$ played status
played v0.1.0

config:
  music dir:  /home/u/Music
  threshold:  80%
  format:     opus @ 128K
  players:    spotify spotifyd

library:
  saved:      347
  failed:     2
  disk used:  4.1G

now playing (Playing via spotify):
  Flume — Skin  [45%]
```

## why

Spotify Wrapped tells you what you played. `played` *keeps* it. Build a personal library of music you've actually committed to over time, with no manual curation. Survives lost subscriptions, removed tracks, and country-locked catalogs.

## install

### arch (AUR)

```sh
paru -S played-git
systemctl --user enable --now played
```

### manual

```sh
git clone https://github.com/mellen9999/played
cd played
make user-install
played init
systemctl --user enable --now played
```

deps: `bash` `playerctl` `yt-dlp` `ffmpeg` `flock` `python3` `python3-mutagen`.

## how it works

1. polls MPRIS metadata via `playerctl` every few seconds
2. tracks the max position reached for each track
3. when the track changes, if `max_pos / length ≥ threshold`, runs the matching pipeline:
   - searches **10 candidates** on YouTube
   - scores each (40% duration match, 25% title, 25% uploader trust, 7% popularity, 3% freshness)
   - **rejects** if no candidate scores ≥ `SCORE_THRESHOLD` (default 70) — saving nothing is better than saving the wrong version
   - downloads top pick at the configured **quality level** (no lossy→lossy re-encoding)
   - **post-verifies** duration is within ±5s of Spotify's `mpris:length`; deletes and tries next candidate if off
4. retags with canonical MPRIS metadata (artist, title, album, track #), strips YouTube's verbose synopsis, embeds cover art via mutagen
5. dedupes by Spotify track URI when available, otherwise by lowercased artist+title

## quality levels

| `QUALITY=` | yt-dlp format | result |
|---|---|---|
| `best` | `251/140/bestaudio` | **zero re-encode** — webm/m4a native (best audio fidelity) |
| `opus` *(default)* | `251/bestaudio` → opus 192k | passthrough if YT serves opus, single transcode otherwise |
| `opus-compact` | `bestaudio` → opus 128k | smaller files, more transcode loss |

YouTube serves opus 160k for popular tracks. `opus-compact` re-encodes 160k → 128k = audible loss. `opus` avoids that.

## scoring + rejection

uploader trust hierarchy: `Topic` (auto-uploads from labels) > `VEVO` > known label keywords > random uploader. Title penalty (×0.5) for `remix/extended/live/mix/demo` words not in the original. Duration scoring is steepest: anything > 60s off = 0.

threshold defaults to 70. lower it (e.g. 60) to be more permissive at the cost of more wrong-version saves. raise it (90) to only accept very clean matches at the cost of more rejections. tune per your taste.

## config

`~/.config/played/config.sh` — sourced as bash. See `examples/config.example`.

```sh
MUSIC_DIR="$HOME/Music"
THRESHOLD=80          # percent of track that must be played
MIN_DURATION_SEC=30   # ignore intros / skits / very short tracks
MAX_DURATION_SEC=600  # ignore mixes / DJ sets
AUDIO_FORMAT=opus     # any yt-dlp-supported format
AUDIO_QUALITY=128K
POLL_INTERVAL=3
PLAYERS="spotify spotifyd"   # MPRIS player names, in priority order
# DRY_RUN=1           # log what would be saved without downloading
```

## commands

| | |
|---|---|
| `played watch` | run the daemon (default) |
| `played download` | download the currently-playing track now |
| `played status` | show daemon, library, and current-track state |
| `played history [search QUERY]` | list/search downloads |
| `played config [show\|edit]` | inspect or edit config |
| `played init` | first-run setup |

## filtering

these tracks are skipped automatically:

- ads (`xesam:artist == "Spotify"` and `xesam:title == "Advertisement"`)
- podcasts (`xesam:url` starts with `spotify:episode:`)
- tracks shorter than `MIN_DURATION_SEC` (default 30s)
- tracks longer than `MAX_DURATION_SEC` (default 10m — catches DJ sets / mixes)

## storage layout

```
$MUSIC_DIR/
├── flume/
│   └── skin.opus
├── new_constellations/
│   └── hot_blooded.opus
└── …
```

album-aware layout (`$artist/$album/$track - $title`) is on the roadmap for v0.2.

## history file

`~/.local/state/played/history.tsv` — tab-separated:

```
spotify_uri	artist	title	timestamp	status	source	score	bitrate
spotify:track:5h…	Flume	Skin	2026-04-25T14:23:00Z	ok	youtube:abc123	84.2	160000
```

`status` values: `ok`, `rejected` (no candidate met the bar), `no-candidates`, `failed`, `exists`, `diskfull`, `migrated`.

v0.1 5-column rows still parse cleanly — extra columns are appended for new rows.

## migration from `spotify-dl`

if you used the precursor `spotify-dl` script, on first run `played` will migrate `~/sync/music/.downloaded` into the new TSV format with `status=migrated` and `uri=unknown`. existing downloads are detected by file existence on disk regardless.

## legal

`played` only downloads tracks the user actively listens to past a high threshold. it relies on yt-dlp to fetch publicly available copies from YouTube. you are responsible for compliance with the laws of your jurisdiction and the terms of any service you use it with. it does not bypass DRM. it does not interact with Spotify's audio stream.

## license

MIT
