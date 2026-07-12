import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

/// Which backend renders the clip: 'media_kit' (libmpv) or 'fvp' (MDK).
const kBackend =
    String.fromEnvironment('BENCH_BACKEND', defaultValue: 'media_kit');

/// Clip URL; playback starts automatically on launch.
const kUrl = String.fromEnvironment('BENCH_URL');

/// Human label for this run, shown in the on-screen badge and in every
/// [BENCH_STATS] log line, so captures are self-documenting.
const kVariant =
    String.fromEnvironment('BENCH_VARIANT', defaultValue: 'unnamed');

/// fvp: use MediaCodec in copy-back mode (CPU copy like mpv's
/// mediacodec-copy) instead of the default zero-copy AImageReader path.
const kFvpDecoderCopy = bool.fromEnvironment('FVP_DECODER_COPY');

/// fvp: force an audio renderer ('AudioTrack' or 'OpenSL'); empty = mdk default.
const kFvpAudioBackend = String.fromEnvironment('FVP_AUDIO_BACKEND');

/// Seconds the variant badge stays on screen. After it hides the UI never
/// repaints again, so window presents track only the video texture
/// (matters for SurfaceFlinger-based pacing measurement). 0 = always on.
const kBadgeSeconds =
    int.fromEnvironment('BENCH_BADGE_SECONDS', defaultValue: 15);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print('[BENCH_META] variant=$kVariant backend=$kBackend url=$kUrl '
      'fvpCopy=$kFvpDecoderCopy fvpAudio=${kFvpAudioBackend.isEmpty ? '-' : kFvpAudioBackend}');
  if (kBackend == 'fvp') {
    // MDK logs arrive via package:logging; print() to avoid debugPrint throttling.
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((r) {
      // ignore: avoid_print
      print('[mdk] [${r.loggerName}] ${r.level.name}: ${r.message}');
    });
    fvp.registerWith(options: {
      'global': {'logLevel': 'all'},
      if (kFvpDecoderCopy) 'video.decoders': ['AMediaCodec:copy=1', 'FFmpeg'],
      if (kFvpAudioBackend.isNotEmpty) 'audioBackends': [kFvpAudioBackend],
    });
  } else {
    MediaKit.ensureInitialized();
  }
  runApp(const BenchApp());
}

class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BenchScreen(),
    );
  }
}

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  // media_kit
  Player? _mkPlayer;
  VideoController? _mkController;

  // fvp
  VideoPlayerController? _fvpController;

  Timer? _statsTimer;
  Timer? _badgeTimer;
  bool _showBadge = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (kUrl.isEmpty) {
      _error = 'BENCH_URL dart-define is not set';
      return;
    }
    if (kBackend == 'fvp') {
      _initFvp();
    } else {
      _initMediaKit();
    }
    _statsTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _logStats());
    if (kBadgeSeconds > 0) {
      _badgeTimer = Timer(Duration(seconds: kBadgeSeconds), () {
        if (mounted) setState(() => _showBadge = false);
      });
    }
  }

  Future<void> _initMediaKit() async {
    final player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.v),
    );
    player.stream.log.listen((l) {
      // ignore: avoid_print
      print('[mpv] [${l.prefix}] ${l.level}: ${l.text}');
    });
    player.stream.error.listen((e) {
      // ignore: avoid_print
      print('[BENCH_ERROR] $e');
    });
    _mkPlayer = player;
    _mkController = VideoController(player);
    setState(() {});
    await player.open(Media(kUrl), play: true);
    await player.setPlaylistMode(PlaylistMode.loop);
  }

  Future<void> _initFvp() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(kUrl));
    _fvpController = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
    } catch (e) {
      // ignore: avoid_print
      print('[BENCH_ERROR] $e');
      if (mounted) setState(() => _error = '$e');
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _logStats() async {
    try {
      if (kBackend == 'fvp') {
        final c = _fvpController;
        if (c == null || !c.value.isInitialized) return;
        final info = c.getMediaInfo();
        final v = c.value;
        final video = info?.video?.firstOrNull;
        final audio = info?.audio?.firstOrNull;
        // Buffered media ahead of the playhead — the live-stream starvation
        // signal (fvp "network speed dies" symptom).
        final bufEnd = v.buffered.isEmpty ? v.position : v.buffered.last.end;
        final ahead = (bufEnd - v.position).inMilliseconds;
        // ignore: avoid_print
        print('[BENCH_STATS] variant=$kVariant backend=fvp '
            'pos=${v.position.inMilliseconds}ms '
            'size=${v.size.width.toInt()}x${v.size.height.toInt()} '
            'buffered-ahead=${ahead}ms buffering=${v.isBuffering} '
            'bitrate=${info?.bitRate} video=${video?.codec.codec} '
            'fps=${video?.codec.frameRate} audio=${audio?.codec.codec}');
      } else {
        final p = _mkPlayer;
        if (p == null) return;
        final native = p.platform;
        String drops = '?', voDelayed = '?', hwdec = '?', vfFps = '?';
        String cacheDur = '?', cacheSpeed = '?';
        if (native is NativePlayer) {
          Future<String> prop(String name) async {
            try {
              return await native.getProperty(name);
            } catch (_) {
              return '?';
            }
          }

          drops = await prop('frame-drop-count');
          voDelayed = await prop('vo-delayed-frame-count');
          hwdec = await prop('hwdec-current');
          vfFps = await prop('estimated-vf-fps');
          // Live-stream starvation signals: seconds buffered in the demuxer
          // and current network read speed (bytes/s).
          cacheDur = await prop('demuxer-cache-duration');
          cacheSpeed = await prop('cache-speed');
        }
        final s = p.state;
        // ignore: avoid_print
        print('[BENCH_STATS] variant=$kVariant backend=media_kit '
            'pos=${s.position.inMilliseconds}ms size=${s.width}x${s.height} '
            'buffering=${s.buffering} framedrops=$drops vo-delayed=$voDelayed '
            'hwdec=$hwdec est-vf-fps=$vfFps cache-dur=${cacheDur}s '
            'cache-speed=$cacheSpeed');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[BENCH_STATS] error: $e');
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _badgeTimer?.cancel();
    _mkPlayer?.dispose();
    _fvpController?.dispose();
    super.dispose();
  }

  Widget _video() {
    if (_error.isNotEmpty) {
      return Text(_error,
          style: const TextStyle(color: Colors.red, fontSize: 24));
    }
    if (kBackend == 'fvp') {
      final c = _fvpController;
      if (c == null || !c.value.isInitialized) {
        return const CircularProgressIndicator();
      }
      return AspectRatio(
          aspectRatio: c.value.aspectRatio, child: VideoPlayer(c));
    }
    final mk = _mkController;
    if (mk == null) return const CircularProgressIndicator();
    return Video(controller: mk, controls: NoVideoControls, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _video()),
          if (_showBadge)
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.black.withValues(alpha: 0.7),
                child: Text(
                  '$kVariant\n$kBackend'
                  '${kFvpDecoderCopy ? ' · copy=1' : ''}'
                  '${kFvpAudioBackend.isNotEmpty ? ' · $kFvpAudioBackend' : ''}\n'
                  '${Platform.operatingSystem} · badge hides in ${kBadgeSeconds}s',
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
