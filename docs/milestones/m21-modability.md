# Milestone 21: Modability

**Status:** in progress (proposed and started 2026-10-13: the loader MVP, an example mod, the agent
tooling; the rest planned below)
**Exit criterion:** someone (or an agent) who has never seen the code makes a new mod from
`docs/modding.md` alone (new parts, their models, words, a rules change), checks it with the tools,
packs it, and a second machine installs the zip into its mods folder and plays a match with a race that
uses it: same race key on both machines, the bake looking the same, the placement checks passing on the
mod's units; a broken mod refused with a message that says what to fix; the game without mods
unchanged (same race keys, same tests); Dominic makes one himself with an agent and says it was easy.

Dominic (2026-10-13): "Can we MVP a little sci-fi style: an armoured soldier with a futuristic weapon,
and also a [TV franchise] soldier with a [its] rifle. I want to see how it'll look. This won't be
released, but should be the start of testing how mods can expand on the art, so we can easily use our
tooling with an agent to generate more and release as a mod on Steam etc. Basically add a milestone
for testing modability."

## Principles

- **A mod is more data, not code hooks.** "Mods are just more of this" (`data/`). A mod adds or
  changes what the data contract already says: parts, creatures, cultures, palettes, words, host
  rules, maps, shot looks. If a mod needs code for a content case, the data contract is missing a
  field: add the field to the game (this milestone added `upgrade_within`, `face: sealed`, families
  and creatures that `extends`, shot looks in data).
- **The one piece of code a mod carries builds 3D models** for the bake: a model script extending
  `unit_models.gd` (its helpers: blob, rod, slab, dome...), or `.glb` files made in Blender. It runs at
  bake time only, never in the sim.
- **Determinism first.** Mods merge in a fixed order; a race made with mods carries the mod set in
  its key, so a peer without the same mods can't silently play a different race.
- **Checked like our own art.** The placement checks and the data asserts run on mod content; a mod
  that fails is refused with the reason.
- **Original official content; franchise mods stay the players' own** (see the IP stance below).

## Scope

In: the mod format, discovery and loading, merging with stable order, the race key and bake cache
with mods, validation and refusal, era packs as a mod (the `scifi` era), shot looks from data, the
agent tooling (scaffold, check, sheet, pack, docs), the example mod, a private fan test kept out of
the repo, the packaging stance for Steam Workshop.

Out (later, in the backlog): an in-game mod browser and enable/disable screen, Workshop upload,
mod-made buildings and architectures, mod sounds, mod tech and AI data, an in-game part editor
(backlog §7), sandboxing model scripts for untrusted mods.

## The mod format

A folder named for the mod's id:

```
<id>/
  mod.json            manifest
  data/               overlays on the game's data/ (only what the mod changes)
    parts.json          [parts]: new ids, or a game part listed in the manifest's "replaces"
    creatures.json      {id: creature} (a creature may "extends" another and change only what it names)
    families.json       {id: culture} (same "extends")
    palettes.json       deep-merged over data/palettes.json (e.g. {"skins": {...}})
    lexicon.json        {"words": {...}, "stopwords": [...]}
    rules/<id>.json     a change to a host rule (deep merge; "+key": [..] appends to a list), or a new
                        rule ("extends": "<rule>", or a whole rule)
    maps/<id>.json      a new map, or one replacing the game's
    shots.json          shot looks: {kind: {tag, speed, arc, len, w, col, glow?, sticks?, sound?}}
  models/             model scripts (.gd extending res://scenes/art_pixel/unit_models.gd) and .glb files
  textures/           SVG textures (a model script's mod_tex("name"))
  sheets/<id>.json    the sheet spec that shows it (tests/sheet.gd; "mods": [<id>])
  tools/              how its .glb files are made (Blender scripts), optional
  README.md
```

The manifest:

```json
{"id": "scifi_test", "name": "Future soldiers (test)", "version": "0.1.0", "game_version": "0.21",
 "authors": [], "description": "", "license": "", "load_order": 100, "depends": [],
 "eras": ["scifi"], "data": "data", "models": ["models/scifi_parts.gd"], "replaces": [],
 "check": {"rules": "anything", "prompts": ["future soldiers"]}, "private": false}
```

- `game_version`: the game version it was made for; refused if the major differs or it's newer than
  the game (`Mods.GAME_VERSION`, "0.21" now; a real version number arrives with the first release).
- `depends`: mods that must be in use and load earlier. `load_order` (then id) orders the merge.
- `eras`: era tags the mod introduces (its parts may only use the game's eras or these).
- `check`: what the placement check generates for this mod (prompts under a rule).
- `private`: never packed (`tools/mods/pack.py` refuses it).

A part may be a `.glb` instead of a builder: `"glb": "models/x.glb"`, its materials named for what the
game puts there (`team`, `skin`, `cloth`, `cloth2`, a game texture's name such as `iron`, or
`glow_<hex>`).

What's not moddable yet (a mod with these files is refused with that message): buildings,
architectures, tech, AI, audio, UI, terrain, the creature kit. Each needs its merge rule and checks.

## Discovery, loading, load order

- Folders, in order (a later folder's copy of a mod wins): `user://mods` (installed), `res://mods`
  (dev, in the repo: the example), `res://mods_private` (dev, gitignored).
- Nothing is used unless asked for: `AOW_MODS=a,b` in the environment, `--mods=a,b` on the command
  line, or `user://mods.json` `{"enabled": [...]}` (the lobby's mod screen will write this, later).
  Tests and sheets call `Mods.use([...])` (a sheet spec's `"mods"`).
- `src/mods.gd` checks each asked-for mod against the base data plus the mods before it (load
  order), registers its model scripts with the bake (`UnitModels.extra`) and its `.glb` parts, and
  every `DataLib` made after that has the mods merged over the game's data. Host rules come through
  `DataLib.load_rules(id)` (the mods' changes to it), maps through `Mods.data_path("maps/<id>.json")`.

## Determinism and the race key

- Merging is in a fixed order (load order, then id; parts by id; candidates sorted as before), so
  every machine with the same mods builds the same data.
- A race made with mods in use carries `mods: ["id@version#hash", ...]` (the hash of the mod's
  parsed data, so an edited mod without a version bump still differs), and the race key includes it.
  A race made without mods has no `mods` field and keeps exactly the key it always had (tested).
- `Mods.missing(race)` lists what a shared race needs that isn't in use: the lobby (later) refuses
  to start, or offers to fetch them.
- Models and textures don't change the sim, so they aren't in the race key; they are in the bake
  cache's version (`BakeCache.folder()` hashes every file of every mod in use), so a changed model
  bakes fresh.
- Later refinement: put only the mods a race actually uses in its key (today it's every mod in use,
  since any of them can change generation: a new creature can volunteer).

## Validation

At load (`Mods._check_manifest`, `_check_data`), a mod is refused with its reason when: the manifest
lacks id/name/version/game_version or its id isn't the folder's; the game version doesn't fit; a
dependency isn't loaded before it; a data file isn't moddable or isn't valid JSON; a part has no id, an
unknown slot, no whole points, no tags, an era that's neither the game's nor the manifest's, a tier
outside 1-3, a body or head without sockets, no model (builder or `.glb`), or an id clashing with a
game part not listed in `replaces`; a creature names parts or cultures that don't exist (or extends a
missing one); a word names an unknown creature, culture or era, or an era word has no note; a rules
file neither changes a game rule nor extends one nor is whole, or names an unknown era; a shot look
lacks tag, speed or colour. The good mods beside a refused one still load. Refusals print and are
kept in `Mods.refused` (for the lobby to show). `tests/mods/` holds one fixture per refusal;
`run_tests.gd` checks each is refused.

The art checks: `tests/mod_check.gd -- <id>` loads the mod and runs the 3D placement check on every
unit of its `check` prompts that wears or holds one of its parts; `AOW_MODS=<id>
placement_check.gd -- "mod <id>"` runs both halves; the mod's sheet runs both on what it shows.

## Era packs as mods

The era is still a tag on parts (`era`) and words (`era`), and the host rules' `era` list bounds it.
A mod brings its own era tag (manifest `eras`), parts in that era with `only_if` (they only come
when the prompt asks), words that ask for it (with a note and a substitute for hosts that keep it
out), and a rules change that opens it (`"+era": ["scifi"]` on Anything goes). New data field
`upgrade_within` (a part gives way on upgrade only to parts with that tag), so a sealed visor
doesn't turn into a bronze helmet at age 2. This is a first step towards backlog §8 "Eras and themes
as a layer" (an era per race, every role re-kitted, buildings by era), which stays later.

## Tooling for an agent

- `python3 tools/mods/new_mod.py <id> ["Name"] [--private] [--era <tag>]`: the folder, a manifest, an
  example part that passes the checks, its model, a word, a rules change for the era, a sheet spec.
- The model helpers in `unit_models.gd`, the creature kit (`scenes/art_pixel/creature_kit.gd`, for
  creatures: moddable later), Blender scripts for `.glb` parts.
- `tests/mod_check.gd`, `tests/sheet.gd`, `tests/print_races.gd` (`AOW_MODS`, `AOW_RULES`).
- `python3 tools/mods/pack.py <id>`: `build/mods/<id>-<version>.zip`.
- `docs/modding.md`: the walkthrough and a mod checklist.

## Distribution

- Now: a zip of the folder, unzipped into `user://mods` (on macOS `~/Library/Application
  Support/Godot/app_userdata/<project>/mods`; the exported game's own user folder later).
- Steam Workshop (later): needs the Steamworks SDK through a Godot extension (GodotSteam), an app
  id, Workshop enabled on the store page, an upload path (a tool or in-game "publish" that sends the
  folder, a preview image (the sheet), title, description, tags and visibility), subscription
  handling (Steam downloads subscribed items into its own folder: add it to `Mods.ROOTS`), the Steam
  legal agreement and Workshop terms, moderation (reporting, takedowns), and a content policy page.
- Exports never include `mods/` or `mods_private/` (`export_presets.cfg` exclude filter).

## IP stance for shared content

- **Official content stays original.** Everything the game ships, and everything in this repo
  (code, data, docs, the archive, commit messages), is ours: no third-party franchises, names,
  insignia, uniforms, props or likenesses (CLAUDE.md, Originality). The example mod is original art.
- **Franchise mods are the players' own**: private and unofficial. We don't make, host, feature or
  promote them; the packer refuses mods marked private; our own fan tests live in `mods_private/`
  (gitignored, never exported, never in `archive/`), with generic names in their files.
- **When Workshop opens**: a content policy (no infringing uploads; rights holders' takedown path),
  the Steam Workshop terms doing the legal work for uploads, reporting in the mod browser. Backlog §7's
  "moderation and IP policy" is answered by this stance, to be written as a player-facing page before
  any public mod sharing.
- **Model scripts are code.** A mod from a stranger running GDScript is a security risk; before mods
  are shared publicly, either sandbox model scripts (a declarative model format in JSON built from the
  same primitives, which agents can write as easily) or only allow `.glb` models in shared mods.

## Plan

1. **Loader MVP** (done 2026-10-13): `src/mods.gd`; DataLib merges; rules and maps through mods;
   models and `.glb` parts registered with the bake; bake cache and race key include the mods;
   validation and refusal; shot looks from data.
2. **Example mod** (done): `mods/scifi_test/`: an armoured future soldier (sealed visor helmet,
   plated armour, power pack, pulse rifle and its age-3 heavy version, arc blade, a Blender-modelled
   arc buckler as the `.glb` test), a `pulse` shot, words, the scifi era opened under Anything goes
   and the default rules; priced by the normal cost curve; passing the placement checks.
3. **Private fan test** (done): in `mods_private/` (gitignored), for Dominic only.
4. **Agent tooling** (done): scaffold, `mod_check.gd`, packer, `docs/modding.md`, tested by
   scaffolding a trial mod (with an era) and checking, sheeting and packing it.
5. **Next:** the lobby's mod list (what's found, enabled, refused and why; writes
   `user://mods.json`), the lobby refusing a shared race whose mods are missing; maps from mods in
   the lobby's map list.
6. **Next:** more of the data moddable: buildings and architectures (the biggest art cost), tech,
   audio (a mod's own sounds), creature-kit creatures (kits in a mod's data).
7. **Next:** a declarative model format (JSON primitives) so shared mods carry no code; or `.glb` only.
8. **Next:** a full sci-fi pack as the proof: every role re-kitted (a field medic, a worker's tool,
   a vehicle for the large line), armour that dresses arms and legs (today a mod's armour only
   covers the torso: the soldier's arms and legs are the body's own), buildings for the era.
9. **Later:** Steam Workshop (above); the exit criterion's second-machine test.

## Checklist

- [x] Mod format and manifest (this file, `docs/modding.md`)
- [x] Discovery (user://mods, res://mods, res://mods_private) and activation (AOW_MODS, --mods=, user://mods.json, Mods.use)
- [x] Merge in load order over parts, creatures, families, palettes, lexicon, rules, maps, shot looks
- [x] Model scripts and `.glb` parts registered with the bake; mod textures
- [x] Bake cache version includes the mods' files; race key includes the mod set (no change without mods)
- [x] Validation and refusal with reasons; refusal fixtures in `tests/mods/`; `_test_mods` in run_tests
- [x] Era pack switch: a mod's era tag, rules `+era`, words with notes, `only_if`, `upgrade_within`
- [x] Example mod `mods/scifi_test/`, sheet beside a spearman and a legionary, 8 facings, walk, firing, in a match
- [x] Private fan test in `mods_private/` (gitignored, export-excluded), sheet rendered there only
- [x] Agent tooling: `tools/mods/new_mod.py`, `tests/mod_check.gd`, `tools/mods/pack.py`, `docs/modding.md`
- [x] Exports exclude `mods/` and `mods_private/`
- [ ] Dominic's look at the example mod and the private test
- [ ] Lobby: mod list, enable/disable, refusals shown, missing mods for a shared race
- [ ] Buildings, tech, audio, creature-kit creatures moddable
- [ ] Model scripts sandboxed (declarative models) or `.glb`-only for shared mods
- [ ] Installed from a zip on a second machine, same race key, a match played
- [ ] Steam Workshop
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

2026-10-13 (Claude):
- `mods/scifi_test` loads in load order; "future soldiers" under Anything goes (or the default rules
  with the mod on) gives Pulse Troopers (age 2: 55F 85W 65G, attack 9, range 7, armour 4/5), Heavy
  Pulse Troopers at age 3, Blade Troopers with the arc buckler; spears, archers and riders wear the
  visor and plate with their own weapons. "romans" gets nothing from the mod; under the bronze rules
  "future soldiers" gets the note and polished helmets.
- Placement: the sheet's 7 rows pass both halves; `mod_check.gd -- scifi_test` 42 units, 0 failed;
  `run_tests.gd` 0 failed (the mod test included), and the batch with and without the mod (see the
  commit).
- Pictures: `archive/images/2026-10-13/530` (8 facings beside a Roman spearman and legionary), `531`
  (firing, the pulse bolt), `532` (walking), `533` (a squad of future soldiers fighting Romans in a
  match, the pulse bolts in flight).
- Found by the mod check, not mod content: a human worker with a basket fails A3 in its work blow
  (tool.basket through the body); the base cases don't cover that worker.

## Changes from the original plan

- The placement rule "head gear leaves the eyes in sight" gained an exception for `"face": "sealed"`
  (a helmet that encloses the whole face by design, the visor helmet). Claude's call for the test;
  Dominic to confirm, else the visor helmet goes back to showing the eyes.

## Links

- `docs/modding.md` (how to make one), `src/mods.gd`, `mods/scifi_test/`, `tests/mod_check.gd`,
  `tools/mods/`, `docs/backlog.md` §7 Community parts and §8 Eras and themes as a layer.
