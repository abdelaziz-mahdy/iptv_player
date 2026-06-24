import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/on_screen_keyboard.dart';
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

  // Stable FocusNodes — created once and reused across rebuilds so D-pad /
  // IME focus doesn't churn on Android TV.
  final _nameFocus = FocusNode();
  final _serverFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _m3uUrlFocus = FocusNode();

  bool _passwordVisible = false;

  /// The controller whose text the on-screen keyboard edits.
  /// Defaults to [_nameController] for all tabs; tapping a field updates this.
  TextEditingController? _activeController;

  /// Tracks the last-rendered tab so we only reset [_activeController] when
  /// the tab actually changes, not on every unrelated rebuild.
  ImportTab? _lastTab;

  @override
  void initState() {
    super.initState();
    _activeController = _nameController;
    // Unify "D-pad focus" with "keyboard target": whenever a field gains focus
    // (via remote D-pad or tap) it becomes the field the on-screen keyboard
    // types into. This makes navigating to a field and then down to the
    // keyboard behave naturally on Android TV.
    _wireActiveOnFocus(_nameFocus, _nameController);
    _wireActiveOnFocus(_serverFocus, _xtreamServerController);
    _wireActiveOnFocus(_usernameFocus, _usernameController);
    _wireActiveOnFocus(_passwordFocus, _passwordController);
    _wireActiveOnFocus(_m3uUrlFocus, _m3uUrlController);
  }

  void _wireActiveOnFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (node.hasFocus && _activeController != controller) {
        setState(() => _activeController = controller);
      }
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

  // ── OSK helpers ────────────────────────────────────────────────────────

  void _oskChar(String c) {
    final ctrl = _activeController;
    if (ctrl == null) return;
    final t = ctrl.text + c;
    ctrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _oskBackspace() {
    final ctrl = _activeController;
    if (ctrl == null || ctrl.text.isEmpty) return;
    final t = ctrl.text.substring(0, ctrl.text.length - 1);
    ctrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _oskClear() {
    _activeController?.clear();
  }

  void _activateField(TextEditingController controller, FocusNode node) {
    setState(() => _activeController = controller);
    node.requestFocus();
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
                  // Only reset the active controller when the tab changes,
                  // not on arbitrary rebuilds (e.g. field activation triggers
                  // setState which would re-run this builder and incorrectly
                  // reset the active field back to name).
                  if (_lastTab != tab) {
                    _lastTab = tab;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _activeController = _nameController);
                      }
                    });
                  }
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
              // ── On-screen keyboard ──────────────────────────────────────
              OnScreenKeyboard(
                onChar: _oskChar,
                onBackspace: _oskBackspace,
                onClear: _oskClear,
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
          _ReadOnlyField(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _nameController,
            onActivate: () => _activateField(_nameController, _nameFocus),
          ),
          const SizedBox(height: 16),
          _ReadOnlyField(
            key: const ValueKey('import-server'),
            controller: _xtreamServerController,
            focusNode: _serverFocus,
            label: l10n.serverUrl,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _xtreamServerController,
            onActivate: () =>
                _activateField(_xtreamServerController, _serverFocus),
          ),
          const SizedBox(height: 16),
          _ReadOnlyField(
            key: const ValueKey('import-username'),
            controller: _usernameController,
            focusNode: _usernameFocus,
            label: l10n.username,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _usernameController,
            onActivate: () =>
                _activateField(_usernameController, _usernameFocus),
          ),
          const SizedBox(height: 16),
          _ReadOnlyPasswordField(
            key: const ValueKey('import-password'),
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: l10n.password,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _passwordController,
            passwordVisible: _passwordVisible,
            onActivate: () =>
                _activateField(_passwordController, _passwordFocus),
            onToggleVisibility: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
        ];
      case ImportTab.m3u:
        return [
          _ReadOnlyField(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _nameController,
            onActivate: () => _activateField(_nameController, _nameFocus),
          ),
          const SizedBox(height: 16),
          _ReadOnlyField(
            key: const ValueKey('import-m3u'),
            controller: _m3uUrlController,
            focusNode: _m3uUrlFocus,
            label: l10n.m3uUrl,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _m3uUrlController,
            onActivate: () =>
                _activateField(_m3uUrlController, _m3uUrlFocus),
          ),
        ];
      case ImportTab.upload:
        return [
          _ReadOnlyField(
            key: const ValueKey('import-name'),
            controller: _nameController,
            focusNode: _nameFocus,
            label: l10n.playlistName,
            palette: p,
            textTheme: textTheme,
            isActive: _activeController == _nameController,
            onActivate: () => _activateField(_nameController, _nameFocus),
          ),
        ];
    }
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

// ── Read-only field (replaces _TextField) ──────────────────────────────────

/// A [TextFormField] that is always `readOnly: true` (system IME never opens).
/// Tapping it calls [onActivate], which the parent uses to set the keyboard
/// target. When [isActive] is true an accent border is shown.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    super.key,
    required this.controller,
    required this.label,
    required this.palette,
    required this.textTheme,
    required this.isActive,
    required this.onActivate,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final AppPalette palette;
  final TextTheme textTheme;
  final bool isActive;
  final VoidCallback onActivate;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final activeBorder = OutlineInputBorder(
      borderSide: BorderSide(color: p.accent, width: 2),
      borderRadius: BorderRadius.circular(8),
    );
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      showCursor: true,
      enableInteractiveSelection: false,
      onTap: onActivate,
      style: textTheme.bodyLarge?.copyWith(color: p.fg),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.dim),
        enabledBorder: isActive
            ? activeBorder
            : OutlineInputBorder(
                borderSide: BorderSide(color: p.border),
                borderRadius: BorderRadius.circular(8),
              ),
        focusedBorder: activeBorder,
        filled: true,
        fillColor: p.surface2,
      ),
    );
  }
}

// ── Read-only password field ───────────────────────────────────────────────

class _ReadOnlyPasswordField extends StatelessWidget {
  const _ReadOnlyPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.palette,
    required this.textTheme,
    required this.isActive,
    required this.passwordVisible,
    required this.onActivate,
    required this.onToggleVisibility,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final AppPalette palette;
  final TextTheme textTheme;
  final bool isActive;
  final bool passwordVisible;
  final VoidCallback onActivate;
  final VoidCallback onToggleVisibility;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final activeBorder = OutlineInputBorder(
      borderSide: BorderSide(color: p.accent, width: 2),
      borderRadius: BorderRadius.circular(8),
    );
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !passwordVisible,
      readOnly: true,
      showCursor: true,
      enableInteractiveSelection: false,
      onTap: onActivate,
      style: textTheme.bodyLarge?.copyWith(color: p.fg),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.dim),
        enabledBorder: isActive
            ? activeBorder
            : OutlineInputBorder(
                borderSide: BorderSide(color: p.border),
                borderRadius: BorderRadius.circular(8),
              ),
        focusedBorder: activeBorder,
        filled: true,
        fillColor: p.surface2,
        suffixIcon: Semantics(
          label: passwordVisible ? 'Hide password' : 'Show password',
          child: IconButton(
            tooltip: passwordVisible ? 'Hide password' : 'Show password',
            icon: Icon(
              passwordVisible ? Icons.visibility_off : Icons.visibility,
              color: p.dim,
            ),
            onPressed: onToggleVisibility,
          ),
        ),
      ),
    );
  }
}
