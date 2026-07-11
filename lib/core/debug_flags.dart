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
