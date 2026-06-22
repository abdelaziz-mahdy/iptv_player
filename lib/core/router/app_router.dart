import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/_placeholder/placeholder_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/adaptive_shell.dart';

/// The shell branch routes, in nav order.
const _branchRoutes = ['/home', '/favorites', '/live', '/movies', '/series', '/search'];

/// Builds the app router: a [StatefulShellRoute] hosting the six main tabs in
/// the [AdaptiveShell], plus pushed routes for settings and playlists. Feature
/// plans replace the placeholder builders with real screens.
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
          );
        },
        branches: [
          for (final r in _branchRoutes)
            StatefulShellBranch(
              routes: [
                GoRoute(path: r, builder: (context, state) => PlaceholderScreen(title: _titleFor(context, r))),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => PlaceholderScreen(title: AppLocalizations.of(context)!.settings),
      ),
      GoRoute(
        path: '/playlists',
        builder: (context, state) => PlaceholderScreen(title: AppLocalizations.of(context)!.playlists),
      ),
    ],
  );
}

String _titleFor(BuildContext context, String route) {
  final t = AppLocalizations.of(context)!;
  switch (route) {
    case '/home':
      return t.home;
    case '/favorites':
      return t.favorites;
    case '/live':
      return t.live;
    case '/movies':
      return t.movies;
    case '/series':
      return t.series;
    case '/search':
      return t.search;
    default:
      return t.home;
  }
}
