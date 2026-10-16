# Save and load

**Status:** built 2026-10-16 (Dominic asked for it mid-session during milestone 20); saves survive updates (D-141) and take the new stats (D-142)
**Exit criterion:** save mid-match, quit, load, and the match goes on with the same state hash as a match that
never stopped (a headless test proves it), and the screens work with a mouse and with a pad.

Nothing about saving had been decided before: the MVP plan cut save/load ("replays cover it"), and neither the
design doc, the backlog nor the decisions said anything more.

## Plan (Claude, 2026-10-16)

Two ways were weighed:

- **(a) A replay up to now.** Store the races (prompt + rules + reroll + key), the map, the rules, seed, teams and the
  command stream; to load, rebuild the start and play the match forward headless to the saved tick, the bots
  thinking as they did (they are deterministic), then check the state hash. Small, and correct by construction.
  But measured: late in a bot match the sim step costs 2 to 6 ms a tick on the Mac (the bots another 1), so
  loading a 20-minute match would take about 100 s on the Mac and longer on the Deck. Too slow on its own.
- **(b) Serialise the World.** Every system's state is plain data: parallel packed int arrays, dicts, a few
  Vector2i, sub-objects (units, buildings, map, spatial, flow fields, shots, rng, commands). A probe of the whole
  object graph after a bot match found no callables, no Nodes and no object held in two places, and the bots
  are the same kind of thing (Bot, EcoBot, Scout, Land, Expand, Reach). So a generic snapshot works: every script
  variable, sub-objects and all.

**Chosen: both, (b) first** (D-140). A save holds the snapshot and the replay. Loading builds the match as at its
start (every constructor runs with its real arguments), pours the snapshot over it and checks the state hash: about
0.1 s whatever the match's length. If the snapshot doesn't fit the build (a sim or AI variable came or went, or the
hash is off), it falls back to (a) and plays the match forward, with a "Catching up" note; a build whose sim plays
differently goes on from wherever the re-run got to and says so in a line on screen. *(Superseded the same day by
D-141: no fallback; a snapshot from any build loads. See "After game updates".)*

- `src/save_game.gd`: `record` / `save` / `load_file` / `list` / `problem` (a race, map or rules that no longer
  rebuild) / `begin` (the snapshot poured over a fresh match) / `merge`.
  It lives outside `src/sim/` because it reads the wall clock to slice a re-run across frames.
- Bots' own commands are not stored (they give them again on a re-run); a person's are, including ones issued
  but not yet run. Bot seats record the player's next seq when the bot took over, so commands from before (a
  test army) stay the player's.
- What the screen needs back rides along in the save's `view`: the side you command, the lobby's choices (prompts,
  rerolls, teams, AI levels, map, mode), race names for the list, the camera, control groups, the tip step.
- Files: `user://saves/<date>_<time>.save`, a zstd-compressed Godot binary variant (about 400 KB at 4 minutes).
  A new file every save; nothing is overwritten or deleted (Dominic: "we just keep them all for now").
- Screens: the pause menu gets **Save game** (it says "Saved (m:ss in)") and **Load game**; the lobby's title menu
  gets **Load game**. Both open the saves page (`src/view/ui/saves_page.gd`): the newest 8, one line each (races,
  map, time in, when saved); one this build can't rebuild says why and greys out. A pad walks it by focus, B
  goes back (and doesn't fall through into the battle). Loading hands the art kit on to a fresh match screen, as
  starting a battle from the lobby does.

## Checklist

- [x] Look for anything decided about saving (nothing)
- [x] Weigh (a) and (b), measure the re-run (too slow alone), probe the object graph (snapshot works)
- [x] `src/save_game.gd`: snapshot + replay, fallback re-run, drift
- [x] Headless test: `test_sim.gd -- part:save_load` (a 4-minute match against a hard bot, saved with an order
      still waiting, loaded both ways, played on 3 more minutes: hashes identical to a match never stopped)
- [x] Pause menu Save game / Load game, lobby Load game, the saves page
- [x] Windowed check through the screens with a mouse and a pad: `tests/save_check.gd`
- [x] Dominic: keep every save; saves must survive updates without replaying (D-141)
- [ ] Try it on the Deck
- [x] Archive

## After game updates (D-141)

Dominic: "we just keep them all for now. After game updates needs real though, replaying is bad." So the replay
fallback is gone: a save always loads from its snapshot, whatever build made it.

- The world is built fresh from the save's own races (merged over this build's regeneration of the same prompt, so
  new fields appear) and rules (merged over this build's rules file), then the snapshot is poured over it.
- Data tables (`SaveGame.DATA`: the World's unit types, buildings, tech, rules and configs, the bots' `cfg`) are
  merged: the save's values win, keys only this build has come in. An old match keeps its old balance.
- A variable added since keeps its constructor's value; units and buildings pad per-unit arrays to their count (0,
  or [] for lists). **When you add a per-unit field whose new-unit value isn't 0, or any variable whose fresh value
  is wrong mid-match, give that class `func after_load(missing: Array)`.** A variable dropped since is ignored; one
  whose type changed keeps this build's value; a sub-object whose class was replaced keeps this build's object.
- A load says what changed (`ld.changed`) and whether the state hash is the saved one (`ld.same`, always true for
  this build's saves).
- Test: `test_sim.gd -- part:save_load` fakes an older build's save (a unit field and world and bot variables
  missing, one extra, a data key missing, a class replaced) and plays it on a minute with its bot.

Size: about 380 KB at 5 minutes and 550-570 KB at 20-25 minutes (zstd; the snapshot is ~3 MB raw, mostly per-cell
map and fog arrays, and the command history is the part that grows). Saving takes 25-55 ms.

## New stats for old saves (D-142)

Dominic: "updated stats aren't something the save should worry about." A save is state; the stats come from the build
loading it (`SaveGame._build(rep, lib, true)`):

- the races are generated again from their prompts (their keys must match), the rules come from this build's file
  with the save's host choices (the mode) kept, and the data tables (`DATA`) are left as this build makes them;
- each player's unit types and building stats are worked out again from the research the save has (`Tech.retype`,
  `Tech.refresh`, as a game mode does at the start), units and buildings keeping their share of health; animals by
  hand; engines standing at speed 0 to pack or unpack still do.
- This needs the tables to line up (`_layout`): the same rosters, buildings, research, resources and armour classes in
  the same order, because state points into them by place. Buildings are sorted by id and line upgrades are made per
  building, so a new building or research usually shifts them: such a save loads **frozen** on its own stats
  (D-141's way). `ld.migrated` says which.
- Test: `part:save_load` halves every unit type's and building's health in a save (a build with other stats): it
  migrates, types take this build's health, every unit keeps its share; a save with a building missing loads frozen.

**Next step, if wanted:** remap by id (building kinds, unit kinds, research bits, queue entries, rubble, garrison
records, hero arrays, fog memories, the bots' notes) so saves keep migrating across added or removed content.

## Still open

- **Autosave:** not built. Could save on quitting to the menu and every few minutes.
- **A delete button** for the saves page, once the list gets long.
