// A body traced from drawings: each view scaled to the published dimensions, a voxel kept only if it's inside the side, top and
// front outlines. `carve -- <spec> build` writes the body, `carve -- <spec> check <dir>` measures it against the outlines and draws
// the overlays. tools/trace/refs.sh fetches the drawings; a spec (mods/ww2/trace/) says what to read from them.
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.voxel

class mask:
    w:int
    h:int
    on:[bool]

def in_mask(m:mask, x:int, y:int) -> bool: return x >= 0 and y >= 0 and x < m.w and y < m.h and m.on[y * m.w + x]

def read_pbm(path:string) -> mask:
    let s = assert read_file(path)
    var i = 2
    def number() -> int:
        while s[i] <= 32: i++
        var n = 0
        while s[i] > 32:
            n = n * 10 + s[i] - 48
            i++
        return n
    let w = number()
    let h = number()
    let on = []::bool
    while i < s.length:
        if s[i] > 32: on.push(s[i] == 49)
        i++
    assert on.length == w * h
    return mask { w, h, on }

// What's inside the outline: all but the white the outside can reach, where lines under 5 px wide (the drawing's inner lines, where
// they leak) don't let it through.
def silhouette(m:mask) -> mask:
    let n = m.w * m.h
    let free = map(n) i:
        let x, y = i % m.w, i / m.w
        var clear = true
        for(5) b: for(5) a:
            if in_mask(m, x + a - 2, y + b - 2): clear = false
        clear
    let out = map(n): false
    let todo = []::int
    for(m.w) x:
        todo.push(x)
        todo.push((m.h - 1) * m.w + x)
    for(m.h) y:
        todo.push(y * m.w)
        todo.push(y * m.w + m.w - 1)
    while todo.length:
        let i = todo.pop()
        if free[i] and not out[i]:
            out[i] = true
            let x, y = i % m.w, i / m.w
            if x > 0: todo.push(i - 1)
            if x < m.w - 1: todo.push(i + 1)
            if y > 0: todo.push(i - m.w)
            if y < m.h - 1: todo.push(i + m.w)
    let on = map(n) i:
        let x, y = i % m.w, i / m.w
        var outside = false
        for(5) b: for(5) a:
            let q = x + a - 2
            let r = y + b - 2
            if q >= 0 and r >= 0 and q < m.w and r < m.h and out[r * m.w + q]: outside = true
        not (outside and not m.on[i])
    return mask { m.w, m.h, on }

def inside(p:[float2], x:float, y:float) -> bool:
    var c = false
    for(p) a, i:
        let b = p[(i + 1) % p.length]
        if (a.y > y) != (b.y > y) and x < a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y): c = not c
    return c

def poly(v:JV) -> [float2]: return map(v.a) q: float2 { as_float(q.a[0]), as_float(q.a[1]) }

def erased(m:mask, polys:[[float2]]) -> mask:
    let kept = map(m.on) on, i:
        var keep = on
        if on:
            for(polys) p:
                if inside(p, float(i % m.w) + 0.5, float(i / m.w) + 0.5): keep = false
        keep
    return mask { m.w, m.h, kept }

let spec_path = command_line_arguments()[0]
let mode = command_line_arguments()[1]
let spec = load_json(spec_path)
let views = at(spec, "views")
let vs = at(views, "side")
let vt = at(views, "top")
let vf = at(views, "front")
let k = as_float(at(spec, "voxels_per_inch"))
let side_len = as_float(at(vs, "len"))
let side_ih = side_len / (as_float(at(vs, "h1")) - as_float(at(vs, "h0")))
let side_iv = as_float(at(vs, "high")) / (as_float(at(vs, "ground")) - as_float(at(vs, "top")))
let top_ih = as_float(at(vt, "len")) / (as_float(at(vt, "h1")) - as_float(at(vt, "h0")))
let top_iv = as_float(at(vt, "wide")) / (as_float(at(vt, "v1")) - as_float(at(vt, "v0")))
let top_mid = (as_float(at(vt, "v0")) + as_float(at(vt, "v1"))) / 2.0
let front_ih = as_float(at(vf, "wide")) / (as_float(at(vf, "h1")) - as_float(at(vf, "h0")))
let front_mid = (as_float(at(vf, "h0")) + as_float(at(vf, "h1"))) / 2.0
let front_iv = as_float(at(vf, "high")) / (as_float(at(vf, "ground")) - as_float(at(vf, "top")))

// tank inches (x right, y forward, z up, y 0 the middle of its length) and the drawings' pixels
def side_h(y:float) -> float: return (y + side_len / 2.0) / side_ih + as_float(at(vs, "h0"))
def side_v(z:float) -> float: return as_float(at(vs, "ground")) - z / side_iv
def top_h(y:float) -> float: return (y + side_len / 2.0) / top_ih + as_float(at(vt, "h0"))
def top_v(x:float) -> float: return top_mid + x / top_iv
def front_h(x:float) -> float: return front_mid - x / front_ih  // (seen from in front: its right is on the left)
def front_v(z:float) -> float: return as_float(at(vf, "ground")) - z / front_iv
def y_of_side(h:float) -> float: return (h - as_float(at(vs, "h0"))) * side_ih - side_len / 2.0
def z_of_side(v:float) -> float: return (as_float(at(vs, "ground")) - v) * side_iv
def y_of_top(h:float) -> float: return (h - as_float(at(vt, "h0"))) * top_ih - side_len / 2.0
def x_of_top(v:float) -> float: return (v - top_mid) * top_iv

// A view's outline: what the drawing fills, or, for a line drawing crossed by dimension lines, polygons traced over it.
def outline_of(v:JV) -> mask:
    let drawn = read_pbm(as_str(at(v, "file")))
    if not has(v, "outline"): return silhouette(drawn)
    let ps = map(glist(v, "outline")) p: poly(p)
    let on = map(drawn.w * drawn.h) i:
        var hit = false
        for(ps) p:
            if inside(p, float(i % drawn.w) + 0.5, float(i / drawn.w) + 0.5): hit = true
        hit
    return mask { drawn.w, drawn.h, on }

let raw_side = outline_of(vs)
let raw_top = outline_of(vt)
let raw_front = outline_of(vf)
let er = at(spec, "erase")
let m_side = erased(raw_side, map(glist(er, "side")) p: poly(p))
let m_top = erased(raw_top, map(glist(er, "top")) p: poly(p))
let m_front = erased(raw_front, map(glist(er, "front")) p: poly(p))
// A flier has no turret or running gear: all of it is one volume, its points set at its flying height (`flies`).
let flies = gfloat(spec, "flies", 0.0)
let flier = flies > 0.0
let lift_in = flies * 2.0 / k  // inches
let turret_top = if flier: []::float2 else: poly(at(spec, "turret_top"))
let lower_keep = if flier: []::float2 else: poly(at(spec, "lower_keep"))
let sponson = if flier: []::float2 else: poly(at(spec, "sponson"))
let lower_half = if flier: 0.0 else: as_float(at(spec, "lower_half_width"))
let seat = if flier: -1.0 else: as_float(at(spec, "seat"))

// Sloped plates as lines on the side view: h0, v0, h1, v1.
let plates = map(glist(spec, "plates")) q: float4 { as_float(q.a[0]), as_float(q.a[1]), as_float(q.a[2]), as_float(q.a[3]) }

// Where along the tank (top view h) a stretch of the front outline doesn't apply.
class exclude:
    h0:float
    h1:float
    front:[float2]

let excludes = map(glist(spec, "exclude")) e: exclude { as_float(at(e, "h").a[0]), as_float(at(e, "h").a[1]), poly(at(e, "front")) }

def sponson_at(h:float) -> float:
    for(sponson.length - 1) i:
        let a, b = sponson[i], sponson[i + 1]
        if h >= a.x and h <= b.x: return a.y + (b.y - a.y) * (h - a.x) / (b.x - a.x)
    return if h < sponson[0].x: sponson[0].y else: sponson[sponson.length - 1].y

def in_views(x:float, y:float, z:float) -> bool:
    return in_mask(m_side, int(side_h(y)), int(side_v(z))) and in_mask(m_top, int(top_h(y)), int(top_v(x))) and in_mask(m_front, int(front_h(x)), int(front_v(z)))

def carved_hull(x:float, y:float, z:float) -> bool:
    let v = side_v(z)
    if v < seat or not in_views(x, y, z): return false
    let h = side_h(y)
    for(excludes) e:  // (three outlines can't tell a wing from a tailplane at the same width: a ghost of each at the other's height)
        let th = top_h(y)
        if th >= e.h0 and th <= e.h1 and inside(e.front, front_h(x), front_v(z)): return false
    for(plates) p:  // (a sloped plate is its own flat box: no voxel steps above it)
        if h >= p.x and h <= p.z and v < p.y + (p.w - p.y) * (h - p.x) / (p.z - p.x): return false
    if flier: return true
    if v > sponson_at(h):  // under the sponsons: the lower hull between the tracks, the tracks are running gear
        return abs(x) <= lower_half and inside(lower_keep, h, v)
    return true

def carved_turret(x:float, y:float, z:float) -> bool:
    if side_v(z) >= seat or not in_views(x, y, z): return false
    return inside(turret_top, top_h(y), top_v(x))

let nx = int(as_float(at(vt, "wide")) * k / 2.0) + 2
let ny = int(side_len * k / 2.0) + 2
let nz = int(as_float(at(vs, "high")) * k) + 2

def jnum(f:float) -> JV:
    let v = JV { J_FLOAT }
    v.f = float(int(f * 1000.0 + (if f < 0.0: -0.5 else: 0.5))) / 1000.0
    return v

def row_full(g:[bool], w:int, d:int, x:int, x1:int, y:int, z:int) -> bool:
    for(x1 - x + 1) a:
        if not g[(z * d + y) * w + x + a]: return false
    return true

def plane_full(g:[bool], w:int, d:int, x:int, x1:int, y:int, y1:int, z:int) -> bool:
    for(y1 - y + 1) b:
        if not row_full(g, w, d, x, x1, y + b, z): return false
    return true

// A volume as boxes: runs along x, grown along y, then up.
def boxes_of(carved) -> [JV]:
    let w, d = nx * 2, ny * 2
    let g = map(w * d * nz) i:
        let x, y, z = i % w, (i / w) % d, i / (w * d)
        carved((float(x - nx) + 0.5) / k, (float(y - ny) + 0.5) / k, (float(z) + 0.5) / k)
    let boxes = []::JV
    for(nz) z: for(d) y: for(w) x:
        if g[(z * d + y) * w + x]:
            var x1 = x
            while x1 + 1 < w and g[(z * d + y) * w + x1 + 1]: x1++
            var y1 = y
            while y1 + 1 < d and row_full(g, w, d, x, x1, y1 + 1, z): y1++
            var z1 = z
            while z1 + 1 < nz and plane_full(g, w, d, x, x1, y, y1, z1 + 1): z1++
            for(z1 - z + 1) c: for(y1 - y + 1) b: for(x1 - x + 1) a:
                g[((z + c) * d + y + b) * w + x + a] = false
            // (a hard shape reaches half a voxel past its edge: the outermost voxels' centres on the box's face)
            let o = jobj()
            let u = 0.5  // body units a voxel
            o.set("box", jarr([ jstr("o"), jnum(u * float(x + x1 + 1 - w) / 2.0), jnum(u * float(y + y1 + 1 - d) / 2.0), jnum(u * float(z + z1 + 1) / 2.0 + flies) ]))
            o.set("n", jarr([ jint(0), jint(1), jint(0) ]))
            o.set("half", jarr([ jnum(u * (float(x1 - x) / 2.0 + 0.04)), jnum(u * (float(y1 - y) / 2.0 + 0.04)), jnum(u * (float(z1 - z) / 2.0 + 0.04)) ]))
            o.set("mat", at(spec, "paint"))
            o.set("round", jint(0))
            boxes.push(o)
    return boxes

def units(inches:float) -> float: return inches * k / 2.0

def point_units(p:[JV]) -> float3:
    if as_str(p[0]) == "t":
        return float3 { x_of_top(as_float(p[1])), y_of_top(as_float(p[2])), z_of_side(as_float(p[3])) + lift_in } * k / 2.0
    return float3 { as_float(p[1]), y_of_side(as_float(p[2])), z_of_side(as_float(p[3])) + lift_in } * k / 2.0

def jpoint(p:[JV]) -> JV:
    let v = point_units(p)
    return jarr([ jstr("o"), jnum(v.x), jnum(v.y), jnum(v.z) ])

// A detail's traced points and inches into the body's units.
def detail(d:JV) -> JV:
    let o = deep_copy(d)
    for([ "cap", "to", "ball", "bead", "disc", "box" ]) key:
        if has(o, key): o.set(key, jpoint(at(o, key).a))
    if has(o, "r"):
        let r = at(o, "r")
        o.set("r", if r.kind == J_ARR: jarr(map(r.a) q: jnum(units(as_float(q)))) else: jnum(units(as_float(r))))
    if has(o, "half"): o.set("half", jarr(map(at(o, "half").a) q: jnum(units(as_float(q)))))
    if has(o, "round"): o.set("round", jnum(units(as_float(at(o, "round")))))
    return o

def wheel(w:JV) -> JV:
    let o = deep_copy(w)
    let a = at(w, "at").a
    let v = point_units([ jstr("o"), a[0], a[1], a[2] ])
    o.set("at", jarr([ jnum(v.x), jnum(v.y), jnum(v.z) ]))
    for([ "r", "thick", "face_r", "hub_r" ]) key:
        if has(o, key): o.set(key, jnum(units(as_float(at(o, key)))))
    return o

// A sloped plate as a flat box under its line, its top the plate: so light falls on one face, with no terraces.
def plate_box(p:float4) -> JV:
    let t = as_float(at(spec, "plate_half_inches"))
    let y0, z0 = y_of_side(p.x), z_of_side(p.y)
    let y1, z1 = y_of_side(p.z), z_of_side(p.w)
    let len = magnitude(float2 { y1 - y0, z1 - z0 })
    var ay, az = (z0 - z1) / len, (y1 - y0) / len
    if az < 0.0:
        ay = -ay
        az = -az
    let cy, cz = (y0 + y1) / 2.0 - ay * t, (z0 + z1) / 2.0 - az * t
    let o = jobj()
    o.set("box", jarr([ jstr("o"), jint(0), jnum(units(cy)), jnum(units(cz)) ]))
    o.set("n", jarr([ jint(0), jnum(ay), jnum(az) ]))
    o.set("half", jarr([ jnum(units(as_float(at(vt, "wide")) / 2.0 - 1.0)), jnum(units(t)), jnum(units(len / 2.0)) ]))
    o.set("mat", at(spec, "paint"))
    o.set("round", jint(0))
    return o

def build_flier():
    let c = at(spec, "colours")
    let hull = boxes_of(fn x, y, z: carved_hull(x, y, z))
    for(plates) p: hull.push(plate_box(p))
    for(glist(spec, "hull_details")) d: hull.push(detail(d))
    let mz = point_units(at(spec, "muzzle").a)
    let points = parse_json("\{\"o\":\{\"at\":[0,0,0]\},\"muzzle\":\{\"at\":[{mz.x},{mz.y},{mz.z}]\}\}")
    let look = jobj()
    for([ "skin", "pale", "mark" ]) key: look.set(key, at(c, key))
    let style = jobj()
    style.set(as_str(at(c, "style")), look)
    def lines(key:string, vals:[JV]) -> string:
        return "\"" + key + "\": [\n  " + concat_string(map(vals) v: stringify(v), ",\n  ") + "\n ]"
    let wh = map(glist(spec, "wheels")) w:
        let o = deep_copy(w)
        let a = at(w, "at").a
        let v = point_units([ jstr("o"), a[0], a[1], a[2] ])
        o.set("at", jarr([ jnum(v.x), jnum(v.y), jnum(v.z) ]))
        o.set("r", jnum(units(as_float(at(w, "r")))))
        o.set("thick", jnum(units(as_float(at(w, "thick")))))
        o
    let text = "\{\n \"_doc\": " + stringify(jstr("Traced from drawings by src/carve.lobster and " + spec_path + "; do not edit by hand: " + as_str(at(spec, "_doc")))) +
        ",\n \"skin\": " + stringify(at(c, "skin")) + ",\n \"pale\": " + stringify(at(c, "pale")) + ",\n \"mark\": " + stringify(at(c, "mark")) +
        ",\n \"fur\": 0.0,\n \"size\": 1.0,\n \"flies\": {flies},\n \"crew\": [],\n \"death\": \"crash\",\n \"points\": " + stringify(points) +
        ",\n \"styles\": " + stringify(style) + ",\n " + lines("wheels", wh) + ",\n " + lines("shapes", hull) + "\n\}\n"
    assert write_file(as_str(at(spec, "out")), text)
    print "{hull.length} boxes"

def build():
    let c = at(spec, "colours")
    let tr = deep_copy(at(spec, "tracks"))
    for([ "x", "half", "pitch", "thick", "bar" ]) key: tr.set(key, jnum(units(as_float(at(tr, key)))))
    let circles = map(glist(tr, "round")) q:
        let v = point_units([ jstr("o"), jint(0), q.a[0], q.a[1] ])
        jarr([ jnum(v.y), jnum(v.z), jnum(units(as_float(q.a[2]))) ])
    tr.set("round", jarr(circles))
    let hull = boxes_of(fn x, y, z: carved_hull(x, y, z))
    let turret = boxes_of(fn x, y, z: carved_turret(x, y, z))
    for(plates) p: hull.push(plate_box(p))
    for(glist(spec, "hull_details")) d: hull.push(detail(d))
    for(glist(spec, "turret_details")) d: turret.push(detail(d))
    let pv = point_units(at(spec, "pivot").a)
    let mz = point_units(at(spec, "muzzle").a)
    let part = jobj()
    part.set("name", jstr("turret"))
    part.set("pivot", jarr([ jnum(pv.x), jnum(pv.y), jnum(pv.z) ]))
    let pts = jobj()
    pts.set("muzzle", jarr([ jnum(mz.x), jnum(mz.y), jnum(mz.z) ]))
    part.set("points", pts)
    let origin = jobj()
    origin.set("at", jarr([ jint(0), jint(0), jint(0) ]))
    let points = jobj()
    points.set("o", origin)
    let style = jobj()
    let look = jobj()
    for([ "skin", "pale", "mark" ]) key:
        look.set(key, at(c, key))
    style.set(as_str(at(c, "style")), look)
    def lines(key:string, vals:[JV]) -> string:
        return "\"" + key + "\": [\n  " + concat_string(map(vals) v: stringify(v), ",\n  ") + "\n ]"
    let parts = stringify(part)
    let head = substring(parts, 0, parts.length - 1)
    let text = "\{\n \"_doc\": " + stringify(jstr("Traced from drawings by src/carve.lobster and " + spec_path + "; do not edit by hand: " + as_str(at(spec, "_doc")))) +
        ",\n \"skin\": " + stringify(at(c, "skin")) + ",\n \"pale\": " + stringify(at(c, "pale")) + ",\n \"mark\": " + stringify(at(c, "mark")) +
        ",\n \"fur\": 0.0,\n \"size\": 1.0,\n \"crew\": [],\n \"death\": \"knocked_out\",\n \"points\": " + stringify(points) +
        ",\n \"styles\": " + stringify(style) + ",\n \"tracks\": " + stringify(tr) + ",\n " + lines("wheels", map(glist(spec, "wheels")) w: wheel(w)) +
        ",\n " + lines("shapes", hull) + ",\n \"parts\": [ " + head + ", " + lines("shapes", turret) + " \} ]\n\}\n"
    assert write_file(as_str(at(spec, "out")), text)
    print "{hull.length} hull boxes, {turret.length} turret boxes"

if mode == "build":
    if flier: build_flier()
    else: build()

// ---- the check: the voxels as they fill, each view's silhouette against the drawing's

class proj:
    w:int  // columns (a voxel across)
    h:int
    x0:int
    y0:int
    on:[bool]

def proj_on(p:proj, a:int, b:int) -> bool:
    let i, j = a - p.x0, b - p.y0
    return i >= 0 and j >= 0 and i < p.w and j < p.h and p.on[j * p.w + i]

def overlay(path:string, line:mask, sil:mask, inch_of_a, inch_of_b, p:proj):
    let bytes = []::int
    for(line.h) y: for(line.w) x:
        let a = int(floor(inch_of_a(float(x) + 0.5) * k))
        let b = int(floor(inch_of_b(float(y) + 0.5) * k))
        let v = proj_on(p, a, b)
        let d = in_mask(sil, x, y)
        var c = if v and d: int3 { 150, 150, 150 } elif v: int3 { 225, 40, 40 } elif d: int3 { 40, 90, 225 } else: int3 { 255, 255, 255 }
        if in_mask(line, x, y): c = c * 2 / 5
        bytes.push(c.x)
        bytes.push(c.y)
        bytes.push(c.z)
    assert write_file(path, "P6\n{line.w} {line.h}\n255\n" + vector_to_buffer(bytes, 1), 0, 1)

def ring_f(f:float) -> string:
    let t = int(abs(f) * 10.0 + 0.5)
    return (if f < 0.0: "-" else: "") + "{t / 10}.{t % 10}"

def extent(on_at, n:int) -> int, int:
    var lo, hi = 1000000, -1000000
    for(n) i:
        if on_at(i):
            lo = min(lo, i)
            hi = max(hi, i)
    return lo, hi

def check(dir:string):
    vx_load([ "../data/voxel", "../mods/ww2/data/voxel" ])
    let id = as_str(at(spec, "body"))
    let u = vx_unit_def { id, id, float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0, nil }
    vx_set_look(u, 0)
    vx_act = ""
    vx_stand = true
    let shape = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_on_zero(u, false))
    var lo = int3 { 100000, 100000, 100000 }
    var hi = lo * -1
    for(shape.pos) q:
        lo = min(lo, q)
        hi = max(hi, q)
    let n = hi - lo + int3_1
    def blank(w:int, h:int, x0:int, y0:int) -> proj: return proj { w, h, x0, y0, map(w * h): false }
    let ps = blank(n.y, n.z, lo.y, lo.z)
    let pt = blank(n.y, n.x, lo.y, lo.x)
    let pf = blank(n.x, n.z, lo.x, lo.z)
    for(shape.pos) q:
        ps.on[(q.z - lo.z) * n.y + q.y - lo.y] = true
        pt.on[(q.x - lo.x) * n.y + q.y - lo.y] = true
        pf.on[(q.z - lo.z) * n.x + q.x - lo.x] = true
    print "voxels: length {n.y} ({float(n.y) / k} in), width {n.x} ({float(n.x) / k} in), height {n.z} ({float(n.z) / k} in), {shape.pos.length} on the surface"
    overlay(dir + "/side.ppm", read_pbm(as_str(at(vs, "file"))), raw_side, fn h: y_of_side(h), fn v: z_of_side(v) + lift_in, ps)
    overlay(dir + "/top.ppm", read_pbm(as_str(at(vt, "file"))), raw_top, fn h: y_of_top(h), fn v: x_of_top(v), proj { n.y, n.x, lo.y, lo.x, pt.on })
    overlay(dir + "/front.ppm", read_pbm(as_str(at(vf, "file"))), raw_front, fn h: (front_mid - h) * front_ih, fn v: (as_float(at(vf, "ground")) - v) * front_iv + lift_in, proj { n.x, n.z, lo.x, lo.z, pf.on })
    // every column: where the drawing's outline ends and where the voxels do, in voxels
    def compare(name:string, m:mask, cols:int, c0:int, rows:int, r0:int, px_of, on) -> void:
        var worst = 0.0
        var worst_at = 0
        var bad = 0
        var seen = 0
        for(cols) c:
            let vlo, vhi = extent(fn r: on(c + c0, r + r0), rows)
            let dlo, dhi = extent(fn r: px_of(m, c + c0, r + r0), rows)
            if vhi >= 0 and dhi >= 0:
                seen++
                let e = max(abs(vlo - dlo), abs(vhi - dhi))
                if e > 1: print "  {name}: column {c + c0} drawing {dlo}..{dhi} voxels {vlo}..{vhi}"
                if e > 1: bad++
                if float(e) > worst:
                    worst = float(e)
                    worst_at = c + c0
        print "{name}: {seen} columns, {bad} over 1 voxel out, worst {worst} at column {worst_at}"
    def in_side(mm:mask, y:int, z:int) -> bool: return in_mask(mm, int(side_h((float(y) + 0.5) / k)), int(side_v((float(z) + 0.5) / k - lift_in)))
    def in_top(mm:mask, y:int, x:int) -> bool: return in_mask(mm, int(top_h((float(y) + 0.5) / k)), int(top_v((float(x) + 0.5) / k)))
    def in_front(mm:mask, x:int, z:int) -> bool: return in_mask(mm, int(front_h((float(x) + 0.5) / k)), int(front_v((float(z) + 0.5) / k - lift_in)))
    compare("side, top and bottom edge per column along the tank", raw_side, n.y + 8, lo.y - 4, n.z + 30, lo.z - 4, fn a, b, c: in_side(a, b, c), fn a, b: proj_on(ps, a, b))
    compare("top, both edges per column along the tank", raw_top, n.y + 8, lo.y - 4, n.x + 8, lo.x - 4, fn a, b, c: in_top(a, b, c), fn a, b: proj_on(pt, a, b))
    def front_rows(a:int, b:int) -> bool: return proj_on(pf, b, a)
    compare("front, both edges per height", raw_front, n.z + 30, lo.z - 4, n.x + 8, lo.x - 4, fn a, b, c: in_front(a, c, b), fn a, b: front_rows(a, b))
    // the named stations, as a table
    let st = at(spec, "stations")
    print "| view | station | drawing | voxels | off, voxels |"
    print "|---|---|---|---|---|"
    def row(view:string, name:JV, what:string, d0:float, d1:float, v0:float, v1:float):
        let off = max(abs(d0 - v0), abs(d1 - v1)) * k
        print "| {view} | {as_str(name)} {what} | {ring_f(d0)} to {ring_f(d1)} in | {ring_f(v0)} to {ring_f(v1)} in | {ring_f(off)} |"
    for(glist(st, "side")) s:
        let h = as_float(s.a[1])
        let c = int(floor(y_of_side(h) * k))
        let dlo, dhi = extent(fn r: in_mask(raw_side, int(h), int(side_v(float(r) / 5.0))), 700)
        let vlo, vhi = extent(fn r: proj_on(ps, c, r), lo.z + n.z + 30)
        row("side", s.a[0], "(height)", float(dlo) / 5.0, float(dhi) / 5.0, float(vlo) / k - lift_in, float(vhi + 1) / k - lift_in)
    for(glist(st, "top")) s:
        let h = as_float(s.a[1])
        let c = int(floor(y_of_top(h) * k))
        let dlo, dhi = extent(fn r: in_mask(raw_top, int(h), r), raw_top.h)
        let vlo, vhi = extent(fn r: proj_on(pt, c, r + lo.x), n.x)
        row("top", s.a[0], "(width)", x_of_top(float(dlo)), x_of_top(float(dhi + 1)), float(vlo + lo.x) / k, float(vhi + lo.x + 1) / k)
    for(glist(st, "front")) s:
        let v = as_float(s.a[1])
        let c = int(floor(((as_float(at(vf, "ground")) - v) * front_iv + lift_in) * k))
        let dlo, dhi = extent(fn r: in_mask(raw_front, r, int(v)), raw_front.w)
        let vlo, vhi = extent(fn r: proj_on(pf, r + lo.x, c), n.x)
        row("front", s.a[0], "(width)", (front_mid - float(dhi + 1)) * front_ih, (front_mid - float(dlo)) * front_ih, float(vlo + lo.x) / k, float(vhi + lo.x + 1) / k)

if mode == "check": check(command_line_arguments()[2])
