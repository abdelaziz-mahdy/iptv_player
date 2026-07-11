
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../features/details/details_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/grid/cubit/grid_cubit.dart';
import '../../features/grid/grid_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/live/live_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/video_controller.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/search/cubit/search_cubit.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../di/injection.dart';
import '../widgets/adaptive_shell.dart';

// ---------------------------------------------------------------------------
// Pushed-route argument classes
// ---------------------------------------------------------------------------

/// One playable entry in a player [PlayerArgs.queue] — a neighbour the player
/// can move to with Previous/Next (an episode in the same season, or a channel
/// in the same group). [kind] and [playlistId] are shared across the queue, so
/// they live on [PlayerArgs], not here.
class PlayerQueueItem {
  final String itemKey, url, title;
  final String? subtitle;
  final String? recentKey;

  const PlayerQueueItem({
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    this.recentKey,
  });
}

class PlayerArgs {
  final String itemKey, url, title;
  final String? subtitle;
  final MediaKind kind;
  final String playlistId;

  /// Browsable key for "recently viewed" (e.g. `series:<id>` when playing an
  /// episode, so the parent series is recorded). Null falls back to [itemKey].
  final String? recentKey;

  /// Ordered neighbours for Previous/Next (same season / same group). Null or a
  /// single-item list means no queue navigation. [queueIndex] is this item's
  /// position within it.
  final List<PlayerQueueItem>? queue;
  final int queueIndex;

  const PlayerArgs({
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    required this.kind,
    required this.playlistId,
    this.recentKey,
    this.queue,
    this.queueIndex = 0,
  });

  /// Builds args for the queue entry at [i], carrying the same queue, kind and
  /// playlist — used by the player's Previous/Next actions.
  PlayerArgs atQueueIndex(int i) {
    final item = queue![i];
    return PlayerArgs(
      itemKey: item.itemKey,
      url: item.url,
      title: item.title,
      subtitle: item.subtitle,
      kind: kind,
      playlistId: playlistId,
      recentKey: item.recentKey,
      queue: queue,
      queueIndex: i,
    );
  }
}

/// Builds the app router: a [StatefulShellRoute] hosting the six main tabs in
/// the [AdaptiveShell], plus pushed routes for player, details, settings, etc.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final t = AppLocalizations.of(context)!;
          final dests = [
            NavDestinationData(Icons.home_outlined, t.home),
            NavDestinationData(Icons.favorite_border, t.favorites),
            NavDestinationData(Icons.live_tv_outlined, t.live),
            NavDestinationData(Icons.movie_outlined, t.movies),
            NavDestinationData(Icons.video_library_outlined, t.series),
            NavDestinationData(Icons.search, t.search),
          ];
          return AdaptiveShell(
            brand: t.brand,
            currentIndex: navigationShell.currentIndex,
            onSelect: navigationShell.goBranch,
            destinations: dests,
            body: navigationShell,
            onOpenSettings: () => context.push('/settings'),
            onOpenPlaylists: () => context.push('/playlists'),
          );
        },
        branches: [
          // /home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(
                  onOpenMovie: (m) =>
                      context.push('/details/movie', extra: m),
                  onOpenSeries: (s) =>
                      context.push('/details/series', extra: s),
                  onAddPlaylist: () => context.push('/import'),
                ),
              ),
            ],
          ),
          // /favorites
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => FavoritesScreen(
                  onOpen: (e) => _openFavorite(context, e),
                ),
              ),
            ],
          ),
          // /live
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                builder: (context, state) => LiveScreen(
                  onPlayChannel: (channels, index) => context.push(
                    '/player',
                    extra: PlayerArgs(
                      itemKey: 'channel:${channels[index].id}',
                      url: channels[index].streamUrl,
                      title: channels[index].name,
                      kind: MediaKind.channel,
                      playlistId: channels[index].playlistId,
                      // Next/Previous surf the channels in this group.
                      queue: [
                        for (final c in channels)
                          PlayerQueueItem(
                            itemKey: 'channel:${c.id}',
                            url: c.streamUrl,
                            title: c.name,
                          ),
                      ],
                      queueIndex: index,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // /movies
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) => GridScreen(
                  kind: GridKind.movies,
                  onOpen: (e) => _openGridEntry(context, e),
                ),
              ),
            ],
          ),
          // /series
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/series',
                builder: (context, state) => GridScreen(
                  kind: GridKind.series,
                  onOpen: (e) => _openGridEntry(context, e),
                ),
              ),
            ],
          ),
          // /search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => SearchScreen(
                  onOpen: (e) => _openSearchEntry(context, e),
                ),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Pushed routes (outside the shell)
      // -----------------------------------------------------------------------

      GoRoute(
        path: '/details/movie',
        builder: (context, state) {
          final movie = state.extra as VodItem?;
          if (movie == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Movie not found')),
            );
          }
          return DetailsScreen.movie(
            movie,
            onBack: () => context.pop(),
            onPlay: (m) => context.push(
              '/player',
              extra: PlayerArgs(
                itemKey: 'movie:${m.id}',
                url: m.streamUrl,
                title: m.title,
                kind: MediaKind.movie,
                playlistId: m.playlistId,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/details/series',
        builder: (context, state) {
          final series = state.extra as Series?;
          if (series == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Series not found')),
            );
          }
          return DetailsScreen.series(
            series,
            onBack: () => context.pop(),
            onPlayEpisode: (episodes, index) => context.push(
              '/player',
              extra: PlayerArgs(
                itemKey: 'episode:${episodes[index].id}',
                url: episodes[index].streamUrl,
                title: episodes[index].title,
                kind: MediaKind.episode,
                playlistId: series.playlistId,
                // Record the parent series (not the episode) as recently viewed.
                recentKey: 'series:${series.id}',
                // Next/Previous walk the episodes of the shown season.
                queue: [
                  for (final ep in episodes)
                    PlayerQueueItem(
                      itemKey: 'episode:${ep.id}',
                      url: ep.streamUrl,
                      title: ep.title,
                      recentKey: 'series:${series.id}',
                    ),
                ],
                queueIndex: index,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final a = state.extra as PlayerArgs?;
          if (a == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Nothing to play')),
            );
          }
          // Previous/Next move within the queue (episodes in a season, channels
          // in a group) by replacing this route — reusing all the player's
          // start/save/dispose logic. Null at the ends (no wrap-around) and
          // when there is no queue, so the buttons hide.
          final queue = a.queue;
          VoidCallback? onPrev;
          VoidCallback? onNext;
          if (queue != null) {
            if (a.queueIndex > 0) {
              onPrev = () =>
                  context.replace('/player', extra: a.atQueueIndex(a.queueIndex - 1));
            }
            if (a.queueIndex < queue.length - 1) {
              onNext = () =>
                  context.replace('/player', extra: a.atQueueIndex(a.queueIndex + 1));
            }
          }
          return PlayerScreen(
            // fvp/MDK on every platform. On Android TV PowerVR GPUs it needs
            // the EGL_SDR_DEPTH=8 env set in MainActivity.onCreate (fvp#374).
            controller: VideoPlayerControllerAdapter(),
            // Key by queue position so `context.replace` to a neighbour tears
            // down the old player State (and its controller) and builds a fresh
            // one, instead of reusing the state with a stale controller.
            key: ValueKey('player-${a.itemKey}'),
            itemKey: a.itemKey,
            url: a.url,
            title: a.title,
            subtitle: a.subtitle,
            onBack: () => context.pop(),
            playbackRepository: sl<PlaybackRepository>(),
            kind: a.kind,
            playlistId: a.playlistId,
            recentKey: a.recentKey,
            onPlayPrevious: onPrev,
            onPlayNext: onNext,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/playlists',
        builder: (context, state) => PlaylistsScreen(
          onAddPlaylist: () => context.push('/import'),
          onSelected: (p) => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => ImportScreen(
          onImported: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onGetStarted: () => context.go('/import'),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

/// Opens a favorite entry by kind: series/movie → details, channel → player.
/// Channels are marked with `badge == 'LIVE'` and carry their stream URL.
void _openFavorite(BuildContext c, GridEntry e) {
  if (e.badge == 'LIVE') {
    c.push(
      '/player',
      extra: PlayerArgs(
        itemKey: 'channel:${e.id}',
        url: e.streamUrl ?? '',
        title: e.title,
        kind: MediaKind.channel,
        playlistId: e.playlistId,
      ),
    );
    return;
  }
  _openGridEntry(c, e);
}

void _openGridEntry(BuildContext c, GridEntry e) {
  if (e.isSeries) {
    c.push(
      '/details/series',
      extra: Series(
        id: e.id,
        playlistId: e.playlistId,
        title: e.title,
        posterUrl: e.posterUrl,
      ),
    );
  } else {
    c.push(
      '/details/movie',
      extra: VodItem(
        id: e.id,
        playlistId: e.playlistId,
        title: e.title,
        posterUrl: e.posterUrl,
        streamUrl: e.streamUrl ?? '',
      ),
    );
  }
}

void _openSearchEntry(BuildContext c, SearchEntry e) {
  switch (e.kind) {
    case SearchEntryKind.movie:
      c.push(
        '/details/movie',
        extra: VodItem(
          id: e.id,
          playlistId: e.playlistId,
          title: e.title,
          posterUrl: e.posterUrl,
          streamUrl: e.streamUrl ?? '',
        ),
      );
    case SearchEntryKind.series:
      c.push(
        '/details/series',
        extra: Series(
          id: e.id,
          playlistId: e.playlistId,
          title: e.title,
          posterUrl: e.posterUrl,
        ),
      );
    case SearchEntryKind.channel:
      c.push(
        '/player',
        extra: PlayerArgs(
          itemKey: 'channel:${e.id}',
          url: e.streamUrl ?? '',
          title: e.title,
          kind: MediaKind.channel,
          playlistId: e.playlistId,
        ),
      );
  }
}
