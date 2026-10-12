"""The capybara (the rats' mount) for the unit bakes, modelled by script (Blender 5, headless):

    blender -b --python tools/blender/capybara.py -- assets/models/head_capybara.glb head
    blender -b --python tools/blender/capybara.py -- assets/models/body_capybara.glb body
    blender -b --python tools/blender/capybara.py -- assets/models/head_capybara_long.glb head long

Built in the game's part units, facing +X, up +Z (glTF turns that into Godot's +X forward, +Y
up), in the frames of unit_models.gd's capybara parts: the head about 10 long from its neck
point, the body standing on the ground (its legs are the game's own, hung from anchors).

The head is the reason for this file ("very cubey face": Dominic, CP1): a sphere pushed into
a soft rounded block and sculpted by functions of position, so it has a capybara's structure
at 30 pixels: a deep blunt muzzle (tall, squarish but soft), the heavy cheek of the chewing
muscle, small eyes high and far back on a slight brow, small round ears at the back of the
crown, and nostrils on top of the muzzle's front. The body is a barrel sloping up to a heavy,
tailless rump, with a short thick neck rising to the head. Materials are named "fur", "nose",
"eye", "ear" (and "face" on a tan-faced variant): the game swaps in its own (the race's palette).

An optional third argument picks a variant (VARIANTS below): cp1 (the default, in play) or the
rat-mount round's pushed looks (RM1, "push the capybara further, bigger head, need to avoid it
looking like a bear": Dominic): long (a much longer, flat-topped, brick-shaped head, a short
neck, the rump well above the shoulders) and long_tan (longer still, with a tan face).
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, part = args[0], args[1]
variant = args[2] if len(args) > 2 else "cp1"
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


FUR, NOSE, EYE, EAR = mat("fur", (0.6, 0.42, 0.25)), mat("nose", (0.25, 0.17, 0.12)), mat("eye", (0.05, 0.04, 0.04)), mat("ear", (0.35, 0.24, 0.17))
FACE = mat("face", (0.75, 0.58, 0.38))

# Head: its front end (the back of the skull is at -1.6), top / jaw / half-width curves along it
# (t 0 at the back, 1 at the nose), where the cheek, brow, eye and ear sit, a tan mask or not.
# Body: its ends, top / belly / half-width curves (t 0 at the rump, 1 at the neck).
VARIANTS = {
    "cp1": {
        "x1": 8.4,
        "top": [(0.0, 1.8), (0.2, 2.5), (0.6, 2.45), (0.9, 2.1), (1.0, 1.9)],
        "bot": [(0.0, -1.6), (0.25, -3.2), (0.6, -3.4), (0.9, -3.2), (1.0, -2.9)],
        "half": [(0.0, 2.0), (0.35, 2.6), (0.7, 2.3), (1.0, 2.05)],
        "cheek": 0.36, "brow": 0.44, "eye": (2.85, 2.25, 1.5), "ear": (-0.1, 1.6, 2.4), "ear_r": (0.55, 0.3, 0.48),
        "face": False, "bridge": 0.2, "block": 3.0,
        "x0b": -14.5, "x1b": 14.0,
        "btop": [(0.0, 15.0), (0.12, 20.6), (0.35, 21.6), (0.7, 20.0), (0.88, 19.2), (1.0, 18.6)],
        "bbot": [(0.0, 10.5), (0.12, 7.8), (0.45, 6.4), (0.75, 7.4), (0.88, 10.0), (1.0, 12.5)],
        "bhalf": [(0.0, 4.5), (0.15, 7.8), (0.45, 8.6), (0.75, 7.2), (0.9, 5.4), (1.0, 4.6)],
    },
    # A head 12 long and 7 deep: the top flat from the crown to the nose, the muzzle as deep as the skull and
    # narrower than it is tall (a capybara's brick, not a bear's broad round snout), tiny ears
    # flat on the back corners, eyes on the top edge. The rump stands well above the shoulders and
    # the back slopes down to a short neck that holds the head low and forward.
    "long": {
        "x1": 10.4,
        "top": [(0.0, 2.2), (0.12, 2.9), (0.5, 3.0), (0.85, 2.85), (1.0, 2.5)],
        "bot": [(0.0, -2.2), (0.22, -4.1), (0.5, -4.2), (0.8, -3.9), (1.0, -3.5)],
        "half": [(0.0, 2.2), (0.3, 2.8), (0.55, 2.35), (0.8, 2.0), (1.0, 1.85)],
        "cheek": 0.3, "brow": 0.3, "eye": (3.4, 2.45, 2.0), "ear": (-0.6, 1.9, 3.0), "ear_r": (0.9, 0.36, 0.85),
        "face": False, "bridge": 0.1, "block": 4.0,
        "x0b": -14.0, "x1b": 12.0,
        "btop": [(0.0, 16.5), (0.12, 21.6), (0.3, 22.2), (0.6, 20.4), (0.85, 18.4), (1.0, 17.0)],
        "bbot": [(0.0, 10.5), (0.12, 7.6), (0.45, 6.6), (0.75, 7.6), (0.9, 10.0), (1.0, 11.6)],
        "bhalf": [(0.0, 4.8), (0.15, 7.6), (0.45, 8.2), (0.75, 7.0), (0.9, 5.2), (1.0, 4.4)],
    },
    # Longer still (14), the muzzle squarer and the face tan: the paler mask shows the head's
    # length from the front and the back, where a dark round face read as a bear.
    "long_tan": {
        "x1": 12.4,
        "top": [(0.0, 2.2), (0.1, 2.95), (0.5, 3.05), (0.88, 3.0), (1.0, 2.7)],
        "bot": [(0.0, -2.2), (0.2, -4.2), (0.45, -4.4), (0.8, -4.2), (1.0, -3.9)],
        "half": [(0.0, 2.2), (0.28, 2.8), (0.5, 2.3), (0.8, 2.0), (1.0, 1.9)],
        "cheek": 0.26, "brow": 0.26, "eye": (3.6, 2.45, 2.05), "ear": (-0.7, 1.9, 3.05), "ear_r": (0.9, 0.36, 0.85),
        "face": True, "bridge": 0.08, "block": 4.5,
        "x0b": -14.5, "x1b": 12.0,
        "btop": [(0.0, 17.0), (0.12, 22.0), (0.28, 22.4), (0.6, 20.4), (0.85, 18.2), (1.0, 16.6)],
        "bbot": [(0.0, 10.8), (0.12, 7.6), (0.45, 6.6), (0.75, 7.6), (0.9, 10.0), (1.0, 11.4)],
        "bhalf": [(0.0, 5.0), (0.15, 7.6), (0.45, 8.2), (0.75, 7.0), (0.9, 5.0), (1.0, 4.2)],
    },
}
P = VARIANTS[variant]


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
    X0, X1 = -1.6, P["x1"]
    ob, bm = sphere("head", 56, 36)
    for v in bm.verts:
        p = blockish(v.co.copy(), P["block"])
        t = (p.x + 1) / 2
        top = curve(P["top"], t)    # a near-flat line, crown to nose
        bot = curve(P["bot"], t)    # the deep jaw; the muzzle stays deep
        half = curve(P["half"], t)  # cheeks wide, the muzzle narrower
        z = lerp(bot, top, (p.z + 1) / 2)
        y = p.y * half
        x = lerp(X0, X1, t)
        # The muzzle's front: nearly upright, the lower lip tucked a little behind the nose.
        x -= smoothstep(0.75, 1.0, t) * smoothstep(0.0, -1.0, p.z) * 0.5
        q = Vector((x, y, z))
        # The chewing muscle: a heavy rounded cheek low behind the eye.
        for s in (-1, 1):
            q += Vector((0, 0.5 * s, -0.1)) * bump(Vector((t, p.y, p.z)), Vector((P["cheek"], 0.9 * s, -0.35)), 0.45)
            # The brow the eye sits under: a slight rise on the crown's edge.
            q += Vector((0, 0.15 * s, 0.3)) * bump(Vector((t, p.y, p.z)), Vector((P["brow"], 0.7 * s, 0.75)), 0.3)
        # The nose's bridge: a gentle convex rise along the top of the muzzle.
        q.z += P["bridge"] * smoothstep(0.55, 0.8, t) * (1 - smoothstep(0.92, 1.0, t)) * smoothstep(0.4, 1.0, p.z)
        v.co = q
    ob.data.materials.append(FUR)
    if variant != "cp1":
        # The pushed heads: the muzzle's whole blunt front bare and dark (a capybara's big
        # leathery nose), and on long_tan a tan mask on the muzzle's sides and under the jaw.
        ob.data.materials.append(FACE)
        ob.data.materials.append(NOSE)
        for f in bm.faces:
            c = f.calc_center_median()
            t = (c.x - X0) / (X1 - X0)
            if t > 0.95 and c.z > -1.2:
                f.material_index = 2
            elif P["face"] and ((t > 0.42 and c.z < 1.0 + 0.7 * smoothstep(0.42, 0.95, t)) or (t > 0.2 and c.z < -2.0)):
                f.material_index = 1
    bm.to_mesh(ob.data)
    bm.free()
    nx = X1 - 0.3              # the muzzle's front
    ntop = curve(P["top"], 1.0)
    # The bare nose: a dark pad over the top of the muzzle's front, nearly flush, the nostrils on it.
    if variant == "cp1":
        ellipsoid("nose", (0.45, 1.3, 0.8), (nx, 0, ntop - 0.85), NOSE, 20, 12)
    else:   # bigger: the pushed heads' broad dark nose, read from the front and the side
        ellipsoid("nose", (0.7, 1.6, 1.2), (nx - 0.1, 0, ntop - 1.0), NOSE, 20, 12)
    for s in (-1, 1):
        ellipsoid("nostril", (0.3, 0.22, 0.18), (nx + 0.15, 0.6 * s, ntop - 0.15), EYE, 10, 6)
        # Eyes: small, high and far back, on the side of the head under the brow.
        ex, ey, ez = P["eye"]
        ellipsoid("eye", (0.55, 0.35, 0.5) if variant == "cp1" else (0.8, 0.5, 0.7), (ex, ey * s, ez), EYE, 12, 8)
        # Ears: small and round, high at the back of the crown, turned a little out.
        ear, bm = sphere("ear", 14, 8)
        rx, ry, rz = P["ear_r"]
        ax, ay, az = P["ear"]
        for v in bm.verts:
            q = Vector((v.co.x * rx, v.co.y * ry, v.co.z * rz))
            q.y += q.z * 0.35 * s   # leaning out
            v.co = q + Vector((ax, ay * s, az))
        bm.to_mesh(ear.data)
        bm.free()
        ear.data.materials.append(EAR)
    # The mouth: a short dark line under the nose, splitting the upper lip.
    ellipsoid("mouth", (0.2, 0.18, 0.7), (nx + 0.05, 0, -0.6), NOSE, 8, 6)


LOW = 1.8   # the body sits this much lower than the curves say: a capybara's legs are short


def body():
    # Lengthwise, t runs 0 at the rump to 1 at the neck's top, where the head joins.
    X0, X1 = P["x0b"], P["x1b"]
    ob, bm = sphere("body", 64, 40)
    for v in bm.verts:
        p = blockish(v.co.copy(), 2.25)
        t = (p.x + 1) / 2
        top = curve(P["btop"], t)    # the heavy rump high, the back sloping down
        bot = curve(P["bbot"], t)    # a deep belly, the throat rising
        half = curve(P["bhalf"], t)
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
