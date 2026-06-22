import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Brand name
              Text(
                'NOOR',
                style: textTheme.displayLarge?.copyWith(
                  color: p.fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Value proposition
              Text(
                'Your playlists. Your content. Beautifully organized.',
                style: textTheme.titleMedium?.copyWith(color: p.dim),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Compliance statement
              Text(
                'NOOR hosts no content. All channels and media come from playlists you provide.',
                style: textTheme.bodySmall?.copyWith(color: p.dim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Get Started button
              FocusableButton(
                semanticLabel: 'Get Started',
                onPressed: onGetStarted,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Get Started',
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
