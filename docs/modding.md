# Making a mod (with an agent)

A mod is a folder of more data: parts, words, creatures, cultures, rules, and their voxel looks. This page is the
walkthrough; the format, the rules and the plan are in `docs/milestones/m21-modability.md`. The example
to copy from is `mods/scifi_test/` (an armoured future soldier). Paths are from the project root;
`lobster` is `~/Dev/lobster/bin/lobster`.

## 1. Scaffold

```sh
tools/mods/new_mod.sh <id> ["Name"] [--era <tag>] [--private]
```

- `<id>`: lower case, digits, underscores (`steam_rats`).
- `--era <tag>`: the mod brings an era (scifi, steam...): its parts only appear where the host's rules
  allow that era and the prompt asks for it. The scaffold opens it under Anything goes.
- `--private`: the folder goes in `mods_private/` (gitignored, never exported, never packed). Use it
  for anything based on someone else's franchise: those stay private and unofficial.

You get `mod.json`, `data/parts.json` (one example helmet), `data/lexicon.json` (one word),
`data/rules/anything.json` (with an era), `data/voxel/gear.json` (the helmet's voxel look and the rule that gives it
the part), `README.md`. It passes the checks as it is: check it now (step 4) so you start green.

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
  `points` is also what the generator spends from a race's budget; the price can differ: `price_points`
  (the game's are calibrated by fights, D-195). `mod_check.sh` ends by fighting the lines that wear your
  parts against a fixed panel and prints the `price_points` each part should have; set them.
- `tier`: 1-3, the age it can first appear. Add a tier-3 version to give the line an age-3 step.
- `face`: on head gear, `"covered"` for a face guard with eye openings, `"sealed"` for a closed helmet.
- `shapes`: a rough 2D outline (the data contract's reference): copy one from a similar game part.
- A part needs no model: its look is voxel gear (step 3).

## 3. Give the parts their looks (voxel data)

A unit is a voxel body (`docs/rendering.md`, "Voxel units"); a part shows as the gear `data/voxel/gear.json`'s
`parts` rules give it (by its id, a prefix, a tag or its slot; the first match wins). A part with no rule of its own
takes the game's rule for its tags (a `helmet` a cap, a `bow` a bow...). For a look of its own, the mod brings its
own `data/voxel/` (the same files as the game's; same ids replace the game's, its rules go first):

- `gear.json` `gear`: held gear (`hand`, `hold`, `dir`, `shapes` in the hold's frame) or worn gear (`fits` per body id,
  `*` for any other: `helm` on the body's helmet spot, `fit` over its armour spot, or shapes on its points), and
  `parts`: `{"part": "<your part id>", "gear": "<your gear>"}`.
- `bodies/<id>.json`: a body for a new creature (points, legs, arms, shapes; copy a game body of the same build).
- `materials.json`: new colours (and `team`: put some team colour on every unit: a stripe, a crest, a band).

Draw it: `cd src && lobster voxel_proto.lobster -- /tmp/s.ppm legs <body> <gear>,<gear>` (standing, walking and
attacking in 8 facings), and play it: `./play.sh lobby mods:<id> rules:anything`. How to make a look read well at
game size: the voxel-art skill (`.claude/skills/voxel-art/`).

## 4. Words, rules, check

- `data/lexicon.json`: words that give your tag (`"tags": {"scifi": 5}`); with an era, the word also
  carries `era`, a `substitute` and a playful `note` for hosts that keep the era out. A word can set
  `creature`, `default_creature`, `family`.
- `data/rules/<rule>.json`: `{"+era": ["<your era>"]}` opens your era under that host rule.
- Cultures and creatures: `data/families.json` / `creatures.json`; `"extends": "imperial"` copies a
  game one and changes only what you name.
- `mod.json` `check.prompts`: the prompts that show your parts (they drive the checks).

- Buildings: `data/buildings.json` in your mod changes them (below). The sim and the
  bots never look a building up by its id, only by what it does, so a building can be called anything. A building
  says what it does by `roles`, a list of:

  | Role | What it means |
  |---|---|
  | `hub` | The town's heart: a player who started with one is out when none is left; herded animals come home to it; the bots' home and first target |
  | `housing` | What the bots build for room before they run out |
  | `trade` | A market: buying, selling, trade carts between two |
  | `barracks` | The bots' first army building, put up before the first age |
  | `tower` | The tower the bots put up where they were raided (and count, with what research turns it into) |
  | `defence` | A strong point guarding a crossing (the bots won't lay a second tower by one) |
  | `wonder` | Stood long enough, it wins; the bots build one when rich and go for the enemy's |

  A building can play several (`"roles": ["tower", "defence"]`) or none. Where several share a role, the bots
  build the first by id. A farm, a pen and a drop-off need no role: `becomes`, `pen` and `drop_off` say it (a drop-off
  that isn't the hub is a camp). An unknown role stops the game at the start. What the bots build in order, raid and
  research is named by id in `data/ai.json`.

Then:

```sh
src/mod_check.sh <id>        # loads it (or says why not), the check prompts' races and who wears the mod's parts, its prices
cd src && lobster races.lobster -- mods:<id> anything "<prompt>"   # the whole race as JSON: who gets what, costs
```

A refusal says exactly what to fix ("parts.json helm.x: needs 'tags' (a list)").

## 4b. Change the game itself: buildings, tech, the AI, sound

A mod can bring `data/buildings.json`, `tech.json`, `ai.json` and `audio.json`. They merge over the game's for every
player in a match using the mod: the same id changes that entry (objects merge), `"remove": true` takes it out,
`"extends": "<id>"` copies a sibling, `"+key"` adds to a list and `"-key"` takes items out. A list with ids (`research`, or
`ages` by their `age`) merges item by item; any other list, such as `build_order`, is replaced whole. In a rule, `"-roster":
["large"]` takes lines out by slot.

Taking a building out takes its research with it, an age stops asking for it, and the bots skip what
asked for it. The rest is refused at load with the reason: no `hub` or `housing` building left, `trains` naming a line no
roster has, a new building without `extends` (it uses that one's model; new models come later), ages that don't run 1, 2, 3 at
real buildings, research at a building that isn't there, a sound without `takes`.

Sounds: `<mod>/audio/sfx/<name>_<take>.wav` (also `voice/`, `music/`), used before the game's file of that name. A new sound
goes in `audio.json`; a shot look names its own with `"sound"` in `shots.json`. A shot look is knobs that mix freely (`arc`, `form`, `pulses`, `scatter`, `wobble`, `jag`, `fade`, `hit` and more; `data/shots.json` says what each
does, and `"extends": "arrow"` starts from one of the game's). They only change what's drawn: the sim fires one shot and decides one hit. `audio.json` and WAVs stay out of the mod's
signature, so a sound never changes a race key.

A mod match is local for now: the network doesn't compare mods yet (#132), and players with different
mods would fall out of step. `mods/scifi_short` is the example: infantry only, two ages:
`./play.sh lobby mods:scifi_test,scifi_short rules:short`. `src/test_mod_match.lobster` plays it to the end.

## 5. Look at it

Look at every picture close up (3x) and at game size (1x) before showing anyone: the sheets
(`voxel_proto.lobster`, step 3), and in a match:
`./play.sh lobby mods:<id> rules:anything "races:<prompt>|romans" mute army:1 look:17,17 shot:/tmp/m.png at:20`.
A mod with its own voxel bodies should pass `lobster voxel_check.lobster` and `lobster voxel_proto.lobster -- - check`
with the mod on. A private mod's pictures stay in its own folder (`mods_private/<id>/renders/`), never in `archive/`.

## 6. Pack

```sh
tools/mods/pack.sh <id>      # build/mods/<id>-<version>.zip (refuses private mods)
```

To install: unzip into the game's `mods/` folder and play with it (`mods:<id>`). Bump `version` when you change it: a shared race names
the mods (and their data) it was made with.

## Mod checklist

- [ ] Original work, or `--private` (never committed, packed or shared)
- [ ] Every part: id, slot, tags, `only_if`, points priced against a game part, tier, shapes; era and
      `upgrade_within` if the mod has an era
- [ ] Every part has a look (a voxel gear rule, its own or the game's); some team colour on every unit
- [ ] Words for the prompts (era words with a note and a substitute); rules open the era
- [ ] `mod.json`: version, game_version, depends, eras, check prompts
- [ ] `src/mod_check.sh <id>`: loaded
- [ ] Looked at close up and at game size; firing if it shoots
- [ ] A race without the mod's words gets none of it (`races.lobster -- mods:<id> anything` on a plain prompt)
- [ ] `tools/mods/pack.sh <id>` (public mods only)
