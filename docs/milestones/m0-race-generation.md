# Milestone 0: Race generation

**Status:** done (2026-10-10)
**Exit criterion:** prompts give stable, readable armies; tests pass.

## Scope
Data contract (`data/`), prompt -> brief -> race generator, pricing from parts, the composer
(recipe -> animated Node2D), and the Race Lab (`scenes/race_lab.tscn`) as the main scene.

## Results
- Met. Same prompt + rules + reroll gives the same race key everywhere; `tests/run_tests.gd`
  runs ~10,000 checks.
- Frogs vs Rats, centaur Romans vs winged Greeks, and silly prompts all produce readable armies.

## Changes from the original plan
- The research plan said to cut the prompt generator from the MVP; we built it first instead (D-011).

## Links
- Journal: `archive/journal/2026-10-10-from-industry-chat-to-race-lab.md`
- Decisions: D-001 to D-018
