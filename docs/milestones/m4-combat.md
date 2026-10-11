# Milestone 4: Combat

**Status:** in progress (plan approved 2026-10-11, with armour classes; see below)
**Exit criterion:** Blind testers predict counters from silhouettes.

## Scope
Melee/ranged attack, armour, HP, counter-tag bonuses, sim-side hitscan + cosmetic projectile,
death animation, and the unit card (recipe, derived stats, tags).

Not in this milestone: the AI's attack waves and counter-picking (milestone 6), fog (7),
hit-flash polish and SFX (7), Blacksmith upgrades and research (5 / Next), formations, siege.

## Plan

### Data first
- **`rules/*.json` gets a `combat` block** (ints only, like `economy`):
  - reload ticks for melee and ranged (20 and 30 to start);
  - melee reach (milli-tiles past the two radii);
  - sight range for picking targets automatically (6 tiles);
  - minimum damage (1);
  - how often units look for targets (every 10 ticks, staggered by id).
- **Armour classes (Dominic: do all armour types now, so nothing important gets missed).**
  This is the genre's model:
  - **Attack:** every attack has a base type, `melee` or `pierce` (a weapon's `damage` field; it
    defaults to melee), plus bonus classes (`bonus`, keyed by tag: spear +large, sling +archer,
    lance +ranged, club +building, and so on).
  - **Armour:** every unit has armour per class, `{"melee": m, "pierce": p, ...}`, summed over
    its parts. It can also hold armour against a bonus class (e.g. `"large": 2` blunts spear
    bonuses), so elite resistances need data, not code.
  - **Classes a target belongs to:** melee and pierce always, plus every one of its tags, plus
    `building` for buildings.
  - **Damage** = max(minimum, Σ over the attack's classes that the target belongs to of
    max(0, attack[class] − armour[class])).
  - **Data:** parts' `armour` becomes a dict. Shields lean to pierce, mail and plate cover both,
    helmets add a little of each. Ranged weapons get `"damage": "pierce"`. Blunt weapons get a
    building bonus. Buildings get high pierce armour, so arrows barely scratch them.
  - Derived stats only: race keys don't change.
- **The missing edge of the web:** the design says mounted beats archers and skirmishers, but
  today only the lance carries that bonus. Mount bodies (pony, beetle, spider) get
  `stats.bonus: {"ranged": 3}`, and `pricing.gd` starts collecting body and mount-body bonuses
  (today it only reads gear). This changes derived stats, not recipes, so race keys stay put.
- **Buildings** keep their `hp` and get an `armour` in `buildings.json`, so units can attack them.

### Sim (`src/sim/combat.gd`, integers only, no Nodes)
- **Unit types** carry range (milli-tiles), reload, and two int vectors over a class table
  built once at setup (melee, pierce, then every tag and bonus name, sorted): the attack (base
  type + bonuses) and the armour, plus the set of classes the unit belongs to. Damage is then a
  loop over ints.
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
- **Damage maths:** unit checks on the formula: base types, bonus classes only against targets
  that have the tag, class armour blunting a bonus, the minimum, and buildings' pierce armour.
- **Behaviour:** chasing works; killing a target picks the next one; buildings take damage,
  and a destroyed one frees its footprint; dead units free their pop.
- **Performance:** a 200-unit battle stays under the 3 ms tick budget (we're at ~0.9 ms now).

### Decided with Dominic (2026-10-11)
1. Attack-move is in this milestone.
2. All armour types now (melee, pierce and per-class armour), not a single value.
3. Workers attack only when ordered; otherwise they keep working.

## Checklist
- [x] Plan approved (with armour classes)
- [x] Data: armour classes on parts and buildings, damage types, `combat` rules block, mount-body bonuses (+ pricing reads them)
- [x] Sim: unit combat stats, ATTACK / ATTACK_MOVE, targeting, chase, hitscan damage, death, events
- [x] Sim: attacking and destroying buildings
- [x] Tests: damage maths, behaviour, battle determinism, counter matrix, 200-unit battle tick
- [x] Attack-move spreads out (Dominic): targets weigh how many allies already fight them, and
  units leave a crowded foe for a free one, so 10 vs 10 becomes ten duels, and winners go and help
- [x] View: attack orders (right-click an enemy; Ctrl + right-click attack-moves, since A pans), F7 test armies
- [x] View: lunge and facing, cosmetic projectiles (arrows, bolts, javelins, stones, darts), impact
  sparks, health bars (a white hit flash needs the team shader: art track)
- [x] View: deaths: the body topples about its feet, darkens where it lies, goes in a puff of dust
- [ ] View: unit card (recipe, stats, tags, strong/weak line)
- [x] Exit check tool: `scenes/counter_quiz.tscn`: 12 equal-cost pairs in the pixel art, no labels,
  answered with 1/2 and scored against real headless fights (saved to user://counter_quiz.json)
- [ ] Exit check: Dominic (and anyone he hands it to) plays the quiz; target 75% right
- [ ] Unit card in the panel (recipe, stats incl. melee/pierce armour, tags, "strong vs / weak vs"),
  after the art track's panel rework is merged
- [ ] Archive: pictures along the way, journal, decisions, timeline

## After this milestone
- **Full review of the art assets (Dominic, 2026-10-11):** every unit part, building, prop,
  texture and the terrain, judged in the pixel-art candidate before the art direction is locked.
  (An independent agent review was also run at the end of the art round, before this milestone.)

## Results
- **Combat sim (2026-10-11):** `src/sim/combat.gd`.
  - A class table (melee, pierce, building, then every tag/bonus/armour name) with int attack and
    armour vectors per unit and building type.
  - Targeting (idle soldiers and attack-movers, every 10 ticks, nearest then lowest id).
  - Chasing: straight at the target when the line is clear, a flow field otherwise.
  - Simultaneous hits; deaths removed in descending slot order.
  - Buildings can be destroyed and free their footprint.
  - `world.events` (hits, deaths) for the view; `world.lost` per player.
- **Counter matrix:** 38 of 48 equal-cost fights (79%) go to the counter (target 75%). Misses, to
  tune with data later:
  - giant frog and rat brutes lose to massed archers (concentration: 1-2 big units vs a crowd);
  - rat slingers lose to archers;
  - centaur and beetle archers lose to spearmen (their "spear" units are large and armoured).
- **After tuning to the genre's norms (2026-10-11):**
  - Skirmisher kit +2 pierce armour; mounts more pierce armour (pony 3, beetle 4, spider 2);
    giants +3 pierce.
  - The matrix skips relations that don't apply (centaur and beetle spearmen aren't infantry).
  - 41 of 46 applicable fights (89%) go to the counter.
  - Still losing: rat brutes vs massed archers, a rat spear mirror, centaur archers vs centaur
    spearmen.
- **Speed:** a 200-unit pitched battle costs about 1.1 ms a tick (combat 0.35, separation 0.46).
  The scripted 10-minute match averages 1.5 ms (budget 3 ms). Single-tick spikes reach 5-12 ms;
  watch them.
