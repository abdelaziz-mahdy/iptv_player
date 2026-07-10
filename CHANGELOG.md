# Changelog

All notable changes to IPTV Player are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- A **Recently Viewed** category now appears first in Movies, Series, and Live,
  so what you just watched is one click away.
- Each category and channel group shows its **item count** on the right.
- The player now has **Previous / Next** buttons: skip between channels in the
  same group while watching Live, and between episodes in the same season while
  watching a series.

### Changed
- On the player, the seek bar now moves **10 seconds per D-pad press** instead of
  jumping large chunks.
- The player's volume slider is hidden on TV (volume is controlled by the remote);
  the mute button stays.

### Fixed
- Continue Watching now remembers where you left off even if you exit from the
  Home button or the app is closed in the background.
- Continue Watching shows the **series poster, name, and season/episode**
  (e.g. "S3 · E12") for episodes you're part-way through — they used to appear
  as blank tiles.
- Continue Watching now shows **one card per series** (the most recent episode)
  instead of a separate card for every episode you've watched.
- Series opened from Search or the Movies/Series grids now load their seasons
  and episodes (previously they could show as empty).
- Series added to Favorites now appear in the Favorites list.
- Series details no longer list **empty seasons** — some providers advertise
  related shows as extra seasons with no episodes in them; only seasons that
  actually have episodes are shown now.
- The focus highlight no longer covers the edge of the item it's on.
