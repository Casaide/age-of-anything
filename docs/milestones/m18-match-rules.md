# Milestone 18: Match rules, saving and stats

**Status:** planned (proposed 2026-10-12; small, can start any time)
**Exit criterion:** the lobby offers a handful of match rules, each a data switch the sim and AI
respect, each tested; Dominic plays two of them and they change how the match feels; a match can be
saved and loaded mid-game (against the AI) and resumes exactly; the end of a match shows its stats.

Dominic (2026-10-12): "match rules we can start to move on, yes."

Game modes start in milestone 16 (Fortress, Siege), on this milestone's rules contract; if 18
isn't done by then, 16 builds the contract.

Host rules already exist (`data/rules/*.json`: era, budgets, Full tech tree, No restrictions,
animals). Match rules are more of the same: switches on a rules file, picked in the lobby.

## First set (pick 4-6)
- **Giant mode:** every unit scale 140 (the giant tags and pricing already exist).
- **Everything costs wood** (or a chosen resource): one-resource economy, fast and silly.
- **Regicide:** each side has its hero (milestone 14); lose it, lose the match.
- **Fast start / Rich start:** age 2 and a town to begin with; or big stockpiles.
- **No rush:** no attacks on buildings before minute N.
- **Fog off / Explored map.**
- **Wonder race:** the Wonder's timer halved, Wonders cheaper.
- **Mirror match:** both sides play the same prompt.

## Saving and loading (Dominic, 2026-10-13: "We also need game save and load added")
- Save a match against the AI from the pause menu (a few slots plus an autosave), load it from the
  title screen or lobby; it resumes exactly where it was: same tick, same hash.
- The sim is deterministic and driven by commands, so a save can be the replay (races, rules, map,
  seed, the command log) plus a snapshot of the World for fast loading (re-simulating a long match
  would be slow); the load check compares the snapshot's hash with a re-simulated one in tests.
- What isn't sim state (the camera, selections, control groups, the UI size) goes in the save too.
- Versioned: a save from an older build says so instead of loading wrong.

## Post-game stats (Dominic, 2026-10-13: "And post game stats")
- At the end (and from the pause menu during a match): per player, units trained and lost, kills by
  unit type, buildings built and lost, resources gathered and spent over time (a graph), age-up times,
  research done, the army's size over time, the biggest battle; a short timeline of the match's moments.
- The sim emits the events already; a stats recorder (view side, or deterministic in the sim if the AI
  should read it) collects them; the end screen in milestone 19's look shows them (m19 step 5's "match
  story").

## Plan
1. The rules contract (a `mutators` list on the match, applied at world setup and in the AI).
2. Lobby UI: a rules card with toggles, saved with the replay.
3. Each rule with a headless test and a bot check.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Rules contract
- [ ] 2. Lobby card
- [ ] 3. The first rules
- [x] 4. Save and load: built on its own (2026-10-16, `save-load.md`: snapshots of the world and the bots, D-140 to D-142)
- [ ] 5. Post-game stats (recorder, end screen with graphs and the match's timeline)
- [ ] Archive: pictures taken along the way, journal, decisions, timeline
