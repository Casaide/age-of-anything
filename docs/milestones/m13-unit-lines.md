# Milestone 13: Unit lines

**Status:** planned (after milestone 12; concept rounds can start earlier)
**Exit criterion:** the tech tree page shows no blank nodes for land; every line trains, fights by
its counters, and the AI uses it; a balance round robin at ages 3 and 4 with no line more than 20%
off at equal cost; Dominic plays a match using siege and mystics.

The second half of the full land tree (Dominic split it, 2026-10-11). The tree itself, with every
line, its building, ages and counters, is in `m12-tech-tree.md` ("Unit lines"). Milestone 12
leaves the buildings standing; this milestone fills them. The 14 planned roster slots are already
in `data/rules/*.json` with `"status": "planned"`.

## Scope

| Building | Lines | New systems |
|---|---|---|
| Barracks | Swordsman (1-4), Raider (3-4) | none: parts exist (swords, clubs); raider = light, fast |
| Archery Range | Mounted Archer (3-4) | none: the generator already makes horse archers |
| Stable | Scout (2-4), War Beast (3-4) | big beasts (bodies) |
| Siege Workshop | Ram, Catapult, Bolt Thrower (3-4), Siege Tower (4) | siege bodies; splash, minimum range, attack vs buildings, carrying units over walls |
| Castle | Unique (3, elite 4), Sapper (3), Great Sling (4) | the unique slot's bigger budget; self-destruct; pack/unpack |
| Temple | Mystic (3-4) + six research | healing, conversion |
| Market | Trade Cart (2) + cart research | trade routes between your markets |

Out: relics (backlog), naval, gunpowder.

## Plan

Each phase: concept round first where there's new art (D-080: 3-5 options at game scale, Dominic
picks), then build, tests, archive pictures.

1. **Lines from parts we have.** Swordsman, Raider, Scout, Mounted Archer: roster slots go live,
   the generator's role needs and biases (`src/race_generator.gd` ROLE_NEEDS / ROLE_BIAS), counter
   tags, pricing check in `tests/balance.gd`, the bot's counter-picks learn them. Light scout gear
   is the one small parts gap.
2. **Combat systems siege needs.** Splash damage (an area, falling off), a minimum range, an
   attack bonus vs buildings, projectiles that can miss a moving target (so siege is dodgeable),
   and units that carry others (the siege tower). Headless tests for each.
3. **Siege, concept round per family.** A ram, catapult, bolt thrower and siege tower in each
   family's own take (a beetle-drawn ram, a frog catapult on a lily-pad sledge, a rat bottle-cap
   sling, timber engines for humans). Then build them as parts and recipes; Siege Workshop trains.
4. **Castle units.** The unique unit: a slot with a bigger point budget, picked from the prompt's
   signature words (the generator's showcase: "romans" -> a testudo legionary); its elite step at
   age 4. The sapper (walks up and blows a hole in a wall). The great sling (long-range anti-building,
   packs and unpacks).
5. **Mystics.** Staff and robes concept round; heal nearby wounded; convert an enemy unit after a
   channel (large units and beasts first; buildings and siege with Deep Faith); a recharge between
   conversions; the six Temple research. The counter: scouts and raiders.
6. **Trade carts.** Between two of your markets: gold by distance, carts walk the route; the
   market's cart research (Pack Animals, Merchant Halls).
7. **War beasts.** Concept round: elephants for humans, giant toads for frogs, capybara-scale beasts
   for rats, a rhino beetle, a tarantula; tanky vs buildings and infantry, weak to spears and mystics.
8. **AI.** The bot trains every line by its counter-reading; uses siege against towers and walls,
   mystics behind its army, trade when it has two markets.
9. **Balance and exit check.** `tests/balance.gd` round robin at ages 3 and 4 with every line;
   no line more than 20% off at equal cost (or price-by-simulation, with Dominic's go-ahead);
   Dominic's match.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Swordsman, raider, scout, mounted archer
- [ ] 2. Siege combat systems
- [ ] 3. Siege engines (concept round per family)
- [ ] 4. Unique unit, sapper, great sling
- [ ] 5. Mystics and the Temple research
- [ ] 6. Trade carts
- [ ] 7. War beasts
- [ ] 8. AI
- [ ] 9. Balance and exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `m12-tech-tree.md` (the tree), `m14-race-identity.md` (what each race does with these lines)
- `../roster-template.md` (the role plan and per-family variants)
