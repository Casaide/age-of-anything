# Milestone 14: Race identity and heroes (asymmetric play)

**Status:** in progress (2026-10-16: bonuses, own research, lacks, the ability system with the web, the AI, heroes (D-138) done; the other mechanics, balance, bears and the exit check left)
**Exit criterion:** every playable creature and every culture has its bonuses, its own research,
what it lacks, and one signature mechanic, all as data and all shown on the tech tree page; each
mechanic has a counter and a headless test; the bot uses its race's mechanic; a round robin of
race pairs shows no race winning more than 60% at equal skill (bot vs bot); Dominic can name what
makes each race he plays different.

Dominic (2026-10-12): "the differing special features between races". Today races differ by their
units' look and stats, plus a few scattered economy numbers (rats cheap, centaurs carry more),
movement classes (frogs swim) and one race-only research (Strong Legs). This milestone gives every
race the genre's full kit of identity, layered so absurd prompts still combine.

## How a race gets its identity

A race's bonuses are **mixed** from every layer it belongs to (Dominic, 2026-10-12: "bugs +
beetles, or humans + Aztecs"): a broad **group** (bugs, amphibians, rodents, folk), the
**creature** inside it, and the **culture**. So a beetle race gets one from bugs, one from beetles
and one from its culture; Aztec humans get one from folk, one from humans and one from Aztec.
Every race ends up with the same number of bonuses whatever it's made of, so an absurd mix stays
as strong as a plain one.

| Layer | Example | Bonuses | Own research (Castle) | Lacks | Mechanic |
|---|---|---|---|---|---|
| Group | bugs (beetles, spiders), amphibians (frogs), rodents (rats, capybaras), folk (humans, centaurs) | 1 | - | - | - |
| Creature | beetles | 1 | 1 (age 3) | 1-2 | 1 |
| Culture | Aztec, Imperial, Swamp... | 1 | 1 (age 3) | 1-2 | 1 (lighter) |
| Prompt | "cheese hammers", wings | - | - | - | the unique unit's signature (milestone 13) |

- **Groups** are data: `creatures.json` gains `"group": "bugs"`, and a new `data/groups.json`
  holds each group's bonus (bugs: workers carry more? cheap houses; amphibians: farms in water;
  rodents: houses hold more; folk: research faster). A creature with no group gets a second
  creature bonus instead, so the count stays even.
- **Combos:** a few creature + culture pairs that belong together (Aztec + jaguar-like creatures,
  Han + pandas once those exist) may get a small extra flavour **note** and a name twist, but not
  an extra bonus: the count stays even. Off-beat mixes (spooky beetles, Roman frogs) are the fun
  and stay legal.
- **Duplicates stack only once:** if group and creature both give the same kind of bonus (two
  "+1 pierce armour"), the second is swapped for its listed alternative, so no race doubles up.
- The tech tree page lists each bonus with where it came from ("Bugs", "Beetles", "Aztec").

Rules (unchanged from the project's): data first, no special cases in code; a mechanic is an
**ability kind** in the sim with parameters in data, so any creature or culture (or a mod) can use
it; every ability has a counter; stat bonuses are applied before pricing so units pay for them
(cost is the balancer); economy bonuses are kept small and even. The host's "Full tech tree"
rule lifts `lacks` and `only`.

## Three rules for asymmetry with generated races (agreed 2026-10-12)

Hand-made factions can go all in because players learn each matchup; ours are generated, so
nobody knows "how rats play" in advance:
1. **Self-explaining:** a mechanic shows on the unit (a web, a shell closing, a leap) and fits on
   one line of the lobby card and the tech tree page.
2. **At most one strong mechanic per race, and never a different economy:** identity comes from
   dials on the shared game, not replacing it.
3. **From a shared vocabulary** of ability kinds with parameters in data, so any mix works and
   the AI uses them without special cases. Start with creature mechanics only; add culture ones
   if races still feel samey.

## Heroes (Dominic, 2026-10-12: "hero unit I think sells generation a lot")

Each race gets one **hero**: a named, generated champion that is the face of the race, the most
exciting thing a prompt produces ("sewer rats with cheese hammers" -> Grand Gnawer Brie the
Unwashed, riding the biggest capybara, wielding the wheel of cheese).
- One per player, trained once at the Castle (or the Town Center in age 3, to decide), revived
  for a cost if it falls; a bigger point budget than any unit, its own name from the culture's
  name parts and the prompt's signature words.
- An aura (nearby units +1 attack or armour, or the race's mechanic stronger near it); tanky but
  beatable; heals slowly.
- Shown big on the lobby card and the tech tree page; regicide uses it (milestone 18).
- Concept round per family for the hero look (scale, a standard bearer, a cape...).

## Land-shaping (decided 2026-10-12: only as race abilities)

Changing the land for other races is worth it only small and fair: as a few race abilities, not
a general system; every change wears off or can be undone, and every one has a counter (permanent
damage reads as griefing). Candidates: beavers' dams flood a strip until the dam is smashed
(needs rivers, milestone 15); spiders' webs slow until burnt or decayed; rats' tunnels link two
burrows until one is found and collapsed; fire burns trees that regrow.

## Data contract

On `data/groups.json`, `creatures.json` and `families.json` entries (bonuses carry an `alt` for
when a race already has that kind):

```json
"bonuses":  [{"text": "Hard shells: every unit +1 pierce armour", "effects": [{"tag": "all", "stat": "armour.pierce", "add": 1}]}],
"research": ["shell_polish"],
"lacks":    ["mounted_archer", "citadel_tower"],
"ability":  {"kind": "leap", "tags": ["infantry"], "range": 3000, "cooldown": 300}
```

Effects reuse milestone 12's effect kinds. Ability kinds are a small vocabulary in
`src/sim/abilities.gd`, one function each, chosen to cover many races:

| Ability kind | What it does | Counter |
|---|---|---|
| `leap` | jump a few tiles (over a gap or onto ranged units), cooldown | spears, stand-ground lines |
| `swim` / `build_on_water` | cross and build on shallows (have, partly) | towers on the shore |
| `web` | lay a slowing patch (a cheap building or a hit effect) | ranged units, fire (burning) |
| `burrow` | hide underground (unseen, can't act), pop up elsewhere nearby | outposts and towers see it surface |
| `shell` | stop and close up: big pierce armour, can't move | melee, siege |
| `volley` | throw once before closing to melee (a pilum) | spread out, skirmishers |
| `formation` | a block gets a frontal armour bonus while together | flanking cavalry, splash |
| `fire_on_move` | ranged mounted units shoot while moving | spears, skirmishers |
| `swarm` | cheap, quick to train, more per house (economy numbers, have) | splash, towers |
| `trample` | big units push through and hurt small ones | spears |
| `scavenge` | kills give a little food | quick wins hurt them |
| `pack_up` | buildings pack and move (nomads) | raids while packed |

## The bonuses (final for now: Dominic, 2026-10-12, "bonuses sound good for now")

Every race gets one group, one creature and one culture bonus (three); if two give the same kind,
the second takes its alternative. Own research: one from the creature and one from the culture,
both at the Castle in age 3. Culture mechanics are left out for now (creature mechanics first).

**Groups**

| Group | Creatures | Bonus | Alternative |
|---|---|---|---|
| Bugs | beetles, spiders | houses cost 30% less (they dig in) | +5% gather speed |
| Amphibians | frogs | farms in water (rice paddies) (have) | farms hold 20% more food |
| Rodents | rats | houses hold 6 instead of 5 (have) | workers carry +2 |
| Folk | humans, centaurs | research 15% faster | research 10% cheaper |

**Creatures**

| Creature | Bonus | Own research | Lacks | Signature mechanic |
|---|---|---|---|---|
| Frogs | amphibious: swim shallows, faster in swamp (have) | Strong Legs: amphibians +2 speed (have) | Ring Mail | leap (infantry onto ranged units) |
| Rats | units 30% cheaper, train 20% faster (have) | Gnawing Teeth: +2 attack vs buildings | Bastion, stone gate | swarm + scavenge (kills give a little food) |
| Humans | workers build 15% faster | Clever Hands: build 25% faster | nothing (generalists) | none (their culture's, later) |
| Spiders | walls cost half (silk) | Sticky Silk: ranged hits slow | stable lines | web (a slowing patch) |
| Beetles | every unit +1 pierce armour (shells) | Shell Polish: +1 melee armour | Quick Draw, mounted archer | shell (stop and close up) |
| Centaurs | carry 160%, faster (have) | Gallop: mounted +15% speed | walls (they roam) | shoot on the move |

**Cultures**

| Culture | Bonus | Own research | Lacks |
|---|---|---|---|
| Imperial | buildings 10% cheaper | Shield Wall: infantry +2 pierce armour | - |
| Hellenic | spears +1 melee armour | Long Spears: spears +1 reach | - |
| Steppe | mounted +10% speed | Saddle Bows: mounted archers +1 range | stone walls |
| Nile | farms +20% food | Flood Plains: farms on wet ground | - |
| Han | walls and towers +20% hit points | Repeating Bows: ranged reload 15% faster | - |
| Aztec | kills give a little gold | Jaguar Pelts: infantry +10% speed | stable lines |
| Swamp | no slowdown in swamp or shallows | Bog Poultice: healers heal 30% more | stone walls |
| Sewer | buildings go up 15% faster (junk) | Rust Spikes: melee +1 vs buildings and siege | Bastion |
| Forest | wood gathered 10% faster | Woodsmen: workers carry +2 wood | bolt thrower |
| Royal | heavy cavalry 10% cheaper | Chivalry: mounted +20 hit points | skirmisher's age-3 step |
| Spooky | units +2 sight | Creeping Dread: enemies near your army move 10% slower | market trade |

## More bonuses: six per race (Dominic, 2026-10-13)

Dominic: "we're not doing enough on the race bonuses. Simple things like chopping wood faster, or
mining faster. Look at the genre regarding symmetric or asymmetric: the classic games are symmetric
and there are still sizeable race differences."

**What the genre does.** The classic games share one tech tree and one unit roster (symmetric), and
make each civilisation feel different with about five or six small bonuses on top: one or two to the
economy (a resource gathered faster, cheaper drop-off camps, farms that last longer, extra food at
the start), one or two to its army (a line cheaper, faster to train, or a little tougher), something
for its buildings (cheaper houses, sturdier walls, faster building), a team bonus that also helps its
allies, plus a unique unit and a couple of its own techs, and a few holes in the tree. No single
bonus decides a match; together they decide how you want to play. We already have the shared tree,
own research, the unique unit and lacks; what was thin was the bonuses (three per race).

**The rule now** (src/identity.gd): the group gives one bonus, the creature two (three with no
group), the culture three, one of them a **team bonus** (`team`: its effects reach the race's allies
too; never a priced unit stat, since pricing doesn't know the allies). Six per race. As before, a
later layer's bonus of a kind the race already has takes its `alt`, so nothing doubles; every
creature with every culture is checked (tests/run_tests.gd). The creatures' bonuses lean to the
economy and the body (what the animal is good at); the cultures' to the army, buildings and the team
(what the people are good at). Each resource now has a race that's good at it: food (frogs,
centaurs), wood (beetles, forest), stone and gold (rats), gold (humans).

New effect shapes (the D-111 research shape, src/sim/tech.gd): `{"start": "food", "add": 100}`
(more at the start, set in Economy.setup) and the building pct `age_time` (the age-up at that
building, Tech.head_ticks).

**Groups** (unchanged: one each)

| Group | Bonus | Alternative | What it says |
|---|---|---|---|
| Bugs | houses cost 30% less | gather 5% faster | they dig in rather than build |
| Amphibians | farms in water (rice paddies) | farms hold 20% more food | they live in the shallows |
| Rodents | houses hold 6 | workers carry +2 | they pack in |
| Folk | research 15% faster | research 10% cheaper | the tool-using thinkers |

**Creatures** (the m14 bonus, then the new one; alternatives for when a culture's doubles it)

| Creature | Bonus 1 | Bonus 2 (new) | Alternative to 2 | What it says |
|---|---|---|---|---|
| Frogs | amphibious | Long tongues: food gathered 20% faster | workers carry +2 | they snap up food |
| Rats | units 10% cheaper (was 20%), train 20% faster | Burrowers: stone and gold mined 10% faster | food gathered 5% faster | a swarm that burrows for treasure |
| Humans | workers build 15% faster | Prospectors: gold mined 15% faster | stone mined 15% faster | generalists who dig for gold |
| Spiders | walls and gates cost half (silk) | Silk-spun camps: Lumber Camp, Mining Camp and Mill cost 25% less | Watchtowers +20% HP | they spin what others build |
| Beetles | every unit +1 pierce armour (shells) | Bark borers: wood gathered 15% faster | stone mined 20% faster | armoured wood-borers |
| Centaurs | workers carry 60% more | Foragers on the move: food gathered 15% faster, +100 food at the start | farms hold 20% more food | grazers on a horse's back |

**Cultures** (the m14 bonus, a new one, and a team bonus)

| Culture | Bonus 1 | Bonus 2 (new) | Team bonus (new, allies too) | What it says |
|---|---|---|---|---|
| Imperial | buildings 10% cheaper | Drilled legions: foot soldiers train 20% faster | Granaries: farms hold 10% more food (alt: houses +10% HP) | an empire of builders and drilled foot |
| Hellenic | spears +1 melee armour | Drill yards: Barracks research 30% cheaper | Agora: Market 25% cheaper | the phalanx and the marketplace |
| Steppe | mounted +10% speed | Horse archers: mounted archers 10% cheaper | Herds: food gathered 5% faster (alt: units +1 sight) | riders who live off their herds |
| Nile | farms hold 20% more food | Monuments: ages advance 20% faster | Granary of the river: +100 food at the start | the river's harvest builds monuments |
| Han | walls and towers +20% HP | Paper and ink: research 10% cheaper (alt: Archery Range research 30% cheaper) | Grain stores: Mill 25% cheaper | walls, books and grain |
| Aztec | kills bring in 5 gold | Obsidian edges: foot melee +1 attack | Flower wars: healers heal 15% more | warriors who take captives |
| Swamp | no slowdown in swamp or shallows (alt: farms hold 20% more food) | Reed mills: Mill and farms 25% cheaper | Marsh lookouts: buildings +2 sight | marsh folk who farm the mud |
| Sewer | buildings go up 15% faster (alt: buildings +10% HP) | Scrap towers: Watchtowers 25% cheaper | Black market: market fee 5 points lower | junk builders and fences |
| Forest | wood gathered 10% faster (alt: food 10% faster) | Woodland archers: bowmen +1 range (alt: +5 HP) | Forest lore: Lumber Camps 25% cheaper | woodsmen and bowmen |
| Royal | cavalry 10% cheaper | Knightly training: cavalry trains 20% faster | Heralds: units +1 sight | knights |
| Spooky | units +2 sight | Night archers: foot archers and skirmishers train 20% faster | Night watch: Watchtowers +1 range | they shoot from the dark |

So a race reads like the genre's civ cards, for example **steppe centaurs**: research 15% faster
(Folk); workers carry 60% more, food gathered 15% faster and 100 more food at the start (Centaurs); mounted 10% faster, mounted
archers 10% cheaper, and allies' units +1 sight (Steppe; the herds' food doubles the centaurs', so
it takes its alt); plus Gallop and Saddle Bows at the Castle, and no walls.

## Plan

1. **Design round** (concept-first, D-080, but for rules): a page per creature and culture with
   2-3 options for bonus, research, lacks and mechanic, each with its counter and a one-line "how
   it feels"; Dominic picks. Written as `docs/concepts/race-identity.md`. Can run now.
2. **Data contract and bonuses.** Groups (`data/groups.json`, `group` on creatures), the `bonuses` (with `alt`), `research`, `lacks` fields, mixed per race; today's scattered bonuses
   moved in (creature economy, movement, Strong Legs); stat bonuses applied before pricing; the
   effect kinds from milestone 12; the tech tree page reads them (replacing `data/bonuses.json`).
3. **Own research.** Each creature's and culture's Castle research, live in the Castle's two slots.
4. **Lacks.** The tech tree filter for each race (D-070 layer), shown crossed out on the page, lifted
   by Full tech tree; the bot never plans around what it lacks.
5. **Ability system.** `src/sim/abilities.gd`: per-unit cooldowns in the units arrays, an ABILITY
   command (and auto-use where the genre does: volley, fire on move), deterministic, in the state
   hash and replays; a panel button with the ability's icon and cooldown.
6. **Mechanics, one at a time,** each with a test of the counter: leap, web, shell, volley,
   formation, fire on move, swarm/scavenge, burrow, pack up, trample (as picked in phase 1).
   Visual tells for each (concept round where new art: webs, a closed shell, a formation look).
7. **AI.** The bot uses its mechanic (shell when shot at, leap onto archers, webs at chokes, volley
   before charging) and reads the enemy's (keeps clear of webs, flanks a phalanx).
8. **Balance.** A race-pair round robin (bot vs bot, several maps and prompts): no race over 60%;
   tune by data. The lobby's race card lists the bonuses and mechanic in a line or two.
9. **Exit check.** Dominic plays three races and says what makes each different.

## Checklist
- [ ] Plan approved by Dominic
- [x] 1. Design round: bonuses, research and lacks agreed (2026-10-12); mechanics' details still to design
- [x] 2. Data contract and bonuses (2026-10-13: `data/groups.json`, creatures' and cultures' `bonuses`/`research`/`lacks`, `src/identity.gd`; race keys unchanged)
- [x] 3. Own research (2026-10-13: 14 live at the Castle, Strong Legs stays at the Barracks; Flood Plains and Creeping Dread planned)
- [x] 4. Lacks (2026-10-13: research, buildings, lines, a line's step, market trade; crossed out on the page; the bot skips them)
- [x] 5. Ability system (2026-10-13: `src/sim/abilities.gd`, the ABILITY command, a panel button; the web; placeholder mark on the ground)
- [ ] 6. Mechanics (the web only so far; leap, shell, swarm/scavenge, shoot on the move to come; the web's look needs a concept round)
- [x] 7. AI (2026-10-13: webs on the nearest foes, own research bought; bonuses are stats)
- [ ] 8. Balance and the lobby card (lobby card done; six bonuses a race and a balance pass 2026-10-14: every race 33-68% over two maps, frogs and rats at the edges, see Results)
- [x] 9. Heroes (generated champion, aura, revive; concept round HR1 done 2026-10-13; D-131: all of HR2's characters as a pool; D-138: every race gets all of its pool's heroes)
  - WIP 2026-10-14 (Claude): `data/heroes.json` (names, 21 signatures with auras, rules), hero parts in `data/parts.json` (only_if hero_only), a `hero` roster line (age 2, Town Center), `src/heroes.gd` (derived from the race key, not in it), `src/sim/heroes.gd` (aura, regen, revive), the bot, models in `scenes/art_pixel/hero_models.gd`, the unit card's temper and aura, `tests/test_heroes.gd`.
  - Resumed 2026-10-16 (Dominic: "heroes i thought we'd do all of them, so each race has some variety"), finished on branch `heroes-all` (Claude). **The rule (D-138):**
    - A race gets every signature naming its creature or its culture (sorted by id); one with fewer than `rules.min_heroes` (3) is topped up from its culture's `kin` (heroes.json: two kindred cultures each, nearest first). In the base game that tops up humans (one culture hero each), spooky spiders and forest beetles; every playable race has 3 or 4 heroes.
    - Each hero is its own unit type on the hero line (TRAIN/SPAWN name it: args `hero`). Each is trained once at the Town Center from age 2; one of each is ever out (queued, alive or sheltering); all of a race's heroes may be out together. A fallen one is revived at the Town Center after 60 s for 60% of its price.
    - Auras don't add up: a friend near several heroes takes the strongest of each stat (+1 attack, +1 melee, +1 pierce at most).
    - Names: each hero its own draw from the race key and its signature; a race's heroes never share a given name (a kindred hero borrows one from its own culture when the race's lists run out).
  - **Done 2026-10-16:** the Town Center's Heroes group (a button per hero: Train / Revive with its price, or why not: out already, on the way, revives in N s); a small gold crown over each hero in the field, its name while selected; the tech tree page (a node per hero, temper and aura) and the lobby (a Heroes group in the traits strip, "N lines; 3 heroes"); sounds `hero_up` and `hero_fell` (tools/audio/sfx.py, rendered, keep imports) with an alert line (yours, and a foe's you saw fall); the bot saves for its next hero and fields another every 3 soldiers (`data/ai.json` military.hero.more), a hurt one walks home to heal.
  - **Placement:** `tests/placement/cases.gd` hero_cases: every hero look on every playable body it can come to (any culture's on any creature), age 3, plus every PROMPTS race's own heroes at every age. The fix pass: a body may declare a `drape` socket and a `drape_scale` (frog, rat, spider, rearing beetle) for back pieces tagged `drape` (the long capes, the lion pelt, the moss mantle), applied by UnitView and the 3D check alike; low-slung hat variants (`hero.*_low`: nothing hanging behind the head, a size smaller, set back) and a per-creature `fit` in heroes.json (a variant, or "" to keep the race's own weapon where a shouldered one would cut a spider's legs); a look with no back piece stows the swordsman's banner or cape in its kit; the Unkillable's roach moved to the far shoulder, the heraldic cape flares back. `placement_check.gd` passes in full (19724 checks).
  - **Balance:** flat stats made a 22 hp rat's hero five times its swordsman and a centaur's twice, so the line now uses `stats_pct` (pricing.gd: 300% hit points, 130% attack), no armour bonus, 30 price points (a rat's hero about 665, a centaur's 885), healing 1 hp every 3 s. `tests/mass_battle.gd -- 2 heroes` (all of a race's heroes plus soldiers against soldiers at equal cost, twice the budget): see Results.
  - Pictures: `archive/images/2026-10-16/` (lineup sheets, the match, the Town Center's buttons). The Regicide rule stays for milestone 18.
- [ ] A new creature: bears (two legs, armoured, dignified, "the smarter version compared to rats"; rideable for some races; bigger polar or older bears; see the backlog entry). Dominic: plan once milestone 13 is done
  - [x] Concept round B1 (2026-10-13): three builds (brown, black, polar), the worker, the mount, the giants, built with the creature kit, all passing placement (`docs/concepts/bears/`, data staged in `data/later/bears.json`). Waiting on Dominic's pick.
- [ ] 10. Exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

**Phases 2-5, 7, 8 (part) and 9's concept round (2026-10-13, Claude):**
- **Data:** `data/groups.json` (the four groups' bonuses and alternatives; the movement words that
  were in `data/bonuses.json`, now gone), `group`/`bonuses`/`research`/`lacks` on the six playable
  creatures and the eleven cultures, the spiders' `ability`. `src/identity.gd` mixes them: one bonus
  per layer, a doubled kind (same scope and stat, or the same `kind`) takes its `alt`. Every creature
  with every culture resolves to three bonuses (checked in `tests/run_tests.gd`).
- **Applied:** unit stat bonuses go into the eval before the price, with the bonus's `price_points`
  (beetles' shells, hellenic spears, steppe riders pay a point); cost and train-time bonuses there too
  (rats, royal cavalry). The rest work like research the race was born with (`Tech._effects`): building
  cost (new `cost` pct: bugs' houses, spiders' walls, imperial buildings), house `pop` (rodents), carry
  pct (centaurs), research time, farm food, wall hp, gathering, sight, `kill_gold` (Aztec), `wade`
  (swamp folk), `reach` (Long Spears), heal pct (Bog Poultice), `slow_on_hit` (Sticky Silk). The
  creatures' old `economy` blocks moved in; **race keys unchanged** (426 prompt/rules/reroll keys
  compared before and after; a test checks the key ignores stats).
- **Own research:** 14 live at the Castle in age 3 (Strong Legs stays at the Barracks in age 2, as
  it was); Flood Plains (farms on wet ground) and Creeping Dread (an aura) planned. A race's page shows
  only its own; the plain tree and the full tech tree show all.
- **Lacks:** research, buildings (and the lines they train), lines, a line's step
  (`line.skirmisher.3`) and `trade`; refused in the sim, crossed out on the page, skipped by the bot's
  build order, counter-pick and market. Age 3 asks for a Stable; a race without one needs an Archery
  Range instead (`requires_else`, found when the page said spiders needed a Stable they can't build).
- **Abilities:** `src/sim/abilities.gd`, the ABILITY command, per-unit cooldowns and webs in the state
  hash, a panel button in the match. The **web** (spiders): a slowing patch (half speed, 15 s, 5-tile
  throw, 30 s cooldown, 45 s since 2026-10-14) that wears off; counter: shoot over it or go round. Its look on the ground is a
  placeholder mark until a concept round. The bot throws webs on the nearest enemy soldiers.
- **AI:** bonuses are stats; own research comes through the usual research rules (worker ones listed
  in `data/ai.json`); webs 25-270 a match.
- **Lobby and page:** bonuses ("Houses cost 30% less (they dig in) (Bugs)"), own research and lacks on
  the tech tree page's race panel and the lobby's traits line.
- **Balance** (`tests/race_matches.gd -- reed_meadow`, bot vs bot, both seatings, 35-minute limit):

  | Race | before m14 (main) | with m14 | with rats 20% cheaper |
  |---|---|---|---|
  | swamp frogs | 30% | 30% | 30% |
  | sewer rats | 100% | 90% | 70% |
  | imperial humans | 40% | 40% | 50% |
  | spooky spiders | 40% | 60% | 60% |
  | forest beetles | 20% | 20% | 20% |
  | steppe centaurs | 0% | 0% | 0% |

  The spread was there before the bonuses (rats' cheap swarm; centaurs' workers cost 150 food, three
  times anyone's). Claude cut the rats' discount from 30% to 20% (data, easy to put back); centaurs
  need a pricing call (D-120's worker price) for Dominic. `balance.gd -- 2`: 18 of 33 units off the
  mean by >20% (main: 20), counters won 79% (83%); `-- 3`: 21 of 38 (18), 79% (81%); `mass_battle -- 2`
  as before within a fight or two.
- **Heroes:** concept round HR1, `docs/concepts/heroes/` (three looks on five races, placement passes);
  waiting on Dominic's pick.
- **Pictures:** `archive/images/2026-10-13/428-431` (the page's bonuses; spiders' lacks crossed out,
  with the "Needs a Stable" they couldn't meet; the lobby's traits line; heroes HR1).
- **Not done yet:** leap, shell, swarm/scavenge and shoot-on-the-move; the web's look; culture
  abilities.

**Six bonuses, centaur prices, lacks in the lobby, balance pass (2026-10-13/14, Claude):**
- **Six bonuses per race** (Dominic: "we're not doing enough on the race bonuses"): see "More
  bonuses" above. New effect shapes `start` and `age_time`; team bonuses (`team`) reach allies
  (Tech.setup), checked in tests/test_race_identity.gd on the 2v2 map (the Nile's granary feeds its
  ally, not its foes). Every creature with every culture mixes six with no kind twice
  (tests/run_tests.gd); race keys unchanged (bonuses never touch recipes).
- **Centaur workers 75 food**, not 150: the worker role's price terms got a `ceiling` (75, beside the
  floor of 50) and `pop` (a worker takes one place, even on a horse's body), rules.cost.roles. The
  150 wasn't the cost multiplier: pricing priced a centaur's horse half as a ridden pony (12 points,
  70/30 food/wood); it now prices the fused body it draws (`fused_body`, body.pony_fused: 9 points,
  priced at 11, half food, half wood). And a centaur isn't a rider on a big beast: the fused body
  has `large: false`, so centaurs are mounted (cavalry: fast, rider loses infantry) but take one
  place and spears' bonus against large doesn't reach them. That was the step that moved centaurs
  off 0%; Dominic may prefer them large (then they need cheaper units or bigger houses).
- **Lacks in the lobby:** the lobby's roster is now a line of words (the bake rework); a lacked line
  is struck through in red and not counted ("13 lines: ... ~~Giant Lancer~~ ... ~~Scout~~"), its row on
  hover says why ("not in this race's tree (Spiders have no Stable)"). Picture 639 (archive/images/2026-10-13).
- **Balance** (`tests/race_matches.gd`, both seatings; win share with a draw as half; reed_meadow
  and old_forest, 20 matches a race):

  | Race | main (reed, wins) | now: reed W-D-L | now: old forest W-D-L | now: share of 20 |
  |---|---|---|---|---|
  | swamp frogs | 40% | 0-6-4 | 3-1-6 | 33% |
  | sewer rats | 90% | 3-5-2 | 8-0-2 | 68% |
  | imperial humans | 50% | 3-4-3 | 2-2-6 | 40% |
  | spooky spiders | 40% (old forest 60-80%) | 5-2-3 | 6-0-4 | 60% |
  | forest beetles | 30% | 3-5-2 | 1-2-7 | 38% |
  | steppe centaurs | 0% | 3-4-3 | 7-1-2 | 63% |

  The levers, all data: rats' units 10% cheaper (was 20%) and the rat body priced at 3 points (its
  speed 13 was cheap); the spider body priced at 7 (it was a 6-point body with armour and a bonus
  against ranged) and the web's cooldown 45 s (was 30; every spider throws its own); centaurs as
  above; the bot (data/ai.json): `military.army_floor` (no new worker while the soldiers are under
  25% of the workers, once there's a Barracks: centaurs met the first wave with nobody) and age 2's
  mix 40/35 food/wood (was 45/30: every race piled food and ran out of wood in age 2). Draws went up
  (16 of 60; reed 13 of 30, main 5): the bots trade evenly more often; worth a look when the 35-minute
  limit or the wave sizes are next tuned. One seed per match, so a race moves 10-20 points between
  runs; the reed-only numbers swing more than the two-map share.
  `balance.gd -- 2`: 19 of 33 units off the mean by >20% (main 18), counters 79% (79%); `-- 3`: 21 of
  38, 81%; `mass_battle -- 2` as main within a fight (spears beat the centaurs' cavalry 8 of 10, was
  10: they're no longer large).

### Heroes (step 9, 2026-10-16, D-138)
`godot --headless --path . --script res://tests/mass_battle.gd -- 2 heroes` (and `-- 3 heroes`): side A fields all of
its race's heroes once plus soldiers for the rest, side B soldiers at the same cost (3000 a side), each fought both
ways round, five races. Final settings: 300% hit points, 130% attack, no armour bonus, 30 price points, 1 hp every 3 s.

Age 2:
```
heroes+spears v spears         A wins 10 of 10 (B 0)   value left: A  73%  B  31%
heroes+swords v swords         A wins  9 of 10 (B 1)   value left: A  68%  B  44%
heroes+archers v archers       A wins  5 of 10 (B 5)   value left: A  38%  B  52%
heroes+swords v spear+archer   A wins  5 of 10 (B 5)   value left: A  44%  B  46%
heroes+spears v cavalry        A wins 10 of 10 (B 0)   value left: A  84%  B  16%
heroes+archers v swords        A wins  9 of 10 (B 1)   value left: A  84%  B  26%
```
Age 3:
```
heroes+spears v spears         A wins 10 of 10 (B 0)   value left: A  81%  B  40%
heroes+swords v swords         A wins 10 of 10 (B 0)   value left: A  81%  B  37%
heroes+archers v archers       A wins  6 of 10 (B 4)   value left: A  59%  B  45%
heroes+swords v spear+archer   A wins  6 of 10 (B 4)   value left: A  57%  B  43%
heroes+spears v cavalry        A wins  9 of 10 (B 1)   value left: A  75%  B  39%
heroes+archers v swords        A wins 10 of 10 (B 0)   value left: A  86%  B  26%
```
Reading them: the clean mirrors (archers, spear+archer) are even; "heroes+spears v spears" and "v cavalry" lean A
by the counters (a hero is a swordsman underneath, swords beat spears; spears beat cavalry), and a plain hero priced as
a swordsman already won 7 of 10 in the sword mirror on its auras alone, so the auras are worth a little more than
nothing. The harness ends many fights at 200 s with both sides standing and calls them by value left, which flatters a
hero that heals and outlives its escort (raising the price raised A's "value left"); the earlier flat stats (+120 hp,
+4 attack, +2/+2) won 60 of 60 with ~95% left. Bot matches: the bots save for their next hero and field 2 or 3
(test_ai bvb checks a bot fields several).

## Changes from the original plan

- Strong Legs stays at the Barracks in age 2 (the plan put own research at the Castle in age 3).
- Spiders and Aztecs lack the Stable itself ("stable lines"), so they have no Heavy line at all;
  watch it in the round robin (spiders still do well with webs).
- Rats' units 20% cheaper, not 30% (balance, Claude; Dominic to confirm); then 10% (2026-10-14, with the rat body priced at 3 points).
- Six bonuses a race instead of three (Dominic, 2026-10-13), with a team bonus per culture.
- Centaurs are mounted but not large (one place, no spear bonus against them): Claude's balance call, for Dominic to confirm.
- Alternatives were only agreed for groups; Claude wrote alts for the creatures and cultures that can
  double up (swamp after frogs: food gathered faster; sewer after humans: buildings +10% hp; and more).

## Links
- `m12-tech-tree.md` "Race bonuses" (the first draft) and "New effect kinds"
- `../backlog.md` §8 "Asymmetric gameplay" (the earlier notes this replaces)
- D-070 (restrictions are layers), D-078 (creatures pay back in data)
