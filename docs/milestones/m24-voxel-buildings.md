# Milestone 24: Voxel buildings and props

**Status:** planned (2026-11-03; Dominic: "voxel buildings yes")
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

Claude recommends **C**.

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
- [ ] 1. Building checks
- [ ] 2. The builder in the game (the experiment's four), cold and warm bakes measured
- [ ] 3. Every building voxelized, materials and patterns, team band; each architecture seen in a match
- [ ] 4. Construction and destruction stages, ruins
- [ ] 5. Walls, gates, towers
- [ ] 6. Props
- [ ] 7. Baking measured, prebake decided, `perf:` in budget
- [ ] 8. Data versions of the most-seen looks
- [ ] 9. The old pipeline removed, golden updated, losses backlogged
- [ ] 10. Archive
