"""A human torso in a belted tunic, for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/human_torso.py -- assets/models/torso_human.glb

Part units, facing +X, up +Z. A chest broader than the waist with shoulders that round over,
a tunic falling from the belt in folds, the neck. Arms are not here: the game poses them for the
weapon held. Materials: "team" (the tunic: the genre's team colour), "cloth" (hem trim, the
culture's colour), "leather" (belt), "skin" (neck).
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


TEAM, CLOTH, LEATHER, SKIN = mat("team", (1, 0, 1)), mat("cloth", (0.6, 0.2, 0.2)), mat("leather", (0.4, 0.25, 0.1)), mat("skin", (0.8, 0.6, 0.45))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def lathe(name, material, profile, segs=40, squash=lambda z, a: (1.0, 1.0)):
    """A body of revolution from (z, radius) pairs, each ring squashed front-back/side by squash(z, angle)."""
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
    return ob


# The chest and waist: wide at the shoulders, deep at the chest, narrow at the belt; a little
# flatter front-to-back than side-to-side (x is front-back, y is side-to-side).
chest = lathe("chest", TEAM, [(14.6, 3.6), (15.4, 4.1), (17.0, 4.5), (19.0, 4.9), (21.0, 5.2), (22.6, 5.0), (23.6, 3.9), (24.2, 2.2)],
              squash=lambda z, a: (0.82 + 0.06 * smoothstep(17, 21, z) * max(0.0, math.cos(a)), 1.08))
# The skirt: from the belt, flaring, its hem in folds.
def skirt_squash(z, a):
    fold = 1.0 + 0.06 * math.sin(8 * a) * smoothstep(14, 10, z)
    return (0.9 * fold, 1.04 * fold)
skirt = lathe("skirt", TEAM, [(15.2, 4.1), (14.0, 4.5), (12.6, 5.0), (11.2, 5.5), (10.6, 5.65)], squash=skirt_squash)
hem = lathe("hem", CLOTH, [(11.15, 5.6), (10.95, 5.75), (10.55, 5.75), (10.45, 5.6)], squash=skirt_squash)
belt = lathe("belt", LEATHER, [(14.6, 4.25), (14.8, 4.35), (15.6, 4.3), (15.8, 4.15)], squash=lambda z, a: (0.86, 1.06))
neck = lathe("neck", SKIN, [(23.2, 2.2), (24.6, 2.1), (26.4, 2.0), (27.6, 1.9)], segs=20)   # up into the head: no gap under the jaw

for ob in bpy.data.objects:
    ob.location = (0.3, 0, 0)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
