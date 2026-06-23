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

        final displayed = state.filteredItems;

        return Scaffold(
          backgroundColor: p.bg,
          body: CustomScrollView(
            slivers: [
              // Title bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 56, 12, 0),
                  child: Text(
                    title,
                    style: tt.headlineMedium?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Category filter chips — lazy horizontal ListView
              if (state.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      itemCount: state.categories.length,
                      itemBuilder: (context, index) {
                        final cat = state.categories[index];
                        final isAll = cat.id.isEmpty;
                        final selected = isAll
                            ? state.selectedCategoryId == null
                            : state.selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: _CategoryChip(
                            label: cat.name,
                            selected: selected,
                            onTap: () => ctx
                                .read<GridCubit>()
                                .selectCategory(isAll ? null : cat.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Poster grid — denser layout
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                sliver: SliverGrid.builder(
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
                    return PosterCard(
                      title: entry.title,
                      subtitle: entry.subtitle,
                      imageUrl: entry.posterUrl,
                      onTap: () => onOpen(entry),
                    );
                  },
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
