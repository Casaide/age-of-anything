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


---

# In play (D-129, 2026-10-13)

Dominic: GS2 is "much better". Built: the siege-weight traction sling for timber, junk, forest and spooky
(`siege_models.gd` _great_sling, `siege.sling.<take>`), and the packed wagon while it isn't set up
(`siege.sling_packed.<take>`, the body part's `packed`; `UnitView.set_packed`, from the sim's `units.ready`).
The six haulers stand in two files beside two pull ropes that run from the crossbar to stakes in the ground (the
haulers in two ranks stood in each other: placement C1); a centaur crew hauls two abreast further out (`_wide`, the
rest `_narrow`). The frogs keep their snail catapult as a stand-in (ENGINE_STAND_IN) until they pick from FS1.
Sheets: `tests/sheets/great_sling_play.json`; archive `632-`, `633-`, in a match `634-`.


# FS1: the frogs' great sling (2026-10-13)

Dominic on GS2's frogs: "the tortoise one is wrong, and the plain one probably too boring". Three swamp ideas that
repeat none of their beasts (the turtle ram, snail catapult, toad bolt thrower, heron war beast, newt cavalry).

Sheets: `fs1_3x.png`, `fs1_1x.png`; archive `635-`, `636-`. Spec `tests/sheets/great_sling_fs1.json` (size references:
a frog worker, the frogs' snail catapult that stands in now, the humans' great sling as played), models
`scenes/art_pixel/m13_concepts.gd` (FS1), staged from `data/later/m13_concepts.json`. All rows pass the placement check.

- **A, the bullfrog leaper:** a counterweight sling the other way round from the traction one: its long arm down in
  front with the pouch on the ground, the short arm up high behind with a padded landing pad, and a giant olive
  bullfrog (yellow throat, gold eyes) crouched on a reed tower behind it, about to leap onto the pad and fling the
  stone. Two frogs load the pouch, one minds the tower.
- **B, the stilt sling:** the GS2 frame smaller on a long deck up on bundled-reed stilts over a sledge (a swamp
  house on the move); the pull ropes run to cleats at the deck's front, four frogs hauling up on the deck, a loader
  at the stones below.
- **C, the crayfish winder:** the GS2 frame hauled down by a giant crayfish (WB2's, unused there) gripping the two
  pull ropes in its claws and backing away; a frog rides it, another loads.

What I see at game scale: A is the most frog and the funniest, and the tower and the bullfrog make it read as tall as
GS2; it's busy from behind. B reads as a deck of frogs more than a sling (frogs are big next to a smaller frame).
C is the longest thing in the game and splits into two things at 1x, though the crayfish is a strong read.

**Claude's recommendation:** A (the bullfrog leaper). **Question for Dominic:** A, B or C (or another idea)?


# FS1 A in play (D-131, 2026-10-14)

Dominic: the bullfrog leaper ("fun!"). Built for the frogs (`siege_models.gd` _frog_sling, `siege.sling.frog`), the
snail catapult stand-in gone: the counterweight sling with its long arm down in front and the loaded pouch on the
ground, the padded short arm up behind, the giant bullfrog crouched on the reed tower; a loader at the pouch with clay
pots and river stones, two haulers on the re-cocking rope to a stake ahead, one frog minding the tower. It throws the
big corded clay pot (`shot.clay_big`).

- **Packed** (`siege.sling_packed.frog`, _frog_packed): the tower's reed posts, the timbers and the arm lashed on a
  heavy sledge, which the bullfrog hauls in a breast band; two frogs beside.
- **The throw** (`siege.sling_throw.frog`, the part's `throw`): the bullfrog landed on the pad, the arm swung through,
  the sling whipped up empty, the rope slipped off and coiled by its stake; shown for 0.9 s after each shot
  (`UnitView.loose`), then back to the set-up look.

Sheets: `tests/sheets/great_sling_play.json` (frog rows: set up, throwing, packed); archive `640-` (3x), `641-` (1x),
throwing in a match `642-`. All rows pass the placement check (composites), in every facing.
