import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/search_cubit.dart';

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

  void _appendChar(BuildContext context, String ch) {
    final cubit = context.read<SearchCubit>();
    final newQuery = cubit.state.query + ch;
    _controller.text = newQuery;
    _controller.selection =
        TextSelection.collapsed(offset: newQuery.length);
    cubit.setQuery(newQuery);
  }

  void _backspace(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    final q = cubit.state.query;
    if (q.isEmpty) return;
    final newQuery = q.substring(0, q.length - 1);
    _controller.text = newQuery;
    _controller.selection =
        TextSelection.collapsed(offset: newQuery.length);
    cubit.setQuery(newQuery);
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
                _OnScreenKeyboard(
                  onKey: (ch) => _appendChar(context, ch),
                  onSpace: () => _appendChar(context, ' '),
                  onBackspace: () => _backspace(context),
                  palette: p,
                  textTheme: textTheme,
                ),
                Expanded(
                  child: _ResultsGrid(
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

// Key rows match design: QWERTY layout
const _kKeyRows = [
  'QWERTYUIOP',
  'ASDFGHJKL',
  'ZXCVBNM',
];

class _OnScreenKeyboard extends StatelessWidget {
  const _OnScreenKeyboard({
    required this.onKey,
    required this.onSpace,
    required this.onBackspace,
    required this.palette,
    required this.textTheme,
  });

  final void Function(String) onKey;
  final VoidCallback onSpace;
  final VoidCallback onBackspace;
  final dynamic palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._kKeyRows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: row.split('').map((ch) {
                  return _KeyButton(
                    label: ch,
                    palette: p,
                    textTheme: textTheme,
                    onPressed: () => onKey(ch.toLowerCase()),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _KeyButton(
                  label: '⎵',
                  palette: p,
                  textTheme: textTheme,
                  width: 100,
                  onPressed: onSpace,
                ),
                const SizedBox(width: 4),
                _KeyButton(
                  label: '⌫',
                  palette: p,
                  textTheme: textTheme,
                  width: 60,
                  onPressed: onBackspace,
                ),
              ],
            ),
          ),
          // Digit row 0-9
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(10, (i) {
                final digit = i.toString();
                return _KeyButton(
                  label: digit,
                  palette: p,
                  textTheme: textTheme,
                  onPressed: () => onKey(digit),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.palette,
    required this.textTheme,
    required this.onPressed,
    this.width,
  });

  final String label;
  final dynamic palette;
  final TextTheme textTheme;
  final VoidCallback onPressed;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return FocusableButton(
      semanticLabel: label,
      onPressed: onPressed,
      child: Container(
        width: width ?? 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: p.fg),
        ),
      ),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${results.length} ${l10n.search}',
                style: textTheme.labelMedium?.copyWith(
                  color: p.dim,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: results.isEmpty && query.isNotEmpty
                ? Center(
                    child: Text(
                      l10n.search,
                      style: textTheme.bodyMedium?.copyWith(color: p.dim),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      childAspectRatio: 2 / 4.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      return PosterCard(
                        title: entry.title,
                        subtitle: entry.subtitle,
                        imageUrl: entry.posterUrl,
                        onTap: () => onOpen(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
