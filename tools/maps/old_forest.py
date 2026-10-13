#!/usr/bin/env python3
"""Builds Old Forest (data/maps/old_forest.json), a 1v1 variety map (milestone 15, phase 6).

Deep woods everywhere, opened up by clearings: each base in a clearing of its own, two hunting
glades beside it (deer, boar, bushes), paths between them, a stream from corner to corner with
three fords (one in each flank glade, one in the central glade), and the central glade's gold
on both banks. The forest is the wood (a lot of it) and the walls: the paths wind, and a few
rows of trees stand between each base and the centre, so cutting them opens a straight road.
A lookout hill in each flank glade watches its ford (one per side, turned half a turn).

Everything is drawn for the north-west start and again turned half a turn about the centre for
the south-east one (rotational symmetry, asserted), from the same parts as Reed Meadow (its
checks are reused: crossings, bridges, heights).

  python3 tools/maps/old_forest.py          # writes the map, prints the ASCII and counts
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reed_meadow import (LEGEND, AMOUNT, rect, seg_dist, check_crossings, check_heights,  # noqa: E402
                         raise_hill, cut_ramps, height_rows, report, reach)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
S = 72
START = (14, 14)


def clearing(cx, cy, r, ry=None, seed=0.0, wob=1.0):
    """An open patch with a wavy edge (no perfect circles in an old wood); `wob` scales the waves
    (the home clearing keeps them small, so its edge never pinches in on the base)."""
    ry = ry or r
    out = []
    for y in range(int(cy - ry * 1.2) - 3, int(cy + ry * 1.2) + 4):
        for x in range(int(cx - r * 1.2) - 3, int(cx + r * 1.2) + 4):
            a = math.atan2(y - cy, x - cx)
            w = 1.0 + wob * (0.10 * math.sin(3 * a + seed) + 0.07 * math.sin(5 * a + 2 * seed + 1))
            if ((x - cx) / r) ** 2 + ((y - cy) / ry) ** 2 <= w * w:
                out.append((x, y))
    return out


def path(points, w=1.5):
    """A track through the trees along a polyline, w tiles each side of it."""
    out = []
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    for y in range(int(min(ys) - w) - 1, int(max(ys) + w) + 2):
        for x in range(int(min(xs) - w) - 1, int(max(xs) + w) + 2):
            if min(seg_dist(x, y, *points[k], *points[k + 1]) for k in range(len(points) - 1)) <= w:
                out.append((x, y))
    return out


# Open ground, in the north-west start's frame. The home clearing is room for a whole base by the
# end (Town Center, houses, farms for 15-20 farmers, the military buildings, a Castle, a wall ring
# at radius 10-11): open to ~15 tiles toward the middle, 11-13 toward the map's edges (a woodline
# behind), with a lobe along each edge toward the hunting glades, the second Town Center's sites
# (2026-10-13, Dominic: "really struggle to build by end game, even early game is a squeeze").
OPEN = [
    clearing(16, 16, 13.0, seed=0.3, wob=0.4),              # home
    clearing(23, 8, 4.5, 4.0, seed=1.7),                    # its north lobe
    clearing(8, 23, 4.0, 4.5, seed=2.9),                    # its west lobe
    clearing(40, 10, 7.5, 6.5, seed=1.1),                   # the north hunting glade (room for a second Town Center)
    clearing(10, 40, 6.5, 7.5, seed=2.3),                   # the west hunting glade (likewise)
    clearing(57.0, 14.0, 8.5, 7.5, seed=0.7),               # the flank glade on the stream (its ford)
    clearing(35.5, 35.5, 12.0, seed=0.0, wob=0.6),          # the central glade
]

# Wood painted back over the clearings' rims. Between home and the centre, a belt 3 trees thick on
# the diagonal: the short way stops three trees short of the glade (cutting them opens a straight
# road) and the way round is a path through it. Behind home, the corner's woodline comes in to ~7
# tiles from the Town Center, so the first lumber camp has a short walk.
WOODS = [
    [(x, y) for y in range(S) for x in range(S) if 50 <= x + y <= 54 and abs(x - y) <= 15],
    clearing(5.5, 5.5, 5.5, seed=0.9),                      # the woodline in the corner behind home, near the Town Center
]

# Tracks through the trees, cut after the woods (3-4 tiles wide).
PATHS = [
    path([(28, 9), (33, 10)], 1.6),                         # home -> north glade
    path([(9, 28), (10, 33)], 1.6),                         # home -> west glade
    path([(45, 11), (50, 13)], 1.6),                        # north glade -> flank glade
    path([(12, 45), (14, 50)], 1.6),                        # west glade -> the other flank glade
    path([(26, 18), (32, 19), (36, 23)], 1.6),              # home -> centre, the long way round: joins the deer track
    path([(38, 15), (36, 22), (37, 27)], 1.6),              # a deer track from the north glade to the centre
]

# What lies on it: (char, cells), in the same frame.
FEATURES = [
    ("b", rect(19, 15, 20, 18)),                            # 8 berry bushes by the Town Center
    ("s", rect(6, 19, 7, 20) + [(8, 20)]),                  # stone, 5 tiles
    ("s", rect(19, 5, 20, 6) + [(21, 5)]),                  # stone, 5 tiles
    ("g", rect(5, 10, 6, 11)),                              # gold, 4 tiles
    ("g", rect(10, 22, 11, 23)),                            # gold, 4 tiles
    ("b", rect(38, 7, 39, 8)), ("b", rect(7, 37, 8, 38)),   # bushes in the hunting glades
    ("s", rect(58, 18, 59, 19) + [(60, 18)]),               # flank stone, over the ford
    ("g", rect(29, 34, 30, 35)), ("g", rect(34, 29, 35, 30)),   # the central glade's gold, this bank (the twins across)
    ("#", rect(34, 9, 34, 10)), ("#", rect(9, 34, 10, 34)),     # a boulder in each hunting glade
]

# The stream: the arm from the north-east corner to the centre (the half turn draws the rest),
# its fords (river cells this close become ford).
STREAM = [(72.5, -1.5), (64.0, 7.0), (58.0, 12.0), (53.5, 17.5), (47.0, 23.0), (42.0, 30.0), (35.5, 35.5)]
STREAM_R = 0.9
FORDS = [((55.75, 14.75), 1.7), ((35.5, 35.5), 1.6)]

# A lookout over each flank ford, on this side of it (turned for the other side's).
HILLS = [
    {"c": (53.0, 12.6), "r": (2.8, 1.5), "turn": 1, "level": 1, "ramps": [(1, 1), (-1, 0)]},
]

# The deer and boar live in the glades. "fixed" cells get a twin turned half a turn.
ANIMALS = {
    "near_start": [
        {"kind": "sheep", "count": 4, "min": 4, "max": 7},
        {"kind": "deer", "count": 1, "size": 3, "min": 8, "max": 10},
    ],
    "fixed": [
        {"kind": "deer", "cells": [[35, 13], [36, 13], [37, 13], [11, 35], [12, 36], [11, 37]]},
        {"kind": "boar", "cells": [[36, 11], [10, 42], [51, 15]]},
        {"kind": "deer", "cells": [[32, 32], [31, 33], [33, 31]]},
    ],
    "wild": [
        {"kind": "deer", "herds": 1, "size": 3, "away": 20},
    ],
}


def turned(x, y):
    return S - 1 - x, S - 1 - y


def build():
    grid = [["T" for _ in range(S)] for _ in range(S)]

    def paint(ch, cells):
        for (x, y) in cells:
            for (px, py) in ((x, y), turned(x, y)):
                if 0 < px < S - 1 and 0 < py < S - 1:
                    grid[py][px] = ch
    for cells in OPEN:
        paint(".", cells)
    for cells in WOODS:
        paint("T", cells)
    for cells in PATHS:
        paint(".", cells)
    for ch, cells in FEATURES:
        paint(ch, cells)
    # the stream, both arms, with wet banks where it runs through the open
    twin = [turned(*p) for p in STREAM]
    for y in range(S):
        for x in range(S):
            d = min(min(seg_dist(x, y, *a[k], *a[k + 1]) for k in range(len(a) - 1)) for a in (STREAM, twin))
            if d <= STREAM_R:
                grid[y][x] = "R"
            elif d <= STREAM_R + 1.2 and grid[y][x] == ".":
                grid[y][x] = ","
    for (f, r) in FORDS:
        for (fx, fy) in (f, turned(*f)):
            for y in range(S):
                for x in range(S):
                    if grid[y][x] == "R" and math.hypot(x - fx, y - fy) <= r:
                        grid[y][x] = "f"
    # the half turn, exactly (the north-west half wins any overlap), and the rock border
    for y in range(S):
        for x in range(S):
            if y * S + x < (S - 1 - y) * S + (S - 1 - x):
                grid[S - 1 - y][S - 1 - x] = grid[y][x]
    for i in range(S):
        grid[0][i] = grid[S - 1][i] = grid[i][0] = grid[i][S - 1] = "#"
    starts = [list(START), list(turned(*START))]
    for (stx, sty) in starts:
        for y in range(sty - 4, sty + 5):
            for x in range(stx - 4, stx + 5):
                assert grid[y][x] in ".,", "start %s blocked at %d,%d (%s)" % ((stx, sty), x, y, grid[y][x])
    # pockets of open ground shut in by trees (no one could walk there): more forest
    rows = ["".join(r) for r in grid]
    joined = reach(rows, starts[0], [])
    shut = [(x, y) for y in range(S) for x in range(S) if grid[y][x] in ".," and (x, y) not in joined]
    for (x, y) in shut:
        grid[y][x] = "T"
    rows = ["".join(r) for r in grid]
    for y in range(S):
        assert rows[y] == rows[S - 1 - y][::-1], "not symmetric at row %d" % y
    check_crossings("old_forest", rows, starts, [])
    H = [[0] * S for _ in range(S)]
    ramps = {}
    for hl in HILLS:
        raise_hill(H, hl, S)
    for hl in HILLS:
        cut_ramps(H, ramps, hl, S)
    heights = height_rows(H, ramps, S)
    tops, cl = check_heights("old_forest", rows, heights, starts, [])
    check_animals(rows, ANIMALS["fixed"])
    print("   old_forest: %d pocket cells filled with trees; %d cells of high ground, %d cliff cells, %d ramp cells"
          % (len(shut), tops, cl, len(ramps)))
    return {"schema": "aow.map/2", "id": "old_forest", "name": "Old Forest", "width": S, "height": S,
            "symmetry": "rotate", "legend": LEGEND, "rows": rows, "heights": heights, "starts": starts,
            "animals": ANIMALS, "bridges": []}


def check_animals(rows, fixed):
    """Every fixed animal (and its twin) stands on open ground a walker reaches."""
    joined = reach(rows, [START[0], START[1]], [])
    for e in fixed:
        for (x, y) in e["cells"]:
            for (px, py) in ((x, y), turned(x, y)):
                assert rows[py][px] in ".," and (px, py) in joined, "a %s at %d,%d isn't on open ground" % (e["kind"], px, py)


def main():
    d = build()
    report(d, 16)
    trees = sum(r.count("T") for r in d["rows"])
    print("   trees: %d (%d wood)" % (trees, trees * AMOUNT["T"][1]))
    if "--dry" in sys.argv:
        return
    with open(os.path.join(ROOT, "data", "maps", "old_forest.json"), "w") as fh:
        json.dump(d, fh, indent=1)
        fh.write("\n")


if __name__ == "__main__":
    main()
