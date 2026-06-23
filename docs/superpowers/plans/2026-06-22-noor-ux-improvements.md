# NOOR UX Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Fix six real-device UX problems — category names, Live TV layout, Netflix-style details hero, search keyboard removal, grid density, and player volume — and make all long lists lazy.

**Architecture:** Flutter + flutter_bloc/Cubit, drift, go_router, get_it. Features depend on `core/` + repository contracts. Equatable state (no freezed in features). Production uses real drift repos; tests use fakes (`configureDependencies()` + `installFakeHydratedStorage()`).

**Tech Stack:** drift, video_player/fvp, dio, xtream_code_client.

## Global Constraints

- **Lazy builders only** for data-driven lists/grids: `ListView.builder`/`.separated`, `GridView.builder`, or slivers with `SliverChildBuilderDelegate`. No eager `children: [...]` for collections (including category chip rows).
- Adaptive: wide (≥ `NoorBreakpoints.rail` = 700) vs phone. Preserve a11y (textScaler, reduce-motion via `AccessibilityCubit`, focus rings via `FocusableButton`) and EN/AR RTL (`EdgeInsetsDirectional`, no physical left/right).
- Features use Equatable state; no freezed/codegen in feature layer. Drift table changes require `schemaVersion` bump + `MigrationStrategy.onUpgrade`.
- Theme tokens via `context.palette` (`core/theme/app_theme.dart`): bg/bg2/surface/surface2/border/fg/dim/focus/accent/accent2/live. Accent is violet `#A78BFA`.
- Commit per task with `git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com"`.
- Each task: write failing test → verify fail → implement → verify pass → `flutter analyze` (your files) clean → commit. Do not run the full suite/macOS build per task (coordinator does that at the end).
- Current contracts to read first: `lib/data/repositories/repositories.dart`, `lib/data/db/database.dart` + `tables.dart`, `lib/data/sources/xtream_source.dart`, `lib/features/player/video_controller.dart`.

---

## Task 1: Categories data layer (table + source + repository)

**Files:**
- Modify: `lib/data/db/tables.dart` (add `Categories` table)
- Modify: `lib/data/db/database.dart` (register table, bump schemaVersion, migration, queries)
- Modify: `lib/data/sources/xtream_source.dart` (fetch categories)
- Modify: `lib/data/repositories/repositories.dart` (contract method)
- Modify: `lib/data/repositories/drift_content_repository.dart` (persist + read)
- Modify: `lib/data/repositories/fakes/fake_repositories.dart` (fake impl)
- Test: `test/data/db/database_test.dart`, `test/data/repositories/drift_repositories_test.dart`

**Interfaces:**
- Produces:
  - drift `@DataClassName('CategoryRow') class Categories` with `TextColumn playlistId`, `TextColumn type`, `TextColumn categoryId`, `TextColumn name`; PK `{playlistId, type, categoryId}`.
  - `AppDatabase.replaceCategories(String playlistId, String type, List<CategoriesCompanion>)` and `Future<List<CategoryRow>> getCategories(String playlistId, String type)`.
  - `ContentRepository.categories(String playlistId, MediaKind kind) → Future<List<CategoryRef>>` where `class CategoryRef extends Equatable { final String id; final String name; }` (new file `lib/data/models/category_ref.dart`, exported from `models.dart`). `MediaKind.channel→'live'`, `movie→'vod'`, `episode`/series→'series' (map series via a helper; use 'vod' for movies, 'series' for series, 'live' for channels).
  - `XtreamContent` gains `final List<({String type, String id, String name})> categories;`

- [ ] **Step 1: Write failing DB test**

Add to `test/data/db/database_test.dart`:
```dart
test('replaceCategories stores and getCategories retrieves by type', () async {
  await db.replaceCategories('p1', 'vod', [
    CategoriesCompanion.insert(playlistId: 'p1', type: 'vod', categoryId: '407', name: 'Action'),
  ]);
  final rows = await db.getCategories('p1', 'vod');
  expect(rows.single.name, 'Action');
  expect(await db.getCategories('p1', 'live'), isEmpty);
});
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/data/db/database_test.dart`
Expected: FAIL (table/methods undefined).

- [ ] **Step 3: Add the table + queries + migration**

In `tables.dart` add:
```dart
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get playlistId => text()();
  TextColumn get type => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {playlistId, type, categoryId};
}
```
In `database.dart`: add `Categories` to `@DriftDatabase(tables: [...])`; bump `schemaVersion` to the next integer; ensure `MigrationStrategy` has `onUpgrade` that calls `await m.createTable(categories)` when upgrading from the prior version (and `onCreate: (m) => m.createAll()`). Add:
```dart
Future<void> replaceCategories(String playlistId, String type, List<CategoriesCompanion> rows) =>
    batch((b) {
      b.deleteWhere(categories, (t) => t.playlistId.equals(playlistId) & t.type.equals(type));
      b.insertAll(categories, rows, mode: InsertMode.insertOrReplace);
    });
Future<List<CategoryRow>> getCategories(String playlistId, String type) =>
    (select(categories)..where((t) => t.playlistId.equals(playlistId) & t.type.equals(type))).get();
```
Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/data/db/database_test.dart` → PASS.

- [ ] **Step 5: Add CategoryRef model + contract method + source + repo + fake**

Create `lib/data/models/category_ref.dart`:
```dart
import 'package:equatable/equatable.dart';
class CategoryRef extends Equatable {
  final String id;
  final String name;
  const CategoryRef({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}
```
Export it from `lib/data/models/models.dart`. Add to `ContentRepository`:
```dart
Future<List<CategoryRef>> categories(String playlistId, MediaKind kind);
```
In `xtream_source.dart`: add `categories` to `XtreamContent`; in `fetchAll`, also call the client's `liveStreamCategoriesData()`/`vodCategoriesData()`/`seriesCategoriesData()` (introspect the package for exact names — confirmed present earlier) and map each to `(type, id, name)` using the category's id + categoryName. Tag types `'live'`/`'vod'`/`'series'`.
In `drift_content_repository.dart`: in `importPlaylist` xtream branch, persist categories via `replaceCategories(p.id, type, ...)` per type. Implement `categories(playlistId, kind)`: map kind→type (`channel→live`, `movie→vod`, else `series`), read `getCategories`, map rows→`CategoryRef`. For m3u (no Categories rows) return `[]` (caller falls back to ids/group-titles).
In `fake_repositories.dart`: implement `categories(...)` returning a couple of sample `CategoryRef`s (e.g. for movies: `CategoryRef(id:'cat1', name:'Action')`).

- [ ] **Step 6: Write failing repo test + implement until pass**

Add to `test/data/repositories/drift_repositories_test.dart` a test seeding categories via the shared db and asserting `DriftContentRepository.categories('p1', MediaKind.movie)` returns the mapped names. Run that test file until PASS. Run `flutter analyze` on changed files.

- [ ] **Step 7: Commit**

```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(data): fetch and store provider category names"
```

---

## Task 2: Movies/Series grid — real category names + density + lazy builders

**Files:**
- Modify: `lib/features/grid/cubit/grid_cubit.dart` (resolve names)
- Modify: `lib/features/grid/grid_screen.dart` (lazy chip row + denser grid)
- Test: `test/features/grid/grid_cubit_test.dart`, `test/features/grid/grid_screen_test.dart`

**Interfaces:**
- Consumes: `ContentRepository.categories(playlistId, kind)` (Task 1).

- [ ] **Step 1: Write failing cubit test**

In `grid_cubit_test.dart`, assert that after `load()` the cubit's category chips expose human names from `FakeContentRepository.categories` (e.g. contains 'Action'), not raw ids, and an 'All' chip exists. Use the fakes.

- [ ] **Step 2: Verify fail**

Run: `flutter test test/features/grid/grid_cubit_test.dart` → FAIL.

- [ ] **Step 3: Implement name resolution**

In `grid_cubit.dart`: after loading items, also `await _content.categories(pid, kind)` and build chips as `{id, name}` (use `CategoryRef`). Keep filtering by the item's `categoryId` but display the resolved `name` (fall back to the id when no match). State holds `List<CategoryRef> categories` (plus the synthetic All). Filtering compares the entry's `categoryId` to the selected `CategoryRef.id`.

- [ ] **Step 4: Verify pass**

Run: `flutter test test/features/grid/grid_cubit_test.dart` → PASS.

- [ ] **Step 5: Lazy chip row + denser grid**

In `grid_screen.dart`: render the chip row with a horizontal `ListView.builder` (not a `Wrap` of all chips). Reduce grid density: `SliverGrid.builder`/`GridView.builder` with `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2/3.4)` (tighter than current) and smaller outer padding (e.g. 12). Keep `PosterCard`.

- [ ] **Step 6: Update widget test + verify**

Update `grid_screen_test.dart` to assert a category name renders (e.g. 'Action') and a movie title renders; run `flutter test test/features/grid` → PASS; `flutter analyze` changed files.

- [ ] **Step 7: Commit**

```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(grid): real category names, lazy chips, denser grid"
```

---

## Task 3: Live TV — sidebar groups + channel grid → full-screen player

**Files:**
- Rewrite: `lib/features/live/cubit/live_cubit.dart` + state
- Rewrite: `lib/features/live/live_screen.dart`
- Create: `lib/features/live/channel_list_screen.dart` (phone drill-in)
- Modify: `lib/core/router/app_router.dart` (channel-list route if needed; LiveScreen already wired)
- Test: `test/features/live/live_cubit_test.dart`, `test/features/live/live_screen_test.dart`

**Interfaces:**
- Consumes: `ContentRepository.channels(pid)`, `ContentRepository.categories(pid, MediaKind.channel)`, `PlaylistRepository.active()`.
- Produces: `LiveScreen({required void Function(Channel) onPlayChannel})` (unchanged signature — keep router wiring).

- [ ] **Step 1: Write failing cubit test**

`live_cubit_test.dart`: construct `LiveCubit(FakeContentRepository(), FakePlaylistRepository())` (drop EpgRepository dependency — Live no longer uses EPG). After `load()`, assert `state.groups` is non-empty (grouped by category, names resolved) and selecting a group exposes that group's channels.

- [ ] **Step 2: Verify fail**

Run: `flutter test test/features/live/live_cubit_test.dart` → FAIL.

- [ ] **Step 3: Implement LiveCubit**

`LiveCubit(this._content, this._playlists)`: `load()` resolves `pid`, reads channel categories (`CategoryRef`s) + subscribes to `channels(pid)`. Build `groups: List<({String id, String name, int count})>` from the channels' `categoryId` (resolve name via categories; group label falls back to id; include an "All" group). State (Equatable): `{bool loading, List<({String id,String name,int count})> groups, String? selectedGroupId, List<Channel> channelsInGroup}`. `selectGroup(String id)` filters channels by categoryId (or all). Cancel subscription in `close()`.

- [ ] **Step 4: Verify pass**

Run: `flutter test test/features/live/live_cubit_test.dart` → PASS.

- [ ] **Step 5: Rewrite LiveScreen (adaptive, lazy)**

Wide (`MediaQuery.sizeOf(context).width >= 700`): a `Row` of a left sidebar (`ListView.builder` of groups, selected highlighted with accent) + right channel grid (`GridView.builder`) of channel tiles (logo/abbr + name + number) each a `FocusableButton` → `onPlayChannel(channel)`. Phone: a groups `ListView.builder`; tapping a group `Navigator.push` to `ChannelListScreen(groupName, channels, onPlayChannel)`. Remove all EPG two-axis grid code. Use `context.palette`, RTL-safe insets.

- [ ] **Step 6: Implement ChannelListScreen + update widget test**

`channel_list_screen.dart`: an AppBar (group name) + `ListView.builder` of channel rows (FocusableButton) → onPlayChannel. Update `live_screen_test.dart`: pump LiveScreen with fakes (setUp `installFakeHydratedStorage()` + `configureDependencies()` + `sl.reset()`); assert a channel name renders and a group label renders; tapping a channel invokes `onPlayChannel`. Run `flutter test test/features/live` → PASS; analyze.

- [ ] **Step 7: Commit**

```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(live): sidebar groups + channel grid, drop EPG grid"
```

---

## Task 4: Details hero — Netflix ambient + series Play

**Files:**
- Modify: `lib/features/details/details_screen.dart`
- Modify: `lib/features/details/cubit/details_cubit.dart` (if needed for first/resume episode)
- Test: `test/features/details/details_screen_test.dart`

**Interfaces:**
- Consumes: existing `DetailsCubit` (reads its current methods first), `WatchProgress` via repo if available.

- [ ] **Step 1: Write failing widget test**

In `details_screen_test.dart` add: pumping `DetailsScreen.series(...)` with fakes shows a **Play** control (find by the localized `play` label) in addition to the episode list. (Currently series has no Play.)

- [ ] **Step 2: Verify fail**

Run: `flutter test test/features/details/details_screen_test.dart` → FAIL (no Play for series).

- [ ] **Step 3: Implement ambient hero**

In `details_screen.dart` `_Backdrop`: replace the cover image with a Stack: (a) bottom layer = the poster via `Image.network` `BoxFit.cover` wrapped in `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), ...)` + a dark scrim (`Container(color: context.palette.bg.withValues(alpha: 0.55))`); (b) centered foreground = the **full** poster `Image.network(..., fit: BoxFit.contain)` constrained to the capped hero height in a portrait box. Keep the back button + bottom gradient. Missing poster → existing `_GradientPlaceholder`. (import `dart:ui` for `ImageFilter`.)

- [ ] **Step 4: Add series Play**

In the series layout, add a primary Play `FocusableButton` (label `AppLocalizations.of(context)!.play`) before/with the episode list. On press, call `onPlayEpisode(target)` where `target` = the first episode of the loaded episodes (or, if a resume episode is identifiable, that one; first is acceptable). If episodes are empty, disable/hide Play. Keep movie Play as-is.

- [ ] **Step 5: Verify pass**

Run: `flutter test test/features/details/details_screen_test.dart` → PASS; `flutter analyze` changed files.

- [ ] **Step 6: Commit**

```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(details): Netflix ambient hero + series Play"
```

---

## Task 5: Search — remove on-screen keyboard, lazy denser results

**Files:**
- Modify: `lib/features/search/search_screen.dart`
- Test: `test/features/search/search_screen_test.dart`

**Interfaces:**
- Consumes: existing `SearchCubit` (unchanged).

- [ ] **Step 1: Update widget test (failing)**

Edit `search_screen_test.dart`: assert the on-screen keyboard is gone — e.g. `expect(find.text('Q'), findsNothing)` and the QWERTY keys are absent — while typing into the `TextField` ('Dune') still shows the 'Dune' result. Run → FAIL (keyboard still present).

- [ ] **Step 2: Implement**

In `search_screen.dart`: delete the `_OnScreenKeyboard` widget and its usage. Keep a single autofocus `TextField` (`autofocus: true`) bound to `SearchCubit.setQuery`. Results: `GridView.builder` (`SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2/3.4)`), smaller padding, filling the freed vertical space. Keep the `noResults`/`resultsLabel` l10n.

- [ ] **Step 3: Verify pass**

Run: `flutter test test/features/search/search_screen_test.dart` → PASS; analyze changed files.

- [ ] **Step 4: Commit**

```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(search): remove on-screen keyboard, lazy denser results"
```

---

## Task 6: Player volume control

**Files:**
- Modify: `lib/features/player/video_controller.dart` (interface + adapter)
- Modify: `lib/features/player/cubit/player_cubit.dart` (+ state)
- Modify: `lib/features/player/player_screen.dart` (UI)
- Test: `test/features/player/player_cubit_test.dart`, `test/features/player/fake_player_controller.dart`

**Interfaces:**
- Produces: `PlayerController.setVolume(double)` + `double volume`; `PlayerCubit.setVolume(double)`, `toggleMute()`; state `volume` + `muted`.

- [ ] **Step 1: Write failing cubit test**

In `player_cubit_test.dart`: `setVolume(0.3)` sets `state.volume == 0.3`; `toggleMute()` sets `muted == true` and volume 0 on the controller, and toggling again restores 0.3.

- [ ] **Step 2: Verify fail**

Run: `flutter test test/features/player/player_cubit_test.dart` → FAIL.

- [ ] **Step 3: Extend controller**

In `video_controller.dart`: add `Future<void> setVolume(double v);` and `double get volume;` to `PlayerController`. Implement in `VideoPlayerControllerAdapter` via the underlying `VideoPlayerController.setVolume` (track the value in a field). In `test/features/player/fake_player_controller.dart` add a `double volume` field + `setVolume`.

- [ ] **Step 4: Extend PlayerCubit**

Add `setVolume(double)` (clamps 0..1, calls controller, emits state.volume), `toggleMute()` (stores pre-mute level, sets 0 or restores). Add `volume` + `muted` to `PlayerUiState` (Equatable, copyWith). Default volume 1.0.

- [ ] **Step 5: Verify pass**

Run: `flutter test test/features/player/player_cubit_test.dart` → PASS.

- [ ] **Step 6: Add UI control**

In `player_screen.dart` transport bar (near CC/audio): add a mute/volume `FocusableButton` (icon `Icons.volume_up`/`Icons.volume_off`) calling `toggleMute()`, and on desktop a compact `Slider` (value `state.volume`, `onChanged: cubit.setVolume`). Use existing control styling; RTL-safe.

- [ ] **Step 7: Verify + commit**

Run: `flutter test test/features/player` → PASS; `flutter analyze` changed files.
```bash
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A
git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(player): working volume slider + mute"
```

---

## Integration & verification (coordinator, after all tasks)

- [ ] `dart run build_runner build --delete-conflicting-outputs` (Task 1 changed drift schema).
- [ ] `flutter analyze` → No issues.
- [ ] `flutter test` → full suite green (update any cross-touched tests, e.g. live no longer takes EpgRepository; router still compiles).
- [ ] `flutter build macos --debug` → succeeds.
- [ ] Commit any integration fixes.

## Self-Review

- **Spec coverage:** §1 categories → Task 1+2; §2 Live → Task 3; §3 details hero+series Play → Task 4; §4 search keyboard → Task 5; §5 density → Tasks 2+5; §6 volume → Task 6; cross-cutting lazy builders → Tasks 2,3,5 (and ContentRail already lazy). All covered.
- **Placeholder scan:** none — concrete code/sizes in each step. Where a step says "introspect the package," it names the exact methods already verified to exist (`*CategoriesData`).
- **Type consistency:** `CategoryRef{id,name}`, `categories(playlistId, kind)`, `replaceCategories/getCategories`, `setVolume/volume/toggleMute`, `LiveCubit(content, playlists)` used consistently across tasks.
- **Parallelism:** Task 1 blocks Tasks 2 & 3 (they consume `categories`). Tasks 4, 5, 6 are independent of 1 and of each other. Suggested waves: Task 1 → then [2, 3, 4, 5, 6] in parallel → integration.
