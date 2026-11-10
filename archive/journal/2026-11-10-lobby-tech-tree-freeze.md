# 2026-11-10: The lobby's tech tree stops hanging the game

**Milestone:** none (a bug, #430)
**Who:** Dominic found it; Claude (Claude Code) fixed it

## What happened
Dominic clicked **Tech tree** on a side panel of the Prepare for Battle page and the game stopped answering. It
wasn't a loop: the page's first frame baked every look of every building of the race's architecture in one go
(`bake_buildings_for`, with the progress frames switched off), 310 frames for the Romans' stone buildings. Timed on
the Mac with the main checkout's bakes, it took 122 s; with nothing baked, 143 s. No frame was drawn and no event read
in all that time, so macOS called the window unresponsive.

It bites whenever the architecture isn't in `bake_cache/` at the screen's density. The shipped `baked/` is at the base
density (and was still at BAKE_VERSION 21), and since #358 the Mac bakes at 2.4, so the shipped bakes never match
there. Any race you haven't played a match with yet hung the page.

Now the page takes one building a frame, starting after its first frame is drawn. When the bakes have the look, it
comes from them. When they don't, only the building's picture is made: its whole frame, with no stages or ruins, at
0.4 of the density, since the page shows it about 60 px across. The match's loader still bakes the full looks, with
its progress bar. Side by side with the full bakes, the pictures look the same at page size.

## Numbers
- The worst frame with nothing baked: 143,165 ms before, 558 ms after (the wonder; the castle 193 ms, the town centre 184 ms).
- At full density the wonder alone was 3.5 s, the castle 1.2 s and the town centre 1.1 s, so one look a frame wasn't
  enough. That's why pictures bake at the lower density.
- `perf_tree` in the batch (it runs alone, with the wall-time jobs): FAIL at 140,376 ms on main, ok at 563 ms with the fix, 12 s.

## Pictures
- `images/2026-11-10/106-lobby-tech-tree-romans.jpg`: the Romans' tree from the lobby, made with nothing baked
- `images/2026-11-10/107-lobby-tech-tree-frogs.jpg`: frogs with cheese hammers, forest buildings
- `images/2026-11-10/108-lobby-tech-tree-greeks.jpg`: centaur greeks

## Ideas parked
- `baked/` on the Mac is three bake versions old and at the wrong density for a 2.4 screen. A prebake at the screen's
  density, or one per density, would make the first match quick as well.
