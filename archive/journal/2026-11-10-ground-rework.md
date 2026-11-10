# 2026-11-10: The ground, painted again from scratch

**Milestone:** 23 (fidelity)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic said the ground "needs a whole rework, not just high res": since the view went further out (D-239) its
patterns were too big and it looked low-res. From a mockup of directions he picked "A with B's voxel tufts" (#392).
Claude rewrote the terrain shader (`TERRAIN_SHADERS` in `src/game/ground.lobster`) from nothing, on the same inputs
(the masks, the paths, the walkers' wear, the map size, time).

- Grass is a soft tone over several tiles, lusher by water and drier in patches, with grain and short blades (a light
  tip, a dark root) one device px in size. No colour bands and no clumps.
- Grass, dirt, rock, sand and swamp meet along a height noise per pixel, so a road's edge shows stones through the
  grass instead of a smear.
- Voxel tufts (three blades, light left, mid, dark right, 2 to 4 px tall, a shadow) on grass and reeds, and 2 x 2
  stones (a lit top, a mid left, a dark right) on trails and rock and at their edges. They're drawn by the shader
  from a hashed grid in the units' voxel size (an art px, one device px on a Retina Mac), with nothing baked.
- Water: shallow #4f8a8c to deep #24506a, sand then wet sand at the edge, a foam line, ripples one px high that move
  with the ground's 15 Hz step.
- Detail is sized on the screen, not on the tile. The shader gets a new `dev_px` (device px a world px) and pins its
  pixel grid to the world, so it doesn't swim when the camera moves.

## Numbers
- 2,000 units (`mods:big_battle`, turn about with main's shader): 58.0 and 58.5 fps on main, 58.4 and 58.4 new; work
  6.7 ms median both.
- GPU watts over 15 s (`tools/perf/pw.c`), second round: a normal match 1.19 W main, 1.11 W new; the big battle 1.21 W
  main, 0.97 W new. The first round was noisy both ways.

## Funny moments
- The first boardwalk was one long dark-brown stripe. Painted red where its distance-along texture was above zero, it
  stayed all blue: the texture is empty everywhere, on main too. Its planks were never there (#397).

## Pictures
- `images/2026-11-10/50-ground-close.jpg`: a sewer rats' start at the default zoom.
- `images/2026-11-10/51-ground-close-1to1.png`: the same at 1:1, the cobbles' edge and the grass.
- `images/2026-11-10/52-ground-shore-1to1.png`: a river: sand, wet sand, foam, ripples.
- `images/2026-11-10/53-ground-swamp.jpg`: River Delta's swamp, its pools and reeds.
- `images/2026-11-10/54-ground-trail-1to1.png`: a forest culture's trails, height-blended into the grass.
- `images/2026-11-10/55-ground-zoomed-out.jpg`: zoomed out to 1.
- `images/2026-11-10/56-ground-1080p.jpg`: a 1080p window.
- `images/2026-11-10/57-ground-road-1to1.png`: a Roman road.

## Ideas parked
- #397, the boardwalk's empty distance-along texture.

## Afternoon: "much much worse", and textures
Dominic on the first try: the ground looked "much much worse"; voxels for details make sense but were overused, with
"zero effort into creating effective overlapping ground tiles/textures", and the map was "basically all one slab of
green". He was right: the shader drew per-pixel noise and a carpet of tufts, with no texture and no zones.

The second try paints real textures. `src/ground_textures.lobster` (run by `src/ground_textures.sh`) paints ten
seamless 256 x 256 tiles once into `data/ground/atlas.png`: lush, dry and dark grass and a flowered meadow (clumps of
blades fanning out, shadowed underneath, painted far to near), trail dirt with pebbles and cracks, weathered rock with
fissures and lichen, rippled sand, wet sand, swamp mud and bare earth. Each texel's alpha is its height. The shader
reads a texel an art px, so detail stays fine at every zoom. Two grids of big cells, half a cell apart, each offset the
texture their own way, so no repeat shows. Every terrain is laid over the last by a height splat: past its line the
higher texel wins in a band a few texels wide, along an edge noise of four octaves, so grass creeps over dirt and sand
and stones poke through. The grass comes in zones over many tiles (lush by water, dark by woods and reeds, dry and
yellow on open and raised ground, meadows, bare earth). Voxel tufts and stones are down to occasional accents, most of
them along the edges of rock and dirt.

- The first rock tile looked like crazy paving with black wedges, then like camouflage. It ended as low-contrast
  mottled grey with thin cracks.
- The swamp was one flat brown slab until tussocks of dark grass went into the mud.

### Pictures (second try)
- `images/2026-11-10/58-ground-textured-close.jpg`, `59-ground-textured-grass-1to1.png`: a start at the default zoom.
- `60-ground-textured-zones-zoomed-out.jpg`, `64-ground-textured-rock-zones.jpg`: the zones, further out.
- `61-ground-textured-shore-1to1.png`, `62-ground-textured-swamp.jpg`, `63-ground-textured-trail-1to1.png`,
  `66-ground-textured-road-1to1.png`, `65-ground-textured-1080p.jpg`.
- `67-ground-atlas.jpg`: the atlas at half size.

### Numbers (second try, turn about with main)
- 2,000 units: main 57.9 and 58.2 fps, new 58.0 and 58.1; work 6.7 to 7.4 ms median for both.
- GPU watts in a normal match over four rounds each: main 1.21, 1.36, 1.29, 0.74; new 3.03, 1.05, 1.13, 1.62. Noisy,
  medians about 1.25 against 1.4 W.

## Evening: a mixture, ground under props, softer
Dominic on the second try: "it looks good", but an all-green palette isn't real ground. Grass and soil are a mixture,
and the old shader had that better at lower detail. Two shades of green covering everything read as tiled. Rocks and
trees should have ground of their own. Then: "may need softening a little so not so crisp".

- Every grass tile is now soil with grass on it: blue-, mid- and yellow-greens, olive and straw clumps over brown soil
  that shows in spots of a few texels and in thin patches (`gt_grass`, `gt_cover`). Two more grasses (olive, worn) are
  mixed in over a few tiles by noise, and the hue drifts region to region, so no field is one tone.
- The ground under props comes from a second mask (`prop_tex`, built with the masks: R trees and stumps, G stone,
  gold and rubble), so it follows the map. Woods get a forest floor (dark soil, leaves, needles, moss, roots). Stone
  and gold get scree (gravel over rocky soil) with a ragged edge into the grass.
- Softer: each tile is blurred part way (`gt_soften`), with height blurred more, so the splat edges soften too. The
  splat band is wider and the voxel accents' faces less contrasty. Picture 69 is the 1:1 before and after.
- The zones moved to a two-octave noise (`zn`), to win back some GPU time.

### Pictures (third try)
`images/2026-11-10/68-ground-mixed-close.jpg` to `78-ground-atlas-mixed.jpg`: close, the 1:1 softening before and
after, scree under gold, zoomed out, the forest floor, shore, swamp, trail, road, 1080p and the atlas.

### Numbers (third try, turn about with main)
- 2,000 units: main 58.1, 58.2, 58.1 fps; new 58.0, 58.0, 57.8.
- GPU watts in a still normal match: main 1.34, 1.35, 1.39 W; new 1.52, 2.00, 1.99 W. The ground redraws at 15 Hz
  while the camera is still, so this is about a third to two thirds of a watt more. Scaled by D-209's numbers (live
  ground at 60 Hz cost about 2.65 W more than cached), that's an estimated 0.5 ms or so of GPU time a full-screen
  frame more than main. That is an estimate, not a measurement.
