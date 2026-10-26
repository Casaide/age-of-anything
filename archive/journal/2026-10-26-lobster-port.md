# 2026-10-26: the whole game in Lobster

## What happened

Dominic, after the spike: "Port it all. I want to see if we can get as far as me playing a game on macos", and then,
asked how, "All Lobster" (a Lobster game, not a Lobster sim inside the Godot game). Claude wrote the plan into
`docs/milestones/lobster-port.md` and worked through the night.

**The rest of the sim**, every piece checked tick by tick against GDScript the same way as the spike: shift-queued
orders, STOP, CANCEL, drop-off, surrender; markets, trade carts, repair; animals and pens; map bridges; siege weapons
(minimum range, packing, splash, bolts, sappers); Wonders and the Siege mode; gates (each team gets walk lanes of its
own), diagonal gates, rubble; walls you stand on (stairs, ladders, docked siege towers, walkways, falls, pours); race
abilities (webs, sticky hits, wading); worn trails. And the bots' sides of all of it: herding and hunting, pens,
trading and carts, engines, Wonders, manning and storming walls, webs. New scenarios: a seeded person's orders on top
of two bots ("play"), age-3 sieges, a walled town stormed, matches from age 3, the Siege mode on Siege Vale, spiders
against frogs. Lobster's port is now about 11,000 lines.

**The game**: a Godot tool (`art_pack.gd`) bakes the match's races with the game's own art kit and renders every unit
type through `UnitView` in 8 directions and every state (idle, 16 walk frames, attack, each job, carrying each load,
the fall) into PNG sheets with a plain index, plus every building, prop and doodad bake, names, team colours, voices
and sound picks. `game.lobster` draws it all (a shader recolours the team key), runs the sim at 20 Hz with the
ported bot on the other side, and takes orders by mouse and keys: select, drag-select, move, attack(-move), gather,
build, repair... train, research, age up, rally, shift-queue; a minimap, fog, sounds and creature voices, health bars,
shots, hit flashes, the win banner. `make_pack.sh [map] ["race" "race"]` makes a pack; `play.sh pack` plays it.

## Decisions

- The art stays Godot-baked for now: the units are procedural 3D models (about 10,000 lines) plus Blender models,
  and porting the baker changes nothing you see. Godot is the game's asset tool; the game runs in Lobster.
- Race generation from prompts also stays in Godot for now (the pack tool runs it); porting the generator, pricing and
  identity only pays once the baker moves too. Dominic's call.

## Funny moments / bugs

- The first Lobster window showed nothing at all: macOS doesn't hand a frame to a window with vsync on while the
  display sleeps (03:00). Captures now run without vsync.
- Then a black screen with a HUD: the camera was edge-scrolling away at full speed, because a mouse outside the
  window reads (0, 0), the top-left corner.
- `gl.origin()` reads the transform's origin; it doesn't reset it. The HUD was drawn far off in the world.
- Units up on walls were half a tile out: separation's last pass still nudged them off the "blocked" wall cells.
- The defending bot sent its archers off its own wall to chase a raid: GDScript's respond leaves units up on a wall
  where they are (they shoot from there). Found by the Siege mode with Lobster's bots.
- Lobster bots answered sheep: GDScript counts meat on the hoof as wild food when deciding farms.

## Pictures

`archive/images/2026-10-26/`: the first frame (01), a rat raid on the frog town (02), sheep penned (03).

## Ideas parked

- The Godot terrain shader's look in Lobster (paths, water, cliffs); music stems; control groups; a proper panel.
- Porting the generator and pricing (and one day the baker) for a lobby that runs without Godot.
