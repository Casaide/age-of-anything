# SP1: the sapper's charge (2026-10-13)

Milestone 13 step 4. The sapper is built and in play (Castle, age 3): the race's light kit (a cap at most)
and a charge; its first blow on a building blows it up (combat.gd `_blast`): a wall, palisade or gate
tile outright, a house at once, about 40% of a Town Center, everything within 1.5 tiles hurt, and the
sapper with it. Its charge is a **placeholder**: the worker's sack, made smaller.

Sheets: `sp1_3x.png`, `sp1_1x.png`; archive `archive/images/2026-10-13/424-`, `425-`. Spec
`tests/sheets/sapper_sp1.json`, models `scenes/art_pixel/m13_concepts.gd` (SP1). All rows pass the
placement check.

| | Everyone | Own (C) |
|---|---|---|
| A | a clay fire pot on a rope, a burning rag in its neck | |
| B | a leather satchel charge, a coiled fuse and a lit match | |
| C | | frogs: a bundle of reed rockets (fireworks); rats: a rusty lamp-oil can, a burning rag in the spout; beetles: a bombardier's gland, amber, glowing; spiders: a black egg sac wound in silk |

What I see: **every charge in the hand is too small to read at game scale**, and still small at 3x; the
flames are the only thing that shows. A held object can't grow much: the placement check caught bigger
ones cutting through a beetle's head and a spider's legs in the blow.

**Claude's recommendation:** a round 2 with the charge **carried on the back** (a keg or a big pot
strapped on, a fuse running to a match in the hand), which reads at 1x and keeps the hands free; the
family takes above as the back loads (rockets in a quiver, the oil can, the gland, the egg sac). If you'd
rather keep it in the hand, A (the fire pot) reads best thanks to its flame.

**Questions for Dominic:**
1. In the hand (A/B/C) or a round 2 on the back?
2. Family takes (C) or one charge for everyone?
3. How strong: a Town Center in three sappers feels right? (data: `tool.charge` bonus vs buildings 600)

## Parked (D-127, D-128, 2026-10-13)

Dominic: no carried charge, and then (the correction) no sapper at all for now: the unit is parked (D-128:
its slot back to `planned`, the Castle and the bot no longer make it). Round SP1 above is history; there is
no round 2 on the back. If the sapper comes back, its look stays plain (the race's light kit, nothing
carried), and the options here (`concept.sp1_*` in `data/later/m13_concepts.json`) stay staged, unused.
