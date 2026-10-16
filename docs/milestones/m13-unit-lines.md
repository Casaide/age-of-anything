# Milestone 13: Unit lines

**Status:** in progress (2026-10-13): siege engines built (step 3b), steps 2 and 8 (siege part) done; trade carts in play; war beasts and the GS2 great sling in play (D-129), siege shots baked; the frogs' great sling is FS1 A, the bullfrog leaper, in play with a throw (D-131); war beasts break cavalry (D-131)
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
| Barracks | Swordsman (1-3) | none: parts exist (swords, clubs) |
| Archery Range | Mounted Archer (2-3) | none: the race's mount and a bow |
| Stable | Scout (2-3), War Beast (3) | sight per unit (scouts); big beasts (bodies) |
| Siege Workshop | Ram, Catapult, Bolt Thrower (3) | siege bodies; splash, minimum range, attack vs buildings (the siege tower moved to milestone 16) |
| Castle | Unique, Sapper, Great Sling (3) | unique themes in data (raiders are one kind, D-123); self-destruct; pack/unpack |
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

1. **Lines from parts we have.** Swordsman, Scout, Mounted Archer (the Raider line is cut, D-123:
   raiders are unique-unit themes, step 4): roster slots go live,
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
   (three ages). Fast light raiders are one kind of theme (steppe, gutter rats, vikings, gloom;
   Dominic, D-123: "Raider isn't really a thing, sounds race specific like a castle unit"). The sapper (walks up and blows up a building or wall tile: a plain kill here; the rubble and breach are milestone 16's). The great sling (long-range anti-building,
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
- [x] 1. Swordsman, scout, mounted archer (2026-10-13)
  - [x] Swordsman line at the Barracks, ages 1-3 (2026-10-13)
  - [x] Scout line at the Stable and mounted archer line at the Archery Range, ages 2-3 (2026-10-13)
  - [x] ~~Raider~~: cut as a line (Dominic, D-123); raiders are unique themes (step 4)
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
- [x] Swordsman age-3 kit for every culture (Dominic, 2026-10-13: "need age 3")
  - [x] Concept round S3: two options each for hellenic, steppe, han, swamp, forest, spooky (2026-10-13)
  - [x] Dominic's pick (D-125), built into play with a plain iron sword as the fallback (2026-10-13)
  - [ ] Dominic's look in a match
- [ ] Rat mount: the long-head capybara (in play) or the alley cat (iterating: a real cat body, sits when idle); the tiger for another culture?
- [x] Siege engine sounds (2026-10-13: ram, catapult release and impact, bolt thrower, great sling, sapper blast, coins)
- [x] The swordsmen's raid mode for the bot (`building_foes` 2, switched on 2026-10-13; see Results)
- [ ] Check bugs (swamp beetles, spiders) riding newts; "frogs riding beetles" now gives newts
- [ ] 4. Unique unit, sapper, great sling
  - [x] The unique unit: themes in `data/uniques.json` (17, raiders among them), from existing parts (2026-10-13)
  - [ ] Dominic's look at the themes; concept round for the new parts each wants (list in Results)
  - [x] Sapper, great sling: built and in play (2026-10-13), placeholder looks
  - [x] Concept rounds SP1 (the sapper's charge) and GS1 (the great sling) (2026-10-13)
  - [x] Dominic's picks: GS2's siege-weight traction sling (D-129); the sapper parked (D-128)
  - [x] The great sling's look in play for timber, junk, forest and spooky, packed on its wagon while it moves (2026-10-13)
  - [x] Concept round FS1: the frogs' great sling (bullfrog leaper, stilt sling, crayfish winder) (2026-10-13)
  - [x] Dominic's pick from FS1: A, the bullfrog leaper (D-131); built and in play, packed on a sledge the bullfrog hauls, a throw shown after each shot (2026-10-14)
- [x] 5. Healers (built 2026-10-12; the look is a pick pending: HL1 concept sheet, look A in game)
- [ ] 6. Trade carts
  - [x] Mechanics, data, AI, Pack Animals, a placeholder look (2026-10-13)
  - [x] Concept round TC1 (2026-10-13)
  - [ ] Dominic's pick, then build the look
- [ ] 7. War beasts
  - [x] Concept round WB1 (2026-10-13)
  - [x] Concept round WB2 (2026-10-13); Dominic's picks (D-129)
  - [x] Built: the `war_beast` line in play (Stable, age 3), elephant, war boar, tarantula, heron, mantis, riders the race's spearmen; priced, balanced (2026-10-13)
  - [x] A bonus against mounted units (D-131), priced (2026-10-14)
  - [x] Real motion (2026-10-16, D-134; Dominic: the elephant has no walk, some views look wrong): every facing was
    there (no blank or magenta one, `archive/images/2026-10-16/01-`); the beasts slid as one rigid sprite (`02-`).
    Now legs bake per hip and the head at its neck (siege_models.gd: the body alone in play, `leg.beast_<kind>`,
    `head.beast_<kind>`); they walk on their planted foot (the elephant and boar on four legs, the tarantula in a
    wave down each flank, the heron striding, the mantis on its four thin legs), strike their own way (tusks, gore,
    bite, stab, strike) and fall like creatures, throwing their riders clear. Sheet:
    `tests/sheets/war_beasts_anim.json` (facings, walk, cycle, strike, fall; the sheet tool's new `strike:<k>` and
    `fall:<k>` columns). Placement passes, with each beast also walked on its own.
  - [x] Bent knees (Dominic: "bent knees are required for sure"; D-135): every beast's leg jointed and baked in 8
    walk steps (`legs.poses`), the knee by two-bone IK as the foot steps back along the ground and swings forward
    lifted (`12-`, `13-`).
  - [ ] Dominic's look in a match
- [ ] 8. AI (siege part done 2026-10-13: a few engines, rams at gates, walls and towers, catapults at towers; trade carts, the sapper and the great sling 2026-10-13; war beasts by the counter-pick, at most 4, 2026-10-13)
- [x] Siege shots drawn as baked art (Dominic: "the rocks they throw look really bad"; 2026-10-13)
- [ ] 9. Balance and exit check
  - [x] Round robin and mass battles at ages 2 and 3 with every line (2026-10-13; see Results)
  - [ ] A design change for the structural outliers (proposal for Dominic in Results)
  - [ ] Dominic's match
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

**Swordsman age 3, concept round S3 (2026-10-13).** Dominic: "Swords looking great, need age 3." The
swamp, forest, hellenic, steppe and spooky swordsmen are the same unit in ages 2 and 3, and han's only
gets a helmet (imperial, nile, aztec and sewer step up through armour or helmets). Two options each,
modelled in `scenes/art_pixel/sword3_concepts.gd` and baked through the real part pipeline in the
swordsman's hold, on the culture's swordsman beside its age-2 self in 8 facings plus a wind-up and a
blow (`tests/sword3_concept_sheet.gd`; nothing in play, no race changed): hellenic A iron kopis, B long
xiphos + Attic helmet with a high crest; steppe A long sabre, B flared heavy sabre + spiked helmet with
mail; han A jian, B dao; swamp A reed saw with obsidian teeth, B river-stone mace; forest A
chitin-edged blade, B thorn sword; spooky A bone scythe-sword, B hooked sickle blade. Polished steel
needed a pale tint to outshine bronze at game scale. Claude recommends hellenic B, steppe B, han B,
swamp B, forest A, spooky B (the helmets change the silhouette from every side; slim blades and the
bone curve vanish at 1x), plus a generic age-3 blade for cultures without one. Pictures
`archive/images/2026-10-13/330-` (all, game scale) and `331-` to `336-` (3x per culture); notes in
`docs/concepts/sword3/README.md`.

**Swordsman age 3, built (2026-10-13).** Dominic picked (D-125) hellenic B, steppe B, han B, swamp B,
forest A, spooky B, plus a plain iron sword as the fallback. In play:
- Data (`data/parts.json`, tier 3, `requires_role: ["infantry"]`, `only_if` + `favour` the culture's
  tag like the healer staffs, attack 8 against the bronze sword's 7, points 6, `price_points` 8 like the
  iron sword): `weapon.sword.xiphos` + `helm.attic` (hellenic, "Xiphos Swordsman"),
  `weapon.sword.flared_sabre` + `helm.steppe_spike` ("Sabreman"), `weapon.sword.dao` ("Dao Swordsman"),
  `weapon.mace.river_stone` ("Maceman Frog", +2 vs buildings), `weapon.sword.chitin` ("Chitin
  Swordsman"), `weapon.sword.hook` ("Hookblade"), `weapon.sword.iron_plain` (the fallback, "Iron
  Swordsman"). The helmets are tier 3 and share the `helmet` kind, so the upgrade swaps the age-2
  helmet for them (armour 2/1, points 3).
- **The mace and the kind rule:** the mace stays `blunt` (it sounds and counts as a club) and carries
  a new field, `"replaces": ["blade"]`: on an upgrade a part may take the place of the kinds it lists,
  besides its own. Tagging it `blade` would have lied to everything else that reads tags; widening the
  swordsman's upgrade to every blunt weapon would have let any club in.
- **The fallback:** a new field `"fallback": true`. Such a weapon is only the upgrade's choice when
  there is no other, and never over the race's own weapon (favoured and of its creature or culture) or
  one the prompt asked for, so the khopesh, macuahuitl and gladius stay. It shows up under the bronze
  rules for royal humans and royal frogs (the royal iron sword is medieval) and for tiny vikings.
- Other lines unchanged: every other line's recipes and the race name of 396 races (44 prompts x 3
  rules x 3 rerolls) are as before; 269 swordsman lines changed. The only age-3 steps left the same as
  age 2 are rats keeping their cheese hammer with a full budget (as before).
- Models: the picks and the helpers (`curved`, `grip`, `tassel`, `_bright_iron`) moved from
  `scenes/art_pixel/sword3_concepts.gd` into `unit_models.gd`, with the brightened steel; the options
  not picked stay in the concept file. Placement (tests/placement/cases.gd now has the greek, steppe and
  han swordsmen in ages 2-3 and royal humans under the bronze rules) found four helmets low on a human's
  brows: the Attic and spiked helmets (as modelled for the concept) and two already in play, `helm.bronze`
  (the steppe and royal age-2 swordsmen) and the han lamellar. All lifted (`_lift`); the spiked helmet's
  all-round mail curtain became a guard at the sides and back quarters, its tuft streams back from the
  spike's foot (upright, it ran into a banner's flag).
- Round robin age 3 (`tests/balance.gd -- 3`): 12 of 25 units more than 20% off the mean (main: 14);
  the new swordsmen all +18% (Xiphos Swordsman, Hookblade Beetle, Maceman Frog), the Iron Swordsman
  Beetle's +26% gone; counters won 80% of same-race counter fights (main 82%). `price_points` 9 moved no
  win rate, so it stays 8. Mass battles age 3 (`tests/mass_battle.gd -- 3`): swords beat spears 8 of 10
  (as main), skirmishers 7 of 10 (main 9), lose to archers 2 of 10 (as main), to cavalry 6 of 10 (as
  main); every other match-up the same as main.
- Pictures: `archive/images/2026-10-13/359-` (every culture's age-3 swordsman, 8 facings, 3x), `360-`
  (hellenic, steppe, han at 5x), `361-` (swamp, forest, spooky at 5x). Every blade is the brightest thing
  on its unit; the Attic crest is team blue against a team banner, so it reads best on units without
  one; the steppe tuft is small; the chitin shards show teal in the side facings.
**Scouts, mounted archers and the unique unit (2026-10-13).** Dominic: "We're also missing the rest of
the units. Horse archers (archery range), scout (stable), castle special units." Three roster slots go
live in `data/rules/*.json`, each with its own random stream (`own_seed`). The other lines' recipes
and the race's name stay as they were (run_tests checks this over 20 prompts x 3 rules x 2 rerolls).
The race keys change, because the new lines are part of them. The Stable trains the scout beside the
cavalry, the Archery Range the mounted archer, the Castle the unique unit (`data/buildings.json`).
- **Scout** (Stable, ages 2-3). It rides the race's mount (rules `mount: "prefer"`). Where nothing
  carries the race it goes on foot: Aztec folk, spooky spiders, winged races (who keep their wings).
  - Kit: a light weapon (melee, no spear, lance or heavy kit: ROLE_EXCLUDES), plus a cap and a jerkin
    at most (`SCOUT_SLOTS`, `_light`: nothing heavy, nothing over 2 points).
  - The slot carries its numbers (rules `stats`): speed +3, attack -2, **sight +4 tiles**, +2 more
    speed on foot (`stats_on_foot`), and a bonus against skirmishers, workers and healers. The mount
    already gives +4 against siege.
  - Sight is data now: pricing outputs `sight` and the fog adds it (`fog.gd`). Its name is the
    slot's noun ("Scout on a Pony", "Scout Frog on a Newt").
- **Mounted archer** (Archery Range, ages 2-3; it opens in age 2, not 3, so the line has an upgrade).
  A bow on the race's mount, +2 against infantry (rules `bonus`). Mounts drop the rider's infantry tag
  (D-120), so archers' bonus doesn't touch it, while skirmishers (+6 against archers) and spears
  (against large) do. A race **lacks** the line in three cases:
  - its archers already ride (`unless_mounted: "archer"`): centaurs, whose archer is their mounted
    archer (so no duplicate), and horse peoples whose prompt mounts the archers (mongols);
  - nothing carries it (`mount: "always"`);
  - it has no hands (`needs_hands`; creatures.json `harness`: beetles and spiders cling to a mount
    and can't draw a bow there, which the placement check caught as a bow through the pony's neck).

  A lacked line is listed in `race.lacks` with a note ("No Mounted Archer line: the centaurs ride
  already as archers."). The tech tree page draws it crossed out and lists it under Lacks.
- **The unique unit** (Castle, age 3, one step), with 10 points over the age's budget
  (`budget_add`). Its **theme** comes from `data/uniques.json`. Choice order, all data: the theme the
  prompt asked for most by its `asked` tags (romans -> testudo, "cheese" -> Big Cheese, "viking" ->
  horned raider, even on frogs: "roman frogs" give a Frog Testudo Guard), else the creature's
  `unique` (creatures.json: rats, frogs, spiders, beetles), else the culture's (families.json).
  - A theme sets: a `role` (which weapon it needs), signature `parts` (taken first where the age and
    era allow), `wants` (what its other gear leans to), `mount: "ride"`, `giant` (where giant_ok),
    `light`, `stats` and `bonus`, and `price_points` (what they add to its price; the cost curve does
    the rest), a `noun` and a one-line `desc` (the tech tree page's card).
  - No new parts: existing ones in a signature combination.
  - **Raiders are themes, not a line** (D-123): the Steppe Raider (a fast light rider with a bonus
    against workers, healers, engines and buildings), the Gutter Raider (the rats' own), the Horned
    Raider (asked "viking") and the Gloom Stalker. The planned Barracks slot is kept in
    `data/later/raider_line.json`.

| Theme | Whose | Role | Kit and numbers |
|---|---|---|---|
| Testudo Guard | imperial, asked "roman" | infantry | gladius, scutum, lorica, galea; +3 pierce armour |
| Phalanx Guard | hellenic, asked "greek" | spear | dory, hoplon, Corinthian, bronze; +2 melee armour |
| Sworn Knight | royal, asked "knight" | infantry | iron sword, kite, mail, iron helm, cape; +20 HP |
| Steppe Raider | steppe | infantry, rides, light | round shield, cap; speed +3; bonus vs workers, healers, siege, buildings |
| Bowguard | nile, asked "egyptian" | archer | bow, headcloth, leather; +1 range, +1 pierce armour |
| Repeater Guard | han, asked "chinese" | archer | crossbow, lamellar helm; attack -2, reload 12 ticks (2.5x) |
| Obsidian Champion | aztec | infantry | macuahuitl, chimalli, eagle helm, banner; speed +2, bonus vs infantry |
| Bog Lurker | swamp | skirmisher, light | blowgun, leaf cape and hat; speed +2, sight +2, bonus vs infantry |
| Moss Warden | forest | archer | bow, leaf cape, bark, acorn; +1 range, +3 sight |
| Scrap Brute | sewer | infantry | club, bottle-cap shield and armour, tin cap; +15 HP, bonus vs buildings |
| Gloom Stalker | spooky | infantry, light | speed +3, attack +2, sight +2; bonus vs healers, archers, workers |
| Gutter Raider | rats | infantry, light | thimble; speed +3, attack +1; bonus vs workers, healers, siege, buildings |
| Big Cheese | asked "cheese" | infantry | cheese hammer, sardine armour, spoon helm, banner; +20 HP, +2 attack |
| Great Bullfrog | frogs | infantry, giant | a giant frog; bonus vs infantry |
| Web Lurker | spiders | skirmisher, light | speed +2, sight +3; bonus vs large (riders and beasts) |
| Stag Colossus | beetles | infantry, giant | a giant beetle in bark; +2 melee armour |
| Horned Raider | asked "viking" | infantry, light | round shield, horned helm; speed +2, attack +2; bonus vs buildings, workers |

- **AI.** Main's bots now scout (`src/ai/scout.gd`: a worker early, then the fastest idle soldier).
  - `_train_scout` keeps one scout-line unit (`military.scouts.keep`), trained before the
    counter-pick, and Scout's soldier tours take a scout-line unit first, without waiting for an army.
  - `pick_bias` keeps the old defaults: the Stable's cavalry, the Range's archers (scout -5, mounted
    archer -6). Seen swordsmen bring mounted archers; seen spears don't (`tests/test_ai.gd pick`).
  - The Castle trains unique units through the same pick.
- **Placement** (`tests/placement_check.gd`, both halves). The cases cover the new lines of 12 more
  races (`tests/placement/cases.gd` LINE_PROMPTS: every unique theme, a foot scout, the steppe raider
  on its pony), plus their cavalry. The wider cover found old placement faults in parts already in
  play, now fixed:
  - helmets low on the brow: bronze and horned helms, khat, Nile bronze, Han lamellar and Aztec
    quilted cap, each raised (`_lift`);
  - the iron helm's nasal and the eagle helm's beak are face guards (`"face": "covered"`);
  - a cloth cape hung through a pony's and a beetle's back: `cape.cloth` gets
    `not_ridden_on: ["pony", "beetle"]`, read by the generator, so such riders now pick other gear;
  - a banner's pole cut through the Han lamellar neck guard and the Nile headcloth: both drawn closer
    in;
  - a hummingbird's own wing blur was held to the withers-wings rule. Dominic had it drawn like any
    back part ("a flat grey plate" from behind), so the 2D rule now skips wing blurs.

  9,320 checks, 0 failed, fixtures all caught.
- **Balance** (`tests/balance.gd`, equal cost, after main's 1.7x soldier prices; units more than 20%
  off the mean). The old lines alone (the round robin with the new lines left out)
  are out 11 of 25 at age 2 and 14 of 25 at age 3. With the new lines: 18 of 33 at age 2 and
  21 of 38 at age 3. Counters won 83% and 85% of same-race counter fights (80% and 82% before).
  - Prices tuned: mounted archer `price_points` -3, scout -2; Big Cheese 20 (from +42% to -2%), Great Bullfrog 5,
    Sworn Knight 7.
  - **Re-run after the movement fix and the rats riding cats** (both change fights): 20 of 33 out at
    age 2, 18 of 38 at age 3; counters 83% and 81%. The rats on cats: scout +8% (age 2) and +4%
    (age 3), mounted archer +14% and +30% (the one new-line rat outlier; the cat's price is the
    cat branch's). Great Bullfrog +14%, Big Cheese +4%, Beetle Sworn Knight -8%.
  - **The newt is not the cause** of the frogs' spread: frog archers are weak on foot too (-48% at
    age 2, like the beetles' -48%), and frog spear cavalry is strong the way every spear-armed rider
    is (pony hoplites +38%, centaur spears +38%). Pricing the newt like the pony (`price_points` 15 to 12)
    lifted the newt archer from -57% to -36% but the spear cavalry from +26% to +44%, so the newt
    stays as it is. The weak archers and the strong spear riders are the old outliers, not a mount's.
  - The rest out are as before: weak archers and slingers, pike and lance riders, the cheese rats'
    swordsman and giant.
- **Mass battles** (`tests/mass_battle.gd`, 1500 a side, ages 2 and 3, new matches; at age 3 after the
  movement fix mounted archers beat spears 4 of 6 and skirmishers beat them only 2 of 6, so they are
  on the strong side there; scouts and unique units as below, unique units a little weaker, 2 of 10
  against cavalry):
  - mounted archers beat swords 6 of 6 and archers 6 of 6, split with spears (3 of 6 at age 2, lose
    4 of 6 at age 3), lose to cavalry 4 of 6 and to skirmishers at age 2 (4 of 6; even at age 3);
  - scouts beat skirmishers and archers 10 of 10 and lose to spears and cavalry 10 of 10;
  - unique units against their own race's lines: beat swords 6 of 10 and archers 6 of 10, lose to
    spears 6 of 10, cavalry 7 of 10 and spear+archer 7 of 10. Strong in the right fights, not a
    must-build.
- Pictures: `archive/images/2026-10-13/383-` (scouts, age 2, rats on cats), `384-` (mounted archers, age 2),
  `385-` (unique units), every culture in 8 facings at 3x (`tests/line_lineup.gd`, which now skips a
  race that lacks the line).
- **New parts each unique unit would want** (concept-first, D-080; nothing built, all of these use
  existing parts today):
  - Testudo Guard: a tall curved tower shield that locks with its neighbours, a crested centurion
    helm; a formation pose (shields raised) would sell the testudo.
  - Phalanx Guard: a long sarissa-length spear, a crested Attic helm with cheek guards, greaves.
  - Sworn Knight: a great helm (flat-topped, closed), a surcoat in the team colour over the mail, a
    long sword.
  - Steppe Raider: a curved sabre, a fur-trimmed cap, a lasso or saddle bags; a smaller, shaggier
    steppe pony.
  - Bowguard: a long self bow taller than the archer, a quiver on the hip, a linen kilt with a team
    sash.
  - Repeater Guard: a magazine crossbow (a box on top, a lever), a lacquered cuirass.
  - Obsidian Champion: an animal-skin war suit (a feathered or spotted body suit with the head as a
    hood), a feathered back-banner.
  - Bog Lurker: a reed-mat ghillie cloak, a long reed blowgun, a dart pouch.
  - Moss Warden: a mossy hood and cloak, a longbow of bent branch, antler or twig trims.
  - Scrap Brute: a riveted scrap-iron cuirass from the sewer's junk at human scale (D-116), a pipe or
    chain flail, a grate shield.
  - Gloom Stalker: a hooded tattered cloak, a hooked blade or a sickle, pale face paint.
  - Gutter Raider: a short cleaver or a hook, a patched leather hood, a sack of loot on the back.
  - Big Cheese: a giant wheel-of-cheese hammer (bigger than the line's), a cheese-rind crown, a cape
    of cloth like a cheese wrap.
  - Great Bullfrog: no gear needed beyond scale; perhaps a lily-crown or warpaint stripes (avoiding
    more lily pads, D-119).
  - Web Lurker: a web-sling (a silk bag of stones), a silk shroud; a spitting pose.
  - Stag Colossus: oversized stag mandibles as its weapon (no held sword), a bark-and-iron carapace
    cap like the forest ram's.
  - Horned Raider: a bearded axe, a round shield with a boss and a painted rim, a fur cloak.
- **Tests.** `tests/batch.sh --quick`: run_tests 36,079 checks, 0 failed (the new lines' rules, the
  theme picks, and that the other lines and names are unchanged); placement 0 failed (and
  `tests/placement_check.gd` in full: 9,724 checks, 0 failed, fixtures all caught); test_ai quick fails only main's known
  "easy strikes before 8 minutes".
  - test_sim's scripted match shares about 200 units over the race's lines (`PER_PLAYER` 99), since
    its tick budget is for a match that size. The tick, part:match on its own, back to back: 2.04 ms
    (158 units at the end) against main's 2.96 ms (194).
  - **The crossings, fixed in the movement code** (the new lines, three mounted and a giant, made the
    fault show: 100 units in ten groups, as main's test spawns them):
    - a unit walking back into its slot now gives way to its side's other groups, as one standing in
      it does (`_separate` yields). It had walked straight back into the passer: a returning
      cavalryman and a passing mounted archer shoved nose to nose until the passer gave up;
    - no ground gained in a moving queue, or while giving way near its slot, isn't stuck (`_queued`,
      `_passed`). The tenth group through choke_test's gap waited longer than the patience, and a
      spearman shoved off his slot by eight groups gave up two tiles from home;
    - one that gave up walking back and stands by its slot again isn't counted stuck.

    All three crossings pass with main's test unchanged (ten of each line). test_sim: 656 checks, 0 failed.
- **Open:** Dominic's look at the themes and the concept round for their parts. The rats' mounted
  archer on a cat at age 3 (+30%), and mounted archers against skirmishers at age 3. The scout and
  mounted archer sounds reuse the cavalry's.

**Trade carts, the sapper and the great sling (2026-10-13; steps 4 and 6, step 8's part).** Three
roster slots go live in `data/rules/*.json` (`own_seed`, so every other line and the race's name stay as
they were; run_tests checks that). Their looks are placeholders until Dominic picks from the concept
rounds below; the mechanics are done.
- **Trade cart** (Market, age 2; `trader`, an engine line with `armed: false`: no weapon, its crew the
  race's worker). `siege.cart.<take>` parts (tags `trade`, `cart`, `machine`; 95 wood, 55 gold, 1 pop,
  speed 10, 70 hp). `src/sim/trade.gd`: command ROUTE (right-click a finished market of yours or an
  ally's): the cart takes its route from its nearest own market there and back for good (units.task
  TRADE, target the far market, units.route the home one, work out or home); it loads `d*d/50 + d/2`
  gold at the far end (rules economy.trade: min_tiles 20, sq_div 50, lin_pct 50; d tiles between the
  markets' middles: 30 tiles 33 gold in about 55 s, 50 tiles 75) and is paid on reaching home; killed
  on the way it loses the load; the far market gone, it goes home and stops. Carts are harmless and
  passive (never fight, never picked as soldiers), stay out of towers (garrison.not), and Pack Animals
  (Market, age 3, +25% speed on `trade`) is live. Unit card: "Trades: right-click a far market".
- **Sapper** (Castle, age 3; role `sapper`): the race's light kit (SAPPER_SLOTS: a cap at most) and
  `tool.charge` (attack 20, +600 vs buildings, `targets: buildings`, `blast` 1500, `blast_line_pct` 100).
  Its first blow is a blast (combat.gd `_blast`): the building takes the blow, a wall, palisade or gate
  tile its whole hp, every other building and unit within 1.5 tiles the charge's damage less further
  out (friends at splash_friend_pct), and the sapper dies. A stone wall tile goes in one, a house in one,
  a Town Center loses 39% (three sappers), a castle about an eighth. 125-135 resources (price_points 10).
  The breach (rubble you can walk) is milestone 16's.
- **Great sling** (Castle, age 3; `engine: "sling"`, its take's catapult as a stand-in look,
  siege_models.gd ENGINE_STAND_IN): `engine.sling` throws at buildings only from 12 tiles (none inside 4),
  a small splash, every 8 s; `unpack` 60 ticks (3 s) standing before its first throw, `pack` 40 (2 s)
  before it can roll (units.ready, World._pack: its speed held at 0 and its stuck count kept at 0 while
  it packs). 325 resources (roles pct 60, like the other engines).
- **Numbers** (`tests/test_ai.gd -- piece:rams`, the same cost as three rams): six frog sappers break a
  stone gate in 0:04 and a wall in 0:03 (rams 0:30 and 0:26, spears 3:51 and 6:19); two great slings
  break them in 2:04 and 1:48 from out of reach.
- **AI:** `_trade_carts` (data economy.carts: from age 2, every 10 s, up to 6): the farthest market pair
  it may trade on (ours, or ours and an ally's), idle carts sent on it, one trained at a time from what's
  over; with no pair, a second market by a far second Town Center. A bot with two markets 28 tiles apart
  ran six carts and brought home 464 gold in its first five minutes (`test_ai -- piece:trade_bot`).
  The Castle trains a sapper and a great sling before more unique units (military.siege.max sapper 1,
  great_sling 1; an engine under its max now scores 1000 up, so it comes before a soldier from the same
  building); on regroup beats sappers go for gates, walls and towers like rams, the sling for towers.
  Carts are kept out of every soldier count (army, guard, scouting memory, allied strength, threats).
- **Movement fix the new line found:** with an eleventh foot line (the sapper) test_sim's choke crossing
  never settled: a unit of one group standing in its slot and one of the next walking back into its own
  overlapping slot knocked each other off by turns. They no longer shove each other (`_separate`, like
  two standing in overlapping slots); all crossings pass.
- **Tests:** test_sim `trade` (12 checks: the formula, too close, enemy and allied markets, the round
  trip, the load lost, the price) and `sapper_sling` (8: unpacks then throws, never at soldiers, packs
  before rolling; a wall tile out, the one beside hurt, the sapper gone; a house in one; a Town Center
  stands); test_ai `trade_bot`, the Castle's pick, the sapper and great sling in `rams`; placement cases
  add the three lines in every LINE_PROMPTS culture (11,202 checks, 0 failed).

**Concept rounds (2026-10-13), waiting on Dominic.** All drawn with the sheet tool, every row passing the
placement check; notes, recommendations and questions in each README.
- **TC1 trade carts** (`docs/concepts/trade_carts/`, `archive/images/2026-10-13/420-`, `421-`): A the
  race's own mount pulls a two-wheeled cart (a new composing feature: the recipe's `haul`, the real mount
  walking on the cart's `haul0` socket, placement-checked), B the handcart in play, C each family's own
  (covered wagon behind two ponies, a giant snail with panniers, a scrap barrow, a ball of goods rolled
  dung-beetle style, a silk bundle on a bone sledge). Claude: A, the snail for frogs.
- **WB1 war beasts** (`docs/concepts/war_beasts/`, `422-`, `423-`): an elephant (howdah, or armoured),
  the giant toad (howdah, or thorned bark), a giant capybara or a war boar, a giant stag beetle (or the
  ram's rhino beetle), a tarantula or a black widow. Claude: elephant with howdah, capybara, black widow;
  frogs and beetles need a beast unlike their siege beasts. The slot stays planned.
- **SP1 the sapper's charge** (`docs/concepts/sapper/`, `424-`, `425-`): a fire pot, a satchel charge, and
  per family reed rockets, a lamp-oil can, a bombardier's gland, an egg-sac bomb. None reads in the hand
  at game scale; Claude suggests a round 2 with the charge on the back.
- **GS1 the great sling** (`docs/concepts/great_sling/`, `426-`, `427-`): a traction sling (tall A-frame,
  crew hauling ropes) or a counterweight sling, each packed on a wagon. Claude: the traction sling, with
  the packed look while it moves.

**Siege engine sounds (2026-10-13).** Their own recipes in `tools/audio/sfx.py`, rendered into
`assets/audio/sfx/` and listed in `data/audio.json`: `ram_hit` (creak, thud, crack, grit, settle),
`catapult_release` and `catapult_impact`, `bolt_release` (double snap, cord twang, heavy whoosh),
`sling_release`, the sapper's `blast`, and `trade_paid` (coins, your carts only). Engines' shot kinds
use them (combat_fx), the ram's blow is `ram_hit`, a stone's splash `catapult_impact`; a stone's or a
blast's victims no longer each play an arrow landing. See `docs/audio.md`. Nobody has listened yet.

**The swordsman raid mode, on (2026-10-13).** `data/ai.json` military.building_foes 0 -> 2. With the bots
saving better since D-120 and the stone and market fix, every test_ai piece passes with it on, and the
walled bases fall sooner or about the same: palisade ring 17:44 (off: 18:20; the Town Center in reach
13:30 against 15:55), stone ring 19:23 (19:46), a ring with a gap 11:52 (10:47), bot against bot 19:41
(20:13). The stall that kept it off (seven swordsmen by 7:00, then none until 13:00) didn't come back.

**Balance, step 9 (2026-10-13).** `tests/balance.gd` at ages 2 and 3 with every line that fights units
(the round robin's: spear, swordsman, skirmisher, archer, cavalry, scout, mounted archer, and the unique
unit at age 3; rams, sappers and great slings hit only buildings, carts and healers don't fight, the
catapult and bolt thrower are in the mass battles): **age 2: 20 of 33 units more than 20% off the mean,
counters won 83%; age 3: 18 of 38, 81%** (the same as before: the new lines don't fight in it).
- Weak everywhere: archers (age 2: centaur archer -57%, newt archer -57%, beetle and frog archers -48%,
  pony archer -24%; age 3: -51% to -28%), slingers (-30%; the beetle's -63% at age 3).
- Strong everywhere: spear-armed riders (age 2: beetle lancer on a spider +65%, spear centaur +38%,
  hoplite on a pony +38%, lance centaur +32%, newt spear +26%; age 3: pike centaur +42%, pike on a pony
  +36%), and the rats' spear and giant (+53%, +46%).
- Mass battles (1500 a side): ages 2 and 3 as before for the soldiers (swords beat spears 8 of 10, lose
  to archers 2 of 10; mounted archers beat swords and archers 6 of 6). Siege at age 3 is now strong at
  equal cost: catapult+spear beat archers 8 of 10 and spear+archer 7 of 10 (was 1 of 10), bolt+spear
  beat spears and spear+cavalry 9 of 10, bolt throwers alone split with cavalry 5 of 10 (was 2 of 10).
  That's D-125 (soldiers 1.7x, engines kept at their price), not this work. Unique units: beat archers
  6 of 10, split with swords, lose to spears 6, cavalry 8 and spear+archer 7 of 10.
- **Why prices can't fix the two structural outliers.** A spear on a mount gets both the mount's hp and
  speed and the spear's bonus against `large`, and half the round robin's lines are now large (cavalry,
  scouts, mounted archers, riders): price it up and it still beats every rider it meets, just fewer of
  them. Archers have the reverse problem: their bonus is against `infantry`, and mounts drop the rider's
  infantry tag (D-120), so of eight lines only the swordsman (and the skirmisher, which beats them)
  is their prey; price them down and they still lose every fight against the five lines that counter
  them. Both moves have been tried (the newt's price, D-120's point prices) and moved the spread around.
- **Proposal for Dominic (not made):** (1) a braced spear counts on foot only: the spear's bonus
  against `large` goes when its holder rides (data: a part field such as `bonus_on_foot`, read by
  pricing like `rider_loses`); a mounted spear is then a plain lancer, and the large slot's lance keeps
  its charge. (2) archers get the genre's prey back: their bonus also against `spear` (foot spears are
  infantry in the genre), or a range step (+1) so they get a second volley in before melee closes. With
  (1) and (2) the round robin should come down to the price-fixable spread; I'd re-run it and re-price
  then. (3) Separately: engines may want their price back up after D-125 (roles pct 60 -> 75?), as
  catapult+spear now beats spear+archer.

**War beasts, the great sling's look, siege shots (2026-10-13; D-129).**
- **War beasts** (step 7): the `war_beast` roster slot is live in `data/rules/*.json` (Stable, age 3, `own_seed`, no
  upgrades), an engine line: `engine: "beast"`, `take: "war_beast"` (the generator reads the creature's, else the
  culture's, `war_beast` field instead of `siege`: creatures.json humans and centaurs the elephant, rats the boar,
  spiders the tarantula, frogs the heron, beetles the mantis; families.json gives every culture one too), `crew:
  "spear"` (its riders are the race's spear line as it is at age 3, drawn as spearmen, not workers) and `crew_drop:
  ["back"]` (wings, capes, banners stowed). Parts `siege.beast.<kind>` (tags war_beast, large, beast; hp 170, speed 9,
  armour 1/5, food and gold) and the blow `engine.beast` (attack 10, melee, +4 vs infantry, +12 vs buildings, every
  1.5 s). The tarantula has nobody on it; a centaur race's riders walk beside the elephant (`_wide` sockets, which
  `UnitView.engine_sockets` now also offers for `_top` ones). The skirmisher line gets `bonus: {war_beast: 8}` (no
  price: only war beasts carry the tag); spears beat it by their bonus against `large`, bolt throwers likewise.
  The Stable trains it (data/buildings.json). Models: `siege_models.gd` BEAST (moved from `m13_concepts.gd`).
- **Price and balance** (`tests/mass_battle.gd -- 3 [budget] beasts`, new BEAST_MATCHES, also in every age-3 run):
  first try (hp 260, attack 12, no price_points, ~360 resources) won everything, spears 0 of 10. Now hp 170, attack 10,
  roster `price_points` 8: a war beast costs 500 (300 food, 200 gold). At 3000 a side: beasts beat swords 7 of 10 and
  archers 8 of 10, lose to spears 0 of 10, skirmishers 2 of 10, bolt+spear 0 of 10, cavalry 2 of 10; beast+archer
  beat spear+archer 6 of 10. At 1500 (three beasts a side, lumpy): swords 9, archers 8, cavalry 4, spears 4 of 10
  for the beasts, skirmishers 6, bolt+spear 2 for the beasts (value left favours the counters each time).
- **AI**: picked by the counter-pick like any soldier (`pick_bias` war_beast -30: only once it has seen a crowd of foot
  soldiers or buildings to break and few spears or skirmishers), at most 4 out and queued (`military.most`, read by
  bot.gd `_enough` with siege.max). test_ai passes but `walled_palisade`'s spread check, which fails the same on main.
- **Great sling** (step 4): GS2 in play for timber, junk, forest and spooky (`siege_models.gd` _great_sling, OWN), the
  frogs' keeps the snail catapult (ENGINE_STAND_IN `sling.frog`). The haulers stand in two files beside two pull ropes
  run to stakes in the ground (in GS2's two ranks they stood in each other, and the ropes ended at a worker's hand
  height, loose for a centaur: placement C1, C3); a centaur crew hauls two abreast further out (`_wide`; the files'
  other places are `_narrow`, left out for such a crew). Packed: the body part's `packed` ("siege.sling_packed.<take>",
  GS2's wagon) is shown while the sling isn't set up (`UnitView.set_packed` from `units.ready`; baked with it in
  art_kit). part_baker's members-front: a member drawn over the engine but behind a nearer member that's drawn under
  it goes under too (a file of haulers in a diagonal view drew in the wrong order: C4).
- **FS1** (`docs/concepts/great_sling/`, `635-`, `636-`): the frogs' great sling, three ideas; Claude: A, the bullfrog leaper.
- **Siege shots** (Dominic: "the rocks they throw look really bad"): an engine's body part names what it throws
  (`shot`), `data/siege_shots.json` the look: a baked sprite (`shot.<look>`, `siege_models.gd` shot_model: a rough
  boulder with a pale chipped face and moss, a cheese wedge with holes and rind, an acorn, a silk-bound ball of bones
  and a skull, a corded clay pot, and the bolt: an ash shaft, iron head, three vanes), the great sling's the same
  bigger; tumbling through its 8 baked facings in flight (the bolt nose first, pitched along the arc), a ground shadow
  tracking under the arc that shrinks and fades as it climbs, and an impact: chunks of its colour thrown up and falling
  back, the stone bouncing on and rolling to a stop (boulder, acorn) or bursting into pieces (cheese, bones, clay),
  over the splash's dust ring. `combat_fx.gd`, drawn from the part bakes; mods' flight styles (main's `Mods.shots`)
  untouched. `tests/shot_sheet.gd` draws before and after (`637-`); in a match `638-`.
- **Placement:** cases add the war beast in every LINE_PROMPTS culture and the packed sling of every take; a new 3D rule,
  A1 the engine stands on the ground (not floating, pressed in at most 4: it caught the elephant's legs 3 under the
  ground; the riderless tarantula had no rule at all); the snail catapult's tail lifted out of the ground.

**The bullfrog leaper in play; war beasts break cavalry (2026-10-14; D-131).**
- **The frogs' great sling** (FS1 A): `siege_models.gd` _frog_sling (OWN `sling.frog`; ENGINE_STAND_IN is empty now, the
  snail catapult stand-in gone; `bullfrog()` moved there from `m13_concepts.gd`): the counterweight sling at 0.9 of GS2's
  frame, the long arm down in front with a loaded pouch on the ground, the short arm up behind with a wicker landing pad
  in team cloth, the reed tower behind (four bundled posts, lashed braces, a plank top, a pennant) with the giant olive
  bullfrog crouched on it. Crew (the race's frog workers): a loader at the pouch with a pile of clay pots and river
  stones, two haulers on the re-cocking rope (from the arm's long end to a stake ahead), one minding the tower. Its shot
  stays `clay_big` (the corded clay pot, 2.3 against the catapult's 1.4). Stats as before (hp 110, armour 1/8, food in
  its cost: the bullfrog is alive); `placeholder` dropped.
- **Packed** (`siege.sling_packed.frog`, _frog_packed): the tower's reed posts, the frame's timbers and the arm lashed
  along a heavy sledge, the pad on top, a coil of rope; the bullfrog hauls it in a breast band, the traces tied to the
  runners' curled fronts; two frogs walk beside.
- **The throw** (`siege.sling_throw.frog`, the body part's new `throw`): the bullfrog landed on the pad, the arm swung
  through (the long end high in front, the sling whipped over it, empty), the re-cocking rope slipped off and coiled
  by its stake. `UnitView.loose` shows it for 0.9 s after each shot (`_throw`, like `set_packed` a swap of the baked
  body, only once it's baked; packing up straight after a throw goes back to the set-up look first). art_kit bakes it
  with the packed look. The pad hangs level on its pin in both poses.
- **Placement:** the haulers stood 14 apart and in each other (C1: frogs are wide), now 21; in the throw's f4 the loader
  drew over the nearer hauler (C4: the rope rising past the hauler made it "behind the engine"), fixed by moving the
  haulers out and letting the rope slip off as it throws. Cases add the frogs' and the winged frogs' packed and
  throwing slings. Full placement_check passes. Sheet `tests/sheets/great_sling_play.json` (frog rows: set up,
  throwing, packed), `640-` (3x), `641-` (1x); in a match `642-` (`tests/sim_screenshot.gd ... flat_test sling
  "swamp frogs" "romans"`, a new scene: one sling throwing at houses, one rolling by on its sledge).
- **War beasts against cavalry** (D-131, Claude: the genre's beasts break cavalry; spears and skirmishers stay their
  counters): `engine.beast` gets `bonus: {mounted: 12}` and `price_points` 12 (its points stay 10): a war beast now
  costs 540 (325 food, 215 gold) against 500. `tests/mass_battle.gd -- 3 [budget] beasts` (the `beasts` word no longer
  reads as a budget of 0 when the budget is left out), before -> after:
  at 3000 a side, beasts v cavalry 2 -> 6 of 10 (one draw; value left 8% -> 57%), v swords 8 -> 10, v archers 8 -> 8;
  spears v beasts 10 -> 10, skirmishers v beasts 8 -> 6, bolt+spear v beasts 10 -> 10; beast+archer v spear+archer
  6 -> 7. At 1500 (three beasts a side, many fights to the time limit): cavalry 4 -> 9 for the beasts, spears 6 -> 4,
  skirmishers 5 -> 4 for the counters. The counters' only losses that moved are the centaurs' (Maximian Cohort): their
  spears and skirmishers are mounted, so a beast breaks them too; every other race's spear and skirmisher fights are
  unchanged. Tried: +6 at 12 points (cavalry 5 of 10 at 3000), +8 at 13, +10 at 14 (the price rise took a beast off
  each side, cancelling the bonus). Many 1500 fights still end at the time limit with both sides standing (beasts
  and their counters not closing), an old quirk of the beasts' matches. `balance.gd -- 3` has no engines or beasts in
  its round robin, so it is unchanged (21 of 38 units more than 20% off the mean, counters 81%, as on main).

**Open (2026-10-14):** Dominic's look at the bullfrog leaper (and its throw) and the war beasts in a match; the centaurs'
spears and skirmishers losing to war beasts (they are cavalry) if he wants it otherwise. Earlier (2026-10-13): Earlier: Dominic's picks for TC1, WB1, SP1 and GS1, and then their looks; war beasts' data
and generator role once a beast is picked; the design change above; an engine-rolling sound; the great
sling showing packed and set-up looks (units.ready is there for the view).

## Changes from the original plan

- 2026-10-13: no generic Raider line (Dominic, D-123); raiders are unique-unit themes. The planned
  slot is kept in `data/later/raider_line.json`. The mounted archer opens in age 2, not 3, so the line
  has an upgrade step.

- 2026-10-13: siege first (Dominic: "why we not done siege yet?"), ahead of step 1. Step 2 shrinks
  to splash, minimum range and the bonus vs buildings: projectiles that can miss are built
  separately as flying arrows for every ranged unit.

## Links
- `m12-tech-tree.md` (the tree), `m14-race-identity.md` (what each race does with these lines)
- `../roster-template.md` (the role plan and per-family variants)
