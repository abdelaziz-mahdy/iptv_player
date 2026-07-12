# benchmark_player — frame-pacing & live-stream A/B bench

Minimal Flutter app + scripts to answer with data: **why does fvp/MDK pace
frames badly on the TCL TV (bursts + 80–183 ms droughts) while
media_kit/mpv is smooth**, and **why does fvp starve on live streams** —
same hardware, same decoder.

The app has no UI: dart-defines pick the backend, the clip URL, and the knob
under test, and it boots straight into fullscreen autoplay. A variant badge
shows for 15 s, then the UI never repaints again so SurfaceFlinger presents
track only the video. Logs are always on (mpv -v / full MDK), and a
`[BENCH_STATS]` line every 5 s reports position, codec, hwdec, drop
counters, and buffer state (`buffered-ahead` / `cache-dur` / `cache-speed`
— the live-starvation signals).

## One-time setup

```bash
tools/make_clips.sh          # ffmpeg-generate reference clips into media/
```

## Test run (fully unattended)

```bash
tools/serve.sh               # terminal 1: LAN clip server (leave running)
tools/make_live.sh           # terminal 2: simulated live HLS (leave running)
tools/run_bench.sh run       # terminal 3: the whole matrix
```

Per variant, `run_bench.sh` builds the APK (cached in `bench-results/apks/`,
auto-invalidated if the server URL changes), installs it, **launches the app
itself** (`am start`), confirms playback is advancing from the app's own
stats lines, captures 5 minutes of logcat + SurfaceFlinger present
timestamps, force-stops the app, and writes
`bench-results/<date>/<variant>/`: `histogram.txt`, `pacing_raw.txt` + `.csv`,
`player.log`, `stats.txt`, `egl_probe.txt`, `meta.txt`, `logcat.txt`.
It ends by generating `comparison.md` — the ticket-ready summary.

`tools/run_bench.sh build` pre-builds all APKs without touching the device.

## The variant matrix (each isolates one hypothesis)

| variant | what changes | if it behaves well, the cause is… |
|---|---|---|
| 01-media_kit-baseline | libmpv, defaults | (reference — expected smooth) |
| 02-fvp-default | MDK, defaults | (reference — expected bursty) |
| 03-fvp-copy | `AMediaCodec:copy=1` (CPU copy-back, like mpv's mediacodec-copy) | the zero-copy AImageReader buffer pipeline |
| 04-fvp-audiotrack | `audioBackends: ['AudioTrack']` (fork option) | AAudio's coarse position clock driving A/V sync |
| 05-fvp-noaudio | clip with no audio track | the audio clock entirely (MDK falls back to system clock) |
| 06-media_kit-live | simulated live HLS (rolling playlist, realtime) | (live reference) |
| 07-fvp-live | same live stream through MDK | fvp's live buffering — watch `buffered-ahead`/`bitrate` decay |
| 08-media_kit-noaudio (extra) | mpv, no-audio clip | control for 05 |
| 09-fvp-opensl (extra) | `audioBackends: ['OpenSL']` | alternative audio-clock test |

Live variants use the local simulated stream by default; `export
LIVE_URL=...` to bench a real provider channel instead (the URL — including
credentials — is baked into that APK; keep it local, don't share it).

Interpretation is pre-committed:

- **03 smooth** → zero-copy pipeline. Fix = ship `copy=1` via `registerWith`
  options in the IPTV app (settings-only), and report upstream.
- **04/05/09 smooth** → audio clock. Fix = audio backend option
  (fork branch `bench/audio-backends-option`, PR-able) or an MDK clock
  interpolation report to wang-bin.
- **all fvp variants bursty** → MDK's render-loop timing itself. Outcome = a
  libmdk report with this data (mpv smooth baseline included) — libmdk is
  closed-source, so no PR is possible there.
- **07 starves while 06 doesn't** (buffered-ahead → 0, bitrate decay) → MDK
  demuxer/network layer on live HLS; separate report with both stats series.

## EGL config probe (fvp#374 follow-up, independent of pacing)

`MainActivity` runs a one-shot `[EGL_PROBE]` at startup — the experiment
wang-bin requested on #374: dump every 1010102/8888 window EGLConfig with
its `EGL_CONFIG_CAVEAT`/`EGL_CONFORMANT` flags, then run his exact
`eglChooseConfig` with `CAVEAT=EGL_NONE` (and a second pass adding
`CONFORMANT=ES2|ES3`). If **0 configs match**, the driver self-reports its
10-bit configs as broken → libmdk can pin the caveat and fix #374 upstream
without losing HDR elsewhere. If configs match (and rendering still
corrupts), caveat filtering is not the discriminator. Every variant's
`egl_probe.txt` carries the answer.

## Dart-defines the app understands

| define | values | meaning |
|---|---|---|
| `BENCH_BACKEND` | `media_kit` (default) / `fvp` | player backend |
| `BENCH_URL` | url | clip/stream to autoplay |
| `BENCH_VARIANT` | text | label in badge + `[BENCH_STATS]` lines |
| `FVP_DECODER_COPY` | `true` | MediaCodec copy-back mode |
| `FVP_AUDIO_BACKEND` | `AudioTrack` / `OpenSL` | force mdk audio renderer |
| `BENCH_BADGE_SECONDS` | int (15) | badge auto-hide; 0 = keep |

Notes: `EGL_SDR_DEPTH=8` is set in MainActivity (fvp#374 corruption
workaround, inert for media_kit). Impeller is disabled (Skia), matching the
IPTV app. The fvp dependency is pinned to fork branch
`bench/audio-backends-option` = upstream master + the `audioBackends`
registerWith option.
