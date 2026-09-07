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

  /// Body element focused when the rail was last entered, restored on the way
  /// back so the position in a long page is not lost.
  FocusNode? _lastBodyFocus;
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

  /// Nearest focusable neighbour of [focused] on the given side, **within the
  /// same scrollable row**.
  ///
  /// Plain directional traversal cannot be used to decide "am I at the edge?".
  /// A horizontal list keeps its scrolled-off items in the tree with real
  /// negative-x rects, so LEFT from the first poster of one row happily lands
  /// on an off-screen item of a *different* row. The rail was then only
  /// reachable once every row happened to be scrolled fully left. Restricting
  /// candidates to the focused item's own Scrollable, in the same vertical
  /// band, makes "no neighbour" mean what it should: this really is the edge.
  FocusNode? _rowNeighbour(FocusNode focused, {required bool toLeft}) {
    final ctx = focused.context;
    if (ctx == null) return null;
    final row = Scrollable.maybeOf(ctx);
    if (row == null) return null;
    final rect = focused.rect;
    FocusNode? best;
    for (final node in _bodyScope.traversalDescendants) {
      if (node == focused || !node.canRequestFocus || node.skipTraversal) {
        continue;
      }
      final nodeCtx = node.context;
      if (nodeCtx == null || Scrollable.maybeOf(nodeCtx) != row) continue;
      final r = node.rect;
      // Same band: excludes the rows above/below in a grid, which share one
      // Scrollable with the focused item.
      if (r.bottom <= rect.top || r.top >= rect.bottom) continue;
      if (toLeft ? r.center.dx >= rect.center.dx : r.center.dx <= rect.center.dx) {
        continue;
      }
      if (best == null ||
          (toLeft
              ? r.center.dx > best.rect.center.dx
              : r.center.dx < best.rect.center.dx)) {
        best = node;
      }
    }
    return best;
  }

  /// Nearest focusable to the given side that is **currently on screen**,
  /// anywhere in the body — the category sidebar beside a grid, for instance.
  ///
  /// Visibility is the filter that [_rowNeighbour] gets from staying inside
  /// one Scrollable: a list keeps its scrolled-off items at real off-screen
  /// coordinates, and without this check LEFT would land on one of them.
  FocusNode? _visibleNeighbour(FocusNode focused, {required bool toLeft}) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final rect = focused.rect;
    FocusNode? best;
    for (final node in _bodyScope.traversalDescendants) {
      if (node == focused || !node.canRequestFocus || node.skipTraversal) {
        continue;
      }
      final r = node.rect;
      if (!r.overlaps(screen)) continue;
      if (r.bottom <= rect.top || r.top >= rect.bottom) continue;
      if (toLeft
          ? r.center.dx >= rect.center.dx
          : r.center.dx <= rect.center.dx) {
        continue;
      }
      if (best == null ||
          (toLeft
              ? r.center.dx > best.rect.center.dx
              : r.center.dx < best.rect.center.dx)) {
        best = node;
      }
    }
    return best;
  }

  /// Focuses [node] and brings it into view — [FocusNode.requestFocus] alone
  /// does not, unlike the traversal policy's move.
  ///
  /// Scrolls only as far as it must, like Flutter's own directional traversal:
  /// a fixed alignment would drag the row along on every press even when the
  /// target is already on screen.
  void _focusAndReveal(FocusNode node, {bool towardStart = true}) {
    node.requestFocus();
    final ctx = node.context;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: towardStart ? 0.0 : 1.0,
      alignmentPolicy: towardStart
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Returns focus to the body from the rail.
  ///
  /// Plain "focus the first focusable" lands on the top row even when the body
  /// is scrolled far down, so the highlight vanishes off-screen. Prefer the
  /// element the user left, then the first one actually on screen, and scroll
  /// whatever is chosen into view.
  void _enterBody() {
    final last = _lastBodyFocus;
    if (last != null &&
        last.context != null &&
        last.canRequestFocus &&
        !last.skipTraversal) {
      _focusAndReveal(last);
      return;
    }
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    FocusNode? first;
    for (final n in _bodyScope.traversalDescendants) {
      if (!n.canRequestFocus || n.skipTraversal) continue;
      first ??= n;
      if (n.rect.overlaps(screen)) {
        _focusAndReveal(n);
        return;
      }
    }
    if (first != null) _focusAndReveal(first);
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
    final bodyDir = rtl ? TraversalDirection.left : TraversalDirection.right;

    // Along the row first, then whatever is visible beside it (a grid's
    // category sidebar), and only then out to the rail.
    if (towardRail && !inRail) {
      final neighbour = _rowNeighbour(focused, toLeft: !rtl) ??
          _visibleNeighbour(focused, toLeft: !rtl);
      if (neighbour != null) {
        _focusAndReveal(neighbour, towardStart: !rtl);
      } else {
        // Remember where we left so RIGHT comes back here.
        _lastBodyFocus = focused;
        _focusFirstIn(_railScope);
      }
      return KeyEventResult.handled;
    }
    // Toward the body from the rail: move within the rail, or escape back.
    if (!towardRail && inRail) {
      if (!focused.focusInDirection(bodyDir)) {
        _enterBody();
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
                    // The rail is a fixed 80 px, and an unconstrained Text
                    // wider than that is clipped at the screen edge rather
                    // than wrapped — the wordmark lost its first letters on
                    // TV. Scale it down to whatever the rail actually has.
                    child: SizedBox(
                      width: 72,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(widget.brand,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ),
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
          // The top bar above already sat inside a SafeArea, so the status-bar
          // inset is spent. Section screens build their own Scaffold + AppBar,
          // and without this they read the untouched MediaQuery and inset a
          // second time — a dead band above every section title on a phone.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.body,
            ),
          ),
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
