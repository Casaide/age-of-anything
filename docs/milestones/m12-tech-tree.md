# Milestone 12: The full land tech tree (buildings and systems)

**Status:** in progress (plan approved 2026-10-11)
**Exit criterion:** the tech tree page shows every building and research of the plan below with
no blank (planned) nodes left (the new unit lines are milestone 13's); a bot-vs-bot match reaches
age 4 and uses every building; tests green; Dominic plays a match to age 4.

This file holds the whole land tree. Dominic split it in two (2026-10-11): **milestone 12** is the
page, the bonuses, age 4, the research, walls, gates, towers, garrison, the Castle, University,
the Wonder and the buildings the new lines need; **milestone 13** (`m13-unit-lines.md`) is the
new unit lines, siege, mystics and war beasts, the art-heavy half with concept rounds.

Dominic, 2026-10-11: "Tech tree page so I can easily see what my race can do, and what their
bonuses are. Should show the full planned tree, with no icons for things we haven't made. This will
be our next milestone, a fully complete tech tree and all buildings, including walls, castle,
towers. No ships, boats or planes yet, focusing on land first."

## Scope

In:
- **The tech tree page:** one screen per race, from the lobby and in a match.
- **The full land tree as data:** every building, line and research below, built or planned.
  Planned items sit in `data/` with `"status": "planned"`: the page draws them (blank frame, no
  icon), the sim and the build menus skip them. Building an item means removing that flag.
- **Race bonuses as data:** each creature and culture states its bonuses and its own research.
- **A fourth age**, the walls and gates, the towers, the Castle, University, Temple, Siege
  Workshop, the Market's trade carts, garrisoning, and the new unit lines.

Out (stay in `../backlog.md`): Dock and everything naval, flying craft, gunpowder (cannons,
gunners, bombard towers), relics, heroes, allies and tribute (until teams play online).

## The tree

Status today: **built** = in the game, **planned** = blank node on the page until built.
All names are ours (no names from other games). Ages 1-3 keep their names; age 4 is new.

### Ages

| Age | Name | Needs (D-071: buildings of the current age) | Status |
|---|---|---|---|
| 1 | Mud Age | - | built |
| 2 | Stick Age | a Barracks | built |
| 3 | Stone Age | two age-2 buildings (Archery Range, Stable, Armoury, Market) | built (needs the Stable today) |
| 4 | Shiny Age (working name) | a Castle, or two age-3 buildings (University, Temple, Siege Workshop) | planned |

Unit lines get a step per age (D-100: upgraded at the building that trains them). Age 4 adds a
fourth step to every line; the generator's point budget gains `"4"`, and the culture kits need an
age-4 gear tier (iron and plate, D-057).

### Buildings

| Building | Age | Does | Status |
|---|---|---|---|
| Town Center | 1 (more from age 3) | workers, drop-off, ages, worker research; garrison shoots | built (more TCs and garrison planned) |
| House | 1 | +pop | built |
| Farm | 1 | renewable food | built |
| Mill, Lumber Camp, Mining Camp | 1 | drop-off, gathering research | built |
| Barracks | 1 | infantry | built |
| Outpost | 1 | sight only, cheap | planned |
| Palisade Wall + Palisade Gate | 1 | wooden wall; the gate opens for its own team | planned (today's stone wall moves to age 2) |
| Archery Range | 2 | ranged lines | built |
| Stable | 2 | mounted lines and beasts | built |
| Armoury | 2 | attack and armour research | built |
| Market | 2 | trade resources; trade carts | built (carts planned) |
| Watchtower | 2 | shoots; upgrades to Bastion (3), Citadel Tower (4) | built (upgrades planned) |
| Stone Wall + Stone Gate | 2 | stone wall; gate as above | wall built, gate planned |
| Siege Workshop | 3 | siege engines | planned |
| University | 3 | building, tower and siege research | planned |
| Temple | 3 | mystics and their research | planned |
| Castle | 3 | unique unit, sapper, great sling, unique research; shoots, garrison | planned |
| Wonder | 4 | alternative victory: stand for a time | planned |

Every building comes in all six architectures (concept-first for new ones, D-080).

### Unit lines

Each line is a roster slot (`data/rules/*.json`) with a building and a first age; the generator
fills it from the race (one creature in its culture's gear, or variants once those exist).

| Building | Line (slot) | Ages | Beats / weak to | Status | Parts |
|---|---|---|---|---|---|
| Town Center | Worker (`worker`) | 1+ | - | built | ok |
| Barracks | Spear (`spear`) | 1-4 | mounted, beasts / ranged, infantry | built (to 3) | ok |
| Barracks | Swordsman (`infantry`) | 1-4 | buildings, spears, skirmishers / archers | planned | swords, clubs exist |
| Barracks | Raider (`raider`) | 3-4 | siege, archers, mystics / infantry | planned | light kit |
| Archery Range | Skirmisher (`skirmisher`) | 2-4 | archers / infantry, mounted | built (to 3) | ok |
| Archery Range | Archer (`archer`) | 2-4 | infantry / skirmishers, mounted | built (to 3) | ok |
| Archery Range | Mounted Archer (`mounted_archer`) | 3-4 | infantry, hit and run / skirmishers | planned | generator makes them already |
| Stable | Scout (`scout`) | 2-4 | siege, archers, mystics, raids / spears | planned | light mount gear |
| Stable | Heavy (`large`) | 2-4 | ranged / spears, mystics | built (to 3) | ok |
| Stable | War Beast (`war_beast`) | 3-4 | buildings, infantry / spears, mystics | planned | **gap**: big beasts |
| Siege Workshop | Ram (`ram`) | 3-4 | buildings / melee | planned | **gap** |
| Siege Workshop | Catapult (`catapult`) | 3-4 | massed units, splash / mounted | planned | **gap** |
| Siege Workshop | Bolt Thrower (`bolt_thrower`) | 3-4 | infantry lines / mounted | planned | **gap** |
| Siege Workshop | Siege Tower (`siege_tower`) | 4 | carries units over walls | planned | **gap** |
| Castle | Unique (`unique`) | 3, elite 4 | the race's signature (bigger budget) | planned | from the prompt |
| Castle | Sapper (`sapper`) | 3 | buildings, walls (blows up) | planned | small: a satchel |
| Castle | Great Sling (`great_sling`) | 4 | buildings at long range; packs/unpacks | planned | **gap** |
| Temple | Mystic (`mystic`) | 3-4 | heals; converts large units and beasts / scouts, raiders | planned | **gap**: staff, robes |
| Market | Trade Cart (`trader`) | 2 | gold by distance between your markets | planned | **gap**: cart |

Siege bodies are the creature's own take (a beetle-drawn ram, a frog catapult on a lily-pad
sledge, a rat's bottle-cap sling): one concept round per family.

### Research

Ages are when it opens. Effects use the forms `tech.json` already has (`tag/stat/add`,
`gather/pct`); new forms are listed under "New effect kinds".

| Building | Research | Age | Effect | Status |
|---|---|---|---|---|
| Town Center | Thick Skins | 1 | workers +15 HP, +1 melee armour | planned |
| Town Center | Big Pockets | 2 | workers +10% speed, +3 carry | planned |
| Town Center | Pack Frames | 3 | workers +10% speed, +5 carry | planned |
| Town Center | Lookouts | 2 | buildings +3 sight | planned |
| Town Center | Night Lanterns | 3 | buildings +3 sight | planned |
| Mill | Bigger Baskets | 1 | food +15% | built |
| Mill | Ploughs | 2 | food +15% | built |
| Mill | Fallow Fields | 3 | farms +50% food | planned |
| Mill | Water Wheels | 4 | food +15% | planned |
| Lumber Camp | Stone Axes, Saws | 1, 2 | wood +15% each | built |
| Lumber Camp | Felling Wedges | 3 | wood +15% | planned |
| Mining Camp | Iron Picks | 1 | stone, gold +15% | built |
| Mining Camp | Ore Carts | 3 | stone, gold +15% | planned |
| Mining Camp | Deep Shafts | 4 | stone, gold +15% | planned |
| Armoury | Melee: Sharp Sticks, Bronze Edges, Iron Edges | 2, 3, 4 | melee +1 attack each | Sharp Sticks built (spears only: becomes all melee) |
| Armoury | Ranged: Hardened Tips, Barbed Heads, Iron Heads | 2, 3, 4 | ranged +1 attack each | Hardened Tips built |
| Armoury | Range: Fletching, Long Shafts | 2, 3 | bows +1 range each | Fletching built |
| Armoury | Infantry armour: Padded Coats, Ring Mail, Plate Shells | 2, 3, 4 | foot melee units +1/+1 | planned |
| Armoury | Ranged armour: Quilted Vests, Leather Jacks, Ring Jacks | 2, 3, 4 | ranged units +1/+1 | planned |
| Armoury | Mount armour: Saddle Blankets, Scale Barding, Iron Barding | 2, 3, 4 | mounted +1/+1 | planned |
| Barracks | line upgrades | 2-4 | next kit | built (to 3) |
| Barracks | Marching Drums | 3 | infantry +10% speed | planned |
| Barracks | Strong Legs | 2 | frogs only: amphibians +2 speed | built |
| Archery Range | line upgrades | 2-4 | next kit | built (to 3) |
| Archery Range | Quick Draw | 3 | ranged reload -15% | planned |
| Stable | line upgrades | 2-4 | next kit | built (to 3) |
| Stable | Hoof Wraps | 2 | mounted +10% speed | planned |
| Stable | Good Hay | 3 | mounted +20 HP | planned |
| Market | trading | 2 | buy/sell | built |
| Market | Haggling | 3 | trade fee lower | planned |
| Market | Pack Animals | 3 | trade carts +25% speed | planned |
| Market | Merchant Halls | 4 | trade fee lowest; carts +gold | planned |
| University | Stonecutting | 3 | buildings +10% HP, +1/+1 armour | planned |
| University | Deep Foundations | 4 | buildings +10% HP, +1/+1 armour | planned |
| University | Lifting Frames | 3 | build 20% faster | planned |
| University | Bastion | 3 | Watchtowers become Bastions (hp, attack) | planned |
| University | Citadel Tower | 4 | Bastions become Citadel Towers | planned |
| University | Slit Windows | 3 | towers, castles, TCs +1 range | planned |
| University | Thick Walls | 4 | walls and gates +100% HP | planned |
| University | Siege Wrights | 4 | siege +1 range | planned |
| Siege Workshop | line upgrades | 4 | heavier engines | planned |
| Castle | creature research | 3 | from the creature (see bonuses) | planned |
| Castle | culture research | 4 | from the culture (see bonuses) | planned |
| Castle | unique elite | 4 | the unique unit's age-4 step | planned |
| Castle | War Drums | 4 | military trains 30% faster | planned |
| Temple | Soothing Songs | 3 | mystics heal faster | planned |
| Temple | Long Sermons | 3 | conversion +3 range | planned |
| Temple | Stubborn Hearts | 3 | your units are harder to convert | planned |
| Temple | Pilgrim Sandals | 3 | mystics +15% speed | planned |
| Temple | Patient Faith | 4 | mystics recover faster | planned |
| Temple | Deep Faith | 4 | mystics convert siege and buildings | planned |

### Race bonuses

Today a race's bonuses are scattered: creature `economy` (rats cheap and quick, centaurs carry
more), movement classes (amphibious, flying), and `only` research (Strong Legs). The page needs
them stated, so they become one data field on creatures and families:

```json
"bonuses": [{"text": "Hard shells: every unit +1 pierce armour", "effects": [{"tag": "all", "stat": "armour.pierce", "add": 1}]}],
"research": ["shell_polish"],
"lacks": ["mounted_archer"]
```

- A race = its creature's bonuses + its culture's bonuses, plus its own research at the Castle
  (one from the creature, age 3; one from the culture, age 4).
- Bonuses that change unit stats are applied **before pricing**, so the unit pays for them
  (cost is the balancer, D-078). Economy bonuses aren't priced, so they stay small and every
  creature and culture gets about the same amount.
- `lacks` (D-070's race tech-tree layer): what a race doesn't get. The host's `full_tech_tree`
  rule lifts it, as it already lifts `only`.
- Derived facts show too, without data: movement class, flying over walls, pop per house.

First draft for Dominic to pick from (one or two each):

| Who | Bonuses | Own research |
|---|---|---|
| Frogs | amphibious (have); farms in water (have) | Strong Legs (have) |
| Rats | units 30% cheaper, train 20% faster, houses +1 pop (have) | Gnawing Teeth: units +2 attack vs buildings |
| Humans | research 15% faster | Clever Hands: workers build 25% faster |
| Spiders | walls cost half (silk) | Sticky Silk: ranged hits slow the target |
| Beetles | every unit +1 pierce armour (shells) | Shell Polish: +1 melee armour |
| Centaurs | carry 160% (have) | Gallop: mounted +15% speed |
| Imperial | buildings 10% cheaper | Shield Wall: infantry +2 pierce armour |
| Hellenic | spears +1 melee armour | Long Spears: spears +1 range (reach) |
| Steppe | mounted +10% speed | Saddle Bows: mounted archers +1 range |
| Swamp, Sewer, Forest, Royal, Spooky, Nile, Han, Aztec | one each, to draft | one each |

### New effect kinds (data contract)

`cost_pct` and `train_pct` by tag, `research_pct`, `build_pct`, `carry_add`, `sight_add` (units or
buildings), `building_hp_pct` and building armour, `reload_pct`, `bonus_vs` (attack bonus vs a tag,
e.g. buildings), `slow_on_hit`, `tower_upgrade` (replaces a building type), `farm_food_pct`,
`trade_fee`. Each lands with the first research that needs it.

## The tech tree page

`scenes/tech_tree.tscn`, view only. It takes a race and the rules; in a match it also reads the
player's state.

- **Layout:** ages as rows (1 at the top, 4 at the bottom), buildings as columns. Under each
  building: its unit lines (one node per age step, joined by a line) and its research. Lines
  between nodes show what unlocks what.
- **Nodes:** built items show their icon, or the race's own unit portrait and name for that age
  ("Reedspear Frog" -> its age-3 name). Planned items: an empty frame, the name in grey, no icon.
  Items the race lacks: crossed out. Race-only items: a small mark.
- **Race panel (left):** name, creature, culture, the army idling (the lobby's preview), the
  bonuses as text, its own research, what it lacks, movement class.
- **Hover:** the same tooltip card as the command panel (cost, what it does, needs, unlocks).
- **In a match:** researched items lit, in progress with a bar, can't-yet dimmed. Opened with T
  and a button on the top bar; Esc closes. The sim keeps running (it's a lockstep game).
- **From the lobby:** a "Tech tree" button on each side's banner.
- A headless check that every node on the page comes from data and every planned item is in
  this file.

## Plan (phases)

Each phase ends with tests green and pictures in the archive. New art is concept-first (D-080).

### Milestone 12 (this file)

1. **Data and the page.** The full tree into `data/` (`status: planned`), age 4 in `tech.json`
   (planned), roster slots with building and age, the loaders skipping planned items, then the
   tech tree page in the lobby and the match. Pictures of the page with frogs and rats.
2. **Race bonuses.** The `bonuses` / `research` / `lacks` fields, today's scattered bonuses
   moved into them, applied before pricing; Dominic picks from the drafts above. A few `lacks`
   per creature or culture (Dominic: yes), lifted by Full tech tree.
3. **Age 4 and the research that needs no new systems.** The age itself, age-4 kit tiers and line
   steps, economy and worker research, the armoury tracks, barracks, range and stable research.
4. **Walls, gates and towers.** Palisade (age 1, wood), stone wall to age 2, gates (passable for
   their own team: flow fields per team where gates exist), Outpost, Watchtower upgrades,
   garrisoning (Town Center, towers, Castle: each unit inside adds an arrow; the TC's call to
   arms), more Town Centers from age 3.
5. **University and Castle.** Building research, tower upgrades; the Castle building, its
   arrows, War Drums, and the race research slots.
6. **The other buildings, standing:** Siege Workshop and Temple built and placeable in every
   architecture, so milestone 13 only adds what they train.
7. **Wonder** (Dominic: in): one model per architecture; build it and hold it for a time to win.
8. **The AI:** `data/ai.json` learns the new buildings, research, walls, towers and age 4; a
   bot-vs-bot to age 4.
9. **Exit check:** no blank buildings or research on the page; Dominic plays to age 4.

### Milestone 13 (`m13-unit-lines.md`)

Swordsman, raider, scout and mounted archer (parts exist); the unique unit and sapper; siege
(ram, catapult, bolt thrower, great sling, siege tower) with a concept round per family; mystics
(healing, conversion) and the Temple research; trade carts and the market's cart research; war
beasts; balance round robin at ages 3 and 4.

## Decided (Dominic, 2026-10-11)

1. Four ages (working name for age 4: "Shiny Age").
2. Split: buildings and systems here, unit lines in milestone 13.
3. Races lack a few things each (`lacks`), lifted by the host's Full tech tree.
4. The Wonder is in.

Still open: the bonus drafts (phase 2), and whether Sharp Sticks (spears only) becomes the first
step of an all-melee track.

## Dominic's playtest notes (2026-10-11, while planning)

Fixed first, as they came in; each ticked when done.

- [x] Build menu split into Civilian and Military pages (Esc or Back returns)
- [x] Stone walls in age 1 were a slip: the stone wall is age 2 now; the wooden palisade (age 1) comes in phase 4
- [x] Soldiers auto-attacked enemy sheep: they ignore animals now; an unguarded rival sheep is stolen by walking up to it
- [x] Bushes lasted far too long (2,000 food each): 150 now, so farms come early; the bot builds farms as wild food near home runs out (only while food is short) and reseeds them; age-1 gatherer mix 50/50
- [ ] Gates for walls (phase 4; palisade gate and stone gate)
- [ ] The UI is too small on a MacBook (a UI scale)
- [ ] Command panel: a stronger split between training and build options; buttons too small; health bar far too big
- [ ] A rally point clicked on a tree, rock or other resource centres on it
- [ ] Centaurs struggle to fight (pathfinding?); spiders very hard for them to kill: check
- [ ] A line upgrade reads "Spearbearer Centaur" to "Spearbearer Centaur": the name must change, or the card show what changes
- [ ] The bot should hunt (and herd sheep)
- [ ] Right-click a drop-off building to drop off what a worker carries
- [ ] Watchtowers don't seem to shoot
- [ ] Unit stances: aggressive, defensive, stand ground (and no-attack)
- [ ] (For another session) building variants turned so no door or window shows

## Checklist
- [x] Plan approved by Dominic (2026-10-11: four ages, split, lacks, Wonder in)
- [x] 1. Data and the tech tree page (2026-10-11: the tree in `data/` with `"status": "planned"`, loaders skip it, `scenes/tech_tree.tscn` from the lobby banners and in a match on F2 or the top bar's button; T stays the Watchtower's hotkey; checked in `tests/run_tests.gd`, captures with `tests/tech_tree_screenshot.gd`)
- [ ] 2. Race bonuses
- [ ] 3. Age 4 and simple research
- [ ] 4. Walls, gates, towers, garrison
- [ ] 5. University and Castle
- [ ] 6. Siege Workshop and Temple standing
- [ ] 7. Wonder
- [ ] 8. AI
- [ ] 9. Exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `../roster-template.md` (the earlier role plan this completes)
- `../backlog.md` "Gates" (moves here), naval and gunpowder (stay there)
- D-057, D-070, D-071, D-078, D-080, D-100, D-101 in `../../archive/decisions.md`
