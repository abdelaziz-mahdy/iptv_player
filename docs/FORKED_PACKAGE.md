# Vendored fork: `flutter_android_tv_text_field`

We use a **forked, vendored copy** of the MIT-licensed
[`flutter_android_tv_text_field`](https://pub.dev/packages/flutter_android_tv_text_field)
(by Talha Yasir) to give Android TV a native keyboard with working D-pad
focus. Flutter's built-in `TextField` has a confirmed engine-level D-pad bug on
Android TV ([flutter#147772](https://github.com/flutter/flutter/issues/147772)),
and the upstream package didn't build against current toolchains, so we
maintain our own copy.

The fork lives at `packages/flutter_android_tv_text_field/` and is referenced
from `pubspec.yaml` with a `path:` dependency.

## What we changed vs upstream 1.0.2
- `android/build.gradle`: `compileSdk 33 → 35`, AGP `7.3.0 → 8.1.0`, Kotlin
  `1.7.10 → 1.9.24` (upstream pinned an SDK lower than its own androidx deps
  require, so it would not build).
- `lib/native_textfield_tv.dart`: the focus border was hardcoded green/amber and
  ignored the widget's color params. Fixed to use themable params, renamed
  `focuesedBorderColor`→`focusedBorderColor` and
  `unFocuesedBorderColor`→`unfocusedBorderColor`; replaced deprecated
  `Color.value` with `Color.toARGB32()`.
- LICENSE (MIT, © 2025 Talha Yasir) kept intact — attribution preserved.

## Moving it to your own GitHub (and switching to a git dependency)

1. Create a new GitHub repo, e.g. `AbdelazizMahdy/flutter_android_tv_text_field`.
2. Push the package folder as the repo root:
   ```bash
   cd packages/flutter_android_tv_text_field
   git init && git add -A
   git commit -m "Fork of flutter_android_tv_text_field (Talha Yasir, MIT): fix build + themable borders"
   git branch -M main
   git remote add origin git@github.com:AbdelazizMahdy/flutter_android_tv_text_field.git
   git push -u origin main
   ```
3. In the app's `pubspec.yaml`, replace the path dependency with a git one:
   ```yaml
   flutter_android_tv_text_field:
     git:
       url: https://github.com/AbdelazizMahdy/flutter_android_tv_text_field.git
       ref: main        # or pin a tag/commit for reproducible builds
   ```
   Then `flutter pub get`. (Remove the `packages/` folder afterward if you want
   it sourced only from GitHub.)
4. To publish to pub.dev later, you must rename the package to a unique name
   (the upstream name is taken) and update the import paths accordingly.

## Notes / follow-ups
- The plugin still uses the legacy `apply plugin: 'kotlin-android'` style, which
  emits a non-fatal "built-in Kotlin" migration warning. A future cleanup is to
  migrate its `build.gradle` to the declarative `plugins {}` block.
- The app pins `compileSdk = 36` (`android/app/build.gradle.kts`) because the
  plugin's androidx deps require ≥34.
- Non-Android platforms use a normal editable `TextField` (physical keyboard),
  so the native widget is only built when `Platform.isAndroid`.
- The in-app `OnScreenKeyboard` widget (`lib/core/widgets/on_screen_keyboard.dart`)
  remains in the codebase (no longer used by import) and can be reused or removed.
