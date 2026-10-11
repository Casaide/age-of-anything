# Milestone 7: Progression

**Status:** done (2026-10-11)
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
Builds on milestone 6's ages and research system (`data/tech.json`, `src/sim/tech.gd`) and
its unit lines.
1. **Buildings (data):**
   - Barracks (age 1; trains spear, skirmisher, archer; hosts Sharp Sticks).
   - Stable (age 2; trains the large unit).
   - Watchtower (age 2; 1x1; shoots at enemies in range).
   - Each type has an `age`; building and training are age-gated (a unit's line says when its
     slot opens).
2. **Sim:**
   - Age checks in BUILD and TRAIN.
   - Buildings that attack (Watchtower: pierce arrows, range 7), using the combat code.
   - Sharp Sticks moves to the Barracks.
3. **Art:** Barracks, Stable and Watchtower for every architecture (thatch, junk, stone, tent),
   built like the existing buildings, with build stages and portraits.
4. **View:**
   - The panel trains whatever the selected building trains (with portraits).
   - Workers' build menu lists every building their age allows; hotkeys.
5. **The bot ages up:**
   - The economy bot builds a Barracks, saves for the age-up and clicks it.
   - Exit check: in the headless opening the bot reaches age 2 at minute 4-6 for frogs and rats
     (tuning costs and the bot, not special cases).
6. **Restriction layers** (D-070) in the tech data's shape: researches and lines can be filtered
   by culture/creature, and a host switch lifts it. Data shape only; content in milestone 10's
   balance pass.

## Checklist
- [x] Barracks, Stable, Watchtower in data; buildings and training age-gated
- [x] Towers shoot (combat code); Sharp Sticks at the Barracks
- [x] Art: the three buildings in every architecture, with build stages and portraits
- [x] Panel: trains whatever a building trains; the build menu follows the age
- [x] The bot builds a Barracks, saves and ages up
- [x] Restriction layers in the data's shape: research `only` (creatures/cultures), host rules
  `full_tech_tree` and `no_restrictions`
- [x] Archive

## Results
- **Exit criterion met:** with the economy bot playing, frogs reach age 2 at 5:21 and rats at
  4:21 (`tests/test_sim.gd`).
- **Pacing:** the genre's tool, not special cases. An age-up needs a building of the current age
  (a Barracks for age 2, a Stable for age 3), and age 2 costs 500 food and 200 wood and takes
  90 s. The rats' cheap, quick workers keep them a minute ahead, which is their identity.
- **Tests:** age gates, a Watchtower shooting, Sharp Sticks surviving an age-up, the frogs-only
  research and the host switches.
- **Pictures:** 57 (a rat junk town: Barracks with a training yard, Stable, stilt Watchtower) and
  58 (a Roman stone Watchtower).
- **Left for later (backlog / balance):**
  - more research;
  - a Blacksmith and its small visual tells (D-057);
  - the bot using the Stable and ageing to 3 (milestone 8);
  - tier-2 and tier-3 woodland kit.
