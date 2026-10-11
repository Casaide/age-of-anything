# Unit art direction (proposal, 2026-10-11): waiting on Dominic

Dominic asked for "a solid planned approach and direction, concepts, examples from other games,
clear approach before anything done". A research agent studied how the genre draws small
soldiers, the history of our first cultures, and our own human figure. This is the plan that
came out of it. **Nothing gets built for units until Dominic approves it.** (The game examples
were given in chat; per house rules, no commercial games are named here.)

## Why the human looks like a blob
Measured from `scenes/art_pixel/unit_models.gd`:

| | Ours | Realistic | Proposed ("chunky classic") |
|---|---|---|---|
| Height in heads | ~3.4 | 7-7.5 | ~4.5 |
| Head width / shoulders | ~57% | 35-40% | 30-35% |
| Legs / height | ~26% | ~47% | ~40% |
| Visible neck | none (under the kerchief) | | 1-2 px |

1. **A ball on a bell:** a near-sphere skull says nothing about which way the unit faces. The rat's
   snout and ears do exactly that, which is why rats work.
2. **No neck, narrow puffed shoulders:** a peg doll. Puffed sleeves read as a later era, not ancient.
3. **Hair is a second helmet, and helmets are lids on it.** Head gear sits on the hair bowl, so a
   helmeted head is a bigger blob. The genre does the opposite: **the helmet is the cranium**,
   and the face shows under the brim.
4. **The face:** white eye decals become one "googly" pixel; on dark skin, face, hair and outline
   merge into one brown disc.
5. **The downsample:** a cubic average over textured skin muddies an 8 px face.
6. **Data:** `helm.cap` is the only age-1 helmet and has no culture, so everyone gets it.

## What the genre does at 30-60 pixels
- The helmet or hat *is* the head; the face is a 2-4 px skin patch with at most one dark
  eye/brow row. Below ~20 px, games drop faces entirely.
- Head gear is drawn 1.2-1.5x real size; crests, plumes and spikes give the vertical read.
- Culture reads from big shapes: shield outline, head-gear silhouette, cloth colour block, weapon.
- **Each upgrade changes the silhouette:** bare, then a helmet, then a bigger helmet with a plume.
- One consistent team-colour region; outlines in dark local colour, not black (we already do).
- Chunky heroic proportions read better than realistic ones; realism costs readability in big
  fights. A big head only works when most of it is hat or hair shape, not a skin ball.
- A parts-based colony sim layers head, hair and apparel sprites per facing: the closest
  precedent for our parts kit.

## Facings (Dominic: "we lack an image for units moving up or down")
- Today: one three-quarter view, mirrored left/right. Walking straight up or down reads as
  crab-walking.
- The genre's minimum is **8 facings** (classically 5 drawn and 3 mirrored); remasters use 16.
- **Proposal: 8 facings, all baked, none mirrored.** Mirroring flips the light (against the
  buildings) and swaps shield and weapon hands; for us an extra bake costs milliseconds.
- Measured: 52 part bakes for two rosters in 0.44 s today, so 8 facings is about 3.5 s naive,
  about 1 s if several parts bake per frame. The atlas grows from about 2048x60 to 2048x450.
- The real work is code: sockets per facing, draw order per facing (a cape in front when walking
  away), gait for up/down views, and facing selection with hysteresis so units don't flicker.
- Back views have no face, which is one more reason for head-gear-as-cranium.

## Pipeline: are we making it harder for ourselves? (Dominic)
| | 3D baked (now) | Pixel art per part | Hybrid |
|---|---|---|---|
| 8 px heads | weak now; better with toon shading, no texture, no averaging | best: every pixel chosen | best where it matters |
| Cost per new part | low: a model function | a sprite per facing | low bodies; small head stamps per facing |
| Cost per facing | ~0 (re-bake) | parts x facings | ~0 bodies; heads x facings |
| Any creature x any gear | best: gear fits a declared skull in 3D | hard: gear per head shape per facing | gear per head family |

**R0, a fair bake-off before any concept round:** one Roman age-1 spearman, plus the same head in
an age-3 galea, in three facings (towards, three-quarter, away). Same new proportions and the
helmet-replaces-cranium rule in every contender, so the test compares pipelines rather than designs:

| | Contender | Claude time |
|---|---|---|
| A | today's 3D (control) | 0 |
| A+ | tuned 3D: new proportions, banded head shading, untextured face, no averaging, one dark brow row | ~0.5-1 day |
| B | pixel-authored head, helmets and body in 3 facings | ~1-1.5 days |
| C | hybrid: A+ body with B's head stamps | ~0.5 day more |

**Judged on:**
1. Reads as a human, and as a Roman, at 1x (a blind pick).
2. The facing is obvious.
3. No blob.
4. Sits with the rats and frogs.
5. Hours to add one new helmet in 8 facings.
6. The same helmet fits rat and frog heads.
7. Walk stability.

**Rule:** take the cheapest pipeline that passes 1-3.

## Proposed style spec (R1 and R2 confirm it)
- **Proportions:**
  - Body: about 4.5 heads tall. The head is an egg 0.8 wide, with the chin and nose forward and a
    brow ledge. A visible neck, shoulders two heads wide, longer legs, chunky hands and feet.
  - Head gear: 1.1-1.3x the head's width. It adds +0.3 to +0.8 of a head in height by age.
- **Parts:**
  - Face: front plane, brow, nose, jaw.
  - Cranium: hair *or* head gear, never both. Gear declares what it covers in data.
  - Facial hair, neck, torso, sleeves, legs (bare, trousers or wraps).
  - Each head declares its skull centre and size, so one helmet fits human, rat and frog.
- **At 8 px:**
  - The cranium is at least two value steps from the skin.
  - About 3x3 px of lit face.
  - One dark brow row, no white eyes.
  - A 1 px nose or chin bump on the facing side.
  - A nape element (hair or neck guard) for back views.
- **Ages:**
  - Age 1 is soft and low: cloth, fur, hair.
  - Age 2 adds one metal piece that replaces the cranium, plus the culture's shield.
  - Age 3 adds full metal and a vertical element, and armour broadens the shoulders.
  - Each age grows the silhouette by about 10%.
- **Values:**
  - Hair and face at least 25% apart in lightness on every skin palette.
  - Bronze warm, iron cool.
  - No texture on faces.
  - One team-colour region shared by every creature.

## Per culture, per age (history checked; myths noted)
| Culture | Age 1 | Age 2 | Age 3 |
|---|---|---|---|
| Rome | wolf-skin hood (light troops) or a leather cap in the Montefortino shape | Montefortino with its top knob (three upright feathers), oval shield | imperial galea with neck guard, crest for officers, curved rectangular shield |
| Greece | felt pilos or petasos; fox cap with a crescent shield for light troops | Chalcidian or bronze pilos, big round shield | Corinthian with crest |
| Norse | bare head, braids and beard, or hood, or fur cap; round shield | conical iron helmet with nasal | spectacle helmet with mail; **horns are a myth** (Bronze Age, then 19th-century opera costumes): only on a silly ask |
| Egypt | shaved head or short wig, white kilt | striped headcloth | scale armour; the Sherden guard's horned helmet with a disc (historical horns!) |
| Han China | topknot and headwrap, crossbow | hood helmet with neck curtain, halberd | plumed lamellar |
| Aztec | tied hair, quilted cotton, round shield | rank hat and back banner | eagle or jaguar helmet (face in the beak or jaws) |

## Concept rounds, in order
Each round has 3-5 options, shown close up and at game scale, in three facings, next to a rat and a frog.

- **R0:** pipeline bake-off (above).
- **R1:** base human figure and turnaround.
  - Options: realistic, chunky classic (recommended), today's proportions fixed, heroic.
  - Recommended: bigger head *gear*, not a bigger skin head.
- **R2:** bare heads (egg, square jaw, long face) and hair (crop, tied back, topknot, braids with
  beard, shaved); face with no marks, a brow row, or white eyes.
- **R3:** each culture's head gear per age (the table above).
- **R4:** shields per culture, with team colour on the face, the rim or an emblem.
- **R5:** tunic cuts, armour types, legs, and the single team-colour region.
- **R6:** whole rosters of two cultures, in 8 facings, in a crowd in the game view.

## Mixed races and many eras (Dominic: look at the mixed-race and multi-era classics)
Two more studies, of a mythology RTS (humans next to myth creatures) and a many-epoch RTS:
- **One body language for every creature.** Humans, creatures and animal-headed humans share one
  light, texture density and chunky heroic build (big hands, broad shoulders). Creature-headed
  human bodies are exactly our parts model. So the style spec above is the *shared* spec;
  creature heads are variants of it.
- **A scale ladder:**
  - Workers and infantry of *every* creature share one height (about 40 px), so armies read
    as equals.
  - Large units (mounts, Heavy elites) are about 1.4-1.8x that height; giants about 2-2.5x.
  - An elite is about 1.1x with a unique crest.
  - Size encodes the counter class (spear > large).
- **The look changes only per age, never per research.** One clear, whole-kit step per age. The
  material ladder runs cloth, hide and wood (age 1), bronze (age 2), iron and a crest (age 3). Later
  era packs carry on up it (steel and dyed uniforms, then khaki, then alloy), with a big silhouette
  break only where the era truly changes (gunpowder, sci-fi). Too many small steps blur together.
- **Culture at every age.** A custom-civ system that reused the same unit models made custom civs
  look the same. That's the trap to avoid. Each family gets a culture palette (cloth, accent,
  metal tint, shield paint), a shield shape and a head-gear line, so even age-1 units differ;
  palette and shield read first at distance, head gear second. Team colour stays one region.
- **Concept rounds change:**
  - R1 shows each option in a mixed lineup: rat, frog and beetle at infantry height, plus a
    centaur or giant for the scale ladder.
  - R3 shows one full unit line, age 1 to 2 to 3, at game scale.
  - R5 adds 3-4 culture palettes per culture.
  - R0 also judges whether the human sits with the frog and rat.
  - A later R7 builds the material ladder for era packs.

## Dominic's answers (2026-10-11)
- Run the 3D vs pixel test: **yes**.
- 8 baked facings, all directions: **yes**.
- Horned helmets: **not by default**.
- Non-European cultures: **all three** (Egypt, Han China, Aztec).
- Workers' costs vary with the body (centaurs faster, carry more, tougher, dearer).
- He wants deeper research with linked examples, and concepts before anything is committed. The
  buildings must show their culture in their structure, not a token on a generic shape (the lily
  pad on a frog hut). Pixel drawing may give more freedom than 3D primitives. A design agent is on it:
  `docs/concepts/research/`.
- Rat buildings look bigger than Roman ones on the same footprint: a building scale rule is needed.

## Design review approved (Dominic, 2026-10-11)
The review "Gone mad, played straight" (five rules: played straight; structure, not stickers;
silhouette first at 8 px; one body language and one scale ladder; each age one whole step):
"on the art side that all makes sense".

**Scale, refined by Dominic:** a culture's buildings are never bigger than the envelope for their
type, but may sit *shorter and more melded into the terrain* than others, so they come across as
less intense and more natural. Same footprint as everyone; lower and part of the ground. (He
pointed at a classic RTS's swamp faction, whose town centre is no smaller than the empire's,
just lower and grown into the land.)

## Psychology and comedy lead (Dominic, 2026-10-11)
How a culture's buildings grow through the ages comes from how its people feel about the world:
- **Small creatures (rats, frogs, bugs) are proud.** By the top age their buildings show they
  think they've made it, level with the humans: still an oversized shed, but trying hard. Rats
  add columns made from stacked oil drums, emulating the Romans; the comedy is in the earnest
  imitation.
- **Bears and beavers don't care about humans.** They don't emulate anyone; their late-age
  buildings are their own thing, and genuinely impressive (dams, great lodges).
- So each culture's age story is written from its psychology first, then its materials.

**Rat Town Centre picked** (Dominic, 2026-10-11): the no-plinth hall made smaller than the human
halls, with scrap and weeds round its base (`junk_town_center_small`, now in play). Human
buildings always read biggest; creature buildings sit lower and smaller on the same footprint.

## Questions for Dominic (original)
1. Is a 1.5-3 day pipeline bake-off (R0) worth doing first?
2. 8 facings, all baked, none mirrored?
3. Horns only on a silly ask?
4. Which non-European culture first: Egypt, Han China or Aztec?
5. Plus the round 1 questions in `README.md` (R1 now covers the head-size one).

**Data fixes that don't depend on the answers:** culture-tag the head gear so `helm.cap` stops being
everyone's; give "vikings" a Norse family.
