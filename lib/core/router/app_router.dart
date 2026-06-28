import 'dart:io' show Platform;

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
import '../../features/player/media_kit_controller.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/video_controller.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/search/cubit/search_cubit.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../debug_flags.dart';
import '../di/injection.dart';
import '../widgets/adaptive_shell.dart';

// ---------------------------------------------------------------------------
// Pushed-route argument classes
// ---------------------------------------------------------------------------

class PlayerArgs {
  final String itemKey, url, title;
  final String? subtitle;
  final MediaKind kind;
  final String playlistId;
  const PlayerArgs({
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    required this.kind,
    required this.playlistId,
  });
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
                  onOpen: (_) {
                    // TODO: resolve favorite to detail (needs full object, not just id)
                  },
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
                  onPlayChannel: (c) => context.push(
                    '/player',
                    extra: PlayerArgs(
                      itemKey: 'channel:${c.id}',
                      url: c.streamUrl,
                      title: c.name,
                      kind: MediaKind.channel,
                      playlistId: c.playlistId,
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
            onPlayEpisode: (ep) => context.push(
              '/player',
              extra: PlayerArgs(
                itemKey: 'episode:${ep.id}',
                url: ep.streamUrl,
                title: ep.title,
                kind: MediaKind.episode,
                playlistId: 'p1',
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
          return PlayerScreen(
            // media_kit (mpv vo_gpu) renders correctly on Android TV GPUs where
            // fvp/MDK corrupts; fvp stays on desktop where it works well.
            controller: (Platform.isAndroid && !kFvpCaptureBuild)
                ? MediaKitPlayerController()
                : VideoPlayerControllerAdapter(),
            itemKey: a.itemKey,
            url: a.url,
            title: a.title,
            subtitle: a.subtitle,
            onBack: () => context.pop(),
            playbackRepository: sl<PlaybackRepository>(),
            kind: a.kind,
            playlistId: a.playlistId,
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

void _openGridEntry(BuildContext c, GridEntry e) {
  if (e.isSeries) {
    c.push(
      '/details/series',
      extra: Series(
        id: e.id,
        playlistId: 'p1',
        title: e.title,
        posterUrl: e.posterUrl,
      ),
    );
  } else {
    c.push(
      '/details/movie',
      extra: VodItem(
        id: e.id,
        playlistId: 'p1',
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
          playlistId: 'p1',
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
          playlistId: 'p1',
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
          playlistId: 'p1',
        ),
      );
  }
}
