# GS1: the great sling (2026-10-13)

Milestone 13 step 4. The great sling is built and in play (Castle, age 3): it hits buildings only, from
12 tiles (none inside 4), unpacks for 3 s after it stops before its first throw and packs up for 2 s
before it can roll. It wears a **stand-in**: the race's catapult (`siege_models.gd` ENGINE_STAND_IN).

Sheets: `gs1_3x.png`, `gs1_1x.png`; archive `archive/images/2026-10-13/426-`, `427-`. Spec
`tests/sheets/great_sling_gs1.json`, models `scenes/art_pixel/m13_concepts.gd` (GS1), each in every
siege take's materials (timber, frog, junk, forest, spooky). All rows pass the placement check. (2026-10-13,
under the stronger composite check: A's three haulers stood in each other; they now stand 15 apart,
staggered. Sheets re-rendered.)

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


---

# GS2: the great sling, round 2 (2026-10-13)

Dominic on GS1 (D-127): "pretty cool, but needs to be bigger and more robust looking: for siege! not thin
and skinny." So a **siege-weight traction sling**, A's direction made heavy.

Sheets: `gs2_3x.png`, `gs2_1x.png`; archive `archive/images/2026-10-13/488-`, `489-`. Spec
`tests/sheets/great_sling_gs2.json` (size references: a worker, the catapult, GS1's sling), models
`scenes/art_pixel/m13_concepts.gd` (GS2), staged from `data/later/m13_concepts.json`. All rows pass the
placement check.

- **The machine:** squared timbers about twice GS1's (4.2 against 2.0), on long sills (56 against the
  catapult's ~40), braced towers with cross ties and raking struts, iron bearing caps, an axle 20 across,
  the arm 5.4 thick at the axle tapering to the long end, four iron bands, the long end cocked high (about
  76 up), a big pouch with a boulder, a crossbar at the short end with six pull ropes, a pile of stones
  behind and a team pennant on top.
- **Crew (D-118):** six haulers in two ranks on the ropes, one loader at the stone pile.
- **Takes:** timber (humans), junk (the rats', D-116: scrap timber patched with rusted plate, chains, cheese
  for ammo), forest (bark timbers, acorns), spooky (dark wood and bone), frogs A (their dark timber, clay
  pots), frogs B on the snapping turtle (D-121/D-122's swamp beasts: the sling smaller on a deck lashed to the
  ram's turtle, three frogs hauling on deck, one beside), and the timber take packed to march (the timbers
  and the arm on a long heavy wagon).

What I see at game scale: it's now the biggest machine on the sheet, taller and heavier than the catapult in
every facing, and GS1 beside it looks like a toy. The crowd of haulers sells "siege". The frogs' turtle take is
the weak one: the frogs are big next to a smaller frame, so it reads as frogs on a turtle more than as a
sling; frogs A (the standing frame) reads better.

**Claude's recommendation:** the standing frame for everyone (frogs A too), with the packed wagon shown while
it moves and packs (a second baked part swapped when it's set up).

**Questions for Dominic:**
1. Big enough and sturdy enough now?
2. Frogs: the standing frame (A), or a beast again (B on the turtle)?
3. Packed and set up as two looks (a small view change), or one look always?
