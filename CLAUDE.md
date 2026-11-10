# Age of Anything

A classic-style 2D RTS where your civ is whatever you can describe. Type "centaur romans" or
"sewer rats with cheese hammers" and the game builds a race from a parts kit, prices every unit fairly,
and you play a normal classic RTS match with it. Silly is fine; broken is not. Cost is the balancer.

Written in [Lobster](https://github.com/aardappel/lobster) (it was Godot/GDScript until 2026-10-28, D-184), 2D. Solo dev,
macOS and the Steam Deck.

| Doc | Read it for |
|---|---|
| `docs/design.md` | What the game is and why: races, generation, modes, balance, multiplayer, art |
| `docs/mvp-plan.md` | The 10-minute demo: scope, cut list, architecture, milestone overview, metrics, risks |
| `docs/milestones/` | One file per milestone: plan, checklist, results, changes. Status lives here |
| `docs/research.md` | Technical reference and sources (lockstep, pathing, Holepunch bridge) |
| [Issues](https://github.com/Drache93/age-of-whatever/issues) | The backlog, bugs and upstream Lobster changes |
| `docs/roster-template.md` | Full building, age and unit-line plan, with MVP/Next/Later status |
| `docs/rendering.md` | How the art is made: models (code and Blender), 8-facing bakes, worn armour, buildings, checking tools
| `docs/milestones/lobster-port.md` | The move from Godot to Lobster: what was ported, how it was checked, what's left |
| `docs/audio.md` | How the sound is made: the offline synth (`src/audio/`), effects, creature voices, the theme in stems by age |
| `docs/movement-charts.md` | How to show a movement fix: before/after path charts from a headless scene, frame strips and traces from a real match |

Before starting a milestone, read `docs/milestones/<its file>.md` (and the related parts of
`docs/mvp-plan.md`), write the plan into the milestone file, and keep its checklist current. If you postpone something,
open an issue labelled `backlog` rather than deleting it.

## Issues, commits and pushes (Dominic, 2026-11-04)

Things were getting out of hand: uncommitted work, overlapping engine changes, nothing to say why. These are not optional.

**Issue first.** Everything we implement gets a GitHub issue before any code is written, saying the problem, the plan and how
we'll know it's done. Find or open it first; a fix found while working gets its own issue. The backlog is issues (`backlog`), and
so are bugs (`bug`). Commit messages name the issue (`#12`), and close it when it's actually done, with the evidence in it.

**Commit.** Commit each tested piece straight away, by file name, so nothing sits uncommitted: `git status` is clean at the end of
every task. Run `src/lint.sh` and the piece's tests first. Scratch goes in `.gitignore`d places, never left lying around.

**Push.** Lint and the quick batch gate every push and merge (`./tests/batch.sh --quick`, lint is in it), at the end of each piece of work. The whole batch runs
once on `main` after a merge, not before each push. A change that could cost frame time also runs `./tests/batch.sh only=perf,perf_big` first. Never force push (one exception: rebasing
the Lobster fork's `master` onto upstream, below). The fork's `master` is pushed with every commit to it, since the game can't be
rebuilt without it.

**Lobster.** The game builds only against the `master` branch of `Drache93/lobster` (the fork), checked out in `~/Dev/lobster`
and tracking `fork/master` (Dominic, 2026-11-06, #256; the old `game` branch is retired):
- **Before any Lobster change**, `git fetch origin fork` and check both: `git status -sb` reads `## master...fork/master` with
  nothing ahead or behind (all our work is pushed), and `git log --oneline master..origin/master` is empty (we have all of
  upstream). If upstream moved, rebase `master` onto `origin/master` first, rebuild `bin/lobster`, run the quick batch, and push
  with `--force-with-lease` (the one allowed force push). Stop and report if anything is unpushed or uncommitted.
- It's upstream master plus one commit per fix, however big, with a message detailed enough to split it into several commits or PRs
  later. `bin/lobster` is always built from a clean checkout of it. No stashes, no uncommitted changes, no patching the engine in a game build.
- Every change to Lobster has its own `upstream-lobster` issue here, opened first and separate from the game issue that needed
  it: what it does, whether it's Lobster's bug or ours, the evidence, and the plan to take it upstream (its PR once open).
  `reports/lobster-fork.md` gets a row for it in the same piece of work. The game issue and PR link to it.
- Before changing Lobster, prove the fault is Lobster's and not our code. Reproduce it without the game if you can, measure with and
  without the change, and keep it only if removing it breaks something. A workaround in the game may be the right fix.
- Only what's validated stays on `master` (Dominic, 2026-11-04): if we aren't sure it's needed, it comes off until we are.
- A PR upstream only for what's committed on the fork's `master` and tested with our game (Dominic, 2026-11-04): no loose files, nothing that
  has only been tried on its own. Each PR is then made on its own branch from upstream master, one change only.

## Creel, the engine, is its own repo (Dominic, 2026-11-10, #428, D-248)

The engine is `Casaide/creel` (public, Apache 2.0), here as the git submodule `creel/`, pinned to a commit. After a clone:
`git submodule update --init`. Its `src/` has the same folder names as ours (`lib`, `gen`, `view`, `model`, `game`, `net`, `audio`,
`testkit`), and every program in our `src/` starts with `import from "../creel/src"`, which puts it on Lobster's search path:
`import lib.world`, `read_file("lib/world.lobster")` and `scan_folder("lib")` all find Creel's files. A new program needs that line too.

- **Which repo a file is in:** a module that compiles without the game is Creel's (`creel/check.sh` proves it); what names our content
  or `game.lobster`'s state is ours. Never keep a file at the same path in both: ours would hide Creel's.
- **An engine change** is made in `creel/` on a branch there, with its issue and PR in `Casaide/creel`, tested here by the batch
  before it's pushed. The game's PR then moves the submodule to the merged commit (`git add creel`), stacked on nothing: Creel's PR
  merges first. Never point the submodule at a commit that isn't on Creel's `main`.
- **Creel is public.** Nothing of the game's content, no private notes, and the Originality rules below apply to it in full.
- `creel/docs/roadmap.md` has what's still to move (the frame loop and the panels) and the lighting to-do.
- **The view is Creel's too (#433):** the controls' shared state (`game/view_state`), the world's drawing (`game/world_view`,
  `world_draw`, `voxel_units`), selection, orders, marks and the minimap (`game/controls`) left `game.lobster`, which imports them
  at the places the code was. What they call of ours: `akb_tile_name`, `akb_wall_tile`, `refresh_paths`, `on_path`, `collect_town`,
  `draw_town`, `draw_cracks_of`, `draw_topbar`. A global that moves earlier in the import order can shadow a local in a
  file imported after it; lint catches it.
- **Panels are ours, the kit is Creel's (Dominic, 2026-11-10):** the top bar, command panel and tech tree are this game's UI and
  stay in `src/game/`. What they're drawn with is Creel's `game/hud_kit` (`hud_s`, `tb_icon`, `tb_text`, `tb_flush`, `tb_plaque`,
  `hud_box`, `hud_button`, `hud_well`, `groove`, `hud_bar`, `wrap`, `cost_row`, `tip_card`). A new drawing helper that names
  nothing of ours goes there; a panel never does.

## Status

- **The game is Lobster (2026-10-28, D-184).** The Godot game was ported whole (sim, bots, generator, models, bakers,
  composer, UI, lobby, network, saves, pad) and held to it tick for tick, triangle for triangle and draw list for draw
  list, then retired: `src/` is the game, `./play.sh` plays it. The golden files (`src/golden.sh`) keep what the
  parity checks proved. See `docs/milestones/lobster-port.md`; what's left of it is in the issues.
- **In progress (milestone 23): fidelity** (D-173): art baked at 2x (`ART_SCALE` 3.0 in `src/view/art.lobster`, the world
  in the old art pixels, `ART_BASE` 1.5), heroic 5.5-head humans; destruction in baked stages with pixel dust and
  fading ruins (D-171, D-172); rat B and frog B (D-177, D-178, D-181); every legged body walks on keyed legs baked per
  step, blows wind up and hold (D-179); units baked at their drawn size, capes only when asked (D-180); howdah riders
  hold their weapons upright (Dominic, 2026-10-28). Open: the items in `docs/milestones/m23-fidelity.md`.
- **Done but for Dominic's looks (milestone 24): voxel buildings and props** (D-203, D-208): every building, stage, wall,
  gate and prop is its 3D model voxelized through `view/voxel_mesh.lobster`; the old baker is gone. Left: a separate
  agent's art review, and the hand-built looks culture by culture (Dominic's, backlog). See
  `docs/milestones/m24-voxel-buildings.md`.
- **In progress (milestone 20): Steam Deck and controllers.** Pad play (last input wins, the reticle, the wheel of
  orders: D-132, D-133); Deck builds by `src/deck/build.sh`. Next: steps 7-9 (fit, speed, Steam Input). See
  `docs/milestones/m20-steam-deck.md`.
- **In progress (networking): multiplayer.** Lockstep over TCP on the home network (`src/net/`), Play on the network in
  the lobby (Host, Join by LAN beacon); next the Mac vs Deck match, then a HyperDHT sidecar. See
  `docs/milestones/networking.md`.
- **In progress (milestone 22): battle feel.** Formations by role, counter-aware targeting, attack lines, the Norse
  shield wall (D-155); next race_matches and Dominic's match. See `docs/milestones/m22-battle-feel.md`.
- **Waiting on Dominic:** his first match in the Lobster game, the Deck play-test, the Mac vs Deck match, a listen to
  the sound (`docs/audio.md`), a look at the bears (`docs/concepts/bears/`).
- **Done or closed (history: each milestone's file in `docs/milestones/`):** race generation (m0), the sim core (m1),
  map and movement (m2), economy (m3), combat (m4), the art rework (m5), foundations (m6), progression (m7), AI and
  match flow (m8), fog and juice (m9), playtest and balance (m10), cleanup (m11), the land tech tree and maps (m12,
  m15), unit lines (m13), race identity and heroes (m14), sieges (m16), living towns (m17), the UI (m19), modability
  (m21), save and load (D-140 to D-142), sound (`src/audio/`, 2026-10-11), bears (D-161 to D-163).

## Layout

```
archive/         development history: journal, decisions, timeline, screenshots
data/            the data contract; mods are just more of this
  parts.json       every part: slot, shapes, sockets, stats, tags, points, era, cost_mix, legs (poses), body_steps
  creatures.json   creature -> body + head + skins + favoured families (+ fused_mount, draw_scale, crew_back)
  families.json    cultures/styles: cloth colours, mounts, name parts, the UI's look
  palettes.json    skin palettes, fixed material colours, team colours
  lexicon.json     word -> creature/mount/family/tags/size; out-of-era words + playful notes
  rules/*.json     host rules: era bounds, point budgets, roster template, cost/train curves, economy
  cost_curves.json fixed-point cost curves (per-mille by points)
  creature_kit.json creature-kit skeletons (the bears); data/later/ holds staged, unplayed data
  terrain.json     terrain types: walkable, colours, resource + amount + what it turns into when used up
  audio.json       buses, every sound's takes / bus / gap / voices, the music mixes by age
  ui.json          the UI's directions (materials, colours, crest, banner cut)
  buildings.json   building types: footprint, hp, cost, build time, pop, drop-off, what it trains, roles (D-192)
  tech.json, ai.json   ages, research, line upgrades; the bots (levels easy, normal, hard)
  maps/*.json      maps: ASCII rows + legend into terrain.json, start tiles
  voxel/           the voxel units: bodies, gear, holds, materials, the part-to-gear rules (a mod adds its own);
                   bodies/siege.*.json written by src/voxel_engines_gen.lobster; buildings/ an experiment (not loaded)
creel/           the engine (a git submodule, Casaide/creel): the sim and bots, packs, the voxel builder, drawing, net, the synth
src/             the game, in Lobster, on Creel (the lib/, view/, net/ named below are in creel/src/, as are parts of gen/, model/, game/); run everything from here (paths are ../data, ../assets)
  game.lobster     the game: the window, the match, the view, input; game/ its pieces (lobby: title, battle setup,
                   Race Lab, saves, network, the loader; panel, topbar, tech tree, pad, town life, fx, ground, art kit)
  lib/             the simulation: integers only, a fixed 20 Hz tick, driven only by commands (no randomness but its
                   rng, no floats, no clocks: test_sim lints it); fog, flow fields, combat, economy, sieges, walls,
                   the bots (bot, eco_bot, land, expand, scout)
  gen/             races from prompts (generator, pricing, identity, heroes, datalib, rng), the match start (setup,
                   start, modes), saves (save, reset: written by gen_reset.lobster), balance by fights, mods
  view/            the voxel units' builder (voxel: bodies, gear and engines from data/voxel/, baked in 8 facings),
                   the buildings' and props' voxelizer (voxel_mesh), the bake settings (bake_cache), art.lobster
  model/           the buildings', props', trees' and bridges' 3D models in code (units are voxel bodies)
  net/             lockstep over TCP, the LAN beacon
  deck/build.sh    the Steam Deck build (Lobster built for Linux in a container)
  android/         the Android build: build.sh, the activity, SDL's Java side, Lobster's engine patched for GLES and touch
  baked/           the buildings and props, baked once by prebake.sh and shipped (not committed; read before bake_cache/)
  golden/          the golden files: races, starts, every building, research text
  bake_cache/      baked voxel units, buildings and props (not committed; emptied when BAKE_VERSION changes)
assets/          SVG icons and textures, audio (rendered), fonts
tests/           batch.sh (the tests side by side), sheets/*.json (concept sheet specs), mods/ (bad-mod fixtures)
mods/            mods (docs/modding.md): data + Lobster models; scifi_test is the example. mods_private/ is gitignored
tools/           mods/ (new_mod.sh, pack.sh), perf/, deck/pull_lobster.sh
```

## Commands

Lobster on this Mac: `~/Dev/lobster/bin/lobster`, from the fork's `master` branch (alias it as `lobster`). Run programs from `src/`. No Python: tools are Lobster programs or shell (#114).

```sh
./play.sh                                                          # the game: the title screen (Battle the AI, network, saves, Race Lab)
./play.sh lobby "races:sewer rats|romans" watch mute               # straight into a match, the bot playing you too, silent
./play.sh lobby page:setup mute shot:/tmp/s.png at:2               # a capture (page:title|setup|lab|saves|net|boot; shot: after at: seconds)
./play.sh lobby windowed                                            # in a window (the game starts fullscreen; Cmd/Alt+Enter switches, #223)
./tests/batch.sh --quick                                           # unit tests, the sim, the AI's quick checks, the voxel units' checks (~30 s)
./tests/batch.sh                                                   # the whole batch side by side (adds every AI piece, 2v2, golden, prices, saves, network, perf)
./play.sh lobby "races:sewer rats|romans" watch mute perf:20        # the drawing's cost in the real window (vsync on), fails over budget (game/perf.lobster; in the batch, alone)
./play.sh lobby mods:big_battle                                    # 2,000 units on the framed field: filming (mute perf:90 to measure; perflive with the bakes on)
lobster run_tests.lobster                                          # the unit tests (~3 s; part:i/n)
lobster test_sim.lobster -- [part:a,b] [shard:i/n]                 # the sim: determinism, tick time, every system (~30 s serial)
lobster test_ai.lobster -- [map] [quick|piece:<name>|levels] [shard:i/n]   # the AI: scenario checks and whole bot matches
lobster test_2v2.lobster                                           # four bots, a 2v2 match
lobster test_formations.lobster                                    # big armies in formation, headless: drift, jitter, facing, overlap, the framed map
lobster test_movement.lobster -- [scene ...]                       # group moves, headless: sway, reversals, facing, overlap, settling (#345; in the batch)
lobster test_heroes.lobster; lobster test_race_identity.lobster
lobster voxel_check.lobster -- [report]                            # the voxel units' art: knees, skins, kit, look-alikes, specks; must pass before a unit change is shown
lobster voxel_proto.lobster -- <out.ppm> [creatures|legs <body> [gear,..]|skins|deaths|animals|engines|check]   # sheets of voxel units; check: feet on their shadow
./golden.sh [update] [section]                                     # races, starts, models, buildings, effects held to golden/ ("update" after a meant change, then read the diff)
lobster save_check.lobster -- [map]; ./net_check.sh [ticks]        # saving and loading; two processes in lockstep
lobster races.lobster -- default "centaur romans" "flying greeks with wings"   # races as JSON
lobster balance.lobster -- rr 2                                    # equal-cost round robin in age 2 (auto: prices from fights)
lobster race_matches.lobster -- reed_meadow; lobster mass_battle.lobster -- 2; lobster resource_audit.lobster -- reed_meadow; lobster path_audit.lobster
./shards.sh <tool.lobster> [args] [jobs=N]                         # any sharded tool side by side
./gen_reset.sh                                      # after adding a sim global: reset and save code
./textures.sh; ./icons.sh                                          # SVG textures and icons as PNGs (rsvg-convert), after one changes
src/deck/build.sh                                                  # the Deck build (podman machine `aoa-build` running)
src/android/build.sh                                               # the Android APK (build/android/age-of-anything.apk; adb install -r it)
src/prebake.sh                                                     # every building and prop baked once into src/baked/ (the builds ship it, D-185)
./render_audio.sh [sfx|voices|music|<name>...]                     # re-render the sounds into assets/audio
tools/mac/make_app.sh                                              # build/mac/Age of Anything.app, marked as a game so Game Mode turns on (play.sh runs it; #224)
tools/mods/new_mod.sh <id> [--era <tag>] [--private]       # scaffold a mod (docs/modding.md); tools/mods/pack.sh <id> zips it
```

Never pass `--mir`: it miscompiles model and rig code (D-182). Lobster's window never takes Ctrl-C; `play.sh` stops the
game for it. A Lobster leak report at exit (`memory_leaks.txt`) is noise.

**Format and warnings** (Dominic, 2026-11-03): every Lobster file is in `lobsterfmt`'s layout and every program
compiles with no warnings. `./lint.sh` checks both (`--fix` formats; in the quick batch); run it before a commit.

**Performance:** everything found so far is in `reports/performance.md`. `perf:` can't see the GPU: heat is measured in watts with `tools/perf/pw.c`.

**Testing rhythm** (Dominic: iteration must stay fast, and the machine quiet). While working: `run_tests` after every
change to `data/` or `src/`, the piece you're touching (`test_sim -- part:<name>`, `test_ai -- piece:<name>`,
`voxel_check`), or `./tests/batch.sh --quick`. After a merge to `main`, the whole batch once, in the
background. The batch runs 4 processes at once by default (`jobs=N` or `AOA_JOBS`), not every core. One heavy run at a time on this
machine, across every worktree and session (`src/machine_lock.sh`): a whole batch or `shards.sh` waits for the `full` lane, saying who holds it; `--quick` and
`only=` take the `quick` lane, so checking a change never waits for a whole batch, and only the perf stage holds both. Each run
keeps its results in its own folder, and a job with no result fails the table. Each shard is its own seeded world, so results match a serial run. The tick-time check measures wall time:
on a busy machine it can fail. Raise `BAKE_VERSION` (`view/bake_cache.lobster`: buildings and props) once for a batch of bake changes, not
per tweak: every raise rebakes everything. Tests are silent (`mute`, and every capture option mutes). Look at a
screenshot after visual changes. After a change to `src/audio/`, re-render and commit `assets/audio/` with it.

## Rules that matter

**Determinism is the backbone** (lockstep multiplayer and shareable races depend on it):
- Same prompt + rules + reroll must give the same race key on every machine. Tests enforce this.
- Never use `randi()`/`randf()`/`RandomNumberGenerator` in generation or the sim. Use `gen/rng.lobster` (and the
  sim's own rng). The only exception is cosmetic view effects (town life, fx).
- Iterate anything that affects output in a stable order (sorted ids or arrays), never raw
  Dictionary order from untrusted sources.
- Recipes hold only strings and ints. The race key hashes names + recipes, not derived stats.
- Saves outlive builds (D-141): a new sim or AI variable must make sense in a match loaded from an older save. A field a save
  lacks loads empty, per-unit and per-building columns are padded with 0 (`pad_saved_columns`); anything else whose
  empty value is wrong mid-match needs its own fix after `load_world`. Run `./gen_reset.sh` after adding a global.
- The sim (`src/lib/`): integer maths, a fixed 20 Hz tick, driven only by the command stream. The AI issues commands
  like a player. Views read sim state; the sim never draws.

**Data first.** New creatures, gear, cultures and words go in `data/`, not code. If you need code
for a content case, the data contract is probably missing a field; add the field.

**Balance through cost.** Every part has `points`; unit cost grows superlinearly
(`rules.cost.curve`, a fixed-point table in `data/cost_curves.json`). Counter tags (infantry > spear > large/mounted > ranged > infantry,
and skirmishers > archers) make even absurd units beatable; each pair wins at equal cost (test_sim's counter checks). Prices are
calibrated offline (`src/calibrate.lobster`, D-195, D-199): a line pays for its neutral fights, not its counters' edge. Don't
special-case silly units.

**Generator behaviour to keep:**
- Unknown words are ignored with a note; missing creature -> a random one "volunteers".
- Out-of-era asks get a substitute plus a funny note (WW2 -> saucepan helmets). Bad
  interpretations are part of the fun; keep notes honest and playful.
- Signature gear (roman, greek, viking, cheese) is only favoured when asked for (or by the race's
  family/creature, e.g. rats like cheese). Wings only appear when asked. A winged race doesn't ride unless asked to
  (then rider and mount both have wings); "pegasus" gives only the mount wings.
- Roster: worker, spear, skirmisher (non-bow ranged, beats archers), archer (bows), large.
- Large units: a mount if available; giants only for creatures where that reads well
  (`giant_ok`); otherwise "Heavy" armoured elites. Centaurs are already mounted, so they go Heavy.
- Cultural knowledge ("romans" -> legionaries) is the generator's known gap. The plan is culture
  templates, then an LLM brief expander, both post-MVP (see backlog). Don't hack it into code.

## Art direction

Target the look of a **classic 2D isometric RTS**: small units, 3/4 view, painterly sprites, readable
silhouettes, team colour on a consistent region. It should feel like the game you know, gone mad.
Units are **voxel bodies** (D-201) made from data (`data/voxel/`: bodies, gear, holds, materials, the
part-to-gear rules; a mod adds its own), baked in **8 facings** standing, walking, working, attacking and
falling, recoloured by a team-mask shader; props and buildings are their 3D models voxelized (D-203). The pipeline is in
`docs/rendering.md`, "Voxel units"; the craft is in the **voxel-art skill** (`.claude/skills/voxel-art/`: know the
subject, show it cleanly at game size, check, review). New art goes concept-first (options, Dominic picks, then
build; D-080), one creature at a time, and every change gets looked at close up and at game size before it's shown.
**No unit, mount, gear or pose change is shown until `voxel_check.lobster` and `voxel_proto.lobster -- - check`
pass** (Dominic, 2026-10-13 and 2026-11-03): standing knees, skins as drawn in every palette and look, kit that keeps
the creature's shape, no look-alikes, no specks, feet on their shadow. When he names a fault, first add a check that
catches it, then fix it.

## The archive (keep it up to date)

`archive/` records how the game grows: pictures, decisions, changes of direction, funny bugs.
It's for future AI sessions (the *why* behind the code) and for fun. See `archive/README.md`.

**Take pictures as you go, not just at the end.** Whenever something visible changes, capture it
straight away into `archive/images/<YYYY-MM-DD>/NN-name.png` (numbered in order within the day).
That includes:
- the first render of a new mechanic, view or map
- each milestone checklist step that changes what you see
- every memorable bug (bug shots are the best part; save the buggy capture before fixing it)
- the final state of a milestone

Capture tools: `./play.sh ... shot:<png> at:<seconds>` (a match, `look:<x>,<y>` for the camera; `page:<name>` for the
lobby's pages; `place:fort in_gate army:1`, `hurt:<percent>`; `lookframes:<arch>,<type> dump:<dir>`, `propframes dump:<dir>`) and `src/voxel_proto.lobster` (voxel units on a sheet).
Look at every capture before keeping it. As a rough guide, aim for at least 2-3 pictures per
milestone.

**Write things down as they happen too.** When a decision, a direction change or a funny bug
comes up mid-session, note it in the day's journal then, while the details are fresh.

At the end of any session that changed something meaningful (a milestone step, a new mechanic,
a direction change, a memorable bug), check that all of these are done:
1. **Pictures:** in `archive/images/<date>/`, as above.
2. **Journal:** add or extend `archive/journal/<YYYY-MM-DD>-<title>.md` using the template:
   what happened, decisions, direction changes, pictures, funny moments, ideas parked.
3. **Decisions:** append numbered entries to `archive/decisions.md` (next D-number). Never edit
   old ones; supersede them with a new entry.
4. **Timeline:** add one line to `archive/timeline.md`.
5. **Milestone file:** tick its checklist and record results in `docs/milestones/`.

Every milestone checklist ends with an "Archive" item, and a milestone isn't done until it's ticked.

The archive is append-only history. Write in plain words, with dates. Credit who decided what
(Dominic or Claude). Before making a design call, skim `archive/decisions.md` so you don't
undo a deliberate choice.

## Originality (legal hygiene)

We make a classic-style RTS. Genre mechanics (gathering, ages, unit lines, counters) are fair
game; everything expressive is ours. In code, data, docs, the archive and commit messages:
- Don't name or reference specific commercial games we're inspired by. Say "classic RTS" or
  "the genre". (Technical references to open-source projects in `docs/research.md` are fine.)
- Never use or recreate another game's art, UI layouts, icons, sounds, fonts, unit or civ
  names, or text.
- Don't write "copy", "clone" or "1:1". Describe what *we* want instead.
- No third-party franchises in shipped content. Fan mods stay private.
- The name "Age of Anything" is a working title (it was "Age of Anything" until 2026-10-12; the folder and
  repo keep the old name); trademark check before any public release.

## House style

- Small single-purpose files, no defensive programming: assert on broken data, don't paper over it.
- Lobster: globals declared before use; no identifier shadowing; a recursive function needs an explicit return type;
  no multi-line `def` signatures; braces in strings as `\{ \}`; `write_file` to an absolute path needs `(path, data, 0, 1)`;
  `dictionary.get` on a class value can't return nil (use a sentinel); `qsort_in_place` recurses (not on big near-sorted
  arrays). Imports live in the main programs (`game.lobster`, `game/deps.lobster`), in an order where each file's
  globals come before their users.
- Keep tests headless where they can be, silent, and fast.
- Shapes drawn every frame go through `gl.draw_mesh` (pooled buffers), never `gl.new_mesh` + `gl.render_mesh`: each
  new mesh is two GPU buffers, and freeing them makes macOS wait for the GPU (D-188; `perf:` catches it).

## Later (not now)

- Sharing races over P2P: race JSON as a Hyperblobs bundle, key = race key. Networking via a
  Bare/Hyperswarm sidecar over a localhost WebSocket, lockstep turns over Protomux (see design doc).
- Price-by-simulation: run headless fights vs reference units to set costs.
- Era packs: gunpowder, then a sci-fi "space federation" pack (a space-fleet sci-fi mod is the dream;
  official names/likenesses stay out of shipped content).
- Optional on-device model to expand prompts into briefs. Runtime stays deterministic either way.
