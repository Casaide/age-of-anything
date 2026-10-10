# MVP plan: the 10-minute demo

**Goal:** a single-player match vs a scripted AI that proves (1) the parts composer and generated
races, and (2) the classic RTS game loop. Everything sits on a deterministic, integer-only, fixed-tick
sim driven by a command stream, so lockstep networking slots in later without a rewrite.

Technical background and sources: `research.md`. Post-MVP items: `backlog.md`.

> **Change from the original research plan:** the research suggested cutting the text-prompt
> generator from the MVP. We built it first instead (milestone 0, done), so the demo can use
> generated races as well as the handmade Frogs and Rats.

---

## 1. Scope

### In

| System | MVP spec |
|---|---|
| Map | One handmade ~64x64 tile map, 2 players, mirrored starts. Reed forest, bug bushes, one swamp band (frog speed bonus) |
| Resources | **Food** (bug bushes/hunting) and **Wood** (reeds). Gather -> carry -> return to Town Center (or one drop-off building) |
| Buildings | Town Center (trains workers, drop-off, age-up), House (+5 pop; Rats +6), Barracks (spear; also skirmisher + archer for the demo, splitting out an Archery Range is Next), Stable (age 2: trains the `large` unit), Watchtower (age 2: static defence + vision). Full plan in `roster-template.md` |
| Age-up | One step at the TC: "Muck Age -> Stick Age", ~400F/200W, 60 s. Unlocks tier-2 recipes + Watchtower |
| Research | One: "Sharp Sticks" (+1 attack to parts tagged `spear`) at the Barracks, proving tags drive stats |
| Units | Per race: worker + spear + skirmisher + archer (age 1) + large (age 2), all from recipes (handmade or generated) |
| Combat | Melee/ranged attack, armour, HP, counter-tag bonuses, sim-side hitscan + cosmetic projectile, death animation |
| Win | Destroy the enemy Town Center (or surrender) |
| AI | Data-driven build order, worker allocator (60/40 food/wood until age-up), 2 attack waves (~min 5, ~min 8), counter-picks by reading enemy tags. Issues commands through the same queue as the player |
| UX | Click and box select, right-click smart command (move/gather/attack/build), control groups 1-3, resource + pop HUD, unit card showing recipe, derived stats and tags, optional minimap |
| Fog | Per-player visibility grid (unexplored/explored/visible), ~5 Hz, shader overlay; enemy views hidden in fog |
| Race select | Pick Frogs/Rats or type a prompt (bounded by host rules) before the match |
| Debug | Recipe inspector, replay playback, state-hash overlay, Race Lab stays as a tool |

### Rosters (handmade launch races)

| Role | Frogs | Rats | Key tags |
|---|---|---|---|
| Worker | Frog Gatherer (basket) | Rat Scavenger (sack), cheaper, faster train | `worker` |
| Spear (age 1) | Reed Spearfrog | Pike Rat | `spear`, `infantry` -> bonus vs `large` |
| Skirmisher (age 1) | Blowgun Skirmisher (swamp speed) | Sling Rat | `ranged`, `skirmish` -> bonus vs `archer` |
| Archer (age 1) | Reed Bowfrog | Rat Archer (short bow) | `bow`, `archer` -> bonus vs `infantry`, weak vs skirmishers and `mounted` |
| Large (age 2) | Frog Lancer on Beetle | Cheese Brute (giant rat) | `large`/`mounted` -> bonus vs `ranged`, weak to `spear` |

- Rat identity comes from economics, not unique code: ~30% cheaper, ~20% faster training, houses +6 pop.
- Frog identity comes from a terrain modifier: `amphibious` +25% speed on swamp tiles.
- Save these as handmade race files (`data/races/frogs.json`, `rats.json`) in the same format as
  generated races, hand-tuned. They are also the pricing reference set.

### Out (cut list)

A third or fourth resource (gold, stone), markets and trade, walls and gates, farms (bug bushes
are near-infinite instead), more than one age-up, tech trees beyond one research, formations,
naval and air combat, garrisoning, relics, multiple or random maps, diplomacy and teams,
campaigns, tutorials beyond a tips screen, Hyperblobs sharing, networked multiplayer, save/load
(replays cover it), Skeleton2D mesh deformation, 8-direction art (2 facings + mirror), audio
beyond placeholder SFX, runtime AI.

---

## 2. Architecture

```
            +-------------------- CommandQueue --------------------+
 Player UI  |  {turn, player, seq, type, args}; execute at turn+2   |  AI (same API)
            +-------------------------+-----------------------------+
                                      v
 Sim (pure GDScript RefCounted, headless-runnable, integer maths, 20 Hz fixed tick)
   entities in arrays by ascending id; seeded rng.gd; flow fields; combat; economy; fog grid
                                      |  snapshot (prev + current tick)
                                      v
 View (Nodes): UnitView composer, TileMapLayer terrain, fog shader, HUD, selection
   interpolates between ticks; never writes to the sim
```

### Sim rules

- **Units:** positions in milli-tiles (int), HP, orders and cooldowns as ints.
- **Tick:** 20 Hz, accumulated in `_process`, not `_physics_process`, so physics settings can't touch it.
- **Maths:** integers only: `isqrt`, squared-distance comparisons, a sin/cos lookup table.
- **Order:** iterate entities by ascending id, never over Dictionary keys. Resolve commands in
  `(turn, player_id, seq)` order.
- **Banned in the sim:** physics nodes, Area2D, NavigationAgent avoidance, float RNG.
- **Replays:** a replay is the command log plus seed, race keys and map hash.
- **State hash:** computed every 30 ticks over the sorted entity arrays.
- **Pricing:** the floats in `pricing.gd` (`pow`) get replaced with a fixed-point table when the sim
  lands, so costs are bit-exact everywhere.

### Selection and commands

- Box select in screen space against the sim's spatial hash, with no Area2D per unit.
- A right-click "smart command" resolves to `MOVE | GATHER | ATTACK | BUILD | TRAIN | RESEARCH | AGE_UP`.

### Pathfinding

| Option | Use | Notes |
|---|---|---|
| Integer **flow field** on the sim grid (BFS/Dijkstra from target cell, cached per target) | **Sim** | One solve serves a whole group; 64x64 = 4,096 cells is trivial; deterministic |
| Integer separation steering + arrival slowdown | **Sim** | Cheap, readable, deterministic |
| `AStarGrid2D` | Prototypes only | Fast, but float costs, so cross-platform bit-exactness unverified; `jumping_enabled` ignores weights |
| `NavigationServer2D`/`NavigationAgent2D` RVO | **Never in sim** | Float and threaded; heavy with many agents. OK for cosmetic critters |

### Terrain

`TileMapLayer` for visuals only (TileMap is deprecated since 4.3). At load time, bake
walkability, terrain type (swamp) and resource nodes from tile custom data into the sim grid.

### Fog

- The sim keeps a per-player `PackedByteArray` (0 unexplored, 1 explored, 2 visible), stamped from unit
  sight radii as integer circles.
- The view uploads it as `Image` -> `ImageTexture` at ~5 Hz, and a full-screen shader darkens and blurs it.

### Composer (production version)

- The current vector shapes become **Sprite2D parts from one atlas** on Marker2D sockets.
- **One shared palette/team-mask ShaderMaterial:**
  - Part textures are masks: R = shade, G = palette channel id, B = team mask, A = alpha.
  - The shader looks up a palette atlas (one row per palette).
  - Which palette row and which team are passed in `modulate`; in Godot 4, `COLOR` includes modulate.
- **Batching:** all units share one material and one atlas, so they stay in one 2D batch. Verify
  draw calls in week 1 of the art pass.
- **Animation:** walk phase is driven by sim distance travelled, not wall time. Analytic two-bone
  IK (law of cosines) if needed; no experimental Skeleton2D IK.
- **Performance target:** 200 composed units at 60 fps on a mid laptop. Escape hatches, in order:
  1. Throttle off-screen animation.
  2. Bake (recipe hash, facing, frame) to an atlas via SubViewport for far zoom and portraits.
  3. `MultiMeshInstance2D` per layer, with UV rects in instance custom data.

### Data formats

- `data/` is built in, and `user://mods/<id>/` holds user content in the same format.
- Mods are **data-only** (JSON + PNG/SVG). PCK packs can carry scripts (a security risk), so they
  are reserved for our own patches/DLC.
- Validate the schema version on load. Recipe and race hashes are canonical-JSON SHA-256.
- **Civ definition (to add):**
  `{id, name, units: [recipes], buildings, modifiers: [{tag, terrain, speed_pct}], economy: {cost_mult, train_time_mult, house_pop}, ai_profile}`.
- **Map definition (to add):** tile layers, start positions, resource nodes, terrain types.

---

## 3. Milestones (solo)

| # | Weeks | Goal | Exit criterion |
|---|---|---|---|
| 0 | done | **Race generation:** data contract, generator, pricing, composer, Race Lab, tests | Prompts give stable, readable armies; tests pass |
| 1 | 1 | **Sim core:** fixed tick, integer maths, command queue, replay record/playback, state hash, determinism test | The same scripted 10-minute replay gives identical hashes |
| 2 | 1 | **Map + movement:** TileMapLayer map, sim grid bake, flow fields, separation, camera pan/zoom, selection, box select, move | 50 units cross the map in groups with no stuck units |
| 3 | 1 | **Economy:** gather/carry/drop-off, Food/Wood, TC trains workers, Houses/pop, build placement + construction | The opening economy is fun to watch for 3 minutes |
| 4 | 1 | **Combat:** attack/armour/HP, counter tags, projectiles, deaths, unit card | Blind testers predict counters from silhouettes |
| 5 | 1 | **Progression:** Barracks, age-up, Sharp Sticks research, tier-2 units, Watchtower, fixed-point cost table | Age-up lands at minutes 4-6 |
| 6 | 1 | **AI + match flow:** build order, waves, tag-aware counter-picking, race select screen, win/lose | AI beats a passive player and loses to a decent one |
| 7 | 1 | **Fog + juice:** fog, minimap, SFX, hit flash, death poses, tuning | A full match runs 9-12 minutes |
| 8 | 1 | **Playtest + balance:** 5-10 people, balance pass, itch.io build | Success metrics below |
| - | (parallel) | **Art pass:** atlas + palette shader replaces vector shapes; classic 2D isometric RTS look | 200 units at 60 fps; draw calls verified |
| - | +2-3 | **Networking:** see `backlog.md` | Two machines on different NATs finish a match with no desync |

---

## 4. Success metrics

- **Readability:** at least 70% of testers can say what beats a unit from its look. Testers describe
  units with the intended tags ("big", "spear", "fast").
- **Pacing:** median first age-up at 4-6 minutes, matches of 8-12 minutes, and at least 80% of testers
  reach age 2 unprompted.
- **Counters:** in a headless sandbox, equal-cost counter fights are won by the counter at least 75% of
  the time. This also seeds price-by-simulation.
- **Cost sanity:** no unit is more than ±20% off the mean on (win rate vs reference) ÷ cost.
- **Performance:** 200 units at 60 fps or better; sim tick of 3 ms or less at 200 units.
- **Determinism:** 100/100 replays hash-identical across macOS and Linux (and Windows if available).
- **Charm:** testers screenshot or laugh at their armies. Count "funny moments" per session.

---

## 5. Art kit for the MVP (~35 parts + buildings)

| Group | Parts |
|---|---|
| Body plans | Frog biped, rat biped (giant via scale), stag beetle 6-leg mount |
| Heads | ~4 per race (variants) |
| Weapons | Reed spear, lance, blowgun, sling, club, cheese hammer |
| Gear (per race) | Leaf cape, acorn helmet, bottle-cap shield, sack/basket |
| Worker tools | 2 |
| Patterns | Spots, stripes, patches |
| Buildings | 4 per race, as static sprites (TC, House, Barracks, Watchtower) |
| Terrain | Grass, swamp, reeds, bug bushes |

### Constraints

- Fixed 3/4 view with 2 facings, mirrored.
- Thick dark outlines baked in.
- 3 shades per channel.
- Silhouette first.
- Team colour on cape, banner or shield.
- Pivots and outline weight consistent across all parts.

### Tools

- **Vector parts:** Inkscape or Affinity. ThorVG supports only a subset of SVG: no filters, and text
  must be converted to paths.
- **Raster touch-ups and mask channels:** Krita or Aseprite.
- **Atlas:** a small script packs the PNGs and writes the rects and pivots into `parts.json`.
- **No Spine or DragonBones:** all animation is procedural.

Dev-time AI is fine for variants. Every part still gets hand-cleaned to the mask spec.

---

## 6. Risks to retire early

| Risk | Retire by |
|---|---|
| GDScript sim too slow at 200 units | Profile in milestone 1-2 with a stress replay; move hot loops to packed arrays |
| Desyncs from hidden float/dict-order use | Determinism test from milestone 1, run on every change; cross-OS check before networking |
| Palette-in-modulate batching trick doesn't batch | Check draw-call monitor in the first art-pass week; fall back to per-race materials or MultiMesh |
| Flow fields + separation jam in chokepoints | Test chokepoint map in milestone 2 |
| Generated races unbalanced | Counter tags + cost curve now; price-by-simulation right after MVP |
| Generated units unreadable | Readability playtests; silhouette rules in the art pass |
