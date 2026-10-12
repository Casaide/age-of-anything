# Milestone 13: Unit lines

**Status:** planned (after milestone 12; concept rounds can start earlier)
**Exit criterion:** the tech tree page shows no blank nodes for land; every line trains, fights by
its counters, and the AI uses it; a balance round robin at ages 2 and 3 with no line more than 20%
off at equal cost; Dominic plays a match using siege and healers.

The second half of the full land tree (Dominic split it, 2026-10-11). The tree itself, with every
line, its building, ages and counters, is in `m12-tech-tree.md` ("Unit lines"). Milestone 12
leaves the buildings standing; this milestone fills them. The 14 planned roster slots are already
in `data/rules/*.json` with `"status": "planned"`.

**Before this milestone (Dominic, 2026-10-12):** the 1v1 map needs resources for a long game,
so the new units and the progression can be enjoyed: milestone 15's phase 1 (resource audit, a
dense 64 x 64 and an 88 x 88 Reed Meadow for Dominic to pick by playing) runs first.

## Scope

| Building | Lines | New systems |
|---|---|---|
| Barracks | Swordsman (1-3), Raider (3) | none: parts exist (swords, clubs); raider = light, fast |
| Archery Range | Mounted Archer (3) | none: the generator already makes horse archers |
| Stable | Scout (2-3), War Beast (3) | big beasts (bodies) |
| Siege Workshop | Ram, Catapult, Bolt Thrower, Siege Tower (3) | siege bodies; splash, minimum range, attack vs buildings, carrying units over walls |
| Castle | Unique, Sapper, Great Sling (3) | the unique slot's bigger budget; self-destruct; pack/unpack |
| Town Center | Healer (2-3) | healing (Dominic, 2026-10-12: the Temple and conversion are cut) |
| Market | Trade Cart (2) + cart research | trade routes between your markets |

Out: relics, conversion and the Temple (cut 2026-10-12), naval, gunpowder.

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
   signature words (the generator's showcase: "romans" -> a testudo legionary); no elite step
   (three ages). The sapper (walks up and blows a hole in a wall). The great sling (long-range anti-building,
   packs and unpacks).
5. **Healers.** (Built 2026-10-12. Dominic: "staffs look good; different staffs for each": every
   culture gets its own staff and bag, queued after living towns merges.) The Town Center trains a healer from age 2 (Dominic, 2026-10-12): it heals nearby
   wounded friends, never fights; concept round for its look per family. Built early, see the
   milestone 12 notes; the counter is scouts and raiders.
6. **Trade carts.** Between two of your markets: gold by distance, carts walk the route; the
   market's cart research (Pack Animals, Merchant Halls).
7. **War beasts.** Concept round: elephants for humans, giant toads for frogs, capybara-scale beasts
   for rats, a rhino beetle, a tarantula; tanky vs buildings and infantry, weak to spears.
8. **AI.** The bot trains every line by its counter-reading; uses siege against towers and walls,
   healers behind its army, trade when it has two markets.
9. **Balance and exit check.** `tests/balance.gd` round robin at ages 2 and 3 with every line;
   no line more than 20% off at equal cost (or price-by-simulation, with Dominic's go-ahead);
   Dominic's match.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Swordsman, raider, scout, mounted archer
- [ ] 2. Siege combat systems
- [ ] 3. Siege engines (concept round per family)
- [ ] 4. Unique unit, sapper, great sling
- [x] 5. Healers (built 2026-10-12; the look is a pick pending: HL1 concept sheet, look A in game)
- [ ] 6. Trade carts
- [ ] 7. War beasts
- [ ] 8. AI
- [ ] 9. Balance and exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

**Healers (2026-10-12).** A `healer` roster slot (Town Center, age 2, `own_seed`: its own random
stream, so every other line's recipes are as they were). The generator gives it a staff
(`tool.staff.herbs`; `tool.staff.cheese` for rats, `tool.staff.lily` for frogs) and a bag in the off
hand, a light hat at most, wings only on a winged race; no shield, no armour. Pricing: attack 0,
`heal` from the staff's stat; the staff's 8 points (mostly gold) set the cost (about 60, 45 gold).
Sim: `src/sim/heal.gd`, before combat: the most wounded unit of its own team within `heal_sight`
(6 tiles), walking up to `heal_range` (2.5 tiles) when idle or on an attack-move, `heal_amount` 3 hp
every `heal_reload` 30 ticks (1.5 s); not itself, animals or buildings; heals land together, capped
at full; `units.patient` is hashed. Healers spawn passive, combat skips them, an attack order is
ignored. View: a soft warm-up and three pale motes on the healed unit, a quiet `heal` sound (herb
rustle and a wooden chime), the card says "Heals 3 hp every 1.5 s, range 2.5". The bot trains one
healer per 5 soldiers, at most 2 in age 2 and 3 in age 3, and keeps them 2 tiles behind the army
that's out (on an attack-move), at home otherwise (`data/ai.json` military.healers). Concept sheet
HL1: `archive/images/2026-10-12/60-` and `61-` (A herb staff + satchel, B salve bowl + bandages,
C pale hood + gourd staff, D cheese staff + poultice sack, E lily staff + moss pouch); A with D and
E as the rat and frog variants is in the game until Dominic picks.

## Changes from the original plan

## Links
- `m12-tech-tree.md` (the tree), `m14-race-identity.md` (what each race does with these lines)
- `../roster-template.md` (the role plan and per-family variants)
