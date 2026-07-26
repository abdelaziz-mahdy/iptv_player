# features/player

## PlayerController abstraction (`video_controller.dart`)

Backend-agnostic interface. All backends implement:
`initialize(url)` / `play()` / `pause()` / `seek()` / `setVolume()` / `dispose()`
+ getters: `status` (Stream<PlayerStatus>), `position`, `duration`, `isPlaying`,
  `streamBadge` (resolution string, e.g. "1280×720"), `currentBitRate` (bits/sec or null).

`PlayerStatus` is an immutable `Equatable` snapshot emitted on every state change.

---

## Backend: fvp (MDK) behind `video_player`

One backend everywhere — `VideoPlayerControllerAdapter` (`video_controller.dart`),
built directly in the `/player` route. media_kit/libmpv was the Android player
until the decoder-to-SurfaceView path landed; it is gone (removed with its
`media_kit_libs_android_video` natives, which clashed with MDK's).

- Wraps `video_player` with fvp (MDK); registered once via `fvp.registerWith()`.
- On Android uses `VideoViewType.platformView` plus `'tunnel': true`:
  MediaCodec writes decoded frames straight into the SurfaceView's buffer
  queue — no GL renderer, no EGLConfig, no GPU copy. This is the only path
  that sustains 4K on the TV (24.0 fps at 4K24, 56.3 at 4K60, against ~22
  through GL and 10.9 through a Flutter texture). `maxWidth`/`maxHeight` are a
  GL-path clamp and do not apply.
- `'audio.renderer': 'OpenSL'` — MDK paces video off the audio clock, and this
  TV's AAudio reported positions too coarsely (frames burst at ~10 fps). Fixed
  upstream (fvp#384) but not in a released SDK, so the override stays.
- `'buffer': '2000+30000'` — 30 s of network buffer; the default 1 s/4 s
  starved on burst-serving IPTV providers.
- `initialize(startAt:)` seeks after init (video_player has no start option).

**Pinned to a fork** (`pubspec.yaml` `dependency_overrides`): the branch of
upstream PR wang-bin/fvp#379. Drop the override once it merges and ships.

**HDR caveat:** direct-to-surface output wedges the Realtek decoder on HDR
content (mdk-sdk#361 — h264 + PQ/BT.2020 VUI stalls, HEVC 10-bit HDR10 plays).
The PR branch has no HDR-to-GL fallback, so HDR titles stall until that is
fixed in MDK.

## `kFvpCaptureBuild` (`core/debug_flags.dart`)

The only debug flag left (`core/debug_flags.dart`), off in shipping builds:
- `FVP_CAPTURE=true` — root logging listener plus MDK `logLevel: all`, so the
  full MDK log reaches logcat for upstream reports.

---

## PlayerCubit (`cubit/player_cubit.dart`)

Manages playback state, controls visibility, and VOD progress persistence.

**Startup sequence:** `start()` → refuse an empty url → `initialize(url)` →
seek to resume pos → `play()` → enable wakelock → subscribe to `status` stream
→ start timers. A failure is classified into `PlaybackFailure`
(network/unavailable/refused/timeout/unknown), emitted to state and rendered as
a localized message with Retry — `start()` never throws.

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
- `_buildVideoSurface()` wraps `VideoPlayer` in an `AspectRatio` — the widget
  itself fills its constraints, and the parent Stack is `StackFit.expand`, so
  without it the picture is stretched to the panel shape. It rebuilds on
  controller value changes (live streams switch resolution mid-play).
- `WidgetsBindingObserver.didChangeAppLifecycleState` → calls `saveProgressNow()`.
- `HardwareKeyboard.instance.addHandler` — any key reveals controls / resets the
  idle timer. It also owns the first left/right press while no control has
  focus: that seeks ±10s and moves focus onto the scrubber, so the highlight
  sits on what is moving and later presses go to the scrubber's own handler.
  It must live here, not in a Focus handler — it runs before focus dispatch,
  and afterwards "were the controls hidden?" cannot be answered. Returns true
  only when it seeks.
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
