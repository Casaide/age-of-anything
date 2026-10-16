# Save and load

**Status:** built 2026-10-16 (Dominic asked for it mid-session during milestone 20); waiting on his choices below
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
differently goes on from wherever the re-run got to and says so in a line on screen.

- `src/save_game.gd`: `record` / `save` / `load_file` / `list` / `problem` (a race, map or rules that no longer
  rebuild) / `begin` (snapshot or start over) / `run` (play forward in budgeted slices) / `drift`.
  It lives outside `src/sim/` because it reads the wall clock to slice a re-run across frames.
- Bots' own commands are not stored (they give them again on a re-run); a person's are, including ones issued
  but not yet run. Bot seats record the player's next seq when the bot took over, so commands from before (a
  test army) stay the player's.
- What the screen needs back rides along in the save's `view`: the side you command, the lobby's choices (prompts,
  rerolls, teams, AI levels, map, mode), race names for the list, the camera, control groups, the tip step.
- Files: `user://saves/<date>_<time>.save`, a zstd-compressed Godot binary variant (about 400 KB at 4 minutes).
  A new file every save; nothing is overwritten or deleted.
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
- [ ] Dominic's choices (below)
- [ ] Try it on the Deck
- [x] Archive

## Open for Dominic

- **Slots or a list?** Built: a new save each time, newest first, none deleted. Alternatives: a few fixed slots
  that overwrite, or a delete button on the list.
- **Autosave?** Not built. Could save every few minutes and on quitting to the menu, keeping the last one or two.
- **Saves across game updates?** Built: a save keeps loading as long as its races, map and rules rebuild the same;
  after a sim change it re-runs the match (slow) and may go its own way. The other choice is to refuse saves from
  another version outright.
