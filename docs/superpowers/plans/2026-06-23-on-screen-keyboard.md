# On-Screen Keyboard (Android TV D-pad) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable in-app D-pad-navigable on-screen keyboard widget and integrate it into the import form so text entry works on Android TV without relying on the system IME (which is broken at the engine level — flutter#147772).

**Architecture:** A pure stateful widget `OnScreenKeyboard` renders rows of `FocusableButton` keys that the D-pad can navigate between; modes (lowercase/uppercase/symbols) are tracked internally. The import screen tracks an `_activeController` pointer and wires its `onChar`/`onBackspace`/`onClear` callbacks to whichever field is "selected". Fields are made `readOnly: true` so the system IME never opens; tapping/focusing a field sets it as active and gives it an accent border.

**Tech Stack:** Flutter 3.x, Dart 3.12+, `FocusableButton` (already exists), `AppPalette` theme tokens via `context.palette`, `flutter_test` for widget tests.

## Global Constraints

- Branch: `build/noor-foundation` — do NOT switch.
- Only edit: `lib/core/widgets/on_screen_keyboard.dart` (new), `lib/features/import/import_screen.dart`, and `test/` files.
- Flutter SDK `^3.12.2`.
- All fields must be `readOnly: true` (no system IME).
- Every keyboard key must be a `FocusableButton` — not `ElevatedButton` or `InkWell`.
- Key minimum touch target: 44 px height (TV-friendly).
- `Scaffold(resizeToAvoidBottomInset: false)` must remain.
- `_handleSubmit` logic must remain unchanged.
- Password visibility eye must remain, toggling `obscureText` independently of `readOnly`.
- All existing tests (`test/features/import/import_screen_test.dart`, `test/core/widgets/`) must keep passing.
- Commit identity: `git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com"`.
- Commit message: `feat(tv): in-app on-screen keyboard + read-only import fields (bypass engine D-pad bug)`.
- Report to `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-osk-report.md`.

---

## File Map

| Path | Status | Responsibility |
|------|--------|----------------|
| `lib/core/widgets/on_screen_keyboard.dart` | **Create** | Pure OSK widget — rows of `FocusableButton` keys, three modes (lower/upper/symbols) |
| `lib/features/import/import_screen.dart` | **Modify** | Read-only fields, `_activeController`, active-field highlighting, embedded `OnScreenKeyboard` |
| `test/core/widgets/on_screen_keyboard_test.dart` | **Create** | Unit/widget tests for OSK: tap letter, Shift, Backspace, symbol mode |
| `test/features/import/import_screen_test.dart` | **Modify** | Extend: field is read-only, tapping field + keys updates text; adjust focus-retention test |

---

### Task 1: Create `OnScreenKeyboard` widget with tests (TDD)

**Files:**
- Create: `lib/core/widgets/on_screen_keyboard.dart`
- Create: `test/core/widgets/on_screen_keyboard_test.dart`

**Interfaces:**
- Produces: `class OnScreenKeyboard extends StatefulWidget` with constructor `OnScreenKeyboard({super.key, required void Function(String) onChar, required VoidCallback onBackspace, VoidCallback? onClear})`

---

- [ ] **Step 1.1 — Write the failing tests**

Create `test/core/widgets/on_screen_keyboard_test.dart` with this full content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/on_screen_keyboard.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('tapping letter key calls onChar with that letter', (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // 'a' must be visible on the lowercase layer (default)
    await tester.tap(find.text('a').first);
    await tester.pump();

    expect(received, 'a');
  });

  testWidgets('Shift toggles uppercase and letter key calls onChar uppercase',
      (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Tap Shift to switch to uppercase layer
    await tester.tap(find.text('⇧').first);
    await tester.pump();

    // Now 'A' should be visible
    await tester.tap(find.text('A').first);
    await tester.pump();

    expect(received, 'A');
  });

  testWidgets('Backspace calls onBackspace', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () => called = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('⌫').first);
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('?123 toggles to symbol layer with digit keys', (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Tap ?123 to open symbol layer
    await tester.tap(find.text('?123').first);
    await tester.pump();

    // Digit '1' must be visible in symbol layer
    await tester.tap(find.text('1').first);
    await tester.pump();

    expect(received, '1');
  });

  testWidgets('Clear button calls onClear when provided', (tester) async {
    var cleared = false;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () {},
      onClear: () => cleared = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear').first);
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets('all letter key widgets have semanticLabel set', (tester) async {
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Verify semantics — at least 'a' has a label
    final semantics = tester.getSemantics(find.text('a').first);
    expect(semantics.label, isNotEmpty);
  });
}
```

- [ ] **Step 1.2 — Run tests to confirm they fail (import error expected)**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/core/widgets/on_screen_keyboard_test.dart 2>&1 | head -30
```

Expected output: error like `Target of URI doesn't exist: 'package:noor_iptv/core/widgets/on_screen_keyboard.dart'`

- [ ] **Step 1.3 — Implement `OnScreenKeyboard`**

Create `lib/core/widgets/on_screen_keyboard.dart` with this exact content:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'focusable_button.dart';

enum _KbMode { lower, upper, symbols }

/// A fully in-app, D-pad-navigable on-screen keyboard for Android TV.
///
/// Every key is a [FocusableButton] so the remote D-pad can navigate between
/// keys and press Select/Enter/GameButtonA to type — no system IME needed.
///
/// [onChar] receives a single character string to insert.
/// [onBackspace] is called when the Backspace key is pressed.
/// [onClear] is called when the Clear key is pressed (optional).
class OnScreenKeyboard extends StatefulWidget {
  final void Function(String char) onChar;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;

  const OnScreenKeyboard({
    super.key,
    required this.onChar,
    required this.onBackspace,
    this.onClear,
  });

  @override
  State<OnScreenKeyboard> createState() => _OnScreenKeyboardState();
}

class _OnScreenKeyboardState extends State<OnScreenKeyboard> {
  _KbMode _mode = _KbMode.lower;

  // ── Key definitions ────────────────────────────────────────────────────

  static const _lowerRows = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const _upperRows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const _symbolRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['.', ':', '/', '@', '-', '_', '+', '?', '='],
    ['&', '%', 'http://', '.com'],
  ];

  // ── Helpers ────────────────────────────────────────────────────────────

  List<List<String>> get _letterRows =>
      _mode == _KbMode.upper ? _upperRows : _lowerRows;

  void _toggleShift() => setState(() {
        _mode = _mode == _KbMode.upper ? _KbMode.lower : _KbMode.upper;
      });

  void _toggleSymbols() => setState(() {
        _mode = _mode == _KbMode.symbols ? _KbMode.lower : _KbMode.symbols;
      });

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      color: p.bg2,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._buildLetterOrSymbolRows(context),
          const SizedBox(height: 4),
          _buildControlRow(context),
        ],
      ),
    );
  }

  List<Widget> _buildLetterOrSymbolRows(BuildContext context) {
    final rows = _mode == _KbMode.symbols ? _symbolRows : _letterRows;
    return rows.map((row) => _buildRow(context, row)).toList();
  }

  Widget _buildRow(BuildContext context, List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((k) => _buildKey(context, k)).toList(),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String label) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    // Wider keys for multi-char convenience strings
    final isWide = label.length > 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FocusableButton(
        semanticLabel: label,
        onPressed: () => widget.onChar(label),
        child: Container(
          constraints: BoxConstraints(
            minWidth: isWide ? 72 : 36,
            minHeight: 44,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: p.fg),
          ),
        ),
      ),
    );
  }

  Widget _buildControlRow(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // Helper for control-key styling (slightly different background)
    Widget ctrlKey({
      required String label,
      required VoidCallback onPressed,
      double minWidth = 56,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FocusableButton(
          semanticLabel: label,
          onPressed: onPressed,
          child: Container(
            constraints: BoxConstraints(minWidth: minWidth, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: p.fg),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shift (only relevant on letter layers)
        if (_mode != _KbMode.symbols)
          ctrlKey(
            label: '⇧',
            onPressed: _toggleShift,
          ),
        // ?123 / ABC toggle
        ctrlKey(
          label: _mode == _KbMode.symbols ? 'ABC' : '?123',
          onPressed: _toggleSymbols,
          minWidth: 60,
        ),
        // Space
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FocusableButton(
            semanticLabel: 'Space',
            onPressed: () => widget.onChar(' '),
            child: Container(
              constraints: const BoxConstraints(minWidth: 140, minHeight: 44),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'Space',
                style: textTheme.bodyMedium?.copyWith(color: p.dim),
              ),
            ),
          ),
        ),
        // Backspace
        ctrlKey(label: '⌫', onPressed: widget.onBackspace),
        // Clear (only shown when callback provided)
        if (widget.onClear != null)
          ctrlKey(label: 'Clear', onPressed: widget.onClear!),
      ],
    );
  }
}
```

- [ ] **Step 1.4 — Run tests and verify they pass**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/core/widgets/on_screen_keyboard_test.dart --reporter=expanded 2>&1
```

Expected: all 6 tests PASS. If any fail, fix the implementation (do NOT change the tests).

- [ ] **Step 1.5 — Run analyzer on the new file**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter analyze lib/core/widgets/on_screen_keyboard.dart 2>&1
```

Expected: `No issues found!`

---

### Task 2: Refactor `import_screen.dart` — read-only fields + active-field + embedded keyboard

**Files:**
- Modify: `lib/features/import/import_screen.dart`

**Interfaces:**
- Consumes: `OnScreenKeyboard({required void Function(String) onChar, required VoidCallback onBackspace, VoidCallback? onClear})` from Task 1.
- Produces: modified `_ImportViewState` with `TextEditingController? _activeController`, each field `readOnly: true`, accent border when active, `OnScreenKeyboard` embedded in the scroll view above the Import button.

---

- [ ] **Step 2.1 — Replace the full `import_screen.dart`**

Replace `lib/features/import/import_screen.dart` with this content:

```dart
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

  @override
  void initState() {
    super.initState();
    _activeController = _nameController;
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
                  // When the tab changes, reset the active controller to name.
                  // Use addPostFrameCallback to avoid setState during build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _activeController != _nameController) {
                      setState(() => _activeController = _nameController);
                    }
                  });
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
```

- [ ] **Step 2.2 — Run analyzer on the modified file**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter analyze lib/features/import/import_screen.dart lib/core/widgets/on_screen_keyboard.dart 2>&1
```

Expected: `No issues found!`

---

### Task 3: Update import screen tests + run the full suite

**Files:**
- Modify: `test/features/import/import_screen_test.dart`

---

- [ ] **Step 3.1 — Replace `test/features/import/import_screen_test.dart`**

Replace with this content (keeps the 3 passing tests; adjusts the focus-retention test for read-only fields; adds OSK-integration tests):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/import/import_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ImportScreen)))!;

Widget _app() => MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ImportScreen(onImported: () {}),
    );

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('ImportScreen renders 3 tab buttons', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('M3U URL'), findsOneWidget);
    expect(find.text(_l10n(tester).tabUpload), findsOneWidget);
  });

  testWidgets('server field is read-only (system IME cannot open)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final serverField = find.byKey(const ValueKey('import-server'));
    expect(serverField, findsOneWidget);

    // The EditableText inside the field must be readOnly
    final editable = tester.widget<EditableText>(
      find.descendant(of: serverField, matching: find.byType(EditableText)),
    );
    expect(editable.readOnly, isTrue,
        reason: 'Field must be read-only so the system IME never opens');
  });

  testWidgets(
      'tapping server field then keyboard keys updates server field text',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // 1. Tap the server field to make it the active keyboard target
    final serverField = find.byKey(const ValueKey('import-server'));
    await tester.tap(serverField);
    await tester.pump();

    // 2. Tap 'a' on the on-screen keyboard (lowercase layer, default)
    await tester.tap(find.text('a').first);
    await tester.pump();

    // 3. Switch to symbol layer and tap '1'
    await tester.tap(find.text('?123').first);
    await tester.pump();
    await tester.tap(find.text('1').first);
    await tester.pump();

    // 4. Assert the server field now shows 'a1'
    final editableAfter = tester.widget<EditableText>(
      find.descendant(of: serverField, matching: find.byType(EditableText)),
    );
    expect(editableAfter.controller.text, 'a1',
        reason: 'On-screen keyboard must append chars to the active field');
  });

  testWidgets(
      'field keeps focus across a rebuild (TV focus-loop regression — read-only variant)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tap the server field to activate it (also focuses it).
    final serverField = find.byKey(const ValueKey('import-server'));
    expect(serverField, findsOneWidget);
    await tester.tap(serverField);
    await tester.pump();

    // The field's FocusNode should have focus
    EditableText editable() => tester.widget<EditableText>(
          find.descendant(of: serverField, matching: find.byType(EditableText)),
        );
    expect(editable().focusNode.hasFocus, isTrue,
        reason: 'field should hold focus after tapping it');

    // Trigger a rebuild via the password eye toggle — field must keep focus.
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(editable().focusNode.hasFocus, isTrue,
        reason: 'field must retain focus across an unrelated rebuild');
  });

  testWidgets('ImportScreen renders Import button', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).importAction), findsWidgets);
  });
}
```

- [ ] **Step 3.2 — Run all import and widget tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/core/widgets test/features/import --reporter=expanded 2>&1
```

Expected: all tests PASS (green). If any fail, investigate and fix `import_screen.dart` or `on_screen_keyboard.dart` — do NOT relax assertions.

- [ ] **Step 3.3 — Run the full test suite to catch regressions**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test --reporter=expanded 2>&1
```

Expected: all tests PASS.

- [ ] **Step 3.4 — Run analyzer across the whole project**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter analyze 2>&1
```

Expected: `No issues found!`

---

### Task 4: Commit and report

- [ ] **Step 4.1 — Stage all changes**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/core/widgets/on_screen_keyboard.dart lib/features/import/import_screen.dart test/core/widgets/on_screen_keyboard_test.dart test/features/import/import_screen_test.dart docs/superpowers/plans/2026-06-23-on-screen-keyboard.md
```

- [ ] **Step 4.2 — Commit**

If `git index.lock` exists, wait 3 seconds and retry once.

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): in-app on-screen keyboard + read-only import fields (bypass engine D-pad bug)

Claude-Session: https://claude.ai/code/session_01FWbJLHscs2umzGHwQfPDkW"
```

- [ ] **Step 4.3 — Write report**

Create `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-osk-report.md` with:

```markdown
# OSK Implementation Report

**Status:** DONE  
**Commit:** <insert actual hash from `git rev-parse --short HEAD`>  
**Tests:** <N> tests in test/core/widgets + test/features/import — all PASS  
**Concerns:** None — all fields are read-only, OnScreenKeyboard uses FocusableButton throughout, _handleSubmit is unchanged.
```

Then reply to the parent with: status, commit hash, one-line test summary, and any concerns.

---

## Self-Review

### Spec coverage check

| Requirement | Covered by |
|---|---|
| `OnScreenKeyboard` widget in `lib/core/widgets/on_screen_keyboard.dart` | Task 1 |
| `onChar`, `onBackspace`, `onClear` callbacks | Task 1 (Step 1.3 constructor) |
| QWERTY lowercase rows | Task 1 (`_lowerRows`) |
| Shift/caps uppercase toggle | Task 1 (`_toggleShift`, `_upperRows`) |
| `?123` symbols layer with digits 0-9 and `. : / @ - _ + ? = & %` | Task 1 (`_symbolRows`) |
| `http://` and `.com` convenience keys | Task 1 (`_symbolRows` row 3) |
| Space key | Task 1 (control row) |
| Backspace key calls `onBackspace` | Task 1 (control row + test) |
| Clear key calls `onClear` | Task 1 (control row + test) |
| Every key is a `FocusableButton` | Task 1 (all keys wrapped) |
| Minimum 44px key height | Task 1 (`minHeight: 44`) |
| `semanticLabel` on every key | Task 1 (all `FocusableButton` calls have `semanticLabel`) |
| All fields `readOnly: true` | Task 2 (`_ReadOnlyField`, `_ReadOnlyPasswordField`) |
| `_activeController` tracks active field | Task 2 (`_activateField`) |
| Accent border on active field | Task 2 (`isActive` → `activeBorder`) |
| `OSK` wired: `onChar` appends, `onBackspace` deletes, `onClear` clears | Task 2 (`_oskChar`, `_oskBackspace`, `_oskClear`) |
| Password visibility eye preserved | Task 2 (`_ReadOnlyPasswordField.onToggleVisibility`) |
| `resizeToAvoidBottomInset: false` | Task 2 (Scaffold) |
| `_handleSubmit` unchanged | Task 2 (copied verbatim) |
| `test/core/widgets/on_screen_keyboard_test.dart` — 6 test cases | Task 1 (Step 1.1) |
| `test/features/import/import_screen_test.dart` — readOnly assertion | Task 3 (`server field is read-only` test) |
| Import screen test: tap field, tap keys, assert text | Task 3 (`tapping server field then keyboard keys…`) |
| Existing import tests kept passing | Task 3 (all 3 original tests preserved + adjusted focus test) |
| Commit with correct identity and message | Task 4 |
| Report to `.superpowers/sdd/b-osk-report.md` | Task 4 |

### Placeholder scan

No TBDs, no "fill in later", no "similar to" references. All code blocks are complete.

### Type consistency

- `OnScreenKeyboard.onChar: void Function(String)` — used as `widget.onChar(label)` / `widget.onChar(c)` consistently.
- `OnScreenKeyboard.onBackspace: VoidCallback` — used as `widget.onBackspace()`.
- `OnScreenKeyboard.onClear: VoidCallback?` — guarded with null check before use.
- `_activeController: TextEditingController?` — null-checked in all three OSK helpers.
- `_ReadOnlyField` / `_ReadOnlyPasswordField` params match their call sites in `_fieldsForTab`.
