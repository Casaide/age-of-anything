# Age of Whatever

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
| `docs/market-context.md` | Why this game, why now (industry, genres, engines) |

Before starting a milestone, read `docs/milestones/<its file>.md` (and the related parts of
`docs/mvp-plan.md`), write the plan into the milestone file, and keep its checklist current. If you postpone something,
move it to `docs/backlog.md` rather than deleting it.

## Status

- **Done (milestone 0): race generation.** Prompt -> race -> composed, animated units in the Race Lab
  (`scenes/race_lab.tscn`, the main scene). The 2D shapes in `data/parts.json` are the data contract
  and socket reference; game scenes draw only the baked pixel art.
- **Done (milestone 1): sim core.** `src/sim/`: integer-only 20 Hz sim driven by a command queue,
  replays, state hashes, straight-line MOVE + separation. Debug view `scenes/sim_debug.tscn`.
  `tests/test_sim.gd` plays a 10-minute 200-unit match; tick is ~0.9 ms avg (budget 3 ms).
- **Done (milestone 2): map + movement.** Flow fields, move groups, isometric debug view, RTS
  camera, click/box/double-click selection. 50 units cross open and chokepoint maps, none stuck.
- **Built (milestone 3): economy.** Food from bug bushes, wood from reeds (cut reeds become
  ground), Town Center + Houses, training, construction, pop cap, rat economy from data, an
  economy bot (`src/ai/eco_bot.gd`), the command panel. Exit check: Dominic watches an opening
  (F6 in the debug view). See `docs/milestones/m3-economy.md`.
- **Next (milestone 4): combat.** See `docs/milestones/m4-combat.md`.

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
  terrain.json     terrain types: walkable, colours, resource + amount + what it turns into when used up
  buildings.json   building types: footprint, hp, cost, build time, pop, drop-off, what it trains
  maps/*.json      maps: ASCII rows + legend into terrain.json, start tiles; the view builds tiles from them
src/
  rng.gd           xorshift32 + FNV-1a. The only randomness allowed in generation/sim
  data_lib.gd      loads data/, era filtering, stable candidate lists
  race_generator.gd  prompt -> brief -> race (recipes) ; race_key()
  pricing.gd       recipe -> stats, tags, cost, train time, pop
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
  ai/              players that issue commands like a person (deterministic, lint-checked)
    eco_bot.gd       plays an opening: trains workers, 60/40 food/wood, houses, idle workers
    replay.gd        record / JSON / rebuild / verify
scenes/race_lab.*  prompt UI, race cards, two armies milling about in the baked art (bakes per generate)
  view/            view side (Nodes allowed): iso.gd projection, rts_camera.gd, command_panel.gd
    art/             the pixel-art views: art_kit.gd (bakes units, buildings, props into one atlas),
                     terrain_view.gd (shader ground + paths + doodads from a SimMap), building_art.gd
      bake/            the 3D bake pipeline for buildings and props: baker.gd, models.gd, materials.gd
scenes/art_pixel.* + art_pixel/          the pixel-art candidate: baked parts, palette, shader terrain,
                   unit_models.gd (hand-built parts), part_baker.gd, paths.gd (culture paths), pixelize.gd
assets/art/textures/  texture art authored by Claude (SVG), mapped onto unit models
scenes/sim_debug.* the playable debug match: select, smart right-click, panel (Q/H/C), Tab side, F6 autoplay,
                   F3 flow, F5/F9 replays, G regen army
tests/           headless checks and dev tools (see Commands)
```

## Commands

Godot on this Mac: `/Applications/Godot.app/Contents/MacOS/Godot` (alias it as `godot`).

```sh
godot --headless --path . --script res://tests/run_tests.gd        # must print "0 failed"
godot --headless --path . --script res://tests/print_races.gd -- "centaur romans" "flying greeks with wings"
godot --path . --script res://tests/screenshot.gd -- /tmp/lab.png "prompt A" "prompt B"
godot --headless --path . --script res://tests/test_sim.gd         # sim determinism + tick time (~45 s)
godot --path . --script res://tests/sim_screenshot.gd -- /tmp/sim.png [map_id] [armies|opening:<tick>] ["prompt A" "prompt B"]
godot --path . res://scenes/sim_debug.tscn                         # run the sim debug view
godot --headless --path . --script res://tests/gen_cost_curve.gd   # regenerate data/cost_curves.json
godot --path . res://scenes/art_pixel.tscn                         # pixel-art candidate (Z zoom, P palette)
godot --path . --script res://tests/art_screenshot.gd -- /tmp/art  # capture it at 1x/2x/3x
godot --path . --script res://tests/art_crop.gd -- /tmp/c.png 6.5 9 ["prompt A" "prompt B"]   # 3x close-up at a tile
godot --path . --script res://tests/art_bench.gd                    # draw calls + frame time, 200+ units
godot --path . --script res://tests/unit_lineup.gd -- /tmp/units.png ["prompt A" "prompt B"]   # both rosters as pixel art, 4x
godot --path .                                                     # run the Race Lab
```

A GDScript parse error in a `--script` run leaves Godot hanging instead of exiting; put a
timeout on headless runs.

Run the tests after every change to `data/` or `src/`, and `test_sim.gd` after every change to
`src/sim/` or pricing. Look at a screenshot after visual changes.

## Rules that matter

**Determinism is the backbone** (lockstep multiplayer and shareable races depend on it):
- Same prompt + rules + reroll must give the same race key on every machine. Tests enforce this.
- Never use `randi()`/`randf()`/`RandomNumberGenerator` in generation or the sim. Use `src/rng.gd`.
  The only exception is cosmetic animation in `unit_view.gd`.
- Iterate anything that affects output in a stable order (sorted ids or arrays), never raw
  Dictionary order from untrusted sources.
- Recipes hold only strings and ints. The race key hashes names + recipes, not derived stats.
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
  family/creature, e.g. rats like cheese). Wings only appear when asked; ridden units put wings on the mount.
- Roster: worker, spear, skirmisher (non-bow ranged, beats archers), archer (bows), large.
- Large units: a mount if available; giants only for creatures where that reads well
  (`giant_ok`); otherwise "Heavy" armoured elites. Centaurs are already mounted, so they go Heavy.
- Cultural knowledge ("romans" -> legionaries) is the generator's known gap. The plan is culture
  templates, then an LLM brief expander, both post-MVP (see backlog). Don't hack it into code.

## Art direction

Target the look of a **classic 2D isometric RTS**: small units, 3/4 view, painterly sprites, readable
silhouettes, team colour on a consistent region. It should feel like the game you know, gone mad.
Units are hand-modelled 3D parts baked to pixel sprites in one atlas, recoloured by a team-mask
shader; props and buildings are realistic bakes. Sockets, recipes and animation stay the same. The
old vector styles and the art-direction sampler are gone (their pictures are in the archive).

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
- The name "Age of Whatever" is a working title; trademark check before any public release.

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
