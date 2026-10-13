# GS1: the great sling (2026-10-13)

Milestone 13 step 4. The great sling is built and in play (Castle, age 3): it hits buildings only, from
12 tiles (none inside 4), unpacks for 3 s after it stops before its first throw and packs up for 2 s
before it can roll. It wears a **stand-in**: the race's catapult (`siege_models.gd` ENGINE_STAND_IN).

Sheets: `gs1_3x.png`, `gs1_1x.png`; archive `archive/images/2026-10-13/426-`, `427-`. Spec
`tests/sheets/great_sling_gs1.json`, models `scenes/art_pixel/m13_concepts.gd` (GS1), each in every
siege take's materials (timber, frog, junk, forest, spooky). All rows pass the placement check.

- **A, a traction sling:** a tall A-frame, a long beam cocked high with the sling and stone at its end,
  three crew hauling the pull ropes from the front. Packed: the frame laid on a long wagon, the beam
  along it, ropes coiled.
- **B, a counterweight sling:** the frame on a wheeled base, a box of stones on the short arm, the long
  arm wound down to a windlass with two crew at the back. Packed: the same wagon with the empty box.

What I see at game scale: A is tall and nothing like the catapult in any facing (the beam and the hanging
sling are the silhouette), and it reads as "the big one". B is small and busy, and close to the
catapult's shape; its crew cover the frame. The packed wagons read as "a machine on the move", and the
change from packed to set up would show the unpack.

**Claude's recommendation:** A (traction), with the packed wagon shown while it moves and packs (a second
baked part, swapped when `units.ready` says it's set up).

**Questions for Dominic:**
1. A or B?
2. Show packed and set up as two looks (needs a small view change), or one look always?
3. The frogs: a sling like A in their reed and timber, or a beast again (D-121, D-122 gave them three)?
