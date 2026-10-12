#!/usr/bin/env python3
"""Builds the Reed Meadow 1v1 maps (data/maps/reed_meadow*.json) from one layout.

The look of the first Reed Meadow (flat_test): a swamp band running corner to corner between
the two starts, a pond with shallows in the middle, rock outcrops, reed beds, stone and gold.
Every feature is drawn for the north-west start and again turned half a turn about the
centre for the south-east one, so both starts get the same ground (rotational symmetry).

  python3 tools/maps/reed_meadow.py          # writes both maps, prints the ASCII and counts

Two sizes, for Dominic to pick by playing (milestone 15, phase 1):
  reed_meadow        64 x 64, dense: today's size with a long game's resources packed in
  reed_meadow_large  88 x 88: more room between bases, a richer contested middle
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LEGEND = {".": "grass", ",": "swamp", '"': "reeds", "#": "rock", "~": "water",
          "b": "bugbush", "s": "stone", "w": "shallows", "g": "gold"}
AMOUNT = {"b": ("food", 150), '"': ("wood", 100), "s": ("stone", 350), "g": ("gold", 800)}

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
            ('"', line(2, 2, 22, 4)), ('"', line(2, 5, 4, 22)),
            ('"', rect(17, 5, 21, 7)),
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
            ("g", rect(45, 17, 46, 18)),                       # gold on the band, equidistant
            ("s", rect(37, 25, 38, 26) + [(39, 25)]),          # stone by the pond
            ('"', rect(33, 15, 35, 18)), ('"', rect(48, 6, 53, 7)), ('"', rect(36, 3, 41, 4)),
            ("#", rect(40, 22, 41, 27)),                       # the rock spit in the swamp
        ]
        pond = (2.6, 4.6)
    else:
        sx, sy = 16, 16
        f = [
            # home: the big reed line along the north and west edges, and groves
            ('"', line(2, 2, 30, 4)), ('"', line(2, 5, 4, 30)),
            ('"', rect(23, 6, 27, 8)),
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
            ("g", rect(76, 10, 77, 11)),                       # far wing gold
            ("s", rect(51, 33, 52, 34) + [(53, 33)]),          # stone by the pond
            ("s", rect(66, 6, 67, 7) + [(68, 6)]),             # wing stone
            ('"', rect(45, 20, 48, 24)), ('"', rect(58, 8, 64, 10)), ('"', rect(50, 3, 56, 4)),
            ('"', rect(70, 15, 72, 19)), ('"', rect(36, 30, 39, 32)),
            ("b", rect(56, 28, 57, 29)),                       # a contested bush patch
            ("#", rect(55, 30, 56, 36)),                       # the rock spit in the swamp
        ]
        pond = (3.4, 6.0)
    return (sx, sy), f, pond


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
    # the pond, round the exact centre
    water_r, shallow_r = layout(S)[2]
    for y in range(S):
        for x in range(S):
            r2 = (x - c) ** 2 + (y - c) ** 2
            if r2 <= water_r ** 2:
                grid[y][x] = "~"
            elif r2 <= shallow_r ** 2:
                grid[y][x] = "w"
    start, feats, _ = layout(S)
    for ch, cells in feats:
        for (x, y) in cells:
            for (px, py) in ((x, y), (S - 1 - x, S - 1 - y)):
                if 0 < px < S - 1 and 0 < py < S - 1:
                    grid[py][px] = ch
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
    d = {"schema": "aow.map/2", "id": map_id, "name": name, "width": S, "height": S,
         "symmetry": "rotate", "legend": LEGEND, "rows": rows, "starts": starts, "animals": ANIMALS}
    return d


def report(d, radius=16):
    S = d["width"]
    print("== %s (%d x %d), starts %s" % (d["id"], S, S, d["starts"]))
    for r in d["rows"]:
        print("   " + r)
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
    maps = [("reed_meadow", "Reed Meadow", 64), ("reed_meadow_large", "Reed Meadow (large)", 88)]
    for map_id, name, size in maps:
        d = build(map_id, name, size)
        report(d, 16 if size == 64 else 20)
        if "--dry" in sys.argv:
            continue
        with open(os.path.join(ROOT, "data", "maps", map_id + ".json"), "w") as fh:
            json.dump(d, fh, indent=1)
            fh.write("\n")


if __name__ == "__main__":
    main()
