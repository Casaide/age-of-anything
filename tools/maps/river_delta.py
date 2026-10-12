#!/usr/bin/env python3
"""Builds River Delta (data/maps/river_delta.json), a 1v1 variety map (milestone 15, phase 6).

A river comes in at the north-east and south-west corners and spreads into a marsh of channels
round a lagoon of shallows in the middle. Each side holds a dry bank (its base, a wood line
behind it) and, across a side channel, two islands of its own (sheep, stone, gold), reached by
fords. The main channel splits the map: walkers cross it only on a timber bridge (one by each
flank), a ford, or the causeway through the lagoon to the middle island (gold and stone).
Amphibians swim every channel and wade the lagoon, so for frogs the whole marsh is a road.
Food: bushes on the bank and the marsh, sheep on the islands (no fishing yet).

Everything is drawn for the north-west start and again turned half a turn about the centre for
the south-east one (rotational symmetry, asserted), from the same parts as Reed Meadow (its
checks are reused: crossings, bridges standing on river, heights).

  python3 tools/maps/river_delta.py          # writes the map, prints the ASCII and counts
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reed_meadow import (LEGEND, AMOUNT, rect, line, blob, seg_dist, check_crossings,  # noqa: E402
                         check_bridges, check_heights, raise_hill, cut_ramps, height_rows, report, reach)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
S = 72
START = (14, 14)
C = (S - 1) / 2.0

# Channels in the north-west start's frame: (points, radius). The main channel runs from the
# north-east corner to the lagoon (the half turn brings it in from the south-west); it runs
# along x for a stretch, wide, where the bridge stands. The side channel leaves it and
# reaches the lagoon round this side's islands; a cut splits them in two.
MAIN = [((72.5, -1.5), (64.0, 7.0), 1.5), ((64.0, 7.0), (57.0, 13.0), 1.5), ((57.0, 13.0), (55.0, 15.0), 1.6),
        ((55.0, 15.0), (49.0, 15.0), 2.0), ((49.0, 15.0), (44.0, 21.0), 1.4), ((44.0, 21.0), (40.5, 28.5), 1.3)]
SIDE = [((61.0, 9.5), (52.0, 6.5), 1.0), ((52.0, 6.5), (44.0, 7.0), 1.0), ((44.0, 7.0), (38.0, 12.0), 1.0),
        ((38.0, 12.0), (33.5, 20.0), 1.0), ((33.5, 20.0), (31.0, 29.0), 1.1)]
CUT = [((41.0, 9.5), (46.5, 17.5), 0.9)]
LAGOON = (7.2, 5.4)       # shallows round the centre, the long axis across the main channel's way
ISLAND = 3.0              # the middle island's radius
FORDS = [((36.0, 16.0), 1.7), ((47.5, 6.8), 1.6), ((43.9, 13.6), 1.5), ((42.3, 24.4), 1.6)]
BRIDGES = [[52, 13, 52, 17]]   # over the main channel's straight stretch (and its twin)
CAUSEWAY = [(34.0, 34.0), (29.0, 29.5)]   # fords through the lagoon, from the island to this bank

FEATURES = [
    ("T", line(2, 2, 24, 4)), ("T", line(2, 5, 4, 24)),     # the wood line behind the base
    ("T", blob(27, 9, 2.6, 2.0)), ("T", blob(9, 27, 2.0, 2.6)),   # groves on the bank
    ("b", rect(19, 16, 20, 19)),                            # 8 bushes by the Town Center
    ("s", rect(7, 19, 8, 20) + [(9, 20)]),                  # stone, 5 tiles
    ("s", rect(20, 6, 21, 7) + [(22, 6)]),                  # stone, 5 tiles
    ("g", rect(6, 10, 7, 11)),                              # gold, 4 tiles
    ("g", rect(11, 22, 12, 23)),                            # gold, 4 tiles
    # the marsh this side of the side channel: reeds, willows, bushes
    ('"', rect(30, 14, 32, 17)), ('"', rect(25, 24, 28, 25)), ('"', rect(14, 31, 16, 34)),
    ("T", blob(29, 20, 1.6, 2.4)), ("T", blob(20, 29, 2.4, 1.6)),
    ("b", rect(23, 29, 24, 30)),
    # the flank (towards the south-west corner, this side of the far main channel)
    ("T", blob(8, 42, 2.4, 3.2)), ('"', rect(4, 48, 6, 53)), ("T", blob(12, 58, 2.2, 1.8)),
    ("b", rect(12, 44, 13, 45)), ("g", rect(6, 34, 7, 35)),
    ('"', rect(26, 40, 28, 42)),
    # the north island (between the side channel, the cut and the main channel): stone, sheep
    ("s", rect(50, 8, 51, 9) + [(52, 8)]),
    ('"', rect(54, 9, 56, 11)),
    # the south island (by the lagoon): gold, reeds, sheep
    ("g", rect(38, 19, 39, 20)), ('"', rect(36, 25, 37, 27)), ("T", blob(40.5, 16.5, 1.4, 1.4)),
]

# A dwelling mound on the flank by the far bridge (turned: the other side's over its bridge).
HILLS = [
    {"c": (19.5, 47.5), "r": (2.6, 2.0), "level": 1, "ramps": [(-1, -1), (0, 1)]},
]

ANIMALS = {
    "near_start": [
        {"kind": "sheep", "count": 4, "min": 4, "max": 7},
        {"kind": "deer", "count": 2, "size": 3, "min": 10, "max": 14},
        {"kind": "boar", "count": 1, "min": 9, "max": 13},
    ],
    "fixed": [
        {"kind": "sheep", "cells": [[49, 11], [50, 11], [52, 11], [53, 12], [40, 22], [41, 22], [36, 22], [37, 21]]},
        {"kind": "sheep", "cells": [[35, 37], [36, 34]]},
        {"kind": "boar", "cells": [[20, 40]]},
    ],
    "wild": [
        {"kind": "deer", "herds": 1, "size": 3, "away": 22},
    ],
}


def turned(x, y):
    return S - 1 - x, S - 1 - y


def near(x, y, segs):
    """How far inside the nearest channel segment (its radius minus the distance; > 0 is water)."""
    return max(r - seg_dist(x, y, *a, *b) for (a, b, r) in segs)


def in_lagoon(x, y):
    dx, dy = x - C, y - C
    u, v = (dx - dy) / math.sqrt(2.0), (dx + dy) / math.sqrt(2.0)   # u across the band, v along it
    return (u / LAGOON[1]) ** 2 + (v / LAGOON[0]) ** 2 <= 1.0


def build():
    grid = [["." for _ in range(S)] for _ in range(S)]
    # the marsh band along the delta (wiggles odd in x - y, so the half turn keeps it)
    for y in range(S):
        for x in range(S):
            off = 2.0 * math.sin((x - y) / 8.0)
            if abs(x + y - (S - 1) - off) <= 14.0:
                grid[y][x] = ","

    def paint(ch, cells):
        for (x, y) in cells:
            for (px, py) in ((x, y), turned(x, y)):
                if 0 < px < S - 1 and 0 < py < S - 1:
                    grid[py][px] = ch
    for ch, cells in FEATURES:
        paint(ch, cells)
    # water: the lagoon, the channels (both arms), the middle island
    chans = MAIN + SIDE + CUT
    twins = [(turned(*a), turned(*b), r) for (a, b, r) in chans]
    for y in range(S):
        for x in range(S):
            if in_lagoon(x, y):
                grid[y][x] = "w"
            if max(near(x, y, chans), near(x, y, twins)) >= 0:
                grid[y][x] = "R"
            if math.hypot(x - C, y - C) <= ISLAND:
                grid[y][x] = "."
    paint("g", rect(35, 35, 36, 36))                        # the middle island's gold (its own twin)
    paint("s", [(33, 36), (33, 37), (34, 37)])              # and stone
    for (f, r) in FORDS:
        for (fx, fy) in (f, turned(*f)):
            for y in range(S):
                for x in range(S):
                    if grid[y][x] == "R" and math.hypot(x - fx, y - fy) <= r:
                        grid[y][x] = "f"
    for (a, b) in [CAUSEWAY, [turned(*p) for p in CAUSEWAY]]:
        for y in range(S):
            for x in range(S):
                if grid[y][x] in "wR" and seg_dist(x, y, *a, *b) <= 0.8:
                    grid[y][x] = "f"
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
    bridges = []
    for b in BRIDGES:
        bridges += [b, [S - 1 - b[2], S - 1 - b[3], S - 1 - b[0], S - 1 - b[1]]]
    rows = ["".join(r) for r in grid]
    # ground a walker only reaches by cutting through reeds or trees: more reeds
    joined = reach(rows, starts[0], bridges)
    pockets = [(x, y) for y in range(S) for x in range(S) if grid[y][x] in ".," and (x, y) not in joined]
    cut = reach(["".join(c if c not in '"T' else "." for c in r) for r in rows], starts[0], bridges)
    for (x, y) in pockets:
        assert (x, y) in cut, "river_delta: ground at %d,%d only a swimmer reaches" % (x, y)
        grid[y][x] = '"'
    rows = ["".join(r) for r in grid]
    if "--show" in sys.argv:
        print("\n".join("%2d %s" % (y, r) for y, r in enumerate(rows)))
    for y in range(S):
        assert rows[y] == rows[S - 1 - y][::-1], "not symmetric at row %d" % y
    check_bridges("river_delta", rows, bridges)
    check_crossings("river_delta", rows, starts, bridges)
    check_ground(rows, bridges)
    H = [[0] * S for _ in range(S)]
    ramps = {}
    for hl in HILLS:
        raise_hill(H, hl, S)
    for hl in HILLS:
        cut_ramps(H, ramps, hl, S)
    heights = height_rows(H, ramps, S)
    tops, cl = check_heights("river_delta", rows, heights, starts, bridges)
    print("   river_delta: %d cells of high ground, %d cliff cells, %d ramp cells" % (tops, cl, len(ramps)))
    return {"schema": "aow.map/2", "id": "river_delta", "name": "River Delta", "width": S, "height": S,
            "symmetry": "rotate", "legend": LEGEND, "rows": rows, "heights": heights, "starts": starts,
            "animals": ANIMALS, "bridges": bridges}


def check_ground(rows, bridges):
    """Walkers reach every piece of dry ground over the crossings (no island only a swimmer
    finds: animals and resources there would be a gift to amphibians alone), and every fixed
    animal stands on it."""
    joined = reach(rows, list(START), bridges)
    for y in range(S):
        for x in range(S):
            if rows[y][x] in ".,":
                assert (x, y) in joined, "river_delta: ground at %d,%d only a swimmer reaches" % (x, y)
    for e in ANIMALS["fixed"]:
        for (x, y) in e["cells"]:
            for (px, py) in ((x, y), turned(x, y)):
                assert rows[py][px] in ".,", "a %s at %d,%d isn't on open ground" % (e["kind"], px, py)


def main():
    d = build()
    report(d, 16)
    if "--dry" in sys.argv:
        return
    with open(os.path.join(ROOT, "data", "maps", "river_delta.json"), "w") as fh:
        json.dump(d, fh, indent=1)
        fh.write("\n")


if __name__ == "__main__":
    main()
