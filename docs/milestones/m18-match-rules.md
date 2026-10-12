# Milestone 18: Match rules

**Status:** planned (proposed 2026-10-12; small, can start any time)
**Exit criterion:** the lobby offers a handful of match rules, each a data switch the sim and AI
respect, each tested; Dominic plays two of them and they change how the match feels.

Dominic (2026-10-12): "match rules we can start to move on, yes."

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

## Plan
1. The rules contract (a `mutators` list on the match, applied at world setup and in the AI).
2. Lobby UI: a rules card with toggles, saved with the replay.
3. Each rule with a headless test and a bot check.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Rules contract
- [ ] 2. Lobby card
- [ ] 3. The first rules
- [ ] Archive: pictures taken along the way, journal, decisions, timeline
