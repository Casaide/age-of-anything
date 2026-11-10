# 2026-11-10: Baking at the screen's density

**Milestone:** 23 (fidelity)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic said the graphics were going the right way since the units got smaller, but the genre's games sit a little
further out. He also said the ground now looked low-res, with patterns too large. Issue #358 measured why. Lobster
reports the window in device px, so on his Mac (3024 x 1834, `ui()` 1.83) the default zoom is 3 (desktops already
start one step out from 4). The art is baked at 2 texture px a world px, so every baked pixel covered 1.5 device px
and every voxel about 1.65. The ground's dither did the same, and its dry patches were about two tiles across, bigger
than a group of soldiers.

The fix is one setting at the start, `art_density(zoom)`. The desktop view goes a quarter further out (zoom 2.4), and
on a screen like that units, buildings and props bake at 2.4 texture px a world px, with voxel units at 2.64 voxels a
body unit. A voxel is then exactly one device px, and the camera and every sprite land on a whole device px, so a
non-integer zoom doesn't shimmer. The ground's dry patches are now about one tile across and blend halfway to the
grass, and the grain is finer.

## Decisions
- D-239: the art bakes at a high-DPI screen's density (at most 2.4), and desktops start a quarter further out.

## Numbers
- First bake at 2.4 on the Mac: buildings 370 s (848 frames), props 20 s; the cache 1.0 GB against 0.7 GB at 2.
  Peak memory in the first match about 2.5 GB.
- 2,000 units (`mods:big_battle`): 58.1 fps, 8.5 ms median work (was 58.4 fps, 7.3 ms).
- The size table holds at 2.4 within the base's voxel and one edge voxel. The deer comes out tallest: its antler
  tines, lost at the base density, show at 2.4.

## Pictures
- `images/2026-11-10/20-hidpi-before-retina-default-view.jpg`, `21-hidpi-after-retina-default-view.jpg`
- `22-hidpi-before-ww2-retina.jpg`, `23-hidpi-after-ww2-retina.jpg`, `24-hidpi-after-ww2-1080p.jpg`
- `25-hidpi-rat-before-after-4x.png`: the rat worker at 4x. Before, voxels were 1 or 2 px wide; after, every one is 1 px.

## Funny moments
- The big battle's 2,000 units outgrew the voxel atlas (a 2048-wide sheet more than 4096 rows tall) the first time
  they baked at the new density.

## Ideas parked
- 1080p desktops start at zoom 1, much further out than a Retina Mac's 2.4 (1,080 world px tall against 764). One
  rule for every desktop would be cleaner.
- Dominic's next step: smaller units with more voxels, a high-detail human from a .vox model (#313).
