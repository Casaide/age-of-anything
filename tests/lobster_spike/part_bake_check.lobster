// Parts baked in Lobster from Lobster-built models (view/part_bake.lobster) against the same parts as the
// Godot part baker made them (the library pack): per facing, the sprite's size and origin, how many pixels
// differ, the rig's sockets and the weapon's tip; and a picture of each pair side by side.
//   lobster part_bake_check.lobster -- "<prompt>" <out.png> [part id ...]   (default: every part the race's units wear)

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
import .game.audio
import .game.pack
import .view.baker
import .model.kit
import .model.grng
import .model.base
import .model.flat
import .model.glb
import .model.units
import .model.units2
import .model.units3
import .model.units4
import .model.units5
import .model.kit_bodies
import .model.siege
import .model.heroes
import .model.bears
import .model.models
import .view.part_bake

let args = command_line_arguments()
var show_facing = 0   // which facing the picture shows (SHOW_FACING=<k> in the environment)
fatal(gl.window("part bake check", 1600, 1000, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(BAKE_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
lib_load("../../data")
id_load("../../data")
load_pack("library")
load_part_data("library")
let race = generate(args[0], load_rules("default"), 0)
let r1 = at(glist(race, "units")[1], "recipe")
let cols = colours_for(rstr(r1, "skin"), rstr(race, "family"), float3 { 1.0, 0.0, 1.0 })
var ids = args.slice(2, -1)
if ids.length == 0:
    for(glist(race, "units")) u:
        let r = at(u, "recipe")
        for(append([rstr(r, "body"), rstr(r, "head")], map(filter(gobj(r, "parts").a) v: v.kind == J_STR) v: v.s)) id:
            if id != "" and find_s(ids, id) < 0: ids.push(id)

// The library's (Godot's) bakes and rigs, kept aside: the Lobster bake goes into the same tables.
class Theirs:
    key:string
    frame:int
    bake:Bake?
    rig:JV
let theirs = []::Theirs
let keys = []::string
for(ids) id:
    let base = tokenize(tokenize(id, "~", "")[0], "@", "")[0]
    let key = bake_key(id, glist(part(base), "shapes"), cols)
    keys.push(key)
    for(8) k:
        let full = key + facing_suffix(k)
        theirs.push(Theirs { full, frame_index("p:" + full), bakes.get(full), rig(id + facing_suffix(k)) })
        bakes.del(full)

// A frame's opaque box relative to its origin (lo, hi in sprite px), read from its sheet.
let sheet_px = dictionary<int, string>(64)
def opaque_box(f:int) -> float2, float2:
    let fr = frames[f]
    var px = sheet_px.get(fr.sheet, "")
    if px == "":
        px = gl.read_texture(sheet_tex[fr.sheet]) or ""
        sheet_px.set(fr.sheet, px)
    let sw = int(sheet_dims[fr.sheet].x)
    var lo = float2 { 1000000.0, 1000000.0 }
    var hi = float2 { -1000000.0, -1000000.0 }
    for(fr.h) y:
        for(fr.w) x:
            if px[((fr.y + y) * sw + fr.x + x) * 4 + 3] > 127:
                lo = min(lo, float2 { float(x - fr.ox), float(y - fr.oy) })
                hi = max(hi, float2 { float(x - fr.ox), float(y - fr.oy) })
    return lo, hi

var failed = 0
var frame_n = 0
var shot_done = false
let mine_frames = []::int
while gl.frame() and not shot_done:
    frame_n++
    if frame_n == 1:   // (bakes inside a frame)
        for(ids) id, i:
            let saved = rigs
            rigs = jobj()
            if not bake_model_part(id, keys[i], cols):
                print "SKIP {id}: no Lobster model"
                rigs = saved
                continue
            let mine_rigs = rigs
            rigs = saved
            var worst_px = 0.0
            var worst_sock = 0.0
            var worst_tip = 0.0
            var notes = ""
            for(8) k:
                let t = theirs[i * 8 + k]
                let mf = frame_index("p:" + t.key)
                mine_frames.push(mf)
                let tb = t.bake
                if t.frame < 0 or not tb:
                    notes += " f{k}: no Godot bake;"
                    continue
                // the opaque pixels' box round the origin, within a couple of pixels
                let mlo, mhi = opaque_box(mf)
                let glo, ghi = opaque_box(t.frame)
                let dbox = max(magnitude(mlo - glo), magnitude(mhi - ghi))
                if dbox > 3.5: notes += " f{k}: box {mlo}..{mhi} vs {glo}..{ghi};"
                // sockets and tip
                let mr = get(mine_rigs, id + facing_suffix(k)) or jobj()
                let ms = gobj(mr, "sockets")
                let gs = gobj(t.rig, "sockets")
                for(gs.keys) name, n:
                    let mv = get(ms, name)
                    if mv: worst_sock = max(worst_sock, magnitude(v2(mv) - v2(gs.a[n])))
                    else: notes += " f{k}: no socket {name};"
                let mt = get(mr, "tip")
                let gt = get(t.rig, "tip")
                if mt and gt: worst_tip = max(worst_tip, magnitude(v2(mt) - v2(gt)))
                worst_px = max(worst_px, dbox)
            // (the tip only matters for what's held: a weapon couched by an armless body; within 2.5 units, a couple of px)
            let held = starts_with(id, "weapon.")
            if notes != "" and find_string(notes, "no Godot bake") >= 0 and worst_px == 0.0:
                print "SKIP {id}: Godot doesn\'t bake it this way (armour bakes on its wearer)"
                continue
            let ok = notes == "" and worst_sock < 0.15 and (not held or worst_tip < 2.5)
            if not ok: failed++
            print "{if ok: "PASS" else: "FAIL"} {id}: sizes/origins within {worst_px} px, sockets {worst_sock}, tip {worst_tip}{notes}"
        continue
    gl.clear(float4 { 0.36, 0.42, 0.3, 1.0 })
    gl.blend(1)
    // each part's facing (pick: the 4th argument after the ids? no: facing 0) pair, Lobster | Godot, in rows
    let z = 2.0
    var x = 10.0
    var y = 10.0
    var row_h = 0.0
    for(ids) id, j:
        if j * 8 >= mine_frames.length: break
        let mf = mine_frames[j * 8 + show_facing]
        let t = theirs[j * 8 + show_facing]
        if mf < 0 or t.frame < 0: continue
        let m = frames[mf]
        let g = frames[t.frame]
        let wpair = float(m.w + g.w) * z + 12.0
        let hpair = float(max(m.oy, g.oy) + max(m.h - m.oy, g.h - g.oy)) * z + 16.0
        if x + wpair > float(gl.window_size().x):
            x = 10.0
            y += row_h + 8.0
            row_h = 0.0
        let base_y = y + float(max(m.oy, g.oy)) * z
        b_sheet = -1
        sprite_xf(mf, [z, 0.0, 0.0, z, x + float(m.ox) * z, base_y], float4 { 1.0, 0.0, 1.0, 1.0 })
        flush_sprites()
        b_sheet = -1
        sprite_xf(t.frame, [z, 0.0, 0.0, z, x + float(m.w) * z + 6.0 + float(g.ox) * z, base_y], float4 { 1.0, 0.0, 1.0, 1.0 })
        flush_sprites()
        gl.set_shader("color")
        gl.color(float4_1):
            gl.translate(float2 { x, y + hpair - 14.0 }):
                gl.set_font_size(11)
                gl.text(id)
        x += wpair + 14.0
        row_h = max(row_h, hpair)
    if frame_n == 3:
        gl.screenshot(args[1])
        shot_done = true
print "{failed} failed"
