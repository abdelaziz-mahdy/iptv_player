import 'dart:ui';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/i18n/locale_cubit.dart';

import '../../support/fake_hydrated_storage.dart';

void main() {
  setUp(installFakeHydratedStorage);

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
