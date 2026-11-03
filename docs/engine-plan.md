# The engine plan: an RTS engine with Age of Anything as content on it

A draft for Dominic to react to (Claude, 2026-11-03). Nothing here is decided and no code has moved. It follows D-190
(the long-term shape is an engine with the game as content on it, the way Spring, now Recoil, splits engine and games)
and the order already in `docs/backlog.md`, section 00. The open questions are in section 7.

What's agreed so far (D-190 and the backlog):

- The engine owns the deterministic lockstep sim, pathing, rendering, sound, networking and saves.
- A game is content plus scripts on top; mods are more of the same, and may depend on and override each other.
- Our own content becomes a base pack, loaded like any mod.
- Units move to procedural voxels defined in data (`data/voxel/`, `src/view/voxel.lobster`,
  `src/game/voxel_units.lobster`). Buildings, tech, AI and sound become mergeable data.
- Mod scripts come first as Lobster compiled in at start, through a small hook API, with `mod_check` as the static
  sandbox: rule hooks deterministic, UI hooks free. A Lua-like runtime script comes later.
- Simple, home-grown approaches; no big tools.

## 1. Name and branding

The engine needs its own name only when it's shown on its own (a "Made with" line, a page, a public repo). Until then
`engine/` is enough. These are options to react to, not a pick. Lobster is the language, so most lean on the sea.

| Name | Tone | Why | Quick web check (2026-11-03) |
|---|---|---|---|
| **Creel** | nautical, sturdy | A creel is the woven trap a lobster is caught in: the thing that holds the catch. The engine holds the packs. Short, easy to say, rare as a software name | A small itch.io project called "creel" is tagged as a game engine; otherwise the fishing basket. Low clash |
| **Pincer** | playful | A lobster's claw, and a pincer movement is a battle tactic, so it reads as strategy too | No engine found; a small itch.io horror game and a chess variant use the word. Low clash |
| **Ballast** | sturdy | The weight low in a hull that keeps the ship steady: the lockstep sim that never drifts | No engine or big product found; an open-source engine called Ballistica is near in sound. Low clash |
| **Moult** | playful | A lobster grows by shedding its shell; the game grew out of this engine (and out of Godot before it) | Nothing found as an engine or product. The risk is spelling: American English writes "molt" |
| **Keel** | sturdy, nautical | The backbone a hull is built on | A Python ECS game engine on PyPI is called Keel. Medium clash: same category |
| **Shoal** | nautical, playful | Many small creatures moving as one, which is what an RTS draws | An old Java clustering framework (GlassFish Shoal, 2010); nothing in games. Low clash, but a shoal is also a hazard to ships |
| **Carapace** | sturdy | The shell that holds the soft parts | A well-used Go shell-completion library (carapace, carapace-bin). Medium clash among developer tools |
| **Tidepool** | playful | A small world full of life, cut off from the sea | A Squids.js starter template, several small games, and a well-known diabetes-data nonprofit. Medium clash |
| **Bosun** | nautical | The deck officer who keeps the ship and the crew in order | An Amsterdam software-maintenance startup and an older open-source monitoring system. Medium to high clash |
| **Brine** | nautical | Salt water | Brine2D, a C# 2D game engine on NuGet. High clash: avoid |

Claude's three: **Creel**, **Pincer**, **Ballast**. These were web searches only, not trademark searches. Before a
pick goes public, check the trademark registers (USPTO, EUIPO, UK IPO), Steam, GitHub, npm and the domain, as the
game's own name check in `docs/business.md` §4 asks.

### Logo and wordmark ideas (in words)

- **Creel:** the woven pot drawn as an isometric cage, its slats on the game's 2:1 tile grid, the wordmark in a plain
  slab face beside it. Works as a one-colour mark.
- **Pincer:** one claw whose two halves close on an isometric tile, or two claws meeting as a chevron. The wordmark
  in lower case, rounded.
- **Ballast:** an isometric stone block sitting just under a waterline, the wordmark across the line.
- **Moult:** an empty shell outline beside the same shape filled in; the wordmark with a split letter.

Keep the engine's look apart from the game's: the game has the timber and bronze with gold titles (`data/ui.json`,
D-187's gold inlay icon); the engine could be ink on chalk or sea blue, one colour, no texture, so it never competes
with the game's own icon.

### How it's presented next to Age of Anything

- In the game: one small line on the boot screen under the game's icon (`src/game/boot.lobster`), "Made with
  &lt;name&gt;", and the engine and Lobster in the credits ("Lobster, by Wouter van Oortmerssen, Apache 2.0").
- On the website (`~/Dev/casaide/age-of-anything-website`): nothing until the Modding page (Early Access in
  `docs/business.md` §5). Then the Modding page says what the engine is and links its docs. A separate engine site
  only once the engine is public and has a user who isn't us.
- On the Steam page: not needed. The players buy the game.
- In the repo, code and docs: no commercial games named, as everywhere else; Spring and Recoil (open source) are fine.

## 2. What's engine and what's game, today

Every line count is from `wc -l` on 2026-11-03. "Engine" means it would work for another RTS with other content
unchanged. "Game" means it is Age of Anything's content or its own idea. "Tangled" means it's engine work with game
names or assumptions inside; each says what tangles it.

### src/lib: the sim and the bots (10,630 lines)

The sim is already in good shape for an engine: integers only, a 20 Hz tick, driven by the command stream, linted by
`test_sim -- part:source_lint`, and set up from a token stream (`lib/tokens.lobster`, `load` in `lib/world.lobster`)
that `gen/setup.lobster` fills from data. Resources are indexed by `data/resources.json`, terrain by
`data/terrain.json`, building and unit stats come from data. The tangles are a few hard-coded building names and the
bots.

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `state`, `world`, `consts`, `fixed`, `tokens`, `spatial`, `commands`, `orders` | 2,000 | engine | Nothing much. `world.lobster`'s `load_extras` names every system's extra table (webs, bridges, wonders, pens): the list of systems is fixed in code |
| `movement`, `flow`, `map`, `fog` | 1,650 | engine | None |
| `combat`, `economy`, `tech`, `siege`, `garrison`, `heal`, `walls`, `bridges`, `trails` | 3,400 | engine | Genre systems driven by data. `tech.lobster` knows the classes "machine" and "mounted" by name (formation bands) |
| `match` | 68 | tangled | Victory is "no `town_center`" and the `wonder` clock (`btype_named` on both) |
| `trade` | 220 | tangled | A trade post is a building named `market` |
| `animals` | 267 | tangled | Herding home is `town_center`; a carcass is the terrain `carcass`, its yield `food` |
| `abilities` | 121 | tangled | One ability kind, `AB_WEB` (the spiders' web), in code: the first rule hook to come |
| `heroes` | 75 | engine | A hero is a flag and an aura in data |
| `bot`, `eco_bot`, `land`, `expand`, `scout`, `walls_ai`, `ai_cfg` | 3,270 | tangled | The bots name buildings (`town_center`, `house`, `farm`, `barracks`, `market`, `pen`, `lumber_camp`, `mill`, `mining_camp`, `watchtower`, `bastion`, `castle`, `wonder`), resources (`[ "food", "wood" ]` in `bot.lobster`, all four in `expand.lobster`) and the `spear` line. Their tuning is data (`data/ai.json`) but their building list is code. This is the backlog's "bots reading what exists instead of a fixed building list" |

About 18 name lookups in all (`grep -n 'btype_named("\|bt_name\[' src/lib`). None is deep: each is a role a building
plays.

### src/gen: generator, setup, saves, balance (7,059 lines)

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `json`, `sha256`, `rng` | 445 | engine | None (JSON in Godot's key order is a leftover worth keeping: the race keys depend on it) |
| `scenario_out` | 233 | engine | None: writes the sim's arrays as a scenario |
| `save`, `reset` | 3,212 | engine (generated) | Written by `src/gen_reset.py` from every global in `lib/`, `gen/setup`, `gen/start`. The mechanism is engine; the globals it lists include the game's systems. Hook state will need to join it |
| `datalib` | 177 | tangled | Reads the game's files by name (parts, creatures, cultures, uniques, heroes, palettes, lexicon) from `../data` |
| `mods` | 229 | tangled | The pack loader we'll build on, but: `MOD_DATA_FILES` is the generator's files only, `MOD_GAME_VERSION = "0.21"`, `MOD_BASE_ERAS` are our eras, roots are `../mods` |
| `setup` | 420 | tangled | Fills the sim from data, but its unit types come from race recipes and `gen/pricing`: the engine's unit type is today "a priced recipe" |
| `start` | 577 | tangled | The match start: rules, starting units and the bots' config, read through our rules files' shape |
| `modes` | 180 | tangled | Fortress and Siege are code; a mode is a start hook |
| `generator`, `pricing`, `identity`, `heroes`, `effect_words`, `balance`, `swap` | 1,586 | game | The race generator and everything round it: prompts, parts, prices, bonuses, heroes, balance by fights, a race swapped mid-match |

### src/view: composer, bakers, voxel builder (5,802 lines)

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `voxel` | 1,015 | engine | Reads `data/voxel/` only. The best example of where everything is going |
| `baker`, `world_bake`, `geom`, `rig3d`, `node` | 2,026 | engine | The rasteriser, the building and prop baker, voxelizing for the checks, the 3D rig, the scene graph |
| `art` | 164 | engine | `ART_SCALE`, `ART_BASE`: engine constants |
| `part_bake` | 614 | tangled | The parts-on-sockets bake: tied to `parts.json`'s slots and cut rules; one creature by name |
| `unit_view` | 1,739 | tangled | The composer reads the recipe format (slots `hand_r`, `back`, `torso`, gaits like `hop`), and bakes a test rat. The old drawing path the voxels replace |
| `corpse` | 199 | tangled | Lays down composed bodies by `parts.json` poses |
| `stage` | 45 | game | Stages `data/later/` concepts |

### src/model: models in code (13,290 lines)

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `base`, `kit`, `glb`, `flat`, `grng`, `models` | 1,092 | engine | The model kit (`blob`, `rod`, `slab`, materials), `.glb` loading, the lookup by part id |
| `mods_active` | 4 | engine (generated) | Written by `mods_gen.lobster` |
| `units`..`units5`, `kit_bodies`, `heroes`, `bears`, `siege`, `carts`, `buildings`, `buildings2`, `build_mats`, `props`, `town_props`, `trees`, `bridges`, `old_bugs` | 12,194 | game | Content written as code. Units are leaving for voxel data; buildings and props stay code for now and ship prebaked (D-185) |

### src/game and src/game.lobster: UI, lobby, the loop (10,563 lines)

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `ui` | 473 | engine | The widget layer, its look from `data/ui.json` |
| `pad`, `touch`, `perf`, `audio`, `order_marks`, `ruin`, `doodads`, `levels` | 1,186 | engine | None to speak of: input, the frame budget, the sound player from `data/audio.json`, order marks, ruins |
| `ground`, `fx` | 920 | engine | The terrain shader (from terrain data) and combat effects (to become voxel effect recipes, backlog 00) |
| `pack`, `pack_data`, `bake_missing`, `voxel_units` | 838 | tangled | The art pipeline: reads parts and recipes; `voxel_units` reads the recipe's body and parts |
| `panel`, `topbar`, `techtree` | 1,676 | tangled | Generic RTS panels with our ideas in them: the culture's crest on the frame, the age badge, the Wonder clock, the tech tree's rows as ages |
| `paths`, `town` | 802 | game | Each culture's paths, living towns: game view extras (UI hooks later) |
| `art_kit`, `art_kit_buildings` | 728 | game | The lists of our props and building looks |
| `lobby` | 1,329 | game | Title, battle setup, Race Lab, saves and network pages: the front end is the game's |
| `boot` | 31 | tangled | The boot screen: engine, with our icon and title in it |
| `game.lobster` | 2,658 | tangled | The window, camera, selection, orders, the minimap and the loop are engine; the lobby glue, the race swap, the playtest log and the self-test are game. It imports everything in one fixed order (116 imports) |

### src/net, src/placement, the tools (2,979 lines plus the tools)

| Files | Lines | Class | What tangles it |
|---|---|---|---|
| `net/lockstep`, `net/lan` | 319 | engine | The LAN answer says name, version, map; no pack list yet |
| `placement/geometry`, `projection`, `composite`, `case2d`, `deps` | 2,003 | engine | The rules are general; `deps.lobster` imports the game |
| `placement/cases`, `fixtures2d`, `fixtures3d` | 657 | game | Our races and the bugs Dominic caught in our units |
| `test_sim`, `save_check`, `net_check`, `path_audit`, `golden.lobster` | ~4,900 | engine (with game data) | Determinism, saves, network, pathing: engine tests, but run on our maps and races |
| `test_ai`, `test_2v2`, `race_matches`, `mass_battle`, `resource_audit` | ~2,100 | tangled | Test the reference bot on our content |
| `run_tests` | 886 | both | Unit tests of both sides in one file |
| `sheet`, `voxel_proto`, `mod_check`, `mods_gen`, `shards.sh`, `batch.sh`, `calibrate` | ~1,500 | engine tools | `sheet` and `mod_check` read our prompts and races |
| `races`, `balance`, `test_heroes`, `test_race_identity` | ~950 | game | The generator's tools and tests |
| `deck/build.sh`, `android/` | scripts | engine | Builds; they name the game, its icon and paths |

### data/ (20,157 lines of JSON at the top, plus maps, rules, voxel)

The schemas are engine (each file says `"schema": "aow.<name>/<n>"`); the content in them is game. Split by who reads
it:

| Files | Lines | Read by | Class |
|---|---|---|---|
| `terrain`, `resources`, `maps/`, `audio`, `ui`, `bridges`, `siege_shots`, `animals`, `modes`, `tips` | ~600, maps 1,426 | the sim and view | engine schema, game content |
| `buildings`, `tech`, `ai`, `rules/` | ~3,800 | the sim and bots | engine schema, game content; not yet moddable (backlog 00) |
| `voxel/` | 6,646 | the voxel builder | engine schema, game content |
| `parts`, `creatures`, `families`, `palettes`, `lexicon`, `cost_curves`, `groups`, `uniques`, `heroes`, `creature_kit` | ~17,000 | the generator | game: the parts kit is Age of Anything's idea, not the engine's |
| `later/` | 6,341 | concept sheets | game, staged |

### What this adds up to

- About half of `src/` is engine already, or nearly: the sim, pathing, net, bakers, voxel builder, model kit, input,
  sound, the widget layer (roughly 25,000 of 53,000 lines).
- About a quarter is clearly game: the generator, the models of our units and buildings, the lobby, the art lists
  (roughly 16,000).
- The tangles are few and shallow. The real ones are: buildings known by name in the sim and bots (18 lookups), the
  unit type defined as "a priced race recipe" (`gen/setup`), the one ability kind in code, the fixed list of data
  files mods can touch, and `game.lobster` holding both the loop and the game's glue.

## 3. Target structure

### One repo, two folders (for now)

```
engine/                      the RTS engine (its name, once picked)
  sim/                       lib/ today: the tick, systems, commands, fog, flow fields
  bots/                      the reference bot (bot, eco_bot, land, expand, scout, walls_ai), reading roles
  core/                      json, sha256, rng, packs (gen/mods grown up), scenario, save mechanism, gen_reset.py
  view/                      baker, world_bake, voxel, rig3d, geom, node, art; ground, fx, ruin, order marks
  ui/                        widgets (game/ui), pad, touch, audio, perf, the loop and camera from game.lobster
  model/                     the model kit: base, kit, glb, flat, grng
  net/                       lockstep, lan
  tools/                     sheet, placement rules, mod_check, voxel_proto, golden runner, shards, batch
  build/                     deck, android
  packs/test/                a tiny pack the engine's own tests run on (a flat map, a worker, a spear, a hub)
  tests/                     test_sim, save_check, net_check, path_audit on the test pack
games/age-of-anything/
  pack.json                  the game's manifest (kind "game")
  data/                      today's data/
  gen/                       the race generator, pricing, identity, heroes, balance, swap
  model/                     our units', buildings' and props' models
  ui/                        lobby, Race Lab, the panel and top bar's game parts, paths, town life, art lists
  hooks/                     our rule hooks (the web, the Wonder, Fortress and Siege) and UI hooks
  golden/, tests/            golden files, placement cases and fixtures, generator tests, bot matches
  main.lobster               the game's program: imports the engine, then the game
mods/                        as now (mods_private/ gitignored)
assets/                      split later; the game's art, audio and fonts first
```

Why one repo: one commit can change the engine and the game together, the golden files keep both honest, and there's
one batch. Lobster takes extra import folders (`--import RELDIR`), so `games/age-of-anything/main.lobster` can import
`engine/` modules without copying. Separate repos only when there's a reason: a second game, an outside modder who
needs the engine without our content, or the engine going public under a different licence from the game.

### Packs: one format for the game and for mods

A pack is a folder (in development) or a zip (to share), with a manifest. Today's `mod.json` grows into it; the loader
accepts both names for a while.

```json
{
  "id": "age_of_anything",
  "kind": "game",
  "name": "Age of Anything",
  "version": "0.22.0",
  "engine": "0.1",
  "depends": [],
  "load_order": 0,
  "data": "data",
  "models": [ "model/units.lobster" ],
  "hooks": { "rules": [ "hooks/web.lobster", "hooks/wonder.lobster" ], "ui": [ "ui/town.lobster" ] },
  "check": { "rules": "default", "prompts": [ "sewer rats", "romans" ] }
}
```

- `kind`: `game` (one per match; it brings the front end and the defaults) or `mod` (depends on a game or other mods).
- `depends`: ids with a version (`"age_of_anything@0.22"`); a missing or wrong one refuses the pack with the reason,
  as the mod loader refuses today.
- Merging: as `gen/mods.lobster` does for parts now, over every data file (buildings, tech, ai, audio too), in load
  order then id; an entry with the same id replaces, `"remove": true` takes one out, `"extends"` copies and changes.
- The hash: sha256 over the pack's sorted file paths and their bytes (data, hooks, models, audio; not renders or
  docs). The signature `id@version#hash` already goes into race keys; the same string is what a lobby compares.
- Multiplayer: the host's pack list (in load order, with signatures) is in the LAN answer and the lockstep handshake
  (`src/net/lan.lobster`, `src/net/lockstep.lobster`); a joiner with a different list is refused with which pack
  differs. Every install ships every official pack (`docs/business.md`'s "the host owns it"), so era packs never
  split a lobby.
- Saves record the pack list; loading without one of them is refused with its name; a save from before packs loads
  as the base pack alone (D-141).

### How a game declares itself

A game is a pack of kind `game` plus its `main.lobster`: the engine's loop with the game's front end and its unit
source. The engine asks the game for one thing it can't do itself: the match's unit types. Today that is
`gen/setup.lobster` reading race recipes priced by `gen/pricing`. The seam: the engine takes a plain unit type table
(stats, cost, armour class, tags, line, its look's id) and builds the sim from it; Age of Anything fills that table
from its generator; a game without one lists its unit types in data. Buildings, tech, resources, terrain and maps
already reach the sim as data.

The bots read **roles**, not names: `buildings.json` gives each building the roles it plays (`hub`, `housing`,
`farm`, `drop_off:<resource>`, `trade`, `barracks`, `defence`, `wonder`), and `match`, `trade`, `animals` and the
bots look buildings up by role.

### The hook API

Hooks are Lobster functions in a pack's hook files, compiled in at start. `mods_gen.lobster` already writes
`model/mods_active.lobster` to chain the mods' model builders; the same step writes a `hooks_active.lobster` that calls
each pack's hooks in load order. Plain generated calls, no lookups by name in the hot loop, so the cost is a function
call where a hook exists and nothing where it doesn't.

Rule hooks run in the sim, in every machine's lockstep, and must be deterministic (integers, the sim's rng, stable
order, no clocks, no files). A first set, each from a case we have:

| Hook | Called | First user |
|---|---|---|
| `ability(kind)`: `use(p, ids, x, y)`, `tick()` | an ABILITY command; every tick | the web (`lib/abilities.lobster`) |
| `on_hit(attacker, target, damage) -> damage` | a blow or shot lands | sticky shots (slow on hit) |
| `on_death(unit, killer)` | a unit dies | carcasses (`lib/animals.lobster`) |
| `on_built(building)`, `building_tick(building)` | a building finishes; each tick for kinds that ask | pens, markets |
| `victory() -> winner or -1` | each second | no hub left; the Wonder clock (`lib/match.lobster`) |
| `start(mode)` | the match start, after the usual start | Fortress and Siege (`gen/modes.lobster`) |

A hook's own state lives in sim columns it declares (`hook_ints("web.ends")`), so `gen_reset.py` puts it in saves
and the state hash covers it.

UI hooks run on one machine only and may do as they like (floats, the view's randomness, no writes to the sim): draw
over the world, add to the panel and the top bar, react to an event with a sound or an effect. First users: living
towns (`game/town.lobster`), the culture paths (`game/paths.lobster`), the Wonder clock in the top bar.

`mod_check` is the sandbox: it refuses a pack whose hooks use file, network, clock or window builtins, applies
`test_sim`'s determinism lint to rule hooks (no floats, no `rnd`, no dictionary order), and runs a short match twice
with the pack to check the state hash matches. Shared races stay data only: a race key never carries code, only the
names and signatures of the packs it was made with.

### Tools that ship with the engine

- `sheet` (`src/sheet.lobster`, `sheet.sh`): concept and lineup sheets from a spec.
- `placement_check`: the rules and the 2D and 3D halves; each game brings its cases and fixtures.
- `perf`: the frame budget in the real window (D-188).
- `mod_check`: loads a pack or says why not, the sandbox above, placement on its units.
- `voxel_proto`: the voxel builder's sheet and contact check.
- `golden` and `shards`, `batch`: the golden-file runner and the test runner; the sections are each pack's.
- `gen_reset.py`: save and reset code from the sim's globals.
- Later: `pack` (`tools/mods/pack.py` grown up), `.vox` import and export (backlog 00).

### Builds

- **Development and code mods:** the JIT, as now (`./play.sh`). Mods' hooks and models join at compile time.
- **Mac and Deck:** ship Lobster's binary and the source (the Deck build does this today), so code mods work there.
- **Android:** `--cpp` (as `src/android/build.sh` does now), so data-only mods; a code mod needs a new build.
- **A release:** `--cpp` where speed matters, the JIT where code mods should work. Never `--mir` (D-182).
- The engine depends on Dominic's Lobster fork (`gl.draw_mesh`, `gl.buffers_made`, `gl.window_icon`, the GLES
  patches): pin the fork's commit in the engine, and offer the changes upstream.

### Testing

- **Engine side, on its own test pack:** determinism (`test_sim`, the source lint), saves across builds
  (`save_check`), lockstep (`net_check`), pathing (`path_audit`), the frame budget (`perf`), the placement rules'
  own fixtures, a golden file of the test pack's start.
- **Game side, on its content:** the golden files (races, starts, models, buildings, effects), the generator's tests
  (`test_race_identity`, `test_heroes`, race keys), placement on every unit, bot matches (`test_ai`, `test_2v2`,
  `race_matches`), balance.
- **Mods:** `mod_check` per pack; the sci-fi mod as the standing test that a mod can reshape the game.
- The batch stays one command for both.

## 4. Licensing and business

Nothing needs a licence until something is public; today nothing is (the repo has no licence file, so it's all rights
reserved). The options when it matters:

| Option | Licences | What it means for us |
|---|---|---|
| Open engine, closed game | MIT, Apache 2.0 (Lobster's own), or MPL 2.0 | Modders and other devs can read, use and fix the engine; the game's content, models, art, sound and generator stay ours. MPL is copyleft per file: changes to engine files come back, while our game files, compiled into the same program, stay closed |
| Copyleft engine | GPL (Spring and Recoil are GPL v2 or later) | Lobster compiles the game, its hooks and mods into one program with the engine, so a GPL engine would make the game's code GPL too. Spring's games are Lua loaded at run time, which is why GPL works for them. Doesn't fit a closed game |
| Source-available | our own terms, or a "free to read and mod, not to sell" licence, or one that opens after some years | Modders can see everything; we keep control. Less goodwill than a real open licence, and more to write |
| Closed for now | none | Decide before Early Access, when the Modding page goes up |

What `docs/business.md` implies:

- The money is the game and its era packs (premium, bought once). The engine isn't sold, and an open engine doesn't
  give away what's sold: the content is the product.
- Every install ships every pack's data ("the host owns it"), so a pack's data isn't secret anyway; ownership is a
  Steam check in the lobby. An open engine doesn't change that.
- Mods, the Workshop and race sharing stay free; a readable engine helps the modders, which is how the genre's games
  lived for decades.
- Someone could ship a game on an open engine. With a permissive licence that's allowed; with MPL they must share
  their engine changes. Neither costs us sales.

Third-party licences to keep straight either way: Lobster (Apache 2.0: keep its notice), SDL (zlib), the fonts
(Cinzel, OFL), and the JIT's libtcc, which is LGPL: check how the Deck and Mac builds link it before a release.

Claude's lean: keep it closed until the Modding page; then the engine under MPL 2.0 or Apache 2.0, and the game, its
content and its generator closed. Section 7 has the questions.

## 5. Migration steps

In order. Each is small, shippable on its own, and the game plays after every one. Steps 1 to 4 are backlog 00 and
help the game and its mods directly; 5 to 8 are the split itself. Backlog 00 waits for voxel units to be the default
(Dominic, 2026-11-03), and so does this. Efforts are rough, in working days of a session like today's.

1. **Roles, not names (1-2 days).** Give buildings their roles in `data/buildings.json`; `lib/match`, `trade`,
   `animals` and the bots look up by role; the bots' resource lists come from `data/resources.json`; `tech`'s
   "machine" and "mounted" become data. Done: `grep 'btype_named("\|bt_name\[' src/lib` finds nothing; `golden.sh`
   unchanged; `test_ai` and `test_sim` give the same matches tick for tick.
2. **Moddable buildings, tech, AI and sound (3-5 days, backlog 00).** `MOD_DATA_FILES` covers `buildings`, `tech`,
   `ai`, `audio` and the rest; entries can be removed or disabled; a mod brings its own `audio/` WAVs; the bots read
   what exists. Done: the sci-fi mod as Dominic described it (infantry only, a short tree, lasers, its own sounds)
   plays a bot match to the end; without mods the golden files are unchanged.
3. **Our content as the base pack (2-3 days).** `data/` loads through the pack loader as the game pack
   (`pack.json` beside it), not as a special case in `gen/datalib`; `mod.json` is read as `pack.json`. Done: the game
   plays, the batch passes, and either race keys are unchanged (the base pack's signature left out of them) or they
   change once with a decision entry and `golden.sh update` read through.
4. **Packs match in multiplayer and saves (1-2 days).** The pack list with signatures goes in the LAN answer, the
   lockstep handshake and saves; a mismatch is refused with the pack's name. Done: `net_check` refuses a mismatched
   pack and passes a matched one; `save_check` passes; a save from before this loads (D-141).
5. **The unit type seam (2-3 days).** Split `gen/setup.lobster`: the engine builds the sim from a plain unit type
   table; the game's `race_to_types` fills it from races. Done: golden starts unchanged; a test builds a match from a
   unit type table in data with no generator.
6. **Hooks, first set (5-8 days).** `mods_gen.lobster` writes `hooks_active.lobster`; the web, the Wonder clock and
   victory, Fortress and Siege move out of `lib/` and `gen/modes` into the base pack's hooks; hook state is declared
   and saved; `mod_check` gets the builtin refusal and the lint; living towns become the first UI hook. Done: every
   match tick for tick as before (`test_sim`, `test_ai`, golden starts); a test pack with a clock call or a float in
   a rule hook is refused; `perf` within budget.
7. **The folders (2-3 days).** One mechanical commit: `git mv` into `engine/` and `games/age-of-anything/`,
   `--import` for the engine, `play.sh`, `batch.sh`, `deck/build.sh`, `android/build.sh` and `prebake.sh` follow.
   Done: `./play.sh` plays, the whole batch passes, the Deck build runs on the Deck, the APK runs on the emulator,
   `CLAUDE.md`'s layout and commands updated.
8. **The engine's own test pack (3-5 days).** `engine/packs/test/`: a flat map, a worker, a spear, a hub, a farm,
   drawn with plain voxels. The engine tests run on it alone. Done: `engine/tests` pass with no game content present.

Then, after Dominic picks: the name in the boot screen and credits, licence files, `engine/README.md`, and
`docs/modding.md` split into the engine's pack format and the game's parts kit (about 1 day).

In all, about 4 to 6 weeks of sessions. Steps 1 to 4 could come before the demo build (`docs/business.md`: December
to January) if modding is to be in it; 5 to 8 can wait until after Next Fest without costing anything.

## 6. Risks, and what not to do yet

**Engines and games drift apart.** Spring's history: its biggest games carried their own engine changes, an engine
change could break a game nobody was testing, the Lua API grew until the games depended on its accidents, and in the
end the most active game's developers forked the engine (Recoil). What keeps us out of that: one repo; the game is
the engine's main test and runs in the same batch; the golden files; no engine release with its own version promises
until someone outside depends on it.

**One game makes for guessed abstractions.** With one game it's easy to build an engine shaped like what we imagine a
second game needs, and be wrong. The rule: draw a line only where something real already needs it: the sci-fi mod
(buildings, tech and sound mergeable), the test pack (the engine runs without our content), the web and the Wonder
(hooks). No hook without a user in the base pack or a mod.

**Determinism.** Hooks are the first code that isn't ours to run in lockstep. Rule hooks: the lint, the builtin
refusal, the twice-run hash check in `mod_check`, calls in load order, state in declared columns. The sim's existing
state hash every 30 ticks catches what slips through, but only as a desync in a match, so the checks come first.

**Saves outlive builds (D-141).** Every step changes what's saved: roles, pack lists, hook columns. Each step's "done"
includes loading a save from before it. A hook's columns are padded with 0 like any other (`pad_saved_columns`); a
removed hook's columns are ignored on load.

**The Lobster fork.** The engine leans on Dominic's fork of Lobster. Pin it, keep the changes small, offer them
upstream; never `--mir` (D-182).

**The demo comes first.** The business plan has the Steam page, the demo and Next Fest in the next months. The split
mustn't hold any of them up: steps 1 to 4 make the game better on their own; the rest waits.

**A change of rule to write down.** `docs/design.md` §9 says mods are data only, with no scripts in shared content.
D-190's hooks change the first half: installed packs carry code. The second half holds: a shared race is data only and
never brings code. That needs its own decision entry when hooks start.

Not yet:

- Separate repos, or a public engine release.
- A runtime script (the Lua-like options in backlog 00): only after the compiled-in hooks have users.
- A general entity system, a new scene graph, or rewriting the sim's columns: the sim works and is fast.
- Renaming identifiers across the code (`aow.*` schemas, `AOW_MODS`) to the engine's name: only when the name is
  picked, in one commit, if at all.
- Engine version numbers with compatibility promises, an engine website, or the Workshop.
- Moving the race generator into the engine: it's Age of Anything's idea.

## 7. Open questions for Dominic

1. **The name.** One of Creel, Pincer, Ballast (or the others), or none until it's needed?
2. **One repo now, separate repos later** (when a second game or the engine going public calls for it): agreed?
3. **The licence.** Closed until the Modding page, then the engine open (MPL 2.0 or Apache 2.0) and the game closed?
   Or source-available, or closed for good?
4. **When.** Steps 1 to 4 straight after voxel units are the default (before the demo, if mods are to be in it), 5 to
   8 after Next Fest?
5. **Race keys.** Leave the base pack's signature out of race keys (keys unchanged), or let it in (every key changes
   once, and changes again with every content update)?
6. **The bots.** Is the reference bot the engine's (reading roles, working for any game) or the game's?
7. **The test pack.** Fine for the engine to have its own tiny, plain-looking content to test on?
8. **Shared code in mods.** Agree that installed packs may carry hooks while a shared race stays data only (a new
   decision over `docs/design.md` §9)?
9. **The Lobster fork.** Offer `gl.draw_mesh`, `gl.buffers_made`, `gl.window_icon` and the GLES patches upstream?
10. **"Made with"** on the boot screen and in the credits once there's a name, and an engine section on the website
    only once the engine is public?
