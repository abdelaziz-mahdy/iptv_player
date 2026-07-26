# Changelog

All notable changes to IPTV Player are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Movie and series pages now show the **full details the provider has**: plot,
  cast, director, genre, country, rating, release year and runtime. Movies
  previously showed no description at all.
- Episode lists now show each **episode's own description**.
- The player now shows a **loading spinner** while a stream is opening or
  re-buffering, so a slow provider no longer looks like a frozen screen.
- When a stream cannot be played, the player now **explains why** — server
  unreachable, no longer available, refused by the provider — with a Retry
  button, instead of showing a black screen.
- A **Recently Viewed** category now appears first in Movies, Series, and Live,
  so what you just watched is one click away.
- Each category and channel group shows its **item count** on the right.
- The player now has **Previous / Next** buttons: skip between channels in the
  same group while watching Live, and between episodes in the same season while
  watching a series.
- Episode lists now show **how much of each episode you've watched** — a
  progress bar for partially watched episodes and a checkmark for finished
  ones, updated as soon as you come back from the player.
- A **Jump to letter** button on Live, Movies and Series: pick a letter and the
  list jumps to the first title starting with it, instead of scrolling through
  thousands of items with the remote.

### Changed
- **Channel groups and categories no longer feel randomly ordered.** The groups
  you actually open are pinned in a block right under "All", most recent first,
  and everything else follows in the provider's own order. A pinned group is not
  repeated further down the list.
- Live, Movies and Series now **open on the group you were last in**, with the
  highlight already on it, instead of resetting to "All" every launch.
- **Recently Viewed no longer runs out.** Live, Movies and Series each keep their
  own history of 20, so a run of movies can no longer push every channel out of
  Live's Recently Viewed (and vice versa).
- Posters, backdrops and channel logos are now **cached on the device** — they
  no longer reload every time you scroll past them.
- **Text on TV is bigger.** Channel names, numbers and category counts were sized
  for a phone in your hand and were hard to read across a room.
- The app now keeps **three days of diagnostic logs** (previously seven) and
  records what the video engine reports, so a problem you hit yesterday can
  still be looked into today.

### Fixed
- **Live channels no longer freeze on a still picture while the sound keeps
  playing.** The audio engine the app asked for could start its clock from the
  wrong point on live streams, leaving the video permanently "in the future";
  the app now uses the player's own default engine.
- **Movies opened from Favorites now play.** They were handed to the player
  without a stream address, so playback failed with "invalid or unsupported
  media" while the same movie played fine from the Movies tab.

### Changed
- **Playback now uses a single engine (MDK) on every platform.** On Android TV
  the decoder writes straight into the display layer, so 4K plays at the
  panel's own resolution and frame rate. The app is also ~40 MB smaller.
- Left / right on the remote now **skips 10 seconds straight away** while the
  controls are hidden, instead of only waking them up first.
- **Next** in a series now continues into the **following season** when you
  finish the last episode of one, rather than stopping there.
- Videos now keep their **correct shape** on TV — widescreen films are no
  longer stretched to fill the screen.
- Moving **left to the side menu** now works from the first item of any row.
  Previously the menu could only be reached when every row happened to be
  scrolled fully to the left. On Movies and Series, left from the first column
  lands on the **category list** first, as it should, instead of skipping
  straight past it.
- Playback on Android now uses the **mpv engine** (media_kit): noticeably
  smoother frame pacing on TV hardware, with a corruption-free picture on
  TVs with PowerVR graphics.
- **4K videos now play at full quality and full smoothness on TV** — decoded
  frames go straight from the hardware decoder to the screen, so 4K content
  plays at its native resolution and frame rate (previously it was downscaled
  and still stuttered). Returning to a video after switching apps shows the
  picture again reliably.
- On the player, the seek bar now moves **10 seconds per D-pad press** instead of
  jumping large chunks.
- The player's volume slider is hidden on TV (volume is controlled by the remote);
  the mute button stays.

### Fixed
- **Favorites now survive provider catalog updates** — when your provider
  re-numbers its content, a favorite no longer plays the wrong item or breaks;
  it finds the same title again and quietly fixes itself. Favorites for
  content the provider removed are hidden (and come back if the content does).
- The **Play button on series details now continues where you left off** —
  it picks the episode you're part-way through (or the next unwatched one)
  instead of always starting from the first episode.
- Details pages **no longer invent a synopsis** when the provider doesn't
  have one — they now say so honestly, in English and Arabic.
- On the player, **D-pad focus no longer gets stuck in the seek bar** —
  up/down move between controls; left/right still seek 10 seconds.
- Pressing **down on the seek bar no longer jumps the video back 10 seconds**
  on its way out — it now only moves to the controls below.
- Opening a movie or episode from **Continue Watching now resumes at the right
  position** on Android (it used to restart from the beginning). Resume is now
  applied when the stream loads, making it reliable on slow connections too.
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
