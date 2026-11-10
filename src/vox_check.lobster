// The .vox reader's checks (#313): MagicaVoxel files built byte by byte here, read back by view/vox.lobster.
// A model, a palette, MATL materials, the scene graph (named objects on named layers, moved and turned),
// files with no scene graph, and broken files (an error, never a crash).
//   lobster vox_check.lobster
import from "../creel/src"
import std
import vec
import view.vox

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

// ---- writing a .vox, for the fixtures

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

def vstr(s:string) -> string: return le32(s.length) + s

def vdict(kv:[string]) -> string:  // key, value, key, value ...
    var s = le32(kv.length / 2)
    for(kv) x: s += vstr(x)
    return s

def chunk(id:string, content:string) -> string: return id + le32(content.length) + le32(0) + content

def size_xyzi(size:int3, vs:[int3], idx:[int]) -> string:
    var x = le32(vs.length)
    for(vs) v, n:
        x += u8s([ v.x, v.y, v.z, idx[n] ])
    return chunk("SIZE", le32(size.x) + le32(size.y) + le32(size.z)) + chunk("XYZI", x)

def ntrn(id:int, attrs:[string], child:int, layer:int, frame:[string]) -> string:
    return chunk("nTRN", le32(id) + vdict(attrs) + le32(child) + le32(-1) + le32(layer) + le32(1) + vdict(frame))

def ngrp(id:int, children:[int]) -> string:
    var s = le32(id) + vdict([]) + le32(children.length)
    for(children) c: s += le32(c)
    return chunk("nGRP", s)

def nshp(id:int, model:int) -> string: return chunk("nSHP", le32(id) + vdict([]) + le32(1) + le32(model) + vdict([]))

def layr(id:int, name:string, hidden:bool) -> string:
    let kv = if hidden: [ "_name", name, "_hidden", "1" ] else: [ "_name", name ]
    return chunk("LAYR", le32(id) + vdict(kv) + le32(-1))

def rgba(cols:[int]) -> string:  // the first colours (0xRRGGBB), the rest black; entry i is palette index i + 1
    var s = ""
    for(256) i:
        let c = if i < cols.length: cols[i] else: 0
        s += u8s([ (c >> 16) & 255, (c >> 8) & 255, c & 255, 255 ])
    return chunk("RGBA", s)

def vox_of(chunks:string) -> string: return "VOX " + le32(150) + "MAIN" + le32(0) + le32(chunks.length) + chunks

// ---- the checks

def one_voxel():
    let f = vox_parse(vox_of(size_xyzi(int3 { 1, 1, 1 }, [ int3_0 ], [ 7 ])))
    expect(f.error == "", "one voxel: reads ({f.error})")
    expect(f.models.length == 1, "one voxel: one model")
    if f.models.length == 1:
        let m = f.models[0]
        expect(m.size == int3_1, "one voxel: its size")
        expect(m.xyz.length == 1 and m.xyz[0] == int3_0 and m.idx[0] == 7, "one voxel: its place and colour index")
    // No scene graph (an old file): each model is an object of its own, unmoved, on no layer
    expect(f.nodes.length == 1 and f.nodes[0].model == 0 and f.nodes[0].t == int3_0 and f.nodes[0].layer == "",
           "one voxel: an object of its own with no scene graph")
    // No RGBA: MagicaVoxel's default palette (index 1 is white)
    expect(f.palette.length == 256 and f.palette[0] == 0xffffff, "one voxel: the default palette")

def high_bytes():  // indices and coordinates over 127 read unsigned
    let f = vox_parse(vox_of(size_xyzi(int3 { 200, 1, 1 }, [ int3 { 199, 0, 0 } ], [ 255 ])))
    expect(f.error == "" and f.models[0].xyz[0].x == 199 and f.models[0].idx[0] == 255, "bytes over 127 read unsigned")
    expect(f.models[0].size.x == 200, "a model 200 voxels across")

def palette():
    let f = vox_parse(vox_of(size_xyzi(int3_1, [ int3_0 ], [ 2 ]) + rgba([ 0x112233, 0xcc2921 ])))
    expect(f.error == "", "palette: reads")
    expect(f.palette[0] == 0x112233 and f.palette[1] == 0xcc2921 and f.palette[2] == 0, "palette: index i is entry i - 1")
    expect(vox_rgb(f, 2) == 0xcc2921, "palette: vox_rgb of an index")

def matl():
    let m = chunk("MATL", le32(4) + vdict([ "_type", "_metal", "_metal", "0.8", "_rough", "0.25" ])) +
        chunk("MATL", le32(9) + vdict([ "_type", "_emit", "_emit", "1.0" ]))
    let f = vox_parse(vox_of(size_xyzi(int3_1, [ int3_0 ], [ 4 ]) + m))
    expect(f.error == "", "MATL: reads")
    expect(vox_mat_type(f, 4) == "_metal" and vox_mat_float(f, 4, "_metal", 0.0) == 0.8 and
           vox_mat_float(f, 4, "_rough", 0.0) == 0.25, "MATL: a metal\'s settings")
    expect(vox_mat_type(f, 9) == "_emit" and vox_mat_float(f, 9, "_emit", 0.0) == 1.0, "MATL: an emitter")
    expect(vox_mat_type(f, 5) == "_diffuse" and vox_mat_float(f, 5, "_metal", 0.5) == 0.5, "MATL: none given is diffuse")

// The scene: a root moved (10, 0, 0), a group, two named objects on two layers; "head" moved (0, 0, 20) and
// turned a quarter round z; "hand.r" on a hidden "points" layer.
def scene_file() -> string:
    let models = size_xyzi(int3 { 3, 1, 1 }, [ int3 { 0, 0, 0 }, int3 { 2, 0, 0 } ], [ 1, 1 ]) +
        size_xyzi(int3_1, [ int3_0 ], [ 2 ])
    let rot_z = "{1 | (0 << 2) | (1 << 4)}"  // rows: (0, -1, 0), (1, 0, 0), (0, 0, 1)
    let nodes = ntrn(0, [], 1, -1, [ "_t", "10 0 0" ]) + ngrp(1, [ 2, 4 ]) +
        ntrn(2, [ "_name", "head" ], 3, 0, [ "_t", "0 0 20", "_r", rot_z ]) + nshp(3, 0) +
        ntrn(4, [ "_name", "hand.r" ], 5, 1, [ "_t", "4 -2 6" ]) + nshp(5, 1)
    return vox_of(models + nodes + layr(0, "body", false) + layr(1, "points", true))

def scene():
    let f = vox_parse(scene_file())
    expect(f.error == "", "scene: reads ({f.error})")
    expect(f.nodes.length == 2, "scene: two objects")
    if f.nodes.length != 2: return
    let head = f.nodes[0]
    let hand = f.nodes[1]
    expect(head.name == "head" and head.model == 0 and head.layer == "body" and not head.hidden, "scene: head\'s name, model, layer")
    expect(hand.name == "hand.r" and hand.model == 1 and hand.layer == "points" and hand.hidden, "scene: a hidden layer\'s object")
    expect(head.t == int3 { 10, 0, 20 }, "scene: moves add up through the graph ({head.t})")
    expect(hand.t == int3 { 14, -2, 6 }, "scene: the hand\'s place ({hand.t})")
    // A voxel's place in the scene: centred on the model (a 3-wide model's middle is voxel 1), turned, moved
    expect(vox_world(f, hand, 0) == int3 { 14, -2, 6 }, "scene: a 1-voxel model sits at its object\'s place")
    expect(vox_world(f, head, 0) == int3 { 10, -1, 20 }, "scene: the head\'s first voxel, turned ({vox_world(f, head, 0)})")
    expect(vox_world(f, head, 1) == int3 { 10, 1, 20 }, "scene: the head\'s last voxel, turned ({vox_world(f, head, 1)})")
    expect(vox_node(f, "hand.r") == 1 and vox_node(f, "nose") == -1, "scene: objects found by name")

def unknown_chunk():
    let f = vox_parse(vox_of(chunk("rOBJ", vdict([ "_type", "_setting" ])) + size_xyzi(int3_1, [ int3_0 ], [ 3 ]) +
                             chunk("NOTE", le32(0))))
    expect(f.error == "" and f.models.length == 1, "chunks we don\'t know are skipped ({f.error})")

def broken():
    expect(vox_parse("").error != "", "broken: empty")
    expect(vox_parse("PNG " + le32(150)).error != "", "broken: not a .vox")
    let whole = vox_of(size_xyzi(int3_1, [ int3_0 ], [ 1 ]))
    for(whole.length) n: if vox_parse(substring(whole, 0, n)).error == "": expect(false, "broken: cut at {n} bytes reads as whole")
    let bad = vox_of(chunk("SIZE", le32(1) + le32(1) + le32(1)) + chunk("XYZI", le32(1000)))
    expect(vox_parse(bad).error != "", "broken: more voxels said than there are")
    let outside = vox_of(size_xyzi(int3_1, [ int3 { 5, 0, 0 } ], [ 1 ]))
    expect(vox_parse(outside).error != "", "broken: a voxel outside its model")
    let cycle = vox_of(size_xyzi(int3_1, [ int3_0 ], [ 1 ]) + ntrn(0, [], 1, -1, []) + ngrp(1, [ 0 ]))
    expect(vox_parse(cycle).error != "", "broken: a scene graph in a loop")

def rotations():  // every one of the 24 rotations MagicaVoxel writes is a proper turn (a det 1 matrix)
    var good = 0
    for(128) r:
        let m = vox_rot(r)
        if m.length == 3:
            let d = m[0].x * (m[1].y * m[2].z - m[1].z * m[2].y) - m[0].y * (m[1].x * m[2].z - m[1].z * m[2].x) +
                m[0].z * (m[1].x * m[2].y - m[1].y * m[2].x)
            if d == 1: good++
    expect(good == 24, "rotations: 24 proper turns ({good})")
    let i = vox_rot(4)  // rows (1,0,0), (0,1,0), (0,0,1): MagicaVoxel's "no turn"
    expect(i.length == 3 and i[0] == int3 { 1, 0, 0 } and i[1] == int3 { 0, 1, 0 } and i[2] == int3 { 0, 0, 1 }, "rotations: 4 is none")

one_voxel()
high_bytes()
palette()
matl()
scene()
unknown_chunk()
broken()
rotations()
print "\n{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
