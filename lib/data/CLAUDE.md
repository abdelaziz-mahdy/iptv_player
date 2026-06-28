# Data Layer

## Repository pattern

Four abstract interfaces in `repositories/repositories.dart`:
`PlaylistRepository`, `ContentRepository`, `EpgRepository`, `PlaybackRepository`.

Fallible methods return `Future<Result<T>>` (`Ok`/`Err`/`Failure` from `core/result.dart`) — never throw for expected failures. Infallible mutations (`toggleFavorite`, `setActive`, `saveProgress`, `removeProgress`) return `Future<void>`.

Two implementations per interface:
- **Drift-backed** — `drift_*_repository.dart`, re-exported via `drift_repositories.dart`. Uses `AppDatabase` + optional injectable `CredentialStore`/`Dio`/source adapters for testing.
- **Fakes** — `fakes/fake_repositories.dart` — all four in one file, seeded with sample data. Used by tests and the dev DI binding. Must be kept in sync when adding interface methods.

## GOTCHA: active playlist is a stream

`PlaylistRepository.active()` returns `Stream<Playlist?>`. The drift implementation emits the current value immediately on subscription, then forwards live updates via a broadcast controller.

**Do NOT** call `.first` once and store the result — that caused "no content until restart" (cubits missed subsequent playlist switches). Feature cubits must `listen`/`StreamBuilder` on `active()` and rebind their content streams when the value changes.

## Series are lazy-loaded

`ContentRepository.loadSeriesDetail(Series)` triggers an Xtream `seriesInfoData` call and caches the result (seasons + episodes) in the local DB. Seasons/episodes are not fetched during `importPlaylist` (too expensive). For M3U playlists or missing credentials, returns a `SeriesDetail` built from whatever is cached locally (possibly empty).

## sources/ — pure fetch/parse

- **`XtreamSource`** — wraps `xtream_code_client`. `fetchAll()` fires 6 parallel requests (live+vod+series streams, all three category lists). `seriesDetail()` calls `seriesInfoData`. `vodPlot()` calls `vodInfoData`. Map helpers (`channelFromLive`, `vodItemFromXtream`, etc.) are top-level for unit-testability without network. Inject `XtreamSource.withClient(client)` in tests.
- **`M3uSource`** — wraps `m3u_nullsafe`; parses M3U/M3U_Plus into `Channel` only (no VOD/series). `categoryId` is the `group-title` attribute.
- **`XmltvSource`** — parses XMLTV XML into `EpgProgramme`. Malformed `<programme>` entries are silently skipped (no abort on one bad row).

Persistence happens in repositories, not sources.

## db/ — drift SQLite

`AppDatabase` (`db/database.dart`) opens `noor.db` (drift_flutter). Schema version 3; migrations add `XtreamCredentials` (v2) and `Categories` (v3). Tables: `Playlists`, `Channels`, `VodItems`, `SeriesItems`, `Seasons`, `Episodes`, `EpgProgrammes`, `WatchProgressRows`, `Favorites`, `XtreamCredentials`, `Categories`.

**GOTCHA: `database.g.dart` is generated** (not committed). After changing `tables.dart` or `database.dart`, run:
```
dart run build_runner build --delete-conflicting-outputs
```

Xtream credentials are stored in the `XtreamCredentials` table, NOT in `Playlists`. They are accessed via `CredentialStore` (injectable; default: `InMemoryCredentialStore` in `DriftContentRepository`). Use `credential_store_drift.dart` for the real persisted implementation.

## models/ — freezed + JSON

All domain models are `@freezed`; `*.freezed.dart` and `*.g.dart` are generated (run build_runner). `SeriesDetail` is not freezed — it is a plain class holding `seasons`, `episodesBySeason`, and optional `description`.

## Domain ID conventions

- Xtream items: `'<playlistId>:<type>:<numericId>'` (e.g. `'p1:live:12345'`, `'p1:series:67:season:1:ep:9'`)
- M3U channels: `'<playlistId>:<streamUrl>'` (stream URL is the stable key; falls back to index)
- Category type strings in DB: `'live'` / `'vod'` / `'series'` (mapped from `MediaKind` by `_kindToType` in `drift_content_repository.dart`)

## importPlaylist behaviour by type

| Type | What happens |
|------|-------------|
| `m3u` | Fetches URL via Dio, parses channels only, replaces channel rows |
| `xtream` | Fetches channels + movies + series + categories in parallel, replaces all rows |
| `upload` | No-op (content assumed already in the local store) |
