import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'favorite.freezed.dart';
part 'favorite.g.dart';

/// A user-favorited item. `itemKey` matches the keyed media (e.g. "channel:7").
@freezed
abstract class Favorite with _$Favorite {
  const factory Favorite({
    required String itemKey,
    required String playlistId,
    required MediaKind kind,
    required DateTime addedAt,
  }) = _Favorite;

  factory Favorite.fromJson(Map<String, dynamic> json) => _$FavoriteFromJson(json);
}
