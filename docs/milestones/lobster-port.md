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
      the screen are in. To come: the Godot terrain's look, music, control groups, a nicer panel.
- [ ] 6. Setup in Lobster (Dominic, 2026-10-26: "Let's do it! Primarily because ... it opens us up to generation at
      army creation time and during the game"). Three steps, each checked against GDScript:
  - [x] 6a. Races and the match from data, 2026-10-26: a JSON reader and Godot-compatible writer, SHA-256, DataLib,
        the generator, pricing, identity, heroes (`gen/`), and World setup (`gen/setup.lobster`, `gen/start.lobster`).
        Checked: `race_check.sh` (23 prompts x 3 rules: the same races, keys, notes, heroes) and `start_check.sh`
        (four matches: the Lobster start equals export.gd's scenario token for token). The game makes its races and
        start from the pack's prompts (`play.sh pack`; `scenario:<file>` for an export). Game modes' starts (Siege,
        Fortress) and mods aren't set up in Lobster yet.
  - [ ] The lobby: prompts typed in the game. Needs a new race's art without Godot (6b, 6c).
  - [ ] 6b. Units drawn from baked parts in Lobster (UnitView's assembly, rigs, procedural animation): no
        per-race flipbooks; Godot bakes each part once.
  - [ ] 6c. The part baker in Lobster (the procedural 3D models, the Blender models converted, the pixel pass):
        Godot no longer needed. Then generation in play: price-by-simulation at race creation, races mid-match.
- [ ] Archive

## Results

- 2026-10-26 (6a): two races from prompts in about 3 ms and the match start in about 3 ms, in the game; frames from the
  Lobster-made start and from the GDScript scenario are byte-identical at tick 101.

- 2026-10-26: the first match in a Lobster window (rats v frogs on flat_test, the bot on both sides when watching):
  `archive/images/2026-10-26/01-lobster-game-first-frame.png`, `02-lobster-game-rat-raid.png`. The sim and both
  bots take 0.35 ms a tick in the game; frames hold 60 fps with the whole match drawn.
