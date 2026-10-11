# Milestone 14: Race identity (asymmetric play)

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

A race = **creature + culture** (+ the prompt's words). Each layer adds a little; the two combine.

| Layer | From the creature | From the culture | From the prompt |
|---|---|---|---|
| Bonuses (always on) | 2 | 1 | - |
| Own research (Castle) | 1 (age 3) | 1 (age 4) | - |
| Lacks (tech tree gaps) | 1-2 | 1-2 | - |
| Signature mechanic | 1 | 1 (a lighter one) | - |
| Unique unit (Castle, milestone 13) | body | gear | signature words |
| Look (have) | body, voice | architecture, gear, paths | wings, mounts |

Rules (unchanged from the project's): data first, no special cases in code; a mechanic is an
**ability kind** in the sim with parameters in data, so any creature or culture (or a mod) can use
it; every ability has a counter; stat bonuses are applied before pricing so units pay for them
(cost is the balancer); economy bonuses are kept small and even. The host's "Full tech tree"
rule lifts `lacks` and `only`.

## Data contract

On `creatures.json` and `families.json` entries:

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

## First draft per creature and culture (for Dominic's picks)

Each row is an offer; the design round below shows 2-3 options each, Dominic picks.

| Who | Bonuses | Own research | Lacks | Mechanic |
|---|---|---|---|---|
| Frogs | amphibious (have); farms in water (have) | Strong Legs (have) | heavy armour tracks | `leap` (infantry) |
| Rats | cheap, quick, houses +1 (have) | Gnawing Teeth (+attack vs buildings) | Citadel Tower, stone gate | `swarm` + `scavenge` |
| Humans | research 15% faster | Clever Hands (build 25% faster) | nothing (the generalists) | none of their own: their culture's |
| Spiders | walls cost half | Sticky Silk (ranged hits slow) | mounted lines | `web` |
| Beetles | +1 pierce armour (shells) | Shell Polish (+1 melee armour) | Quick Draw, mounted archer | `shell` |
| Centaurs | carry 160% (have), faster | Gallop (mounted +15% speed) | walls (they roam) | `fire_on_move` |
| Imperial | buildings 10% cheaper | Shield Wall (infantry +2 pierce) | - | `volley` (infantry) |
| Hellenic | spears +1 melee armour | Long Spears (+reach) | - | `formation` (phalanx) |
| Steppe | mounted +10% speed | Saddle Bows (+1 range) | stone walls | `pack_up` |
| Nile | farms +food | Flood Plains (farms on wet ground) | - | (bonus only) |
| Han | walls and towers stronger | Repeating Bows (reload) | - | (bonus only) |
| Aztec | kills give gold | Jaguar Pelts (infantry speed) | mounted lines | `scavenge` (gold) |
| Swamp, Sewer, Forest, Royal, Spooky | one each, to draft | one each | - | - |

## Plan

1. **Design round** (concept-first, D-080, but for rules): a page per creature and culture with
   2-3 options for bonus, research, lacks and mechanic, each with its counter and a one-line "how
   it feels"; Dominic picks. Written as `docs/concepts/race-identity.md`. Can run now.
2. **Data contract and bonuses.** `bonuses`, `research`, `lacks` fields; today's scattered bonuses
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
- [ ] 1. Design round (Dominic's picks)
- [ ] 2. Data contract and bonuses
- [ ] 3. Own research
- [ ] 4. Lacks
- [ ] 5. Ability system
- [ ] 6. Mechanics
- [ ] 7. AI
- [ ] 8. Balance and the lobby card
- [ ] 9. Exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `m12-tech-tree.md` "Race bonuses" (the first draft) and "New effect kinds"
- `../backlog.md` §8 "Asymmetric gameplay" (the earlier notes this replaces)
- D-070 (restrictions are layers), D-078 (creatures pay back in data)
