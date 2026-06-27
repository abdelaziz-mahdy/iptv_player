import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/sources/xmltv_source.dart';
import 'package:iptv_player/data/models/models.dart';

void main() {
  late XmltvSource source;

  setUp(() {
    source = XmltvSource();
  });

  const twoProgXmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20260621200000 +0000" stop="20260621210000 +0000" channel="bbc1">
    <title>News</title>
    <desc>Evening news</desc>
  </programme>
  <programme start="20260621210000 +0000" stop="20260621220000 +0000" channel="bbc2">
    <title>Sport</title>
  </programme>
</tv>''';

  group('XmltvSource.parse', () {
    test('parses two programme elements into two EpgProgramme objects', () {
      final result = source.parse(twoProgXmltv);

      expect(result, hasLength(2));
      expect(result[0].channelId, 'bbc1');
      expect(result[0].title, 'News');
      expect(result[1].channelId, 'bbc2');
      expect(result[1].title, 'Sport');
    });

    test('start="20260621200000 +0000" yields DateTime.utc(2026,6,21,20,0,0)',
        () {
      final result = source.parse(twoProgXmltv);

      expect(result[0].startUtc, DateTime.utc(2026, 6, 21, 20, 0, 0));
    });

    test('stop="20260621210000 +0000" yields DateTime.utc(2026,6,21,21,0,0)',
        () {
      final result = source.parse(twoProgXmltv);

      expect(result[0].stopUtc, DateTime.utc(2026, 6, 21, 21, 0, 0));
    });

    test(
        'non-zero offset: start="20260621200000 +0200" yields '
        'DateTime.utc(2026,6,21,18,0,0)', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20260621200000 +0200" stop="20260621210000 +0200" channel="bbc1">
    <title>News</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      expect(result[0].startUtc, DateTime.utc(2026, 6, 21, 18, 0, 0));
    });

    test('negative offset: start="20260621200000 -0500" yields '
        'DateTime.utc(2026,6,22,1,0,0)', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20260621200000 -0500" stop="20260621210000 -0500" channel="bbc1">
    <title>Late Show</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      // 20:00 local - (-05:00) = 20:00 + 05:00 = 01:00 next day UTC
      expect(result[0].startUtc, DateTime.utc(2026, 6, 22, 1, 0, 0));
    });

    test('<desc> maps to description field', () {
      final result = source.parse(twoProgXmltv);

      expect(result[0].description, 'Evening news');
    });

    test('absent <desc> yields null description', () {
      final result = source.parse(twoProgXmltv);

      expect(result[1].description, isNull);
    });

    test('id is stable: channelId:14-digit-start', () {
      final result = source.parse(twoProgXmltv);

      expect(result[0].id, 'bbc1:20260621200000');
      expect(result[1].id, 'bbc2:20260621210000');
    });

    test('returns empty list when no programme elements present', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv></tv>''';
      final result = source.parse(xmltv);

      expect(result, isEmpty);
    });

    test('parses programme with no timezone offset (treated as UTC)', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20260621200000" stop="20260621210000" channel="ch1">
    <title>Plain</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      expect(result[0].startUtc, DateTime.utc(2026, 6, 21, 20, 0, 0));
    });

    test('result elements are EpgProgramme instances', () {
      final result = source.parse(twoProgXmltv);

      expect(result, everyElement(isA<EpgProgramme>()));
    });

    // ------------------------------------------------------------------
    // Robustness: malformed timestamps must not crash the parser
    // ------------------------------------------------------------------

    test(
        'document with one malformed programme (start="") and one good '
        'programme parses to exactly one EpgProgramme', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="" stop="" channel="bad">
    <title>Bad Entry</title>
  </programme>
  <programme start="20260621200000 +0000" stop="20260621210000 +0000" channel="bbc1">
    <title>News</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      expect(result, hasLength(1));
      expect(result[0].channelId, 'bbc1');
      expect(result[0].title, 'News');
    });

    test(
        'document with one programme whose start is too short (e.g. "2026") '
        'and one good programme parses to exactly one EpgProgramme', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="2026" stop="2026" channel="short">
    <title>Short Timestamp</title>
  </programme>
  <programme start="20260621210000 +0000" stop="20260621220000 +0000" channel="bbc2">
    <title>Sport</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      expect(result, hasLength(1));
      expect(result[0].channelId, 'bbc2');
      expect(result[0].title, 'Sport');
    });

    test('document where all programmes are malformed returns empty list', () {
      const xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="" stop="20260621210000 +0000" channel="ch1">
    <title>No Start</title>
  </programme>
  <programme start="20260621200000 +0000" stop="" channel="ch2">
    <title>No Stop</title>
  </programme>
</tv>''';
      final result = source.parse(xmltv);

      expect(result, isEmpty);
    });
  });
}
