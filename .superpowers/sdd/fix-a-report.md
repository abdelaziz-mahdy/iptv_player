# Fix-A Report

## Status
All 5 fixes applied cleanly. `flutter analyze` (6 target files): 0 issues. Tests: 27 passed, 0 failed.

## Fixes Applied

### FIX 1 — FocusableButton D-pad/keyboard SELECT
- Replaced `Focus` + `GestureDetector` with `FocusableActionDetector` wrapping an outer `GestureDetector`.
- Shortcuts: Enter, Space, Select, GameButtonA → `ActivateIntent` → `CallbackAction` calling `onPressed`.
- Added optional `autofocus` param (default false) passed through to `FocusableActionDetector`.
- Focus ring driven by `onShowFocusHighlight`.
- Test: kept tap test; added keyboard Enter test with `autofocus: true`.

### FIX 2 — Settings & Playlists reachable from shell
- `AdaptiveShell`: added `VoidCallback? onOpenSettings` and `VoidCallback? onOpenPlaylists`.
- Wide layout: trailing pinned `Column` with `IconButton`s (Icons.playlist_play, Icons.settings) in `Expanded > Align(bottomCenter)`.
- Narrow layout: `SafeArea` top bar with brand text, Spacer, Playlists and Settings `IconButton`s above the body.
- `app_router.dart`: passes `onOpenSettings: () => context.push('/settings')` and `onOpenPlaylists: () => context.push('/playlists')` to `AdaptiveShell`.
- Tests: added wide + narrow assertions for `find.byIcon(Icons.settings)` and callback invocation.

### FIX 3 — Home empty-state CTA
- `HomeScreen`: added `required VoidCallback onAddPlaylist` constructor param.
- `_HomeView`: added `_hasContent()` helper; when false, renders centered "No content yet" + "Set up a playlist" `FocusableButton`.
- `app_router.dart`: passes `onAddPlaylist: () => context.push('/import')`.
- Tests: `_buildTestApp` updated to pass `onAddPlaylist` (defaults to `() {}`); existing tests remain green.

### FIX 4 — Safe route extra casts
- `/details/movie`: `state.extra as VodItem?` — returns fallback Scaffold if null.
- `/details/series`: `state.extra as Series?` — returns fallback Scaffold if null.
- `/player`: `state.extra as PlayerArgs?` — returns fallback Scaffold if null.

### FIX 5 — Player progress with real kind + playlistId
- `PlayerCubit`: added `required MediaKind kind` and `required String playlistId`; used in `_saveProgress`.
- `PlayerScreen`: added `required MediaKind kind` and `required String playlistId`; passed to cubit constructor.
- `PlayerArgs`: extended with `MediaKind kind` and `String playlistId`.
- Push sites: channel → `MediaKind.channel`, movie → `MediaKind.movie`, episode → `MediaKind.episode`.
- `playlistId` sourced from model (`c.playlistId`, `m.playlistId`) or falls back to `'p1'` (Episode has no playlistId field).
- Tests: all cubit/screen tests updated with `kind: MediaKind.movie, playlistId: 'p1'`; added assertion for stored kind/playlistId.

## Concerns
- Episode model lacks `playlistId` — router falls back to `'p1'`. A future task should propagate playlistId through the Series/Season/Episode hierarchy.
- The narrow AdaptiveShell top bar is rendered only when at least one of `onOpenSettings`/`onOpenPlaylists` is non-null; if both are null, no top bar appears (no brand wordmark shown on narrow — same as before this change).
