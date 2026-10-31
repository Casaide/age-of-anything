"""The war elephant sculpted (round BA1, 2026-10-30), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/elephant.py -- assets/models/ a|b

Dominic, 2026-10-30: "quality here is bad, they are clearly a bunch of spheres put together". Two looks:
- a (the eastern elephant): an arched back, highest over the middle; a twin-domed forehead with the hollow of the
  temple behind the eye; small ears folded down; short tusks.
- b (the bush elephant): the shoulder higher than the rump, the back dipping behind it; a sloping forehead; great fan
  ears; long tusks curving up.
In the game's part units and axes (sculpt.py), in the frames of src/model/siege.lobster's elephant:
- body_elephant_<look>: the barrel from rump to neck (the ground at y 0, the hips at y 30, the howdah's floor at
  (-3, 52.5) on the back, the neck at (28.5, 42)), the shoulder and haunch masses over the legs, the belly, the tail.
- head_elephant_<look>: from the neck (the origin): the skull, the trunk hanging to y -36.5 with its rings, the lower
  lip, the eyes, the ears against the neck, the tusks (their tips where siege.lobster puts the bronze caps).
- leg_elephant_<look>: one leg from its hip (the origin) in pieces "upper" (to the knee at (0, -13.8)), "lower" (to
  the ankle at (0, -27.6)) and "foot" (the pad to the ground at -30, its toenails forward); the game turns each about
  its joint per walk step.
Materials "hide", "dark" (ears' backs, the lip, the tail's tuft), "ivory", "eye": the game swaps in its own.
"""
import sys, os, math
sys.dont_write_bytecode = True
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sculpt import *

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, look = args[0], args[1]


def mats():
    return [mat("hide", (0.62, 0.6, 0.58)), mat("dark", (0.45, 0.43, 0.42)), mat("ivory", (0.93, 0.89, 0.78)), mat("eye", (0.08, 0.06, 0.05)), mat("nail", (0.6, 0.57, 0.52))]


HIDE, DARK, IVORY, EYE, NAIL = 0, 1, 2, 3, 4

# ------------------------------------------------------------------ the body
if look == "a":
    TOP = [(-28.0, 37.0), (-25.0, 45.0), (-19.0, 50.0), (-10.0, 52.6), (-2.0, 53.2), (6.0, 52.6), (14.0, 52.4), (20.0, 52.8), (26.0, 51.6), (31.0, 48.6)]
else:
    TOP = [(-28.0, 36.0), (-25.0, 44.0), (-19.0, 49.0), (-10.0, 51.6), (-2.0, 52.0), (6.0, 53.2), (13.0, 55.0), (20.0, 53.4), (26.0, 51.8), (31.0, 48.6)]
BOT = [(-28.0, 33.0), (-24.0, 27.0), (-17.0, 24.0), (-8.0, 21.6), (1.0, 21.0), (9.0, 22.4), (17.0, 25.0), (24.0, 30.0), (31.0, 37.0)]
HALF_LO = [(-28.0, 6.0), (-24.0, 11.5), (-15.0, 14.6), (-4.0, 15.6), (6.0, 15.2), (16.0, 14.6), (24.0, 11.0), (31.0, 7.0)]
HALF_HI = [(-28.0, 5.0), (-24.0, 9.0), (-15.0, 11.0), (-4.0, 11.6), (6.0, 11.2), (16.0, 11.0), (24.0, 8.6), (31.0, 6.0)]
BODY = Loft(-29.5, 32.0, TOP, BOT, HALF_LO, HALF_HI)


def body_shape(q, x, u, side):
    s = 1.0 if side >= 0 else -1.0
    out = Vector((0, 0, s))
    # The shoulder (over the forelegs) and the haunch (over the hind legs): masses standing out of the barrel's
    # sides, the elbow's point low behind the shoulder.
    q = q + out * 2.8 * bump(q, V(14.0, 31.0, 11.0 * s), (9.0, 12.0, 6.0))
    q = q + out * 1.6 * bump(q, V(11.0, 26.0, 12.0 * s), (4.0, 4.0, 5.0))
    q = q + out * 2.6 * bump(q, V(-14.0, 33.0, 11.0 * s), (10.0, 13.0, 6.0))
    q = q + V(-0.8, 0, 0) * bump(q, V(-26.0, 38.0, 0.0), (4.0, 8.0, 8.0))
    # The flank sinks a little between them; the spine shows down the back.
    q = q - out * 1.0 * bump(q, V(0.0, 36.0, 13.0 * s), (8.0, 9.0, 6.0))
    q = q + V(0, 0.7, 0) * bump(q, V(0.0, BODY.at(0.0, 1.0, 0).y, 0.0), (30.0, 3.0, 2.5))
    if look == "b":   # the withers' hump in front of the howdah
        q = q + V(0, 1.2, 0) * bump(q, V(13.0, 55.0, 0.0), (6.0, 4.0, 6.0))
    return q


def body():
    reset()
    M = mats()
    loft("body", M, BODY, body_shape, n=2.3)
    tail = [V(-28.5, 40.5), V(-31.0, 34.0), V(-31.4, 27.0), V(-30.6, 22.0)]
    limb("tail", M, tail, [1.4, 0.9, 0.7, 0.55], segs=10, steps=6)
    limb("tuft", [M[DARK]], [V(-30.6, 22.6), V(-30.4, 19.4)], [0.8, 0.5], segs=10, steps=3)
    finish(out_dir + "body_elephant_%s.glb" % look, smooth=("body",))


# ------------------------------------------------------------------ the head
if look == "a":
    S_TOP = [(-9.0, 3.0), (-6.0, 8.5), (-1.0, 11.0), (3.5, 10.5), (6.5, 7.0), (8.8, 1.0)]
    S_BOT = [(-9.0, -3.0), (-5.0, -8.0), (0.0, -10.0), (5.0, -9.0), (8.8, -3.0)]
    S_HALF_LO = [(-9.0, 7.0), (-3.0, 8.6), (3.0, 7.6), (8.8, 4.6)]
    S_HALF_HI = [(-9.0, 6.0), (-3.0, 7.0), (3.0, 6.0), (8.8, 3.8)]
    TRUNK = [V(5.0, -1.5), V(8.8, -6.5), V(10.8, -14.0), V(11.2, -22.0), V(10.8, -29.0), V(12.2, -34.0), V(14.4, -36.0)]
    TUSK = [V(5.0, -7.0, 3.4), V(8.6, -10.6, 4.4), V(12.2, -11.4, 5.2)]
    TUSK_R = [1.3, 1.0, 0.55]
else:
    S_TOP = [(-9.0, 3.0), (-6.0, 8.0), (-1.5, 10.0), (3.0, 8.8), (6.5, 5.0), (8.8, 0.0)]
    S_BOT = [(-9.0, -3.0), (-5.0, -8.0), (0.0, -10.0), (5.0, -9.0), (8.8, -3.5)]
    S_HALF_LO = [(-9.0, 6.6), (-3.0, 8.0), (3.0, 7.0), (8.8, 4.4)]
    S_HALF_HI = [(-9.0, 5.6), (-3.0, 6.6), (3.0, 5.6), (8.8, 3.6)]
    TRUNK = [V(5.6, -2.5), V(9.2, -7.5), V(11.0, -15.0), V(11.4, -23.0), V(11.0, -29.5), V(12.4, -34.2), V(14.6, -36.0)]
    TUSK = [V(5.0, -7.0, 3.6), V(10.0, -12.6, 4.6), V(15.6, -13.2, 5.8), V(19.6, -9.8, 6.8)]
    TUSK_R = [1.5, 1.2, 0.8, 0.4]
HEAD_K = 1.16   # the skull a size up on the trunk and tusks: an elephant's head is a third of its height
S_TOP, S_BOT, S_HALF_LO, S_HALF_HI = ([(x * HEAD_K, v * HEAD_K) for (x, v) in t] for t in (S_TOP, S_BOT, S_HALF_LO, S_HALF_HI))
SKULL = Loft(-10.0 * HEAD_K, 9.6 * HEAD_K, S_TOP, S_BOT, S_HALF_LO, S_HALF_HI)


def skull_shape(q, x, u, side):
    s = 1.0 if side >= 0 else -1.0
    q = q / HEAD_K
    if look == "a":   # the twin domes and the groove between them
        for k in (1.0, -1.0):
            q = q + V(0.3, 1.4, 0.5 * k) * bump(q, V(1.5, 10.0, 3.4 * k), (4.0, 3.0, 3.0))
        q = q - V(0, 0.8, 0) * bump(q, V(2.0, 11.0, 0.0), (5.0, 2.0, 1.2))
    # The temple's hollow behind the eye; the cheek and the jaw's bulge under it; the brow over the eye.
    q = q - V(0, 0, s) * 1.3 * bump(q, V(-0.5, 3.0, 7.5 * s), (3.0, 3.0, 3.0))
    q = q + V(0, 0, s) * 0.9 * bump(q, V(0.5, -5.5, 7.0 * s), (4.0, 3.0, 3.0))
    q = q + V(0.3, 0.4, 0.3 * s) * bump(q, V(5.0, 3.6, 5.8 * s), (2.0, 1.2, 2.0))
    return q * HEAD_K


def trunk_disp(s, a):
    # rings round the trunk, the rings closer and finer towards the tip; flattened a little on its inner side
    k = s * s
    return 1.0 + 0.05 * math.sin((s * 18.0 + k * 10.0) * math.pi) * (0.4 + 0.6 * s)


SURFACE = []   # the head's skull and the neck behind it as built (a BVH tree), for the ears to lie against


def side_at(x, y):
    """How far out the head, or the neck and shoulder behind it, stand at (x, y) in the head's frame (the near side)."""
    hit, _n, _i, _d = SURFACE[0].ray_cast(G(V(x, y, 40.0)), G(V(0.0, 0.0, -1.0)))
    return -hit.y if hit else 0.0


def ear(M, s):
    """An ear hanging from its root behind the temple and lying back over the neck: a curved flap, thin, standing off
    the neck more towards its free edge, its middle bowed out, a rolled rim round the edge (a: the top edge folded
    forward and out; b: a great fan, its lower lobe hanging to a point)."""
    if look == "a":
        r_top, r_bot = V(-4.6, 6.6), V(-6.2, -4.6)
        def width(v): return 1.0 + 6.0 * math.sin(math.pi * min(1.0, v * 1.3)) ** 0.6 * (1.0 - 0.45 * v)
        def drop(v): return 1.5 + 5.0 * v ** 1.6
    else:
        r_top, r_bot = V(-4.8, 8.4), V(-6.8, -6.0)
        def width(v): return 1.5 + 11.5 * math.sin(math.pi * min(v * 1.15, 1.0)) ** 0.65
        def drop(v): return 1.5 + 9.0 * v ** 2.2
    NS, NT = 14, 8

    def mid(v, t):   # the flap's middle surface at v (0 its top, 1 its bottom) and t (0 the root, 1 the free edge)
        root = lerp(r_top, r_bot, v) + V(-0.6 * math.sin(math.pi * v), 0, 0)
        x = root.x - width(v) * t
        y = root.y - drop(v) * t * t
        off = 0.3 + (1.4 if look == "a" else 2.6) * t + 0.7 * math.sin(math.pi * t) * math.sin(math.pi * v)
        if look == "a":   # the top edge folds forward and out
            off += 1.2 * t * t * max(0.0, 1.0 - v / 0.35)
        off += 0.12 * math.sin(v * math.pi * 9.0) * t   # the veins' ridges fanning out from the root
        return V(x, y, s * (side_at(x, y) + off))

    ob = obj("ear%s" % ("n" if s > 0 else "f"), [M[HIDE], M[DARK]])
    bm = bmesh.new()
    th = lambda t: 0.45 - 0.1 * t
    outer = [[bm.verts.new(G(mid(i / NS, j / NT) + V(0, 0, s * th(j / NT)))) for j in range(NT + 1)] for i in range(NS + 1)]
    inner = [[bm.verts.new(G(mid(i / NS, j / NT) - V(0, 0, s * th(j / NT)))) for j in range(NT + 1)] for i in range(NS + 1)]
    for i in range(NS):
        for j in range(NT):
            bm.faces.new((outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1])).material_index = 0
            bm.faces.new((inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j], inner[i][j])).material_index = 1
    for i in range(NS):   # the root's edge and the free edge
        for j in (0, NT):
            bm.faces.new((outer[i][j], inner[i][j], inner[i + 1][j], outer[i + 1][j])).material_index = 0
    for i in (0, NS):     # the top and bottom edges
        for j in range(NT):
            bm.faces.new((outer[i][j], outer[i][j + 1], inner[i][j + 1], inner[i][j])).material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def head():
    reset()
    M = mats()
    skull = loft("skull", M, SKULL, skull_shape, n=2.2)
    neck = loft("neck", M, BODY, lambda q, x, u, side: body_shape(q, x, u, side) - V(28.5, 42.0, 0.0), n=2.3)
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    for ob in (skull, neck):
        bm.from_mesh(ob.data)
    SURFACE.append(BVHTree.FromBMesh(bm))
    bm.free()
    bpy.data.objects.remove(neck)
    r = [4.8, 4.4, 3.6, 3.0, 2.5, 2.0, 1.5]
    limb("trunk", M, TRUNK, r, segs=20, steps=8, squash=(1.0, 0.92), disp=trunk_disp)
    limb("tip", [M[DARK]], [TRUNK[-1] + V(0.4, -0.3), TRUNK[-1] + V(1.2, -0.6)], [1.3, 1.1], segs=12, steps=2, cap=(0.4, 0.4))
    ball("lip", [M[DARK]], V(6.4, -9.2), (2.4, 1.3, 2.6), segs=14)
    for s in (1.0, -1.0):
        ear(M, s)
        limb("tusk", [M[IVORY]], [V(p.x, p.y, p.z * s) for p in TUSK], TUSK_R, segs=10, steps=6)
        eye = SKULL.at(5.0, 0.6, s * 0.9)
        ball("eye", [M[EYE]], eye, (0.95, 0.5, 0.6), segs=12, rot=(0.0, 0.0, -12.0))
        ball("lid", [M[HIDE]], eye + V(-0.1, 0.5, -0.15 * s), (1.4, 0.55, 0.7), segs=12, rot=(0.0, 0.0, -12.0))
    finish(out_dir + "head_elephant_%s.glb" % look, smooth=("skull", "trunk", "earn", "earf"))


# ------------------------------------------------------------------ a leg
KNEE, ANKLE, GROUND = -13.8, -27.6, -30.0


def leg_disp(s, a):   # soft folds across, fading out above the ankle
    return 1.0 + 0.008 * math.sin(s * 11.0 * math.pi + 0.8 * math.sin(a * 3.0)) * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.75, 1.0, s))


def leg():
    reset()
    M = mats()
    thick = 1.0 if look == "a" else 1.06
    # The upper leg: the arm or thigh, broad up in the body, the knee's front standing out a little.
    limb("upper", M, [V(0.0, 6.0), V(0.4, 0.0), V(0.2, -8.0), V(0.0, KNEE)], [4.6 * thick, 6.0 * thick, 5.5 * thick, 5.0 * thick],
         segs=24, steps=8, squash=(0.8, 1.0), cap=(1.0, 0.6))
    # The lower leg, a pillar flaring into the foot, wrinkled across.
    limb("lower", M, [V(0.0, KNEE + 2.0), V(0.1, -20.0), V(0.0, ANKLE + 0.6)], [4.9 * thick, 4.7 * thick, 5.4 * thick], segs=24, steps=10,
         squash=(0.95, 1.0), disp=leg_disp, cap=(0.6, 0.4))
    # The foot: a round pad to the ground, its toenails round the front.
    limb("foot", M, [V(0.0, ANKLE + 1.6), V(0.0, GROUND + 1.0)], [5.25 * thick, 5.7 * thick], segs=28, steps=4, cap=(0.2, 0.2))
    for k in range(4):
        a = math.radians(-54.0 + k * 36.0)
        ball("foot", [M[NAIL]], V(5.4 * thick * math.cos(a), GROUND + 0.8, 5.4 * thick * math.sin(a)), (1.0, 0.7, 0.9), segs=10)
    # A leg's pieces keep their names (the game turns each about its joint); the toenails are part of the foot.
    finish(out_dir + "leg_elephant_%s.glb" % look, smooth=("upper", "lower"))


body()
head()
leg()
