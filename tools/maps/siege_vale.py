#!/usr/bin/env python3
"""Builds Siege Vale (data/maps/siege_vale.json), the siege showcase map (milestone 16).

A 72 x 64 vale for the Fortress and Siege modes: the west start sits in a wide clear round (no
trees, stone or bushes on its ring, 10 tiles out: modes.json's walls follow the land and leave
gaps where it can't build), its food, stone and gold inside the ring; the east start is an open
camp with its own resources. Between them a field with rock outcrops and groves for cover, a
swamp in the middle, woods along the north and south edges and behind each start.

  python3 tools/maps/siege_vale.py      # writes the map, prints the ASCII
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 72, 64
WEST = (18, 32)
EAST = (56, 32)
LEGEND = {".": "grass", ",": "swamp", "#": "rock", "b": "bugbush", "s": "stone", "g": "gold", "T": "tree", '"': "reeds"}


def main():
    g = [["." for _ in range(W)] for _ in range(H)]

    def put(x, y, ch):
        if 0 < x < W - 1 and 0 < y < H - 1:
            g[y][x] = ch

    def rect(x0, y0, w, h, ch):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                put(x, y, ch)

    # Woods: the north and south edges (wavy), behind each start.
    for x in range(1, W - 1):
        d = 3 + (x * 7 % 5) // 2
        for y in range(1, d + 1):
            put(x, y, "T")
        for y in range(H - 1 - d, H - 1):
            put(x, y, "T")
    for y in range(1, H - 1):
        for x in range(1, 4 + (y * 5 % 3)):
            put(x, y, "T")
        for x in range(W - 4 - (y * 3 % 3), W - 1):
            put(x, y, "T")
    # The west start's round: cleared 12 tiles out (the ring stands at 10).
    wx, wy = WEST
    for y in range(wy - 12, wy + 13):
        for x in range(wx - 12, wx + 13):
            put(x, y, ".")
    rect(wx + 4, wy - 5, 3, 2, "b")      # food, stone and gold inside the ring
    rect(wx - 6, wy + 4, 2, 2, "s")
    rect(wx - 6, wy - 6, 2, 2, "g")
    rect(wx + 5, wy + 5, 2, 2, "b")
    # The east camp.
    ex, ey = EAST
    rect(ex - 3, ey - 7, 3, 2, "b")
    rect(ex + 5, ey + 4, 2, 2, "s")
    rect(ex + 5, ey - 6, 2, 2, "g")
    rect(ex - 2, ey + 6, 3, 2, "b")
    rect(ex + 8, ey - 2, 2, 5, '"')
    # The field between: outcrops, groves, a swamp.
    rect(36, 22, 3, 3, "#")
    rect(36, 40, 3, 3, "#")
    for (x, y) in [(42, 28), (43, 28), (42, 29), (44, 35), (44, 36), (45, 36), (34, 31), (34, 32)]:
        put(x, y, "T")
    for y in range(29, 36):
        for x in range(46, 51):
            if (x + y) % 4 != 0:
                put(x, y, ",")
    # Rock border.
    for x in range(W):
        g[0][x] = "#"
        g[H - 1][x] = "#"
    for y in range(H):
        g[y][0] = "#"
        g[y][W - 1] = "#"
    rows = ["".join(r) for r in g]
    d = {"schema": "aow.map/2", "id": "siege_vale", "name": "Siege Vale", "width": W, "height": H,
         "legend": LEGEND, "starts": [list(WEST), list(EAST)], "rows": rows}
    with open(os.path.join(ROOT, "data", "maps", "siege_vale.json"), "w") as f:
        f.write(json.dumps(d, indent=1) + "\n")
    print("\n".join(rows))


if __name__ == "__main__":
    main()
