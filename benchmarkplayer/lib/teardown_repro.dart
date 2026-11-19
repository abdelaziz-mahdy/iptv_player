import 'dart:async';

import 'package:fvp/mdk.dart' as mdk;

/// fvp#412: players torn down the way fvp's `dispose()` does it — texture
/// released first, then the player deleted — with the gap between the two
/// held open while the players keep playing. Each round logs how long the
/// main isolate was held; a round that never logs is the freeze (an ANR in
/// `mdkPlayerAPI_reset` on Android, where Dart runs on the main thread).
///
/// Adapted from the emulator repro posted on fvp#412, with HTTP clips in
/// place of RTSP cameras.
Future<void> runTeardownRepro({
  required List<String> urls,
  required int rounds,
  required int players,
  required int gapMs,
  required String decoder,
}) async {
  var last = DateTime.now();
  var maxLag = 0;
  Timer.periodic(const Duration(milliseconds: 50), (_) {
    final now = DateTime.now();
    final lag = now.difference(last).inMilliseconds - 50;
    if (lag > maxLag) maxLag = lag;
    last = now;
  });
  Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));
  void log(String s) => print('[BENCH_TEARDOWN] $s'); // ignore: avoid_print

  final held = <int>[];
  for (var round = 1; round <= rounds; round++) {
    final open = <mdk.Player>[];
    final firstFrames = <Future<void>>[];
    for (var i = 0; i < players; i++) {
      final player = mdk.Player();
      player.setBufferRange(min: 0, max: 1000, drop: true);
      player.videoDecoders = [decoder, 'FFmpeg'];
      final first = Completer<void>();
      player.onEvent.listen((e) {
        if (e.category == 'render.video' &&
            e.detail == '1st_frame' &&
            !first.isCompleted) {
          first.complete();
        }
      });
      player.media = urls[i % urls.length];
      firstFrames.add(first.future);
      open.add(player);
    }
    try {
      for (final player in open) {
        await player.prepare().timeout(const Duration(seconds: 15));
        await player.updateTexture().timeout(const Duration(seconds: 10));
        player.volume = 0;
        player.state = mdk.PlaybackState.playing;
      }
      await Future.wait(firstFrames).timeout(const Duration(seconds: 20));
    } catch (e) {
      log('round $round open failed: $e');
    }
    await wait(1500);
    // What fvp's dispose() does first: the texture goes, the player plays on.
    await Future.wait([for (final p in open) p.updateTexture(width: -1)]);
    await wait(gapMs);
    maxLag = 0;
    for (final p in open) {
      p.dispose();
    }
    await wait(1500);
    held.add(maxLag);
    log('round $round: main isolate held ${maxLag}ms after dispose');
  }
  held.sort();
  log(
    'done rounds=$rounds players=$players decoder=$decoder gap=${gapMs}ms '
    'held_ms_sorted=$held',
  );
}
