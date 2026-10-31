"""Shared helpers for the beasts sculpted by script (elephant.py, centaur.py; round BA1, 2026-10-30).

Everything is written in the game's part units and axes (x forward, y up, z towards the near side) and turned into
Blender's (x forward, z up, the near side -y) as each vertex is set; glTF turns that back into the game's axes.
- loft: one closed surface from a sphere, laid along x between a top line, a bottom line and a half-width that may
  narrow towards the top (a barrel, a skull); `shape` moves each point after (bulges, hollows).
- limb: a tube along a smooth path (Catmull-Rom through the points), its radius eased between the points' radii,
  rounded caps at both ends; `disp` scales the radius at each point (wrinkles, a knee's front).
"""
import math, sys
sys.dont_write_bytecode = True
import bpy, bmesh
from mathutils import Vector


def G(q):
    return Vector((q.x, -q.z, q.y))


def V(x, y, z=0.0):
    return Vector((x, y, z))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


def obj(name, materials):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for m in materials:
        me.materials.append(m)
    return ob


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
    """1 at c falling to 0 at the ellipsoid of radii r about it (a smooth hump to push a surface by)."""
    d = ((p.x - c.x) / r[0]) ** 2 + ((p.y - c.y) / r[1]) ** 2 + ((p.z - c.z) / r[2]) ** 2
    return max(0.0, 1.0 - d) ** 2


def blockish(p, n):
    s = (abs(p.x) ** n + abs(p.y) ** n + abs(p.z) ** n) ** (1.0 / n)
    return p / s


class Loft:
    def __init__(self, x0, x1, top, bot, half_lo, half_hi):
        self.x0, self.x1, self.top, self.bot, self.half_lo, self.half_hi = x0, x1, top, bot, half_lo, half_hi

    def at(self, x, u, side):
        """The surface point at x, height u (0 under, 1 on top) and side (-1 far .. 1 near; 0 the middle line)."""
        y = lerp(curve(self.bot, x), curve(self.top, x), u)
        return V(x, y, side * lerp(curve(self.half_lo, x), curve(self.half_hi, x), u))


def loft(name, materials, lf, shape=None, n=2.4, segs=72, rings=44, mat_of=None):
    ob = obj(name, materials)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        p = blockish(Vector((v.co.z, v.co.y, v.co.x)), n)   # along, up, across
        x = lerp(lf.x0, lf.x1, (p.x + 1) / 2)
        u = (p.y + 1) / 2
        q = lf.at(x, u, p.z)
        if shape:
            q = shape(q, x, u, p.z)
        v.co = G(q)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)   # (the sphere with its axes swapped is inside out)
    if mat_of:
        for f in bm.faces:
            c = f.calc_center_median()
            f.material_index = mat_of(Vector((c.x, c.z, -c.y)))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def catmull(pts, t):
    """A point on the Catmull-Rom curve through pts, t in [0, len - 1]."""
    i = min(int(t), len(pts) - 2)
    f = t - i
    p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)


def limb(name, materials, pts, radii, segs=22, steps=10, squash=(1.0, 1.0), disp=None, cap=(1.0, 1.0), mat_of=None):
    """A tube through pts (game Vectors) with radii; squash scales its section (sideways, the other way); disp(s, a)
    scales the radius at s (0..1 along) and angle a; cap scales how far each rounded end reaches past its point."""
    ob = obj(name, materials)
    bm = bmesh.new()
    n = (len(pts) - 1) * steps
    centres = [catmull(pts, i / steps) for i in range(n + 1)]
    rs = [curve([(k, r) for k, r in enumerate(radii)], i / steps) for i in range(n + 1)]
    ref = V(0, 0, 1)
    rings, frames = [], []
    for i, c in enumerate(centres):
        d = (centres[min(i + 1, n)] - centres[max(i - 1, 0)]).normalized()
        if abs(d.dot(ref)) > 0.95:
            ref = V(1, 0, 0)
        u = (ref - d * d.dot(ref)).normalized()   # sideways (towards the near side, as near as it can)
        w = d.cross(u)
        ref = u
        frames.append((d, u, w))

    def ring(c, r, f, s):
        d, u, w = f
        out = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            m = disp(s, a) if disp else 1.0
            out.append(bm.verts.new(G(c + (u * math.cos(a) * squash[0] + w * math.sin(a) * squash[1]) * r * m)))
        return out

    caps = 4
    for j in range(caps, 0, -1):   # the first end's rounded cap
        th = math.pi / 2 * j / (caps + 1)
        rings.append(ring(centres[0] - frames[0][0] * rs[0] * cap[0] * math.sin(th), rs[0] * math.cos(th), frames[0], 0.0))
    for i, c in enumerate(centres):
        rings.append(ring(c, rs[i], frames[i], i / n))
    for j in range(1, caps + 1):
        th = math.pi / 2 * j / (caps + 1)
        rings.append(ring(centres[n] + frames[n][0] * rs[n] * cap[1] * math.sin(th), rs[n] * math.cos(th), frames[n], 1.0))
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    for end, tip in ((rings[0], centres[0] - frames[0][0] * rs[0] * cap[0]), (rings[-1], centres[n] + frames[n][0] * rs[n] * cap[1])):
        pole = bm.verts.new(G(tip))
        for k in range(segs):
            a, b = end[k], end[(k + 1) % segs]
            bm.faces.new((b, a, pole) if end is rings[0] else (a, b, pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if mat_of:
        for f in bm.faces:
            c = f.calc_center_median()
            f.material_index = mat_of(Vector((c.x, c.z, -c.y)))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def ball(name, materials, centre, radii, segs=18, rot=(0.0, 0.0, 0.0)):
    """An ellipsoid at a game point, turned by rot (degrees about the game's x, y, z)."""
    ob = obj(name, materials)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 2, radius=1.0)
    from mathutils import Euler
    e = Euler((math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ")
    for v in bm.verts:
        q = V(v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])
        q.rotate(e)
        v.co = G(q + centre)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def finish(path, smooth=(), scale=1.0):
    for ob in bpy.data.objects:
        if scale != 1.0:
            for v in ob.data.vertices:
                v.co *= scale
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if ob.name in smooth:
            mod = ob.modifiers.new("smooth", "SUBSURF")
            mod.levels = 1
            mod.render_levels = 1
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("wrote", path)
