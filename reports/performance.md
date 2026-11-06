# Performance: everything found, in its current state

For review by another agent. Written 2026-11-04 from the journals, decisions, `reports/playtest-check/heat-notes.md` and
PR notes. Numbers are copied from those records. Where a number has no measurement behind it, it says so.

**The complaint:** Dominic's MacBook (M4 Max) runs hot playing the Lobster game, and it didn't with Godot. It's still in
`TODO.md` as of today, after everything below. **Is it fixed? Not known:** nobody has re-checked since the ground cache,
and the Godot comparison was never measured.

## How to measure, and how it misleads

| Tool | Sees | Doesn't see |
|---|---|---|
| `./play.sh lobby "races:sewer rats\|romans" watch mute perf:20` | Main thread's work per frame, fps, buffers made, phases | **GPU load**. It passing says nothing about heat |
| `tools/perf/pw.c` (`clang -framework CoreFoundation pw.c -o pw; ./pw 20`) | GPU and CPU watts from the energy counters, no sudo | Only whole-machine effects of other apps if any run |
| `ioreg -r -d 1 -c IOAccelerator` | GPU utilisation | **Misleading: it scales with the clock.** It barely moved (25% to 22%) on a change that halved the watts |
| `top -pid` | Process CPU | Includes background baking |

Traps: one build measures up to 2x apart between runs (which cores macOS gives it), so compare turn about. A locked screen
draws no vsync'd frames. Other sessions keep the machine busy. `perf:` budgets are the MacBook's; the Deck and phones have
none. The `text` budget of 0.1 ms currently fails with 0.12 ms, on the old and new Lobster alike.

## What was found, and what happened to it

### Lobster's fault: fixed on our fork, PR open or none

| Finding | Fix | Measured | Where |
|---|---|---|---|
| `gl.text`, `gl.polygon` etc. made and deleted a GPU buffer per call; macOS waits on the delete | Buffer pool | Game, about 168 draws a frame: work 27.6-30.2 ms to 0.9-2.4 ms. Worst case, 1,000 draws: 132-135 ms to 3.5 ms. 200 `gl.text`: 25.9-32.7 ms to 1.05-1.23 ms | `game` branch; aardappel/lobster#468; issue #1. Timings from a test build, macOS only |
| No focus query, so a window in the background drew at 60 | `gl.window_focused`, 10 fps in the background | Watched match in the background 13-19% to 4.7% CPU | `game` branch; no PR; issue #3 |
| Frame cap sleeps in 1 ms steps | One long sleep, then finish | Context switches: match 2,100 to 1,400 a second, title 1,650 to 800. Same fps. No heat measurement | `game` branch; no PR; issue #4 |

### Ours: fixed in the game

| Finding | Fix | Measured | Where |
|---|---|---|---|
| 120 fps on the ProMotion display | Cap at 60 | Not recorded alone | game, 2026-10-31 |
| About 1,500 GPU buffers a frame: every UI fill, line, icon and sprite batch was `gl.new_mesh` drawn once and freed | `gl.draw_mesh` (needs Lobster; issue #2) | Work 13.7 / 18.4 ms to 3.3 / 4.6 ms (median / 95th); 81% busy to 21%; 0 buffers a frame | D-188 |
| Sprites took 50 draws, each a texture of its own | Atlas pages | About 10 draws. Work 1.9 / 2.3 to 1.1 / 1.5 ms with the next row; busy 12% to 7%; CPU 12.1% to about 10% | D-194 |
| A button is about 20 fills, order marks a draw per segment | `ui_batch` | In the row above | D-194 |
| The idle title cost nearly what a match did | 30 fps, then 15 after 2 s idle | CPU about 9% to 3.5%, then 6.2% to 4.7% on a busier machine | D-194 |
| An edged label is six `gl.text` calls | Text atlas pages (`game/text_cache.lobster`) | Text 0.24 to 0.03 ms a frame then (0.12 ms today, see open items); panel 0.36 to 0.21 ms | D-197 |
| Terrain shader runs per pixel at 60 fps though only water moves | Still ground is a texture, 15 Hz for water | GPU 2.06-3.11 W to 0.95-1.30 W | D-209 |

Ground share, same window, camera still, GPU watts:

| Mode | GPU W |
|---|---|
| Live (before) | 2.06, 3.11 |
| Cached, 15 Hz water (shipped) | 0.95-1.30 |
| Cached, 2 Hz | 0.62 |
| No ground | 0.41 |
| Cached, redrawn every frame (why a moving camera draws live) | 3.95 |

### Looked needed, wasn't

- **`gl.text_list`** (aardappel/lobster#471, issue #10): the slowness was the buffer churn. 200 labels: `gl.text_list` without
  the pool 1.00-1.24 ms, `gl.text` with the pool 1.05-1.23 ms. The game doesn't call it.

## The state today, 2026-11-04

Clean `game` branch against the old binary, same game, one run each, turn about, `perf:20`:

| | Old binary | `game` branch |
|---|---|---|
| fps | 59.7 | 59.7 |
| Work, median / 95th | 2.4 / 5.6 ms | 2.3 / 5.3 ms |
| Busy | 20% | 19% |
| Buffers a frame | 0 | 0 |
| Text | 0.12 ms | 0.12 ms |

One run each, with no watts measured. It shows the branch isn't worse, nothing more.

Phases on the `game` branch (ms a frame): input and sim 0.17, ground 0.5, collect 0.47, sort 0.03, sprites 0.55, over the
world 0.15, panel 0.9, hud 0.49.

Work has grown since 2026-11-03's 0.8-1.1 ms median, and text since 0.03 ms, though those runs were on a different game state.

## Not answered: check these

1. **Is the laptop still hot, and how does it compare with Godot?** Never compared. The most important open question.
2. **67-71% GPU first seen, 25% in later runs.** Unexplained. Window size differs (3024x1834 against 2582x1834), and baking may
   have been running.
3. **A moving camera draws the ground live**, so 2-3 W returns whenever the camera pans. Not measured over real play.
4. **Memory:** 1199 MB to 1315 MB in 12 s, not checked whether it levels off.
5. **Baking a new race:** 5 W of CPU for about 30 s. Parked as the biggest burst.
6. **Work went up:** median 0.8-1.1 ms to 2.3 ms, panel 0.21 to 0.9 ms, text 0.03 to 0.12 ms. Not investigated. May be voxel
   buildings, new UI, or machine load.
7. **`build_wear` makes a map-sized texture and `build_fog` a new mesh every 10 ticks** (`src/game.lobster:834`). Not measured.
   These are GPU allocations the 0-buffers check may not count.
8. **Skip the 15 Hz ground when no water is in view:** about 0.6 W by the 2 Hz row. Not done.
9. **The title's hill mesh is rebuilt every frame** (`ui_paint_poly`). Parked.
10. **Is the text atlas still needed now that the pool exists?** `gl.text` costs about 6 µs with the pool, but an edged label is
    six calls and a screen has many. Not measured against the atlas since the pool.
11. **Is `gl.draw_mesh` needed in that form?** Wouter asks whether pooled `gl.polygon` and friends now suffice. Most of the 17 calls
    need per-vertex colour or texture. Batches as pooled `gl.rect_tc_col` against `gl.draw_mesh` not measured.
12. **Android and the Deck:** nothing above was measured there. Their budgets don't exist, and phone GPUs may care about draw
    calls where the M4 doesn't. That's the remaining case for `gl.text_list`.
13. **The occasional macOS loading cursor** (`TODO.md`). May be a stall, not looked at.
14. **The pool on the Lobster side:** the timings came from a test build, not the exact PR branch, and macOS only.
15. **Which single change matters most for watts?** Only the ground was measured in watts. Everything else is CPU or context
    switches.

## For the reviewer

Check whether the conclusions follow from the numbers, whether anything measured in `archive/journal` or `archive/decisions.md` is
missing here, and what's the cheapest next measurement. Sources: `archive/journal/2026-10-31-the-perf-check.md`,
`2026-11-03-the-laptop-still-ran-hot.md`, `2026-11-04-ground-cache.md`; D-188, D-194, D-197, D-209; `reports/lobster-prs.md` items
2, 3, 8, 9, 12; `reports/playtest-check/heat-notes.md`; `src/game/perf.lobster`.

## Big battles (2026-11-06, #169)

Zoomed out (`zoom:1`), `reveal`, everything baked, two-sided on `open_field`, MacBook. Before formations and with them:

| Units | Work median / 95th | Sim a tick (median) | Busy | FPS |
|---|---|---|---|---|
| 258, no formations | 2.4 / 4.2 ms | 0.4 ms | 17% | 59.5 |
| 998, no formations | 5.2 / 9.3 ms | 1.5 ms | 34% | 59.1 |
| 2000, no formations | 12.0 / 22.3 ms | 3.3 ms | 71% | 55.2 |
| 2000, formations | 7.3 / 11.6 ms | 2.2 ms | 47% | 58.4 |

Formations made it cheaper: fewer shoves between units, and a tighter crowd to resolve. The march and a whole battle are in the last row (120 s).

**The lag Dominic saw was baking, not units.** With bakes on, a frame's "input and sim" was 9.8 ms against 0.2 ms: a PNG save 114 ms on average (181 ms at worst), a cell 8.5 ms (up to 20 ms), a fill's end 12 ms (up to 38 ms). Bakes now keep out of a fight and of a match of 300+ units, unless a unit is waiting on the look.

**The layout is already data-oriented.** Units are parallel flat int arrays (`u_x`, `u_y`, ...), no per-unit objects in the sim, and separation is on a grid. A DOTS-style rewrite has nothing to win there. What's left is per-sprite work in Lobster, not memory layout:

| What | Cost at 2,000 units | Idea |
|---|---|---|
| Sprites: 18 pushes a quad, 4,000 quads (shadows are half) | 2.5 ms (up to 6.5 ms in a crush) | Prebuilt index list; cheaper shadows zoomed out |
| Collect: a class per drawable, four dictionary calls a unit | 2.2 ms | A pool of drawables; unit columns instead of dictionaries |
| Sim tick | 2.2 ms median, one frame in three | Not the limit |

Tried and dropped: sorting sprites into depth bands by sheet to batch them. No gain on the main thread (6.9 ms against 6.5 ms): draw calls aren't the cost. GPU load wasn't measured (`perf:` can't see it).

**Still open:** a first match with a new race bakes on the main thread outside fights, about 22 ms at the 95th percentile at 250 units. Moving bakes to a worker or a separate process is the real fix.

To film: `./play.sh lobby "races:norse frogs|centaurs" map:open_field watch skirmish reveal army:107 zoom:1` (first run of a new race pair: about 45 s on the loader).
