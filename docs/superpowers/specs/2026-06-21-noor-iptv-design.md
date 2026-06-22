# NOOR / ClearView IPTV — Design Spec

**Date:** 2026-06-21
**Source design:** `ClearView IPTV.dc.html` (claude.ai/design project "IPTV app accessibility design", id `58c70b44-6fee-44cb-a516-98f69cfe8777`)
**Status:** Approved direction; pending spec review before plan.

## 1. Goal

Build, from scratch, a production-oriented Flutter IPTV player ("NOOR") that faithfully implements the ClearView prototype: an accessibility-first IPTV app with a real backend (Xtream Codes + M3U/M3U8 playlists, XMLTV EPG, real stream playback), adaptive across **Android phone, Android TV, and desktop (macOS/Windows/Linux)**, in **English and Arabic (RTL)**.

The app hosts **no content** — playlists supplied by the user are the only source and the only "login". This is surfaced at onboarding, playlists, and settings (app-store compliance).

## 2. Scope

In scope (the full app):

- Screens: Onboarding, Import (Xtream / M3U / Upload), Playlists, Home (hero + content rails incl. "Continue watching"), Movies grid, Series grid, Favorites, Search (with on-screen keyboard for TV), Live/EPG guide, Details (movie + series with seasons/episodes), Player, Settings, Accessibility panel.
- Real data: Xtream API + M3U parsing + XMLTV EPG, normalized and persisted locally.
- Real playback via `fvp` (libmpv/FFmpeg) with subtitles, audio/subtitle track menus, resume, next-episode.
- Accessibility system: text scaling, reduce-motion, high-contrast theme, colorblind-safe palette, configurable captions (size/background/color), screen-reader semantics, full D-pad/remote focus traversal.
- i18n: EN + AR with full RTL mirroring.

Out of scope (first build): casting (Chromecast/AirPlay), account sync/cloud, DVR/recording, multi-profile, web target.

## 3. Decisions (locked)

- **State management:** `flutter_bloc` / Cubit; `hydrated_bloc` for persisted state (accessibility settings, active playlist, lightweight caches).
- **Adaptive shell:** custom `AdaptiveShell` widget (NOT `flutter_adaptive_scaffold`, which is discontinued). NavigationRail + content rails on TV/wide; NavigationBar on phone. Full control over D-pad focus traversal.
- **Targets:** Android (phone + TV), Desktop (macOS/Windows/Linux). iOS/web not targeted in this build.
- **Execution:** plan now via `writing-plans`, then build with parallel subagents for independent modules.

## 4. Package stack (verified on pub.dev, 2026-06-21)

| Concern | Package | Version | Notes |
|---|---|---|---|
| State | `flutter_bloc`, `hydrated_bloc`, `equatable` | latest | locked choice |
| Models / codegen | `freezed`, `json_serializable`, `build_runner` | latest | reduce boilerplate |
| Navigation | `go_router` | latest | `StatefulShellRoute` for per-tab state |
| DI | `get_it` + `injectable` | latest | module isolation for parallel work |
| Xtream | `xtream_code_client` | 2.0.1 | design's pick |
| M3U | `m3u_nullsafe` | 1.0.4 | **replaces** design's `m3u_parser` (does not exist) |
| EPG / XMLTV | `xml` | latest | XMLTV parse |
| HTTP | `dio` | latest | shared client, retries |
| Video | `fvp` | 0.37.2 | registers as `video_player` backend; FFmpeg codecs |
| Subtitles | `subtitle` | 0.2.0 | SRT/WebVTT → SubtitleController |
| Local DB | `drift` | 2.34 | channels/vod/series/epg/progress/favorites |
| Secrets | `flutter_secure_storage` | latest | Xtream credentials |
| Images | `cached_network_image` | 3.4.1 | posters/logos |
| Loading | `skeletonizer` | 2.1.3 | skeleton states from real widgets |
| Playback UX | `wakelock_plus` | latest | keep screen awake while playing |
| i18n | `flutter_localizations`, `intl` | sdk/latest | `.arb` per locale |
| Connectivity | `connectivity_plus` | latest | offline/retry awareness |

Notes / risks:
- `fvp` track switching (manual quality/audio selection) may be limited; default to auto/best, expose manual selection only where the backend/track API supports it. Download-speed badge uses fvp media statistics.
- `xtream_code_client` vs `muxa_xtream` (newer, smaller adoption): start with `xtream_code_client`; the source layer is behind a repository interface so it can be swapped.

## 5. Architecture & layering

```
lib/
  core/
    theme/        design tokens, ThemeData (standard + high-contrast), fonts
    a11y/         AccessibilityCubit + MediaQuery wiring, caption style mapping
    i18n/         arb, l10n, Directionality helpers, Arabic-Indic numerals
    router/       go_router + StatefulShellRoute
    di/           get_it/injectable setup
    widgets/      PosterCard, ContentRail, FocusableButton, LiveBadge, AdaptiveShell
  data/
    models/       freezed models (Channel, VodItem, Series, Season, Episode, EpgProgramme, Playlist, WatchProgress, Favorite)
    db/           drift database + DAOs
    sources/      xtream_source, m3u_source, xmltv_source (interfaces + impls)
    repositories/ ContentRepository, PlaylistRepository, EpgRepository, PlaybackRepository
  features/
    onboarding/ import/ playlists/ home/ grid/ favorites/ search/
    live/ details/ player/ settings/
      <feature>/ cubit/  view/  widgets/
  main.dart  app.dart
```

- Each feature: a Cubit (screen state) + a View + local widgets. Features depend only on `core/` and repository interfaces — no feature-to-feature deps — so they can be built in parallel.
- Repositories return typed results (`Result<T, Failure>` or sealed states). Sources are swappable behind interfaces.

## 6. Data model & flow

drift tables (one playlist active at a time; rows scoped by `playlistId`):

- `Playlist(id, name, type[xtream|m3u|upload], serverUrl?, initial, channelCount, createdAt)`
- `Channel(id, playlistId, name, number, logoUrl, streamUrl, categoryId, isFavorite)`
- `VodItem(id, playlistId, title, posterUrl, categoryId, year, rating, streamUrl, kind[movie])`
- `Series(id, playlistId, title, posterUrl, categoryId, year, rating)` + `Season(id, seriesId, number)` + `Episode(id, seasonId, title, number, durationSec, streamUrl)`
- `EpgProgramme(id, channelId, title, startUtc, stopUtc, description)`
- `WatchProgress(itemKey, playlistId, kind, positionSec, durationSec, updatedAt)` — drives "Continue watching" + player resume
- `Favorite(itemKey, playlistId, kind, addedAt)`

Flow: Import → source fetches (Xtream API / M3U parse / XMLTV) → normalize to models → persist to drift → cubits stream from repositories (drift `.watch()`). Player writes `WatchProgress` on pause/seek/dispose. Credentials stored in `flutter_secure_storage`, never in drift.

Error handling: import validates the connection before persisting; repos surface typed failures; screens render retry/empty/loading states (skeletonizer for loading).

## 7. Screens (map to parallel work units)

**Foundation (sequential — blocks all features):**
scaffold + targets enabled (Android phone/TV, desktop) → design tokens + two ThemeData + fonts (Hanken Grotesk, IBM Plex Sans Arabic, Atkinson Hyperlegible) → AccessibilityCubit wired to MediaQuery → i18n EN/AR + RTL → AdaptiveShell + go_router shell → shared widgets (PosterCard, ContentRail, FocusableButton, LiveBadge, focus traversal helpers).

**Parallel wave (after Foundation; each depends on Foundation + data interfaces):**
- **Data/import module:** models, drift schema + DAOs, xtream/m3u/xmltv sources, repositories, ImportCubit (3 tabs), Playlists management, Onboarding + compliance copy.
- **Browse:** Home (hero, rails, continue-watching), Movies/Series grid (+ category chips), Favorites, Search (+ on-screen keyboard for TV remote).
- **Live/EPG:** two-axis (time × channel) scrolling guide with synced sticky headers, now/next, favorite toggle, jump-to-now.
- **Details:** movie + series; hero, synopsis, season chips, episode list, add-to-list, play.
- **Player:** fvp surface, custom transport controls (play/pause, ±10s, progress), subtitle rendering honoring caption a11y settings, audio/subtitle menu, episode menu, next-episode, favorite, captions toggle, quality/speed badge, resume, wakelock, landscape on phone.
- **Settings + Accessibility panel:** all toggles (text scale, reduce motion, high contrast, colorblind-safe, captions on/off, caption size/bg/color), language toggle, playlists entry, compliance statement.

Integration pass wires Browse/Details/Player/Live to the live data layer and verifies cross-screen flows (continue-watching, favorites, resume).

## 8. Accessibility (first-class)

- `MediaQuery.textScaler` honored everywhere (the prototype's `*var(--ts)` factor).
- Reduce-motion / `disableAnimations`: stops the live-pulse animation and any autoplay.
- High-contrast: second `ThemeData` variant; colorblind-safe palette avoids red/green-only cues (e.g. live state uses icon+text+motion, not color alone).
- Captions: configurable size (S/M/L), background (none/light/solid), color (white/yellow/cyan) mapped to subtitle render style.
- Semantics: every card/control is a labelled `Semantics` node; live badges announce state; player controls have aria-equivalent labels.
- Focus: `FocusTraversalGroup` + directional traversal for TV remotes/D-pad; visible focus ring matching the prototype (`--focus` outline).

## 9. Testing strategy

- **TDD** on pure logic with highest payoff: M3U parser normalization, XMLTV parser, Xtream response mapping, drift DAO queries, repository result/failure paths, caption-style mapping.
- **bloc_test** for each Cubit (load/empty/error/success transitions, import flow, player state).
- **Widget smoke tests** per screen (renders in EN + AR, with text scaling and high-contrast variants).
- Golden tests optional for PosterCard/ContentRail/EPG cell.
- Manual run on macOS desktop for fast iteration; Android phone/TV verification at integration.

## 10. Reference assets

Visual source of truth:
- `design/ClearView IPTV.dc.html` — the full prototype (all bindings, copy, colors, layout). Saved locally; this is the authoritative reference for every screen.
- Reference screenshots (`screenshots/live.png`, `player.png`, `phone-player.png`) live in the claude.ai/design project and can be fetched on demand via the design connector if a rendered view is needed.

## 11. Build order

1. Foundation (sequential).
2. Parallel wave: Data/import ‖ Browse shells ‖ Live/EPG ‖ Details ‖ Player ‖ Settings (UI against mock/fixtures behind repo interfaces).
3. Integration: wire UI to real repositories; cross-screen flows.
4. Verification: tests green, run on macOS + Android.

## 12. Open questions for plan stage

- Exact category/chip taxonomy comes from Xtream categories at runtime; grid chips are data-driven.
- Manual quality switching included only if `fvp` exposes track switching for the given stream; otherwise auto-only (surfaced honestly in UI).
