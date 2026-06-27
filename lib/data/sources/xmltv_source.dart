import 'package:iptv_player/data/models/models.dart';
import 'package:xml/xml.dart';

/// Parses XMLTV documents into a list of [EpgProgramme] objects.
class XmltvSource {
  /// Parses an XMLTV document into EPG programmes.
  ///
  /// Any `<programme>` whose `start` or `stop` attribute is missing, shorter
  /// than 14 characters, or contains non-numeric digits is silently skipped so
  /// that one malformed entry cannot abort the entire document.
  List<EpgProgramme> parse(String xmltv) {
    final document = XmlDocument.parse(xmltv);
    final results = <EpgProgramme>[];
    for (final element in document.findAllElements('programme')) {
      final programme = _tryParseProgramme(element);
      if (programme != null) results.add(programme);
    }
    return results;
  }

  /// Returns `null` if either timestamp cannot be parsed rather than throwing.
  EpgProgramme? _tryParseProgramme(XmlElement element) {
    final startRaw = element.getAttribute('start') ?? '';
    final stopRaw = element.getAttribute('stop') ?? '';
    final channel = element.getAttribute('channel') ?? '';

    if (!_isValidTimestamp(startRaw) || !_isValidTimestamp(stopRaw)) {
      return null;
    }

    final startBasic = startRaw.substring(0, 14);
    final startUtc = _parseXmltvDatetime(startRaw);
    final stopUtc = _parseXmltvDatetime(stopRaw);

    if (startUtc == null || stopUtc == null) return null;

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

  /// Returns `true` when [raw] is at least 14 characters long and the first
  /// 14 characters are all ASCII digits (0–9).
  bool _isValidTimestamp(String raw) {
    if (raw.length < 14) return false;
    for (var i = 0; i < 14; i++) {
      final c = raw.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false; // not '0'..'9'
    }
    return true;
  }

  /// Parses an XMLTV datetime string of the form:
  ///   `yyyyMMddHHmmss` or `yyyyMMddHHmmss ±HHMM`
  ///
  /// Returns a UTC [DateTime], or `null` if parsing fails.
  /// If no offset is provided the wall-clock is treated as UTC. When an offset
  /// is present the wall-clock components are interpreted in the local timezone
  /// described by that offset and then converted to UTC by subtracting the
  /// offset.
  DateTime? _parseXmltvDatetime(String raw) {
    try {
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
    } catch (_) {
      return null;
    }
  }
}
