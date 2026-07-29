import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../a11y/accessibility_cubit.dart';
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
/// up to 1.04 via [AnimatedScale].
///
/// The scale is skipped when the user has asked for reduced motion. That is
/// read from [AccessibilityCubit] here rather than passed in: as a parameter
/// it defaulted to "animate" and not one of the ~36 call sites ever set it, so
/// the setting did nothing at all.
class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final bool autofocus;

  /// Overrides the user's reduced-motion setting. Only for tests and previews.
  final bool? reduceMotion;
  final FocusNode? focusNode;

  const FocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.reduceMotion,
    this.focusNode,
  });

  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  bool _focused = false;

  /// The cubit is absent in widget tests that pump a single screen, so fall
  /// back to animating rather than failing to build.
  bool get _reduceMotion {
    if (widget.reduceMotion != null) return widget.reduceMotion!;
    try {
      return context.watch<AccessibilityCubit>().state.reduceMotion;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusedScale = _reduceMotion ? 1.0 : (_focused ? 1.04 : 1.0);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
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
            // foregroundDecoration paints the focus ring OVER the child. The
            // 3 px inner padding keeps the ring in a gutter around the content
            // instead of covering its edges (reserved even when unfocused so
            // gaining focus never shifts layout).
            child: Container(
              padding: const EdgeInsets.all(3),
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
