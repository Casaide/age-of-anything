#!/usr/bin/env python3
"""Builds the river test map (data/maps/river_test.json): a small map for the sim tests of
milestone 15's land: a river down the middle (ground units cross only at the ford, top, and
the bridge, bottom; amphibians swim it anywhere), a block of forest on the west bank (it
blocks movement and sight until felled), reed and bush for the bots.

  python3 tools/maps/river_test.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 40, 24
LEGEND = {".": "grass", "#": "rock", "R": "river", "f": "ford", "T": "tree", '"': "reeds", "b": "bugbush"}


def main():
    g = [["." for _ in range(W)] for _ in range(H)]
    for y in range(H):
        for x in range(19, 22):
            g[y][x] = "R"
    for y in (4, 5):
        for x in range(19, 22):
            g[y][x] = "f"
    for y in range(9, 15):
        for x in range(8, 11):
            g[y][x] = "T"
    for y in range(2, 4):
        for x in range(2, 6):
            g[y][x] = '"'
    for x in range(30, 32):
        g[19][x] = "b"
    for i in range(W):
        g[0][i] = g[H - 1][i] = "#"
    for i in range(H):
        g[i][0] = g[i][W - 1] = "#"
    d = {"schema": "aow.map/2", "id": "river_test", "name": "River test", "width": W, "height": H,
         "legend": LEGEND, "rows": ["".join(r) for r in g], "starts": [[4, 18], [35, 12]],
         "bridges": [[19, 16, 21, 16]]}
    with open(os.path.join(ROOT, "data", "maps", "river_test.json"), "w") as fh:
        json.dump(d, fh, indent=1)
        fh.write("\n")
    print("\n".join(d["rows"]))


if __name__ == "__main__":
    main()
