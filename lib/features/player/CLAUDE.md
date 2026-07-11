# features/player

## PlayerController abstraction (`video_controller.dart`)

Backend-agnostic interface. All backends implement:
`initialize(url)` / `play()` / `pause()` / `seek()` / `setVolume()` / `dispose()`
+ getters: `status` (Stream<PlayerStatus>), `position`, `duration`, `isPlaying`,
  `streamBadge` (resolution string, e.g. "1280×720"), `currentBitRate` (bits/sec or null).

`PlayerStatus` is an immutable `Equatable` snapshot emitted on every state change.

---

## Backends: media_kit on Android, fvp on desktop

Chosen at route time in `core/router/app_router.dart`:

```dart
controller: (Platform.isAndroid && !kForceFvpVideo)
    ? MediaKitPlayerController()   // mpv vo_gpu — smooth pacing on TV GPUs
    : VideoPlayerControllerAdapter() // fvp/MDK — desktop (+ FORCE_FVP A/B)
```

### Android: `MediaKitPlayerController` (`media_kit_controller.dart`)
- Wraps media_kit / libmpv (`vo_gpu`). Opens with `play: false`.
- **Resume** is passed as `initialize(url, startAt:)` → `Media(start:)` — mpv
  applies it at load. A seek command right after open is silently dropped by
  mpv (media-kit/media-kit#1215); early scrubber seeks are parked and applied
  once the duration arrives.
- Video surface: `Video(controller: c.videoController, controls: NoVideoControls)`.

### Desktop (+ FORCE_FVP): `VideoPlayerControllerAdapter` (`video_controller.dart`)
- Wraps `video_player` with fvp (MDK); registered once via `fvp.registerWith()`
  (Android options: `maxWidth/maxHeight` 1920×1088 cap).
- On Android uses `VideoViewType.platformView` (SurfaceView from the pinned
  fvp fork — own display layer, prerequisite for tunneled true-4K).
- `initialize(startAt:)` seeks after init (video_player has no start option).

### WHY media_kit on Android
fvp/MDK **paces frames badly on this TV** through BOTH the texture path and
the SurfaceView platform view: frames present in 60 Hz bursts separated by
80–183 ms droughts while decode/network/CPU are all healthy (measured via
SurfaceFlinger timestamps; matches upstream fvp#134, where media_kit and
video_player are smooth through the same Flutter texture). mpv's VO thread
paces against a smoothed clock with vsync feedback; MDK appears to schedule
off raw timers. fvp also needed the 8-bit EGLConfig workaround on PowerVR
(fvp#374, `EGL_SDR_DEPTH=8` in MainActivity — kept for FORCE_FVP builds).
Upstream fvp work continues: PR #379 (SurfaceView platform view), PR #380
(10-bit driver probe, draft), tunnel-at-open ordering (needs libmdk).

---

## `kFvpCaptureBuild` (`core/debug_flags.dart`)

Debug flags (`core/debug_flags.dart`), all off in shipping builds:
- `FVP_CAPTURE=true` — root logging listener so MDK's `log=all` reaches logcat.
- `MPV_LOG_CAPTURE=true` — verbose mpv log → logcat (media_kit backend).
- `FORCE_FVP=true` — Android uses fvp instead of media_kit (A/B testing).

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
