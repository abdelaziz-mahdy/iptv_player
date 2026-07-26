import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'focusable_button.dart';

/// Bucket key for titles that do not start with a Latin letter.
const String kOtherLetter = '#';

/// The letters offered by the picker, in order.
const List<String> kJumpLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  kOtherLetter,
];

/// First index in [titles] for each leading letter.
///
/// Built from the list as displayed, so it works whatever order the provider
/// returned — picking "S" lands on the first S-titled item, not on a position
/// that assumes the list is sorted.
Map<String, int> buildLetterIndex(List<String> titles) {
  final index = <String, int>{};
  for (var i = 0; i < titles.length; i++) {
    final t = titles[i].trimLeft();
    if (t.isEmpty) continue;
    final c = t[0].toUpperCase();
    final letter = RegExp(r'[A-Z]').hasMatch(c) ? c : kOtherLetter;
    index.putIfAbsent(letter, () => i);
  }
  return index;
}

/// Asks the user for a letter. Returns null when dismissed.
///
/// Letters absent from [available] are shown dimmed and are not focus stops,
/// so a D-pad never lands on a dead end.
Future<String?> showJumpToLetter(
  BuildContext context, {
  required Set<String> available,
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final p = context.palette;
      final firstEnabled = kJumpLetters.firstWhere(
        available.contains,
        orElse: () => '',
      );
      return AlertDialog(
        backgroundColor: p.bg2,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: p.fg),
        ),
        content: SizedBox(
          width: 420,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final letter in kJumpLetters)
                _LetterKey(
                  letter: letter,
                  enabled: available.contains(letter),
                  autofocus: letter == firstEnabled,
                  onPressed: () => Navigator.of(context).pop(letter),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _LetterKey extends StatelessWidget {
  const _LetterKey({
    required this.letter,
    required this.enabled,
    required this.autofocus,
    required this.onPressed,
  });

  final String letter;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final box = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? p.surface : p.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: enabled ? p.fg : p.dim,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
    if (!enabled) return ExcludeFocus(child: box);
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: letter,
      onPressed: onPressed,
      child: box,
    );
  }
}
