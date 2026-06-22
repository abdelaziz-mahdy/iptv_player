import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/favorites_cubit.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.onOpen,
  });

  final void Function(String id) onOpen;

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

  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (ctx, state) {
        if (state.loading) {
          return Scaffold(
            backgroundColor: p.bg,
            body: Center(
              child: CircularProgressIndicator(color: p.accent),
            ),
          );
        }

        return Scaffold(
          backgroundColor: p.bg,
          body: CustomScrollView(
            slivers: [
              // Title bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                  child: Text(
                    l10n.favorites,
                    style: tt.headlineMedium?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              if (state.isEmpty)
                // Empty state
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 64,
                          color: p.dim,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.favorites,
                          style: tt.titleLarge?.copyWith(
                            color: p.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Items you add to My List will appear here.',
                          style: tt.bodyMedium?.copyWith(color: p.dim),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
                          title: entry.title,
                          subtitle: entry.subtitle,
                          imageUrl: entry.posterUrl,
                          badge: entry.badge,
                          onTap: () => onOpen(entry.id),
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
