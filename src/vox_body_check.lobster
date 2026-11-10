// A body from a .vox file (#313, PR 3), drawn standing: the hip, knee and ankle and the bones' lengths come from where
// its thigh and shin are drawn; the points layer moves a point (another keeps its JSON place); a part rides its point;
// thigh and shin stay on their bones through a walk, mirrored on the left when only the right is drawn. Files are
// written byte by byte into a scratch folder.
//   lobster vox_body_check.lobster
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.vox
import view.voxel

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

def le32(i:int) -> string:
    let s, at = write_int32_le("", 0, i)
    assert at == 4
    return s

def u8s(bs:[int]) -> string:  // bytes
    var s = ""
    for(bs) b, i:
        let t, at = write_int8_le(s, i, b)
        assert at == i + 1
        s = t
    return s

def chunk(id:string, content:string) -> string: return id + le32(content.length) + le32(0) + content

def model(size:int3, vs:[int3], idx:[int]) -> string:
    var xyzi = le32(vs.length)
    for(vs) v, i: xyzi += u8s([ v.x, v.y, v.z, idx[i] ])
    return chunk("SIZE", le32(size.x) + le32(size.y) + le32(size.z)) + chunk("XYZI", xyzi)

def rgba(cols:[int]) -> string:
    var s = ""
    for(256) i:
        let c = if i < cols.length: cols[i] else: 0
        s += u8s([ (c >> 16) & 255, (c >> 8) & 255, c & 255, 255 ])
    return chunk("RGBA", s)

def vox_of(chunks:string) -> string: return "VOX " + le32(150) + "MAIN" + le32(0) + le32(chunks.length) + chunks

def vstr(s:string) -> string: return le32(s.length) + s

def vdict(kv:[string]) -> string:  // key, value, key, value ...
    var s = le32(kv.length / 2)
    for(kv) x: s += vstr(x)
    return s

def ntrn(id:int, name:string, child:int, layer:int, t:int3) -> string:
    let attrs = if name != "": [ "_name", name ] else: []
    return chunk("nTRN", le32(id) + vdict(attrs) + le32(child) + le32(-1) + le32(layer) + le32(1) + vdict([ "_t", "{t.x} {t.y} {t.z}" ]))

def ngrp(id:int, children:[int]) -> string:
    var s = le32(id) + vdict([]) + le32(children.length)
    for(children) c: s += le32(c)
    return chunk("nGRP", s)

def nshp(id:int, m:int) -> string: return chunk("nSHP", le32(id) + vdict([]) + le32(1) + le32(m) + vdict([]))

def layr(id:int, name:string, hidden:bool) -> string:
    let kv = if hidden: [ "_name", name, "_hidden", "1" ] else: [ "_name", name ]
    return chunk("LAYR", le32(id) + vdict(kv) + le32(-1))

let dir = "/tmp/vox_body_check"
launch_subprocess([ "/bin/mkdir", "-p", dir + "/models" ])
vx_load([ "../data/voxel" ])
vx_cur_dir = dir

// the models: a point; a head 4 wide; a thigh 2 x 2 x 18 with a third column at its middle (so a mirror shows); a shin
let head_v = []::int3
for(4) z: for(4) y: for(4) x: head_v.push(int3 { x, y, z })
let thigh_v = []::int3
for(18) z: for(2) y: for(if z == 8 or z == 9: 3 else: 2) x: thigh_v.push(int3 { x, y, z })
let shin_v = []::int3
for(18) z: for(2) y: for(2) x: shin_v.push(int3 { x, y, z })
let models = model(int3_1, [ int3_0 ], [ 1 ]) + model(int3 { 4, 4, 4 }, head_v, map(head_v): 1) + model(int3 { 3, 2, 18 }, thigh_v, map(thigh_v): 1) +
    model(int3 { 2, 2, 18 }, shin_v, map(shin_v): 1)
// the scene (MagicaVoxel voxels: 2 a body unit), the right leg drawn standing: the thigh's voxels at x 3..4 (and 5
// in the middle), z 24..41; the shin's at x 3..4, z 6..23. The head part, and the head point in layer 1, "points", hidden.
let nodes = ntrn(0, "", 1, -1, int3_0) + ngrp(1, [ 2, 4, 6, 8 ]) + ntrn(2, "head", 3, 0, int3 { 0, 2, 78 }) + nshp(3, 1) +
    ntrn(4, "head", 5, 1, int3 { 0, 2, 78 }) + nshp(5, 0) + ntrn(6, "thigh.r", 7, 0, int3 { 4, 0, 33 }) + nshp(7, 2) +
    ntrn(8, "shin.r", 9, 0, int3 { 4, 0, 15 }) + nshp(9, 3)
assert write_file(dir + "/models/body.vox", vox_of(models + nodes + rgba([ 0xb04020 ]) + layr(0, "body", false) + layr(1, "points", true)), 0, 1)

let blank = parse_json(assert read_file("../.claude/skills/voxel-art/blank_body.json"))
blank.keys.push("vox")
blank.a.push(parse_json("\"body.vox\""))
let b = vx_parse_body("vox_test", blank)
vx_bodies.set("vox_test", b)
def near(a:float3, e:float3, by:float) -> bool: return magnitude(a - e) < by

// the joints, from the drawn limbs: hip (2, 0, 20.75), knee (2, 0, 12), ankle (2, 0, 3.25)
let l = b.legs[0]
expect(near(l.a, float3 { 2.0, 0.0, -0.25 }, 0.001), "the hip from the top of the thigh: {l.a} from the hip point")
expect(abs(l.l1 - 8.75) < 0.001 and abs(l.l2 - 8.75) < 0.001, "the bones from the knee where thigh and shin meet: {l.l1}, {l.l2}")
expect(near(l.foot, float3 { 2.0, 0.0, 3.25 }, 0.001), "the foot stands where the shin ends: {l.foot}")

// the points layer, and a part on a point
let rest = vx_points { b.pnames, b.pat }
let head_at = vx_where(rest, "head")
expect(near(head_at, float3 { 0.25, 1.25, 39.25 }, 0.001), "the points layer moves the head: {head_at}")
let chest_at = vx_where(rest, "chest")
expect(near(chest_at, float3 { 0.0, 0.3, 29.6 }, 0.001), "a point not in the file keeps its JSON place: {chest_at}")
let heads = filter(b.shapes) q: q.kind == vx_k_model and q.pa == "head"
expect(heads.length == 1, "the head part rides the head point")
if heads.length == 1:
    let hpr = []::vx_prim
    vx_emit(hpr, heads[0], rest, vx_X, vx_Y, vx_Z, [], b)
    expect(near(hpr[0].a, float3 { 0.0, 1.0, 39.0 }, 0.001), "the head part is centred where it was drawn: {hpr[0].a}")

// thigh and shin: drawn by the .vox, right and mirrored left, where they were drawn standing, on their bones walking
expect((find(b.vox_bones) n: n == "thigh") >= 0 and (find(b.vox_bones) n: n == "shin") >= 0, "thigh and shin are drawn by the .vox")
expect(b.leg_r.length == 2 and b.leg_l.length == 2, "two pieces a leg, the left mirrored from the right")
let u = vx_unit_def { "t", "vox_test", float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0, nil }
let thigh = b.leg_r[0].model
let shin = b.leg_r[1].model
let thigh_drawn = float3 { 2.25, 0.0, 16.5 }
let shin_drawn = float3 { 2.0, 0.0, 7.5 }
vx_stand = true
let sp = vx_body_points(b, 0.0, float3_0)
let standing = []::vx_prim
vx_legs(standing, u, b, sp, 0.0, [])
vx_stand = false
let st = filter(standing) q: q.model == thigh and q.a.x > 0.0
let ss = filter(standing) q: q.model == shin and q.a.x > 0.0
// (standing, a leg keeps a hair of bend: the hips drop until it is 0.995 of its reach, so the knee comes forward
// under a voxel; within a voxel, 0.5, of where it was drawn)
expect(st.length == 1 and near(st[0].a, thigh_drawn, 0.5), "standing, the thigh is where it was drawn: {map(st) q: q.a}")
expect(ss.length == 1 and near(ss[0].a, shin_drawn, 0.5), "standing, the shin is where it was drawn: {map(ss) q: q.a}")
var last = float3_0
for(8) k:
    let ph = float(k) * 45.0
    let p = vx_body_points(b, ph, float3_0)
    let out = []::vx_prim
    vx_legs(out, u, b, p, ph, [])
    let ts = filter(out) q: q.model == thigh
    let ss2 = filter(out) q: q.model == shin
    expect(ts.length == 2 and ss2.length == 2, "two thighs and two shins at {ph}")
    expect((exists(out) q: q.model < 0) == false, "no capsules under the pieces at {ph}")
    for(ts) t:
        let side = if t.a.x > 0.0: 1.0 else: -1.0
        let m = float3 { side, 1.0, 1.0 }
        let hip = vx_where(p, "hip") + l.a * m
        expect(abs(magnitude(t.a - hip) - magnitude(thigh_drawn - (float3 { 0.0, 0.0, 21.0 } + l.a))) < 0.01, "the thigh keeps its place on the hip at {ph} side {side}")
        let out_side = float3 { side / vx_RES, 0.0, 0.0 }
        let up = t.mz * (3.0 / vx_RES)
        expect(vx_dist(t.a + out_side, t) < 0.0 and vx_dist(t.a + out_side + up, t) > 0.0, "the middle column is on the outside at {ph} side {side}")
    for(ss2) t:
        let side = if t.a.x > 0.0: 1.0 else: -1.0
        let foot, _ = vx_foot(b, l, side, ph)
        expect(abs(magnitude(t.a - foot) - magnitude(shin_drawn - l.foot)) < 0.05, "the shin keeps its place on the ankle at {ph} side {side}")
    if k == 4: expect(not near(ts[0].a, last, 0.01), "the thigh moves through the walk")
    if k == 0: last = ts[0].a

print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
