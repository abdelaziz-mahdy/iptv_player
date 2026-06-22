import 'package:noor_iptv/data/models/models.dart';
import 'package:xml/xml.dart';

/// Parses XMLTV documents into a list of [EpgProgramme] objects.
class XmltvSource {
  /// Parses an XMLTV document into EPG programmes.
  List<EpgProgramme> parse(String xmltv) {
    final document = XmlDocument.parse(xmltv);
    return document
        .findAllElements('programme')
        .map(_parseProgramme)
        .toList();
  }

  EpgProgramme _parseProgramme(XmlElement element) {
    final startRaw = element.getAttribute('start') ?? '';
    final stopRaw = element.getAttribute('stop') ?? '';
    final channel = element.getAttribute('channel') ?? '';

    final startBasic = startRaw.substring(0, 14);
    final startUtc = _parseXmltvDatetime(startRaw);
    final stopUtc = _parseXmltvDatetime(stopRaw);

    final title = element.findElements('title').firstOrNull?.innerText ?? '';
    final desc = element.findElements('desc').firstOrNull?.innerText;

    final id = '$channel:$startBasic';

    return EpgProgramme(
      id: id,
      channelId: channel,
      title: title,
      startUtc: startUtc,
      stopUtc: stopUtc,
      description: desc,
    );
  }

  /// Parses an XMLTV datetime string of the form:
  ///   `yyyyMMddHHmmss` or `yyyyMMddHHmmss ±HHMM`
  ///
  /// Returns a UTC [DateTime]. If no offset is provided the wall-clock is
  /// treated as UTC. When an offset is present the wall-clock components are
  /// interpreted in the local timezone described by that offset and then
  /// converted to UTC by subtracting the offset.
  DateTime _parseXmltvDatetime(String raw) {
    // The string is at least 14 chars: yyyyMMddHHmmss
    final digits = raw.substring(0, 14);
    final year = int.parse(digits.substring(0, 4));
    final month = int.parse(digits.substring(4, 6));
    final day = int.parse(digits.substring(6, 8));
    final hour = int.parse(digits.substring(8, 10));
    final minute = int.parse(digits.substring(10, 12));
    final second = int.parse(digits.substring(12, 14));

    // Look for a timezone offset: space followed by +HHMM or -HHMM
    int offsetMinutes = 0;
    if (raw.length > 14) {
      final rest = raw.substring(14).trim();
      if (rest.length >= 5) {
        final sign = rest[0] == '-' ? -1 : 1;
        final offsetHour = int.parse(rest.substring(1, 3));
        final offsetMin = int.parse(rest.substring(3, 5));
        offsetMinutes = sign * (offsetHour * 60 + offsetMin);
      }
    }

    // Build a UTC DateTime by subtracting the offset.
    // local_time - offset_duration = UTC
    final local = DateTime.utc(year, month, day, hour, minute, second);
    return local.subtract(Duration(minutes: offsetMinutes));
  }
}
