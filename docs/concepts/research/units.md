# Units: the small-scale reads per culture (research, 2026-10-11)

Builds on `../direction.md` (proportions, head gear as cranium, 8 facings, the material ladder,
one team-colour region) and `../README.md` (round 1: head gear alone can't carry a culture at
8 px). This file adds the **examples**: what the genre's best small sprites do, and linked real
references per culture and per creature. Game references are codes like [G37]; see
[README.md](README.md).

## 1. How the genre's small sprites carry identity (with examples)

At game scale a unit is about 40 px tall and its head about 8 px. What carries identity, in
order: **silhouette > colour block > shield > head-gear shape > weapon > face** (faces are almost
nothing). Each example below is a unit page with the sprite in the infobox.

| Example [code] | What to look at | What to take |
|---|---|---|
| A classic medieval RTS's swordsman line, from militia to champion [G37] | One body, the head changes per upgrade: bare or capped, a nasal helmet, a closed helm, then a tall helm with a plume | **Each age changes the head silhouette**, and the top of the head gets higher each time |
| The same game's eagle and jaguar warriors [G37] | A beak or jaw helmet with the face inside, a feather back-banner | Animal head gear reads at tiny size *because the beak breaks the head outline*; the back banner adds height |
| Its Norse infantry (the huskarl) and the throwing axeman [G37] | Big round shields and dark cloaks | Culture read from the shield shape and colour block before the head. (The same game uses horned helmets for its berserkers; we keep horns for a silly ask, per Dominic) |
| A classic RTS's first game: hoplite to phalanx to centurion, and the legion line [G37] | The same bronze body; the crest grows and turns with each upgrade | The crest is the rank: across the helmet for officers, front to back for the line |
| A mythology RTS's hoplite, hypaspist and toxotes [G37] | A tall crested Corinthian helmet over a big round shield; archers bare-headed in a cap | The Greek kit is "big round shield + crest"; light troops have no metal on the head at all |
| The same game's animal-headed humanoids (the jackal-headed anubite, the minotaur) and its centaur [G37] | Creature heads on heroic human bodies at RTS scale | Exactly our parts model. The head shape (ears, snout, horns) *is* the identity; nothing covers it |
| A fantasy RTS's human footman and orc grunt [G12] | The same role with opposite silhouettes: slim and helmeted vs bulky with tusks and pauldrons | Species difference comes from shoulder width and head shape, not detail |
| A sci-fi RTS's insect units (small biters and spined ranged units) [G13] | Non-human units of 20-30 px read through exaggerated limbs, crests and claws | Beetles and spiders: exaggerate the horn, the mandibles and the legs; don't add human clothes |
| A pixel-art animal RTS [G17] | Rats, toads, squirrels, lizards and others as tiny soldiers | Animal heads drawn big, ears and snouts exaggerated, one strong faction colour on the clothes |
| A parts-based colony sim's apparel layers [G36] | Head, hair, hat and clothes layered per facing | The closest precedent for our parts kit; hats replace hair, as in `direction.md` |
| A sprite archive's pages for these games [G41] | The raw sprite sheets in every facing | How 8 facings are drawn: front, back and side views each keep the shield on the same arm |

**Rules confirmed by the examples:**
1. **Never cover the creature's identity features with gear.** Frog eye bumps, rat ears and snout,
   beetle horn and mandibles, spider eye cluster and leg fan, horse head. Gear goes *between* or
   *behind* them: a frog helmet is a brow band or a skull cap set behind the eyes; a rat helmet
   has ear slots; a beetle "helmet" is a sheath on the horn. Look at
   `archive/images/2026-10-11/89-unit-textures-frogs-and-beetles.png`: the frogs' brown
   caps sit on the eyes and the frogs read as bears in berets; and in `90-...rats-and-centaurs.png`
   the rats' grey domes hide their ears.
2. **Culture first through the shield and the cloth block**, then head gear, per round 1.
3. **One vertical element by age 3** (crest, plume, horn, cattail, back banner).
4. **Light troops are bare-headed or soft-capped in every culture**; metal is for line and heavy.

## 2. Per human culture: shields, head gear by age, cloth

The age table in `../direction.md` stays. Here are the references to check it against, and the
shapes that read at 1x.

### Roman
- **Shield:** age 1 oval, age 2-3 the curved rectangle ([Scutum](https://en.wikipedia.org/wiki/Scutum)).
  Team colour on the shield face; a boss and a painted motif (thunderbolt, wings) as the second
  tone.
- **Head:** age 1 leather cap in the shape of the bronze helmet, or a wolf-skin hood for light
  troops; age 2 [Montefortino helmet](https://en.wikipedia.org/wiki/Montefortino_helmet)
  ([gallery](https://commons.wikimedia.org/wiki/Category:Montefortino_helmets): take the top knob,
  which can hold upright feathers, and the cheek flaps); age 3 the imperial
  [galea](https://en.wikipedia.org/wiki/Galea_(helmet)) with a broad neck guard (the nape element
  for back views) and a crest for officers.
- **Body:** red or off-white tunic, age 3 the banded
  [lorica segmentata](https://en.wikipedia.org/wiki/Lorica_segmentata) that broadens the
  shoulders; javelin (pilum) and short sword.
- **Check against:** [Trajan's Column gallery](https://commons.wikimedia.org/wiki/Category:Trajan%27s_Column)
  (hundreds of soldiers carved small: the best sheet of Roman silhouettes);
  [Legionary](https://en.wikipedia.org/wiki/Legionary).

### Greek
- **Shield:** the big round [aspis (hoplon)](https://en.wikipedia.org/wiki/Aspis) with a wide rim
  and a painted blazon (team colour on the face, the blazon as a light emblem); light troops a
  small crescent shield ([Peltast](https://en.wikipedia.org/wiki/Peltast)).
- **Head:** age 1 the felt [pileus/pilos cap](https://en.wikipedia.org/wiki/Pileus_(hat)) or the
  sun hat ([Petasos](https://en.wikipedia.org/wiki/Petasos)); age 2 a bronze pilos-shaped or
  open helmet; age 3 the [Corinthian helmet](https://en.wikipedia.org/wiki/Corinthian_helmet) with
  a tall crest ([gallery](https://commons.wikimedia.org/wiki/Category:Corinthian_helmets)).
- **Body:** linen corselet with shoulder flaps ([Linothorax](https://en.wikipedia.org/wiki/Linothorax)),
  greaves, the long spear (dory).
- **Check against:** the [Chigi vase](https://en.wikipedia.org/wiki/Chigi_vase) (a phalanx in
  painted profile: shields, crests and spears as pure silhouettes: our 1x view);
  [Riace bronzes gallery](https://commons.wikimedia.org/wiki/Category:Riace_bronzes);
  [Hoplite](https://en.wikipedia.org/wiki/Hoplite).

### Norse
- **Shield:** the [round shield](https://en.wikipedia.org/wiki/Round_shield) of planks with a
  central iron boss, painted in halves or quarters or a spiral (team colour on alternate segments:
  very readable). Kite shields only for a late-era pack.
- **Head:** age 1 bare with braids and beard, a hood or a fur cap; age 2 a conical iron helmet
  with a nose guard ([Spangenhelm](https://en.wikipedia.org/wiki/Spangenhelm)); age 3 the
  spectacle helmet with mail ([Gjermundbu helmet](https://en.wikipedia.org/wiki/Gjermundbu_helmet),
  [gallery](https://commons.wikimedia.org/wiki/Category:Gjermundbu_helmet)). Horns only on a
  silly ask.
- **Body:** wool tunic and trousers with leg wraps, a cloak; mail at age 3; axe, spear, seax.
- **Check against:** [Lewis chessmen gallery](https://commons.wikimedia.org/wiki/Category:Lewis_chessmen)
  (chunky, big-headed Norse warriors with kite shields and helmets: a medieval model of *our*
  proportions; one bites his shield); [Bayeux Tapestry gallery](https://commons.wikimedia.org/wiki/Category:Bayeux_Tapestry)
  (nasal helmets and shields as flat silhouettes); [Viking Age arms and armour](https://en.wikipedia.org/wiki/Viking_Age_arms_and_armour).

### Egyptian
- **Shield:** tall, round-topped, of hide on a wooden frame, often dappled (cowhide pattern: a
  natural two-tone that reads at 1x; team colour on the rim and the boss).
- **Head:** age 1 shaved head or a short dark wig; age 2 the striped headcloth (the
  [nemes](https://en.wikipedia.org/wiki/Nemes) is royal, so soldiers get a plain striped
  headcloth); age 3 for elites the blue crown shape ([Khepresh](https://en.wikipedia.org/wiki/Khepresh))
  for chariot nobles, and the [Sherden](https://en.wikipedia.org/wiki/Sherden) guard's horned
  helmet with a disc ([gallery](https://commons.wikimedia.org/wiki/Category:Sherden)).
- **Body:** a white kilt ([Clothing in ancient Egypt](https://en.wikipedia.org/wiki/Clothing_in_ancient_Egypt)),
  bare chest (age 1), a quilted or scale corselet (age 3); the sickle sword
  ([Khopesh](https://en.wikipedia.org/wiki/Khopesh)), spears, composite bows, chariots.
- **Check against:** the model soldiers from the tomb of [Mesehti](https://en.wikipedia.org/wiki/Mesehti)
  (a whole troop of small painted wooden soldiers with shields and spears: literally Egyptian
  "game pieces"); [Medinet Habu gallery](https://commons.wikimedia.org/wiki/Category:Medinet_Habu)
  (battle reliefs); [Military of ancient Egypt](https://en.wikipedia.org/wiki/Military_of_ancient_Egypt).

### Han Chinese
- **Shield:** small, waisted rectangles or a narrow tall shield; team colour as a painted animal
  face (the [taotie](https://en.wikipedia.org/wiki/Taotie) mask is older, but its idea of a face on
  the shield works).
- **Head:** age 1 the topknot with a headwrap (bare head reads Han at once from the knot); age 2 a
  hood-like cap with a neck curtain; age 3 a lamellar helmet with a plume.
- **Body:** a long wrap-front robe ([Hanfu](https://en.wikipedia.org/wiki/Hanfu)) that flares at
  the hem (the strongest Han silhouette), [lamellar armour](https://en.wikipedia.org/wiki/Lamellar_armour)
  vests, the [dagger-axe](https://en.wikipedia.org/wiki/Dagger-axe) and [ji](https://en.wikipedia.org/wiki/Ji_(polearm)),
  the [crossbow](https://en.wikipedia.org/wiki/Crossbow) (the Han signature).
- **Check against:** [Terracotta Army gallery](https://commons.wikimedia.org/wiki/Category:Terracotta_Army)
  (Qin, just before Han; take the topknots, the armour vests over robes, the kneeling archers);
  the Han pottery figures in [Han dynasty tomb architecture](https://en.wikipedia.org/wiki/Han_dynasty_tomb_architecture).

### Aztec
- **Shield:** the round [chīmalli](https://en.wikipedia.org/wiki/Ch%C4%ABmalli)
  ([gallery](https://commons.wikimedia.org/wiki/Category:Chimalli)) with feather fringe hanging
  below and a bold device (step-fret, bars, a feather mosaic). Team colour on the shield field.
- **Head:** age 1 tied-up hair (a warrior's lock); age 2 a rank cap and the back banner (the tall
  frame on the back is *the* Aztec vertical read); age 3 the [eagle](https://en.wikipedia.org/wiki/Eagle_warrior)
  or [jaguar](https://en.wikipedia.org/wiki/Jaguar_warrior) helmet with the face inside the beak
  or jaws.
- **Body:** quilted cotton armour ([Ichcahuipilli](https://en.wikipedia.org/wiki/Ichcahuipilli)),
  full-body suits for ranked warriors in team-dyed colours; the obsidian-edged club
  ([Macuahuitl](https://en.wikipedia.org/wiki/Macuahuitl)), the [spear-thrower](https://en.wikipedia.org/wiki/Spear-thrower).
- **Check against:** [Codex Mendoza gallery](https://commons.wikimedia.org/wiki/Category:Codex_Mendoza)
  (the warrior-rank pages show each rank's suit and shield as flat, coloured silhouettes: exactly
  an age ladder); [Florentine Codex gallery](https://commons.wikimedia.org/wiki/Category:Florentine_Codex);
  [Aztec warfare](https://en.wikipedia.org/wiki/Aztec_warfare).

## 3. Creature units: what makes them read, and kit that's theirs

The principle: **gear is made from the culture's own materials** (the same material systems as the
buildings in `creature-cultures.md`), and follows the age ladder of `direction.md` in those
materials: soft and natural (age 1), one hard piece (age 2), full prestige material plus a
vertical element (age 3). Human materials (bronze, iron) only enter through a silly ask or a mixed
prompt ("frogs with muskets").

### Frogs
- **What reads:** a wide flat head with **two eye bumps on top** breaking the outline; a wide
  mouth line; a squat body with long folded thighs; webbed feet; skin colour and spots.
- **At 8 px:** the eye bumps are the face. Keep them 1-2 px proud of the head outline in every
  facing (back views too: they're visible from behind). The mouth line is one dark row. No
  pupils needed at 1x; one light pixel per eye at 2x.
- **Gear by age (frog materials):**
  - Age 1: woven reed (a reed cuirass, a reed-bundle spear with a fish-bone point), a lily-pad
    shield **stiffened by reed ribs** (so the pad is a shield, not a sticker), a brow band of
    plaited reed, cattail-fluff padding.
  - Age 2: freshwater-mussel and snail shells (a shell skull cap set *behind* the eyes, shell
    shoulder plates), pike-tooth spearheads, a turtle-shell round shield.
  - Age 3: lacquered turtle-shell plates and scale armour of fish scales (gar scales were really
    used as arrowheads: [Alligator gar](https://en.wikipedia.org/wiki/Alligator_gar),
    [Scale armour](https://en.wikipedia.org/wiki/Scale_armour)), a cattail-head crest as the
    vertical element.
- **Team colour:** the dyed reed bindings and a painted spot pattern on the shield (warning
  colours, from [poison dart frogs](https://en.wikipedia.org/wiki/Poison_dart_frog)).
- **Examples:** the frog clan of a 2D animal-knights game [G20] (take: frog armour that respects
  the head shape); the toads of a pixel animal RTS [G17];
  [The Tale of Mr. Jeremy Fisher](https://en.wikipedia.org/wiki/The_Tale_of_Mr._Jeremy_Fisher) (take:
  a frog in clothes that still reads as a frog because the head and legs stay free).

### Rats
- **What reads:** the long pointed snout, round ears standing up, the tail curve, the hunch.
- **At 8 px:** the snout is the facing indicator (it's why rats already work, per
  `direction.md`); the ears must stay visible (helmets with ear slots, or caps sitting between
  the ears); the tail is the back-view read.
- **Gear by age (junk materials, kept recognisable):**
  - Age 1: rags and sacking, a cork or button shield, a sharpened nail or pin spear, a
    string-tied thimble cap *between* the ears.
  - Age 2: tin (a sardine-tin breastplate, a bottle-cap shield with its crimped edge: the crimp is
    the read), a sewing-needle sword.
  - Age 3: cutlery steel (a spoon-bowl helmet with ear slots, a fork trident, a knife-blade
    sword), patched tin plate, a feather or bristle-brush crest.
- **Team colour:** rag sashes and painted bottle caps (one region: the sash).
- **Examples:** [Mouse Guard](https://www.mouseguard.net/) (cloaks and simple kit on mice that
  read from the cloak colour alone: take the cloak as the team region); the rat kingdom of a
  2D animal-knights game [G20]; a rat-and-mouse RPG [G26]; [The Borrowers](https://en.wikipedia.org/wiki/The_Borrowers)
  (take: a pin is a sword, a thimble is a bucket: objects keep their identity).

### Beetles
- **What reads:** the horn or mandibles, the shield-like pronotum behind the head, the **split
  line between the wing cases**, six legs splayed low.
- **At 8 px:** the horn is the face and the facing indicator; the wing-case split line shows
  direction from above and behind. Our current beetles read well; the red back patch works as
  the team region (`89-unit-textures-frogs-and-beetles.png`).
- **Gear by age (beetle materials):** the beetle body *is* armour, so gear is added on top, never
  as human clothes:
  - Age 1: painted pigment on the wing cases (clan bands), thorn spears lashed to the forelegs, a
    leaf-and-silk saddle cloth for riders.
  - Age 2: bark and husk plates lashed over the pronotum, thorn spikes on the shell edges, a horn
    tip capped with a hard seed husk.
  - Age 3: lacquered or iridescent chitin plates, a horn sheath with a crest, an amber-bead
    harness; riders' howdahs of wing-case shells.
- **Team colour:** the painted band across the wing cases.
- **Examples:** the beetle and ant soldiers of a bug RPG [G16] (take: chitin and leaf gear on
  insect bodies); the insect knights of a bug metroidvania [G15] (take: shells and horns as armour
  shapes); [Nausicaä](https://www.ghibli.jp/works/nausicaa/) (take: armour cut from insect shell);
  [Dynastinae](https://en.wikipedia.org/wiki/Dynastinae) and [Stag beetle gallery](https://commons.wikimedia.org/wiki/Category:Stag_beetles)
  for horn and mandible shapes.

### Spiders
- **What reads:** the fan of eight legs (the silhouette), a big abdomen behind, and the **front
  eye pair**: jumping spiders have two huge forward eyes that make a real face
  ([Jumping spider](https://en.wikipedia.org/wiki/Jumping_spider)).
- **At 8 px:** two light pixels (the front eyes) on the dark head give spiders a face and a
  facing direction; the leg fan must stay clear of gear.
- **Gear by age (silk materials):**
  - Age 1: silk wraps and a silk bandolier, a silk bolas or a hand net as the skirmisher's weapon
    (real hunting methods: [Bolas spider](https://en.wikipedia.org/wiki/Bolas_spider),
    [Deinopis](https://en.wikipedia.org/wiki/Deinopis)), venom-dipped thorn javelins.
  - Age 2: caddis-style plates of leaves and bark stitched with silk on the abdomen.
  - Age 3: captured beetle wing cases and shell plates stitched on as trophy armour, a silk
    plume on a thorn as the crest, dew-pearl ornaments.
- **Team colour:** a dyed silk band round the abdomen.
- **Examples:** the weavers of a bug metroidvania [G15] (take: silk gear and slender spider
  silhouettes); [Peacock spider](https://en.wikipedia.org/wiki/Maratus) (take: natural display
  colours on the abdomen as a team region).

## 4. The scale ladder for units (from `direction.md`, with examples)

Infantry of every creature share one height; large units 1.4-1.8x; giants 2-2.5x. The examples:
the mythology RTS [G37] puts minotaurs, centaurs and hoplites on one ladder; the sci-fi RTS
[G13] makes small biters and big brutes the same race at different sizes. Doors on buildings are
1.1x infantry height (see `buildings.md`).
