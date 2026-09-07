import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/logging/app_logger.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// In-app log viewer.
///
/// Exists because a release build is otherwise undiagnosable from the device:
/// logcat needs a computer and adb, and the rolling file sink needs a cable to
/// pull. When an import or a stream fails on a TV across the room, this is the
/// only way to see why and send it on — the screen's own actions copy and
/// share the log.
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    return TalkerScreen(
      talker: appLog,
      appBarTitle: l10n.logs,
      theme: TalkerScreenTheme(
        backgroundColor: p.bg,
        textColor: p.fg,
        cardColor: p.surface2,
      ),
    );
  }
}
