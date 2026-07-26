import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'live_state.dart';

/// Ids of the synthetic groups pinned above the provider's own list. They have
/// no name of their own — the UI resolves a localized label from the id.
const kRecentGroupId = 'recent';
const kAllGroupId = 'all';
const kOtherGroupId = 'other';

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
  StreamSubscription<List<String>>? _recentGroupSub;
  String? _playlistId;
  bool _hasBound = false;

  /// All channels loaded from the repository (raw, not filtered).
  List<Channel> _allChannels = [];

  /// Recently-viewed browsable keys, most-recent first.
  List<String> _recentKeys = const [];

  /// Category ids the user has opened, most-recent first.
  List<String> _recentGroupIds = const [];

  /// Category ids in the provider's own order.
  List<String> _categoryOrder = const [];

  /// Category name lookup: categoryId → name.
  Map<String, String> _categoryNames = {};

  /// Set once per playlist, when the first recency list arrives: the group the
  /// user was last in becomes the initial selection.
  bool _restoredSelection = false;

  String? _selectedGroupId;

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
    await _recentGroupSub?.cancel();
    _recentGroupSub = null;
    _recentKeys = const [];
    _recentGroupIds = const [];
    _restoredSelection = false;

    if (pid == null) {
      _allChannels = [];
      _categoryNames = {};
      _categoryOrder = const [];
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
    _categoryOrder = [for (final c in cats) c.id];

    // Recently-viewed (optional dependency).
    _recentSub = _playback
        ?.recentlyViewed(pid, prefix: 'channel:')
        .listen((keys) {
      _recentKeys = keys;
      _recompute();
    });

    _recentGroupSub =
        _content.recentCategoryIds(pid, MediaKind.channel).listen((ids) {
      _recentGroupIds = ids;
      if (!_restoredSelection) {
        _restoredSelection = true;
        if (ids.isNotEmpty && state.selectedGroupId == null) {
          _selectedGroupId = ids.first;
        }
      }
      _recompute();
    });

    _channelsSub = _content.channels(pid).listen((channels) {
      _allChannels = channels;
      _recompute();
    });
  }

  /// Changes the active group and filters [channelsInGroup] accordingly.
  void selectGroup(String id) {
    _selectedGroupId = id;
    emit(state.copyWith(
      selectedGroupId: id,
      channelsInGroup: _filterChannels(_allChannels, id),
    ));
    final pid = _playlistId;
    if (pid != null && !_isSyntheticGroup(id)) {
      _content.recordCategoryUse(pid, MediaKind.channel, id);
    }
  }

  /// Rebuilds groups + the current group's channels from raw channels and
  /// recent keys, preserving the selected group.
  void _recompute() {
    final built = _buildGroups(_allChannels);
    var selectedId = _selectedGroupId ?? kAllGroupId;
    // A restored or previously selected group can vanish when the provider
    // drops a category.
    if (!built.groups.any((g) => g.id == selectedId)) selectedId = kAllGroupId;
    _selectedGroupId = selectedId;
    emit(state.copyWith(
      loading: false,
      groups: built.groups,
      pinnedGroupCount: built.pinned,
      selectedGroupId: selectedId,
      channelsInGroup: _filterChannels(_allChannels, selectedId),
    ));
  }

  static bool _isSyntheticGroup(String id) =>
      id == kRecentGroupId || id == kAllGroupId || id == kOtherGroupId;

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
  /// Order: "Recently Viewed" (channels), "All", the groups the user has
  /// opened — most recent first, capped at [kRecentCategoryLimit] — then the
  /// rest in the provider's own order. A group in the recency block is
  /// *removed* from the block below, so nothing is listed twice.
  ///
  /// Channels with null or unknown categoryId are grouped under "Other" (only
  /// when at least one named category exists; otherwise they all go into
  /// "All" only).
  ({List<ChannelGroup> groups, int pinned}) _buildGroups(
      List<Channel> channels) {
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
      // Synthetic groups carry no display name — the UI localizes them by id.
      if (recentCount > 0)
        (id: kRecentGroupId, name: '', count: recentCount),
      (id: kAllGroupId, name: '', count: channels.length),
    ];

    ChannelGroup group(String id) => (
          id: id,
          name: _categoryNames[id] ?? id,
          count: counts[id] ?? 0,
        );

    final pinned = <String>{};
    for (final id in _recentGroupIds) {
      if (pinned.length >= kRecentCategoryLimit) break;
      if (!counts.containsKey(id)) continue;
      if (!pinned.add(id)) continue;
      groups.add(group(id));
    }

    final pinnedCount = groups.length;

    for (final id in _categoryOrder) {
      if (pinned.contains(id) || !counts.containsKey(id)) continue;
      groups.add(group(id));
    }
    // Categories present on channels but absent from the provider's list.
    for (final id in counts.keys) {
      if (pinned.contains(id) || _categoryOrder.contains(id)) continue;
      groups.add(group(id));
    }

    if (uncategorised > 0 && counts.isNotEmpty) {
      groups.add((id: kOtherGroupId, name: '', count: uncategorised));
    }

    return (groups: groups, pinned: pinnedCount);
  }

  /// Returns channels belonging to the group identified by [groupId].
  List<Channel> _filterChannels(List<Channel> channels, String groupId) {
    if (groupId == kRecentGroupId) return _recentChannels();
    if (groupId == kAllGroupId) return List.unmodifiable(channels);
    if (groupId == kOtherGroupId) {
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
    await _recentGroupSub?.cancel();
    return super.close();
  }
}
