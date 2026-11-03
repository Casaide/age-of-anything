"""Voxel buildings, an experiment (Dominic, 2026-11-03: "test a few buildings, see how close we can make them using
voxels"; then "textures and lights real issue"). Writes data/voxel/buildings/: materials (colours, and surface
patterns: stone blocks, planks, corrugated sheet with rust, roof tiles, worn plaster, mottled stone; lights that glow)
and bodies (the voxel format's points and shapes) for a Roman house and Town Center, the rats' shack and silo, two
trees and a rock. The game doesn't load this folder; src/voxel_buildings.lobster draws them. Body units: z up, y to
the front, x across; a tile is about 62. Each is drawn facing as the game's baked one is (its front to the lower left).
Run from the repo root: python3 tools/voxel/buildings.py"""
import json, math, os

OUT = "data/voxel/buildings"


def pat(kind, size=(1, 1), depth=0.15, mix=0.0, color2="#000000", **kw):
    return {"kind": kind, "size": list(size), "depth": depth, "mix": mix, "color2": color2, **kw}


MATS = {
    "plaster": {"rgb": "#e6dfd0", "pattern": pat("wear", depth=0.16, mix=0.55, color2="#8f7f63")},
    "plaster_lit": {"rgb": "#f2ece0", "pattern": pat("wear", depth=0.12, mix=0.4, color2="#8f7f63")},
    "stone": {"rgb": "#b3ab9b", "pattern": pat("blocks", (6.5, 3.2), 0.12, 1.0, "#78705f")},
    "paving": {"rgb": "#a9a395", "pattern": pat("blocks", (7.5, 7.5), 0.1, 1.0, "#6f6a5e")},
    "stone_dark": {"rgb": "#8c8475", "pattern": pat("mottle", depth=0.3)},
    "tile": {"rgb": "#b4482c", "fur": True, "pattern": pat("tiles", (3.0, 3.2), 0.14, 0.3, "#6d6236")},
    "tile_dark": {"rgb": "#8a3320", "pattern": pat("tiles", (3.0, 3.2), 0.1)},
    "timber": {"rgb": "#7a5230", "pattern": pat("planks", (4.5, 1), 0.14, 1.0, "#2e1e12")},
    "timber_dark": {"rgb": "#4e321e", "pattern": pat("planks", (3.0, 1), 0.12, 1.0, "#22160d")},
    "crate": {"rgb": "#9a6c3c", "pattern": pat("planks", (2.2, 1), 0.14, 1.0, "#3a2614")},
    "glass": {"rgb": "#ffe9a0", "glow": True},
    "fire": {"rgb": "#ffb040", "glow": True},
    "shutter": {"rgb": "#a33f2a", "pattern": pat("planks", (1.4, 1), 0.1, 1.0, "#5a2014")},
    "sheet": {"rgb": "#b9bdc3", "pattern": pat("ripples", (0.55, 26), 0.2, 0.6, "#9a5a30")},
    "sheet_round": {"rgb": "#b9bdc3", "pattern": pat("ripples", (0.55, 40), 0.2, 0.8, "#9a5a30", round=True)},
    "sheet_dark": {"rgb": "#80858d", "pattern": pat("ripples", (0.55, 26), 0.2, 0.7, "#7a4424")},
    "steel": {"rgb": "#a7acb4"},
    "pipe": {"rgb": "#2c2a2a"},
    "cheese": {"rgb": "#f0c23c", "pattern": pat("mottle", depth=0.12)},
    "sack": {"rgb": "#c9b58a", "pattern": pat("mottle", depth=0.2)},
    "leaf": {"rgb": "#3f6b29", "fur": True, "pattern": pat("mottle", depth=0.35)},
    "leaf_dark": {"rgb": "#2b4c1d", "fur": True, "pattern": pat("mottle", depth=0.35)},
    "cypress": {"rgb": "#24401f", "fur": True, "pattern": pat("mottle", depth=0.35)},
    "bark": {"rgb": "#5a4030", "pattern": pat("planks", (1.2, 1), 0.2, 0.6, "#2e1e12")},
    "rock": {"rgb": "#c4b69a", "pattern": pat("mottle", depth=0.28)},
    "rock_dark": {"rgb": "#8d877a", "pattern": pat("mottle", depth=0.28)},
    "pot": {"rgb": "#b0582e", "pattern": pat("mottle", depth=0.15)},
    "team": {"rgb": "#cc2921"},
}


def box(c, half, n=(0, 1, 0), mat="plaster", rnd=0.3):
    """A box round c facing along n, half sizes across, thick and up (the format's); facing x (a side wall's), half
    is given as the world's x, y, z like the rest."""
    if tuple(n) == (1, 0, 0): half = (half[1], half[0], half[2])
    return {"box": ["o", *c], "n": list(n), "half": list(half), "round": rnd, "mat": mat}


def cap(a, b, r, mat, hard=True):
    return {"cap": ["o", *a], "to": ["o", *b], "r": list(r), "mat": mat, "hard": hard}


def ball(c, r, mat, hard=False):
    return {"ball": ["o", *c], "r": r, "mat": mat, "hard": hard}


def disc(c, n, r, thick, mat):
    return {"disc": ["o", *c], "n": list(n), "r": [r, thick], "mat": mat}


def gable_roof(w, d, z0, rise, over, mat, ridge, along_y=False):
    """A gable roof over a w x d (half sizes) box from eave height z0 up `rise`, the ridge along x (or y), overhanging
    by `over`: two sloped planes (the material's pattern lays the tiles or ripples down them), a ridge, and the gable
    ends filled under it (in `fill`)."""
    out = []
    run = (d if not along_y else w) + over
    ang = math.atan2(rise, run)
    slope = math.hypot(run, rise)
    span = (w if not along_y else d) + over * 0.5
    for s in (1, -1):
        n = (0, s * math.sin(ang), math.cos(ang)) if not along_y else (s * math.sin(ang), 0, math.cos(ang))
        c = (0, s * run / 2, z0 + rise / 2) if not along_y else (s * run / 2, 0, z0 + rise / 2)
        out.append(box(c, (span, 1.1, slope / 2), n, mat, 0.2))
        k = 8.2
        cf = (0, s * (run / 2 - k * math.sin(ang)), z0 + rise / 2 - k * math.cos(ang)) if not along_y else (s * (run / 2 - k * math.sin(ang)), 0, z0 + rise / 2 - k * math.cos(ang))
        out.append(box(cf, (span - over * 0.5, 8.0, slope / 2 - 2.5), n, "plaster", 0.0))
    if not along_y: out.append(cap((-span, 0, z0 + rise + 1.0), (span, 0, z0 + rise + 1.0), (1.8, 1.8), ridge))
    else: out.append(cap((0, -span, z0 + rise + 1.0), (0, span, z0 + rise + 1.0), (1.8, 1.8), ridge))
    return out


def facet_rock(cx, cy, size, seed, mat="rock"):
    """A rock of flat cut faces: boxes at angles, a few overlapping, the edges barely rounded."""
    out = []
    rnd = (seed * 9301 + 49297) % 233280
    def r():
        nonlocal rnd
        rnd = (rnd * 9301 + 49297) % 233280
        return rnd / 233280.0
    for k in range(4):
        n = (r() - 0.5, r() - 0.5, 0.6 + r() * 0.4)
        h = (size * (0.5 + r() * 0.5), size * (0.45 + r() * 0.4), size * (0.35 + r() * 0.3))
        out.append(box((cx + (r() - 0.5) * size, cy + (r() - 0.5) * size, h[2] * 0.8), h, n, mat, 0.25))
    return out


def barrel(x, y, z=0, r=2.6, h=6):
    return [cap((x, y, z + r * 0.4), (x, y, z + h - r * 0.4), (r, r), "timber", False),
            disc((x, y, z + 1.2), (0, 0, 1), r + 0.25, 0.35, "steel"), disc((x, y, z + h - 1.2), (0, 0, 1), r + 0.25, 0.35, "steel")]


def crate(x, y, z, s):
    return [box((x, y, z + s), (s, s, s), (0.25, 1, 0), "crate", 0.2)]


def firewood(x, y, n=3):
    out = []
    for row in range(n):
        for k in range(n - row):
            yy = y + (k - (n - row - 1) / 2) * 2.3
            out.append(cap((x - 4, yy, 1.1 + row * 2.0), (x + 4, yy, 1.1 + row * 2.0), (1.1, 1.1), "bark"))
    return out


def roman_house():
    s = [box((0, 0, 2.5), (38, 30, 2.5), mat="stone", rnd=0.5)]
    s.append(box((0, 0, 21), (33, 25, 16)))
    s += gable_roof(33, 25, 37, 17, 5, "tile", "tile_dark")
    s.append(box((-8, 25.6, 12), (5, 0.8, 9.5), mat="timber_dark"))
    s.append(box((-8, 26.2, 22.5), (6.5, 0.8, 1.2), mat="stone"))
    for y in (-8, 8):  # the gable end facing the lower right: two shuttered, lit windows
        s.append(box((-33.6, y, 24), (0.7, 3, 4.5), (1, 0, 0), "glass"))
        s.append(box((-33.9, y - 4.6, 24), (0.7, 1.5, 4.8), (1, 0, 0), "shutter"))
        s.append(box((-33.9, y + 4.6, 24), (0.7, 1.5, 4.8), (1, 0, 0), "shutter"))
    s.append(box((0, 25.4, 35.5), (33, 0.9, 1.2), mat="team"))
    s.append(box((20, -10, 58), (2.6, 2.6, 9), mat="stone_dark"))
    s.append(box((20, -10, 67.5), (3.4, 3.4, 0.8), mat="stone"))
    s.append(ball((-20, 31, 7.5), 3.2, "pot"))
    s.append(cap((-20, 31, 9.5), (-20, 31, 13.5), (1.3, 1.6), "pot"))
    s.append(box((14, 31, 4.5), (3.2, 2.4, 0.5), mat="timber"))
    s += [cap((14 + dx, 31 + dy, 0), (14 + dx, 31 + dy, 4.2), (0.4, 0.4), "timber_dark") for dx in (-2.6, 2.6) for dy in (-1.8, 1.8)]
    s += facet_rock(30, 33, 2.4, 3, "rock_dark")
    return {"_doc": "A Roman house (2 tiles): plaster on a stone plinth, a red tile gable roof, a door, shuttered lit windows, the team's band under the eaves, a chimney, an amphora and a stool.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def roman_tc():
    s = [box((0, 0, 3), (52, 62, 3), mat="paving", rnd=0.6)]
    for k in range(3):
        s.append(box((0, 62 + 3 + k * 3.5, 1 + k * 2), (30, 3.5 - k * 0.5, 1 + k * 2), mat="stone"))
    s.append(box((0, -8, 30), (40, 42, 24)))
    s += gable_roof(46, 58, 54, 20, 4, "tile", "tile_dark", along_y=True)
    for x in (-36, -12, 12, 36):
        s.append(cap((x, 50, 6), (x, 50, 52), (3.2, 2.8), "plaster_lit", False))
        s.append(box((x, 50, 7), (4.2, 4.2, 1.2), mat="stone"))
        s.append(box((x, 50, 52.5), (4.2, 4.2, 1.2), mat="stone"))
    s.append(box((0, 50, 55), (47, 4, 2), mat="plaster"))
    s.append(box((0, 54.2, 55), (47, 0.8, 0.9), mat="team"))
    s.append(disc((0, 58, 63), (0, 1, 0.25), 5.0, 0.8, "team"))
    s.append(box((0, 34.4, 20), (8, 0.8, 14), mat="timber_dark"))
    for y in (-30, -6, 18):  # the long side to the lower right: lit windows, the team's band
        s.append(box((-40.6, y, 32), (0.7, 4, 6), (1, 0, 0), "glass"))
    s.append(box((-40.4, -8, 52), (0.9, 42, 1.4), (1, 0, 0), "team"))
    s.append(cap((-46, 66, 0), (-46, 66, 60), (0.9, 0.7), "timber_dark"))
    s.append(ball((-46, 66, 61), 1.4, "pot", True))
    for a in (0, 120, 240):  # a brazier on the steps
        x, y = 22 + 2.4 * math.cos(math.radians(a)), 70 + 2.4 * math.sin(math.radians(a))
        s.append(cap((x, y, 0), (22, 70, 9), (0.4, 0.4), "timber_dark"))
    s.append(disc((22, 70, 9.5), (0, 0, 1), 3.4, 0.7, "steel"))
    s.append(ball((22, 70, 11), 2.4, "fire", True))
    s.append(ball((-30, 70, 3.5), 3.0, "pot"))
    s.append(cap((-30, 70, 5.5), (-30, 70, 9), (1.2, 1.5), "pot"))
    return {"_doc": "A Roman Town Center (3 tiles): a temple on a paved podium with steps, four columns, a tiled roof along its length, lit windows, the team's band and disc, a flag, a brazier, an amphora.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def rat_shack():
    s = [box((0, 0, 1), (40, 30, 1), mat="stone_dark", rnd=0.4)]
    s.append(box((0, 0, 19), (36, 26, 17), mat="timber"))
    ang = math.atan2(15, 31)
    for side in (1, -1):
        n = (0, side * math.sin(ang), math.cos(ang))
        s.append(box((0, side * 15.5, 44), (41, 1.1, math.hypot(31, 15) / 2), n, "sheet", 0.1))
    s.append(cap((-41, 0, 52), (41, 0, 52), (1.2, 1.2), "sheet_dark"))
    s.append(box((0, 0, 40), (36, 12, 4), mat="timber"))
    s.append(box((-36.3, 0, 44), (0.6, 14, 4), (1, 0, 0), "timber"))
    s.append(box((-10, 26.4, 12), (5, 0.8, 10), mat="timber_dark"))
    for k in range(3):
        s.append(box((-10, 29 + k * 2.2, 0.6 + k * 1.2), (6, 1.1, 0.6 + k * 1.2), mat="timber_dark"))
    s.append(box((14, 26.4, 24), (4.5, 0.6, 4.5), mat="glass"))
    s.append(box((-36.6, -9, 24), (0.6, 4.5, 4.5), (1, 0, 0), "glass"))
    s.append(box((-36.6, 9, 24), (0.6, 4.5, 4.5), (1, 0, 0), "glass"))
    s.append(box((-37, 0, 15), (0.8, 7, 15), (1, 0, 0), "sheet_dark", 0.1))
    s.append(cap((22, -10, 40), (22, -10, 64), (2.6, 2.6), "pipe"))
    s.append(cap((22, -10, 64), (27, -10, 68), (2.6, 2.4), "pipe"))
    s.append(disc((34, 30, 5), (0.3, 1, 0), 5.5, 2.6, "cheese"))
    s += barrel(-26, 31)
    s += crate(-32, 22, 0, 3.2)
    s += firewood(26, 31)
    s += facet_rock(-18, 34, 3.6, 7) + facet_rock(4, 34, 3.0, 11)
    s.append(ball((-40, 10, 3), 3.2, "sack"))
    s.append(box((0, 26.2, 36), (36, 0.8, 1.0), mat="team"))
    return {"_doc": "The rats' Town Center: a timber shack under a roof of corrugated sheet (two slopes, rust), a stove pipe, lit windows, a sheet patch on the gable, steps, a cheese wheel, a barrel, a crate, firewood, rocks and a sack at the door, the team's band under the eaves.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def rat_silo():
    s = [disc((0, 0, 1.0), (0, 0, 1), 25, 1.0, "stone_dark")]
    s.append(disc((0, 0, 23.0), (0, 0, 1), 22, 21.0, "sheet_round"))
    for z in (14, 32):
        s.append(disc((0, 0, z), (0, 0, 1), 22.9, 0.9, "steel"))
    s.append(disc((0, 0, 44.7), (0, 0, 1), 23.2, 0.8, "sheet"))
    s += facet_rock(6, -4, 3.2, 5, "rock")
    s.append(cap((-6, -2, 45), (-6, -2, 54), (1.5, 1.5), "pipe"))
    s.append(box((-2, 23.0, 14), (7, 1.4, 11), (0.1, 1, 0), "pipe", 0.2))
    s.append(box((-13, 23.8, 15), (4.5, 1.2, 12), (0.45, 1, 0), "sheet_dark", 0.1))
    s.append(box((14, 18.5, 24), (2.4, 0.6, 2.0), (0.6, 0.8, 0), "team"))
    return {"_doc": "The rats' silo: a round tank of corrugated sheet with two steel hoops, a flat corrugated lid with a stone on it, a vent pipe, a dark door with a sheet panel leant beside it, the team's plate.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


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
    s = facet_rock(0, 0, 7, 1) + facet_rock(9, 4, 4.5, 2) + facet_rock(-7, 5, 3.5, 4)
    return {"_doc": "Rocks of flat cut faces: boxes at angles, overlapping, mottled.", "points": {"o": {"at": [0, 0, 0]}}, "shapes": s}


def main():
    os.makedirs(OUT + "/bodies", exist_ok=True)
    mats = {"_doc": "The voxel buildings' materials (an experiment: the game doesn't load this folder). pattern: a surface texture in the colour (view/voxel.lobster, vx_patterned): blocks, planks, ripples, tiles, wear, mottle; size in body units; glow: a light."}
    mats.update(MATS)
    json.dump(mats, open(OUT + "/materials.json", "w"), indent=1)
    for name, f in [("roman_house", roman_house), ("roman_tc", roman_tc), ("rat_shack", rat_shack), ("rat_silo", rat_silo), ("cypress", cypress), ("broadleaf", broadleaf), ("rock", rock)]:
        b = f()
        b["size"] = {"cypress": 1.7, "broadleaf": 1.6, "rock": 2.2}.get(name, 1.0)
        json.dump(b, open(f"{OUT}/bodies/{name}.json", "w"), indent=1)
        print(name, len(b["shapes"]), "shapes")


main()
