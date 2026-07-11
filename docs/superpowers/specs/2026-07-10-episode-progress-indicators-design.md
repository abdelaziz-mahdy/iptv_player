# Episode watch-progress indicators + resume fixes — design

Date: 2026-07-10
Status: approved (episode rows only; watched rule; both bug fixes)

## Goal

Show how much of each episode has been watched in series details, mark
finished episodes as watched, and fix two resume bugs found in review.

## Watched rule (shared)

Extension on `WatchProgress` (in `watch_progress.dart`):

- `double? fraction` — `positionSec / durationSec`, `null` when
  `durationSec <= 0`, clamped to `[0, 1]`.
- `bool isWatched` — `fraction != null && fraction >= 0.95`
  (constant `kWatchedFraction = 0.95`).

## Bug fixes

1. **Zero-position clobber.** `PlayerCubit._saveProgress()` returns early
   when `position <= Duration.zero`. Covers `close()` and the
   backgrounding path (`saveProgressNow()`); a zero save carries no
   information and previously wiped a real resume point when the user
   backed out during initial buffering.
2. **Finished items.** `PlayerCubit.start()` does not seek when the
   stored progress `isWatched` — a finished episode replays from the
   start. `continueWatching` (drift + fake) filters out watched rows.
   The progress row itself is kept — it powers the checkmark.

## Indicator

- `PlaybackRepository.progressForPlaylist(String playlistId)` →
  `Stream<List<WatchProgress>>`; drift impl watches all
  `WatchProgressRows` for the playlist, fake mirrors it.
- `DetailsCubit` gains a `PlaybackRepository` dependency, subscribes on
  `loadSeries`, and exposes `Map<String, WatchProgress> progressByKey`
  (key = `episode:<id>`) in `DetailsState`. Stream-based so bars update
  when returning from the player.
- `_EpisodeRow` renders a thin accent progress bar under the row when
  `0 < fraction < watched`, and swaps the trailing play icon for a
  checkmark when watched.

## Testing

- Player cubit: zero-position save is skipped (existing resume point
  survives close); watched progress does not seek on start.
- Drift repo: `continueWatching` excludes watched rows;
  `progressForPlaylist` streams saved rows.
- Details cubit: `progressByKey` populated from the fake repo.
- Widget: episode row shows bar for partial, checkmark for watched.
