import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The header every main section shares.
///
/// Each tab used to build its own — or fake one with padding, or skip it — so
/// the title moved as you switched tabs.
class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppBar(
      backgroundColor: p.bg2,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: p.fg,
              fontWeight: FontWeight.w700,
            ),
      ),
      actions: actions,
    );
  }
}
