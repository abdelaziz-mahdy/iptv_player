import 'package:freezed_annotation/freezed_annotation.dart';

part 'vod_item.freezed.dart';
part 'vod_item.g.dart';

/// A video-on-demand movie.
@freezed
abstract class VodItem with _$VodItem {
  const factory VodItem({
    required String id,
    required String playlistId,
    required String title,
    String? posterUrl,
    String? categoryId,
    String? year,
    double? rating,
    required String streamUrl,
  }) = _VodItem;

  factory VodItem.fromJson(Map<String, dynamic> json) => _$VodItemFromJson(json);
}
