import 'package:flutter/material.dart';

/// Temporary screen shown for shell branches until the real feature screens
/// (built in their own plans) replace it.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(title, style: Theme.of(context).textTheme.headlineMedium));
}
