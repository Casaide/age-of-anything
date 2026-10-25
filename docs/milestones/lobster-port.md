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

- [ ] 1. Rest of the sim
- [ ] 2. Match pack
- [ ] 3. Game shell
- [ ] 4. Playing
- [ ] 5. Feel
- [ ] 6. Setup in Lobster
- [ ] Archive

## Results

(none yet)
