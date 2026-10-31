# 2026-10-31: the skipping walk, the chop, and the match start drawn huge

Dominic played on the Mac: "humans look a bit like they're skipping when they walk. Tunic looks a bit like a dress.
And when using axes animation is too slow, and the axes rotates OUT of their hand." And: after starting a game he
saw "parts of the UI zoomed in super huge" for a few seconds.

## What happened

- **The zoomed start.** A part baked inside a frame (the on-demand bakes in a match's first seconds) leaves Lobster
  on the screen again but with the bake texture's projection (`SwitchToFrameBuffer(nil)` doesn't set 2D mode back),
  so the rest of the frame was drawn scaled up from the corner, the food counter filling the window, until the bakes
  ran out. `bake_wanted_tick` now calls `gl.ortho()` after baking. Found by dumping frames from inside the game (the
  Mac's screen capture refused). Pictures 01 (the bug) and 02.
- **The skip.** The body rode the lowest foot on screen. In 3/4 view the near foot always stands lower on screen than
  the far one, so the body rose about 2.7 px whenever the far foot carried it: one step low, one high. `planted` now
  measures each foot against its own standing line; the placement check's B5 walking rule the same way.
- **The chop.** Up for 60% of a 0.9 s swing; on the way down the arm hung low while the axe turned, and towards or
  away from the camera the axe turned flat in the picture though the swing was in depth. Now 0.6 s, up for 35%, down
  through the arm held out ("thrust") into the blow, the axe turned only as far as the view is side-on. Sheets got a
  `work:<job>,<facing>` column. Picture 03.

## Decisions

- The balance fights at load stay (D-170): the first round still finds half the lines or more over 10 points off.
  Offered Dominic: keep prices by race key, and fight while the setup page is open.
- The tunic is a look change: concepts first, not done yet.
