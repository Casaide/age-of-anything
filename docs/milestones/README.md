# Milestones

One file per milestone: status, exit criterion, scope, plan, results and anything that changed
along the way. The overview table lives in `../mvp-plan.md` §3; these files hold the detail.

| # | File | Status |
|---|---|---|
| 0 | [Race generation](m0-race-generation.md) | done 2026-10-10 |
| 1 | [Sim core](m1-sim-core.md) | done 2026-10-10 |
| 2 | [Map + movement](m2-map-movement.md) | done 2026-10-11 |
| 3 | [Economy](m3-economy.md) | planned |
| 4 | [Combat](m4-combat.md) | planned |
| 5 | [Progression](m5-progression.md) | planned |
| 6 | [AI + match flow](m6-ai-match-flow.md) | planned |
| 7 | [Fog + juice](m7-fog-juice.md) | planned |
| 8 | [Playtest + balance](m8-playtest-balance.md) | planned |
| - | [Art pass](art-pass.md) | planned (parallel) |
| - | [Networking](networking.md) | planned (after the demo) |

## How to use these

- **Before starting** a milestone: read its file, then write the plan into it (approved by
  Dominic) before writing code.
- **While working:** tick the checklist, and note any scope moved in or out (with where it went:
  another milestone or `../backlog.md`).
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
## Results
## Changes from the original plan
## Links
```
