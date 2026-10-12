"""A human head for the unit bakes, modelled by script (Blender 5, run headless):

    blender -b --python tools/blender/human_head.py -- assets/models/head_human.glb

Built in the game's part units (a head about 9 tall), facing +X, up +Z (glTF turns that into
Godot's +X forward, +Y up). The skull is a sphere sculpted by functions of position: brow ridge,
eye sockets, cheekbones, a nose, jaw and chin, so it has structure at 30 pixels rather than
being an egg. Ears and a hair cap are their own objects. Materials are named "skin", "hair" and
"eye": the game swaps in its own (team palettes, skin tones) when it loads the file.
"""
import sys, math
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
# Face options (for concept sheets): eye=<radius scale> wide=<how much wider than tall>
# brows=<0 none, else thickness> white=<1: an eye white behind the dark iris>
opt = {"eye": 1.3, "wide": 1.3, "brows": 1.6, "white": 0, "bx": 4.3}   # the picked look (2026-10-13)
for a in args[1:]:
    k, v = a.split("=")
    opt[k] = float(v)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


SKIN, HAIR, EYE = mat("skin", (0.85, 0.65, 0.5)), mat("hair", (0.2, 0.12, 0.06)), mat("eye", (0.05, 0.04, 0.04))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def bump(p, c, r):
    """1 at c, falling to 0 at distance r."""
    d = (p - c).length / r
    return max(0.0, 1.0 - d * d) ** 2


def sphere(name, radius, segs=48, rings=32):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    return ob, bm


# ---- the skull and face: a sphere, pushed and pulled
head, bm = sphere("head", 1.0)
for v in bm.verts:
    p = v.co.copy()   # unit sphere
    x, y, z = p
    # Proportions: a little longer front to back than wide, taller than both.
    q = Vector((x * 4.3, y * 3.9, z * 4.9))
    front = smoothstep(0.1, 0.9, x)
    # The face is flatter than the back of the skull.
    q.x -= front * 0.6
    # Jaw: narrower and forward under the face; the chin juts.
    low = smoothstep(-0.1, -0.8, z)
    # (Gently: a sharp narrowing under a jutting chin faced the ground, and its shadow band read
    # as stubble on every face: Dominic.)
    q.y *= 1.0 - low * 0.16
    q.x += low * front * 0.3
    q += Vector((1.0, 0, 0)) * bump(p, Vector((0.75, 0, -0.55)), 0.35) * 0.3   # chin
    # Brow ridge across the forehead, eye sockets under it.
    q.x += bump(p, Vector((0.85, 0, 0.32)), 0.55) * 0.45
    for s in (-1, 1):
        q -= Vector((1.0, 0, 0)) * bump(p, Vector((0.8, 0.38 * s, 0.12)), 0.26) * 0.55   # socket
        q += Vector((0.4, 0.6 * s, 0)) * bump(p, Vector((0.62, 0.62 * s, -0.12)), 0.35) * 0.4   # cheekbone
    # The nose: a ridge down the middle of the face, a tip and nostrils.
    ridge = bump(Vector((0, y, 0)), Vector((0, 0, 0)), 0.16) * smoothstep(0.75, 0.95, x) * smoothstep(-0.45, 0.2, z) * (1 - smoothstep(0.2, 0.35, z))
    q.x += ridge * 1.1
    q.x += bump(p, Vector((0.97, 0, -0.18)), 0.2) * 0.9   # the tip
    v.co = q + Vector((0.5, 0, 5.2))
bm.to_mesh(head.data)
bm.free()
head.data.materials.append(SKIN)

# ---- ears
for s in (-1, 1):
    ear, bm = sphere("ear", 1.0, 16, 10)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.7, v.co.y * 0.35, v.co.z * 1.25)) + Vector((-0.2, 3.95 * s, 5.0))
    bm.to_mesh(ear.data)
    bm.free()
    ear.data.materials.append(SKIN)

# ---- eyes, set in the sockets (a tiny dark dot read as creepy: Dominic; options are bigger,
# wider eyes, a white round the iris, and brows over them)
WHITE = mat("eye_white", (0.9, 0.87, 0.8))
for s in (-1, 1):
    r = 0.42 * opt["eye"]
    if opt["white"]:
        white, bm = sphere("eye_white", 1.0, 12, 8)
        for v in bm.verts:
            v.co = Vector((v.co.x * r * 0.9, v.co.y * r * 1.5 * opt["wide"], v.co.z * r * 0.95)) + Vector((3.75, 1.55 * s, 5.75))
        bm.to_mesh(white.data)
        bm.free()
        white.data.materials.append(WHITE)
    eye, bm = sphere("eye", 1.0, 12, 8)
    for v in bm.verts:
        w = 1.0 if opt["white"] else opt["wide"]
        v.co = Vector((v.co.x * r, v.co.y * r * w, v.co.z * r)) + Vector((3.85 + (0.12 if opt["white"] else 0), 1.55 * s, 5.75))
    bm.to_mesh(eye.data)
    bm.free()
    eye.data.materials.append(EYE)
    if opt["brows"] > 0:   # a brow: a flattened hair-coloured bar on the ridge, tilted down at the outer end
        brow, bm = sphere("brow", 1.0, 12, 8)
        for v in bm.verts:
            q = Vector((v.co.x * 0.35, v.co.y * 0.95, v.co.z * 0.22 * opt["brows"]))
            q.z -= 0.18 * q.y * s   # the outer end lower
            v.co = q + Vector((opt["bx"], 1.5 * s, 6.55 + 0.1 * opt["eye"]))
        bm.to_mesh(brow.data)
        bm.free()
        brow.data.materials.append(HAIR)

# ---- hair: a cap over the top and back of the skull, a little shaggy
hair, bm = sphere("hair", 1.0, 40, 24)
drop = []
for v in bm.verts:
    p = v.co.copy()
    x, y, z = p
    shag = 1.0 + 0.05 * math.sin(11 * math.atan2(y, x)) * smoothstep(-0.2, 0.4, z)
    q = Vector((x * 4.6, y * 4.2, z * 5.15)) * shag
    v.co = q + Vector((0.2, 0, 5.45))
    # Keep the top and back: cut away the face and below the ears.
    if z < -0.15 + 0.55 * smoothstep(0.0, 0.7, x) or (x > 0.55 and z < 0.55):
        drop.append(v)
bmesh.ops.delete(bm, geom=drop, context="VERTS")
bm.to_mesh(hair.data)
bm.free()
hair.data.materials.append(HAIR)

for ob in bpy.data.objects:
    for poly in ob.data.polygons:
        poly.use_smooth = True
    mod = ob.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1
    if ob.name.startswith("hair"):
        sol = ob.modifiers.new("thick", "SOLIDIFY")
        sol.thickness = 0.35

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_materials="EXPORT")
print("wrote", out)
