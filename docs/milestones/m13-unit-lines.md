# Milestone 13: Unit lines

**Status:** in progress (2026-10-13): siege engines built (step 3b), steps 2 and 8 (siege part) done
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
  - [x] Swordsman line at the Barracks, ages 1-3 (2026-10-13)
  - [ ] Raider, scout, mounted archer
- [x] 2. Siege combat systems (splash, minimum range, bonus vs buildings, rams for buildings only, bolts through a line; 2026-10-13)
- [ ] 3. Siege engines (concept round per family)
  - [x] 3a. Concept round SW1: ram, catapult, bolt thrower, five families, two directions (2026-10-13)
  - [x] Dominic's pick (D-119: crewed engines, the rats' open ram, the ridden giant beetle)
  - [x] Round 3: the frogs' engines rethought, three directions (2026-10-13)
  - [x] Dominic's pick for the frogs: B, the turtle ram and the toad bolt thrower (D-121)
  - [x] Round 4: the newt as frog cavalry, other frog catapults (the snail first) (2026-10-13)
  - [x] Dominic's pick: the frogs' catapult, the snail (D-122); the newt mount too
  - [x] 3b. Build the pick: parts, recipes, roster slots, Siege Workshop, pricing (2026-10-13)
  - [ ] Dominic's look in a match
  - [x] The newt built as the frogs' cavalry mount (D-122): `body/head/leg.newt` in data and
    `unit_models.gd`, three skins, amphibious, the swamp family's and the frogs' own mount (2026-10-13)
- [ ] 4. Unique unit, sapper, great sling
- [x] 5. Healers (built 2026-10-12; the look is a pick pending: HL1 concept sheet, look A in game)
- [ ] 6. Trade carts
- [ ] 7. War beasts
- [ ] 8. AI (siege part done 2026-10-13: a few engines, rams at gates, walls and towers, catapults at towers)
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

**Siege concepts SW1 round 2 (2026-10-13), waiting on Dominic.** Dominic on round 1: rats are
human-sized, no pencils (D-116); the forest ram as a giant beetle (D-117); crews on every engine
(D-118). Every engine is now crewed by the race's own workers at true scale, and grown to them
(open ram 1.5x round 1's, catapult 1.8x, bolt thrower 2.1x of a soldier-scale build; frog engines
1.25x more, since the frog worker really is that big: the crouched frog is as tall as a human and
twice as wide). Crew sockets name their facing, arm hold and layer (`crew1_f0_reach_in`: swinging
the log from inside the frame). Sheet `tests/siege_concept_sheet_r2.gd` (a "for size" column, then
three facings), models in the round-2 section of `scenes/art_pixel/siege_concepts.gd`. Pictures:
`archive/images/2026-10-13/226-` to `231-`, and `docs/concepts/sw1/siege_r2_*`.
- Rats (sewer junk, human scale): a covered ram roofed like half a barrel (staves under iron hoops,
  rusted plates riveted over the gaps), a sewer grate standing in front as a shield, mismatched cart
  wheels, two rats shoving at poles out the back; an open ram of iron pipe A-frames with the log on
  chains, a hooped scrap beam with a flanged pipe-end head; a catapult with pipe uprights, an iron
  bucket for a cup and a wedge of cheese; a bolt thrower with leaf-spring arms, a pipe trail, an
  iron-rod bolt and a sewer grate as its gun shield.
- Forest: a giant rhinoceros beetle (mahogany, a bark-and-iron cap on its pronotum, a long head horn
  capped in iron with a thoracic horn over it like pincers), low on thick splayed legs, about 2.5
  times a cavalry beetle's length. Ridden: two beetle riders on a howdah, team cloth down its sides.
  Led: a team saddle cloth, a handler ahead on a lead rope and one behind with a goad.
- Humans and frogs, for comparison: round 1's open ram (B) and arm-and-cup catapult and carriage
  bolt thrower (A), crewed. Two crew swing the ram from inside its frame, one shoves at the back;
  the catapult's crew wind at the back and load from the side; the bolt thrower's aim at the trail
  and load beside it. Crew stand behind the machine, so the arm and the bow stay clear.
- At game scale: every ram reads, the giant beetle most of all (a beast first, the team colour only
  on its cloth); the catapult reads in every facing; the bolt thrower is still the weakest, but the
  crew make it read as a crewed gun.
- **Claude's recommendation:** the rats' open ram (pipes and chains) as their ram, since it matches
  the other families' open ram and its crew show; the barrel shed is the better-looking object and
  could be an age-3 upgrade (a covered ram). The forest's beetle **ridden** (the riders make it read
  as a war beast, not a wild one, in every facing). Crewed catapult and bolt thrower as shown.

**Siege concepts SW1 round 3, the frogs (2026-10-13), waiting on Dominic.** Dominic picked the rest of
round 2 but not the frogs' engines ("overusing lilypads and stuff", D-119). Three new directions, each
with a ram, catapult and bolt thrower crewed by the frog worker at true scale, no lily pads: **A, reed
and clay engineers** (the frogs' own reed-town building culture on timber sledges: a reed-bundle log
with a fired-clay, stone-studded head under a small thatch roof; reed uprights, a twisted-reed skein
in daub blocks and a wicker cup of fired clay; a reed-bow bolt thrower firing a sharpened reed spear
behind a wicker mantlet); **B, living swamp beasts** (a giant snapping turtle rams with a frog driving
from a basket; a giant newt carries the catapult; a giant toad carries the bolt thrower); **C, river
engines** (boats dragged through the shallows: a net-wrapped stone ram on crossed punt poles, a
swing beam with a stone basket and a net of stones, a harpoon thrower with its line in a basket).
Sheet `tests/siege_concept_sheet_r3.gd` (per engine, three facings, and a "directions" overview),
models in the round-3 section of `scenes/art_pixel/siege_concepts.gd`. Pictures:
`archive/images/2026-10-13/236-` to `243-`, and `docs/concepts/sw1/siege_r3_*`.
- At game scale A reads best (golden reed parts from the frog crew; roof and log, arm and clay ball,
  mantlet and bow each name the engine in every facing). B's turtle is a strong beast and nothing like
  the beetle; the newt reads; the toad is a big frog carrying frogs. C's boats read, the harpoon best,
  the swing beam more like a crane.
- **Claude's recommendation:** A for all three (their own architecture, the clearest at 1x, the same
  kind of crewed engine as everyone else's), with the turtle kept for a later showpiece (a heavy ram
  or unique unit, as the forest has its beetle).
- Dominic picked B's turtle ram and toad bolt thrower (D-121), not the newt as the catapult carrier.

**Concept round SW1 round 4 (2026-10-13), waiting on Dominic.** Dominic: "Salamander I'm not 100%
sure, I wonder if better for cavalry?", then "catapult on snail maybe?". Two questions, concepts only,
nothing in play. Notes and pictures in `docs/concepts/sw1/README.md` (round 4); archive pictures
`archive/images/2026-10-13/244-` to `253-`.
- **The newt as frog cavalry** (`tests/newt_cavalry_sheet.gd`, models in
  `scenes/art_pixel/newt_concepts.gd`): a real mount in the real pipeline (body, head and four legs
  baked apart in eight facings and composed by UnitView like the beetle; the sheet puts the parts in
  the loaded data for the run only). Long and low, sprawling legs, a paddle tail, a broad flat head,
  a team saddle cloth and reed saddle roll; sized so the frog sits on it at about a beetle's saddle
  height. Three colourings: fire (black and yellow), red eft, crested (olive). All eight facings and
  a walk, beside the frog on a beetle and a human on a pony. At 1x it reads as a rider on a beast in
  every facing; the fire colouring reads best (the eft would merge with red frogs, the crested is
  muddy); it is about twice the beetle's length with its tail.
- **Frog catapults** (`tests/siege_concept_sheet_r4.gd`, the round-4 section of
  `scenes/art_pixel/siege_concepts.gd`, which now shares the turtle, the toad, the deck catapult and
  the post bolt thrower as helpers): 1. a giant swamp snail (Dominic's idea) with the catapult on a
  deck over its coiled shell, eye stalks up; 2. the toad carrying the catapult, the turtle taking the
  bolt thrower (a swap); 3. a bigger snapping turtle with the catapult; 4. round 3's reed catapult on
  its sledge hauled by the turtle. A sets sheet shows the whole frog siege per proposal. The snail
  reads as a snail and a catapult in all three facings and is nothing like the turtle ram (tan, wet,
  legless, an amber coil); it is the tallest engine, and edge-on from the front its shell looks more
  like a jar. The toad is still a big frog carrying frogs; two turtles blur ram and catapult; the
  hauled one is a cart and the longest thing on the sheet. A heron wasn't tried (it wouldn't read as
  a load-bearer, and herons eat frogs).
- **Claude's recommendation:** the newt as the swamp family's cavalry mount in the fire colouring
  (the beetle stays the forest's; amphibious movement could give it a reason later), and the snail
  catapult beside the picked turtle ram and toad bolt thrower: three different beasts, the slowest
  throwing the rocks.

**Siege engines built (2026-10-13; steps 2, 3b and 8's siege part).** The Siege Workshop (age 3)
trains a ram, a catapult and a bolt thrower for every race (roster slots live, `own_seed`, each with
`engine`). An engine's body is the engine of the race's **take** (`families.json` `siege`, a
creature's own `siege` first): **timber** for every human culture and the swamp folk who aren't frogs
(the open ram, arm-and-cup catapult and carriage bolt thrower, hemmed in the culture's cloth),
**junk** for the sewer (pipes, chains, a bucket of cheese, leaf springs and a grate), **forest** (the
ridden giant beetle ram; round 1's twig-and-acorn catapult and log-wheeled bolt thrower, crewed),
**spooky** (round 1's dark wood and bone, crewed), and **frog** for frogs whatever their culture
(D-121, D-122: the snapping turtle ram, the snail carrying the reed catapult, the toad-borne bolt
thrower). Every engine is one part (`siege.<engine>.<take>`, slot `engine`) baked in 8 facings from
`scenes/art_pixel/siege_models.gd` (the concept builders moved there; `siege_concepts.gd` keeps the
concept ids); the crew are the race's age-1 workers (the recipe's `crew`), composed by `UnitView` on
the crew sockets, walking while it rolls, heaving with a ram's blow, falling when it breaks.
- **Combat** (rules `splash_*`, weapon stats in the `engine.*` parts): the catapult's stone lands on
  a spot and hurts every unit within 1.1 tiles, `damage x (splash - gap) / splash`; **friends in it
  take half** (`splash_friend_pct` 50: the genre's stone throwers hurt their own side; so they're for
  crowds and towers, not your own melee), enemy buildings by the same falloff. Catapults (3 tiles)
  and bolt throwers (2) have a **minimum range**: they don't pick foes inside it and step back from
  one that comes in. The ram goes for **buildings only** (`targets`), +70 vs the building class
  every 3 s, pierce armour 14 (arrows do 1), melee armour 0. Bolts fly slowly (`shot_speeds`
  bolt_thrower 220, catapult 180) and go **through a line** (every foe on the last 2.5 tiles of the
  flight). Weapons carry their own `reload`. Cavalry (every mount body) +4 vs siege. Machines aren't
  healed (`heal_not`); the beasts are. Stopped melee units hitting a building get the shooters' hold
  slack (a big body at a corner place stood just out of reach).
- **Prices** (points through the cost curve, no special cases): ram 260 (170 wood, 90 gold), catapult
  290, bolt thrower 185; the beasts cost some food (turtle 260, snail 290, toad 185); rats about 70%.
  Engines move at 8 (a worker 10), are large (pop 2) and the size of a horse in the sim (radius 420;
  500 stuck at one-tile gaps).
- **Numbers.** Three rams break a stone gate in 0:30 and a wall in 0:26; the same cost in spears
  takes 2:50 and 3:20, in cavalry 6:06 and 5:06 (`tests/test_ai.gd -- flat_test rams`). Mass battles
  at age 3, 1500 a side (`tests/mass_battle.gd -- 3`, new siege matches): catapult+spear beat massed
  archers 8 of 10 but lose to spear+archer 9 of 10 (their own spears in the splash); bolt+spear beat
  spear+cavalry 8 of 10 and spears 6 of 10; catapults alone lose to cavalry 10 of 10, bolt throwers 8
  of 10. The balance round robin (soldiers only) is unchanged at age 3.
- **AI** (`data/ai.json` military.siege): the workshop goes up at 28 workers in age 3 (before the
  second Town Center); the bot keeps at most 2 rams, 2 catapults and 1 bolt thrower, training the one
  it has fewest of (a ram first); on its regroup beats rams go for the nearest enemy gate, wall or
  tower in sight (else any building, else they march on the army's target), catapults for a tower
  within 14 tiles. A bot in age 3 fields all three by 15:30.
- **Tests:** `tests/test_sim.gd` (splash and falloff, friends at half, minimum range and the step
  back, the ram ignoring soldiers and shrugging off arrows, a bolt through three; engines crossing
  flat, choke and hill maps on their own), `tests/run_tests.gd` (every take builds, crews are the
  workers), `tests/test_ai.gd` (rams vs stone, the siege bot). `tests/siege_lineup.gd` shows every
  take in four facings. Pictures `archive/images/2026-10-13/270-` to `275-`.
- **Cost to draw:** crews are composed, not baked in (each crew member a worker UnitView): 60 crewed
  engines on top of 211 units stay at the frame cap (8.3 ms; `tests/art_bench.gd`, which bakes them
  outside the atlas, so 137 draw calls there; in a match they're in the one atlas). The sim tick with
  siege in the 200-unit script measured 2.75 ms against main's 2.79 the same hour.
- **Open:** Dominic's look in a match; the engines' sounds reuse the stone and bolt shots and the
  blunt hit; workers don't repair engines yet; garrisoning a ram is milestone 16's.

**The swordsman line (2026-10-13).** Dominic: "start the barrack sword line". Why now: the pricing pass
(D-120) found the round robin can't balance with four combat slots (large units counter two, archers
one); a line for archers to beat that beats spears and skirmishers closes the web. The `infantry` slot
in `data/rules/*.json` is live (tier 1, `own_seed`, so every other line's recipes, and the race's name,
are as they were: every other line and the name of 306 races, 34 prompts x 3 rules x 3 rerolls,
checked unchanged, and a run_tests check; the race keys change, as the new line is in them). The Barracks trains it beside the spear; its line upgrades (ages 2 and 3) come from the
Barracks' `trains` like every line's, and the tech tree page draws it with no new code.
- Generator: the role needs a `melee` weapon that's no `spear` or `lance` (ROLE_NEEDS / ROLE_EXCLUDES),
  leaning to blades. Age 1 has only the bone club (and the rats' cheese hammer, their signature, kept
  through the ages); on the age 2 upgrade a primitive weapon may become a blade (ROLE_KINDS: the club
  becomes the culture's sword). The khopesh and macuahuitl now take `requires_role: ["large",
  "infantry"]` (a list, from a single role). Lines by culture (default rules): Clubber, then Swordsman
  (bronze sword: swamp, forest, hellenic, steppe, spooky, han), Legionary (gladius, when "roman" is
  asked), Khopesh Warrior (nile), Club Warrior (aztec), Iron Swordsman in age 3 (royal, or anyone
  asking for knights), Cheesehammer Rat throughout. Names are the weapons' nouns (data).
- Counters: the slot carries its own `bonus` (rules roster: +3 against `spear`, `skirmish` and
  `building`, whatever weapon the line holds, so large units with the same swords don't get it) and
  its `price_points` (3: what the bonus adds to the price, pricing.gd). Archers' bonus against
  infantry does the rest. The cheese hammer's `price_points` went 8 -> 10 and the iron sword got 8
  (budget points unchanged, so no race changed): both were the round robin's top outliers.
- Round robin (`tests/balance.gd`, units more than 20% off the mean): age 2 was 8 of 20 before, 8 of
  25 now (the swordsmen within 20%: human +18%, beetle +10%, cheese rat +10%, frog +2%); age 3 was 10
  of 20, 12 of 25 now (cheese rat +34%, human +26% out; iron beetle -8%, frog -8%). Counters won 90%
  of same-race counter fights before, 80-82% now with three more pairs counted. The rest of the
  outliers are as before (weak archers, the hoplite and pike cavalry, the giant cheese rat).
- Mass battles (`tests/mass_battle.gd`, age 2, new match-ups): swords beat spears 8 of 10, skirmishers
  6 of 10, lose to archers 2 of 10, cavalry 4 of 10; sword+archer v spear+cavalry 6 of 10.
  `test_sim.gd`'s counter fights add swords v spears and archers v swords (each line's first step):
  60 of 68 won by the counter; the age 1 club loses to spears for centaur romans and royal knights,
  and the frogs' clubs beat their archers.
- AI: the counter-pick (bot.gd `_score`, now in its own `pick`) already weighs a unit's bonuses by
  the foes it has seen, so seen spears and skirmishers bring swords. Two data knobs in
  `data/ai.json` military: `pick_bias` (infantry -7), so with nothing seen the Barracks still
  trains spears as before (the first try, without it, had every bot on swords and broke a bot-vs-bot
  game and two walled-base checks); and `building_foes`: while the army goes for an enemy
  building (`_aim`, a wall shutting the way) that many foes of class building count, so the
  wall-breakers are trained. It's **off (0)**: at 2 a stone ring fell sooner (18:40 against 20:25)
  but a palisade ring much later (18:10 against 12:00) with its blows spread over many pieces (a
  new test_ai failure: seven swordsmen by 7:00, then none trained until 13:00, as they're dearer
  than spears and come out of what it saves for the age); left for the big-map AI work.
  `tests/test_ai.gd -- flat_test pick` checks the pick in seconds. test_ai fails only main's three
  known checks (easy strikes early, two shelter checks); before rebasing on the siege work, one
  bot-vs-bot game (Maximian Cohort v Bog Frogs) ran to the 30-minute cap with no winner, and it
  ends again now. test_sim: determinism and the counter fights pass; one new failure: on
  hill_test's crossing, with a seventh group (the swordsmen) the groups' targets shift and one
  unit gives up stuck 3 tiles short (#44, group 5); it passed before the rebase (newt mounts came
  in with it), so it's a pathing edge the new layout finds, left for a look.
- Art: no new parts; `tests/line_lineup.gd` (any line, any age, every culture in 8 facings) shows the
  swordsmen at 3x: `archive/images/2026-10-13/310-` (age 1), `311-` (age 2), `312-` (age 3). The club,
  gladius, khopesh, macuahuitl, iron sword and cheese hammer read; the bronze sword is small and dark
  against bronze armour, and the frog's sword hides behind its body in the front facings (a concept
  question, not a fix). **Gap:** the iron sword is the only tier-3 blade and it's royal (knight) kit,
  so swamp, forest, hellenic, steppe and spooky swordsmen get nothing new in age 3 (the upgrade
  shows "nothing to upgrade"); a generic age-3 blade (or a culture blade each) needs a concept round.

## Changes from the original plan

- 2026-10-13: siege first (Dominic: "why we not done siege yet?"), ahead of step 1. Step 2 shrinks
  to splash, minimum range and the bonus vs buildings: projectiles that can miss are built
  separately as flying arrows for every ranged unit.

## Links
- `m12-tech-tree.md` (the tree), `m14-race-identity.md` (what each race does with these lines)
- `../roster-template.md` (the role plan and per-family variants)
