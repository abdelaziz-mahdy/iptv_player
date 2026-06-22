import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_rail.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/home_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onOpenChannel,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final void Function(Channel) onOpenChannel;

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
        onOpenChannel: onOpenChannel,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onOpenChannel,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final void Function(Channel) onOpenChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
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
                  onOpenMovie: onOpenMovie,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            if (state.movies.isNotEmpty)
              SliverToBoxAdapter(
                child: _MoviesRail(
                  movies: state.movies,
                  onOpenMovie: onOpenMovie,
                ),
              ),
            if (state.series.isNotEmpty)
              SliverToBoxAdapter(
                child: _SeriesRail(
                  series: state.series,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            if (state.channels.isNotEmpty)
              SliverToBoxAdapter(
                child: _ChannelsRail(
                  channels: state.channels,
                  onOpenChannel: onOpenChannel,
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
              child: Image.network(
                featured.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
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
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.black, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.play,
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.black,
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
                                  color: p.fg, size: 20),
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

class _ContinueWatchingRail extends StatelessWidget {
  const _ContinueWatchingRail({
    required this.items,
    required this.movies,
    required this.series,
    required this.onOpenMovie,
    required this.onOpenSeries,
  });

  final List<WatchProgress> items;
  final List<VodItem> movies;
  final List<Series> series;
  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final cards = items.map((progress) {
      final progress0 = progress.durationSec > 0
          ? progress.positionSec / progress.durationSec
          : 0.0;

      // Try to find the matching movie
      final movie = movies.cast<VodItem?>().firstWhere(
            (m) => m?.id == progress.itemKey || 'movie:${m?.id}' == progress.itemKey,
            orElse: () => null,
          );
      if (movie != null) {
        return PosterCard(
          title: movie.title,
          subtitle: movie.year,
          imageUrl: movie.posterUrl,
          progress: progress0.clamp(0.0, 1.0),
          onTap: () => onOpenMovie(movie),
        );
      }

      // Try to find the matching series
      final show = series.cast<Series?>().firstWhere(
            (s) => s?.id == progress.itemKey || 'series:${s?.id}' == progress.itemKey,
            orElse: () => null,
          );
      if (show != null) {
        return PosterCard(
          title: show.title,
          subtitle: show.year,
          imageUrl: show.posterUrl,
          progress: progress0.clamp(0.0, 1.0),
          onTap: () => onOpenSeries(show),
        );
      }

      return PosterCard(
        title: progress.itemKey,
        progress: progress0.clamp(0.0, 1.0),
        onTap: () {},
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
    required this.onOpenMovie,
  });

  final List<VodItem> movies;
  final void Function(VodItem) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = movies
        .map(
          (m) => PosterCard(
            title: m.title,
            subtitle: m.year,
            imageUrl: m.posterUrl,
            onTap: () => onOpenMovie(m),
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
    required this.onOpenSeries,
  });

  final List<Series> series;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = series
        .map(
          (s) => PosterCard(
            title: s.title,
            subtitle: s.year,
            imageUrl: s.posterUrl,
            onTap: () => onOpenSeries(s),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.series, items: cards),
    );
  }
}

class _ChannelsRail extends StatelessWidget {
  const _ChannelsRail({
    required this.channels,
    required this.onOpenChannel,
  });

  final List<Channel> channels;
  final void Function(Channel) onOpenChannel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = channels
        .map(
          (c) => PosterCard(
            title: c.name,
            subtitle: c.number,
            imageUrl: c.logoUrl,
            badge: 'LIVE',
            onTap: () => onOpenChannel(c),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.live, items: cards),
    );
  }
}
