"""The centaur's horse half sculpted, round BA3 (2026-10-31), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/centaur.py -- assets/models/ f|g

Dominic on round BA2 (centaur_ba2.py, looks c, d, e): "the whole body shape is the issue, look more like a banana with
the human part perched on top". The BA2 top line rose at both ends over a sagging back, the belly curved up to meet it,
and the man sat on a hump in the middle of a long body. Here a horse's side: a level back, the croup no higher than the
withers, a short body (as long as the horse is tall at the withers), a straight belly tucking up only at the flank, the
buttock just behind the hind legs, and a deep upright chest at the front that the man grows out of: his front over the
chest's front, his tunic's hem on the withers, no hump.
- f: a riding horse, as big as the pony.
- g: the same a size up (1.15).
In the game's part units and axes (sculpt.py), before the lift the game gives the body (units2.lobster CENTAUR_*), at
look f's size (finish scales g): the legs' hips at y 14 (fore x 8.5 and 7, hind -9 and -9.5, z 2.9), the man's seat at
(11.7, 11.2) with his tunic's hem at 26.5, its skirt x 8.2 to 15.8.
- body_centaur_<look>: one surface from buttock to chest, rising into the man's waist at the front; the tail.
- leg_horse_<look>, leg_horse_hind_<look>: one leg from its hip in pieces the game turns about their joints
  (units2.lobster hoof_joints): "upper" (forearm or gaskin to the knee or hock at (0, -6)), "cannon" (to the fetlock at
  (0.3, -13.8)), "hoof" (the pastern and hoof, the sole at -16.1).
Materials "hide" (the coat), "points" (the coat darker, knee down), "mane" (tail), "horn" (hooves).
"""
import sys, os, math
sys.dont_write_bytecode = True
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sculpt import *

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, look = args[0], args[1]
K = {"f": 1.0, "g": 1.15}[look]
W = 1.15   # breadth (the barrel near three quarters as wide as deep)
T = 1.35   # the legs' thickness over a true horse's (they must read a few pixels wide)


def mats():
    return [mat("hide", (0.55, 0.42, 0.3)), mat("points", (0.3, 0.22, 0.16)), mat("mane", (0.2, 0.15, 0.12)), mat("horn", (0.16, 0.14, 0.12))]


HIDE, POINTS, MANE, HORN = 0, 1, 2, 3

TOP = [(-16.6, 21.6), (-16.0, 23.6), (-14.2, 25.0), (-11.0, 25.8), (-7.0, 25.6), (-2.0, 25.0), (3.0, 25.0), (6.5, 25.8),
       (9.0, 27.4), (11.0, 29.4), (13.0, 30.4), (15.0, 30.0), (16.0, 27.0)]
BOT = [(-16.6, 15.4), (-15.8, 13.4), (-13.6, 12.2), (-10.5, 12.0), (-7.5, 13.4), (-4.0, 13.9), (1.0, 13.0), (6.0, 12.4),
       (10.0, 12.4), (13.6, 14.0), (16.0, 17.0)]
HALF_LO = [(-16.6, 3.4 * W), (-13.0, 4.3 * W), (-8.0, 4.6 * W), (0.0, 4.9 * W), (7.0, 4.6 * W), (12.0, 3.9 * W), (16.0, 2.6 * W)]
HALF_HI = [(-16.6, 2.8 * W), (-12.0, 3.6 * W), (0.0, 3.7 * W), (6.0, 3.3), (10.0, 3.3), (13.0, 3.2), (16.0, 2.4)]
BODY = Loft(-17.2, 16.8, TOP, BOT, HALF_LO, HALF_HI)


def body_shape(q, x, u, side):
    s = 1.0 if side >= 0 else -1.0
    out = V(0, 0, s)
    # The shoulder blade lying back from the point of the shoulder, the forearm's top under it.
    q = q + out * 0.6 * bump(q, V(7.5, 20.5, 4.4 * s * W), (3.5, 5.0, 2.5))
    q = q + out * 0.5 * bump(q, V(10.0, 16.0, 3.8 * s * W), (2.5, 3.0, 2.0))
    # The haunch: the point of the hip, the round of the quarter, the stifle low and forward.
    q = q + out * 0.5 * bump(q, V(-7.0, 23.5, 4.0 * s * W), (2.5, 2.5, 2.0))
    q = q + out * 0.8 * bump(q, V(-11.5, 20.0, 4.3 * s * W), (4.5, 5.0, 2.5))
    q = q + out * 0.5 * bump(q, V(-6.5, 15.5, 4.7 * s * W), (2.5, 3.0, 2.0))
    # The chest: two muscles either side of the front, a groove between; the girth's hollow behind the elbow.
    q = q + V(0.3, 0, 0.4 * s) * bump(q, V(14.8, 18.5, 1.8 * s), (2.0, 4.0, 2.0))
    q = q - V(0.35, 0, 0) * bump(q, V(15.8, 18.5, 0.0), (1.2, 3.5, 0.8))
    q = q - out * 0.35 * bump(q, V(4.0, 14.5, 4.8 * s * W), (2.5, 2.5, 2.0))
    # The spine's line down the back; the man's back hollowing as it rises out of the withers.
    q = q - V(0, 0.2, 0) * bump(q, V(-2.0, 25.1, 0.0), (8.0, 1.0, 0.8))
    q = q - V(0.35, 0, 0) * bump(q, V(9.0, 26.8, 0.0), (1.5, 2.0, 2.0))
    return q


def body():
    reset()
    M = mats()
    loft("body", M, BODY, body_shape, n=2.7)
    # The tail: set on at the top of the buttock, arching out a little, the hair falling in a full switch.
    tail = [V(-15.8, 23.8), V(-17.6, 22.8), V(-18.4, 19.5), V(-18.6, 15.0), V(-18.3, 11.5)]
    limb("tail", [M[MANE]], tail, [0.9, 1.3, 1.6, 1.4, 0.5], segs=14, steps=6, squash=(0.6, 1.0))
    finish(out_dir + "body_centaur_%s.glb" % look, smooth=("body", "tail"), scale=K)


def leg(hind):
    reset()
    M = mats()
    pt = [M[POINTS]]
    if hind:   # the gaskin, broad behind, down to the hock, its point standing out behind
        limb("upper", M, [V(0.6, 1.0), V(-0.3, -1.0), V(-0.3, -4.0), V(0.0, -6.4)], [1.6 * T, 1.75 * T, 1.15 * T, 0.95 * T],
             segs=16, steps=8, squash=(0.7, 1.0))
        ball("upper_hock", M, V(-0.9, -5.7), (0.8 * T, 0.9 * T, 0.6 * T), segs=12)
    else:      # the forearm, muscled at the top, slim to the knee; the knee a flat knob
        limb("upper", M, [V(0.0, 1.0), V(0.4, -1.2), V(0.1, -4.6), V(0.0, -6.2)], [1.5 * T, 1.6 * T, 1.0 * T, 0.92 * T],
             segs=16, steps=8, squash=(0.75, 1.0))
        ball("upper_knee", M, V(0.2, -6.0), (1.0 * T, 1.1 * T, 0.85 * T), segs=12)
    # The cannon: flat and slim, darker, to the fetlock's knob.
    limb("cannon", pt, [V(0.0, -6.4), V(0.15, -10.0), V(0.3, -13.6)], [0.8 * T, 0.7 * T, 0.76 * T], segs=12, steps=6, squash=(0.75, 1.0))
    ball("cannon_fetlock", pt, V(0.35, -13.7), (0.9 * T, 0.85 * T, 0.75 * T), segs=12)
    # The pastern sloping forward to the hoof; the hoof's wall flaring to its sole.
    limb("hoof", pt, [V(0.3, -13.8), V(0.9, -14.9)], [0.72 * T, 0.68 * T], segs=12, steps=3)
    limb("hoof_wall", [M[HORN]], [V(0.95, -14.95), V(1.05, -16.05)], [0.82 * T, 1.15 * T], segs=16, steps=3, cap=(0.4, 0.05), squash=(0.9, 1.0))
    finish(out_dir + "leg_horse%s_%s.glb" % ("_hind" if hind else "", look), smooth=("upper", "cannon"), scale=K)


body()
leg(False)
leg(True)
