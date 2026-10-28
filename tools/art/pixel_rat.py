#!/usr/bin/env python3
"""The rat, drawn in 2D (the 2D vertical slice): parts per facing in the pixel kit's semantic
letters (see tests/pixel_kit.py). A hunched rat: back curved, chest forward, head low and forward,
ears up and never covered, a long tail. Facings drawn: se (three-quarter, facing right and towards
us); the others follow once this one is right.

Run: python3 tests/pixel_rat.py   (writes previews to docs/concepts/2d/)
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_kit import *

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "concepts", "2d")

# ---------------------------------------------------------------- se: facing down-right on the map
# Drawn from the game's raised camera (about 30 degrees down): the top of the head, pot and
# shoulders show, the far foot sits higher than the near one, the tail lies on the ground.
TORSO_SE = [   # hunched, seen from above: the curved back's top shows, narrow waist; neck at (10, 0)
    ".........fFf....",
    "......gfFFFFf...",
    ".....gfFFFFFFf..",
    "....ggfFFFFFFf..",
    "....ggffFtUtff..",
    "...gggffFtttTf..",
    "...gggfPPPPPf...",
    "...ggffPPPPpf...",
    "....ggfPPPPpf...",
    "....ggffPPppf...",
    ".....ggffppf....",
    "......ggfff.....",
    "......gggg......",
]
LEGS_SE = [    # hips at row 0; the far (left) foot higher on the ground than the near (right) one
    [
        "......gg.ff.....",
        "......gg..ff....",
        ".....gg....ff...",
        ".....pp.....ff..",
        "....ppp......ff.",
        ".............ppp",
        "............pppp",
    ],
    [
        "......gg.ff.....",
        ".......gg.ff....",
        ".......gg..ff...",
        "......ppp...ff..",
        ".............pp.",
        "............ppp.",
        "................",
    ],
    [
        "......gg.ff.....",
        ".....gg...ff....",
        "....gg.....ff...",
        "...pp.......ff..",
        "..ppp........ff.",
        "..............pp",
        ".............ppp",
    ],
]
HEAD_SE = [    # seen from above: the crown shows, a long snout down-right
    "....fFFFf........",
    "...fFFFFFff......",
    "...fFFFFFFff.....",
    "...ffFFeWFfff....",
    "....ffFFFFffffg..",
    ".....ffFFFffffffP",
    "......gfffffffopp",
    ".......gggffgg...",
    "........ggg......",
]
EARS_SE = [    # drawn last, over any head gear: big round rat ears, always showing
    ".ff......ff.",
    "fPPf....fPPf",
    "fPpf....fPpf",
    ".fpf....fpf.",
]
TAIL_SE = [    # lying on the ground behind, a flat curve seen from above
    "...........pp",
    ".........pp..",
    "......ppp....",
    "...ppp.......",
    ".pp..........",
    "p............",
    ".pp..........",
    "...ppp.......",
]
POT_SE = [     # a small cooking pot on the crown, seen from above: its rim's top shows
    "..nnnn..",
    ".nMMMMn.",
    "nMMMmmmn",
    "nmmmmmmn",
    ".nnnnnn.",
]
SPEAR_ARM_SE = [   # the near arm forward holding a spear upright; grip at (4, 17)
    "...M.",
    "..MMm",
    "..MMm",
    "..Mmn",
    "...m.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "fF.h.",
    ".fFPP",
    "..fPP",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
    "...h.",
]
SHIELD_SE = [  # a bottle-cap shield on the far arm, seen a little from above: an ellipse
    "..nmMmn.",
    ".nmtttmn",
    "nmtUtttm",
    "nmttttTm",
    ".nmtTTmn",
    "..nmmn..",
]
SHADOW = [     # the ground shadow (drawn first, in ink, under everything)
    "....oooooooooo....",
    "..oooooooooooooo..",
    ".oooooooooooooooo.",
    "..oooooooooooooo..",
    "....oooooooooo....",
]


def spearman_se(frame):
    cv = canvas(34, 42)
    stamp(cv, TAIL_SE, 0, 30)
    stamp(cv, SHIELD_SE, 5, 22)
    stamp(cv, TORSO_SE, 7, 20)
    stamp(cv, LEGS_SE[frame], 7, 32)
    stamp(cv, HEAD_SE, 12, 11)
    stamp(cv, POT_SE, 14, 9)
    stamp(cv, EARS_SE, 12, 9)
    stamp(cv, SPEAR_ARM_SE, 21, 8)
    cv = outline(cv)
    shadow = canvas(34, 42)
    stamp(shadow, SHADOW, 9, 36)
    for y in range(42):   # the shadow goes under, as a darker ground (marked 'z')
        for x in range(34):
            if shadow[y][x] == "o" and cv[y][x] == ".":
                cv[y][x] = "z"
    return cv


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    pal = palette("#d8d4cc", "#e8a8a8", "#b03a2a")   # a white rat, pink skin, red cloth
    pal["z"] = hexc("#3c5420")   # the shadow on the grass
    frames = [spearman_se(f) for f in range(3)]
    grass = hexc("#56782e")
    png(os.path.join(OUT, "rat_spear_se_x8.png"), sheet(frames, 32, 40, 3), pal, 8, grass)
    png(os.path.join(OUT, "rat_spear_se_x2.png"), sheet(frames, 32, 40, 3), pal, 2, grass)
    print("wrote", OUT)
