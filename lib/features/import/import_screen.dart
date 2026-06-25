import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_text_field/native_textfield_tv.dart';
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
  final _nameController = NativeTextFieldController();

  // Xtream
  final _xtreamServerController = NativeTextFieldController();
  final _usernameController = NativeTextFieldController();
  final _passwordController = NativeTextFieldController();

  // M3U
  final _m3uUrlController = NativeTextFieldController();

  // Stable FocusNodes — created once and reused across rebuilds so D-pad /
  // IME focus doesn't churn on Android TV.
  final _nameFocus = FocusNode();
  final _serverFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _m3uUrlFocus = FocusNode();

  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    // Give the remote a focus anchor ON a field when the screen opens, so
    // D-pad navigation can reach/move between the native TV fields. Without an
    // initial field focus the remote has nothing to traverse from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _xtreamServerController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _m3uUrlController.dispose();
    _nameFocus.dispose();
    _serverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _m3uUrlFocus.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportCubit>();
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: p.bg,
      // On Android TV the IME is an overlay; resizing the body when it opens
      // caused a relayout→focus→IME loop. Don't resize for the keyboard.
      resizeToAvoidBottomInset: false,
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
              BlocSelector<ImportCubit, ImportState, ImportTab>(
                selector: (state) => state.tab,
                builder: (context, tab) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TabSelector(
                        selected: tab,
                        onSelect: cubit.selectTab,
                        palette: p,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 24),
                      ..._fieldsForTab(tab, p, textTheme, l10n),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Error + submit rebuild independently of the fields.
              BlocBuilder<ImportCubit, ImportState>(
                buildWhen: (a, b) =>
                    a.submitting != b.submitting || a.error != b.error,
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.error != null) ...[
                        Text(
                          state.error!,
                          style: textTheme.bodyMedium?.copyWith(color: p.live),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _submitButton(context, state, p, textTheme, l10n),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fieldsForTab(
    ImportTab tab,
    AppPalette p,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    switch (tab) {
      case ImportTab.xtream:
        return [
          _field(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            p: p,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _field(
            key: const ValueKey('import-server'),
            controller: _xtreamServerController,
            focusNode: _serverFocus,
            label: l10n.serverUrl,
            p: p,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _field(
            key: const ValueKey('import-username'),
            controller: _usernameController,
            focusNode: _usernameFocus,
            label: l10n.username,
            p: p,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _field(
            key: const ValueKey('import-password'),
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: l10n.password,
            p: p,
            textTheme: textTheme,
            obscure: true,
            suffix: Semantics(
              label: _passwordVisible ? 'Hide password' : 'Show password',
              child: IconButton(
                tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  color: p.dim,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          ),
        ];
      case ImportTab.m3u:
        return [
          _field(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            p: p,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),
          _field(
            key: const ValueKey('import-m3u'),
            controller: _m3uUrlController,
            focusNode: _m3uUrlFocus,
            label: l10n.m3uUrl,
            p: p,
            textTheme: textTheme,
          ),
        ];
      case ImportTab.upload:
        return [
          _field(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            p: p,
            textTheme: textTheme,
          ),
        ];
    }
  }

  /// Returns an adaptive text field.
  ///
  /// On Android: native [AndroidTVTextField] for full D-pad support.
  /// On other platforms: a standard editable [TextFormField].
  Widget _field({
    Key? key,
    required NativeTextFieldController controller,
    required FocusNode focusNode,
    required String label,
    required AppPalette p,
    required TextTheme textTheme,
    bool obscure = false,
    Widget? suffix,
  }) {
    if (Platform.isAndroid) {
      return AndroidTVTextField(
        key: key,
        focusNode: focusNode,
        controller: controller,
        hint: label,
        height: 64,
        obscureText: obscure,
        showPasswordToggle: obscure,
        backgroundColor: p.surface2,
        textColor: p.fg,
        focusedBorderColor: p.accent,
        unfocusedBorderColor: p.border,
      );
    }
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure && !_passwordVisible,
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
        suffixIcon: suffix,
      ),
    );
  }

  Widget _submitButton(
    BuildContext context,
    ImportState state,
    AppPalette p,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    return FocusableButton(
      semanticLabel: l10n.importAction,
      onPressed:
          state.submitting ? () {} : () => _handleSubmit(context, state),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

// ── Tab selector (unchanged) ───────────────────────────────────────────────

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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
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
