# Roster template: the full unit and building plan

**Decision:** follow the genre's standard _role structure_ for classic 2D RTS games: a set of
production buildings, four ages, unit lines that upgrade through tiers, and a rock-paper-scissors
counter web. Players already know this structure, and that familiarity is what makes the
generated madness readable.

Roles, counters, age gating and building functions are standard game mechanics shared across
the genre. Names, art, UI, text and sounds are entirely our own, as is each race's take on every
slot (Reedspear Frog, Pilum-thrower Centaur...).

A slot is a **role + required tags + counters**. The generator picks parts that satisfy the
required tags. Upgrades within a line are the same recipe re-priced at higher tiers, with
better material and gear (bronze -> iron, +armour), not new units.

Legend:

- **MVP:** in the 10-minute demo.
- **Next:** first post-MVP content pass.
- **Later:** needs new systems (naval, mystics/conversion, trade, walls).
- **Parts gap:** the parts kit has nothing that can fill the slot yet.

## Ages

| Age | Working name         | MVP              |
| --- | -------------------- | ---------------- |
| 1   | Muck Age             | yes              |
| 2   | Stick Age            | yes (one age-up) |
| 3   | Stone Age (name TBD) | Next             |
| 4   | Iron Age (name TBD)  | Next             |

## Resources

| Resource | Sources                                      | MVP                           |
| -------- | -------------------------------------------- | ----------------------------- |
| Food     | Bug bushes, hunting; farms and fishing later | yes                           |
| Wood     | Reeds/trees                                  | yes                           |
| Gold     | Shiny things                                 | Next                          |
| Stone    | Quarries                                     | Next (walls, castles, towers) |

## Units by building

### Town Center

| Line   | Slot     | Role / needs | Counters | Age | Status  |
| ------ | -------- | ------------ | -------- | --- | ------- |
| Worker | `worker` | worker tool  | -        | 1   | **MVP** |

### Barracks (infantry)

| Line                     | Slot              | Role / needs                   | Beats / weak to                                 | Age | Status                  |
| ------------------------ | ----------------- | ------------------------------ | ----------------------------------------------- | --- | ----------------------- |
| Swordsman line (3 tiers) | `infantry`        | melee, not spear (blade/blunt) | buildings, spears, skirmishers; weak to archers | 1   | **Built** (m13)         |
| Spear line (3 tiers)     | `spear`           | spear                          | beats large/mounted; weak to archers, infantry  | 2   | **MVP**                 |
| ~~Fast light infantry~~  | ~~`raider`~~      | -                              | cut as a line: raiders are unique-unit themes (Castle) | -   | Cut (Dominic, 2026-10-13); `data/later/raider_line.json` |

### Archery Range (ranged)

| Line                      | Slot             | Role / needs    | Beats / weak to                                     | Age | Status                                       |
| ------------------------- | ---------------- | --------------- | --------------------------------------------------- | --- | -------------------------------------------- |
| Archer line (3 tiers)     | `archer`         | bow             | beats infantry; weak to skirmishers, cavalry, siege | 2   | **MVP**                                      |
| Skirmisher line (2 tiers) | `skirmisher`     | ranged, not bow | beats archers; weak to infantry, cavalry            | 2   | **MVP**                                      |
| Mounted archer line       | `mounted_archer` | bow + mount     | beats infantry; weak to skirmishers, spears, cavalry | 2   | **Built** (m13); lacked by races whose archers already ride or with nothing to ride |
| Gunner                    | `gunner`         | gun             | beats infantry                                      | 4   | Later (gunpowder era)                        |

### Stable (mounts and beasts)

| Line                          | Slot                 | Role / needs                 | Beats / weak to                                                   | Age | Status                      |
| ----------------------------- | -------------------- | ---------------------------- | ----------------------------------------------------------------- | --- | --------------------------- |
| Light scout cavalry (2 tiers) | `scout`              | fast mount, light weapon     | beats skirmishers, healers, workers, siege; sees far; weak to spears | 2   | **Built** (m13); on foot where nothing carries the race |
| Heavy cavalry (3 tiers)       | `large`              | mount or Heavy/Giant + melee | beats archers, skirmishers; weak to spears, anti-cavalry, mystics | 3   | **MVP** (as the age-2 unit) |
| Anti-cavalry mount            | `anti_cavalry_mount` | mount + bonus vs mounted     | beats cavalry; weak to spears, infantry                           | 3   | Later                       |
| War beast                     | `war_beast`          | giant creature or huge mount | tanky vs buildings and infantry; weak to spears, mystics          | 3   | Later                       |
| Light lancer                  | `lancer`             | mount + reach                | beats ranged; weak to spears                                      | 3   | Later                       |

### Siege Workshop

| Line          | Slot           | Role / needs                       | Beats / weak to                                | Age | Status                |
| ------------- | -------------- | ---------------------------------- | ---------------------------------------------- | --- | --------------------- |
| Ram           | `ram`          | siege vehicle/beast, anti-building | beats buildings; weak to melee                 | 3   | Next (**parts gap**)  |
| Catapult line | `catapult`     | siege ranged, splash               | beats massed archers/infantry; weak to cavalry | 3   | Next (**parts gap**)  |
| Bolt thrower  | `bolt_thrower` | siege ranged, pierce               | beats infantry lines; weak to cavalry          | 3   | Later (**parts gap**) |
| Siege tower   | `siege_tower`  | carries units over walls           | -                                              | 4   | Later                 |
| Cannon        | `cannon`       | gun siege                          | beats buildings, siege                         | 4   | Later (gunpowder)     |

### Castle

| Line                    | Slot        | Role / needs                                              | Notes                                                         | Age | Status                |
| ----------------------- | ----------- | --------------------------------------------------------- | ------------------------------------------------------------- | --- | --------------------- |
| Unique unit             | `unique`    | the race's signature (prompt-driven, bigger point budget) | A theme from `data/uniques.json`: asked for, else the creature's, else the culture's; raiders (steppe, gutter rats, vikings, gloom) are themes | 3   | **Built** (m13)       |
| Long-range siege engine | `trebuchet` | long-range anti-building siege                            | Packs/unpacks                                                 | 4   | Later (**parts gap**) |
| Sapper                  | `sapper`    | suicide anti-building                                     | Frogs with fireworks                                          | 3   | Later                 |

### Temple

| Line   | Slot     | Role / needs     | Notes                              | Age | Status                              |
| ------ | -------- | ---------------- | ---------------------------------- | --- | ----------------------------------- |
| Mystic | `mystic` | healer/converter | Needs conversion and relic systems | 3   | Later (**parts gap**: staff, robes) |

### Dock

| Line            | Slot          | Notes         | Status        |
| --------------- | ------------- | ------------- | ------------- |
| Fishing boat    | `fisher`      | Water economy | Later (naval) |
| Transport       | `transport`   |               | Later         |
| Sea trader      | `sea_trader`  |               | Later         |
| Warship line    | `warship`     |               | Later         |
| Fire ship line  | `fire_ship`   |               | Later         |
| Demolition boat | `demo_ship`   |               | Later         |
| Cannon ship     | `cannon_ship` | Gunpowder     | Later         |

Naval craft are bodies too: lily-pad rafts for frogs, bottle boats for rats.

### Market

| Line       | Slot     | Notes                             | Status |
| ---------- | -------- | --------------------------------- | ------ |
| Trade cart | `trader` | Needs gold and multi-market trade | Later  |

## Variety: every army must look varied (Dominic, 2026-10-11)

"If a whole army ends up looking the same, the game will be terrible." Today a race is one
creature in different gear, plus a pony, beetle or spider as the mount. Planned sources of
variety, from biggest to smallest. Planning only: nothing here is built yet.

1. **Creature variants per line.** A creature family supplies different bodies for different
   roles, instead of only riding something. The data contract gains `variants` on a creature
   (line -> body/head/size/tags).
2. **Mounts that suit the family.** Each creature family has its own mounts (`rides` on the
   creature), not just the culture's ponies. Small creatures ride small beasts.
3. **Gear tiers by age** (milestone 6, D-057): light kit at age 1, bronze and mail, then iron and
   plate, within the culture.
4. **Unit-line upgrades:** spearman -> pikeman, a new silhouette per tier step.
5. **Culture kit:** helmets, shields, banners, capes and architecture.
6. **The blacksmith:** small visual tells only.

### Draft plan per creature type

Lines across: worker, spear, swordsman/infantry, skirmisher, archer, scout, heavy/large, war
beast, siege, unique. "Variant" means a different body. "Rides" means a mount.

| Family                             | Variants (by line)                                                                                                                               | Rides                                                                  | Gaps today                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------- |
| Frogs                              | tree frog (worker, scout), common frog (infantry, spear), dart frog (skirmisher: poison), bullfrog (heavy), giant toad (war beast)               | newts or salamanders (scout), beetles (heavy), lilypads on water?      | only one frog body; no newt     |
| Rats                               | mouse (worker, scout), rat (line infantry), sewer brute (heavy), giant rat or capybara (war beast)                                               | spiders (as now), cats as a joke war beast?                            | no mouse or brute body          |
| Spiders                            | house spider (worker), jumping spider (skirmisher, scout: leaps), wolf spider (infantry), **tarantula (heavy)**, trapdoor spider (sapper/ambush) | no mounts: the variants are the cavalry                                | one spider body; no tarantula   |
| Beetles                            | dung beetle (worker: rolls food), ladybird (skirmisher), stag beetle (spear: mandibles), rhino or Hercules beetle (heavy, war beast)             | **snails (slow, tanky), giant worms or caterpillars**                  | one beetle body; no snail, worm |
| Folk (humans)                      | by culture (legionary, hoplite, viking...)                                                                                                       | ponies, camels (desert), elephants (Mauryan India, Carthage), chariots | no camel, elephant, chariot     |
| Centaurs                           | foal (scout), centaur (line), armoured centaur (heavy)                                                                                           | fused (no mounts)                                                      | one body                        |
| Ponies                             | (mount only)                                                                                                                                     | -                                                                      | -                               |
| Future animals (backlog §8 roster) | bears (maul), beavers (dams), snakes (venom? catapults firing venom?), birds, elephants, tigers, pandas, crocodiles, capybaras, kangaroos        | per family                                                             | everything                      |

### Gaps this shows

- **Bodies:** the biggest gap. Most families need two to four variants, and each needs a model
  (unit_models.gd) and data.
- **Mount types:**
  - for small creatures: snail, worm, newt;
  - for cultures: camel, elephant, chariot.
- **Roles with no parts:** siege (every family needs its own take: a beetle-drawn ram, a frog
  catapult on a lily pad), mystics, scouts' light gear.
- **Data contract:** `variants` and `rides` on creatures; the generator picks a variant per line
  before gear. The race key covers it.

### Future packs (not the starter roster)

- **Fantasy pack:** wizards, dragons, enchanted gear (backlog §8).
- **Forest folk / sky pack:** people riding big birds, tree people, flying mounts. Another answer
  to "flying races" besides wings.
- **Sci-fi:** lasers, vehicles, walkers, spaceships

## Buildings

| Building                               | Function                                              | Status                                           |
| -------------------------------------- | ----------------------------------------------------- | ------------------------------------------------ |
| Town Center                            | Workers, drop-off, age-up                             | **MVP**                                          |
| House                                  | +pop                                                  | **MVP**                                          |
| Barracks                               | Infantry                                              | **MVP**                                          |
| Archery Range                          | Archers, skirmishers                                  | **MVP** (could merge into Barracks for the demo) |
| Stable                                 | Mounts and beasts                                     | **MVP**-lite: trains the age-2 `large` unit      |
| Watchtower (upgrades through 3 levels) | Defence, vision                                       | **MVP** (one level)                              |
| Drop-off camps (wood, food, mining)    | Drop-off                                              | Next                                             |
| Farm                                   | Renewable food                                        | Next                                             |
| Pen                                    | Penned herd animals trickle food and breed (no worker) | Built (2026-10-13)                              |
| Blacksmith                             | Attack/armour upgrades by tag (melee, ranged, armour) | Next (tag upgrades fit our system perfectly)     |
| Siege Workshop                         | Siege                                                 | Next                                             |
| Castle                                 | Unique unit, long-range siege, defence                | Next                                             |
| Market                                 | Trade resources, trade carts                          | Later                                            |
| Temple                                 | Mystics, relics                                       | Later                                            |
| University                             | Tech, building upgrades                               | Later                                            |
| Dock                                   | Naval                                                 | Later                                            |
| Palisade/stone walls, gates            | Defence                                               | Later                                            |
| Outpost                                | Vision                                                | Later                                            |
| Wonder                                 | Alternative win condition                             | Later                                            |

Each race gets its buildings in its own style (frog lily-pad houses, rat bottle-cap barracks),
with the same footprint and function.

## The counter web

```
spear    > large / mounted / beasts
mounted  > archer, skirmisher, siege
archer   > infantry, spear
skirm    > archer
infantry > buildings, skirm, spear (cheap units)
catapult > massed archers/infantry
ram      > buildings
mystic   > large (conversion), heals
scout    > siege, mystics, archers (raids)
```

Counter bonuses live in part stats (`bonus: {tag: n}`) and unit tags, so generated races slot in
automatically. A counters table in data (`data/counters.json`) is in the backlog.

## Generator implications

- `data/rules/*.json` roster gains a `building` and `age` per slot. Right now it holds only the MVP
  five: worker, spear, skirmisher, archer, large.
- **Required parts to add before Next:**
  - siege bodies: ram, catapult, bolt thrower, long-range siege engine;
  - light cavalry gear;
  - mystic gear: staff, robes;
  - big beasts (or giant creatures);
  - generic infantry weapons for more cultures.
- Unit lines: the tier upgrades material and adds armour; the recipe stays recognisably the same unit.
- **The `unique` slot is where prompt knowledge matters most:** "romans" -> testudo legion.
  This is the strongest use case for the post-MVP LLM brief expander.
