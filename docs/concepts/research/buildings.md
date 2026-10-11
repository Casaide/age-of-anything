# Buildings that show a culture (research, 2026-10-11)

Creature cultures (frogs, beetles, spiders, rats, bears, beavers) are in
[creature-cultures.md](creature-cultures.md). This file covers the diagnosis, the principles, the
scale ladder, and the six human cultures. Game references are codes like [G7]; the list was given
in chat (see [README.md](README.md)).

## 1. What we have, and why it reads as lazy

Look at `archive/images/2026-10-11/94-six-architectures-reed-and-mound-added.png` (rows: thatch,
junk, stone, tent, reed, mound), `95-frog-reed-town.png` and `96-beetle-mound-town.png`.

**What works (stone and tent).** The Roman town centre and the steppe tent read as cultures
because every visible form comes from a real way of building:
- Roman: a podium, a hall of plastered walls, a column porch carrying an entablature, a
  terracotta tile roof at the pitch tiles allow, a pediment, a fire bowl on a tripod. Nothing is
  stuck on; each part holds up or protects another.
- Steppe: a round lattice wall, a conical roof on rafters meeting at a crown ring, rope bands
  holding felt down against the wind, a door flap. Again, the shape *is* the construction.

**What doesn't (reed and mound), and why.** In `src/view/art/bake/models.gd`:
1. **Barracks, stable and watchtower are one layout for every culture.** `_barracks`, `_stable`
   and `_tower` build the same hall, yard, straw target, dummy, spear rack, hay bales and trough
   for all six architectures; only materials change, through the `KIT` table. Reed gets
   `dome: true, stilts: true`; mound gets `dome: true`. A frog barracks is a Roman barracks with a
   thatch dome and a lily pad. This is the "custom civs that reuse the same models all look the
   same" trap from `../direction.md`, applied to buildings.
2. **Primitives with no construction story.** The frog dome is a smooth thatch hemisphere on a
   short woven wall: an African or English hut shape. Nothing says *reed*: no bundles, no arches,
   no lattice, no lashing. The bug mound is a smooth lump with round holes: nothing says how bugs
   build (pellet by pellet, chewed paper, silk, rolling).
3. **The sticker.** The lily pad on the roof (`_lily_cap`) does nothing. A lily pad that
   *meant* something would be a shingle, a float, a sunshade, a rain basin, or the foundation.
4. **No relation to the creature's life.** Frogs need water, damp and somewhere to lay eggs; the
   frog town sits on dry grass on a plank deck. Beetles dig, roll, chew and farm fungus; spiders
   hang, stretch and ambush. None of that is in the buildings.
5. **Shared props.** Plank stilts, plank decks, post-and-rail fences, pennants on poles, straw
   targets, hay bales, wooden barrels: the same vocabulary everywhere, so cultures blur.
6. **No growth story.** Ages swap sizes and stack another dome; they don't show a culture
   getting richer in *its own* way.

## 2. What "deep culture" means visually

The test: **cover the team flag and the lily pad. Can you still tell who lives there, and how it
was built?** The best genre examples pass it:
- **A classic medieval RTS's architecture sets [G1]**: every civ has the same building types and
  footprints, but each set changes the *system* (roof form, wall material, tower shape), not
  just the colour. The houses [G3] and town centres [G2] are the cleanest comparison: same
  footprint, same height band, utterly different construction. *Take:* same envelope, different
  structural system.
- **Its later sequel's steppe civ [G5]**: buildings are gers on carts that pack up and move. The
  mechanic, the look and the culture are one idea. *Take:* let the culture's way of life decide
  the building's form.
- **A mythology RTS [G8]**: the Norse longhouse is a long timber hall with a ridge and dragon
  gables, and the Egyptian fort is a battered mudbrick tower (a migdol); the hill fort is a timber
  stockade on an earth mound. *Take:* the building type is reinterpreted per culture (a
  "barracks" is a longhouse for one people and a military camp for another), not reskinned.
- **The living buildings of a fantasy RTS's forest elves [G9]**: the barracks is an ancient tree
  that walks; the town hall is a tree of life. The orcs' burrows [G10] are spiky hide-and-bone huts
  that hold peons, and the undead ziggurats [G11] are their farms. *Take:* when the culture is
  non-human, build from its biology and beliefs.
- **The insect faction of a sci-fi RTS [G13]**: every building is an organism grown on creep (the
  hatchery, the spawning pool, the spire, the sunken colony). The town centre is literally where
  larvae spawn. *Take:* the strongest model for bug and frog towns. Structure = biology, and the
  ground itself changes under the town.
- **Small-creature worlds**: the insect kingdoms of a bug RPG [G16] (the termite kingdom's spires,
  the ant capital, the bee hive palace) and the bug city of a hand-drawn metroidvania [G15] (the
  weavers' silk dens, the mantis village of hanging pods, the hive). *Take:* insect architecture
  is grown, spun, chewed or dug, never assembled from planks.

**The six layers of a culture brief** (used for every culture below and in
`creature-cultures.md`):
1. **Materials:** what's at hand, and what's precious.
2. **Construction logic:** how it is really built, step by step. This should *produce* the
   shapes.
3. **Shape grammar:** 3-5 recurring forms that every building is made of (e.g. a bundled arch, a
   lattice end, a tufted column).
4. **Site:** how it meets the ground (on stilts, floating, dug in, hung, on a podium).
5. **Meaning:** motifs tied to what the people value; where the team colour goes, in a way
   native to the culture.
6. **Growth by age:** what changes from age 1 to 3, in the culture's own terms (more arches, a
   taller spire, metal fittings), plus a silhouette break at each age.

## 3. The building scale ladder (Dominic: "weird the rat buildings are bigger than the Roman ones")

**The cause.** The sim footprints are identical (`data/buildings.json`: town centre, barracks and
stable 3x3; house and farm 2x2; watchtower 1x1). The models aren't. Measured from `models.gd` (one
model unit is about one tile; the town-centre plinths are 2.8 units on a 3-tile footprint):

| | Body footprint | Top of body (no flags or smoke) | Rough volume |
|---|---|---|---|
| Roman town centre (`stone_town_center`) | hall 1.9 x 1.55, on a 2.9 podium | ~1.9 | ~2.9 |
| Rat town centre (`junk_town_center`) | full 2.1 x 2.1 cube, roof 2.7 wide | ~2.2 (stove pipe ~2.9) | ~4.6 + roof (~1.6x) |
| Roman house (`villa_house`) | 1.15 x 1.0 | ~1.17 | ~0.8 |
| Rat house (`tin_can_house`) | 1.56 across (lid) | ~1.3 (chimney ~1.5) | ~1.6 (~2x) |
| Steppe town centre | tent r 1.05 + small tent | ~1.33 | low and wide |
| Frog town centre | 2.5 deck, dome r 0.92 on 0.46 stilts | ~1.7 | wide; the deck is most of the mass |

So the rat buildings are bulkier because each model was built on its own with no shared
envelope.

**How the genre keeps sizes consistent.**
- A classic medieval RTS [G1][G2][G3]: each building type has one footprint and one height band
  for *all* civs. A house is a house-sized lump whether it's a timber cottage or a mudbrick cube;
  the town centre is always the biggest economic building; castles all share one mass. Culture
  changes the silhouette *within* the envelope.
- Its first game [G4] shows the town centre growing per age inside the same footprint: the
  silhouette changes, the footprint never does.
- Buildings are drawn *small* relative to units. A house is only about 2-3 villagers tall,
  far shorter than real life, because units are drawn about 1.5-2x too big so they read. Every
  culture follows the same compression, so cultures compare fairly.
- The fantasy RTS [G9][G10][G11] and the sci-fi RTS [G13] do the same across wildly different
  races: the elves' tree barracks and the orcs' hide barracks occupy the same footprint and
  similar heights; the insect hatchery and the human command centre are equally big.

**Should a rat town look rat-sized?** No: buildings match other cultures for readability. Reasons:
- The player reads *type from size* before anything else (big = town centre, long = barracks,
  thin and tall = tower). If rats get small buildings, a rat town centre reads as a house.
- Fairness: a player's sense of how strong an enemy base is comes from mass on screen.
- The "creature scale" joke is told by the *object*, not by the envelope. A tin can is a funny
  house *because* we know cans; it can be a house-sized can. The scale cue that keeps it honest is
  the **door**: every culture's door is the same height (about 1.1x an infantry unit, since all
  infantry share one height per `../direction.md`). A rat door cut into a can tells you the can is
  huge to a rat, without the can being bigger than a Roman villa.

**The rule (applies to every architecture).** Heights in tiles (model units), measured to the
top of the solid body. Flags, smoke, banners and one thin "crown" element (a spire, finial,
chimney, antenna or horn no wider than 0.3) may rise above it by the stated allowance.

| Type | Footprint | Solid body max (w x d) | Wall or eave height | Body top, age 1 / 2 / 3 | Crown allowance |
|---|---|---|---|---|---|
| Town centre | 3x3 | 2.4 x 2.4 | 0.9-1.2 | 1.7 / 1.9 / 2.1 | +0.5 |
| Barracks | 3x3 | 2.5 x 1.6 (long, low) | 0.7-0.9 | - / 1.4 / 1.6 | +0.3 |
| Stable / large-unit building | 3x3 | 2.5 x 1.8, open front | 0.6-0.8 | - / 1.3 / 1.5 | +0.3 |
| House | 2x2 | 1.4 x 1.4 | 0.6-0.75 | 1.1 / 1.2 / 1.3 | +0.3 |
| Watchtower | 1x1 | 0.8 x 0.8 | - | - / 2.0 / 2.2 | +0.3 |
| Farm | 2x2 | full plot | - | 0.3 (one scarecrow-type marker to 0.9) | none |
| Door (every building) | | | 1.1x infantry height | | |

Orderings to hold, always: **in height**, watchtower > town centre > barracks > stable > house >
farm; **in mass** (on-screen solid pixels), town centre > barracks ≈ stable > house > watchtower
> farm. Each age grows the body by about 10% and changes the silhouette (no age is "the same
model, bigger").

**How to enforce it.** A lineup sheet (concept sheet BC0 in `concept-plan.md`) bakes every
architecture's buildings side by side on one ground strip with an infantry unit beside each door.
Later a headless check can read each bake's opaque-pixel count and height and flag anything more
than 15% off the reference (pick the Roman set as the reference, since Dominic likes it).

**Applied today:** the rat town centre loses about a third of its bulk (a narrower hall, a lower
eave, the stove pipe as its crown); the tin-can house shrinks to about 1.2 across and 1.1 tall;
the frog town centre's deck shrinks so the dome, not the platform, is the mass.

## 4. Human culture briefs

The existing `stone` architecture serves Romans, Greeks and the "royal" family alike. These briefs
split them. Each culture: materials, construction, shape grammar, signature building per type,
meaning and team colour, age growth, references. (Units for each culture are in `units.md`.)

### Roman
- **Materials:** fired brick and tile, Roman concrete faced with small stones in a net pattern,
  limewash, travertine and marble trim (later), timber, terracotta.
- **Construction logic:** brick-faced concrete walls let them build **arches and vaults**; tile
  roofs at a low pitch (about 20-25°) of flat tiles with half-round cover tiles over the joints;
  courtyard houses face inward. The army builds the same square camp everywhere.
- **Shape grammar:** the round arch; the low tiled roof with cover-tile ribs; the courtyard (a
  hole in the roof catching rain); the square camp gate with two towers; the podium temple front.
- **By building:**
  - Town centre: a forum front: an arcade of arches on a podium, a tiled hall, a statue base.
    Age 3: a basilica clerestory and a triumphal-arch gate.
  - House: an inward-facing courtyard house (blank walls, one door, a roof sloping into the
    centre) for age 1-2; an apartment block of two storeys with shop arches below for age 3.
  - Barracks: **the camp**, not a hall: an earth bank and timber palisade, a gate with two
    towers, rows of leather tents inside (age 1-2), stone barrack blocks (age 3).
  - Stable: an arched brick shed with a tiled roof and a paved yard.
  - Tower: a square signal tower with a gallery and a beacon (the column in Rome shows them).
- **Meaning and team colour:** standards (the eagle, the square cavalry flag on a crossbar),
  shields stacked by the gate, painted plaster bands. Team colour: the square crossbar flag, the
  plaster band under the eaves, door curtains.
- **Age growth:** timber and thatch-tile mix (age 1, early Republic) -> brick, tile and arches
  (age 2) -> marble facing, concrete vaults, a dome or basilica (age 3).
- **References:** [Roman architecture](https://en.wikipedia.org/wiki/Roman_architecture);
  [Insula (apartment blocks)](https://en.wikipedia.org/wiki/Insula_(building)) (take: shops under
  arches, two-storey blocks); [Domus](https://en.wikipedia.org/wiki/Domus) (take: the blank-walled,
  inward-looking house); [Castra](https://en.wikipedia.org/wiki/Castra) and its
  [Commons gallery](https://commons.wikimedia.org/wiki/Category:Castra) (take: the barracks as a
  camp with a gate); [Trajan's Column gallery](https://commons.wikimedia.org/wiki/Category:Trajan%27s_Column)
  (take: legionaries building camps, signal towers, bridges: the best ancient "how they built"
  picture book); [Imbrex and tegula](https://en.wikipedia.org/wiki/Imbrex_and_tegula) (take: the
  roof rib pattern that reads at 1x).
- **Genre reference:** the Roman civ of a classic RTS and its expansion [G43] (its buildings borrow the
  Mediterranean set); the Roman camp-builders of a settlement game [G38].

### Greek
- **Materials:** limestone and marble for temples; mudbrick on stone footings and timber for
  everything else; terracotta roof tiles with painted antefixes; whitewash and ochre.
- **Construction logic:** post and lintel only (no arches): columns carry beams, so spans are
  short and buildings are long colonnades. Houses are mudbrick rooms around a courtyard.
- **Shape grammar:** the colonnade (a stoa: a long roofed porch, open on one side); the round
  building with a ring of columns; the triangular gable with painted tile ends; the courtyard; the
  open exercise ground.
- **By building:**
  - Town centre: a stoa on the edge of an agora: a long colonnade with a back hall, a herm and an
    altar in front. Distinct from the Roman arcade: square beams over columns, no arches.
  - House: whitewashed mudbrick cube on a stone footing, flat or low tiled roof, a small court.
  - Barracks: a **gymnasium / exercise ground**: a sanded open yard with a colonnade on one side,
    racks of round shields and spears, a running track mark.
  - Stable: a timber colonnade over stalls; horse-head antefixes.
  - Tower: a round tower of fitted polygonal stone (the island forts have them).
- **Meaning and team colour:** painted shield blazons, the meander key along friezes, painted
  roof-tile ends (team colour), dedications at altars.
- **Age growth:** timber and mudbrick with a thatch or tile roof (age 1, "Geometric") ->
  limestone columns and painted terracotta (age 2, "Archaic") -> marble, sculpted pediments,
  a round temple (age 3, "Classical").
- **References:** [Ancient Greek temple](https://en.wikipedia.org/wiki/Ancient_Greek_temple);
  [Stoa](https://en.wikipedia.org/wiki/Stoa) (take: the town-centre form);
  [Agora](https://en.wikipedia.org/wiki/Agora);
  [Meander](https://en.wikipedia.org/wiki/Meander_(art)) (take: the frieze band);
  [Corinthian helmets gallery](https://commons.wikimedia.org/wiki/Category:Corinthian_helmets).
- **Genre reference:** the Greek town centre and military camp of a mythology RTS [G8] (take:
  how it keeps Greek buildings "white column + red roof" yet different from Romans by colonnades
  and painted blazons).

### Norse
- **Materials:** timber (oak, pine), turf, wattle and daub, stone footings, split shingles, tar.
- **Construction logic:** long halls with **curved, boat-like walls** and inner rows of posts;
  turf or shingle roofs; stave buildings stack roofs in tiers. Ring forts are circles of earth bank
  with timber.
- **Shape grammar:** the ship-hull curve of a long hall's ridge and walls; the steep shingled
  roof; crossed gable boards ending in carved beasts; turf roofs; the circle fort.
- **By building:**
  - Town centre: a great hall: curved long walls, a turf or shingle roof, carved dragon gables,
    shields hung along the walls.
  - House: a small turf-roofed house, half-dug, smoke from a roof hole.
  - Barracks: a longhouse with weapon racks and a fenced practice ring.
  - Stable: a turf-roofed byre (animals lived at one end of the long house).
  - Tower: a timber watchtower on a stone footing with a horn.
  - A boat shed (the dock later) is their most cultural building.
- **Meaning and team colour:** carved interlace and beasts, painted round shields on the hall
  walls (team colour), striped sails and woven bands.
- **Age growth:** turf and wattle huts (age 1) -> timber halls with carved gables (age 2) ->
  tiered stave buildings and a ring fort (age 3).
- **References:**
  [Longhouse](https://en.wikipedia.org/wiki/Longhouse);
  [Medieval Scandinavian architecture](https://en.wikipedia.org/wiki/Medieval_Scandinavian_architecture);
  [Stave church](https://en.wikipedia.org/wiki/Stave_church) and its
  [gallery](https://commons.wikimedia.org/wiki/Category:Stave_churches) (take: the tiered age-3
  silhouette with dragon heads); [Borgund Stave Church](https://en.wikipedia.org/wiki/Borgund_Stave_Church);
  [Earth shelter / turf house](https://en.wikipedia.org/wiki/Earth_shelter);
  [Oseberg ship gallery](https://commons.wikimedia.org/wiki/Category:Oseberg_ship) (take: the
  carving style and the curved hull line for roofs); [Viking art](https://en.wikipedia.org/wiki/Viking_art).
- **Genre reference:** the Norse longhouse and hill fort of a mythology RTS [G8]; the Norse clan
  town hall of a modern Norse RTS [G14] (take: snow, turf and carved gables carry the culture even
  at a distance).

### Egyptian
- **Materials:** sun-dried mudbrick (everything everyday), limestone and sandstone (temples and
  tombs), palm trunks and fronds, reed matting, plaster painted in bright flat colour.
- **Construction logic:** thick mudbrick walls that **lean inwards** (a batter) for stability;
  flat roofs on palm beams where people sleep and store grain; temples are a gate (two sloping
  towers) then courts then columned halls.
- **Shape grammar:** the battered wall; the gorge (a curved, flared cornice) with a rolled edge;
  the pylon gate; papyrus- and lotus-bundle columns; flat roofs with wind-catchers and stairs.
- **By building:**
  - Town centre: a small pylon gate in front of a columned hall, flagpoles in the pylon's
    niches (team colour flags, exactly as the real ones had).
  - House: a mudbrick block with a flat roof, a roof shelter of palm fronds, stairs up the side,
    a grain bin on top.
  - Barracks: a walled compound with battered walls and a gate; archers' targets.
  - Stable: chariot sheds (the chariot is the elite) with palm-trunk posts.
  - Tower: the migdol, a battered tower with crenellations.
  - Granary domes (beehive-shaped) for the farm.
- **Meaning and team colour:** painted friezes, the winged sun over doors, cartouches, flagpoles on
  the pylon. Team colour: the pylon flags, painted door bands, the cornice stripe.
- **Age growth:** reed-and-mud huts and a mud enclosure (age 1, Predynastic) -> mudbrick with
  painted cornices (age 2, Old/Middle Kingdom) -> stone pylons and columned halls (age 3, New
  Kingdom).
- **References:**
  [Ancient Egyptian architecture](https://en.wikipedia.org/wiki/Ancient_Egyptian_architecture);
  [Pylon](https://en.wikipedia.org/wiki/Pylon_(architecture)) (take: the gate with flag niches);
  [Deir el-Medina](https://en.wikipedia.org/wiki/Deir_el-Medina) and its
  [gallery](https://commons.wikimedia.org/wiki/Category:Deir_el-Medina) (take: a workers'
  village: the right scale for houses); [Mudbrick](https://en.wikipedia.org/wiki/Mudbrick);
  [Hypostyle](https://en.wikipedia.org/wiki/Hypostyle);
  [Ancient Egyptian models gallery](https://commons.wikimedia.org/wiki/Category:Ancient_Egyptian_models)
  (take: tomb models of granaries, houses and workshops: perfect "game-scale" references);
  [Medinet Habu gallery](https://commons.wikimedia.org/wiki/Category:Medinet_Habu) (take: the
  migdol gate).
- **Genre reference:** the Egyptian migdol of a mythology RTS [G8] (take: the battered fort as the
  barracks); the Egyptian civ of a classic RTS's first game [G37].

### Han Chinese
- **Materials:** rammed earth (walls, platforms), timber frames, grey fired tile, lacquer
  (red and black), stone only for footings and tomb pillars.
- **Construction logic:** a **timber frame on a rammed-earth platform**; walls don't carry the
  roof, the frame does, through stacked brackets; heavy tile roofs with deep eaves. Courtyards
  enclosed by walls; gate towers (que) in pairs. Watchtowers of several storeys, each with its own
  eave (known from tomb pottery models).
- **Shape grammar:** the platform; the bracket cluster under the eave; the stacked tower of eaves;
  the paired gate pillars; the courtyard wall with a tiled coping. (The swept-up eave corners are
  mostly later dynasties: Han eaves are straighter, a useful age cue.)
- **By building:**
  - Town centre: a hall on a raised earth platform with stairs, a tiled hip roof, a pair of que
    towers in front.
  - House: a courtyard house: a tiled wall around a small yard, a gatehouse, one hall.
  - Barracks: a walled yard with a drum tower; crossbow racks.
  - Stable: a long tiled shed on posts.
  - Tower: **the multi-storey watchtower** from Han tomb models, balconies on every floor. This is
    the most Han building there is.
- **Meaning and team colour:** lacquer red posts, animal-mask door rings, roof-ridge ornaments,
  banners on the gate towers. Team colour: the vertical banners on the que, the lacquered posts.
- **Age growth:** rammed-earth walls and thatch (age 1) -> grey tile, timber frames, one bracket
  tier (age 2) -> multi-storey towers, lacquer, glazed ridge ornaments (age 3).
- **References:** [Han dynasty tomb architecture](https://en.wikipedia.org/wiki/Han_dynasty_tomb_architecture)
  (take: the pottery tower and house models, the best evidence of Han buildings);
  [Que (tower)](https://en.wikipedia.org/wiki/Que_(tower)); [Dougong](https://en.wikipedia.org/wiki/Dougong)
  and its [gallery](https://commons.wikimedia.org/wiki/Category:Dougong);
  [Siheyuan](https://en.wikipedia.org/wiki/Siheyuan) (take: the courtyard house);
  [Rammed earth](https://en.wikipedia.org/wiki/Rammed_earth);
  [Fujian tulou gallery](https://commons.wikimedia.org/wiki/Category:Fujian_Tulou) (much later,
  but take: rammed-earth rings as a possible age-3 fortified town centre).
- **Genre reference:** the Chinese civ of a classic RTS's later sequel [G6] (take: how it shows
  dynasties changing the buildings: a direct model for our age growth).

### Aztec
- **Materials:** volcanic stone (tezontle, red and porous), adobe, lime stucco painted bright,
  timber, reed and thatch, feathers and paper for decoration.
- **Construction logic:** **stepped platforms** (sloped panel then vertical frame, repeated)
  with temples on top; a city on a lake, built out on reed-and-mud garden plots; houses of adobe
  around a patio; everything stuccoed and painted.
- **Shape grammar:** the stepped platform with a single stair and balustrades; the twin shrine on
  top; the sloped-and-framed wall profile; the step-fret motif; the walled sacred precinct.
- **By building:**
  - Town centre: a stepped platform with one wide stair and a shrine on top (age 1: one step,
    thatch shrine; age 3: four steps, twin shrines).
  - House: an adobe cube on a low platform, a flat roof, a patio and a sweat-bath dome beside it.
  - Barracks: the warrior school (a walled hall with a patio and a drum), with shields and banners.
  - Stable: (no horses) the large-unit building is a beast pen or the eagle/jaguar orders' houses.
  - Tower: a small stepped platform with a lookout and a drum.
  - Farm: the floating garden plot, edged with willow stakes.
- **Meaning and team colour:** step-frets, serpent-head balustrades, painted bands, feather banners
  and back standards. Team colour: the painted band on the platform cornice and the paper banners.
- **Age growth:** adobe and thatch on one low platform (age 1) -> stuccoed stone, two steps,
  painted bands (age 2) -> big twin-shrine platforms, serpent balustrades, feather banners (age 3).
- **References:** [Aztec architecture](https://en.wikipedia.org/wiki/Aztec_architecture);
  [Templo Mayor](https://en.wikipedia.org/wiki/Templo_Mayor) and its
  [gallery](https://commons.wikimedia.org/wiki/Category:Templo_Mayor) (take: the twin-shrine
  platform); [Talud-tablero](https://en.wikipedia.org/wiki/Talud-tablero) (take: the wall profile;
  strictly an older central-Mexican style the Aztecs revived);
  [Chinampa](https://en.wikipedia.org/wiki/Chinampa) and its
  [gallery](https://commons.wikimedia.org/wiki/Category:Chinampas) (take: the farm);
  [Xicalcoliuhqui (step-fret)](https://en.wikipedia.org/wiki/Xicalcoliuhqui);
  [Codex Mendoza gallery](https://commons.wikimedia.org/wiki/Category:Codex_Mendoza) (take: houses,
  warrior costumes and banners drawn by Aztec painters themselves).
- **Genre reference:** the Aztec civ of a classic medieval RTS [G37] (it uses a shared
  Mesoamerican set: take its stepped stone blocks, and note we can go further with stucco colour).

### Steppe (existing tent architecture)
Already the best of our six. Keep it; at most add the cart-mounted ger for age 3 and felt
ornament bands. Genre reference: the packing gers of [G5]; real: the
[Yurt](https://en.wikipedia.org/wiki/Yurt).
