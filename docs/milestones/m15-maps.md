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
- [x] 1. Resource audit, bigger 1v1 (built 2026-10-12; two sizes waiting for Dominic's pick by playing)
- [ ] 2. Trees
- [ ] 3. Rivers, fords, bridges
- [ ] 4. Worn paths
- [ ] 5. High ground
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

## Changes from the original plan

## Links
- `m16-sieges.md` (walls and high ground meet there), `m14-race-identity.md` (land-shaping as race abilities)
