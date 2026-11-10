// A body from a .vox file (#313, PR 3): its points layer places the body's points (one moved, one left to its JSON, a
// limb's hip), its parts ride their points, and a thigh drawn hanging follows the thigh through a walk, mirrored on
// the left when only the right is drawn. Files are written byte by byte into a scratch folder.
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

// the models: a point; a head 4 wide; a thigh 3 x 2 x 8, its third column only at the top (so a mirror shows)
let head_v = []::int3
for(4) z: for(4) y: for(4) x: head_v.push(int3 { x, y, z })
let thigh_v = []::int3
for(8) z: for(2) y: for(if z >= 6: 3 else: 2) x: thigh_v.push(int3 { x, y, z })
let models = model(int3_1, [ int3_0 ], [ 1 ]) + model(int3 { 4, 4, 4 }, head_v, map(head_v): 1) + model(int3 { 3, 2, 8 }, thigh_v, map(thigh_v): 1)
// the scene (MagicaVoxel voxels: 2 a body unit): the head part and the thigh in layer 0; the head and hip.r points in
// layer 1, "points", hidden
let nodes = ntrn(0, "", 1, -1, int3_0) + ngrp(1, [ 2, 4, 6, 8 ]) + ntrn(2, "head", 3, 0, int3 { 0, 2, 78 }) + nshp(3, 1) +
    ntrn(4, "head", 5, 1, int3 { 0, 2, 78 }) + nshp(5, 0) + ntrn(6, "thigh.r", 7, 0, int3 { 4, 0, 32 }) + nshp(7, 2) +
    ntrn(8, "hip.r", 9, 1, int3 { 3, 0, 42 }) + nshp(9, 0)
assert write_file(dir + "/models/body.vox", vox_of(models + nodes + rgba([ 0xb04020 ]) + layr(0, "body", false) + layr(1, "points", true)), 0, 1)

let blank = parse_json(assert read_file("../.claude/skills/voxel-art/blank_body.json"))
blank.keys.push("vox")
blank.a.push(parse_json("\"body.vox\""))
let b = vx_parse_body("vox_test", blank)
vx_bodies.set("vox_test", b)
def near(a:float3, e:float3) -> bool: return magnitude(a - e) < 0.01

// 5. points
let rest = vx_points { b.pnames, b.pat }  // (the points as placed, not lowered to the legs' reach)
let head_at = vx_where(rest, "head")
expect(near(head_at, float3 { 0.25, 1.25, 39.25 }), "the points layer moves the head: {head_at}")
let chest_at = vx_where(rest, "chest")
expect(near(chest_at, float3 { 0.0, 0.3, 29.6 }), "a point not in the file keeps its JSON place: {chest_at} {rest.names}")
expect(near(b.legs[0].a, float3 { 1.75, 0.25, 0.25 }), "hip.r places the leg on its hip point: {b.legs[0].a}")
let hp = []::vx_prim
vx_emit(hp, vx_parse_shape(parse_json("\{\"helm\": 0.5\}"), true), rest, vx_X, vx_Y, vx_Z, [], b)
expect(hp.length == 1 and near(hp[0].a, float3 { 0.25, 0.95, 40.25 }), "a helmet sits on the moved head: {hp[0].a}")
let heads = filter(b.shapes) s: s.kind == vx_k_model and s.pa == "head"
if heads.length == 1:
    let hpr = []::vx_prim
    vx_emit(hpr, heads[0], rest, vx_X, vx_Y, vx_Z, [], b)
    expect(near(hpr[0].a, float3 { 0.0, 1.0, 39.0 }), "the head part is centred where it was drawn: {hpr[0].a}")
else: expect(false, "the head part rides the head point")

// 6. the thigh through a walk
expect((find(b.vox_bones) n: n == "thigh") >= 0 and b.leg_r.length == 1 and b.leg_l.length == 1, "the thigh is drawn by the .vox, right and mirrored left")
let u = vx_unit_def { "t", "vox_test", float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0, nil }
let thigh = b.leg_r[0].model
var last = float3_0
for(8) k:
    let ph = float(k) * 45.0
    let p = vx_body_points(b, ph, float3_0)
    let out = []::vx_prim
    vx_legs(out, u, b, p, ph, [])
    let ts = filter(out) q: q.model == thigh
    expect(ts.length == 2, "two thighs at {ph}: {ts.length}")
    expect((exists(out) q: q.model < 0 and q.box == float3_0 and not q.disc and q.ra == b.legs[0].r[0]) == false, "no thigh capsule under the model at {ph}")
    for(ts) t:
        let side = if t.a.x > 0.0: 1.0 else: -1.0
        let hip = vx_where(p, "hip") + b.legs[0].a * float3 { side, 1.0, 1.0 }
        let along = t.a - hip  // (the model's up is its local +z: the bone runs down from the hip along -mz)
        expect(near(along, t.mz * (-b.legs[0].l1 * 0.5)), "the thigh centred on its bone, along it, at {ph} side {side}")
        let up = t.mz * (2.5 / vx_RES)
        let out_side = float3 { side / vx_RES, 0.0, 0.0 }
        expect(vx_dist(t.a + up + out_side, t) < 0.0 and vx_dist(t.a - up + out_side, t) > 0.0, "the third column, only at the top, is on the outside at {ph} side {side}")
    if k == 4: expect(not near(ts[0].a, last), "the thigh moves through the walk")
    if k == 0: last = ts[0].a

print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
