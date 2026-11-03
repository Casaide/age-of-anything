# 2026-11-03: the laptop still ran hot

Dominic: "my laptop still gets hot when playing the game ... we got it down from 60% to, I think, 30%. That's still
way too high." Claude measured where a frame's work goes and cut the draws.

## What happened

- **Where it goes.** `perf:` now prints a frame's work phase by phase (input and sim, ground, collect, sort, sprites,
  over the world, panel, HUD). In a watched match the sprites were 70 a frame in about 50 draws (every baked part,
  prop and building frame is a texture of its own), the rally line, its dashes and the selection ring were a draw per
  segment (0.5 ms on their own), and the panel and HUD drew every bevel and outline as its own draw (a button is some
  20 fills).
- **The fixes.** Sprites from shared atlas pages (D-194): 50 sprite draws became about 10. `ui_batch` gathers fills,
  lines and studs into one mesh until something else is drawn. Sprites wholly off the screen aren't collected. The
  lobby's pages draw at 30 frames a second and batch the same way; a minimised match keeps playing and draws nothing.
- **The idle title screen** cost nearly what a match did: 4 ms a frame at 60 a second, its armies a draw per part,
  each stud four circles. Now 2.8 ms at 30 a second.
- **Measured** against the build before (8e2153b), turn about, on the MacBook (M4 Max) with vsync:
  | | before | after |
  |---|---|---|
  | a watched match, work a frame (median / 95th) | 1.9 / 2.3 ms | 1.1 / 1.5 ms |
  | main thread busy | 12% | 7% |
  | the process's CPU, a watched match | 12.1% | about 10% |
  | the process's CPU, the idle title | about 9% | 3.5% |
- **Funny:** the same build measures up to twice as slow from one run to the next (which cores macOS gives it), and
  with the screen locked a vsync'd window never draws a frame at all, so the measures run turn about, and `novsync`
  measures a locked machine.

## Decisions

- D-194: the lobby at 30 frames a second, atlas pages for sprites, batched UI fills; the busy budget in `perf:`.

## Pictures

- `05-batched-hud-and-order-marks.png`: the order marks, rings, panel, top bar and minimap, drawn batched (the
  panel, top bar and minimap byte for byte the same as before).
- `06-title-at-30-fps.png`: the title screen, its studs and buttons batched.

## Ideas parked

- Text is the HUD's biggest cost now: an edged label is six `gl.text` calls. Text drawn once into an atlas page.
- A window in the background (not minimised) still draws at 60: Lobster has no focus query (`SDL_WINDOW_INPUT_FOCUS`,
  `SDL_WINDOW_OCCLUDED`); with one, a few frames a second when unfocused.
- Lobster's frame cap sleeps in 1 ms steps (`SDL_DelayPrecise`): about a thousand wake-ups a second.

## Later the same day: text, the idle title, a window in the background

Dominic: "We definitely can't have text slowing down the game." Claude took the parked ideas in turn, each measured
turn about against the build before (one run swings up to 2x, and other sessions kept the machine busy).

- **Text from atlas pages** (`game/text_cache.lobster`, D-197). Each distinct label (face, size, colour, edge, string,
  and where it falls inside a pixel, in 64ths) is drawn with `gl.text` once into a 1024 px page, premultiplied so the
  edge's five passes and the text composite exactly as they did on the screen, then drawn as one quad: a batch's labels
  are a draw a page. A label not on a page yet is drawn the old way that frame; at most 24 are packed a frame, so a
  number that changes every frame can't churn the pages; when four pages are full the least recently used one is
  emptied. The panel, top bar, lobby, tech tree and the control group numbers all go through it. A watched match's
  text went from 0.24 to 0.03 ms a frame (`perf:` now prints it and fails over 0.1 ms; `oldtext` measures the old way).
  The captures match the old text to within 2-5 levels of 255 (the premultiplied page's rounding).
- **Funny:** the one place the top bar still differed by 50 levels was the top row of "Mud Age". Not the cache: the
  font's own glyph atlas is rebuilt whenever a new character turns up, so the faint row a glyph picks up from its
  neighbour in that atlas depends on which characters had been seen when it was drawn.
- **The idle title at 15 frames a second.** Halving only the armies' updates saved nothing (their drawing, not their
  animation, is the cost), so the whole title page drops to 15 a second after two seconds without the mouse or the
  pad, and comes back to 30 on the first touch. The idle title 6.2% -> 4.7% of a core.
- **A window in the background at 10 frames a second.** Lobster had no focus query, so the engine got one:
  `gl.window_focused()` (SDL's input focus and occlusion flags). `game/pace.lobster` draws a window without the focus at
  10 a second; the sim steps for the time each frame took and lockstep's turns run 400 ms ahead, so the match and the
  network keep their pace (12 s of play reached tick 240 on time). A watched match in the background 13-19% -> 4.7%.
  Tests and captures (`mute`, `shot:` ...) keep their pace: a window started from a shell has no focus.
- **The frame cap's sleep.** `SDL_DelayPrecise` sleeps in 1 ms steps and spins at the end. The engine now sleeps most
  of the wait at once, stopping short by what long sleeps have overshot lately (macOS coalesces timers, by up to a
  third of the sleep for a background process), then lets `SDL_DelayPrecise` finish. Context switches: a match about
  2,100 -> 1,400 a second, the title 1,650 -> 800, the frame rate unchanged. Engine commits on `lsp-index`, and on
  branches `window-focused` and `frame-sleep` from `origin/master` for an upstream PR.
- **Measured** (old: e6f3a69 with the Lobster of Oct 31; new: today's), on a machine other sessions kept at a load of
  14 to 30, so the absolute numbers are higher than the morning's:
  | | before | after |
  |---|---|---|
  | text, a watched match (a frame) | 0.24 ms | 0.03 ms |
  | the panel's phase (a frame) | 0.36 ms | 0.21 ms |
  | a watched match, work a frame (median, quiet machine) | 1.0 ms | 0.8 ms |
  | the idle title, the process's CPU | 6.2% (7.8% loaded) | 4.7% (2.9% loaded) |
  | a watched match in the background | 13-19% | 4.7% |
  | context switches, a match / the title | 2,100 / 1,650 a second | 1,400 / 800 |

## Pictures

- `07-text-from-atlas-pages.png`: the top bar, the old text above, the text from pages below.
- `08-tech-tree-text-from-pages.png`: the tech tree page, its labels drawn from pages.

## Ideas parked

- Labels drawn inside a fractional `gl.translate` key on their own position only; none do now.
- The title's hill mesh is rebuilt every frame (`ui_paint_poly`).
