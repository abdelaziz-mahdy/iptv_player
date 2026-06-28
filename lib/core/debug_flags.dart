/// Compile-time debug flags, set via `--dart-define`.
///
/// These are **off in every shipping build** — they only flip on when a build
/// passes the matching `--dart-define`, so release/CI artifacts are unaffected.
library;

/// Forces the Android video path onto **fvp** (instead of the default
/// `media_kit`) and turns on full MDK log forwarding to logcat.
///
/// Built only to reproduce the fvp/MDK PowerVR corruption for the upstream
/// report (wang-bin/fvp#374) and capture the *complete* MDK log the maintainer
/// needs. fvp already calls `setGlobalOption("log", "all")`, but it routes
/// those lines through `package:logging`'s `Logger`, which has no listener by
/// default — so every MDK line is dropped before it reaches logcat. This flag
/// makes `main()` attach a root listener so the logs actually surface.
///
/// Enable with: `flutter build apk --release --dart-define=FVP_CAPTURE=true`
const bool kFvpCaptureBuild = bool.fromEnvironment('FVP_CAPTURE');
