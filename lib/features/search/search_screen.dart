import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_text_field/native_textfield_tv.dart';
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
  // NativeTextFieldController works with both the native Android-TV field and a
  // plain TextField (it extends TextEditingController).
  final NativeTextFieldController _controller = NativeTextFieldController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'search-field');
  SearchCubit? _cubit;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= context.read<SearchCubit>();
    if (!_listening) {
      _controller.addListener(_onText);
      _listening = true;
    }
  }

  /// Live search as the user types.
  void _onText() {
    final text = _controller.text;
    if (_cubit != null && text != _cubit!.state.query) {
      _cubit!.setQuery(text);
    }
  }

  /// Pressing the keyboard's Done/Search action moves focus into the results,
  /// so the remote can scroll the posters.
  void _moveToResults() {
    _fieldFocus.unfocus();
    FocusScope.of(context).nextFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _controller.dispose();
    _fieldFocus.dispose();
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
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.bg,
          // The IME is an overlay on TV; don't resize the body for it.
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  hint: l10n.search,
                  palette: p,
                  textTheme: textTheme,
                  onSubmitted: _moveToResults,
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
                    favoriteKeys: state.favoriteKeys,
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
    required this.focusNode,
    required this.hint,
    required this.palette,
    required this.textTheme,
    required this.onSubmitted,
  });

  final NativeTextFieldController controller;
  final FocusNode focusNode;
  final String hint;
  final dynamic palette;
  final TextTheme textTheme;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = palette;

    // Android (incl. TV): native EditText for working D-pad text entry.
    if (Platform.isAndroid) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: AndroidTVTextField(
          focusNode: focusNode,
          controller: controller,
          hint: hint,
          height: 56,
          backgroundColor: p.surface,
          textColor: p.fg,
          focusedBorderColor: p.accent,
          unfocusedBorderColor: p.border,
          onSubmitted: (_) => onSubmitted(),
        ),
      );
    }

    // Desktop / other: standard editable field.
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
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSubmitted(),
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
    required this.favoriteKeys,
  });

  final List<SearchEntry> results;
  final bool loading;
  final String query;
  final void Function(SearchEntry) onOpen;
  final dynamic palette;
  final TextTheme textTheme;
  final AppLocalizations l10n;
  final Set<String> favoriteKeys;

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
            favoriteKeys: favoriteKeys,
          ),
        if (series.isNotEmpty)
          _SectionRail(
            label: l10n.series,
            entries: series,
            onOpen: onOpen,
            textTheme: textTheme,
            favoriteKeys: favoriteKeys,
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
    required this.favoriteKeys,
  });

  final String label;
  final List<SearchEntry> entries;
  final void Function(SearchEntry) onOpen;
  final TextTheme textTheme;
  final Set<String> favoriteKeys;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
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
              final itemKey = entry.kind == SearchEntryKind.series
                  ? 'episode:${entry.id}'
                  : 'movie:${entry.id}';
              return Padding(
                padding: EdgeInsets.only(
                  right: index < entries.length - 1 ? 14 : 0,
                ),
                child: PosterCard(
                  title: entry.title,
                  subtitle: entry.subtitle,
                  imageUrl: entry.posterUrl,
                  isFavorite: favoriteKeys.contains(itemKey),
                  onTap: () => onOpen(entry),
                  onToggleFavorite: () => cubit.toggleFavorite(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
