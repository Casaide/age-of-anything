// The haidut: an 18th-century Bulgarian man drawn as a .vox body (#381), written voxel by voxel so it can be rebuilt
// and tweaked, and opened in MagicaVoxel as it is. He stands 7.5 heads tall (a head 10 voxels, 2 voxels a body unit:
// the body's `size` brings him to a human's height), in pieces named for what they ride: head, chest (shirt, sleeveless
// coat, sash), hip (the coat's skirt and the belt), thigh.r (breeches), shin.r (black wraps tied with crossed cords),
// foot.r (opanci), upper_arm.r and forearm.r (shirt sleeves), hand.r. The left limbs are the right ones mirrored.
// A hidden `points` layer puts the body's hip, chest and head.
//   cd src && lobster ../mods/vox_example/tools/haidut.lobster
import std
import vec

// the palette (the body's `mats` names the indexes that are our materials: skin, hair, team, leather, metal)
let SKIN, HAIR, FUR, LINEN, COAT, TRIM, SASH, BELT, SILVER, WRAP, CORD, SHOE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
let COLOURS = [ 0xd9a27c, 0x3a2a20, 0x2b2420, 0xe6dfcd, 0x2e2925, 0xb03228, 0xa8302a, 0x6b4a2e, 0xc8c8c0, 0x1f1d1b,
                0xcfc6b0, 0x7a5236 ]

def le32(i:int) -> string:
    let s, at = write_int32_le("", 0, i)
    assert at == 4
    return s

def u8s(bs:[int]) -> string:
    var s = ""
    for(bs) b, i:
        let t, at = write_int8_le(s, i, b)
        assert at == i + 1
        s = t
    return s

def chunk(id:string, content:string) -> string: return id + le32(content.length) + le32(0) + content

def vdict(kv:[string]) -> string:
    var s = le32(kv.length / 2)
    for(kv) t: s += le32(t.length) + t
    return s

// A piece: its voxels in body voxels (x right, y forward, z up, the ground at 0) and their palette indexes.
class piece:
    name:string
    layer:int
    vs:[int3] = []
    idx:[int] = []

def sq(x:float) -> float: return x * x

// every voxel in [lo, hi] whose centre f gives a palette index (0: empty)
def fill(p:piece, lo:int3, hi:int3, f):
    for(hi.z - lo.z + 1) dz: for(hi.y - lo.y + 1) dy: for(hi.x - lo.x + 1) dx:
        let v = lo + int3 { dx, dy, dz }
        let m = f(float(v) + float3_1 * 0.5)
        if m > 0:
            p.vs.push(v)
            p.idx.push(m)

// inside a section that runs from z0 to z1, its centre and radii (x, y) eased from the bottom's to the top's
def in_taper(c:float3, z0:float, z1:float, a0:float2, a1:float2, r0:float2, r1:float2) -> bool:
    if c.z < z0 or c.z > z1: return false
    let t = (c.z - z0) / (z1 - z0)
    let a = a0 + (a1 - a0) * t
    let r = r0 + (r1 - r0) * t
    return sq((c.x - a.x) / r.x) + sq((c.y - a.y) / r.y) <= 1.0

def in_ball(c:float3, at:float3, r:float3) -> bool: return sq((c.x - at.x) / r.x) + sq((c.y - at.y) / r.y) + sq((c.z - at.z) / r.z) <= 1.0

let pieces = []::piece

// the head: a long oval face over a firm jaw, ears, a big drooping moustache, and the kalpak (a tall fur cap, a red
// band at its foot); no eyes (at game size they read as holes)
let head = piece { "head", 0 }
fill(head, int3 { -6, -5, 61 }, int3 { 6, 6, 80 }) c:
    if in_taper(c, 71.0, 79.5, float2 { 0.0, -0.4 }, float2 { 0.0, -0.8 }, float2 { 4.6, 4.8 }, float2 { 4.1, 4.3 }):
        if c.z < 72.5: TRIM else: FUR
    elif in_ball(c, float3 { 0.0, 0.3, 67.5 }, float3 { 3.6, 4.0, 5.0 }) or in_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 }):
        if c.y > 2.6 and c.z > 64.0 and c.z < 66.6 and abs(c.x) < 4.4: HAIR  // the moustache's bar under the nose
        else: SKIN
    elif c.y > 1.6 and c.z > 61.8 and c.z < 66.6 and abs(c.x) < 5.6 and abs(c.x) > 2.4 and c.z > 66.6 - (abs(c.x) - 2.4) * 1.6: HAIR  // its ends, drooping
    elif in_ball(c, float3 { 3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }) or in_ball(c, float3 { -3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }): SKIN
    elif in_ball(c, float3 { 0.0, 4.4, 67.4 }, float3 { 0.8, 0.9, 1.4 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: a broad chest (two heads across the shoulders) over a narrower waist; the white shirt open at the neck,
// the black coat over it without sleeves, red along its edges; the sash (team colour) round the waist
let torso = piece { "chest", 0 }
fill(torso, int3 { -11, -6, 44 }, int3 { 11, 6, 62 }) c:
    let body = in_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
               in_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if not body: 0
    elif c.z < 48.0: SASH
    elif c.y > 2.0 and abs(c.x) < 2.6 + (c.z - 48.0) * 0.12: LINEN  // the shirt, in the coat's opening
    elif c.y > 2.0 and abs(c.x) < 3.6 + (c.z - 48.0) * 0.12: TRIM
    elif abs(c.x) > 8.2 and c.z > 55.0: TRIM  // round the armholes
    else: COAT
pieces.push(torso)

// the hip: the belt with its silver plates, and the coat's skirt to the knee, open in front, its hem red
let hip = piece { "hip", 0 }
fill(hip, int3 { -12, -8, 18 }, int3 { 12, 7, 44 }) c:
    let belt = in_taper(c, 40.0, 44.0, float2_0, float2_0, float2 { 7.2, 4.6 }, float2 { 7.2, 4.6 })
    let outer = in_taper(c, 18.0, 44.0, float2 { 0.0, -1.2 }, float2 { 0.0, 0.0 }, float2 { 11.0, 7.0 }, float2 { 7.4, 4.8 })
    let inner = in_taper(c, 17.0, 45.0, float2 { 0.0, -1.2 }, float2 { 0.0, 0.0 }, float2 { 9.8, 5.8 }, float2 { 6.2, 3.6 })
    let open = c.y > 0.0 and abs(c.x) < 2.0 + (44.0 - c.z) * 0.12
    if belt and c.z >= 40.0:
        if c.y > 3.0 and c.z > 41.0 and c.z < 43.0 and (int(floor(c.x + 0.5)) % 3 + 3) % 3 == 0 and abs(c.x) < 5.0: SILVER
        else: BELT
    elif outer and not inner and not open: (if c.z < 19.5 or (c.y > 0.0 and abs(c.x) < 3.2 + (44.0 - c.z) * 0.12): TRIM else: COAT)
    else: 0
pieces.push(hip)

// a leg (the right): wide white breeches to the knee, the shin wound in black with light cords crossing, opanci
let thigh = piece { "thigh.r", 0 }
fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if in_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.6, 2.8 }, float2 { 3.6, 3.8 }): LINEN else: 0
pieces.push(thigh)
let shin = piece { "shin.r", 0 }
fill(shin, int3 { 0, -4, 3 }, int3 { 7, 4, 19 }) c:
    if in_taper(c, 3.0, 19.0, float2 { 3.8, 0.0 }, float2 { 3.8, 0.2 }, float2 { 1.6, 1.6 }, float2 { 2.4, 2.6 }):
        let a = atan2(float2 { c.x - 3.8, c.y })  // the cords cross round the leg, a pair of turns every 5 voxels
        let u = c.z * 72.0
        if abs(((a - u) % 360.0 + 360.0) % 360.0 - 180.0) < 26.0 or abs(((a + u) % 360.0 + 360.0) % 360.0 - 180.0) < 26.0: CORD
        else: WRAP
    else: 0
pieces.push(shin)
let foot = piece { "foot.r", 0 }
fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 2 }) c:
    if in_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.2, 4.4 }, float2 { 1.8, 3.4 }): SHOE else: 0
pieces.push(foot)

// an arm (the right), hanging: a full white sleeve, gathered at the wrist in a red cuff, and the hand
let upper = piece { "upper_arm.r", 0 }
fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if in_taper(c, 48.0, 60.0, float2 { 9.9, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.0, 2.1 }, float2 { 2.4, 2.4 }): LINEN else: 0
pieces.push(upper)
let fore = piece { "forearm.r", 0 }
fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if in_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.6, 1.6 }, float2 { 2.0, 2.0 }):
        if c.z < 39.0: TRIM else: LINEN
    else: 0
pieces.push(fore)
let hand = piece { "hand.r", 0 }
fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 36 }) c:
    if in_ball(c, float3 { 10.3, 0.5, 34.5 }, float3 { 1.4, 1.6, 2.2 }): SKIN else: 0
pieces.push(hand)

// the points: one voxel each, hidden (the hip between the legs' tops, the chest at the armpits, the head's middle)
let points = [ [ "hip", "0", "0", "38" ], [ "chest", "0", "0", "57" ], [ "head", "0", "1", "67" ] ]
for(points) pt:
    let p = piece { pt[0], 1 }
    p.vs.push(int3 { string_to_int(pt[1]), string_to_int(pt[2]), string_to_int(pt[3]) })
    p.idx.push(SKIN)
    pieces.push(p)

// the file: a model per piece, each placed by a transform under one group; layer 1 "points" hidden
var models = ""
var nodes = ""
let kids = []::int
for(pieces) p, i:
    assert p.vs.length
    let lo = fold(p.vs, p.vs[0]) a, v: min(a, v)
    let hi = fold(p.vs, p.vs[0]) a, v: max(a, v)
    let size = hi - lo + int3_1
    var xyzi = le32(p.vs.length)
    for(p.vs) v, k:
        let q = v - lo
        xyzi += u8s([ q.x, q.y, q.z, p.idx[k] ])
    models += chunk("SIZE", le32(size.x) + le32(size.y) + le32(size.z)) + chunk("XYZI", xyzi)
    let t = lo + size / 2  // (MagicaVoxel: a voxel's place is the transform plus its index less half the size)
    let tid = 2 + i * 2
    kids.push(tid)
    nodes += chunk("nTRN", le32(tid) + vdict([ "_name", p.name ]) + le32(tid + 1) + le32(-1) + le32(p.layer) + le32(1) +
                   vdict([ "_t", "{t.x} {t.y} {t.z}" ]))
    nodes += chunk("nSHP", le32(tid + 1) + vdict([]) + le32(1) + le32(i) + vdict([]))
var grp = le32(1) + vdict([]) + le32(kids.length)
for(kids) k: grp += le32(k)
let root = chunk("nTRN", le32(0) + vdict([]) + le32(1) + le32(-1) + le32(-1) + le32(1) + vdict([]))
var rgba = ""
for(256) i:
    let c = if i < COLOURS.length: COLOURS[i] else: 0
    rgba += u8s([ (c >> 16) & 255, (c >> 8) & 255, c & 255, 255 ])
let layers = chunk("LAYR", le32(0) + vdict([ "_name", "body" ]) + le32(-1)) +
             chunk("LAYR", le32(1) + vdict([ "_name", "points", "_hidden", "1" ]) + le32(-1))
let content = models + root + chunk("nGRP", grp) + nodes + chunk("RGBA", rgba) + layers
let out = "../data/voxel/models/haidut.vox"  // (beside this tool: the mod's models)
launch_subprocess([ "/bin/mkdir", "-p", "../mods/vox_example/data/voxel/models" ])
assert write_file(out, "VOX " + le32(150) + "MAIN" + le32(0) + le32(content.length) + content)
let total = fold(pieces, 0) n, p: n + p.vs.length
print "{out}: {pieces.length} pieces, {total} voxels"
