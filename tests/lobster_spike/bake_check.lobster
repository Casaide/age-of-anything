// The baker's port, stage 1 (view/baker.lobster): each exported part (mesh_export.gd) baked in Lobster
// beside Godot's bake of the same part in the same colours (the part library), 6x, for the eye; and
// how much they differ (the share of pixels whose coverage differs, and the mean colour difference
// where both are opaque). Run from tests/lobster_spike:
//   lobster bake_check.lobster -- <mesh dir> "<prompt>" <out.png> [facing]
import std
import vec
import color
import gl
import texture
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import view.node
import view.art
import game.audio
import game.pack
import view.baker

let args = command_line_arguments()
let dir = args[0]
let facing = if args.length > 3: string_to_int(args[3]) else: 0
bake_shadow_debug = args.length > 4
fatal(gl.window("bake check", 1600, 1000, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(BAKE_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
lib_load("../../data")
id_load("../../data")
load_pack("library")
load_part_data("library")
let race = generate(args[1], load_rules("default"), 0)
let r0 = at(glist(race, "units")[1], "recipe")
let cols = colours_for(rstr(r0, "skin"), rstr(race, "family"), float3 { 1.0, 0.0, 1.0 })
let names, sizes = scan_folder(dir, true)
let ids = sorted_strs(map(filter(names or []) n: ends_with(n, ".mesh")) n: n.substring(0, n.length - 5))

class Pair:
    id:string
    mine:resource<texture>?
    mw:int
    mh:int
    theirs:int          // the library's frame, or -1
    note:string

let pairs = []::Pair
var shot_done = false
var frame_n = 0
while gl.frame() and not shot_done:
    frame_n++
    if frame_n == 1:   // (the bakes inside a frame: after an offscreen render outside one the window draws nothing)
        for(ids) id:
            let tris = load_mesh(dir + "/" + id + ".mesh")
            bake_debug = dir + "/raw_" + id
            let sprite, w, h, origin = bake_facing(tris, facing)
            let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                                    float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
            let tex = gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag)
            let key = "p:" + bake_key(id, glist(part(id), "shapes"), cols) + facing_suffix(facing)
            let f = frame_index(key)
            var note = "{w}x{h}"
            if f >= 0: note += " vs Godot {frames[f].w}x{frames[f].h}"
            else: note += " (Godot\'s bake not in the library: {key})"
            print "{id}: {note}"
            pairs.push(Pair { id, tex, w, h, f, note })
        continue
    gl.clear(float4 { 0.36, 0.42, 0.3, 1.0 })
    gl.blend(1)
    let z = 5.0
    var x = 20.0
    var y = 20.0
    var row_h = 0.0
    for(pairs) pr:
        let mw = float(pr.mw) * z
        let gw = if pr.theirs >= 0: float(frames[pr.theirs].w) * z else: 0.0
        let ph = max(float(pr.mh), if pr.theirs >= 0: float(frames[pr.theirs].h) else: 0.0) * z
        if x + mw + gw + 40.0 > float(gl.window_size().x):
            x = 20.0
            y += row_h + 50.0
            row_h = 0.0
        let t = pr.mine
        if t:   // (a mesh: gl.rect isn't where it's asked in this build)
            let hh = float(pr.mh) * z
            let m = gl.new_mesh("PT", [float3 { x, y, 0.0 }, float3 { x + mw, y, 0.0 }, float3 { x + mw, y + hh, 0.0 }, float3 { x, y + hh, 0.0 }],
                                []::float4, []::float3, [float2 { 0.0, 0.0 }, float2 { 1.0, 0.0 }, float2 { 1.0, 1.0 }, float2 { 0.0, 1.0 }], []::float2, [0, 2, 1, 0, 3, 2])
            gl.set_mesh_texture(m, 0, 0, t)
            gl.set_shader("textured")
            gl.color(float4_1): gl.render_mesh(m)
        if pr.theirs >= 0:
            b_sheet = -1
            sprite_xf(pr.theirs, [z, 0.0, 0.0, z, x + mw + 10.0, y], float4 { 1.0, 0.0, 1.0, 1.0 })
            flush_sprites()
        gl.set_shader("color")
        gl.color(float4_1):
            gl.translate(float2 { x, y + ph + 4.0 }):
                gl.set_font_size(14)
                gl.text("{pr.id}: Lobster | Godot")
        x += mw + gw + 50.0
        row_h = max(row_h, ph + 20.0)
    if frame_n == 3:
        gl.screenshot(args[2])
        shot_done = true
