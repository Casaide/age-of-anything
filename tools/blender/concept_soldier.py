"""Fidelity study (docs/concepts/fidelity/): a whole legionary modelled for realism, one piece, standing.
Not a game part: tests/art_quality/fidelity_sheet.gd bakes it with the unit baker beside today's units.

    blender -b --python tools/blender/concept_soldier.py -- out.glb heads=7 [build=1.0]

Part units, facing +X, up +Z, about 40 tall to the crown (today's human is ~38 with a head a quarter of
that). heads: how many heads tall (7 realistic, 5.5 the genre's heroic build); build: how broad.
An anatomical body (pelvis, ribcage, shoulders, limbs as tapered tubes along their bones, knees, calves),
a head with a jaw, brow and nose, then the kit: a red wool tunic, segmented plate over the chest and
shoulders, a belt with a studded apron, nailed boots, a galea with cheek guards, neck guard and crest,
a curved scutum on the left arm, a gladius in the right hand. The right (sword) side is -Y (the game's
near side). Materials are named for the game's: skin, hair, cloth (the tunic), team (shield face, crest),
iron, bronze, leather, wood.
"""
import sys, math
import bpy, bmesh
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
opt = {"heads": 7.0, "build": 1.0}
for a in args[1:]:
    k, v = a.split("=")
    opt[k] = float(v)
bpy.ops.wm.read_factory_settings(use_empty=True)

H = 40.0                          # to the crown
HEAD = H / opt["heads"]           # chin to crown
CHIN = H - HEAD
B = CHIN / (H * 0.86)             # the body's landmarks are set for a 7.5-head figure; squeezed under a bigger head
W = opt["build"] * (1.0 + (7.0 - opt["heads"]) * 0.08)   # a heroic build is broader too


def z(f):
    return f * H * B


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


SKIN, HAIR, CLOTH, TEAM = mat("skin", (0.8, 0.6, 0.45)), mat("hair", (0.2, 0.12, 0.06)), mat("cloth", (0.55, 0.12, 0.1)), mat("team", (1, 0, 1))
IRON, BRONZE, LEATHER, WOOD = mat("iron", (0.6, 0.6, 0.62)), mat("bronze", (0.7, 0.5, 0.25)), mat("leather", (0.35, 0.22, 0.12)), mat("wood", (0.45, 0.3, 0.18))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def lathe(name, material, profile, segs=36, squash=lambda zz, a: (1.0, 1.0), at=(0.0, 0.0)):
    """A body of revolution about Z from (z, radius) pairs, each ring squashed (front-back, side) by squash(z, angle)."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for zz, r in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            sx, sy = squash(zz, a)
            ring.append(bm.verts.new((at[0] + math.cos(a) * r * sx, at[1] + math.sin(a) * r * sy, zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def tube(name, material, pts, segs=16, flat=1.0):
    """A tapered tube along a chain of (point, radius): rings square to the chain, capped. flat < 1 squashes it sideways."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for i, (p, r) in enumerate(pts):
        p = Vector(p)
        d = (Vector(pts[min(i + 1, len(pts) - 1)][0]) - Vector(pts[max(i - 1, 0)][0])).normalized()
        u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = d.cross(u).normalized()
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ring.append(bm.verts.new(p + (u * math.cos(a) * flat + v * math.sin(a)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def box(name, material, centre, size, rot=(0, 0, 0)):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(ob.data)
    bm.free()
    ob.rotation_euler = rot
    ob.location = centre
    return ob


def ball(name, material, centre, radii, segs=16):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 2, radius=1.0)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    bm.to_mesh(ob.data)
    bm.free()
    ob.location = centre
    return ob


# ------------------------------------------------------------------ the body
# Torso: pelvis to neck, a ribcage deeper than the waist, shoulders rounding over (x front-back, y side).
def torso_squash(zz, a):
    front = math.cos(a)
    depth = 0.62 + 0.1 * smoothstep(z(0.62), z(0.72), zz) * max(0.0, front)   # the chest stands forward
    return (depth, 1.0)
torso = lathe("torso", SKIN, [(z(0.47), 3.2 * W), (z(0.52), 3.55 * W), (z(0.58), 3.3 * W), (z(0.62), 3.05 * W), (z(0.68), 3.5 * W),
                              (z(0.74), 3.9 * W), (z(0.79), 4.3 * W), (z(0.815), 3.8 * W), (z(0.835), 2.2 * W), (CHIN - 0.2, 1.3 * W), (CHIN + 1.0, 1.15 * W)],
              squash=torso_squash)
SH = z(0.81)   # shoulder height
for side in (1, -1):
    y = side
    # Leg: hip, knee, ankle, then the foot forward. Feet a little apart, the near (sword) leg forward a step.
    fwd = 0.9 if side < 0 else -0.6
    tube("leg%d" % side, SKIN, [((0.0, y * 2.0 * W, z(0.5)), 2.15 * W), ((fwd * 0.3, y * 2.2 * W, z(0.4)), 1.85 * W),
                               ((fwd * 0.55 + 0.3, y * 2.35 * W, z(0.28)), 1.3 * W), ((fwd * 0.6, y * 2.4 * W, z(0.2)), 1.45 * W),
                               ((fwd * 0.65, y * 2.45 * W, z(0.08)), 0.9 * W), ((fwd * 0.65, y * 2.5 * W, z(0.045)), 0.8 * W)])
    # Arm: shoulder, elbow, wrist. The sword arm bent forward at the waist, the shield arm across in front.
    if side < 0:
        arm = [((0.0, -4.0 * W, SH - 0.3), 1.3 * W), ((-0.3, -4.6 * W, z(0.7)), 1.1 * W), ((0.2, -4.7 * W, z(0.63)), 0.95 * W),
               ((2.6, -4.2 * W, z(0.6)), 0.95 * W), ((4.8, -3.8 * W, z(0.585)), 0.7 * W)]
    else:
        arm = [((0.0, 4.0 * W, SH - 0.3), 1.3 * W), ((0.4, 4.8 * W, z(0.7)), 1.1 * W), ((0.9, 5.0 * W, z(0.64)), 0.95 * W),
               ((3.0, 4.2 * W, z(0.64)), 0.95 * W), ((4.4, 3.4 * W, z(0.645)), 0.7 * W)]
    tube("arm%d" % side, SKIN, arm, segs=12)
    ball("hand%d" % side, SKIN, arm[-1][0], (0.85 * W, 0.7 * W, 0.8 * W), segs=10)

# Head: an egg narrower than it is deep, the jaw tapering to the chin, a brow ridge and a nose.
hc = Vector((0.2, 0.0, CHIN + HEAD * 0.5))
head = ball("head", SKIN, hc, (HEAD * 0.42, HEAD * 0.36, HEAD * 0.52), segs=24)
for v in head.data.vertices:
    p = v.co
    low = smoothstep(0.1, -1.0, p.z / (HEAD * 0.52))           # the jaw narrows towards the chin
    p.y *= 1.0 - 0.28 * low
    p.x *= 1.0 - 0.12 * low * max(0.0, -p.x)
    front = max(0.0, p.x / (HEAD * 0.42))
    brow = math.exp(-((p.z / HEAD - 0.12) / 0.06) ** 2) * front ** 3
    nose = math.exp(-((p.z / HEAD + 0.05) / 0.1) ** 2) * math.exp(-(p.y / (HEAD * 0.08)) ** 2) * front ** 4
    p.x += HEAD * (0.06 * brow + 0.12 * nose)
ball("hair", HAIR, hc + Vector((-0.4, 0, HEAD * 0.08)), (HEAD * 0.42, HEAD * 0.37, HEAD * 0.48), segs=20)

# ------------------------------------------------------------------ the kit
# Tunic: from under the plate to just above the knee, in folds.
def skirt_squash(zz, a):
    fold = 1.0 + 0.07 * math.sin(10 * a) * smoothstep(z(0.5), z(0.36), zz)
    return (0.75 * fold, 1.0 * fold)
lathe("tunic", CLOTH, [(z(0.66), 3.25 * W), (z(0.58), 3.45 * W), (z(0.5), 3.9 * W), (z(0.42), 4.4 * W), (z(0.37), 4.7 * W)], squash=skirt_squash)
lathe("sleeves", CLOTH, [(SH - 1.6, 4.45 * W), (SH - 0.2, 4.55 * W), (SH + 0.3, 3.9 * W)], squash=lambda zz, a: (0.68, 1.0))
# Segmented plate: bands round the body, each a little proud of the one below, with shoulder hoops.
bands = 6
for i in range(bands):
    z0 = z(0.6) + (z(0.79) - z(0.6)) * i / bands
    z1 = z0 + (z(0.79) - z(0.6)) / bands * 1.15
    r0 = 3.25 * W + 0.9 * W * smoothstep(z(0.6), z(0.76), z0)
    r1 = 3.25 * W + 0.9 * W * smoothstep(z(0.6), z(0.76), z1)
    lathe("plate%d" % i, IRON, [(z0, r0 + 0.25), (z0 + 0.15, r0 + 0.4), (z1 - 0.1, r1 + 0.35), (z1, r1 + 0.2)], squash=torso_squash)
for side in (1, -1):
    for i in range(4):   # shoulder hoops, layered down the upper arm
        c = Vector((0.0, side * (3.3 + i * 0.45) * W, SH + 0.5 - i * 0.75))
        hoop = lathe("hoop%d%d" % (side, i), IRON, [(-1.0, 1.9 * W - i * 0.1), (0.0, 2.0 * W - i * 0.1), (0.35, 1.7 * W)], segs=20,
                     squash=lambda zz, a: (1.0, 0.75))
        hoop.location = c
        hoop.rotation_euler = (side * math.radians(-30 - i * 12), 0, 0)
# Belt and the studded apron hanging in front.
lathe("belt", LEATHER, [(z(0.585), 3.5 * W), (z(0.6), 3.6 * W), (z(0.625), 3.6 * W), (z(0.64), 3.5 * W)], squash=torso_squash)
for k in range(5):
    y = (k - 2) * 0.75 * W
    box("strap%d" % k, LEATHER, (2.45 * W, y, z(0.535)), (0.18, 0.45, z(0.585) - z(0.48)), rot=(0, math.radians(-8), 0))
    for s in range(3):
        ball("stud%d%d" % (k, s), BRONZE, (2.62 * W, y, z(0.56) - s * 1.2), (0.16, 0.22, 0.22), segs=8)
# Nailed boots.
for side in (1, -1):
    fwd = 0.9 if side < 0 else -0.6
    lathe("boot%d" % side, LEATHER, [(0.0, 1.0 * W), (0.35, 1.05 * W), (z(0.07), 0.95 * W), (z(0.11), 0.85 * W)], segs=16,
          squash=lambda zz, a: (1.5 if math.cos(a) > 0 else 1.0, 0.75), at=(fwd * 0.65 + 0.7, side * 2.5 * W))
# Galea: a dome over the crown, a brow band, cheek guards, a flared neck guard and a crest front to back.
dome = ball("galea", IRON, hc + Vector((-0.2, 0, HEAD * 0.12)), (HEAD * 0.48, HEAD * 0.42, HEAD * 0.46), segs=24)
for v in dome.data.vertices:
    if v.co.z < 0:
        v.co.z *= 0.15
lathe("brow", BRONZE, [(hc.z + HEAD * 0.05, HEAD * 0.46), (hc.z + HEAD * 0.11, HEAD * 0.47)], segs=28,
      squash=lambda zz, a: (1.05, 0.9), at=(hc.x - 0.2, 0))
guard = lathe("neckguard", IRON, [(hc.z + HEAD * 0.08, HEAD * 0.42), (hc.z - HEAD * 0.12, HEAD * 0.62)], segs=28,
              squash=lambda zz, a: (1.0, 0.9) if math.cos(a) < -0.3 else (0.01, 0.01), at=(hc.x - 0.4, 0))
for side in (1, -1):
    box("cheek%d" % side, IRON, (hc.x + HEAD * 0.12, side * HEAD * 0.37, hc.z - HEAD * 0.12), (HEAD * 0.32, 0.18, HEAD * 0.42),
        rot=(side * math.radians(8), 0, 0))
crest = tube("crest", TEAM, [((hc.x + HEAD * 0.35, 0, hc.z + HEAD * 0.48), 0.35), ((hc.x, 0, hc.z + HEAD * 0.72), 0.75),
                             ((hc.x - HEAD * 0.4, 0, hc.z + HEAD * 0.6), 0.6), ((hc.x - HEAD * 0.62, 0, hc.z + HEAD * 0.3), 0.3)], segs=10, flat=0.35)
# Scutum: a curved rectangle on the shield arm, its face the team colour, a bronze rim and boss.
SW, SHH, SR = 9.5 * W, z(0.56), 7.0
sc = Vector((6.2, 3.0 * W, z(0.5)))
for part, mtl, w_, h_, t_ in (("scutum", TEAM, SW, SHH, 0.35), ("rim", BRONZE, SW + 0.5, SHH + 0.5, 0.25)):
    ob = obj(part, mtl)
    bm = bmesh.new()
    cols, rows = 14, 2
    grid = []
    for j in range(rows + 1):
        row = []
        for i in range(cols + 1):
            a = (i / cols - 0.5) * w_ / SR
            row.append(bm.verts.new((math.cos(a) * SR - SR, math.sin(a) * SR, (j / rows - 0.5) * h_)))
        grid.append(row)
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=t_)
    bm.to_mesh(ob.data)
    bm.free()
    ob.location = sc + (Vector((-0.12, 0, 0)) if part == "rim" else Vector())
    ob.rotation_euler = (0, 0, math.radians(28))
boss = ball("boss", BRONZE, sc + Vector((0.55, 0.3, 0)), (0.9, 1.4, 1.4), segs=14)
boss.rotation_euler = (0, 0, math.radians(28))
# Gladius: a broad short blade forward from the sword hand, a wooden grip, a round pommel.
hand = Vector((4.8, -3.8 * W, z(0.585)))
tube("grip", WOOD, [(hand + Vector((-0.9, 0, 0.15)), 0.32), (hand + Vector((0.6, 0, 0.05)), 0.32)], segs=8)
ball("pommel", WOOD, hand + Vector((-1.2, 0, 0.17)), (0.5, 0.5, 0.5), segs=8)
box("hilt", BRONZE, hand + Vector((0.8, 0, 0.05)), (0.25, 0.4, 1.4))
blade = tube("blade", IRON, [(hand + Vector((0.9, 0, 0.05)), 0.62), (hand + Vector((6.0, 0, 0.6)), 0.55), (hand + Vector((7.3, 0, 0.75)), 0.05)], segs=4, flat=0.18)

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    if ob.name.startswith(("torso", "leg", "arm", "tunic", "head", "hair", "galea", "crest", "boot")):
        mod = ob.modifiers.new("smooth", "SUBSURF")
        mod.levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
