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
- Episode lists now show **how much of each episode you've watched** — a
  progress bar for partially watched episodes and a checkmark for finished
  ones, updated as soon as you come back from the player.

### Changed
- Movies, series, and live TV on Android now play through the **same video
  engine as desktop**, with a corruption-free picture on TVs with PowerVR
  graphics.
- **4K videos play much more smoothly on TV** — video now renders on its own
  display layer with a sensible size cap, roughly doubling the delivered
  frame rate on weak TV GPUs.
- On the player, the seek bar now moves **10 seconds per D-pad press** instead of
  jumping large chunks.
- The player's volume slider is hidden on TV (volume is controlled by the remote);
  the mute button stays.

### Fixed
- Opening a movie or episode from **Continue Watching now resumes at the right
  position** on Android (it used to restart from the beginning).
- In Arabic, the app now shows its current name (**مشغل IPTV**) instead of the
  old one, and the **My List** button and Favorites hint are translated.
- In Arabic, the side menu is now **reachable with the D-pad** — focus
  navigation used to assume a left-to-right layout.
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
- Backing out of a video while it is still buffering no longer **loses your
  resume point**.
- Finishing a movie or episode now marks it **watched**: it leaves Continue
  Watching and replays from the beginning next time, instead of "resuming"
  at the last few seconds.
- The focus highlight no longer covers the edge of the item it's on.
