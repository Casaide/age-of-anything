# The Lobster the game runs on

Goal: one clean fork branch, every change committed, each one proven needed by the game and sorted into
"our bug" or "Lobster's bug". Audit of 2026-11-04. "Evidence" is what has actually been measured so far. Numbers in full: `performance.md`.

## Why it's unclear today

- `~/Dev/lobster/bin/lobster` can't be rebuilt from any commit. It has `gl.window_icon` and `parsed_tokens`, which exist
  only in a stash, and its file date is older than the stash's date.
- The game calls `gl.window_icon` (`src/game.lobster:1910`, uncommitted), so a checkout of the game's commits plus
  the fork's commits doesn't describe what's running.
- Android runs a further change on top: `src/android/lobster_android.py` patches a copy of the engine at build time.
- The branch is 8 commits behind upstream, including #467's `--mir` fixes.
- Local `master` isn't upstream's, and the fork's `master` is different again.

## What's in it

| # | Change | Where it is | Game uses it | PR | Our bug or Lobster's? | Evidence |
|---|---|---|---|---|---|---|
| 1 | Buffer pool | `lsp-index`, `gl-pooled-buffers` | Yes, indirectly | #468 | Lobster's (macOS waits on buffer delete) | Game: work about 29 ms to 2 ms, from a test build. Worst case 133 ms to 3.5 ms |
| 2 | `gl.draw_mesh` | `lsp-index` | Yes, 9 files | None | Partly ours: we made a mesh per shape per frame (D-188) | Work 13.7 ms to 3.3 ms, 1,500 buffers a frame to 0. Against pooled `gl.polygon`: not measured |
| 3 | `gl.buffers_made` | `lsp-index` | Only `game/perf.lobster` | None | Test tool | None |
| 4 | `gl.window_focused` | `lsp-index`, `window-focused` | `game/pace.lobster` | None (you said don't) | Missing feature | Match in the background 13-19% to 4.7% CPU |
| 5 | Frame sleep | `lsp-index`, `frame-sleep` | Yes, every frame | None (you said don't) | Unknown | Context switches 2,100 to 1,400 a second, no heat measurement |
| 6 | `gl.window_icon` | Stash only | `game.lobster`, uncommitted | None | Missing feature | None |
| 7 | LSP, `--index`, `--warn-unused` (13 commits) | `lsp-index` | Not at runtime | #459 | Tooling, shouldn't be in the game's build | n/a |
| 8 | `parsed_tokens`, lexer logging | Stash only | No, old formatter only | #466 | Goes with the old formatter | n/a |
| 9 | ReadTexture on GLES | `lobster_android.py`, `gles-read-texture` | Android bakes | #473 | Lobster's | Not tested on the emulator |
| 10 | Touch position | `lobster_android.py`, `android-touch-position` | Android | #472 | Unknown | Emulator test inconclusive |
| 11 | Touch without delay | `lobster_android.py` only | Android | None | Unknown: the game may read `gl.button` wrongly (`touch.lobster`) | No reproduction yet |
| 12 | SDL3 Android template | `android-gles-touch-sdl3`, game's own `android/sdl` | Android | #469 | Lobster's | Runs `dragtest` on the emulator |
| 13 | `gl.text_list` | `text-batching` | No | #471 | Not needed if #1 lands | 200 texts: 1.0 ms with the pool alone |
| 14 | Formatter | `lobsterfmt-parser` | Tooling | None yet | Tooling, shouldn't be in the game's build | See `lobster-prs.md` item 10 |

## How each change gets decided

Start from upstream master alone, and add one change at a time. A change stays only if removing it breaks something.

- macOS: `tests/batch.sh --quick`, then `play.sh ... perf:20` for frame time, plus a match watched.
- Android: build, install on the emulator, start a match, bake a new race, tap and drag. Device if the emulator can't tell.
- Result for each: needed or not, on which platform, with the numbers, and whether the fix belongs in the game or upstream.

## Target layout

- A branch `game` on the fork: upstream master plus only what passed, one commit per fix, however big that fix is
  (Dominic, 2026-11-04). The message has to say enough to split it into several commits or PRs for Lobster later: what
  each part does, why, how it was checked, and how the parts depend on each other.
- A branch for a PR gets made from upstream master when one is wanted, one change only.
- `lobster_android.py` goes: its patches become commits, or game fixes.
- This file stays the record: every line in `game` has a row saying why it's there.
