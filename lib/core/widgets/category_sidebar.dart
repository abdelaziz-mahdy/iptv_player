import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'focusable_button.dart';

/// One row of a [CategorySidebar].
typedef SidebarEntry = ({String id, String label, int? count});

/// The left-hand category picker shared by Live, Movies and Series.
///
/// [pinnedCount] is how many leading entries belong to the pinned block: the
/// synthetic rows ("Recently Viewed", "All") and then the last [recentCount]
/// categories the user opened, headed "Recent". A separator follows the
/// block, dividing "yours" from the provider's full list. A recent category
/// is also listed in its normal place below.
///
/// Focus starts on the *selected* row rather than the first one, so returning
/// to a section lands where the user left it.
///
/// Picking a category adds it to "Recent" right away. Rows are inserted above
/// the one the user just picked, so the list scrolls by the same height and
/// that row stays exactly where it was on screen.
class CategorySidebar extends StatefulWidget {
  const CategorySidebar({
    super.key,
    required this.entries,
    required this.selectedId,
    required this.pinnedCount,
    this.recentCount = 0,
    required this.onSelect,
  });

  static const double width = 180;

  final List<SidebarEntry> entries;
  final String? selectedId;
  final int pinnedCount;
  final int recentCount;
  final ValueChanged<String> onSelect;

  @override
  State<CategorySidebar> createState() => _CategorySidebarState();
}

class _CategorySidebarState extends State<CategorySidebar> {
  final _scroll = ScrollController();

  /// One key per row (keyed by [_rowKey]) so a row can be found on screen
  /// before and after the list changes, and keeps its element when it moves.
  final _keys = <String, GlobalKey>{};
  GlobalKey _keyFor(String rowKey) => _keys.putIfAbsent(rowKey, GlobalKey.new);

  int get _recentStart => widget.pinnedCount - widget.recentCount;

  bool _isRecentRow(int index) =>
      widget.recentCount > 0 &&
      index >= _recentStart &&
      index < widget.pinnedCount;

  /// A row's key: the same category can be listed twice (in "Recent" and in
  /// its normal place), so the key says which copy it is.
  String _rowKey(int index) =>
      '${_isRecentRow(index) ? 'recent' : 'row'}:${widget.entries[index].id}';

  /// The row that holds focus for the selected category: its normal place
  /// when it has one, otherwise wherever it is listed.
  int _homeIndex() {
    final id = widget.selectedId;
    var fallback = -1;
    for (var i = 0; i < widget.entries.length; i++) {
      if (widget.entries[i].id != id) continue;
      if (!_isRecentRow(i)) return i;
      if (fallback < 0) fallback = i;
    }
    return fallback;
  }

  double? _topOf(String rowKey) {
    final box = _keys[rowKey]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  @override
  void didUpdateWidget(CategorySidebar old) {
    super.didUpdateWidget(old);
    // The row the user is on: the selected category's normal place. Where
    // was that same row before this update (still the old layout here)?
    final home = _homeIndex();
    if (home < 0) return;
    final anchor = _rowKey(home);
    final before = _topOf(anchor);
    if (before == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final after = _topOf(anchor);
      if (after == null || !_scroll.hasClients) return;
      final shift = after - before;
      if (shift.abs() < 0.5) return;
      final pos = _scroll.position;
      _scroll.jumpTo(
        (pos.pixels + shift).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final home = _homeIndex();
    final keyIndex = <Key, int>{
      for (var i = 0; i < widget.entries.length; i++) _keyFor(_rowKey(i)): i,
    };
    return SizedBox(
      width: CategorySidebar.width,
      child: Container(
        color: p.bg2,
        child: ListView.builder(
          controller: _scroll,
          itemCount: widget.entries.length,
          // Rows move when "Recent" changes; match them by key so a row keeps
          // its element (and focus) instead of being rebuilt at a new index.
          findChildIndexCallback: (key) => keyIndex[key],
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            final isSelected = entry.id == widget.selectedId;
            final tile = _SidebarTile(
              entry: entry,
              isSelected: isSelected,
              autofocus: index == home,
              onTap: () => widget.onSelect(entry.id),
            );
            final heading =
                widget.recentCount > 0 && index == _recentStart && index > 0;
            final divider = index == widget.pinnedCount && index > 0;
            return KeyedSubtree(
              key: _keyFor(_rowKey(index)),
              child: heading || divider
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (divider)
                          Divider(height: 17, thickness: 1, color: p.border),
                        if (heading) const _RecentHeading(),
                        tile,
                      ],
                    )
                  : tile,
            );
          },
        ),
      ),
    );
  }
}

/// "RECENT" over the categories the user opened last.
class _RecentHeading extends StatelessWidget {
  const _RecentHeading();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 4),
      child: Text(
        AppLocalizations.of(context)!.recentGroups.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: p.dim,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.entry,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
  });

  final SidebarEntry entry;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: entry.label,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? p.accent.withValues(alpha: 0.18) : null,
          border: isSelected
              ? BorderDirectional(start: BorderSide(color: p.accent, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? p.accent : p.fg,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.count != null)
              Text(
                '${entry.count}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: isSelected ? p.accent : p.dim),
              ),
          ],
        ),
      ),
    );
  }
}
