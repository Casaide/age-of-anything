# 2026-10-16: The bake stops freezing the screen

**Milestone:** 20 (Steam Deck and controllers), a bug from the Deck
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic, on the Deck: the UI freezes while the army generates (the lobby's bake, the match loader). On the Mac it was
no better, just faster: a cold match bake (two races, nothing on disk) ran ~35 s at a median frame of 75 ms, p95
180 ms, worst 1.2 to 1.4 s, every frame over 25 ms (`tests/bake_frames.gd`, new: times every frame of a cold bake
with the loader up, and can dump everything baked to compare runs with `tests/bake_compare.gd`).

Where the time went: all the image work between renders (pixelize, ground shadows, cutting parts by their bodies)
ran pixel by pixel in GDScript on the main thread; every render was read back with `get_image`, which waits for the
GPU (25 to 75 ms for a 2048 px building frame); a whole set of props, a building's stages, or a war beast's body were
built in one go; and the bake clock took its "hidden window" budget (500 ms a frame) whenever a frame was slow, which
the bake's own slow frames were. D-143 has what changed.

After (same machine, quiet): ~29 to 31 s, median 8.3 ms, p95 12 to 15 ms, worst ~120 to 250 ms, 50 to 110 of ~3200
frames over 25 ms. The art matches: parts, buildings, props and rigs differ from HEAD only by GPU noise (a few
pixels by a few levels; HEAD differs from itself too).

## Decisions
- D-143: the bake's main-thread work is budgeted, image work goes to threads, reads are asynchronous; models are
  built on the main thread (on a thread the game hung, twice).

## Bugs found on the way
- The hidden-window check fed itself: a slow bake frame made it think the window was hidden, so the next frame
  took 500 ms, which looked hidden again.
- Portraits weren't still: stopped before they were in the tree, the units started animating again on `_ready`,
  so a portrait's pose (and its crop) depended on how long the loader's frames took.
- A war beast's body was built 32 times per race, once for each leg of each walk step.

- Quitting mid-bake crashed the exported build (signal 11, found by the Deck-build session: 3 to 5 crashes in 10
  cold quits; the code before D-143 quit cleanly 10 of 10). A bake now waits for budget between building a model
  and putting it in the tree, so models built but not yet placed were never freed; and a bake waiting on a frame
  was woken during shutdown and went on building with freed nodes. Now `BakeClock` frees what it built that never
  reached the tree, waits for its worker tasks, and once the game quits its waits never return. 16 cold quits clean.

## Not done (follow-ups)
- The worst frames left are the GPU's: forcing a 2048 px building frame with 8x MSAA and ambient occlusion
  (20 to 60 ms, more the first time a material is drawn). Four building bakers also hold ~1 GB of render targets.
- Not yet felt on the Deck: the build from this session is the check.

## Funny moments
- The first thread-built models hung the game at 13% on the loader. The fix for the freeze froze it harder.
