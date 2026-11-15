import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Calls [onHidden] when the section holding [child] stops being the visible
/// one.
///
/// The shell keeps every section alive in an IndexedStack and turns tickers
/// off for the hidden ones, so a [TickerMode] change is the signal.
class OnSectionHidden extends StatefulWidget {
  const OnSectionHidden({
    super.key,
    required this.onHidden,
    required this.child,
  });

  final VoidCallback onHidden;
  final Widget child;

  @override
  State<OnSectionHidden> createState() => _OnSectionHiddenState();
}

class _OnSectionHiddenState extends State<OnSectionHidden> {
  ValueListenable<TickerModeData>? _mode;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = TickerMode.getValuesNotifier(context);
    if (mode == _mode) return;
    _mode?.removeListener(_onModeChanged);
    _mode = mode..addListener(_onModeChanged);
    _visible = mode.value.enabled;
  }

  void _onModeChanged() {
    final visible = _mode!.value.enabled;
    if (_visible && !visible) widget.onHidden();
    _visible = visible;
  }

  @override
  void dispose() {
    _mode?.removeListener(_onModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
