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
2b. **Clothes and gear to the concept's quality** (Dominic: the design "feels cheap still"): the concept figure
   (`tools/blender/concept_soldier.py`) is the bar: modelled garments with folds and real materials in muted natural
   colours, team colour on a smaller region, arms shaped like arms, culture gear (helmets, armour, shields, weapons)
   remodelled in Blender. Then rats and frogs to the same quality ("rats etc should follow").
3. **Gear refitted:** helmets on the smaller head (`gear_scale`), worn armour regenerated for the new torso
   (`tools/blender/human_armour.py`), shields and weapons at the new hands, banners on the back.
4. **Riders and centaurs:** the seat and rider legs on every mount; the centaur's human half.
5. **Checks:** `tests/placement_check.gd` on every human unit, pose and facing; fixtures for any bug found; the batch.
6. **Look at it:** sheets close up and at play zoom, a match screenshot, the Race Lab; a Deck build.
7. **Archive.**

## Checklist

- [x] 1. 2x art, zooms unchanged on screen
- [x] 2. Heroic human body (proportions; the clothes and gear look cheap still: step 2b)
- [ ] 3. Gear refitted
- [ ] 4. Riders and centaurs
- [ ] 5. Placement check and batch
- [ ] 6. Pictures, Deck build
- [ ] 7. Archive

## Results

**2026-10-26, steps 1-2.** The art scale is 3.0 by default; camera, Race Lab, portraits and sheets zoom in
`ArtKit.BASE_SCALE`, so sizes on screen are unchanged and the art is finer. The atlas is 8192 wide. The human is
the heroic build: legs `leg_human_heroic.glb` (hip to sole 18, was 11), the trunk lifted and 1.06 broader
(`torso_human_heroic.glb`, worn armour regenerated), the head 0.68 the size, arms in code longer
(`UnitModels.arm_reach` scales the holds' reach, except low, mouth and draw). Fixes the new build needed: gear on the
head a touch higher (every cap came under 0.5 over the brow), a higher quiver (the stride met it), the rested
sword and shield hands higher (riders' hands met their mounts), the howdah's two crew further apart, the covered
ram's roof and log higher (the log went through the crew's skirts), the plume helm lifted.
- 3D placement, every unit: 26166 checks, 0 failed. 2D: 19658 checks, 0 failed at the old scale (the 2D check's
  per-pixel work at 2x ran past 50 minutes for the whole roster and was stopped; its pixel tolerances now keep their
  size on screen, `PX_SCALE`); at 2x the Romans: 1170 checks, 3 failed, all **K4: the centaur's kneel slides a hind
  hoof 4.03 px against 4 in facing 2** (open). Fixture "a rider's tiny leg" now uses the old leg's length.
- Cold match start 49 s on this Mac (units 10.6 s, props and buildings 38.5 s with the ruin stages).

**Dominic, 2026-10-26, on the heroic humans:** "feel like we're almost there, but not 100%. The design (clothes etc)
of the humans feels cheap still. And the rats and frogs dont feel same quality". On round F1's concept figure:
"this is good. conceptually we've gone from [one classic RTS] style to [another]" (the later, more realistic
classics), and "rats etc should follow". Next: step 2b, the humans' clothes and gear to the concept figure's quality,
then rats and frogs.

**2026-10-27, step 2b (in progress).** Wool tunic and shaped arms (D-175), Blender galea and scutum, banners only when
asked (D-174), the walled howdah (D-176). 3D placement before the last scutum change: 26195 checks, 2 failed; both
fixed but one: **open: the "gear: spider infantry with shield.scutum" fixture, the board 42 voxels into the spider's
back gear (34 allowed)**. Round F2 (rats and frogs) waits on Dominic's pick.

**2026-10-27, the rat (D-177, D-179).** Built with keyed legs (8 walk steps). 3D placement passes for every rat case.
Open, 2D at 2x on the rats: 10 failures (C4 draw order on rat-crewed ram, siege tower and great sling in one facing each;
a banner in front in facing 7; a scutum over the face in facing 0) and 4 fixtures no longer caught (hummingbird wings,
frog's hidden sword, centaur kneel, TC1 rat and cat). Frog B (D-178) not started.

**2026-10-27, the rat's open 2D failures.** Fixed: the rat heroes' feet (the 2D check's foot tolerance now scales with a
unit's drawn size, D-180), the banner in front facing the camera (back gear now goes by the back's depth, whatever its own
socket), the scutum over the face (the rat's shield hand up and out: RAT_HAND_L), the rats at the ram and siege tower
(crew rats stand back by their hunch, creatures.json `crew_back`; the bake's in-front test samples ahead of a member
leaning into work, part_baker MEMBER_AHEAD), the great sling's file of rats (two members whose bodies meet go over or
under the engine together). The rats pass 2D: 705 checks on "sewer rats", 0 failed; 3D every rat case.
**Open, 2D C4 on crewed engines (there before this change, run 2026-10-27 with and without it):** the siege tower's
reaching crew in f2/f7 (romans, swamp frogs, winged greeks, winged frogs), the moonbears' ram (f0, f7), the spiders'
great sling (f2), and war beast riders ordered among themselves (the rats' boar f0/f3/f4, han and swamp humans' box f3).
