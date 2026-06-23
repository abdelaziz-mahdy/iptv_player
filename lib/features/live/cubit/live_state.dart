part of 'live_cubit.dart';

/// A named group of channels (e.g. "All", "Sports", "News").
typedef ChannelGroup = ({String id, String name, int count});

class LiveState extends Equatable {
  const LiveState({
    this.loading = false,
    this.groups = const [],
    this.selectedGroupId,
    this.channelsInGroup = const [],
  });

  final bool loading;
  final List<ChannelGroup> groups;
  final String? selectedGroupId;
  final List<Channel> channelsInGroup;

  LiveState copyWith({
    bool? loading,
    List<ChannelGroup>? groups,
    String? selectedGroupId,
    List<Channel>? channelsInGroup,
  }) {
    return LiveState(
      loading: loading ?? this.loading,
      groups: groups ?? this.groups,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      channelsInGroup: channelsInGroup ?? this.channelsInGroup,
    );
  }

  @override
  List<Object?> get props => [loading, groups, selectedGroupId, channelsInGroup];
}
