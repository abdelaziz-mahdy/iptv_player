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

/// MDK audio backend on Android ("AudioTrack", "AAudio", "OpenSL").
///
/// AudioTrack ships. MDK's default, AAudio, opens a low-latency stream on a
/// shared hardware endpoint. When the TV re-handshakes eARC, that endpoint
/// goes dead, and a player whose teardown hangs in the decoder (fvp#412) keeps
/// it alive. Every later stream at the same sample rate joins it and stays
/// silent, because MDK never reopens a disconnected stream (fvp#386). The
/// system reroutes AudioTrack itself and never shares an endpoint.
///
/// OpenSL zeroes the audio clock on live streams whose timestamps start far
/// from zero (3/5 starts), freezing the picture while sound plays.
///
/// Override with: `--dart-define=AUDIO_RENDERER=AAudio`
const String kAudioRenderer = String.fromEnvironment(
  'AUDIO_RENDERER',
  defaultValue: 'AudioTrack',
);
