import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// ### TV focus: crossing between the rail and the body
/// Each shell branch is hosted in its own [Navigator], which establishes a
/// [FocusScope]. Flutter's directional focus traversal does NOT cross focus
/// scopes, so a D-pad LEFT at the left edge of the content would otherwise
/// never reach the rail. The wide layout wraps the rail and the body in
/// explicit scopes and intercepts edge LEFT/RIGHT to hop between them.
class AdaptiveShell extends StatefulWidget {
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
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  final FocusScopeNode _railScope = FocusScopeNode(debugLabel: 'nav-rail');
  final FocusScopeNode _bodyScope = FocusScopeNode(debugLabel: 'shell-body');

  @override
  void dispose() {
    _railScope.dispose();
    _bodyScope.dispose();
    super.dispose();
  }

  /// True when the user is typing in a text field, so directional keys must
  /// move the caret rather than focus.
  bool _isEditing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null && ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// Moves focus to the first focusable element inside [scope], descending
  /// into any nested child scopes (e.g. NavigationRail's internal scope).
  /// Returns true if focus moved.
  bool _focusFirstIn(FocusScopeNode scope) {
    for (final n in scope.traversalDescendants) {
      if (n.canRequestFocus && !n.skipTraversal) {
        n.requestFocus();
        return true;
      }
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft;
    final isRight = key == LogicalKeyboardKey.arrowRight;
    if (!isLeft && !isRight) return KeyEventResult.ignored;
    if (_isEditing()) return KeyEventResult.ignored;

    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return KeyEventResult.ignored;
    final inRail = focused.ancestors.contains(_railScope);

    // The rail sits at the reading-start edge: visually LEFT in LTR, RIGHT in
    // RTL (the Row mirrors). Arrow keys and TraversalDirection are visual, so
    // flip the hop directions under RTL or the rail becomes unreachable.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final towardRail = rtl ? isRight : isLeft;
    final railDir = rtl ? TraversalDirection.right : TraversalDirection.left;
    final bodyDir = rtl ? TraversalDirection.left : TraversalDirection.right;

    // Toward the rail from the body: move within the body, or escape to the
    // rail at the edge.
    if (towardRail && !inRail) {
      if (!focused.focusInDirection(railDir)) {
        _focusFirstIn(_railScope);
      }
      return KeyEventResult.handled;
    }
    // Toward the body from the rail: move within the rail, or escape back.
    if (!towardRail && inRail) {
      if (!focused.focusInDirection(bodyDir)) {
        _focusFirstIn(_bodyScope);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= NoorBreakpoints.rail;
    if (wide) {
      return Scaffold(
        body: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _handleKey,
          child: Row(
            children: [
              FocusScope(
                node: _railScope,
                child: NavigationRail(
                  selectedIndex: widget.currentIndex,
                  onDestinationSelected: widget.onSelect,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(widget.brand,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  trailing: (widget.onOpenSettings != null ||
                          widget.onOpenPlaylists != null)
                      ? Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.onOpenPlaylists != null)
                                    Tooltip(
                                      message: 'Playlists',
                                      child: Semantics(
                                        label: 'Playlists',
                                        button: true,
                                        child: IconButton(
                                          icon: const Icon(Icons.playlist_play),
                                          onPressed: widget.onOpenPlaylists,
                                        ),
                                      ),
                                    ),
                                  if (widget.onOpenSettings != null)
                                    Tooltip(
                                      message: 'Settings',
                                      child: Semantics(
                                        label: 'Settings',
                                        button: true,
                                        child: IconButton(
                                          icon: const Icon(Icons.settings),
                                          onPressed: widget.onOpenSettings,
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
                    for (final d in widget.destinations)
                      NavigationRailDestination(
                          icon: Icon(d.icon), label: Text(d.label)),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: FocusScope(
                  node: _bodyScope,
                  child: widget.body,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Narrow layout: slim top bar + body + bottom nav
    return Scaffold(
      body: Column(
        children: [
          if (widget.onOpenSettings != null || widget.onOpenPlaylists != null)
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(widget.brand,
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (widget.onOpenPlaylists != null)
                      Tooltip(
                        message: 'Playlists',
                        child: Semantics(
                          label: 'Playlists',
                          button: true,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.playlist_play),
                            onPressed: widget.onOpenPlaylists,
                          ),
                        ),
                      ),
                    if (widget.onOpenSettings != null)
                      Tooltip(
                        message: 'Settings',
                        child: Semantics(
                          label: 'Settings',
                          button: true,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.settings),
                            onPressed: widget.onOpenSettings,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: widget.onSelect,
        destinations: [
          for (final d in widget.destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
