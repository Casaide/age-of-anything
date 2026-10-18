# 2026-10-17: The deep river, and walls over hills

## What happened

Dominic played a 2v2 on Reed Meadow and came back with two things that made it "very one sided too early on":

- **Gaps behind the trees.** The wood line behind each base was drawn from one tile in (`line(2, ...)` in
  `tools/maps/reed_meadow.py`), leaving a grass lane between the trees and the map edge. An enemy could cross the far
  flank bridge, walk the lane behind the woods and turn up at the back of the base. The wood lines now start at the
  edge, one tile deeper, their inner edge where it was. (Shifting them outward instead, same depth, looked harmless,
  but the 1v1's age-3 bot then never built its University or Castle in test_ai: it is tuned to the old inner edge.)
  So every start has a little more home wood.
- **Frogs.** The river was one terrain, `river`, which amphibians swim and flyers cross. Against frogs it wasn't a
  river at all. Dominic's idea: shallow, deep, shallow. A new terrain, `deep_river` (`"move": []`, nobody crosses),
  down the middle of a wider river; the shallow bands stay `river`.

Mid-way he added: flyers over trees "feels again too imbalanced". Trees now block flyers too (`"move": []` on `tree`).
His idea for what flying should be: a castle unit with extra big wings that can soar over trees. That's new unit art,
so it goes concept-first, as its own piece.

## How it's built

- `data/terrain.json`: `deep_river` (darker colour), `tree` with `move: []`.
- `tools/maps/reed_meadow.py`: rivers with a `deep` radius inside `r` (88: r 3.0, deep 1.5; 64: r 2.0, deep 1.0);
  fords turn deep cells into ford too; bridges stretch along their length until both ends stand on ground; the map
  edge is deep where the river runs off it (else a flyer goes round the end over the edge rock). The crossing check
  now floods for walkers, amphibians and flyers, with and without the crossings.
- `src/view/art/terrain_view.gd`: the deep middle draws as full water, the `river` band at 0.8, so you can see where
  frogs can swim.
- `tests/test_sim.gd` (part movement_classes): on both Reed Meadows, every class reaches the other side only through
  a ford.

## Then the hills

"While we're there", Dominic: the mounds are "a bit boxy around the edges", and walls wouldn't go over them.

- **Walls over hills.** Cliff cells (the foot of a step) and ramps refused any building, so a wall line stopped dead at a
  hill. Wall and palisade pieces now go on them (`SimMap.can_build(..., slope_ok)`, from `Economy.can_place` for `line`
  buildings). Each piece is one cell at its own level, so the wall steps up the hill. Gates stay off cliffs: an own
  gate is open to its side, and on a cliff it would be a staircase. `_refresh` also never opens a gate cell on a cliff.
  Checked in test_sim (part walls): a line across the 2v2's team hill, every piece placeable, wall and palisade; no
  gate on the cliff; a gate still over the wall on flat ground. `tests/sim_screenshot.gd` scene `wallhill` draws it.
- **Bevelled edges.** `Iso.corner_heights`: a raised cell's outer corner (the other three cells round it all lower
  plain ground) drops to their height. The diagonal staircases become sloped edges. Small dark triangles remain on
  the front where a straight run steps out; better than the tile notches, not yet smooth.

## Checks

- test_sim movement_classes: the new flood checks on both maps, all three classes.
- test_ai quick on reed_meadow: everything passes but the siege bot's "rams go out": its first ram came at 14:50
  instead of 13:40 and was still at home when it won (16:30, as before). A direct check: groups of rams, frogs and
  flyers sent across both maps all arrive, and none ever stands on deep water.
- test_2v2 on reed_meadow_2v2: passes (team 0 wins at 26:39).

## Funny moments

The first crossing check said flyers got round the river. They didn't: the check counted fords as open sky. A ford
is a crossing for flyers as much as for anyone.

## Pictures

- `archive/images/2026-10-17/17-reed-meadow-deep-river-at-the-ford.png`: the 2v2's ford, deep water either side.
- `18-hill-edges-boxy-before.png` and `19-hill-edges-bevelled-after.png`: the team hill, before and after.
- `20-wall-and-palisade-straight-over-the-hill.png`: a stone wall and a palisade across it, stepping up the levels.

## Ideas parked

- A winged race's castle unit with big wings that soars over trees (concept-first).
- Deep middles for the other river maps (river_test, old_forest, siege_vale, river_delta) if they play the same way.
