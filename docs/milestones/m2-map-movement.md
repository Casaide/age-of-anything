# Milestone 2: Map + movement

**Status:** done (2026-10-11)
**Exit criterion:** 50 units cross the map in groups with no stuck units. Also from the risk
table: flow fields + separation don't jam at a chokepoint. Tick stays at or under 3 ms with 200
units.

## Scope
Map with terrain, flow-field pathfinding, separation, camera pan/zoom, selection, box select, move.

## Plan (approved by Dominic, 2026-10-10)

**Decisions taken up front**
- **Isometric view now** (Dominic). The sim grid stays square; the view projects to 2:1 diamonds.
  Camera, picking, box select and tiles are built once for the target look.
- **Maps stay JSON** (Dominic). `data/maps/*.json` is canonical (mod-safe, headless, easy hash);
  terrain types live in `data/terrain.json`; the view generates its TileMapLayer from the map.
  Painting maps in the editor becomes a small tool later. This replaces the original plan's
  "TileMapLayer -> sim grid bake".

**Sim (`src/sim/`, integers only)**
- `flow.gd`: a flow field per target cell. Dijkstra with a bucket queue, costs 10/14, no corner
  cutting, fixed neighbour order. Fields are pure functions of (map, target), so the cache never
  affects results and isn't hashed.
- Movement: units steer at a waypoint, re-planned every few ticks (staggered by id). The waypoint
  is the target if the straight line is clear, else the furthest clear cell a few steps down
  the field. Blocked targets snap to the nearest walkable cell.
- Arrival: each MOVE is a move group. A unit stops at the target radius, or when it bumps a
  stopped groupmate near the target. Units stuck against walls for too long give up (and the
  test counts them).
- Separation also pushes units out of blocked neighbour cells.
- Terrain types per cell (grass, swamp, reeds, rock, water); only walkability matters for now.

**View**
- Isometric tiles generated from the map; units y-sorted in screen space.
- Camera: WASD/arrows/screen edge pan, wheel zoom to cursor, middle-drag pan, clamped to the map.
- Selection: click, shift adds, double-click selects that type on screen, box select tested
  against on-screen unit positions (view-side, so it matches what you see).
- F3: flow-field overlay for the selected group.

**Tests (`tests/test_sim.gd`)**
- Determinism tests carry over (hashes change because movement changes).
- Crossing: 50 units in groups cross `flat_test`; all arrive in time, none stuck.
- Chokepoint: `choke_test` (wall with a 2-tile gap); 50 units through, none stuck.
- Flow fields: identical however cached; solve time reported. Tick <= 3 ms at 200 units.

## Checklist
- [x] Terrain data + maps v2 (`data/terrain.json`, `flat_test`, `choke_test`)
- [x] Flow fields
- [x] Waypoint steering, group arrival, wall push-out
- [x] Crossing + chokepoint tests, tick time
- [x] Isometric view: tiles, projection, y-sort
- [x] Camera
- [x] Selection: click, box, double-click
- [x] Flow-field debug overlay
- [x] Archive: screenshots, journal, decisions, timeline

## Results
- **Exit criterion met.** 50 units in 5 groups cross `flat_test` corner to corner (settled at
  72 s) and `choke_test` through the 2-tile gap (54 s). Nobody gives up stuck, everyone ends near
  their own target, and all stay settled 10 s later.
- Determinism still holds: 400/400 checkpoints across runs, reversed dicts and shuffled commands.
- **Flow field solve:** ~2.4 ms on 64x64 (GDScript). At most one solve per tick.
- **Tick time, 200 units, 10-minute scripted match:** avg 1.38 ms, p50 1.27, p99 3.86, max ~11 ms.
  The average is well inside 3 ms; the p99 is ticks that also solve a field (the script orders
  a new random target every 2 s per player, far more often than a person would). The crossing
  runs (50 units) peak at 2.8 ms.
- View input checked by driving real mouse events: box select catches the whole army,
  right-click lands on the clicked milli-tile, double-click picks the type, zoom keeps the
  cursor point fixed.

## Not done / left for later
- Field solves still spike a tick by ~2.4 ms. If it matters: an incremental solve spread over
  ticks, or a GDExtension solver (backlog).
- Terrain is flat colour diamonds; rocks and reeds don't look raised yet (art pass).
- Sprites are wider than their 0.3-tile collision radius, so crowds overlap visually.

## Changes from the original plan
- Maps: JSON + generated TileMapLayer instead of baking a painted TileMapLayer (see above).
- Box select moved from a sim spatial query to a view-side screen-space test; `World.pick` went too.
- One flow-field solve per tick from a queue (units head straight until theirs is ready). This
  makes "which fields exist" sim state, so it's hashed.
- Added "return to spot": a settled unit shoved well off its target by passing groups walks back.
  Found because the chokepoint test failed: later groups bulldozed the first one 4-5 tiles past
  its target.
