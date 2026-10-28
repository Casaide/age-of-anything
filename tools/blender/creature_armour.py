"""Worn armour fitted to a creature's own trunk (the rat as a rat is, D-177, tools/blender/rat.py; the frog as a frog
is, D-178, tools/blender/frog.py), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/creature_armour.py -- assets/models/ rat|frog

Writes armour_<kind>_<body>.glb for every armour it can wear: leather, bottlecap, sardine, bronze, mail, bark, lorica.
Made in the trunk's own space (+X forward, +Z up, the trunk leaning forward from the hips: BODIES), so the game puts
it on as modelled (UnitModels.fitted): a shell just outside the trunk's profile, cut to the piece, with its own
detail. (Before, these bodies wore the human-sized piece scaled by torso_scale: a barrel or a band round the middle,
Dominic.) Materials are named for the game's (UnitModels.ARMOUR_MATS): leather, trim, iron, tin, brass, bronze,
mail, bark, label.
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]
BODY = sys.argv[sys.argv.index("--") + 2]


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


FS = 1.15   # frog.py's S
# Each trunk as its model makes it: lean, hips, profile ((along the trunk from the hips, radius)), front-back squash, and
# where its armour ends (top: below the shoulders and neck; bottom: above the legs).
BODIES = {
    "rat": {"lean": 42.0, "hip": (0.0, 0.0, 11.0),
            "profile": [(-0.6, 2.6), (0.0, 3.7), (2.5, 4.9), (6.0, 5.2), (9.5, 4.4), (12.5, 3.75), (14.5, 3.0), (15.5, 2.2)],
            "squash": lambda z, a: (0.78 + 0.1 * max(0.0, math.cos(a)) * smoothstep(5, 11, z), 1.0), "top": 12.9, "bottom": 2.4},
    "frog": {"lean": 55.0, "hip": (0.0, 0.0, 7.5 * FS),
             "profile": [(z * FS, r * FS) for z, r in [(0.0, 5.2), (3.0, 6.4), (7.0, 6.6), (11.0, 5.8), (13.0, 4.7)]],
             "squash": lambda z, a: (0.8 + 0.12 * max(0.0, math.cos(a)), 1.08), "top": 11.4, "bottom": 3.4},
}
B = BODIES[BODY]
LEAN = B["lean"]
HIP = Vector(B["hip"])
PROFILE = B["profile"]


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def radius(z):
    for (z0, r0), (z1, r1) in zip(PROFILE, PROFILE[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return PROFILE[0][1] if z < PROFILE[0][0] else PROFILE[-1][1]


def squash(z, a):
    return B["squash"](z, a)


def lean(p):
    """From the trunk's upright frame to the body's: leaned forward about the hips."""
    s, c = math.sin(math.radians(LEAN)), math.cos(math.radians(LEAN))
    return Vector((p.x * c + p.z * s + HIP.x, p.y, -p.x * s + p.z * c + HIP.z))


def surface(z, a, off):
    """A point `off` outside the trunk at height z (upright frame) round angle a (0 forward), and its outward normal."""
    sx, sy = squash(z, a)
    r = radius(z) + off
    p = Vector((math.cos(a) * r * sx, math.sin(a) * r * sy, z))
    n = Vector((math.cos(a) / sx, math.sin(a) / sy, 0)).normalized()
    return p, n


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name):
    cols = {"leather": (0.45, 0.3, 0.17), "trim": (0.3, 0.2, 0.1), "iron": (0.6, 0.6, 0.64), "tin": (0.8, 0.82, 0.85),
            "brass": (0.8, 0.65, 0.3), "bronze": (0.72, 0.52, 0.26), "mail": (0.55, 0.56, 0.58), "bark": (0.4, 0.3, 0.2),
            "label": (0.8, 0.6, 0.2)}
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*cols[name], 1.0)
    return m


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mat(material))
    return ob


def shell(name, material, z0, z1, off, a0=-math.pi, a1=math.pi, rows=10, segs=40, bulge=lambda z, a: 0.0, closed=None):
    """A shell over the trunk from z0 to z1 between angles a0 and a1 (whole round when closed)."""
    whole = closed if closed is not None else (a1 - a0) >= 2 * math.pi - 0.01
    ob = obj(name, material)
    bm = bmesh.new()
    n = segs if whole else segs + 1
    grid = []
    for j in range(rows + 1):
        z = z0 + (z1 - z0) * j / rows
        row = []
        for k in range(n):
            a = a0 + (a1 - a0) * k / segs
            p, _ = surface(z, a, off + bulge(z, a))
            row.append(bm.verts.new(lean(p)))
        grid.append(row)
    for j in range(rows):
        for k in range(segs if whole else segs):
            k2 = (k + 1) % n
            bm.faces.new((grid[j][k], grid[j][k2], grid[j + 1][k2], grid[j + 1][k]))
    bm.to_mesh(ob.data)
    bm.free()
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = 0.3
    mod.offset = 1.0
    return ob


def disc(name, material, z, a, off, r, thick=0.25, segs=12, crimp=0):
    """A disc lying on the trunk at (z, a): a bottle cap, a stud, a scale. crimp: teeth round its rim."""
    p, nrm = surface(z, a, off)
    ob = obj(name, material)
    bm = bmesh.new()
    ring_ = []
    for k in range(segs):
        t = 2 * math.pi * k / segs
        rr = r * (1.0 + (0.12 if crimp and k % 2 == 0 else 0.0))
        ring_.append((math.cos(t) * rr, math.sin(t) * rr))
    up = Vector((0, 0, 1))
    u = nrm.cross(up).normalized()
    v = nrm.cross(u).normalized()
    top = [bm.verts.new(lean(p + nrm * thick + u * x + v * y)) for x, y in ring_]
    bot = [bm.verts.new(lean(p + u * x + v * y)) for x, y in ring_]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for k in range(segs):
        bm.faces.new((bot[k], bot[(k + 1) % segs], top[(k + 1) % segs], top[k]))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def strap(name, material, pts, w=0.5, off=0.6):
    """A strap over the trunk through (z, a) points, lying on it."""
    ob = obj(name, material)
    bm = bmesh.new()
    rows = []
    for z, a in pts:
        p, nrm = surface(z, a, off)
        side = nrm.cross(Vector((0, 0, 1))).normalized()
        rows.append([bm.verts.new(lean(p - side * w * 0.5)), bm.verts.new(lean(p + side * w * 0.5)),
                     bm.verts.new(lean(p + side * w * 0.5 + nrm * 0.25)), bm.verts.new(lean(p - side * w * 0.5 + nrm * 0.25))])
    for i in range(len(rows) - 1):
        for k in range(4):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % 4], rows[i + 1][(k + 1) % 4], rows[i + 1][k]))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def finish(kind):
    for ob in bpy.data.objects:
        for poly in ob.data.polygons:
            poly.use_smooth = True
    path = out_dir + "armour_%s_%s.glb" % (kind, BODY)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("wrote", path)


# The pieces end at the shoulders (z 13.2: the arms and neck go on above) and the belly (z 2.4: the legs below).
TOP, BOT = B["top"], B["bottom"]

# Leather: a jerkin laced up the front, a belt low round the belly, edged at the neck.
reset()
shell("jerkin", "leather", BOT, TOP, 0.4)
shell("belt", "trim", BOT + 0.3, BOT + 1.4, 0.75)
shell("collar", "trim", TOP - 0.6, TOP, 0.75)
for k in range(5):
    z = BOT + 2.2 + k * 1.7
    disc("lace%d" % k, "trim", z, 0.0, 0.7, 0.35, thick=0.2, segs=8)
finish("leather")

# Bottle caps: crimped caps sewn in rows over a leather jerkin, each row overlapping the one below (the junk scale).
reset()
shell("backing", "leather", BOT, TOP, 0.4)
for j in range(6):
    z = BOT + 1.3 + j * 1.75
    n = 9 if j < 4 else 7
    for k in range(n):
        a = -1.9 + 3.8 * k / (n - 1) + (0.2 if j % 2 else 0.0)
        disc("cap%d_%d" % (j, k), "brass" if (j + k) % 3 else "tin", z, a, 0.75, 0.85, thick=0.3, segs=14, crimp=1)
shell("collar", "trim", TOP - 0.6, TOP, 0.85)
finish("bottlecap")

# Sardine tins: bands of tin round the trunk, each a little proud of the one below, a printed label on one, a rolled key.
reset()
for j in range(6):
    z0 = BOT + j * (TOP - BOT) / 6
    shell("band%d" % j, "tin", z0, z0 + (TOP - BOT) / 6 * 1.12, 0.45 + 0.05 * (5 - j), rows=2)
shell("label", "label", BOT + 4.5, BOT + 5.9, 0.95, a0=-0.9, a1=0.9, rows=2, segs=16, closed=False)
key = strap("key", "iron", [(7.0, 1.6), (7.0, 1.9)], w=1.4, off=1.2)
finish("sardine")

# Bronze: a cuirass shaped to the chest (a ridge down the front), a rolled rim, leather strips hanging below.
reset()
shell("cuirass", "bronze", BOT + 0.8, TOP, 0.5, bulge=lambda z, a: 0.35 * math.exp(-(a / 0.18) ** 2) * smoothstep(4, 9, z))
shell("rim", "bronze", TOP - 0.4, TOP, 0.85)
shell("flare", "bronze", BOT + 0.8, BOT + 1.5, 0.9)
for k in range(8):
    a = -1.6 + 3.2 * k / 7
    strap("strip%d" % k, "leather", [(BOT + 0.9, a), (BOT - 1.6, a)], w=0.9, off=0.95)
finish("bronze")

# Mail: a shirt of rings down over the haunches, an iron collar, a leather belt.
reset()
shell("mail", "mail", BOT - 1.4, TOP, 0.45)
shell("collar", "iron", TOP - 0.7, TOP, 0.8)
shell("belt", "trim", BOT + 1.0, BOT + 2.0, 0.8)
finish("mail")

# Bark: curved plates of bark over the chest and back, lashed with leather straps crossing on the chest.
reset()
for j in range(3):
    for side, (a0, a1) in enumerate(((-0.6, 0.6), (math.pi - 0.7, math.pi + 0.7))):
        z0 = BOT + 0.6 + j * 3.4
        shell("plate%d_%d" % (j, side), "bark", z0, z0 + 3.9, 0.5 + 0.12 * (2 - j), a0=a0, a1=a1, rows=3, segs=8, closed=False)
for s in (1, -1):
    strap("cross%d" % s, "leather", [(BOT + 1.0, -1.1 * s), (6.0, 0.0), (TOP - 0.5, 1.1 * s)], w=0.55, off=1.0)
shell("belt", "leather", BOT + 0.4, BOT + 1.3, 0.85)
finish("bark")

# Lorica: iron bands round the trunk, hoops over the shoulders, brass hinges down the front.
reset()
for j in range(7):
    z0 = BOT + 0.4 + j * (TOP - BOT - 0.4) / 7
    shell("band%d" % j, "iron", z0, z0 + (TOP - BOT) / 7 * 1.12, 0.45 + 0.04 * (6 - j), rows=2)
for s in (1, -1):
    for k in range(3):
        strap("hoop%d%d" % (s, k), "iron", [(TOP - 0.2 - k * 0.9, s * 1.0), (TOP - 0.2 - k * 0.9, s * 1.9)], w=0.85, off=0.9 + 0.08 * k)
for k in range(4):
    disc("hinge%d" % k, "brass", BOT + 2.0 + k * 2.4, 0.0, 0.9, 0.35, segs=8)
finish("lorica")
