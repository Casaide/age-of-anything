# 2026-10-31: a performance check in the real window, and the HUD's meshes

The laptop ran hot with the Lobster game (it didn't with Godot). The port's speed-ups had all been measured headless
(ticks, fights, bakes); nobody had measured the windowed game drawing its HUD. Earlier today a profile found `gl.text`
creating and deleting a GPU buffer per call, macOS waiting on each delete, and the game drawing 120 frames a second
on the ProMotion display; Lobster's a070621f pools those buffers and the game caps itself at 60.

## What happened

- **The check.** `./play.sh lobby "races:sewer rats|romans" watch mute perf:20` plays a watched match in the real
  window, vsync on, the Town Center selected (its panel and queue drawn), and after 4 s of warm-up measures 20 s:
  each frame's work (from `gl.frame`'s return to the next call: everything but the swap's wait and the cap's sleep),
  the frames a second, and the GPU buffers each frame made (`gl.buffers_made`, new in Lobster). It fails above a
  budget (`src/game/perf.lobster`) with exit code 1. It's in the full `tests/batch.sh`, run alone once the other
  suites are done, since it measures wall time.
- **What it found at once.** Even with the text fixed, a frame made about 1,500 GPU buffers: every UI fill, line,
  painted rect, minimap shape, portrait and icon, and every batch of sprites, was a `gl.new_mesh` drawn once and freed
  (two buffers, and the same delete macOS waits on). Work a frame 13.7 ms median, 18.4 ms 95th: 81% of the main
  thread at 60 fps.
- **The fix.** Lobster got `gl.draw_mesh`: `gl.new_mesh`'s arguments, drawn at once from the pooled buffers
  (textures from `gl.set_primitive_texture`). The UI (`game/ui.lobster`), the minimap, the panel's portraits, the top
  bar's icons and the sprite batch (`game/pack.lobster`) draw with it. Now 3.3 ms median, 4.6 ms 95th, 0 buffers a
  frame, 21% busy. The match and the lobby look as before (picture 12).
- **The check checks itself.** With the frame cap taken out it fails ("116.6 frames a second, over 66"); before the
  `draw_mesh` change it failed on the work and the 1,500 buffers.

## Decisions

- D-188: the windowed perf check and its budgets (6 ms median, 9 ms 95th, 66 frames a second, 0 buffers a frame).

## Pictures

- `12-hud-drawn-from-the-pool.png`: a match with the HUD drawn by `gl.draw_mesh`, the same as before.

## Ideas parked

- The budgets are the MacBook's. The Deck would want its own numbers (a perf run there, then a second set).
- The check needs the display awake: with vsync on and the display asleep no frame comes, and the batch's 240 s
  timeout fails it.
