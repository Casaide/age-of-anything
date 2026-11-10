# 2026-11-10: Trees, rocks, stone and gold, voxel by voxel

**Milestone:** 23 (fidelity)
**Who:** Dominic + Claude (Claude Code)

## What happened
Units moved to a voxel a device px, and the ground was repainted (#392), so the map's props read low-detail next to
them (#410). A scratch mockup came first: an oak and a boulder, then a pine, a willow, a stone and a gold deposit.
Dominic: round one "much better", round two "perfect".

The game's props were meshes voxelized, and a mesh can't give each voxel its own tone (the leaves' hue goes from
yellow-olive in the sun to blue-green in the shade, per clump; rock has specks, lichen and moss). So the props are now
grids of voxels made in code (`view/voxel_grid.lobster`): capsules, flat-ended posts, ragged blobs with noise and
holes, faceted stones as an ellipsoid cut by planes. They're lit as the mockup was and coloured from that light,
then drawn by the same drawer as the buildings (`vm_draw`, split out of `voxel_bake`). Trees are in
`model/trees.lobster`, rocks and deposits in `model/rocks.lobster`. The old stone props in `model/props.lobster`
went.

Every tree style is used now, one per variant: the oak's third style is a pale birch, the pine's a tall one crowned
only near the top, the willow's lower with longer curtains. The pine first came out as a fluffy column; wider gaps
between whorls, flatter pads and a tone per whorl made its tiers read.

## Decisions
- D-244: trees, rocks, stone and gold are built voxel by voxel; they keep their size on the map.

## Numbers
- All 193 prop frames bake in 46 s (main: 16 s). The 92 reworked frames compress to 1.1 MB (main: 1.6 MB).
- The prebake (buildings and props at both densities): 1,744 s, 342 MB. The props are shipped, so a player's first
  match bakes none of them ("baked 0 props the pack lacked, in 44 ms").
- 2,000 units (`perf_big`): 57.3 fps, 8.6 ms median work. Current main with the same bakes: 57.5 fps, 9.8 ms. Both
  fail the frame when a house finishes (22.9 vs 23.7 ms), a sim regression already on main (#383).

## Pictures
- `images/2026-11-10/79-props-default-zoom.jpg`: the start at the default zoom.
- `80-props-forest-edge.jpg`, `81-props-forest-edge-1to1.png`: oak, birch and pine at the forest's edge with felled
  trunks and stumps, gold and stone, after 90 s.
- `82-props-town-close.jpg`: close, stone and gold by the town.
- `83-props-sheet.png`: every tree style standing, the oak's stages, boulders, field stones, stone and gold as mined.

## Funny moments
- Sourcing the machine lock in zsh wiped PATH (zsh's `path` array is PATH), so the waiter spun for half an hour
  without ever taking the lock.

## Ideas parked
- Birch logs and stumps lie nearly flat white: a felled birch wants its dark marks.
