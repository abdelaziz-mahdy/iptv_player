import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/grid_cubit.dart';

/// Minimum width (logical pixels) for the wide (sidebar + grid) layout.
const double _kWideBreakpoint = 700.0;

/// Width of the left category-selector sidebar in wide layout.
const double _kSidebarWidth = 180.0;

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

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.title, required this.onOpen});

  final String title;
  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tt = Theme.of(context).textTheme;

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
                      return _CategoryTile(
                        name: cat.name,
                        count: null, // categories don't have a count in CategoryRef
                        isSelected: isSelected,
                        onTap: () => ctx
                            .read<GridCubit>()
                            .selectCategory(isAll ? null : cat.id),
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
                          'No items found',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: p.dim),
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
              return FocusableButton(
                semanticLabel: cat.name,
                onPressed: () {
                  final cubit = ctx.read<GridCubit>();
                  cubit.selectCategory(isAll ? null : cat.id);
                  final items = cubit.state.filteredItems;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CategoryResultsScreen(
                        categoryName: cat.name,
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
                          cat.name,
                          style: tt.bodyMedium?.copyWith(
                            color: p.fg,
                            fontWeight: FontWeight.w600,
                          ),
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
                'No items found',
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
    required this.onTap,
  });

  final String name;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
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
                      fontSize: 11,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
