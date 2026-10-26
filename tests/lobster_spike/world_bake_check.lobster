// Props baked in Lobster (view/world_bake.lobster, from model/props.lobster and friends) against the library's
// Godot bakes of them (ArtKit's doodads: the same seeds): the opaque box round the anchor, the brightness and
// colour where both have pixels, and a picture of each pair (Lobster | Godot).
//   lobster world_bake_check.lobster -- <out.png>

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
import .view.world_bake

let args = command_line_arguments()
fatal(gl.window("world bake check", 1600, 1000, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(BAKE_SHADERS, true))
fatal(gl.load_materials(WORLD_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
lib_load("../../data")
load_pack("library")
bmat_matte = true

class Case:
    name:string
    shadow:bool
    reach:float

let cases = [
    Case { "rock0", true, 1.0 },
    Case { "rock3", true, 1.0 },
    Case { "reeds1", true, 1.0 },
    Case { "reeds2.2", true, 1.0 },
    Case { "bush0", true, 1.0 },
    Case { "quarry1", true, 1.0 },
    Case { "gold2", true, 1.0 },
    Case { "carcass0", true, 1.0 },
    Case { "tree_pine0", true, 2.0 },
    Case { "tree_broadleaf1", true, 2.0 },
    Case { "tree_swamp2", true, 2.0 },
    Case { "pile.wood.2", true, 1.0 },
    Case { "yard2", true, 1.0 },
    Case { "tether_post", true, 1.0 },
    Case { "stones1", false, 1.0 },
    Case { "tuft2", false, 1.0 },
    Case { "lily0", false, 1.0 },
    Case { "crops1", false, 1.0 },
]

// Each case's model, built as ArtKit builds that doodad (its seed: the kind's base + the variant).
def make_case(i:int) -> MNode:
    switch i:
        case 0: return boulders(1000)
        case 1: return boulders(1003)
        case 2: return reed_clump(301, 1.0, 0)
        case 3: return reed_clump(302, 1.0, 2)
        case 4: return bug_bush(400, 0)
        case 5: return quarry(1301, 0, "stone")
        case 6: return quarry(1302, 0, "gold")
        case 7: return carcass(1400, 0)
        case 8: return tree(1500, "pine", 0, 0)
        case 9: return tree(1501, "broadleaf", 0, 0)
        case 10: return tree(1502, "swamp", 1, 0)
        case 11: return pile("wood", 2, "a")
        case 12: return yard(2, 0)
        case 13: return tether_post()
        case 14: return field_stones(501)
        case 15: return grass_tuft(602)
        case 16: return lily_pads(900)
        case 17: return crops(1101)
        default: return mnode()

class Made:
    tex:resource<texture>
    w:int
    h:int
    anchor:float2
    px:string

let made = []::Made?
let sheet_px = dictionary<int, string>(16)

// A frame's pixels as RGBA bytes (read from its sheet once).
def frame_pixel(f:int, x:int, y:int) -> int, int, int, int:
    let fr = frames[f]
    var px = sheet_px.get(fr.sheet, "")
    if px == "":
        px = gl.read_texture(sheet_tex[fr.sheet]) or ""
        sheet_px.set(fr.sheet, px)
    let i = ((fr.y + y) * int(sheet_dims[fr.sheet].x) + fr.x + x) * 4
    return px[i], px[i + 1], px[i + 2], px[i + 3]

var frame_n = 0
var shot_done = false
var failed = 0
while gl.frame() and not shot_done:
    frame_n++
    if frame_n == 1:
        for(cases) c, ci:
            let f = frame_index(c.name)
            let sprite, w, h, anchor = world_bake(make_case(ci), c.shadow, c.reach)
            let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                                    float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
            made.push(Made { gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag), w, h, anchor, sprite })
            if f < 0:
                print "SKIP {c.name}: not in the library"
                continue
            // opaque boxes round the anchor, brightness and colour where both are opaque
            let g = frames[f]
            var mlo = float2_1 * 100000.0
            var mhi = float2_1 * -100000.0
            var glo = mlo
            var ghi = mhi
            var sum = 0.0
            var lm = 0.0
            var lg = 0.0
            var n = 0
            for(h) y:
                for(w) x:
                    if sprite[(y * w + x) * 4 + 3] == 255:
                        let p = float2 { float(x), float(y) } - anchor
                        mlo = min(mlo, p)
                        mhi = max(mhi, p)
                        let gx = int(float(x) - anchor.x + float(g.ox) + 0.5)
                        let gy = int(float(y) - anchor.y + float(g.oy) + 0.5)
                        if gx >= 0 and gy >= 0 and gx < g.w and gy < g.h:
                            let r, gg, b, a = frame_pixel(f, gx, gy)
                            if a == 255:
                                let mine = [sprite[(y * w + x) * 4], sprite[(y * w + x) * 4 + 1], sprite[(y * w + x) * 4 + 2]]
                                let theirs = [r, gg, b]
                                for(3) k:
                                    sum += abs(float(mine[k] - theirs[k]))
                                    lm += float(mine[k])
                                    lg += float(theirs[k])
                                n++
            for(g.h) y:
                for(g.w) x:
                    let _r, _g, _b, a = frame_pixel(f, x, y)
                    if a == 255:
                        let p = float2 { float(x - g.ox), float(y - g.oy) }
                        glo = min(glo, p)
                        ghi = max(ghi, p)
            let dbox = max(magnitude(mlo - glo), magnitude(mhi - ghi))
            let k3 = float(max(1, n * 3))
            let bright = abs(lm - lg) / k3
            let ok = dbox <= 3.5 and bright < 12.0
            if not ok: failed++
            print "{if ok: "PASS" else: "FAIL"} {c.name}: box within {dbox} px ({mlo}..{mhi} vs {glo}..{ghi}), colour {int(sum / k3)}, brightness {int(lm / k3)} vs {int(lg / k3)}"
        continue
    gl.clear(float4 { 0.36, 0.42, 0.3, 1.0 })
    gl.blend(1)
    let z = 2.0
    var x = 10.0
    var y = 10.0
    var row_h = 0.0
    for(cases) c, i:
        let mm = made[i]
        let f = frame_index(c.name)
        if not mm or f < 0: continue
        let m = mm
        let g = frames[f]
        let wpair = float(m.w + g.w) * z + 12.0
        let top = max(m.anchor.y, float(g.oy))
        let hpair = (top + max(float(m.h) - m.anchor.y, float(g.h - g.oy))) * z + 16.0
        if x + wpair > float(gl.window_size().x):
            x = 10.0
            y += row_h + 8.0
            row_h = 0.0
        let base_y = y + top * z
        let q = gl.new_mesh("PT", [float3 { 0.0, 0.0, 0.0 }, float3 { float(m.w), 0.0, 0.0 }, float3 { float(m.w), float(m.h), 0.0 }, float3 { 0.0, float(m.h), 0.0 }],
                            []::float4, []::float3, [float2 { 0.0, 0.0 }, float2 { 1.0, 0.0 }, float2 { 1.0, 1.0 }, float2 { 0.0, 1.0 }], []::float2, [0, 2, 1, 0, 3, 2])
        gl.set_mesh_texture(q, 0, 0, m.tex)
        gl.set_shader("textured")
        gl.translate(float2 { x, base_y - m.anchor.y * z }):
            gl.scale(z):
                gl.color(float4_1): gl.render_mesh(q)
        b_sheet = -1
        sprite_xf(f, [z, 0.0, 0.0, z, x + float(m.w) * z + 6.0 + float(g.ox) * z, base_y], float4 { 1.0, 0.0, 1.0, 1.0 })
        flush_sprites()
        gl.set_shader("color")
        gl.color(float4_1):
            gl.translate(float2 { x, y + hpair - 14.0 }):
                gl.set_font_size(11)
                gl.text(c.name)
        x += wpair + 14.0
        row_h = max(row_h, hpair)
    if frame_n == 3:
        gl.screenshot(args[0])
        shot_done = true
print "{failed} failed"
