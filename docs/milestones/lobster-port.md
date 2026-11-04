# The Lobster port: a whole game in Lobster

**Status:** in progress (started 2026-10-26, Dominic: "Port it all. I want to see if we can get as far as me playing a
game on macos", then "All Lobster" over a Lobster sim inside the Godot game)
**Exit criterion:** Dominic plays a match against the bot on his Mac in a game written in Lobster: a window, the map,
his town and army, orders by mouse and keys, the bot playing back, to a win or a loss.

Branch `worktree-lobster-sim-spike`, code in `tests/lobster_spike/` (the spike that grew; see its README).

## Where it starts

The sim and the bots run in Lobster and match GDScript on every tick (all.sh, 2026-10-26): movement, combat, hills,
fog, the economy, ages and research, towers, garrisons, healers, heroes, the match rules, the eco bot and the full
bot. Not ported: walls, gates, bridges, animals and pens, trade and markets, Wonders and game modes, siege engines
(packing, blasts, rams, ladders, towers), abilities (webs), shift-queued orders, STOP, CANCEL, DROP_OFF, REPAIR,
SURRENDER, the bots' walls and abilities.

## Shape (Claude, 2026-10-26)

- **The sim and bots: Lobster**, every system hash-checked against GDScript as before (`export.gd` writes a
  scenario, `sim.lobster` replays it or plays its own bots).
- **The art: baked by Godot, drawn by Lobster.** The units, buildings and props are 3D models in GDScript and Blender
  baked to pixel sprites; porting the models and the baker is weeks on its own and changes nothing you see. So a
  Godot tool writes a *match pack*: the scenario (the match's starting state, as the export does now) plus every sprite
  the match needs as PNG sheets and a JSON index (anchors, facings, frames). Lobster loads the pack and draws it.
  Whether the baker moves to Lobster later is a later call.
  Units aren't baked whole: each part is baked (8 facings for modelled parts) and `UnitView` puts them together on
  rigs with procedural animation (bobbing, swinging legs, posed walk steps, 0.35 s attacks, tools and loads swapped
  in). So the pack renders `UnitView` itself, per unit type, facing and step, into flipbook sheets: idle, the 8 walk
  steps, 5 attack steps, work per tool, carrying per load, the fall. Team colour stays the baked magenta key
  (`team_mask.gdshader`'s test), recoloured by a Lobster shader. Buildings, construction stages, gates, wall arms,
  props and resource stages come out of `kit.bakes` as they are (image + origin). Terrain is a shader in Godot;
  Lobster starts with per-tile colours blended (`data/terrain.json`) and the doodads, and grows from there. Iso:
  64x32 canvas px a tile, `to_screen(x, y) = ((x - y) * 32 / 1000, (x + y) * 16 / 1000)`, 20 px a level.
- **The game: Lobster.** Window, isometric camera, terrain, units and buildings in draw order, selection, orders,
  the command panel, minimap, fog, sound (the WAVs in `assets/audio/`), the bot on the other side.
- **Setup (races from prompts): Godot first, Lobster later.** The first playable match comes from a pack Godot
  writes (races, map, rules); porting the generator, pricing and identity to Lobster is a later step, and with it a
  Lobster lobby. Until the baker moves, a new race needs a Godot bake (it could run as a subprocess).

## Plan

1. **The rest of the sim**, hash-checked: shift-queued orders, STOP, CANCEL, DROP_OFF, SURRENDER, AUTO_RESEED;
   repair; markets and trade carts; animals and pens; bridges; walls, gates and walkways; siege engines (packing,
   min range, splash, blasts, buildings-only, rams, ladders, siege towers); abilities and slowing; trails; game modes
   and Wonders; the bots' walls, abilities and trade. New scenarios: matches on reed_meadow and siege_vale with
   varied races, and a command fuzzer (every player command, seeded) so what a person does is checked too.
2. **The match pack** (Godot tool): scenario + sprite sheets + index for a chosen match (races, map, mode).
3. **The game shell** (Lobster): load a pack, draw the map and everything on it, camera, the sim at 20 Hz.
4. **Playing**: selection, orders, the command panel (train, build, research, age up), the bot opponent, win/lose.
5. **Feel**: minimap, fog, sound, hit flashes and shots, health bars, the top bar.
6. **Setup in Lobster** (later): DataLib, the generator, pricing, identity; a lobby.

## Checklist

- [x] 1. Rest of the sim, 2026-10-26, each piece hash-checked against GDScript (replayed, and with Lobster's own
      bots where bots use it): shift-queued orders, STOP, CANCEL, DROP_OFF, SURRENDER, auto-reseed; markets, trade
      carts, repair and the bots' trading; animals and pens and the bots' herding and hunting; map bridges; siege
      weapons (minimum range, packing, splash, bolts, sappers' blasts) and the bots' engines; bounties; Wonders and
      the Siege mode's win rules, the bots' Wonders; gates and per-team lanes, wall lines, diagonal gates, rubble;
      walls you stand on (climbing, walkways, ladders, docked siege towers, falling, pours) and the bots manning and
      storming them; race abilities (webs, sticky hits, wading) and the bots' webs; worn trails. Scenarios in
      `all.sh`: siege (age-3 armies with engines), walls (a stone ring stormed), play (a seeded person's orders,
      walls and gates included, on top of two bots), matches with animals, from age 3, in the Siege mode on Siege
      Vale, spiders v frogs.
- [x] 2. Match pack (`art_pack.gd`, `make_pack.sh [map] ["race A" "race B"]`: every unit type x 8 directions x every
      state, every bake, in sheets; names, team colours, voices, sounds)
- [x] 3. Game shell (`game.lobster`, `play.sh`)
- [ ] 4. Playing: selection, orders (shift-queued), building, training, research (Q W E R T Y I O P), age-up,
      the bot opponent, the win banner; a self-test drives the controls (`play.sh pack selftest`). Waiting on
      Dominic's first match.
- [x] 5. Feel: minimap, fog, sound and creature voices, hit flashes, shots, health bars, the top bar, a UI scaled to
      the screen are in; the ground is Godot's terrain shader, ported (`game/ground.lobster`, 2026-10-26), with hills'
      relief, joined walls, the ground's doodads, the theme in stems, and each culture's paths (`game/paths.lobster`:
      A* from the town's door to its buildings, food and wood, merging into trunk roads), and the combat effects
      (`game/fx.lobster`: each weapon's shot on its arc, misses standing in the ground, sparks, dust, heal motes; the
      sim tells the view of misses, heals and stones landing), and the living town (`game/town.lobster`: piles at
      the drop-offs, chores, builders' dust, yards and gardens, critters). Control groups (Ctrl or Cmd + a number keeps the selection, the number brings it back, twice to look;
      in the self-test). The nicer panel came with the UI after Godot's (below);
      from town life, all in now: the stable's tethered mount too (`26-...`; `place:<building>` puts one down for
      captures). Cracks on damaged walls (sorted with their building; `25-...`)
      and the town's sound (the meadow loop, the town's quiet and busy loops by its size and the camera) are in. Chimney smoke, lit windows
      and fire on badly hurt buildings are in (`building_fx.gd` writes where each look's chimney and windows are; `15-...`).
- [x] Save and load (2026-10-26): `gen/save.lobster`, written by `gen_reset.lobster` from the same list of globals as
      the reset: every sim and setup global plus the bots, one record as a flexbuffer (about 3 MB, saved in 15 ms,
      loaded in 10 ms). F5 saves, F9 loads (`reload:<s>` in tests). `save_check.lobster`: a bot match saved at
      7.5 minutes and loaded plays the next 4,000 ticks hash for hash. Not yet: Godot's saves (JSON, its own
      layout) can't be read here, and a save from an older Lobster build won't load once a global changes type.
- [x] Network play (2026-10-26): `net/lockstep.lobster`, lockstep over TCP (the Lobster build's `tcp.` sockets):
      `host` waits for a player and sends the whole set-up match (the save record, about 1.5 MB); `join:<ip>`
      skips the lobby and plays the second side. Turns as in `src/net/lockstep.gd` (commands run two turns on,
      a hash every 40 ticks); no pausing, speed, loading or N in a network match. `net_check.sh`: two processes,
      each side's bot only on its own machine, a 10-minute match with all 300 hash checks the same. Two game
      windows played 100 seconds together (`13-...`). Finding a host (2026-10-26, `net/lan.lobster`): this Lobster build has
      no UDP, so Find asks every address of the home network's /24 over TCP; a host answers with its name, version
      and map, and only a join with the same build's version (a hash of the protocol and the data) becomes its match.
      The lobby has Find, Join (an address), Host (`30-...`). `net_check.sh` now scans, finds the host, and plays.
      A peer that closes its end no longer hangs a read (an empty read was taken as more to come). Not yet: more than
      two players, the Mac against the Deck. More than two since (2026-10-26): a star round the host (each joiner's
      turns relayed to the others, a seat given with the match); `host:4` makes a 2v2 on the four-player map from
      the two prompts and their further takes. `net_check.sh 2400 noscan 4`: four processes, 60 of 60 hashes the
      same; four game windows played a minute together (`38-...`). Not yet: the Mac against the Deck.
- [x] Pad play (2026-10-26): `game/pad.lobster`, after `src/view/pad_play.gd` and the m20 button table: a reticle
      for the mouse (left stick pans, right stick nudges), A taps to select, held a circle sweeps, on what's
      selected the wheel (train, research, age up; build); X smart order, Y attack-move, B back, RB soldiers on
      screen, LT / RT zoom, the d-pad an idle worker, the Town Center, groups 1 and 2. Last input wins.
      `padtest`: a fake pad plays (10 checks). Since: the wheel's pages (LB turns them), menus by the pad's focus, a Deck build, and LB as Godot's pad has it (2026-10-27: held, X and Y queue and A adds to the selection; tapped, the next kind of what's selected), A or X giving an armed order. Not yet: Steam Input's layout.
- [x] Control groups shown (Dominic, 2026-10-26: "visible somewhere, at least as a number on the units", then "only
      when you select the group"): the group's number by each selected unit, and each group with its size under the
      top bar (`14-...`).
- [x] The tech tree page (2026-10-26): `game/techtree.lobster`, after `src/view/tech_tree_model.gd`: ages as rows,
      buildings as columns, unit lines (a node where the unit changes) and research tracks packed into lanes, your
      race's names, what it lacks struck through, other races' own research left off; F1 in a match (`18-...`).
      The race panel too (its bonuses and where each comes from, its own research, what it lacks; `27-...`).
      Research effects in words (`gen/effect_words.lobster`, all 56 as Godot's: `effect_words_check.lobster`) and the
      heroes' nodes since 2026-10-27 (`02-...`). (In this Lobster build `gl.rect` draws -size..size round its point:
      the page's boxes allow for it.) Drawn as the Godot page since 2026-11-03 (`game/techtree_page.lobster`: the
      race panel and its army, the age rail, pictures and lines, the hover card, the match's progress;
      `2026-11-03/11-...` to `15-...`).
- [x] The Race Lab, in the lobby (2026-10-26): each typed race's whole roster drawn from the part library as you
      type, idling in its team colour, under its stats (`lab` with `races:A|B` captures it; `19-...`). Rerolls too: a
      Reroll button per race, another take on the same prompt, played as shown (`reroll:a|b`; `28-...`). And Test: every line of the two
      typed races fought against every other at equal cost there and then (66 fights, about a second), how even they
      are before any pricing (`29-...`). And Fight (the Race Lab's
      armies fighting): both races' armies on the map at once, three of each soldier, marching on each other, the camera
      following (`skirmish`; `31-...`).
- [x] The command panel (2026-10-26): `game/panel.lobster`: a unit card (a portrait from the unit's own parts, hp,
      stats) and clickable buttons with hotkeys, units' portraits and buildings' pictures on them, cost on hover
      (`20-...`). Queue progress and research icons came with the UI after Godot's.
- [x] The UI layer and the timber look (2026-10-26): `game/ui.lobster`: the look from data/ui.json (and a culture's
      `ui` block), wood and bronze painted by a shader, boxes raised / flat / sunk with bevels and studs, buttons
      (hover, pressed, focus, primary), text queued and drawn last, the pad's focus for menus. Every flat shape
      now draws through screen-space meshes: in this Lobster build `gl.rect` draws -size..size round its point
      and goes astray after a custom shader, and a raw mesh doesn't get gl.color. The command panel uses it
      (`21-...`), and the lobby (`22-...`: the races in panels with their armies, the map and mode, Join with an
      address, Host, Play). Then a pause menu (Esc or Start: Resume, Save, Load, Tech tree, Quit;
      `23-...`) and the tech tree page (`24-...`).
- [x] A Steam Deck build of the Lobster game (2026-10-26): `tests/lobster_spike/deck/build.sh` builds Lobster for
      Linux x86-64 in a Podman container (Ubuntu 22.04; Dominic approved the downloads) and assembles the game folder
      (185 MB at first; 49 MB since the part library stays home and the game bakes its own art); it ran headless in a Linux container (the same
      races as on the Mac). Copied to the SMB share as `lobster_linux`, with `pull_lobster.sh` beside it for the Deck.
      Not yet played on the Deck itself.
- [ ] 6. Setup in Lobster (Dominic, 2026-10-26: "Let's do it! Primarily because ... it opens us up to generation at
      army creation time and during the game"). Three steps, each checked against GDScript:
  - [x] 6a. Races and the match from data, 2026-10-26: a JSON reader and Godot-compatible writer, SHA-256, DataLib,
        the generator, pricing, identity, heroes (`gen/`), and World setup (`gen/setup.lobster`, `gen/start.lobster`).
        Checked: `race_check.sh` (23 prompts x 3 rules: the same races, keys, notes, heroes) and `start_check.sh`
        (four matches: the Lobster start equals export.gd's scenario token for token). The game makes its races and
        start from the pack's prompts (`play.sh pack`; `scenario:<file>` for an export). Game modes' starts are in since
        2026-10-26 (`gen/modes.lobster`: Fortress and Siege match export.gd's token for token, `start_check.sh`;
        F2 in the lobby or `mode:<id>`). Mods too (`gen/mods.lobster`, after `src/mods.gd`: found, checked, merged in
        load order, rules and maps overlaid, the signature in the race key): with `scifi_test` and the anything rules
        `race_check.sh anything scifi_test` gives GDScript's 26 races. A pack baked with a mod (`AOW_MODS=... art_pack.gd
        ... rules:<id>`) records its rules and mods; the game merges them (or `mods:` / `rules:`) and plays the
        modded race with its shot looks (`17-...`). The mod's models still bake in Godot.
  - [x] 6b. Units drawn from baked parts in Lobster, 2026-10-26: `view/` (a scene graph, Godot's PCG, the part
        bakes and rigs, `src/unit_view.gd` ported). `view_check.lobster`: art_pack's states for 39 types x 8 facings,
        14946 of 14952 frames' draw lists identical to Godot's (six differ by Godot's float32 positions). The game
        composes every unit live.
  - [x] The part library (`art_pack.gd ... library`): every part in every colour any race can wear (every creature
        with every culture in every skin, every hold, every part on every body): about 90,000 bakes, 26 sheets,
        160 MB, loaded in 2.4 s. `library_check.lobster`: 120 of 120 random races drawn whole. So any race the
        generator makes plays at once, looking exactly as in Godot.
  - [x] The lobby: two prompts typed in the game, each race shown as you type; Enter balances them by fights
        (below) and starts the match (`play.sh library lobby`, or `game.lobster -- library lobby`).
  - [x] Balance by simulation (`gen/balance.lobster`, `balance.lobster`): tests/round_robin.gd's equal-cost fights,
        the same fights (all 528 of balance.gd's age-2 round robin match GDScript), in 8 s in one process; the
        auto-balance prices each line by its win rate, then bisects: on balance.gd's five races, 20 of 33 units
        more than 10 points off the mean become 2 in six rounds. Two races before a match: about 5 s.
  - [x] A new race mid-match (N): the running world stashed (`gen/reset.lobster`), the newcomer balanced against
        the others by fights, then the player's lines, bonuses and buildings become it (`gen/swap.lobster`).
  - [x] 6c, stage 1 (2026-10-26): `view/baker.lobster` bakes a part's mesh as Godot's part baker does (its camera,
        its warm key and cool fill over ambient, Lambert over pi, sRGB; 4x supersampled, then pixelized with the
        inner outline). `mesh_export.gd` writes Godot-built models as triangles (skinned .glb parts posed);
        `bake_check.lobster` lays each beside Godot's bake from the library (`32-...`: the rat's parts). Shapes,
        facing and light agree; textures too (UV and triplanar, `33-...`), and the size (the units' scale, 1.5 x 0.85:
        every part within a pixel of Godot's). The rest (ambient occlusion, cuts, worn armour, the models themselves) came
        in 6c, 6d and 6e below.
  - [x] 6c, the mesh library (2026-10-26): `mesh_export.gd library` writes every modelled part once (293 parts,
        binary vertices), each material tagged with the race channel its colour follows (skin, cloth, team...: a
        multiply and add) or fixed; the Lobster baker bakes any race's parts from it in that race's colours (the
        moonbears and the tiny vikings match Godot's bakes, `36-...`). So new races need no Godot; only new models do.
        In the game too (`game/bake_missing.lobster`, `meshes:<dir>`): at the match's start every part a unit type
        wears is looked up in the pack in eight facings and what's missing is baked from the mesh library (the
        sci-fi mod's soldiers: 56 facings in 3.6 s, drawn in play, `37-...`). (Superseded by the part baker and the
        models in Lobster, below.)
  - [x] 6c. The part baker in Lobster (2026-10-26): `view/part_bake.lobster` bakes a Lobster-built model in all eight
        facings as `part_baker.gd` does: the near-arm layer (`#front`), a leg or head cut by its body, armour worn on
        it, a neck run into its head without an outline (the creature kit's seams), and each facing's rig (sockets,
        depth, hips, which way it faces, scales, the weapon's tip) and a leg's soles and span. The baker now has a depth
        test (a framebuffer with depth, `gl.ortho(false, true)`), a mask pass for cuts, and two-sided faces lit from the
        front. `part_bake_check.lobster`: a race's parts against the library's Godot bakes: the opaque boxes within a
        couple of pixels, sockets within 0.1 of a unit, brightness within a few levels. Found on the way: Godot's part
        baker frames a scaled model without its scale, so the larger junk engines are clipped in Godot's bakes; the
        Lobster ones show all of the engine (`43-...`). The game bakes what the pack lacks from these models
        (`bake_missing.lobster`); the mesh library is no longer needed for parts.
  - [x] 6d. The models in Lobster (2026-10-26): `model/`: a kit of Godot's primitive meshes vertex for vertex
        (`prim_check.lobster`), nodes and materials, a glTF reader for the Blender parts, Godot's random generator
        and FastNoiseLite; then every model file ported line for line and checked triangle for triangle against
        Godot's (`model_check.sh`, `prop_check.sh`, `building_check.sh`): the unit parts (frog, rat, spider, human,
        ponies, horses, centaurs, capybaras, cats, birds, beasts, beetles, newts, weapons, shields, helmets, armour,
        tools, loads, the culture kits, healers, the creature kit's bears in every pose and step), siege engines,
        carts, the great sling, war beasts and shots, heroes' gear, bears' helmets (~440 part ids); the props,
        trees, piles, yards, gardens and bridges (243 cases); every building, wall, gate and look (302 cases); the
        buildings' materials with their noise textures made in Lobster (`mat_check.sh`, within 2/255). The world
        baker (`view/world_bake.lobster`, Godot's building baker in pixel mode: sun, fill, rim, the sun's shadow,
        a GGX highlight, filmic tone, ground shadows) bakes props within 2 px and a few levels of Godot's
        (`world_bake_check.lobster`, `42-...`); the game bakes the props the pack lacks (`game/art_kit.lobster`;
        `rebake` bakes all 193 in 2.5 s, `41-...`). Next: the buildings' looks (stages, layers, gate parts, wall
        arms, chimney points) baked in Lobster, then a pack made without Godot.
  - [x] 6e. Buildings and a match without a pack (2026-10-26): every look of each culture's buildings baked in the
        game (`game/art_kit_buildings.lobster`: construction stages, near layers, gates open and their towers, wall
        arms, house variants, age looks, chimney and window points; 1283 of 1312 frames within 3 px and 12 levels
        of Godot's, `building_bake_check.sh`, the rest thin scaffold), the pack's tables from data
        (`game/pack_data.lobster`: team colours, sounds, voices, building and research names, ground colours, and
        each tree cell's species, cell for cell as Godot's on all nine maps, `species_check.lobster`). So
        `play.sh none lobby` plays with no Godot-made files at all: every part, prop and building baked at the
        start, the parts kept in `bake_cache/` for the next start (the first start bakes a few hundred part facings;
        a beast's legs in every walk step, each with its body, are most of it). `rebake` bakes every prop and
        building even with a pack.
  - [x] Controls after Godot's (2026-10-26): the whole smart right-click (pens, slaughter, breaking and rebuilding
        bridges, mending, walling up a breach, climbing our wall, trade routes, reseeding, garrisoning), attack-move
        and the race's ability armed by a button or key then a click, Ungarrison, Reseed and Auto-reseed, Release,
        the market's buying and selling, Surrender in the pause menu; GARRISON and UNGARRISON by hand in the sim
        (left out before: the bots don't use them). The self-test garrisons and ungarrisons (9 checks).
  - [x] The UI after Godot's (2026-10-26, `39-...`, `40-...`): the top bar (`game/topbar.lobster`) and the command
        panel, unit card, portraits as busts, captioned button groups with costs and hover cards, the training
        well, the minimap's diamond and frame; Godot's icons as PNGs (`icons.sh`). Every culture's painted materials
        since (13, after `ui_materials.gd`), and the pad's compact panel (2026-10-27).
  - [x] Checked at the end (2026-10-26): the parity suite (`all.sh`): all 18 scenarios, 26 runs, every tick's
        hash the same as Godot's (moves, fights to 2000 units, sieges, walls, economies, a person's orders, five whole
        bot matches, the bots in Lobster too). A whole match with no pack (`play.sh none lobby ... watch tillend`):
        the races balanced by fights at the start, 40 minutes of bot play to age 3 without a fault (`46-...`; no side
        had won by then).
  - [x] Selection rings on the ground (Dominic, 2026-10-26: "selection circles arent behind anything. They're on
        top"): drawn in the sorted world under everything standing (`41-...`). Test runs are silent (Dominic: "stop
        any future testing having sounds"): the game mutes with shot:, selftest, padtest, labtest, reload:, or `mute`.
  - [x] A new army mid-match with no pack (2026-10-27): the creature kit's bodies completed in Lobster as
        `CreatureKit.complete` (`kitparts_check.lobster`, 12 of 12), and a swapped-in race's parts and buildings baked
        on the spot: rats became moonbears with axes at 1:00, balanced in 598 fights, played on to 5:00
        (`2026-10-27/01-...`).
- [x] 6. Setup in Lobster.
- [ ] Archive

## What Godot is still for (2026-10-27)

The game: nothing. `play.sh none lobby` reads only `data/`, the sounds (`tools/audio/`, Python), the Blender models
(`assets/models/*.glb`), the SVG icons and textures as PNGs (`icons.sh`, `textures.sh`: rsvg-convert) and the font.
Every model, bake, map, rule, race, price, bot, save, network match and screen is Lobster.

Godot is left in three places, none needed to play:
- **The parity checks**: `export.gd`, `*_dump.gd`, `*_export.gd` write Godot's answers that the Lobster checks compare
  against (all.sh, model_check, building_bake_check...). They go when the GDScript game is retired.
- **Packs** (`art_pack.gd`, `make_pack.sh`): optional. A pack only skips the first start's baking.
- **The GDScript game itself** (`src/`, `scenes/`, the Godot Deck build): still in the repo beside the port. Retiring
  it is Dominic's call once he has played the Lobster one.

Left in the port, against the Godot game: Godot's saves don't load in Lobster (each game has its own; moved to the
backlog with a way to do it, 2026-10-27). The pad's compact panel is in since 2026-10-27 (the orders on the wheel,
the card and queue in the panel). Steam Input's layout isn't a port gap: the Godot game hasn't one yet either
(m20 step 9). The exit criterion (Dominic's own match), the Deck play-test and the Mac against the Deck over the
network wait on Dominic.

## After the port: Godot out, Lobster in (Dominic, 2026-10-27)

Once the art study's work lands (rat B D-177, frog B D-178, limbs baked in keyed poses), the GDScript game is deleted,
the Lobster code moves out of `tests/lobster_spike/` to the repo root, and the branch merges to main. Before that:
- the art study's new bodies and poses ported to `model/` and held to Godot's triangles, as every model so far;
- a placement check in Lobster (`placement_check.gd`'s checks: ground contact, attachment, interpenetration, layering
  in every facing, the bug fixtures), since no unit change is shown until it passes;
- the concept-sheet tool (`tests/sheet.gd` from a sheet spec) in Lobster, so new art stays concept-first;
- the parity checks retired with Godot (their GDScript side goes), the docs and CLAUDE.md rewritten for Lobster.

The sheet tool in Lobster (2026-10-27): `tests/lobster_spike/sheet.sh tests/sheets/<spec>.json <out dir>` (sheet.lobster)
reads the same specs and writes the same sheets through the Lobster composer and bakes; cat_mount, bears_b1, heroes_h1 and
line_lineup drawn beside Godot's with the same rows, columns and poses. Each row goes through the Lobster placement
check (`sheet_row_check`: both halves, each distinct unit once, expected failures honoured; rat_push_home: 4 rows, the
one expected to fail A3 does); corpse columns aren't drawn yet.

The placement check in Lobster (2026-10-27): `lobster placement_check.lobster -- [filter] [3d|2d]` (placement/), with
`parity` / `parity2d` against Godot's dumps. 3D: the 1316 cases the same as Godot's, its fixtures all caught. 2D on the
rats (46 units, 722 rules): one rule differs from Godot's, the sitting cat mount's hind paw in facing 5 (3 px over its
ground point; Godot's 2, at the limit). Found on the way and fixed in the game: the trade cart's draught harness never
baked (an empty-model guard ran before the harness was fitted to its beast); engines' crews drawn on the wrong side of
the engine (the bake never worked out which members stand in front: part_baker.gd `_members_front`, ported); parts baked
at the exact art scale where Godot's whole-pixel viewport makes each a little larger, rigs with them (now as Godot's:
the beetle's seat and girth to 1e-5). The check: crews drawn at the creature's draw_scale (rats and frogs a fifth
smaller on foot, Lobster only); composing repeats until nothing new is baked (results no longer hang on unit order); a
far foot's one-pixel sliver in the CPU truth no longer counts as in sight. bake_cache.sh empties the bake cache when
BAKE_VERSION changes.

Destruction in Lobster (2026-10-28, the art study's D-171 and D-172): `game/ruin.lobster` breaks a building up in 3D
as ruin.gd does (the same random numbers in the same order: `building_check.sh` holds `building:<type>:<arch>:ruin<s>`
to Godot's, triangle for triangle); the art kit bakes ":ruin1".. ":ruin4" for every look but walls, gates and what has
a near layer. In the game a building shows its battered, breaking and collapsed stages at 30, 55 and 80% damage (cracks
only for a look baked without them), its fires sit lower in the walls, and when it falls it leaves its ruin under
pixel dust (game/fx.lobster: draw_puffs). The ruin burns 8 s, lies 45 s, fades over 5 s (a sprite-shader uniform: the
vertex colour is bytes) and goes at once when something is built on its cells. `raze:<s>` (captures) makes your
buildings but the Town Center fall then. Pictures: `archive/images/2026-10-28/06-...` to `09-...`.

## Results

- 2026-10-26 (6b and on): the ground shader and composed rats (`archive/images/2026-10-26/05-...`), moonbears typed into
  the lobby and drawn from the library (`06-...`), rats becoming forest bears a minute into a match (`07-...`).
  Then hills and cliffs (`08-...`), joined walls (`09-...`), and the rats' cobbled roads from their town out to the
  bushes and reeds (`10-...`). Shots on their arcs in a rat and frog fight (`11-...`). The rats' town with its piles (`12-...`).

- 2026-10-26 (6a): two races from prompts in about 3 ms and the match start in about 3 ms, in the game; frames from the
  Lobster-made start and from the GDScript scenario are byte-identical at tick 101.

- 2026-10-26: the first match in a Lobster window (rats v frogs on flat_test, the bot on both sides when watching):
  `archive/images/2026-10-26/01-lobster-game-first-frame.png`, `02-lobster-game-rat-raid.png`. The sim and both
  bots take 0.35 ms a tick in the game; frames hold 60 fps with the whole match drawn.

## Godot retired (2026-10-28, D-184)

Dominic: "actually complete the migration to lobster. Godot should be gone, performance for all tests should be
optimised." Done in this order, each step checked against Godot while it still existed:
- **The art study ported** (merge of `claude/upbeat-cray-f3dce8`): every model it changed (rat B, frog B with its hop,
  heroic humans, horse legs, keyed legs for every legged body, creature-fitted armour, the walled howdah) held to Godot's
  triangle for triangle (253 of 253 parts), the 3D placement check identical (1312 cases, 25650 checks); the composer's
  walk steps, head nod, blow timing, sized bakes (D-180) and draw lists the same as Godot's but for intended differences
  (rats drawn at 80%, the howdah's upright weapons: Dominic). The art at 2x (D-173) with the world kept in the old art
  pixels. Destruction (ruins in four stages, dust, fading), the dead laid down in 3D baked, the fog's memory of the
  ground, the sim's formation and terrain-speed fixes (the latter a Lobster bug the AI tests found).
- **The front end ported** (`game/lobby.lobster`): the title, the battle setup in each culture's look with AI levels and
  team games, the Race Lab, saves, the network page, the match loader, back to the lobby after a match; the playtest
  log (`src/matches.jsonl`).
- **The tests ported**: run_tests (38,814 checks), test_heroes, test_race_identity, test_sim (51 parts), test_ai,
  test_2v2, race_matches, mass_battle, balance, resource_audit, path_audit; the placement check and the sheet tool;
  mod_check; the golden files for what the parity checks proved.
- **Faster:** `./tests/batch.sh` (4 processes at once, shards, slow suites first: the quick batch in about 100 s);
  the bake twice as fast (triangles grouped once a part), Godot's bicubic shrink; building and prop bakes cached
  (a match start's 134 s of buildings now 0.13 s); the 3D placement check's attachments cached; the forest ram's
  crash (a recursive sort on 100k triangles) fixed.
- **Removed**: the GDScript game, its tests, the parity tools; the code moved to `src/`; CLAUDE.md, README, rendering,
  modding, audio and playtest docs, the make-mod skill and new_mod.py rewritten for Lobster.
Left over: `docs/backlog.md`, "Left from the Lobster port".
