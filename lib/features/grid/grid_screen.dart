import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/jump_to_letter.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/grid_cubit.dart';

/// Display label for a category: the synthetic ones are localized here, since
/// the cubit has no BuildContext.
String _categoryLabel(AppLocalizations l10n, CategoryRef c) => switch (c.id) {
      kRecentCategoryId => l10n.recentlyViewed,
      '' => l10n.allCategory,
      _ => c.name,
    };

/// Minimum width (logical pixels) for the wide (sidebar + grid) layout.
const double _kWideBreakpoint = 700.0;

/// Width of the left category-selector sidebar in wide layout.
const double _kSidebarWidth = 180.0;

/// Poster metrics — shared by the grid delegate and the letter jump, which
/// computes a scroll offset from them.
const double _kPosterWidth = 150.0;
const double _kPosterAspect = 2 / 3.4;
const double _kPosterSpacing = 10.0;

class GridScreen extends StatelessWidget {
  const GridScreen({
    super.key,
    required this.kind,
    required this.onOpen,
  });

  final GridKind kind;
  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GridCubit(
        sl<ContentRepository>(),
        sl<PlaylistRepository>(),
        kind,
        playback: sl<PlaybackRepository>(),
      )..load(),
      child: _GridView(kind: kind, onOpen: onOpen),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({required this.kind, required this.onOpen});

  final GridKind kind;
  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final isWide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;

    final title = kind == GridKind.movies ? l10n.movies : l10n.series;

    return BlocBuilder<GridCubit, GridState>(
      builder: (ctx, state) {
        if (state.loading) {
          return Scaffold(
            backgroundColor: p.bg,
            body: Center(
              child: CircularProgressIndicator(color: p.accent),
            ),
          );
        }

        if (isWide) {
          return _WideLayout(
            title: title,
            onOpen: onOpen,
          );
        } else {
          return _NarrowLayout(
            title: title,
            onOpen: onOpen,
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Wide layout: sidebar (categories) + poster grid
// ---------------------------------------------------------------------------

class _WideLayout extends StatefulWidget {
  const _WideLayout({required this.title, required this.onOpen});

  final String title;
  final void Function(GridEntry entry) onOpen;

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout> {
  final _gridController = ScrollController();

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  /// Scrolls the poster grid to the first title starting with a letter the
  /// user picks. Posters are a fixed size, so the offset is arithmetic.
  Future<void> _jumpToLetter(List<GridEntry> items) async {
    final index = buildLetterIndex([for (final e in items) e.title]);
    if (index.isEmpty) return;
    final letter = await showJumpToLetter(
      context,
      available: index.keys.toSet(),
      title: AppLocalizations.of(context)!.jumpToLetter,
    );
    final target = letter == null ? null : index[letter];
    if (target == null || !mounted || !_gridController.hasClients) return;

    final width = MediaQuery.sizeOf(context).width - _kSidebarWidth - 25;
    final columns = (width / _kPosterWidth).ceil().clamp(1, 100);
    final tileWidth = (width - (columns - 1) * _kPosterSpacing) / columns;
    final row = target ~/ columns;
    final offset = row * (tileWidth / _kPosterAspect + _kPosterSpacing);
    _gridController.jumpTo(
      offset.clamp(0.0, _gridController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tt = Theme.of(context).textTheme;
    final title = widget.title;
    final onOpen = widget.onOpen;

    return BlocBuilder<GridCubit, GridState>(
      builder: (ctx, state) {
        final displayed = state.filteredItems;

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg2,
            title: Text(
              title,
              style: tt.titleLarge?.copyWith(
                color: p.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (displayed.isNotEmpty)
                FocusableButton(
                  semanticLabel: AppLocalizations.of(context)!.jumpToLetter,
                  onPressed: () => _jumpToLetter(displayed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.sort_by_alpha, color: p.fg, size: 24),
                  ),
                ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Sidebar: category list ----
              SizedBox(
                width: _kSidebarWidth,
                child: Container(
                  color: p.bg2,
                  child: ListView.builder(
                    itemCount: state.categories.length,
                    itemBuilder: (context, index) {
                      final cat = state.categories[index];
                      final isAll = cat.id.isEmpty;
                      final isSelected = isAll
                          ? state.selectedCategoryId == null
                          : state.selectedCategoryId == cat.id;
                      final tile = _CategoryTile(
                        name: _categoryLabel(
                            AppLocalizations.of(context)!, cat),
                        count: cat.count,
                        isSelected: isSelected,
                        autofocus: isSelected,
                        onTap: () => ctx
                            .read<GridCubit>()
                            .selectCategory(isAll ? null : cat.id),
                      );
                      // Separates the pinned block (All + the categories you
                      // use) from the provider's full list.
                      if (index != state.pinnedCategoryCount || index == 0) {
                        return tile;
                      }
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
              ),
              // Divider
              Container(width: 1, color: p.border),
              // ---- Poster grid ----
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noItemsFound,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: p.dim),
                        ),
                      )
                    : GridView.builder(
                        controller: _gridController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: _kPosterWidth,
                          mainAxisSpacing: _kPosterSpacing,
                          crossAxisSpacing: _kPosterSpacing,
                          childAspectRatio: _kPosterAspect,
                        ),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final entry = displayed[index];
                          final itemKey = entry.isSeries
                              ? 'episode:${entry.id}'
                              : 'movie:${entry.id}';
                          return PosterCard(
                            title: entry.title,
                            subtitle: entry.subtitle,
                            imageUrl: entry.posterUrl,
                            isFavorite: state.favoriteKeys.contains(itemKey),
                            onTap: () => onOpen(entry),
                            onToggleFavorite: () =>
                                ctx.read<GridCubit>().toggleFavorite(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow layout: category list; tap → CategoryResultsScreen
// ---------------------------------------------------------------------------

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.title, required this.onOpen});

  final String title;
  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<GridCubit, GridState>(
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg2,
            title: Text(
              title,
              style: tt.titleLarge?.copyWith(
                color: p.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: ListView.builder(
            itemCount: state.categories.length,
            itemBuilder: (context, index) {
              final cat = state.categories[index];
              final isAll = cat.id.isEmpty;
              final isSelected = isAll
                  ? state.selectedCategoryId == null
                  : state.selectedCategoryId == cat.id;
              final label = _categoryLabel(AppLocalizations.of(context)!, cat);
              return FocusableButton(
                autofocus: isSelected,
                semanticLabel: label,
                onPressed: () {
                  final cubit = ctx.read<GridCubit>();
                  cubit.selectCategory(isAll ? null : cat.id);
                  final items = cubit.state.filteredItems;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CategoryResultsScreen(
                        categoryName: label,
                        items: items,
                        onOpen: onOpen,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: tt.bodyMedium?.copyWith(
                            color: p.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (cat.count != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${cat.count}',
                            style: tt.labelSmall?.copyWith(color: p.dim),
                          ),
                        ),
                      Icon(Icons.chevron_right, color: p.dim, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Category results screen (second page in phone drill-in)
// ---------------------------------------------------------------------------

/// Shows a grid of posters for a single category.
/// Takes a static snapshot of items passed at construction time.
class CategoryResultsScreen extends StatelessWidget {
  const CategoryResultsScreen({
    super.key,
    required this.categoryName,
    required this.items,
    required this.onOpen,
  });

  final String categoryName;
  final List<GridEntry> items;
  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg2,
        title: Text(
          categoryName,
          style: tt.titleLarge?.copyWith(
            color: p.fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noItemsFound,
                style: tt.bodyLarge?.copyWith(color: p.dim),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2 / 3.4,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                return PosterCard(
                  autofocus: index == 0,
                  title: entry.title,
                  subtitle: entry.subtitle,
                  imageUrl: entry.posterUrl,
                  onTap: () => onOpen(entry),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sidebar tile widget (wide layout)
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.count,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
  });

  final String name;
  final int? count;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: name,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? p.accent.withValues(alpha: 0.18) : null,
          border: isSelected
              ? BorderDirectional(
                  start: BorderSide(color: p.accent, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? p.accent : p.fg,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null)
              Text(
                '$count',
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
