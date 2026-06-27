import 'package:m3u_nullsafe/m3u_nullsafe.dart';
import 'package:iptv_player/data/models/models.dart';

/// Parses M3U / M3U_Plus content into a list of [Channel]s.
class M3uSource {
  /// Parses M3U/M3U_Plus [content] into channels for [playlistId].
  ///
  /// Throws on malformed input (lets the m3u parser's exception propagate).
  Future<List<Channel>> parse(
    String content, {
    required String playlistId,
  }) async {
    final entries = await parseFile(content);

    return List<Channel>.generate(entries.length, (index) {
      final entry = entries[index];
      final attrs = entry.attributes;

      final streamUrl = entry.link;
      final name = entry.title;
      final logoUrl =
          attrs['tvg-logo']?.isEmpty ?? true ? null : attrs['tvg-logo'];
      final categoryId = attrs['group-title']?.isEmpty ?? true
          ? null
          : attrs['group-title'];
      final number = (attrs['tvg-chno']?.isEmpty ?? true)
          ? '${index + 1}'
          : attrs['tvg-chno']!;

      // Prefer the stream URL as the stable identifier; fall back to index.
      final id =
          streamUrl.isNotEmpty ? '$playlistId:$streamUrl' : '$playlistId:$index';

      return Channel(
        id: id,
        playlistId: playlistId,
        name: name,
        number: number,
        logoUrl: logoUrl,
        streamUrl: streamUrl,
        categoryId: categoryId,
      );
    });
  }
}
