# Debugging NOOR on Android TV (without the physical TV)

You can fully reproduce and debug Android-TV behavior (D-pad focus, the
leanback on-screen keyboard/IME, leanback theming) locally on an emulator,
and see the screen via screenshots.

## One-time setup (already done on this machine)

```bash
SDK=~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager
AVDM=~/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager

# TV system image (Apple Silicon → arm64)
yes | "$SDK" "system-images;android-34;android-tv;arm64-v8a" "platforms;android-34"

# TV AVD
echo no | "$AVDM" create avd -n Android_TV \
  -k "system-images;android-34;android-tv;arm64-v8a" -d "tv_1080p" --force
```

## Launch the TV emulator

```bash
~/Library/Android/sdk/emulator/emulator -avd Android_TV -no-snapshot-load &
adb wait-for-device
adb shell getprop sys.boot_completed   # prints 1 when ready
```

`flutter devices` / `flutter emulators` will list it. Run the app with logs +
hot reload:

```bash
flutter run -d emulator-5554
```

Or install a built APK:

```bash
flutter build apk --release
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 shell am start -n com.noor.iptv.noor_iptv/.MainActivity
```

## Drive the D-pad / remote from the terminal

```bash
D=emulator-5554
adb -s $D shell input keyevent 19   # DPAD_UP
adb -s $D shell input keyevent 20   # DPAD_DOWN
adb -s $D shell input keyevent 21   # DPAD_LEFT
adb -s $D shell input keyevent 22   # DPAD_RIGHT
adb -s $D shell input keyevent 23   # DPAD_CENTER / select
adb -s $D shell input keyevent 4    # BACK
adb -s $D shell input text "hello"  # type into a focused field
```

## See the screen (no physical TV needed)

```bash
adb -s emulator-5554 exec-out screencap -p > /tmp/tv.png
# then open /tmp/tv.png
```

## Inspect focus / keyboard state

```bash
# Is the soft keyboard (IME) showing? Watch for flicker by polling this.
adb -s emulator-5554 shell dumpsys input_method | grep mInputShown

# Currently focused / resumed activity
adb -s emulator-5554 shell dumpsys activity activities | grep ResumedActivity
```

To log every Flutter focus change (exposes focus-churn loops), temporarily add
in `main()` before `runApp`:

```dart
import 'package:flutter/widgets.dart';
// ...
debugFocusChanges = true; // prints each focus traversal to the console
```

Then watch `flutter run` / `flutter logs` output.

## Automated focus regression tests

`test/features/import/import_screen_test.dart` includes
`field keeps focus across a rebuild (TV focus-loop regression)` — it focuses a
field, forces an unrelated rebuild, and asserts focus is retained. This catches
the focus-churn class of bug headlessly (no emulator needed):

```bash
flutter test test/features/import
```

## TV focus rules of thumb (learned from this app)

- Give text fields **stable `FocusNode`s** owned by the State (never recreated
  per build) so rebuilds don't churn focus / flicker the IME.
- Keep rebuild scope narrow (`BlocSelector`/`buildWhen`) so typing and
  unrelated state changes don't rebuild the field subtree.
- On forms set `Scaffold(resizeToAvoidBottomInset: false)` — on TV the IME is
  an overlay; resizing the body when it opens causes a relayout→focus→IME loop.
- Make every tappable element a `FocusableButton` (Enter/Space/Select/
  gameButtonA activation) so the remote can trigger it.
- The focus ring must contrast with the element — an accent-colored button
  needs a focus indicator that isn't the same accent (see follow-ups).
```
