import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/i18n/numerals.dart';

void main() {
  test('converts digits to Arabic-Indic when rtl', () {
    expect(localizeDigits('2026', rtl: true), '٢٠٢٦');
  });

  test('leaves digits untouched when ltr', () {
    expect(localizeDigits('2026', rtl: false), '2026');
  });

  test('preserves non-digit characters in rtl', () {
    expect(localizeDigits('S1 E12', rtl: true), 'S١ E١٢');
  });
}
