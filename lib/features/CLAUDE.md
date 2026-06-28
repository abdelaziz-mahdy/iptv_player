# lib/features — Feature Module Pattern

## Anatomy

Each feature follows:
```
<name>/
  <name>_screen.dart          # StatelessWidget; creates BlocProvider + calls cubit.load()
  cubit/<name>_cubit.dart     # logic; sometimes contains state class too
  cubit/<name>_state.dart     # optional separate state file (home, live, search use `part`)
```

Screen widgets are dumb — no business logic. Cubits own all logic. Repositories are pulled from DI
via `sl<SomeRepository>()` inside the screen's `BlocProvider.create`.

Live has a second file: `channel_list_screen.dart` (the full-screen channel list pushed from `live_screen.dart`).

## CRITICAL GOTCHA — Active-Playlist Stream Binding

Content cubits (home, grid, live, favorites, search) must **subscribe to the active-playlist stream**
and re-bind content when it changes. The canonical pattern:

```dart
StreamSubscription<Playlist?>? _activeSub;

Future<void> load() async {
  emit(state.copyWith(loading: true));
  _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
}

void _onActivePlaylistChanged(Playlist? playlist) {
  final pid = playlist?.id;
  if (_hasBound && pid == _playlistId) return; // de-dupe
  _hasBound = true;
  _playlistId = pid;
  // cancel old content subs, then re-subscribe with new pid
}

@override
Future<void> close() async {
  await _activeSub?.cancel();
  // cancel all other subs
  return super.close();
}
```

**Do NOT use `_playlists.active().first`** — that resolves once on startup and does not react to
playlist import/switch, leaving the screen empty until an app restart. This was the root cause of
the "no content until restart" bug fixed in commit d7603ae.

## TV / D-pad

- All screens are D-pad navigable. `FocusableButton` (from `core/widgets/`) is the standard
  interactive widget; it draws the focus ring and handles Enter/Select/GameButtonA.
- The side rail is reached with D-pad LEFT from the leftmost body element (`AdaptiveShell`
  intercepts the edge event). Do not add nested `FocusScope` nodes without testing D-pad traversal.
- The favorite heart on `PosterCard` is **intentionally NOT a focus stop** — D-pad grid traversal
  skips it. Favorites are toggled by touch/mouse or from the details screen on a remote. See the
  comment in `core/widgets/poster_card.dart:101`.
- Text input on Android TV: `search_screen.dart` and `import_screen.dart` use
  `NativeTextFieldController` / `AndroidTVTextField` from
  `package:flutter_android_tv_text_field`. This opens the system keyboard overlay. On non-Android
  it degrades to a plain `TextField` via the same controller.

## Favorite item keys

Movies: `movie:<id>` with `MediaKind.movie`.
Series: `episode:<id>` with `MediaKind.episode` (matches the details screen convention — not `series:<id>`).
Channels: `channel:<id>` (resolved in `favorites_cubit.dart`).

## Player

`features/player/` is structured differently (no screen-wrapping `BlocProvider` at the top,
separate `VideoController` abstraction, platform-conditional controller selection). See
`lib/features/player/CLAUDE.md` for details (to be created when the player is next touched).
