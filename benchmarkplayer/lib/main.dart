import 'dart:async';

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

/// Human label for this run, shown in the on-screen HUD and in every
/// [BENCH_STATS] log line, so captures are self-documenting.
const kVariant =
    String.fromEnvironment('BENCH_VARIANT', defaultValue: 'unnamed');

/// fvp: use MediaCodec in copy-back mode (CPU copy like mpv's
/// mediacodec-copy) instead of the default zero-copy AImageReader path.
const kFvpDecoderCopy = bool.fromEnvironment('FVP_DECODER_COPY');

/// fvp: force an audio renderer ('AudioTrack' or 'OpenSL'); empty = mdk default.
const kFvpAudioBackend = String.fromEnvironment('FVP_AUDIO_BACKEND');

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
  String _error = '';

  // Status HUD: refreshed at most once per 5s stats tick (plus state
  // changes), so it adds ~1 UI repaint per 5s — visible liveness without
  // polluting the pacing measurement on the texture path.
  String _hudState = 'starting';
  String _hudDetail = '';
  Duration _lastPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (kUrl.isEmpty) {
      _error = 'BENCH_URL dart-define is not set';
      _hudState = 'ERROR';
      return;
    }
    if (kBackend == 'fvp') {
      _initFvp();
    } else {
      _initMediaKit();
    }
    _statsTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _logStats());
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
      _updateHud('ERROR', e.toString());
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
      _updateHud('ERROR', '$e');
      return;
    }
    if (mounted) setState(() {});
  }

  void _updateHud(String state, String detail) {
    if (!mounted) return;
    if (state == _hudState && detail == _hudDetail) return;
    setState(() {
      _hudState = state;
      _hudDetail = detail;
    });
  }

  Future<void> _logStats() async {
    try {
      if (kBackend == 'fvp') {
        final c = _fvpController;
        if (c == null || !c.value.isInitialized) {
          _updateHud('LOADING', '');
          return;
        }
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
        final advancing = v.position > _lastPos;
        _lastPos = v.position;
        _updateHud(
          v.isBuffering
              ? 'BUFFERING'
              : advancing
                  ? 'PLAYING'
                  : 'STALLED',
          '${_fmt(v.position)}  ${v.size.width.toInt()}x${v.size.height.toInt()}  '
          'ahead ${(ahead / 1000).toStringAsFixed(1)}s',
        );
      } else {
        final p = _mkPlayer;
        if (p == null) {
          _updateHud('LOADING', '');
          return;
        }
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
        final advancing = s.position > _lastPos;
        _lastPos = s.position;
        _updateHud(
          s.buffering
              ? 'BUFFERING'
              : advancing
                  ? 'PLAYING'
                  : 'STALLED',
          '${_fmt(s.position)}  ${s.width ?? 0}x${s.height ?? 0}  '
          'hwdec $hwdec  drops $drops  cache ${double.tryParse(cacheDur)?.toStringAsFixed(1) ?? cacheDur}s',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[BENCH_STATS] error: $e');
    }
  }

  Color _stateColor() {
    switch (_hudState) {
      case 'PLAYING':
        return Colors.greenAccent;
      case 'ERROR':
      case 'STALLED':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
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
          Positioned(
            left: 24,
            top: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                border: Border(
                  left: BorderSide(width: 6, color: _stateColor()),
                ),
              ),
              child: Text(
                '$kVariant · $kBackend'
                '${kFvpDecoderCopy ? ' · copy=1' : ''}'
                '${kFvpAudioBackend.isNotEmpty ? ' · $kFvpAudioBackend' : ''}\n'
                '$_hudState  $_hudDetail',
                style: TextStyle(fontSize: 20, color: _stateColor()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
