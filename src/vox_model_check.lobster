// The .vox model shape (#313, PR 2): a model placed on a point lands where it should at size 1 and 2, a blade one
// voxel thick shows in every facing, its palette maps to our materials (named, by colour, else its own), and a
// changed model changes the bake cache's key. Models are written byte by byte into a scratch folder.
//   lobster vox_model_check.lobster
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

let dir = "/tmp/vox_model_check"
launch_subprocess([ "/bin/mkdir", "-p", dir + "/models" ])
def put(name:string, bytes:string): assert write_file(dir + "/models/" + name, bytes, 0, 1)

vx_load([ "../data/voxel" ])
vx_cur_dir = dir

def box_voxels(size:int3, m:int) -> [int3], [int]:
    let vs = []::int3
    let idx = []::int
    for(size.z) z: for(size.y) y: for(size.x) x:
        vs.push(int3 { x, y, z })
        idx.push(m)
    return vs, idx

let pts = vx_points { [ "o" ], [ float3 { 0.0, 0.0, 10.0 } ] }

def prims_of(shape:string) -> [vx_prim]:
    let out = []::vx_prim
    vx_emit(out, vx_parse_shape(parse_json(shape), true), pts, vx_X, vx_Y, vx_Z, [], nil)
    return out

def solid(sh:vx_shape) -> int: return fold(sh.grid, 0) n, m: n + (if m >= 0: 1 else: 0)

def centre(sh:vx_shape) -> float3:
    var c = float3_0
    var n = 0
    for(sh.grid) m, i:
        if m >= 0:
            c += float(sh.lo + int3 { i % sh.dims.x, (i / sh.dims.x) % sh.dims.y, i / (sh.dims.x * sh.dims.y) }) + float3_1 * 0.5
            n++
    return c / float(n)

// 2. placement: a 4 x 6 x 2 box, centred on its point, a voxel a voxel at size 1 and two at size 2
let bv, bi = box_voxels(int3 { 4, 6, 2 }, 1)
put("box.vox", vox_of(model(int3 { 4, 6, 2 }, bv, bi) + rgba([ 0xb04020 ])))
let box = prims_of("\{\"model\": \"box.vox\", \"at\": [\"o\", 0, 0, 0]\}")
expect(box.length == 1 and box[0].model >= 0, "a model shape gives one model prim")
for([ 1.0, 2.0 ]) size:
    let sh = vx_fill(box, size)
    let want = int(48.0 * size * size * size)
    expect(solid(sh) == want, "box at size {size}: {solid(sh)} voxels, want {want}")
    let c = centre(sh)
    expect(abs(c.x) < 0.01 and abs(c.y) < 0.01, "box at size {size} centred on its point: {c}")
    expect(abs(c.z - size) < 0.01, "box at size {size} stands on the ground: centre z {c.z}")

// a mirrored shape draws the model flipped: an L, its foot to the right, has it to the left in the mirror
let lv = [ int3 { 0, 0, 0 }, int3 { 0, 0, 1 }, int3 { 0, 0, 2 }, int3 { 1, 0, 0 }, int3 { 2, 0, 0 } ]
put("ell.vox", vox_of(model(int3 { 3, 1, 3 }, lv, map(lv): 1) + rgba([ 0xb04020 ])))
let ell = prims_of("\{\"model\": \"ell.vox\", \"at\": [\"o\", 6, 0, 0], \"mirror\": true\}")
expect(ell.length == 2, "a mirrored model gives two prims")
if ell.length == 2:
    def solid_at(p:vx_prim, x:float, z:float) -> bool: return vx_dist(p.a + float3 { x, 0.0, z } / vx_RES, p) < 0.0
    expect(solid_at(ell[0], 1.0, -1.0) and not solid_at(ell[0], 1.0, 1.0) and solid_at(ell[0], -1.0, 1.0), "the L stands as drawn, its foot right")
    expect(solid_at(ell[1], -1.0, -1.0) and not solid_at(ell[1], -1.0, 1.0) and solid_at(ell[1], 1.0, 1.0), "the mirrored L has its foot left")

// a sword drawn symmetric about its centre column keeps its shape on its point (Dominic, 2026-11-10: "that sword is
// bugged, off center": the sword in #360's picture was drawn off its own centre)
let sw = []::int3
for(16) y: for(3) x: for(2) z: sw.push(int3 { 2 + x, 8 + y, z + 1 })
for(7) x: for(2) z: sw.push(int3 { x, 7, z + 1 })
for(5) y: for(2) z: sw.push(int3 { 3, 2 + y, z + 1 })
for(2) y: for(3) x: for(2) z: sw.push(int3 { 2 + x, y, z + 1 })
put("sword.vox", vox_of(model(int3 { 7, 24, 4 }, sw, map(sw): 1) + rgba([ 0xb8bcc4 ])))
let swsh = vx_fill(prims_of("\{\"model\": \"sword.vox\", \"at\": [\"o\", 0, 0, 0]\}"), 1.0)
// (7 wide on a grid whose lines meet at the point: it sits half a voxel to one side, but must keep its shape)
var x0 = 1000
var x1 = -1000
for(swsh.grid) m, i:
    if m >= 0:
        x0 = min(x0, i % swsh.dims.x)
        x1 = max(x1, i % swsh.dims.x)
var asym = 0
for(swsh.grid) m, i:
    if m >= 0 and swsh.grid[i - i % swsh.dims.x + x0 + x1 - i % swsh.dims.x] < 0: asym++
let off = float(swsh.lo.x) + float(x0 + x1 + 1) * 0.5
expect(x1 - x0 == 6 and abs(off) <= 0.5, "a symmetric sword 7 voxels wide stays 7 wide within half a voxel of its point: {x1 - x0 + 1} wide, {off} off")
expect(solid(swsh) == sw.length and asym == 0, "a symmetric sword fills {solid(swsh)} of {sw.length} voxels, {asym} without a mirror twin about its own centre")

// 3. facings: a blade one voxel thick and 12 long shows in all 8 facings
let blv, bli = box_voxels(int3 { 1, 12, 3 }, 1)
put("blade.vox", vox_of(model(int3 { 1, 12, 3 }, blv, bli) + rgba([ 0xc8c8d0 ])))
let blade = vx_fill(prims_of("\{\"model\": \"blade.vox\", \"at\": [\"o\", 0, 0, 0], \"to\": [\"o\", 1, 1, 0]\}"), 1.0)
expect(solid(blade) >= 24, "a blade 12 long aimed along a diagonal keeps 3 rows of 8 or more: {solid(blade)} voxels")
for(8) f:
    let px = fold(vx_cell(blade, f), 0) n, c: n + (if c.w > 0.0: 1 else: 0)
    expect(px >= 12, "the blade shows in facing {f}: {px} pixels")

// 4. materials: index 1 named team, index 2 exactly metal's colour, index 3 a colour of its own (MATL metal: shiny)
def hex_of(c:float3) -> int: return (int(c.x * 255.0 + 0.5) << 16) | (int(c.y * 255.0 + 0.5) << 8) | int(c.z * 255.0 + 0.5)
let metal = vx_mat("metal")
let mv = [ int3 { 0, 0, 0 }, int3 { 1, 0, 0 }, int3 { 2, 0, 0 } ]
let matl = chunk("MATL", le32(3) + le32(2) + le32(5) + "_type" + le32(6) + "_metal" + le32(6) + "_metal" + le32(3) + "0.9")
put("mats.vox", vox_of(model(int3 { 3, 1, 1 }, mv, [ 1, 2, 3 ]) + rgba([ 0x123456, hex_of(vx_MAT_BASE[metal]), 0x10e080 ]) + matl))
let mp = prims_of("\{\"model\": \"mats.vox\", \"at\": [\"o\", 0, 0, 0], \"mats\": \{\"1\": \"team\"\}\}")[0]
let at1 = vx_model_mat_at(mp.a + float3 { -1.0, 0.0, 0.0 } / vx_RES, mp)
let at2 = vx_model_mat_at(mp.a, mp)
let at3 = vx_model_mat_at(mp.a + float3 { 1.0, 0.0, 0.0 } / vx_RES, mp)
expect(at1 == vx_mat("team"), "index 1 named team is team: {vx_mat_names[at1]}")
expect(at2 == metal, "index 2 in the metal colour is metal: {vx_mat_names[at2]}")
expect(vx_mat_names[at3] == "vox:mats.vox:3", "index 3 is its own material: {vx_mat_names[at3]}")
expect(hex_of(vx_MAT_BASE[at3]) == 0x10e080, "its own material keeps its colour")
expect(vx_MAT_SHINE[at3] > 0.3, "MATL metal makes it shiny: {vx_MAT_SHINE[at3]}")
let again = prims_of("\{\"model\": \"mats.vox\", \"at\": [\"o\", 0, 0, 0], \"mats\": \{\"1\": \"team\"\}\}")[0]
expect(again.model == mp.model, "the same model and map load once")

// 7. the cache: a changed .vox changes the bake cache's key
vx_data_dirs.push(dir)
let key0 = vx_data_text()
put("box.vox", vox_of(model(int3 { 4, 6, 2 }, bv, bi) + rgba([ 0xb04021 ])))
expect(vx_data_text() != key0, "a changed model colour changes the bake key")

// 8. the creel.vox palette (vox_palette.lobster): painted with it, every colour is its material, no mats map needed
let creel = vox_parse(assert read_file("../data/voxel/creel.vox"))
let base_mats = filter(vx_mat_names) n: (find(n) c: c == '#') < 0 and not n.starts_with("vox:")
expect(creel.error == "" and creel.models.length == 1 and creel.models[0].xyz.length == base_mats.length, "creel.vox has a swatch for each of our {base_mats.length} materials")
for(base_mats) n, i:
    let m = vx_vox_mat(creel, "creel.vox", i + 1, parse_json("\{\}"))
    expect(m == vx_mat(n), "creel.vox index {i + 1} is {n}: {vx_mat_names[m]}")

print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
