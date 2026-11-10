// The creel.vox palette (#313): our materials at fixed palette indexes, one swatch voxel each, so a modder who paints
// with it in MagicaVoxel needs no `mats` map (a colour that is a material's is that material). Written to
// data/voxel/creel.vox; vox_model_check holds the file to the materials.
//   lobster vox_palette.lobster
import from "../creel/src"
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

def hex_of(c:float3) -> int: return (int(c.x * 255.0 + 0.5) << 16) | (int(c.y * 255.0 + 0.5) << 8) | int(c.z * 255.0 + 0.5)

vx_load([ "../data/voxel" ])
let names = filter(vx_mat_names) n: (find(n) c: c == '#') < 0 and not n.starts_with("vox:")
assert names.length <= 255
var xyzi = le32(names.length)
var rgba = ""
let used = []::int
for(names) n, i:
    xyzi += u8s([ i % 16, i / 16, 0, i + 1 ])
    // (two materials of one colour, mark and white, wood and frame: the later one's swatch a step off, so each
    // colour is one material; drawn, a material keeps its own colour)
    var c = hex_of(vx_MAT_BASE[vx_mat(n)])
    while(find(used) u: u == c) >= 0: c = (c & 0xffff00) | ((c + 1) & 255)
    used.push(c)
    rgba += u8s([ (c >> 16) & 255, (c >> 8) & 255, c & 255, 255 ])
for(256 - names.length): rgba += u8s([ 0, 0, 0, 255 ])
let size = int3 { 16, (names.length + 15) / 16, 1 }
let chunks = chunk("SIZE", le32(size.x) + le32(size.y) + le32(size.z)) + chunk("XYZI", xyzi) + chunk("RGBA", rgba)
assert write_file("../data/voxel/creel.vox", "VOX " + le32(150) + "MAIN" + le32(0) + le32(chunks.length) + chunks, 0, 1)
print "data/voxel/creel.vox: {names.length} materials"
