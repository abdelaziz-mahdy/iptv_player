# features/player

## PlayerController abstraction (`video_controller.dart`)

Backend-agnostic interface. All backends implement:
`initialize(url)` / `play()` / `pause()` / `seek()` / `setVolume()` / `dispose()`
+ getters: `status` (Stream<PlayerStatus>), `position`, `duration`, `isPlaying`,
  `streamBadge` (resolution string, e.g. "1280×720"), `currentBitRate` (bits/sec or null).

`PlayerStatus` is an immutable `Equatable` snapshot emitted on every state change.

---

## Two backends — chosen at route time in `core/router/app_router.dart`

```dart
controller: (Platform.isAndroid && !kFvpCaptureBuild)
    ? MediaKitPlayerController()
    : VideoPlayerControllerAdapter(),
```

### Android: `MediaKitPlayerController` (`media_kit_controller.dart`)
- Wraps `media_kit` / libmpv with `vo_gpu` renderer.
- Opens media with `play: false`; `PlayerCubit.start()` does the seek-then-play.
- Volume is 0–100 (media_kit scale); the adapter divides by 100.
- `currentBitRate` returns `null` — media_kit does not expose real-time bitrate.
- Video surface: `Video(controller: c.videoController, controls: NoVideoControls)`.

### Desktop (macOS/Windows/Linux): `VideoPlayerControllerAdapter` (`video_controller.dart`)
- Wraps `video_player` with `fvp` (MDK) as the backend; registered once via `fvp.registerWith()`.
- `currentBitRate` from `_controller.getMediaInfo()?.bitRate` (fvp extension, updated live).
- `streamBadge` falls back to `VideoPlayerValue.size` when bitrate is 0.
- Video surface: `VideoPlayer(c.nativeController)` (requires `c.isInitialized` guard).

### WHY two backends
fvp/MDK's GL texture renderer **corrupts video on PowerVR TV GPUs** (every decoder,
including software). media_kit's `vo_gpu` renders correctly on the same device.
Desktop keeps fvp where it works fine. Upstream bug: wang-bin/fvp#374.

---

## `kFvpCaptureBuild` (`core/debug_flags.dart`)

`--dart-define=FVP_CAPTURE=true` forces fvp on Android + attaches a root logging
listener so MDK logs reach logcat. **Diagnostic/reproduction builds only.**
Also suppresses `MediaKit.ensureInitialized()` in `main.dart` on Android.

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
