# Roster template: the full unit and building plan

**Decision:** follow the genre's standard *role structure* for classic 2D RTS games: a set of
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

| Age | Working name | MVP |
|---|---|---|
| 1 | Muck Age | yes |
| 2 | Stick Age | yes (one age-up) |
| 3 | Stone Age (name TBD) | Next |
| 4 | Iron Age (name TBD) | Next |

## Resources

| Resource | Sources | MVP |
|---|---|---|
| Food | Bug bushes, hunting; farms and fishing later | yes |
| Wood | Reeds/trees | yes |
| Gold | Shiny things | Next |
| Stone | Quarries | Next (walls, castles, towers) |

## Units by building

### Town Center
| Line | Slot | Role / needs | Counters | Age | Status |
|---|---|---|---|---|---|
| Worker | `worker` | worker tool | - | 1 | **MVP** |

### Barracks (infantry)
| Line | Slot | Role / needs | Beats / weak to | Age | Status |
|---|---|---|---|---|---|
| Swordsman line (4 tiers) | `infantry` | melee, not spear (blade/blunt) | buildings, cheap units; weak to archers | 1 | Next |
| Spear line (3 tiers) | `spear` | spear | beats large/mounted; weak to archers, infantry | 2 | **MVP** |
| Fast light infantry | `raider_infantry` | fast melee infantry | beats mystics, siege, archers; weak to infantry | 2 | Later (family-specific) |

### Archery Range (ranged)
| Line | Slot | Role / needs | Beats / weak to | Age | Status |
|---|---|---|---|---|---|
| Archer line (3 tiers) | `archer` | bow | beats infantry; weak to skirmishers, cavalry, siege | 2 | **MVP** |
| Skirmisher line (2 tiers) | `skirmisher` | ranged, not bow | beats archers; weak to infantry, cavalry | 2 | **MVP** |
| Mounted archer line | `mounted_archer` | bow + mount | hit-and-run vs infantry; weak to skirmishers | 3 | Next (generator already makes horse archers) |
| Gunner | `gunner` | gun | beats infantry | 4 | Later (gunpowder era) |

### Stable (mounts and beasts)
| Line | Slot | Role / needs | Beats / weak to | Age | Status |
|---|---|---|---|---|---|
| Light scout cavalry (3 tiers) | `scout` | fast mount, light weapon | beats mystics, siege, archers; weak to spears | 2 | Next |
| Heavy cavalry (3 tiers) | `large` | mount or Heavy/Giant + melee | beats archers, skirmishers; weak to spears, anti-cavalry, mystics | 3 | **MVP** (as the age-2 unit) |
| Anti-cavalry mount | `anti_cavalry_mount` | mount + bonus vs mounted | beats cavalry; weak to spears, infantry | 3 | Later |
| War beast | `war_beast` | giant creature or huge mount | tanky vs buildings and infantry; weak to spears, mystics | 3 | Later |
| Light lancer | `lancer` | mount + reach | beats ranged; weak to spears | 3 | Later |

### Siege Workshop
| Line | Slot | Role / needs | Beats / weak to | Age | Status |
|---|---|---|---|---|---|
| Ram | `ram` | siege vehicle/beast, anti-building | beats buildings; weak to melee | 3 | Next (**parts gap**) |
| Catapult line | `catapult` | siege ranged, splash | beats massed archers/infantry; weak to cavalry | 3 | Next (**parts gap**) |
| Bolt thrower | `bolt_thrower` | siege ranged, pierce | beats infantry lines; weak to cavalry | 3 | Later (**parts gap**) |
| Siege tower | `siege_tower` | carries units over walls | - | 4 | Later |
| Cannon | `cannon` | gun siege | beats buildings, siege | 4 | Later (gunpowder) |

### Castle
| Line | Slot | Role / needs | Notes | Age | Status |
|---|---|---|---|---|---|
| Unique unit (+ elite) | `unique` | the race's signature (prompt-driven, bigger point budget) | The generator's showcase slot: "the thing this race is about" | 3 | Next |
| Long-range siege engine | `trebuchet` | long-range anti-building siege | Packs/unpacks | 4 | Later (**parts gap**) |
| Sapper | `sapper` | suicide anti-building | Frogs with fireworks | 3 | Later |

### Temple
| Line | Slot | Role / needs | Notes | Age | Status |
|---|---|---|---|---|---|
| Mystic | `mystic` | healer/converter | Needs conversion and relic systems | 3 | Later (**parts gap**: staff, robes) |

### Dock
| Line | Slot | Notes | Status |
|---|---|---|---|
| Fishing boat | `fisher` | Water economy | Later (naval) |
| Transport | `transport` | | Later |
| Sea trader | `sea_trader` | | Later |
| Warship line | `warship` | | Later |
| Fire ship line | `fire_ship` | | Later |
| Demolition boat | `demo_ship` | | Later |
| Cannon ship | `cannon_ship` | Gunpowder | Later |

Naval craft are bodies too: lily-pad rafts for frogs, bottle boats for rats.

### Market
| Line | Slot | Notes | Status |
|---|---|---|---|
| Trade cart | `trader` | Needs gold and multi-market trade | Later |

## Buildings

| Building | Function | Status |
|---|---|---|
| Town Center | Workers, drop-off, age-up | **MVP** |
| House | +pop | **MVP** |
| Barracks | Infantry | **MVP** |
| Archery Range | Archers, skirmishers | **MVP** (could merge into Barracks for the demo) |
| Stable | Mounts and beasts | **MVP**-lite: trains the age-2 `large` unit |
| Watchtower (upgrades through 3 levels) | Defence, vision | **MVP** (one level) |
| Drop-off camps (wood, food, mining) | Drop-off | Next |
| Farm | Renewable food | Next |
| Blacksmith | Attack/armour upgrades by tag (melee, ranged, armour) | Next (tag upgrades fit our system perfectly) |
| Siege Workshop | Siege | Next |
| Castle | Unique unit, long-range siege, defence | Next |
| Market | Trade resources, trade carts | Later |
| Temple | Mystics, relics | Later |
| University | Tech, building upgrades | Later |
| Dock | Naval | Later |
| Palisade/stone walls, gates | Defence | Later |
| Outpost | Vision | Later |
| Wonder | Alternative win condition | Later |

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
