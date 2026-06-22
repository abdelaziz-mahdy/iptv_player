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
class AdaptiveShell extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<NavDestinationData> destinations;
  final String brand;
  const AdaptiveShell({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onSelect,
    required this.destinations,
    required this.brand,
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
    return Scaffold(
      body: body,
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
