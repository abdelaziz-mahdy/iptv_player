part of 'live_cubit.dart';

class LiveState extends Equatable {
  const LiveState({
    this.loading = false,
    this.channels = const [],
    this.epgByChannel = const {},
  });

  final bool loading;
  final List<Channel> channels;
  final Map<String, List<EpgProgramme>> epgByChannel;

  LiveState copyWith({
    bool? loading,
    List<Channel>? channels,
    Map<String, List<EpgProgramme>>? epgByChannel,
  }) {
    return LiveState(
      loading: loading ?? this.loading,
      channels: channels ?? this.channels,
      epgByChannel: epgByChannel ?? this.epgByChannel,
    );
  }

  @override
  List<Object> get props => [loading, channels, epgByChannel];
}
