# Milestone 3: Economy

**Status:** built (2026-10-11); waiting on the exit check, which is Dominic watching an opening (F6 in the debug view)
**Exit criterion:** the opening economy is fun to watch for 3 minutes. That's Dominic's call
by eye. The tests back it with numbers: a scripted 3-minute opening gathers in a sensible
range, nobody stalls, and it's deterministic.

## Scope
Gather -> carry -> return to the Town Center. **Food** (bug bushes, near-infinite instead of farms)
and **Wood** (reeds). The Town Center trains workers; Houses give pop (+5; Rats +6); build
placement and construction.

Not in this milestone: Barracks, Stable, Watchtower, age-up (milestone 7), combat (4), AI (8),
drop-off camps (Next), hunting (Next: needs animals that move).

## Plan

**Decided with Dominic before starting:** cut-down reeds become walkable ground (paths open up
over a match), and the milestone builds a minimal clickable panel plus hotkeys, not hotkeys only.

### Data first
- `data/terrain.json`: resource terrain gets `resource`, `amount` and `depleted` fields.
  Reeds = 100 wood per tile; a new **bug bush** terrain = 2,000 food per tile (near-infinite).
  Maps get bug bush clumps near each start.
- `data/buildings.json` (new): per building: footprint, hp, cost, build time, pop it provides,
  drop-off resources, what it trains, age. MVP here: **Town Center** (3x3, pop 5, drop-off for
  everything, trains workers) and **House** (2x2, pop 5).
- `rules/*.json` gets an `economy` block: start resources (200 food, 200 wood), starting
  workers (3), pop cap (200), carry (10), gather ticks per unit, build speed.
- **Race economy modifiers** (`cost_pct`, `train_time_pct`, `house_pop`) come from
  `creatures.json`, so rats are cheaper, train faster and get +6 houses from data, not code.
  This is the "civ definition" from the MVP plan, starting small. Stats aren't in the race
  key, so no keys change.

### Sim (integers only, ids ascending, everything through commands)
- **Players:** food, wood, pop, pop cap as ints, per player id.
- **Resources live on the map grid:** remaining amount per cell. A depleted cell becomes its
  `depleted` terrain (see the question below).
- **Buildings:** a second packed-array store (same id counter as units, so command ids never
  clash): type, owner, cell, footprint, hp, build progress, train queue, rally point. Footprints
  block movement.
- **Map changes** (a building placed, a reed bed cut down) bump a map version and drop the
  cached flow fields that tick. This is deterministic, and the version goes into the hash.
- **Flow fields** take a *set* of source cells, so one field serves "any tile next to this
  Town Center" or "this reed tile". Gathering trips are short, so these are solved with a
  cost cutoff (cheap); a unit beyond the cutoff falls back to a full field.
- **Worker state machine:** idle -> to node -> gather -> full (10) -> to nearest drop-off ->
  deposit -> back to the same node, or the nearest node of that type if it ran out. Building:
  to foundation -> build -> next order or idle.
- **New commands:**
  - `GATHER {ids, cell}`
  - `BUILD {ids, building, cx, cy}`: places a foundation, pays up front, and sends builders.
  - `BUILD {ids, target}`: help an existing foundation.
  - `TRAIN {building, slot}` and `CANCEL {building, index}`: pay when queued, refund on cancel.
    Training waits while you're at the pop cap.
  - `RALLY {building, x, y}`: a rally point on a resource means new workers start gathering
    there.
- The **state hash** covers the new stores, player resources, resource amounts and the map
  version.

### View (debug scene, still placeholder art)
- **Buildings:** extruded iso blocks with a team-colour roof. Foundations are outlines that fill
  as they're built.
- **Resources:** reed and bug bush tiles get their own look; hover shows how much is left.
  Workers show what they're carrying.
- **Smart right-click:**
  - Resource -> gather (workers only; other units just move there).
  - Own foundation -> help build.
  - Ground -> move.
  - With a building selected, right-click sets the rally point.
- **Bottom panel:** resources and pop. It also shows the selected building's train queue (Q
  trains a worker) or a worker's build menu (B, H for a House), with a placement ghost that
  turns red where you can't build.

### Tests (`tests/test_sim.gd`)
- **Scripted 3-minute opening** per race:
  - 3 workers, keep the TC training, split food and wood, build houses on time.
  - Check: resources gathered fall within an expected band, nobody idle-stalls or gets stuck,
    pop never goes over the cap, and the Rats' +6 houses and cheaper workers show in the result.
- **Determinism** carries over, with the 10-minute match now including the economy. Add a check
  that cutting a reed bed and placing a building change the map deterministically.
- **Tick time** stays within 3 ms at 200 units with everyone gathering.
- **Archive:** a screenshot at 1, 2 and 3 minutes of the opening.

## Checklist
- [x] Plan approved
- [x] Data: terrain resources, buildings.json, rules economy, race economy modifiers
- [x] Sim: players, resource grid, buildings store, map version + field invalidation
- [x] Multi-source flow fields with cost cutoff
- [x] Worker gather/deposit loop; construction
- [x] TRAIN/CANCEL/RALLY, pop cap
- [x] View: buildings, resources, carry, smart right-click, panel, placement ghost
- [x] Tests: 3-minute opening, determinism, map-change determinism, tick time
- [x] Archive: pictures along the way (first buildings, first gather loop, bugs, the 1/2/3-minute
  opening), journal, decisions, timeline

## Results
- **3-minute opening, frogs vs rats, both played by the economy bot** (the same numbers headless
  and in the view):

  | | Workers | Houses | Pop | Gathered food / wood | Bank |
  |---|---|---|---|---|---|
  | Frogs | 15 | 3 | 15/20 | 520 / 280 | 510 / 250 |
  | Rats | 23 | 4 (6 pop each) | 23/29 | 780 / 360 | 870 / 440 |

  No worker idles for 5 s, nobody goes over the pop cap, nobody is stuck on a job.
- Determinism holds with the economy inside the 10-minute match (400/400 checkpoints, including
  reversed dicts and shuffled commands); the map changes (houses, cut reeds) are part of it.
- **Tick time:** opening avg 0.22 ms (worst 1.5); 210-unit 10-minute match avg 1.54 ms, p99 4.3 ms.
  A near field solves in ~0.4 ms against ~2.3 ms for a full one.
- **UI checked with real input events:** click a building, Q and the Train button queue workers
  (cost charged), the queue's x refunds, H plus a click places a house and the builders go, a
  right-click on a bush sets a worker gathering, and a right-click with the TC selected sets
  the rally point.

## Not done / left for later
- **Balance:** workers are cheap (frogs 25, rats 5 food), so banks pile up; the TC is the
  bottleneck. Revisit with the age-up (milestone 7) and the playtest (10).
- Hunting and drop-off camps (Next).
- The placeholder buildings are plain blocks; the panel is plain. Art pass, and race-themed UI
  (backlog).

## Changes from the original plan
- Train time moved into data: `rules.cost.train_base` (20 s) on a flatter `pow0.5` curve, so a
  worker takes ~11-14 s, a spear ~20 s, a large unit ~27 s. Pricing's old fixed 8 s base gave
  2-3 s workers, which would have flooded the opening.
- Gatherers sent to a busy tile take the quietest tile of the same resource within 2 tiles
  (`Economy.least_busy`). Without it everyone piled onto one bush and gathering halved.
- The economy bot (`src/ai/eco_bot.gd`) arrived early, as a test driver and an autoplay key in
  the debug view. It's the seed of the milestone 8 AI.
- Replays now pin the rules too (`rules` id + content hash), since the economy reads them.
- Added (Dominic): test hotkeys in the debug view to regenerate an army: G rerolls your army,
  Shift+G gives it a random prompt, Ctrl+G does that for the enemy. The match restarts; the
  replay records the prompt and reroll.
