import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/debug_flags.dart';
import 'core/logging/app_logger.dart';
import 'core/di/injection.dart';
import 'core/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Persistent file logging (adb-pullable via scripts/pull_logs.sh) — set up
  // first so early startup problems are captured too.
  await initAppLogging();
  FlutterError.onError = (details) {
    appLog.handle(details.exception, details.stack, 'FlutterError');
    FlutterError.presentError(details);
  };
  // fvp routes MDK's output through package:logging, and with no root listener
  // those lines are dropped. They are the only view into decode/audio-clock
  // behaviour when playback misbehaves on the TV, so they ship: INFO into the
  // pullable app log, everything under FVP_CAPTURE.
  Logger.root.level = kFvpCaptureBuild ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((r) {
    final line = '[${r.loggerName}] ${r.message}';
    if (r.level >= Level.SEVERE) {
      appLog.error(line);
    } else if (r.level >= Level.WARNING) {
      appLog.warning(line);
    } else {
      appLog.debug(line);
    }
    if (kFvpCaptureBuild) {
      // print, not debugPrint: long runs must not be throttled/truncated.
      // ignore: avoid_print
      print('[${r.loggerName}] ${r.level.name}: ${r.message}');
    }
  });
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationSupportDirectory()).path,
    ),
  );
  await configureProductionDependencies();
  // Android kills backgrounded apps without a clean shutdown, so this is the
  // last dependable chance to get buffered log lines onto disk — the whole
  // reason the file sink exists is to still be there afterwards.
  AppLifecycleListener(
    onPause: flushAppLog,
    onDetach: flushAppLog,
  );

  runApp(const NoorApp());

  // Refresh the active playlist's content in the background on launch so
  // channels/VOD/series stay current without a manual re-import.
  unawaited(sl<SyncService>().syncActive());
}
