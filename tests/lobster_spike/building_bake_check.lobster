// The buildings baked in Lobster (game/art_kit_buildings.lobster) against the library's Godot bakes of them (ArtKit's
// building looks, the same frame names): every frame of every look of each architecture asked for, the opaque box
// round the anchor (within 3 px) and the brightness where both have pixels (within 12 levels), and the building fx
// (chimney smoke, lantern, windows) against fx.txt's (within a pixel). Godot's bake viewport is 512 art px square
// (2048 / SS), 256 either side of the anchor and 291 above it: what it cut off (a town centre's scaffold, a castle's
// flag) is left out of the Lobster box too. Brightness only counts where 300+ pixels are shared (an early
// stage's scaffold poles are a few pixels wide: a pixel off and none overlap). Pictures of each pair (Lobster | Godot),
// failures first, then each look's body, a page a picture.
//   lobster building_bake_check.lobster -- <out prefix> [arch...]   (no archs: thatch junk stone tent reed mound)

import std
import vec
import color
import gl
import texture
import dictionary
import .gen.json
import .gen.rng
import .gen.sha256
import .gen.identity
import .gen.datalib
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
import .model.props
import .model.trees
import .model.town_props
import .model.bridges
import .model.build_mats
import .model.buildings
import .model.buildings2
import .view.world_bake
import .game.art_kit
import .game.art_kit_buildings

let args = command_line_arguments()
let out_prefix = args[0]
let archs = if args.length > 1: args.slice(1, -1) else: ["thatch", "junk", "stone", "tent", "reed", "mound"]
fatal(gl.window("building bake check", 1600, 1000, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(BAKE_SHADERS, true))
fatal(gl.load_materials(WORLD_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
lib_load("../../data")
load_pack("library")

// The library's frames and fx before the bake replaces them.
let godot_frame = dictionary<string, int>(4096)
for(frame_at.get_keys()) k: godot_frame.set(k, frame_at.get(k, -1))
let godot_fx = dictionary<string, BFx>(512)
for(bfx.get_keys()) k: godot_fx.set(k, bfx.get(k, BFx { float2_0, false, [] }))

class Pair:
    name:string
    godot:int
    mine:int
    ok:bool

let pairs = []::Pair
var failed = 0
var frame_n = 0
var page = 0
var shown = []::Pair

def in_archs(name:string) -> bool:
    let c = find_string(name, ":")
    return c > 0 and has_s(archs, name.substring(0, c))

let cached_sheet = [-1]
var cached_px = ""
def godot_px(f:int, x:int, y:int) -> string, int:   // frame f's sheet pixels and the offset of (x, y) in them
    let fr = frames[f]
    if fr.sheet != cached_sheet[0]:
        cached_px = gl.read_texture(sheet_tex[fr.sheet]) or ""
        cached_sheet[0] = fr.sheet
    return cached_px, ((fr.y + y) * int(sheet_dims[fr.sheet].x) + fr.x + x) * 4

while gl.frame():
    frame_n++
    if frame_n == 1:
        let t0 = seconds_elapsed()
        ak_rebake = true
        akb_keep_all = true
        let n = bake_buildings_for(archs)
        print "baked {n} frames in {int((seconds_elapsed() - t0) * 1000.0)} ms"
        // the frames, the library's sorted by sheet (one sheet's pixels read at a time)
        let names = filter(godot_frame.get_keys()) k: in_archs(k)
        insertion_sort(names) a, b: frames[godot_frame.get(a, 0)].sheet < frames[godot_frame.get(b, 0)].sheet
        let missing = []::string
        for(names) name:
            let g = godot_frame.get(name, -1)
            let m = frame_index(name)
            if m == g:
                missing.push(name)
                failed++
                continue
            let mf = frames[m]
            let mine = akb_px.get(name) or ""
            let gf = frames[g]
            var mlo = float2_1 * 100000.0
            var mhi = float2_1 * -100000.0
            var glo = mlo
            var ghi = mhi
            var lm = 0.0
            var lg = 0.0
            var cnt = 0
            for(mf.h) y:
                for(mf.w) x:
                    let i = (y * mf.w + x) * 4
                    let inside = x - mf.ox >= -256 and x - mf.ox < 256 and y - mf.oy >= -291 and y - mf.oy < 221
                    if mine[i + 3] == 255 and inside:
                        let p = float2 { float(x - mf.ox), float(y - mf.oy) }
                        mlo = min(mlo, p)
                        mhi = max(mhi, p)
                        let gx = x - mf.ox + gf.ox
                        let gy = y - mf.oy + gf.oy
                        if gx >= 0 and gy >= 0 and gx < gf.w and gy < gf.h:
                            let gp, j = godot_px(g, gx, gy)
                            if gp[j + 3] == 255:
                                for(3) k:
                                    lm += float(mine[i + k])
                                    lg += float(gp[j + k])
                                cnt++
            for(gf.h) y:
                for(gf.w) x:
                    let gp, j = godot_px(g, x, y)
                    if gp[j + 3] == 255:
                        let p = float2 { float(x - gf.ox), float(y - gf.oy) }
                        glo = min(glo, p)
                        ghi = max(ghi, p)
            let dbox = max(magnitude(mlo - glo), magnitude(mhi - ghi))
            let k3 = float(max(1, cnt * 3))
            let bright = abs(lm - lg) / k3
            let ok = dbox <= 3.5 and (bright < 12.0 or cnt < 300)
            if not ok: failed++
            pairs.push(Pair { name, g, m, ok })
            print "{if ok: "PASS" else: "FAIL"} {name}: box within {dbox} px ({mlo}..{mhi} vs {glo}..{ghi}), brightness {int(lm / k3)} vs {int(lg / k3)} over {cnt} px"
        for(missing) name: print "FAIL {name}: not baked"
        // the fx
        var fx_n = 0
        for(godot_fx.get_keys()) key:
            if in_archs(key):
                let g = godot_fx.get(key, BFx { float2_0, false, [] })
                let m = bfx.get(key)
                var err = ""
                if not m: err = "not made"
                else:
                    if m.has_smoke != g.has_smoke or (g.has_smoke and magnitude(m.smoke - g.smoke) * WB_ART > 1.0): err = "smoke {m.smoke} vs {g.smoke}"
                    if m.lights.length != g.lights.length: err += " {m.lights.length} lights vs {g.lights.length}"
                    else:
                        for(g.lights) l, i:
                            if magnitude(m.lights[i] - l) * WB_ART > 1.0: err += " light {i} {m.lights[i]} vs {l}"
                fx_n++
                if err != "":
                    failed++
                    print "FAIL fx {key}: {err}"
        print "fx: {fx_n} looks checked"
        // a wall tile composed with its arms (wall_look): east, south-east and west
        let wl = archs[0] + ":wall"
        let wb, wf = wall_look(wl, 1 | 2 | 16)
        let wfr = frames[wb]
        print "wall_look {wl} east+se+west: {wfr.w}x{wfr.h} anchor {wfr.ox},{wfr.oy}, front layer {if wf >= 0: "yes" else: "none"}"
        if wb < 0 or frames[frame_index(wl)].w > wfr.w: failed++
        // the pictures: failures first, then each look's body
        shown = filter(pairs): not _.ok
        for(pairs) p:
            if p.ok and looks.get(p.name): shown.push(p)
        print "{failed} failed"
        continue
    gl.clear(float4 { 0.36, 0.42, 0.3, 1.0 })
    gl.blend(1)
    let z = 1.0
    var x = 10.0
    var y = 10.0
    var row_h = 0.0
    var drawn = 0
    for(shown) p:
        let m = frames[p.mine]
        let g = frames[p.godot]
        let wpair = float(m.w + g.w) * z + 12.0
        let top = float(max(m.oy, g.oy))
        let hpair = (top + float(max(m.h - m.oy, g.h - g.oy))) * z + 16.0
        if x + wpair > float(gl.window_size().x):
            x = 10.0
            y += row_h + 8.0
            row_h = 0.0
        if y + hpair > float(gl.window_size().y): break
        let base_y = y + top * z
        b_sheet = -1
        sprite_xf(p.mine, [z, 0.0, 0.0, z, x, base_y - float(m.oy) * z], float4 { 1.0, 0.0, 1.0, 1.0 })
        flush_sprites()
        b_sheet = -1
        sprite_xf(p.godot, [z, 0.0, 0.0, z, x + float(m.w) * z + 6.0, base_y - float(g.oy) * z], float4 { 1.0, 0.0, 1.0, 1.0 })
        flush_sprites()
        gl.set_shader("color")
        gl.color(if p.ok: float4_1 else: float4 { 1.0, 0.3, 0.3, 1.0 }):
            gl.translate(float2 { x, y + hpair - 14.0 }):
                gl.set_font_size(11)
                gl.text(p.name)
        x += wpair + 14.0
        row_h = max(row_h, hpair)
        drawn++
    if frame_n % 2 == 0:
        gl.screenshot("{out_prefix}{page}.png")
        print "page {page}: {drawn} pairs"
        page++
        shown = shown.slice(drawn, -1)
        if not shown.length or drawn == 0 or page >= 12: break
print "{failed} failed"
