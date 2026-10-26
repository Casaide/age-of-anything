# 2026-10-26: how far can the art go? (study AQ1)

## What happened

Dominic: "I want to explore how far we can go with art quality ... higher res, better destruction, better
animations ... sci fi mods ... lasers firing ... while maintaining nostalgia above all else." Claude ran a
concept round (D-080) in its own session: four directions, each captured in the game's own pipeline beside
today's look, with costs. Write-up and pictures: `docs/concepts/art-quality/README.md`. Nothing is in the game.

1. **Higher resolution.** A flag, `AOW_ART_SCALE`, makes the whole game bake finer (units, buildings, props,
   ground). Same match, same camera: today, 1.5x and 2x. At play zoom the gain is modest (faces, shield
   bosses, the howdah's fringe, corrugated roofs); close up 2x is clearly sharper. Cold bake 21.7 s, 40.8 s,
   43.3 s; video memory ~0.5 GB to 1.2 GB at 2x; frame time unchanged on the Mac.
2. **Destruction.** Buildings broken up in 3D before they bake (`tests/art_quality/ruin.gd`): pieces fall
   from the top, others tilt and scorch, rubble heaps up from the building's own materials, walls become
   ragged stumps with breaches; five stages, then the fall with pixel dust, and a ruin that stays.
3. **Animation.** A follow-through arm hold (`follow`, behind `AOW_STUDY_HOLDS`), and every death laid down in
   3D through the frog's corpse pipeline: the legionary on its back with its helmet rolling off, the rat on
   its side. Placement check PASS on every row.
4. **Sci-fi effects.** A real volley of the `scifi_test` mod's pulse troopers, frozen, drawn four ways: today,
   pixel bolts on the art grid with starburst hits and light pools, full laser beams, plasma balls.

## Decisions

None yet: Dominic picks. Claude's recommendations: destruction in stages next; deaths in 3D for every body;
pixel bolts and plasma as `shots.json` styles for the sci-fi mod; no global 2x (maybe buildings-only 2x,
and a Deck build with the flag to see it on the real screen).

## Bugs and surprises on the way

- **2x broke the atlas**: 23178 px tall at 4096 wide, over the GPU's 16384 (the game's assert caught it). The
  study widens the atlas to 8192 under the flag; a real 2x needs atlas pages.
- **1.5x has uneven pixels**: an art pixel is 1.33 screen pixels at play zoom, so some draw one pixel wide and
  some two. Only 2x lands on whole pixels.
- The first collapse squashed each wall box down whole: clean white blocks standing in the rubble, like a
  ruin made of sugar cubes. Walls now break into ragged stumps along their sides, with gaps.
- The first sci-fi capture froze a volley after the rats had all died: twelve troopers solemnly lasering
  a few deer.
- The fallen legionary lay end on in facings 0-3, boots to the camera; turned per facing (as the frog, D-166)
  every view reads.

## Pictures

`archive/images/2026-10-26/01-13-art-quality-*.png` (the same as `docs/concepts/art-quality/`).

## Ideas parked

- Buildings and props at 2x, units as today (where the gain shows most, a third of the memory).
- A weapon smear frame (an arc of pixels behind a heavy blow) with the follow-through hold.
- A ruin's sim rules (blocks? buildable? how long it stays?) if destruction is picked.
