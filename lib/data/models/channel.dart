import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    required String id,
    required String playlistId,
    required String name,
    required String number,
    String? logoUrl,
    required String streamUrl,
    String? categoryId,
    @Default(false) bool isFavorite,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}
