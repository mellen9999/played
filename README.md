# played

[![lint](https://github.com/mellen9999/played/actions/workflows/lint.yml/badge.svg)](https://github.com/mellen9999/played/actions/workflows/lint.yml)

Auto-archive music you actually listen to.

`played` watches your music player and quietly downloads tracks you finished — to opus files, properly tagged, in your library. It's a personal listening-history archiver, not a bulk ripper. Only what you heard, only after you heard most of it.

```
$ played status

config:
  music dir:    ~/Music
  listen pct:   80%
  quality:      opus
  score min:    70
  dur tol:      ±5s
  search top-N: 10
  players:      spotify spotifyd

library:
  saved:      347
  failed:     2
  disk used:  4.1G

now playing (Playing via spotify):
  Flume — Skin  [45%]
```

Spotify Wrapped tells you what you played. `played` *keeps* it. Build a personal library of music you've actually committed to over time, with no manual curation. Survives lost subscriptions, removed tracks, and country-locked catalogs.

## is it for me?

You'll get the most out of `played` if you stream music on Linux and miss having a local library.

It needs:

- **Linux with a desktop session.** macOS and Windows don't have MPRIS — the player-agnostic protocol `played` listens on — so it can't run there.
- **A music player that exposes MPRIS.** Spotify (desktop), spotifyd, mpd (with mpDris2), VLC, Strawberry, Rhythmbox, GNOME Music, Mopidy, Clementine, Tauon, Amberol, audacious, lollypop. Run `playerctl --list-all` to see what's exposed on your system. **Spotify Web Player in a browser is not exposed** — use the desktop client.
- **Internet.** Downloads come from YouTube via yt-dlp.
- **Disk.** ~5 GB per ~500 tracks at default quality.

## install

`played` is a bash script + two small Python helpers. Install the deps, then drop the files into `~/.local`.

### 1. dependencies

| distro | command |
|---|---|
| Arch / Manjaro | `sudo pacman -S bash playerctl yt-dlp ffmpeg util-linux python python-mutagen` |
| Debian / Ubuntu / Mint | `sudo apt install bash playerctl yt-dlp ffmpeg util-linux python3 python3-mutagen` |
| Fedora | `sudo dnf install bash playerctl yt-dlp ffmpeg util-linux python3 python3-mutagen` |
| openSUSE | `sudo zypper install bash playerctl yt-dlp ffmpeg util-linux python3 python3-mutagen` |
| Alpine | `sudo apk add bash playerctl yt-dlp ffmpeg util-linux python3 py3-mutagen` |
| Void | `sudo xbps-install -S bash playerctl yt-dlp ffmpeg util-linux python3 python3-mutagen` |
| NixOS | add `bash playerctl yt-dlp ffmpeg util-linux python3 python3Packages.mutagen` to your config |

A few caveats:

- **Fedora** users need [RPM Fusion](https://rpmfusion.org/) for a full ffmpeg.
- If your distro packages a stale yt-dlp (>6 months old), prefer `pipx install yt-dlp`. YouTube changes break old yt-dlp builds.

### 2. played itself

```sh
git clone https://github.com/mellen9999/played
cd played
make user-install
played init
systemctl --user enable --now played
```

That's it. `played` is now running in the background and will save tracks as you finish them.

#### Arch: PKGBUILD

The repo ships a PKGBUILD if you'd rather install via pacman:

```sh
git clone https://github.com/mellen9999/played
cd played
makepkg -si
systemctl --user enable --now played
```

#### Headless / always-on

If you want `played` to keep running when you're logged out (e.g. on a home server with mpd):

```sh
sudo loginctl enable-linger $USER
```

## first run

Play a song you like and let it finish. When the next track starts, the previous one shows up under your music dir as a tagged opus file. To force a download for whatever's playing right now:

```sh
played download
```

To see what's been saved:

```sh
played history
played history search flume
```

## uninstall

```sh
systemctl --user disable --now played
cd played
make user-uninstall
rm -rf ~/.config/played ~/.local/state/played
```

Your music dir is left alone.

## configure

`~/.config/played/config.sh` — plain bash, sourced on each run. Run `played config edit` to open it in `$EDITOR`.

```sh
MUSIC_DIR="$HOME/Music"          # where downloads go
THRESHOLD=80                     # percent of track played before saving
MIN_DURATION_SEC=30              # skip intros, skits, ads
MAX_DURATION_SEC=600             # skip DJ sets, mixes (10 min)
QUALITY=opus                     # best | opus | opus-compact
SCORE_THRESHOLD=70               # 0-100; how confident the YT match must be
DURATION_TOLERANCE_SEC=5         # reject downloads >5s off Spotify length
SEARCH_LIMIT=10                  # YT search candidates per track
EMBED_COVER=1                    # 1 to embed cover art, 0 to skip
POLL_INTERVAL=3                  # MPRIS poll seconds
PLAYERS="spotify spotifyd"       # MPRIS player names, priority order
# DRY_RUN=1                      # log what would save, don't download
```

Every setting also has a `PLAYED_*` environment variable that overrides the file (e.g. `PLAYED_THRESHOLD=90 played watch`).

### custom music dir

If `MUSIC_DIR` isn't `~/Music`, the systemd unit needs a drop-in to grant write access:

```sh
mkdir -p ~/.config/systemd/user/played.service.d
cat > ~/.config/systemd/user/played.service.d/music-dir.conf <<EOF
[Service]
ReadWritePaths=$HOME/your/music/path
EOF
systemctl --user daemon-reload
systemctl --user restart played
```

## quality

| `QUALITY=` | what you get |
|---|---|
| `best` | zero re-encode — webm/m4a native; best fidelity, larger files |
| `opus` *(default)* | opus 192k; passthrough if YT serves opus, one transcode if not |
| `opus-compact` | opus 128k; smaller files, audible loss vs `opus` |

YouTube usually serves opus 160k for popular tracks. `opus` keeps that as-is; `opus-compact` re-encodes 160k → 128k.

## how it picks the right version

When a track ends played-past-threshold, `played` asks YouTube for 10 candidates and scores each:

| weight | factor | what it rewards |
|---|---|---|
| 40% | duration match | within ±5s of Spotify's reported length |
| 25% | title match | clean artist + title; penalized ×0.5 for `remix`/`live`/`extended`/`demo` words not in the original |
| 25% | uploader trust | `Topic` channels (label auto-uploads) > VEVO > known labels > random uploaders |
| 7%  | popularity | view count, broad bands |
| 3%  | freshness | newer uploads slightly preferred |

If no candidate scores ≥ `SCORE_THRESHOLD` (default 70), nothing is saved — saving the wrong version is worse than not saving. After download, the file's actual duration is re-checked. If it's >`DURATION_TOLERANCE_SEC` off Spotify's, the file is deleted and the next candidate is tried.

Tune `SCORE_THRESHOLD` to taste: 60 is permissive (more saves, more wrong matches), 90 is strict (fewer saves, cleaner library).

## commands

| | |
|---|---|
| `played watch` | run the daemon (default; usually invoked via systemd) |
| `played download` | force-download the currently playing track |
| `played status` | daemon state, library count, current track |
| `played history` | list everything `played` has saved or skipped |
| `played history search QUERY` | search history by artist or title |
| `played config show` | print current effective config |
| `played config edit` | open config in `$EDITOR` |
| `played init` | first-run setup (creates config, dirs) |
| `played version` | print version |

## what's saved where

```
$MUSIC_DIR/
├── flume/
│   └── skin.opus
├── new_constellations/
│   └── hot_blooded.opus
…
```

History: `~/.local/state/played/history.tsv` — tab-separated, append-only:

```
spotify_uri	artist	title	timestamp	status	source	score	bitrate
```

`status` is one of: `ok`, `rejected` (no candidate met the bar), `no-candidates`, `failed`, `exists`, `diskfull`, `migrated`.

Logs: `~/.local/state/played/played.log`.

## what's filtered out

Skipped automatically:

- ads (`Spotify` artist + `Advertisement` title)
- podcasts (`spotify:episode:` URIs)
- tracks shorter than `MIN_DURATION_SEC`
- tracks longer than `MAX_DURATION_SEC`
- anything you didn't play past `THRESHOLD`%

## troubleshooting

**Nothing's downloading.** Run `played status`. If "now playing" is empty, your player isn't exposing MPRIS — check `playerctl --list-all`. If a player is listed but `played` doesn't see it, add its name to `PLAYERS=` in config.

**It saved the wrong version (live/remix/cover).** Raise `SCORE_THRESHOLD` toward 80–90. Delete the bad file and let it re-download next listen.

**Nothing saved for an obscure track.** YouTube didn't have a confident match. Lower `SCORE_THRESHOLD` (e.g. 60) to be more permissive at the cost of more wrong matches. Or set `DRY_RUN=1` and re-listen to see what scored what.

**yt-dlp errors / 403s / bot challenges.** YouTube periodically tightens its anti-bot. Update yt-dlp (`pipx upgrade yt-dlp` or your distro's package). If your IP is flagged, a residential VPN switch usually clears it.

**The systemd unit can't write to my custom MUSIC_DIR.** See [custom music dir](#custom-music-dir).

**It's running but no MPRIS event ever fires.** You may not have a D-Bus session bus. On most desktop sessions this is automatic; on headless boxes, run `systemctl --user start dbus.socket` and `loginctl enable-linger $USER`.

## why YouTube and not Spotify directly?

Spotify's audio is DRM-encrypted; capturing the stream requires bypassing DRM, which is illegal in most jurisdictions and against the terms of service. YouTube hosts the same recordings — often uploaded by the labels themselves on `- Topic` channels — at comparable bitrate. `played` matches Spotify's metadata against YouTube's catalog and grabs the closest version. No DRM bypass, no audio-stream capture.

## migrating from spotify-dl

If you used the precursor `spotify-dl` script, `played` auto-migrates `~/sync/music/.downloaded` into the new TSV format on first run. Existing files on disk are recognized regardless — you won't get duplicate downloads.

## legal

`played` downloads tracks the user actively listens to past a high threshold, sourced from YouTube via yt-dlp. Whether that's permitted depends on your jurisdiction and on YouTube's and Spotify's current terms of service. `played` does not bypass DRM and does not interact with Spotify's audio stream. You are responsible for using it within the law where you live.

## license

MIT
