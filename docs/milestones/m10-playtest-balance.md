# Milestone 10: Playtest + balance

**Status:** prepared (2026-10-11); waiting on Dominic: testers, an export build, sign-offs
**Exit criterion:** The success metrics in `../mvp-plan.md` §4.

## Scope
5-10 testers, balance pass, itch.io build.

## Plan (2026-10-11, Claude)
1. **Balance tooling:** `tests/balance.gd` runs every soldier of five races against every other at
   equal cost in a given age and lists win rates, outliers first (the cost-sanity metric: none more
   than 20% off the mean).
2. **Balance pass through data:** prices of the outliers' parts, flat worker prices, the Town Center.
3. **Pacing:** bot matches as a guide (`tests/test_ai.gd`), the real numbers from testers.
4. **Playtest kit:** `docs/playtest.md` (what to watch, questions), a match log the game writes.
5. **Build:** an itch.io export; needs Godot's export templates (waiting on Dominic).
6. **Testers:** 5-10, run by Dominic.

## Checklist
- [x] Plan
- [x] Balance tool (`tests/balance.gd`)
- [x] Balance pass 1 (data): beetle, pony, spider and bow prices; workers one price; Town Center
- [ ] Cost sanity: 11 of 20 units still more than 20% off the mean (see Results)
- [x] Playtest kit and match log
- [ ] Export build (**waiting on Dominic**: export templates, itch account)
- [ ] 5-10 testers; metrics from `../mvp-plan.md` §4 (**waiting on Dominic**)
- [ ] Determinism across macOS and Linux (needs a Linux machine)
- [x] Archive

## Results (balance pass 1, 2026-10-11)
- **Counters:** 91% of equal-cost counter fights go to the counter (target 75%; was 84-86%).
- **Cost sanity** (`tests/balance.gd`, age 2): 13 of 20 units were more than 20% off the mean; 11
  after the pass. The extremes are gone: the beetle spearman no longer wins all 19 fights (100% to
  ~80%), and the worst archer went from 15% to ~26%. Hand-tuning trades one outlier for another
  (each unit plays 19 fights, so one fight is ~5%). The planned fix is price-by-simulation
  (backlog): let the tool adjust part points until the table is flat. Archers stay weakest: with
  no kiting, spearmen close the gap.
- **Workers cost the same for every body** (`rules.cost.worker`, still scaled by a creature's
  economy): a centaur worker cost 75 against a frog's 25 and crippled the centaurs' start.
- **Pacing:** bot vs bot now runs 13-18 minutes (median ~14) with the AI keeping a small guard
  while it saves for an age; it was 10:50 before workers got one price. Testers decide whether
  that's long; the levers are data (`data/ai.json` waves, `data/buildings.json` Town Center hp).
- Performance: 17 draw calls with 200+ units; sim tick ~1 ms (budget 3 ms).
