import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/grid_cubit.dart';

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
    final tt = Theme.of(context).textTheme;

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

        final displayed = state.items.where((e) {
          if (state.selectedCategory == null) return true;
          return e.badge == state.selectedCategory;
        }).toList();

        return Scaffold(
          backgroundColor: p.bg,
          body: CustomScrollView(
            slivers: [
              // Title bar
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 56, 20, 0),
                  child: Text(
                    title,
                    style: tt.headlineMedium?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Category filter chips
              if (state.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // "All" chip
                        _CategoryChip(
                          label: 'All',
                          selected: state.selectedCategory == null,
                          onTap: () =>
                              ctx.read<GridCubit>().selectCategory(null),
                        ),
                        ...state.categories.map(
                          (cat) => _CategoryChip(
                            label: cat,
                            selected: state.selectedCategory == cat,
                            onTap: () =>
                                ctx.read<GridCubit>().selectCategory(cat),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Poster grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisExtent: 260,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = displayed[index];
                      return PosterCard(
                        title: entry.title,
                        subtitle: entry.subtitle,
                        imageUrl: entry.posterUrl,
                        onTap: () => onOpen(entry),
                      );
                    },
                    childCount: displayed.length,
                  ),
                ),
              ),

              if (displayed.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Text(
                        'No items found',
                        style: tt.bodyLarge?.copyWith(color: p.dim),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      semanticLabel: label,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surface2,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: p.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? p.bg : p.fg,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}
