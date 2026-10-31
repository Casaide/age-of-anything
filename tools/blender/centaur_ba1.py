"""The centaur's horse half sculpted (round BA1, 2026-10-30), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/centaur.py -- assets/models/ a|b

Dominic, 2026-10-30, of the centaurs beside the war elephant: "they are clearly a bunch of spheres put together".
Two looks:
- a (the riding horse): a light, deep-chested half; the withers sweep up into the man's waist in one line.
- b (the heavy horse): broader and lower, a rounder croup, thick legs with feathered fetlocks.
In the game's part units and axes (sculpt.py), in the frame of src/model/units2.lobster's fused pony before its
lift (PONY_LIFT 3; the game lifts it): the hips of the legs at y 14 (fore x 8.5 and 7, hind -9.5 and -10, z 3.4),
the man's seat at (10, 16.5) with his hips 18 over it, his tunic's hem at about 31.8.
- body_centaur_<look>: one surface from croup to breast, the waist rising out of the withers to the man's hem;
  the shoulder, the haunch, the belly; the tail.
- leg_horse_<look>, leg_horse_hind_<look>: one leg from its hip (the origin) in pieces turned about their joints by
  the game (units2.lobster hoof_joints): "upper" (forearm or gaskin to the knee or hock at (0, -6)), "cannon" (to the
  fetlock at (0.3, -13.8)), "hoof" (the pastern and hoof, the hoof's sole at -16.1).
Materials "hide" (the coat), "mane" (tail, feathering), "horn" (hooves): the game swaps in its own.
"""
import sys, os, math
sys.dont_write_bytecode = True
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sculpt import *

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, look = args[0], args[1]
HEAVY = look == "b"


def mats():
    return [mat("hide", (0.55, 0.42, 0.3)), mat("mane", (0.2, 0.15, 0.12)), mat("horn", (0.16, 0.14, 0.12))]


HIDE, MANE, HORN = 0, 1, 2
W = 1.12 if HEAVY else 1.0   # the heavy horse's breadth

TOP = [(-16.2, 23.2), (-14.6, 24.8), (-10.5, 25.8 if HEAVY else 25.5), (-6.0, 24.8), (-1.0, 24.4), (4.0, 25.2), (6.5, 27.6), (8.0, 31.0),
       (9.5, 33.8), (11.5, 34.4), (13.0, 32.0), (14.2, 28.0), (15.4, 26.0), (16.4, 24.0)]
BOT = [(-16.2, 18.0), (-13.5, 15.6), (-9.0, 13.2 if HEAVY else 13.6), (-3.0, 11.8 if HEAVY else 12.4), (2.0, 11.6 if HEAVY else 12.2),
       (7.0, 12.6), (11.0, 13.8), (14.0, 15.0), (16.4, 16.4)]
HALF_LO = [(-15.5, 2.6 * W), (-12.0, 5.6 * W), (-8.0, 6.2 * W), (-2.0, 6.5 * W), (3.0, 6.4 * W), (7.0, 5.6 * W), (11.0, 4.8 * W), (14.0, 4.0 * W), (16.4, 3.0 * W)]
HALF_HI = [(-15.5, 2.0 * W), (-12.0, 4.8 * W), (-8.0, 5.1 * W), (-2.0, 5.3 * W), (3.0, 5.0 * W), (6.5, 4.2), (9.0, 3.5), (11.5, 3.4), (14.0, 3.0), (16.4, 2.4)]
BODY = Loft(-17.4, 17.2, TOP, BOT, HALF_LO, HALF_HI)


def body_shape(q, x, u, side):
    s = 1.0 if side >= 0 else -1.0
    out = V(0, 0, s)
    # The shoulder blade lying back from the point of the shoulder; the forearm's top under it.
    q = q + out * 0.8 * bump(q, V(7.5, 21.0, 5.6 * s * W), (3.5, 5.0, 3.0))
    q = q + out * 0.5 * bump(q, V(10.5, 16.5, 4.6 * s * W), (2.5, 3.0, 2.5))
    # The haunch: the point of the hip, the round of the quarter, the stifle low and forward.
    q = q + out * 0.7 * bump(q, V(-7.5, 23.0, 5.2 * s * W), (2.5, 2.5, 2.5))
    q = q + out * 1.0 * bump(q, V(-10.5, 19.0, 5.6 * s * W), (4.5, 5.0, 3.0))
    q = q + out * 0.6 * bump(q, V(-6.0, 15.0, 6.0 * s * W), (2.5, 3.0, 2.5))
    # The breast: two muscles either side of the front, a groove between; the girth behind the elbow.
    q = q + V(0.3, 0, 0.5 * s) * bump(q, V(14.6, 18.5, 2.4 * s), (2.5, 4.0, 2.5))
    q = q - V(0.4, 0, 0) * bump(q, V(16.0, 18.5, 0.0), (1.5, 3.5, 1.0))
    q = q - out * 0.4 * bump(q, V(4.0, 14.5, 6.0 * s * W), (2.5, 2.5, 2.5))
    # The man's waist: his back's hollow over the withers, the front of his belly over the breast.
    q = q - V(0.5, 0, 0) * bump(q, V(8.4, 32.0, 0.0), (1.5, 3.0, 2.0))
    return q


def body():
    reset()
    M = mats()
    loft("body", M, BODY, body_shape, n=2.6)
    k = 1.15 if HEAVY else 1.0
    tail = [V(-15.0, 23.6), V(-17.2, 22.0), V(-18.6, 17.0), V(-18.8, 12.0), V(-18.2, 8.6)]
    limb("tail", [M[MANE]], tail, [1.2 * k, 1.8 * k, 1.9 * k, 1.5 * k, 0.6], segs=14, steps=6, squash=(0.6, 1.0))
    finish(out_dir + "body_centaur_%s.glb" % look, smooth=("body", "tail"))


# ------------------------------------------------------------------ the legs
KNEE, FETLOCK, PASTERN, HOOF = V(0.0, -6.0), V(0.3, -13.8), V(0.8, -14.8), V(1.0, -15.4)
T = 1.2 if HEAVY else 1.0


def leg(hind):
    reset()
    M = mats()
    if hind:   # the gaskin, broad behind, down to the hock, its point standing out behind
        limb("upper", M, [V(1.2, 2.6), V(-0.2, -1.0), V(-0.3, -4.0), V(0.0, -6.4)], [2.7 * T, 2.1 * T, 1.45 * T, 1.15 * T],
             segs=16, steps=8, squash=(0.65, 1.0))
        ball("upper_hock", M, V(-1.1, -5.7), (0.9 * T, 1.0 * T, 0.7 * T), segs=12)
    else:      # the forearm, muscled at the top, slim to the knee; the knee a flat knob
        limb("upper", M, [V(0.0, 2.6), V(0.4, -1.2), V(0.1, -4.6), V(0.0, -6.2)], [2.5 * T, 1.9 * T, 1.2 * T, 1.1 * T],
             segs=16, steps=8, squash=(0.75, 1.0))
        ball("upper_knee", M, V(0.25, -6.0), (1.2 * T, 1.3 * T, 1.0 * T), segs=12)
    # The cannon: flat and slim, the tendon behind it, to the fetlock's knob.
    limb("cannon", M, [V(0.0, -6.4), V(0.15, -10.0), V(0.3, -13.6)], [0.95 * T, 0.8 * T, 0.9 * T], segs=12, steps=6, squash=(0.7, 1.0))
    ball("cannon_fetlock", M, FETLOCK + V(0.05, 0.1), (1.05 * T, 1.0 * T, 0.85 * T), segs=12)
    # The pastern sloping forward to the hoof; the hoof's wall flaring to its sole.
    limb("hoof", M, [FETLOCK, PASTERN + V(0.1, -0.1)], [0.85 * T, 0.8 * T], segs=12, steps=3)
    limb("hoof_wall", [M[HORN]], [HOOF + V(-0.05, 0.4), HOOF + V(0.05, -0.7)], [1.0 * T, 1.45 * T], segs=16, steps=3, cap=(0.4, 0.05),
         squash=(0.9, 1.0))
    if HEAVY:   # the feathering: long hair from the fetlock falling over the hoof
        limb("hoof_feather", [M[MANE]], [FETLOCK + V(-0.3, 0.8), FETLOCK + V(-0.1, -0.8), HOOF + V(-0.3, -0.2)], [1.2, 1.7, 1.75],
             segs=14, steps=4, cap=(0.5, 0.2))
    finish(out_dir + "leg_horse%s_%s.glb" % ("_hind" if hind else "", look), smooth=("upper", "cannon"))


body()
leg(False)
leg(True)
