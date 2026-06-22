# NOOR / ClearView IPTV — Plan Index

> **For agentic workers:** This index defines the plan set and build order. Each plan is implemented with superpowers:subagent-driven-development. Foundation is sequential and blocks everything; the feature wave runs in parallel afterward.

**Spec:** `docs/superpowers/specs/2026-06-21-noor-iptv-design.md`
**Visual source of truth:** `design/ClearView IPTV.dc.html`

## Plan set

| # | Plan | File | Depends on | Parallel group |
|---|------|------|-----------|----------------|
| 0 | Foundation | `2026-06-21-noor-foundation.md` | — | sequential (blocks all) |
| 1 | Data & Import | `noor-data-import.md` | Foundation | Wave A |
| 2 | Browse (Home/Grid/Favorites/Search) | `noor-browse.md` | Foundation, Data interfaces | Wave B |
| 3 | Live / EPG guide | `noor-live-epg.md` | Foundation, Data interfaces | Wave B |
| 4 | Details | `noor-details.md` | Foundation, Data interfaces | Wave B |
| 5 | Player | `noor-player.md` | Foundation, Data interfaces | Wave B |
| 6 | Settings & Onboarding | `noor-settings-onboarding.md` | Foundation | Wave B |
| 7 | Integration & verification | `noor-integration.md` | all above | sequential (final) |

## Build order

1. **Foundation** (Plan 0) — single track. Produces design system, themes, accessibility, i18n, adaptive shell, router, DI, shared widgets, and **repository interfaces** (abstract classes with method signatures + freezed models) so feature plans can compile against contracts before the data layer is real.
2. **Wave A — Data & Import** (Plan 1) — implements the repository interfaces against drift + Xtream/M3U/XMLTV. Browse/Live/Details/Player can develop against the interfaces in parallel using in-memory fakes until Wave A lands.
3. **Wave B — Features** (Plans 2–6) — parallel; each consumes Foundation widgets + repository interfaces only, no feature-to-feature deps.
4. **Integration** (Plan 7) — wire real repositories into all features, end-to-end flows (continue-watching, favorites, resume), run on macOS + Android.

## Interface-first rule

Foundation (Plan 0, Task: "Repository contracts & models") defines, as abstract classes + freezed models, the full surface every feature consumes:
`ContentRepository`, `PlaylistRepository`, `EpgRepository`, `PlaybackRepository`, plus models `Channel`, `VodItem`, `Series`, `Season`, `Episode`, `EpgProgramme`, `Playlist`, `WatchProgress`, `Favorite`, and `Result<T>`/`Failure`.
Feature plans are written and reviewed against these signatures. When a feature plan is authored, copy the exact current signatures from the generated Dart into that plan's Interfaces block.

## Plan authoring schedule

- Author Plan 0 now (this commit).
- Author Plans 1–7 after Foundation merges, copying real signatures from the implemented contracts. This avoids signature drift.
