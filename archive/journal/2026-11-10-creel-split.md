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

## Decisions

- D-248: its own repo, public, Apache 2.0, a submodule here, fresh history there.

## What's left

- `game.lobster` still holds the window, camera, drawing and the match loop. Until that moves, a new game copies it.
- The engine's tests still run here, on our content. Creel has only a compile check.
- The Deck and Android build scripts were changed for the new folder but not run.

## Funny moments

- The first run of the tests after the move passed with nothing moved: `git rm` had refused over three edited files, and the rest of
  the command carried on without it.

## Pictures

None: nothing visible changed.
