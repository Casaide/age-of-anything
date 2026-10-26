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
- [ ] 5. Feel: minimap, fog, sound and creature voices, hit flashes, shots, health bars, the top bar, a UI scaled to
      the screen are in; the ground is Godot's terrain shader, ported (`game/ground.lobster`, 2026-10-26), with hills'
      relief, joined walls, the ground's doodads, the theme in stems, and each culture's paths (`game/paths.lobster`:
      A* from the town's door to its buildings, food and wood, merging into trunk roads), and the combat effects
      (`game/fx.lobster`: each weapon's shot on its arc, misses standing in the ground, sparks, dust, heal motes; the
      sim tells the view of misses, heals and stones landing), and the living town (`game/town.lobster`: piles at
      the drop-offs, chores, builders' dust, yards and gardens, critters). Control groups (Ctrl or Cmd + a number keeps the selection, the number brings it back, twice to look;
      in the self-test). To come: a nicer panel;
      from town life, all in now: the stable's tethered mount too (`26-...`; `place:<building>` puts one down for
      captures). Cracks on damaged walls (sorted with their building; `25-...`)
      and the town's sound (the meadow loop, the town's quiet and busy loops by its size and the camera) are in. Chimney smoke, lit windows
      and fire on badly hurt buildings are in (`building_fx.gd` writes where each look's chimney and windows are; `15-...`).
- [x] Save and load (2026-10-26): `gen/save.lobster`, written by `gen_reset.py` from the same list of globals as
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
      two players, the Mac against the Deck.
- [x] Pad play (2026-10-26): `game/pad.lobster`, after `src/view/pad_play.gd` and the m20 button table: a reticle
      for the mouse (left stick pans, right stick nudges), A taps to select, held a circle sweeps, on what's
      selected the wheel (train, research, age up; build); X smart order, Y attack-move, B back, RB soldiers on
      screen, LT / RT zoom, the d-pad an idle worker, the Town Center, groups 1 and 2. Last input wins.
      `padtest`: a fake pad plays (7 checks). Not yet: the wheel's pages, LB (queue, cycling kinds), menus on
      the pad, Steam Input's layout, a Deck build of the Lobster game.
- [x] Control groups shown (Dominic, 2026-10-26: "visible somewhere, at least as a number on the units", then "only
      when you select the group"): the group's number by each selected unit, and each group with its size under the
      top bar (`14-...`).
- [x] The tech tree page (2026-10-26): `game/techtree.lobster`, after `src/view/tech_tree_model.gd`: ages as rows,
      buildings as columns, unit lines (a node where the unit changes) and research tracks packed into lanes, your
      race's names, what it lacks struck through, other races' own research left off; F1 in a match (`18-...`).
      The race panel too (its bonuses and where each comes from, its own research, what it lacks; `27-...`).
      Not yet: research effects in words, heroes' nodes. (In this Lobster build `gl.rect`
      draws -size..size round its point: the page's boxes allow for it.)
- [x] The Race Lab, in the lobby (2026-10-26): each typed race's whole roster drawn from the part library as you
      type, idling in its team colour, under its stats (`lab` with `races:A|B` captures it; `19-...`). Rerolls too: a
      Reroll button per race, another take on the same prompt, played as shown (`reroll:a|b`; `28-...`). And Test: every line of the two
      typed races fought against every other at equal cost there and then (66 fights, about a second), how even they
      are before any pricing (`29-...`). And Fight (the Race Lab's
      armies fighting): both races' armies on the map at once, three of each soldier, marching on each other, the camera
      following (`skirmish`; `31-...`).
- [x] The command panel (2026-10-26): `game/panel.lobster`: a unit card (a portrait from the unit's own parts, hp,
      stats) and clickable buttons with hotkeys, units' portraits and buildings' pictures on them, cost on hover
      (`20-...`). Not yet: queue progress, research icons.
- [x] The UI layer and the timber look (2026-10-26): `game/ui.lobster`: the look from data/ui.json (and a culture's
      `ui` block), wood and bronze painted by a shader, boxes raised / flat / sunk with bevels and studs, buttons
      (hover, pressed, focus, primary), text queued and drawn last, the pad's focus for menus. Every flat shape
      now draws through screen-space meshes: in this Lobster build `gl.rect` draws -size..size round its point
      and goes astray after a custom shader, and a raw mesh doesn't get gl.color. The command panel uses it
      (`21-...`), and the lobby (`22-...`: the races in panels with their armies, the map and mode, Join with an
      address, Host, Play). Then a pause menu (Esc or Start: Resume, Save, Load, Tech tree, Quit;
      `23-...`) and the tech tree page (`24-...`).
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
  - [ ] 6c, stage 1 (2026-10-26): `view/baker.lobster` bakes a part's mesh as Godot's part baker does (its camera,
        its warm key and cool fill over ambient, Lambert over pi, sRGB; 4x supersampled, then pixelized with the
        inner outline). `mesh_export.gd` writes Godot-built models as triangles (skinned .glb parts posed);
        `bake_check.lobster` lays each beside Godot's bake from the library (`32-...`: the rat's parts). Shapes,
        facing and light agree; not yet: textures (the fur, the wood, the metal come from texture maps), shadows
        and ambient occlusion, the sprite's scale (about 1.2x large), the head's turn, the cuts (a leg by its body,
        armour on its wearer). Then the models themselves in Lobster.
  - [ ] 6c. The part baker in Lobster (the procedural 3D models, the Blender models converted, the pixel pass):
        Godot no longer needed. With the library, this is now the art-quality step (higher resolution, more poses,
        destruction, effects), not a blocker. The art-quality study (Dominic, 2026-10-26: "how far we can go with art
        quality ... while maintaining nostalgia above all else") goes concept-first, after this.
- [ ] Archive

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
