# Milestone 2: Map + movement

**Status:** in progress (started 2026-10-10)
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
- [ ] Flow fields
- [ ] Waypoint steering, group arrival, wall push-out
- [ ] Crossing + chokepoint tests, tick time
- [ ] Isometric view: tiles, projection, y-sort
- [ ] Camera
- [ ] Selection: click, box, double-click
- [ ] Flow-field debug overlay
- [ ] Archive: screenshot, journal, decisions, timeline

## Results
(when done)

## Changes from the original plan
- Maps: JSON + generated TileMapLayer instead of baking a painted TileMapLayer (see above).
- Box select moved from a sim spatial query to a view-side screen-space test.
