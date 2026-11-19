part of 'live_cubit.dart';

/// A named group of channels (e.g. "All", "Sports", "News").
typedef ChannelGroup = ({String id, String name, int count});

class LiveState extends Equatable {
  const LiveState({
    this.loading = false,
    this.groups = const [],
    this.selectedGroupId,
    this.channelsInGroup = const [],
    this.pinnedGroupCount = 0,
    this.recentGroupCount = 0,
  });

  final bool loading;
  final List<ChannelGroup> groups;
  final String? selectedGroupId;
  final List<Channel> channelsInGroup;

  /// How many leading entries of [groups] sit above the provider's own list:
  /// the synthetic groups plus the recency block. The sidebar draws its
  /// separator here.
  final int pinnedGroupCount;

  /// How many of the pinned entries are recently opened groups (the sidebar
  /// heads them "Recent"); they sit just above [pinnedGroupCount].
  final int recentGroupCount;

  LiveState copyWith({
    bool? loading,
    List<ChannelGroup>? groups,
    String? selectedGroupId,
    List<Channel>? channelsInGroup,
    int? pinnedGroupCount,
    int? recentGroupCount,
  }) {
    return LiveState(
      loading: loading ?? this.loading,
      groups: groups ?? this.groups,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      channelsInGroup: channelsInGroup ?? this.channelsInGroup,
      pinnedGroupCount: pinnedGroupCount ?? this.pinnedGroupCount,
      recentGroupCount: recentGroupCount ?? this.recentGroupCount,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    groups,
    selectedGroupId,
    channelsInGroup,
    pinnedGroupCount,
    recentGroupCount,
  ];
}
