import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'live_state.dart';

/// Id of the synthetic "Recently Viewed" group pinned at the top.
const kRecentGroupId = 'recent';

class LiveCubit extends Cubit<LiveState> {
  LiveCubit(this._content, this._playlists, {this._playback})
      : super(const LiveState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

  /// Optional — when provided, powers the pinned "Recently Viewed" group.
  final PlaybackRepository? _playback;

  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<Channel>>? _channelsSub;
  StreamSubscription<List<String>>? _recentSub;
  String? _playlistId;
  bool _hasBound = false;

  /// All channels loaded from the repository (raw, not filtered).
  List<Channel> _allChannels = [];

  /// Recently-viewed browsable keys, most-recent first.
  List<String> _recentKeys = const [];

  /// Category name lookup: categoryId → name.
  Map<String, String> _categoryNames = {};

  /// React to the ACTIVE playlist so an imported/switched playlist shows live,
  /// without an app restart.
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
  }

  Future<void> _onActivePlaylistChanged(Playlist? playlist) async {
    final pid = playlist?.id;
    if (_hasBound && pid == _playlistId) return;
    _hasBound = true;
    _playlistId = pid;

    await _channelsSub?.cancel();
    _channelsSub = null;
    await _recentSub?.cancel();
    _recentSub = null;
    _recentKeys = const [];

    if (pid == null) {
      _allChannels = [];
      _categoryNames = {};
      emit(state.copyWith(
        loading: false,
        groups: const [],
        channelsInGroup: const [],
      ));
      return;
    }

    // Load categories so we can resolve names for group labels.
    final cats = await _content.categories(pid, MediaKind.channel);
    _categoryNames = {for (final c in cats) c.id: c.name};

    // Recently-viewed (optional dependency).
    _recentSub = _playback?.recentlyViewed(pid).listen((keys) {
      _recentKeys = keys;
      _recompute();
    });

    _channelsSub = _content.channels(pid).listen((channels) {
      _allChannels = channels;
      _recompute();
    });
  }

  /// Changes the active group and filters [channelsInGroup] accordingly.
  void selectGroup(String id) {
    final filtered = _filterChannels(_allChannels, id);
    emit(state.copyWith(
      selectedGroupId: id,
      channelsInGroup: filtered,
    ));
  }

  /// Rebuilds groups + the current group's channels from raw channels and
  /// recent keys, preserving the selected group.
  void _recompute() {
    final selectedId = state.selectedGroupId ?? 'all';
    emit(state.copyWith(
      loading: false,
      groups: _buildGroups(_allChannels),
      selectedGroupId: selectedId,
      channelsInGroup: _filterChannels(_allChannels, selectedId),
    ));
  }

  /// Recently-viewed channels in recency order, only those still present.
  List<Channel> _recentChannels() {
    final byId = {for (final c in _allChannels) c.id: c};
    final out = <Channel>[];
    final seen = <String>{};
    for (final key in _recentKeys) {
      if (!key.startsWith('channel:')) continue;
      final id = key.substring('channel:'.length);
      final ch = byId[id];
      if (ch != null && seen.add(id)) out.add(ch);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Builds the list of [ChannelGroup]s from [channels].
  ///
  /// Always prepends an "All" group. Channels with null or unknown categoryId
  /// are grouped under "Other" (only added when there are uncategorised channels
  /// and the channel list is non-trivial — i.e. at least one named category
  /// exists; otherwise they all go into "All" only).
  List<ChannelGroup> _buildGroups(List<Channel> channels) {
    // Build per-category counts.
    final counts = <String, int>{}; // categoryId → count
    int uncategorised = 0;

    for (final ch in channels) {
      final cid = ch.categoryId;
      if (cid != null && _categoryNames.containsKey(cid)) {
        counts[cid] = (counts[cid] ?? 0) + 1;
      } else {
        uncategorised++;
      }
    }

    final recentCount = _recentChannels().length;
    final groups = <ChannelGroup>[
      if (recentCount > 0)
        (id: kRecentGroupId, name: 'Recently Viewed', count: recentCount),
      (id: 'all', name: 'All', count: channels.length),
    ];

    for (final entry in counts.entries) {
      groups.add((
        id: entry.key,
        name: _categoryNames[entry.key] ?? entry.key,
        count: entry.value,
      ));
    }

    if (uncategorised > 0 && counts.isNotEmpty) {
      groups.add((id: 'other', name: 'Other', count: uncategorised));
    }

    return groups;
  }

  /// Returns channels belonging to the group identified by [groupId].
  List<Channel> _filterChannels(List<Channel> channels, String groupId) {
    if (groupId == kRecentGroupId) return _recentChannels();
    if (groupId == 'all') return List.unmodifiable(channels);
    if (groupId == 'other') {
      return channels
          .where((ch) =>
              ch.categoryId == null ||
              !_categoryNames.containsKey(ch.categoryId))
          .toList();
    }
    return channels
        .where((ch) => ch.categoryId == groupId)
        .toList();
  }

  @override
  Future<void> close() async {
    await _activeSub?.cancel();
    await _channelsSub?.cancel();
    await _recentSub?.cancel();
    return super.close();
  }
}
