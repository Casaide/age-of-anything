# 2026-11-10: Creel gets its own repo

## What happened

Dominic asked for the engine to be split out now, so his next game can use it, with the atmosphere pass that went in today. Creel
is now `Casaide/creel`, public, and this repo takes it as a submodule at `creel/` (#428).

Which files are engine was settled by compiling. A program that imports only the candidate files, in the game's import order, either
compiles or names what it's missing. The first cut is 79 files, about 23,400 lines. Three small things had to move so those files
don't name the game: `ui()` and `mouse_px()` went from `game.lobster` into the widget layer, `strip_edges` from the heroes into the
JSON file, and the pack loader now calls `packs_loaded`, which the game defines, in place of the game's `id_load`.

The game finds Creel through one line at the top of each program, `import from "../creel/src"`. Lobster treats that folder as part
of its search path for imports, `read_file` and `scan_folder`, so the source lint in test_sim, `gen_reset` and the tests that read
source files all kept working without a change.

Later the same day the view followed (#433). Compiling `game.lobster` section by section against Creel alone showed the knot
was smaller than it looked: team colours, the ground mesh, what the view remembers, drawing the world, selection and orders, the
marks, the HUD and the minimap, about 1,500 lines, call only nine of the game's functions (wall tile names, paths, town life,
cracks, the top bar, the HUD's scale). Those sections are now three files in Creel, imported where the code was, and
`game.lobster` went from 3,136 lines to about 1,630. The voxel unit drawer moved too, once it stopped reading the `army:` option.
Still here: the frame loop with its options, the panels, pad, touch and cursors.

## Decisions

- D-248: its own repo, public, Apache 2.0, a submodule here, fresh history there.

## What's left

- `game.lobster` still holds the frame loop and every option. Until that moves, a new game copies that part.
- The panels, pad, touch and cursors lean on each other and on our crests and age badges.
- The engine's tests still run here, on our content. Creel has only a compile check.
- The Deck and Android build scripts were changed for the new folder but not run.

## Funny moments

- The first run of the tests after the move passed with nothing moved: `git rm` had refused over three edited files, and the rest of
  the command carried on without it.

- `banner` and `typing` moved to the top of the import order and at once shadowed locals in our models and lobby.
  Lint said so; `banner` stayed where it was.

## Pictures

None: nothing visible changed.
