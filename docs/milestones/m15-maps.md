# Milestone 15: Maps and land

**Status:** closed for now (2026-10-13, Dominic: "12 and 15 close for now. New maps look great"); the bots-on-big-maps work lands when it finishes
**Exit criterion:** a finished 1v1 map where a match can run 40 minutes to the last age without the
economy running dry; a 2v2 map that plays; rivers with fords and bridges, real trees, and high
ground, all in every architecture's look; the bot plays both maps; tick budget held at the bigger
sizes; Dominic plays a long 1v1.

Dominic (2026-10-12): "our current test map is nice, but too small, not enough resources for a
prolonged game, even as a 1v1. Resources biggest issue. We need to expand a bit, and plan a larger
map for future 2v2. Make a milestone for maps that covers a few + assets for it (trees, rivers)
and makes a 2v2 scale map and rounds off the 1v1." Also: "high ground I always wanted"; roads
shouldn't be a chore ("building houses or bridges gives them for free ... self-creating paths").

## Today
`flat_test` (64 x 64, 2 starts, 12 bug bushes, reeds, stone, gold, a pond) and `choke_test` (48 x
32, a movement test map, no food or wood). Wood is reeds; there are no trees. Maps are ASCII rows +
a legend into `data/terrain.json` (`data/maps/*.json`), the view builds tiles and props from them.

## Scope

1. **Resources for a long game.** Per start: bushes, two herds (sheep), deer and boar, a big wood
   line plus scattered groves, two stone and two gold deposits near, more in contested middle
   ground; totals checked against a 40-minute economy (a headless sim that counts what a bot
   gathers vs what's on the map).
2. **Trees.** Real trees as the wood resource beside reeds (reeds stay for swamp and frog maps):
   several species per biome, baked props like the bushes (concept round first, D-080), felled
   trees leave stumps, forests block movement and sight until cut.
3. **Rivers.** Deep water that blocks ground units, shallows as fords (amphibians cross anywhere
   shallow, and swim faster), banks and shore art (we have good shorelines already).
4. **Bridges.** Map bridges over rivers (choke points), destructible and rebuildable by workers;
   built in each culture's look. Frogs and other amphibians ignore them.
5. **Paths without the chore.** No road building. Culture paths already join buildings; they
   also wear in along routes units walk often (a trail that appears and fades). A small speed
   bonus on paths for everyone (10-15%: a road helps an invader too), or none: to decide by play.
6. **High ground.** Elevation in map data (a height per cell, 0-3), drawn as raised plateaus with
   ramps and cliffs in the iso view; ranged units shoot further from above and hit less often
   upwards; line of sight blocked by higher ground (fog); pathing through ramps only. Touches the
   renderer (heights in projection and y-sort), the sim (an integer height grid, LOS) and the art
   (cliff faces per biome: concept round).
7. **Maps.**
   - `reed_meadow` rounded off as the main 1v1 (about 96 x 96): the current look, resources for a
     long game, a river with two fords and a bridge, a hill in the middle.
   - A **2v2** map (about 144 x 144): four starts, teams side by side, shared middle ground.
   - Two more 1v1 maps for variety (a forest map, a river delta for amphibians), from the same parts.
   - `choke_test` stays a test map; the lobby lists real maps only.
8. **Performance at size.** Flow fields, fog and the minimap at 144 x 144 with 400+ units: the
   tick budget and frame time measured (`tests/test_sim.gd`, `tests/art_bench.gd`), cutoffs and
   caching where needed.
9. **The AI** on bigger maps: scouting further, expanding to far resources (a second Town Center),
   using fords and bridges, holding high ground.

## Plan
1. Resource audit and the bigger 1v1 (with today's assets): fixes "not enough resources" first.
   Moved ahead of milestone 13 (Dominic, 2026-10-12). Two versions of the same layout, 64 x 64
   dense and 88 x 88, for Dominic to pick by playing ("two minds about size").
2. Trees (concept round, then build).
3. Rivers, fords, bridges.
4. Worn paths and the speed question.
5. High ground (concept round for cliffs; renderer, sim, fog).
6. The 2v2 map and the variety maps; 2v2 needs teams in the lobby (allies exist in the sim).
7. Performance at size, the AI, exit check.

## Checklist
- [x] Plan approved by Dominic
- [x] 1. Resource audit, bigger 1v1 (built 2026-10-12; Dominic picked: the 64 is the 1v1, the 88 becomes the 2v2)
- [x] 2. Trees (built 2026-10-12; concept sheet waiting on Dominic's pick, one look per species in play)
- [x] 3. Rivers, fords, bridges (built 2026-10-12; bridge look waiting on Dominic's pick)
- [x] 4. Worn paths (built 2026-10-12; the speed bonus is off, see the experiment)
- [x] 5. High ground (built 2026-10-13; cliff look waiting on Dominic's pick: layered rock in play)
- [x] 6. 2v2 map, variety maps, lobby teams (variety maps built 2026-10-13: Old Forest, River Delta)
- [ ] 7. Performance, AI, exit check (performance at size done 2026-10-13; the AI done 2026-10-13, numbers below; the exit check to come)
- [x] Archive: pictures taken along the way, journal, decisions, timeline (journals 2026-10-12, 2026-10-13)

## Results

### Phase 1: resource audit and the bigger 1v1 (2026-10-12, Claude; moved ahead of milestone 13 by Dominic)
Tools: `tests/resource_audit.gd -- <map> [minutes] [radius]` counts each resource within 16 tiles of
each start and in contested ground, then plays bot vs bot, bot vs passive and "peace" (two bots that
never attack) for up to 40 minutes, printing per minute what each side gathered, what's left near
home, idle and far workers, and when each resource ran out near home. `tools/maps/reed_meadow.py`
builds both new maps from one layout, turned half a turn for the second start (rotational symmetry,
asserted). Maps can now carry their own animals (`"animals"`, the `data/animals.json` spawn shape,
with herds via `"size"`) and `"symmetry": "rotate"` mirrors them for the second start.

| | flat_test (first Reed Meadow) | reed_meadow 64 x 64 | reed_meadow_large 88 x 88 |
|---|---|---|---|
| per start (16 tiles) F/W/S/G | 1620 / 4900 / 1400 / 3200 | 3480 / 14900 / 3500 / 6400 | 3900 / 14400 / 3500 / 6400 |
| contested F/W/S/G | 1260 / 2600 / 0 / 0 | 1680 / 7200 / 3500 / 6400 | 2040 / 27600 / 7000 / 12800 |
| animals per start | 4 sheep, 1 boar | 8 sheep, 2 deer herds of 3, 2 boar | the same (+ a wild herd near) |
| peace: wild food gone near home | 7-9 min | 17-18 min | 16-21 min |
| peace: wood gone near home | 21-23 min (whole map dry at 32) | never (6700-7700 left at 40) | never (7500-9700 left) |
| peace: gold gone near home | 22-36 min (whole map dry at 38) | 37:30 / never | never |
| peace: sim tick avg (machine loaded) | 1.96 ms (25 min) | 1.57-1.85 ms | 2.4-3.0 ms |

Per start: 8 bug bushes, 4 sheep by the Town Center and 2 pairs further out, 2 deer herds and 2 boar
within 9-15 tiles, a ragged reed line along the two map edges behind the base plus groves, 2 stone
(5 tiles) and 2 gold (4 tiles) deposits. Contested: gold on the swamp band (equidistant), stone by the
pond, reed beds; the large map adds wing gold and stone, more reeds and a bush patch in the middle.

Bot matches (test_ai with a map argument): all pass on reed_meadow (median 11:45); on the large map
everything passes but Easy's army in the first ten minutes (26 pop against a cap of 25: a richer map
feeds a bigger Easy army) and one bot-vs-bot match ran 21:30. Camera bounds, minimap, fog and the
lobby card all scale from the map size; nothing broke at 88 x 88. Flow fields cost more there (full
fields are re-solved whenever a resource tile runs out, 6000+ cells each); the average holds the
budget, the worst ticks spike. A follow-up for phase 7: patch opened cells into cached fields instead
of dropping them.

Bot notes found on the way (not map problems): after wild food the bots farm slowly (30-130 food a
minute at 30 workers), and the bots' 30-worker cap makes a 40-minute economy smaller than a player's.

### Phases 2-4: trees, rivers, fords, bridges, worn trails (2026-10-12, Claude)
**Trees.** One `tree` terrain (100 wood, blocks movement and sight, `"opaque"` in terrain.json),
felled into a walkable `stump`. Sight: fog stamps go through a line-of-sight table (each cell
of the sight circle seen only if the cell before it on the line from the centre is seen and
doesn't block) where a chunk counter says a tree is near; open country keeps the plain stamp.
Workers chop with the existing wood job, animation and sound. Art (`scenes/art_pixel/tree_models.gd`):
three species in three concept looks each (`archive/images/2026-10-12/300`), in play: broadleaf 0
(leaf-card crown), pine 0 (tiers of needle cards), swamp 1 (weeping willow); the view picks the
species from the ground (swamp trees by water and swamp, pine and broadleaf groves elsewhere).
Felled stages: the log by its stump, sawn up, the stump (303); stumps stay until built over.
**Rivers.** `river` terrain (deep running water: walkers go round, amphibians swim it at 115%)
and `ford` (walkable, walkers at 70%, amphibians 120%: rules.movement.terrain_speed). Drawn
with the existing water shader (a ford reads as shallows with the bed showing).
**Bridges** (`src/sim/bridges.gd`, `data/bridges.json`): placed by the map (`"bridges": [[x0, y0,
x1, y1]]`), owned by nobody, ids from the shared counter. A standing bridge lays a deck
(`SimMap.deck`: ground over the water). Anyone breaks one with an ATTACK (an attack-click on it
in the view; 1200 hp, pierce armour 20, so spears and axes, not arrows); it falls, the deck goes,
anyone on it scrambles to a bank. Any player's workers rebuild it with HELP_BUILD (right-click
a broken bridge), the first to start paying 150 wood, 30 s of work. Neutral timber look, three
concepts (trestle in play, log, humped: 301); every size the maps use is baked.
**Maps.** `tools/maps/reed_meadow.py` builds both, asserting symmetry, bridges standing on river
and landing on ground, and that the river cuts the map in two without its crossings.
- `reed_meadow` 64 x 64, the 1v1: the wood line behind each base and groves are trees now
  (reeds stay down the side and on the swamp), a contested wood; a stream along the swamp band
  (2-3 tiles) with two fords and a 2 x 2 bridge in the middle (304). Resources as phase 1 but
  contested wood 9600 (from 7200).
- `reed_meadow_2v2` 88 x 88 (was reed_meadow_large; Dominic: "much too big for 1v1, call it our
  first 2v2"): four starts listed in mirror pairs (0, 1 and 2, 3; `"teams": [0, 1, 0, 1]`),
  teammates side by side on one half, the second start the first one's kit transposed, the
  other team the half turn. Each start: 8 bushes (+4 between teammates), the animal kit, a
  forest line, 2 stone, 2 gold; flanks with gold, stone, bushes and a forest; a shared corner
  forest; contested gold, stone, bushes and woods by the centre; the wide river with two fords
  and three bridges (a kink in each arm and the centre) (305, 306). Per start (16 tiles): F/W/S/G
  3800 (2220 for the north starts in a 2-player run, which places no animals there) / 11-12k /
  3500 / 6400; contested 5000 / 78000 / 10500 / 25600. Animals are mirrored per start pair now.
**Worn trails** (`src/sim/trails.gd`, rules.trails): a byte per cell; every 10 ticks each walking
unit wears its cell, every 100 ticks each row grows back (spread over ticks). The view hands the
grid to the terrain shader once a second, softened, drawn as earth trail (307). It reads as a
trail between the Town Center and its work, and as trampled ground where soldiers stand at a
rally; tuning by eye left for Dominic.
**The speed question** (`tests/trail_experiment.gd`, reed_meadow, the same matches with
`speed_pct` 0 and 12): trails cover about 1.4% of the map and units walk on them 17-26% of the
time. Peace, 15 minutes: gathered 6276 / 8612 without, 6309 / 7896 with (within the noise of
diverging matches). Bot vs bot: the same winner, 11:52 without, 12:37 with. A 12% bonus on a
fifth of the walking is a 2-3% speed-up: not felt. Left off (default 0); worth trying again
when culture paths are known to the sim (roads between buildings carry most traffic).
**Performance.** Flow fields are patched where cells only opened (felled trees, picked-bare
bushes, a rebuilt bridge: a decrease-only relaxation, checked against fresh solves in
test_sim) instead of dropped: dropped fields on the old large map over 20 minutes 2706 -> 770.
Fog: allies share one grid (copied), units on the same cell stamp once, only last update's lit
cells are dimmed. The flow cache holds 12 fields per player (24 at least). `tests/sim_profile.gd`
times World.step's parts. Measured with the machine loaded by other agents' Godot runs (13
processes): 1v1 test_sim match 2.68 ms avg; reed_meadow peace 1.83 ms; the 2v2 with four bots
(20 minutes) 2.83 ms avg (fog 0.72, solve 0.66, separation 0.44); a whole 2v2 bot match 3.7 ms.
**Bots.** test_ai on reed_meadow: 10/10, matches 10:47 / 11:52 / 18:41 (median 11:52).
`tests/test_2v2.gd`: four bots in teams on reed_meadow_2v2: ended 37:01, team 0 won, no hits
between teammates, 9706 across.
Known gaps: bots don't break or rebuild bridges (they path over them); the lobby has two sides
(another agent's redesign); a 2-player match on the 2v2 map uses starts 0 and 1 (opposite).

### Phase 5: high ground (2026-10-13, Claude; Dominic: "high ground I always wanted")
**Data.** A map may carry `heights`, rows like the terrain rows: a level per cell, `0`-`3`, and
ramps as letters (`a` climbs from 0 to 1, `b` from 1 to 2, `c` from 2 to 3). Maps without it are
flat. Cliffs are derived (`SimMap._load_heights`): a cell is a cliff if a neighbour (8-way) stands
higher than the highest ground it reaches (its level, or a ramp's top). So any step without a
ramp, and any step of two levels, has a cliff cell at its foot. The heights go into the map hash.
**Sim.** A cliff cell is closed to walkers and amphibians in every walk grid (flyers cross it) and
can't be built on; buildings stand on one level, never on a ramp. Nothing else had to change:
flow fields, movement, separation and the bots' reach areas all read the walk grids, so walkers
change level only on a ramp. Combat (`rules.high_ground`, integers): a shooter a level above its
target reaches 1 tile further, one below 1 tile less and deals 75% (arrows falling short, no
dice); towers the same. Fog: ground above the viewer's level blocks sight like a tree, so from
below you see a hill's rim but not its top; units see 1 tile further per level, buildings 2. A
per-chunk highest level keeps the plain stamp in flat country. Tests (`tests/test_sim.gd`
`_test_hills`, on `hill_test`: a plateau with a ramp and a knoll on it): cliffs close, flyers
cross, nothing built on cliffs or ramps or across levels, a walker climbs by the ramp and never
stands on a cliff, the rim is seen from below and the top beyond it isn't, the top sees 7 tiles,
an archer hits 600 beyond its flat reach downhill without moving, closes in uphill (as on the
flat) and hits for less, 60 walkers cross onto the plateau and settle, a fight over the ramp
gives the same hashes twice.
**View.** `Iso` keeps corner heights per cell (`set_relief`; `lift`, `to_ground`, `pick`); a level
is `Iso.LEVEL_PX` = 20 px. `TerrainView.build_relief` draws raised tops through the terrain
shader again (UV.x: the lift, so it paints that cell's ground; ramps slope, shaded by their
facing), cliff faces down the edges that face the camera (`scenes/art_pixel/cliff.gdshader`: a
grass lip, the face, scree at the foot, lit faces turned to the light) and a dark line on back
edges. Under everything, level by level; copies of the tops within two cells of a back edge go
into the y-sorted layer, one per screen row, so a hill hides units behind it. The rule that
makes it work: everything in the y-sorted layer sorts on the base plane, its art raised inside
the node (units, buildings, props, piles, flags; overlays use `UnitView.ground()` and
`Iso.to_ground`). Mouse picking finds the highest ground drawn under the cursor; the fog shader
walks down the screen to the frontmost ground drawn at each pixel; the minimap lightens each
level and darkens cliffs. **Concept round** (180): earth bank, layered rock, mossy boulders;
layered rock is in play (the other two read as a wall); Dominic to pick.
**Maps.** `reed_meadow`: a ridge on each side of the middle bridge (the bridgehead, 166 cells of
level 1 per map, a ramp from home and one towards the bridge; 182, the fight up the ramp 181).
`reed_meadow_2v2`: between each team's bases a two-level hill (ramps towards both bases, a ramp
onto the knoll), and a lookout hill on each start's flank over the fords (183). Both symmetric
(asserted), resources untouched (no resource, rock or water on a hill, ramp or cliff), starts and
bridge landings flat; the generator checks with the sim's rule that every hill top is reached
from every start and none without its ramps.
**Numbers.** `sim_profile` flat_test (10 min): 1.08 / 1.09 ms with this branch, 1.07 ms with main's
sim (flat maps unchanged). reed_meadow with its hills (15 min, peace): 1.65 ms (fog 0.43).
test_sim's 200-unit match measured 3.34 ms avg with the machine loaded (load 6, eight other Godot
runs); the same code on flat ground is within 1% of main, so that's the load.
**Bots.** `test_2v2`: four bots on the hilly 2v2, ended 12:40, no hits between teammates (4/4).
`test_ai -- reed_meadow`: 24 of 26; the same code on the flat map passes 26/26. The first two
matches play out the same; later ones diverge and two checks fail on bot habits the new ground
brings out, not on pathing: a Cohort-vs-Frogs match runs to the 30-minute limit (the Cohort's
army stands at home on an attack-move whose formation slots fall on its own Town Center, while
the Frogs' archers hold the Cohort's ridge), and in the walled-fords check a worker is shut in
for 30 s by its own houses and the forest. Both are for the bot pass (phase 7).
**Not done:** the bots don't seek high ground for their archers (they path over hills fine);
cliff edges are staircases of cells (no rounded or diagonal faces); a farm sown within two cells
of a plateau's back edge is drawn under the hill's copy of its ground (flat things lie under the
y-sort); a level is 20 px, subtle when zoomed out: Dominic may want it taller.

### Phase 6: the variety maps (2026-10-13, Claude)
Two more 1v1 maps from the same parts, each a generator in `tools/maps/` that reuses Reed Meadow's
checks (rotational symmetry, crossings that split the map, bridges standing on river, heights:
hills reached only by their ramps). Both are listed in the lobby by name, with the card drawn
from the map data (200, 205), and in sim_debug's map list.
- **Old Forest** (`old_forest`, 72 x 72, `tools/maps/old_forest.py`): the map starts as trees and
  is opened up: a home clearing per base, two hunting glades beside it (deer herds, a boar,
  bushes), a flank glade on the stream with a lookout hill over its ford (one per side, turned),
  and the central glade with gold on both banks and a ford in the middle (201, 202). Paths wind;
  the short way from each base to the centre stops three or four trees short of the glade, so
  cutting them opens a straight road. A stream from corner to corner with three fords. Pockets of
  open ground shut in by trees are filled with trees by the generator (no unreachable grass).
  Per start (16 tiles) F/W/S/G 2020 (+ 4 sheep, a deer herd) / 33900 / 3500 / 6400; contested
  7680 (bushes, 24 deer, 6 boar) / 208600 / 3500 / 12800; 2764 trees on the map.
- **River Delta** (`river_delta`, 72 x 72, `tools/maps/river_delta.py`): the river comes in at the
  north-east and south-west corners and spreads into a marsh of channels round a lagoon of
  shallows. Each side has a dry bank (base, wood line, groves), and across a side channel two
  islands of its own (sheep and stone on one, gold and sheep on the other) reached by fords. The
  main channel splits the map: walkers cross on a bridge by each flank (a dwelling mound beside
  each, held by the side whose bank it's on), a ford, or the causeway (fords through the lagoon)
  over the middle island (gold, stone, two sheep) (203, 204, 206). Amphibians swim every channel
  and wade the lagoon. The generator asserts every piece of dry ground is reached by walkers over
  the crossings (no swimmers-only island: its animals and resources would be the frogs' alone);
  ground only reached by cutting reeds is filled with reeds. Per start F/W/S/G 2760 (+ 4 sheep,
  2 deer herds, a boar) / 16100 / 3500 / 6400; contested 5680 (+ 18 sheep, deer, boar) / 24200 /
  5600 / 16000; map total wood 56400.
- **Data:** a map's animal spawn may list `"fixed"` cells (`src/sim/animals.gd`): a glade's deer,
  an island's sheep, nobody's, each with its half-turned twin on a turned map; placed before the
  rings round the starts. Both generators assert each one stands on open ground walkers reach.

**Resource audit** (`tests/resource_audit.gd`, 40 minutes, peace and bot vs bot, Frogs vs Rats):
- Old Forest, peace: ended 31:27 (the "peace" bots fight now: Reed Meadow's peace run ended 25:52
  the same way, a bot change, not the maps). Near home nothing ran out: at 30:00 wood 28900 /
  26500 left, stone 3460 / 2200, gold 4100 / 3200; wild food near home gone by ~9 min, then farms.
- River Delta, peace: ran the full 40 minutes; nothing ran out near home: at 40:00 wood 4300 /
  4400 left, stone 1470 / 1220, gold 1480 / 3190, food from farms (gathered 13500 / 13250); the
  contested gold barely touched (15000 of 16000 left). Wood near home is the first to thin (from
  ~30 minutes the bots cut 400-700 a minute); the marsh reeds (14600 contested) are next.
- Sim tick averages (machine loaded by other agents' runs): forest peace 2.84 ms, delta peace 3.72 ms.

**Bots** (`test_ai -- <map>`): every match ends with a winner and the bot beats a passive player on
both maps. Old Forest 29 of 32 (matches 10:03-23:23), River Delta 30 of 32 (10:07-13:48). The two
age-3 checks (University and Castle, their research) fail on both, and fail on `reed_meadow` too
with today's bot (`test_ai -- reed_meadow age3`): not the maps. Old Forest also fails "healers
keep behind the army" (23 of 34 looks, 70% needed): armies strung along forest paths.
Bot notes for the bot pass: the Frogs bot sits at 17 workers in age 1 until ~9 minutes on Old
Forest (Rats age at 5:30), and lost the bot-vs-bot match without reaching age 2; bots don't
cut through the thin woods to open the straight road; no bot uses its amphibians' swimming as a
route choice beyond what pathing gives them; the causeway fords read close to the lagoon's
shallows in the view (a look for Dominic).

### Phase 7, performance at size (2026-10-13, Claude)
**Measured first** (`tests/sim_profile.gd`, which now times every part of `World.step` and the
bots' thinking, prints the average, p99 and worst tick, what the ten worst ticks spent their time
on and the final hash; `-- test_sim` plays test_sim's timed match). Main and this branch were run
side by side in the same minutes (other agents' Godot runs loaded the machine, load average 7-8):

| | main | this branch |
|---|---|---|
| 2v2, four bots (ended 12:40): tick avg / p99 / worst | 4.27 / 30.6 / 117 ms | 2.99 / 9.6 / 43.6 ms (next worst 17.8) |
| reed_meadow 1v1, two bots (ended ~17:30) | 2.13 / 11.9 / 26.8 ms | 1.83 / 6.3 / 11.1 ms |
| test_sim's match (200 units, no bots) | 3.35 / 8.5 / 17.0 ms | 2.78 / 6.8 / 16.6 ms |
| 2v2 bots' share / fog / map sync worst | 1.51 ms avg, 110 ms worst / 12.0 / 43.7 ms | 0.45 ms avg, 4.3 ms worst / 3.7 / 7.6 ms |
| flow fields dropped by map changes (2v2, 1v1) | 1176, 615 | 353, 88 |
| match view, 2v2 at 10 min, 340-350 units, over a town at 3x / 1x (`tests/view_bench.gd`) | 14.5 / 14.8 ms a frame (worst 48) | 9.4 / 10.1 ms (worst 23); 350-440 draw calls either way |

What the worst ticks were: the four bots thinking on one tick (the economy's resource search walked
every resource cell of the map with string lookups, per idle worker and per resource; research
wishes worked out once per building), flow fields patched cell by cell for a farm finishing (a
label-correcting relaxation over the whole shadow behind it, 48 fields x 9 cells: 44 ms), fog for
every team on one tick, and the bots' area labels.
**Fixed:**
- Bots: the resource search tests kind (per terrain) and distance before reach and farms; "is
  there any" stops at the first; research wishes once per think; reach labels without a list per
  cell (all the same answers: same final hashes on the 2v2). Then each player's bot thinks on its own
  tick (two ticks apart), so no tick thinks for everyone (a behaviour change: decisions move by a
  few ticks; test_ai fails only the two age-3 checks main fails too, test_2v2 passes).
- Flow fields (`Flow.patch_opened`, `patch_closed`): cells that open are patched in one pass
  cheapest first (each cell settled once); cells that close no longer drop the field: the cells
  whose way ran through them are reset and re-solved locally. Only lanes whose grid really changed
  count (a building shuts nothing for flyers). A per-tick budget (3000 cells, a quarter of the map
  per field) bounds it; past it a field is dropped as before. Checked against fresh solves through
  180 closings and openings on the 2v2 map (`test_sim`: `_test_flow_patch_mixed`).
- Fog: one team per tick of the fog cycle; allies copy their leader's grid and memory instead of
  working it out again; the remembered ground walks the shorter of "in sight" and "watched".
- Towers find targets in the tiles within reach (spatial grid), not by scanning every unit.
- Movement: `clear_path` answers a sample in one look where its cell and all round it are open (a
  "roomy" grid per lane, kept up by `SimMap._refresh`); the walk checks in `_move` and `_separate`
  written out. test_sim's movement 1.34 -> 0.85 ms, same hashes.
- View: units off screen or in the fog don't animate, turn or change tools; resource props are
  looked at when what you'd see there changed (all of them at the fog's rate, only cells whose
  shown amount or ground moved; fading ones every frame: 1.7 ms a frame -> nothing most frames);
  the minimap repaints from a colour table (2.9 -> 0.7 ms, five times a second); town life reads
  the sim once a tick (dust from blows still every frame). Units sync 2.2 -> 0.9 ms a frame.
**What's left:** a full flow-field solve on 88 x 88 is 4-5 ms (more when the machine is busy) and
runs whole in one tick: the remaining spikes. A solve sliced over ticks would flatten them. Fog
with forests everywhere is line-of-sight stamps (~25 us each), 0.4-0.7 ms a tick on average.
**The budget** (milestone 16 asks): test_sim's 200-unit match measures 2.8 ms with the machine
loaded (main 3.35 ms in the same minutes, 17% more); no quiet machine was to be had, so the
margin on a quiet one is still to confirm (test_sim's own check passed at 2.82 ms loaded). Proposal: keep 3 ms average at 200 units and allow 5 ms at 400 units for sieges (movement,
separation and fog grow with the units; bots excluded, as each runs on one machine), p99 under 10 ms
on Dominic's Mac, checked on a weaker machine before release.

### Phase 7, the bots on the new land (2026-10-13, Claude)
All of it is the bot playing like a player: commands only, from what it sees and remembers; data
in `data/ai.json` (new sections `scout`, `land`, `expand`; `economy.trade`; `military.raid_*`,
`contain_*`, `dominant_pct`; `levels.*.guard_crossing`, `raids`, `raid_from`). Four new scripts
beside `bot.gd`:
- **`src/ai/routes.gd`**: a whole-map route search for the bots (a bucket-ring Dijkstra like the
  flow fields', 8 neighbours, diagonals only between cells that are really open), priced per cell:
  slow ground dearer (a ford for walkers), and the extras a player weighs: trees it could fell, a
  broken bridge as if mended, ground under enemy fire, the main route (for a flank). 3.5 ms a
  whole search on 72 x 72, 9 ms on 88 x 88: a study runs as a `Routes.Search` sliced over thinks
  (1200 cells a think, `land.search_cells`), so no tick spends a whole search.
- **`src/ai/scout.gd`: scouting and memory.** A worker tours once the bot has 9 workers (150 s at
  most): round the enemy start at 7 tiles (facing us, and a sixth of a turn each way), then up to 6
  crossings and the middle, nearest next, home and back to work; from age 2 the fastest idle
  soldier at home tours every 5 minutes. Hit, a scout runs home. By 4:00 the bot has seen 157-176 of
  the 289 cells round the enemy start. The fog keeps the ground and the enemy buildings
  (`fog_seen`); the scout remembers the enemy soldiers it saw for 3 minutes (where, and what), and
  counter-picks, raids, detours and "who's stronger" read that memory, not just what's in sight
  this second. A Town Center on a map start counts as known (every player knows the starts): a
  scout that saw only an outlying camp turned the first wave from the Town Center to the camp
  (frogs vs passive on Reed Meadow: 9:01 -> 20:22, fixed).
- **`src/ai/land.gd`: crossings, roads, bridges, hills, flanks.** Fords in clumps and the bridges
  are the crossings. One "study" (a search) every 2 s at most, each kept fresh on its own clock:
  *our way* to the wave target and to the enemy start (20 s), *their way* to us on the enemy's lane
  (30 s; the crossing on it is the **key crossing**), each bridge (30 s), a detour, a flank, a road.
  - **Bridges.** A broken bridge whose mending makes our way to their start 20% shorter, or is the
    only way, is mended by the two nearest workers when no enemy soldier is near it (walled-fords
    check on Reed Meadow: mended at 0:42, and the bot won over it). A standing bridge whose loss
    makes *their* way 30% longer (or cuts it) is broken by up to 6 melee soldiers idle at home,
    once they field 6 population, when we swim (amphibians lose nothing) or they outnumber us by
    30%; one broken on purpose isn't mended while there's another way. In the test matches the
    condition never came up: the fords lie close to the bridges on all three maps.
  - **Guarding the crossing.** A level that guards (Easy, Normal), once it has been on the back
    foot (the army it remembers outnumbering its own by 30%), takes one more build step: a
    Watchtower at 24 workers within 5 tiles of where their way leaves the key crossing on our side,
    if that's within 24 tiles of home (a spot search of its own: the house spot's margins off resources find nothing by a ford in
    the woods). Scenario check (`test_ai -- <map> hills`): 2 tiles from it on Reed Meadow and Old Forest (the delta's key crossing is out by
    the enemy: skipped).
  - **Roads through thin woods.** Two searches from the side of home facing the middle (walking;
    trees at 2.5 times open ground), trees on our side of the map only: the cell beyond 12 tiles
    with the biggest saving, at least 5 tiles and 10%, with 1-6 trees on the way, gives the road.
    Three wood gatherers fell exactly those trees (each its own, nearest first), from a lumber camp
    they lay by the road when nothing of ours takes wood within 4 tiles (kept 2 tiles off the road:
    the first one shut it). Up to two roads a match, from 16 workers. Old Forest: 3 trees in the
    north corridor (a 6-7 tile saving; the cut by the enemy's side of the middle saves more but is
    theirs to cut); Reed Meadow 2-4 trees (20-24 tiles in all), River Delta 3 (26).
  - **Hills.** Ranged soldiers with 3+ enemy soldiers within 10 tiles step up (a plain move: an
    attack-move stopped to shoot at the foot) to the nearest higher ground within 10 steps, no
    lower than the enemy stands; defence and raid answers leave a climbing shooter be. Scenario
    check: 4 archers 3 steps from a ramp, 4 spears coming: 2+ up in 1-4 s on all three maps; 1-28
    hill orders a side in the test matches.
  - **Detours round fire.** Remembered enemy shooters on a hill above our way, and remembered
    towers (not the ones by the target: those are what the wave is for), price the cells under them;
    a way round no more than 50% longer gives the wave a waypoint (queued attack-moves). 7-9 waves
    a match took one in the delta and meadow test matches.
  - **Amphibious flank.** For an amphibious army, a second way kept 5 cells off the main one, no
    more than 60% longer: 40% of a wave of 6+ goes that way (through the channels on the delta).
- **`src/ai/expand.gd`: reaching out.** Camps follow the workers: 3+ gatherers of a resource
  working over 7 tiles from any drop-off of theirs get a camp (a mill for food) by the middle of
  them, one look every 45 s, not while saving for an age; a camp it can't pay for is held back from
  the soldiers (the Hard rats on Old Forest sat at 0-40 wood for minutes, 25 wood gatherers walking
  9-10 tiles). Escorts: a knot of 4+ gatherers beyond 18 tiles gets 3 soldiers posted (age 2, an
  army of 10+, two posts), out of the waves. The second Town Center's step waits for 30 workers
  instead of 40 on a big map (80 wide: the 2v2) or once home runs thin (under 1500 wood or 600 gold
  within 16 tiles), laid on our side (nearer us than them by a fifth).
- **Finishing (the Old Forest draw).** Hard vs Normal drew there because Hard bled small waves
  into towers and a Castle and fell behind. Now: a raiding level (`raids`: Hard 3 groups from the
  start, Normal 2 from 20 minutes) sends its waves at the enemy's economy first, the camps, mills,
  farms, pens and markets it remembers out of reach of their shooting buildings; an army under 30
  population doesn't storm a Town Center under towers or a Castle but waits on its way in, out of
  their reach (contain), and storms it once it's 30; an army that with its allies' is 2.5 times the
  enemy army it remembers skips the raids and goes for the Town Centers with everyone out there not
  fighting a soldier (no more chewing through houses; two bots against a last one finish it
  together). Each building trains the best counter it can pay for now (one short of wood no longer
  stops a building whose other line uses the gold piled up). Hard researches gathering and line upgrades first too (`build_up`:
  it fell behind on the economy). The market trades (`economy.trade`): while food or wood is under
  200, gold over 500 buys a lot of the lower one; with gold short too, the biggest pile over 500
  sells (bots sat on 600 gold, stone or food with no wood and armies of 5-15); the market comes at
  22 workers in age 2 and every level's soldiers leave its cost alone (`save: 2`): at 26 minutes,
  behind the Castle in the build order, it came too late to matter. No caps anywhere.
- **Fixes on the way.** Camps, mills and (for the build order) houses no longer hold up the build
  order: it waited minutes on far houses (the age-3 check failed on that, not on the content).
  Healers follow the middle of the army's rear half (a wave split by a flank pulled them forward).
  The flow-field cache is 24 fields a player (was 12): a bot working camps, posts and scouts at once
  thrashed 12 (fields solved in 15 minutes of Reed Meadow 6587 -> 2689; ~60 KB a field on 88 x 88).
- **Tests.** `test_ai -- <map> land` (also in the full run): an early scout sees round the enemy
  start; a Normal match reports what each bot did (tours, roads, camps, posts, hills, raids,
  guards, flanks, detours) and checks camps go up, a road is felled on Old Forest, the match ends;
  then the guard and hill scenarios (`-- <map> hills` runs just those). The walled-fords check
  takes a mended bridge as a way over (and checks the mend on Reed Meadow, where the bridge is the
  only other way); the healer check leaves posted escorts out of "the army".

**Numbers** (`test_ai -- <map>`, seed 7; before = main at c0658e1, after = this branch; machine
loaded by other agents' runs throughout, so times are comparative only):

| | Reed Meadow before / after | Old Forest before / after | River Delta before / after |
|---|---|---|---|
| test_ai checks | 35/35 / 42/42 | 34/35 (Hard drew Normal) / 42/42 | 35/35 / 40/40 |
| bot vs bot (3 matches) | 20:35, 24:23, 28:08 / 15:57, 22:44, 26:22 | 9:09, 15:49, 26:26 / 19:57, 20:05, 22:22 | 16:29, 24:18, 26:08 / 14:19, 14:34, 24:06 |
| Hard vs Normal | Hard 10:06 / Hard 22:44 | draw at 30:00 / Hard 23:42 | Hard 12:05 / Hard 25:27 |
| bot vs passive (frogs, rats) | 9:01, 8:20 / 21:17, 17:59 | 22:39, 15:30 / 22:23, 23:36 | 19:09, 11:08 / 21:29, 16:30 |
| levels left alone (age 3 E/N/H) | 14:15, 15:12, 15:13 (m12) / 11:53, 11:41, 11:59 | 13:02, 13:22, 16:35, 3 checks failed / 11:58, 13:13, 13:50, 1 failed (Easy's Castle) | - / 12:31, 12:17, 12:59 |

Every bot match ends inside the 30-minute limit on all three maps. The 2v2 (`test_2v2`, 45-minute
limit) ended 15:03 before and 27:43 after (a bot left alone behind its Castle had held out to
37-45 minutes until teammates counted each other in "stronger than them"). Bot matches against a
passive side got slower: the bot now scouts and raids the economy first, contains outside towers
and only storms with 30 population. `sim_profile` (same minutes, loaded machine): the bots' share
of a tick on Reed Meadow 0.16 -> 0.31 ms on average, the 2v2 0.54 -> 0.90 ms (longer matches with
more units: 157 vs 88 units at the end on Reed Meadow); the worst bot think 9.8 -> ~5 ms after the
searches were sliced (a whole search was 7-10 ms). test_sim 2.955 ms with main's 2.952 in the
same minutes (both under its 3 ms budget).

## Changes from the original plan
- 2026-10-12 (Dominic): the 88 x 88 Reed Meadow became the first 2v2 instead of a second 1v1 size.
- Bridges are one neutral timber look, not one per culture (they belong to nobody); amphibians
  swim the river anywhere (no shallows band needed).

## Links
- `m16-sieges.md` (walls and high ground meet there), `m14-race-identity.md` (land-shaping as race abilities)
