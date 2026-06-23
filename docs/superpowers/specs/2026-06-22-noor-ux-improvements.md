# NOOR IPTV — UX Improvements Pass

**Date:** 2026-06-22
**Status:** Approved direction; pending spec review before plan.
**Builds on:** `docs/superpowers/specs/2026-06-21-noor-iptv-design.md` (the app is built; this is a polish/feature pass driven by real-device feedback testing against a live Xtream provider).

## Goal

Fix concrete UX problems found while running the app against a real Xtream playlist, following Netflix-style patterns, and make long lists performant.

## Cross-cutting requirements (apply to every item)

- **Lazy builders everywhere.** Every potentially-long list or grid MUST use a lazy builder (`ListView.builder`/`.separated`, `GridView.builder`, `SliverList`/`SliverGrid` with `SliverChildBuilderDelegate`). No eager `children: [...]` for data-driven collections (real playlists have hundreds–thousands of channels/movies and dozens of categories). Category chip rows included.
- **Adaptive + RTL preserved.** Wide (TV/desktop) vs narrow (phone) layouts; honor existing accessibility (textScaler, reduce-motion, high-contrast, focus traversal) and EN/AR RTL.
- **Equatable state (no freezed) in features; no new codegen** unless a drift table changes (then bump `schemaVersion` + migration).
- **TDD:** cubit tests for logic, widget smoke tests for new layouts.

## 1. Category names (root fix)

**Problem:** Movies/Series filter chips render raw category IDs ("407", "567"); Live TV has no real group names. The app stores `categoryId` but never the category name.

**Design:**
- New drift table `Categories(playlistId TEXT, type TEXT[live|vod|series], categoryId TEXT, name TEXT)`, primary key `{playlistId, type, categoryId}`. Bump `schemaVersion` (→ next) with a migration creating the table.
- `XtreamSource.fetchAll` additionally fetches `liveStreamCategoriesData` / `vodCategoriesData` / `seriesCategoriesData` and returns them in `XtreamContent` (add `categories`).
- `DriftContentRepository.importPlaylist` persists categories (replace per playlist+type).
- `ContentRepository` gains `Future<List<({String id, String name})>> categories(String playlistId, MediaKind kind)` (or a small `Category` value type). Grid + Live resolve `categoryId → name`; if a name is missing, fall back to the id.
- **M3U:** `group-title` already IS the name; treat the m3u categoryId as the display name directly (no lookup needed). The resolver returns the id unchanged when no Categories row exists.

## 2. Live TV — sidebar groups + channel grid

**Problem:** the two-axis EPG grid renders poorly and isn't the desired model.

**Design:**
- Replace the EPG-grid Live screen with an adaptive groups→channels view:
  - **Wide (≥ rail breakpoint):** left sidebar lists category groups (lazy `ListView.builder`); selecting a group shows its channels in a lazy grid/list on the right.
  - **Phone:** a groups list (`ListView.builder`); tapping a group pushes a channel-list screen; tapping a channel plays.
- Tap a channel → `context.push('/player', extra: PlayerArgs(... channel ...))` → full-screen player.
- `LiveCubit` loads channels for the active playlist and groups them by `categoryId`, resolving names via item 1. State: `{loading, groups: List<({id,name,count})>, selectedGroupId, channelsInGroup}` (Equatable). Channels fetched lazily/streamed; do not build all channel widgets eagerly.
- The two-axis EPG grid and its sticky-header code are removed from the Live screen. `EpgRepository` stays in the data layer for a future "now/next" badge (out of scope here).

## 3. Details hero — Netflix ambient + series Play

**Problem:** vertical poster art cover-cropped into a wide hero looks bad (blurry slice); series has no Play button.

**Design:**
- Hero: a blurred, darkened copy of the poster fills the hero area (`ImageFiltered`/blur + dark scrim); the **full sharp poster** is shown on top with `BoxFit.contain` in a portrait frame — never cropped. Title/meta/actions sit beside the poster on wide screens, stacked below on phone. Backdrop height stays capped relative to viewport.
- **Series:** add a primary **Play** button that plays the first episode (or resumes via watch progress) — `onPlayEpisode(firstOrResumeEpisode)`. Keep the episode list + season chips below. **Movies** keep their Play button.
- Graceful fallbacks: missing poster → existing gradient placeholder; missing description → localized "No description available" (already added).

## 4. Search — remove on-screen keyboard

**Problem:** the on-screen keyboard wastes space; results feel sparse.

**Design:**
- Remove the on-screen keyboard entirely. Use a single focused system `TextField` (autofocus) bound to `SearchCubit.setQuery`. On Android TV the remote drives the focused field + focus traversal into results.
- Results use a lazy `GridView.builder` filling the freed space, with tighter spacing (see item 5).

## 5. Density

- Reduce poster-grid spacing/padding across Movies, Series, Search, Favorites (smaller cross-axis spacing/run spacing, smaller outer padding) for a denser, more content-forward layout. Keep poster aspect ratio (2:3) and focus rings intact.

## 6. Player volume control

**Problem:** no working volume control.

**Design:**
- `PlayerController` interface gains `Future<void> setVolume(double)` and a `double volume` (0.0–1.0); `VideoPlayerControllerAdapter` implements via `video_player`'s `setVolume`; `FakePlayerController` tracks it for tests.
- `PlayerCubit` gains `setVolume(double)` + `toggleMute()` (remembers pre-mute level); state carries `volume` + `muted`.
- UI: a volume control in the transport bar near CC/audio — a slider on desktop, mute/volume affordance reachable by focus on TV. Honors the existing control-bar styling.

## Out of scope (this pass)

EPG now/next badges, Chromecast, manual quality switching, onboarding first-run gating, colorblind-safe palette implementation, favorites→detail resolution (tracked separately).

## Testing strategy

- **Cubits:** category-name resolution + fallback; Live grouping by category; series Play target selection (first vs resume); player setVolume/toggleMute/state.
- **Widgets:** Live wide (sidebar+grid) and phone (drill-in) smoke tests with fakes; ambient details hero renders poster + Play for series; Search renders a system field and results with no on-screen keyboard; grids use builders (verify a long list scrolls / not all built — at least a smoke test).
- **Data:** Categories table round-trip; XtreamSource category mapping (pure).
- Full suite + `flutter analyze` clean + macOS build after integration.
