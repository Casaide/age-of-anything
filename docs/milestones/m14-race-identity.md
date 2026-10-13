# Milestone 14: Race identity and heroes (asymmetric play)

**Status:** planned (design round can run alongside milestones 12-13)
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
- [ ] 2. Data contract and bonuses
- [ ] 3. Own research
- [ ] 4. Lacks
- [ ] 5. Ability system
- [ ] 6. Mechanics
- [ ] 7. AI
- [ ] 8. Balance and the lobby card
- [ ] 9. Heroes (generated champion, aura, revive; concept round)
- [ ] A new creature: bears (two legs, armoured, dignified, "the smarter version compared to rats"; rideable for some races; bigger polar or older bears; see the backlog entry). Dominic: plan once milestone 13 is done
- [ ] 10. Exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `m12-tech-tree.md` "Race bonuses" (the first draft) and "New effect kinds"
- `../backlog.md` §8 "Asymmetric gameplay" (the earlier notes this replaces)
- D-070 (restrictions are layers), D-078 (creatures pay back in data)
