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

extension WatchProgressX on WatchProgress {
  /// How far through the item this progress is (0..1), or null when the
  /// duration is unknown (stream never reported one).
  double? get fraction {
    if (durationSec <= 0) return null;
    final f = positionSec / durationSec;
    if (f < 0) return 0;
    return f > 1 ? 1.0 : f;
  }

  /// Whether the item counts as finished. Finished items replay from the
  /// start and leave Continue Watching (the row is kept for indicators).
  bool get isWatched => (fraction ?? 0) >= kWatchedFraction;
}
