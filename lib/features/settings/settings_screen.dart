import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/a11y/accessibility_settings.dart';
import 'package:noor_iptv/core/i18n/locale_cubit.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

/// Settings & Accessibility screen for NOOR IPTV.
///
/// Reads [AccessibilityCubit] and [LocaleCubit] via [BlocBuilder] and exposes:
/// - Language selector (EN / عربي)
/// - Display toggles: High contrast, Reduce motion, Colorblind-safe, High-legibility font
/// - Text size selector (Default / Large / Larger)
/// - Captions section: on/off, size, background opacity, color
/// - Compliance note at the bottom
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: context.palette.surface,
        foregroundColor: context.palette.fg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          const _SectionHeader(title: 'Language'),
          const SizedBox(height: 8),
          const _LanguageSelector(),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.accessibility),
          const SizedBox(height: 8),
          const _DisplayToggles(),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Text size'),
          const SizedBox(height: 8),
          const _TextSizeSelector(),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Captions'),
          const SizedBox(height: 8),
          const _CaptionsSection(),
          const SizedBox(height: 32),
          const _ComplianceNote(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.palette.dim,
            letterSpacing: 0.8,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language selector
// ---------------------------------------------------------------------------

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (ctx, locale) {
        final isEn = locale.languageCode == 'en';
        return Semantics(
          label: 'Language selector',
          child: Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                _LangChip(
                  label: 'EN',
                  selected: isEn,
                  onTap: () => ctx.read<LocaleCubit>().setEnglish(),
                  semanticLabel: 'English',
                ),
                _LangChip(
                  label: 'عربي',
                  selected: !isEn,
                  onTap: () => ctx.read<LocaleCubit>().setArabic(),
                  semanticLabel: 'Arabic',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? context.palette.bg
                          : context.palette.fg,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display toggles
// ---------------------------------------------------------------------------

class _DisplayToggles extends StatelessWidget {
  const _DisplayToggles();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessibilityCubit, AccessibilitySettings>(
      builder: (ctx, state) {
        return Material(
          color: context.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.palette.border),
          ),
          child: Column(
            children: [
              _ToggleRow(
                label: 'High contrast',
                value: state.highContrast,
                onChanged: (_) => ctx.read<AccessibilityCubit>().toggleHighContrast(),
                semanticLabel: 'High contrast mode',
                isFirst: true,
              ),
              const _Divider(),
              _ToggleRow(
                label: 'Reduce motion',
                value: state.reduceMotion,
                onChanged: (_) => ctx.read<AccessibilityCubit>().toggleReduceMotion(),
                semanticLabel: 'Reduce motion',
              ),
              const _Divider(),
              _ToggleRow(
                label: 'Colorblind-safe palette',
                value: state.colorblindSafe,
                onChanged: (_) => ctx.read<AccessibilityCubit>().toggleColorblindSafe(),
                semanticLabel: 'Colorblind-safe palette',
              ),
              const _Divider(),
              _ToggleRow(
                label: 'High-legibility font',
                value: state.hyperlegibleFont,
                onChanged: (_) => ctx.read<AccessibilityCubit>().toggleHyperlegible(),
                semanticLabel: 'High-legibility font',
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;
  final bool isFirst;
  final bool isLast;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: SwitchListTile(
        title: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.palette.fg),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: context.palette.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(14) : Radius.zero,
            bottom: isLast ? const Radius.circular(14) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: context.palette.border,
    );
  }
}

// ---------------------------------------------------------------------------
// Text size selector
// ---------------------------------------------------------------------------

class _TextSizeSelector extends StatelessWidget {
  const _TextSizeSelector();

  static const _options = [
    (label: 'Default', value: 1.0),
    (label: 'Large', value: 1.25),
    (label: 'Larger', value: 1.5),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessibilityCubit, AccessibilitySettings>(
      builder: (ctx, state) {
        return Semantics(
          label: 'Text size selector',
          child: Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: _options.map((opt) {
                final selected = state.textScale == opt.value;
                return _SegmentChip(
                  label: opt.label,
                  selected: selected,
                  onTap: () => ctx.read<AccessibilityCubit>().setTextScale(opt.value),
                  semanticLabel: 'Text size ${opt.label}',
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? context.palette.bg
                          : context.palette.fg,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Captions section
// ---------------------------------------------------------------------------

class _CaptionsSection extends StatelessWidget {
  const _CaptionsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessibilityCubit, AccessibilitySettings>(
      builder: (ctx, state) {
        return Material(
          color: context.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Captions on/off toggle
              Semantics(
                label: 'Captions on/off',
                toggled: state.captionsOn,
                child: SwitchListTile(
                  title: Text(
                    'Captions',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.palette.fg),
                  ),
                  value: state.captionsOn,
                  onChanged: (_) => ctx.read<AccessibilityCubit>().toggleCaptions(),
                  activeThumbColor: context.palette.accent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
              ),
              if (state.captionsOn) ...[
                const _Divider(),
                const _SubSectionLabel(title: 'Size'),
                _CaptionSizeRow(currentSize: state.captionSize, ctx: ctx),
                const _Divider(),
                const _SubSectionLabel(title: 'Background'),
                _CaptionBgRow(currentOpacity: state.captionBgOpacity, ctx: ctx),
                const _Divider(),
                const _SubSectionLabel(title: 'Color'),
                _CaptionColorRow(currentColor: state.captionColor, ctx: ctx),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  final String title;
  const _SubSectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.dim,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _CaptionSizeRow extends StatelessWidget {
  final double currentSize;
  final BuildContext ctx;

  static const _options = [
    (label: 'Small', value: 18.0),
    (label: 'Medium', value: 24.0),
    (label: 'Large', value: 32.0),
  ];

  const _CaptionSizeRow({required this.currentSize, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Semantics(
        label: 'Caption size selector',
        child: Row(
          children: _options.map((opt) {
            final selected = currentSize == opt.value;
            return Expanded(
              child: Semantics(
                label: 'Caption size ${opt.label}',
                selected: selected,
                button: true,
                child: GestureDetector(
                  onTap: () => ctx.read<AccessibilityCubit>().setCaptionSize(opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.palette.accent
                          : context.palette.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        opt.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? context.palette.bg
                                  : context.palette.fg,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CaptionBgRow extends StatelessWidget {
  final double currentOpacity;
  final BuildContext ctx;

  static const _options = [
    (label: 'None', value: 0.0),
    (label: 'Light', value: 0.45),
    (label: 'Solid', value: 0.85),
  ];

  const _CaptionBgRow({required this.currentOpacity, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Semantics(
        label: 'Caption background selector',
        child: Row(
          children: _options.map((opt) {
            final selected = currentOpacity == opt.value;
            return Expanded(
              child: Semantics(
                label: 'Caption background ${opt.label}',
                selected: selected,
                button: true,
                child: GestureDetector(
                  onTap: () => ctx.read<AccessibilityCubit>().setCaptionBg(opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.palette.accent
                          : context.palette.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        opt.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? context.palette.bg
                                  : context.palette.fg,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CaptionColorRow extends StatelessWidget {
  final int currentColor;
  final BuildContext ctx;

  static const _options = [
    (label: 'White', value: 0xFFFFFFFF, color: Color(0xFFFFFFFF)),
    (label: 'Yellow', value: 0xFFFFE23D, color: Color(0xFFFFE23D)),
    (label: 'Cyan', value: 0xFF5EE7FF, color: Color(0xFF5EE7FF)),
  ];

  const _CaptionColorRow({required this.currentColor, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Semantics(
        label: 'Caption color selector',
        child: Row(
          children: _options.map((opt) {
            final selected = currentColor == opt.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Semantics(
                label: 'Caption color ${opt.label}',
                selected: selected,
                button: true,
                child: GestureDetector(
                  onTap: () => ctx.read<AccessibilityCubit>().setCaptionColor(opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: opt.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? context.palette.accent
                            : context.palette.border,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compliance note
// ---------------------------------------------------------------------------

class _ComplianceNote extends StatelessWidget {
  const _ComplianceNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'NOOR hosts no content. All channels and media come from playlists you provide.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.dim,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
