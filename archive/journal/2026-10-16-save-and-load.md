# 2026-10-16: Save and load

**Milestone:** none of its own (asked for during milestone 20); see `docs/milestones/save-load.md`
**Who:** Dominic asked; Claude (Claude Code, a session started by another session) built it

## What happened
Dominic asked for save/load mid-session while the Deck bugs were being worked on. Nothing had been decided about it
before; the MVP plan had cut it because "replays cover it".

- **The replay way first.** The sim is deterministic and command-driven, so a save could be a replay up to now: load
  it by playing the match forward headless, bots thinking as they did. It worked first time (hashes identical to a
  match never stopped) and was too slow: profiling a bot match, the sim step alone is 2 to 6 ms a tick in the
  middle game, so loading 20 minutes would take about 100 s on the Mac.
- **Then the snapshot.** A probe walked the whole World and both bots: ints, packed arrays, data dicts, a few
  Vector2i, a dozen sub-objects, no callables or Nodes or shared objects. So the snapshot is generic: every script
  variable, recursively, poured back over a match built fresh (so constructors that take arguments run normally).
  390 KB at 4 minutes, saved in 24 ms, loaded in about 100 ms. The replay stays in the save as the fallback for a
  build the snapshot no longer fits (D-140).
- **The screens.** Save game and Load game in the pause menu, Load game on the lobby's title menu, one saves page
  for both. `tests/save_check.gd` walks it with the buttons and with a pad (real pad events), and from the lobby.

## Pictures
- `images/2026-10-16/15-save-pause_menu_saved.png`: the pause menu just after Save game
- `images/2026-10-16/16-save-saves_page_pad.png`: the saves page on a pad, the newest save focused
- `images/2026-10-16/17-save-lobby_saves.png`: Load game from the lobby

## Decisions
- D-140: snapshot + replay fallback; a new file per save.

## Funny moments / bugs
- B on the saves page closed the page during input, then the battlefield's pad code saw the same B a moment later
  with the page gone and closed the pause menu too, unpausing the match. Fixed with a closed-on-this-frame guard (the
  tech tree had the same trick).
- Reopening the saves page put the pad's focus on a button that was already queued for deletion (queue_free leaves
  it in the list until the frame ends), so A loaded the old save's ghost.

## Ideas parked
- Slots vs a list, autosave, refusing saves from another version: Dominic's call (the milestone file).
