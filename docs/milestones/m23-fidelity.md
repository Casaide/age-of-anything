# Milestone 23: Fidelity (heroic humans, 2x art)

**Status:** in progress (started 2026-10-26; D-173, Dominic: "go with heroic 5.5 heads at 2x")
**Exit criterion:** the game bakes at 2x (art scale 3.0) with play zoom, the lobby, the Race Lab and the tech tree
showing everything at the size they did; humans stand about 5.5 heads tall with broad shoulders, every human unit,
gear piece, pose and facing passing `tests/placement_check.gd`; riders and centaurs fit their mounts; the batch passes
(or fails only where it failed before); a Steam Deck build runs a match; Dominic looks at a match and the Race Lab.

## Why

Round F1 (`docs/concepts/fidelity/`) showed the cartoon look comes from the models (toy proportions, primitive
blobs, flat team colour), not the rendering; a realistic figure through our baker reads as a soldier, and needs 2x
to read at play size. Dominic picked the heroic 5.5-head build at 2x.

## Plan

1. **2x art.** `ArtKit.ART_SCALE` 3.0 by default (`AOW_ART_SCALE` still sets it: 1.5 is the old look). Zooms that
   meant "N screen pixels per art pixel" at 1.5 become canvas zooms (`ArtKit.BASE_SCALE`), so the camera, the Race
   Lab and the stages show things at the size they did. The atlas is 8192 wide at 2x. Check the art-pixel numbers in
   the view (outlines, cracks, dust, unit snapping) and in the tests' thresholds.
2. **The heroic human body** (Blender, `tools/blender/`): torso, legs and head at ~5.5 heads with broad shoulders,
   the overall height near today's; its 3D sockets, arm holds and hips in `unit_models.gd`, its 2D sockets and leg
   anchors in `data/parts.json`. The old models stay as files (kept, not deleted).
3. **Gear refitted:** helmets on the smaller head (`gear_scale`), worn armour regenerated for the new torso
   (`tools/blender/human_armour.py`), shields and weapons at the new hands, banners on the back.
4. **Riders and centaurs:** the seat and rider legs on every mount; the centaur's human half.
5. **Checks:** `tests/placement_check.gd` on every human unit, pose and facing; fixtures for any bug found; the batch.
6. **Look at it:** sheets close up and at play zoom, a match screenshot, the Race Lab; a Deck build.
7. **Archive.**

## Checklist

- [ ] 1. 2x art, zooms unchanged on screen
- [ ] 2. Heroic human body
- [ ] 3. Gear refitted
- [ ] 4. Riders and centaurs
- [ ] 5. Placement check and batch
- [ ] 6. Pictures, Deck build
- [ ] 7. Archive

## Results
