# Milestones

One file per milestone: status, exit criterion, scope, plan, results and anything that changed
along the way. The overview table lives in `../mvp-plan.md` §3; these files hold the detail.

| # | File | Status |
|---|---|---|
| 0 | [Race generation](m0-race-generation.md) | done 2026-10-10 |
| 1 | [Sim core](m1-sim-core.md) | done 2026-10-10 |
| 2 | [Map + movement](m2-map-movement.md) | done 2026-10-11 |
| 3 | [Economy](m3-economy.md) | done 2026-10-11 |
| 4 | [Combat](m4-combat.md) | done 2026-10-11 |
| 5 | [Art rework](m5-art-rework.md) | built; waiting on Dominic's look sign-off |
| 6 | [Foundations](m6-foundations.md) | done 2026-10-11 |
| 7 | [Progression](m7-progression.md) | done 2026-10-11 |
| 8 | [AI + match flow](m8-ai-match-flow.md) | closed 2026-10-11 (playtest moved to the backlog) |
| 9 | [Fog + juice](m9-fog-juice.md) | done 2026-10-11 |
| 10 | [Playtest + balance](m10-playtest-balance.md) | closed 2026-10-11 (testers, build, price-by-simulation moved to the backlog) |
| 11 | [Cleanup](m11-cleanup.md) | done 2026-10-11 |
| 12 | [The full land tech tree](m12-tech-tree.md) | closed for now 2026-10-13 |
| 13 | [Unit lines](m13-unit-lines.md) | in progress (siege, healers, trade carts, war beasts in play; costs by material, D-144) |
| 14 | [Race identity and heroes](m14-race-identity.md) | in progress (bonuses, research, lacks, the web, heroes done) |
| 15 | [Maps and land](m15-maps.md) | closed for now 2026-10-13 |
| 16 | [Sieges](m16-sieges.md) | in progress (every step built; concept picks and the archive left) |
| 17 | [Living towns](m17-living-towns.md) | done 2026-10-13 |
| 18 | [Match rules](m18-match-rules.md) | planned (small, any time) |
| 19 | [UI that feels like the game](m19-ui.md) | in progress (theme, loaders, lobby, portraits done; the review left) |
| 20 | [Steam Deck and controllers](m20-steam-deck.md) | in progress (pad controls, Deck builds, Deck fixes) |
| 21 | [Modability](m21-modability.md) | in progress (loader MVP, example mod, agent tooling done) |
| 22 | [Battle feel](m22-battle-feel.md) | planned (formations by role, counter targeting, attack lines, a Norse shield wall) |
| - | [Art pass](art-pass.md) | direction chosen, vertical slice done |
| - | [Art and UI track](art-ui-track.md) | A1 = milestone 5; later stages run alongside milestones 7-10 |
| - | [Networking](networking.md) | planned (after the demo) |
| - | [Save and load](save-load.md) | built 2026-10-16; Dominic's choices open |

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
