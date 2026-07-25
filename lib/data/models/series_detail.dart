import 'package:equatable/equatable.dart';

import 'episode.dart';
import 'media_detail.dart';
import 'season.dart';

/// Holds the on-demand detail payload for a series: plot text,
/// ordered season list, and episodes keyed by season domain id.
class SeriesDetail extends Equatable {
  /// Cast, genre, rating, runtime and the rest of the provider's metadata.
  final MediaDetail info;

  final List<Season> seasons;

  /// Episodes keyed by the domain season id (`'<playlistId>:series:<sid>:season:<num>'`).
  final Map<String, List<Episode>> episodesBySeason;

  const SeriesDetail({
    this.info = MediaDetail.empty,
    this.seasons = const [],
    this.episodesBySeason = const {},
  });

  /// Plot text — the field callers needed before the rest of the metadata was
  /// mapped, kept as a shorthand.
  String? get description => info.description;

  /// An empty result used as the initial / fallback value.
  static const empty = SeriesDetail();

  @override
  List<Object?> get props => [info, seasons, episodesBySeason];
}
