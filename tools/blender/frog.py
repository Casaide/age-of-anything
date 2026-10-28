"""The frog as a frog is (D-178, round F2's B; milestone 23), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/frog.py -- assets/models/

Writes body_frog.glb and head_frog.glb in the game's part units (+X forward, +Z up; the game's near side is -Y here),
built at S (1.15) times the concept (tools/blender/concept_creatures.py frog "b") so it stands as tall as today's frog.
- body_frog: the trunk, squat, leaning 55 degrees forward from the hips at (0, 0, HIP_Z), a pale belly and throat
  down its front. Arms and legs are the game's (scenes/art_pixel/unit_models.gd: legs baked per hop phase, D-179).
  The neck (where the head goes) at the trunk's top: NECK below.
- head_frog: from the neck (the origin): wide and flat, the mouth a long seam round the front, the eyes bulging on top.
Materials: "skin" (the frog's wet skin), "belly" (the pale throat and belly), "eye" (the pupils and mouth line),
"eyeball" (the bulging eyes' whites).
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]

S = 1.15
LEAN = 55.0
HIP_Z = 7.5 * S
TRUNK = 13.0 * S
NECK = Vector((math.sin(math.radians(LEAN)) * TRUNK, 0.0, HIP_Z + math.cos(math.radians(LEAN)) * TRUNK))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


def mats():
    return {k: mat(k, c) for k, c in (("skin", (0.3, 0.5, 0.2)), ("belly", (0.85, 0.8, 0.55)), ("eye", (0.05, 0.04, 0.03)),
                                       ("eyeball", (0.9, 0.85, 0.5)))}


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def tube(name, material, pts, segs=14, flat=1.0):
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for i, (p, r) in enumerate(pts):
        p = Vector(p)
        d = (Vector(pts[min(i + 1, len(pts) - 1)][0]) - Vector(pts[max(i - 1, 0)][0])).normalized()
        u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = d.cross(u).normalized()
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / segs) * flat + v * math.sin(2 * math.pi * k / segs)) * r) for k in range(segs)])
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def ball(name, material, centre, radii, segs=18):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 2, radius=1.0)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    bm.to_mesh(ob.data)
    bm.free()
    ob.location = centre
    return ob


def lathe(name, material, profile, squash, at=(0.0, 0.0), segs=32):
    """Rings about the trunk's axis from (along, radius) pairs, leaned LEAN forward about the hips and set on them."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            sx, sy = squash(z, a)
            ring.append(bm.verts.new((at[0] + math.cos(a) * r * sx, at[1] + math.sin(a) * r * sy, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    s, c = math.sin(math.radians(LEAN)), math.cos(math.radians(LEAN))
    for v in ob.data.vertices:
        x, z = v.co.x, v.co.z
        v.co.x = x * c + z * s
        v.co.z = -x * s + z * c + HIP_Z
    return ob


def finish(path, smooth):
    for ob in bpy.data.objects:
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if ob.name.startswith(smooth):
            mod = ob.modifiers.new("smooth", "SUBSURF")
            mod.levels = 1
            mod.render_levels = 1
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("wrote", path)


# The trunk's profile along it (from the hips) and how it's squashed front to back (frog_armour reads the same).
PROFILE = [(0.0, 5.2), (3.0, 6.4), (7.0, 6.6), (11.0, 5.8), (13.0, 4.7)]


def trunk_squash(z, a):
    return (0.8 + 0.12 * max(0.0, math.cos(a)), 1.08)


# ------------------------------------------------------------------ the body
reset()
M = mats()
lathe("trunk", M["skin"], [(z * S, r * S) for z, r in PROFILE], lambda z, a: trunk_squash(z / S, a))
lathe("belly", M["belly"], [(1.0 * S, 4.6 * S), (4.0 * S, 5.9 * S), (8.0 * S, 5.9 * S), (11.0 * S, 5.0 * S)],
      lambda z, a: (0.86 if math.cos(a) > 0.2 else 0.5, 0.85), at=(0.45 * S, 0))
finish(out_dir + "body_frog.glb", smooth=("trunk", "belly"))

# ------------------------------------------------------------------ the head
reset()
M = mats()
hc = Vector((2.2, 0, 1.4)) * S   # its middle, from the neck
head = ball("head", M["skin"], hc, Vector((5.0, 5.6, 3.2)) * S, segs=24)
for v in head.data.vertices:
    if v.co.z < 0:
        v.co.z *= 0.75   # (flat underneath: the jaw is its own)
ball("jaw", M["belly"], hc + Vector((0.8, 0, -1.3)) * S, Vector((4.4, 5.0, 1.7)) * S, segs=20)
tube("mouth", M["eye"], [(hc + Vector((3.4, -4.4, -0.6)) * S, 0.12 * S), (hc + Vector((4.95, 0, -0.5)) * S, 0.12 * S),
                         (hc + Vector((3.4, 4.4, -0.6)) * S, 0.12 * S)], segs=4)
for side in (1, -1):
    e = hc + Vector((1.4, side * 3.2, 2.4)) * S
    ball("eyebulge%d" % side, M["skin"], e, Vector((1.9, 1.8, 1.7)) * S, segs=14)
    ball("eyeball%d" % side, M["eyeball"], e + Vector((0.7, side * 0.35, 0.35)) * S, Vector((1.25, 1.2, 1.2)) * S, segs=12)
    ball("pupil%d" % side, M["eye"], e + Vector((1.75, side * 0.6, 0.45)) * S, Vector((0.35, 0.55, 0.55)) * S, segs=8)
finish(out_dir + "head_frog.glb", smooth=("head", "jaw", "eyebulge"))
print("neck", tuple(round(x, 3) for x in NECK), "hip_z", HIP_Z)
