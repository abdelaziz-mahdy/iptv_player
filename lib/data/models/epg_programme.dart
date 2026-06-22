import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_programme.freezed.dart';
part 'epg_programme.g.dart';

/// A single EPG (electronic program guide) entry on a channel's timeline.
@freezed
abstract class EpgProgramme with _$EpgProgramme {
  const factory EpgProgramme({
    required String id,
    required String channelId,
    required String title,
    required DateTime startUtc,
    required DateTime stopUtc,
    String? description,
  }) = _EpgProgramme;

  factory EpgProgramme.fromJson(Map<String, dynamic> json) =>
      _$EpgProgrammeFromJson(json);
}
