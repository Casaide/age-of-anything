"""The horse's head (the pony's look h2) for the unit bakes, modelled by script (Blender 5, headless):

    blender -b --python tools/blender/horse.py -- assets/models/head_horse.glb

Dominic, 2026-10-13: "horses heads need a real re-work". Built in the game's part units, facing +X,
up +Z (glTF turns that into Godot's +X forward, +Y up), in the frame of unit_models.gd's reworked
pony heads: the socket (between the poll and the throat latch) at the origin, the face running along
+X before the head is pitched nose-down (HORSE_TILT), the back of the head at x -1.6, the muzzle's
front at 11.8. One surface lofted from a sphere: at each point along the head its top line (the
poll's rise, then the forehead and the nose one straight line, down to the soft muzzle), its jaw line
(the big round jowl low at the back, the jaw's edge rising to the chin) and its half-width (the
jowl broad, the face narrowing to the muzzle, which flares a little at the nostrils); the face's
sides flat and drawing in towards the jaw, a brow over the eye, the chin, the nostrils' flare.
Materials "hide", "muzzle", "nostril", "eye": the game swaps in its own (the coat's palette). The
ears, forelock and bridle are the game's (unit_models._horse_ears), as on h1.
"""
import sys
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


HIDE, MUZZLE, NOSTRIL, EYE = mat("hide", (0.45, 0.3, 0.2)), mat("muzzle", (0.3, 0.2, 0.15)), mat("nostril", (0.06, 0.05, 0.04)), mat("eye", (0.05, 0.04, 0.04))

X0, X1 = -1.6, 11.8
TOP = [(-1.6, 0.8), (-0.7, 2.6), (0.6, 3.25), (2.0, 2.95), (5.0, 2.4), (8.0, 1.9), (10.4, 1.45), (11.3, 0.95), (11.8, 0.1)]
BOT = [(-1.6, -0.6), (-0.4, -2.7), (1.3, -3.45), (3.2, -3.0), (5.5, -2.45), (8.0, -2.1), (9.4, -2.3), (10.8, -1.75), (11.8, -0.7)]
HALF = [(-1.6, 1.4), (-0.4, 2.05), (1.2, 2.3), (2.8, 2.0), (4.4, 1.75), (6.6, 1.5), (8.6, 1.35), (10.0, 1.45), (11.0, 1.3), (11.8, 0.8)]


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def curve(pts, x):
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, v0), (x1, v1) in zip(pts, pts[1:]):
        if x <= x1:
            return lerp(v0, v1, smoothstep(x0, x1, x))
    return pts[-1][1]


def bump(p, c, r):
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
    s = (abs(p.x) ** n + abs(p.y) ** n + abs(p.z) ** n) ** (1.0 / n)
    return p / s


def ellipsoid(name, r, at, m, segs=14, rings=8):
    ob, bm = sphere(name, segs, rings)
    for v in bm.verts:
        v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + Vector(at)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    return ob


def head():
    ob, bm = sphere("head", 64, 36)
    for v in bm.verts:
        p = blockish(v.co.copy(), 2.4)
        x = lerp(X0, X1, (p.x + 1) / 2)
        top, bot, half = curve(TOP, x), curve(BOT, x), curve(HALF, x)
        u = (p.z + 1) / 2   # 0 under the jaw, 1 on top
        z = lerp(bot, top, u)
        # The face's sides draw in towards the jaw (a rounded wedge in section, not a tube), most
        # along the face; the jowl stays round and full low down.
        face = smoothstep(2.5, 5.0, x) * (1 - smoothstep(9.6, 11.0, x))
        y = p.y * half * (1.0 - 0.32 * face * smoothstep(0.55, 0.0, u))
        q = Vector((x, y, z))
        for s in (-1, 1):
            # The jowl: a big round flat cheek low at the back.
            q += Vector((0, 0.35 * s, -0.1)) * bump(Vector((x / 4.0, p.y, p.z)), Vector((1.3 / 4.0, 0.9 * s, -0.35)), 0.6)
            # The brow over the eye.
            q += Vector((0, 0.2 * s, 0.25)) * bump(Vector((x / 3.0, p.y, p.z)), Vector((3.0 / 3.0, 0.75 * s, 0.6)), 0.35)
            # The nostrils' flare at the front of the muzzle.
            q += Vector((0.1, 0.25 * s, 0)) * bump(Vector((x / 2.0, p.y, p.z)), Vector((11.2 / 2.0, 0.8 * s, 0.25)), 0.4)
        # The chin: a soft knob under the lips.
        q.z -= 0.25 * bump(Vector((x / 2.0, p.y, p.z)), Vector((9.6 / 2.0, 0.0, -1.0)), 0.5)
        v.co = q
    ob.data.materials.append(HIDE)
    ob.data.materials.append(MUZZLE)
    for f in bm.faces:
        if f.calc_center_median().x > 9.2:
            f.material_index = 1
    bm.to_mesh(ob.data)
    bm.free()
    for s in (-1, 1):
        ellipsoid("nostril", (0.32, 0.22, 0.45), (11.4, 0.72 * s, 0.25), NOSTRIL)
        hw = curve(HALF, 3.1)
        ellipsoid("eye", (0.5, 0.35, 0.42), (3.1, (hw - 0.05) * s, 1.75), EYE)
    ellipsoid("mouth", (0.7, 0.62, 0.12), (10.9, 0, -1.3), NOSTRIL, 10, 6)


head()

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
