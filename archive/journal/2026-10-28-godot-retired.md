# 2026-10-28: Godot retired, the game is Lobster

## What happened
Dominic set the goal: finish the move to Lobster, Godot gone, the tests fast. The art study's branch was merged and
its Godot changes ported to Lobster by area (models, destruction and effects, the composer), each held to Godot's with
the parity tools while Godot was still here. The Godot test suites were ported to Lobster in parallel. A full 2D
placement comparison on every race found Lobster shrinking its 4x renders with a box filter where Godot uses a bicubic
resize: thin legs vanished; with Godot's resize and its square frame the sprites came out within a pixel. The lobby
and its pages were ported last. Then the golden files were recorded, Godot deleted, and `tests/lobster_spike` became
`src/`.

## Decisions
- D-184: Godot retired; the game is Lobster (Dominic's goal). D-182/D-183 renumbered from 179/173 (the art study
  took those numbers).
- Howdah riders hold their weapons upright (Dominic).
- The batch runs 4 processes at once, not every core (Dominic: the fans).

## Bugs worth remembering
- The forest ram crashed the game's bake: a recursive quicksort on 100,000 almost-sorted triangles ran off the stack.
- Lobster units kept moving at a cell's starting terrain speed after it changed (a carcass in a swamp): found by the
  AI tests drifting from Godot's at tick 7339.
- Grouping triangles by a formatted string per triangle was half of every bake.
- Every match start re-baked 630 building frames (134 s): no cache for buildings; now cached.

## Pictures
- `archive/images/2026-10-28/10-lobster-title.png`, `11-lobster-battle-setup.png`, `12-lobster-team-setup.png` (the
  lobby in Lobster); `06-` to `09-` (destruction in Lobster).

## Ideas parked
- The leftovers in `docs/backlog.md` ("Left from the Lobster port"): the shared network lobby, lobby polish, the wall
  join check, a Mac and Windows build.
