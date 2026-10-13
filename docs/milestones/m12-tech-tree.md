# Milestone 12: The full land tech tree (buildings and systems)

**Status:** closed for now (2026-10-13, Dominic: "12 and 15 close for now")
**Exit criterion:** the tech tree page shows every building and research of the plan below with
no blank (planned) nodes left (the new unit lines are milestone 13's); a bot-vs-bot match reaches
age 3 and uses every building; tests green; Dominic plays a match to age 3.

This file holds the whole land tree. Dominic split it in two (2026-10-11): **milestone 12** is the
page, the research, walls, gates, towers, garrison, the Castle, University,
the Wonder and the buildings the new lines need; **milestone 13** (`m13-unit-lines.md`) is the
new unit lines, siege, healers and war beasts, the art-heavy half with concept rounds.

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
- ~~Race bonuses as data~~: moved to milestone 14 (race identity) with the rest of what makes races differ.
- The walls and gates, the towers, the Castle, University, Siege
  Workshop, the Market's trade carts, garrisoning, and the new unit lines.

Out (stay in `../backlog.md`): Dock and everything naval, flying craft, gunpowder (cannons,
gunners, bombard towers), relics, heroes, allies and tribute (until teams play online).

## The tree

Status today: **built** = in the game, **planned** = blank node on the page until built.
All names are ours (no names from other games). Three ages (Dominic, 2026-10-12: "lose age 4").

### Ages

| Age | Name | Needs (D-071: buildings of the current age) | Status |
|---|---|---|---|
| 1 | Mud Age | - | built |
| 2 | Stick Age | a Barracks | built |
| 3 | Stone Age | two age-2 buildings (Archery Range, Stable, Armoury, Market) | built (needs the Stable today) |

Unit lines get a step per age (D-100: upgraded at the building that trains them). Age 4 adds a
fourth step to every line; the generator's point budget gains `"4"`, and the culture kits need an
age-4 gear tier (iron and plate, D-057).

### Buildings

| Building | Age | Does | Status |
|---|---|---|---|
| Town Center | 1 (more from age 3) | workers, drop-off, ages, worker research; garrison shoots | built (garrison, call to arms, more from age 3: phase 3) |
| House | 1 | +pop | built |
| Farm | 1 | renewable food | built |
| Mill, Lumber Camp, Mining Camp | 1 | drop-off, gathering research | built |
| Barracks | 1 | infantry | built |
| Outpost | 1 | sight only, cheap | built (phase 3; look per culture from a concept round, pick pending) |
| Palisade Wall + Palisade Gate | 1 | wooden wall; the gate opens for its own team | planned (today's stone wall moves to age 2) |
| Archery Range | 2 | ranged lines | built |
| Stable | 2 | mounted lines and beasts | built |
| Armoury | 2 | attack and armour research | built |
| Market | 2 | trade resources; trade carts | built (carts planned) |
| Watchtower | 2 | shoots; upgrades to Bastion (3) | built (Bastion upgrade and garrison: phase 3; the research waits for the University) |
| Stone Wall + Stone Gate | 2 | stone wall; gate as above | wall built, gate planned |
| Siege Workshop | 3 | siege engines | built (phase 6; trains nothing until milestone 13) |
| University | 3 | building, tower and siege research | planned |
| Castle | 3 | unique unit, sapper, great sling, unique research; shoots, garrison | planned |
| Wonder | 3 | alternative victory: stand for a time | built (phase 7) |
| Siege Workshop | 3 | siege engines | planned |
| University | 3 | building, tower and siege research | built (phase 4; look per culture pending Dominic's pick) |
| Castle | 3 | unique unit, sapper, great sling, unique research; shoots, garrison | built (phase 5: shoots a 4-arrow volley, `garrison` 20 in data, War Drums and the race slots; trains nothing until milestone 13) |
| Wonder | 3 | alternative victory: stand for a time | planned |

Every building comes in all six architectures (concept-first for new ones, D-080).

### Unit lines

Each line is a roster slot (`data/rules/*.json`) with a building and a first age; the generator
fills it from the race (one creature in its culture's gear, or variants once those exist).

| Building | Line (slot) | Ages | Beats / weak to | Status | Parts |
|---|---|---|---|---|---|
| Town Center | Worker (`worker`) | 1+ | - | built | ok |
| Town Center | Healer (`healer`) | 2-3 | heals nearby wounded / scouts, raiders | built (milestone 13, 2026-10-12; look A in, the pick pending: HL1 sheet) | staff + bag (herbs; cheese for rats, a lily for frogs) |
| Barracks | Spear (`spear`) | 1-3 | mounted, beasts / ranged, infantry | built (to 3) | ok |
| Barracks | Swordsman (`infantry`) | 1-3 | buildings, spears, skirmishers / archers | built (to 3; milestone 13) | club, then the culture's sword |
| ~~Barracks~~ | ~~Raider (`raider`)~~ | - | cut as a line (Dominic, 2026-10-13: "sounds race specific like a castle unit"): raiders are unique-unit themes now | in `data/later/raider_line.json` | - |
| Archery Range | Skirmisher (`skirmisher`) | 2-3 | archers / infantry, mounted | built (to 3) | ok |
| Archery Range | Archer (`archer`) | 2-3 | infantry / skirmishers, mounted | built (to 3) | ok |
| Archery Range | Mounted Archer (`mounted_archer`) | 2-3 | infantry / skirmishers, spears, cavalry | built (milestone 13, 2026-10-13; a race whose archers already ride, or with nothing to ride, lacks it) | the race's mount + a bow |
| Stable | Scout (`scout`) | 2-3 | skirmishers, healers, workers, siege; sees far / spears, any real soldier | built (milestone 13, 2026-10-13; on foot where nothing carries the race) | the race's mount + a light weapon, light kit |
| Stable | Heavy (`large`) | 2-3 | ranged / spears | built (to 3) | ok |
| Stable | War Beast (`war_beast`) | 3 | buildings, infantry / spears | planned | **gap**: big beasts |
| Siege Workshop | Ram (`ram`) | 3 | buildings / melee | planned | **gap** |
| Siege Workshop | Catapult (`catapult`) | 3 | massed units, splash / mounted | planned | **gap** |
| Siege Workshop | Bolt Thrower (`bolt_thrower`) | 3 | infantry lines / mounted | planned | **gap** |
| Siege Workshop | Siege Tower (`siege_tower`) | 3 | carries units over walls | planned | **gap** |
| Castle | Unique (`unique`) | 3 | the race's signature (a theme from `data/uniques.json`: asked for, else creature, else culture) | built (milestone 13, 2026-10-13) | existing parts in a signature combination; new parts concept-first |
| Castle | Sapper (`sapper`) | 3 | buildings, walls (blows up) | planned | small: a satchel |
| Castle | Great Sling (`great_sling`) | 3 | buildings at long range; packs/unpacks | planned | **gap** |
| Market | Trade Cart (`trader`) | 2 | gold by distance between your markets | planned | **gap**: cart |

Siege bodies are the creature's own take (a beetle-drawn ram, a frog catapult on a lily-pad
sledge, a rat's bottle-cap sling): one concept round per family.

### Research

Ages are when it opens. Effects use the forms `tech.json` already has (`tag/stat/add`,
`gather/pct`); new forms are listed under "New effect kinds".

| Building | Research | Age | Effect | Status |
|---|---|---|---|---|
| Town Center | Thick Skins | 1 | workers +15 HP, +1 melee armour | built (phase 2) |
| Town Center | Big Pockets | 2 | workers +10% speed, +3 carry | built (phase 2) |
| Town Center | Pack Frames | 3 | workers +10% speed, +5 carry | built (phase 2) |
| Town Center | Lookouts | 2 | buildings +3 sight | built (phase 2) |
| Town Center | Night Lanterns | 3 | buildings +3 sight | built (phase 2) |
| Mill | Bigger Baskets | 2 | food +15% | built |
| Mill | Ploughs | 3 | food +15% | built |
| Mill | Fallow Fields | 3 | farms +50% food | built (phase 2) |
| Lumber Camp | Stone Axes, Saws | 2, 3 | wood +15% each | built |
| Mining Camp | Iron Picks | 2 | stone, gold +15% | built |
| Mining Camp | Ore Carts | 3 | stone, gold +15% | built (phase 2) |
| Armoury | Melee: Sharp Sticks, Bronze Edges | 2, 3 | melee +1 attack each | built (Bronze Edges after Sharp Sticks) |
| Armoury | Ranged: Hardened Tips, Barbed Heads | 2, 3 | ranged +1 attack each | built |
| Armoury | Range: Fletching, Long Shafts | 2, 3 | bows +1 range each | built |
| Armoury | Infantry armour: Padded Coats, Ring Mail | 2, 3 | foot melee units +1/+1 | built (phase 2) |
| Armoury | Ranged armour: Quilted Vests, Leather Jacks | 2, 3 | ranged units +1/+1 | built (phase 2) |
| Armoury | Mount armour: Saddle Blankets, Scale Barding | 2, 3 | mounted +1/+1 | built (phase 2) |
| Barracks | line upgrades | 2-3 | next kit | built (to 3) |
| Barracks | Marching Drums | 3 | infantry +10% speed | built (phase 2) |
| Barracks | Strong Legs | 2 | frogs only: amphibians +2 speed | built |
| Archery Range | line upgrades | 2-3 | next kit | built (to 3) |
| Archery Range | Quick Draw | 3 | ranged reload -15% | built (phase 2) |
| Stable | line upgrades | 2-3 | next kit | built (to 3) |
| Stable | Hoof Wraps | 2 | mounted +10% speed | built (phase 2) |
| Stable | Good Hay | 3 | mounted +20 HP | built (phase 2) |
| Market | trading | 2 | buy/sell | built |
| Market | Haggling | 3 | selling fee 25 -> 15 points | built (phase 2) |
| Market | Pack Animals | 3 | trade carts +25% speed | planned |
| University | Stonecutting | 3 | buildings +10% HP, +1/+1 armour | planned |
| University | Lifting Frames | 3 | build 20% faster | planned |
| University | Bastion | 3 | Watchtowers become Bastions (hp, attack) | built (phase 3: `tower_upgrade`; researchable once the University stands) |
| University | Slit Windows | 3 | towers, castles, TCs +1 range | planned |
| University | Thick Walls | 3 | walls and gates +100% HP | planned |
| University | Siege Wrights | 3 | siege +1 range | planned |
| University | Stonecutting | 3 | buildings +10% HP, +1/+1 armour | built |
| University | Lifting Frames | 3 | build 20% faster | built |
| University | Bastion | 3 | Watchtowers become Bastions (hp, attack) | planned |
| University | Slit Windows | 3 | towers, castles, TCs +1 range | built |
| University | Thick Walls | 3 | walls and gates +100% HP | built |
| University | Siege Wrights | 3 | siege +1 range | built (reaches units tagged `siege`: milestone 13) |
| Siege Workshop | (none: engines don't upgrade) | - | - | - |
| Castle | creature research | 3 | from the creature (see bonuses) | built as a slot: "Creature's Own Way", soldiers +5 HP until milestone 14 fills it |
| Castle | culture research | 3 | from the culture (see bonuses) | built as a slot: "Culture's Own Way", soldiers +5% speed until milestone 14 fills it |
| Castle | War Drums | 3 | military trains 30% faster | built |

### Postponed: age 4 and the Temple (Dominic, 2026-10-12)

"Lose age 4, and the temple ... don't throw anything away, we may come back to age 4 later." The
game has three ages and no Temple for now. Every cut entry is kept, exactly as it was, in
`data/later/age4_and_temple.json` (nothing loads it); to bring them back, move the entries back
into `data/tech.json`, `data/buildings.json` and `data/rules/*.json`. What was cut or moved:

- **Age 4 "Shiny Age"** (needed a Castle, or two age-3 buildings) and each line's fourth step;
  an age-4 kit tier per culture.
- **Fourth steps of tracks:** Water Wheels (mill), Felling Wedges (lumber), Deep Shafts (mining),
  Iron Edges, Iron Heads, Plate Shells, Ring Jacks, Iron Barding (armoury), Merchant Halls
  (market), Deep Foundations and Citadel Tower (university), the unique unit's elite step.
- **Moved to age 3:** Thick Walls, Siege Wrights, the culture's Castle research, War Drums, the
  Wonder, the siege tower and the great sling.
- **The Temple:** the building, mystics (healing and conversion; the healer at the Town Center
  takes the healing role), and its research: Soothing Songs, Long Sermons, Stubborn Hearts,
  Pilgrim Sandals, Patient Faith, Deep Faith.

The rows as they stood in the tables above:

| Where | Item | Age | Effect / does | Status then |
|---|---|---|---|---|
| 4 | Shiny Age (working name) | a Castle, or two age-3 buildings (University, Temple, Siege Workshop) | planned |
| Temple | 3 | mystics and their research | planned |
| Temple | Mystic (`mystic`) | 3-4 | heals; converts large units and beasts / scouts, raiders | planned | **gap**: staff, robes |
| Mill | Water Wheels | 4 | food +15% | planned |
| Lumber Camp | Felling Wedges | 4 | wood +15% | planned |
| Mining Camp | Deep Shafts | 4 | stone, gold +15% | planned |
| Market | Merchant Halls | 4 | trade fee lowest; carts +gold | planned |
| University | Deep Foundations | 4 | buildings +10% HP, +1/+1 armour | planned |
| University | Citadel Tower | 4 | Bastions become Citadel Towers | planned |
| Castle | unique elite | 4 | the unique unit's age-4 step | planned |
| Temple | Soothing Songs | 3 | mystics heal faster | planned |
| Temple | Long Sermons | 3 | conversion +3 range | planned |
| Temple | Stubborn Hearts | 3 | your units are harder to convert | planned |
| Temple | Pilgrim Sandals | 3 | mystics +15% speed | planned |
| Temple | Patient Faith | 4 | mystics recover faster | planned |
| Temple | Deep Faith | 4 | mystics convert siege and buildings | planned |

### Race bonuses (moved to milestone 14, `m14-race-identity.md`)

Today a race's bonuses are scattered: creature `economy` (rats cheap and quick, centaurs carry
more), movement classes (amphibious, flying), and `only` research (Strong Legs). The page needs
them stated, so they become one data field on creatures and families:

```json
"bonuses": [{"text": "Hard shells: every unit +1 pierce armour", "effects": [{"tag": "all", "stat": "armour.pierce", "add": 1}]}],
"research": ["shell_polish"],
"lacks": ["mounted_archer"]
```

- A race = its creature's bonuses + its culture's bonuses, plus its own research at the Castle
  (one from the creature, one from the culture, both age 3).
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

Built in phase 2 (2026-10-12) as one shape (`src/sim/tech.gd`): a scope, a `stat`, and an `add` or a
`pct` (the change to that number in percent, signed). Scopes: `tag` (unit types with it, `"all"`
for every unit; optional `"not": [tags]`, e.g. foot melee = `melee` not `mounted`) or `building`
(`"all"` or one id). The old `{gather, pct}` stays. The kinds above map to it:

| Kind | As data |
|---|---|
| tag/stat/add (incl. armour) | `{"tag": "worker", "stat": "armour.melee", "add": 1}` |
| `speed_pct` | `{"tag": "mounted", "stat": "speed", "pct": 10}` |
| `cost_pct`, `train_pct` | `{"tag": "all", "stat": "cost", "pct": -10}`, `stat: "train_time"` |
| `reload_pct` | `{"tag": "ranged", "stat": "reload", "pct": -15}` |
| `build_pct` | `{"tag": "worker", "stat": "build_speed", "pct": 20}` |
| `carry_add`, unit `sight_add` | `{"tag": "worker", "stat": "carry", "add": 3}`, `stat: "sight"` (tiles) |
| building `sight_add` | `{"building": "all", "stat": "sight", "add": 3}` |
| `building_hp_pct`, building armour | `{"building": "all", "stat": "hp", "pct": 10}`, `stat: "armour.melee"` add |
| `farm_food_pct` | `{"building": "farm", "stat": "food", "pct": 50}` (sown and reseeded farms) |
| `research_pct` | `{"building": "all", "stat": "research_time", "pct": -15}` (not the age-up) |
| `trade_fee` | `{"building": "market", "stat": "trade_fee", "add": -10}` (points of the selling fee) |

Unit effects are re-applied whenever a type changes (units out and units trained later); building
effects live per player in `w.bmods` (standing buildings keep their share of health). A research
with `after` needs that one first (`why_not`: "needs Sharp Sticks first").

## The tech tree page

`scenes/tech_tree.tscn`, view only. It takes a race and the rules; in a match it also reads the
player's state.

- **Layout:** ages as rows (1 at the top, 3 at the bottom), buildings as columns. Under each
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

Replanned 2026-10-12 after phase 1 and Dominic's playtest fixes. Race bonuses moved to milestone 14.

1. ~~Data and the page~~ (done).
2. **The research that needs no new systems.** The effect kinds the research needs (`cost_pct`,
   `train_pct`, `research_pct`, `build_pct`, `carry_add`, `sight_add`, `building_hp_pct`,
   `reload_pct`, `farm_food_pct`, `trade_fee`), each with a test; then all the plain research: Town
   Center (Thick Skins, Big Pockets, Pack Frames, Lookouts, Night Lanterns), Fallow Fields, Ore Carts,
   the armoury's six two-step tracks, Marching Drums, Quick Draw, Hoof Wraps, Good Hay, Haggling and
   Pack Animals. An icon per research (SVG, the house style), so no scroll fallbacks remain.
3. **Towers and garrison.** ~~Walls and gates~~ (done). Outpost (sight only); Watchtower upgrades
   to Bastion (`tower_upgrade`: a type replaced in place); garrisoning (Town
   Center, towers, Castle: units go inside, heal slowly, each adds an arrow; ungarrison; the Town
   Center's call to arms for workers); more Town Centers from age 3.
4. **University.** The building (every architecture, concept-first) and its research: Stonecutting,
   Lifting Frames, Bastion, Slit Windows, Thick Walls, Siege Wrights.
5. **Castle.** The building (big, shoots, garrisons; concept round per architecture), War Drums,
   and the two race research slots (filled by milestone 14; a placeholder "own research" until then).
6. **Siege Workshop, standing.** Built and placeable in every architecture (the Temple was cut, 2026-10-12).
7. **Wonder.** One per architecture (the culture's showpiece; concept round); build it and hold it
   for N minutes to win, with a countdown everyone sees; the bot attacks a Wonder.
8. **AI.** Bots never reach age 3 (checked on Reed Meadow 64, 2026-10-12: 11-18 minute matches,
   wood near home never runs out, so not the map): they save for age 3 only with a big economy,
   build a mining camp only at 20 workers (age 3 needs gold), and their attacks end matches first.
   Fix: plan age 3 (gold income early in age 2, the Stable, save while defending). `data/ai.json` learns the new research (gathering first, then armoury tracks by its
   army), towers and garrisoning when attacked, a University, a Castle; walls stay optional.
9. **Exit check.** No blank buildings or research on the page; bot-vs-bot reaches age 3 using every
   building; Dominic plays to age 3.

### Milestone 13 (`m13-unit-lines.md`)

Swordsman, raider, scout and mounted archer (parts exist); the unique unit and sapper; siege
(ram, catapult, bolt thrower, great sling, siege tower) with a concept round per family; healers at
the Town Center (Temple cut); trade carts and the market's cart research; war
beasts; balance round robin at ages 3 and 4.

## Decided (Dominic, 2026-10-11)

1. ~~Four ages~~: back to three, and no Temple (Dominic, 2026-10-12: "lose age 4, and the temple"); a healer trains at the Town Center instead of mystics.
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
- [x] Gates for walls: palisade (age 1), palisade gate, stone gate; gates open for their own team (passability per team)
- [x] Diagonal gates (2026-10-13, Dominic: "diagonal gates missing?"): a gate dropped on a diagonal wall run lies on it corner to corner (`along` 2 and 3; a building's footprint can be the cells on one diagonal of its square, `Buildings.diag`/`cells`); R turns a gate an eighth; the gatehouses bake on both diagonals (`^d`, `^a`), `gate_span` long; checked in `tests/test_sim.gd` `_test_diagonal_gates`; captures `sim_screenshot.gd` `gate:<kind>:<state>:<along>`, archive 2026-10-13 94-103
- [x] The UI is too small on a MacBook: the HUD and lobby scale with the screen's density (`src/view/ui_scale.gd`)
- [x] Command panel: captioned groups (Train, Research, Age up, Orders, Stance, Build), 80 px buttons, the queue in its own well, a slim health bar with its number
- [x] A rally point set on a resource sits in the middle of its tile
- [x] Centaurs: not pathing; every centaur is large and mounted, so every spear counters it, and spider pierce armour stops centaur missiles. Kept (the genre's counters); centaur ranged units are the cost-sanity backlog item (price by simulation)
- [x] Line steps are named for what got better (new weapon, else the gear's epithet, else the culture's rank word); a step with no new kit isn't sold; the tooltip shows stats before and after
- [x] The bot claims and slaughters sheep, hunts deer, and takes on boar with a party
- [x] Right-click a drop-off building to drop off, then back to the patch
- [x] Watchtowers shot, unseen: the view now draws their arrows; attack 5 -> 10 pierce
- [x] Unit stances: aggressive, defensive, stand ground, no attack
- [x] House variants only turn or mirror where the door stays in view
- [x] Gathering research opened in age 1 (Dominic: "mill lets me upgrade food in the 1st age"): each camp's track now starts in age 2, then 3 and 4

## Checklist
- [x] Plan approved by Dominic (2026-10-11: four ages, split, lacks, Wonder in)
- [x] 1. Data and the tech tree page (2026-10-11: the tree in `data/` with `"status": "planned"`, loaders skip it, `scenes/tech_tree.tscn` from the lobby banners and in a match on F2 or the top bar's button; T stays the Watchtower's hotkey; checked in `tests/run_tests.gd`, captures with `tests/tech_tree_screenshot.gd`)
- [x] 2. Effect kinds, plain research, research icons (age 4 cut 2026-10-12; effect kinds and research 2026-10-12, a test per kind in `tests/test_sim.gd`; icons drawn separately; Pack Animals waits for trade carts)
- [x] 3. Towers and garrison (walls and gates done 2026-10-11; the rest 2026-10-13: Outpost, Bastion via `tower_upgrade`, garrisons, call to arms, more Town Centers from age 3; checked in `tests/test_sim.gd` `_test_garrison`, `_test_towers`; captures `tests/sim_screenshot.gd` `garrison[:bastion]`)
- [ ] 4. University
- [ ] 5. Castle
- [x] 6. Siege Workshop standing (Temple cut) (2026-10-13: every architecture, military page, "Siege engines come later")
- [x] 7. Wonder (2026-10-13: six showpieces, hold-to-win in `match.gd`, host rule `wonder`, countdown and alerts, the bot builds and targets one; tests in `test_sim.gd` and `test_ai.gd`)
- [ ] 3. Towers and garrison (walls and gates done 2026-10-11)
- [x] 4. University (2026-10-13: concept round of three looks per culture, archive/images/2026-10-13/146-151; research real, the Bastion's effect is phase 3's)
- [x] 5. Castle (2026-10-13: concept round, 140-145; arrows, garrison by data, War Drums, the two race slots as placeholders)
- [ ] 6. Siege Workshop standing (Temple cut)
- [ ] 7. Wonder
- [x] 8. AI (2026-10-13: ages on time, the content used, levels in data; `test_ai -- <map> levels`, `_test_shelter`; results below. Open: Hard draws with Normal on old_forest)
- [x] 9. Exit check: closed for now by Dominic (2026-10-13)
- [x] Archive: pictures taken along the way, journal, decisions, timeline (journals 2026-10-12, 2026-10-13)

## Results

- **Phase 2 (2026-10-12, Claude):** every effect kind as one data shape, a headless check each;
  21 research made real (Town Center five, Fallow Fields, Ore Carts, the armoury's six tracks to
  their second step, Marching Drums, Quick Draw, Hoof Wraps, Good Hay, Haggling). Still planned:
  Pack Animals (trade carts), University, Castle research. The bot buys the economy research in
  `data/ai.json` (`research.economy`) and the soldiers' research reaching at least 4 of its
  soldiers, keeping back the next age's cost; it now builds an armoury (after the archery range)
  and a mill. test_ai: age 2 at the same times as before (4:20-5:49, one slow 8:30 as before),
  bot match lengths 10:35 / 10:58 / 13:35 (median 10:58; was 13:11). Bots still don't reach age 3
  in these matches (as before): the age-2 wood economy is phase 8's.

- **Phases 6 and 7 (2026-10-13, Claude):** the **Siege Workshop** is real: age 3, 3x3, 200 wood, on the
  military page, a yard in each culture's materials (the shed under its roof, a catapult half built,
  the bare rafters of a ram's shed, wheels as tin lids for the junk-rats and log rounds for reed and
  mound; `_siege_workshop` in `models.gd`). It trains nothing yet; its panel says "Siege engines come
  later." (`idle_note` in `buildings.json`). The **Wonder**: age 3, 5x5, 1000 of each resource,
  1500 s of work, 4800 hp; a showpiece per architecture (`wonder_<arch>`): a colonnaded temple
  (stone), the elders' hall with a stave tower and carved posts (thatch), the Great Cheese on a giant
  can (junk), a two-storey felt pavilion with horse-tail standards (tent), the Lily Spire on stilts
  (reed), termite spires with amber (mound). Concept round 1, pictures 160-162, for Dominic to pick
  or redirect (stone serves six cultures; Nile, Han and Aztec may want their own later). Victory in
  `src/sim/match.gd`: a finished Wonder whose owner is still in starts a countdown
  (`rules.wonder.hold_seconds`, 600); standing that long wins for the owner's team; a fallen one stops
  (a new one starts from the top); `rules.wonder.victory: false` turns it off. The list of standing
  Wonders and their start ticks is in the hash. Everyone gets an alert when one is finished or falls
  (events "wonder"), and the countdown sits under the top bar for all (`src/view/wonder_clock.gd`).
  The bot (`data/ai.json` "wonder"): in age 3 with 150% of the cost in every stock it lays one by its
  Town Center with 8 builders; an enemy Wonder it knows of (seen, or finished: announced) is the first
  target of every attack, and a finished one gets everyone sent at once. An unfinished Wonder no
  longer holds up the bots' other building. No lobby toggle for the host rule yet (data only).
- **Phase 3 (2026-10-13, Claude):** towers and garrison.
  - **Outpost** (age 1, 25 wood, 1 tile, sight 11, no attack, nobody inside). Three concept looks in
    every architecture (`outpost_pole`, `outpost_deck`, `outpost_beacon` in `models.gd`; sheet 120):
    built for now as `OUTPOST_LOOK`: the deck for thatch, reed and mound, the mast for junk and tent,
    the beacon cairn for stone. Dominic to pick.
  - **Bastion** (`buildings.json` `bastion`, `"upgrade_of": "watchtower"`): 1300 hp, 14 pierce, range
    8, garrison 6, its own look per architecture (sheet 121). The effect kind `tower_upgrade` is
    `{"building": "watchtower", "becomes": "bastion"}` in `tech.json`: every Watchtower becomes a
    Bastion where it stands (same id, health share, queue, people inside), and a Watchtower ordered
    afterwards is laid as a Bastion (`Economy.upgraded`). The research sits at the University (phase 4).
  - **Garrison** (`src/sim/garrison.gd`, data `"garrison": N` on a building type, rules in
    `buildings.json` `garrison`): Town Center 10, Watchtower 4, Bastion 6 (the Castle gets it by
    data). Units inside leave the units arrays (no sight, no target, no pushing) and live on the
    building as records in the hash; pop still counts them; they heal 1 hp a second; each adds an
    arrow (towers 1 + inside, the Town Center 0 + inside); ungarrison, a falling building spills them
    with their own ids. Riders and giants (`large`) stay out, workers always fit (centaur workers are
    large). Right-click your own building to send units in; the panel shows "n of N inside" and
    Ungarrison; a count shows over the roof.
  - **Call to arms / Back to work** on the Town Center: workers within 16 tiles run to the nearest
    building with room; back to work sends every sheltering worker to the resource it was gathering.
  - **More Town Centers:** `"more_from_age": 3`; a Town Center now costs 275 wood + 100 stone (the
    first is free at the start).
- **Phases 4 and 5 (2026-10-13, Claude):** the University (3 x 3, 200 wood 50 stone) and the
  Castle (4 x 4, 650 stone, 4800 HP, a volley of 4 arrows at 8 tiles, `garrison: 20` for phase 3's
  system, +10 pop) are in every architecture, built from one vocabulary per culture (its tower,
  wall and hall in `models.gd`), so a castle reads as its culture. Concept round: three layouts
  each (Castle: curtain, motte, great tower; University: observatory, cloister, builders' yard),
  sheets 140-151; until Dominic picks, `CASTLE_LOOK` and `UNIVERSITY_LOOK` in `models.gd` say
  which each culture builds (the building sheet shows any look as `castle:<arch>:<look>`). The
  research: Stonecutting, Lifting Frames, Slit Windows (a building effect on `range`; building
  effects may now name a list of ids), Thick Walls, Siege Wrights (by the `siege` tag, no units
  yet), War Drums, and the race slots as generic placeholders (soldiers +5 HP / +5% speed) for
  milestone 14. A shooting building's `attack.arrows` (default 1) looses that many, one at each of
  the nearest foes in turn. The Bastion research stays phase 3's (it lives at the University).
  The bot builds a University and a Castle in age 3 (steps of a later age no longer hold up the
  build order) and buys Lifting Frames and Stonecutting (`research.buildings`); War Drums by its
  army. Checks: `test_sim` (each effect, the volley, Slit Windows' reach), `test_ai -- <map> age3`.
  Age 3 still needs the Stable, as before (unchanged).
- **Phase 8 (2026-10-13, Claude):** the AI plays the ages and the new content (`src/ai/bot.gd`,
  `src/ai/eco_bot.gd`, `data/ai.json`; no sim changes).
  - **A goal steers the economy.** What the bot saves for (`_goal`): the next age, plus the
    building the age needs, once it has `age_workers` (15) / `age3_workers` (Easy 24, Normal 26,
    Hard 30); else the build step waiting on resources. The worker shares (`EcoBot.shares`) lean
    to what the goal lacks (an age-up: a hundred shares split by the shortfall, the rest halved; a
    building: `build_push` 30), and a resource piled past `plenty` (600) gets nobody. Workers no
    longer stay where they were first sent: one gatherer every `rebalance_every` (2 s) moves from
    the resource most over its share to the one most under. Soldiers and research leave the
    age's cost alone (while nobody raids it; age 1's guard trains while the age-up runs), and a
    building-up level's soldiers leave alone the cost of steps marked `save` (the buildings the
    ages and the content need). Gold income starts as age 2 does (a mining camp by gold is the
    first age-2 step, gold in the age-2 mix), a stone camp and a Watchtower by the gold follow.
  - **Fixes found on the way:** farms were never built once wild food ran out (farms followed the
    food gatherers, and with no food left there were none: a deadlock that starved age 3), now
    they follow food's share, and go up beside other foundations; a boar hunt killed seven
    workers in age 1 (now soldiers must lead it); buildings could seal a pocket with houses and
    forest, and soldiers trained into it never left (`_seals`: the ground round a footprint
    must still join up and reach out); waves sent the soldiers already out and left the new ones
    at home; trickles of a few soldiers walked into Town Center arrows one by one (under half a
    wave out, they come home to join the next).
  - **Content:** a University and a Castle in age 3 (more builders: 3 and 6), research by plan
    (economy, then the University's: Lifting Frames, Stonecutting, then Bastion and Slit Windows
    once the Castle stands, `research.wait_for`), line upgrades at their own cost, a Watchtower
    by the gold and another where it was raided once quiet (up to the level's `towers`), call
    to arms when a raid on the Town Center outnumbers the soldiers at home (for `shelter.seconds`
    30, then back to work; not again for 120 s: a Town Center full of workers held out for ever
    and bot matches stalled at 30 minutes), a second Town Center by far wood at 40 workers, a
    Siege Workshop and a Market late, the Wonder (as before), workers up to 50 in age 3.
  - **Levels** (data `levels`): Easy builds up most (army 35% of workers per age, sends 40%,
    towers 3, shelters from 2 raiders), Normal (70%, 70%, 2 towers, shelters from 4), Hard (no
    ratio, all, first wave at 4:00, 1 tower, shelters from 8); `all_in`: a big army leaves no
    guard (Easy 60, Normal 36).
  - **Numbers** (Reed Meadow 64; frogs, left alone = waves off against a passive side, 30 min):

    | | before | after |
    |---|---|---|
    | age 2, left alone (Easy/Normal/Hard) | 7:01 / 7:01 / 7:01 | 5:37 / 5:37 / 5:37 |
    | age 3, left alone | 14:15 / 15:12 / 15:13 | 12:35 / 12:41 / 13:46 |
    | by 20:00 (Easy, Normal) | no Castle, no tower; University for Normal only | University, Castle, Watchtower (Bastion), 19-20 research |
    | research by 20:00 (E/N/H) | 18 / 13 / 11 | 19 / 20 / 8 |
    | army pop at 10/20/30 min, Normal | 15 / 60 / 68 | 7 / 29 / 83 |
    | age 2 in matches vs passive | 7:01, 6:13 | 5:37, 4:53 |
    | bot vs bot (Reed Meadow) | 10:02, 16:16, 16:49; nobody in age 3 | 20:35, 24:23, 28:08; the winner in age 3 |
    | bot vs bot (old_forest / river_delta) | - | 9:09, 15:49, 26:26 / 16:29, 24:18, 26:08 |
    | Hard vs Normal (Reed Meadow) | Hard 7:35 | Hard 10:06 |
    | 2v2 (reed_meadow_2v2) | 12:52 | 15:03 (all four in age 3 in the longer runs) |

    Centaur workers cost more, so centaurs still reach age 2 at 7-8 minutes. Bot matches are
    longer because both sides now build up (D-077: a tester metric).
  - **Open:** on old_forest Hard and Normal draw at 30:00 (Hard rushes, Normal's call to arms,
    tower and upgrades hold; a mirror of rats draws too), so `test_ai -- old_forest` fails that one
    check; Hard needs a better plan than "more soldiers" (siege in milestone 13 is the genre's
    answer to a garrisoned Town Center). Not done: cutting through thin woods for a road, healers
    in forest lanes, amphibious bots using swim routes on purpose.

## Changes from the original plan

## Links
- `../roster-template.md` (the earlier role plan this completes)
- `../backlog.md` "Gates" (moves here), naval and gunpowder (stay there)
- D-057, D-070, D-071, D-078, D-080, D-100, D-101 in `../../archive/decisions.md`
