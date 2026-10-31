"""The centaur's horse half sculpted, round BA2 (2026-10-30), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/centaur_ba2.py -- assets/models/ c|d|e

Dominic on round BA1's centaurs (centaur_ba1.py, looks a and b): "the centaurs looks mad": a pale bloated barrel as wide as
it was deep, short, the man sitting on its middle like a rider with no legs, sticks for legs. Here a horse's build: the
barrel two thirds as wide as it is deep, a long back, the man standing up out of the breast (his tunic's front over the
breast's front, the withers sweeping up into his back), the legs thick enough to read, darker from the knee down.
- c: a riding horse, as big as the pony.
- d: the same horse a size up (1.2): the man's torso in proportion to a horse's.
- e: a heavy horse (1.1): broad, deep, thick-legged, feathered fetlocks.
In the game's part units and axes (sculpt.py), before the lift the game gives the body (units2.lobster CENTAUR_*), at
look c's size (finish scales d and e): the legs' hips at y 14 (fore x 10 and 8.5, hind -11 and -11.5, z 2.9), the man's
seat at (12.5, 10.5) with his hips 18 over it and his tunic's hem at 25.8 (just over the withers), its skirt x 9 to
16.6, z 5.1 each side.
- body_centaur_<look>: one surface from buttock to breast, the waist rising out of the withers under the man's hem;
  the shoulder, the haunch, the belly; the tail.
- leg_horse_<look>, leg_horse_hind_<look>: one leg from its hip in pieces the game turns about their joints
  (units2.lobster hoof_joints): "upper" (forearm or gaskin to the knee or hock at (0, -6)), "cannon" (to the fetlock at
  (0.3, -13.8)), "hoof" (the pastern and hoof, the sole at -16.1).
Materials "hide" (the coat), "points" (the coat darker, knee down), "mane" (tail, feathering), "horn" (hooves).
"""
import sys, os, math
sys.dont_write_bytecode = True
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sculpt import *

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, look = args[0], args[1]
K = {"c": 1.0, "d": 1.2, "e": 1.1}[look]
HEAVY = look == "e"
W = 1.3 if HEAVY else 1.15   # breadth (the barrel near three quarters as wide as deep)
T = 1.6 if HEAVY else 1.35   # the legs' thickness over a true horse's (they must read a few pixels wide)


def mats():
    return [mat("hide", (0.55, 0.42, 0.3)), mat("points", (0.3, 0.22, 0.16)), mat("mane", (0.2, 0.15, 0.12)), mat("horn", (0.16, 0.14, 0.12))]


HIDE, POINTS, MANE, HORN = 0, 1, 2, 3

TOP = [(-19.0, 22.0), (-17.0, 25.0), (-13.0, 26.2), (-8.0, 25.4), (-2.0, 24.9), (4.0, 25.6), (7.5, 27.0), (9.5, 28.4),
       (11.0, 29.4), (13.0, 29.6), (14.8, 28.6), (15.9, 26.8), (16.7, 24.0), (17.2, 21.6)]
BOT = [(-19.0, 19.0), (-16.5, 15.6), (-12.0, 13.6), (-5.0, 12.8 if not HEAVY else 12.2), (2.0, 12.4 if not HEAVY else 11.8),
       (7.0, 12.8), (10.5, 13.6), (13.5, 15.0), (16.0, 17.0), (17.2, 19.2)]
HALF_LO = [(-19.0, 2.4 * W), (-15.0, 4.4 * W), (-10.0, 4.8 * W), (-3.0, 5.0 * W), (3.0, 5.0 * W), (8.0, 4.4 * W), (12.0, 3.9 * W),
           (15.0, 3.1 * W), (17.2, 2.2 * W)]
HALF_HI = [(-19.0, 1.9 * W), (-15.0, 3.8 * W), (-10.0, 3.9 * W), (-3.0, 3.9 * W), (3.0, 3.8 * W), (7.0, 3.2), (10.0, 3.2), (13.0, 3.3),
           (15.0, 2.7), (17.2, 2.0)]
BODY = Loft(-20.2, 18.0, TOP, BOT, HALF_LO, HALF_HI)


def body_shape(q, x, u, side):
    s = 1.0 if side >= 0 else -1.0
    out = V(0, 0, s)
    # The shoulder blade lying back from the point of the shoulder, the forearm's top under it.
    q = q + out * 0.6 * bump(q, V(9.5, 21.0, 4.6 * s * W), (3.5, 5.0, 2.5))
    q = q + out * 0.5 * bump(q, V(12.5, 16.5, 3.8 * s * W), (2.5, 3.0, 2.0))
    # The haunch: the point of the hip, the round of the quarter, the stifle low and forward.
    q = q + out * 0.5 * bump(q, V(-9.0, 23.0, 4.0 * s * W), (2.5, 2.5, 2.0))
    q = q + out * 0.8 * bump(q, V(-13.0, 19.5, 4.4 * s * W), (4.5, 5.0, 2.5))
    q = q + out * 0.5 * bump(q, V(-8.0, 15.0, 4.8 * s * W), (2.5, 3.0, 2.0))
    # The breast: two muscles either side of the front, a groove between; the girth's hollow behind the elbow.
    q = q + V(0.3, 0, 0.4 * s) * bump(q, V(16.0, 19.0, 1.8 * s), (2.0, 4.0, 2.0))
    q = q - V(0.35, 0, 0) * bump(q, V(17.2, 19.0, 0.0), (1.2, 3.5, 0.8))
    q = q - out * 0.35 * bump(q, V(6.0, 14.5, 4.8 * s * W), (2.5, 2.5, 2.0))
    # The spine's line down the back to the croup; the man's back hollowing as it rises out of the withers.
    q = q - V(0, 0.25, 0) * bump(q, V(-4.0, 25.2, 0.0), (10.0, 1.0, 0.8))
    q = q - V(0.4, 0, 0) * bump(q, V(10.2, 28.0, 0.0), (1.5, 2.0, 2.0))
    return q


def body():
    reset()
    M = mats()
    loft("body", M, BODY, body_shape, n=2.5)
    k = 1.2 if HEAVY else 1.0
    # The tail: set high on the croup, arching out, the hair falling in a long flattened switch.
    tail = [V(-18.6, 23.4), V(-20.8, 22.6), V(-22.2, 18.4), V(-22.6, 13.0), V(-22.2, 9.0)]
    limb("tail", [M[MANE]], tail, [1.0 * k, 1.5 * k, 1.8 * k, 1.5 * k, 0.5], segs=14, steps=6, squash=(0.55, 1.0))
    finish(out_dir + "body_centaur_%s.glb" % look, smooth=("body", "tail"), scale=K)


def leg(hind):
    reset()
    M = mats()
    pt = [M[POINTS]]
    if hind:   # the gaskin, broad behind, down to the hock, its point standing out behind
        limb("upper", M, [V(1.0, 2.6), V(-0.3, -1.0), V(-0.3, -4.0), V(0.0, -6.4)], [2.3 * T, 1.75 * T, 1.15 * T, 0.95 * T],
             segs=16, steps=8, squash=(0.7, 1.0))
        ball("upper_hock", M, V(-0.9, -5.7), (0.8 * T, 0.9 * T, 0.6 * T), segs=12)
    else:      # the forearm, muscled at the top, slim to the knee; the knee a flat knob
        limb("upper", M, [V(0.0, 2.6), V(0.4, -1.2), V(0.1, -4.6), V(0.0, -6.2)], [2.2 * T, 1.6 * T, 1.0 * T, 0.92 * T],
             segs=16, steps=8, squash=(0.75, 1.0))
        ball("upper_knee", M, V(0.2, -6.0), (1.0 * T, 1.1 * T, 0.85 * T), segs=12)
    # The cannon: flat and slim, darker, to the fetlock's knob.
    limb("cannon", pt, [V(0.0, -6.4), V(0.15, -10.0), V(0.3, -13.6)], [0.8 * T, 0.7 * T, 0.76 * T], segs=12, steps=6, squash=(0.75, 1.0))
    ball("cannon_fetlock", pt, V(0.35, -13.7), (0.9 * T, 0.85 * T, 0.75 * T), segs=12)
    # The pastern sloping forward to the hoof; the hoof's wall flaring to its sole.
    limb("hoof", pt, [V(0.3, -13.8), V(0.9, -14.9)], [0.72 * T, 0.68 * T], segs=12, steps=3)
    limb("hoof_wall", [M[HORN]], [V(0.95, -14.95), V(1.05, -16.05)], [0.82 * T, 1.15 * T], segs=16, steps=3, cap=(0.4, 0.05), squash=(0.9, 1.0))
    if HEAVY:   # the feathering: long hair from the fetlock falling over the hoof
        limb("hoof_feather", [M[MANE]], [V(0.0, -13.0), V(0.2, -14.6), V(0.7, -15.7)], [1.1, 1.55, 1.6], segs=14, steps=4, cap=(0.5, 0.2))
    finish(out_dir + "leg_horse%s_%s.glb" % ("_hind" if hind else "", look), smooth=("upper", "cannon"), scale=K)


body()
leg(False)
leg(True)
