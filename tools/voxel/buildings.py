"""Voxel buildings, an experiment (Dominic, 2026-11-03: "test a few buildings, see how close we can make them using
voxels"). Writes data/voxel/buildings/: materials and bodies (the voxel format's bodies: points and shapes) for a
Roman house and Town Center, the rats' shack and silo, two trees and a rock. The game doesn't load this folder;
src/voxel_buildings.lobster draws them. Body units: z up, y to the front, x across; a tile is about 62.
Run from the repo root: python3 tools/voxel/buildings.py"""
import json, math, os

OUT = "data/voxel/buildings"
MATS = {
    "plaster": "#e6dfd0", "stone": "#b3ab9b", "stone_dark": "#8c8475", "tile": "#b4482c", "tile_dark": "#8a3320",
    "timber": "#7a5230", "timber_dark": "#4e321e", "glass": "#f4e39a", "shutter": "#a33f2a", "sheet": "#b9bdc3",
    "sheet_dark": "#7d828a", "pipe": "#2c2a2a", "cheese": "#f0c23c", "leaf": "#3f6b29", "leaf_dark": "#2b4c1d",
    "cypress": "#24401f", "bark": "#5a4030", "rock": "#8d877a", "pot": "#b0582e", "team": "#cc2921",
}
FUR = {"tile", "leaf", "leaf_dark", "cypress", "rock", "stone", "bark", "sheet"}


def box(c, half, n=(0, 1, 0), mat="plaster", rnd=0.3):
    return {"box": ["o", *c], "n": list(n), "half": list(half), "round": rnd, "mat": mat}


def cap(a, b, r, mat, hard=True):
    return {"cap": ["o", *a], "to": ["o", *b], "r": list(r), "mat": mat, "hard": hard}


def ball(c, r, mat, hard=False):
    return {"ball": ["o", *c], "r": r, "mat": mat, "hard": hard}


def disc(c, n, r, thick, mat):
    return {"disc": ["o", *c], "n": list(n), "r": [r, thick], "mat": mat}


def gable_roof(w, d, z0, rise, over, mat, dark, along_y=False, step=4.0):
    """A gable roof over a w x d (half sizes) box from eave height z0 up `rise`, the ridge along x (or y), overhanging
    by `over`, in rows of tiles from eave to ridge; and the gable ends filled under it."""
    out = []
    run = (d if not along_y else w) + over
    ang = math.atan2(rise, run)
    slope = math.hypot(run, rise)
    span = (w if not along_y else d) + over * 0.5
    for s in (1, -1):
        if not along_y:
            n = (0, s * math.sin(ang), math.cos(ang))
            c = (0, s * run / 2, z0 + rise / 2)
            out.append(box(c, (span, 1.0, slope / 2), n, mat, 0.2))
            out.append(box((0, s * (run / 2 - 8.2 * math.sin(ang)), z0 + rise / 2 - 8.2 * math.cos(ang)), (span - over * 0.5, 8.0, slope / 2 - 2.5), n, "plaster", 0.0))
            x = -span + step / 2
            while x < span:
                out.append(cap((x, s * run, z0 + 1.0), (x, 0, z0 + rise + 1.0), (1.25, 1.25), dark if int((x + span) / step) % 3 == 0 else mat))
                x += step
        else:
            n = (s * math.sin(ang), 0, math.cos(ang))
            c = (s * run / 2, 0, z0 + rise / 2)
            out.append(box(c, (span, 1.0, slope / 2), n, mat, 0.2))
            out.append(box((s * (run / 2 - 8.2 * math.sin(ang)), 0, z0 + rise / 2 - 8.2 * math.cos(ang)), (span - over * 0.5, 8.0, slope / 2 - 2.5), n, "plaster", 0.0))
            y = -span + step / 2
            while y < span:
                out.append(cap((s * run, y, z0 + 1.0), (0, y, z0 + rise + 1.0), (1.25, 1.25), dark if int((y + span) / step) % 3 == 0 else mat))
                y += step
    if not along_y: out.append(cap((-span, 0, z0 + rise + 1.4), (span, 0, z0 + rise + 1.4), (1.8, 1.8), dark))
    else: out.append(cap((0, -span, z0 + rise + 1.4), (0, span, z0 + rise + 1.4), (1.8, 1.8), dark))
    return out


def roman_house():
    s = [box((0, 0, 2.5), (38, 30, 2.5), mat="stone", rnd=0.5)]
    s.append(box((0, 0, 21), (33, 25, 16)))
    s += gable_roof(33, 25, 37, 17, 5, "tile", "tile_dark")
    s.append(box((-12, 25.6, 12), (5, 0.8, 9.5), mat="timber_dark"))
    s.append(box((-12, 26.2, 22.5), (6.5, 0.8, 1.2), mat="stone"))
    for x in (11, 22):
        s.append(box((x, 25.6, 25), (3, 0.7, 4.5), mat="glass"))
        s.append(box((x - 4.6, 25.9, 25), (1.5, 0.7, 4.8), mat="shutter"))
        s.append(box((x + 4.6, 25.9, 25), (1.5, 0.7, 4.8), mat="shutter"))
    s.append(box((0, 25.4, 35.5), (33, 0.9, 1.2), mat="team"))
    s.append(box((22, -10, 58), (2.6, 2.6, 9), mat="stone_dark"))
    s.append(box((22, -10, 67.5), (3.4, 3.4, 0.8), mat="stone"))
    s.append(ball((-24, 31, 6.5), 3.2, "pot"))
    s.append(cap((-24, 31, 8.5), (-24, 31, 12.5), (1.3, 1.6), "pot"))
    return {"_doc": "A Roman house (2 tiles): plaster on a stone plinth, a red tile gable roof, a door, shuttered windows, the team's band under the eaves, a chimney, an amphora.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def roman_tc():
    s = [box((0, 0, 3), (52, 62, 3), mat="stone", rnd=0.6)]
    for k in range(3):
        s.append(box((0, 62 + 3 + k * 3.5, 1 + k * 2), (30, 3.5 - k * 0.5, 1 + k * 2), mat="stone"))
    s.append(box((0, -8, 30), (40, 42, 24)))
    s += gable_roof(46, 58, 54, 20, 4, "tile", "tile_dark", along_y=True)
    for x in (-36, -12, 12, 36):
        s.append(cap((x, 50, 6), (x, 50, 52), (3.2, 2.8), "plaster", False))
        s.append(box((x, 50, 7), (4.2, 4.2, 1.2), mat="stone"))
        s.append(box((x, 50, 52.5), (4.2, 4.2, 1.2), mat="stone"))
    s.append(box((0, 50, 55), (47, 4, 2), mat="plaster"))
    s.append(box((0, 54.2, 55), (47, 0.8, 0.9), mat="team"))
    s.append(disc((0, 58, 63), (0, 1, 0.25), 5.0, 0.8, "team"))
    s.append(box((0, 34.4, 20), (8, 0.8, 14), mat="timber_dark"))
    for x in (-26, 26):
        s.append(box((x, 34.4, 32), (4, 0.7, 6), mat="glass"))
    s.append(cap((-46, 66, 0), (-46, 66, 60), (0.9, 0.7), "timber_dark"))
    s.append(box((-46, 70, 54), (0.4, 4, 3), mat="team"))
    return {"_doc": "A Roman Town Center (3 tiles): a temple on a stone podium with steps, four columns, a tiled roof along its length, the team's band and disc on the pediment, a flag.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def corrugated_slope(x0, x1, y_eave, z_eave, z_ridge, mat, dark, step=2.4):
    out = []
    x = x0 + step / 2
    k = 0
    while x < x1:
        out.append(cap((x, y_eave, z_eave), (x, 0, z_ridge), (0.9, 0.9), dark if k % 2 else mat))
        x += step
        k += 1
    return out


def rat_shack():
    s = [box((0, 0, 1), (40, 30, 1), mat="stone_dark", rnd=0.4)]
    s.append(box((0, 0, 19), (36, 26, 17), mat="timber"))
    for x in range(-34, 36, 6):
        s.append(box((x, 26.3, 19), (0.5, 0.5, 17), mat="timber_dark", rnd=0.0))
    for side in (1, -1):
        n = (0, side * math.sin(math.atan2(14, 31)), math.cos(math.atan2(14, 31)))
        s.append(box((0, side * 15.5, 43), (40, 1.0, 17), n, "sheet", 0.1))
        s += [dict(c, **{}) for c in corrugated_slope(-40, 40, side * 31, 36.5, 51, "sheet", "sheet_dark")]
    s.append(box((0, 0, 40), (36, 20, 4), mat="timber"))
    s.append(box((-10, 26.4, 12), (5, 0.8, 10), mat="timber_dark"))
    for k in range(3):
        s.append(box((-10, 29 + k * 2.2, 0.6 + k * 1.2), (6, 1.1, 0.6 + k * 1.2), mat="timber_dark"))
    s.append(box((16, 26.4, 26), (4, 0.6, 4), mat="glass"))
    s.append(box((-36.4, 0, 26), (0.6, 4, 4), mat="glass"))
    s.append(cap((26, -10, 40), (26, -10, 62), (2.6, 2.6), "pipe"))
    s.append(cap((26, -10, 62), (31, -10, 66), (2.6, 2.4), "pipe"))
    s.append(disc((-40, 18, 9), (1, 0.2, 0), 7, 3.5, "cheese"))
    s.append(box((31, 30, 4), (5, 4, 4), mat="timber_dark", rnd=0.2))
    s.append(box((0, 26.2, 36), (36, 0.8, 1.0), mat="team"))
    return {"_doc": "The rats' Town Center: a timber shack under a corrugated sheet roof, a stove pipe, a cheese wheel, a crate, the team's band under the eaves.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def rat_silo():
    s = [disc((0, 0, 1.5), (0, 0, 1), 26, 1.5, "stone_dark")]
    r = 22
    n = 40
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = r * math.cos(a), r * math.sin(a)
        s.append(cap((x, y, 3), (x, y, 44), (1.5, 1.5), "sheet" if k % 2 else "sheet_dark"))
    s.append(disc((0, 0, 23.5), (0, 0, 1), 21, 20.5, "sheet_dark"))
    for z in (12, 26, 40):
        s.append(disc((0, 0, z), (0, 0, 1), 23.4, 0.9, "sheet"))
    for k in range(6):
        s.append(disc((0, 0, 45 + k * 2), (0, 0, 1), 23 - k * 3.6, 1.2, "sheet"))
    s.append(ball((0, 0, 58), 3.5, "sheet"))
    s.append(cap((8, 6, 52), (8, 6, 60), (1.3, 1.3), "pipe"))
    s.append(box((0, 22.5, 12), (6, 1.5, 9), mat="sheet_dark"))
    s.append(box((-9, 22.5, 12), (1.5, 2.5, 10), mat="sheet"))
    s.append(box((18, 14, 22), (2.5, 0.6, 2.5), (0.6, 0.8, 0), "team"))
    return {"_doc": "The rats' silo: a round tank of corrugated sheet in bands, a stepped lid, a vent pipe, a door, the team's plate.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def cypress():
    s = [cap((0, 0, 0), (0, 0, 10), (1.6, 1.2), "bark")]
    for k in range(9):
        z = 8 + k * 6
        r = 8.5 * math.sin(math.pi * (k + 1) / 10) + 1.2
        s.append(ball((0.3 * (k % 2), 0, z), r, "cypress" if k % 3 else "leaf_dark"))
    return {"_doc": "A cypress: a dark green spire of melted balls on a short trunk.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def broadleaf():
    s = [cap((0, 0, 0), (0, 0, 22), (3.0, 2.0), "bark", False), cap((0, 0, 18), (7, 3, 28), (1.4, 1.0), "bark"), cap((0, 0, 18), (-6, -4, 27), (1.4, 1.0), "bark")]
    for k, (x, y, z, r) in enumerate([(0, 0, 34, 12), (9, 4, 30, 9), (-9, -3, 30, 9), (4, -9, 32, 8), (-4, 9, 32, 8), (2, 2, 42, 8), (-7, 6, 38, 7), (7, -6, 38, 7)]):
        s.append(ball((x, y, z), r, "leaf" if k % 2 == 0 else "leaf_dark"))
    return {"_doc": "A broadleaf tree: a crown of melted balls on a forked trunk.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def rock():
    s = []
    for (x, y, z, r) in [(0, 0, 4, 7), (6, 3, 3, 5), (-6, 2, 3, 5), (2, -5, 3, 5), (1, 1, 8, 4.5)]:
        s.append(ball((x, y, z), r, "rock"))
    s.append(box((3, 2, 7), (3, 3, 2), (0.3, 0.9, 0.2), "rock", 0.8))
    return {"_doc": "A rock: lumps melted together.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def main():
    os.makedirs(OUT + "/bodies", exist_ok=True)
    mats = {"_doc": "The voxel buildings' materials (an experiment: the game doesn't load this folder)."}
    for k, v in MATS.items():
        mats[k] = {"rgb": v, "fur": k in FUR} if k in FUR else {"rgb": v}
    json.dump(mats, open(OUT + "/materials.json", "w"), indent=1)
    for name, f in [("roman_house", roman_house), ("roman_tc", roman_tc), ("rat_shack", rat_shack), ("rat_silo", rat_silo), ("cypress", cypress), ("broadleaf", broadleaf), ("rock", rock)]:
        b = f()
        b["size"] = {"cypress": 1.7, "broadleaf": 1.6, "rock": 2.2}.get(name, 1.0)
        json.dump(b, open(f"{OUT}/bodies/{name}.json", "w"), indent=1)
        print(name, len(b["shapes"]), "shapes")


main()
