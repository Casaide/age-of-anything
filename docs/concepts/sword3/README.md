# S3: the swordsman's age-3 kit (2026-10-13): picked (D-125) and built

Dominic: "Swords looking great, need age 3." The swordsman line (Barracks, slot `infantry`) has an
age-3 weapon only for royal races and knight prompts (`weapon.sword.iron`, tagged `knight`/`royal`).
The swamp, forest, hellenic, steppe and spooky swordsmen are the same unit in ages 2 and 3 (bronze
sword, bronze armour, their age-2 helmet: "nothing to upgrade"), and the han swordsman only gets
its lamellar helmet. Imperial (lorica), nile (bronze helmet), aztec (eagle helmet) and sewer
(sardine plate) already step up through armour or a helmet, so they're left out of this round.

Two options per culture: a weapon in the culture's own look, and for hellenic and steppe a
helmet with option B (the line already upgrades helmets: a tier-3 helmet sharing tags replaces the
age-2 one). Every option is longer, brighter or heavier than the age-2 bronze sword (14.4 long, 1.5
wide, dull bronze): blades are polished steel, bone or shell, 16.5 to 18.8 long.

Built in the real pipeline: 3D parts in `scenes/art_pixel/sword3_concepts.gd` (the `unit_models.gd`
idiom, extending it), baked by `PartBaker` in the 8 facings and held in the swordsman's `low` hold
like every sword, composed by `UnitView` on the culture's age-2 (han: age-3) swordsman. Nothing is in
play: `tests/sword3_concept_sheet.gd` puts the ids into the loaded data only, after generating, so
no race changes. Each row shows the 8 facings plus a wind-up and a blow (the attack lunge).

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/sword3_concept_sheet.gd -- out_dir 4.5   # 3x, one sheet per culture
godot --audio-driver Dummy --always-on-top --path . --script res://tests/sword3_concept_sheet.gd -- out_dir 1.5   # game scale, all cultures
```

Pictures: `archive/images/2026-10-13/330-sword3-all-game-scale.png` (every culture, game scale),
`331-` hellenic, `332-` steppe, `333-` han, `334-` swamp, `335-` forest, `336-` spooky (3x).

## The options

| Culture | A | B |
|---|---|---|
| Hellenic (greeks) | **iron kopis**: a heavy forward-curved chopper widening to a belly near the tip, bronze fittings | **long leaf-bladed xiphos + Attic helmet**: polished bronze, open face, brow peak, a tall team crest on a stand |
| Steppe (mongols) | **long sabre**: slim, curving back, a disc guard and a team tassel | **flared heavy sabre + spiked helmet**: a broad blade flaring before the point, brass cross-guard; an iron cone helmet with a bronze spike, team tuft and mail neck guard |
| Han | **jian**: long straight double-edged blade with a ridge, bronze guard, team tassel | **dao**: broad single-edged sabre widest near the tip, disc guard, ring pommel with a crimson cloth |
| Swamp (frogs) | **reed saw**: a flattened pale reed blade with black obsidian teeth and a knapped obsidian point, cord-bound | **river-stone mace**: a pale driftwood haft and a big grey river stone lashed on |
| Forest (beetles) | **chitin-edged blade**: a dark heartwood blade edged with bright green-blue shell shards, a shell guard | **thorn sword**: a red-brown bramble stem with big pale thorns and a thorn point, a leaf at the hand |
| Spooky (spiders) | **bone scythe-sword**: a long pale blade sweeping back, a vertebra grip | **hooked sickle blade**: polished steel, straight then a big forward hook, a white silk-wound grip |

## What the sheets show

- **Every option reads as a step up at game scale** in the facings where the weapon hand is on the
  near side (facings 2-3 and 6-7): the steel and bone blades are the brightest thing on the unit,
  where the age-2 bronze sword is as dark as the armour. In the blow column the bright blades flash.
- **Strongest at 1x:** han dao (broad and white), steppe B (the helmet changes the head's colour and
  shape, so the unit reads different even with the sword hidden), hellenic B (the high blue crest),
  swamp B (the stone club head is a new silhouette), spooky B (the hook is a shape nothing else has),
  forest A (the only teal on the field).
- **Weaker:** slim blades seen edge-on (steppe A, han A) go to a line of a pixel or two in some
  facings; the bone scythe's curve doesn't read at 1x (it reads as a pale straight sword); the reed
  saw's teeth are lost at 1x (it reads as a long pale stick); the thorn sword is a thin red-brown line
  on a dark beetle.
- **Polished steel had to be pushed:** the iron texture at its usual tint bakes a dark grey at game
  scale, as dark as bronze. The concepts use a pale tint and a little sheen (`_bright_iron`). An
  over-bright iron helmet baked as a white blob, so the steppe helmet stays at a normal tint.
- **Layering:** checked by eye (`tests/layer_check.gd` isn't on main yet). Weapons sit in the hand
  like the age-2 sword in every facing: behind the shield and body on the far side, over them on the
  near side, the tassels and ring pommel behind the hand. The frog's weapon still hides behind its
  body in the front facings, as the age-2 sword does (a body/hold question, not these parts).

## Recommendation (Claude)

- **Hellenic: B** (xiphos + Attic helmet). The high crest changes the silhouette from every side;
  the kopis alone only shows in four facings.
- **Steppe: B** (flared sabre + spiked helmet), for the same reason; the slim sabre (A) is too thin.
- **Han: B** (dao). The broad white blade reads in every side facing; the jian is elegant but slim.
  Han already gets its lamellar helmet in age 3, so the weapon alone is enough.
- **Swamp: B** (river-stone mace): a new silhouette and in the frogs' river-and-stone kit (the turtle
  ram, the snail). The reed saw could come back thicker as a raider or unique weapon. Note: a mace is
  `blunt`, and the age-3 upgrade keeps the weapon's kind (`blade` for the sword); in data it would
  carry `blade` too or the upgrade's kinds would need the club's (a data question for the build).
- **Forest: A** (chitin-edged blade): the teal shell is the most readable of all twelve at 1x and
  says "beetle". The thorn sword would need to be much bulkier to read.
- **Spooky: B** (hooked sickle blade): the hook is unmistakable; the bone scythe needs a deeper curve
  to read, and pale bone is already the spooky healer's staff.

Also worth a decision: a **generic age-3 blade** for any future culture without one (the iron
sword minus its `knight`/`royal` tags, or a plain steel longsword), so no culture is ever stuck at
"nothing to upgrade".

To build a pick: the part entries in `data/parts.json` (tier 3, `blade`, the family's tag with
`only_if`/`favour` like the healer staffs, `price_points` like the iron sword's 8), the model moved
into `unit_models.gd`, then the round robin at age 3.

## Built (2026-10-13)

Dominic picked hellenic B, steppe B, han B, swamp B, forest A, spooky B and a plain iron sword as the
fallback (D-125). They are in play: parts in `data/parts.json`, models in `scenes/art_pixel/unit_models.gd`
(the options not picked stay in `sword3_concepts.gd`). The mace keeps `blunt` and follows the sword through
a new `replaces` field; the helmets were lifted clear of a human's brows for the placement check. Results
and pictures (`359-` to `361-`) are in `docs/milestones/m13-unit-lines.md`.
