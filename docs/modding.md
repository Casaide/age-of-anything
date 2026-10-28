# Making a mod (with an agent)

A mod is a folder of more data plus the models its parts are built from. This page is the
walkthrough; the format, the rules and the plan are in `docs/milestones/m21-modability.md`. The example
to copy from is `mods/scifi_test/` (an armoured future soldier). Paths are from the project root;
`lobster` is `~/Dev/lobster/bin/lobster`.

## 1. Scaffold

```sh
python3 tools/mods/new_mod.py <id> ["Name"] [--era <tag>] [--private]
```

- `<id>`: lower case, digits, underscores (`steam_rats`).
- `--era <tag>`: the mod brings an era (scifi, steam...): its parts only appear where the host's rules
  allow that era and the prompt asks for it. The scaffold opens it under Anything goes.
- `--private`: the folder goes in `mods_private/` (gitignored, never exported, never packed). Use it
  for anything based on someone else's franchise: those stay private and unofficial.

You get `mod.json`, `data/parts.json` (one example helmet), `data/lexicon.json` (one word),
`data/rules/anything.json` (with an era), `models/<id>_parts.lobster` (the helmet's model),
`sheets/<id>.json`, `README.md`. It passes the checks as it is: check it now (step 4) so you start green.

## 2. Write the parts (data)

In `data/parts.json`, one entry per part. Copy a game part of the same slot from `data/parts.json` and
change it. What matters:

- `id`: `<kind>.<name>` (`weapon.pulse_rifle`, `helm.visor_sealed`, `armour.plate_composite`,
  `shield.arc_buckler`, `pack.power`). Never a game part's id unless the manifest lists it in `replaces`.
- `slot`: `hand_r` (the weapon: decides the line), `hand_l` (shield, satchel), `head_gear`, `torso`
  (worn armour), `back`. (Bodies, heads and legs are possible but need sockets: copy a game body.)
- `tags`: what the generator matches. The weapon's tags pick its line: `spear` (spear line), `ranged`
  without `bow` (skirmishers), `bow` (archers), `melee` + `blade` (swordsmen); `gun` holds it aimed like
  a musket; `heavy`, `armour`, `helmet`, `shield` are kinds an upgrade keeps.
- `only_if`: `[tag]` so it only appears when the prompt asks (your word gives that tag).
- `era`: `[your era]` if the mod has one; `upgrade_within`: your tag, so an upgrade only swaps it for
  more of your kit (no bronze helmet over your visor).
- `stats` and `points`: points set the price through the game's cost curve. Compare with a game part
  doing the same job (a musket: attack 9, range 7, 8 points). Don't make it free; don't special-case.
- `tier`: 1-3, the age it can first appear. Add a tier-3 version to give the line an age-3 step.
- `face`: on head gear, `"covered"` for a face guard with eye openings, `"sealed"` for a closed helmet.
- `shapes`: a rough 2D outline (the data contract's reference): copy one from a similar game part.

## 3. Build the models

Each part needs a model: a builder in your model script, or a `.glb`.

**Code (most parts):** in `models/<id>_parts.lobster` (listed in `mod.json` as `"models"`), a function per part
returning `spec_of(n)`, and `build_mod_<id>(base, c) -> Spec?` choosing by part id (nil for the rest). The game joins
the file in when the mod is on (`src/mods_gen.lobster`, run by `play.sh`, `sheet.sh` and `mod_check.sh`). Use the game's
model kit (`src/model/base.lobster`): `blob` (ellipsoid), `rod` (capsule between two points), `slab` (extruded
outline), `dome`, `ring`, `cone`, `box`; materials `surf(texture, tint, units)` (game textures: iron, bronze,
leather, wood_grain, cloth...; your own: `surf("textures/<id>/plate", ...)` from `textures/plate.svg`, made a PNG by
`src/textures.sh`), `plain(colour)`, `glow(colour)` (lit, for lights and energy). `col(c, "team")` is the team colour
(put some on every unit: a stripe, a band), `col(c, "cloth")`/`col(c, "cloth2")` the culture's cloth.

Frames (part units, about one art pixel): x the way the unit faces, y up, z towards the viewer.
- Head gear: round the head's top socket, the crown at y 0, the head about 5 across, the face at +x,
  the eyes about 4-6 below the crown. Copy `helm_bronze` (`src/model/`) or the example's `helm_visor_sealed`.
- Held weapons: built round the grip at the origin. Melee along the sword's line (3, 14, 0); guns along
  the musket's line (14, 3.6, 0). Copy `weapon_pulse_rifle` or `weapon_arc_blade`.
- Worn armour: frog-sized, round (1.5, 0.5, 0) about 9 x 8 x 10; the body scales it. Copy
  `armour_plate_composite`.
- Back gear: from the back's surface outwards (-x). Copy `pack_power`.

Play it: `./play.sh lobby mods:<id> rules:anything`.

**Blender (`.glb`):** a script in `tools/` (copy `mods/scifi_test/tools/buckler.py`), run
`blender -b --python mods/<id>/tools/<part>.py -- mods/<id>/models/<part>.glb`, then give the part
`"glb": "models/<part>.glb"` instead of a builder. Model in part units facing +X, up +Z; name the
materials `team`, `skin`, `cloth`, `cloth2`, a game texture (`iron`...), or `glow_<hex>`.

## 4. Words, rules, check

- `data/lexicon.json`: words that give your tag (`"tags": {"scifi": 5}`); with an era, the word also
  carries `era`, a `substitute` and a playful `note` for hosts that keep the era out. A word can set
  `creature`, `default_creature`, `family`.
- `data/rules/<rule>.json`: `{"+era": ["<your era>"]}` opens your era under that host rule.
- Cultures and creatures: `data/families.json` / `creatures.json`; `"extends": "imperial"` copies a
  game one and changes only what you name.
- `mod.json` `check.prompts`: the prompts that show your parts (they drive the checks).

Then:

```sh
src/mod_check.sh <id>        # loads it (or says why not), the check prompts' races and who wears the mod's parts, the 3D placement check
cd src && lobster races.lobster -- mods:<id> anything "<prompt>"   # the whole race as JSON: who gets what, costs
```

A refusal says exactly what to fix ("parts.json helm.x: no model: add a case for it to a model file...").
A placement FAIL names the rule and the measurement (`docs/rendering.md`, "Placement rules"): a helmet
too low over the eyes, armour cutting through, a weapon away from the hand. Fix the model, run again.

## 5. Look at it

```sh
src/sheet.sh mods/<id>/sheets/<id>.json /tmp/<id>
```

Edit the sheet spec to show your units (rows by prompt, slot and age; `size` for a game unit beside
them; columns `facings`, `walk:1,3`, `shots` for firing). It runs both placement halves on every row.
Look at every picture close up (3x) and at game size (1x) before showing anyone. In a match:
`./play.sh lobby mods:<id> rules:anything "races:<prompt>|romans" watch mute shot:/tmp/m.png at:600`.
A private mod's pictures stay in its own folder (`mods_private/<id>/renders/`), never in `archive/`.

## 6. Pack

```sh
python3 tools/mods/pack.py <id>      # build/mods/<id>-<version>.zip (refuses private mods)
```

To install: unzip into the game's `mods/` folder and play with it (`mods:<id>`). Bump `version` when you change it: a shared race names
the mods (and their data) it was made with.

## Mod checklist

- [ ] Original work, or `--private` (never committed, packed or shared)
- [ ] Every part: id, slot, tags, `only_if`, points priced against a game part, tier, shapes; era and
      `upgrade_within` if the mod has an era
- [ ] Every part has a model; some team colour on every unit
- [ ] Words for the prompts (era words with a note and a substitute); rules open the era
- [ ] `mod.json`: version, game_version, depends, eras, models, check prompts
- [ ] `src/mod_check.sh <id>`: loaded, 0 failed
- [ ] The sheet: every row PASS; looked at close up and at game size; firing if it shoots
- [ ] A race without the mod's words gets none of it (`races.lobster -- mods:<id> anything` on a plain prompt)
- [ ] `tools/mods/pack.py <id>` (public mods only)
