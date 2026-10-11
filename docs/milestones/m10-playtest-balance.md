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
- [x] Balance pass 1 (data): beetle, pony, spider and bow prices; Town Center; a price tuner (`tests/tune_points.gd`)
- [ ] Cost sanity: 10 of 20 units still more than 20% off the mean; the rest is archers, a mechanics fix (see Results)
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
- **Workers** (D-078, Dominic): costs vary with the body; a creature's economy pays it back
  (centaurs carry 160% a trip). A flat worker price (D-076) was tried and reverted.
- **Price tuner** (`tests/tune_points.gd`): nudges part points until the round robin is flat;
  it took the table from 11 to 6 outliers but broke counters (67%) by making bows nearly free.
  With bows restored: 10 outliers, counters 91%. Next: give the tuner the counter check as a
  constraint, and let archers keep their distance (with no kiting, spearmen always close the
  gap, so no price makes archers both beat infantry and lose to their counters).
- **Pacing:** bot vs bot now runs 13-18 minutes (median ~14) with the AI keeping a small guard
  while it saves for an age; it was 10:50 before workers got one price. Testers decide whether
  that's long; the levers are data (`data/ai.json` waves, `data/buildings.json` Town Center hp).
- **Archers keeping their distance** (`rules.combat.kite_gap`, off by default; built to test,
  not adopted): ranged units that just fired step back from a closing melee foe. Measured with
  `tests/balance.gd -- 2 kite_gap=N`: 1.5 tiles left the table at 10 outliers, 2.5 tiles made it
  12. Spearmen move as fast as archers, so stepping back costs shots. Archers' weakness needs a
  different lever (range, speed, or the roster's counter design); a call for Dominic.
- **Centaurs vs frogs runs long** (~22 minutes in bot play): expensive centaur workers and
  soldiers make small armies. Balance item; the AI test allows 30 minutes (it guards against
  stalemates, not pacing).
- Performance: 17 draw calls with 200+ units; sim tick ~1 ms (budget 3 ms).
