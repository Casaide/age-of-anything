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
- [ ] Archive: pictures taken along the way (430-432, 455-456 on 2026-10-13), journal, decisions, timeline (left to the main session)

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

**Open.**
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
