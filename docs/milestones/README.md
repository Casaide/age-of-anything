# Milestones

One file per milestone: status, exit criterion, scope, plan, results and anything that changed
along the way. The overview table lives in `../mvp-plan.md` §3; these files hold the detail.

| # | File | Status |
|---|---|---|
| 0 | [Race generation](m0-race-generation.md) | done 2026-10-10 |
| 1 | [Sim core](m1-sim-core.md) | done 2026-10-10 |
| 2 | [Map + movement](m2-map-movement.md) | done 2026-10-11 |
| 3 | [Economy](m3-economy.md) | built; exit check: Dominic watches an opening |
| 4 | [Combat](m4-combat.md) | sim, view and quiz built; waiting on the quiz run and the unit card |
| 5 | [Art rework](m5-art-rework.md) | built; waiting on Dominic's look sign-off |
| 6 | [Foundations](m6-foundations.md) | done 2026-10-11 |
| 7 | [Progression](m7-progression.md) | done 2026-10-11 |
| 8 | [AI + match flow](m8-ai-match-flow.md) | planned |
| 9 | [Fog + juice](m9-fog-juice.md) | planned |
| 10 | [Playtest + balance](m10-playtest-balance.md) | planned |
| - | [Art pass](art-pass.md) | direction chosen, vertical slice done |
| - | [Art and UI track](art-ui-track.md) | A1 = milestone 5; later stages run alongside milestones 7-10 |
| - | [Networking](networking.md) | planned (after the demo) |

## How to use these

- **Before starting** a milestone: read its file, then write the plan into it (approved by
  Dominic) before writing code.
- **While working:** tick the checklist, and note any scope moved in or out (with where it went:
  another milestone or `../backlog.md`). Take archive pictures as things become visible (see
  CLAUDE.md "The archive").
- **When done:** set the status and date, record the measured exit criterion under Results, and
  update the status column here and in `../mvp-plan.md` §3. The story goes in `archive/journal/`.

## Template

```markdown
# Milestone N: Title

**Status:** planned | in progress | done (YYYY-MM-DD)
**Exit criterion:** ...

## Scope
## Plan
## Checklist
- [ ] ...
- [ ] Archive: pictures taken along the way, journal, decisions, timeline
## Results
## Changes from the original plan
## Links
```
