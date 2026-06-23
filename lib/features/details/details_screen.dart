import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/repositories.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import 'cubit/details_cubit.dart';

// ---------------------------------------------------------------------------
// Entry-point widget with two named constructors
// ---------------------------------------------------------------------------

class DetailsScreen extends StatelessWidget {
  final VodItem? _movie;
  final Series? _series;
  final VoidCallback onBack;
  final void Function(VodItem)? _onPlay;
  final void Function(Episode)? _onPlayEpisode;

  /// Show movie details.
  const DetailsScreen.movie(
    VodItem movie, {
    super.key,
    required this.onBack,
    required void Function(VodItem) this._onPlay,
  })  : _movie = movie,
        _series = null,
        _onPlayEpisode = null;

  /// Show series details with season/episode browsing.
  const DetailsScreen.series(
    Series series, {
    super.key,
    required this.onBack,
    required void Function(Episode) this._onPlayEpisode,
  })  : _movie = null,
        _series = series,
        _onPlay = null;

  @override
  Widget build(BuildContext context) {
    final series = _series;
    if (series != null) {
      final onPlayEpisode = _onPlayEpisode!;
      return BlocProvider<DetailsCubit>(
        create: (_) =>
            DetailsCubit(sl<ContentRepository>())..loadSeries(series.id),
        child: _SeriesDetailBody(
          series: series,
          onBack: onBack,
          onPlayEpisode: onPlayEpisode,
        ),
      );
    }
    return _MovieDetailBody(
      movie: _movie!,
      onBack: onBack,
      onPlay: _onPlay!,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared backdrop hero + back button
// ---------------------------------------------------------------------------

class _BackdropHero extends StatelessWidget {
  final String? posterUrl;
  final String title;
  final VoidCallback onBack;

  const _BackdropHero({
    required this.posterUrl,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Cap the backdrop height so a full-width 16:9 image doesn't dominate on
    // wide desktop / TV windows; on phones it still fills nicely.
    final size = MediaQuery.sizeOf(context);
    final backdropHeight =
        (size.height * 0.42).clamp(220.0, 460.0).toDouble();

    Widget buildPosterContent() {
      if (posterUrl == null) {
        return _GradientPlaceholder(title: title);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          // Bottom layer: blurred full-bleed poster for ambient glow
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Image.network(
              posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => _GradientPlaceholder(title: title),
            ),
          ),
          // Dark scrim over the blurred layer
          Container(
            color: context.palette.bg.withValues(alpha: 0.55),
          ),
          // Foreground: full poster, contained (portrait box centred)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: backdropHeight,
                maxWidth: backdropHeight * 0.67, // typical portrait aspect
              ),
              child: Image.network(
                posterUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => _GradientPlaceholder(title: title),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Backdrop / ambient hero
        SizedBox(
          height: backdropHeight,
          width: double.infinity,
          child: buildPosterContent(),
        ),
        // Gradient overlay so text is readable
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: backdropHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  context.palette.bg.withAlpha(230),
                ],
              ),
            ),
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: FocusableButton(
            semanticLabel: l10n.back,
            onPressed: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.palette.surface.withAlpha(200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, color: context.palette.fg, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  final String title;
  const _GradientPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.palette.surface, context.palette.surface2],
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: context.palette.dim),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta chips (CC / AD / year / match)
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.palette.dim),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My-List (favorite) button — stateful, reads/writes via ContentRepository
// ---------------------------------------------------------------------------

class _MyListButton extends StatefulWidget {
  final String itemKey;
  final String playlistId;
  final MediaKind kind;

  const _MyListButton({
    required this.itemKey,
    required this.playlistId,
    required this.kind,
  });

  @override
  State<_MyListButton> createState() => _MyListButtonState();
}

class _MyListButtonState extends State<_MyListButton> {
  bool _inList = false;
  StreamSubscription<dynamic>? _favSub;

  @override
  void initState() {
    super.initState();
    _favSub = sl<ContentRepository>().favorites(widget.playlistId).listen((favs) {
      if (!mounted) return;
      setState(() {
        _inList = favs.any((f) => f.itemKey == widget.itemKey);
      });
    });
  }

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableButton(
      semanticLabel: _inList ? 'Remove from My List' : 'Add to My List',
      onPressed: () => sl<ContentRepository>().toggleFavorite(
        widget.itemKey,
        widget.playlistId,
        widget.kind,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _inList ? context.palette.accent.withAlpha(30) : context.palette.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _inList ? context.palette.accent : context.palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _inList ? Icons.check : Icons.add,
              color: _inList ? context.palette.accent : context.palette.fg,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'My List',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _inList ? context.palette.accent : context.palette.fg,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Movie detail body
// ---------------------------------------------------------------------------

class _MovieDetailBody extends StatelessWidget {
  final VodItem movie;
  final VoidCallback onBack;
  final void Function(VodItem) onPlay;

  const _MovieDetailBody({
    required this.movie,
    required this.onBack,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackdropHero(
              posterUrl: movie.posterUrl,
              title: movie.title,
              onBack: onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    style: tt.headlineMedium?.copyWith(
                      color: context.palette.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Meta chips row
                  Row(
                    children: [
                      if (movie.year != null) _MetaChip(movie.year!),
                      if (movie.rating != null)
                        _MetaChip('${movie.rating!.toStringAsFixed(1)}★'),
                      const _MetaChip('CC'),
                      const _MetaChip('AD'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      FocusableButton(
                        semanticLabel: l10n.play,
                        onPressed: () => onPlay(movie),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.palette.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: context.palette.bg, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                l10n.play,
                                style: tt.labelLarge?.copyWith(
                                  color: context.palette.bg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MyListButton(
                        itemKey: 'movie:${movie.id}',
                        playlistId: movie.playlistId,
                        kind: MediaKind.movie,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Synopsis heading
                  Text(
                    l10n.synopsis,
                    style: tt.titleMedium?.copyWith(
                      color: context.palette.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'An extraordinary story unfolds — action, drama, and suspense '
                    'combine in this must-watch feature.',
                    style: tt.bodyMedium?.copyWith(color: context.palette.dim),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series detail body
// ---------------------------------------------------------------------------

class _SeriesDetailBody extends StatelessWidget {
  final Series series;
  final VoidCallback onBack;
  final void Function(Episode) onPlayEpisode;

  const _SeriesDetailBody({
    required this.series,
    required this.onBack,
    required this.onPlayEpisode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<DetailsCubit, DetailsState>(
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: context.palette.bg,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackdropHero(
                  posterUrl: series.posterUrl,
                  title: series.title,
                  onBack: onBack,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        series.title,
                        style: tt.headlineMedium?.copyWith(
                          color: context.palette.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Meta chips row
                      Row(
                        children: [
                          if (series.year != null) _MetaChip(series.year!),
                          if (series.rating != null)
                            _MetaChip('${series.rating!.toStringAsFixed(1)}★'),
                          const _MetaChip('CC'),
                          const _MetaChip('AD'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          // Play button — only shown when episodes are available
                          if (!state.loading && state.episodes.isNotEmpty) ...[
                            FocusableButton(
                              semanticLabel: l10n.play,
                              onPressed: () =>
                                  onPlayEpisode(state.episodes.first),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.palette.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow,
                                        color: context.palette.bg, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.play,
                                      style: tt.labelLarge?.copyWith(
                                        color: context.palette.bg,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          _MyListButton(
                            itemKey: 'episode:${series.id}',
                            playlistId: series.playlistId,
                            kind: MediaKind.episode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Synopsis
                      Text(
                        l10n.synopsis,
                        style: tt.titleMedium?.copyWith(
                          color: context.palette.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'An epic multi-season series that will keep you on the '
                        'edge of your seat from the very first episode.',
                        style: tt.bodyMedium
                            ?.copyWith(color: context.palette.dim),
                      ),
                      const SizedBox(height: 20),
                      // Season chips
                      if (state.seasons.isNotEmpty) ...[
                        Text(
                          l10n.episodes,
                          style: tt.titleMedium?.copyWith(
                            color: context.palette.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SeasonChips(
                          seasons: state.seasons,
                          selectedIndex: state.selectedSeasonIndex,
                          onSelect: (i) =>
                              ctx.read<DetailsCubit>().selectSeason(i),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Loading indicator or episode list
                      if (state.loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        _EpisodeList(
                          episodes: state.episodes,
                          onPlay: onPlayEpisode,
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Season chips
// ---------------------------------------------------------------------------

class _SeasonChips extends StatelessWidget {
  final List<Season> seasons;
  final int selectedIndex;
  final void Function(int) onSelect;

  const _SeasonChips({
    required this.seasons,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(seasons.length, (i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FocusableButton(
              semanticLabel: 'Season ${seasons[i].number}',
              onPressed: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? context.palette.accent
                      : context.palette.surface2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'S${seasons[i].number}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? context.palette.bg
                            : context.palette.fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Episode list
// ---------------------------------------------------------------------------

class _EpisodeList extends StatelessWidget {
  final List<Episode> episodes;
  final void Function(Episode) onPlay;

  const _EpisodeList({required this.episodes, required this.onPlay});

  static String _fmt(int? secs) {
    if (secs == null) return '';
    final m = secs ~/ 60;
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();
    return Column(
      children: episodes.map((ep) => _EpisodeRow(
            episode: ep,
            onPlay: onPlay,
            duration: _fmt(ep.durationSec),
          )).toList(),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final void Function(Episode) onPlay;
  final String duration;

  const _EpisodeRow({
    required this.episode,
    required this.onPlay,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return FocusableButton(
      semanticLabel: 'Play episode ${episode.number}: ${episode.title}',
      onPressed: () => onPlay(episode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Episode number badge
            SizedBox(
              width: 36,
              child: Text(
                '${episode.number}',
                style: tt.titleMedium?.copyWith(
                  color: context.palette.dim,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Title + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: tt.bodyMedium?.copyWith(color: context.palette.fg),
                  ),
                  if (duration.isNotEmpty)
                    Text(
                      duration,
                      style:
                          tt.bodySmall?.copyWith(color: context.palette.dim),
                    ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline,
                color: context.palette.dim, size: 22),
          ],
        ),
      ),
    );
  }
}
