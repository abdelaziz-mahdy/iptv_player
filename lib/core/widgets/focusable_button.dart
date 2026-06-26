import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A button that shows a high-contrast focus ring when focused — for TV remote /
/// D-pad navigation — and exposes a semantics label for screen readers.
///
/// Responds to Enter, Space, Select, and GameButtonA (TV remote centre/select)
/// in addition to tap, so it works correctly with Android TV D-pad navigation.
///
/// ### Focus ring
/// When focused, renders a 3 px `context.palette.fg` border via
/// [foregroundDecoration] (does NOT affect layout size) PLUS scales the widget
/// up to 1.04 via [AnimatedScale] (skipped when [reduceMotion] is true).
///
/// Pass [reduceMotion] from `AccessibilityCubit().state.reduceMotion`.
class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final bool autofocus;
  final bool reduceMotion;

  const FocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.reduceMotion = false,
  });

  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final focusedScale = widget.reduceMotion ? 1.0 : (_focused ? 1.04 : 1.0);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (f) {
          if (_focused == f) return;
          setState(() => _focused = f);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: AnimatedScale(
          scale: focusedScale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: widget.onPressed,
            // foregroundDecoration paints the focus ring OVER the child without
            // adding to layout size, so wrapping fixed-width widgets (e.g. EPG
            // cells) doesn't shift or overflow their layout.
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focused ? context.palette.fg : Colors.transparent,
                  width: 3,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
