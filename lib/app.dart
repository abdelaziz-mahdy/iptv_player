import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/a11y/accessibility_cubit.dart';
import 'core/a11y/accessibility_settings.dart';
import 'core/i18n/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

/// Application root.
///
/// Provides the [AccessibilityCubit] and [LocaleCubit], then rebuilds the
/// [MaterialApp.router] whenever either changes — applying the high-contrast
/// palette, the high-legibility font, the global text scale, reduce-motion,
/// and RTL/LTR direction derived from those settings.
class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AccessibilityCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<AccessibilityCubit, AccessibilitySettings>(
            builder: (context, a11y) {
              final rtl = locale.languageCode == 'ar';
              final palette = a11y.highContrast ? AppPalette.highContrast : AppPalette.standard;
              return MaterialApp.router(
                debugShowCheckedModeBanner: false,
                routerConfig: router,
                locale: locale,
                theme: buildTheme(palette: palette, hyperlegible: a11y.hyperlegibleFont, rtl: rtl),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(
                      textScaler: TextScaler.linear(a11y.textScale),
                      disableAnimations: a11y.reduceMotion,
                    ),
                    child: Directionality(
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: child!,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
