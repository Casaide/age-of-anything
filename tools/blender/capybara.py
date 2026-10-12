"""The capybara (the rats' mount) for the unit bakes, modelled by script (Blender 5, headless):

    blender -b --python tools/blender/capybara.py -- assets/models/head_capybara.glb head
    blender -b --python tools/blender/capybara.py -- assets/models/body_capybara.glb body

Built in the game's part units, facing +X, up +Z (glTF turns that into Godot's +X forward, +Y
up), in the frames of unit_models.gd's capybara parts: the head about 10 long from its neck
point, the body standing on the ground (its legs are the game's own, hung from anchors).

The head is the reason for this file ("very cubey face": Dominic, CP1): a sphere pushed into
a soft rounded block and sculpted by functions of position, so it has a capybara's structure
at 30 pixels: a deep blunt muzzle (tall, squarish but soft), the heavy cheek of the chewing
muscle, small eyes high and far back on a slight brow, small round ears at the back of the
crown, and nostrils on top of the muzzle's front. The body is a barrel sloping up to a heavy,
tailless rump, with a short thick neck rising to the head. Materials are named "fur", "nose",
"eye" and "ear": the game swaps in its own (the race's palette).
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, part = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


FUR, NOSE, EYE, EAR = mat("fur", (0.6, 0.42, 0.25)), mat("nose", (0.25, 0.17, 0.12)), mat("eye", (0.05, 0.04, 0.04)), mat("ear", (0.35, 0.24, 0.17))


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


def bump(p, c, r):
    """1 at c, falling to 0 at distance r."""
    d = (p - c).length / r
    return max(0.0, 1.0 - d * d) ** 2


def sphere(name, segs=48, rings=32):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    return ob, bm


def blockish(p, n):
    """A unit-sphere point pushed out onto a superellipsoid (n > 2: a rounded block)."""
    s = (abs(p.x) ** n + abs(p.y) ** n + abs(p.z) ** n) ** (1.0 / n)
    return p / s


def ellipsoid(name, r, at, m, segs=16, rings=10):
    ob, bm = sphere(name, segs, rings)
    for v in bm.verts:
        v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + Vector(at)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    return ob


def head():
    # Lengthwise, t runs 0 at the back of the skull to 1 at the muzzle's front.
    X0, X1 = -1.6, 8.4
    ob, bm = sphere("head", 56, 36)
    for v in bm.verts:
        p = blockish(v.co.copy(), 3.0)
        t = (p.x + 1) / 2
        top = curve([(0.0, 1.8), (0.2, 2.5), (0.6, 2.45), (0.9, 2.1), (1.0, 1.9)], t)      # a near-flat line, crown to nose
        bot = curve([(0.0, -1.6), (0.25, -3.2), (0.6, -3.4), (0.9, -3.2), (1.0, -2.9)], t)  # the deep jaw; the muzzle stays deep
        half = curve([(0.0, 2.0), (0.35, 2.6), (0.7, 2.3), (1.0, 2.05)], t)                 # cheeks wide, muzzle a little narrower
        z = lerp(bot, top, (p.z + 1) / 2)
        y = p.y * half
        x = lerp(X0, X1, t)
        # The muzzle's front: nearly upright, the lower lip tucked a little behind the nose.
        x -= smoothstep(0.75, 1.0, t) * smoothstep(0.0, -1.0, p.z) * 0.5
        q = Vector((x, y, z))
        # The chewing muscle: a heavy rounded cheek low behind the eye.
        for s in (-1, 1):
            q += Vector((0, 0.5 * s, -0.1)) * bump(Vector((t, p.y, p.z)), Vector((0.36, 0.9 * s, -0.35)), 0.45)
            # The brow the eye sits under: a slight rise on the crown's edge.
            q += Vector((0, 0.15 * s, 0.3)) * bump(Vector((t, p.y, p.z)), Vector((0.44, 0.7 * s, 0.75)), 0.3)
        # The nose's bridge: a gentle convex rise along the top of the muzzle.
        q.z += 0.2 * smoothstep(0.55, 0.8, t) * (1 - smoothstep(0.92, 1.0, t)) * smoothstep(0.4, 1.0, p.z)
        v.co = q
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(FUR)
    # The bare nose: a dark pad over the top of the muzzle's front, nearly flush, the nostrils on it.
    ellipsoid("nose", (0.45, 1.3, 0.8), (8.1, 0, 1.05), NOSE, 20, 12)
    for s in (-1, 1):
        ellipsoid("nostril", (0.3, 0.22, 0.18), (8.25, 0.6 * s, 1.75), EYE, 10, 6)
        # Eyes: small, high and far back, on the side of the head under the brow.
        ellipsoid("eye", (0.55, 0.35, 0.5), (2.85, 2.25 * s, 1.5), EYE, 12, 8)
        # Ears: small and round, high at the back of the crown, turned a little out.
        ear, bm = sphere("ear", 14, 8)
        for v in bm.verts:
            q = Vector((v.co.x * 0.55, v.co.y * 0.3, v.co.z * 0.48))
            q.y += q.z * 0.35 * s   # leaning out
            v.co = q + Vector((-0.1, 1.6 * s, 2.4))
        bm.to_mesh(ear.data)
        bm.free()
        ear.data.materials.append(EAR)
    # The mouth: a short dark line under the nose, splitting the upper lip.
    ellipsoid("mouth", (0.2, 0.18, 0.7), (8.15, 0, -0.6), NOSE, 8, 6)


LOW = 1.8   # the body sits this much lower than the curves say: a capybara's legs are short


def body():
    # Lengthwise, t runs 0 at the rump to 1 at the neck's top, where the head joins.
    X0, X1 = -14.5, 14.0
    ob, bm = sphere("body", 64, 40)
    for v in bm.verts:
        p = blockish(v.co.copy(), 2.25)
        t = (p.x + 1) / 2
        top = curve([(0.0, 15.0), (0.12, 20.6), (0.35, 21.6), (0.7, 20.0), (0.88, 19.2), (1.0, 18.6)], t)   # the heavy rump high, the back sloping down
        bot = curve([(0.0, 10.5), (0.12, 7.8), (0.45, 6.4), (0.75, 7.4), (0.88, 10.0), (1.0, 12.5)], t)     # a deep belly, the throat rising
        half = curve([(0.0, 4.5), (0.15, 7.8), (0.45, 8.6), (0.75, 7.2), (0.9, 5.4), (1.0, 4.6)], t)
        z = lerp(bot, top, (p.z + 1) / 2)
        y = p.y * half * (1.0 - 0.12 * smoothstep(0.2, -1.0, p.z))   # narrower under the belly
        x = lerp(X0, X1, t)
        # Coarse fur: a shallow shag over the back and flanks, breaking the plastic sheen.
        shag = 0.18 * math.sin(9 * x * 0.37 + 5 * math.atan2(y, z - 13)) * smoothstep(-0.6, 0.4, p.z)
        n = Vector((0, p.y, p.z)).normalized() if abs(p.y) + abs(p.z) > 1e-4 else Vector((0, 0, 1))
        v.co = Vector((x, y, z - LOW)) + n * shag
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(FUR)


head() if part == "head" else body()

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
