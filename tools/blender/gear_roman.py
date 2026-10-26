"""Roman gear modelled for the heroic humans (D-173, milestone 23 step 2b; Blender 5, headless):

    blender -b --python tools/blender/gear_roman.py -- assets/models/

Writes helm_galea.glb and shield_scutum.glb, made in the frames the game's code puts them in
(scenes/art_pixel/unit_models.gd _helm_galea, _shield_scutum), after the fidelity concept (Dominic: "this is good"):
- helm_galea: in head-gear space (the head's crown socket at the origin, +X forward, the gear scaled with the
  head): an iron bowl with a raised brow ridge and two reinforcing ribs over the crown, a bronze brow band,
  hinged cheek guards shaped to the face, a broad neck guard flaring out behind, a crest holder on top (the
  game adds the crest). Materials: "iron", "bronze".
- shield_scutum: in the shield's facing space (Blender -Y is the face, +Z up, X across): a curved oval-cornered
  board 17 tall and 9.0 across, its face the team colour, a bronze rim, a boss with its flange, a spine up and
  down it, and bronze wings and lightning bolts either side of the boss. Materials: "team", "bronze", "wood".
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


def finish(path, smooth=()):
    for ob in bpy.data.objects:
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if ob.name.startswith(smooth):
            mod = ob.modifiers.new("smooth", "SUBSURF")
            mod.levels = 1
            mod.render_levels = 1
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("wrote", path)


def sweep(name, material, rows, closed=True):
    """A surface from rows of points (each row a ring or strip), faces between neighbouring rows."""
    ob = obj(name, material)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in row] for row in rows]
    n = len(rows[0])
    for i in range(len(vs) - 1):
        for k in range(n if closed else n - 1):
            bm.faces.new((vs[i][k], vs[i][(k + 1) % n], vs[i + 1][(k + 1) % n], vs[i + 1][k]))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def solid(ob, t):
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = t
    mod.offset = 0.0
    return ob


# ------------------------------------------------------------------ the galea
reset()
IRON, BRONZE = mat("iron", (0.62, 0.62, 0.66)), mat("bronze", (0.72, 0.52, 0.26))
C = Vector((0.0, 0.0, -3.8))   # the bowl's centre (the crown socket is the origin: the bowl rises 5 above C)
R = (5.0, 4.8, 5.0)            # its radii: front-back, side, up


def bowl_point(a, e, grow=0.0):
    """A point on the bowl: a = round the head (0 forward), e = elevation (0 at the brow, pi/2 at the crown)."""
    return C + Vector((math.cos(a) * math.cos(e) * (R[0] + grow), math.sin(a) * math.cos(e) * (R[1] + grow), math.sin(e) * (R[2] + grow)))


segs = 40
rows = []
for j in range(13):   # brow (e = -0.08: just under the brow line) up to the crown
    e = -0.08 + (math.pi / 2 - 0.08 + 0.08) * j / 12
    rows.append([bowl_point(2 * math.pi * k / segs, min(e, math.pi / 2 - 0.02)) for k in range(segs)])
solid(sweep("galea_bowl", IRON, rows), 0.35)
# A raised brow ridge over the eyes (the front third) and a bronze band all round at the brow.
ridge = []
for e, g in ((0.02, 0.0), (0.1, 0.5), (0.2, 0.55), (0.28, 0.1)):
    ridge.append([bowl_point(a, e, g) for a in [(-0.95 + 1.9 * k / 16) for k in range(17)]])
sweep("galea_ridge", IRON, ridge, closed=False)
band = []
for e, g in ((-0.1, 0.25), (-0.08, 0.45), (0.0, 0.45), (0.02, 0.25)):
    band.append([bowl_point(2 * math.pi * k / segs, e, g) for k in range(segs)])
sweep("galea_band", BRONZE, band)
# Two ribs crossing over the crown, front to back and side to side.
for turn in (0.0, math.pi / 2):
    across = Vector((-math.sin(turn), math.cos(turn), 0.0))   # the rib's width runs this way
    rib = []
    for g, w in ((0.25, -0.12), (0.45, -0.12), (0.45, 0.12), (0.25, 0.12)):
        row = []
        for k in range(25):
            e = -1.45 + 2.9 * k / 24   # from the top: -1.45 one side of the bowl, over the crown, to the other
            row.append(C + Vector((math.cos(turn) * math.sin(e) * (R[0] + g), math.sin(turn) * math.sin(e) * (R[1] + g),
                                   math.cos(e) * (R[2] + g))) + across * w)
        rib.append(row)
    sweep("galea_rib%d" % int(turn * 10), BRONZE, rib, closed=False)
# The neck guard: a broad plate behind, flaring out and down from the bowl's back edge.
guard = []
for t, (drop, out) in enumerate(((0.0, 0.0), (0.6, 0.9), (1.2, 1.9), (1.6, 2.7))):
    row = []
    for k in range(17):
        a = math.pi + (-1.25 + 2.5 * k / 16)
        p = bowl_point(a, -0.06, 0.2)
        row.append(p + Vector((math.cos(a) * out, math.sin(a) * out * 0.8, -drop)))
    guard.append(row)
solid(sweep("galea_guard", IRON, guard, closed=False), 0.3)
# Cheek guards: shaped plates hinged at the band in front of the ears, curving round the cheek to a point.
for side in (1, -1):
    plate = []
    for t in range(6):
        f = t / 5.0
        z = C.z - 0.3 - 4.2 * f
        width = 2.6 * (1.0 - 0.55 * f)
        row = []
        for k in range(6):
            a = side * (0.95 + (k / 5.0 - 0.5) * width / 4.6) - side * 0.15 * f
            r = 4.95 - 0.5 * f
            row.append(Vector((C.x + math.cos(a) * r, math.sin(a) * r * 0.97, z)))
        plate.append(row)
    solid(sweep("galea_cheek%d" % side, IRON, plate, closed=False), 0.3)
    hinge = obj("galea_hinge%d" % side, BRONZE)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.35)
    bm.to_mesh(hinge.data)
    bm.free()
    hinge.location = bowl_point(side * 0.95, -0.02, 0.5)
# The crest holder on top: a bronze knob with a slot.
holder = obj("galea_holder", BRONZE)
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.7, radius2=0.45, depth=1.1)
bm.to_mesh(holder.data)
bm.free()
holder.location = C + Vector((0, 0, R[2] + 0.5))
finish(out_dir + "helm_galea.glb", smooth=("galea_bowl",))

# ------------------------------------------------------------------ the scutum
reset()
TEAM, BRONZE, WOOD = mat("team", (1, 0, 1)), mat("bronze", (0.72, 0.52, 0.26)), mat("wood", (0.45, 0.3, 0.18))
RC = 6.2                       # the curve's radius: the board wraps round the bearer
W, H = 9.0, 17.0               # across (along the curve), tall (9.6 met a spider's back gear: A3)
CORNER = 1.4


def curve(x, z, out=0.0):
    """A point on the board: x along the curve from the middle, z up; out = proud of the face (towards -Y)."""
    a = x / RC
    r = RC + out
    return Vector((math.sin(a) * r, RC - math.cos(a) * r, z))


def outline(i, n, half_w, half_h, corner):
    """Points round a rounded rectangle, i of n, as (x, z)."""
    t = i / n * 4.0
    side = int(t)
    f = t - side
    pts = [(-half_w, -half_h), (half_w, -half_h), (half_w, half_h), (-half_w, half_h)]
    a, b = pts[side % 4], pts[(side + 1) % 4]
    x, z = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
    x = max(-half_w + corner, min(half_w - corner, x)) if abs(z) > half_h - corner else x
    z = max(-half_h + corner, min(half_h - corner, z)) if abs(x) > half_w - corner else z
    cx, cz = max(-half_w + corner, min(half_w - corner, x)), max(-half_h + corner, min(half_h - corner, z))
    d = Vector((x - cx, z - cz))
    if d.length > 0.001:
        d = d.normalized() * corner
        x, z = cx + d.x, cz + d.y
    return x, z


def board(name, material, half_w, half_h, corner, out, thick, n=96):
    rows = []
    rim = [outline(i, n, half_w, half_h, corner) for i in range(n)]
    for f in (1.0, 0.66, 0.33, 0.0):
        rows.append([curve(x * f, z * f, out) for x, z in rim])
    ob = obj(name, material)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in row] for row in rows]
    for i in range(len(vs) - 1):
        for k in range(n):
            if i == len(vs) - 2:
                bm.faces.new((vs[i][k], vs[i][(k + 1) % n], vs[i + 1][0]))
            else:
                bm.faces.new((vs[i][k], vs[i][(k + 1) % n], vs[i + 1][(k + 1) % n], vs[i + 1][k]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bm.to_mesh(ob.data)
    bm.free()
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = thick
    return ob


board("scutum_board", WOOD, W * 0.5 + 0.25, H * 0.5 + 0.25, CORNER + 0.2, -0.05, 0.7)   # the board's edge shows round the face
board("scutum_face", TEAM, W * 0.5, H * 0.5, CORNER, 0.0, 0.12)
# The rim: a bronze binding round the edge.
rim = []
n = 96
pts = [outline(i, n, W * 0.5 + 0.3, H * 0.5 + 0.3, CORNER + 0.25) for i in range(n)]
inner = [outline(i, n, W * 0.5 - 0.15, H * 0.5 - 0.15, CORNER - 0.1) for i in range(n)]
rim.append([curve(x, z, -0.05) for x, z in pts])
rim.append([curve(x, z, -0.3) for x, z in pts])
rim.append([curve(x, z, -0.3) for x, z in inner])
rim.append([curve(x, z, -0.12) for x, z in inner])
sweep("scutum_rim", BRONZE, rim)
# The boss: a dome on a square flange in the middle, the spine running up and down from it.
flange = obj("scutum_flange", BRONZE)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(3.6, 0.2, 3.6), verts=bm.verts)
bm.to_mesh(flange.data)
bm.free()
flange.location = curve(0, 0, -0.18)
boss = obj("scutum_boss", BRONZE)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=1.0)
for v in bm.verts:
    v.co = Vector((v.co.x * 1.45, min(v.co.y, 0.0) * 1.1, v.co.z * 1.45))
bm.to_mesh(boss.data)
bm.free()
boss.location = curve(0, 0, -0.25)
for s in (1, -1):
    sp = obj("scutum_spine%d" % s, BRONZE)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.55, 0.25, H * 0.5 - 3.0), verts=bm.verts)
    bm.to_mesh(sp.data)
    bm.free()
    sp.location = curve(0, s * (H * 0.25 + 0.6), -0.2)
# Wings either side of the boss and lightning bolts above and below: low bronze slabs on the face.
def slab(name, pts2d, out):
    ob = obj(name, BRONZE)
    bm = bmesh.new()
    vs = [bm.verts.new(curve(x, z, out)) for x, z in pts2d]
    bm.faces.new(vs)
    bm.to_mesh(ob.data)
    bm.free()
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = 0.12
    return ob


for s in (1, -1):
    wing = [(s * 2.2, 0.4), (s * 3.4, 1.6), (s * 4.1, 2.6), (s * 3.9, 1.5), (s * 3.3, 0.6), (s * 3.9, 0.3), (s * 3.3, -0.3), (s * 2.2, -0.4)]
    slab("scutum_wing%d" % s, wing, -0.14)
    for up in (1, -1):
        bolt = [(s * 0.7, up * 2.6), (s * 2.2, up * 4.6), (s * 1.5, up * 4.8), (s * 2.8, up * 6.6), (s * 1.0, up * 4.9), (s * 1.6, up * 4.7), (s * 0.4, up * 2.8)]
        slab("scutum_bolt%d%d" % (s, up), bolt, -0.14)
finish(out_dir + "shield_scutum.glb", smooth=())
