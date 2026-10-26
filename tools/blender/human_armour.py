"""Body armour fitted to the human torso (tools/blender/human_torso.py), for the unit bakes:

    blender -b --python tools/blender/human_armour.py -- assets/models/ leather
    blender -b --python tools/blender/human_armour.py -- assets/models/ bronze
    blender -b --python tools/blender/human_armour.py -- assets/models/ leather heroic   (and bronze)

heroic (D-173): fitted to the heroic trunk (tools/blender/human_torso_heroic.py: the belt at 21.6, the shoulders
at 30.3, a chest shallower front to back): writes armour_<kind>_human_heroic.glb, which the game uses; without it,
the build before D-173.

Writes armour_<kind>_human.glb. Part units, facing +X, up +Z, in the torso's own space (no
fitting at bake time): a shell just outside the chest's profile, from the belt to the shoulders.
leather: a jerkin with shoulder doublers and a laced front. bronze: a cuirass with a muscled
chest, a flared hem. Materials: "leather", "bronze", "trim".
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, kind = args[0], args[1]
heroic = "heroic" in args[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


MAIN = mat(kind, (0.5, 0.3, 0.15))
TRIM = mat("trim", (0.3, 0.2, 0.1))


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def chest_squash(z, a):   # the torso's own (human_torso.py), so the shell follows it
    return (0.82 + 0.06 * smoothstep(17, 21, z) * max(0.0, math.cos(a)), 1.08)


def lathe(name, material, profile, bulge=lambda z, a: 0.0, segs=40):
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            sx, sy = chest_squash(z, a)
            rr = r + bulge(z, a)
            ring.append(bm.verts.new((math.cos(a) * rr * sx, math.sin(a) * rr * sy, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def blob(name, material, at, r):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * r[0] + at[0], v.co.y * r[1] + at[1], v.co.z * r[2] + at[2]))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# The torso's chest is [(14.6, 3.6) ... (21.0, 4.95), (22.6, 4.6), (23.6, 3.6)]; the shell sits
# about half a unit outside it.
if kind == "leather":
    lathe("jerkin", MAIN, [(13.9, 4.5), (14.6, 4.45), (15.4, 4.6), (17.0, 5.0), (19.0, 5.3), (21.0, 5.45), (22.6, 5.1), (23.5, 4.1)])
    for s in (-1, 1):   # shoulder doublers
        blob("doubler", MAIN, (0.2, 4.4 * s, 22.6), (2.3, 1.8, 0.9))
    for k in range(4):   # the laces down the front
        blob("lace", TRIM, (4.45, 0, 16.0 + k * 1.6), (0.3, 0.9, 0.25))
    lathe("hem", TRIM, [(13.7, 4.6), (14.3, 4.6)])
else:
    def muscles(z, a):   # the pectorals and a ridge down the middle, on the front only
        front = max(0.0, math.cos(a))
        pecs = sum(math.exp(-((a - s * 0.5) ** 2) / 0.08) for s in (-1, 1)) * math.exp(-((z - 20.0) ** 2) / 3.0)
        return front * 0.55 * pecs
    lathe("cuirass", MAIN, [(14.0, 4.9), (14.6, 4.55), (15.4, 4.6), (17.0, 5.0), (19.0, 5.35), (21.0, 5.5), (22.6, 5.1), (23.5, 4.1)], bulge=muscles)
    lathe("rim", TRIM, [(23.3, 4.3), (23.7, 4.0)])
    lathe("flare", TRIM, [(13.4, 5.2), (14.1, 4.95)])

for ob in bpy.data.objects:
    if heroic:   # fitted to the heroic trunk (human_torso_heroic.py): belt 14.6 -> 21.6, shoulders 23.6 -> 30.3, a shallower chest
        for v in ob.data.vertices:
            v.co = Vector((v.co.x * 0.84, v.co.y * 0.88, 21.6 + (v.co.z - 14.6) * 0.967))
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1
bpy.ops.export_scene.gltf(filepath=out_dir + "armour_%s_human%s.glb" % (kind, "_heroic" if heroic else ""), export_format="GLB", export_apply=True, export_materials="EXPORT")
