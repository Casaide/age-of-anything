# MVP plan: the 10-minute demo

**Goal:** a single-player match vs a scripted AI that proves (1) the parts composer and generated
races, and (2) the classic RTS game loop. Everything sits on a deterministic, integer-only, fixed-tick
sim driven by a command stream, so lockstep networking slots in later without a rewrite.

Technical background and sources: `research.md`. Post-MVP items: the `backlog` issues.

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
- **Pricing:** cost and train-time curves are fixed-point tables (`data/cost_curves.json`), so costs
  are bit-exact everywhere. Done in milestone 1.

### Selection and commands

- Box select in screen space against the units' drawn positions (view-side), with no Area2D per unit.
- A right-click "smart command" resolves to `MOVE | GATHER | ATTACK | BUILD | TRAIN | RESEARCH | AGE_UP`.

### Pathfinding

| Option | Use | Notes |
|---|---|---|
| Integer **flow field** on the sim grid (BFS/Dijkstra from target cell, cached per target) | **Sim** | One solve serves a whole group; 64x64 = 4,096 cells is trivial; deterministic |
| Integer separation steering + arrival slowdown | **Sim** | Cheap, readable, deterministic |
| `AStarGrid2D` | Prototypes only | Fast, but float costs, so cross-platform bit-exactness unverified; `jumping_enabled` ignores weights |
| `NavigationServer2D`/`NavigationAgent2D` RVO | **Never in sim** | Float and threaded; heavy with many agents. OK for cosmetic critters |

### Terrain

Maps are JSON (`data/maps/`, terrain types in `data/terrain.json`); the sim reads them directly
and the view generates an isometric `TileMapLayer` from the same file (decided in milestone 2,
replacing the earlier "bake from tile custom data" plan).

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

Each milestone has its own file in `milestones/` (plan, checklist, results); this table is the overview.

| # | Weeks | Goal | Exit criterion |
|---|---|---|---|
| [0](milestones/m0-race-generation.md) | done | **Race generation:** data contract, generator, pricing, composer, Race Lab, tests | Prompts give stable, readable armies; tests pass |
| [1](milestones/m1-sim-core.md) | done | **Sim core:** fixed tick, integer maths, command queue, replay record/playback, state hash, determinism test | The same scripted 10-minute replay gives identical hashes (met: 400/400 checkpoints; 200-unit tick 0.9 ms avg) |
| [2](milestones/m2-map-movement.md) | done | **Map + movement:** JSON map + generated isometric TileMapLayer, flow fields, separation, camera pan/zoom, selection, box select, move | 50 units cross the map in groups with no stuck units (met: open map and chokepoint) |
| [3](milestones/m3-economy.md) | done | **Economy:** gather/carry/drop-off, Food/Wood, TC trains workers, Houses/pop, build placement + construction | The opening economy is fun to watch for 3 minutes |
| [4](milestones/m4-combat.md) | done | **Combat:** attack/armour/HP, counter tags, projectiles, deaths, unit card | Blind testers predict counters from silhouettes |
| [5](milestones/m5-art-rework.md) | closed | **Art rework:** realistic props and terrain, prop variety, resource and build stages, gear for armless creatures, UI pass (queue, generated icons, cursors), animation pass, the old art gone from every scene | Dominic signs off the look in the game view and the Race Lab |
| [6](milestones/m6-foundations.md) | done | **Foundations:** resources from data (stone from rock outcrops), movement classes (ground, amphibious, flying), placement rules per race and building, teams, data-driven ages and tech, per-race farms | Stone is mined, flyers cross water, frogs farm the swamp, all from data; the tests prove it |
| [7](milestones/m7-progression.md) | done | **Progression:** Barracks, age-up, Sharp Sticks research, tier-2 units, Watchtower, fixed-point cost table | Age-up lands at minutes 4-6 |
| [8](milestones/m8-ai-match-flow.md) | closed | **AI + match flow:** build order, waves, tag-aware counter-picking, race select screen, win/lose | AI beats a passive player and loses to a decent one |
| [9](milestones/m9-fog-juice.md) | done | **Fog + juice:** fog, minimap, SFX, hit flash, death poses, tuning | A full match runs 9-12 minutes |
| [10](milestones/m10-playtest-balance.md) | closed | **Playtest + balance:** 5-10 people, balance pass, itch.io build | Success metrics below |
| [11](milestones/m11-cleanup.md) | done | **Cleanup:** UI, UX, SFX and art polish from playing; a real lobby; more buildings | Deep review of UI, UX and art |
| [12](milestones/m12-tech-tree.md) | closed for now | **The full land tech tree:** three ages, walls, gates, towers, castle, research as data, the tech tree page | The page shows the whole land tree; every building stands |
| [13](milestones/m13-unit-lines.md) | closed | **Unit lines:** swordsman, scout, mounted archer, siege engines, unique units, sapper, great sling, healers, trade carts, war beasts; costs by material | Every line trains, fights by its counters, the AI uses it; no line 20% off at equal cost |
| [14](milestones/m14-race-identity.md) | closed | **Race identity and heroes:** bonuses, own research, lacks, abilities, heroes | Every creature and culture plays differently, balanced |
| [15](milestones/m15-maps.md) | closed for now | **Maps and land:** big maps, high ground, bridges, fords | New maps play well with the bots |
| [16](milestones/m16-sieges.md) | closed | **Sieges:** walkable walls, gatehouses, rams, ladders, siege towers, Fortress and Siege modes | A full siege plays out |
| [17](milestones/m17-living-towns.md) | done | **Living towns:** idle chores, damage states, piles | "Living town is good" |
| [18](milestones/m18-match-rules.md) | planned | **Match rules:** a rules contract, lobby card, post-game stats | |
| [19](milestones/m19-ui.md) | closed | **UI that feels like the game:** theme, loaders, lobby, HUD, tech tree, portraits | Every screen looks designed |
| [20](milestones/m20-steam-deck.md) | in progress | **Steam Deck and controllers:** pad controls, Deck builds, handheld UI, performance | A full match on the Deck with a pad |
| [21](milestones/m21-modability.md) | closed | **Modability:** a mod loader, an example mod, agent tooling | A mod installed on a second machine plays the same race |
| [22](milestones/m22-battle-feel.md) | planned | **Battle feel:** formations by role, counter-aware targeting, attack lines, a Norse shield wall | Groups line up by role; counters seek their prey; fights read |
| [-](milestones/save-load.md) | built | **Save and load:** snapshots that survive updates | Tried on the Deck |
| [-](milestones/art-pass.md) | (parallel) | **Art pass:** atlas + palette shader replaces vector shapes; classic 2D isometric RTS look | 200 units at 60 fps; draw calls verified |
| [-](milestones/art-ui-track.md) | (parallel) | **Art and UI track:** stage A1 is milestone 5; A2-A5 run alongside milestones 7-10 (props, UI, icons, cursors, animation, new buildings, menus, juice) | Each stage done before its milestone closes |
| [-](milestones/networking.md) | in progress | **Networking:** lockstep over ENet on the LAN (phase 1), then a HyperDHT sidecar | Two machines on different NATs finish a match with no desync |

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
| Palette-in-modulate batching trick doesn't batch | **Retired (2026-10-11):** team colour in self_modulate + one atlas + one material batches; 20 draw calls at 211 units |
| Flow fields + separation jam in chokepoints | Test chokepoint map in milestone 2 |
| Generated races unbalanced | Counter tags + cost curve now; price-by-simulation right after MVP |
| Generated units unreadable | Readability playtests; silhouette rules in the art pass |
