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
  if (kFvpCaptureBuild) {
    // fvp routes MDK's `log=all` output through package:logging; with no root
    // listener those lines are dropped before reaching logcat. Surface them so
    // the fvp#374 report carries the complete MDK log. (`print`, not
    // `debugPrint`, so long runs aren't throttled/truncated.)
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((r) {
      // ignore: avoid_print
      print('[${r.loggerName}] ${r.level.name}: ${r.message}');
    });
  }
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationSupportDirectory()).path,
    ),
  );
  await configureProductionDependencies();
  runApp(const NoorApp());

  // Refresh the active playlist's content in the background on launch so
  // channels/VOD/series stay current without a manual re-import.
  unawaited(sl<SyncService>().syncActive());
}
