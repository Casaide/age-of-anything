// Writing a body as a MagicaVoxel file, voxel by voxel (the haidut method, #381): pieces named for the body points they
// ride (head, chest, hip, thigh.r, shin.r, foot.r, upper_arm.r, forearm.r, hand.r; the left is the right mirrored), a
// hidden `points` layer for hip, chest and head, and the palette. Used by the culture bodies' scripts beside it (#417).
import std
import vec

def vw_le32(i:int) -> string:
    let s, at = write_int32_le("", 0, i)
    assert at == 4
    return s

def vw_u8s(bs:[int]) -> string:
    var s = ""
    for(bs) b, i:
        let t, at = write_int8_le(s, i, b)
        assert at == i + 1
        s = t
    return s

def vw_chunk(id:string, content:string) -> string: return id + vw_le32(content.length) + vw_le32(0) + content

def vw_dict(kv:[string]) -> string:
    var s = vw_le32(kv.length / 2)
    for(kv) t: s += vw_le32(t.length) + t
    return s

// A piece: its voxels in body voxels (x right, y forward, z up, the ground at 0) and their palette indexes.
class vw_piece:
    name:string
    layer:int
    vs:[int3] = []
    idx:[int] = []

def vw_sq(x:float) -> float: return x * x

// every voxel in [lo, hi] whose centre f gives a palette index (0: empty)
def vw_fill(p:vw_piece, lo:int3, hi:int3, f):
    for(hi.z - lo.z + 1) dz: for(hi.y - lo.y + 1) dy: for(hi.x - lo.x + 1) dx:
        let v = lo + int3 { dx, dy, dz }
        let m = f(float(v) + float3_1 * 0.5)
        if m > 0:
            p.vs.push(v)
            p.idx.push(m)

// inside a section that runs from z0 to z1, its centre and radii (x, y) eased from the bottom's to the top's
def vw_taper(c:float3, z0:float, z1:float, a0:float2, a1:float2, r0:float2, r1:float2) -> bool:
    if c.z < z0 or c.z > z1: return false
    let t = (c.z - z0) / (z1 - z0)
    let a = a0 + (a1 - a0) * t
    let r = r0 + (r1 - r0) * t
    return vw_sq((c.x - a.x) / r.x) + vw_sq((c.y - a.y) / r.y) <= 1.0

def vw_ball(c:float3, at:float3, r:float3) -> bool:
    return vw_sq((c.x - at.x) / r.x) + vw_sq((c.y - at.y) / r.y) + vw_sq((c.z - at.z) / r.z) <= 1.0

// the hidden points (name, x, y, z), one voxel each
def vw_points(pieces:[vw_piece], pts:[[int]], names:[string], idx:int):
    for(pts) pt, i:
        let p = vw_piece { names[i], 1 }
        p.vs.push(int3 { pt[0], pt[1], pt[2] })
        p.idx.push(idx)
        pieces.push(p)

// the file: a model per piece, each placed by a transform under one group; layer 1 "points" hidden
def vw_write(path:string, pieces:[vw_piece], colours:[int]):
    var models = ""
    var nodes = ""
    let kids = []::int
    for(pieces) p, i:
        assert p.vs.length
        let lo = fold(p.vs, p.vs[0]) a, v: min(a, v)
        let hi = fold(p.vs, p.vs[0]) a, v: max(a, v)
        let size = hi - lo + int3_1
        var xyzi = vw_le32(p.vs.length)
        for(p.vs) v, k:
            let q = v - lo
            xyzi += vw_u8s([ q.x, q.y, q.z, p.idx[k] ])
        models += vw_chunk("SIZE", vw_le32(size.x) + vw_le32(size.y) + vw_le32(size.z)) + vw_chunk("XYZI", xyzi)
        let t = lo + size / 2  // (MagicaVoxel: a voxel's place is the transform plus its index less half the size)
        let tid = 2 + i * 2
        kids.push(tid)
        nodes += vw_chunk("nTRN", vw_le32(tid) + vw_dict([ "_name", p.name ]) + vw_le32(tid + 1) + vw_le32(-1) + vw_le32(p.layer) +
                          vw_le32(1) + vw_dict([ "_t", "{t.x} {t.y} {t.z}" ]))
        nodes += vw_chunk("nSHP", vw_le32(tid + 1) + vw_dict([]) + vw_le32(1) + vw_le32(i) + vw_dict([]))
    var grp = vw_le32(1) + vw_dict([]) + vw_le32(kids.length)
    for(kids) k: grp += vw_le32(k)
    let root = vw_chunk("nTRN", vw_le32(0) + vw_dict([]) + vw_le32(1) + vw_le32(-1) + vw_le32(-1) + vw_le32(1) + vw_dict([]))
    var rgba = ""
    for(256) i:
        let c = if i < colours.length: colours[i] else: 0
        rgba += vw_u8s([ (c >> 16) & 255, (c >> 8) & 255, c & 255, 255 ])
    let layers = vw_chunk("LAYR", vw_le32(0) + vw_dict([ "_name", "body" ]) + vw_le32(-1)) +
        vw_chunk("LAYR", vw_le32(1) + vw_dict([ "_name", "points", "_hidden", "1" ]) + vw_le32(-1))
    let content = models + root + vw_chunk("nGRP", grp) + nodes + vw_chunk("RGBA", rgba) + layers
    assert write_file(path, "VOX " + vw_le32(150) + "MAIN" + vw_le32(0) + vw_le32(content.length) + content)
    let total = fold(pieces, 0) n, p: n + p.vs.length
    print "{path}: {pieces.length} pieces, {total} voxels"
