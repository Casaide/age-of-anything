"""A human leg in trousers and a boot, for the unit bakes (Blender 5, headless):

    blender -b --python tools/blender/human_leg.py -- assets/models/leg_human.glb

Part units, facing +X, up +Z, the hip at the origin (the game swings the leg about it). The same
hip, knee and ankle as the primitive leg: knee a little forward, the calf behind it, the foot
pointing forward. Materials: "cloth" (trousers, the culture's second colour), "leather" (boot).
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


CLOTH, LEATHER = mat("cloth", (0.3, 0.3, 0.5)), mat("leather", (0.4, 0.25, 0.1))


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def centre(z):
    """The leg's line: hip (0, 0), knee (0.7, -5.4), ankle (0.1, -9.4)."""
    if z > -5.4:
        t = z / -5.4
        return 0.7 * t * t * (3 - 2 * t)
    t = (z + 5.4) / -4.0
    return 0.7 + (0.1 - 0.7) * t


def sweep(name, material, profile, segs=24):
    """Rings along the leg's line from (z, radius front-back, radius across, x offset) rows."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for z, rx, ry, dx in profile:
        cx = centre(z) + dx
        rings.append([bm.verts.new((cx + math.cos(2 * math.pi * k / segs) * rx, math.sin(2 * math.pi * k / segs) * ry, z)) for k in range(segs)])
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.contextual_create(bm, geom=rings[0])
    bmesh.ops.contextual_create(bm, geom=rings[-1])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# Trousers: a full thigh, narrower at the knee (the kneecap a touch forward), the calf swelling
# behind, tapering into the boot top.
sweep("trousers", CLOTH, [(0.6, 1.9, 1.9, 0.0), (0.0, 2.05, 2.0, 0.0), (-1.6, 2.0, 1.85, 0.1), (-3.4, 1.7, 1.6, 0.1),
                          (-5.0, 1.45, 1.4, 0.15), (-5.6, 1.45, 1.38, 0.1), (-6.6, 1.55, 1.45, -0.25),
                          (-7.6, 1.45, 1.35, -0.2), (-8.6, 1.25, 1.2, 0.0)])
# The boot: a turned-down cuff, the shaft, the heel and a foot pointing forward.
sweep("boot", LEATHER, [(-8.0, 1.55, 1.5, 0.0), (-8.5, 1.6, 1.55, 0.0), (-8.7, 1.38, 1.32, 0.0),
                        (-9.6, 1.3, 1.25, 0.0), (-10.2, 1.4, 1.3, 0.2), (-10.8, 1.45, 1.35, 0.25)])
foot = obj("foot", LEATHER)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
for v in bm.verts:
    x, y, z = v.co
    v.co = Vector((x * 2.2 + 1.3, y * 1.3, max(z, -0.55) * 1.0 - 10.2))   # flat sole
bm.to_mesh(foot.data)
bm.free()

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
