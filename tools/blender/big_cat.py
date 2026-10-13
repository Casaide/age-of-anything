"""Cats as mounts (concept round RM1, "OR, we need a new mount for rats? cat? tiger?": Dominic),
modelled by script (Blender 5, headless):

    blender -b --python tools/blender/big_cat.py -- assets/models/body_cat.glb body cat
    blender -b --python tools/blender/big_cat.py -- assets/models/head_cat.glb head cat
    (and tiger for the tiger)

Built in the game's part units like tools/blender/capybara.py: facing +X, up +Z (glTF turns
that into Godot's +X forward, +Y up). The body stands at its height on the game's own legs (hung
from anchors in scenes/art_pixel/rat_mount_concepts.gd), the neck included; the head is in its
own frame from the neck point. The coat's markings are faces given another material by where they
sit (no textures): "fur", "stripe", "pale" (belly, chest, muzzle), "nose", "eye", "iris",
"ear_in". The game swaps in its own colours.

cat    a scruffy sewer alley cat: lean, deep-chested, tucked waist; a round skull, a short muzzle,
       big upright pointed ears (the near one notched from a fight), big eyes; mackerel tabby
       stripes, a dark line down the spine, the tabby's M on the brow, a pale chest
tiger  heavier and longer, a broad head with a ruff of cheek fur and a longer muzzle, small
       rounded ears; bold dark stripes on orange, white cheeks, muzzle and belly
lean   the alley cat again (C2, Dominic on C: "I think you've almost tried to force it to horse
       skeleton. Needs to be more naturally a cat"): a long, supple, low-slung body, the loin
       arched a little, a deep chest and a tucked waist, a short neck carrying the head low and
       forward; the head rounder, the muzzle shorter, the ears bigger. Legs and tail are built in
       the game (scenes/art_pixel/unit_models.gd, the cat section), posed and baked per frame.
       Hips at (-8, 13.5), shoulders at (8.5, 12.5) (x, z).

    blender -b --python tools/blender/big_cat.py -- assets/models/body_cat_lean.glb body lean
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, part, kind = args[0], args[1], args[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
TIGER = kind == "tiger"
LEAN = kind == "lean"


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


FUR, STRIPE, PALE = mat("fur", (0.55, 0.55, 0.52)), mat("stripe", (0.15, 0.14, 0.13)), mat("pale", (0.9, 0.88, 0.84))
NOSE, EYE, IRIS, EAR_IN = mat("nose", (0.75, 0.45, 0.45)), mat("eye", (0.04, 0.04, 0.04)), mat("iris", (0.7, 0.75, 0.2)), mat("ear_in", (0.8, 0.6, 0.55))
COAT = [FUR, STRIPE, PALE]   # material indices 0, 1, 2 on a coat mesh


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def curve(pts, t):
    """Piecewise smooth interpolation through [(t, value)...]."""
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            return lerp(v0, v1, smoothstep(t0, t1, t))
    return pts[-1][1]


def sphere(name, segs=48, rings=32):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    return ob, bm


def finish(ob, bm, mats, paint=None):
    """Write the mesh; paint(centre, normal) -> material index colours the coat by place."""
    for m in mats:
        ob.data.materials.append(m)
    if paint:
        for f in bm.faces:
            f.material_index = paint(f.calc_center_median(), f.normal)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def ellipsoid(name, r, at, m, segs=16, rings=10, rot=0.0, paint=None, mats=None):
    """An ellipsoid with radii r at `at`, pitched by rot (degrees, nose up) about the y axis."""
    ob, bm = sphere(name, segs, rings)
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for v in bm.verts:
        q = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2]))
        v.co = Vector((q.x * c - q.z * s, q.y, q.x * s + q.z * c)) + Vector(at)
    return finish(ob, bm, mats or [m], paint)


def tube(name, a, b, ra, rb, paint, segs=32, rings=20):
    """A rounded tube from a to b (radius ra to rb) in the xz plane, its coat painted."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    ux = d / L
    uz = Vector((-ux.z, 0, ux.x))
    ob, bm = sphere(name, segs, rings)
    for v in bm.verts:
        t = (v.co.x + 1) / 2
        r = lerp(ra, rb, t)
        along = lerp(-ra * 0.6, L + rb * 0.6, t)
        v.co = a + ux * along + Vector((0, v.co.y * r, 0)) + uz * (v.co.z * r)
    return finish(ob, bm, COAT, paint)


# ------------------------------------------------------------------ the coat

PERIOD = 4.6 if TIGER else 4.4   # stripe spacing along the body
WIDTH = 0.42 if TIGER else (0.0 if LEAN else 0.3)  # how much of each period is dark (higher: thinner stripes)


def stripes(c, wobble=1.0):
    """Stripes across the body, wavy with height, forking a little (tiger) or regular (tabby)."""
    ph = 2 * math.pi * c.x / PERIOD + wobble * 0.9 * math.sin(c.z * 0.55) + 0.35 * abs(c.y)
    if TIGER:
        ph += 0.6 * math.sin(c.x * 0.9 + c.z * 0.3)   # irregular: some thick, some forked
    return math.sin(ph) > WIDTH


def body_paint(top_at, bot_at):
    def paint(c, n):
        top, bot = top_at(c.x), bot_at(c.x)
        h = (c.z - bot) / max(0.1, top - bot)   # 0 at the belly, 1 on the spine
        if h < (0.34 if TIGER else 0.26) or (LEAN and c.x > 0.0 and h < 0.3 + 0.045 * c.x):   # (C2: up the chest)
            return 2   # pale belly
        if not TIGER and abs(c.y) < 1.0 and h > 0.8:
            return 1   # the tabby's dark line down the spine
        return 1 if stripes(c) and h > (0.42 if TIGER else 0.32) else 0
    return paint


def body():
    # Lengthwise, t runs 0 at the rump to 1 at the chest.
    if TIGER:
        X0, X1 = -17.0, 13.0
        TOP = [(0.0, 19.0), (0.15, 23.0), (0.45, 22.2), (0.8, 23.4), (1.0, 22.0)]
        BOT = [(0.0, 15.0), (0.15, 12.6), (0.45, 13.0), (0.78, 10.6), (1.0, 13.5)]
        HALF = [(0.0, 4.6), (0.15, 7.2), (0.45, 6.4), (0.75, 7.4), (1.0, 5.6)]
    elif LEAN:
        # t = (x + 13) / 25: the rump end, the thigh, the loin's arch, the waist, behind the
        # withers, the withers, the front of the chest.
        X0, X1 = -13.0, 12.0
        TOP = [(0.0, 14.8), (0.12, 17.2), (0.28, 18.0), (0.52, 17.4), (0.68, 17.1), (0.84, 17.6), (1.0, 15.4)]
        BOT = [(0.0, 12.4), (0.12, 10.6), (0.30, 12.9), (0.52, 11.8), (0.68, 9.4), (0.84, 8.4), (1.0, 10.8)]
        HALF = [(0.0, 3.0), (0.12, 4.4), (0.28, 3.5), (0.52, 4.1), (0.68, 4.8), (0.84, 4.8), (1.0, 3.6)]
    else:
        X0, X1 = -13.0, 11.0
        TOP = [(0.0, 16.0), (0.15, 19.9), (0.45, 19.1), (0.8, 20.1), (1.0, 18.9)]   # hips and shoulders, a slight dip between
        BOT = [(0.0, 13.1), (0.15, 11.1), (0.45, 11.9), (0.78, 9.9), (1.0, 12.3)]   # a tucked waist, a deep chest
        HALF = [(0.0, 3.4), (0.15, 5.2), (0.45, 4.5), (0.75, 5.4), (1.0, 4.2)]
    ob, bm = sphere("body", 128, 48)
    tx = lambda x: (x - X0) / (X1 - X0)
    for v in bm.verts:
        p = v.co.copy()
        t = (p.x + 1) / 2
        top, bot, half = curve(TOP, t), curve(BOT, t), curve(HALF, t)
        z = lerp(bot, top, (p.z + 1) / 2)
        v.co = Vector((lerp(X0, X1, t), p.y * half, z))
    finish(ob, bm, COAT, body_paint(lambda x: curve(TOP, tx(x)), lambda x: curve(BOT, tx(x))))
    # The neck, up and forward from the chest to the head; its throat pale.
    def neck_paint(c, n):
        if (n.z < -0.35 and n.x > -0.2) or (LEAN and n.x > 0.2 and n.z < 0.3):   # the throat (C2: a bib down the chest)
            return 2
        return 1 if stripes(c, 1.6) and n.z > -0.1 else 0
    if TIGER:
        tube("neck", (10.0, 0, 18.5), (15.6, 0, 22.0), 5.6, 4.6, neck_paint)
    elif LEAN:
        tube("neck", (9.5, 0, 14.2), (14.2, 0, 15.2), 3.9, 3.2, neck_paint)   # short, carried low and forward
    else:
        tube("neck", (8.5, 0, 16.6), (13.0, 0, 19.6), 4.0, 3.3, neck_paint)


# ------------------------------------------------------------------ the head

def head():
    # In the head's frame: the neck point at the origin, the face looking along +x.
    if TIGER:
        skull_c, skull_r = Vector((2.4, 0, 1.0)), (3.9, 3.9, 3.4)
        muz_c, muz_r = Vector((6.0, 0, -0.6)), (2.6, 2.4, 2.0)
    elif LEAN:
        skull_c, skull_r = Vector((2.0, 0, 1.2)), (3.3, 3.4, 3.2)
        muz_c, muz_r = Vector((4.3, 0, -0.4)), (1.2, 1.8, 1.25)
    else:
        skull_c, skull_r = Vector((2.0, 0, 1.2)), (3.3, 3.3, 3.1)
        muz_c, muz_r = Vector((4.5, 0, -0.3)), (1.3, 1.8, 1.3)

    def skull_paint(c, n):
        # Pale under the jaw and (tiger) the cheeks round the eyes; dark brow stripes.
        if n.z < -0.55 or (TIGER and n.x > 0.2 and abs(n.y) > 0.5 and n.z < 0.15):
            return 2
        if TIGER:
            return 1 if n.z > 0.2 and math.sin(c.y * 2.6 + c.x * 0.6) > 0.55 or (abs(n.y) > 0.7 and math.sin(c.x * 2.2 - c.z * 1.2) > 0.65) else 0
        # The tabby's M: three short dark lines up the brow, and a line back from each eye.
        if n.z > 0.45 and n.x > -0.2 and math.cos(c.y * 2.4) > 0.6:
            return 1
        if abs(n.y) > 0.75 and abs(c.z - 1.0) < 0.35 and c.x < 2.6:
            return 1
        return 0

    ellipsoid("skull", skull_r, skull_c, None, 48, 32, 0.0, skull_paint, COAT)
    if TIGER:
        # The ruff: cheek fur sweeping out and back below the ears, a tiger's broad face.
        for s in (-1, 1):
            ellipsoid("ruff", (2.2, 1.4, 2.2), (1.4, 3.2 * s, -0.6), None, 20, 14, -20.0,
                lambda c, n: 2 if n.x > -0.3 else (1 if math.sin(c.z * 3.0) > 0.4 else 0), COAT)
    # The muzzle: short and rounded, white whisker pads, the chin under it.
    ellipsoid("muzzle", muz_r, muz_c, None, 32, 20, 0.0, lambda c, n: 2 if TIGER or n.z < 0.3 else 0, COAT)
    for s in (-1, 1):
        pad = muz_c + Vector((muz_r[0] * 0.45, muz_r[1] * 0.45 * s, -muz_r[2] * 0.25))
        ellipsoid("pad", (muz_r[0] * 0.55, muz_r[1] * 0.5, muz_r[2] * 0.55), pad, PALE, 16, 10)
    ellipsoid("chin", (muz_r[0] * 0.6, muz_r[1] * 0.5, muz_r[2] * 0.45), muz_c + Vector((-0.2, 0, -muz_r[2] * 0.85)), PALE, 14, 8)
    # The nose: a small triangle-ish pad at the muzzle's front top.
    ellipsoid("nose", (0.5, 0.75 if TIGER else 0.55, 0.45), muz_c + Vector((muz_r[0] * 0.92, 0, muz_r[2] * 0.45)), NOSE, 12, 8)
    # Eyes: big, set forward on the face (a hunter's), a coloured iris with a dark pupil.
    for s in (-1, 1):
        e = skull_c + Vector((skull_r[0] * 0.78, skull_r[1] * 0.5 * s, skull_r[2] * 0.25))
        ellipsoid("eye", (0.5, 0.8, 0.62), e, IRIS, 14, 10)
        ellipsoid("pupil", (0.3, 0.25, 0.5), e + Vector((0.32, 0.2 * s, 0)), EYE, 10, 8)
    # Ears: a cat's big upright triangles (one notched), a tiger's small rounded ones.
    for s in (-1, 1):
        ear(s, skull_c, skull_r)


def ear(s, skull_c, skull_r):
    if TIGER:
        base = skull_c + Vector((-0.6, skull_r[1] * 0.62 * s, skull_r[2] * 0.75))
        h, w, d = 2.0, 1.6, 0.6
    else:
        base = skull_c + Vector((-0.2, skull_r[1] * 0.55 * s, skull_r[2] * 0.72))
        h, w, d = (5.6, 2.9, 0.6) if LEAN else (5.0, 2.5, 0.6)
    notched = not TIGER and s == -1   # the near ear (Blender -y is the game's +z, towards the viewer)
    ob, bm = sphere("ear", 20, 12)
    for v in bm.verts:
        p = v.co.copy()
        u = (p.z + 1) / 2   # 0 at the base, 1 at the tip
        taper = (1 - u) ** (0.6 if TIGER else 1.0) if not TIGER else math.sqrt(max(0.0, 1 - u * u))
        q = Vector((p.x * d * (1 - 0.5 * u), p.y * w * taper, u * h))
        if notched and u > 0.45 and u < 0.7 and q.y * s > 0:
            q.y *= 0.35   # a bite out of the outer edge
        q.y += s * u * h * 0.22   # splayed out a little
        v.co = base + q
    finish(ob, bm, [FUR, EAR_IN, STRIPE],
        lambda c, n: 1 if n.x > 0.5 and (c - base).z < h * 0.75 else (2 if TIGER and n.x < -0.5 else 0))


head() if part == "head" else body()

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
