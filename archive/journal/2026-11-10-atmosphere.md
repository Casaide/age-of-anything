# 2026-11-10: The atmosphere pass

**Milestone:** none (an engine feature, #411)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic's concept pictures for the next game get most of their mood from light and air: a warm low sun against cool
shadow, haze that thickens with distance, a fire lighting what is round it. The game drew the world straight to the
screen with one fixed sun. Issue #411 asked for a pass over the frame, driven by data, that both games can use.

The world is now drawn into a window-sized texture, then to the screen through one shader
(`src/view/atmosphere.lobster`): a cool shadow tint and a warm highlight tint, exposure, contrast and saturation, haze
by screen height that drifts slowly over the ground, a vignette, and bloom from a quarter-size blurred bright pass. The
UI is drawn after it, untouched. Fires, lit windows, flashes and glowing shots put glows into a quarter-size light
buffer, and the pass lights what lies under them by it, so a burning roof warms the boards and the grass round it
instead of being painted over in orange. Everything is a mood in `data/atmosphere.json`: three of them (clear_noon,
the default, golden_evening, misty_morning), one per map where a map wants its own, and a mod's file merges over it.
`atmosphere:off` draws the frame straight, and the mood `none` (all zeros) gives the same frame through the pass.

## Decisions
- D-244: the atmosphere is one pass over the world, from data; glows light through a light buffer.

## How it was checked
- `atmosphere:off` and `atmosphere:none` against main, the same view: the only pixels that differ are the
  randomly placed smoke puffs, flames and a bird, which differ between two runs of main too.
- run_tests' `atmosphere` group: the file loads, every mood validates and can be set, the default and the maps'
  moods exist, an unknown mood is reported, broken values, knobs and glow sources are caught, and a mod's mood with
  `extends` merges and can become the default.

## Numbers
- Uncapped, 3024 x 1834, medians of 4 runs alternating off and on (the machine was not quiet: other apps used
  over a core): a normal match 3.1 ms a frame off, 4.1 ms with clear_noon or golden_evening; mods:big_battle
  9.4 ms off, 10.2 to 10.6 ms on. About 1 ms added, at the edge of the budget.
- The all-zero mood costs as much as the full ones, so the cost is the world drawn into a texture and the
  composite at full size, not the bloom or the glows. Capped, every match held 59.9 fps.
- Not checked on the Steam Deck.

## Pictures
- `images/2026-11-10/80-atmosphere-off.jpg`, `81-atmosphere-clear-noon.jpg`, `82-atmosphere-golden-evening.jpg`,
  `83-atmosphere-misty-morning.jpg`: the same view in each.
- `84-atmosphere-fire-golden-evening.jpg`: a burning hut close up at dusk.

## Funny moments
- The first golden evening looked like noon with the lights dimmed. The split toning only touched pixels brighter
  than 0.3, and nearly all of the game's grass sits below that, so the "warm sun" fell on the roofs and nowhere else.
- The first mist was an even grey film over everything, like looking through a dirty window.

## Ideas parked
- Sun direction and shadow length per map (needs the sprite bake), god rays and cloud shadows: their own issues.
- The Deck: if it can't hold 60 fps, the pass at a lower size first (the bloom is not where the cost is).
