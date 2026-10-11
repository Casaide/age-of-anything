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

# ---------------------------------------------------------------- se: three-quarter, facing right
TORSO_SE = [   # neck point at (12, 0)
    "...........fff..",
    ".........ffFFFf.",
    "........fFFFFFff",
    ".......fFFFtUTff",
    "......gfFFtUttTf",
    ".....gffFFFttTff",
    "....ggfFFPPPPff.",
    "...ggffFPPPPpf..",
    "...ggffFPPPPpf..",
    "...gggfFPPPppf..",
    "...gggffPPppf...",
    "...ggggffppff...",
    "....ggggffff....",
]
LEGS_SE = [    # three walk frames: standing, far leg forward, near leg forward; hips at row 0
    [
        "....gggg.fff....",
        "....gg....ff....",
        "...gg.....ff....",
        "...gg......ff...",
        "..pp.......pp...",
        ".ppp.......ppp..",
    ],
    [
        "....gggg.fff....",
        ".....gg..ff.....",
        "......gg.ff.....",
        ".......gg.ff....",
        "........ppp.....",
        ".......pppp.....",
    ],
    [
        "....gggg.fff....",
        "...gg.....ff....",
        "..gg.......ff...",
        ".gg.........ff..",
        "pp...........pp.",
        "pp...........ppp",
    ],
]
HEAD_SE = [    # neck point at (5, 10); a long tapered snout with the nose at its tip
    "................",
    "................",
    "................",
    "..ffFFFFf.......",
    ".fFFFFFFFff.....",
    ".fFFFFeWFFfff...",
    ".fFFFFFFFFffffP.",
    ".ffFFFFFFfffffpp",
    "..fffFFfffffoo..",
    "...gggffggg.....",
    "....gggg........",
]
EARS_SE = [    # drawn last, over any head gear: big round rat ears, always showing
    ".ff.....ff.",
    "fPPf...fPPf",
    "fPpf...fPpf",
    "fPpf...fPpf",
    ".ff.....ff.",
]
TAIL_SE = [    # from the rump (top right) curling out behind and along the ground
    "........pp",
    "......pp..",
    "....pp....",
    "..pp......",
    ".p........",
    "p.........",
    "p.........",
    ".pp.......",
]
POT_SE = [     # a small cooking pot on the crown, between the ears
    "..mm..",
    ".MMmm.",
    "MMMmmn",
    "nnnnnn",
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
SHIELD_SE = [  # a bottle-cap shield on the far arm: crimped metal rim, painted in the team colour
    ".nmMm.",
    "nmtttm",
    "mtUttm",
    "mtttTm",
    "nmtTTn",
    ".nmmn.",
]


def spearman_se(frame):
    cv = canvas(32, 40)
    stamp(cv, TAIL_SE, 0, 28)
    stamp(cv, SHIELD_SE, 5, 23)
    stamp(cv, TORSO_SE, 6, 20)
    stamp(cv, LEGS_SE[frame], 6, 32)
    stamp(cv, HEAD_SE, 13, 10)
    stamp(cv, POT_SE, 15, 10)
    stamp(cv, EARS_SE, 12, 8)
    stamp(cv, SPEAR_ARM_SE, 19, 5)
    return outline(cv)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    pal = palette("#d8d4cc", "#e8a8a8", "#b03a2a")   # a white rat, pink skin, red cloth
    frames = [spearman_se(f) for f in range(3)]
    grass = hexc("#56782e")
    png(os.path.join(OUT, "rat_spear_se_x8.png"), sheet(frames, 32, 40, 3), pal, 8, grass)
    png(os.path.join(OUT, "rat_spear_se_x2.png"), sheet(frames, 32, 40, 3), pal, 2, grass)
    print("wrote", OUT)
