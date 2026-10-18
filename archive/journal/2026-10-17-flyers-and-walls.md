# 2026-10-17: Flyers and walls

## What happened
Dominic, after playing: flyers go over palisades ("probably fair, just annoying early game"), but big walls they
shouldn't cross; and "is it just too unbalanced either way?" Claude looked: flyers crossed every building, stone
walls and gatehouses included, and wings cost 4 points. Over everything, walls meant nothing against a winged race;
over nothing, after D-154 took trees and the deep river away, wings would be little but speed. So: stone walls (and
their gates and towers) stop flyers, palisades and other buildings don't (D-158). Dominic agreed, and added that
flying over a building looked like ghosting through it.

## Decisions
- D-158: `blocks_flyers` on the stone wall, stone gate and wall tower; old saves mark their walls on load.
- Flyers over a building sort after its front corner and climb a little: drawn over the roof.

## Bugs on the way
- The first run of the new check: walls didn't stop flyers. The sim's building table copies only the fields it knows
  from buildings.json, and the new flag wasn't one of them.
- The first flyover picture had no flyers in it: the scene picked its units before the spawn had happened.

## Pictures
- `21-flyers-drawn-over-the-town-center.png`: winged hoplites crossing their Town Center, over the portico.

## Checks
- test_sim `movement_classes`: a full-width stone wall is closed to flyers and keeps one on its side; a palisade
  line it flies over; an older save's walls close on load. test_ai quick: 96 checks, 0 failed. run_tests: 0 failed.

## Ideas parked
- Should the Castle stop flyers too? (Not asked; the flag does it.)
- Win rates of winged races before and after (race_matches), not run yet.
