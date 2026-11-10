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
