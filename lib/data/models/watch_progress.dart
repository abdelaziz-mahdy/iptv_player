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
