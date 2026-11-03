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
