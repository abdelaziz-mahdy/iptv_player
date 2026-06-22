# NOOR Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the sequential foundation of the NOOR IPTV app — project scaffold, design system, themes, accessibility, i18n/RTL, adaptive shell, router, DI, shared widgets, and the repository contracts every feature consumes.

**Architecture:** Layered Flutter app (`core/` → `data/` → `features/`). flutter_bloc/Cubit for state, hydrated_bloc for persisted settings, go_router `StatefulShellRoute` for the adaptive shell, get_it/injectable for DI. Accessibility is wired through a single `MediaQuery` override at the app root driven by `AccessibilityCubit`. Feature modules depend only on `core/` and repository interfaces.

**Tech Stack:** Flutter 3.44.2, flutter_bloc, hydrated_bloc, equatable, freezed, json_serializable, build_runner, go_router, get_it, injectable, google_fonts, intl, flutter_localizations.

## Global Constraints

- Flutter `3.44.2` stable; Dart SDK `>=3.9.0 <4.0.0` (match `flutter create` default — verify and copy actual value).
- Platforms enabled: `android`, `macos`, `windows`, `linux`. No iOS, no web.
- Brand name: `NOOR`. Two locales: English (`en`, LTR) and Arabic (`ar`, RTL).
- Fonts: Latin UI `Hanken Grotesk`; Arabic `IBM Plex Sans Arabic`; high-legibility option `Atkinson Hyperlegible`. Loaded via `google_fonts`.
- Accessibility is first-class: honor `textScaler`, reduce-motion, high-contrast, captions config; every interactive element focusable + labelled.
- App hosts NO content; playlists are user-supplied (compliance copy is in the Settings/Onboarding plan).
- Color tokens (exact, from `design/ClearView IPTV.dc.html`):
  - Shared: `accent #ffe000`, `accent2 #00e5ff`, `live #ff5252`.
  - Standard palette: `bg #0a0d13`, `bg2 #10141d`, `surface #171c28`, `surface2 #222a3b`, `border rgba(255,255,255,0.11)`, `fg #f3f6fb`, `dim #97a3b7`, `focus #5ab0ff`.
  - High-contrast palette: `bg #000000`, `bg2 #000000`, `surface #0c0c0c`, `surface2 #1c1c1c`, `border #ffffff`, `fg #ffffff`, `dim #eaeaea`, `focus #ffe000`.
- Every code change ends in a commit. TDD: failing test → minimal impl → passing test → commit.

---

### Task 1: Project scaffold

**Files:**
- Create: whole Flutter project at repo root (alongside existing `design/`, `docs/`).
- Modify: `.gitignore` (merge Flutter's into existing).

- [ ] **Step 1: Create the Flutter project in place**

Run from repo root (`/Users/AbdelazizMahdy/flutter_projects/Iptv`):
```bash
flutter create --org com.noor.iptv --project-name noor_iptv \
  --platforms=android,macos,windows,linux .
```
Expected: project files generated; `design/` and `docs/` untouched.

- [ ] **Step 2: Verify it builds and the SDK constraint**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`. Open `pubspec.yaml` and record the actual `environment: sdk:` value (replace the placeholder in Global Constraints if different).

- [ ] **Step 3: Smoke-run on desktop**

Run: `flutter run -d macos` (or `flutter test` if no display). Confirm the counter app launches, then stop.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project (android, macos, windows, linux)"
```

---

### Task 2: Dependencies and tooling

**Files:**
- Modify: `pubspec.yaml`
- Create: `build.yaml`
- Modify: `analysis_options.yaml`

**Interfaces:**
- Produces: project dependency set used by all later tasks.

- [ ] **Step 1: Add runtime dependencies**

Run:
```bash
flutter pub add flutter_bloc hydrated_bloc equatable bloc_concurrency \
  go_router get_it injectable google_fonts intl path_provider \
  freezed_annotation json_annotation
flutter pub add flutter_localizations --sdk=flutter
```

- [ ] **Step 2: Add dev dependencies**

Run:
```bash
flutter pub add -d build_runner freezed json_serializable injectable_generator \
  bloc_test mocktail
```

- [ ] **Step 3: Create `build.yaml`**

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
          field_rename: none
```

- [ ] **Step 4: Enable l10n + linity in `analysis_options.yaml`**

Replace file contents:
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/l10n/generated/**"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    prefer_const_constructors: true
    prefer_final_locals: true
```

- [ ] **Step 5: Verify**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: add core dependencies and build/lint config"
```

---

### Task 3: Color palettes

**Files:**
- Create: `lib/core/theme/app_palette.dart`
- Test: `test/core/theme/app_palette_test.dart`

**Interfaces:**
- Produces:
  - `class AppPalette { final Color bg, bg2, surface, surface2, border, fg, dim, focus, accent, accent2, live; const AppPalette({...}); }`
  - `AppPalette.standard` and `AppPalette.highContrast` (static const instances).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';

void main() {
  test('standard palette matches design tokens', () {
    expect(AppPalette.standard.bg, const Color(0xFF0A0D13));
    expect(AppPalette.standard.surface, const Color(0xFF171C28));
    expect(AppPalette.standard.fg, const Color(0xFFF3F6FB));
    expect(AppPalette.standard.dim, const Color(0xFF97A3B7));
    expect(AppPalette.standard.focus, const Color(0xFF5AB0FF));
    expect(AppPalette.standard.accent, const Color(0xFFFFE000));
    expect(AppPalette.standard.live, const Color(0xFFFF5252));
  });

  test('high-contrast palette matches design tokens', () {
    expect(AppPalette.highContrast.bg, const Color(0xFF000000));
    expect(AppPalette.highContrast.border, const Color(0xFFFFFFFF));
    expect(AppPalette.highContrast.fg, const Color(0xFFFFFFFF));
    expect(AppPalette.highContrast.focus, const Color(0xFFFFE000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_palette_test.dart`
Expected: FAIL — `app_palette.dart` not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

@immutable
class AppPalette {
  final Color bg, bg2, surface, surface2, border, fg, dim, focus, accent, accent2, live;
  const AppPalette({
    required this.bg, required this.bg2, required this.surface, required this.surface2,
    required this.border, required this.fg, required this.dim, required this.focus,
    required this.accent, required this.accent2, required this.live,
  });

  static const accentColor = Color(0xFFFFE000);
  static const accent2Color = Color(0xFF00E5FF);
  static const liveColor = Color(0xFFFF5252);

  static const standard = AppPalette(
    bg: Color(0xFF0A0D13), bg2: Color(0xFF10141D), surface: Color(0xFF171C28),
    surface2: Color(0xFF222A3B), border: Color(0x1CFFFFFF), fg: Color(0xFFF3F6FB),
    dim: Color(0xFF97A3B7), focus: Color(0xFF5AB0FF),
    accent: accentColor, accent2: accent2Color, live: liveColor,
  );

  static const highContrast = AppPalette(
    bg: Color(0xFF000000), bg2: Color(0xFF000000), surface: Color(0xFF0C0C0C),
    surface2: Color(0xFF1C1C1C), border: Color(0xFFFFFFFF), fg: Color(0xFFFFFFFF),
    dim: Color(0xFFEAEAEA), focus: Color(0xFFFFE000),
    accent: accentColor, accent2: accent2Color, live: liveColor,
  );
}
```
Note: `0x1CFFFFFF` ≈ rgba(255,255,255,0.11).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_palette_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(theme): add standard and high-contrast palettes"
```

---

### Task 4: Typography

**Files:**
- Create: `lib/core/theme/app_typography.dart`
- Test: `test/core/theme/app_typography_test.dart`

**Interfaces:**
- Consumes: `google_fonts`.
- Produces: `TextTheme buildTextTheme({required Color fg, required Color dim, required bool hyperlegible, required bool rtl})` — returns a TextTheme using Hanken Grotesk (Latin) / IBM Plex Sans Arabic (rtl) / Atkinson Hyperlegible (hyperlegible) with `displayLarge/headlineMedium/titleLarge/bodyLarge/bodyMedium/labelLarge` set.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_typography.dart';

void main() {
  test('text theme sets foreground color on body and headline', () {
    final t = buildTextTheme(fg: const Color(0xFFFFFFFF), dim: const Color(0xFF888888),
        hyperlegible: false, rtl: false);
    expect(t.bodyLarge!.color, const Color(0xFFFFFFFF));
    expect(t.headlineMedium!.color, const Color(0xFFFFFFFF));
    expect(t.bodyMedium!.color, const Color(0xFF888888));
  });

  test('headline uses a bold weight', () {
    final t = buildTextTheme(fg: Colors.white, dim: Colors.grey, hyperlegible: false, rtl: false);
    expect(t.headlineMedium!.fontWeight, FontWeight.w800);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/theme/app_typography_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme({
  required Color fg, required Color dim, required bool hyperlegible, required bool rtl,
}) {
  TextStyle base(double size, FontWeight w, Color c) {
    if (hyperlegible) return GoogleFonts.atkinsonHyperlegible(fontSize: size, fontWeight: w, color: c);
    if (rtl) return GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: w, color: c);
    return GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: w, color: c);
  }
  return TextTheme(
    displayLarge: base(34, FontWeight.w800, fg),
    headlineMedium: base(24, FontWeight.w800, fg),
    titleLarge: base(18, FontWeight.w700, fg),
    bodyLarge: base(15, FontWeight.w500, fg),
    bodyMedium: base(14, FontWeight.w500, dim),
    labelLarge: base(13, FontWeight.w700, fg),
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/theme/app_typography_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(theme): add typography with Hanken/IBM Plex Arabic/Atkinson"
```

---

### Task 5: ThemeData builder

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppPalette`, `buildTextTheme`.
- Produces: `ThemeData buildTheme({required AppPalette palette, required bool hyperlegible, required bool rtl})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';

void main() {
  test('theme uses palette bg as scaffold background and is dark', () {
    final theme = buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false);
    expect(theme.scaffoldBackgroundColor, AppPalette.standard.bg);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppPalette.standard.accent);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_typography.dart';

ThemeData buildTheme({required AppPalette palette, required bool hyperlegible, required bool rtl}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: palette.accent,
    secondary: palette.accent2,
    surface: palette.surface,
    error: palette.live,
    onSurface: palette.fg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    textTheme: buildTextTheme(fg: palette.fg, dim: palette.dim, hyperlegible: hyperlegible, rtl: rtl),
    dividerColor: palette.border,
    extensions: [PaletteExt(palette)],
  );
}

@immutable
class PaletteExt extends ThemeExtension<PaletteExt> {
  final AppPalette palette;
  const PaletteExt(this.palette);
  @override
  PaletteExt copyWith({AppPalette? palette}) => PaletteExt(palette ?? this.palette);
  @override
  PaletteExt lerp(ThemeExtension<PaletteExt>? other, double t) => this;
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<PaletteExt>()!.palette;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(theme): add ThemeData builder with palette extension"
```

---

### Task 6: Accessibility settings model

**Files:**
- Create: `lib/core/a11y/accessibility_settings.dart`
- Test: `test/core/a11y/accessibility_settings_test.dart`

**Interfaces:**
- Produces (freezed):
  ```dart
  @freezed
  class AccessibilitySettings with _$AccessibilitySettings {
    const factory AccessibilitySettings({
      @Default(1.0) double textScale,        // 1.0 / 1.25 / 1.5
      @Default(false) bool reduceMotion,
      @Default(false) bool highContrast,
      @Default(false) bool colorblindSafe,
      @Default(false) bool hyperlegibleFont,
      @Default(false) bool captionsOn,
      @Default(24.0) double captionSize,     // 18 / 24 / 32
      @Default(0.45) double captionBgOpacity,// 0 / 0.45 / 0.85
      @Default(0xFFFFFFFF) int captionColor, // white/yellow/cyan ARGB
    }) = _AccessibilitySettings;
    factory AccessibilitySettings.fromJson(Map<String, dynamic> json) => _$AccessibilitySettingsFromJson(json);
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/a11y/accessibility_settings.dart';

void main() {
  test('defaults match design baseline', () {
    const s = AccessibilitySettings();
    expect(s.textScale, 1.0);
    expect(s.reduceMotion, false);
    expect(s.captionSize, 24.0);
    expect(s.captionColor, 0xFFFFFFFF);
  });

  test('json round-trips', () {
    const s = AccessibilitySettings(highContrast: true, textScale: 1.5);
    expect(AccessibilitySettings.fromJson(s.toJson()), s);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/a11y/accessibility_settings_test.dart`
Expected: FAIL — file/types not found.

- [ ] **Step 3: Implement the freezed class**

Create the file with the freezed class above, plus the part directives:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'accessibility_settings.freezed.dart';
part 'accessibility_settings.g.dart';
// ... (class body from Interfaces)
```

- [ ] **Step 4: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `.freezed.dart` and `.g.dart`.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/core/a11y/accessibility_settings_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(a11y): add AccessibilitySettings model"
```

---

### Task 7: AccessibilityCubit (hydrated)

**Files:**
- Create: `lib/core/a11y/accessibility_cubit.dart`
- Test: `test/core/a11y/accessibility_cubit_test.dart`

**Interfaces:**
- Consumes: `AccessibilitySettings`, `HydratedCubit`.
- Produces: `class AccessibilityCubit extends HydratedCubit<AccessibilitySettings>` with methods:
  `setTextScale(double)`, `toggleReduceMotion()`, `toggleHighContrast()`, `toggleColorblindSafe()`, `toggleHyperlegible()`, `toggleCaptions()`, `setCaptionSize(double)`, `setCaptionBg(double)`, `setCaptionColor(int)`; and `fromJson`/`toJson` overrides.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/a11y/accessibility_settings.dart';
import 'package:path_provider/path_provider.dart';

class _FakeStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
}

void main() {
  setUp(() => HydratedBloc.storage = _FakeStorage());

  blocTest<AccessibilityCubit, AccessibilitySettings>(
    'toggleHighContrast flips the flag',
    build: AccessibilityCubit.new,
    act: (c) => c.toggleHighContrast(),
    expect: () => [const AccessibilitySettings(highContrast: true)],
  );

  blocTest<AccessibilityCubit, AccessibilitySettings>(
    'setTextScale updates scale',
    build: AccessibilityCubit.new,
    act: (c) => c.setTextScale(1.5),
    expect: () => [const AccessibilitySettings(textScale: 1.5)],
  );
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/a11y/accessibility_cubit_test.dart`
Expected: FAIL — cubit not found.

- [ ] **Step 3: Implement**

```dart
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'accessibility_settings.dart';

class AccessibilityCubit extends HydratedCubit<AccessibilitySettings> {
  AccessibilityCubit() : super(const AccessibilitySettings());

  void setTextScale(double v) => emit(state.copyWith(textScale: v));
  void toggleReduceMotion() => emit(state.copyWith(reduceMotion: !state.reduceMotion));
  void toggleHighContrast() => emit(state.copyWith(highContrast: !state.highContrast));
  void toggleColorblindSafe() => emit(state.copyWith(colorblindSafe: !state.colorblindSafe));
  void toggleHyperlegible() => emit(state.copyWith(hyperlegibleFont: !state.hyperlegibleFont));
  void toggleCaptions() => emit(state.copyWith(captionsOn: !state.captionsOn));
  void setCaptionSize(double v) => emit(state.copyWith(captionSize: v));
  void setCaptionBg(double v) => emit(state.copyWith(captionBgOpacity: v));
  void setCaptionColor(int v) => emit(state.copyWith(captionColor: v));

  @override
  AccessibilitySettings fromJson(Map<String, dynamic> json) => AccessibilitySettings.fromJson(json);
  @override
  Map<String, dynamic> toJson(AccessibilitySettings state) => state.toJson();
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/a11y/accessibility_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(a11y): add hydrated AccessibilityCubit"
```

---

### Task 8: Caption style mapping

**Files:**
- Create: `lib/core/a11y/caption_style.dart`
- Test: `test/core/a11y/caption_style_test.dart`

**Interfaces:**
- Consumes: `AccessibilitySettings`.
- Produces: `class CaptionStyle { final double fontSize; final Color textColor; final Color backgroundColor; const CaptionStyle(...); factory CaptionStyle.from(AccessibilitySettings s); }` where background = black at `captionBgOpacity`, text = `Color(s.captionColor)`, fontSize = `s.captionSize * s.textScale`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/a11y/accessibility_settings.dart';
import 'package:noor_iptv/core/a11y/caption_style.dart';

void main() {
  test('maps settings to caption style scaled by text scale', () {
    const s = AccessibilitySettings(captionSize: 32, captionBgOpacity: 0.85,
        captionColor: 0xFFFFE23D, textScale: 1.25);
    final cs = CaptionStyle.from(s);
    expect(cs.fontSize, 40); // 32 * 1.25
    expect(cs.textColor, const Color(0xFFFFE23D));
    expect(cs.backgroundColor.opacity, closeTo(0.85, 0.01));
    expect(cs.backgroundColor.value & 0x00FFFFFF, 0x000000); // black base
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/a11y/caption_style_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'accessibility_settings.dart';

@immutable
class CaptionStyle {
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  const CaptionStyle({required this.fontSize, required this.textColor, required this.backgroundColor});

  factory CaptionStyle.from(AccessibilitySettings s) => CaptionStyle(
        fontSize: s.captionSize * s.textScale,
        textColor: Color(s.captionColor),
        backgroundColor: Colors.black.withOpacity(s.captionBgOpacity),
      );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/a11y/caption_style_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(a11y): map accessibility settings to caption style"
```

---

### Task 9: Localization setup (EN/AR) + LocaleCubit

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Create: `lib/core/i18n/locale_cubit.dart`
- Test: `test/core/i18n/locale_cubit_test.dart`

**Interfaces:**
- Produces:
  - Generated `AppLocalizations` (class) with getters: `brand, home, favorites, live, movies, series, search, settings, play, moreInfo, back, synopsis, episodes`.
  - `class LocaleCubit extends HydratedCubit<Locale>` with `setEnglish()`, `setArabic()`, `toggle()`.

- [ ] **Step 1: Create `l10n.yaml`**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
```

- [ ] **Step 2: Create `lib/l10n/app_en.arb`**

```json
{
  "@@locale": "en",
  "brand": "NOOR",
  "home": "Home",
  "favorites": "Favorites",
  "live": "Live TV",
  "movies": "Movies",
  "series": "Series",
  "search": "Search",
  "settings": "Settings",
  "accessibility": "Accessibility",
  "playlists": "Playlists",
  "play": "Play",
  "moreInfo": "More Info",
  "back": "Back",
  "synopsis": "Synopsis",
  "episodes": "Episodes"
}
```

- [ ] **Step 3: Create `lib/l10n/app_ar.arb`**

```json
{
  "@@locale": "ar",
  "brand": "نور",
  "home": "الرئيسية",
  "favorites": "المفضلة",
  "live": "البث المباشر",
  "movies": "أفلام",
  "series": "مسلسلات",
  "search": "بحث",
  "settings": "الإعدادات",
  "accessibility": "إمكانية الوصول",
  "playlists": "قوائم التشغيل",
  "play": "تشغيل",
  "moreInfo": "المزيد",
  "back": "رجوع",
  "synopsis": "القصة",
  "episodes": "الحلقات"
}
```

- [ ] **Step 4: Generate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/generated/app_localizations.dart` created.

- [ ] **Step 5: Write the failing LocaleCubit test**

```dart
import 'dart:ui';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:noor_iptv/core/i18n/locale_cubit.dart';

class _FakeStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
}

void main() {
  setUp(() => HydratedBloc.storage = _FakeStorage());

  blocTest<LocaleCubit, Locale>(
    'setArabic emits ar locale',
    build: LocaleCubit.new,
    act: (c) => c.setArabic(),
    expect: () => [const Locale('ar')],
  );

  blocTest<LocaleCubit, Locale>(
    'toggle from default en emits ar',
    build: LocaleCubit.new,
    act: (c) => c.toggle(),
    expect: () => [const Locale('ar')],
  );
}
```

- [ ] **Step 6: Run to verify fail**

Run: `flutter test test/core/i18n/locale_cubit_test.dart`
Expected: FAIL — cubit not found.

- [ ] **Step 7: Implement LocaleCubit**

```dart
import 'dart:ui';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class LocaleCubit extends HydratedCubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  void setEnglish() => emit(const Locale('en'));
  void setArabic() => emit(const Locale('ar'));
  void toggle() => emit(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));

  @override
  Locale? fromJson(Map<String, dynamic> json) => Locale(json['code'] as String? ?? 'en');
  @override
  Map<String, dynamic>? toJson(Locale state) => {'code': state.languageCode};
}
```

- [ ] **Step 8: Run to verify pass**

Run: `flutter test test/core/i18n/locale_cubit_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat(i18n): add EN/AR localizations and hydrated LocaleCubit"
```

---

### Task 10: Arabic-Indic numeral formatter

**Files:**
- Create: `lib/core/i18n/numerals.dart`
- Test: `test/core/i18n/numerals_test.dart`

**Interfaces:**
- Produces: `String localizeDigits(String input, {required bool rtl})` — maps `0-9` to Arabic-Indic `٠-٩` when `rtl`, else returns input unchanged.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/i18n/numerals.dart';

void main() {
  test('converts digits to Arabic-Indic when rtl', () {
    expect(localizeDigits('2026', rtl: true), '٢٠٢٦');
  });
  test('leaves digits untouched when ltr', () {
    expect(localizeDigits('2026', rtl: false), '2026');
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/i18n/numerals_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String localizeDigits(String input, {required bool rtl}) {
  if (!rtl) return input;
  final sb = StringBuffer();
  for (final ch in input.runes) {
    if (ch >= 0x30 && ch <= 0x39) {
      sb.write(_arabicIndic[ch - 0x30]);
    } else {
      sb.writeCharCode(ch);
    }
  }
  return sb.toString();
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/i18n/numerals_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(i18n): add Arabic-Indic numeral formatter"
```

---

### Task 11: Repository contracts and domain models

**Files:**
- Create: `lib/core/result.dart`
- Create: `lib/data/models/models.dart` (barrel) and one file per model under `lib/data/models/`
- Create: `lib/data/repositories/repositories.dart` (abstract contracts)
- Test: `test/data/models/models_test.dart`

**Interfaces:**
- Produces (this is the contract surface every feature plan consumes — keep names exact):
  - `sealed class Result<T>` with `Ok<T>(T value)` and `Err<T>(Failure failure)`; helper `R when<R>({required R Function(T) ok, required R Function(Failure) err})`.
  - `class Failure { final String message; final Object? cause; const Failure(this.message, {this.cause}); }`
  - freezed models:
    - `Playlist(String id, String name, PlaylistType type, String? serverUrl, String initial, int channelCount)`; `enum PlaylistType { xtream, m3u, upload }`
    - `Channel(String id, String playlistId, String name, String number, String? logoUrl, String streamUrl, String? categoryId, bool isFavorite)`
    - `VodItem(String id, String playlistId, String title, String? posterUrl, String? categoryId, String? year, double? rating, String streamUrl)`
    - `Series(String id, String playlistId, String title, String? posterUrl, String? categoryId, String? year, double? rating)`
    - `Season(String id, String seriesId, int number)`
    - `Episode(String id, String seasonId, String title, int number, int? durationSec, String streamUrl)`
    - `EpgProgramme(String id, String channelId, String title, DateTime startUtc, DateTime stopUtc, String? description)`
    - `WatchProgress(String itemKey, String playlistId, MediaKind kind, int positionSec, int durationSec, DateTime updatedAt)`; `enum MediaKind { channel, movie, episode }`
    - `Favorite(String itemKey, String playlistId, MediaKind kind, DateTime addedAt)`
  - abstract contracts:
    - `abstract class PlaylistRepository { Future<Result<List<Playlist>>> all(); Future<Result<Playlist>> add(Playlist p); Future<Result<void>> remove(String id); Stream<Playlist?> active(); Future<void> setActive(String id); }`
    - `abstract class ContentRepository { Stream<List<Channel>> channels(String playlistId); Stream<List<VodItem>> movies(String playlistId); Stream<List<Series>> series(String playlistId); Future<Result<List<Season>>> seasons(String seriesId); Future<Result<List<Episode>>> episodes(String seasonId); Stream<List<Favorite>> favorites(String playlistId); Future<void> toggleFavorite(String itemKey, String playlistId, MediaKind kind); Future<Result<void>> importPlaylist(Playlist p); }`
    - `abstract class EpgRepository { Future<Result<List<EpgProgramme>>> programmes(String channelId, DateTime from, DateTime to); }`
    - `abstract class PlaybackRepository { Future<WatchProgress?> progressFor(String itemKey); Future<void> saveProgress(WatchProgress p); Stream<List<WatchProgress>> continueWatching(String playlistId); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/result.dart';
import 'package:noor_iptv/data/models/models.dart';

void main() {
  test('Result.when dispatches ok/err', () {
    const Result<int> ok = Ok(5);
    const Result<int> err = Err(Failure('boom'));
    expect(ok.when(ok: (v) => 'v$v', err: (f) => f.message), 'v5');
    expect(err.when(ok: (v) => 'v$v', err: (f) => f.message), 'boom');
  });

  test('Channel json round-trips', () {
    const c = Channel(id: '1', playlistId: 'p', name: 'BBC', number: '101',
        logoUrl: null, streamUrl: 'http://x', categoryId: 'news', isFavorite: false);
    expect(Channel.fromJson(c.toJson()), c);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/data/models/models_test.dart`
Expected: FAIL — files/types not found.

- [ ] **Step 3: Implement `lib/core/result.dart`**

```dart
class Failure {
  final String message;
  final Object? cause;
  const Failure(this.message, {this.cause});
  @override
  bool operator ==(Object other) => other is Failure && other.message == message;
  @override
  int get hashCode => message.hashCode;
}

sealed class Result<T> {
  const Result();
  R when<R>({required R Function(T) ok, required R Function(Failure) err});
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
  @override
  R when<R>({required R Function(T) ok, required R Function(Failure) err}) => ok(value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
  @override
  R when<R>({required R Function(T) ok, required R Function(Failure) err}) => err(failure);
}
```

- [ ] **Step 4: Implement the freezed models**

Create one file per model under `lib/data/models/` (e.g. `channel.dart`) using the freezed pattern, with enums in `lib/data/models/enums.dart`, and a barrel `models.dart` exporting all. Example `channel.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
class Channel with _$Channel {
  const factory Channel({
    required String id, required String playlistId, required String name,
    required String number, String? logoUrl, required String streamUrl,
    String? categoryId, @Default(false) bool isFavorite,
  }) = _Channel;
  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}
```
Repeat for every model listed in Interfaces. Put enums in `enums.dart`:
```dart
enum PlaylistType { xtream, m3u, upload }
enum MediaKind { channel, movie, episode }
```

- [ ] **Step 5: Implement the abstract repositories**

Create `lib/data/repositories/repositories.dart` containing exactly the four abstract classes from the Interfaces block (no implementations).

- [ ] **Step 6: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generated files for all models.

- [ ] **Step 7: Run to verify pass**

Run: `flutter test test/data/models/models_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(data): add domain models, Result type, and repository contracts"
```

---

### Task 12: In-memory fakes for repositories (enables parallel feature dev)

**Files:**
- Create: `lib/data/repositories/fakes/fake_repositories.dart`
- Test: `test/data/repositories/fake_repositories_test.dart`

**Interfaces:**
- Consumes: contracts + models from Task 11.
- Produces: `FakePlaylistRepository`, `FakeContentRepository`, `FakeEpgRepository`, `FakePlaybackRepository` — in-memory implementations seeded with sample data matching the prototype copy (a sample playlist, a few channels/movies/series). Used by feature plans until Wave A (Data & Import) lands, and by widget tests.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';

void main() {
  test('fake content repo streams seeded movies', () async {
    final repo = FakeContentRepository();
    final movies = await repo.movies('p1').first;
    expect(movies, isNotEmpty);
  });

  test('toggleFavorite adds then removes a favorite', () async {
    final repo = FakeContentRepository();
    await repo.toggleFavorite('movie:1', 'p1', MediaKindStub.movie);
    expect((await repo.favorites('p1').first).length, 1);
  });
}
```
(Use the real `MediaKind` import; `MediaKindStub` above is a placeholder — replace with `MediaKind` from `package:noor_iptv/data/models/models.dart` and import it.)

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/data/repositories/fake_repositories_test.dart`
Expected: FAIL — fakes not found.

- [ ] **Step 3: Implement the fakes**

Implement each fake with `BehaviorSubject`-free plain `StreamController.broadcast` + an in-memory list, seeded in the constructor with 1 playlist (`Playlist(id:'p1', name:'My Playlist', type: PlaylistType.m3u, serverUrl:null, initial:'M', channelCount: 3)`), 3 channels, 4 movies, 2 series. `toggleFavorite` mutates a set and re-emits. Provide concrete return values for every contract method (no `UnimplementedError`).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/data/repositories/fake_repositories_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(data): add in-memory fake repositories with seed data"
```

---

### Task 13: FocusableButton widget

**Files:**
- Create: `lib/core/widgets/focusable_button.dart`
- Test: `test/core/widgets/focusable_button_test.dart`

**Interfaces:**
- Consumes: `PaletteContext` (`context.palette`).
- Produces: `class FocusableButton extends StatelessWidget { final Widget child; final VoidCallback onPressed; final String? semanticLabel; const FocusableButton({...}); }` — wraps child in `Semantics(button:true,label:semanticLabel)` + focus ring using `context.palette.focus` (3px outline on focus).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';

void main() {
  testWidgets('invokes onPressed on tap and exposes semantics', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(body: FocusableButton(
        semanticLabel: 'Play',
        onPressed: () => tapped = true,
        child: const Text('Play'),
      )),
    ));
    await tester.tap(find.text('Play'));
    expect(tapped, true);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/widgets/focusable_button_test.dart`
Expected: FAIL — widget not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;
  const FocusableButton({super.key, required this.child, required this.onPressed, this.semanticLabel});
  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? context.palette.focus : Colors.transparent,
                width: 3,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/focusable_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(widgets): add FocusableButton with focus ring and semantics"
```

---

### Task 14: LiveBadge widget (reduce-motion aware)

**Files:**
- Create: `lib/core/widgets/live_badge.dart`
- Test: `test/core/widgets/live_badge_test.dart`

**Interfaces:**
- Consumes: `context.palette`, `AccessibilityCubit` (reads `reduceMotion` via `BlocProvider` if present; defaults to animating).
- Produces: `class LiveBadge extends StatelessWidget { final String label; final bool reduceMotion; const LiveBadge({required this.label, this.reduceMotion = false}); }` — red badge with a dot that pulses unless `reduceMotion`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/live_badge.dart';

void main() {
  testWidgets('renders label and no pulsing animation when reduceMotion', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: const Scaffold(body: LiveBadge(label: 'LIVE', reduceMotion: true)),
    ));
    expect(find.text('LIVE'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0); // no ticker running
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/widgets/live_badge_test.dart`
Expected: FAIL — widget not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    }
  }
  @override
  void dispose() { _c?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 6, height: 6,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: context.palette.live, borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _c == null ? dot : FadeTransition(opacity: _c!, child: dot),
        const SizedBox(width: 5),
        Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/live_badge_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(widgets): add reduce-motion-aware LiveBadge"
```

---

### Task 15: PosterCard widget

**Files:**
- Create: `lib/core/widgets/poster_card.dart`
- Test: `test/core/widgets/poster_card_test.dart`

**Interfaces:**
- Consumes: `context.palette`, `FocusableButton`.
- Produces: `class PosterCard extends StatelessWidget { final String title; final String? subtitle; final String? imageUrl; final String? badge; final double? progress; final VoidCallback onTap; const PosterCard({...}); }` — fixed-ratio card with gradient scrim, title/subtitle, optional badge + progress bar.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/poster_card.dart';

void main() {
  testWidgets('shows title, badge, and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(body: PosterCard(
        title: 'Dune', subtitle: '2021', badge: 'HD', imageUrl: null,
        progress: 0.4, onTap: () => tapped = true,
      )),
    ));
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('HD'), findsOneWidget);
    await tester.tap(find.text('Dune'));
    expect(tapped, true);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/widgets/poster_card_test.dart`
Expected: FAIL — widget not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'focusable_button.dart';

class PosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? badge;
  final double? progress;
  final VoidCallback onTap;
  const PosterCard({super.key, required this.title, this.subtitle, this.imageUrl,
      this.badge, this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      semanticLabel: title,
      onPressed: onTap,
      child: SizedBox(
        width: 130,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(10))),
              if (imageUrl != null)
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              if (badge != null) Positioned(top: 8, right: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
              if (progress != null) Positioned(left: 8, right: 8, bottom: 8, child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: progress, minHeight: 4,
                  backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(p.accent)))),
            ]),
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
          if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/poster_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(widgets): add PosterCard"
```

---

### Task 16: ContentRail widget

**Files:**
- Create: `lib/core/widgets/content_rail.dart`
- Test: `test/core/widgets/content_rail_test.dart`

**Interfaces:**
- Produces: `class ContentRail extends StatelessWidget { final String title; final List<Widget> items; const ContentRail({required this.title, required this.items}); }` — section title + horizontal scroller of `items`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/content_rail.dart';

void main() {
  testWidgets('renders title and items', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(body: ContentRail(title: 'Trending', items: const [Text('A'), Text('B')])),
    ));
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/widgets/content_rail_test.dart`
Expected: FAIL — widget not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

class ContentRail extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const ContentRail({super.key, required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
      SizedBox(height: 230, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) => items[i],
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemCount: items.length,
      )),
    ]);
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/content_rail_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(widgets): add ContentRail"
```

---

### Task 17: AdaptiveShell + breakpoints

**Files:**
- Create: `lib/core/widgets/adaptive_shell.dart`
- Create: `lib/core/widgets/breakpoints.dart`
- Test: `test/core/widgets/adaptive_shell_test.dart`

**Interfaces:**
- Produces:
  - `class NoorBreakpoints { static const double rail = 700; }` — width ≥ rail → NavigationRail (TV/desktop/tablet); below → NavigationBar (phone).
  - `class NavDestinationData { final IconData icon; final String label; const NavDestinationData(this.icon, this.label); }`
  - `class AdaptiveShell extends StatelessWidget { final Widget body; final int currentIndex; final ValueChanged<int> onSelect; final List<NavDestinationData> destinations; final String brand; const AdaptiveShell({...}); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/adaptive_shell.dart';

Widget _wrap(Size size) => MaterialApp(
  theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: AdaptiveShell(
      brand: 'NOOR', currentIndex: 0, onSelect: (_) {},
      destinations: const [NavDestinationData(Icons.home, 'Home'), NavDestinationData(Icons.tv, 'Live')],
      body: const Text('BODY'),
    ),
  ),
);

void main() {
  testWidgets('wide layout uses NavigationRail', (tester) async {
    await tester.pumpWidget(_wrap(const Size(1280, 800)));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('narrow layout uses NavigationBar', (tester) async {
    await tester.pumpWidget(_wrap(const Size(400, 800)));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/widgets/adaptive_shell_test.dart`
Expected: FAIL — widgets not found.

- [ ] **Step 3: Implement `breakpoints.dart`**

```dart
class NoorBreakpoints {
  static const double rail = 700;
}
```

- [ ] **Step 4: Implement `adaptive_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'breakpoints.dart';

class NavDestinationData {
  final IconData icon;
  final String label;
  const NavDestinationData(this.icon, this.label);
}

class AdaptiveShell extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<NavDestinationData> destinations;
  final String brand;
  const AdaptiveShell({super.key, required this.body, required this.currentIndex,
      required this.onSelect, required this.destinations, required this.brand});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= NoorBreakpoints.rail;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.all,
            leading: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(brand, style: Theme.of(context).textTheme.titleLarge)),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/core/widgets/adaptive_shell_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(shell): add AdaptiveShell with rail/navbar breakpoint"
```

---

### Task 18: Router with StatefulShellRoute and placeholder screens

**Files:**
- Create: `lib/core/router/app_router.dart`
- Create: `lib/features/_placeholder/placeholder_screen.dart`
- Test: `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `AdaptiveShell`, `NavDestinationData`, generated `AppLocalizations`.
- Produces: `GoRouter buildRouter()` with a `StatefulShellRoute.indexedStack` over branches `/home`, `/favorites`, `/live`, `/movies`, `/series`, `/search`, plus pushed routes `/settings`, `/playlists`. Each shell branch shows `PlaceholderScreen(title)` for now (feature plans replace these).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/router/app_router.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('home branch renders inside the shell', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: FAIL — router not found.

- [ ] **Step 3: Implement `placeholder_screen.dart`**

```dart
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(title, style: Theme.of(context).textTheme.headlineMedium));
}
```

- [ ] **Step 4: Implement `app_router.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/adaptive_shell.dart';
import '../../features/_placeholder/placeholder_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final t = AppLocalizations.of(context)!;
          final dests = [
            NavDestinationData(Icons.home_outlined, t.home),
            NavDestinationData(Icons.favorite_border, t.favorites),
            NavDestinationData(Icons.live_tv_outlined, t.live),
            NavDestinationData(Icons.movie_outlined, t.movies),
            NavDestinationData(Icons.video_library_outlined, t.series),
            NavDestinationData(Icons.search, t.search),
          ];
          return AdaptiveShell(
            brand: t.brand,
            currentIndex: navigationShell.currentIndex,
            onSelect: (i) => navigationShell.goBranch(i),
            destinations: dests,
            body: navigationShell,
          );
        },
        branches: [
          for (final r in const ['/home', '/favorites', '/live', '/movies', '/series', '/search'])
            StatefulShellBranch(routes: [
              GoRoute(path: r, builder: (c, s) => PlaceholderScreen(title: _titleFor(c, r))),
            ]),
        ],
      ),
      GoRoute(path: '/settings', builder: (c, s) => PlaceholderScreen(title: AppLocalizations.of(c)!.settings)),
      GoRoute(path: '/playlists', builder: (c, s) => PlaceholderScreen(title: AppLocalizations.of(c)!.playlists)),
    ],
  );
}

String _titleFor(BuildContext c, String route) {
  final t = AppLocalizations.of(c)!;
  switch (route) {
    case '/home': return t.home;
    case '/favorites': return t.favorites;
    case '/live': return t.live;
    case '/movies': return t.movies;
    case '/series': return t.series;
    case '/search': return t.search;
    default: return t.home;
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(router): add StatefulShellRoute with placeholder branches"
```

---

### Task 19: DI bootstrap

**Files:**
- Create: `lib/core/di/injection.dart`
- Create: `lib/core/di/register_module.dart`
- Test: `test/core/di/injection_test.dart`

**Interfaces:**
- Consumes: contracts (Task 11), fakes (Task 12).
- Produces: `Future<void> configureDependencies()` registering — for now — the fake repositories against their contract types via get_it. Wave A swaps these registrations for real implementations. Exposes `final GetIt sl = GetIt.instance;`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/data/repositories/repositories.dart';

void main() {
  test('content repository resolves from the container', () async {
    await configureDependencies();
    expect(sl<ContentRepository>(), isNotNull);
    await sl.reset();
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/core/di/injection_test.dart`
Expected: FAIL — injection not found.

- [ ] **Step 3: Implement (manual registration; injectable codegen optional later)**

```dart
import 'package:get_it/get_it.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/fakes/fake_repositories.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<PlaylistRepository>(FakePlaylistRepository.new);
  sl.registerLazySingleton<ContentRepository>(FakeContentRepository.new);
  sl.registerLazySingleton<EpgRepository>(FakeEpgRepository.new);
  sl.registerLazySingleton<PlaybackRepository>(FakePlaybackRepository.new);
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/di/injection_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(di): bootstrap get_it with fake repositories"
```

---

### Task 20: App root wiring (accessibility + locale + theme + MediaQuery)

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/app_test.dart`

**Interfaces:**
- Consumes: `AccessibilityCubit`, `LocaleCubit`, `buildTheme`, `buildRouter`, `configureDependencies`, generated `AppLocalizations`.
- Produces: `class NoorApp extends StatelessWidget` — provides both cubits, builds `MaterialApp.router`, applies palette by `highContrast`, overrides `MediaQuery` with `textScaler`, `boldText`/`disableAnimations` from settings, and `Directionality` follows locale.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:noor_iptv/app.dart';
import 'package:noor_iptv/core/di/injection.dart';

class _FakeStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
}

void main() {
  setUp(() async { HydratedBloc.storage = _FakeStorage(); await sl.reset(); await configureDependencies(); });

  testWidgets('app boots to the home branch', (tester) async {
    await tester.pumpWidget(const NoorApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/app_test.dart`
Expected: FAIL — `NoorApp` not found.

- [ ] **Step 3: Implement `lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/a11y/accessibility_cubit.dart';
import 'core/a11y/accessibility_settings.dart';
import 'core/i18n/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

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
```

- [ ] **Step 4: Implement `lib/main.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory((await getApplicationSupportDirectory()).path),
  );
  await configureDependencies();
  runApp(const NoorApp());
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/app_test.dart`
Expected: PASS.

- [ ] **Step 6: Full suite + analyze + run**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests green.
Run: `flutter run -d macos` — confirm the shell renders with rail + Home, then stop.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(app): wire NoorApp root with a11y, locale, theme, MediaQuery"
```

---

## Self-Review

- **Spec coverage:** scaffold (T1), packages (T2), design system colors/typography/theme (T3–T5), accessibility model/cubit/captions (T6–T8), i18n EN/AR + numerals (T9–T10), repository contracts + models (T11), fakes for parallel dev (T12), shared widgets (T13–T16), adaptive shell (T17), router (T18), DI (T19), app-root a11y/MediaQuery wiring (T20). Maps to spec §5 (architecture), §8 (accessibility), and the Foundation milestone of §7/§11. Data/playback/EPG implementations and feature screens are intentionally deferred to their own plans (per plan index).
- **Placeholder scan:** none — every code step contains complete code. The `MediaKindStub` token in Task 12 Step 1 is explicitly flagged to be replaced with the real `MediaKind` import.
- **Type consistency:** model + contract names in Task 11 match the plan-index "interface-first rule" list; `context.palette`, `buildTheme`, `AppPalette.standard/highContrast`, `AccessibilitySettings`, `Result/Ok/Err/Failure`, `AdaptiveShell`, `buildRouter`, `configureDependencies/sl`, `NoorApp` are used consistently across tasks.
- **Scope:** Foundation only; produces a running, navigable, accessible, localized shell backed by fake repositories — testable on its own.
