import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'live_state.dart';

class LiveCubit extends Cubit<LiveState> {
  LiveCubit(this._content, this._epg, this._playlists)
      : super(const LiveState());

  final ContentRepository _content;
  final EpgRepository _epg;
  final PlaylistRepository _playlists;

  StreamSubscription<List<Channel>>? _channelsSub;

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

    _channelsSub = _content.channels(pid).listen((channels) async {
      final now = DateTime.now().toUtc();
      final from = DateTime.utc(now.year, now.month, now.day);
      final to = from.add(const Duration(hours: 6));

      final epgByChannel = <String, List<EpgProgramme>>{};
      for (final ch in channels) {
        final result = await _epg.programmes(ch.id, from, to);
        result.when(
          ok: (progs) => epgByChannel[ch.id] = progs,
          err: (_) => epgByChannel[ch.id] = [],
        );
      }

      emit(state.copyWith(
        loading: false,
        channels: channels,
        epgByChannel: epgByChannel,
      ));
    });
  }

  @override
  Future<void> close() async {
    await _channelsSub?.cancel();
    return super.close();
  }
}
