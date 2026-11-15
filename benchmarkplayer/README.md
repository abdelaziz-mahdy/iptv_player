# benchmark_player — frame-pacing & live-stream A/B bench

Minimal Flutter app + scripts to answer with data: **why does fvp/MDK pace
frames badly on the TCL TV (bursts + 80–183 ms droughts) while
media_kit/mpv is smooth**, and **why does fvp starve on live streams** —
same hardware, same decoder.

The app has no controls: dart-defines pick the backend, the clip URL, and
the knob under test, and it boots straight into fullscreen autoplay. A
persistent color-coded HUD (green PLAYING / orange loading-buffering / red
stalled-error, with position and buffer state) shows the run is alive; it
refreshes at most once per 5 s stats tick, so the pacing measurement stays
clean. Logs are always on (mpv -v / full MDK), and a `[BENCH_STATS]` line
every 5 s reports position, codec, hwdec, drop counters, and buffer state
(`buffered-ahead` / `cache-dur` / `cache-speed` — the live-starvation
signals).

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
stats lines, captures DURATION (default 60s) of logcat + SurfaceFlinger present
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

## Player teardown repro (fvp#412)

Closing a player is where the TV froze (ANR in `mdkPlayerAPI_reset`). Two
modes exercise it in one process, logging how long each close held the main
thread (a 50 ms heartbeat, so a block anywhere in `dispose()` is caught; a
close that never logs is a freeze):

- `BENCH_CYCLES=N` (fvp, with `BENCH_VIEW=platform FVP_TUNNEL=true` for the
  IPTV app's path): open, play `BENCH_CYCLE_PLAY` s, remove the view, wait
  `BENCH_CYCLE_GAP_MS`, dispose. `BENCH_CYCLE_OVERLAP=true` opens the next
  player before disposing the previous one, like next/previous episode.
  Lines: `[BENCH_CYCLE] n=3 closed dispose=118ms main_held_max=99ms`.
- `BENCH_MODE=teardown`: `BENCH_TEARDOWN_PLAYERS` texture players per round,
  textures released, `BENCH_TEARDOWN_GAP_MS` later disposed
  (`lib/teardown_repro.dart`, after the emulator repro on fvp#412).
  `BENCH_URL` may list several comma-separated clips.

On an Android emulator with fvp 0.40.0: `BENCH_CYCLE_GAP_MS=0` crashes on the
first close (SIGSEGV in `surfaceDestroyed`), and teardown rounds hold the main
thread 0.9-2.7 s. Both are fixed by the pinned fork commit. The emulator
reaches the clip server as `http://10.0.2.2:8000/`.

## Dart-defines the app understands

| define | values | meaning |
|---|---|---|
| `BENCH_BACKEND` | `media_kit` (default) / `fvp` | player backend |
| `BENCH_URL` | url | clip/stream to autoplay |
| `BENCH_VARIANT` | text | label in badge + `[BENCH_STATS]` lines |
| `FVP_DECODER_COPY` | `true` | MediaCodec copy-back mode |
| `FVP_AUDIO_BACKEND` | `AudioTrack` / `OpenSL` | force mdk audio renderer |

Notes: `EGL_SDR_DEPTH=8` is set in MainActivity (fvp#374 corruption
workaround, inert for media_kit). Impeller is disabled (Skia), matching the
IPTV app. The fvp dependency is pinned to fork branch
`bench/audio-backends-option` = upstream master + the `audioBackends`
registerWith option.
