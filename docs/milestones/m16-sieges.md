# Milestone 16: Sieges (and the first game modes)

**Status:** in progress (started 2026-10-13, Dominic: "start milestone 16", "including full siege with
walkable walls etc"): every step built to a first version; art waits on concept picks; the budget
waits on Dominic's word
**Exit criterion:** a walled town can be held and taken: defenders on the walls, attackers with
rams, ladders or siege towers, sappers and catapults making breaches; it reads clearly on screen;
neither side's win is a foregone conclusion at equal cost; the bot defends and assaults walls;
a 300-unit siege runs within the agreed tick budget; Dominic plays "Romans besiege the rats".

Dominic (2026-10-12): "Right now [walls are] small... I always wished you could garrison walls and
have larger scale sieges. My gut says a large scale siege, Romans vs rats, will go down very well.
We need a milestone focusing on siege mechanics, while keeping it simple and enjoyable." And: "we
should consider the effect of the 3 ms sim budget, if we're tying our hands too much."

## The line with milestone 13 (agreed 2026-10-13)

Milestone 13 brings the engines as plain damage dealers (ram, catapult, bolt thrower, great
sling, sapper). This milestone owns breaches (a destroyed wall tile becomes rubble, walkable and
repairable), walkways, gatehouses, wall towers, ladders, the siege tower (moved here from 13),
the defenders' tools and the game modes; it turns 13's sapper and catapult hits on walls into
breaches.

## Game modes (Dominic, 2026-10-12: "sieges should be the first step into game modes")

Sieges open the game modes, built on milestone 18's match rules contract:
- **Fortress:** every side starts with a walled town already built (palisade or stone ring with
  gatehouses and towers by its culture, a few defenders on the walls), more resources to spend on
  siege; matches are about breaking in and holding out.
- **Siege (attack/defend):** one side starts walled and stocked, the other with an army and siege
  engines; win by taking the Town Center, or by holding until a timer runs out.
- Each mode is data (start buildings and walls per map, rules), offered in the lobby, with the
  bot able to play both roles.

## Mechanics (simple first)
1. **Walls you stand on.** Stone walls get a walkway: ranged units ordered onto a wall stand on it
   (a few per tile), get +1 range and can't be hit by melee from the ground. Palisades stay
   walkway-free (cheap, early). Units reach the walkway through gatehouses and towers.
2. **Gatehouses and wall towers** join the wall line (a gate with a walkway over it; a tower that
   shoots and holds a garrison), placed into a line like gates are.
3. **Ways in:** rams batter gates and walls; ladders (a worker or infantry carries one, a few
   seconds to climb, defenders can push it off); siege towers dock on a wall and unload onto the
   walkway; sappers and catapults make **breaches** (a destroyed wall tile becomes rubble you can
   walk over, repairable by workers).
4. **Defenders' tools:** something poured on whoever's at the gate (each culture's version: hot oil,
   boiling swamp water, scalding cheese), and the existing garrison arrows.
5. **High ground** (milestone 15) makes walls on hills stronger.
6. **Readability:** units behind tall walls show as outlines (or walls fade near the cursor);
   wall damage states (cracks, then rubble); a breach is obvious.

## The tick budget
The sim targets 3 ms average per tick at 20 Hz (budget set in milestone 1 for 200 units, leaving
room for rendering and lockstep on modest machines). A tick at 20 Hz may take up to 50 ms, so 3 ms
is a self-imposed comfort margin, not a wall. For sieges we decide, with measurements:
- the unit count a big siege needs (300-500 together, crowds at a breach, the worst case for
  separation and flow fields);
- a new budget per unit count (e.g. 5 ms at 400 units on Dominic's Mac, still checked on a weaker
  machine before release);
- what to optimise first if needed: flow-field caching per target, separation only near movers,
  fog at a lower rate, crowds through gaps (the pathing work in progress).
Decision written down before building the big pieces, so we're not designing around a number we
don't need.

## Plan
1. Measure: a scripted 400-unit siege on a walled test map; set the budget (decision).
2. Walkways and garrisoned walls; gatehouses and wall towers.
3. Rams on gates, breaches and rubble, repair.
4. Ladders and siege towers.
5. Defenders' tools; readability (outlines, damage states).
6. The AI: defend walls (man the walkway, sally against rams), assault (bring rams and ladders,
   pick the weak side).
7. Game modes: Fortress and Siege (attack/defend) in the lobby, prebuilt walls per culture and
   map; a siege showcase map; balance; exit check.

**Refined with what's built (2026-10-13, Claude).** Walls are one building per tile (walls.gd needs no
new map layer): a walkway is a per-cell place count on a building type (`walkway`), a way up is a
building with `stairs` (the stone gate, now the gatehouse, and the new wall tower), a ladder (a
walk-over building against an enemy walkway) or a docked siege tower (a unit with `docks`). A unit on
a wall stays in the units arrays (seen, hit, selected) with `perch` set; movement and separation skip
it, the walkway is walked by its own small path (breadth first over the network, cached per tick).
High ground's rules give the height (combat.gd _height_step, fog.gd), so a wall on a hill counts
both. Breaches are terrain (wall_rubble) with a record of what stood there, so the flow fields and the
view need nothing new. Modes are a `mode` on the host rules (data/modes.json, src/sim/modes.gd), the
first piece of milestone 18's contract; the lobby picks it.

## Walls for sieges: what we take from castle-building games (2026-10-13, Claude)

Dominic, having seen the milestone: the siege towers are too small, and the walls are "a bit buggy and
overlappy, and not really big enough for what we're aiming for": learn from castle-building games and
others, "less like the classic first-generation look". What makes a wall read as a fortification in the
games built around castles, and what it means for us:

- **Mass first.** A real curtain is thick: the walkway on top is wide enough to walk two abreast, with a
  parapet on the outside and often a low one on the town side, so the top reads as a road, not a ridge. In
  those games the wall is commonly two or more tiles deep, and you see soldiers walking along it and
  standing at the crenels. Ours is a 0.54-tile ridge 0.72 high: a man and a bit. It reads as a garden wall
  next to a house.
- **Height you can measure.** The wall is several times a man's height, and the eye measures it by the
  people on it and by details that repeat at a known size: crenels, arrow loops, string courses, a battered
  foot. Ours had no cues but merlons.
- **Merlons with men between them.** Tall crenellations (half a man high) with defenders visible in the gaps
  are the single strongest "this is a castle wall" signal. It needs the art to put the near merlons in
  front of the defenders and the far ones behind them.
- **Towers that rise well above the walls**, round or square, standing proud of the wall face so they can
  shoot along it, with a crown (corbels, a wider fighting top) and often a roof or a timber hoarding. They
  are where stairs come up: the wall walk is reached from towers and gatehouses, which is also how our sim
  already works (`stairs`).
- **The gatehouse is the strongest piece**: two towers either side of a deep passage, a block over it with
  the wall walk across, a portcullis and leaves, drop holes over the arch (our pour has its home here).
  Ours is a pier at each end of an open arch.
- **Clean joins.** Corners, T junctions and towers join without seams or doubled stone; diagonal stretches
  run between towers rather than stepping. The joins are the model's, not stacked sprites fighting.
- **Height that matters.** Ladders and siege towers are sized against the wall top; a siege tower is
  clearly taller than the wall, a storey or two, with a gangway that drops onto the walk. Being up there is
  an advantage (reach, sight, safety from melee), which our high-ground rules already give.
- **Damage you can read.** Whole, cracked, holed, breached to a rubble heap you can walk over; a breach
  is obvious at a glance and so is a repaired stretch.
- **Culture in the material, not the shape.** The same strong silhouette in dressed stone, brick, timber or
  earth; a palisade stays the cheap, light early wall.

**How it maps to us.** The grid stays: walls are buildings on cells, a walkway is places on cells
(walls.gd), ways up are buildings with `stairs`. A thicker wall is a wider footprint, a taller one only a
bigger model and a bigger walkway lift, a tower a bigger building that joins the line. The art keeps the
classic pipeline (each piece baked from 3D), but the pieces must join as the 3D does: the join check
below compares our composed sprites with one 3D bake of the same layout. The options, their sim
implications and the questions for Dominic are in `docs/concepts/m16/README.md` (round W2).

## Checklist
- [ ] Plan approved by Dominic
- [x] 1. Measure and set the budget (measured 2026-10-13; the number is a proposal for Dominic, below)
- [x] 2. Walkways, gatehouses, wall towers (Dominic, 2026-10-13: "full siege with walkable walls etc")
  - [ ] Dominic's pick of the wall tower look (concept W1: squat, drum, hoard; the squat one is in as a placeholder)
- [x] 3. Rams, breaches, repair (walls and breaches; workers repairing siege engines too)
  - [ ] Dominic's pick of the rubble look (W1: heap, stub; in play it's the terrain's colour only)
- [x] 4. Ladders, siege towers
  - [ ] Dominic's pick of the siege tower (concept T1: hide, open frame, belfry, the frogs' turtle; "hide" is in as a placeholder) and the ladder (W1: plain, hooked, mantlet)
- [x] 5. Defenders' tools, readability (pour built; readability partly: units drawn up on the wall, the pour's burst; outlines behind walls and wall damage states not yet)
- [x] 6. AI (mans walls, siege towers over the wall, a townless besieger for the Siege mode; ladders not used by the bot yet)
- [x] 7. Game modes (Fortress, Siege), showcase map, balance (Siege 2-2 over four bot matches), exit check (Dominic's "Romans besiege the rats" still to play)
- [x] Walls round 2 (Dominic, after seeing the milestone: "the siege towers are too small... walls... a bit buggy and
  overlappy, and not really big enough... less like the classic first-generation look"): research below, the bugs
  found and fixed with a join check (`tests/wall_join_check.gd`), concept round W2 (`docs/concepts/m16/README.md`)
  - [ ] Dominic's pick of the W2 direction (A thick, B tall, C per culture), then the sim and art build
- [x] Siege and Fortress fill the gap (Dominic: "just in siege mode we fill the gap"): every side can build and repair
  walls, gates, wall towers and ladders in those modes whatever its race lacks (`lift_lacks`)
- [ ] Archive: pictures taken along the way (430-432, 455-456, 560-568 on 2026-10-13), journal, decisions, timeline (left to the main session)

## Results

**The tick budget (step 1).** `tests/siege_bench.gd -- <per side> <minutes>`: the rats in a stone
ring (gatehouses on four sides, wall towers) round their Town Center on flat_test, archers and
skirmishers sent up on the walls, the Romans marching on it with rams, catapults, siege towers and
a big army, attack-moving every 20 s. Measured on Dominic's Mac with other sessions running (load
6-26); the 200-unit reference (`sim_profile.gd -- test_sim`, 2.75 ms on a quiet machine) measured in
the same minute to scale by:

| run | reference | siege avg | ticks with 300+ units | worst |
|---|---|---|---|---|
| 200 a side (368 units), no walkways yet | 4.66 ms | 6.97 ms | 9.24 ms | 66 ms |
| 200 a side, walkways in | 3.40 ms | 4.45 ms | 7.31 ms (~5.9 quiet) | 44 ms |
| 250 a side (458 units), walkways in | 3.40 ms | 6.18 ms | 8.98 ms (~7.3 quiet) | 41 ms |

Combat is half the siege tick (2.3 ms of 4.4: idle soldiers looking for foes, towers' volleys),
separation next (0.7 ms; crowds at a gate), the walls' own tick 0.3 ms (80 on the walls).
**Proposed budget (Claude; Dominic decides, then a D-number):** keep 3 ms average for 200 units
(the everyday match); for a big siege, 8 ms average with 400-450 units on Dominic's Mac and no tick
over 50 ms (one 20 Hz tick), checked on a weaker machine before release. What to optimise first if
it's tight: combat's target search for idle units (a slower beat while nothing is near), then
separation only near movers.

**Walls you stand on (step 2).** `src/sim/walls.gd`; data `walkway` in data/buildings.json (climb 2 s,
fall 10 hp, 80% speed on the walkway, riders, giants and engines can't climb). Stone walls hold 2 a
tile, the stone gatehouse 2 a tile and has stairs, the new Wall Tower (age 2, 25 wood 60 stone,
1800 hp, shoots, holds 3 inside and 3 on top, has stairs) drops onto a wall tile like a gate (it
`replaces` the wall). Units ordered onto a wall (right-click your wall) walk to the nearest way up,
climb, and spread over the nearest places (a group fills the wall outward); up there they are a level
up (+1 tile reach for shooters, 75% damage from shots fired up at them, +1 sight), melee below can't
reach them nor they it, and they don't chase. Ordered anywhere else they walk to the best way down
(on the destination's side) and climb down; anything else (gather, attack a building...) waits in
their queue until they're down. A wall tile destroyed under them: they fall (10 hp, never killed).
Melee on the walkway fight each other along it. Drawn raised on the wall (sim_debug `_wall_lift`;
higher on a tower). Pictures 430 (archers on the walkway), 431 (a breach, the archers fallen).

**Breaches and repair (step 3).** A destroyed wall, palisade, gate or tower leaves its cells as
`wall_rubble` terrain owned by its player (walls.gd breach, w.rubble); workers right-clicking it
rebuild the piece for 40% (data `breach.repair_pct`); anything built over rubble clears it. Repair
(`src/sim/repair.gd`, Commands.REPAIR): workers mend damaged buildings and machine siege engines (not
the frogs' beasts: healers mend those) at half the build pace for half the price, paid a twentieth at
a time. Rams, catapults, the great sling and soldiers make breaches through the usual building death
(the sapper is parked, D-128: nothing here depends on it).

**Ladders and siege towers (step 4).** The Siege Ladder (age 2, 25 wood, 60 hp): a worker raises it
on open ground beside an enemy walkway; it's walked over and is a way up for its side; a defender
settled on its top cell with no attacker there pushes it off (2 hp a tick each). The Siege Tower
(Siege Workshop, every race, roster slot `siege_tower`, engine part `siege.tower.<take>`, never
fights: weapon `targets: none`, tag `docks`): stopped within 1.6 tiles of an enemy walkway cell it's
docked, and its side's foot soldiers ordered onto that wall climb through it. Climbers on the enemy's
wall come down the enemy's own gatehouse and tower stairs into the town. The model is a marked
placeholder (picture 432). `tests/placement_check.gd -- siege_tower`: 22 checks pass.

**Defenders' tools (step 5).** A gatehouse or wall tower with one of its side settled on top pours on
every enemy on the ground within a tile, every 5 s: 14 melee against armour (a ram's melee armour is 0:
it suffers most). Each culture names it (families.json `pour`: hot oil, red-hot sand, boiling pitch,
boiling sap, boiling tar, hot ash...; creatures.json: the rats' scalding cheese, the frogs' boiling
swamp water); the view shows a burst at the gate. The name isn't shown in the UI yet.

**AI (step 6).** `src/ai/walls_ai.gd`, data `military.walls` in ai.json: with walkway walls the bot
keeps up to 60% of its shooters at home up on the wall nearest the nearest enemy it sees (its defence
and raid response leave them up there); it trains one siege tower (military.siege.max), pushes it to
the nearest enemy wall when attacking and, once docked, sends the foot soldiers within 12 tiles up
and over (a queued attack-move takes them down the enemy's stairs); a side with no town (Siege's
attackers) puts its whole army on the attack (rams at the walls, towers over, the rest attack-moving).
`tests/test_ai.gd -- piece:walls_bot` (6 of 10 shooters up in a minute; the tower docks at 0:06, 8 up,
8 inside) and `piece:siege_mode`.

**Game modes (step 7).** data/modes.json, src/sim/modes.gd; the lobby's map card has a Mode row
(Standard, Fortress, Siege). Fortress: every side in age 2 behind a stone ring (radius 9, gatehouses
on four sides, a wall tower every 6 tiles), 4 archers and 2 skirmishers up on the wall facing the
enemy, a stockpile. Siege: player 0's team holds a ring (radius 10) in age 3 with a garrison; the
others start townless in age 3 with an army (26 swordsmen, 13 spears, 15 archers, 9 heavy, 6 rams, 4
catapults, 3 siege towers) and 4 workers; the defenders win after 20 minutes, the attackers are out
when they have nothing left. **Siege Vale** (`tools/maps/siege_vale.py`, 72 x 64): the west start in a
clear round so its ring stands whole (rings follow the land and leave gaps at trees and stone, so on
the forest maps they're patchy), the east an open camp. Bot vs bot Siege on Siege Vale, both orders of
rats/Romans and frogs/Greeks: defenders 2, attackers 2 (7:58 to 13:45, 14 to 30 breach cells); a
notch smaller army and the defenders win 3 of 4, a notch bigger and the attackers do. `tests/test_sim.gd` parts walls, siege_ways, modes; `tests/test_ai.gd` pieces
walls_bot (quick), siege_mode (slow).

**The walls' bugs (walls round 2, 2026-10-13).** Found with a join fixture in the game
(`sim_screenshot.gd -- out.png flat_test walljoins:5`: a straight run with a tower, an L with a tower on its
corner, a T, a diagonal with a tower, gatehouses along x and on a diagonal, archers on every kind of piece)
and measured by `tests/wall_join_check.gd` (below). Fixed:
1. Units on a walkway were drawn 22 px up on every piece, but a wall's top is 28 px up, a wall tower's 49 and a
   gatehouse's 54: they were sunk into the stone (on towers and gatehouses only a head showed). Each piece now
   says how high its walkway is (`Models.WALK_H`, `ArtKit` `walk_px`) and units stand on it.
2. A unit on a wall sorted on its own point, level with or before the piece under it, so the piece drew over its
   legs (worst on diagonals; on a gatehouse's far end it vanished into the gate, which sorts by its middle). Units
   up on a piece now sort just after it (`BuildingArt.perch_sort_y`).
3. There was no "between the merlons": a unit was over or under a whole piece. The near merlons of a walkway
   piece now bake as a front layer, a node of its own sorted just after the units on that piece
   (`ArtKit.front_split`, `BuildingArt.front`): defenders stand between merlons, legs hidden by the ones in
   front.
4. The wall tower was 0.86 tiles wide: a 0.07-tile gap showed where the wall arms met it. It fills its tile now.
5. The merlons had no beat: two on the post's corners (off the arms' faces), one on the edge the arm owned, so
   pairs and wide gaps alternated along a line. One merlon each face halfway along each arm now: an even
   rhythm across tile edges.
6. The gatehouse's piers had a merlon on the walkway's line (in the way, and neither in front of the units nor
   behind); the post stood 0.08 higher than its arms (a bump every tile). Both gone.
Pictures 560 (before), 561 (after), 562 (the check's truth, the old composition, the difference).
Not fixed (they depend on the redesign, W2): the gatehouse has no floor over its passage (open to the sky so a
unit in the gateway shows; units on its middle stand on air: the check reports it as known); a gatehouse on a
diagonal seen end-on reads as a hollow shaft; towers barely rise over the wall (1.25 against 0.72) and the
siege tower's top (0.83) is hardly over the wall's; the rubble is the terrain's colour only (W1's pick).
A risk to watch, not seen in the fixtures: a 3-tile gate sorts by its middle, so a ground unit right beside its
far end could draw under it; per-tile pieces (as in every W2 option) avoid it.

**The join check.** `tests/wall_join_check.gd -- [filter] [arch] [debug] [legacy]` (needs a window, ~1 minute):
twelve fixtures (straight runs with towers along x and y, both corners, a T, both diagonals, gatehouses along
x, y and the diagonal, a gatehouse between towers, units up on each). Per fixture it bakes the 3D truth once
(every piece's model with its arms, units' stand-ins at the walkway height, one id colour each) and lays out
the game's own sprites (wall looks, bodies, front layers) in the game's draw order, and compares the two id
maps past a pixel's slack at edges: any pair of pieces where one is drawn over the other wrongly, a piece
where the truth has none, a unit hidden, floating or sunk, fails with its pixel count. It also checks that
joined pieces meet (solid stone within 0.02 of each join: the tower gap passed the id check, because the
truth had the gap too) and each walkway's height against its model's top. `legacy` lays the units out as
before the fix: every fixture fails (picture 562); with the fix all pass.

**Siege and Fortress fill the gap.** Dominic: "Siege mode we need to ensure everyone has walls", then "just in
siege mode we fill the gap": race lacks stay in normal matches; in Fortress and Siege the mode's `lift_lacks`
(data/modes.json: palisade, palisade gate, stone wall, gatehouse, wall tower, ladder) lets every side build
and repair them, defenders and attackers alike (the attackers can wall a camp). A race only mends what it can
build (`Repair.can_mend`). `tests/test_sim.gd -- part:modes`: the centaurs (who lack walls) can't build or mend
a stone wall in a normal match, can in both modes, rebuild a breach, and a later normal match's centaurs still
lack them (the lift is a copy per side). The rings themselves (`Fortify.ring`) were always put up whatever the
race.

**Open.**
- Dominic: the W2 pick (thick, tall, per culture; `docs/concepts/m16/README.md`), which sets the wall's
  footprint, the tower and gatehouse sizes and the siege tower's height.
- Dominic: the budget number; the picks (W1 wall tower, ladder, rubble; T1 siege tower); playing
  "Romans besiege the rats" (Siege mode, Siege Vale).
- Fortress bot vs bot stalls: four 22-minute matches on Siege Vale, no breach, about 45 units a side
  (the bots' waves don't take on a ring with every gate shut; a human plays it fine). The bot's
  assault against a full ring is the next AI step.
- The bot doesn't raise ladders; infantry can't carry one (workers raise them).
- Readability: outlines behind tall walls, wall damage states (cracks), the pour's name and a better
  pour effect, the rubble's own look (W1).
- The siege tower doesn't carry units inside; units climb through it once it's docked.
- Ladders and the siege tower aren't in the bot's counter-reading or the balance round robin.

## Changes from the original plan
- Gatehouse: the stone gate is the gatehouse (stairs and a walkway), no new building.
- Ladders are a building a worker raises (not carried by infantry) for now.
- The siege tower is a way up while docked, not a carrier.
- The match rules contract is only `mode` so far (milestone 18 builds the rest on it).

## Links
- `m13-unit-lines.md` (rams, catapults, sappers; the siege tower is this milestone's), `m15-maps.md` (high ground),
  `m12-tech-tree.md` (walls, gates, towers, garrison)
