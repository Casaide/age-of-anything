# Milestone 16 concepts: sieges

| Round | Sheet | What |
|---|---|---|
| T1 | `siege_tower_t1.png`, `siege_tower_t1_sets.png` | siege tower directions (hide, open frame, belfry, the frogs' turtle) |
| W1 | `walls_w1.png` | wall tower, ladder and rubble looks |
| W2 | `walls_w2_sheet.png`, `walls_w2_*_3x.png` | bigger walls for sieges (below) |

## Round W2 (2026-10-13): walls for sieges

Dominic, after seeing the milestone: "the siege towers are too small, and I think we need to improve our
walls for siege, they're a bit buggy and overlappy, and not really big enough for what we're aiming for:
need to learn a bit from castle-building games and others. Less like the classic first-generation look."
What we take from those games is in `docs/milestones/m16-sieges.md` ("Walls for sieges"); the bugs that
were plain bugs are fixed already (same file, "The walls' bugs").

Each option is one walled corner at game scale: a run with a gatehouse in it, a run with a ladder against it,
towers on the corner and the ends, a diagonal stretch on to one more tower (A, B, C rats), defenders up on the
walkway and the towers (the game's own unit art), the attack (a siege tower docked with its gangway on the
walk, a ladder with a climber, attackers at the foot). The town is inside, up the screen. Each is built as
one 3D scene and baked once with the building baker, so these joins are the model's own; in play the pieces
would bake per tile and join as `tests/wall_join_check.gd` checks. **Nothing here is in play.**

| Sheet | |
|---|---|
| `walls_w2_sheet.png` | every option side by side at the game's scale |
| `walls_w2_now_3x.png` | now: the walls in play (after today's fixes) and the siege tower at its size in play, for scale |
| `walls_w2_a_3x.png` | **A thick**: a 2-tile-deep stone curtain, walkway 1.5 high (about 2.5 men) between an outer parapet of tall merlons and a low town-side parapet, round towers 2.4 across and 2.6 high, a gatehouse of two round towers over a 2-wide passage with a portcullis and drop holes |
| `walls_w2_b_3x.png` | **B tall**: a 1-tile curtain 1.7 high, square towers 2 across and 2.9 high with timber hoardings and tiled roofs, a square twin-towered gatehouse |
| `walls_w2_c_rats_3x.png` | **C per culture, rats**: A's shape in brick with tin patches, square towers with tin-roofed hoardings; rats defending, Romans attacking |
| `walls_w2_c_frogs_3x.png` | **C per culture, frogs**: an earth rampart 2.4 deep and 1.2 high with a stake breastwork and a plank walk behind it, mud drum towers with reed galleries and thatched cones; frogs defending |

In every option the siege tower is two storeys over the walkway (A: top 2.6 against a 1.5 walk) with a
gangway down onto it, on four wheels, hide-hung with timber braces showing; the ladder reaches just over the
parapet. Palisades stay as they are (light, early, no walkway).

Re-render with:
`godot --path . --audio-driver Dummy --always-on-top --script res://tests/wall_concepts.gd -- out_dir [now,a,b,c_rats,c_frogs]`

### Recommendation (Claude)

**A, with C's materials per culture.** A gives the strongest "this is a fortress" read at game scale:
the thick walk is a visible road with people on it, the round towers break the silhouette and rise a full
storey over the walk, the twin-towered gatehouse is the obvious place to attack and to defend, and a
2-tile curtain makes a breach a real gap a crowd pushes through. B's roofs are handsome but hide the
defenders on the towers and make the town read as rooftops; keep hoardings as an upgrade look (a "hoardings"
research: more pour, a sturdier tower) rather than the base. C shows the shape survives other materials: the
rats in brick and tin and the frogs' rampart read as theirs while the silhouette stays A's, so every culture
gets the same kind of wall (each architecture picks the material, not the rules).

### Sim implications (not changed: Dominic picks first)

- **Thickness.** A: wall pieces 2 x 2 tiles (a line snaps to even cells and is drawn as one thick run), towers
  2 x 2 (round ones drawn a little wider, standing proud of both faces), the gatehouse 6 x 2 (two towers and a
  2-wide passage). B: walls stay 1 tile deep, towers and gatehouse grow to 2 x 2 and 6 x 2. C: A's footprints.
- **walls.gd.** Unchanged in kind: a walkway is places per cell, so a 2 x 2 piece holds 4 cells x 2 places;
  the 8-way walk over walkway cells, the breadth-first path, `perch`, stairs on towers and gatehouses, the
  pour (from the gatehouse's drop holes) all carry over. A breach knocks out one 2 x 2 piece: two tiles of
  rubble wide, which suits crowds at a breach (the 3-wide gate passage becomes 2 wide).
- **Flow and lanes.** Walls are blocked cells as now; gates stay team lanes. Thicker walls only add blocked
  cells. Diagonal lines: as now, a diagonal step needs both corner cells open; with 2 x 2 pieces a diagonal
  run is a staircase of pieces that the art joins as one 45-degree stretch between towers (the W2 diagonal).
- **Height.** A's walk at 1.5 is about two of today's levels: on the wall a unit could count two high-ground
  steps (more reach and sight) or keep one; balance either way. Climb time on ladders and through siege towers
  should grow with the height (2 s now; about 3 s). The view lifts units by the piece's walkway height
  (`Models.WALK_H`, today's fix), so taller walls need nothing new there.
- **Siege tower.** Its sim size stays a unit radius; the docking distance (1.6 tiles of a walkway cell) works
  for 2-deep walls. Its art grows to two storeys over the walk (it must be clearly taller than the wall).
- **Cost and build time.** A 2 x 2 piece is four tiles of wall: price and hp per piece about four of today's
  (or a cheaper wall per tile, as thickness is the point). Towers and the gatehouse dearer and much tougher.
- **The modes on Siege Vale.** `Fortify.ring` lays a square ring at radius 9 (Fortress) and 10 (Siege) with
  3-tile gates in the middle of each side and towers every 6 or 8 tiles. With 2-deep walls the ring takes two
  rows: radius 10 and 11 (outer edge) keeps the town's room inside; gates become the 6-tile gatehouse centred
  on each side; towers at the corners and every 8 tiles (2 x 2 each). The west start's clear round is 12 tiles
  (`tools/maps/siege_vale.py`): enough for radius 10, one more tile (13) for Siege's 11, which needs the west
  start nudged east by a tile or two from the woods. The east start is an open camp (attackers may now build a
  palisade camp: the modes lift wall lacks); Fortress walls it too, and its ring at radius 9 already crosses the
  swamp at x 46-50 and leaves gaps there (rings follow the land): move the swamp a few tiles west or shrink
  Fortress's east ring. Every race gets the ring in both modes (`lift_lacks`, `Fortify.ring` ignores lacks).

### Questions for Dominic

1. A (thick), B (tall), or A with C's materials per culture (Claude's pick)?
2. Hoardings: part of the base look (B) or an upgrade you research?
3. Height in the sim: should a taller wall give more than today's one level of high ground?
4. Round or square towers for the stone cultures (A shows round; B and the rats square)?
5. The frogs' wall: an earth rampart with stakes (C), or the same stone shape in mud like the rats' brick?
6. Gate passage width 2 (as drawn) or keep 3?
