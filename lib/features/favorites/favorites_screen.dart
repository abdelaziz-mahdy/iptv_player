import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/poster_card.dart';
import '../../core/widgets/section_app_bar.dart';
import '../../core/widgets/status_views.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../grid/cubit/grid_cubit.dart' show GridEntry;
import 'cubit/favorites_cubit.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.onOpen,
  });

  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FavoritesCubit(
        sl<ContentRepository>(),
        sl<PlaylistRepository>(),
      )..load(),
      child: _FavoritesView(onOpen: onOpen),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView({required this.onOpen});

  final void Function(GridEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (ctx, state) {
        if (state.loading) {
          return Scaffold(
            backgroundColor: p.bg,
            appBar: SectionAppBar(title: l10n.favorites),
            body: const LoadingState(),
          );
        }

        return Scaffold(
          backgroundColor: p.bg,
          appBar: SectionAppBar(title: l10n.favorites),
          body: CustomScrollView(
            slivers: [
              if (state.isEmpty)
                // Empty state
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.favorite_border_rounded,
                    message: l10n.favoritesEmptyHint,
                  ),
                )
              else
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
                        final entry = state.entries[index];
                        return PosterCard(
                          autofocus: index == 0,
                          title: entry.title,
                          subtitle: entry.subtitle,
                          imageUrl: entry.posterUrl,
                          badge: entry.badge,
                          onTap: () => onOpen(entry),
                        );
                      },
                      childCount: state.entries.length,
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
