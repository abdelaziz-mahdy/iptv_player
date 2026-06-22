import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/a11y/accessibility_settings.dart';

import '../../support/fake_hydrated_storage.dart';

void main() {
  setUp(installFakeHydratedStorage);

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

  blocTest<AccessibilityCubit, AccessibilitySettings>(
    'caption settings update independently',
    build: AccessibilityCubit.new,
    act: (c) => c..setCaptionSize(32)..setCaptionBg(0.85)..setCaptionColor(0xFFFFE23D),
    expect: () => [
      const AccessibilitySettings(captionSize: 32),
      const AccessibilitySettings(captionSize: 32, captionBgOpacity: 0.85),
      const AccessibilitySettings(captionSize: 32, captionBgOpacity: 0.85, captionColor: 0xFFFFE23D),
    ],
  );
}
