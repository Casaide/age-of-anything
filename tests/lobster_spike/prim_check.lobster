// The model kit's primitive meshes against Godot's (prim_dump.gd's numbers): the same vertices, normals,
// UVs and triangles, and the same polygon triangulation.
//   godot --headless --path . --script res://tests/lobster_spike/prim_dump.gd -- /tmp/prims.txt
//   lobster prim_check.lobster -- /tmp/prims.txt

import std
import vec
import .model.kit

let text = read_file(command_line_arguments()[0])
assert text
let ours = dictionary<string, MMesh>(16)
ours.set("sphere", sphere_mesh(1.0, 2.0, 32, 16, false))
ours.set("hemi", sphere_mesh(1.0, 1.0, 28, 10, true))
ours.set("cyl", cylinder_mesh(1.5, 2.0, 3.0, 14, 4, true, true))
ours.set("cone", cylinder_mesh(0.0, 2.0, 3.0, 18, 1, true, false))
ours.set("torus", torus_mesh(2.0, 3.0, 28, 10))
ours.set("box", box_mesh(float3 { 2.0, 3.0, 4.0 }, 0, 0, 0))
ours.set("boxsub", box_mesh(float3 { 2.0, 3.0, 4.0 }, 2, 1, 3))
ours.set("quad", quad_mesh(float2 { 2.0, 3.0 }))
ours.set("plane", plane_mesh(float2 { 2.0, 3.0 }, 2, 1, FACE_Y, float3_0))
let poly = [float2 { 0.0, 0.0 }, float2 { 4.0, -1.0 }, float2 { 6.0, 2.0 }, float2 { 3.0, 1.0 }, float2 { 2.0, 5.0 }, float2 { -1.0, 3.0 }]

def same(a:[int], b:[int]) -> bool:
    if a.length != b.length: return false
    for(a) x, i:
        if x != b[i]: return false
    return true

var failed = 0
var cur:MMesh? = nil
var name = ""
var k = 0
var bad = 0
def report():
    if name != "":
        if bad: failed++
        print "{if bad: "FAIL" else: "PASS"} {name}{if bad: " ({bad} differ)" else: ""}"
for(tokenize(text, "\n", "")) line:
    let w = tokenize(line, " ", "")
    if w.length == 0: continue
    if w[0] == "mesh":
        report()
        name = w[1]
        cur = ours.get(name)
        k = 0
        bad = 0
        let m = cur
        if m:
            if m.p.length != string_to_int(w[2]) or m.idx.length != string_to_int(w[3]):
                print "  {name}: {m.p.length} vertices, {m.idx.length} indices; Godot {w[2]}, {w[3]}"
                bad++
    elif w[0] == "v":
        let m = cur
        if m and k < m.p.length:
            let f = map(w.slice(1, -1)) s: string_to_float(s)
            let d = max(magnitude(m.p[k] - float3 { f[0], f[1], f[2] }),
                        max(magnitude(m.n[k] - float3 { f[3], f[4], f[5] }) * 0.1, magnitude(m.uv[k] - float2 { f[6], f[7] })))
            if d > 0.001:
                if bad < 4: print "  {name} v{k}: ours {m.p[k]} {m.n[k]} {m.uv[k]}, Godot {f}"
                bad++
        k++
    elif w[0] == "i":
        let m = cur
        if m:
            let idx = map(w.slice(1, -1)) s: string_to_int(s)
            if not same(idx, m.idx):
                print "  {name}: the triangles differ"
                bad++
    elif w[0] == "poly":
        report()
        name = "triangulate"
        bad = 0
        let idx = map(w.slice(1, -1)) s: string_to_int(s)
        let mine = triangulate(poly)
        if not same(idx, mine):
            print "  ours {mine}, Godot {idx}"
            bad++
report()
print "{failed} failed"
