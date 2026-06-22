import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/app.dart';
import 'package:noor_iptv/core/di/injection.dart';

import 'support/fake_hydrated_storage.dart';

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await sl.reset();
    await configureDependencies();
  });

  testWidgets('app boots to the home branch', (tester) async {
    await tester.pumpWidget(const NoorApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
