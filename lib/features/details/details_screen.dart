import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/repositories.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import 'cubit/details_cubit.dart';

// ---------------------------------------------------------------------------
// Entry-point widget with two named constructors
// ---------------------------------------------------------------------------

class DetailsScreen extends StatelessWidget {
  final VodItem? _movie;
  final Series? _series;
  final VoidCallback onBack;
  final void Function(VodItem)? _onPlay;
  final void Function(List<Episode> episodes, int index)? _onPlayEpisode;

  /// Show movie details.
  const DetailsScreen.movie(
    VodItem movie, {
    super.key,
    required this.onBack,
    required void Function(VodItem) this._onPlay,
  })  : _movie = movie,
        _series = null,
        _onPlayEpisode = null;

  /// Show series details with season/episode browsing. [onPlayEpisode] receives
  /// the shown season's episode list and the tapped index, so the player can
  /// offer Previous/Next within the season.
  const DetailsScreen.series(
    Series series, {
    super.key,
    required this.onBack,
    required void Function(List<Episode> episodes, int index)
        this._onPlayEpisode,
  })  : _movie = null,
        _series = series,
        _onPlay = null;

  @override
  Widget build(BuildContext context) {
    final series = _series;
    if (series != null) {
      final onPlayEpisode = _onPlayEpisode!;
      return BlocProvider<DetailsCubit>(
        create: (_) => DetailsCubit(
          sl<ContentRepository>(),
          sl<PlaybackRepository>(),
        )..loadSeries(series),
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
// Responsive detail scaffold: full-bleed blurred backdrop, poster on the left
// (wide) or on top (narrow), content/sections in the remaining space.
// ---------------------------------------------------------------------------

/// Width at/above which the two-column (poster-left) layout is used.
const double _wideBreakpoint = 840;

class _DetailScaffold extends StatelessWidget {
  final String? posterUrl;
  final String title;
  final VoidCallback onBack;

  /// Header block: title, meta chips, action buttons, synopsis.
  final Widget header;

  /// Optional extra sections shown after the header (e.g. seasons + episodes).
  final List<Widget> sections;

  const _DetailScaffold({
    required this.posterUrl,
    required this.title,
    required this.onBack,
    required this.header,
    this.sections = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient blurred backdrop fills the whole screen.
          _AmbientBackdrop(posterUrl: posterUrl, title: title),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: poster column
                        SizedBox(
                          width: 280,
                          child: _Poster(posterUrl: posterUrl, title: title),
                        ),
                        const SizedBox(width: 28),
                        // Right: scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                header,
                                ...sections,
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Narrow (phone): poster on top, content below.
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: _Poster(posterUrl: posterUrl, title: title),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            header,
                            ...sections,
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                  color: p.surface.withAlpha(200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back, color: p.fg, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen blurred poster used as an ambient background, with a scrim so
/// foreground content stays readable.
class _AmbientBackdrop extends StatelessWidget {
  final String? posterUrl;
  final String title;
  const _AmbientBackdrop({required this.posterUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (posterUrl == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.surface, p.bg],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Image.network(
            posterUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: p.surface),
          ),
        ),
        // Darken + fade toward the bottom so text is legible.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.bg.withValues(alpha: 0.70),
                p.bg.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sharp, contained portrait poster with rounded corners.
class _Poster extends StatelessWidget {
  final String? posterUrl;
  final String title;
  const _Poster({required this.posterUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: posterUrl == null
            ? _GradientPlaceholder(title: title)
            : Image.network(
                posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _GradientPlaceholder(title: title),
              ),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: context.palette.dim),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta chips (CC / AD / year / rating)
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
// Reusable play button
// ---------------------------------------------------------------------------

class _PlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool autofocus;
  const _PlayButton({required this.onPressed, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: l10n.play,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: context.palette.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: context.palette.bg, size: 20),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Title + meta + synopsis header block
// ---------------------------------------------------------------------------

class _DetailHeader extends StatelessWidget {
  final String title;
  final List<Widget> chips;
  final List<Widget> actions;
  final String synopsis;

  const _DetailHeader({
    required this.title,
    required this.chips,
    required this.actions,
    required this.synopsis,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.headlineMedium?.copyWith(
            color: context.palette.fg,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: chips),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: actions),
        const SizedBox(height: 20),
        Text(
          l10n.synopsis,
          style: tt.titleMedium?.copyWith(
            color: context.palette.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          synopsis,
          style: tt.bodyMedium?.copyWith(color: context.palette.dim),
        ),
      ],
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
    return _DetailScaffold(
      posterUrl: movie.posterUrl,
      title: movie.title,
      onBack: onBack,
      header: _DetailHeader(
        title: movie.title,
        chips: [
          if (movie.year != null) _MetaChip(movie.year!),
          if (movie.rating != null)
            _MetaChip('${movie.rating!.toStringAsFixed(1)}★'),
          const _MetaChip('CC'),
          const _MetaChip('AD'),
        ],
        actions: [
          _PlayButton(autofocus: true, onPressed: () => onPlay(movie)),
          _MyListButton(
            itemKey: 'movie:${movie.id}',
            playlistId: movie.playlistId,
            kind: MediaKind.movie,
          ),
        ],
        synopsis: 'An extraordinary story unfolds — action, drama, and '
            'suspense combine in this must-watch feature.',
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
  final void Function(List<Episode> episodes, int index) onPlayEpisode;

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
        final hasEpisodes = !state.loading && state.episodes.isNotEmpty;
        return _DetailScaffold(
          posterUrl: series.posterUrl,
          title: series.title,
          onBack: onBack,
          header: _DetailHeader(
            title: series.title,
            chips: [
              if (series.year != null) _MetaChip(series.year!),
              if (series.rating != null)
                _MetaChip('${series.rating!.toStringAsFixed(1)}★'),
              const _MetaChip('CC'),
              const _MetaChip('AD'),
            ],
            actions: [
              if (hasEpisodes)
                _PlayButton(
                  autofocus: true,
                  onPressed: () => onPlayEpisode(state.episodes, 0),
                ),
              _MyListButton(
                itemKey: 'episode:${series.id}',
                playlistId: series.playlistId,
                kind: MediaKind.episode,
              ),
            ],
            synopsis: state.description?.isNotEmpty == true
                ? state.description!
                : 'An epic multi-season series that will keep you on the edge '
                    'of your seat from the very first episode.',
          ),
          sections: [
            const SizedBox(height: 20),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.seasons.isEmpty)
              Text(
                'No episodes available for this series.',
                style: tt.bodyMedium?.copyWith(color: context.palette.dim),
              )
            else ...[
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
                onSelect: (i) => ctx.read<DetailsCubit>().selectSeason(i),
              ),
              const SizedBox(height: 12),
              _EpisodeList(
                episodes: state.episodes,
                progressByKey: state.progressByKey,
                onPlayAt: (i) => onPlayEpisode(state.episodes, i),
              ),
            ],
          ],
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

  /// Watch progress keyed by `episode:<id>`; drives the per-row indicator.
  final Map<String, WatchProgress> progressByKey;

  /// Called with the tapped episode's index within [episodes].
  final void Function(int index) onPlayAt;

  const _EpisodeList({
    required this.episodes,
    required this.progressByKey,
    required this.onPlayAt,
  });

  static String _fmt(int? secs) {
    if (secs == null) return '';
    final m = secs ~/ 60;
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < episodes.length; i++)
          _EpisodeRow(
            episode: episodes[i],
            progress: progressByKey['episode:${episodes[i].id}'],
            onPlay: () => onPlayAt(i),
            duration: _fmt(episodes[i].durationSec),
          ),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final WatchProgress? progress;
  final VoidCallback onPlay;
  final String duration;

  const _EpisodeRow({
    required this.episode,
    required this.progress,
    required this.onPlay,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final itemKey = 'episode:${episode.id}';
    final watched = progress?.isWatched ?? false;
    final fraction = progress?.fraction ?? 0.0;
    final showBar = !watched && fraction > 0;
    return FocusableButton(
      semanticLabel: 'Play episode ${episode.number}: ${episode.title}',
      onPressed: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
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
                  if (showBar)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          key: Key('episode-progress-$itemKey'),
                          value: fraction,
                          minHeight: 3,
                          backgroundColor: context.palette.surface2,
                          color: context.palette.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (watched)
              Icon(
                Icons.check_circle,
                key: Key('episode-watched-$itemKey'),
                color: context.palette.accent,
                size: 22,
              )
            else
              Icon(Icons.play_circle_outline,
                  color: context.palette.dim, size: 22),
          ],
        ),
      ),
    );
  }
}
