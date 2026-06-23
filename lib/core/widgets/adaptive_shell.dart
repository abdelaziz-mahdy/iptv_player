import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// A navigation destination for the adaptive shell.
class NavDestinationData {
  final IconData icon;
  final String label;
  const NavDestinationData(this.icon, this.label);
}

/// Adaptive navigation scaffold: a [NavigationRail] with the brand wordmark on
/// wide layouts (TV/desktop/tablet) and a [NavigationBar] on narrow (phone),
/// switching at [NoorBreakpoints.rail].
///
/// When [onOpenSettings] or [onOpenPlaylists] are provided, affordances are
/// rendered so the user can reach those screens from every tab.
class AdaptiveShell extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<NavDestinationData> destinations;
  final String brand;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenPlaylists;

  const AdaptiveShell({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onSelect,
    required this.destinations,
    required this.brand,
    this.onOpenSettings,
    this.onOpenPlaylists,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= NoorBreakpoints.rail;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(brand, style: Theme.of(context).textTheme.titleLarge),
              ),
              trailing: (onOpenSettings != null || onOpenPlaylists != null)
                  ? Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onOpenPlaylists != null)
                                Tooltip(
                                  message: 'Playlists',
                                  child: Semantics(
                                    label: 'Playlists',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.playlist_play),
                                      onPressed: onOpenPlaylists,
                                    ),
                                  ),
                                ),
                              if (onOpenSettings != null)
                                Tooltip(
                                  message: 'Settings',
                                  child: Semantics(
                                    label: 'Settings',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.settings),
                                      onPressed: onOpenSettings,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : null,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Narrow layout: slim top bar + body + bottom nav
    return Scaffold(
      body: Column(
        children: [
          if (onOpenSettings != null || onOpenPlaylists != null)
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(brand, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (onOpenPlaylists != null)
                      Tooltip(
                        message: 'Playlists',
                        child: Semantics(
                          label: 'Playlists',
                          button: true,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.playlist_play),
                            onPressed: onOpenPlaylists,
                          ),
                        ),
                      ),
                    if (onOpenSettings != null)
                      Tooltip(
                        message: 'Settings',
                        child: Semantics(
                          label: 'Settings',
                          button: true,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.settings),
                            onPressed: onOpenSettings,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
