import 'package:equatable/equatable.dart';

import 'episode.dart';
import 'season.dart';

/// Holds the on-demand detail payload for a series: plot text,
/// ordered season list, and episodes keyed by season domain id.
class SeriesDetail extends Equatable {
  final String? description;
  final List<Season> seasons;

  /// Episodes keyed by the domain season id (`'<playlistId>:series:<sid>:season:<num>'`).
  final Map<String, List<Episode>> episodesBySeason;

  const SeriesDetail({
    this.description,
    this.seasons = const [],
    this.episodesBySeason = const {},
  });

  /// An empty result used as the initial / fallback value.
  static const empty = SeriesDetail();

  @override
  List<Object?> get props => [description, seasons, episodesBySeason];
}
