# packages/ — vendored dependencies

## flutter_android_tv_text_field

**Source:** fork of github.com/talhayasir/flutter_android_tv_text_field  
**License:** MIT — Copyright (c) 2025 Talha Yasir — keep LICENSE intact  
**Referenced as:** path dependency in root `pubspec.yaml` → `packages/flutter_android_tv_text_field`

### Why vendored

Flutter's built-in `TextField` is broken on Android TV when navigating with a D-pad (flutter#147772 — cursor and focus misbehave). This fork wraps a native Android `EditText` via a platform view, sidestepping the Flutter bug entirely.

The fork also fixes two upstream issues that blocked this project:
- `compileSdk` bumped to build against current toolchains
- Renamed misspelled params (`focuesedBorderColor` → `focusedBorderColor`, `unFocuesedBorderColor` → `unfocusedBorderColor`) and wired them to the border instead of the upstream hardcoded `Colors.green` / `Colors.amber`, making the focus border themable

### Public API (lib/native_textfield_tv.dart)

| Symbol | Role |
|---|---|
| `AndroidTVTextField` | **Primary widget.** High-level wrapper with D-pad key handling, focus border, optional password-toggle suffix, and `postFixWidget` slot. Use this in app code. |
| `NativeTextFieldController` | Extends `TextEditingController`. Pass to `AndroidTVTextField`. Bridges Flutter text state ↔ native `EditText`. |
| `NativeTextField` | Low-level `AndroidView` platform widget. Prefer `AndroidTVTextField` unless you need full layout control. |

Typical usage (Android path only):

```dart
final controller = NativeTextFieldController();
final focusNode = FocusNode();

AndroidTVTextField(
  controller: controller,
  focusNode: focusNode,
  hint: 'Search…',
  focusedBorderColor: Theme.of(context).colorScheme.primary,
  unfocusedBorderColor: Colors.grey,
)
```

On non-Android platforms use the regular Flutter `TextField` — this plugin only registers an `AndroidView` and has no other platform implementations.

### Gotchas

- **Fork — changes live here, not upstream.** Any bug fix or feature must be applied in `packages/flutter_android_tv_text_field/` and committed to this repo.
- **KGP deprecation warning at build** (Kotlin Gradle Plugin API). Harmless for now; suppress or fix when the Android Gradle Plugin minimum is raised.
- Do **not** publish this package to pub.dev without verifying upstream attribution requirements in LICENSE.
