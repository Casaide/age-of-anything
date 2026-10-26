"""Fidelity round F2 (docs/concepts/fidelity/): rats and frogs at the heroic humans' quality (Dominic, 2026-10-27:
"the rats and frogs dont feel same quality", "rats etc should follow"). Whole concept figures, one piece, standing,
baked by tests/art_quality/fidelity_sheet.gd beside today's units. Not game parts.

    blender -b --python tools/blender/concept_creatures.py -- out_dir/

Writes rat_a.glb (a heroic rat soldier: upright, broad in the shoulder, a long snout and big ears, digitigrade
legs, a tail like a whip; a leather jerkin, a tin cap, a spear), rat_b.glb (a rat as a rat is: hunched on its hind
legs, long body, short arms, a head carried low; the same kit), frog_a.glb (a heroic frog soldier: upright on long
folded legs, a broad chest, a wide flat head with the eyes on top; a bark cuirass, a spear) and frog_b.glb (a frog as
a frog is: squat, the haunches folded under, the forelimbs planted, the spear in one hand). Part units, +X forward,
+Z up, about 34-40 tall like a human soldier (rats are human-sized, D-116). Materials: "fur", "pink" (ears, tail,
hands, feet), "frogskin", "belly", "eye", "cloth", "team", "leather", "iron", "wood".
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]


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
    """A tapered tube along (point, radius) pairs, capped; flat squashes it across."""
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


def lathe(name, material, profile, segs=32, squash=lambda z, a: (1.0, 1.0), at=(0.0, 0.0), tilt=0.0, pivot=0.0):
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
    if tilt:
        for v in ob.data.vertices:   # lean forward about the hips (z = pivot), as the trunk does
            z0 = pivot
            dz = v.co.z - z0
            v.co.x += dz * math.sin(math.radians(tilt))
            v.co.z = z0 + dz * math.cos(math.radians(tilt))
    return ob


def box(name, material, centre, size, rot=(0, 0, 0)):
    ob = obj(name, material)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(ob.data)
    bm.free()
    ob.location = centre
    ob.rotation_euler = rot
    return ob


def finish(path, smooth):
    for ob in bpy.data.objects:
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if ob.name.startswith(smooth):
            mod = ob.modifiers.new("smooth", "SUBSURF")
            mod.levels = 1
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("wrote", path)


def materials():
    return {k: mat(k, c) for k, c in (("fur", (0.5, 0.46, 0.42)), ("pink", (0.85, 0.6, 0.6)), ("frogskin", (0.3, 0.5, 0.2)),
                                       ("belly", (0.85, 0.8, 0.6)), ("eye", (0.05, 0.04, 0.03)), ("cloth", (0.55, 0.45, 0.3)),
                                       ("team", (1, 0, 1)), ("leather", (0.4, 0.26, 0.14)), ("iron", (0.6, 0.6, 0.64)),
                                       ("wood", (0.45, 0.3, 0.18)))}


def spear(M, hand, up=Vector((0.25, 0, 1.0)), length=40.0, low=11.0):
    d = up.normalized()
    tube("spear_shaft", M["wood"], [(hand - d * low, 0.42), (hand + d * (length - low), 0.38)], segs=8)
    tip = hand + d * (length - low)
    tube("spear_head", M["iron"], [(tip, 0.55), (tip + d * 1.6, 0.85), (tip + d * 4.0, 0.05)], segs=4, flat=0.3)


def rat(variant):
    """A: heroic, upright. B: a rat as a rat is, hunched, the head low."""
    reset()
    M = materials()
    heroic = variant == "a"
    lean = 18.0 if heroic else 42.0        # how far the trunk leans forward (degrees)
    hip = Vector((0, 0, 15.5 if heroic else 11.0))
    trunk_len = 15.0 if heroic else 15.5
    # Trunk: a pear lying forward from the hips, the chest broad (heroic) or narrow; belly paler in front.
    chest_r = 5.4 if heroic else 4.4
    lathe("trunk", M["fur"], [(0.0, 3.6), (2.5, 4.9), (6.0, 5.2), (9.5, chest_r), (12.5, chest_r * 0.85), (14.5, 3.0), (trunk_len, 2.2)],
          squash=lambda z, a: (0.78 + 0.1 * max(0.0, math.cos(a)) * smoothstep(5, 11, z), 1.0), at=(0, 0), tilt=lean)
    for ob in [bpy.data.objects["trunk"]]:
        for v in ob.data.vertices:
            v.co += hip
    top = hip + Vector((math.sin(math.radians(lean)) * trunk_len, 0, math.cos(math.radians(lean)) * trunk_len))
    sh = hip + Vector((math.sin(math.radians(lean)) * 12.0, 0, math.cos(math.radians(lean)) * 12.0))
    # Head: a long tapering snout, the skull behind it, big round ears, a black eye each side, whiskers.
    fwd = Vector((math.cos(math.radians(25 if heroic else 5)), 0, -math.sin(math.radians(25 if heroic else 5))))
    neck = top + Vector((0.8, 0, 0.6))
    skull = neck + Vector((0.6, 0, 2.6 if heroic else 1.6))
    ball("skull", M["fur"], skull, (3.4, 3.0, 2.9), segs=20)
    tube("snout", M["fur"], [(skull + fwd * 1.0, 2.6), (skull + fwd * 3.6, 1.9), (skull + fwd * 6.2, 1.0), (skull + fwd * 7.4, 0.45)], segs=14)
    ball("nose", M["pink"], skull + fwd * 7.5, (0.55, 0.55, 0.5), segs=10)
    for side in (1, -1):
        ball("ear%d" % side, M["pink"], skull + Vector((-1.2, side * 2.6, 2.4)), (1.9, 0.45, 2.1), segs=14, rot=(side * math.radians(-20), 0, side * math.radians(10)))
        ball("eye%d" % side, M["eye"], skull + fwd * 2.4 + Vector((0, side * 1.75, 0.8)), (0.42, 0.42, 0.42), segs=8)
        for w in range(3):
            tube("whisker%d%d" % (side, w), M["eye"], [(skull + fwd * 6.0 + Vector((0, side * 0.6, -0.1)), 0.06),
                                                       (skull + fwd * 6.6 + Vector((-0.6, side * 3.8, -0.6 + w * 0.6)), 0.03)], segs=3)
    # Legs: a heavy thigh folded forward, the long shank back, standing on long hind feet (digitigrade).
    for side in (1, -1):
        y = side * (2.8 if heroic else 2.6)
        knee = hip + Vector((3.8, y, -6.0 if heroic else -4.5))
        heel = Vector((-1.6, y * 1.05, 3.4 if heroic else 2.6))
        tube("thigh%d" % side, M["fur"], [(hip + Vector((0, y * 0.8, 0)), 3.3), (knee, 2.0)], segs=14)
        tube("shank%d" % side, M["fur"], [(knee, 1.9), (heel, 1.1)], segs=12)
        tube("foot%d" % side, M["pink"], [(heel, 1.0), (Vector((2.2, y * 1.05, 0.45)), 0.7), (Vector((4.6, y * 1.1, 0.35)), 0.45)], segs=10, flat=0.55)
    # Tail: thick at the root, whipping out behind and up.
    tail = [(hip + Vector((-3.0, 0, -1.0)), 1.3), (Vector((-9, 1.5, 4.5)), 0.95), (Vector((-15, 3.0, 2.2)), 0.7), (Vector((-20, 4.0, 4.5)), 0.45), (Vector((-23, 4.5, 9.0)), 0.18)]
    tube("tail", M["pink"], tail, segs=10)
    # Arms: shoulders out on the chest, the spear arm forward, the far arm down holding the jerkin's strap.
    for side in (1, -1):
        s0 = sh + Vector((0.6, side * (4.4 if heroic else 3.4), 0))
        if side < 0:
            el = s0 + Vector((1.8, -0.8, -4.2))
            hd = el + Vector((3.6, 0.2, 0.6))
        else:
            el = s0 + Vector((-0.6, 1.0, -4.4))
            hd = el + Vector((2.4, 0.0, -3.0))
        tube("uarm%d" % side, M["fur"], [(s0, 1.9 if heroic else 1.5), (el, 1.4)], segs=12)
        tube("farm%d" % side, M["fur"], [(el, 1.35), (hd, 0.95)], segs=12)
        ball("hand%d" % side, M["pink"], hd, (0.9, 0.75, 0.75), segs=10)
        if side < 0:
            spear(M, hd)
    # Kit: a leather jerkin over the chest (a shell just outside the trunk), a team scarf, a tin cap between the ears.
    jer = lathe("jerkin", M["leather"], [(2.5, 5.3), (6.0, 5.6), (9.5, chest_r + 0.4), (12.3, chest_r * 0.85 + 0.4), (13.6, 3.6)],
                squash=lambda z, a: (0.82 + 0.1 * max(0.0, math.cos(a)) * smoothstep(5, 11, z), 1.04), tilt=lean)
    for v in jer.data.vertices:
        v.co += hip
    sc = lathe("scarf", M["team"], [(12.6, 3.7), (13.6, 3.4), (14.3, 2.7)], squash=lambda z, a: (0.95, 1.1), tilt=lean)
    for v in sc.data.vertices:
        v.co += hip
    cap = ball("cap", M["iron"], skull + Vector((-0.4, 0, 2.3)), (2.5, 2.2, 1.4), segs=18)
    for v in cap.data.vertices:
        v.co.z = max(v.co.z, -0.2)
    lathe("cap_rim", M["iron"], [(0.0, 2.75), (0.25, 2.75)], segs=20, at=(skull.x - 0.4, 0))
    bpy.data.objects["cap_rim"].location.z = skull.z + 2.1
    for ob in bpy.data.objects:   # human-sized (D-116): the heroic rat's ears at a heroic human's crown
        ob.scale = Vector((1.12, 1.12, 1.12)) if heroic else Vector((1.05, 1.05, 1.05))
        ob.location = ob.location * (1.12 if heroic else 1.05)
    finish(out_dir + "rat_%s.glb" % variant, smooth=("trunk", "skull", "snout", "thigh", "shank", "jerkin", "cap"))


def frog(variant):
    """A: heroic, upright on long folded legs. B: a frog as a frog is, squat on its haunches."""
    reset()
    M = materials()
    heroic = variant == "a"
    hip = Vector((-1.0, 0, 13.5 if heroic else 7.5))
    lean = 20.0 if heroic else 55.0
    trunk = lathe("trunk", M["frogskin"], [(0.0, 5.2), (3.0, 6.4), (7.0, 6.6), (11.0, 5.8), (13.5, 4.6)],
                  squash=lambda z, a: (0.8 + 0.12 * max(0.0, math.cos(a)), 1.08), tilt=lean)
    belly = lathe("belly", M["belly"], [(1.0, 4.6), (4.0, 5.9), (8.0, 5.9), (11.0, 5.0)],
                  squash=lambda z, a: (0.86 if math.cos(a) > 0.2 else 0.5, 0.85), tilt=lean, at=(0.45, 0))
    for ob in (trunk, belly):
        for v in ob.data.vertices:
            v.co += hip
    top = hip + Vector((math.sin(math.radians(lean)) * 13.0, 0, math.cos(math.radians(lean)) * 13.0))
    # Head: wide and flat, the mouth a long seam, the eyes bulging on top.
    hc = top + Vector((2.2, 0, 1.4))
    head = ball("head", M["frogskin"], hc, (5.0, 5.6, 3.2), segs=24)
    for v in head.data.vertices:
        if v.co.z < 0:
            v.co.z *= 0.75
    ball("jaw", M["belly"], hc + Vector((0.8, 0, -1.3)), (4.4, 5.0, 1.7), segs=20)
    tube("mouth", M["eye"], [(hc + Vector((3.4, -4.4, -0.6)), 0.12), (hc + Vector((4.95, 0, -0.5)), 0.12), (hc + Vector((3.4, 4.4, -0.6)), 0.12)], segs=4)
    for side in (1, -1):
        e = hc + Vector((1.4, side * 3.2, 2.4))
        ball("eyebulge%d" % side, M["frogskin"], e, (1.9, 1.8, 1.7), segs=14)
        ball("eyeball%d" % side, M["belly"], e + Vector((0.7, side * 0.35, 0.35)), (1.25, 1.2, 1.2), segs=12)
        ball("pupil%d" % side, M["eye"], e + Vector((1.75, side * 0.6, 0.45)), (0.35, 0.55, 0.55), segs=8)
    # Hind legs: folded in a Z, the thigh forward, the shank back, the long webbed foot flat.
    for side in (1, -1):
        y = side * (4.6 if heroic else 5.4)
        knee = hip + Vector((6.0 if heroic else 7.5, y * 1.25, -4.0 if heroic else -3.2))
        ankle = Vector((-3.0, y * 1.2, 3.2 if heroic else 1.6))
        tube("thigh%d" % side, M["frogskin"], [(hip + Vector((0, y * 0.7, 0)), 3.4), (knee, 2.1)], segs=14)
        tube("shank%d" % side, M["frogskin"], [(knee, 2.0), (ankle, 1.1)], segs=12)
        for t in (-1, 0, 1):   # three long toes, webbed
            tube("toe%d%d" % (side, t), M["frogskin"], [(ankle, 0.8), (Vector((3.5, y * 1.2 + t * 1.2, 0.35)), 0.45), (Vector((5.6, y * 1.2 + t * 2.0, 0.3)), 0.35)], segs=8, flat=0.5)
    # Forelimbs: from the chest, the spear arm raised forward, the other down (planted, for B).
    sh = hip + Vector((math.sin(math.radians(lean)) * 10.0, 0, math.cos(math.radians(lean)) * 10.0))
    for side in (1, -1):
        s0 = sh + Vector((1.5, side * 5.2, 0))
        if side < 0:
            el = s0 + Vector((2.5, -1.4, -3.5))
            hd = el + Vector((3.2, 0.6, 1.5))
        else:
            el = s0 + Vector((2.0, 1.8, -4.5))
            hd = el + Vector((2.5, 0.0, -4.5 if not heroic else -2.5))
            if not heroic:
                hd.z = 0.8
        tube("uarm%d" % side, M["frogskin"], [(s0, 1.6), (el, 1.2)], segs=12)
        tube("farm%d" % side, M["frogskin"], [(el, 1.15), (hd, 0.8)], segs=12)
        for t in (-1, 0, 1):
            tube("finger%d%d" % (side, t), M["frogskin"], [(hd, 0.45), (hd + Vector((1.4, t * 0.7, -0.4)), 0.3)], segs=6)
            ball("pad%d%d" % (side, t), M["belly"], hd + Vector((1.5, t * 0.75, -0.45)), (0.38, 0.38, 0.3), segs=8)
        if side < 0:
            spear(M, hd, up=Vector((0.35, 0, 1.0)), length=36.0, low=9.0)
    # Kit: a bark cuirass over the back and chest, a team sash, a leaf over the shoulder.
    cui = lathe("cuirass", M["wood"], [(3.0, 6.9), (7.0, 7.1), (11.0, 6.3)], squash=lambda z, a: (0.84 + 0.12 * max(0.0, math.cos(a)), 1.12), tilt=lean)
    sash = lathe("sash", M["team"], [(2.0, 6.75), (3.0, 7.0)], squash=lambda z, a: (0.84 + 0.12 * max(0.0, math.cos(a)), 1.12), tilt=lean)
    for ob in (cui, sash):
        for v in ob.data.vertices:
            v.co += hip
    finish(out_dir + "frog_%s.glb" % variant, smooth=("trunk", "belly", "head", "jaw", "eyebulge", "thigh", "shank", "cuirass"))


rat("a")
rat("b")
frog("a")
frog("b")
