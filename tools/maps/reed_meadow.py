#!/usr/bin/env python3
"""Builds the Reed Meadow maps (data/maps/reed_meadow*.json): the 1v1 and the first 2v2.

The look of the first Reed Meadow (flat_test): a swamp band running corner to corner between
the two starts, a pond with shallows in the middle, rock outcrops, reed beds, stone and gold.
Every feature is drawn for the north-west start and again turned half a turn about the
centre for the south-east one, so both starts get the same ground (rotational symmetry).

  python3 tools/maps/reed_meadow.py          # writes both maps, prints the ASCII and counts

Milestone 15, phase 5: high ground. A `heights` layer (digits 0-3; ramps are letters, `a`
climbing from 0 to 1, `b` from 1 to 2, `c` from 2 to 3). A cell lower than a neighbour it has
no ramp to is a cliff (src/sim/sim_map.gd: blocked to walkers), so a hill is climbed only by
its ramps; checked here with the same rule. The 1v1 has a ridge on each side of the middle
bridge (the bridgehead: archers on it cover the crossing), the 2v2 a two-level hill between
each team's bases and a lookout hill on every start's flank, over the fords.

Milestone 15, phases 2-3: forests (real trees: the north wood line behind each base, groves,
contested woods) and a river along the swamp band from corner to corner, deep for walkers
(amphibians swim it), with fords (mirror images) and timber bridges, so each side has the same
crossings. The pond gives way to the river.

  reed_meadow      64 x 64, THE 1v1 (Dominic, 2026-10-12: the large one was much too big for
                   1v1): tight, a long game's resources, a narrow stream with two fords and a
                   small bridge in the middle
  reed_meadow_2v2  88 x 88, the first 2v2 (it was reed_meadow_large): four starts, teammates
                   side by side on one half (starts 0 and 2 against 1 and 3; each odd start is
                   the half-turned image of the even one before it), each with the full kit,
                   the wide river with two fords and three bridges, contested stone, gold, food
                   and woods in the middle and on the flanks
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LEGEND = {".": "grass", ",": "swamp", '"': "reeds", "#": "rock", "~": "water",
          "b": "bugbush", "s": "stone", "w": "shallows", "g": "gold",
          "T": "tree", "R": "river", "f": "ford"}
AMOUNT = {"b": ("food", 150), '"': ("wood", 100), "s": ("stone", 450), "g": ("gold", 800), "T": ("wood", 100)}

# Animals per start (sim: src/sim/animals.gd). "size" places a herd: one animal on the ring,
# the rest beside it. On a map with "symmetry": "rotate" the south-east start gets the mirror
# image of the north-west one's animals, and each wild herd gets a mirror twin.
ANIMALS = {
    "near_start": [
        {"kind": "sheep", "count": 4, "min": 4, "max": 7},
        {"kind": "sheep", "count": 2, "size": 2, "min": 9, "max": 13},
        {"kind": "deer", "count": 2, "size": 3, "min": 11, "max": 15},
        {"kind": "boar", "count": 2, "min": 9, "max": 13},
    ],
    "wild": [
        {"kind": "deer", "herds": 2, "size": 3, "away": 18},
    ],
}


def rect(x0, y0, x1, y1):
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def line(x0, y0, x1, y1):
    """A wood line along an edge: a rect whose inner edge is ragged (horizontal if wider)."""
    out = []
    across = x1 - x0 >= y1 - y0
    for (x, y) in rect(x0, y0, x1, y1):
        along, depth = (x, y - y0) if across else (y, x - x0)
        last = (y1 - y0) if across else (x1 - x0)
        if depth == last and (along * 5) % 7 >= 4:
            continue   # notches in the inner row
        out.append((x, y))
        if depth == last and (along * 3) % 7 == 0:
            out.append((x, y + 1) if across else (x + 1, y))   # and a few cells poking out
    return out


def blob(cx, cy, rx, ry):
    """An ellipse of cells round (cx, cy)."""
    out = []
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                out.append((x, y))
    return out


def layout(size):
    """Features in the north-west start's frame: (char, cells). k scales positions from 64."""
    S = size
    if S == 64:
        sx, sy = 12, 12
        f = [
            # home: the big reed line along the north and west edges behind the base, and groves
            ("T", line(2, 2, 22, 4)), ('"', line(2, 5, 4, 22)),   # a forest behind the base, reeds down the side
            ("T", rect(17, 5, 21, 7)),
            ('"', rect(5, 19, 10, 21)),
            ('"', rect(24, 11, 26, 14)),
            ("b", rect(17, 11, 18, 14)),                       # 8 bug bushes
            ("s", rect(6, 8, 7, 9) + [(8, 8)]),               # stone, 5 tiles
            ("s", rect(15, 18, 16, 19) + [(17, 19)]),          # stone, 5 tiles
            ("g", rect(6, 14, 7, 15)),                         # gold, 4 tiles
            ("g", rect(19, 8, 20, 9)),                         # gold, 4 tiles
            # rock outcrops (the first Reed Meadow's, made to pair up)
            ("#", rect(28, 8, 30, 9)), ("#", rect(21, 15, 23, 17)), ("#", rect(10, 31, 12, 36)),
            # contested: wings of the swamp band (NE for this start's half), by the pond
            ("g", rect(41, 17, 42, 18)),                       # gold on the band, by the river
            ("s", rect(37, 25, 38, 26) + [(39, 25)]),          # stone by the pond
            ('"', rect(33, 15, 35, 18)), ('"', rect(48, 6, 53, 7)), ("T", rect(36, 3, 41, 4)),
            ("T", blob(29, 4.5, 2.2, 1.6)),                    # a contested wood by the north edge
            ("#", rect(40, 22, 41, 27)),                       # the rock spit in the swamp
        ]
        pond = None
    else:
        sx, sy = 16, 16
        f = [
            # home: the big reed line along the north and west edges, and groves
            ("T", line(2, 2, 30, 4)), ('"', line(2, 5, 4, 30)),   # a forest behind the base, reeds down the side
            ("T", rect(23, 6, 27, 8)),
            ('"', rect(6, 24, 9, 28)),
            ('"', rect(30, 14, 32, 18)),
            ("b", rect(21, 15, 22, 18)),                       # 8 bug bushes
            ("s", rect(10, 12, 11, 13) + [(12, 12)]),          # stone, 5 tiles
            ("s", rect(20, 23, 21, 24) + [(22, 24)]),          # stone, 5 tiles
            ("g", rect(9, 19, 10, 20)),                        # gold, 4 tiles
            ("g", rect(24, 11, 25, 12)),                       # gold, 4 tiles
            # rock outcrops
            ("#", rect(38, 10, 40, 11)), ("#", rect(28, 21, 30, 23)), ("#", rect(13, 42, 15, 48)),
            ("#", rect(46, 3, 48, 5)),
            # contested: the swamp band's wings, the middle round the pond
            ("g", rect(62, 23, 63, 24)),                       # gold on the band, equidistant
            ("g", rect(70, 8, 71, 9)),                         # far wing gold (this side of the river)
            ("s", rect(51, 33, 52, 34) + [(53, 33)]),          # stone by the pond
            ("s", rect(66, 6, 67, 7) + [(68, 6)]),             # wing stone
            ('"', rect(45, 20, 48, 24)), ('"', rect(58, 8, 64, 10)), ("T", rect(50, 3, 56, 4)),
            ('"', rect(70, 15, 72, 19)), ("T", rect(36, 30, 39, 32)),
            ("T", blob(40, 16, 3.0, 2.2)), ("T", blob(34, 40, 2.4, 2.4)),   # contested woods
            ("b", rect(56, 28, 57, 29)),                       # a contested bush patch
            ("#", rect(55, 30, 56, 36)),                       # the rock spit in the swamp
        ]
        pond = None
    return (sx, sy), f, pond


# The river, in the north-west start's frame: the arm from the north-east corner to the middle,
# then along x to the centre (the half turn draws the rest). Radius in tiles; the fords are
# points on the arm (river cells this close become ford); the bridge is centred on the map
# (so it maps onto itself), across the middle stretch, [x0, y0, x1, y1].
RIVER = {
    64: {"arm": [(64.5, -1.5), (50.0, 15.0), (39.0, 28.0), (35.0, 31.5), (31.5, 31.5)], "r": 1.1,
         "fords": [(44.5, 21.5)], "ford_r": 1.8, "bridges": [[31, 31, 32, 32]]},
    # the 2v2: a kink in each arm runs along x for a while, crossed by a bridge (with its twin)
    88: {"arm": [(88.5, -1.5), (78.0, 9.0), (70.0, 9.0), (57.0, 38.0), (51.0, 43.5), (43.5, 43.5)], "r": 2.0,
         "fords": [(63.5, 24.5)], "ford_r": 2.3, "bridges": [[43, 42, 44, 45], [74, 7, 74, 11]]},
}


# Hills in the north-west start's frame (the half turn draws the other side's): an ellipse of
# cells raised to `level` (a ridge when `turn` is set: its long axis runs along x - y, the
# river's way), and ramps up onto it, each centred where a ray from the hill's centre in a
# direction of `ramps` (in tiles) leaves it, about three cells wide.
HILLS = {
    64: [
        {"c": (25.0, 25.0), "r": (7.6, 3.6), "turn": 1, "level": 1, "ramps": [(-1, -1), (1, 1)]},
    ],
}
# The 2v2: the team hill between the two bases (drawn once, on the diagonal: teammates get the
# same), and a lookout on each start's flank (in the kit: drawn for A1 and transposed for A2).
HILLS_2V2_SHARED = [
    {"c": (18.0, 18.0), "r": (5.3, 5.3), "level": 1, "ramps": [(1, 0), (0, 1)]},
    {"c": (18.0, 18.0), "r": (2.3, 2.3), "level": 2, "ramps": [(1, 1)]},
]
HILLS_2V2_KIT = [
    {"c": (19.5, 48.5), "r": (3.4, 2.6), "level": 1, "ramps": [(-1, -1), (1, 0)]},
]
RAMP = "abc"


def in_hill(hl, x, y):
    cx, cy = hl["c"]
    rx, ry = hl["r"]
    dx, dy = x - cx, y - cy
    if hl.get("turn"):
        dx, dy = (dx - dy) / math.sqrt(2.0), (dx + dy) / math.sqrt(2.0)
    return (dx / rx) ** 2 + (dy / ry) ** 2 <= 1.0


def raise_hill(H, hl, S, flip=None):
    """Raise a hill and its half-turned twin in the heights grid H (rows of ints). `flip` maps
    a cell into the frame drawn (the 2v2 kit's transpose)."""
    f = flip or (lambda x, y: (x, y))
    for y in range(S):
        for x in range(S):
            if in_hill(hl, x, y):
                fx, fy = f(x, y)
                for (px, py) in ((fx, fy), (S - 1 - fx, S - 1 - fy)):
                    H[py][px] = max(H[py][px], hl["level"])


def cut_ramps(H, ramps, hl, S, flip=None):
    """Ramps up onto a raised hill (and its twin): the cells at the level below, beside the
    hill, round where each ramp direction leaves it. `ramps`: cell -> foot level."""
    f = flip or (lambda x, y: (x, y))
    lv = hl["level"]
    cx, cy = hl["c"]
    for (dx, dy) in hl["ramps"]:
        n = math.hypot(dx, dy)
        dx, dy = dx / n, dy / n
        t = 0.0
        while in_hill(hl, cx + dx * t, cy + dy * t):
            t += 0.05
        ax, ay = f(cx + dx * (t + 0.5), cy + dy * (t + 0.5))
        for y in range(S):
            for x in range(S):
                if H[y][x] != lv - 1 or math.hypot(x - ax, y - ay) > 2.1:
                    continue
                if not any(0 <= x + ex < S and 0 <= y + ey < S and H[y + ey][x + ex] >= lv
                           for ex in (-1, 0, 1) for ey in (-1, 0, 1)):
                    continue
                for (px, py) in ((x, y), (S - 1 - x, S - 1 - y)):
                    ramps[(px, py)] = lv - 1
    # Fill the notches: a cell at the foot between a ramp and the hill (4-way) joins the ramp,
    # or it stands as a pit of cliff in the slope.
    four = ((1, 0), (-1, 0), (0, 1), (0, -1))
    fill = [(x, y) for y in range(1, S - 1) for x in range(1, S - 1)
            if H[y][x] == lv - 1 and (x, y) not in ramps
            and sum(1 for (ex, ey) in four if ramps.get((x + ex, y + ey)) == lv - 1) >= 1
            and any(H[y + ey][x + ex] >= lv and (x + ex, y + ey) not in ramps for (ex, ey) in four)
            and sum(1 for ex in (-1, 0, 1) for ey in (-1, 0, 1) if ramps.get((x + ex, y + ey)) == lv - 1) >= 1]
    for (x, y) in fill:
        for (px, py) in ((x, y), (S - 1 - x, S - 1 - y)):
            ramps[(px, py)] = lv - 1


def height_rows(H, ramps, S):
    return ["".join(RAMP[ramps[(x, y)]] if (x, y) in ramps else str(H[y][x]) for x in range(S)) for y in range(S)]


def levels(heights):
    """Per cell (level, ramp) from height rows."""
    return [[(RAMP.find(ch), 1) if ch in RAMP else (int(ch), 0) for ch in row] for row in heights]


def cliffs(heights):
    """The sim's rule (sim_map.gd): a cell is a cliff if a neighbour (8-way) stands higher than
    the highest ground it reaches (its level, or a ramp's top)."""
    L = levels(heights)
    S = len(heights)
    out = set()
    for y in range(S):
        for x in range(S):
            top = L[y][x][0] + L[y][x][1]
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and L[ny][nx][0] > top:
                        out.add((x, y))
    return out


def check_heights(map_id, rows, heights, starts, bridges):
    """High ground that plays: symmetric; hills, ramps and cliffs on open ground (no resources,
    rock or water under a face or a ramp); starts and bridge landings flat and clear; every
    hill top reached from every start, and only by its ramps."""
    S = len(rows)
    for y in range(S):
        assert heights[y] == heights[S - 1 - y][::-1], "%s: heights not symmetric at row %d" % (map_id, y)
    cl = cliffs(heights)
    L = levels(heights)
    for y in range(S):
        for x in range(S):
            if L[y][x][0] > 0 or L[y][x][1] or (x, y) in cl:
                assert rows[y][x] in ".,", "%s: high ground, a ramp or a cliff on '%s' at %d,%d" % (map_id, rows[y][x], x, y)
    for (sx, sy) in starts:
        for y in range(sy - 4, sy + 5):
            for x in range(sx - 4, sx + 5):
                assert heights[y][x] == "0" and (x, y) not in cl, "%s: start %s not on flat ground" % (map_id, (sx, sy))
    for (x0, y0, x1, y1) in bridges:
        for y in range(y0 - 1, y1 + 2):
            for x in range(x0 - 1, x1 + 2):
                assert heights[y][x] == "0" and (x, y) not in cl, "%s: a bridge in the hills at %d,%d" % (map_id, x, y)
    tops = [(x, y) for y in range(S) for x in range(S) if L[y][x][0] > 0 and (x, y) not in cl]
    assert tops, "%s: no high ground" % map_id
    for s in starts:
        joined = reach(rows, s, bridges, cl)
        for t in tops:
            assert t in joined, "%s: hill top %s can't be reached from %s" % (map_id, t, s)
    # Without its ramps (each one plain ground at its foot) no hill top is reached.
    flat = ["".join(str(RAMP.find(ch)) if ch in RAMP else ch for ch in row) for row in heights]
    shut = reach(rows, starts[0], bridges, cliffs(flat))
    for t in tops:
        assert t not in shut, "%s: hill top %s is reached without a ramp" % (map_id, t)
    return len(tops), len(cl)


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def river(grid, S):
    """Draws the river (both arms: the half turn of the listed one); returns its bridges, each
    one listed with its half-turned twin (a bridge on the centre is its own twin)."""
    spec = RIVER[S]
    arm = spec["arm"]
    for y in range(S):
        for x in range(S):
            rx, ry = x, y   # the far arm comes from the half turn (build copies the top half over)
            d = min(seg_dist(rx, ry, *arm[k], *arm[k + 1]) for k in range(len(arm) - 1))
            if d <= spec["r"]:
                grid[y][x] = "R"
            elif d <= spec["r"] + 1.0 and grid[y][x] == ".":
                grid[y][x] = ","   # wet banks
    for (fx, fy) in spec["fords"]:
        for y in range(S):
            for x in range(S):
                rx, ry = x, y
                if grid[y][x] == "R" and math.hypot(rx - fx, ry - fy) <= spec["ford_r"]:
                    grid[y][x] = "f"
    out = []
    for b in spec["bridges"]:
        x0, y0, x1, y1 = b
        out.append(b)
        twin = [S - 1 - x1, S - 1 - y1, S - 1 - x0, S - 1 - y0]
        if twin != b:
            out.append(twin)
    return out


def build(map_id, name, size):
    S = size
    grid = [["." for _ in range(S)] for _ in range(S)]
    c = (S - 1) / 2.0
    # the swamp band, corner to corner between the starts, with a wiggle (odd in x - y, so the
    # half turn maps it onto itself)
    for y in range(S):
        for x in range(S):
            d = x - y
            off = 2.0 * math.sin(d / 9.0)
            if abs(x + y - (S - 1) - off) <= 4.0:
                grid[y][x] = ","
    start, feats, _ = layout(S)
    for ch, cells in feats:
        for (x, y) in cells:
            for (px, py) in ((x, y), (S - 1 - x, S - 1 - y)):
                if 0 < px < S - 1 and 0 < py < S - 1:
                    grid[py][px] = ch
    lost = {}
    before = [row[:] for row in grid]
    bridges = river(grid, S)
    for y in range(S):
        for x in range(S):
            if before[y][x] in AMOUNT and grid[y][x] != before[y][x]:
                lost[before[y][x]] = lost.get(before[y][x], 0) + 1
    if lost:
        print("   %s: the river took %s" % (map_id, lost))
    # guarantee the half turn (the north-west half wins any overlap)
    for y in range(S):
        for x in range(S):
            if y * S + x < (S - 1 - y) * S + (S - 1 - x):
                grid[S - 1 - y][S - 1 - x] = grid[y][x]
    for i in range(S):
        grid[0][i] = grid[S - 1][i] = grid[i][0] = grid[i][S - 1] = "#"
    starts = [list(start), [S - 1 - start[0], S - 1 - start[1]]]
    # keep the Town Center's ground (and a ring round it) clear
    for (stx, sty) in starts:
        for y in range(sty - 3, sty + 4):
            for x in range(stx - 3, stx + 4):
                assert grid[y][x] in ".,", "%s: start %s blocked at %d,%d (%s)" % (map_id, (stx, sty), x, y, grid[y][x])
    rows = ["".join(r) for r in grid]
    for y in range(S):
        assert rows[y] == rows[S - 1 - y][::-1], "%s: not symmetric at row %d" % (map_id, y)
    check_bridges(map_id, rows, bridges)
    check_crossings(map_id, rows, starts, bridges)
    H = [[0] * S for _ in range(S)]
    ramps = {}
    for hl in HILLS[S]:
        raise_hill(H, hl, S)
    for hl in HILLS[S]:
        cut_ramps(H, ramps, hl, S)
    heights = height_rows(H, ramps, S)
    tops, cl = check_heights(map_id, rows, heights, starts, bridges)
    print("   %s: %d cells of high ground, %d cliff cells, %d ramp cells" % (map_id, tops, cl, len(ramps)))
    d = {"schema": "aow.map/2", "id": map_id, "name": name, "width": S, "height": S,
         "symmetry": "rotate", "legend": LEGEND, "rows": rows, "heights": heights, "starts": starts,
         "animals": ANIMALS, "bridges": bridges}
    return d


def reach(rows, start, crossings, cliff=frozenset()):
    """Cells a walker reaches from start (8-way, no corner cutting, as the sim walks), with
    or without the fords and bridges, never onto a cliff."""
    S = len(rows)
    deck = set()
    if crossings:
        for b in crossings:
            deck |= {(x, y) for x in range(b[0], b[2] + 1) for y in range(b[1], b[3] + 1)}
    def ok(x, y):
        if not (0 <= x < S and 0 <= y < S) or (x, y) in cliff:
            return False
        t = LEGEND[rows[y][x]]
        return t in ("grass", "swamp") or (crossings is not None and (t == "ford" or (x, y) in deck))
    seen = {tuple(start)}
    todo = [tuple(start)]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            n = (x + dx, y + dy)
            if n in seen or not ok(*n):
                continue
            if dx and dy and not (ok(x + dx, y) and ok(x, y + dy)):
                continue
            seen.add(n)
            todo.append(n)
    return seen


def check_crossings(map_id, rows, starts, bridges):
    """The river splits the map in two for walkers: without its fords and bridges the two halves
    don't meet; with them, every start reaches every other."""
    cut = reach(rows, starts[0], None)
    assert tuple(starts[1]) not in cut, "%s: walkers get round the river without a crossing" % map_id
    joined = reach(rows, starts[0], bridges)
    for s in starts:
        assert tuple(s) in joined, "%s: start %s can't be reached over the crossings" % (map_id, s)


def check_bridges(map_id, rows, bridges):
    """Every bridge stands on river and lands on ground at both ends of its length."""
    for (x0, y0, x1, y1) in bridges:
        along_y = y1 - y0 >= x1 - x0
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                assert rows[y][x] == "R", "%s: a bridge must stand on the river at %d,%d" % (map_id, x, y)
        ends = [(x, y) for x in range(x0, x1 + 1) for y in (y0 - 1, y1 + 1)] if along_y else \
            [(x, y) for y in range(y0, y1 + 1) for x in (x0 - 1, x1 + 1)]
        for (x, y) in ends:
            assert LEGEND[rows[y][x]] in ("grass", "swamp"), "%s: a bridge must land on ground at %d,%d" % (map_id, x, y)


# ------------------------------------------------------------------ the 2v2

def transpose(cells):
    return [(y, x) for (x, y) in cells]


def layout_2v2():
    """The 2v2 in the north-west team's half. `kit` is drawn for the west start (A1) and again
    transposed (x <-> y) for the north start (A2), so teammates get the same ground; `shared`
    is drawn once. The half turn draws the other team."""
    a1 = (14, 34)
    kit = [
        ("T", line(2, 20, 5, 48)),                          # the wood line behind the base, along the west edge
        ("T", rect(22, 39, 25, 41)),                        # a grove
        ("b", rect(19, 32, 20, 35)),                        # 8 bug bushes
        ("s", rect(8, 27, 9, 28) + [(10, 27)]),             # stone, 5 tiles
        ("s", rect(17, 42, 18, 43) + [(19, 43)]),           # stone, 5 tiles
        ("g", rect(8, 40, 9, 41)),                          # gold, 4 tiles
        ("g", rect(21, 27, 22, 28)),                        # gold, 4 tiles
        ('"', rect(9, 50, 13, 52)),                         # reeds down the flank
        # the flank beyond the base (towards the river's far arm): contested but nearer us
        ("T", line(2, 52, 5, 72)),                          # the flank forest along the edge
        ("g", rect(11, 60, 12, 61)),                        # flank gold
        ("s", rect(8, 56, 9, 57) + [(10, 56)]),             # flank stone
        ("b", rect(8, 64, 9, 65)),                          # flank bushes
        ("T", blob(16, 55, 2.0, 1.6)),                      # a flank grove
        ("#", rect(24, 52, 25, 55)),                        # an outcrop
    ]
    shared = [
        ("T", blob(7.5, 7.5, 6.0, 6.0)),                    # the corner forest between teammates
        ("T", blob(27.5, 27.5, 2.6, 2.6)),                  # a grove between the two bases
        ("b", rect(30, 22, 31, 23)), ("b", rect(22, 30, 23, 31)),   # bushes between the bases
        # the middle, this side of the bridge
        ("g", rect(39, 36, 40, 37)), ("g", rect(36, 39, 37, 40)),
        ("s", rect(46, 35, 47, 36) + [(48, 35)]),
        ("b", rect(32, 34, 33, 35)),
        ("T", blob(29, 40, 1.8, 1.8)), ("T", blob(40, 29, 1.8, 1.8)),
        ("#", rect(43, 33, 45, 34)),
        ('"', rect(48, 26, 51, 28)), ('"', rect(26, 48, 28, 51)),   # reeds on the swamp band
    ]
    return a1, kit, shared


def build_2v2(map_id, name):
    S = 88
    grid = [["." for _ in range(S)] for _ in range(S)]
    for y in range(S):
        for x in range(S):
            d = x - y
            off = 2.0 * math.sin(d / 9.0)
            if abs(x + y - (S - 1) - off) <= 4.0:
                grid[y][x] = ","
    a1, kit, shared = layout_2v2()
    feats = kit + [(ch, transpose(cells)) for ch, cells in kit] + shared
    for ch, cells in feats:
        for (x, y) in cells:
            for (px, py) in ((x, y), (S - 1 - x, S - 1 - y)):
                if 0 < px < S - 1 and 0 < py < S - 1:
                    grid[py][px] = ch
    before = [row[:] for row in grid]
    bridges = river(grid, S)
    lost = {}
    for y in range(S):
        for x in range(S):
            if before[y][x] in AMOUNT and grid[y][x] != before[y][x]:
                lost[before[y][x]] = lost.get(before[y][x], 0) + 1
    if lost:
        print("   %s: the river took %s" % (map_id, lost))
    for y in range(S):
        for x in range(S):
            if y * S + x < (S - 1 - y) * S + (S - 1 - x):
                grid[S - 1 - y][S - 1 - x] = grid[y][x]
    for i in range(S):
        grid[0][i] = grid[S - 1][i] = grid[i][0] = grid[i][S - 1] = "#"
    a2 = (a1[1], a1[0])
    starts = [list(a1), [S - 1 - a1[0], S - 1 - a1[1]], list(a2), [S - 1 - a2[0], S - 1 - a2[1]]]
    for (stx, sty) in starts:
        for y in range(sty - 3, sty + 4):
            for x in range(stx - 3, stx + 4):
                assert grid[y][x] in ".,", "%s: start %s blocked at %d,%d (%s)" % (map_id, (stx, sty), x, y, grid[y][x])
    rows = ["".join(r) for r in grid]
    for y in range(S):
        assert rows[y] == rows[S - 1 - y][::-1], "%s: not symmetric at row %d" % (map_id, y)
    check_bridges(map_id, rows, bridges)
    check_crossings(map_id, rows, starts, bridges)
    H = [[0] * S for _ in range(S)]
    ramps = {}
    tr = lambda x, y: (y, x)
    for hl in HILLS_2V2_SHARED:
        raise_hill(H, hl, S)
    for hl in HILLS_2V2_KIT:
        raise_hill(H, hl, S)
        raise_hill(H, hl, S, tr)
    for hl in HILLS_2V2_SHARED:
        cut_ramps(H, ramps, hl, S)
    for hl in HILLS_2V2_KIT:
        cut_ramps(H, ramps, hl, S)
        cut_ramps(H, ramps, hl, S, tr)
    heights = height_rows(H, ramps, S)
    tops, cl = check_heights(map_id, rows, heights, starts, bridges)
    print("   %s: %d cells of high ground, %d cliff cells, %d ramp cells" % (map_id, tops, cl, len(ramps)))
    return {"schema": "aow.map/2", "id": map_id, "name": name, "width": S, "height": S,
            "symmetry": "rotate", "legend": LEGEND, "rows": rows, "heights": heights, "starts": starts,
            "teams": [0, 1, 0, 1], "animals": ANIMALS, "bridges": bridges}


def report(d, radius=16):
    S = d["width"]
    print("== %s (%d x %d), starts %s" % (d["id"], S, S, d["starts"]))
    for y, r in enumerate(d["rows"]):
        print("   " + r + ("   " + d["heights"][y] if "heights" in d else ""))
    regions = {}
    for y, row in enumerate(d["rows"]):
        for x, ch in enumerate(row):
            if ch not in AMOUNT:
                continue
            region = "contested"
            for p, (sx, sy) in enumerate(d["starts"]):
                if (x - sx) ** 2 + (y - sy) ** 2 <= radius * radius:
                    region = "start %d" % p
            res, amt = AMOUNT[ch]
            regions.setdefault(region, {}).setdefault(res, 0)
            regions[region][res] += amt
    for k in sorted(regions):
        print("   %-10s %s" % (k, regions[k]))


def main():
    for map_id in ["reed_meadow", "reed_meadow_2v2"]:
        d = build(map_id, "Reed Meadow", 64) if map_id == "reed_meadow" else build_2v2(map_id, "Reed Meadow (2v2)")
        report(d, 16)
        if "--dry" in sys.argv:
            continue
        with open(os.path.join(ROOT, "data", "maps", map_id + ".json"), "w") as fh:
            json.dump(d, fh, indent=1)
            fh.write("\n")


if __name__ == "__main__":
    main()
