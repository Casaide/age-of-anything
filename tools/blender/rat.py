"""The rat as a rat is (D-177, round F2's B; milestone 23), for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/rat.py -- assets/models/

Writes body_rat.glb and head_rat.glb in the game's part units (+X forward, +Z up; the game's near side is -Y here).
- body_rat: the trunk, a long pear leaning 42 degrees forward from the hips at (0, 11), the belly paler, the
  shoulders at (8.0, 19.9), the neck at its top (11.2, 23.1); the tail, thick at the root, whipping out behind
  and up. Legs and arms are the game's (scenes/art_pixel/unit_models.gd: baked per pose, D-179).
- head_rat: from the neck (the origin): the skull, a long tapering snout carried a little down, a pink nose,
  buck teeth, big round ears, a black eye each side, whiskers. Its crown (where head gear sits) at (0.4, 3.7).
Materials: "fur" (the coat), "belly" (paler fur), "pink" (ears, nose, tail), "eye", "tooth".
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]

LEAN = 42.0
HIP = Vector((0.0, 0.0, 11.0))
TRUNK = 15.5


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


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


def ball(name, material, centre, radii, segs=18, rot=(0, 0, 0)):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 2, radius=1.0)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    bm.to_mesh(ob.data)
    bm.free()
    ob.location = centre
    ob.rotation_euler = rot
    return ob


def lathe(name, material, profile, segs=32, squash=lambda z, a: (1.0, 1.0)):
    """Rings about Z from (z, radius) pairs, then leaned LEAN forward about the hips and set on them."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            sx, sy = squash(z, a)
            ring.append(bm.verts.new((math.cos(a) * r * sx, math.sin(a) * r * sy, z)))
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
        v.co.x = x * c + z * s + HIP.x
        v.co.z = -x * s + z * c + HIP.z
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


def mats():
    return {k: mat(k, c) for k, c in (("fur", (0.5, 0.46, 0.42)), ("belly", (0.72, 0.66, 0.6)), ("pink", (0.85, 0.6, 0.6)),
                                       ("eye", (0.05, 0.04, 0.03)), ("tooth", (0.95, 0.92, 0.8)))}


# ------------------------------------------------------------------ the body
reset()
M = mats()
lathe("trunk", M["fur"], [(-0.6, 2.6), (0.0, 3.7), (2.5, 4.9), (6.0, 5.2), (9.5, 4.4), (12.5, 3.75), (14.5, 3.0), (TRUNK, 2.2)],
      squash=lambda z, a: (0.78 + 0.1 * max(0.0, math.cos(a)) * smoothstep(5, 11, z), 1.0))
# The belly: paler fur down the front, under the chest to the groin.
lathe("belly", M["belly"], [(1.0, 3.9), (3.5, 4.6), (7.0, 4.75), (10.5, 3.9), (12.8, 3.2)],
      squash=lambda z, a: (0.82 if math.cos(a) > 0.35 else 0.4, 0.8))
# The tail: thick at the root under the haunch, whipping out behind and up.
tube("tail", M["pink"], [(HIP + Vector((-2.6, 0, -1.2)), 1.3), (Vector((-8.5, -1.5, 4.0)), 0.95), (Vector((-14, -3.0, 2.0)), 0.7),
                          (Vector((-19, -4.0, 4.4)), 0.45), (Vector((-22, -4.5, 8.6)), 0.18)], segs=10)
finish(out_dir + "body_rat.glb", smooth=("trunk", "belly"))

# ------------------------------------------------------------------ the head
reset()
M = mats()
NOD = 5.0
fwd = Vector((math.cos(math.radians(NOD)), 0, -math.sin(math.radians(NOD))))
skull = Vector((0.6, 0, 1.6))
ball("skull", M["fur"], skull, (3.4, 3.0, 2.9), segs=20)
tube("snout", M["fur"], [(skull + fwd * 1.0, 2.6), (skull + fwd * 3.6, 1.9), (skull + fwd * 6.2, 1.0), (skull + fwd * 7.4, 0.45)], segs=14)
ball("nose", M["pink"], skull + fwd * 7.5, (0.55, 0.55, 0.5), segs=10)
ball("teeth", M["tooth"], skull + fwd * 6.9 + Vector((0, 0, -0.9)), (0.25, 0.45, 0.45), segs=8)
for side in (1, -1):
    ball("ear%d" % side, M["pink"], skull + Vector((-1.2, side * 2.6, 2.4)), (1.9, 0.45, 2.1), segs=14, rot=(side * math.radians(-20), 0, side * math.radians(10)))
    ball("earfur%d" % side, M["fur"], skull + Vector((-1.45, side * 2.75, 2.4)), (2.0, 0.35, 2.2), segs=14, rot=(side * math.radians(-20), 0, side * math.radians(10)))
    ball("eye%d" % side, M["eye"], skull + fwd * 2.4 + Vector((0, side * 1.75, 0.8)), (0.45, 0.42, 0.45), segs=8)
    for w in range(3):
        tube("whisker%d%d" % (side, w), M["eye"], [(skull + fwd * 6.0 + Vector((0, side * 0.6, -0.1)), 0.06),
                                                   (skull + fwd * 6.6 + Vector((-0.6, side * 3.8, -0.6 + w * 0.6)), 0.03)], segs=3)
finish(out_dir + "head_rat.glb", smooth=("skull", "snout"))
