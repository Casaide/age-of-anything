# Age of Anything

A classic-style 2D RTS where your civ is whatever you can describe. Type "centaur romans" or
"sewer rats with cheese hammers" and the game builds a race from a parts kit, prices every unit fairly,
and you play a normal classic RTS match with it. Silly is fine; broken is not. Cost is the balancer.

Godot 4.7 (GDScript), 2D. Solo dev, macOS.

| Doc | Read it for |
|---|---|
| `docs/design.md` | What the game is and why: races, generation, modes, balance, multiplayer, art |
| `docs/mvp-plan.md` | The 10-minute demo: scope, cut list, architecture, milestone overview, metrics, risks |
| `docs/milestones/` | One file per milestone: plan, checklist, results, changes. Status lives here |
| `docs/research.md` | Technical reference and sources (lockstep, Godot 2D, pathing, Holepunch bridge) |
| `docs/backlog.md` | Everything postponed, in rough priority order |
| `docs/roster-template.md` | Full building, age and unit-line plan, with MVP/Next/Later status |
| `docs/rendering.md` | How the art is made: models (code and Blender), 8-facing bakes, worn armour, buildings, checking tools |
| `docs/audio.md` | How the sound is made: the offline synth (`tools/audio/`), effects, creature voices, the theme in stems by age |

Before starting a milestone, read `docs/milestones/<its file>.md` (and the related parts of
`docs/mvp-plan.md`), write the plan into the milestone file, and keep its checklist current. If you postpone something,
move it to `docs/backlog.md` rather than deleting it.

## Status

- **Done (milestone 0): race generation.** Prompt -> race -> composed, animated units in the Race Lab
  (`scenes/race_lab.tscn`). The 2D shapes in `data/parts.json` are the data contract
  and socket reference; game scenes draw only the baked pixel art.
- **Done (milestone 1): sim core.** `src/sim/`: integer-only 20 Hz sim driven by a command queue,
  replays, state hashes, straight-line MOVE + separation. Debug view `scenes/sim_debug.tscn`.
  `tests/test_sim.gd` plays a 10-minute 200-unit match; tick is ~0.9 ms avg (budget 3 ms).
- **Done (milestone 2): map + movement.** Flow fields, move groups, isometric debug view, RTS
  camera, click/box/double-click selection. 50 units cross open and chokepoint maps, none stuck.
- **Done (milestone 3): economy.** Food from bug bushes, wood from reeds (cut reeds become
  ground), Town Center + Houses, training, construction, pop cap, rat economy from data, an
  economy bot (`src/ai/eco_bot.gd`), the command panel. Dominic watched an opening: "all looks
  good". See `docs/milestones/m3-economy.md`.
- **Done (milestone 4): combat.** Armour classes, attack-move that spreads into duels,
  projectiles, deaths, hit flash, the unit card, the two-part counter quiz
  (`scenes/counter_quiz.tscn`); Dominic called the stats fine. See `docs/milestones/m4-combat.md`.
- **Closed (milestone 5): art rework.** Realistic props and buildings in six architectures (reed
  for frogs and mound for bugs come from the creature), textured units, posed gear, portraits and
  cursors. Closed 2026-10-17. See `docs/milestones/m5-art-rework.md`.
- **Done (milestone 6): foundations**: resources from data (stone), movement classes (ground,
  amphibious, flying), placement rules, teams, farms, shift-queued orders, unit lines through the
  ages, ages and research as data (`data/tech.json`, `src/sim/tech.gd`). See `docs/milestones/m6-foundations.md`.
- **Done (milestone 7): progression**: Barracks, Stable, Watchtower per culture, age gates,
  age-ups needing a building, the bot ageing up at 4-6 minutes.
- **Closed (milestone 8): AI and match flow.** `src/ai/bot.gd` (data in `data/ai.json`): build
  order, counter-picked soldiers, defence, attack waves; `src/sim/match.gd`: defeat, surrender,
  winner. The match setup screen (`scenes/match_setup.tscn`) is the main scene. Dominic closed it
  "for now"; his playtest moved to the backlog.
- **Art direction under research:** unit art goes concept-first; the proposal is in `docs/concepts/direction.md`. Nothing new
  gets built for units until Dominic approves a direction.
- **Done (milestone 9): fog and juice.** Fog of war (`src/sim/fog.gd`, `src/view/fog_view.gd`),
  minimap, synthesised placeholder sounds. Bot matches ran ~11 minutes; ~14 since workers' costs
  vary again (D-078). Pacing is a tester metric (D-077).
- **Closed (milestone 10): playtest and balance.** `tests/balance.gd` (equal-cost round robin),
  balance pass 1, `docs/playtest.md`, a match log. Testers, the export build, the Linux check and
  price-by-simulation moved to the backlog.
- **Built (audio, 2026-10-11): sound from the ground up.** Our own offline synth (`tools/audio/`, Python) renders
  every effect, creature voice and the theme's stems into `assets/audio/`; `src/view/audio.gd` plays them on
  buses, with takes, creature voices on select/ack/die, and the theme growing by age plus a battle layer.
  Nobody has listened yet: Dominic to listen. See `docs/audio.md`.
- **Done (milestone 11): cleanup.** UI, UX and art polish from Dominic's list, the lobby (`scenes/match_setup.tscn`),
  animals, gold and new buildings, 8 facings, Blender-modelled humans, reared spiders, the Nile/Han/Aztec kits; the
  Fable review met the exit criterion. See `docs/milestones/m11-cleanup.md`.
- **Closed for now (milestones 12 and 15): the land tech tree and maps.** Three ages, walls, gates, towers, castle,
  research as data, the tech tree page; big maps, high ground, bridges, fords (Dominic, 2026-10-13).
- **Done (milestone 17): living towns** ("living town is good"). **Closed (milestone 19, UI):** the timber look
  approved, loaders built (the bake keeps them moving: `src/view/art/bake/bake_clock.gd`, D-143), unit portraits are
  busts with a role glyph and a line upgrade shows the unit it gives (D-145).
- **In progress (milestone 20): Steam Deck and controllers.** The pad controls are built (D-132): `src/view/pad_mode.gd`
  (last input wins, menu focus), `pad_play.gd` (reticle, selection circle, orders), `pad_wheel.gd` (tap A on what you command: the
  panel's buttons on a ring; D-133). Deck builds played; Dominic's Deck fixes going in (white boxes, the bake freeze,
  a quit crash, the wheel's pages); next: steps 7-9 (fit, speed, Steam Input). See `docs/milestones/m20-steam-deck.md`.
- **Built (save and load, D-140 to D-142):** `src/save_game.gd` (a snapshot of the World and bots; saves from older builds
  load too, on the new stats while the data tables line up), Save/Load in the pause menu and lobby (`src/view/ui/saves_page.gd`). See `docs/milestones/save-load.md`.
- **Closed (milestone 13): unit lines.** Crewed engines per family (D-116 to D-119); shots fly and can miss
  (`src/sim/shots.gd`); healers, trade carts, the great sling, war beasts with jointed legs; a unit's parts set its cost
  and its line what it's paid in (D-150). See `docs/milestones/m13-unit-lines.md`.
- **Closed (milestone 14): race identity and heroes.** Bonuses, own research, lacks (`src/identity.gd`), the web
  ability, heroes (one a race, named in the prompt or picked by its key, D-159). See `docs/milestones/m14-race-identity.md`.
- **Closed (milestone 16): sieges.** Walkable walls, gatehouses, rams, ladders, siege towers, Fortress and Siege
  modes, tall walls (D-130). See `docs/milestones/m16-sieges.md`.
- **Closed (milestone 21): modability.** The mod loader, an example mod, agent tooling (`docs/modding.md`).
- **Milestones 5, 13, 14, 16, 19 and 21 closed 2026-10-17** (Dominic: what waited on his checks closes, the rest
  moves forward): what's left is in `docs/backlog.md` §0b.
- **In progress (networking): multiplayer.** Phase 1 built: lockstep over ENet on the home network (`src/net/`), Play
  on the network in the lobby (Host, Join by LAN beacon), D-147; next the Mac vs Deck match, then a HyperDHT
  sidecar. See `docs/milestones/networking.md`.
- **Built (bears, 2026-10-17):** brown, black ("moonbears") and polar bear races from the creature
  kit (kit bodies completed by DataLib from `data/creature_kit.json`), the bear mount for others ("romans riding bears"),
  a bear voice; every piece of gear checked on every bear (D-161 to D-163). Dominic to look and listen. See `docs/concepts/bears/`.
- **In progress (milestone 22): battle feel.** Built (D-155): formations by role (riders on the flanks), counter-aware
  targeting (`counter_pull`), attack lines for the selection, the Norse shield wall; next race_matches and Dominic's
  match. See `docs/milestones/m22-battle-feel.md`.

## Layout

```
archive/         development history: journal, decisions, timeline, screenshots
data/            the data contract; mods are just more of this
  parts.json       every part: slot, shapes, sockets, stats, tags, points, era, cost_mix
  creatures.json   creature -> body + head + skins + favoured families (+ fused_mount for centaurs)
  families.json    cultures/styles: cloth colours, mounts, name parts
  palettes.json    skin palettes, fixed material colours, team colours
  lexicon.json     word -> creature/mount/family/tags/size; out-of-era words + playful notes
  rules/*.json     host rules: era bounds, point budgets, roster template, cost/train curves, economy
  cost_curves.json fixed-point cost curves (per-mille by points), written by tests/gen_cost_curve.gd
  creature_kit.json creature-kit skeletons (scenes/art_pixel/creature_kit.gd: the bears); data/later/ holds staged, unplayed data
  terrain.json     terrain types: walkable, colours, resource + amount + what it turns into when used up
  audio.json       buses, every sound's takes / bus / gap / voices, the music mixes by age
  ui.json          the UI's directions (materials, colours, crest, banner cut) and which one is in use
  buildings.json   building types: footprint, hp, cost, build time, pop, drop-off, what it trains
  maps/*.json      maps: ASCII rows + legend into terrain.json, start tiles; the view builds tiles from them
src/
  rng.gd           xorshift32 + FNV-1a. The only randomness allowed in generation/sim
  data_lib.gd      loads data/, era filtering, stable candidate lists
  race_generator.gd  prompt -> brief -> race (recipes) ; race_key()
  pricing.gd       recipe -> stats, tags, cost, train time, pop
  identity.gd      a race's bonuses, own research, lacks and ability, from group + creature + culture (m14)
  unit_view.gd     composer + procedural animation (recipe -> Node2D on sockets)
  part_shape.gd    draws one part's baked sprite from the atlas (a missing bake shows magenta)
  team_mask.gdshader  recolours the baked team key per unit (team colour arrives in self_modulate)
  sim_clock.gd     the only Node in the sim path: steps a World at 20 Hz from _process
  sim/             the simulation: RefCounted, integers only, no Nodes (lint-checked by test_sim)
    fixed.gd         isqrt, sin/cos table, hash mixing
    world.gd         tick loop: commands -> move -> separate -> hash every 30 ticks
    units.gd         units as parallel packed int arrays, sorted by id
    spatial.gd       per-tile buckets for neighbour queries
    commands.gd      CommandQueue {turn, player, seq, type, args}; 4-tick turns, run at turn + 2
    sim_map.gd       terrain, walkable grid, resources left, building occupancy (the map changes)
    flow.gd          flow fields (multi-source integer Dijkstra, optional cutoff), line of sight
    buildings.gd     buildings as parallel arrays sorted by id (ids shared with units)
    economy.gd       setup, worker jobs (gather/carry/drop off/build), training, pop, economy commands
    abilities.gd     race abilities (a kind + data: the spiders' web), the ABILITY command, slowing
  ai/              players that issue commands like a person (deterministic, lint-checked)
    eco_bot.gd       plays an opening: trains workers, 60/40 food/wood, houses, idle workers
    replay.gd        record / JSON / rebuild / verify
scenes/race_lab.*  prompt UI, race cards, two armies milling about in the baked art (bakes per generate)
  view/            view side (Nodes allowed): iso.gd projection, rts_camera.gd, command_panel.gd,
                   audio.gd (the one audio node: effects, creature voices, the theme's stems)
    ui/              the UI's look: theme.gd (every screen's Theme, type, button weight; looks from data/ui.json
                     + each culture's `ui` block), painted materials, lit frames, cloth banners
    art/             the pixel-art views: art_kit.gd (bakes units, buildings, props into one atlas),
                     terrain_view.gd (shader ground + paths + doodads from a SimMap), building_art.gd
      bake/            the 3D bake pipeline for buildings and props: baker.gd, models.gd, materials.gd
scenes/art_pixel.* + art_pixel/          the pixel-art candidate: baked parts, palette, shader terrain,
                   unit_models.gd (hand-built parts), part_baker.gd, paths.gd (culture paths), pixelize.gd
assets/art/textures/  texture art authored by Claude (SVG), mapped onto unit models
assets/audio/    every sound and music stem, rendered by tools/audio/render.py (see docs/audio.md)
scenes/sim_debug.* the playable debug match: select, smart right-click, panel (Q/H/C), Tab side, F6 autoplay,
                   F3 flow, F5/F9 replays, G regen army
mods/            mods (milestone 21, docs/modding.md): folders of more data/ + models; scifi_test is the example.
                 Loaded only when asked (AOW_MODS=id). mods_private/ is gitignored: fan pieces, never committed
src/mods.gd      finds, checks and merges mods (load order); DataLib.load_rules(id) gives rules with mods
tools/mods/      new_mod.py (scaffold a mod), pack.py (zip it)
tests/           headless checks and dev tools (see Commands)
tools/blender/   bpy scripts that model parts (blender -b --python ...); output .glb in assets/models/
tools/ui/        crests.py: writes the culture crests (assets/art/ui/crest_*.svg)
tools/audio/     the sound synth (pure Python): synth, instruments, sfx and voice recipes, the theme; render.py
```

## Commands

Godot on this Mac: `/Applications/Godot.app/Contents/MacOS/Godot` (alias it as `godot`).

```sh
tests/batch.sh                                                     # the whole batch side by side, a table, exit 1 on a failure (~3 min)
tests/batch.sh --quick                                             # the fast subset: run_tests, test_sim, test_ai quick, placement 3d (~1 min)
godot --headless --path . --script res://tests/run_tests.gd        # must print "0 failed" (~5 s; "-- placement" adds the 3D placement check)
godot --headless --path . --script res://tests/print_races.gd -- "centaur romans" "flying greeks with wings"
godot --path . --script res://tests/screenshot.gd -- /tmp/lab.png "prompt A" "prompt B"
godot --headless --path . --script res://tests/test_sim.gd         # sim determinism + tick time, its parts side by side (~1 min; "-- serial" in one process)
godot --headless --path . --script res://tests/test_ai.gd -- [map] [quick|slow|piece:<name>|walls|...]   # the AI: scenario checks (quick, ~30 s) and whole bot matches (slow), side by side
godot --headless --path . --script res://tests/test_2v2.gd         # four bots, one 2v2 match (~2.5 min: one process, the batch's longest piece)
godot --headless --path . --script res://tests/balance.gd -- 2     # equal-cost round robin in age 2: win rates, outliers
godot --headless --path . --script res://tests/test_race_identity.gd   # race bonuses, own research, lacks, the web ability in the sim
godot --headless --path . --script res://tests/race_matches.gd -- reed_meadow   # bot-vs-bot round robin of races: win rates (~10 min) (fights side by side)
godot --headless --path . --script res://tests/mass_battle.gd -- 2 # 30 v 30 mixed armies at equal cost (each match side by side)
godot --headless --path . --script res://tests/resource_audit.gd -- reed_meadow   # resources per start, 40-minute bot economies (~3 min)
python3 tools/maps/reed_meadow.py                                  # rebuild the Reed Meadow maps (64 and 88) from one layout
godot --headless --path . --script res://tests/path_audit.gd -- 8  # pathing diagnostic: give-ups, snaps, jitter, treading, with examples
godot --path . res://scenes/match_setup.tscn                       # pick races and play vs the AI (the main scene)
godot --path . --script res://tests/sim_screenshot.gd -- /tmp/sim.png [map_id] [armies|opening:<tick>] ["prompt A" "prompt B"]
godot --headless --path . --script res://tests/net_check.gd -- [loop|enet] [ticks]   # lockstep: two worlds over a loopback, two processes over ENet; same hashes
godot --path . --audio-driver Dummy --always-on-top --script res://tests/net_game_check.gd -- /tmp/net [ticks]   # a network match in two game windows through the lobby page
godot --path . --audio-driver Dummy --always-on-top --script res://tests/pad_check.gd -- /tmp/pad   # a match played by a fake pad: 25 checks + pictures (exit 1 on a failure)
godot --path . --audio-driver Dummy --always-on-top --script res://tests/save_check.gd -- /tmp/save   # save and load through the menus, mouse, pad and lobby (exit 1 on a failure)
godot --path . res://scenes/sim_debug.tscn                         # run the sim debug view
godot --path . res://scenes/counter_quiz.tscn                      # blind counter quiz (milestone 4 exit check)
godot --headless --path . --script res://tests/gen_cost_curve.gd   # regenerate data/cost_curves.json
godot --path . res://scenes/art_pixel.tscn                         # pixel-art candidate (Z zoom, P palette)
godot --path . --script res://tests/art_screenshot.gd -- /tmp/art  # capture it at 1x/2x/3x
godot --path . --script res://tests/art_crop.gd -- /tmp/c.png 6.5 9 ["prompt A" "prompt B"]   # 3x close-up at a tile
godot --path . --script res://tests/wall_join_check.gd -- [filter]   # walls: composed sprites vs one 3D bake per join fixture (exit 1 on overlaps, gaps, sunk units)
godot --path . --script res://tests/art_bench.gd                    # draw calls + frame time, 200+ units
godot --path . --script res://tests/unit_lineup.gd -- /tmp/units.png ["prompt A" "prompt B"]   # both rosters as pixel art, 4x
godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/bears_b1.json /tmp/out [sheet,...] [zoom,...]   # any concept or lineup sheet from a spec, placement PASS/FAIL per row
godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_check.gd -- [filter] [3d|2d]   # placement + layering on every unit, pose, facing, and the bug fixtures (~2 min); must pass before a unit change is shown
godot --headless --path . --script res://tests/geometry_check.gd -- [filter]   # its 3D half alone, headless (~35 s; also run_tests -- placement)
godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_shot.gd -- /tmp/p.png 5 "frog on newt_fire"   # a placement case in 8 facings
godot --path . --script res://tests/healer_lineup.gd -- /tmp/healers.png [zoom] [family,...]   # every culture's healer in 8 facings
godot --path . --script res://tests/siege_lineup.gd -- /tmp/siege.png [zoom] ["prompt" ...]     # each race's crewed siege engines, four facings
godot --headless --path . --script res://tests/siege_bench.gd -- 200 3   # the siege tick budget: a walled town stormed, 400 units, per-system times (m16)
godot --path . --audio-driver Dummy --always-on-top --script res://tests/siege_tower_sheet.gd -- /tmp/out 3   # siege tower concepts (T1)
python3 tools/maps/siege_vale.py                                   # rebuild Siege Vale, the siege showcase map
python3 tools/audio/render.py [sfx|voices|music|<name>...]       # re-render the sounds into assets/audio (~15 s)
python3 tools/audio/check.py assets/audio/sfx/chop_*.wav          # length, peak, RMS, pitch guess; afplay to listen
godot --headless --path . --script res://tests/mod_check.gd -- scifi_test   # load a mod (or say why not) + 3D placement on its units
python3 tools/mods/new_mod.py <id> [--era <tag>] [--private]       # scaffold a mod (docs/modding.md); tools/mods/pack.py <id> zips it
godot --path .                                                     # run the game (match setup; Race Lab from there)
```

A GDScript parse error in a `--script` run leaves Godot hanging instead of exiting; put a
timeout on headless runs.

Windowed test and capture runs (screenshots, sheets, benches) play the game's sound: add
`--audio-driver Dummy` so they're silent (Dominic), and `--always-on-top` so a covered window
doesn't crawl.

**Testing rhythm** (Dominic: iteration must stay fast). While working, the quick checks: `run_tests`
after every change to `data/` or `src/`, the piece you're touching (`test_ai.gd -- piece:<name>`,
`test_sim.gd -- part:<name>`, `placement_check.gd -- <filter>`), or `tests/batch.sh --quick`.
After a set of changes, the whole batch once, in the background (`tests/batch.sh`), not the slow
suites over and over. The test scripts run their independent pieces in parallel Godot processes
(`tests/par.gd`; `jobs=N` or `AOA_JOBS` to change how many, performance cores - 1 by default);
each piece is its own seeded sim, so results match a serial run. Logs: the path the batch prints.
The tick-time check in test_sim measures wall time: on a machine busy with other runs it can fail.
Look at a screenshot after visual changes. After a change to `tools/audio/`,
re-render and commit the files in `assets/audio/` with it (the game plays files, not recipes).

## Rules that matter

**Determinism is the backbone** (lockstep multiplayer and shareable races depend on it):
- Same prompt + rules + reroll must give the same race key on every machine. Tests enforce this.
- Never use `randi()`/`randf()`/`RandomNumberGenerator` in generation or the sim. Use `src/rng.gd`.
  The only exception is cosmetic animation in `unit_view.gd`.
- Iterate anything that affects output in a stable order (sorted ids or arrays), never raw
  Dictionary order from untrusted sources.
- Recipes hold only strings and ints. The race key hashes names + recipes, not derived stats.
- Saves outlive builds (D-141): a new sim or AI variable must make sense in a match loaded from an older save. Per-unit
  arrays are padded with 0; anything else whose fresh value is wrong mid-match gets an `after_load(missing)` (see
  `docs/milestones/save-load.md`).
- The coming sim: integer/fixed-point maths, fixed 20 Hz tick, driven only by a command stream,
  no physics nodes or NavigationAgent avoidance inside it. The AI issues commands like a player.
  Views read sim state; the sim never touches Nodes.

**Data first.** New creatures, gear, cultures and words go in `data/`, not code. If you need code
for a content case, the data contract is probably missing a field; add the field.

**Balance through cost.** Every part has `points`; unit cost grows superlinearly
(`rules.cost.curve`, a fixed-point table in `data/cost_curves.json`). Counter tags (spear > large/mounted > ranged > infantry) make even absurd
units beatable. Don't special-case silly units.

**Generator behaviour to keep:**
- Unknown words are ignored with a note; missing creature -> a random one "volunteers".
- Out-of-era asks get a substitute plus a funny note (WW2 -> saucepan helmets). Bad
  interpretations are part of the fun; keep notes honest and playful.
- Signature gear (roman, greek, viking, cheese) is only favoured when asked for (or by the race's
  family/creature, e.g. rats like cheese). Wings only appear when asked. A winged race doesn't ride unless asked to
  (then rider and mount both have wings); "pegasus" gives only the mount wings.
- Roster: worker, spear, skirmisher (non-bow ranged, beats archers), archer (bows), large.
- Large units: a mount if available; giants only for creatures where that reads well
  (`giant_ok`); otherwise "Heavy" armoured elites. Centaurs are already mounted, so they go Heavy.
- Cultural knowledge ("romans" -> legionaries) is the generator's known gap. The plan is culture
  templates, then an LLM brief expander, both post-MVP (see backlog). Don't hack it into code.

## Art direction

Target the look of a **classic 2D isometric RTS**: small units, 3/4 view, painterly sprites, readable
silhouettes, team colour on a consistent region. It should feel like the game you know, gone mad.
Units are 3D parts (built in code, or scripted in Blender: `tools/blender/`, `.glb` in
`assets/models/`) baked to pixel sprites in **8 facings** in one atlas, recoloured by a team-mask
shader; worn armour bakes on its wearer; props and buildings are realistic bakes. The full pipeline
is in `docs/rendering.md`. New art goes concept-first (options, Dominic picks, then build; D-080),
and every change gets looked at close up before it's shown.
New rounds write a sheet spec (`tests/sheets/*.json`, drawn by `tests/sheet.gd`), not a new script;
new creatures start in the creature kit (`scenes/art_pixel/creature_kit.gd`, kits in `data/creature_kit.json`,
unplayed ones staged in `data/later/`). Both are in `docs/rendering.md`. **No unit, mount, gear or pose change is
shown until `tests/placement_check.gd` passes** (Dominic, 2026-10-13): numeric checks of ground
contact, attachment, interpenetration, stance, feet, visibility and layering in 3D and in every facing,
plus a fixture for every placement bug he caught (`docs/rendering.md`, "Placement rules"). A new body,
mount or gear goes into a race in `tests/placement/cases.gd`; a body's anchors in parts.json are its
model's hips; legs that aren't the same on both sides bake at each hip (`"cut": ["legs"]`).

## The archive (keep it up to date)

`archive/` records how the game grows: pictures, decisions, changes of direction, funny bugs.
It's for future AI sessions (the *why* behind the code) and for fun. See `archive/README.md`.

**Take pictures as you go, not just at the end.** Whenever something visible changes, capture it
straight away into `archive/images/<YYYY-MM-DD>/NN-name.png` (numbered in order within the day).
That includes:
- the first render of a new mechanic, view or map
- each milestone checklist step that changes what you see
- every memorable bug (bug shots are the best part; save the buggy capture before fixing it)
- the final state of a milestone

Capture tools: `tests/screenshot.gd` (Race Lab) and `tests/sim_screenshot.gd` (sim view, any map).
Look at every capture before keeping it. As a rough guide, aim for at least 2-3 pictures per
milestone.

**Write things down as they happen too.** When a decision, a direction change or a funny bug
comes up mid-session, note it in the day's journal then, while the details are fresh.

At the end of any session that changed something meaningful (a milestone step, a new mechanic,
a direction change, a memorable bug), check that all of these are done:
1. **Pictures:** in `archive/images/<date>/`, as above.
2. **Journal:** add or extend `archive/journal/<YYYY-MM-DD>-<title>.md` using the template:
   what happened, decisions, direction changes, pictures, funny moments, ideas parked.
3. **Decisions:** append numbered entries to `archive/decisions.md` (next D-number). Never edit
   old ones; supersede them with a new entry.
4. **Timeline:** add one line to `archive/timeline.md`.
5. **Milestone file:** tick its checklist and record results in `docs/milestones/`.

Every milestone checklist ends with an "Archive" item, and a milestone isn't done until it's ticked.

The archive is append-only history. Write in plain words, with dates. Credit who decided what
(Dominic or Claude). Before making a design call, skim `archive/decisions.md` so you don't
undo a deliberate choice.

## Originality (legal hygiene)

We make a classic-style RTS. Genre mechanics (gathering, ages, unit lines, counters) are fair
game; everything expressive is ours. In code, data, docs, the archive and commit messages:
- Don't name or reference specific commercial games we're inspired by. Say "classic RTS" or
  "the genre". (Technical references to open-source projects in `docs/research.md` are fine.)
- Never use or recreate another game's art, UI layouts, icons, sounds, fonts, unit or civ
  names, or text.
- Don't write "copy", "clone" or "1:1". Describe what *we* want instead.
- No third-party franchises in shipped content. Fan mods stay private.
- The name "Age of Anything" is a working title (it was "Age of Anything" until 2026-10-12; the folder and
  repo keep the old name); trademark check before any public release.

## House style

- Small single-purpose scripts, no defensive programming: assert on broken data, don't paper over it.
- Use `preload` constants rather than `class_name`, so headless `--script` runs work without an editor import.
- Avoid dictionary keys that clash with Dictionary methods (`size`, `keys`, `values`, `hash`); use brackets for those.
- Keep tests headless and fast.

## Later (not now)

- Sharing races over P2P: race JSON as a Hyperblobs bundle, key = race key. Networking via a
  Bare/Hyperswarm sidecar over a localhost WebSocket, lockstep turns over Protomux (see design doc).
- Price-by-simulation: run headless fights vs reference units to set costs.
- Era packs: gunpowder, then a sci-fi "space federation" pack (a space-fleet sci-fi mod is the dream;
  official names/likenesses stay out of shipped content).
- Optional on-device model to expand prompts into briefs. Runtime stays deterministic either way.
