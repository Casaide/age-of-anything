// The buildings' materials made in Lobster (model/build_mats.lobster) against Godot's (mat_dump.gd): each
// material's properties exactly (as text), and its textures pixel by pixel (the mean and worst channel
// difference, 0..255: the bar is a mean under 1 and a worst under 4). The noise textures are made here afresh
// (the cached PNGs deleted first) and the PNGs build_mats writes are read back and held to what it made.
//   lobster mat_check.lobster -- <mat_dump.gd's out dir>      (mat_check.sh runs both)

import std
import vec
import color
import gl
import texture
import dictionary
import .gen.json
import .gen.rng
import .gen.sha256
import .gen.datalib
import .gen.identity
import .gen.pricing
import .gen.heroes
import .gen.generator
import .view.node
import .view.art
import .view.baker
import .model.kit
import .model.grng
import .model.base
import .model.flat
import .model.props
import .model.build_mats

let args = command_line_arguments()

let dir = args[0]

def f6(x:float) -> string: return string(x)
def v6(v:float3) -> string: return "{f6(v.x)},{f6(v.y)},{f6(v.z)}"
def b01(b:bool) -> int: return if b: 1 else: 0

def tex_key(t:string) -> string:
    if t == "": return "-"
    if starts_with(t, bmat_dir + "/bmat"): return "noise:512x512"
    return t

def line_of(name:string, matte:bool, m:MMat) -> string:
    return "{name} matte={b01(matte)} albedo={v6(m.albedo)},{f6(1.0)} roughness={f6(m.roughness)} metallic={f6(m.metallic)} " +
           "metallic_specular={f6(m.metallic_specular)} clearcoat_enabled={b01(m.clearcoat_enabled)} clearcoat={f6(m.clearcoat)} " +
           "normal_enabled={b01(m.normal_enabled)} normal_scale={f6(m.normal_scale)} uv1_scale={v6(m.uv_scale)} " +
           "uv1_offset={v6(m.uv_offset)} triplanar={b01(m.triplanar)} world_triplanar={b01(m.world_triplanar)} " +
           "triplanar_sharpness={f6(m.triplanar_sharpness)} texture_filter={m.texture_filter} albedo_tex={tex_key(m.tex)} " +
           "normal_tex={tex_key(m.normal_tex)}"

// a PNG's RGBA bytes, by way of a texture
def png_bytes(file:string) -> string, int2:
    let t = gl.load_texture(file, texture_format_nomipmap)
    if not t: return "", int2_0
    return gl.read_texture(t) or "", gl.texture_size(t)

// mean and worst channel difference (RGBA) between two byte buffers of one size
def diff(a:string, b:string) -> float, int:
    var sum = 0
    var worst = 0
    for(a.length) i:
        let d = abs(a[i] - b[i])
        sum += d
        if d > worst: worst = d
    return float(sum) / float(a.length), worst

def field(line:string, key:string) -> string:   // the value after " key=" up to the next space
    let at = find_string(line, key) + key.length
    let end = find_string(line, " ", at)
    return line.substring(at, (if end >= 0: end else: line.length) - at)

fatal(gl.window("mat check", 64, 64, gl.window_init_no_vsync))
set_print_decimals(6)
var failed = 0

for(bmat_noise_names()) name:   // (made afresh: the first bmat of each, in the properties, writes them)
    for(["albedo", "normal"]) slot:
        delete_file(bmat_tex_path(name, slot) + ".png")

// the properties
let theirs = tokenize(read_file(dir + "/props.txt") or "", "\n", "")
var lines = 0
for(theirs) godot_line:
    if godot_line == "": continue
    lines++
    let name = tokenize(godot_line, " ", "")[0]
    let matte = find_string(godot_line, " matte=1 ") >= 0
    var mine = ""
    if starts_with(name, "flat:"):
        let c = map(tokenize(name.substring(5, name.length - 5), ",", "")) s: string_to_float(s)
        let rough = string_to_float(field(godot_line, " roughness="))
        let metal = string_to_float(field(godot_line, " metallic="))
        mine = line_of(name, false, bflat(float3 { c[0], c[1], c[2] }, rough, metal))
    else:
        bmat_matte = matte
        mine = line_of(name, matte, bmat(name))
    if mine != godot_line:
        failed++
        print "FAIL props {name} matte={b01(matte)}:\n  godot:  {godot_line}\n  lobster: {mine}"
print "{lines} property lines compared"
bmat_matte = false

// the textures: the authored ones as tex_png.gd made them, the noise ones made here
for(["thatch", "wood", "stone", "mud", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt", "weave"]) name:
    let m = bmat(name)
    let g, gs = png_bytes(dir + "/" + name + "_albedo.png")
    let l, ls = png_bytes(model_tex_dir + "/" + m.tex + ".png")
    if gs != ls or g.length == 0:
        failed++
        print "FAIL {name} albedo: size {ls} here, {gs} in Godot"
        continue
    let mean, worst = diff(g, l)
    let ok = mean < 1.0 and worst < 4
    if not ok: failed++
    print "{if ok: "PASS" else: "FAIL"} {name} albedo ({m.tex}.png, {ls.x}x{ls.y}): mean {mean}, worst {worst}"
for(bmat_noise_names()) name:
    let t0 = seconds_elapsed()
    let m = bmat(name)
    let r = bmat_recipe(name, MMat { float3_1 })
    let img = bmat_image(r)
    let made = seconds_elapsed() - t0
    for(["albedo", "normal"]) slot:
        let px = vector_to_buffer(bmat_pixels(r, img, slot), 1)
        let g, gs = png_bytes(dir + "/" + name + "_" + slot + ".png")
        let file = (if slot == "albedo": m.tex else: m.normal_tex) + ".png"
        let w, ws = png_bytes(file)
        if ws != int2 { 512, 512 } or w != px:
            failed++
            print "FAIL {name} {slot}: the PNG written ({file}, {ws}) doesn\'t hold the pixels made"
        if gs != int2 { 512, 512 }:
            failed++
            print "FAIL {name} {slot}: Godot\'s is {gs}"
            continue
        let mean, worst = diff(g, px)
        let ok = mean < 1.0 and worst < 4
        if not ok: failed++
        print "{if ok: "PASS" else: "FAIL"} {name} {slot} (noise, 512x512, its image of bytes made in {made}s): mean {mean}, worst {worst}"
print "{failed} failed"
