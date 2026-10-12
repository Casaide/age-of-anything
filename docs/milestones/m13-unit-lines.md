# Milestone 13: Unit lines

**Status:** in progress (2026-10-13): siege concept round
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

## The line with milestone 16 (sieges), agreed 2026-10-13

13 builds the siege engines as ordinary units that damage things: the ram (hits buildings and
gates hard, weak to melee), the catapult (splash, minimum range), the bolt thrower, the great
sling, and the sapper (destroys a building or wall tile outright). 16 builds everything about
getting over or through walls: breaches as walkable rubble and their repair, walkways and
garrisoned walls, gatehouses and wall towers, ladders, the siege tower (moved here from 13),
defenders' tools, and the Fortress and Siege modes. Neither touches the other's systems.

## Scope

| Building | Lines | New systems |
|---|---|---|
| Barracks | Swordsman (1-3), Raider (3) | none: parts exist (swords, clubs); raider = light, fast |
| Archery Range | Mounted Archer (3) | none: the generator already makes horse archers |
| Stable | Scout (2-3), War Beast (3) | big beasts (bodies) |
| Siege Workshop | Ram, Catapult, Bolt Thrower (3) | siege bodies; splash, minimum range, attack vs buildings (the siege tower moved to milestone 16) |
| Castle | Unique, Sapper, Great Sling (3) | the unique slot's bigger budget; self-destruct; pack/unpack |
| Town Center | Healer (2-3) | healing (Dominic, 2026-10-12: the Temple and conversion are cut) |
| Market | Trade Cart (2) + cart research | trade routes between your markets |

Out: relics, conversion and the Temple (cut 2026-10-12), naval, gunpowder.

## Plan

**Starting with siege (2026-10-13).** Dominic: "why we not done siege yet?". Siege goes first,
ahead of step 1, in this order; the other steps keep their plan below.
- **3a. Siege concept round (now).** The ram, catapult and bolt thrower in each family's own take,
  two directions each, rendered through the unit bake at game scale and 3x with the race's worker
  beside for size, three facings (`tests/siege_concept_sheet.gd`, models in
  `scenes/art_pixel/siege_concepts.gd`, nothing in play). Dominic picks; see "Siege concepts" in
  Results.
- **2. Siege combat systems, trimmed.** Projectiles that can miss a moving target are being built
  right now, separately, as flying arrows for every ranged unit (`src/sim/combat.gd`); this
  milestone builds on them and adds only **splash** (an area, falling off), a **minimum range**
  and the **attack bonus vs buildings**, each with a headless test.
- **3b. Build the picked engines.** Siege bodies as parts (a body with no legs, rolling: the
  engine as one baked part, its crew as composed units if B is picked), recipes and roster slots
  (`ram`, `catapult`, `bolt_thrower` are `planned` in `data/rules/*.json`), pricing, counter tags
  (ram > buildings, weak to melee; catapult > massed archers and infantry, weak to cavalry; bolt
  thrower > infantry lines, weak to cavalry), the Siege Workshop trains them; `tests/balance.gd`
  with siege at age 3.
- **8 (siege part).** The bot brings rams and catapults against towers and walls.
- The line with 16 stays: 13 makes the ram, catapult and bolt thrower ordinary units that deal
  damage; the siege tower, ladders, garrisoned walls, breaches and the modes are 16's.

Each phase: concept round first where there's new art (D-080: 3-5 options at game scale, Dominic
picks), then build, tests, archive pictures.

1. **Lines from parts we have.** Swordsman, Raider, Scout, Mounted Archer: roster slots go live,
   the generator's role needs and biases (`src/race_generator.gd` ROLE_NEEDS / ROLE_BIAS), counter
   tags, pricing check in `tests/balance.gd`, the bot's counter-picks learn them. Light scout gear
   is the one small parts gap.
2. **Combat systems siege needs.** Splash damage (an area, falling off), a minimum range, an
   attack bonus vs buildings, projectiles that can miss a moving target (so siege is dodgeable;
   2026-10-13: being built separately as flying arrows for all ranged units, so this step only
   adds splash, minimum range and the bonus vs buildings). Headless tests for each. (Carrying units over walls is milestone 16's.)
3. **Siege, concept round per family.** A ram, catapult and bolt thrower in each
   family's own take (a beetle-drawn ram, a frog catapult on a lily-pad sledge, a rat bottle-cap
   sling, timber engines for humans). Then build them as parts and recipes; Siege Workshop trains.
4. **Castle units.** The unique unit: a slot with a bigger point budget, picked from the prompt's
   signature words (the generator's showcase: "romans" -> a testudo legionary); no elite step
   (three ages). The sapper (walks up and blows up a building or wall tile: a plain kill here; the rubble and breach are milestone 16's). The great sling (long-range anti-building,
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
  - [x] 3a. Concept round SW1: ram, catapult, bolt thrower, five families, two directions (2026-10-13)
  - [ ] Dominic's pick (direction per engine, family takes)
  - [ ] 3b. Build the pick: parts, recipes, roster slots, Siege Workshop, pricing
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

**A staff per culture (2026-10-13).** Dominic: "staffs look good; different staffs for each". Every
culture in `data/families.json` now has its own staff, and a bag where one reads: imperial a
laurel-wound rod with bronze fittings (leather satchel), hellenic an olive staff (clay flask), steppe
a horsehair-tasselled staff (felt pouch), nile a papyrus reed with its umbel (linen bag), han a bamboo
staff with a medicine gourd (lacquered box), aztec a staff with a fan of plumes (woven pouch), royal a
lantern staff (leather satchel), spooky a crooked bone staff with a candle (dark bottle), forest a
living branch (leaf bundle); swamp keeps the lily staff and sewer the cheese staff. All data: each
part carries its family's tag, `only_if: [family]` (the family is always in the race's tags) and
`favour` 5, the same way the cheese and lily kits are picked; no generator code changed. The herb staff
stays as the fallback. Races whose healer kit didn't change keep their keys (checked over 174
prompt/reroll/rules combinations); a race whose culture now offers a staff gets a new key. Models in
`scenes/art_pixel/unit_models.gd`; `tests/healer_lineup.gd` shows every culture's healer in 8 facings
(`archive/images/2026-10-13/100-` to `102-`).

**Siege concepts SW1 (2026-10-13), waiting on Dominic.** The ram, catapult and bolt thrower, each
in five family takes (timber for every human culture with a cloth trim, swamp frogs, sewer rats,
forest beetles, spooky spiders) and two directions: **A, the engine alone** (one baked sprite, the
crew hidden or implied) and **B, the crew shows** (the race's own units on the engine's sockets:
two beside an open ram, two pulling a pole flinger, one aiming a tripod bolt thrower; the forest's
ram is pushed by a rhinoceros beetle). Models in `scenes/art_pixel/siege_concepts.gd`, built at a
soldier's scale and grown (catapult 1.5x, bolt thrower 1.6x); sheet `tests/siege_concept_sheet.gd`,
three facings, the race's worker beside for size, at 3x and at game scale. Pictures:
`archive/images/2026-10-13/220-` to `225-`, and `docs/concepts/sw1/` (with the full notes).
- Ram: A covered shed (tortoise roof nearly to the ground) | B open ram on A-frames, crew alongside.
- Catapult: A arm-and-cup on wheels or a lily-pad sledge | B tall pole flinger pulled by its crew.
- Bolt thrower: A on a two-wheeled carriage | B on a tripod with a gunner.
- Family takes: frogs on lily-pad sledges (pad shed, reed-bundle ram with a river stone, snail-shell
  cup); rats with bottle-cap wheels (sardine-tin shed, pencil ram, spoon catapult throwing cheese,
  bottle-cap sling, knitting-needle bolt); beetles with log-slice wheels (mossy shed, beetle-horn
  ram, acorn cup, thorn bolt); spiders in dark wood and bone (skull ram, femur arm, web shot).
- At game scale the open ram reads as a ram better than the shed (the log is the silhouette); the
  arm-and-cup catapult reads in every facing; the carriage bolt thrower is small and busy at 1x.
- **Claude's recommendation:** ram B, catapult A, bolt thrower A (a touch bigger): crews where they
  make the silhouette, one sprite where the machine does. **Dominic to pick:** A or B per engine,
  the beetle-pushed forest ram or not, any family take to redo, and the size.

## Changes from the original plan

- 2026-10-13: siege first (Dominic: "why we not done siege yet?"), ahead of step 1. Step 2 shrinks
  to splash, minimum range and the bonus vs buildings: projectiles that can miss are built
  separately as flying arrows for every ranged unit.

## Links
- `m12-tech-tree.md` (the tree), `m14-race-identity.md` (what each race does with these lines)
- `../roster-template.md` (the role plan and per-family variants)
