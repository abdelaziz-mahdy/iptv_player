/// Compile-time debug flags, set via `--dart-define`.
///
/// These are **off in every shipping build** — they only flip on when a build
/// passes the matching `--dart-define`, so release/CI artifacts are unaffected.
library;

/// Turns on full MDK (fvp) log forwarding to logcat.
///
/// Built for the fvp#374 PowerVR-corruption investigation and kept for future
/// player diagnostics. fvp already calls `setGlobalOption("log", "all")`, but
/// it routes those lines through `package:logging`'s `Logger`, which has no
/// listener by default — so every MDK line is dropped before it reaches
/// logcat. This flag makes `main()` attach a root listener so the logs
/// actually surface.
///
/// Enable with: `flutter build apk --release --dart-define=FVP_CAPTURE=true`
const bool kFvpCaptureBuild = bool.fromEnvironment('FVP_CAPTURE');


/// MDK audio backend ("OpenSL", "AudioTrack", "AAudio"). Empty = MDK's own
/// default, which is what ships.
///
/// OpenSL was forced for a while because this TV's AAudio reported positions
/// too coarsely and video presented in bursts (fvp#384, fixed upstream). It
/// then turned out to zero the audio clock on live streams whose timestamps
/// start far from zero: video is paced against that clock, so frames are hours
/// in the future and the picture freezes while sound plays. Measured over 5
/// starts per backend, only OpenSL did this (3/5); AAudio, AudioTrack and the
/// default were correct every time.
///
/// Override with: `--dart-define=AUDIO_RENDERER=OpenSL`
const String kAudioRenderer = String.fromEnvironment('AUDIO_RENDERER');
