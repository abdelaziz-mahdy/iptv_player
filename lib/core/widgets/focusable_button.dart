import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A button that shows a high-contrast focus ring (the prototype's `--focus`
/// outline) when focused — for TV remote / D-pad navigation — and exposes a
/// semantics label for screen readers.
class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;
  const FocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
  });

  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? context.palette.focus : Colors.transparent,
                width: 3,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
