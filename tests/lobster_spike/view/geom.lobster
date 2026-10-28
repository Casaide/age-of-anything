// ------------------------------------------------------------------ geometry of a posed model (src/view/art/geom.gd)
// A posed 3D model's solid voxels on a fixed grid and its vertices in world space, for the placement check
// (placement/) and the dead laid down in 3D. Primitive meshes (spheres, cylinders and cones, boxes, tori) are
// filled exactly by an inside test at each voxel centre; any other mesh (a .glb, an extruded slab) by ray parity
// along y, column by column (an open mesh marks only its crossings). Decals (quads, planes) are left out: they
// are pictures on a surface, not volume.

let GEOM_RES = 0.5                   // part units per voxel edge
let GEOM_BIAS = 2048
let GEOM_EDGE = 0.000001             // a voxel centre on a surface (to rounding) is inside, as Godot's 32-bit floats mostly have it

def vkey(i:int, j:int, k:int) -> int: return (i + GEOM_BIAS) | ((j + GEOM_BIAS) << 12) | ((k + GEOM_BIAS) << 24)
def vunkey(q:int) -> int3: return int3 { (q & 4095) - GEOM_BIAS, ((q >> 12) & 4095) - GEOM_BIAS, ((q >> 24) & 4095) - GEOM_BIAS }

// The centre of a voxel in part units.
def vcentre(q:int) -> float3: return (float(vunkey(q)) + float3_1 * 0.5) * GEOM_RES

def vcell(p:float3) -> int: return vkey(int(floor(p.x / GEOM_RES)), int(floor(p.y / GEOM_RES)), int(floor(p.z / GEOM_RES)))

// A set of voxel keys: open addressing, grown at half full; `keys` in the order they came.
class Vox:
    slots:[int]
    keys:[int]

def new_vox() -> Vox: return Vox { map(64): -1, [] }

def vslot(s:Vox, q:int) -> int:
    let mask = s.slots.length - 1
    var h = (q * 0x9E3779B1) & mask
    while s.slots[h] != -1 and s.slots[h] != q: h = (h + 1) & mask
    return h

def vhas(s:Vox, q:int) -> bool: return s.slots[vslot(s, q)] == q

def vadd(s:Vox, q:int):
    let h = vslot(s, q)
    if s.slots[h] == q: return
    s.slots[h] = q
    s.keys.push(q)
    if s.keys.length * 2 > s.slots.length:
        s.slots = map(s.slots.length * 2): -1
        for(s.keys) k: s.slots[vslot(s, k)] = k

def vcount(s:Vox) -> int: return s.keys.length

// A map from int to int on the same scheme (2D cells to what's there), `keys` in the order they came.
class IMap:
    slots:[int]
    vals:[int]
    keys:[int]

def new_imap() -> IMap: return IMap { map(64): -1, map(64): 0, [] }

def islot(m:IMap, q:int) -> int:
    let mask = m.slots.length - 1
    var h = (q * 0x9E3779B1) & mask
    while m.slots[h] != -1 and m.slots[h] != q: h = (h + 1) & mask
    return h

def ihas(m:IMap, q:int) -> bool: return m.slots[islot(m, q)] == q
def iget(m:IMap, q:int, d:int) -> int:
    let h = islot(m, q)
    return if m.slots[h] == q: m.vals[h] else: d

def iset(m:IMap, q:int, v:int):
    let h = islot(m, q)
    if m.slots[h] == q:
        m.vals[h] = v
        return
    m.slots[h] = q
    m.vals[h] = v
    m.keys.push(q)
    if m.keys.length * 2 > m.slots.length:
        let old_s = m.slots
        let old_v = m.vals
        m.slots = map(old_s.length * 2): -1
        m.vals = map(old_s.length * 2): 0
        for(old_s) k, i:
            if k != -1:
                let h2 = islot(m, k)
                m.slots[h2] = k
                m.vals[h2] = old_v[i]

// A 2D cell (art pixels) as one int, and back.
def ckey(x:int, y:int) -> int: return (x + 8192) * 16384 + (y + 8192)
def cunkey(q:int) -> int2: return int2 { q / 16384 - 8192, q % 16384 - 8192 }

// The meshes under n (visible, not decals) with their transforms relative to n's parent space, times t; a .glb
// mesh's surfaces (nodes sharing a `vol`) together, as Godot holds them in one mesh.
class GMesh:
    ms:[MMesh]
    t:Xform
    vol:int

def geom_meshes(n:MNode, t:Xform) -> [GMesh]:
    let out = []::GMesh
    geom_walk(n, xmul(t, node_xform(n)), out)
    return out

def geom_walk(n:MNode, t:Xform, out:[GMesh]) -> void:
    let m = n.mesh
    if m and n.visible and m.prim != PRIM_FLAT:
        if n.vol >= 0 and out.length and out[out.length - 1].vol == n.vol: out[out.length - 1].ms.push(m)
        else: out.push(GMesh { [m], t, n.vol })
    for(n.kids) c: geom_walk(c, xmul(t, node_xform(c)), out)

// A mesh's box (its vertices' bounds, as a primitive's AABB is), lowest corner and size.
def mesh_box(ms:[MMesh]) -> float3, float3:
    var lo = float3_1 * 100000000.0
    var hi = float3_1 * -100000000.0
    for(ms) m:
        for(m.p) v:
            lo = min(lo, v)
            hi = max(hi, v)
    return lo, hi - lo

// The axis-aligned box round a box (lo, size) moved by t.
def xf_box(t:Xform, lo:float3, size:float3) -> float3, float3:
    var a = float3_1 * 100000000.0
    var b = float3_1 * -100000000.0
    for(8) c:
        let p = xf(t, lo + size * float3 { float(c & 1), float((c >> 1) & 1), float((c >> 2) & 1) })
        a = min(a, p)
        b = max(b, p)
    return a, b - a

// The solid voxels of a model placed by t.
def voxels(n:MNode, t:Xform) -> Vox:
    let out = new_vox()
    for(geom_meshes(n, t)) g: geom_fill(g.ms, g.t, out)
    return out

def voxels_into(n:MNode, t:Xform, out:Vox):
    for(geom_meshes(n, t)) g: geom_fill(g.ms, g.t, out)

// The world-space vertices of a model placed by t.
def vertices(n:MNode, t:Xform) -> [float3]:
    let out = []::float3
    for(geom_meshes(n, t)) g:
        for(g.ms) m:
            for(m.p) v: out.push(xf(g.t, v))
    return out

def geom_fill(ms:[MMesh], t:Xform, out:Vox):
    if bdet(t.b) == 0.0: return
    let m = ms[0]
    let alo, asize = mesh_box(ms)
    let blo, bsize = xf_box(t, alo, asize)
    let inv = xinverse(t)
    let lo = int3 { int(floor(blo.x / GEOM_RES)), int(floor(blo.y / GEOM_RES)), int(floor(blo.z / GEOM_RES)) }
    let bend = blo + bsize
    let hi = int3 { int(floor(bend.x / GEOM_RES)), int(floor(bend.y / GEOM_RES)), int(floor(bend.z / GEOM_RES)) }
    if ms.length == 1 and m.prim == PRIM_SPHERE:
        var c = alo + asize * 0.5
        var r = asize * 0.5
        var base = -100000000.0
        if m.pp.z > 0.5:   // a hemisphere
            c = float3 { c.x, alo.y, c.z }
            r = float3 { r.x, asize.y, r.z }
            base = alo.y
        geom_scan(lo, hi, inv, out) p:
            let d = (p - c) / r
            p.y >= base and dot(d, d) <= 1.0
    elif ms.length == 1 and m.prim == PRIM_CYLINDER:
        let h = m.pp.z * 0.5
        geom_scan(lo, hi, inv, out) p:
            if abs(p.y) > h: false
            else:
                let rr = lerp(m.pp.y, m.pp.x, (p.y + h) / (2.0 * h))
                p.x * p.x + p.z * p.z <= rr * rr + GEOM_EDGE
    elif ms.length == 1 and m.prim == PRIM_BOX:
        let s = float3 { m.pp.x, m.pp.y, m.pp.z } * 0.5
        geom_scan(lo, hi, inv, out) p: abs(p.x) <= s.x + GEOM_EDGE and abs(p.y) <= s.y + GEOM_EDGE and abs(p.z) <= s.z + GEOM_EDGE
    elif ms.length == 1 and m.prim == PRIM_TORUS:
        let big = (m.pp.x + m.pp.y) * 0.5
        let small = (m.pp.y - m.pp.x) * 0.5
        geom_scan(lo, hi, inv, out) p:
            let q = sqrt(p.x * p.x + p.z * p.z) - big
            q * q + p.y * p.y <= small * small
    else: geom_parity(ms, t, out)

def geom_scan(lo:int3, hi:int3, inv:Xform, out:Vox, inside):
    var i = lo.x
    while i <= hi.x:
        var j = lo.y
        while j <= hi.y:
            var k = lo.z
            while k <= hi.z:
                if inside(xf(inv, (float3 { float(i), float(j), float(k) } + float3_1 * 0.5) * GEOM_RES)): vadd(out, vkey(i, j, k))
                k++
            j++
        i++

// Ray parity along +y through each voxel column's centre: crossings sorted, filled in pairs. The crossings of all
// a mesh's surfaces count together: a modelled object painted in several materials (a cat's tabby coat) comes as
// one surface per material, none of them closed on its own.
def geom_parity(ms:[MMesh], t:Xform, out:Vox):
    let cks = []::int                // each crossing: its column and height (voxel units)
    let ys = []::float
    for(ms) m:
        let w = map(m.p) v: xf(t, v) / GEOM_RES
        let tris = if m.idx.length: m.idx.length / 3 else: m.p.length / 3
        for(tris) f:
            let a = w[if m.idx.length: m.idx[f * 3] else: f * 3]
            let b = w[if m.idx.length: m.idx[f * 3 + 1] else: f * 3 + 1]
            let c = w[if m.idx.length: m.idx[f * 3 + 2] else: f * 3 + 2]
            let area = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
            if abs(area) >= 0.000000001:
                let x0 = int(floor(min(a.x, min(b.x, c.x))))
                let x1 = int(floor(max(a.x, max(b.x, c.x))))
                let z0 = int(floor(min(a.z, min(b.z, c.z))))
                let z1 = int(floor(max(a.z, max(b.z, c.z))))
                var i = x0
                while i <= x1:
                    var k = z0
                    while k <= z1:
                        let px = float(i) + 0.5
                        let pz = float(k) + 0.5
                        let w0 = geom_edge(b, c, px, pz, area)
                        let w1 = geom_edge(c, a, px, pz, area)
                        let w2 = geom_edge(a, b, px, pz, area)
                        // (half-open edges so a column through a shared edge counts once)
                        if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0 and
                           not ((w0 == 0.0 and not geom_top_left(b, c, area)) or (w1 == 0.0 and not geom_top_left(c, a, area)) or (w2 == 0.0 and not geom_top_left(a, b, area))):
                            let y = (w0 * a.y + w1 * b.y + w2 * c.y) / abs(area)
                            cks.push(vkey(i, 0, k))
                            ys.push(y)
                        k++
                    i++
    let order = map(cks.length) n: n
    qsort_in_place(order) x, y: cks[x] < cks[y] or (cks[x] == cks[y] and ys[x] < ys[y])
    var g = 0
    while g < order.length:   // each column's crossings, low to high
        var e = g
        while e < order.length and cks[order[e]] == cks[order[g]]: e++
        let col = map(e - g) n: ys[order[g + n]]
        let v = vunkey(cks[order[g]])
        if col.length % 2 == 1:
            for(col) y: vadd(out, vkey(v.x, int(floor(y)), v.z))
        else:
            var p = 0
            while p < col.length:
                var j = int(floor(col[p]))
                while j <= int(floor(col[p + 1])):
                    if float(j) + 0.5 >= col[p] - 0.5 and float(j) + 0.5 <= col[p + 1] + 0.5: vadd(out, vkey(v.x, j, v.z))
                    j++
                p += 2
        g = e

// Signed area weight of (px, pz) against edge a->b, in the triangle's winding (>= 0 inside).
// (Worked out from the edge's lower end, so a->b is exactly minus b->a: a column through two triangles' shared edge
// lands in one of them, never neither.)
def geom_edge(a:float3, b:float3, px:float, pz:float, area:float) -> float:
    let flip = a.x > b.x or (a.x == b.x and a.z > b.z)
    let p = if flip: b else: a
    let q = if flip: a else: b
    let e = (q.x - p.x) * (pz - p.z) - (px - p.x) * (q.z - p.z)
    return if (area > 0.0) != flip: e else: -e

def geom_top_left(a:float3, b:float3, area:float) -> bool:
    var dx = b.x - a.x
    var dz = b.z - a.z
    if area < 0.0:
        dx = -dx
        dz = -dz
    return dz < 0.0 or (dz == 0.0 and dx > 0.0)

// How many voxels two sets share.
def vshared(a:Vox, b:Vox) -> int:
    let swap = vcount(a) > vcount(b)
    let small = if swap: b else: a
    let big = if swap: a else: b
    var n = 0
    for(small.keys) q:
        if vhas(big, q): n++
    return n

// The shared voxels themselves.
def vintersect(a:Vox, b:Vox) -> [int]:
    let swap = vcount(a) > vcount(b)
    let small = if swap: b else: a
    let big = if swap: a else: b
    return filter(small.keys) q: vhas(big, q)

// Signed distance (part units, voxel accurate) from p to the surface of a voxel set: < 0 inside (how deep), > 0
// outside (how far). Searched out to `reach`; beyond that returns +-reach.
def vdepth(cells:Vox, p:float3, reach:float = 8.0) -> float:
    let c = vunkey(vcell(p))
    let inside = vhas(cells, vcell(p))
    let steps = int(ceiling(reach / GEOM_RES))
    var best = reach
    var r = 1
    while r <= steps:
        if float(r - 1) * GEOM_RES >= best: break
        var i = -r
        while i <= r:
            var j = -r
            while j <= r:
                // (only the shell at distance r: inside it, k is just -r and r)
                let edge = abs(i) == r or abs(j) == r
                var k = -r
                while k <= r:
                    if vhas(cells, vkey(c.x + i, c.y + j, c.z + k)) != inside:
                        best = min(best, sqrt(float(i * i + j * j + k * k)) * GEOM_RES)
                    k += if edge or k == r: 1 else: 2 * r
                j++
            i++
        r++
    return if inside: -best else: best

// The sizes of a voxel set's 6-connected pieces, biggest first.
def vcomponents(cells:Vox) -> [int]:
    let seen = new_vox()
    let sizes = []::int
    let steps = [1, -1, 1 << 12, -(1 << 12), 1 << 24, -(1 << 24)]
    for(cells.keys) start:
        if not vhas(seen, start):
            var n = 0
            let todo = [start]
            vadd(seen, start)
            while todo.length:
                let q = todo.pop()
                n++
                for(steps) d:
                    let r = q + d
                    if vhas(cells, r) and not vhas(seen, r):
                        vadd(seen, r)
                        todo.push(r)
            sizes.push(n)
    qsort_in_place(sizes) a, b: a > b
    return sizes

// The world boxes (lowest corner, size) of a model's features named by `word`: meshes whose name has it (a
// modelled eye or brow) and decals made from a picture whose name has it (a painted eye).
def features(n:MNode, word:string, t:Xform) -> [[float3]]:
    let out = []::[float3]
    features_walk(n, xmul(t, node_xform(n)), word, out)
    return out

def features_walk(n:MNode, t:Xform, word:string, out:[[float3]]) -> void:
    let m = n.mesh
    if m and find_string(n.meta, word) >= 0:
        let lo, size = mesh_box([m])
        let a, s = xf_box(t, lo, size)
        out.push([a, s])
    for(n.kids) c: features_walk(c, xmul(t, node_xform(c)), word, out)
