import 'package:flutter/material.dart';

/// A titled horizontal scroller of [items] — the building block of the Home
/// screen's content rows.
class ContentRail extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const ContentRail({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => items[i],
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}
