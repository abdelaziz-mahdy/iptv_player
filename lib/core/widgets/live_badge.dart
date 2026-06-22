import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The red "LIVE" badge from the prototype. The leading dot pulses, unless
/// [reduceMotion] is set (accessibility), in which case it stays static and
/// starts no animation ticker.
class LiveBadge extends StatefulWidget {
  final String label;
  final bool reduceMotion;
  const LiveBadge({super.key, required this.label, this.reduceMotion = false});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.palette.live,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _c == null ? dot : FadeTransition(opacity: _c!, child: dot),
          const SizedBox(width: 5),
          Text(
            widget.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
