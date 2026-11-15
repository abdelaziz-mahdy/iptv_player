import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/widgets/section_visibility.dart';

void main() {
  Widget section({required bool active, required VoidCallback onHidden}) =>
      TickerMode(
        enabled: active,
        child: OnSectionHidden(onHidden: onHidden, child: const SizedBox()),
      );

  testWidgets('calls onHidden when the section stops being visible', (
    tester,
  ) async {
    var hidden = 0;
    await tester.pumpWidget(section(active: true, onHidden: () => hidden++));
    expect(hidden, 0);

    await tester.pumpWidget(section(active: false, onHidden: () => hidden++));
    expect(hidden, 1);

    // Staying hidden, or coming back, does not call it again.
    await tester.pumpWidget(section(active: false, onHidden: () => hidden++));
    await tester.pumpWidget(section(active: true, onHidden: () => hidden++));
    expect(hidden, 1);
  });

  testWidgets('a section built while hidden is not reported as left', (
    tester,
  ) async {
    var hidden = 0;
    await tester.pumpWidget(section(active: false, onHidden: () => hidden++));
    expect(hidden, 0);
  });
}
