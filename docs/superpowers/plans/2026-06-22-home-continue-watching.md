# Home + Continue Watching Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Live TV rail from Home, make Continue Watching exclude live channels and cap at 20 items, and add long-press remove support throughout the stack.

**Architecture:** The change touches three layers in dependency order — (1) the DB query method (`AppDatabase.watchContinue`), (2) the repository contract (`PlaybackRepository`) and both implementations (`DriftPlaybackRepository`, `FakePlaybackRepository`), (3) the cubit (`HomeCubit` / `HomeState`), and (4) the home UI. Each task is fully testable before the next begins.

**Tech Stack:** Flutter / Dart, flutter_bloc (Cubit), Drift (SQLite ORM), freezed models, flutter_test widget tests, drift/native.dart in-memory DB for integration tests.

## Global Constraints

- Edit only `lib/features/home/**`, `lib/data/repositories/**`, `lib/data/db/**` (only if needed), and matching `test/**`.
- Do NOT touch `lib/core/widgets/poster_card.dart`, grid, search, or player files.
- Branch is `build/noor-foundation` — do not switch.
- All tests in `test/features/home` and `test/data/repositories` must pass green.
- `flutter analyze` must be clean on the edited files.
- Commit identity: `git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com"`.
- `MediaKind` enum values: `channel`, `movie`, `episode` (from `lib/data/models/enums.dart`).
- `AppDatabase.watchContinue` is the existing Drift query at `lib/data/db/database.dart:111-115`.
- `WatchProgress` has fields: `itemKey`, `playlistId`, `kind` (MediaKind), `positionSec`, `durationSec`, `updatedAt`.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/data/db/database.dart` | Modify | Add `deleteProgress(String itemKey)` method; update `watchContinue` to filter channels and limit to 20 |
| `lib/data/repositories/repositories.dart` | Modify | Add `removeProgress(String itemKey)` to `PlaybackRepository` abstract class |
| `lib/data/repositories/drift_playback_repository.dart` | Modify | Implement `removeProgress` calling `_db.deleteProgress` |
| `lib/data/repositories/fakes/fake_repositories.dart` | Modify | Implement `removeProgress` in `FakePlaybackRepository`; update `continueWatching` to filter channels and cap 20 |
| `lib/features/home/cubit/home_state.dart` | Modify | Remove `channels` field; remove from `copyWith` and `props` |
| `lib/features/home/cubit/home_cubit.dart` | Modify | Remove `_channelsSub`; add `removeFromContinueWatching(String itemKey)` |
| `lib/features/home/home_screen.dart` | Modify | Remove `_ChannelsRail`; remove `onOpenChannel` param; fix `_hasContent`; wrap CW cards with `GestureDetector(onLongPress:...)` |
| `test/data/repositories/drift_repositories_test.dart` | Modify | Add tests for continueWatching-excludes-channel, cap-20, removeProgress |
| `test/data/repositories/fake_repositories_test.dart` | Modify | Add tests for continueWatching-excludes-channel, removeProgress |
| `test/features/home/home_cubit_test.dart` | Modify | Remove channels assertions; add removeFromContinueWatching test |
| `test/features/home/home_screen_test.dart` | Modify | Assert no Live rail; keep movies/series assertions |

---

## Task 1: DB layer — filter channels, cap 20, add deleteProgress

**Files:**
- Modify: `lib/data/db/database.dart:111-115` (watchContinue query)
- Modify: `lib/data/db/database.dart` (add deleteProgress method after saveProgress)
- Test: `test/data/repositories/drift_repositories_test.dart` (add to existing DriftPlaybackRepository group)

**Interfaces:**
- Produces:
  - `AppDatabase.watchContinue(String playlistId)` — now filters `kind != 'channel'`, orders by `updatedAt DESC`, limits to 20
  - `AppDatabase.deleteProgress(String itemKey)` — deletes the row where `itemKey` matches

- [ ] **Step 1: Write the failing tests**

Add these two tests inside the `group('DriftPlaybackRepository', ...)` block in `test/data/repositories/drift_repositories_test.dart`, before the closing `});`:

```dart
test('continueWatching excludes channel-kind entries', () async {
  final db = _makeDb();
  addTearDown(db.close);

  final repo = DriftPlaybackRepository(db);

  // Save a channel entry and a movie entry.
  await repo.saveProgress(WatchProgress(
    itemKey: 'channel:c1',
    playlistId: _playlistId,
    kind: MediaKind.channel,
    positionSec: 10,
    durationSec: 60,
    updatedAt: DateTime.utc(2026, 1, 1),
  ));
  await repo.saveProgress(WatchProgress(
    itemKey: 'movie:m1',
    playlistId: _playlistId,
    kind: MediaKind.movie,
    positionSec: 42,
    durationSec: 120,
    updatedAt: DateTime.utc(2026, 1, 2),
  ));

  final list = await repo.continueWatching(_playlistId).first;
  expect(list, hasLength(1));
  expect(list.first.itemKey, 'movie:m1');
  expect(list.first.kind, MediaKind.movie);
});

test('continueWatching caps at 20 most-recent entries', () async {
  final db = _makeDb();
  addTearDown(db.close);

  final repo = DriftPlaybackRepository(db);

  // Save 25 movie entries with increasing updatedAt.
  for (var i = 1; i <= 25; i++) {
    await repo.saveProgress(WatchProgress(
      itemKey: 'movie:m$i',
      playlistId: _playlistId,
      kind: MediaKind.movie,
      positionSec: i,
      durationSec: 100,
      updatedAt: DateTime.utc(2026, 1, i),
    ));
  }

  final list = await repo.continueWatching(_playlistId).first;
  expect(list, hasLength(20));
  // Most recent should be first (m25 updatedAt is largest).
  expect(list.first.itemKey, 'movie:m25');
});

test('removeProgress deletes the row; progressFor returns null', () async {
  final db = _makeDb();
  addTearDown(db.close);

  final repo = DriftPlaybackRepository(db);

  await repo.saveProgress(WatchProgress(
    itemKey: 'movie:m1',
    playlistId: _playlistId,
    kind: MediaKind.movie,
    positionSec: 42,
    durationSec: 120,
    updatedAt: DateTime.utc(2026),
  ));

  // Confirm it exists.
  expect(await repo.progressFor('movie:m1'), isNotNull);

  // Remove it.
  await repo.removeProgress('movie:m1');

  // Should be gone.
  expect(await repo.progressFor('movie:m1'), isNull);

  // continueWatching stream should also be empty.
  final list = await repo.continueWatching(_playlistId).first;
  expect(list, isEmpty);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/drift_repositories_test.dart --name "continueWatching excludes|continueWatching caps|removeProgress deletes" 2>&1 | tail -20
```

Expected: FAIL — `removeProgress` not defined, `continueWatching excludes channel` still finds 2 items (no filter), cap test finds 25 (no limit).

- [ ] **Step 3: Update `watchContinue` in `lib/data/db/database.dart`**

Replace lines 111-115 (the `watchContinue` method):

```dart
  Stream<List<WatchProgressRow>> watchContinue(String playlistId) =>
      (select(watchProgressRows)
            ..where((t) =>
                t.playlistId.equals(playlistId) &
                t.kind.equals('channel').not())
            ..orderBy([
              (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
            ])
            ..limit(20))
          .watch();
```

- [ ] **Step 4: Add `deleteProgress` to `lib/data/db/database.dart`**

After the `saveProgress` method (currently around line 110), add:

```dart
  Future<void> deleteProgress(String itemKey) =>
      (delete(watchProgressRows)..where((t) => t.itemKey.equals(itemKey))).go();
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/drift_repositories_test.dart --name "continueWatching excludes|continueWatching caps|removeProgress deletes" 2>&1 | tail -20
```

Expected: FAIL on `removeProgress` (not yet implemented in DriftPlaybackRepository), PASS on the two `continueWatching` DB tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/data/db/database.dart test/data/repositories/drift_repositories_test.dart
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(db): watchContinue excludes channels, caps at 20; add deleteProgress"
```

---

## Task 2: Repository contract and Drift implementation for removeProgress

**Files:**
- Modify: `lib/data/repositories/repositories.dart:44` (add `removeProgress` abstract method)
- Modify: `lib/data/repositories/drift_playback_repository.dart` (implement `removeProgress`)

**Interfaces:**
- Consumes: `AppDatabase.deleteProgress(String itemKey)` (from Task 1)
- Produces: `PlaybackRepository.removeProgress(String itemKey) → Future<void>`

Note: Adding `removeProgress` to the abstract class will cause a compile error in `FakePlaybackRepository` until Task 3. That is expected and fine — both tasks 2 and 3 are grouped together logically. The drift repo test from Task 1 (`removeProgress deletes the row`) will be the integration test for this.

- [ ] **Step 1: Add `removeProgress` to the abstract contract**

In `lib/data/repositories/repositories.dart`, replace:

```dart
/// Tracks playback position and the "continue watching" list.
abstract class PlaybackRepository {
  Future<WatchProgress?> progressFor(String itemKey);
  Future<void> saveProgress(WatchProgress p);
  Stream<List<WatchProgress>> continueWatching(String playlistId);
}
```

With:

```dart
/// Tracks playback position and the "continue watching" list.
abstract class PlaybackRepository {
  Future<WatchProgress?> progressFor(String itemKey);
  Future<void> saveProgress(WatchProgress p);
  Future<void> removeProgress(String itemKey);
  Stream<List<WatchProgress>> continueWatching(String playlistId);
}
```

- [ ] **Step 2: Implement `removeProgress` in `DriftPlaybackRepository`**

In `lib/data/repositories/drift_playback_repository.dart`, add after `saveProgress`:

```dart
  @override
  Future<void> removeProgress(String itemKey) async {
    await _db.deleteProgress(itemKey);
  }
```

The full file should look like:

```dart
import '../db/database.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Drift-backed [PlaybackRepository].
class DriftPlaybackRepository implements PlaybackRepository {
  DriftPlaybackRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  static WatchProgress _fromRow(WatchProgressRow r) => WatchProgress(
        itemKey: r.itemKey,
        playlistId: r.playlistId,
        kind: MediaKind.values.byName(r.kind),
        positionSec: r.positionSec,
        durationSec: r.durationSec,
        updatedAt: r.updatedAt,
      );

  static WatchProgressRowsCompanion _toCompanion(WatchProgress p) =>
      WatchProgressRowsCompanion.insert(
        itemKey: p.itemKey,
        playlistId: p.playlistId,
        kind: p.kind.name,
        positionSec: p.positionSec,
        durationSec: p.durationSec,
        updatedAt: p.updatedAt,
      );

  // ---------------------------------------------------------------------------
  // PlaybackRepository
  // ---------------------------------------------------------------------------

  @override
  Future<WatchProgress?> progressFor(String itemKey) async {
    final row = await _db.getProgress(itemKey);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> saveProgress(WatchProgress p) async {
    await _db.saveProgress(_toCompanion(p));
  }

  @override
  Future<void> removeProgress(String itemKey) async {
    await _db.deleteProgress(itemKey);
  }

  @override
  Stream<List<WatchProgress>> continueWatching(String playlistId) {
    return _db.watchContinue(playlistId).map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }
}
```

- [ ] **Step 3: Run drift repo tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/drift_repositories_test.dart 2>&1 | tail -20
```

Expected: The `removeProgress deletes the row` test passes. The existing `continueWatching streams saved progress` test now **fails** because it saved a channel entry and expected length 1 — but the new filter excludes channels. We must update that test.

- [ ] **Step 4: Fix the stale `continueWatching streams saved progress` test**

In `test/data/repositories/drift_repositories_test.dart`, the test `'continueWatching streams saved progress'` saves a `MediaKind.channel` entry and expects length 1. Update it to save a `MediaKind.movie` entry instead:

```dart
test('continueWatching streams saved progress', () async {
  final db = _makeDb();
  addTearDown(db.close);

  final repo = DriftPlaybackRepository(db);

  final wp = WatchProgress(
    itemKey: 'movie:m1',
    playlistId: _playlistId,
    kind: MediaKind.movie,
    positionSec: 10,
    durationSec: 60,
    updatedAt: DateTime.utc(2026),
  );

  await repo.saveProgress(wp);

  final list = await repo.continueWatching(_playlistId).first;
  expect(list.length, 1);
  expect(list.first.itemKey, 'movie:m1');
});
```

- [ ] **Step 5: Run all drift repo tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/drift_repositories_test.dart 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/data/repositories/repositories.dart lib/data/repositories/drift_playback_repository.dart test/data/repositories/drift_repositories_test.dart
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(repo): add removeProgress to contract; implement in DriftPlaybackRepository"
```

---

## Task 3: FakePlaybackRepository — filter channels, cap 20, removeProgress

**Files:**
- Modify: `lib/data/repositories/fakes/fake_repositories.dart` (`FakePlaybackRepository`)
- Modify: `test/data/repositories/fake_repositories_test.dart`

**Interfaces:**
- Consumes: `PlaybackRepository.removeProgress(String itemKey)` contract from Task 2
- Produces: `FakePlaybackRepository.removeProgress` — removes from `_progress` map and re-emits `_continue`; `continueWatching` filters channel-kind and caps at 20

- [ ] **Step 1: Write failing tests for fake repo**

In `test/data/repositories/fake_repositories_test.dart`, add after the existing `playback repo round-trips saved progress` test:

```dart
  test('fake playback repo continueWatching excludes channel-kind', () async {
    final repo = FakePlaybackRepository();

    await repo.saveProgress(WatchProgress(
      itemKey: 'channel:c1',
      playlistId: 'p1',
      kind: MediaKind.channel,
      positionSec: 10,
      durationSec: 60,
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await repo.saveProgress(WatchProgress(
      itemKey: 'movie:m1',
      playlistId: 'p1',
      kind: MediaKind.movie,
      positionSec: 42,
      durationSec: 120,
      updatedAt: DateTime.utc(2026, 1, 2),
    ));

    final list = await repo.continueWatching('p1').first;
    expect(list, hasLength(1));
    expect(list.first.itemKey, 'movie:m1');
  });

  test('fake playback repo removeProgress removes item and re-emits', () async {
    final repo = FakePlaybackRepository();

    await repo.saveProgress(WatchProgress(
      itemKey: 'movie:m1',
      playlistId: 'p1',
      kind: MediaKind.movie,
      positionSec: 42,
      durationSec: 120,
      updatedAt: DateTime.utc(2026),
    ));

    expect(await repo.progressFor('movie:m1'), isNotNull);

    await repo.removeProgress('movie:m1');

    expect(await repo.progressFor('movie:m1'), isNull);
    final list = await repo.continueWatching('p1').first;
    expect(list, isEmpty);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/fake_repositories_test.dart 2>&1 | tail -20
```

Expected: Compile error — `removeProgress` not yet implemented in `FakePlaybackRepository`. After implementing the contract fix in Task 2, this becomes a runtime failure (method missing on concrete class).

- [ ] **Step 3: Update `FakePlaybackRepository`**

In `lib/data/repositories/fakes/fake_repositories.dart`, replace the entire `FakePlaybackRepository` class:

```dart
/// In-memory [PlaybackRepository] with no seeded progress.
class FakePlaybackRepository implements PlaybackRepository {
  final _progress = <String, WatchProgress>{};
  final _continue = _Store<List<WatchProgress>>([]);

  List<WatchProgress> _filtered() {
    final all = _progress.values
        .where((p) => p.kind != MediaKind.channel)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all.take(20).toList();
  }

  @override
  Future<WatchProgress?> progressFor(String itemKey) async => _progress[itemKey];

  @override
  Future<void> saveProgress(WatchProgress p) async {
    _progress[p.itemKey] = p;
    _continue.value = _filtered();
  }

  @override
  Future<void> removeProgress(String itemKey) async {
    _progress.remove(itemKey);
    _continue.value = _filtered();
  }

  @override
  Stream<List<WatchProgress>> continueWatching(String playlistId) => _continue.stream;
}
```

- [ ] **Step 4: Run fake repo tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/data/repositories/fake_repositories_test.dart 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/data/repositories/fakes/fake_repositories.dart test/data/repositories/fake_repositories_test.dart
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(repo): FakePlaybackRepository filters channels, caps 20, implements removeProgress"
```

---

## Task 4: HomeState and HomeCubit — remove channels, add removeFromContinueWatching

**Files:**
- Modify: `lib/features/home/cubit/home_state.dart`
- Modify: `lib/features/home/cubit/home_cubit.dart`
- Modify: `test/features/home/home_cubit_test.dart`

**Interfaces:**
- Consumes: `PlaybackRepository.removeProgress(String itemKey)` from Task 2
- Produces:
  - `HomeState` without `channels` field
  - `HomeCubit.removeFromContinueWatching(String itemKey) → Future<void>`

- [ ] **Step 1: Write failing cubit tests**

Replace the contents of `test/features/home/home_cubit_test.dart` entirely:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/home/cubit/home_cubit.dart';

void main() {
  group('HomeCubit', () {
    test('load() emits state with non-empty movies and series', () async {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.movies, isNotEmpty);
      expect(cubit.state.series, isNotEmpty);
      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('initial state has no channels field', () {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.movies, isEmpty);
      expect(cubit.state.series, isEmpty);
      expect(cubit.state.continueWatching, isEmpty);
      // HomeState no longer has a channels field.
    });

    test('HomeState copyWith returns updated fields', () {
      const initial = HomeState();
      final updated = initial.copyWith(loading: true);

      expect(updated.loading, isTrue);
      expect(updated.movies, isEmpty);
    });

    test('HomeState props equality works correctly', () {
      const s1 = HomeState();
      const s2 = HomeState();
      expect(s1, equals(s2));
    });

    test('removeFromContinueWatching removes item from state', () async {
      final playback = FakePlaybackRepository();
      final cubit = HomeCubit(
        FakeContentRepository(),
        playback,
        FakePlaylistRepository(),
      );

      await cubit.load();

      // Seed a movie progress entry via the repository directly.
      await playback.saveProgress(WatchProgress(
        itemKey: 'movie:m1',
        playlistId: 'p1',
        kind: MediaKind.movie,
        positionSec: 42,
        durationSec: 120,
        updatedAt: DateTime.utc(2026),
      ));

      // Give the stream a tick to propagate.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.continueWatching, isNotEmpty);

      await cubit.removeFromContinueWatching('movie:m1');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.continueWatching, isEmpty);

      await cubit.close();
    });
  });
}
```

- [ ] **Step 2: Run tests to see them fail**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home/home_cubit_test.dart 2>&1 | tail -20
```

Expected: Compile errors — `HomeState` still has `channels`, `HomeCubit` doesn't have `removeFromContinueWatching`.

- [ ] **Step 3: Update `HomeState` — remove channels**

Replace `lib/features/home/cubit/home_state.dart` entirely:

```dart
part of 'home_cubit.dart';

class HomeState extends Equatable {
  const HomeState({
    this.loading = false,
    this.movies = const [],
    this.series = const [],
    this.continueWatching = const [],
  });

  final bool loading;
  final List<VodItem> movies;
  final List<Series> series;
  final List<WatchProgress> continueWatching;

  HomeState copyWith({
    bool? loading,
    List<VodItem>? movies,
    List<Series>? series,
    List<WatchProgress>? continueWatching,
  }) {
    return HomeState(
      loading: loading ?? this.loading,
      movies: movies ?? this.movies,
      series: series ?? this.series,
      continueWatching: continueWatching ?? this.continueWatching,
    );
  }

  @override
  List<Object> get props => [loading, movies, series, continueWatching];
}
```

- [ ] **Step 4: Update `HomeCubit` — remove channels subscription, add removeFromContinueWatching**

Replace `lib/features/home/cubit/home_cubit.dart` entirely:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._content, this._playback, this._playlists)
      : super(const HomeState());

  final ContentRepository _content;
  final PlaybackRepository _playback;
  final PlaylistRepository _playlists;

  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<WatchProgress>>? _continueSub;

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

    _moviesSub = _content.movies(pid).listen(
      (movies) => emit(state.copyWith(movies: movies, loading: false)),
    );
    _seriesSub = _content.series(pid).listen(
      (series) => emit(state.copyWith(series: series)),
    );
    _continueSub = _playback.continueWatching(pid).listen(
      (cw) => emit(state.copyWith(continueWatching: cw)),
    );
  }

  Future<void> removeFromContinueWatching(String itemKey) async {
    await _playback.removeProgress(itemKey);
  }

  @override
  Future<void> close() async {
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _continueSub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 5: Run cubit tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home/home_cubit_test.dart 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/home/cubit/home_state.dart lib/features/home/cubit/home_cubit.dart test/features/home/home_cubit_test.dart
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(home): remove channels from HomeState; add removeFromContinueWatching to HomeCubit"
```

---

## Task 5: HomeScreen — remove Live rail, wire long-press remove

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `HomeState.channels` no longer exists; `HomeCubit.removeFromContinueWatching(String itemKey)` from Task 4
- Produces: `HomeScreen` without `onOpenChannel` param; no `_ChannelsRail`; CW cards have `GestureDetector(onLongPress:...)` calling `removeFromContinueWatching`

- [ ] **Step 1: Write failing screen tests**

Replace `test/features/home/home_screen_test.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/features/home/home_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({
  void Function(VodItem)? onOpenMovie,
  void Function(Series)? onOpenSeries,
  VoidCallback? onAddPlaylist,
}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeScreen(
      onOpenMovie: onOpenMovie ?? (_) {},
      onOpenSeries: onOpenSeries ?? (_) {},
      onAddPlaylist: onAddPlaylist ?? () {},
    ),
  );
}

/// Pump the widget and suppress layout-overflow FlutterErrors.
Future<void> _pumpAndIgnoreOverflow(WidgetTester tester, Widget widget) async {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previousHandler?.call(details);
  };
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  FlutterError.onError = previousHandler;
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('HomeScreen renders a movie title from fakes', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    final titleFinder = find.textContaining(
      RegExp('The Signal|Dune'),
      skipOffstage: false,
    );
    expect(titleFinder, findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen renders Movies rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.text('Movies', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen renders Series rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.text('Series', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen does NOT render Live TV rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // The Live TV rail has title 'Live' (from l10n.live).
    // We use skipOffstage: false to catch rails that are scrolled offscreen.
    expect(find.text('Live', skipOffstage: false), findsNothing);
  });

  testWidgets('HomeScreen tapping Play button triggers onOpenMovie',
      (tester) async {
    VodItem? tappedMovie;
    await _pumpAndIgnoreOverflow(
      tester,
      _buildTestApp(onOpenMovie: (m) => tappedMovie = m),
    );

    final playFinder = find.text('Play');
    expect(playFinder, findsAtLeastNWidgets(1));

    final previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousHandler?.call(details);
    };
    await tester.tap(playFinder.first);
    await tester.pumpAndSettle();
    FlutterError.onError = previousHandler;

    expect(tappedMovie, isNotNull);
  });
}
```

- [ ] **Step 2: Run failing screen tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home/home_screen_test.dart 2>&1 | tail -20
```

Expected: Compile error — `HomeScreen` still requires `onOpenChannel`. After next step it will pass compile and the `does NOT render Live TV rail` test will fail (Live rail still present).

- [ ] **Step 3: Update `home_screen.dart` — remove Live rail, wire long-press**

Replace `lib/features/home/home_screen.dart` entirely with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_rail.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/poster_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/home_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onAddPlaylist,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final VoidCallback onAddPlaylist;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(
        sl<ContentRepository>(),
        sl<PlaybackRepository>(),
        sl<PlaylistRepository>(),
      )..load(),
      child: _HomeView(
        onOpenMovie: onOpenMovie,
        onOpenSeries: onOpenSeries,
        onAddPlaylist: onAddPlaylist,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.onOpenMovie,
    required this.onOpenSeries,
    required this.onAddPlaylist,
  });

  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;
  final VoidCallback onAddPlaylist;

  bool _hasContent(HomeState state) =>
      state.movies.isNotEmpty || state.series.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_hasContent(state)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No content yet'),
                const SizedBox(height: 16),
                FocusableButton(
                  semanticLabel: 'Set up a playlist',
                  onPressed: onAddPlaylist,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Set up a playlist',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroBanner(
                movies: state.movies,
                onOpenMovie: onOpenMovie,
              ),
            ),
            if (state.continueWatching.isNotEmpty)
              SliverToBoxAdapter(
                child: _ContinueWatchingRail(
                  items: state.continueWatching,
                  movies: state.movies,
                  series: state.series,
                  onOpenMovie: onOpenMovie,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            if (state.movies.isNotEmpty)
              SliverToBoxAdapter(
                child: _MoviesRail(
                  movies: state.movies,
                  onOpenMovie: onOpenMovie,
                ),
              ),
            if (state.series.isNotEmpty)
              SliverToBoxAdapter(
                child: _SeriesRail(
                  series: state.series,
                  onOpenSeries: onOpenSeries,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.movies,
    required this.onOpenMovie,
  });

  final List<VodItem> movies;
  final void Function(VodItem) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    final featured = movies.first;
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  p.surface2,
                  p.bg,
                ],
              ),
            ),
          ),
          if (featured.posterUrl != null)
            Opacity(
              opacity: 0.3,
              child: Image.network(
                featured.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          // Gradient scrim over backdrop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  p.bg,
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          // Content
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    featured.title,
                    style: textTheme.displaySmall?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (featured.year != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      featured.year!,
                      style: textTheme.bodyLarge?.copyWith(color: p.dim),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FocusableButton(
                        semanticLabel: l10n.play,
                        onPressed: () => onOpenMovie(featured),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.black, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.play,
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FocusableButton(
                        semanticLabel: l10n.moreInfo,
                        onPressed: () => onOpenMovie(featured),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: p.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: p.fg, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.moreInfo,
                                style: textTheme.labelLarge?.copyWith(
                                  color: p.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingRail extends StatelessWidget {
  const _ContinueWatchingRail({
    required this.items,
    required this.movies,
    required this.series,
    required this.onOpenMovie,
    required this.onOpenSeries,
  });

  final List<WatchProgress> items;
  final List<VodItem> movies;
  final List<Series> series;
  final void Function(VodItem) onOpenMovie;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    final cards = items.map((progress) {
      final progress0 = progress.durationSec > 0
          ? progress.positionSec / progress.durationSec
          : 0.0;

      Widget card;

      // Try to find the matching movie
      final movie = movies.cast<VodItem?>().firstWhere(
            (m) =>
                m?.id == progress.itemKey ||
                'movie:${m?.id}' == progress.itemKey,
            orElse: () => null,
          );
      if (movie != null) {
        card = PosterCard(
          title: movie.title,
          subtitle: movie.year,
          imageUrl: movie.posterUrl,
          progress: progress0.clamp(0.0, 1.0),
          onTap: () => onOpenMovie(movie),
        );
      } else {
        // Try to find the matching series
        final show = series.cast<Series?>().firstWhere(
              (s) =>
                  s?.id == progress.itemKey ||
                  'series:${s?.id}' == progress.itemKey,
              orElse: () => null,
            );
        if (show != null) {
          card = PosterCard(
            title: show.title,
            subtitle: show.year,
            imageUrl: show.posterUrl,
            progress: progress0.clamp(0.0, 1.0),
            onTap: () => onOpenSeries(show),
          );
        } else {
          card = PosterCard(
            title: progress.itemKey,
            progress: progress0.clamp(0.0, 1.0),
            onTap: () {},
          );
        }
      }

      return GestureDetector(
        onLongPress: () => cubit.removeFromContinueWatching(progress.itemKey),
        child: card,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(
        title: 'Continue Watching',
        items: cards,
      ),
    );
  }
}

class _MoviesRail extends StatelessWidget {
  const _MoviesRail({
    required this.movies,
    required this.onOpenMovie,
  });

  final List<VodItem> movies;
  final void Function(VodItem) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = movies
        .map(
          (m) => PosterCard(
            title: m.title,
            subtitle: m.year,
            imageUrl: m.posterUrl,
            onTap: () => onOpenMovie(m),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.movies, items: cards),
    );
  }
}

class _SeriesRail extends StatelessWidget {
  const _SeriesRail({
    required this.series,
    required this.onOpenSeries,
  });

  final List<Series> series;
  final void Function(Series) onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = series
        .map(
          (s) => PosterCard(
            title: s.title,
            subtitle: s.year,
            imageUrl: s.posterUrl,
            onTap: () => onOpenSeries(s),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ContentRail(title: l10n.series, items: cards),
    );
  }
}
```

- [ ] **Step 4: Check for any callers of HomeScreen that pass onOpenChannel — fix them**

```bash
grep -rn "onOpenChannel\|HomeScreen(" /Users/AbdelazizMahdy/flutter_projects/Iptv/lib/ --include="*.dart" | grep -v "home_screen.dart"
```

For each caller found, remove the `onOpenChannel` named argument. Typically this is in the router or shell file. Example fix: if `lib/features/shell/shell_screen.dart` has:

```dart
HomeScreen(
  onOpenMovie: ...,
  onOpenSeries: ...,
  onOpenChannel: ...,   // DELETE THIS LINE
  onAddPlaylist: ...,
),
```

Remove only the `onOpenChannel: ...,` line.

- [ ] **Step 5: Run screen tests**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home/home_screen_test.dart 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 6: Run full target test suites**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home test/data/repositories 2>&1 | tail -30
```

Expected: All tests PASS.

- [ ] **Step 7: Run flutter analyze on edited files**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter analyze lib/features/home/ lib/data/repositories/ lib/data/db/ 2>&1 | tail -20
```

Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/home/home_screen.dart test/features/home/home_screen_test.dart
# Also stage any callers that were fixed (e.g. lib/features/shell/shell_screen.dart)
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(home): drop live rail; CW cards long-press to remove"
```

---

## Task 6: Final commit and report

- [ ] **Step 1: Run full target test suites one final time**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter test test/features/home test/data/repositories 2>&1 | tail -30
```

Expected: All tests PASS.

- [ ] **Step 2: Run flutter analyze**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
flutter analyze lib/features/home/ lib/data/repositories/ lib/data/db/ 2>&1 | tail -20
```

Expected: No issues found.

- [ ] **Step 3: Stage all changes and make the single required commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(home): drop live rail; continue-watching excludes live, caps 20, supports remove"
```

If `git add` fails with `index.lock` error, wait 3 seconds and retry:
```bash
sleep 3
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(home): drop live rail; continue-watching excludes live, caps 20, supports remove"
```

- [ ] **Step 4: Write the report**

Create `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-home-report.md` with:
- Status (success/failure)
- Commit hash (`git rev-parse HEAD`)
- One-line test summary (count passing)
- Any concerns

---

## Self-Review Against Spec

| Spec Requirement | Task |
|-----------------|------|
| Remove Live TV rail from `home_screen.dart` | Task 5 |
| Remove `channels` subscription from `home_cubit.dart` | Task 4 |
| Remove `channels` from `HomeState` props/copyWith | Task 4 |
| `continueWatching` drops `MediaKind.channel` entries | Tasks 1, 3 |
| `continueWatching` caps at 20 most-recent (Drift) | Task 1 |
| Add `removeProgress(String itemKey)` to contract | Task 2 |
| Implement `DriftPlaybackRepository.removeProgress` | Task 2 |
| Implement `FakePlaybackRepository.removeProgress` | Task 3 |
| Add `HomeCubit.removeFromContinueWatching` | Task 4 |
| Long-press on CW card calls removeFromContinueWatching | Task 5 |
| Tests: continueWatching excludes channel, keeps movie | Tasks 1, 3 |
| Tests: removeProgress deletes (progressFor null, gone from stream) | Tasks 1, 2, 3 |
| Tests: no live rail in home_screen_test | Task 5 |
| Tests: home_cubit_test updated for removed channels field | Task 4 |
| Tests: removeFromContinueWatching cubit test | Task 4 |
| `flutter test test/features/home test/data/repositories` green | Task 6 |
| `flutter analyze` clean on edited files | Task 6 |
