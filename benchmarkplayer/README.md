# benchmark_player — frame-pacing A/B bench

Minimal Flutter app + scripts to answer one question with data: **why does
fvp/MDK pace frames badly on the TCL TV (bursts + 80–183 ms droughts) while
media_kit/mpv is smooth, on the same hardware and decoder?**

The app has no UI: dart-defines pick the backend, the clip URL, and the knob
under test, and it boots straight into fullscreen autoplay. A variant badge
shows for 15 s, then the UI never repaints again so SurfaceFlinger presents
track only the video.

## One-time setup

```bash
tools/make_clips.sh          # ffmpeg-generate reference clips into media/
```

## Test night

```bash
tools/serve.sh               # terminal 1: LAN clip server (leave running)
tools/run_bench.sh run       # terminal 2: the whole matrix, guided
```

`run_bench.sh` builds each variant APK (cached in `bench-results/apks/`),
installs it, waits for you to open **FVP Bench** on the TV, then captures
5 minutes of logcat + SurfaceFlinger present timestamps and writes
`bench-results/<date>/<variant>/` with `histogram.txt`, `pacing_raw.txt` +
`.csv`, `player.log` (mpv -v / full MDK log), `stats.txt`
(player-reported codec/hwdec/drop counters), `meta.txt`, `logcat.txt`.
It ends by generating `comparison.md` — the ticket-ready summary.

`tools/run_bench.sh build` pre-builds all APKs without touching the device.

## The variant matrix (each isolates one hypothesis)

| variant | what changes | if it paces smoothly, the cause is… |
|---|---|---|
| 01-media_kit-baseline | libmpv, defaults | (reference — expected smooth) |
| 02-fvp-default | MDK, defaults | (reference — expected bursty) |
| 03-fvp-copy | `AMediaCodec:copy=1` (CPU copy-back, like mpv's mediacodec-copy) | the zero-copy AImageReader buffer pipeline |
| 04-fvp-audiotrack | `audioBackends: ['AudioTrack']` (fork option) | AAudio's coarse position clock driving A/V sync |
| 05-fvp-noaudio | clip with no audio track | the audio clock entirely (MDK falls back to system clock) |
| 06-media_kit-noaudio (extra) | mpv, no-audio clip | control for 05 |
| 07-fvp-opensl (extra) | `audioBackends: ['OpenSL']` | alternative audio-clock test |

Interpretation is pre-committed:

- **03 smooth** → zero-copy pipeline. Fix = ship `copy=1` via `registerWith`
  options in the IPTV app (settings-only), and report upstream.
- **04/05/07 smooth** → audio clock. Fix = audio backend option
  (fork branch `bench/audio-backends-option`, PR-able) or an MDK clock
  interpolation report to wang-bin.
- **all fvp variants bursty** → MDK's render-loop timing itself. Outcome = a
  libmdk report with this data (mpv smooth baseline included) — libmdk is
  closed-source, so no PR is possible there.

## Dart-defines the app understands

| define | values | meaning |
|---|---|---|
| `BENCH_BACKEND` | `media_kit` (default) / `fvp` | player backend |
| `BENCH_URL` | url | clip to autoplay |
| `BENCH_VARIANT` | text | label in badge + `[BENCH_STATS]` lines |
| `FVP_DECODER_COPY` | `true` | MediaCodec copy-back mode |
| `FVP_AUDIO_BACKEND` | `AudioTrack` / `OpenSL` | force mdk audio renderer |
| `BENCH_BADGE_SECONDS` | int (15) | badge auto-hide; 0 = keep |

Notes: `EGL_SDR_DEPTH=8` is set in MainActivity (fvp#374 corruption
workaround, inert for media_kit). Impeller is disabled (Skia), matching the
IPTV app. The fvp dependency is pinned to fork branch
`bench/audio-backends-option` = upstream master + the `audioBackends`
registerWith option.
