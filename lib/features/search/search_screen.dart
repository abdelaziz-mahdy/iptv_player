import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/search_cubit.dart';

// Rail height: 130px-wide PosterCard at 2:3 aspect = 195px art + 6px gap +
// ~24px title + ~18px subtitle ≈ 264px (matches ContentRail).
const _kRailHeight = 264.0;

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.onOpen});

  final void Function(SearchEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(
        sl<ContentRepository>(),
        sl<PlaylistRepository>(),
      )..load(),
      child: _SearchView(onOpen: onOpen),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({required this.onOpen});

  final void Function(SearchEntry) onOpen;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<SearchCubit, SearchState>(
      listenWhen: (prev, curr) => prev.query != curr.query,
      listener: (context, state) {
        if (_controller.text != state.query) {
          _controller.text = state.query;
          _controller.selection =
              TextSelection.collapsed(offset: state.query.length);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  controller: _controller,
                  hint: l10n.search,
                  palette: p,
                  textTheme: textTheme,
                  onChanged: (q) =>
                      context.read<SearchCubit>().setQuery(q),
                ),
                Expanded(
                  child: _ResultsRails(
                    results: state.results,
                    loading: state.loading,
                    query: state.query,
                    onOpen: widget.onOpen,
                    palette: p,
                    textTheme: textTheme,
                    l10n: l10n,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.palette,
    required this.textTheme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final dynamic palette;
  final TextTheme textTheme;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, color: p.dim, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                style: textTheme.bodyLarge?.copyWith(color: p.fg),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: textTheme.bodyLarge?.copyWith(color: p.dim),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                cursorColor: p.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays search results grouped by type as horizontal rails.
/// Movies appear in a "Movies" rail; Series in a "Series" rail.
/// Live channels are excluded. Only renders a rail when it has entries.
class _ResultsRails extends StatelessWidget {
  const _ResultsRails({
    required this.results,
    required this.loading,
    required this.query,
    required this.onOpen,
    required this.palette,
    required this.textTheme,
    required this.l10n,
  });

  final List<SearchEntry> results;
  final bool loading;
  final String query;
  final void Function(SearchEntry) onOpen;
  final dynamic palette;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final p = palette;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty query — show nothing (hint could go here if desired).
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final movies = SearchCubit.byKind(results, SearchEntryKind.movie);
    final series = SearchCubit.byKind(results, SearchEntryKind.series);
    final hasResults = movies.isNotEmpty || series.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Text(
          l10n.noResults,
          style: textTheme.bodyMedium?.copyWith(color: p.dim),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        if (movies.isNotEmpty)
          _SectionRail(
            label: l10n.movies,
            entries: movies,
            onOpen: onOpen,
            textTheme: textTheme,
          ),
        if (series.isNotEmpty)
          _SectionRail(
            label: l10n.series,
            entries: series,
            onOpen: onOpen,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

/// A titled horizontal rail of [PosterCard]s for a single content type.
class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.label,
    required this.entries,
    required this.onOpen,
    required this.textTheme,
  });

  final String label;
  final List<SearchEntry> entries;
  final void Function(SearchEntry) onOpen;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(label, style: textTheme.titleLarge),
        ),
        SizedBox(
          height: _kRailHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < entries.length - 1 ? 14 : 0,
                ),
                child: PosterCard(
                  title: entry.title,
                  subtitle: entry.subtitle,
                  imageUrl: entry.posterUrl,
                  onTap: () => onOpen(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
