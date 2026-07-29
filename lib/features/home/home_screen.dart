import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_rail.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../core/widgets/remote_image.dart';
import '../../core/widgets/status_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/home_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onAddPlaylist,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final VoidCallback onAddPlaylist;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(
        sl<ContentRepository>(),
        sl<PlaybackRepository>(),
        sl<PlaylistRepository>(),
      )..load(),
      child: _HomeView(
        onOpenMovie: onOpenMovie,
        onOpenSeries: onOpenSeries,
        onAddPlaylist: onAddPlaylist,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onAddPlaylist,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final VoidCallback onAddPlaylist;

  bool _hasContent(HomeState state) =>
      state.movies.isNotEmpty || state.series.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state.loading) {
          return const LoadingState();
        }
        if (!_hasContent(state)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.noContentYet),
                const SizedBox(height: 16),
                FocusableButton(
                  autofocus: true,
                  semanticLabel: AppLocalizations.of(context)!.setUpPlaylist,
                  onPressed: onAddPlaylist,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.palette.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.setUpPlaylist,
                      style: TextStyle(color: context.palette.onAccent),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroBanner(
                movies: state.movies,
                onOpenMovie: onOpenMovie,
              ),
            ),
            if (state.continueWatching.isNotEmpty)
              SliverToBoxAdapter(
                child: _ContinueWatchingRail(
                  items: state.continueWatching,
                  movies: state.movies,
                  series: state.series,
                  episodesById: state.episodesById,
                  onOpenMovie: onOpenMovie,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            if (state.movies.isNotEmpty)
              SliverToBoxAdapter(
                child: _MoviesRail(
                  movies: state.movies,
                  favoriteKeys: state.favoriteKeys,
                  onOpenMovie: onOpenMovie,
                ),
              ),
            if (state.series.isNotEmpty)
              SliverToBoxAdapter(
                child: _SeriesRail(
                  series: state.series,
                  favoriteKeys: state.favoriteKeys,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.movies,
    required this.onOpenMovie,
  });

  final List<VodItem> movies;
  final void Function(VodItem) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    final featured = movies.first;
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  p.surface2,
                  p.bg,
                ],
              ),
            ),
          ),
          if (featured.posterUrl != null)
            Opacity(
              opacity: 0.3,
              child: RemoteImage(url: featured.posterUrl!, memWidth: 900),
            ),
          // Gradient scrim over backdrop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  p.bg,
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          // Content
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    featured.title,
                    style: textTheme.displaySmall?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (featured.year != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      featured.year!,
                      style: textTheme.bodyLarge?.copyWith(color: p.dim),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FocusableButton(
                        autofocus: true,
                        semanticLabel: l10n.play,
                        onPressed: () => onOpenMovie(featured),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: p.onAccent, size: IconSize.sm),
                              const SizedBox(width: 8),
                              Text(
                                l10n.play,
                                style: textTheme.labelLarge?.copyWith(
                                  color: p.onAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FocusableButton(
                        semanticLabel: l10n.moreInfo,
                        onPressed: () => onOpenMovie(featured),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: p.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: p.fg, size: IconSize.sm),
                              const SizedBox(width: 8),
                              Text(
                                l10n.moreInfo,
                                style: textTheme.labelLarge?.copyWith(
                                  color: p.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves a watch-progress `itemKey` to a `(seriesDomainId, seasonNumber)`.
///
/// Handles episode keys — `episode:<playlistId>:series:<sid>:season:<n>:ep:<id>`
/// — by taking the series id (before `:season:`) and the season number (between
/// `:season:` and `:ep:`), plus direct `series:` keys. Returns `(null, null)`
/// for movie/channel keys so the caller falls through to the movie branch.
(String?, String?) resolveContinueWatchingSeriesRef(String itemKey) {
  if (itemKey.startsWith('movie:') || itemKey.startsWith('channel:')) {
    return (null, null);
  }
  if (itemKey.startsWith('episode:')) {
    final ep = itemKey.substring('episode:'.length);
    final parts = ep.split(':season:');
    final seriesId = parts.first;
    String? seasonNumber;
    if (parts.length > 1) {
      final num = parts[1].split(':ep:').first;
      if (num.isNotEmpty) seasonNumber = num;
    }
    return (seriesId, seasonNumber);
  }
  if (itemKey.startsWith('series:')) {
    return (itemKey.substring('series:'.length), null);
  }
  return (itemKey, null); // bare id (defensive)
}

class _ContinueWatchingRail extends StatelessWidget {
  const _ContinueWatchingRail({
    required this.items,
    required this.movies,
    required this.series,
    required this.episodesById,
    required this.onOpenMovie,
    required this.onOpenSeries,
  });

  final List<WatchProgress> items;
  final List<VodItem> movies;
  final List<Series> series;
  final Map<String, Episode> episodesById;
  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    final cards = items.map((progress) {
      final progress0 = progress.durationSec > 0
          ? progress.positionSec / progress.durationSec
          : 0.0;

      Widget card;

      // Try to find the matching movie
      final movie = movies.cast<VodItem?>().firstWhere(
            (m) =>
                m?.id == progress.itemKey ||
                'movie:${m?.id}' == progress.itemKey,
            orElse: () => null,
          );
      if (movie != null) {
        card = PosterCard(
          title: movie.title,
          subtitle: movie.year,
          imageUrl: movie.posterUrl,
          progress: progress0.clamp(0.0, 1.0),
          onTap: () => onOpenMovie(movie),
        );
      } else {
        // Resolve a series either from a direct series key, or from an episode
        // key `episode:<playlistId>:series:<sid>:season:<n>:ep:<id>` — the
        // series id is the segment before ':season:', and the season number
        // sits between ':season:' and ':ep:'.
        final (seriesId, seasonNumber) =
            resolveContinueWatchingSeriesRef(progress.itemKey);
        final show = seriesId == null
            ? null
            : series.cast<Series?>().firstWhere(
                  (s) => s?.id == seriesId,
                  orElse: () => null,
                );
        if (show != null) {
          // Prefer "S{season} · E{number}" when the episode is cached locally,
          // else fall back to the season, else the year.
          final ep = progress.itemKey.startsWith('episode:')
              ? episodesById[progress.itemKey.substring('episode:'.length)]
              : null;
          String? subtitle;
          if (ep != null) {
            subtitle = seasonNumber != null
                ? 'S$seasonNumber · E${ep.number}'
                : 'E${ep.number}';
          } else if (seasonNumber != null) {
            subtitle = 'Season $seasonNumber';
          } else {
            subtitle = show.year;
          }
          card = PosterCard(
            title: show.title,
            subtitle: subtitle,
            imageUrl: show.posterUrl,
            progress: progress0.clamp(0.0, 1.0),
            onTap: () => onOpenSeries(show),
          );
        } else {
          card = PosterCard(
            title: progress.itemKey,
            progress: progress0.clamp(0.0, 1.0),
            onTap: () {},
          );
        }
      }

      return GestureDetector(
        onLongPress: () => cubit.removeFromContinueWatching(progress.itemKey),
        child: card,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(
        title: 'Continue Watching',
        items: cards,
      ),
    );
  }
}

class _MoviesRail extends StatelessWidget {
  const _MoviesRail({
    required this.movies,
    required this.favoriteKeys,
    required this.onOpenMovie,
  });

  final List<VodItem> movies;
  final Set<String> favoriteKeys;
  final void Function(VodItem) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<HomeCubit>();
    final cards = movies
        .map(
          (m) => PosterCard(
            title: m.title,
            subtitle: m.year,
            imageUrl: m.posterUrl,
            isFavorite: favoriteKeys.contains('movie:${m.id}'),
            onTap: () => onOpenMovie(m),
            onToggleFavorite: () => cubit.toggleFavoriteMovie(m),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.movies, items: cards),
    );
  }
}

class _SeriesRail extends StatelessWidget {
  const _SeriesRail({
    required this.series,
    required this.favoriteKeys,
    required this.onOpenSeries,
  });

  final List<Series> series;
  final Set<String> favoriteKeys;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<HomeCubit>();
    final cards = series
        .map(
          (s) => PosterCard(
            title: s.title,
            subtitle: s.year,
            imageUrl: s.posterUrl,
            isFavorite: favoriteKeys.contains('episode:${s.id}'),
            onTap: () => onOpenSeries(s),
            onToggleFavorite: () => cubit.toggleFavoriteSeries(s),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.series, items: cards),
    );
  }
}
