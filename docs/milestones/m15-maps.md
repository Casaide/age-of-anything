# Milestone 15: Maps and land

**Status:** planned (proposed 2026-10-12; the first phase can start alongside milestones 12-13)
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
- [ ] Plan approved by Dominic
- [x] 1. Resource audit, bigger 1v1 (built 2026-10-12; Dominic picked: the 64 is the 1v1, the 88 becomes the 2v2)
- [x] 2. Trees (built 2026-10-12; concept sheet waiting on Dominic's pick, one look per species in play)
- [x] 3. Rivers, fords, bridges (built 2026-10-12; bridge look waiting on Dominic's pick)
- [x] 4. Worn paths (built 2026-10-12; the speed bonus is off, see the experiment)
- [x] 5. High ground (built 2026-10-13; cliff look waiting on Dominic's pick: layered rock in play)
- [ ] 6. 2v2 map, variety maps, lobby teams
- [ ] 7. Performance, AI, exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

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

## Changes from the original plan
- 2026-10-12 (Dominic): the 88 x 88 Reed Meadow became the first 2v2 instead of a second 1v1 size.
- Bridges are one neutral timber look, not one per culture (they belong to nobody); amphibians
  swim the river anywhere (no shallows band needed).

## Links
- `m16-sieges.md` (walls and high ground meet there), `m14-race-identity.md` (land-shaping as race abilities)
