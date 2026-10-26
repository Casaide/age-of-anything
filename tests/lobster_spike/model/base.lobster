// ------------------------------------------------------------------ the part builders' helpers (unit_models.gd: materials, shapes)
// What every part builder uses, named and shaped as in unit_models.gd so a part's code ports line by
// line: surf/plain/glow/decal for materials, blob/rod/ring/cone/dome/disc/slab/blade for shapes. A
// built part is a Spec (unit_models.gd's spec dictionary: the model, its front layer, sockets, anchors).

// ---- colours (Godot's Color: sRGB floats)

def html(h:string) -> float3:       // Color("#rrggbb")
    let s = if h.length and h[0] == '#': h.substring(1, h.length - 1) else: h
    def byte(i:int) -> float:
        let v, _ok = string_to_int(s.substring(i, 2), 16)
        return float(v) / 255.0
    return float3 { byte(0), byte(2), byte(4) }

def lerp3(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t   // Vector3.lerp, Color.lerp
def darkened(c:float3, a:float) -> float3: return c * (1.0 - a)
def lightened(c:float3, a:float) -> float3: return c + (float3_1 - c) * a

// Color.h, .s, .v (h in 0..1) and Color.from_hsv.
def hsv(c:float3) -> float, float, float:
    let mx = max(c.x, max(c.y, c.z))
    let mn = min(c.x, min(c.y, c.z))
    let d = mx - mn
    var h = 0.0
    if d > 0.0:
        if c.x == mx: h = (c.y - c.z) / d
        elif c.y == mx: h = 2.0 + (c.z - c.x) / d
        else: h = 4.0 + (c.x - c.y) / d
        h /= 6.0
        if h < 0.0: h += 1.0
    return h, (if mx == 0.0: 0.0 else: d / mx), mx

def from_hsv(h:float, s:float, v:float) -> float3:
    if s == 0.0: return float3 { v, v, v }
    let hh = (h * 6.0) % 6.0
    let i = int(floor(hh))
    let f = hh - float(i)
    let p = v * (1.0 - s)
    let q = v * (1.0 - s * f)
    let t = v * (1.0 - s * (1.0 - f))
    return [float3 { v, t, p }, float3 { q, v, p }, float3 { p, v, t }, float3 { p, q, v }, float3 { t, p, v }, float3 { v, p, q }][i % 6]

// A race colour by channel (skin, skin2, cloth, team...; the team is the team key while baking).
def col(c:Colours, ch:string) -> float3:
    if ch == "team": return c.team
    let h = c.hex.get(ch)
    assert h
    return html(h)

def has_col(c:Colours, ch:string) -> bool: return ch == "team" or c.hex.get(ch) != nil

// ---- a built part

class Anchor:                        // a leg's hip: where, its phase (radians, as Godot's), its side, and what else
    pos:float3                       // the body says (unit_models.gd's anchor arrays: a spider's leg pair,
    phase:float                      // fan; booleans as 0 or 1)
    side:int
    more:[float]

def anchor(pos:float3, phase:float, side:int) -> Anchor: return Anchor { pos, phase, side, [] }
def anchor(pos:float3, phase:float, side:int, more:[float]) -> Anchor: return Anchor { pos, phase, side, more }

class Spec:
    node:MNode
    front:MNode? = nil               // drawn over the body's other parts (the near arm)
    sockets = dictionary<string, float3>(11)
    anchors = []::Anchor
    nums = dictionary<string, float3>(11)    // the spec's other numbers (torso_scale, gear_scale...; a Vector2 in x, y)
    strs = dictionary<string, string>(5)     // and words (carry: "harness")
    flags = []::string                       // its true flags (legs_under...)

def spec_of(n:MNode) -> Spec: return Spec { n }
def sock(s:Spec, k:string, v:float3) -> Spec:
    s.sockets.set(k, v)
    return s
def spec_num(s:Spec, k:string, v:float3) -> Spec:
    s.nums.set(k, v)
    return s
def spec_num(s:Spec, k:string, v:float) -> Spec: return spec_num(s, k, float3 { v, 0.0, 0.0 })
def spec_str(s:Spec, k:string, v:string) -> Spec:
    s.strs.set(k, v)
    return s
def spec_flag(s:Spec, k:string) -> Spec:
    s.flags.push(k)
    return s

// ---- materials

def surf(name:string, tint:float3, units:float) -> MMat:   // a tileable texture wrapped triplanar, tinted
    let m = MMat { tint }
    m.tex = name
    m.triplanar = true
    m.uv_scale = float3_1 / units
    return m

def plain(c:float3) -> MMat: return MMat { c }

def glow(c:float3) -> MMat:
    let m = plain(c)
    m.unshaded = true
    return m

// A decal: an authored picture with crisp alpha on a quad, facing `facing`.
def decal(name:string, w:float, h:float, pos:float3, facing:float3, lit:bool, up:float3, tint:float3) -> MNode:
    let m = MMat { tint }
    m.tex = name
    m.scissor = true
    m.two_sided = true
    m.unshaded = not lit
    let n = mesh_node(quad_mesh(float2 { w, h }), m)
    n.meta = name
    n.pos = pos
    let f = normalize(facing)
    let u = if abs(dot(f, up)) < 0.95: up else: float3 { 0.0, 0.0, -1.0 }
    set_basis(n, basis_looking_at(-f, u))   // a QuadMesh faces +z; point that along `facing`
    return n

def decal(name:string, w:float, h:float, pos:float3, facing:float3, lit:bool) -> MNode:
    return decal(name, w, h, pos, facing, lit, float3 { 0.0, 1.0, 0.0 }, float3_1)
def decal(name:string, w:float, h:float, pos:float3, facing:float3) -> MNode:
    return decal(name, w, h, pos, facing, true)

// ---- shapes

// The point on an ellipsoid's surface in direction `dir` from its centre, nudged out a little.
def on_surface(centre:float3, radii:float3, dir:float3, out:float) -> float3:
    let d = normalize(dir)
    let k = 1.0 / sqrt(pow(d.x / radii.x, 2.0) + pow(d.y / radii.y, 2.0) + pow(d.z / radii.z, 2.0))
    return centre + d * (k + out)
def on_surface(centre:float3, radii:float3, dir:float3) -> float3: return on_surface(centre, radii, dir, 0.25)

let unit_sphere = sphere_mesh(1.0, 2.0, 32, 16, false)

def blob(r:float3, m:MMat, pos:float3, rot:float3) -> MNode:
    let n = mesh_node(unit_sphere, m)
    n.scl = r
    n.rot = rot
    n.pos = pos
    return n
def blob(r:float3, m:MMat, pos:float3) -> MNode: return blob(r, m, pos, float3_0)

// A rod from a to b (radius r1 at a, r2 at b), with rounded ends.
def rod(a:float3, b:float3, r1:float, r2:float, m:MMat, caps:bool) -> MNode:
    let n = mnode()
    let mi = add_child(n, mesh_node(cylinder_mesh(r2, r1, magnitude(b - a), 14, 4, true, true), m))
    mi.pos = (a + b) * 0.5
    let d = normalize(b - a)
    set_basis(mi, if magnitude(d - float3 { 0.0, -1.0, 0.0 }) > 0.00001: arc(float3 { 0.0, 1.0, 0.0 }, d) else: axis_angle(float3 { 1.0, 0.0, 0.0 }, 180.0))
    if caps:
        add_child(n, blob(float3_1 * r1, m, a))
        add_child(n, blob(float3_1 * r2, m, b))
    return n
def rod(a:float3, b:float3, r1:float, r2:float, m:MMat) -> MNode: return rod(a, b, r1, r2, m, true)

def ring(inner:float, outer:float, m:MMat, pos:float3, rot:float3, scl:float3) -> MNode:
    let n = mesh_node(torus_mesh(inner, outer, 28, 10), m)
    n.pos = pos
    n.rot = rot
    n.scl = scl
    return n
def ring(inner:float, outer:float, m:MMat, pos:float3, rot:float3) -> MNode: return ring(inner, outer, m, pos, rot, float3_1)
def ring(inner:float, outer:float, m:MMat, pos:float3) -> MNode: return ring(inner, outer, m, pos, float3_0, float3_1)

def cone(r_top:float, r_bot:float, h:float, m:MMat, pos:float3, rot:float3, seg:int) -> MNode:
    let n = mesh_node(cylinder_mesh(r_top, r_bot, h, seg, 4, true, true), m)
    n.pos = pos
    n.rot = rot
    return n
def cone(r_top:float, r_bot:float, h:float, m:MMat, pos:float3, rot:float3) -> MNode: return cone(r_top, r_bot, h, m, pos, rot, 18)
def cone(r_top:float, r_bot:float, h:float, m:MMat, pos:float3) -> MNode: return cone(r_top, r_bot, h, m, pos, float3_0, 18)

let unit_dome = sphere_mesh(1.0, 1.0, 28, 10, true)

// The top half of an ellipsoid (helmets), its flat side at `pos`.
def dome(r:float3, m:MMat, pos:float3) -> MNode:
    let n = mesh_node(unit_dome, m)
    n.scl = r
    n.pos = pos
    return n

// A node at `pos` whose local +z points along `face`: shields are built flat in its xy plane.
def facing(n:MNode, pos:float3, face:float3) -> MNode:
    let h = mnode()
    h.pos = pos
    set_basis(h, basis_looking_at(-normalize(face), float3 { 0.0, 1.0, 0.0 }))
    add_child(n, h)
    return h

// A disc (flat cylinder) in a facing node's xy plane.
def disc(r:float, thick:float, m:MMat, z:float) -> MNode: return cone(r, r, thick, m, float3 { 0.0, 0.0, z }, float3 { 90.0, 0.0, 0.0 }, 28)

// A flat polygon (in xy) given a thickness: both faces and the sides.
def slab_mesh(pts:[float2], thick:float) -> MMesh:
    let m = new_mesh()
    let tris = triangulate(pts)
    let h = thick * 0.5
    for([1.0, -1.0]) face:
        var k = 0
        while k + 2 < tris.length:
            let order = if face > 0.0: [tris[k], tris[k + 1], tris[k + 2]] else: [tris[k], tris[k + 2], tris[k + 1]]
            for(order) i: add_vertex(m, float3 { pts[i].x, pts[i].y, h * face }, float3 { 0.0, 0.0, face }, float2_0)
            k += 3
    for(pts.length) i:
        let a = pts[i]
        let b = pts[(i + 1) % pts.length]
        let nrm = normalize(float3 { b.y - a.y, a.x - b.x, 0.0 })
        for([float3 { a.x, a.y, h }, float3 { b.x, b.y, h }, float3 { b.x, b.y, -h }, float3 { a.x, a.y, h }, float3 { b.x, b.y, -h }, float3 { a.x, a.y, -h }]) v:
            add_vertex(m, v, nrm, float2_0)
    m.idx = map(m.p.length) i: i
    return m

def slab(points:[float2], thick:float, m:MMat, pos:float3) -> MNode:
    m.two_sided = true
    let n = mesh_node(slab_mesh(points, thick), m)
    n.pos = pos
    return n
def slab(points:[float2], thick:float, m:MMat) -> MNode: return slab(points, thick, m, float3_0)

// A blade or head flat in the xy plane, set at `at` and turned to angle `ang` (degrees).
def blade(points:[float2], thick:float, m:MMat, at:float3, ang:float) -> MNode:
    let b = slab(points, thick, m)
    b.pos = at
    b.rot = float3 { 0.0, 0.0, ang }
    return b

// A horsehair crest along the helmet's ridge, tinted.
def crest(n:MNode, tint:float3, pos:float3, length:float, height:float):
    add_child(n, decal("plume", length, height, pos + float3 { 0.0, height * 0.5, 0.0 }, float3 { 0.0, 0.0, 1.0 }, true, float3 { 0.0, 1.0, 0.0 }, tint))

// The angle (degrees about z) that stands a ring or cone along a staff from a to b.
def tilt_of(a:float3, b:float3) -> float:
    let d = normalize(b - a)
    return atan2(float2 { d.x, d.y }) - 90.0

// Every child moved up by dy.
def lift_kids(n:MNode, dy:float):
    for(n.kids) k: k.pos += float3 { 0.0, dy, 0.0 }

// Scale a built part about its origin, with its sockets and anchors (front layer too).
def scaled(s:Spec, k:float) -> Spec:
    let w = mnode()
    w.scl = float3_1 * k
    add_child(w, s.node)
    s.node = w
    let f = s.front
    if f:
        let wf = mnode()
        wf.scl = float3_1 * k
        add_child(wf, f)
        s.front = wf
    for(s.sockets.get_keys()) name: s.sockets.set(name, s.sockets.get(name, float3_0) * k)
    for(s.anchors) a: a.pos *= k
    return s

// A team-colour kerchief knotted at the neck, with a tail hanging in front.
def kerchief(into:MNode, c:Colours, neck:float3, r:float, lean:float):
    let team = surf("cloth", col(c, "team"), 3.0)
    add_child(into, ring(r * 0.75, r * 1.3, team, neck, float3 { 0.0, 0.0, lean }, float3 { 1.0, 1.6, 1.0 }))
    let knot = neck + float3 { r * 0.95, -r * 0.2, r * 0.35 }
    add_child(into, blob(float3 { 1.1, 1.1, 1.0 } * r * 0.32, team, knot))
    add_child(into, slab([float2 { 0.0, 0.0 }, float2 { r * 0.45, -r * 0.2 }, float2 { r * 0.25, -r * 1.3 }, float2 { -r * 0.15, -r * 1.1 }], 0.5, team, knot + float3 { -r * 0.1, -r * 0.1, 0.3 }))

// ---- helpers the model files share (unit_models.gd: harness, _sword, curved, grip, tassel, _bright_iron,
// _box; creature_kit.gd: _ik)

// Bodies with no arms carry their gear on a harness: a girth strap, a holder on the near flank, a
// shield pad on the far one. `ry`, `rz`: the girth's radii (up and across) around `centre`.
def harness(n:MNode, centre:float3, ry:float, rz:float, hand_r:float3, hand_l:float3):
    let leather = surf("leather", float3_1, 3.0)
    let dark = surf("leather", float3 { 0.55, 0.42, 0.32 }, 2.0)
    add_child(n, ring(0.86, 1.0, leather, centre, float3 { 0.0, 0.0, 90.0 }, float3 { ry, 1.6, rz }))
    add_child(n, rod(hand_r + float3 { -1.6, -0.6, 0.6 }, hand_r + float3 { 1.6, 0.6, 0.6 }, 1.15, 1.15, dark))
    add_child(n, blob(float3 { 0.7, 0.7, 0.5 }, surf("bronze", float3_1, 2.0), hand_r + float3 { 0.0, 0.0, 1.6 }))
    add_child(n, blob(float3 { 2.2, 2.6, 0.8 }, dark, hand_l))

// A sword: the blade outline along `tip` from the grip at the origin, a cross guard, a wrapped grip, a pommel.
def sword(blade_pts:[float2], tip:float3, metal:MMat, fittings:MMat) -> MNode:
    let n = mnode()
    let d = normalize(tip)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(blade_pts, 0.6, metal, float3_0, ang))
    let across = float3 { -d.y, d.x, 0.0 }
    add_child(n, rod(-across * 3.0 + float3 { 0.0, 0.0, 0.6 }, across * 3.0 - float3 { 0.0, 0.0, 0.6 }, 0.55, 0.55, fittings))
    add_child(n, rod(float3_0, -d * 3.0, 0.6, 0.6, surf("leather", float3_1, 2.0), false))
    add_child(n, blob(float3 { 0.9, 0.9, 0.9 }, fittings, -d * 3.6))
    return n

def sample_ws(ws:[float], t:float) -> float:
    let f = t * float(ws.length - 1)
    let i = min(int(f), ws.length - 2)
    return ws[i] + (ws[i + 1] - ws[i]) * (f - float(i))

// A blade outline bent along a curve: `length` along +x, the centre rising `sag` at the tip, half-widths
// sampled from `widths`; `edge` 1 keeps the spine on the centre line (single-edged).
def curved(length:float, sag:float, widths:[float], edge:float = 0.0, steps:int = 14) -> [float2]:
    let top = []::float2
    let low = []::float2
    for(steps + 1) i:
        let t = float(i) / float(steps)
        let w = sample_ws(widths, t)
        let cy = sag * t * t
        let x = length * t
        top.push(float2 { x, cy + w * (1.0 - edge) })
        low.push(float2 { x, cy - w * (1.0 + edge) })
    let bottom = map(low.length) i: low[low.length - 1 - i]
    if magnitude(top[top.length - 1] - bottom[0]) < 0.05: bottom.remove(0)
    return append(top, bottom)

// The grip end the age-3 weapons share: a wrapped grip down the line from the hand and a pommel.
def grip(n:MNode, d:float3, wrap:MMat, pommel:MMat, length:float = 3.0):
    add_child(n, rod(float3_0, -d * length, 0.6, 0.6, wrap, false))
    add_child(n, blob(float3 { 0.95, 0.95, 0.95 }, pommel, -d * (length + 0.6)))

// A tassel hanging from the pommel.
def tassel(n:MNode, d:float3, m:MMat, length:float = 3.0):
    let at = -d * 3.8
    add_child(n, rod(at, at + float3 { -1.2, -length, 0.4 }, 0.45, 0.8, m))
    add_child(n, blob(float3 { 0.7, 1.2, 0.7 }, m, at + float3 { -1.3, -length - 0.6, 0.4 }))

// Polished steel: the iron texture over a pale tint (beyond one: brighter than the texture).
def bright_iron(units:float = 3.0) -> MMat: return surf("iron", float3 { 2.2, 2.25, 2.4 }, units)

def box(size:float3, m:MMat, pos:float3, rot:float3 = float3_0) -> MNode:
    let n = mesh_node(box_mesh(size, 0, 0, 0), m)
    n.pos = pos
    n.rot = rot
    return n

// Two-bone IK in a plane: the middle joint for bones l1, l2 from a to b, bending to `side`.
def ik(a:float2, b:float2, l1:float, l2:float, side:float) -> float2:
    let d = b - a
    let l = clamp(magnitude(d), 0.01, l1 + l2 - 0.01)
    let u = normalize(d)
    let along = (l1 * l1 - l2 * l2 + l * l) / (2.0 * l)
    let hh = sqrt(max(0.0, l1 * l1 - along * along))
    return a + u * along + float2 { -u.y, u.x } * hh * side
