# Milestone 24: Voxel buildings and props

**Status:** in progress: steps 1-3 and 9 done (2026-11-03; Dominic: "voxel buildings yes", then "C, go": D-203)
**Exit criterion:**
- **Coverage:** every building, in every architecture and age, and every prop (trees, rocks, bushes, doodads, town
  props, bridges, walls, gates, towers) is voxel, with its construction and destruction stages, ruins and the team
  colour band.
- **One cache:** baked through the voxel units' cache, the start bake measured cold and warm, the frame cost inside
  `perf:`.
- **One pipeline:** the old baked-building pipeline removed and its losses backlogged.
- **Green:** golden green (updated with the diff read), the batch passing (or failing only where it did before).
- **Seen:** captures from real matches at game zoom, and Dominic looking at a match.

## Why

The building experiment (archive/journal/2026-11-03-voxel-units-from-data.md: rounds 1 to 3, and the pediment fix)
came close to the baked buildings once textures, lights, true slopes and relief were in. Dominic: "voxel buildings
yes". One look for the whole game (units and buildings voxel), one cache, one pipeline.

## What there is

**Buildings:**
- 25 building types (`data/buildings.json`) in 6 architectures (stone, thatch, junk, tent, reed, mound), with age
  looks and variants: about 150 looks (`golden/buildings.txt`).
- Each look also has 4 construction stages, 4 broken-up stages (`game/ruin.lobster`) and the ruin.
- Walls, gates and wall towers have their own joins (`wall_links`), near layers and an open gate.

**Props:** trees, rocks, bushes, reeds and town props (`model/props`, `trees`, `town_props`, `bridges`).

**The code:** the models are about 3,000 lines of Lobster mesh code (`model/buildings*.lobster`, `build_mats`), baked
by `view/world_bake.lobster` and `game/art_kit*.lobster`, shipped prebaked (`src/prebake.sh`, `src/baked/`, D-185).

## How the shapes are made (the choice to make first)

A. **Voxel data per look**, written by Lobster programs (as the experiment: `voxel_buildings_gen.lobster`, helpers in
   `gen/vx_write.lobster`).
   - For: the best result, it can be modded, and it uses the voxel-native details (tile rows, patterns, lights).
   - Against: the experiment took about an hour a look, so roughly 150 hours for all.

B. **Voxelize the existing 3D models.** Rasterize each building's mesh into the voxel grid (a solid fill by its
   triangles, each voxel taking its triangle's material), then shade it with the voxel light, patterns and glow.
   - For: every look, stage and variant at once, with the shapes Dominic already likes.
   - Against: the models stay code, and their flat-shaded detail isn't voxel-native (no tile relief, no glow
     unless the material says so).

C. **B for coverage now, A culture by culture after.** Voxelize everything first (and map the models' materials to
   voxel materials with patterns: plaster, stone, tile, timber, sheet, glass as glow). Then replace looks with
   voxel data where it shows (the Town Centers, the houses, the most-seen buildings), one culture at a time.

Claude recommends **C**. Dominic: "C, go. I will have another agent review all the art afterwards" (D-203).

## Plan

1. **Pediment fix** (done, 2026-11-03): true pediments, a vertical triangle of level courses at the roof's slope.
   Add building checks (`voxel_check` or a `voxel_buildings` check):
   - a gable's face in one vertical plane;
   - level cornices;
   - a building standing on its footprint;
   - its team band present and seen from the game's facing;
   - no specks.
2. **The building builder in the game.** Bake a building look (one facing, the game's) through the voxel units'
   queue and cache, into the frames the building drawing already uses (`Look`: body, stages, ruin stages, near
   layers, fire spots, crack lines), so collect_buildings draws voxel buildings unchanged.
   - Start with the experiment's four.
   - Measure the bake cold and warm.
3. **Coverage (C, step B first):**
   - voxelize every building model;
   - map materials to voxel materials and patterns (stone blocks, tiles, timber, thatch, sheet, reed);
   - lit windows as glow;
   - the team band as the team material.

   Check each architecture at game zoom in a real match.
4. **Stages:**
   - construction: build up by height and held-back parts, as `akb_hold_back` does now;
   - destruction (D-171): voxels knocked out by deterministic noise, debris fallen at the foot, the ruin;
   - the dust effects stay.
5. **Walls, gates and towers:** joins by neighbour (`wall_links`), the near layers (merlons in front of units), the
   open gate.
6. **Props:** trees (crowns of melted balls with mottled leaves), rocks (faceted), bushes, reeds, town props, bridges,
   the doodads' scatter unchanged (`game/doodads.lobster`).
7. **Baking and cost:**
   - a match bakes only the architectures in play, the start fast, the rest in play;
   - decide whether the prebake still pays (voxel bakes are fast: measure all 150 looks);
   - `perf:` inside its budget.
8. **Data versions (C, step A)** where they show: the Town Centers and houses of each culture first, Dominic's picks.
9. **Remove the old pipeline** once nothing needs it:
   - code: the mesh models, `world_bake`, `baker`, the art kits' bake paths, `prebake.sh` and `baked/` if unused;
   - golden's buildings section becomes the voxel digests (diff read);
   - backlog what's lost.
10. **Archive:** pictures each step, the journal, a D-entry for the switch and one for the removal, the timeline.

## Checklist

- [x] 1. Pediment fix
- [x] 1. Building checks: `vbcheck` (no specks, the team colour showing) on every look of every architecture
- [x] 2. The builder in the game: `voxel_bake` (`view/voxel_mesh.lobster`) in `world_bake`'s frame, so every look, stage,
      ruin, near layer, wall arm, gate tower, vane and prop bakes as voxels through the art kits unchanged
- [ ] 3. Every building voxelized: done by step 2; each architecture seen in a match (Romans and rats so far)
- [ ] 4. Construction and destruction stages, ruins
- [ ] 5. Walls, gates, towers
- [ ] 6. Props
- [ ] 7. Baking measured, prebake decided, `perf:` in budget
- [ ] 8. Data versions of the most-seen looks: Dominic's, later (backlog: "Hand-built voxel buildings")
- [x] 9. The old baker removed (view/world_bake, view/baker; 2026-11-03); golden's buildings section (the models' digest)
      unchanged. Nothing was lost but the gate towers' shadow-only layer (a gate tower now casts its own shadow)
- [ ] 10. Archive

## Results so far

- **The bridge:** `view/voxel_mesh.lobster` rasterizes a model's triangles into a sparse shell of voxels at 1.5 art px
  a voxel, each voxel the colour its triangles' material gives there. The material's own texture is sampled into it,
  so stone blocks, tiles, thatch and sheet keep their detail; lit and unshaded materials glow. It is drawn with the
  voxel units' light (bands by the sun, its own shadow, occlusion, an outline) and its shadow on the ground, in
  `world_bake`'s camera and frame.
- **Speed:** the light is worked out only for the voxels that show.
  - A Town Center: about 720,000 voxels, 1.9 s; a house 0.33 s.
  - A cold start bakes about 3 s a look (each look is 9 frames: the whole, 4 construction stages, 4 broken-up
    stages), so a cold start of two cultures is minutes. The shipped prebake (D-185) bakes them once on the build
    machine.
- **The prebake:** every architecture's 1,868 frames in 23 min on the build machine, shipped as 104 MB.
- **A warm start:** 5-6 s in all, the buildings 6 ms (from `baked/`).
- **First matches:** the Romans and the frogs (pictures 41-42); the stone, junk and thatch buildings (43).
- **`vbcheck`:** 205 looks, no specks.
  - 16 keep their model's team colour out of sight from the game's view, by the model's own doing: stone houses #2
    and #3 (behind the cypress), the stone and thatch mills, every architecture's diagonal palisade and stone gates.
  - The review should decide whether to move those bands.

## For the art review (Dominic: "I will have another agent review all the art afterwards")

A reviewer should look at each of these at game zoom in a real match, and close up (3x):
- **Every architecture's buildings** (stone, thatch, junk, tent, reed, mound), in every age's look and variant.
  - Do the voxelized models keep their character?
  - Do textures read (stone blocks, tile, thatch, sheet, planks), or turn to noise at 1.5 px a voxel?
  - Is the light consistent with the units' (one sun, the same bands)?
- **The team colour:** a clear band on every building, not scattered; `vbcheck` only says some shows, and lists the 16
  looks where the model hides it (NOTE lines). Farms, markets, walls and palisades carry none by design: should they?
- **Construction stages** (4) and **destruction stages** (battered, breaking, collapsed, the ruin): do they read as
  the building going up and coming down?
- **Walls, gates and towers:** joins between neighbours, the near layers (merlons in front of units), the open gate.
- **Props:** trees, rocks, bushes, reeds, gold and stone, town props, bridges against the voxel units: same scale and
  style, no plastic look.
- **Units against buildings:** do units stand out from the ground and the buildings? Their outlines and shadows
  agree?
- **Lights:** windows, lanterns, braziers glowing, halos not blown out.
- **The data-built looks** (step 8, Town Centers and houses first) against the voxelized ones of the same culture:
  is the jump in detail jarring next to the rest?
- **Specks, holes and seams:** voxelized thin parts (fences, poles, ropes, banners), and gaps where meshes met.
- **The checks are honest:** `vbcheck`, `voxel_check` and `voxel_proto -- - check` pass, and what they don't cover is
  listed here.

## Next steps

1. **Re-run the prebake** (`src/prebake.sh`, about 25 minutes) since BAKE_VERSION is 12 (contact shadows): until then
   a cold start bakes the two cultures in play (about 8 minutes).
2. **Look at every architecture in a match** (stone and junk seen; thatch, tent, reed and mound in a match still to
   see), close up and at game zoom, and the construction and destruction stages in play.
3. **Walls, gates, towers** (step 5): a lone wall tile stands as a tall plain brick block (picture: a rats' match with
   `place:wall`); check joins, the near layers and the open gate against how they looked.
4. **`perf:`** with voxel buildings (step 7), and whether the prebake still pays (a cold building bake is 2-3 s a look).
5. **Props** (step 6): trees, rocks, bushes, town props and bridges are voxelized; look at them close up.
6. **The art review** (the section above), then Dominic's hand-built looks (backlog).
