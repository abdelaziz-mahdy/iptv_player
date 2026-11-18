import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'watch_progress.freezed.dart';
part 'watch_progress.g.dart';

/// Playback position for a resumable item. `itemKey` uniquely identifies the
/// channel/movie/episode (e.g. "movie:123").
@freezed
abstract class WatchProgress with _$WatchProgress {
  const factory WatchProgress({
    required String itemKey,
    required String playlistId,
    required MediaKind kind,
    required int positionSec,
    required int durationSec,
    required DateTime updatedAt,
  }) = _WatchProgress;

  factory WatchProgress.fromJson(Map<String, dynamic> json) =>
      _$WatchProgressFromJson(json);
}

/// Fraction of an item's duration at/above which it counts as watched.
const double kWatchedFraction = 0.95;

/// Stopping in the end credits also counts as watched: past
/// [kCreditsFraction] with at most [kCreditsRemainingSec] left. Episodes on
/// the TV were left at 92-94% with about 2.5 minutes of credits to go and
/// stayed "unfinished" forever.
const double kCreditsFraction = 0.90;
const int kCreditsRemainingSec = 180;

extension WatchProgressX on WatchProgress {
  /// How far through the item this progress is (0..1), or null when the
  /// duration is unknown (stream never reported one).
  double? get fraction {
    if (durationSec <= 0) return null;
    final f = positionSec / durationSec;
    if (f < 0) return 0;
    return f > 1 ? 1.0 : f;
  }

  /// Seconds still to watch, or null when the duration is unknown.
  int? get remainingSec {
    if (durationSec <= 0) return null;
    final left = durationSec - positionSec;
    return left < 0 ? 0 : left;
  }

  /// Whether the item counts as finished. Finished items replay from the
  /// start and leave Continue Watching (the row is kept for indicators).
  bool get isWatched {
    final f = fraction;
    if (f == null) return false;
    if (f >= kWatchedFraction) return true;
    return f >= kCreditsFraction && remainingSec! <= kCreditsRemainingSec;
  }
}
