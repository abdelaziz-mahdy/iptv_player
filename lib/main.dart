import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/di/injection.dart';
import 'core/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
