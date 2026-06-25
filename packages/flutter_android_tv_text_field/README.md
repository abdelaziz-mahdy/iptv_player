Fork of flutter_android_tv_text_field by Talha Yasir (MIT). Maintained for NOOR; fixes compileSdk + themable borders.

Original upstream: https://pub.dev/packages/flutter_android_tv_text_field
Fork repository: https://github.com/AbdelazizMahdy/flutter_android_tv_text_field

## Changes from upstream (1.0.2 → 1.0.3)

- `compileSdkVersion` bumped 33 → 35 (AndroidX deps require ≥34)
- AGP classpath bumped 7.3.0 → 8.1.0; Kotlin 1.7.10 → 1.9.24
- `AndroidTVTextField`: renamed misspelled params `focuesedBorderColor` →
  `focusedBorderColor` and `unFocuesedBorderColor` → `unfocusedBorderColor`
- Border color now uses widget params instead of hardcoded Colors.green / Colors.amber
- Border width is 2 when focused, 1 when unfocused

## License

MIT License — Copyright (c) 2025 Talha Yasir. See LICENSE file for full text.
