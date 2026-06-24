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
