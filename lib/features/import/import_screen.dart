import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../data/credential_store.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/import_cubit.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.onImported});

  final VoidCallback onImported;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImportCubit(
        sl<PlaylistRepository>(),
        sl<ContentRepository>(),
        credentialStore: sl<CredentialStore>(),
      ),
      child: BlocListener<ImportCubit, ImportState>(
        listener: (context, state) {
          if (state.done) {
            widget.onImported();
          }
        },
        child: _ImportView(),
      ),
    );
  }
}

class _ImportView extends StatefulWidget {
  @override
  State<_ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<_ImportView> {
  final _formKey = GlobalKey<FormState>();

  // Shared
  final _nameController = TextEditingController();

  // Xtream
  final _xtreamServerController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // M3U
  final _m3uUrlController = TextEditingController();

  bool _passwordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _xtreamServerController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _m3uUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportCubit>();
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<ImportCubit, ImportState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            title: Text(
              l10n.addPlaylist,
              style: textTheme.titleLarge?.copyWith(color: p.fg),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab selector
                  _TabSelector(
                    selected: state.tab,
                    onSelect: cubit.selectTab,
                    palette: p,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 24),

                  // Tab-specific fields
                  if (state.tab == ImportTab.xtream) ...[
                    _TextField(
                      controller: _nameController,
                      label: l10n.playlistName,
                      palette: p,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _xtreamServerController,
                      label: l10n.serverUrl,
                      palette: p,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _usernameController,
                      label: l10n.username,
                      palette: p,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      style: textTheme.bodyLarge?.copyWith(color: p.fg),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        labelStyle: textTheme.bodyMedium?.copyWith(color: p.dim),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: p.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: p.accent, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: p.surface2,
                        suffixIcon: Semantics(
                          label: _passwordVisible
                              ? 'Hide password'
                              : 'Show password',
                          child: IconButton(
                            tooltip: _passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: p.dim,
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else if (state.tab == ImportTab.m3u) ...[
                    _TextField(
                      controller: _nameController,
                      label: l10n.playlistName,
                      palette: p,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _m3uUrlController,
                      label: l10n.m3uUrl,
                      palette: p,
                      textTheme: textTheme,
                    ),
                  ] else ...[
                    _TextField(
                      controller: _nameController,
                      label: l10n.playlistName,
                      palette: p,
                      textTheme: textTheme,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Error text
                  if (state.error != null) ...[
                    Text(
                      state.error!,
                      style: textTheme.bodyMedium?.copyWith(color: p.live),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  FocusableButton(
                    semanticLabel: l10n.importAction,
                    onPressed: state.submitting
                        ? () {}
                        : () => _handleSubmit(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: state.submitting ? p.surface2 : p.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: state.submitting
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.fg,
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                l10n.importAction,
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSubmit(BuildContext context, ImportState state) {
    final cubit = context.read<ImportCubit>();
    final name = _nameController.text.trim();

    switch (state.tab) {
      case ImportTab.xtream:
        cubit.submit(
          name: name.isEmpty ? _xtreamServerController.text.trim() : name,
          serverUrl: _xtreamServerController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      case ImportTab.m3u:
        cubit.submit(
          name: name,
          serverUrl: _m3uUrlController.text.trim(),
        );
      case ImportTab.upload:
        cubit.submit(
          name: name,
        );
    }
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.selected,
    required this.onSelect,
    required this.palette,
    required this.textTheme,
  });

  final ImportTab selected;
  final void Function(ImportTab) onSelect;
  final AppPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      (ImportTab.xtream, 'Xtream Codes'),
      (ImportTab.m3u, 'M3U URL'),
      (ImportTab.upload, l10n.tabUpload),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: tabs.map((entry) {
          final (tab, label) = entry;
          final isSelected = selected == tab;
          return Expanded(
            child: FocusableButton(
              semanticLabel: label,
              onPressed: () => onSelect(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? p.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected ? Colors.black : p.fg,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.palette,
    required this.textTheme,
  });

  final TextEditingController controller;
  final String label;
  final AppPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return TextFormField(
      controller: controller,
      style: textTheme.bodyLarge?.copyWith(color: p.fg),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.dim),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.border),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.accent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: p.surface2,
      ),
    );
  }
}
