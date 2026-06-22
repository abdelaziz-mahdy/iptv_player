import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'playlist.freezed.dart';
part 'playlist.g.dart';

@freezed
abstract class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    required PlaylistType type,
    String? serverUrl,
    required String initial,
    @Default(0) int channelCount,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
}
