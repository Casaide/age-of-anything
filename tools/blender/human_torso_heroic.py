"""The heroic human's trunk in a belted wool tunic, for the unit bakes (D-173, milestone 23 step 2b; Blender 5, headless):

    blender -b --python tools/blender/human_torso_heroic.py -- assets/models/torso_human_heroic.glb

Part units, facing +X, up +Z, the game's heroic build: hips at 18, the shoulders at 29.3, the neck up into the
head at 31.6 (unit_models.gd _body_human). Modelled after the fidelity concept (tools/blender/concept_soldier.py,
Dominic: "this is good"): a ribcage deeper than the waist, the chest standing forward, shoulders rounding over;
a tunic of wool in the culture's colour with folds falling from the belt to mid-thigh; the team colour on a sash
round the waist and a band at the hem (a smaller region over natural cloth, D-173); a leather belt over the sash.
The arms are the game's (posed for what the hand holds). Materials: "cloth" (the tunic), "team" (sash, hem),
"leather" (belt), "skin" (neck).
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


CLOTH, TEAM, LEATHER, SKIN = mat("cloth", (0.6, 0.2, 0.2)), mat("team", (1, 0, 1)), mat("leather", (0.4, 0.25, 0.1)), mat("skin", (0.8, 0.6, 0.45))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def obj(name, material):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def lathe(name, material, profile, segs=48, squash=lambda z, a: (1.0, 1.0), bulge=lambda z, a: 0.0):
    """A body of revolution about Z from (z, radius) pairs; each ring squashed (front-back, side) and bulged."""
    ob = obj(name, material)
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            sx, sy = squash(z, a)
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


def trunk(z, a):
    """Front-back and side squash of the trunk: deeper at the chest, the chest standing forward."""
    front = math.cos(a)
    depth = 0.64 + 0.1 * smoothstep(24.0, 27.5, z) * max(0.0, front) - 0.04 * smoothstep(22.0, 21.0, z)
    return (depth, 1.0)


def chest(z, a):
    """The pectorals under the wool, and the shoulder blades behind."""
    front = max(0.0, math.cos(a))
    back = max(0.0, -math.cos(a))
    pecs = sum(math.exp(-((a - s * 0.55) ** 2) / 0.09) for s in (-1, 1)) * math.exp(-((z - 27.0) ** 2) / 2.5)
    blades = sum(math.exp(-((a - math.pi + s * 0.6) ** 2) / 0.12) for s in (-1, 1)) * math.exp(-((z - 27.8) ** 2) / 3.0)
    return front * 0.35 * pecs + back * 0.25 * blades


# The tunic's upper part is the trunk itself: the wool over the ribcage, from the belt up to the neck opening.
lathe("tunic", CLOTH, [(21.6, 3.45), (22.6, 3.35), (23.8, 3.45), (25.2, 3.85), (26.6, 4.25), (27.8, 4.6), (28.8, 4.75),
                       (29.6, 4.35), (30.3, 3.3), (30.8, 2.1)], squash=trunk, bulge=chest)
neck = lathe("neck", SKIN, [(30.2, 1.6), (31.0, 1.45), (32.0, 1.35), (33.2, 1.3)], segs=24)


# The skirt: wool falling from the belt to mid-thigh in folds that deepen towards the hem, a little longer behind.
def skirt_squash(z, a):
    t = smoothstep(21.5, 15.6, z)
    fold = 1.0 + (0.025 + 0.07 * t) * math.sin(11 * a + 0.4) + 0.03 * t * math.sin(5 * a)
    return (0.72 * fold, 1.0 * fold)


skirt = lathe("skirt", CLOTH, [(22.0, 3.45), (21.0, 3.65), (19.8, 4.0), (18.4, 4.4), (17.0, 4.75), (16.0, 4.95), (15.6, 5.0)],
              squash=skirt_squash)
for v in skirt.data.vertices:   # the hem dips behind (the wool hangs over the seat)
    a = math.atan2(v.co.y, v.co.x)
    v.co.z -= 0.45 * max(0.0, -math.cos(a)) * smoothstep(17.0, 15.6, v.co.z)
hem = lathe("hem", TEAM, [(16.15, 5.02), (16.0, 5.06), (15.45, 5.06), (15.3, 4.98)], squash=skirt_squash)
for v in hem.data.vertices:
    a = math.atan2(v.co.y, v.co.x)
    v.co.z -= 0.45 * max(0.0, -math.cos(a))
# The sash: the team colour round the waist, its knot and hanging ends on the left hip.
lathe("sash", TEAM, [(21.0, 3.6), (21.2, 3.72), (22.6, 3.62), (22.8, 3.5)], squash=lambda z, a: (0.7, 1.02))
for k, (dz, ln) in enumerate(((0.0, 3.4), (0.4, 2.6))):
    end = obj("sash_end%d" % k, TEAM)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.5, 0.18, ln), verts=bm.verts)
    bm.to_mesh(end.data)
    bm.free()
    end.location = (0.6 + k * 0.6, 3.75, 21.0 - ln * 0.5 + dz)
    end.rotation_euler = (math.radians(-8 + k * 10), math.radians(6), 0)
# The belt over the sash: leather, narrower.
lathe("belt", LEATHER, [(21.75, 3.78), (21.85, 3.83), (22.25, 3.83), (22.35, 3.76)], squash=lambda z, a: (0.71, 1.02))

for ob in bpy.data.objects:
    ob.location.x += 0.3
    for poly in ob.data.polygons:
        poly.use_smooth = True
    if not ob.name.startswith("sash_end"):
        mod = ob.modifiers.new("smooth", "SUBSURF")
        mod.levels = 1
        mod.render_levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
