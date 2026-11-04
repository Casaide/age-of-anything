# Engine hooks: what a mod and a second game need

An analysis for Dominic (Claude, 2026-11-03). No code changed. It follows `docs/engine-plan.md`, D-190 and D-191, and
backlog section 00. Dominic's question: "a clear idea on ease of making a game like ours on the engine, and making a
mod on our game", without boxing modders into our expectations and without making them edit the whole source to do
anything. His follow-up: "I'd like a good start point to advertise easy".

The method: walk two real cases step by step through today's code, mark each step as one of three kinds, and derive
the hook list from what the walks hit. Every path and function name is from the tree at `d329b09`.

- **Data today:** works now with files in a mod's `data/` (which files).
- **Small engine change:** a change of a few dozen lines in one or two engine files, after which it is data.
- **Game source:** the author has to edit our code (where, and why).

Work in progress elsewhere, not findings here:

- **Building roles.** Another session is moving the building lookups in `src/lib` from names (`btype_named("town_center")`,
  `bt_name[...] == "market"`) to roles. Today `grep 'btype_named("\|bt_name\[' src/lib` finds 31 lines, and 22 more in
  `gen/`, `game/` and `game.lobster`. Everything below that depends on roles assumes that work lands.
- **Voxel units as the default.** Another session is making `data/voxel/` and `src/view/voxel.lobster` the default
  drawing (today it is the `voxels` option, `game.lobster` `voxel_units`). The walkthroughs assume voxel units.

## 1. A mod on our game: sci-fi infantry with aliens and lasers

Dominic's example: "disable most units and buildings and focus on reduced tree, like just infantry fighting ... easily
make some aliens, and add custom SFX and lasers". The starting point is `mods/scifi_test/` (a future soldier: sealed
helmet, plate, power pack, pulse rifle, arc blade, a `pulse` shot look) and the scaffold
`tools/mods/new_mod.sh`. Call the new mod `zorbs`.

### 1.1 Scaffold and load

**Data today.** `tools/mods/new_mod.sh zorbs --era scifi` writes `mod.json`, `data/parts.json`,
`data/lexicon.json`, `data/rules/anything.json`, a model file and a sheet spec. `src/mod_check.sh zorbs` loads it or says
why not. The loader is `src/gen/mods.lobster` (`mods_use`, `mod_read`, `mod_check_data`, `mod_apply`); the game takes
`mods:zorbs` on the command line (`game.lobster`, `mods_use(mods_wanted)`).

Limits met straight away:

- `mod_read` refuses any file that isn't in `MOD_DATA_FILES` (`parts`, `creatures`, `families`, `palettes`, `lexicon`,
  `shots`) or `MOD_DATA_DIRS` (`rules/`, `maps/`). Everything the rest of this walk wants to touch is outside that list.
- `mods_gen.lobster` reads manifests from `../mods/` only, while `mod_roots` also has `../mods_private`: a private
  mod's models aren't joined in.

### 1.2 Turning off units

**Data today.** The roster is a host rule. A mod's `data/rules/<id>.json` either deep-merges into a game rule or makes
a rule of its own with `"extends"` (`load_rules` in `gen/datalib.lobster`, `mod_merge`). Arrays are replaced whole, so
a rule `rules/infantry.json` with `"extends": "default"` and a `roster` of three entries (worker, infantry, skirmisher)
gives every race just those lines. Play it with `rules:infantry`.

Limits:

- The roster can only use slot names some building already trains: what trains a slot comes from
  `buildings.json` `trains` (`gen/start.lobster`, `bm_trains`), not from the roster's `building` field, which is a label
  for the tech tree page. A new line name ("trooper") trains nowhere. **Needs** `buildings.json` merge (1.3).
- Arrays replaced whole means the mod restates each roster entry it keeps. Fine for a reduced tree; clumsy for
  "the default roster minus one". A `"-roster": ["large"]` (remove by `slot`) in `mod_merge` would be a few lines.

### 1.3 Turning off buildings

**Partly data today, by a side door.** A creature or culture can lack buildings: `creatures.json` and
`families.json` `lacks` (the rats lack `bastion` and `stone_gate`). `gen/identity.lobster` turns a lacked building into
lacked lines too, `gen/start.lobster` fills `bm_lacks`, the sim refuses to place them (`build_barred` in
`lib/economy.lobster`), and the bot's `build_order_step` (`lib/bot.lobster`) skips a lacked building. So an alien culture in the mod's `families.json` with `lacks: [stable,
archery_range, siege_workshop, castle, university, market, wonder, ...]` trims the tree for every race of that culture.

Why it isn't enough: it is per race, not per match (a plain "romans" opponent keeps everything), and the bots have
other paths that name buildings without checking `bm_lacks` (`watchtower`, `wonder`, `market` in `lib/bot.lobster`).

**Needs a small engine change** for the real thing:

- `buildings.json` merged like parts: same id replaces, `"remove": true` or `"status": "planned"` (already the
  convention: `load_btypes` in `gen/setup.lobster` leaves planned ones out) takes one out, `"extends"` copies.
- The catch is where it's read. `buildings.json` is loaded straight from `lib_root` in at least eight places:
  `gen/setup.lobster` `load_btypes`, `gen/start.lobster`, `gen/identity.lobster`, `game/panel.lobster` (the build
  `menu`), `game/techtree.lobster` (twice), `game/art_kit_buildings.lobster` `akb_bdata`, `game/lobby.lobster`,
  `game/pack_data.lobster`. The merge needs one accessor (say `lib_data("buildings.json")`, merged once at `mods_use`)
  and those reads moved onto it. The same is true of every other file below.
- A rule could also carry a match-wide `"buildings": { "remove": [...] }` so the cut is a rule, not a pack: the mod
  then works with or without its own culture.

### 1.4 Turning off tech and ages

**Mostly game data that mods can't reach.** `tech.json` (ages, 56 research items, line upgrades) is read by
`gen/setup.lobster` `load_tech_data` from `lib_root` and isn't moddable. The rule's `"ages": 3` only limits how many
steps the generator makes per line (`gen/generator.lobster`, `gen/heroes.lobster`); the sim's ages are every built
age in `tech.json` (`su_ages`), so an "infantry, one age" rule still offers Age 2 and 3 at the Town Center, just with
nothing new in them. Line upgrades are made for every slot a building trains (`load_tech_data`, `line.<slot>.<age>`).

**Needs a small engine change:** `tech.json` in the merge (research by id with `remove`, ages by `age`), and the rule's
`ages` also capping `su_ages` and the line upgrades. A research's `building` must exist after the merge: the loader
should drop or refuse research whose building is removed, with the reason, rather than leave it to fail later.

### 1.5 An alien creature with a voxel body

**Data today, almost.** What a creature is:

- `creatures.json`: noun, plural, `body`, `head`, `skins`, `families`, `voice`, `bonuses`, `lacks`, `ability`,
  `mounts`, `draw_scale`. A mod may `"extends": "frog"` and change only what it names (`mod_check_data`, `mod_apply`).
- `families.json`: the culture (cloth colours, name parts, architecture, the UI's look).
- `palettes.json`: its skins. `lexicon.json`: the word that gives it (`"zorbs": {"creature": "zorb"}`).
- `data/voxel/bodies/zorb.json`: the body itself, in the same shape as `frog.json` (skin, pale, size, points, legs,
  arms, helm, armour, seat, shapes). `game/voxel_units.lobster` `vx_bake_types` reads `<mod>/data/voxel/` after the
  game's, and `vx_body_for` picks the body by the recipe's body id, then the creature's id, then `human`.

Two things stop it today:

1. **The loader refuses a mod's `data/voxel/`.** `MOD_DATA_DIRS` is `[ "rules", "maps" ]`, and `mod_read` walks every
   file under the mod's `data/`, so `voxel/bodies/zorb.json` is refused with "can't be modded yet", although
   `docs/modding.md` (5b) and `vx_bake_types` both expect it. A one-line fix: add `"voxel"` (the voxel files then also
   join the mod's signature, which is right for looks and harmless for keys).
2. **A body still has to be a part with a model.** `mod_check_data` requires the creature's `body` and `head` to be
   parts, a body or head part needs `sockets`, and every new part needs a model case in the mod's Lobster file or a
   `.glb`. A voxel alien has none of that to give. **Small engine change:** a part may say `"voxel": "zorb"` (or the
   check accepts `data/voxel/bodies/<id>.json` as the body's model), its sockets taken from the voxel body's points;
   `mod_check` runs `voxel_proto`'s contact check on it instead of the part placement check.

Pricing still comes from the body's `points` in `parts.json`, so the part entry stays, as a price, not a model.

### 1.6 New weapons and lasers

**Data today:**

- The weapon part in `parts.json` (`weapon.laser_rifle`, `slot: hand_r`, `tags: [ranged, gun, energy, scifi]`,
  `only_if`, `era`, `stats`, `points`, `tier`): its tags pick the line (`ranged` without `bow` is the skirmisher).
- Its voxel look in the mod's `data/voxel/gear.json` (a `gear` entry with `shapes`, `hand`, `hold`) and a `parts`
  rule mapping the part to it (`vx_load`: a mod's rules go first).
- Its shot in `shots.json`: `{"tag": "energy", "speed": 980, "arc": 0, "len": 8, "w": 1.6, "col": "#d8fbff",
  "glow": "#38c8ff", "sticks": false}`. `game.lobster` `shot_kind_of` gives a mod's look first by tag;
  `game/fx.lobster` `shot_style` draws it as a glowing streak.

Today it still needs a model case or `.glb` for the part (as in 1.5), until gear can be voxel-only.

**Needs a small engine change:**

- **A beam.** A shot today is a projectile that flies (`ShotStyle`: arc, len, w, colour, glow). A laser that is a line
  from muzzle to target for a moment needs a `"draw": "beam"` kind in `shot_style` and the shot drawing in
  `game/fx.lobster`: view side only, the sim's shot can stay as it is (fast, flat). About 40 lines.
- **Hit effects.** What a hit looks and sounds like is code: `race_facts` in `game.lobster` picks the blow sound from
  the weapon's tags (`ram`, `blade`, `blunt`, else `hit_pierce`) and the shot sound by kind; `fx_spark`, `fx_stick`,
  `fx_splash` are fixed. A shot entry should name its `hit` (an effect recipe: spark colour, count, size, a sound),
  which is the first small piece of backlog 00's "effects as voxels".
- **The shot's sound is silent today.** `shots.json` has `"sound": "shoot_ball"`, but nothing reads it: `race_facts`
  sets `unit_shot` to `"shoot_" + kind`, `shoot_pulse`, which isn't in `audio.json`, and `play_sound` returns quietly
  on an unknown name. Read `sound` from the shot look (two lines), and a mod's own sound per 1.7.

### 1.7 Custom sounds and voices

**Game source today.** `data/audio.json` (buses, every sound's takes, bus and gap, voices, the music mixes by age) isn't
moddable, and the files are found at one fixed folder: `AUDIO_DIR = "../assets/audio"` in `game/audio.lobster`;
`play_sound` plays `sfx/<name>_<n>.wav`, `say` plays `voice/<voice>_<kind>_<n>.wav`, `music_start` reads
`../data/audio.json` by a literal path (not even `lib_root`) and plays `music/theme_<stem>.ogg`;
`ambience_start` names its three loops in code. `game/pack_data.lobster` `pack_from_data` fills `sounds` from the
game's `audio.json` only.

What works: a mod creature can borrow a game voice (`"voice": "frog"` in `creatures.json`), and a shot can borrow a
game sound once 1.6's `sound` is read.

**Needs a small engine change:** `audio.json` in the merge (sounds by name, voices, music mixes), and one lookup for a
sound's file: the last pack in load order that has `audio/sfx/<name>_<n>.wav` wins, else the game's (as
`data_path` does for data in `gen/datalib.lobster`). Then a mod's `audio/sfx/shoot_laser_1.wav` and
`audio/voice/zorb_ack_1.wav` just work. A mod's sounds can come from `src/audio/` (the synth) or anywhere; the pack
ships the WAVs.

### 1.8 New abilities

**Data for the one kind; game source for any other.** A creature's `ability` in `creatures.json` (kind, range, radius,
lasts, slow, cooldown) reaches `lib/abilities.lobster` through `gen/identity.lobster`. There is one kind, `AB_WEB`
(a slowing patch), and the code branches on it (`cmd_ability`, the web tick). A teleport, a shield bubble or a stun
grenade is new sim code in `lib/abilities.lobster`, plus its state in `gen/save.lobster` (regenerated by
`gen_reset.lobster`), plus its look in `game/fx.lobster`.

**Needs the first rule hook**, `ability(kind)` with `use(p, ids, x, y)` and `tick()` (the engine plan's hook API),
and the web moved into the base pack as its first user. Not small: it brings hook state columns into saves and the
`mod_check` determinism lint. Data-only kinds (a vocabulary of effects: slow, damage over time, heal, buff a stat for
some ticks, in a radius) would cover many mods before any code, and are worth doing alongside.

### 1.9 New win conditions

**Some data today.** `rules.wonder.victory: false` turns the Wonder clock off; `modes.json` has a rich start
vocabulary (age, stock, `town: false`, workers, walls, garrison, army, defend/attack, `hold_minutes`).

**Game source for the rest.** Victory is `lib/match.lobster` `match_tick`: out when your Town Centers are gone (if you
started with one), the Wonder, and the Siege mode's hold time. A "last army standing" skirmish (no towns, armies
only) can't be said in data: with `town: false` and no `defend`, `mode_hold` is -1, `mode_tick` returns, and nobody is
ever out. `modes.json` isn't moddable either, and the lobby's modes are read from the game's file only.

**Needs:** `modes.json` in the merge; a small `victory` vocabulary in data (`no_hub`, `wonder`, `nothing_left`,
`hold`, `kills:<n>`), each a few lines in `match.lobster`; and later the `victory()` rule hook for anything else.

### 1.10 The bots with a reduced building set

**Breaks today if the building set shrinks.** The bots' plan is data (`data/ai.json` `build_order`, `military`,
`research`, `levels`) but not moddable, and the code assumes our buildings and lines:

- `build_order_step` (`lib/bot.lobster`) looks each step up with `btype_named`; a building that isn't there gives -1,
  and `bm_cost[p][k]` then indexes with -1 (lacked buildings are skipped, missing ones aren't).
- `town_center`, `farm`, `house`, `pen`, `barracks`, `lumber_camp`, `watchtower`, `market`, `wonder` by name in
  `lib/bot.lobster`, `lib/eco_bot.lobster`, `lib/land.lobster`, `lib/match.lobster`, `lib/trade.lobster`,
  `lib/animals.lobster` (the roles work in progress).
- Lines by slot name: `type_named(p, "spear")` for the army's lane (`lib/bot.lobster`, line 1225), `scout`, `healer`,
  `trader`. The spear one is used without a check.
- Resources by name (`[ "food", "wood" ]` in `bot.lobster`, all four in `expand.lobster`).

**Needs:** `ai.json` in the merge (a mod gives its own `build_order`, or the bots drop steps whose building doesn't
exist); `btype_named` misses skipped wherever the bots ask; lines by role (from the roster's `role`) rather than slot;
resources from `data/resources.json`. After roles land, this is a day or two, and the test is backlog 00's: the sci-fi
mod plays a bot match to the end.

### 1.11 New maps

**Data today.** `maps/` is in `MOD_DATA_DIRS`; `gen/setup.lobster` `load_map` reads `data_path("maps/<id>.json")`,
so a mod's map plays with `map:<id>`. The rows are the source: edit them by hand.

**Small engine change for the lobby:** `game.lobster` `map_ids` scans `../data/maps` only and `game/lobby.lobster`
loads the preview from `lib_root`, so a mod's map isn't in the battle setup. Both should go through the mods'
folders (`data_path`). New terrain types (`terrain.json`) and resources (`resources.json`) aren't moddable; they are
needed for a map with, say, crystal fields.

### 1.12 UI text and names

- **Data today:** unit line names (`roster` `name`, `short`, `desc` in the rule), creature nouns and plurals, culture
  name parts (`families.json`), the generator's notes (`lexicon.json`), a culture's look in the UI (`families.json`).
- **Not moddable data:** building names and descriptions (`buildings.json`), age names ("Mud Age", `tech.json`),
  research names, tips (`tips.json`), the UI's directions (`ui.json`), mode names (`modes.json`). All fixed by the
  general merge.
- **Game source:** the lobby's and panel's own words are in code (`game/lobby.lobster`, `game/panel.lobster`,
  `game/topbar.lobster`). A strings file is worth it only when translation comes; for a mod, the data above covers
  what players read during a match.

### 1.13 The lobby

**Game source today.** Mods are on only by command line (`mods:`); there is no mods page. The Race Lab's rules are a
fixed list (`FE_RULES = [ "default", "bronze", "anything" ]` in `game/lobby.lobster`), so a mod's `rules/infantry.json`
can't be picked there; maps as in 1.11; modes from the game's `modes.json` (and `MODE_IDS` in `game.lobster`).

**Small engine change:** rules, maps and modes listed from the merged data; a Mods page listing `mods_discover`'s
finds with their refusals (the reason strings already exist), saving the choice to `settings.txt`. Mods change what is
compiled (their models), so turning one on means a restart: the page says so.

### 1.14 Prices and balance

**Data today.** Every part's `points` set its price through the rule's `cost.curve` (`data/cost_curves.json`, a
fixed-point table) and the roster's `price_points`; `races.lobster -- mods:zorbs anything "zorbs"` shows each unit and
its cost. The counter tags hold whatever the parts are.

**Small gaps:** `cost_curves.json` isn't moddable (a rule can only name an existing curve); `balance.lobster` (price
by fights) doesn't take `mods:` yet. Both small.

### 1.15 The mod walk in one table

| Step | Data today | Small engine change | Game source |
|---|---|---|---|
| Scaffold, load, check | `new_mod.sh`, `mod_check.sh` | `mods_gen` reads `mods_private` | |
| Units off | rules `roster` (extends a rule) | `-roster` removal in `mod_merge` | |
| Buildings off | per race: culture `lacks` | `buildings.json` merge, one accessor, rule-wide removal | |
| Tech and ages off | | `tech.json` merge; rule `ages` caps the sim's ages | |
| Alien on voxels | creatures, families, palettes, lexicon | `voxel` in `MOD_DATA_DIRS` (one line); voxel-only body and gear parts | |
| Laser weapon | part, gear rule, `shots.json` streak | beam draw kind; hit effect recipe; shot `sound` read | |
| Sounds and voices | borrow a game voice | `audio.json` merge; pack audio folders | |
| Abilities | the web's numbers | data effect kinds | any new kind (until `ability` hook) |
| Win conditions | Wonder off, mode starts | `modes.json` merge; victory vocabulary | anything else (until `victory` hook) |
| Bots | | `ai.json` merge; bots skip missing buildings, read roles | |
| Maps | `maps/` | lobby lists the mods' maps; terrain and resources merge | |
| UI text | lines, creatures, cultures | buildings, tech, tips, ui, modes merge | lobby and panel words |
| Lobby | | rules, maps, modes from data; a Mods page | |
| Prices | points, rules `cost` | `cost_curves` merge; `balance` takes `mods:` | |

What's striking is how little needs game source once the data merge exists: abilities and victory beyond the
vocabulary, and new building models (1.16).

### 1.16 One more the walk found: new buildings

The sci-fi mod as described removes buildings; it doesn't add any. A mod that does (a "drop pod" for its infantry)
hits building art: building looks are Lobster models (`model/buildings.lobster`, `buildings2`, `build_mats`) baked by
`game/art_kit_buildings.lobster` per architecture and stage, and shipped prebaked (`src/baked/`, D-185). A mod's
`models` file only answers part ids (`build_mod_<id>` in `model/mods_active.lobster`). **Needs:** a second builder in
the mod's model file for building types (`build_mod_building_<id>(arch, type)`), joined the same way, or voxel
buildings (D-190's "then buildings"). Until then, a mod reuses our building looks under new names.

## 2. A different game on the engine

The case: a small RTS that isn't race-from-prompt. Call it *Three Banners*: three fixed factions with set units, its
own UI look (slate and teal, not our timber and bronze), its own maps, and a rule of its own (control three shrines
for five minutes to win).

### 2.1 What they'd keep as the engine

From `docs/engine-plan.md` section 2, these work unchanged for another game's content:

| Kept | Lines | Notes |
|---|---|---|
| `lib/` sim core: `state`, `world`, `consts`, `fixed`, `tokens`, `spatial`, `commands`, `orders`, `movement`, `flow`, `map`, `fog` | ~3,650 | Integer, 20 Hz, command-driven; set up from a token stream |
| `lib/` genre systems: `combat`, `economy`, `tech`, `siege`, `garrison`, `heal`, `walls`, `bridges`, `trails`, `heroes` | ~3,500 | Driven by data. `tech.lobster`'s `machine` and `mounted` class names are the one tangle |
| `gen/json`, `sha256`, `rng`, `scenario_out`, `save`/`reset` (generated) | ~3,900 | Saves come from `gen_reset.lobster` over the sim's globals |
| `view/voxel`, `baker`, `world_bake`, `geom`, `rig3d`, `node`, `art` | ~3,200 | Their units are voxel data in `data/voxel/` |
| `model/base`, `kit`, `glb`, `flat`, `grng`, `models` | ~1,100 | The model kit, for their buildings and props |
| `game/ui`, `pad`, `touch`, `perf`, `audio`, `order_marks`, `ruin`, `doodads`, `levels`, `ground`, `fx` | ~2,600 | Widgets (look from `ui.json`), input, sound, effects |
| `net/lockstep`, `net/lan` | ~320 | |
| Tools: `sheet`, `placement/` rules, `voxel_proto`, `golden`, `shards.sh`, `batch.sh`, `test_sim`, `save_check`, `net_check`, `path_audit` | ~10,000 | Tests run on our content today; they'd point them at theirs |

About 18,000 lines of `src/` they'd use without reading, and another 10,000 of tools.

### 2.2 What they'd have to rip out or fork

| Tangle | Where | Why it's in the way | What they'd do |
|---|---|---|---|
| **Unit types are priced race recipes** | `gen/setup.lobster` (`add_type` takes a recipe and its `eval`), `gen/start.lobster` `setup_world(seed, map, races, rules, teams)`, `setup_identities` (bonuses from `creatures.json` and `families.json`) | There's no way to hand the sim a faction except as a generated race; every match in `game.lobster` calls `generate(prompt, rules, reroll)` | Today: write each faction as a race JSON by hand (units with `recipe`, `eval`, `line`), keep stub `creatures.json`/`families.json` entries for identity, and add a loader for race files. Properly: the engine plan's step 5, a plain unit type table in data |
| **The generator's data is required** | `gen/datalib.lobster` `lib_load` reads `parts`, `creatures`, `families`, `uniques`, `heroes`, `palettes`, `lexicon`, `cost_curves` and the creature kit | Load fails without them; identity, voxel colours (`vx_palette` reads `lib_palettes`) and names go through them | Ship minimal stubs, or split `lib_load` into engine files (resources, palettes) and the generator's |
| **`MOD_DATA_FILES` and the version** | `gen/mods.lobster`: the generator's files, `MOD_GAME_VERSION = "0.21"`, `MOD_BASE_ERAS` our eras, roots `../mods` | Their game's packs and mods would need their own list and version | The pack format (engine plan, packs) replaces it |
| **`game.lobster`'s mixed loop** | 2,664 lines, 117 imports: camera, selection, orders, minimap (engine) beside the lobby glue (~100 lines), the race swap `become` (~65), `race_facts` (shot and blow sounds by our tags), the self-test (~260), `main` (~680, mixed) | One fixed import order for everything, our game's glue inside the loop | Fork the file: keep the window, camera, selection, orders, HUD and minimap sections; replace the lobby, swap, `race_facts` and self-test |
| **The lobby** | `game/lobby.lobster` (1,334): title, battle setup by prompts, Race Lab, saves, network | It is our front end | Write their own (a faction pick is simpler: perhaps 400-600 lines on `game/ui`), keep the saves and network pages' logic |
| **Our ideas in the HUD** | `game/panel.lobster` (culture crest on the frame), `game/topbar.lobster` (age badge, Wonder clock), `game/techtree.lobster` (rows as ages) | Generic panels with our looks and rules inside | Edit perhaps 150 lines, or wait for UI hooks |
| **Building names in `lib/`** | `lib/match`, `trade`, `animals`, the bots | Their buildings have other names | In progress (roles) |
| **Victory** | `lib/match.lobster` | "No Town Center" and the Wonder | Rewrite the 68 lines for shrines, or the `victory()` hook |
| **Our view extras** | `game/town.lobster`, `game/paths.lobster`, `game/art_kit.lobster`, `game/art_kit_buildings.lobster`, `view/unit_view`, `part_bake`, `corpse`, `game/pack`, `pack_data` | Living towns, culture paths, our building list, the parts-on-sockets composer | Drop the imports (town, paths); the art kit's building jobs read `buildings.json` but bake through our model functions by architecture |
| **Building and prop art is code** | `model/buildings`, `buildings2`, `build_mats`, `props`, `town_props`, `trees`, `bridges` (~5,000 of the 12,194 model lines) | No data form for a building's look yet | Write their buildings in the model kit (the largest content job), or wait for voxel buildings |
| **The bots** | `lib/bot`, `eco_bot`, `land`, `expand`, `scout`, `walls_ai` (3,270) | Our buildings, our lines (`spear`), our resources | After roles: tune `ai.json`; before: edit about 60 lines |

### 2.3 How much they'd touch

Today, for *Three Banners*:

| Kind | Files | Lines |
|---|---|---|
| Edited engine files (setup, start, datalib, mods, match, the bots' names, panel, topbar, techtree, pack_data, voxel_units, art kit) | ~15 | ~800-1,200 changed |
| Forked `game.lobster` | 1 | ~1,100 kept, ~1,000 replaced or cut |
| Written new: lobby, faction loader, shrine rule, HUD bits | 4-6 | ~1,000-1,500 |
| Their content: data (buildings, tech, ai, rules, maps, terrain, voxel units, audio, ui) | ~20 JSON | most of the work, as it should be |
| Their building and prop models in Lobster | 3-5 | ~2,000-4,000 |
| Stubs to satisfy our generator's loader | 6-8 JSON | small, but confusing |

So about 20 of our files edited or forked and 2,000 to 3,000 lines of engine-side code changed, before their own
content. It's doable for someone who reads Lobster well, over a few weeks, and every edit is a merge conflict with
each engine update after.

After the engine plan's steps 1 to 6 and the hooks below, the same game is: a `pack.json` of kind `game`, its data,
faction files, building models (or voxel buildings), a `main.lobster` that imports the engine and its own lobby, one
`victory` hook for the shrines, and a few UI hooks. No edited engine files. Roughly 1,000 to 1,500 lines of their own
code (the lobby and the hooks), plus content.

## 3. The hook list

Each row is a hook or a data extension point. **Side:** *rule* runs in the deterministic lockstep sim (integers, the
sim's rng, stable order, no clocks or files; `mod_check`'s lint and twice-run hash apply); *UI* runs on one machine and
may do as it likes; *load* runs once at start, before the sim exists. Efforts are rough working days of a session.
The first nine rows are the **easy set** (section 4): together they make the common cases data only. Rows marked ★
unblock the most.

| # | Hook or extension | Need it serves | Side | Where it plugs in | Effort |
|---|---|---|---|---|---|
| 1 ★ | **One data accessor and a merge for every data file**: `buildings`, `tech`, `ai`, `audio`, `modes`, `ui`, `terrain`, `resources`, `animals`, `bridges`, `siege_shots`, `cost_curves`, `tips`, and `voxel/` in `MOD_DATA_DIRS`. Same id replaces, `"remove": true` takes out, `"extends"` copies, `+key` appends, `-key` removes from a list | 1.2-1.4, 1.7, 1.9-1.12, 1.14; 2.2's stubs | load | `gen/mods.lobster` (`MOD_DATA_FILES`, `MOD_DATA_DIRS`, `mod_read`, `mod_apply`), `gen/datalib.lobster` (`mod_merge`, a `lib_data(rel)`), and the 27 `load_json(lib_root + "/<file>")` reads moved onto it (setup, start, identity, modes, panel, techtree, art_kit_buildings, lobby, pack_data, audio, ui) | 3-4 |
| 2 ★ | **Building roles, not names** (in progress) | 1.3, 1.10; 2.2's names in `lib/` | rule | `data/buildings.json` `roles`; `lib/match`, `trade`, `animals`, `bot`, `eco_bot`, `land`; `gen/modes.lobster` | 1-2 |
| 3 ★ | **Bots read what exists**: steps whose building is missing are dropped, lines by roster `role` not slot, resources from `resources.json`, `ai.json` merged | 1.10 | rule | `lib/bot.lobster` `build_order_step` and the `type_named(p, "<slot>")` calls; `lib/expand.lobster`; `gen/start.lobster` `load_ai_config` | 1-2 |
| 4 ★ | **Rules that shape the match**: rule `ages` caps the sim's ages; rule-wide building and research removal; a `victory` vocabulary (`no_hub`, `wonder`, `nothing_left`, `hold`) | 1.2-1.4, 1.9 | rule | `gen/setup.lobster` `load_btypes`, `load_tech_data`; `lib/match.lobster` `match_tick` | 1-2 |
| 5 ★ | **Pack audio**: a sound's file from the last pack that has it; `audio.json` merged; a shot look's `sound` read | 1.6, 1.7 | UI | `game/audio.lobster` `play_sound`, `say`, `music_start`, `ambience_start`; `game/pack_data.lobster`; `race_facts` in `game.lobster` | 1 |
| 6 ★ | **Voxel-only units**: a body, head or gear part with `"voxel"` instead of a model case; sockets from the voxel body; `mod_check` runs the voxel contact check | 1.5, 1.6; 2.1's units | load | `gen/mods.lobster` `mod_check_data`; `game/voxel_units.lobster` `vx_body_for`, `vx_def_of`; `src/mod_check.lobster`; `src/voxel_proto.lobster` | 1-2 |
| 7 | **Shot and hit looks as data**: `draw: beam`, a `hit` effect recipe (sparks, colour, sound), blow sounds by data not tags | 1.6 | UI | `game/fx.lobster` `shot_style`, `fx_spark`; `game.lobster` `shot_kind_of`, `race_facts` | 1-2 (more with backlog 00's voxel effects) |
| 8 | **The lobby from data, and a Mods page**: rules, maps and modes listed from the merged data; mods picked and remembered | 1.11, 1.13 | UI | `game/lobby.lobster` (`FE_RULES`, `fe_load_maps`), `game.lobster` `map_ids`, `MODE_IDS`; `settings.txt` | 2 |
| 9 | **Starter kit**: `new_mod.sh --template`, a template game pack, `mod_check` with a sheet of the unit firing (section 4) | everything, for a newcomer | tools | `tools/mods/new_mod.sh`, `src/mod_check.sh`, `tests/sheets/`, `src/sheet.sh` | 2 |
| 10 ★ | **The unit type seam: factions from data** (engine plan step 5): the sim built from a plain unit type table; a `factions/*.json` loader; the generator fills the table for our game | 2.2's biggest tangle | load | `gen/setup.lobster` `add_type`, `gen/start.lobster` `setup_world`, `setup_identities`; `game.lobster`'s `generate` calls | 2-3 |
| 11 | **Pack signatures in multiplayer and saves** (engine plan step 4) | any mod played online | load | `net/lan.lobster`, `net/lockstep.lobster`, `gen/save.lobster` | 1-2 |
| 12 | **Rule hook `ability(kind)`**: `use(p, ids, x, y)`, `tick()`; hook state in declared columns; plus a data vocabulary of effect kinds (slow, damage over time, heal, stat buff) | 1.8 | rule | `lib/abilities.lobster` `cmd_ability`; `mods_gen.lobster` writing `hooks_active.lobster`; `gen_reset.lobster` | 3 (the first hook carries the hook machinery) |
| 13 | **Rule hook `victory() -> winner or -1`** | 1.9; 2's shrines | rule | `lib/match.lobster` `match_tick` | 0.5 after 12 |
| 14 | **Rule hook `start(mode)`** | Fortress and Siege as base-pack hooks; a mod's scenario start | rule | `gen/modes.lobster` `setup_mode` | 0.5 after 12 |
| 15 | **Rule hooks `on_hit`, `on_death`, `on_built`, `building_tick`** | sticky shots, carcasses, pens; a mod's shields, explosions, spawners | rule | `lib/combat.lobster`, `lib/animals.lobster`, `lib/economy.lobster` | 1-2 after 12 |
| 16 | **Building models in a mod**: `build_mod_building_<id>(arch, type)` beside `build_mod_<id>`, or voxel buildings | 1.16; 2.2's building art | load | `mods_gen.lobster`, `model/mods_active.lobster`, `game/art_kit_buildings.lobster` | 1-2 (voxel buildings: much more) |
| 17 | **UI hooks**: draw over the world, add to the panel and top bar, react to an event with a sound or effect | living towns, culture paths, the Wonder clock; 2.2's HUD; a mod's shield bubble | UI | `game.lobster` drawing, `game/panel.lobster`, `game/topbar.lobster` | 2 |
| 18 | **Split `game.lobster`**: the loop, camera, selection, orders, HUD and minimap as engine; the game's glue behind a few calls (front end, unit source, self-test) | 2.2 | load | `game.lobster`; engine plan step 7 | 2-3 |
| 19 | **Split `lib_load`**: the engine's files (resources, palettes) apart from the generator's | 2.2's stubs | load | `gen/datalib.lobster` | 0.5 |
| 20 | **Small fixes**: `mods_gen` reads `mods_private`; `balance.lobster` takes `mods:`; `tech.lobster`'s `machine`/`mounted` as data | 1.1, 1.14; 2.1 | load | `mods_gen.lobster`, `balance.lobster`, `lib/tech.lobster` | 0.5 |

The few that unblock the most: **1** (nearly every mod step waits on it), **2** and **3** together (a reduced building
set without breaking the bots), **4** (a mod's whole shape as one rule file), **5** (sounds), **6** (aliens without
code), and **10** (any game that isn't ours).

## 4. A starting point we can honestly call easy

### The smallest set

Rows 1 to 9 of the table, about 13 to 18 days of sessions, mostly in data loading, not in the sim. With them, the
common cases need no source edits:

- remove or replace any building, research, age, line, sound, map, mode, terrain or UI text;
- an alien on a voxel body with its own colours, words, culture and voice;
- a weapon with its own shot, beam, hit sparks and sound;
- a rule file that is the mod's whole match: its roster, ages, buildings, victory;
- bots that play whatever is left;
- all of it picked in the lobby.

What stays code, and is honestly "advanced": new ability kinds beyond the vocabulary and new victory conditions beyond
it (rows 12-15), new building models (row 16), UI extras (row 17). For a different game, row 10 and row 18 are the
line between "a pack" and "a fork".

### The starter kit

- **A template mod**, scaffolded: `tools/mods/new_mod.sh <id> --template infantry`. It is the sci-fi mod
  rebuilt as Dominic described it, standing in for `mods/scifi_test`:
  - `data/rules/infantry.json`: extends `default`, roster of worker, infantry and skirmisher, `ages: 2`, buildings
    left: Town Center, house, farm, barracks, lumber camp; `victory: [ no_hub ]`.
  - `data/creatures.json`, `families.json`, `palettes.json`, `lexicon.json`: one alien, its culture and its word.
  - `data/voxel/bodies/<alien>.json` (copied from `frog.json` with a note per field) and `gear.json` (a laser rifle).
  - `data/parts.json`: the rifle and a blade, priced against a game part, `"voxel"` instead of a model case.
  - `data/shots.json`: a `laser` beam with its `hit` sparks and `sound`.
  - `data/ai.json`: the bots' build order for that tree.
  - `audio/sfx/shoot_laser_1.wav`, `audio/voice/<alien>_ack_1.wav`: placeholders rendered by `src/audio/`.
  - `sheets/<id>.json`: the alien in 8 facings, walking and firing.
  - `README.md`: what each file does, in the order a newcomer edits them.
- **A template mini-game on the engine** (after rows 10 and 18): `games/template/` with `pack.json` of kind `game`,
  two fixed factions in `factions/*.json`, one small map, its own `rules/`, `buildings.json` with five buildings,
  plain voxel units and buildings, a one-page lobby (pick a faction, start), and a `victory` hook as the example of
  a rule hook. The engine plan's test pack (`engine/packs/test/`, step 8) could be the same thing: the engine's own
  tests run on the template, so the template can't rot.
- **The tools that come with them:** `mod_check` (loads or says exactly why not; the determinism lint for hooks; the
  voxel contact check; a short bot match to the end with the mod), `sheet.sh` (the unit close up, firing), `races.lobster
  -- mods:<id>` (who gets what and what it costs), `./play.sh ... watch` (a bot match to watch), `tools/mods/pack.sh`.

### The first hour

From nothing to an alien firing lasers in a match, once the easy set exists:

1. `tools/mods/new_mod.sh zorbs --template infantry` (a green mod that already plays).
2. Edit `mods/zorbs/data/voxel/bodies/zorb.json` (size, skin, eyes, legs) and `data/shots.json` (the beam's colour),
   and drop a WAV over `audio/sfx/shoot_laser_1.wav` if they have one.
3. `src/mod_check.sh zorbs` (loaded, checks pass, and a sheet of the zorb firing to look at).
4. `./play.sh lobby mods:zorbs rules:infantry "races:zorbs|zorbs" watch` (or pick the mod in the lobby's Mods page).

### What we could say once it exists

Honest, plain, each one checkable against the kit:

- A mod is a folder of JSON and sounds. The template plays as it is; most changes are edits to its files.
- You can remove or replace any building, unit line, research, age, sound or map without touching code.
- Units are voxel bodies described in data; the template has an alien to start from.
- Every mod is checked when it loads, and a refusal says what to fix and where.
- The bots play whatever buildings and lines a mod leaves.
- New abilities, win rules and UI need a little Lobster code through a small set of hooks; the engine's source is
  open for anything the hooks don't cover.
- Mods with code need the desktop builds; Android takes data-only mods.

What we shouldn't say yet: that a whole new game is easy (it's "possible, with the template", until row 18 is done and
someone outside has done it), or that the kit is large (it's small and growing, as `docs/business.md` says about
public copy).

## 5. Verdicts

**A mod on our game.** Today it's half data, half wall. The alien's creature, culture, words and colours, the laser
rifle, its streak of a shot, a reduced roster and new maps are data, and the checks are good. But a mod can't touch
buildings, tech, the bots' plan or sound at all; its voxel body is refused by the loader and still needs a model case;
the laser is silent; the bots index with -1 once a building they plan is gone; and the lobby can't pick a mod, its
rules or its maps. Dominic's sci-fi mod, done properly today, means editing about ten game files. After the easy set
(rows 1-9, about three weeks of sessions), the same mod is a folder of data and WAVs made from a template, checked by
`mod_check`, picked in the lobby, and played by the bots; only new ability kinds and win rules want code, through
hooks.

**A different game on the engine.** Today it's a fork, not a game. The sim, pathing, net, saves, bakers, voxels and
widgets (about 18,000 lines) carry over untouched, which is a good start, but there's no way into a match except as a
generated race, the loader requires the generator's data, and `game.lobster`, the lobby, the HUD and the bots carry
our game inside them: about 20 files and 2,000 to 3,000 lines of engine-side edits before their own content, and a
merge conflict with every engine update. After the easy set plus the unit type seam (row 10), the `game.lobster`
split (row 18) and the first rule hooks (rows 12-13), it's a game pack with its own data, factions, lobby and a hook
or two, with no edited engine files: real work, mostly content, and the building art the largest part until buildings
are voxels too.


## 6. Maps: a drawing and what it means (proposal, Dominic 2026-11-03)

Today a map is one JSON file (`data/maps/*.json`: `rows`, `legend`, `heights`, `starts`) edited by hand; terrain types
(`data/terrain.json`) and ground textures (`assets/art/textures/*.svg`)
can't be modded, props (trees, rocks) are models in code, the lobby lists only `data/maps`, and there's no editor or
random map generator.

Dominic: "a simple format defining it all, we could have editor later", with "a second file drawing the map in pure
ASCII, and then JSON defining what it means". A map is a folder:

```
maps/reed_meadow/
  terrain.txt     the map drawn in plain ASCII, one character a cell, one line a row
  height.txt      optional: the same grid as digits 0-9 (flat where missing)
  map.json        what the characters mean, the objects, the settings
```

`terrain.txt` is just the drawing:

```
~~~~~......TTTT.....
~~~~......TTTTT..1..
~~~.......TTT.......
~~.....g............
~...D.......s.......
~..........2........
```

`map.json` says what it means. A character is either a terrain type, or a marker for something placed on that cell
(drawn on its terrain's default ground):

```json
{
  "id": "reed_meadow", "name": "Reed Meadow",
  "legend": {
    ".": "grass", "~": "water", "T": "forest", "g": "gold", "s": "stone",
    "1": { "start": 1 }, "2": { "start": 2 },
    "D": { "animal": "deer", "count": 4 }
  },
  "objects": [
    { "prop": "oak", "at": [30.5, 41.2], "turn": 90 },
    { "resource": "gold", "at": [50, 50], "amount": 800 }
  ],
  "rules": { "mode": "conquest", "players": [2, 4] }
}
```

- Grids for what covers the map (terrain, height); markers in the drawing for single things on a cell; `objects`
  for anything with exact positions or properties; `rules` for the mode, player counts and (later) triggers through
  the rule hooks.
- Readable and diffable in git, and easy for a person or an AI to draw and edit. An editor later reads and writes
  the same three files; a random map generator writes them from a style and a seed, so the engine loads one format.
- Today's maps convert mechanically (`rows` -> `terrain.txt`, `heights` -> `height.txt`, `starts` -> markers).
- Engine: the format, loading, pathing per movement class, the ground renderer, the generator and editor as tools.
  Game or mod: terrain types (`terrain.json`, moddable), textures, props (as voxel data like units), the maps.

Steps: (1) the folder format and the converter, mod maps in the lobby, `terrain.json` and textures moddable; (2)
props as voxels from data; (3) a random map generator with styles as data; (4) a simple in-game editor; (5) scenario
triggers through the rule hooks.

## 7. Era capabilities: tanks, planes and the like

If it's a unit with different numbers or a different look, it's game data; if units behave in a way the sim doesn't
model yet, it's engine work, added as a general capability that data switches on.

| Capability | Today | Engine work | Data that switches it on |
|---|---|---|---|
| Heavy armoured vehicle with a cannon (a tank) | works: armour, splash, minimum range, a shell shot, counter tags, points | none needed | the unit and its parts |
| A turret aiming apart from the hull | no: a unit faces one way | a voxel part that turns to the target while the body faces its way (view only) | `turret` on a part |
| Turn rate (vehicles, ships) | no: facing changes at once | turning in the sim, slowing while it turns | `turn_rate` per unit type |
| Hovering flyers (helicopters, birds, dragons) | works: the flying movement class over terrain and water | none | `mclass` flying |
| Flyers that can't stop (planes) | no | circling when idle, passes and turning back, a turn radius | `must_keep_moving`, `turn_radius` |
| Air and ground target layers, anti-air | no: `targets` is only `none` or `buildings` | targeting by layer in combat | `targets: air`, `targets: ground` |
| Landing and rearming (airfields) | no | a building behaviour: land, rearm, take off | `rearms_at` on the unit, a role on the building |
| Height for flyers (vision, shadow) | no | sight and drawing by altitude | `altitude` per unit type |

These come with the era packs (gunpowder, then sci-fi), each built when a pack needs it.

## Fixed since (2026-11-03)

- A mod's `data/voxel/` is accepted (`MOD_DATA_DIRS` in `src/gen/mods.lobster`).
- A data-only mod (no `models` in `mod.json`) compiles: `src/mods_gen.lobster` only chains a builder for a mod that has
  models (before, the game failed to compile with `build_mod_<id>` unknown).
- `src/mod_check.lobster` runs on a mod with no `data/parts.json`.
- The bots skip a build-order step whose building doesn't exist, don't wait for research on a building that doesn't
  exist, and pick a lane with no spear line (`src/lib/bot.lobster`); before, they read index -1.
