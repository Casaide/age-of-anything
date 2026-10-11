# Milestone 7: Progression

**Status:** planned
**Exit criterion:** Age-up lands at minutes 4-6.

## Scope
Barracks (spear, skirmisher, archer), Stable (age 2 large unit), Watchtower (age 2), one
age-up at the TC ("Muck Age -> Stick Age", ~400F/200W, 60 s), one research ("Sharp Sticks",
+1 attack to `spear` parts). Note: the fixed-point cost table already landed in milestone 1.

## Design notes for the plan (Dominic, 2026-10-11)
- **Upgrades change how units look.** This differs from the genre, where an upgrade only changes
  numbers. An upgrade swaps parts in the unit's recipe: an armour line goes leather -> mail ->
  plate, a weapon line goes reed spear -> bronze -> iron pike. Stats already come from parts, so
  the numbers follow, the unit visibly changes, and existing art is reused (a frog with top
  armour wears the knights' plate, if frogs can unlock it at all).
- **Per-race paths:** each race's upgrade path picks parts within its culture and era first
  (theme guards and signature kit, as the generator does), falling back to generic kit. How far
  each race goes depends on this milestone and the post-MVP tech tree.
- **Sim:** an upgrade is a command. It re-prices the player's unit types from the new recipes
  (integer pricing, deterministic) and applies to existing units too, as the genre does. Recipes
  stay strings and ints, so replays and race keys are unaffected (the race key is the starting
  recipe).
- **View:** the art kit pre-bakes each race's upgrade parts at match start, or bakes them on
  demand, so an upgrade never stalls a frame.
- "Sharp Sticks" (+1 attack to spears) can be the first instance: a better spearhead part.
- **Restrictions in layers** (design.md §6): era (host rules), culture and theme, and the race's
  tech tree, plus a "Full tech tree / No restrictions" host option that lifts culture and tech
  limits (frog musketeers with "Anything goes"). Plan the tech tree data so each layer is a
  filter that can be switched off.

## Plan
(write before starting; see the template in `README.md`)
