# Changelog

## [1.0.3] - 2026-06-25

### Fork fixes (NOOR IPTV)
- Bumped `compileSdkVersion` 33 → 35 (AndroidX deps require ≥34; 33 caused build failure)
- Bumped AGP classpath `7.3.0` → `8.1.0` and `kotlin_version` `1.7.10` → `1.9.24`
- Renamed misspelled params `focuesedBorderColor` → `focusedBorderColor` and
  `unFocuesedBorderColor` → `unfocusedBorderColor` in `AndroidTVTextField`
- Fixed border color to use widget params instead of hardcoded Colors.green / Colors.amber
- Added width=2 when focused, width=1 when unfocused
- Minor lint fixes (const SizedBox, if-body braces)

## [0.0.3] - 2025-07-26

### 版本更新
- 每个instance绑定到nativetextfiled而不是controller

## [0.0.2] - 2025-07-26

### Critical Update - Android TV Remote Control Solution
- Solves Flutter TextField TV Remote Issues
- Native Android EditText via PlatformView
- NativeTextFieldController now extends TextEditingController

## [0.0.1] - 2024-01-XX

### 初始版本
- 基本的 NativeTextField 组件
- NativeTextFieldController 控制器
- Android 平台支持
