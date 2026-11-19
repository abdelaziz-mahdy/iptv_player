import '../../l10n/generated/app_localizations.dart';

/// "38m left" / "1h 32m left" for an item with [remainingSec] to go.
///
/// Rounds up so a few seconds remaining still reads "1m left" rather than
/// "0m left".
String timeLeftLabel(AppLocalizations l10n, int remainingSec) {
  final totalMin = remainingSec <= 0 ? 1 : (remainingSec + 59) ~/ 60;
  final hours = totalMin ~/ 60;
  final minutes = totalMin % 60;
  final time = hours > 0
      ? l10n.durationHoursMinutes(hours, minutes)
      : l10n.durationMinutes(minutes);
  return l10n.timeLeft(time);
}
