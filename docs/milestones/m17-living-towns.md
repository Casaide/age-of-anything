# Milestone 17: Living towns

**Status:** built, waiting on Dominic's look (2026-10-12; view-side, ran alongside other milestones)
**Exit criterion:** a town at 10 minutes looks lived in at a glance, in every architecture, without
costing gameplay readability or frame time (art bench within budget); Dominic: "the town is alive".

Dominic (2026-10-12): "living towns is a must; our roads are great, but the town is dead."

## Scope (all view-side: the sim doesn't change)
1. **Work you can see.** Workers carry visible loads home (a bundle of reeds, a basket of bugs, a
   stone on the shoulder); builders hammer with dust; farmers tend rows; a drop-off pile grows at
   camps and empties; smoke from chimneys while a building works (training, research).
2. **Town folk and animals.** Idle workers do small chores near home (sweep, sit, chat) instead of
   standing; claimed sheep graze in a pen by the Town Center; birds and small critters by the
   culture (frogs' dragonflies, rats' pigeons).
3. **Buildings at work.** Doors open when units come and go; the barracks has drilling dummies,
   the range targets, the stable a horse at the rail; lights in windows at a dusk tint (cosmetic,
   if day-night comes).
4. **Wear and growth.** Paths wear in along busy routes (milestone 15), gardens and clutter grow
   around older houses, damaged buildings show cracks and fire.
5. **Sound** (src/view/audio.gd): a town ambience that grows with the town.

Concept-first for every new prop and animation (D-080); nothing floats, team colour stays subtle.

## Plan (Claude, 2026-10-12)
Everything lives in one view node, `src/view/town_life.gd` (TownLife), which the match view
updates after it has synced units and buildings; it only reads the sim. It also answers two
questions the match view asks per unit: what job it is seen doing (`job_for`) and what it holds
(`tool_for`). New baked props come from `scenes/art_pixel/town_props.gd` (baked with the other
props in `ArtKit._bake_town`), new unit parts from `unit_models.gd` and `data/parts.json`.
Concepts first: `tests/town_concept_sheet.gd` renders loads (8 facings), chores and props
(two styles of pile); the picks below were built and the sheet stays for Dominic's call.

## Checklist
- [ ] Plan approved by Dominic
- [x] 1. Work you can see
- [x] 2. Town folk and animals (but the pen: see below)
- [x] 3. Buildings at work
- [x] 4. Wear and growth
- [x] 5. Town ambience
- [ ] Dominic: "the town is alive"
- [ ] Archive: pictures taken along the way (400-407 in archive/images/2026-10-12), journal, decisions, timeline

## Results (2026-10-12, Claude)
1. **Work you can see.** Loads by resource, all held under the near arm (the hand over them, not
   pasted on top: Dominic's bug): the reed bundle, a haunch of meat (from a carcass), stone and
   a gold sack ride the shoulder in the body's "raise" hold (parts tagged `shoulder`), bugs go
   home in the basket. Gold loads were never baked before (load.gold was missing from
   `ArtKit.JOB_PARTS`). Farmers tend the rows with a hoe ("till": a waist-high swing). Builders'
   blows raise dust. Drop-off piles at the Town Center and camps grow with each load brought
   home (three stages per resource, picked styles: bug baskets, reed bundles in a heap, dressed
   stone blocks, ore in a box) and lose a load's worth every 14 s. Chimneys smoke only while
   their building trains or researches (houses always).
2. **Town folk and animals.** Idle workers near a house or Town Center (idle 3 s, nothing
   queued) sweep with a broom, sit (bipeds legs out, four-legged and armless lie down, frogs
   settle) or chat in pairs (turned to each other, nods, a hand lifted), a new pick every 18 s.
   Herd animals graze when they stand. Critters by culture round each Town Center: dragonflies
   (reed), pigeons (junk), small birds elsewhere; six each, drawn as a few art pixels, fly off
   when someone walks by, hidden in the fog.
   *Not done:* the sheep pen. Claimed sheep wait at eight spots round the Town Center (the sim,
   `animals.gd _to_town_center`), so a pen would stand empty; one sim change (park them at one
   spot) would let the view draw a pen round them. Dominic's call.
3. **Buildings at work.** Doorways light up (dark, firelight low inside) for 1.6 s when a load
   goes in or a unit or research comes out: town centres in every culture (but the stone one,
   whose porch columns stand in front of the door) and barracks. The stable keeps one of its
   race's mounts tethered by a post when the race rides one (a frog's beetle); centaurs, giants
   and Heavy elites have none. The barracks' dummies and the range's targets were already baked.
4. **Wear and growth.** A house grows a yard (a pot and stool, then firewood, then a drying
   rack) from 1 minute and a garden a stage behind (seedlings, a wattle fence, bean poles and
   gourds), on free ground off the paths. Damaged buildings crack from 30 % lost and burn from
   60 % (flames and black smoke on the roof, more fires as it gets worse).
5. **Town ambience.** Two loops rendered by `tools/audio` (`town_quiet`, `town_busy`), faded by
   your town's size and how close the camera is to your Town Center. Nobody has listened.

Cost: TownLife's own update is about 0.18 ms a frame at six minutes (72 units, 15 buildings;
`tests/town_bench.gd`), frame time unchanged; the art bench is unchanged (17 draw calls with
211 units). The town adds about 8 draw calls in the match view (critters, dust, fire, doors).
