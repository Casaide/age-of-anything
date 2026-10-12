#!/usr/bin/env python3
"""Builds the hill test map (data/maps/hill_test.json): a small map for the sim tests of
milestone 15's high ground: a plateau (level 1) in the middle with a ramp up its west face and
a knoll (level 2) on it with its own ramp; cliffs all round otherwise. Start 0 is on the low
ground to the west, start 1 on the plateau.

  python3 tools/maps/hill_test.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 32, 20
LEGEND = {".": "grass", "#": "rock"}


def main():
    g = [["." for _ in range(W)] for _ in range(H)]
    for i in range(W):
        g[0][i] = g[H - 1][i] = "#"
    for i in range(H):
        g[i][0] = g[i][W - 1] = "#"
    h = [["0" for _ in range(W)] for _ in range(H)]
    for y in range(4, 16):
        for x in range(14, 24):
            h[y][x] = "1"
    for y in range(7, 11):
        for x in range(18, 22):
            h[y][x] = "2"
    for y in (11, 12, 13):
        h[y][13] = "a"   # up the plateau's west face
    for y in (8, 9):
        h[y][17] = "b"   # up onto the knoll
    d = {"schema": "aow.map/2", "id": "hill_test", "name": "Hill test", "width": W, "height": H,
         "legend": LEGEND, "rows": ["".join(r) for r in g], "heights": ["".join(r) for r in h],
         "starts": [[4, 10], [19, 13]]}
    with open(os.path.join(ROOT, "data", "maps", "hill_test.json"), "w") as fh:
        json.dump(d, fh, indent=1)
        fh.write("\n")
    print("\n".join(d["heights"]))


if __name__ == "__main__":
    main()
