import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'focusable_button.dart';

/// One row of a [CategorySidebar].
typedef SidebarEntry = ({String id, String label, int? count});

/// The left-hand category picker shared by Live, Movies and Series.
///
/// [pinnedCount] is how many leading entries belong to the pinned block — the
/// synthetic rows plus the categories the user actually opens. A separator is
/// drawn there, dividing "yours" from the provider's full list.
///
/// Focus starts on the *selected* row rather than the first one, so returning
/// to a section lands where the user left it.
class CategorySidebar extends StatelessWidget {
  const CategorySidebar({
    super.key,
    required this.entries,
    required this.selectedId,
    required this.pinnedCount,
    required this.onSelect,
  });

  static const double width = 180;

  final List<SidebarEntry> entries;
  final String? selectedId;
  final int pinnedCount;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: width,
      child: Container(
        color: p.bg2,
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelected = entry.id == selectedId;
            final tile = _SidebarTile(
              entry: entry,
              isSelected: isSelected,
              autofocus: isSelected,
              onTap: () => onSelect(entry.id),
            );
            if (index != pinnedCount || index == 0) return tile;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 17, thickness: 1, color: p.border),
                tile,
              ],
            );
          },
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.count != null)
              Text(
                '${entry.count}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? p.accent : p.dim,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
