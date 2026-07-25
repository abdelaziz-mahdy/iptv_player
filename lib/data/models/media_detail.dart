import 'package:equatable/equatable.dart';

/// Extended metadata for one movie or series, fetched on demand from the
/// provider's per-item info endpoint (Xtream `get_vod_info` /
/// `get_series_info`).
///
/// The catalog listing carries only enough to draw a poster tile; everything
/// here needs a second request, so it is loaded when a detail screen opens.
/// Every field is optional — providers fill these in very unevenly, and a
/// missing field means "not supplied", not "empty".
class MediaDetail extends Equatable {
  /// Plot / synopsis.
  final String? description;

  /// Comma-separated cast list, as the provider wrote it.
  final String? cast;
  final String? director;

  /// Comma-separated genres.
  final String? genre;
  final String? country;

  /// Release date. Providers send several formats; the source parses what it
  /// can and leaves this null otherwise.
  final DateTime? releaseDate;

  /// Provider rating, on a 0–10 scale.
  final double? rating;

  /// Runtime of a movie, or the typical episode runtime of a series.
  final int? durationSec;

  /// Trailer, as a YouTube id or a full URL — [trailerUrl] normalizes it.
  final String? youtubeTrailer;

  /// Wide backdrop images (the poster lives on the catalog item).
  final List<String> backdrops;

  const MediaDetail({
    this.description,
    this.cast,
    this.director,
    this.genre,
    this.country,
    this.releaseDate,
    this.rating,
    this.durationSec,
    this.youtubeTrailer,
    this.backdrops = const [],
  });

  static const empty = MediaDetail();

  /// Whether anything beyond the synopsis is worth rendering.
  bool get hasCredits =>
      (cast?.isNotEmpty ?? false) ||
      (director?.isNotEmpty ?? false) ||
      (genre?.isNotEmpty ?? false) ||
      (country?.isNotEmpty ?? false);

  bool get isEmpty =>
      (description?.isEmpty ?? true) &&
      !hasCredits &&
      releaseDate == null &&
      rating == null &&
      durationSec == null &&
      backdrops.isEmpty;

  /// Full watch URL for [youtubeTrailer], which providers give either as a
  /// bare video id or as a link. Null when there is no trailer.
  String? get trailerUrl {
    final t = youtubeTrailer?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://www.youtube.com/watch?v=$t';
  }

  @override
  List<Object?> get props => [
        description,
        cast,
        director,
        genre,
        country,
        releaseDate,
        rating,
        durationSec,
        youtubeTrailer,
        backdrops,
      ];
}
