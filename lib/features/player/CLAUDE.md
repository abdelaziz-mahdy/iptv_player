# features/player

## PlayerController abstraction (`video_controller.dart`)

Backend-agnostic interface. All backends implement:
`initialize(url)` / `play()` / `pause()` / `seek()` / `setVolume()` / `dispose()`
+ getters: `status` (Stream<PlayerStatus>), `position`, `duration`, `isPlaying`,
  `streamBadge` (resolution string, e.g. "1280×720"), `currentBitRate` (bits/sec or null).

`PlayerStatus` is an immutable `Equatable` snapshot emitted on every state change.

---

## One backend: fvp on every platform

`VideoPlayerControllerAdapter` (`video_controller.dart`) on Android + desktop:
- Wraps `video_player` with `fvp` (MDK) as the backend; registered once via `fvp.registerWith()`.
- `currentBitRate` from `_controller.getMediaInfo()?.bitRate` (fvp extension, updated live).
- `streamBadge` falls back to `VideoPlayerValue.size` when bitrate is 0.
- Video surface: `VideoPlayer(c.nativeController)` (requires `c.isInitialized` guard).

### GOTCHA — PowerVR TV GPUs need an 8-bit EGLConfig (fvp#374)
MDK defaults to a **10-bit (RGBA_1010102) window surface** even for 8-bit SDR
content. The PowerVR BXE driver (TCL TVs, RTD2875P) cannot share those buffers
consistently across GL contexts (`IMGSRV: IsTextureConsistent` errors →
corrupted video on ALL decoders, hardware and software).
**Fix:** `MainActivity.onCreate()` sets `Os.setenv("EGL_SDR_DEPTH", "8", true)`
before the Flutter engine loads libmdk. Do not remove until fvp/mdk handle this
upstream (wang-bin/fvp#374).

media_kit (libmpv) was the Android backend until 2026-07; it was removed once
this fix landed — mpv never hits the bug because it takes the driver's first
≥8-bit EGLConfig (RGBA_8888). If fvp ever regresses, media_kit + 
media_kit_libs_android_video is the known-good fallback (note: its Android
natives clash with fvp's bundled FFmpeg — don't ship both).

---

## `kFvpCaptureBuild` (`core/debug_flags.dart`)

`--dart-define=FVP_CAPTURE=true` attaches a root logging listener so MDK's
`log=all` output reaches logcat. **Diagnostic builds only.**

---

## PlayerCubit (`cubit/player_cubit.dart`)

Manages playback state, controls visibility, and VOD progress persistence.

**Startup sequence:** `start()` → `initialize(url)` → seek to resume pos → `play()` →
enable wakelock → subscribe to `status` stream → start timers.

**Timers running during playback:**
- `_bitrateTimer` (2 s): polls `currentBitRate` / `streamBadge` → updates badge.
- `_controlsTimer` (4 s idle): auto-hides controls while playing; resets on any interaction.
- `_progressTimer` (10 s): periodic VOD progress checkpoint (`progressSaveInterval`).

**VOD progress saving — GOTCHA on TV:**
Saved every 10 s via `_tickSaveProgress()` AND immediately when the app is
backgrounded via `saveProgressNow()` (called by `player_screen.dart`'s
`WidgetsBindingObserver` on `paused`/`inactive`/`hidden`). Also saved in `close()`.
**Do not rely on `close()` alone** — TV apps are killed without a clean dispose.
Guard: `_saveProgress` skips when `position <= Duration.zero` (covers the periodic
tick, backgrounding, AND close) to avoid clobbering an existing resume point when
the user backs out during initial buffering.
Live channels (`isLive = kind == MediaKind.channel`) are **never** saved.
Watched rule: at ≥ 95% (`kWatchedFraction`, `WatchProgressX.isWatched`) an item is
"finished" — `start()` skips the resume seek (replays from zero) and
`continueWatching` filters it out; the row is kept for episode indicators.

**Stream badge logic (`computeStreamBadge`):**
Priority: bitrate (Mbps/Kbps) > resolution string > null (badge hidden).

---

## PlayerScreen (`player_screen.dart`)

- Accepts `PlayerController` and `PlaybackRepository` directly (no DI) — tests
  can inject fakes without a service locator.
- `_buildVideoSurface()` runtime-branches on controller type (no interface method for surface).
- `WidgetsBindingObserver.didChangeAppLifecycleState` → calls `saveProgressNow()`.
- `HardwareKeyboard.instance.addHandler` — any key reveals controls / resets idle timer;
  handler always returns `false` (never consumes the event).
- Controls use `_hideable()` = `AnimatedOpacity` + `IgnorePointer` + `ExcludeFocus`
  so hidden controls are fully invisible and unreachable by D-pad focus.
- Focus management: `_rootFocus` holds focus while controls are hidden; on reveal,
  focus is moved to `_playPauseFocus` (play/pause button) via `addPostFrameCallback`.
- Live channels show a red `_LivePill`; skip buttons and scrubber are VOD-only.
- `WakelockPlus` enabled on `start()`, disabled in `close()`.

---

## Test hooks (used in `test/features/player/`)

- `PlayerCubit.saveProgressNow()` — force a progress save without waiting on timer.
- `PlayerCubit.hideControlsForTesting()` — hides controls immediately (skips idle timer).
- `PlayerCubit.pollBitrateBadgeForTesting()` — drives one `_tickBitrate()` tick.
