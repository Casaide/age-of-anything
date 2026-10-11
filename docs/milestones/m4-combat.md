# Milestone 4: Combat

**Status:** plan written (2026-10-11), waiting for Dominic's OK
**Exit criterion:** Blind testers predict counters from silhouettes.

## Scope
Melee/ranged attack, armour, HP, counter-tag bonuses, sim-side hitscan + cosmetic projectile,
death animation, and the unit card (recipe, derived stats, tags).

Not in this milestone: the AI's attack waves and counter-picking (milestone 6), fog (7),
hit-flash polish and SFX (7), Blacksmith upgrades and research (5 / Next), split melee and
pierce armour (backlog), formations, siege.

## Plan

### Data first
- **`rules/*.json` gets a `combat` block** (ints only, like `economy`):
  - reload ticks for melee and ranged (20 and 30 to start);
  - melee reach (milli-tiles past the two radii);
  - sight range for picking targets automatically (6 tiles);
  - minimum damage (1);
  - how often units look for targets (every 10 ticks, staggered by id).
- **Damage** = max(min, attack + the sum of the attacker's `bonus` for every tag the target has
  − armour). Bonuses already live on the parts (spear +large, sling/blowgun/pilum +archer,
  bow/crossbow +infantry, lance +ranged), so the counter web comes from data.
- **The missing edge of the web:** the design says mounted beats archers and skirmishers, but
  today only the lance carries that bonus. Mount bodies (pony, beetle, spider) get
  `stats.bonus: {"ranged": 3}`, and `pricing.gd` starts collecting body and mount-body bonuses
  (today it only reads gear). This changes derived stats, not recipes, so race keys stay put.
- **Buildings** keep their `hp` and get an `armour` in `buildings.json`, so units can attack them.

### Sim (`src/sim/combat.gd`, integers only, no Nodes)
- **Unit types** carry attack, armour, range (milli-tiles), reload, and bonus and tags as
  sorted int arrays (tag names mapped to indices once, at setup), so damage is a loop over
  ints.
- **New per-unit arrays** in `units.gd`: attack target (a unit or building id), cooldown and
  stance (an explicit order or auto).
- **Commands:**
  - `ATTACK {ids, target}`: attack a unit or a building.
  - `ATTACK_MOVE {ids, x, y}`: walk there and fight whatever comes into sight on the way.
    Tests and the AI need this; the player gets it on A + right-click.
  - MOVE still means move: units on a plain move don't stop to fight.
- **Each tick:** combat runs after worker jobs and before movement.
  - Idle military units and attack-movers pick the nearest enemy in sight, then the lowest id
    as a tie-break, using the spatial buckets. Workers don't pick targets by themselves, but they
    can be ordered to attack.
  - In range, a unit stops, attacks when its cooldown is up, and the damage lands at once
    (hitscan).
  - Out of range, it chases: straight steering when close, otherwise a flow field to the
    target's cell. It re-aims on re-plan ticks.
  - Units that are attacked and idle fight back.
- **Death:** hp ≤ 0 removes the unit (ids stay sorted) and frees its pop; a destroyed building
  frees its footprint and bumps the map version. Anything targeting the dead unit or building
  looks for a new target.
- **Events for the view:** every tick, `world.events` lists attacks (attacker, target, damage,
  ranged or not) and deaths (id, position, owner, type). The view reads them; the sim never
  reads them back, so they stay out of the hash.
- **The hash** covers hp, cooldowns, targets and stances.

### View (`scenes/sim_debug`, plus `UnitView`)
- **Orders:**
  - Right-click an enemy unit or building to attack it (the smart command gains ATTACK).
  - A + right-click attack-moves.
  - F7 sets up a test battle: two armies on opposite sides, attack-moving into each other.
- **Attack animation:** units face their target and lunge (the existing flourish) on every
  attack event.
- **Projectiles (cosmetic):** arrows and javelins fly in an arc, stones and darts fly flat,
  crossbow bolts fly fast. The projectile picked depends on the weapon's tags, and its flight
  time on distance. Damage has already landed in the sim, so the impact is decoration.
- **Hit flash:** a short white flash when a unit takes damage, and HP bars over damaged or
  selected units.
- **Silly death poses:** when the sim removes a unit, its view becomes a ghost. The ghost tips
  over (on its back for bodies, on its side for mounts), its gear drops a little, and it fades
  out over about 2 s. The pose is picked deterministically from the unit id, though only for
  looks.
- **The unit card** in the panel for a selected unit:
  - the unit drawn large, its name and its recipe (parts);
  - hp, attack, armour, range, speed and cost;
  - its tags, plus a plain line built from bonuses and the tag web, e.g. "Strong vs large and
    mounted. Weak vs archers."
- **Rendering:** the debug view keeps the placeholder style for now (the art goes in with the
  vertical slice). The quiz below uses the pixel art, because silhouettes are what's being
  tested.

### Exit check: "blind testers predict counters from silhouettes"
- **`tests/counter_quiz.gd`** (needs a display): shows pairs of units from generated races in
  the pixel-art style, with no names or stats. The tester picks which one wins a fair fight
  (equal cost). Their answers are scored against headless fights run in the real sim. Dominic
  (and anyone he hands it to) is the blind tester; the target is ≥ 75% right.
- **Automated stand-in, in `tests/test_sim.gd`:** a counter matrix. For frogs, rats and four
  generated races (centaur Romans, Greek folk, royal knights, beetles), equal-cost groups
  fight:
  - spear vs large;
  - large vs archer;
  - archer vs spear (infantry);
  - skirmisher vs archer.
  Each counter must win, both ways round and on both sides of the map. This also catches
  pricing that makes a counter fail. Where one does fail, we tune the data (bonuses, points),
  never special-case code.

### Tests
- **Determinism:** a recorded battle replays to the same hashes, and a battle is added to the
  10-minute match.
- **Damage maths:** unit checks on the formula, bonuses, the minimum and armour.
- **Behaviour:** chasing works; killing a target picks the next one; buildings take damage,
  and a destroyed one frees its footprint; dead units free their pop.
- **Performance:** a 200-unit battle stays under the 3 ms tick budget (we're at ~0.9 ms now).

### Questions for Dominic (Claude's defaults in brackets)
1. Attack-move now, or leave it for the AI milestone? [Now: the tests need it, and it's small.]
2. One armour value now, with split melee/pierce armour later? [Yes: one value; split goes to the
   backlog.]
3. Workers: fight back when hit, or flee? [Fight back only if ordered; otherwise keep working.
   Fleeing is AI-milestone material.]

## Checklist
- [ ] Plan approved
- [ ] Data: `combat` rules block, building armour, mount-body bonuses (+ pricing reads them)
- [ ] Sim: unit combat stats, ATTACK / ATTACK_MOVE, targeting, chase, hitscan damage, death, events
- [ ] Sim: attacking and destroying buildings
- [ ] Tests: damage maths, behaviour, battle determinism, counter matrix, 200-unit battle tick
- [ ] View: attack orders (right-click, A + right-click), F7 battle setup
- [ ] View: lunge and facing, cosmetic projectiles, hit flash, HP bars
- [ ] View: silly death poses
- [ ] View: unit card (recipe, stats, tags, strong/weak line)
- [ ] Exit check: `tests/counter_quiz.gd`, Dominic plays it
- [ ] Archive: pictures along the way, journal, decisions, timeline

## After this milestone
- **Full review of the art assets (Dominic, 2026-10-11):** every unit part, building, prop,
  texture and the terrain, judged in the pixel-art candidate before the art direction is locked.
  (An independent agent review was also run at the end of the art round, before this milestone.)
