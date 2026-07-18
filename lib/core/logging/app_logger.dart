import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Global app logger (talker). Console output reaches logcat immediately;
/// [initAppLogging] additionally attaches a rolling file sink in the app's
/// EXTERNAL storage dir so logs survive logcat's buffer rotation and can be
/// pulled from the TV days later without root:
///
///   adb pull /sdcard/Android/data/com.iptvplayer/files/logs
///
/// (`scripts/pull_logs.sh` wraps that.) Events logged before init are
/// buffered and flushed once the sink opens. In tests nothing is written —
/// [initAppLogging] simply isn't called.
final Talker appLog = TalkerFlutter.init(observer: _fileObserver);

final _FileLogObserver _fileObserver = _FileLogObserver();

/// Never log credentials: Xtream URLs embed user/pass in the path
/// (`/movie/<user>/<pass>/<id>`) and sometimes as query params.
String scrubUrl(String url) => url
    .replaceAllMapped(
      RegExp(r'(/(?:live|movie|series))/[^/]+/[^/]+/'),
      (m) => '${m[1]}/****/****/',
    )
    .replaceAllMapped(
      RegExp(r'(username|password)=[^&\s]+'),
      (m) => '${m[1]}=****',
    );

/// Opens the file sink, prunes logs older than [keepDays], and flushes any
/// buffered early events. Call once from `main()`; safe to skip in tests.
Future<void> initAppLogging({int keepDays = 7}) => _fileObserver.open(keepDays);

class _FileLogObserver extends TalkerObserver {
  IOSink? _sink;
  final List<String> _buffer = [];
  static const _bufferCap = 200;

  Future<void> open(int keepDays) async {
    try {
      Directory base;
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory() ??
            await getApplicationSupportDirectory();
      } else {
        base = await getApplicationSupportDirectory();
      }
      final dir = Directory('${base.path}/logs');
      await dir.create(recursive: true);

      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      await for (final f in dir.list()) {
        if (f is File && (await f.stat()).modified.isBefore(cutoff)) {
          await f.delete().catchError((_) => f);
        }
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      _sink = File('${dir.path}/app-$today.log')
          .openWrite(mode: FileMode.append);
      for (final line in _buffer) {
        _sink!.writeln(line);
      }
      _buffer.clear();
    } catch (_) {
      // Logging must never break the app; console output still works.
    }
  }

  void _write(TalkerData data) {
    // Defense in depth: scrub the whole line even if a call site forgot.
    final line = scrubUrl(data.generateTextMessage());
    final sink = _sink;
    if (sink != null) {
      sink.writeln(line);
    } else if (_buffer.length < _bufferCap) {
      _buffer.add(line);
    }
  }

  @override
  void onLog(TalkerData log) => _write(log);

  @override
  void onError(TalkerError err) => _write(err);

  @override
  void onException(TalkerException err) => _write(err);
}
