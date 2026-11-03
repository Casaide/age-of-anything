// ------------------------------------------------------------------ the front end (scenes/match_setup.gd, race_lab.gd, match_loader.gd,
// src/view/ui/saves_page.gd, net_page.gd, trait_strip.gd, ui_banner.gd)
// The title screen (the two rolled armies facing each other on a hill under the title; battle the AI, play on
// the network, load a game, the Race Lab, quit) leads to the battle setup: a side panel per player in its race's
// culture (frame, crest, banner with the race's name, its army idling on a lit stage, dice and prompt, the roster
// as its lines' names with every line age by age on hover, one line of bonuses, lacks and notes with the lists on
// hover), a cast "vs" in the middle, the map card, the AI's level and Start. A map with more than two starts is a
// team game: a panel per player, you and an AI ally against two AIs, each with its dice, prompt and AI level. Each
// banner's Tech tree opens that race's page (game/techtree.lobster). Laid out at 1600 x 950 and scaled to fill the
// window (fixed sizes: nothing moves when a race changes). The pages are immediate mode on the UI layer
// (game/ui.lobster); a pad walks them by focus (ui_frame), X rolls the focused panel's dice, Start starts, B goes back.
// run_front returns what was chosen: "play", "host", "join", "load:<path>", or "" (quit). Imported by game.lobster
// after the lobby's helpers (roster_views, balance_for_match).

let FE_DESIGN = float2 { 1600.0, 950.0 }
let FE_UNIT_INCHES = 0.6                            // the setup page's stage: a unit for each this much of its width on the screen
let FE_GRASS = float4 { 0.306, 0.431, 0.165, 1.0 }  // #4e6e2a
let FE_LEVELS = [ "Easy", "Normal", "Hard" ]
let FE_NOT_MAPS = [ "choke_test", "river_test", "hill_test" ]  // test maps (the debug view lists them)
let FE_STAGE_ROLES = [ "spear", "infantry", "archer", "large", "skirmisher", "worker", "catapult", "healer" ]
let FE_BAKE_AFTER = 0.6                             // seconds of no typing before a side's army is made again
let FE_RULES = [ "default", "bronze", "anything" ]  // the Race Lab's rules
let FE_TRAIT_COLS = [ float4 { 0.66, 0.85, 0.47, 1.0 }, float4 { 0.95, 0.79, 0.3, 1.0 }, float4 { 0.91, 0.54, 0.44, 1.0 }, float4 { 0.95, 0.79, 0.3, 1.0 }, float4 { 0.85, 0.78, 0.63, 1.0 } ]
let FE_STRUCK = float4 { 0.91, 0.54, 0.44, 1.0 }  // #e88a70: a lacked line

class FeSide:
    typed = ""   // what's in the box
    rolled = ""  // what the dice rolled (shown when the box is empty)
    reroll = 0
    level = 0  // the AI's level (FE_LEVELS)
    team = 0
    race:JV
    gen = 0  // bumped by each new race; its army is made once typing stops
    views_gen = -1
    views_bake = -1  // bake_gen when its views were made (made again when wanted parts are baked)
    dirty_at = -1.0
    views:[UV] = []  // the few the stage shows (fe_stage_pick)
    picks:[JV] = []
    traits:[[string]] = []  // per group (bonuses, own research, lacks, heroes, notes): its lines

class FeTrait:
    title:string
    one:string

let FE_TRAITS = [ FeTrait { "Bonuses", "bonus" }, FeTrait { "Own research", "own research" }, FeTrait { "Lacks", "lack" }, FeTrait { "Heroes", "hero" }, FeTrait { "Notes", "note" } ]

var fe_sides = []::FeSide
var fe_page = "title"  // title, setup, lab, saves, net
var fe_back = "title"  // where the saves and network pages go back to
var fe_k = 1.0         // screen px per design px
var fe_w = 1600.0      // the window's width in design px
var fe_field = -1      // the box that has the keyboard: a side (0..3), 10 + a lab side, 20 the address; -1 none
var fe_maps = []::string
var fe_map_k = 0
var fe_map_json = jobj()
var fe_mode_k = 0
var fe_modes = []::[string]  // id, name, desc
var fe_rules = jobj()
var fe_tip_lines = []::string  // the hover card this frame
var fe_hosting = false         // the battle setup is for hosting a network game
var fe_note = ""               // a line at the foot (the saves page, the network page)
var fe_frames = 0
var fe_pad = false  // the pad was used last (its hints shown)
var fe_hosts = []::LanHost
var fe_scanned = false
var fe_address = "127.0.0.1"
var fe_lab_rules = 0
let fe_lab_scroll = [ 0.0, 0.0 ]
var fe_lab_views = [ []::UV, []::UV ]
let fe_lab_gen = [ -1, -1 ]
let fe_lab_bake = [ -1, -1 ]  // bake_gen when the lab's views were made

// The lobby's views let go (a view's tree is a cycle: parent and kids, freed only by free_tree).
def fe_free_views():
    for(fe_sides) s:
        uv_free_all(s.views)
        s.views = []
    for(fe_lab_views) vs: uv_free_all(vs)
    fe_lab_views = [ []::UV, []::UV ]
var fe_test_lines = []::string
var fe_tip_k = 0
var fe_tip_t = 0.0
var fe_tips = []::string
var loop_round = 0  // (tests: lobbyloop's matches so far)

// ---- layout

def fe_trim(s:string) -> string:
    let t = tokenize(s, "\n", " \t")
    return if t.length: t[0] else: ""

def fe_fit():
    let ws = float(gl.window_size())
    fe_k = ws.y / FE_DESIGN.y
    if ws.x / fe_k < FE_DESIGN.x: fe_k = ws.x / FE_DESIGN.x
    fe_w = ws.x / fe_k

def D(x:float, y:float) -> float2: return float2 { x, y } * fe_k
def fz(n:float) -> int: return max(8, int(n * fe_k + 0.5))
def fe_over(at:float2, size:float2) -> bool:
    let m = float(gl.mouse_pos(0))
    return m.x >= at.x and m.y >= at.y and m.x <= at.x + size.x and m.y <= at.y + size.y

// ---- pieces of the look

// A dark table under everything: wood, darkening to the corners.
def fe_backdrop():
    let ws = float(gl.window_size())
    ui_paint(float2_0, ws, float4 { 0.165, 0.11, 0.07, 1.0 }, "wood")
    ui_radial(float2_0, ws, float2 { 0.5, 0.42 }, float2 { 0.8, 0.9 }, float4 { 0.0, 0.0, 0.0, 0.15 }, float4 { 0.0, 0.0, 0.0, 0.8 })

// A framed panel of a look, its crest on the top edge (theme.gd's CrestFrame).
def fe_panel(at:float2, size:float2, lk:UiLook, crest:bool):
    ui_use(lk)
    ui_box(at, size, 1, lk.face, true)
    if crest: tb_icon_wide("crest_" + lk.ornament, float2 { at.x + size.x / 2.0, at.y + 2.0 * fe_k }, 34.0 * fe_k)

// The sunk well (a stage, the map, a box to type in).
def fe_well(at:float2, size:float2): ui_box(at, size, -1, ui_look.well, false)

// A side's colour as a small cut gem.
def fe_gem(c:float2, r:float, col:float4):
    let dark = col * float4 { 0.75, 0.75, 0.75, 1.0 }
    let lit = col + (float4_1 - col) * 0.15
    let pts = [ c + float2 { 0.0, -r }, c + float2 { r, 0.0 }, c + float2 { 0.0, r }, c + float2 { -r, 0.0 } ]
    ui_paint_poly(pts, [ dark, dark, dark, dark ], [ 0, 1, 2, 0, 2, 3 ], ui_material("lacquer"))
    ui_paint_poly([ pts[0], pts[1], c, pts[3] ], [ lit, lit, lit, lit ], [ 0, 1, 2, 0, 2, 3 ], ui_material("lacquer"))
    for(4) k: ui_line(pts[k], pts[(k + 1) % 4], 1.2, float4 { 0.0, 0.0, 0.0, 0.7 })

// The cast "vs": a lacquered medallion in a bronze rim.
def fe_medallion(c:float2, r:float):
    let lk = ui_look_of("")
    ui_batch_flush()
    gl.set_shader("color")
    gl.color(float4 { 0.0, 0.0, 0.0, 0.45 }): gl.translate(c + float2 { 2.0, 4.0 } * fe_k): gl.circle(r * 1.04, 40)
    gl.color(lk.metal): gl.translate(c): gl.circle(r, 40)
    gl.color(lk.metal * float4 { 0.6, 0.6, 0.6, 1.0 }): gl.translate(c): gl.circle(r * 0.9, 40)
    gl.color(float4 { 0.42, 0.12, 0.07, 1.0 }): gl.translate(c): gl.circle(r * 0.84, 40)
    gl.color(float4 { 0.55, 0.18, 0.1, 1.0 }): gl.translate(c - float2_1 * r * 0.08): gl.circle(r * 0.7, 40)
    ui_text_c(c.x, c.y - 30.0 * fe_k, "VS", fz(46.0), lk.title, 2, 2.0 * fe_k)

// A race's banner (src/view/ui/ui_banner.gd): cloth in the culture's colour hanging from a rod, cut to the culture's
// shape, with soft folds, light from above, a hem in the side's team colour and a shadow.
def fe_banner_cut(at:float2, size:float2, shape:string, tail:float) -> [float2]:
    // the lower edge, right to left (the top edge is straight)
    let x0 = at.x
    let x1 = at.x + size.x
    let yb = at.y + size.y
    let w = size.x
    let out = []::float2
    if shape == "swallowtail": return [ float2 { x1, yb }, float2 { x0 + w * 0.5, yb - tail }, float2 { x0, yb } ]
    if shape == "pointed": return [ float2 { x1, yb - tail }, float2 { x0 + w * 0.5, yb }, float2 { x0, yb - tail } ]
    if shape == "notched":
        out.push(float2 { x1, yb })
        for([ 0.72, 0.28 ]) kk:
            let cx = x0 + w * kk
            for([ float2 { cx + tail * 0.6, yb }, float2 { cx, yb - tail * 0.8 }, float2 { cx - tail * 0.6, yb } ]) p: out.push(p)
        out.push(float2 { x0, yb })
        return out
    if shape == "tongues":
        let n = 3
        out.push(float2 { x1, yb })
        var k = n
        while k > 0:
            let a = x0 + w * float(k) / float(n)
            let b = x0 + w * float(k - 1) / float(n)
            out.push(float2 { a - w / float(n) * 0.12, yb - tail })
            out.push(float2 { b + w / float(n) * 0.5, yb })
            if k > 1: out.push(float2 { b + w / float(n) * 0.12, yb - tail })
            k--
        out.push(float2 { x0, yb })
        return out
    if shape == "ragged":
        let steps = max(2, int(w / (18.0 * fe_k)))
        var k = steps
        while k >= 0:
            let h = fraction(abs(sin(float(k) * 12.9898 * 57.29578 + 4.1 * 57.29578) * 43758.5453))
            out.push(float2 { x0 + w * float(k) / float(steps), yb - tail * 0.15 - tail * 0.7 * h * (if k == 0 or k == steps: 0.0 else: 1.0) })
            k--
        return out
    if shape == "scalloped":
        let bumps = max(4, int(w / (60.0 * fe_k)))
        out.push(float2 { x1, yb - tail * 0.5 })
        var k = bumps
        while k > 0:
            let a = x0 + w * float(k) / float(bumps)
            let b = x0 + w * float(k - 1) / float(bumps)
            for(8) s:
                let t = float(s + 1) / 8.0
                out.push(float2 { a + (b - a) * t, yb - tail * 0.5 + sin(t * 180.0) * tail * 0.5 })
            k--
        return out
    let lift = if shape == "fringe": tail * 0.4 else: 0.0
    return [ float2 { x1, yb - lift }, float2 { x0, yb - lift } ]

def fe_banner(at:float2, size:float2, lk:UiLook, team:float4, tail_d:float):
    let rod_w = 7.0 * fe_k
    let top = at.y + rod_w * 0.5
    let tail = tail_d * fe_k
    let low = fe_banner_cut(at, size, lk.banner, tail)
    // the cloth as quads from the top edge down to each run of the cut (the cuts run right to left, x falling)
    def cloth(off:float2, cols:float4, kind:int):
        let pts = []::float2
        let idx = []::int
        for(low) p, k:
            pts.push(float2 { p.x, top } + off)
            pts.push(p + off)
            if k > 0:
                let a = (k - 1) * 2
                for([ a, a + 2, a + 1, a + 1, a + 2, a + 3 ]) q: idx.push(q)
        ui_paint_poly(pts, map(pts): cols, idx, kind)
    cloth(float2 { 5.0, 7.0 } * fe_k * 0.6, float4 { 0.0, 0.0, 0.0, 0.35 }, ui_material("felt"))
    let lum = lk.cloth.x * 0.3 + lk.cloth.y * 0.59 + lk.cloth.z * 0.11
    let tint = if lum > 0.4: 0.4 / lum + 0.1 else: 1.0
    cloth(float2_0, float4 { lk.cloth.x * tint, lk.cloth.y * tint, lk.cloth.z * tint, 1.0 }, ui_material("felt"))
    // folds: soft upright bands of light and shade, light from above
    let folds = max(3, int(size.x / (70.0 * fe_k)))
    for(folds * 2) k:
        let a = at.x + size.x * float(k) / float(folds * 2)
        let b = at.x + size.x * float(k + 1) / float(folds * 2)
        var yb = at.y + size.y
        for(low) p:
            if p.x >= a and p.x <= b: yb = min(yb, p.y)
        let c = if k % 2 == 0: float4 { 1.0, 0.95, 0.85, 0.07 } else: float4 { 0.0, 0.0, 0.0, 0.13 }
        ui_shade(float2 { a, top }, float2 { b - a, max(0.0, yb - top - tail * 0.3) }, 6, 1) u, v: float4 { c.x, c.y, c.z, c.w * sin(u * 180.0) }
    ui_shade(float2 { at.x, top }, float2 { size.x, 16.0 * fe_k }, 1, 4) u, v: float4 { 0.0, 0.0, 0.0, 0.45 * (1.0 - v) }
    // the hem in the team colour, along the cut
    for(low) p, k:
        if k > 0:
            let a = low[k - 1] - float2 { 0.0, 7.0 * fe_k }
            let b = p - float2 { 0.0, 7.0 * fe_k }
            ui_line(a, b, 5.0 * fe_k * 0.6, float4 { 0.0, 0.0, 0.0, 0.35 })
            ui_line(a, b, 3.0 * fe_k * 0.6, team)
            ui_line(low[k - 1], p, 1.2, float4 { 0.0, 0.0, 0.0, 0.6 })
    if lk.banner == "fringe":
        var x = at.x + 3.0 * fe_k
        let yb = low[0].y
        while x < at.x + size.x - 2.0 * fe_k:
            ui_line(float2 { x, yb }, float2 { x + 0.5, yb + tail * 0.4 }, 1.6 * fe_k * 0.6, lk.metal)
            x += 4.0 * fe_k
    // the rod across the top, a finial at each end
    let ra = float2 { at.x - 12.0 * fe_k, top }
    let rb = float2 { at.x + size.x + 12.0 * fe_k, top }
    ui_line(ra + float2 { 0.0, 2.0 * fe_k }, rb + float2 { 0.0, 2.0 * fe_k }, rod_w, float4 { 0.0, 0.0, 0.0, 0.5 })
    ui_line(ra, rb, rod_w, lk.metal * float4 { 0.75, 0.75, 0.75, 1.0 })
    ui_line(ra - float2 { 0.0, rod_w * 0.22 }, rb - float2 { 0.0, rod_w * 0.22 }, rod_w * 0.3, lk.metal + (float4_1 - lk.metal) * 0.25)
    for([ ra, rb ]) p: ui_stud(p, rod_w * 0.9, lk.metal)

// A toggle (the AI's level): a button, the lit one outlined in the accent.
def fe_toggle(at:float2, size:float2, label:string, on:bool) -> bool:
    let hit = ui_button(at, size, label, false)
    if on:
        ui_outline(at + float2_1 * 3.0 * fe_k, size - float2_1 * 6.0 * fe_k, 2.0 * fe_k, ui_look.accent)
        ui_fill(at + float2_1 * 5.0 * fe_k, size - float2_1 * 10.0 * fe_k, float4 { ui_look.accent.x, ui_look.accent.y, ui_look.accent.z, 0.12 })
    return hit

// The dice: a button with the die on it.
def fe_dice(at:float2, side:float) -> bool:
    let hit = ui_button(at, float2_1 * side, "", false)
    tb_icon("dice", at + float2_1 * side * 0.22, side * 0.56, 1.0)
    return hit

// A box to type in: click it to type there. Shows the placeholder when empty.
def fe_box(id:int, at:float2, size:float2, text:string, placeholder:string, fs:int, centred:bool):
    fe_well(at, size)
    if fe_field == id: ui_outline(at + float2_1 * 2.0, size - float2_1 * 4.0, 2.0 * fe_k, float4 { ui_look.accent.x, ui_look.accent.y, ui_look.accent.z, 0.6 })
    if gl.button("mouse1") == 1 and fe_over(at, size): fe_focus(id, text)
    let caret = if fe_field == id and (int(seconds_elapsed() * 2.0) % 2) == 0: "|" else: ""
    let s = if text == "": placeholder else: text + caret  // (empty: the placeholder stays, the caret before it)
    let col = if text == "": ui_look.dim else: ui_look.text
    var f = fs
    while f > 10 and ui_text_wf(s, f, 0) > size.x - 28.0 * fe_k: f -= 2
    let y = at.y + (size.y - float(f)) / 2.0 - 2.0 * fe_k
    let x = if centred: at.x + (size.x - ui_text_wf(s, f, 0)) / 2.0 else: at.x + 14.0 * fe_k
    ui_text(float2 { x, y }, s, f, col)
    if text == "" and caret != "": ui_text(float2 { x - ui_text_wf(caret, f, 0) - 2.0 * fe_k, y }, caret, f, ui_look.text)

// The text in the box that has the keyboard.
def fe_field_text() -> string:
    if fe_field >= 0 and fe_field < 4 and fe_field < fe_sides.length: return fe_sides[fe_field].typed
    if fe_field >= 10 and fe_field < 12: return fe_sides[fe_field - 10].typed
    if fe_field == 20: return fe_address
    return ""

def fe_focus(id:int, text:string):
    fe_field = id
    gl.set_text_input(text)

// Words wrapped to a width (about: the text's measure is a guess).
def fe_wrap(s:string, size:int, w:float) -> [string]:
    let out = []::string
    var line = ""
    for(tokenize(s, " ", "")) word:
        let next = if line == "": word else: line + " " + word
        if line != "" and ui_text_w(next, size) > w:
            out.push(line)
            line = word
        else: line = next
    if line != "": out.push(line)
    return out

// The hover card: drawn last, over everything.
def fe_tip(rows:[string]): fe_tip_lines = rows

def fe_draw_tip():
    if not fe_tip_lines.length: return
    ui_flush()  // (what's under it first)
    let fs = fz(15.0)
    var w = 0.0
    for(fe_tip_lines) l: w = max(w, ui_text_w(l, fs))
    let size = float2 { w + 36.0 * fe_k, float(fe_tip_lines.length) * float(fs) * 1.35 + 26.0 * fe_k }
    let ws = float(gl.window_size())
    let m = float(gl.mouse_pos(0))
    var at = m + float2 { 18.0, 22.0 } * fe_k
    if at.x + size.x > ws.x - 8.0: at.x = max(8.0, ws.x - 8.0 - size.x)
    if at.y + size.y > ws.y - 8.0: at.y = max(8.0, m.y - size.y - 12.0 * fe_k)
    ui_box(at, size, 1, ui_look.well * float4 { 1.6, 1.6, 1.6, 1.0 }, false)
    for(fe_tip_lines) l, k:
        ui_text(at + float2 { 18.0 * fe_k, 12.0 * fe_k + float(k) * float(fs) * 1.35 }, l, fs, if k == 0: ui_look.title else: ui_look.text)
    fe_tip_lines = []

// ---- maps and modes

def fe_load_maps():
    let ids = filter(map_ids()) m: not has_s(FE_NOT_MAPS, m)
    fe_maps = append(filter(ids) m: find_string(m, "test") < 0, filter(ids) m: find_string(m, "test") >= 0)
    let d = at(load_json(lib_root + "/modes.json"), "modes")
    fe_modes = map(d.keys) id: [ id, gstr(at(d, id), "name", id), gstr(at(d, id), "desc", "") ]
    fe_tips = map(glist(load_json(lib_root + "/tips.json"), "tips")) t: as_str(t)

let fe_map_meshes = dictionary<string, resource<mesh>>(16)

// The map as a small isometric diamond, coloured from data/terrain.json, the starts in gold; 1 unit = a tile's half width.
def fe_map_mesh(id:string, m:JV) -> resource<mesh>:
    let had = fe_map_meshes.get(id)
    if had: return had
    let terr = at(load_json(lib_root + "/terrain.json"), "terrain")
    let w = gint(m, "width", 1)
    let h = gint(m, "height", 1)
    let legend = gobj(m, "legend")
    let rows = glist(m, "rows")
    let tcol = dictionary<string, float4>(32)
    for(terr.keys) t: tcol.set(t, hex4(gstr(at(terr, t), "colour", "#4e6e2a")))
    let pos = []::float3
    let cols = []::float4
    let idx = []::int
    def quad(c:float2, r:float2, col:float4):
        let n = pos.length
        for([ float2 { 0.0, -r.y }, float2 { r.x, 0.0 }, float2 { 0.0, r.y }, float2 { -r.x, 0.0 } ]) d:
            pos.push(float3 { c.x + d.x, c.y + d.y, 0.0 })
            cols.push(col)
        for([ 0, 1, 2, 0, 2, 3 ]) q: idx.push(n + q)
    for(h) y:
        let row = as_str(rows[y])
        for(w) x:
            let ch = row.substring(x, 1)
            let t = gstr(legend, ch, "grass")
            quad(float2 { float(x - y + h), float(x + y + 1) * 0.5 }, float2 { 1.0, 0.5 }, tcol.get(t, FE_GRASS))
    for(glist(m, "starts")) s:
        let sx = as_int(s.a[0])
        let sy = as_int(s.a[1])
        quad(float2 { float(sx - sy + h), float(sx + sy + 1) * 0.5 }, float2 { 2.2, 1.4 }, float4 { 0.95, 0.79, 0.3, 1.0 })
    let mesh = gl.new_mesh("PC", pos, cols, []::float3, []::float2, []::float2, idx)
    fe_map_meshes.set(id, mesh)
    return mesh

// The map's picture fitted into a box (its diamond as wide as the box).
def fe_draw_map(at:float2, size:float2, id:string, m:JV):
    let w = gint(m, "width", 1)
    let h = gint(m, "height", 1)
    let s = min(size.x / float(w + h), size.y * 2.0 / float(w + h + 1))
    let off = at + (size - float2 { float(w + h), float(w + h) * 0.5 } * s) / 2.0
    ui_batch_flush()
    gl.set_shader("color_attr")
    gl.translate(off):
        gl.scale(s):
            gl.render_mesh(fe_map_mesh(id, m))
    gl.set_shader("color")

def fe_team_of(i:int, n:int) -> int:
    let mteams = glist(fe_map_json, "teams")
    if i < mteams.length: return as_int(mteams[i])
    return if n <= 2: i elif i < n / 2: 0 else: 1

def fe_set_map(k:int):
    fe_map_k = (k + fe_maps.length) % fe_maps.length
    fe_map_json = load_json(lib_root + "/maps/" + fe_maps[fe_map_k] + ".json")
    lobby_map = fe_maps[fe_map_k]
    let n = glist(fe_map_json, "starts").length
    if n != fe_sides.length: fe_build_sides(n)

// ---- the sides

// A panel per player; what was typed, rolled and picked carries over when the map changes; new players are rolled.
def fe_build_sides(n:int):
    let keep = fe_sides
    for(keep) s, i:
        if i >= n: uv_free_all(s.views)
    fe_sides = map(n) i:
        if i < keep.length: keep[i] else: FeSide { race: jobj() }
    for(fe_sides) s, i:
        s.team = fe_team_of(i, n)
        if i >= keep.length: fe_roll(i)

// The words a side's race comes from: what's typed, else what the dice rolled.
def fe_prompt(i:int) -> string:
    let s = fe_sides[i]
    let typed = s.typed.fe_trim()
    return if typed != "": typed else: s.rolled

// The dice: with the box empty, a new race from random words; with words typed, another roll of those words.
// Lobby-only randomness: the match gets the words and the roll, as ever.
def fe_roll(i:int):
    let s = fe_sides[i]
    if s.typed.fe_trim() != "": s.reroll++
    else:
        s.rolled = fe_random_words()
        s.reroll = rnd(4)
    fe_regen(i)

// A race's worth of words from the lexicon: maybe a culture, a creature, maybe "with" some kit.
def fe_random_words() -> string:
    let creatures = []::string
    let cultures = []::string
    let kit = []::string
    for(lib_lexicon.keys) w, n:
        let e = lib_lexicon.a[n]
        if has(e, "creature") and ends_with(w, "s") and gbool(gobj(lib_creatures, gstr(e, "creature", "")), "playable", false): creatures.push(w)
        elif has(e, "family") and not has(e, "creature"): cultures.push(w)
        elif e.keys.length == 1 and has(e, "tags"): kit.push(w)
    let cr = sorted_strs(creatures)
    let cu = sorted_strs(cultures)
    let ki = sorted_strs(kit)
    let words = []::string
    if rnd(3) != 0 and cu.length: words.push(cu[rnd(cu.length)])
    words.push(cr[rnd(cr.length)])
    if rnd(2) == 0 and ki.length: words.push("with " + ki[rnd(ki.length)])
    return concat_string(words, " ")

// A prompt changed: the name, roster and traits at once (generation is instant), the army once typing stops.
def fe_regen(i:int):
    let s = fe_sides[i]
    let race = generate(fe_prompt(i), fe_rules, s.reroll)
    s.race = race
    s.gen++
    s.dirty_at = seconds_elapsed()
    let words = race_words_of(race, identity_of(rstr(race, "creature"), rstr(race, "family")), fe_rules)
    s.traits = [ words.bonuses, words.own, words.lacks,
                 map(glist(race, "heroes")) h: "{gstr(h, "name", "?")}: {gstr(h, "temper", "")} ({gstr(h, "aura", "")})",
                 map(glist(race, "notes")) n: as_str(n) ]

// The few that show off a race on the stage, a line each, in this order while there's room.
def fe_stage_pick(units:[JV], room:int) -> [JV]:
    let out = []::JV
    for(FE_STAGE_ROLES) role:
        if out.length < clamp(room, 3, 6):
            var found = false
            for(units) u:
                if not found and gstr(at(u, "recipe"), "role", "") == role:
                    out.push(u)
                    found = true
    return out

def fe_view(u:JV, p:int, right:bool) -> UV:
    let tc = team_rgb[p % team_rgb.length]
    let v = uv_new()  // (parts not baked yet are wanted as it's drawn: baked between frames, then the view made again)
    uv_build(v, at(u, "recipe"), float3 { tc.x, tc.y, tc.z }, 20)
    v.node.scl = float2_1 * 0.85
    v.pose_steps = 8
    v.art_px = ART_SCALE
    face_vec(v, float2 { if right: -1.0 else: 1.0, 0.45 })
    return v

// Bake and stand up a side's stage army once its race has settled (no typing for a moment).
def fe_muster(now:float):
    for(fe_sides) s, i:
        if s.views_gen != s.gen and now - s.dirty_at > FE_BAKE_AFTER:
            s.picks = fe_stage_pick(glist(s.race, "units"), 6)
            bake_what = "the army of " + rstr(s.race, "name")
            uv_free_all(s.views)
            s.views = map(s.picks) u: fe_view(u, i, s.team != fe_sides[0].team or (fe_sides.length == 2 and i == 1))
            s.views_gen = s.gen
            s.views_bake = bake_gen
            return                                             // (one a frame)
        if s.views_gen == s.gen and s.views_bake != bake_gen:  // (its parts baked since: on their rigs now)
            uv_free_all(s.views)
            s.views = map(s.picks) u: fe_view(u, i, s.team != fe_sides[0].team or (fe_sides.length == 2 and i == 1))
            s.views_bake = bake_gen

// Units at screen spots (their feet), z screen px per canvas px, drawn back to front.
def fe_draw_units(vs:[UV], spots:[float2], z:float, p:int, alpha:float, dt:float):
    let tc = team_rgb[p % team_rgb.length]
    let order = map(vs.length) k: k
    insertion_sort(order) a, b: spots[a].y < spots[b].y
    b_sheet = -1
    for(order) k:
        let v = vs[k]
        v.node.pos = float2_0
        uv_process(v, dt)
        let screen = [ 1.5 * z, 0.0, 0.0, 1.5 * z, spots[k].x, spots[k].y ]
        let ds = draw_list(v, ID_XF)
        let fs = map(ds) d: frame_index("p:" + d.key)
        if (find(ds) d: not bakes.get(d.key)) < 0:  // (a unit shows once all its parts are baked: not a weapon on its own)
            for(ds) d, n:
                if fs[n] >= 0: sprite_xf(fs[n], xf_mul(screen, d.xf), float4 { tc.x, tc.y, tc.z, d.alpha * alpha })  // (none: hidden from here)
    flush_sprites()

// The roster in words: each line's name, the creature's noun left off when most share it; a line the race lacks
// struck through (as the tech tree page crosses it out) and not counted. Returns the words and which are struck.
def fe_lacks(race:JV, slot:string) -> bool:
    let ident = identity_of(rstr(race, "creature"), rstr(race, "family"))
    return race_lacks(ident, slot) or has_s(gstrs(race, "lacks"), slot)

def fe_lines(race:JV) -> [string], [bool], string:
    let units = filter(glist(race, "units")) u: rstr(at(u, "recipe"), "slot") != "hero"
    let count = dictionary<string, int>(64)
    for(units) u:
        for(tokenize(rstr(at(u, "recipe"), "name"), " ", "")) w:
            if w.length > 2: count.set(w, count.get(w, 0) + 1)
    var common = ""
    for(sorted_strs(count.get_keys())) w:
        if count.get(w, 0) * 2 >= units.length and (common == "" or count.get(w, 0) > count.get(common, 0)): common = w
    let names = []::string
    let struck = []::bool
    var have = 0
    for(units) u:
        let r = at(u, "recipe")
        let words = filter(tokenize(rstr(r, "name"), " ", "")) w: w != common
        names.push(if words.length: concat_string(words, " ") else: rstr(r, "name"))
        let lack = fe_lacks(race, rstr(r, "slot"))
        struck.push(lack)
        if not lack: have++
    let heroes = glist(race, "units").length - units.length
    return names, struck, "{have} lines: " + (if heroes > 1: "; {heroes} heroes" elif heroes == 1: "; a hero" else: "")

// Why a race has no such line, from whichever of its creature and culture lacks it.
def fe_lack_reason(race:JV, slot:string) -> string:
    if not fe_lacks(race, slot): return ""
    let blds = at(load_json(lib_root + "/buildings.json"), "buildings")
    let cr = creature(rstr(race, "creature"))
    let fam = family(rstr(race, "family"))
    let srcs = [ cr, fam ]
    let who = [ gstr(cr, "plural", "They"), capitalize(rstr(race, "family")) + " folk" ]
    for(srcs) src, k:
        for(gstrs(src, "lacks")) id:
            if id == slot: return "{who[k]} have no such line"
            if has(blds, id) and has_s(gstrs(at(blds, id), "trains"), slot): return "{who[k]} have no {gstr(at(blds, id), "name", id)}"
    return "not in this race\'s tree"

// The roster on hover: every line, age by age.
def fe_lines_card(race:JV) -> [string]:
    let rows = [ "{rstr(race, "name")}: every line" ]
    for(glist(race, "units")) u:
        let r = at(u, "recipe")
        let why = fe_lack_reason(race, rstr(r, "slot"))
        if why != "": rows.push("{rstr(r, "name")}: not in this race\'s tree ({why})")
        elif rstr(r, "slot") == "hero": rows.push("Hero: {rstr(r, "name")} (age {gint(r, "tier", 1)}, Town Center)")
        else:
            let steps = glist(u, "line")
            rows.push(if steps.length: concat_string(map(steps) l: "{rstr(at(l, "recipe"), "name")} (age {gint(l, "age", gint(r, "tier", 1))})", " > ") else: "{rstr(r, "name")} (age {gint(r, "tier", 1)})")
    rows.push("")
    rows.push("Tech tree: every line\'s research and buildings")
    return rows

// The tech tree page for a side's race (over the lobby until Esc or B).
def fe_open_tree(i:int):
    let race = fe_sides[i].race
    let ident = identity_of(rstr(race, "creature"), rstr(race, "family"))
    tree_page = build_tree_of(race, ident, fe_rules)
    tree_words = race_words_of(race, ident, fe_rules)
    tree_title = rstr(race, "name")
    tree_lobby = true
    tree_open = true
    tree_scroll = 0.0

// ---- the side panel

// The roster's words, wrapped to `nlines` lines in a width, struck where lacked; the whole list on hover.
def fe_roster_text(race:JV, at:float2, w:float, nlines:int, fs:int):
    let names, struck, tail = fe_lines(race)
    let head = substring(tail, 0, find_string(tail, ":") + 2)
    let rest = substring(tail, head.length, tail.length - head.length)
    var x = at.x
    var y = at.y
    var line = 0
    let lh = float(fs) * 1.3
    def put(s:string, col:float4, strike:bool):
        let sw = ui_text_wf(s, fs, 0)
        if x + sw > at.x + w and x > at.x:
            line++
            x = at.x
            y += lh
        if line < nlines:
            ui_text(float2 { x, y }, s, fs, col)
            if strike: ui_fill(float2 { x, y + float(fs) * 0.62 }, float2 { ui_text_wf(s, fs, 0) - ui_text_wf(", ", fs, 0), max(1.0, 1.5 * fe_k) }, col)
        x += sw
    put(head, ui_look.dim, false)
    for(names) n, k: put(n + (if k < names.length - 1: ", " else: ""), if struck[k]: FE_STRUCK else: ui_look.dim, struck[k])
    if rest != "": put(rest, ui_look.dim, false)
    if fe_over(at, float2 { w, lh * float(nlines) }): fe_tip(fe_lines_card(race))

// Bonuses, own research, lacks, heroes, notes: a plaque per kind with its count, the list on hover, the first note after.
def fe_traits(s:FeSide, at:float2, w:float, h:float, fs:int):
    var x = at.x
    var first_note = ""
    for(s.traits) rows_, g:
        if rows_.length:
            let t = FE_TRAITS[g]
            if g == 4 and first_note == "": first_note = rows_[0]
            let label = if rows_.length > 1: "{rows_.length} {t.title.lowercase()}" elif rows_[0].length <= 26 and g != 4: "{t.title}: {rows_[0]}" else: "1 {t.one}"
            let cw = ui_text_wf(label, fs, 1) + 16.0 * fe_k
            if x + cw <= at.x + w:
                ui_fill(float2 { x, at.y }, float2 { cw, h }, float4 { 0.0, 0.0, 0.0, 0.55 })
                ui_outline(float2 { x, at.y }, float2 { cw, h }, max(1.0, fe_k), ui_look.frame * float4 { 0.7, 0.7, 0.7, 1.0 })
                ui_text_f(float2 { x + 8.0 * fe_k, at.y + (h - float(fs)) / 2.0 - 1.0 * fe_k }, label, fs, FE_TRAIT_COLS[g], 1, 0.0)
                if fe_over(float2 { x, at.y }, float2 { cw, h }): fe_tip(append([ t.title ], map(rows_) l: "-  " + l))
            x += cw + 6.0 * fe_k
    if first_note != "" and x < at.x + w - 40.0 * fe_k:
        let room = int((at.x + w - x) / (0.52 * float(fs + 2)))
        let note = if first_note.length > room: first_note.substring(0, max(0, room - 3)) + "..." else: first_note
        ui_text(float2 { x, at.y + (h - float(fs + 2)) / 2.0 - 1.0 * fe_k }, note, fs + 2, float4 { 0.91, 0.85, 0.66, 1.0 })

// One side's panel, in its race's culture: who it is and the tech tree, the race's banner, its army on a lit stage,
// the dice and the prompt, the roster as a line of its rows_' names, a line of bonuses, lacks and notes. Compact (a
// team game, two panels a column): a smaller banner (the traits ride on it), stage and type, an AI's level in its
// top row.
def fe_side_panel(i:int, at:float2, size:float2, compact:bool, who:string, dt:float):
    let s = fe_sides[i]
    let lk = ui_look_of(rstr(s.race, "family"))
    let team = team_rgb[i % team_rgb.length]
    fe_panel(at, size, lk, true)
    let pad = 20.0 * fe_k
    let x = at.x + pad
    let w = size.x - pad * 2.0
    var y = at.y + 14.0 * fe_k
    // the top row: the side's gem and who it is, an AI's level (a team game), the tech tree
    let top_h = 36.0 * fe_k
    fe_gem(float2 { x + 9.0 * fe_k, y + top_h / 2.0 }, 8.0 * fe_k, team)
    ui_text_f(float2 { x + 26.0 * fe_k, y + top_h / 2.0 - 10.0 * fe_k }, who.uppercase(), fz(17.0), lk.dim, 0, 0.0)
    let tw = 128.0 * fe_k
    if ui_button(float2 { x + w - tw, y }, float2 { tw, top_h }, "", false): fe_open_tree(i)
    tb_icon("research", float2 { x + w - tw + 12.0 * fe_k, y + 8.0 * fe_k }, 20.0 * fe_k, 1.0)
    ui_text(float2 { x + w - tw + 40.0 * fe_k, y + 7.0 * fe_k }, "Tech tree", fz(17.0), lk.text)
    if fe_over(float2 { x + w - tw, y }, float2 { tw, top_h }): fe_tip([ "Everything this race can build, train and research, and its bonuses" ])
    if compact and i > 0 and not (fe_hosting and i == 1):
        var lx = x + w - tw - 8.0 * fe_k
        var k = FE_LEVELS.length - 1
        while k >= 0:
            let lw = 74.0 * fe_k
            lx -= lw
            if fe_toggle(float2 { lx, y + 1.0 * fe_k }, float2 { lw, top_h - 2.0 * fe_k }, FE_LEVELS[k], s.level == k): s.level = k
            lx -= 8.0 * fe_k
            k--
    y += top_h + 10.0 * fe_k
    // the banner: the race's name, its creature and culture
    let bh = (if compact: 76.0 else: 96.0) * fe_k
    fe_banner(float2 { x, y }, float2 { w, bh }, lk, team, if compact: 14.0 else: 26.0)
    ui_text_f(float2 { x + 20.0 * fe_k, y + 10.0 * fe_k }, rstr(s.race, "name"), fz(if compact: 28.0 else: 42.0), lk.title, 2, 2.0 * fe_k)
    let cr = creature(rstr(s.race, "creature"))
    let line = "{gstr(cr, "plural", rstr(s.race, "creature"))}  -  {capitalize(rstr(s.race, "family"))} culture"
    let line_y = y + (if compact: 42.0 else: 56.0) * fe_k
    let lfs = fz(if compact: 17.0 else: 19.0)
    ui_text_f(float2 { x + 20.0 * fe_k, line_y }, line, lfs, lk.text, 1, 1.5 * fe_k)
    if fe_over(float2 { x, y }, float2 { w, bh }) and glist(s.race, "notes").length: fe_tip(append([ "The generator\'s notes" ], map(glist(s.race, "notes")) n: as_str(n)))
    if compact:
        let tx = x + 20.0 * fe_k + ui_text_wf(line, lfs, 1) + 14.0 * fe_k
        fe_traits(s, float2 { tx, line_y - 1.0 * fe_k }, x + w - tx - 8.0 * fe_k, 24.0 * fe_k, fz(12.0))
    y += bh + 12.0 * fe_k
    // the stage: the army idling on turf, lit from above, sunk in the panel
    let foot_h = (if compact: 48.0 + 9.0 + 22.0 else: 68.0 + 9.0 + 48.0 + 9.0 + 30.0) * fe_k
    let st_at = float2 { x, y }
    let st_size = float2 { w, at.y + size.y - pad - foot_h - 12.0 * fe_k - y }
    fe_well(st_at, st_size)
    let in_at = st_at + float2_1 * 3.0 * fe_k
    let in_size = st_size - float2_1 * 6.0 * fe_k
    ui_paint(in_at, in_size, FE_GRASS, "felt")
    ui_radial(in_at, in_size, float2 { 0.5, 0.75 }, float2 { 0.75, 1.05 }, float4 { 1.0, 0.92, 0.7, 0.12 }, float4 { 0.02, 0.03, 0.0, 0.75 })
    let forging = s.views_gen != s.gen
    if s.views.length:
        // as many as the stage has room for on this screen: one each FE_UNIT_INCHES (a phone shows two or
        // three, drawn bigger), at most six
        let inches = in_size.x / float(max(96, gl.dpi(0)))
        let n = min(s.views.length, clamp(int(inches / FE_UNIT_INCHES), 2, 6))
        let zm = max((if st_size.y >= 144.0 * 1.45 * fe_k: 3.0 else: 2.0) * fe_k, min(in_size.x / (float(n) * 40.0), in_size.y / 62.0))
        let right = s.team != fe_sides[0].team or (fe_sides.length == 2 and i == 1)
        let vs = s.views.slice(0, n)
        let spots = map(n) k:
            let feet = if in_size.y / zm >= 40.0: (if k % 2 == 0: 0.62 else: 0.8) else: 0.92
            let along = (float(k) + 0.75) / (float(n) + 0.5)
            in_at + float2 { in_size.x * (if right: 1.0 - along else: along), in_size.y * feet }
        fe_draw_units(vs, spots, zm / 1.5, i, if forging: 0.32 else: 1.0, dt)
    if forging:  // the forge veil: the old army dims while the new one is made
        ui_fill(in_at, in_size, float4 { 0.05, 0.03, 0.01, 0.35 })
        ui_text_c(in_at.x + in_size.x / 2.0, in_at.y + in_size.y / 2.0 - 12.0 * fe_k, "Forging the army...", fz(20.0), lk.accent, 2, 1.5 * fe_k)
    elif not compact:
        ui_text_f(float2 { in_at.x + 8.0 * fe_k, in_at.y + in_size.y - 24.0 * fe_k }, "{glist(s.race, "units").length} units, every one priced by its parts", fz(15.0), float4 { 0.96, 0.93, 0.83, 0.85 }, 0, 1.0 * fe_k)
    y = st_at.y + st_size.y + 12.0 * fe_k
    // the dice, then the prompt
    let ph = (if compact: 48.0 else: 68.0) * fe_k
    if fe_dice(float2 { x, y }, ph): fe_roll(i)
    fe_box(i, float2 { x + ph + 10.0 * fe_k, y }, float2 { w - ph - 10.0 * fe_k, ph }, s.typed, "...or describe your race", fz(if compact: 20.0 else: 25.0), true)
    y += ph + 9.0 * fe_k
    fe_roster_text(s.race, float2 { x, y }, w, if compact: 1 else: 2, fz(if compact: 15.0 else: 17.0))
    if not compact: fe_traits(s, float2 { x, y + 57.0 * fe_k }, w, 26.0 * fe_k, fz(13.0))
    ui_use(ui_look_of(""))

// ---- the pages

// The title screen: the crest, the name, the menu on a plaque, both armies on the hill below.
def fe_title_page(dt:float) -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    // the hill along the bottom: turf rising out of the dark, melting into the table at its top and its ends
    let hill_h = 270.0 * fe_k
    let hill_at = float2 { 0.0, ws.y - hill_h }
    let grass = FE_GRASS * float4 { 0.75, 0.75, 0.75, 1.0 }
    def smooth(a:float, b:float, t:float) -> float:
        let q = clamp((t - a) / (b - a), 0.0, 1.0)
        return q * q * (3.0 - 2.0 * q)
    let pts = []::float2
    let cols = []::float4
    let idx = []::int
    let nx = 24
    let ny = 8
    for(ny + 1) j:
        for(nx + 1) i:
            let u = float(i) / float(nx)
            let v = float(j) / float(ny)
            pts.push(hill_at + float2 { ws.x * u, hill_h * v })
            let shade = if v < 0.55: 0.35 * (1.0 - v / 0.55) else: 0.5 * (v - 0.55) / 0.45
            let a = smooth(0.0, 0.3, v) * smooth(0.0, 0.24, u) * (1.0 - smooth(0.76, 1.0, u))
            cols.push(float4 { grass.x * (1.0 - shade), grass.y * (1.0 - shade), grass.z * (1.0 - shade), a })
    for(ny) j:
        for(nx) i:
            let a = j * (nx + 1) + i
            for([ a, a + nx + 2, a + 1, a, a + nx + 1, a + nx + 2 ]) q: idx.push(q)
    ui_paint_poly(pts, cols, idx, ui_material("felt"))
    let zm = 3.0 * fe_k
    let cw = ws.x / zm
    for(min(2, fe_sides.length)) i:
        let s = fe_sides[i]
        if s.views.length and s.views_gen == s.gen:
            let n = s.views.length
            let vs = map(n) k: s.views[n - 1 - k]  // the big ones at the front
            let spots = map(n) k: float2 { (if i == 0: cw * (0.42 - 0.055 * float(k)) else: cw * (0.58 + 0.055 * float(k))) * zm, hill_at.y + hill_h * (if k % 2 == 0: 0.7 else: 0.86) }
            fe_draw_units(vs, spots, zm / 1.5, i, 1.0, dt)
    // the column: crest, title, tag line, the plaque of buttons, the foot
    let cx = ws.x / 2.0
    let top = (950.0 - 270.0 * 0.55 - 760.0) / 2.0 + 20.0
    tb_icon_wide("crest_" + lk.ornament, float2 { cx, (top + 45.0) * fe_k }, 90.0 * fe_k)
    ui_text_c(cx, (top + 112.0) * fe_k, "Age of Anything", fz(78.0), lk.title, 2, 3.0 * fe_k)
    ui_text_c(cx, (top + 214.0) * fe_k, "Your civilisation is whatever you can describe.", fz(22.0), lk.dim, 0, 0.0)
    let plaque_at = float2 { cx - 182.0 * fe_k, (top + 270.0) * fe_k }
    let plaque_size = float2 { 364.0, 352.0 } * fe_k
    ui_box(plaque_at, plaque_size, 1, lk.frame * float4 { 0.6, 0.6, 0.6, 1.0 }, true)
    var y = plaque_at.y + 18.0 * fe_k
    var go = ""
    for([ [ "Battle the AI", "setup" ], [ "Play on the network", "net" ], [ "Load game", "saves" ], [ "Race Lab", "lab" ], [ "Quit", "quit" ] ]) item, k:
        let h = (if k == 0: 72.0 else: 52.0) * fe_k
        if ui_button(float2 { cx - 164.0 * fe_k, y }, float2 { 328.0 * fe_k, h }, "", k == 0): go = item[1]
        if k == 0: ui_text_c(cx, y + h / 2.0 - 19.0 * fe_k, item[0], fz(30.0), lk.title, 2, 1.5 * fe_k)
        else: ui_text_c(cx, y + h / 2.0 - 12.0 * fe_k, item[0], fz(20.0), lk.text, 1, 0.0)
        y += h + 12.0 * fe_k
    let vh = volume_rows(float2 { cx - 164.0 * fe_k, plaque_at.y + plaque_size.y + 16.0 * fe_k }, 328.0 * fe_k, 40.0 * fe_k, 8.0 * fe_k)
    ui_text_c(cx, plaque_at.y + plaque_size.y + 34.0 * fe_k + vh, "Type \"centaur romans\" or \"sewer rats with cheese hammers\": the game builds the race and prices every unit fairly.", fz(15.0), lk.dim, 0, 0.0)
    if gl.button("escape") == 1 or gl.button("controller_b") == 1: go = "quit"
    return go

// The volumes: a row each for the music and the sound, - and + either side of the level (saved as it changes).
// Returns the rows' height.
def volume_rows(at:float2, w:float, h:float, gap:float) -> float:
    let lk = ui_look
    for([ "Music", "Sound" ]) name, k:
        let y = at.y + float(k) * (h + gap)
        let lv = if k == 0: music_level else: sound_level
        var nv = lv
        if ui_button(float2 { at.x, y }, float2 { h, h }, "-", false): nv = max(0, lv - 1)
        if ui_button(float2 { at.x + w - h, y }, float2 { h, h }, "+", false): nv = min(10, lv + 1)
        let fs = int(h * 0.42)
        ui_text_c(at.x + w / 2.0, y + (h - float(fs)) / 2.0 - 2.0, "{name}: {if nv == 0: "off" else: string(nv * 10) + "%"}", fs, lk.text, 1, 0.0)
        if nv != lv:
            if k == 0: music_level = nv
            else: sound_level = nv
            volume_save()
    return h * 2.0 + gap

// The battle setup: a panel per player (your team on the left), the middle column, Start.
def fe_setup_page(dt:float) -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    var go = ""
    if ui_button(D(26.0, 18.0), D(150.0, 48.0), "Menu", false): go = "back"
    tb_icon("back", D(38.0, 30.0), 22.0 * fe_k, 1.0)
    ui_text_c(ws.x / 2.0, 14.0 * fe_k, "Prepare for Battle", fz(46.0), lk.title, 2, 2.0 * fe_k)
    let n = fe_sides.length
    let compact = n > 2
    let row_y = 96.0
    let row_h = 950.0 - 22.0 - row_y
    let centre_w = 420.0
    let col_w = (fe_w - 52.0 - centre_w - 44.0) / 2.0
    let left = filter(n) i: fe_sides[i].team == fe_sides[0].team
    let right = filter(n) i: fe_sides[i].team != fe_sides[0].team
    for([ left, right ]) col, c:
        let x = 26.0 + float(c) * (col_w + 22.0 + centre_w + 22.0)
        let each = (row_h - 30.0 * float(col.length - 1)) / float(max(1, col.length))
        for(col) i, r:
            let who = if i == 0: "You" elif fe_hosting and i == 1: "The other player" elif c == 0: "Ally (AI)" else: "The AI"
            fe_side_panel(i, D(x, row_y + float(r) * (each + 30.0)), D(col_w, each), compact, who, dt)
    // the middle: the cast "vs", the map card, the AI's level, Start
    let cx = 26.0 + col_w + 22.0
    let mid = cx + centre_w / 2.0
    fe_medallion(D(mid, row_y + 52.0), 46.0 * fe_k)
    let card_w = centre_w - 16.0
    let pic_w = card_w - 44.0
    let pic_h = pic_w * 0.5 + 8.0
    let card_h = 36.0 + 52.0 + pic_h + 16.0 + 30.0 + 46.0 + 30.0
    let card_y = row_y + 110.0 + (row_h - 110.0 - 300.0 - card_h) / 2.0
    let card_at = D(cx + 8.0, card_y)
    fe_panel(card_at, D(card_w, card_h), lk, true)
    var y = card_y + 26.0
    ui_text_c(mid * fe_k, y * fe_k, "BATTLEFIELD", fz(14.0), lk.dim, 1, 0.0)
    y += 26.0
    if ui_button(D(cx + 30.0, y), D(46.0, 46.0), "<", false): fe_set_map(fe_map_k - 1)
    if ui_button(D(cx + centre_w - 76.0, y), D(46.0, 46.0), ">", false): fe_set_map(fe_map_k + 1)
    let name = gstr(fe_map_json, "name", fe_maps[fe_map_k])
    var nfs = 30.0
    while nfs > 16.0 and ui_text_wf(name, fz(nfs), 2) > (centre_w - 180.0) * fe_k: nfs -= 2.0
    ui_text_c(mid * fe_k, (y + 23.0 - nfs * 0.6) * fe_k, name, fz(nfs), lk.title, 2, 1.5 * fe_k)
    y += 56.0
    fe_well(D(cx + 30.0, y), D(pic_w, pic_h))
    fe_draw_map(D(cx + 34.0, y + 4.0), D(pic_w - 8.0, pic_h - 8.0), fe_maps[fe_map_k], fe_map_json)
    y += pic_h + 10.0
    let starts = glist(fe_map_json, "starts").length
    ui_text_c(mid * fe_k, y * fe_k, "{gint(fe_map_json, "width", 0)} x {gint(fe_map_json, "height", 0)} tiles  -  " + (if starts == 2: "1 v 1" else: "{starts / 2} v {starts - starts / 2}"), fz(16.0), lk.dim, 0, 0.0)
    y += 32.0
    if ui_button(D(cx + 30.0, y), D(36.0, 36.0), "<", false): fe_mode_k = (fe_mode_k + fe_modes.length - 1) % fe_modes.length
    if ui_button(D(cx + centre_w - 66.0, y), D(36.0, 36.0), ">", false): fe_mode_k = (fe_mode_k + 1) % fe_modes.length
    ui_text_c(mid * fe_k, (y + 6.0) * fe_k, "Mode: " + fe_modes[fe_mode_k][1], fz(19.0), lk.text, 0, 0.0)
    if fe_over(D(cx + 70.0, y), D(centre_w - 140.0, 36.0)) and fe_modes[fe_mode_k][2] != "": fe_tip(append([ fe_modes[fe_mode_k][1] ], fe_wrap(fe_modes[fe_mode_k][2], fz(15.0), 520.0 * fe_k)))
    lobby_mode = fe_modes[fe_mode_k][0]
    // the AI's level (1v1; a team game has it in each AI's panel), Start, the hint
    let by = 950.0 - 22.0 - 30.0 - 100.0
    if not compact and not fe_hosting:
        let lc_y = by - 18.0 - 92.0
        ui_box(D(cx + 8.0, lc_y), D(card_w, 92.0), 1, lk.face, false)
        ui_text_c(mid * fe_k, (lc_y + 12.0) * fe_k, "THE AI PLAYS", fz(14.0), lk.dim, 1, 0.0)
        let bw = (card_w - 40.0 - 16.0) / 3.0
        for(FE_LEVELS) l, k:
            if fe_toggle(D(cx + 28.0 + float(k) * (bw + 8.0), lc_y + 36.0), D(bw, 44.0), l, fe_sides[1].level == k): fe_sides[1].level = k
    let breathe = 1.0 + 0.06 * (0.5 + 0.5 * sin(seconds_elapsed() * 128.0))
    let start_k = ui_hits.length
    if ui_button(D(cx + 8.0, by), D(card_w, 100.0), "", true): go = "start"
    ui_text_c(mid * fe_k, (by + 24.0) * fe_k, if fe_hosting: "Host the Battle" else: "Start Battle", fz(40.0), lk.title * float4 { breathe, breathe, breathe, 1.0 }, 2, 2.0 * fe_k)
    ui_text_c(mid * fe_k, (by + 112.0) * fe_k, if fe_pad: "X: roll the dice  -  Start: start  -  B: back" elif fe_hosting: "Start: wait for the other player to join" else: "Esc in battle: pause and menu", fz(16.0), lk.dim, 0, 0.0)
    if fe_frames == 1 and fe_pad: ui_focus = start_k  // (a pad starts on Start)
    // the pad: X rolls the dice of the panel the focus is in (yours when it's elsewhere), Start starts, B goes back
    if gl.button("controller_x") == 1:
        var k = 0
        if ui_focus >= 0 and ui_focus < ui_hits_last.length:
            let f = ui_hits_last[ui_focus].at
            for([ left, right ]) col, c:
                if (c == 0 and f.x < cx * fe_k) or (c == 1 and f.x > (cx + centre_w) * fe_k):
                    let each = (row_h - 30.0 * float(col.length - 1)) / float(max(1, col.length))
                    for(col) i, r:
                        if f.y >= (row_y + float(r) * (each + 30.0)) * fe_k: k = i
        fe_roll(k)
    if gl.button("controller_start") == 1: go = "start"
    if gl.button("controller_b") == 1 or (gl.button("escape") == 1 and fe_field < 0): go = "back"
    if gl.button("escape") == 1: fe_field = -1
    return go

// Load a game: the saved matches, newest first (gen/save.lobster files in saves/, each with a line about it).
let FE_SAVES = 8
def fe_saves() -> [string], [string]:  // paths, rows_
    let names, _, times = scan_folder("saves", true)
    let found = []::string
    let when = []::int
    if names and times:
        for(names) n, k:
            if ends_with(n, ".sav"):
                found.push("saves/" + n)
                when.push(times[k])
    let order = map(found.length) k: k
    insertion_sort(order) a, b: when[a] > when[b]
    let paths = map(order) k: found[k]
    let rows_ = map(paths) p:
        let meta = read_file(substring(p, 0, p.length - 4) + ".txt")
        if meta: tokenize(meta, "\n", "")[0] else: p
    return paths, rows_

// The saves over a dimmed screen: pick one to play on from there. Returns the path picked, "back", or "".
def fe_saves_card(note:string) -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    ui_fill(float2_0, ws, float4 { 0.0, 0.0, 0.0, 0.5 })
    let paths, rows_ = fe_saves()
    let shown = min(FE_SAVES, paths.length)
    let size = D(740.0, 186.0 + float(shown) * 64.0 + (if note != "" or shown == 0 or paths.length > FE_SAVES: 40.0 else: 0.0))
    let at = (ws - size) / 2.0
    fe_panel(at, size, lk, true)
    var y = at.y + 26.0 * fe_k
    ui_text_c(ws.x / 2.0, y, "Load a game", fz(44.0), lk.title, 2, 2.0 * fe_k)
    y += 66.0 * fe_k
    ui_fill(float2 { at.x + 40.0 * fe_k, y }, float2 { size.x - 80.0 * fe_k, 2.0 * fe_k }, lk.metal)
    y += 14.0 * fe_k
    var go = ""
    for(shown) k:
        if ui_button(float2 { at.x + 40.0 * fe_k, y }, float2 { size.x - 80.0 * fe_k, 56.0 * fe_k }, rows_[k], false): go = paths[k]
        y += 64.0 * fe_k
    let say = if note != "": note elif shown == 0: "No saved games yet. Save one from the pause menu (Esc, or Menu on a pad)." elif paths.length > FE_SAVES: "The newest {FE_SAVES} of {paths.length} saves." else: ""
    if say != "":
        ui_text_c(ws.x / 2.0, y + 4.0 * fe_k, say, fz(16.0), lk.dim, 0, 0.0)
        y += 40.0 * fe_k
    if ui_button(float2 { at.x + 40.0 * fe_k, y }, float2 { size.x - 80.0 * fe_k, 50.0 * fe_k }, "Back", false): go = "back"
    if gl.button("escape") == 1 or gl.button("controller_b") == 1: go = "back"
    return go

// Play on the network: host (the battle setup, then wait for a player) or join a game on the home network (the
// hosts found nearby, or an address).
def fe_net_page() -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    ui_fill(float2_0, ws, float4 { 0.0, 0.0, 0.0, 0.5 })
    let rows = max(1, fe_hosts.length)
    let size = D(740.0, 470.0 + float(rows) * 60.0)
    let at = (ws - size) / 2.0
    fe_panel(at, size, lk, true)
    let x = at.x + 40.0 * fe_k
    let w = size.x - 80.0 * fe_k
    var y = at.y + 26.0 * fe_k
    ui_text_c(ws.x / 2.0, y, "Play on the network", fz(44.0), lk.title, 2, 2.0 * fe_k)
    y += 62.0 * fe_k
    ui_text_c(ws.x / 2.0, y, "Both machines on the same home network (Wi-Fi or cable).", fz(17.0), lk.dim, 0, 0.0)
    y += 36.0 * fe_k
    var go = ""
    if ui_button(float2 { x, y }, float2 { w, 64.0 * fe_k }, "Host a game", true): go = "host"
    y += 78.0 * fe_k
    ui_fill(float2 { x, y }, float2 { w, 2.0 * fe_k }, lk.metal)
    y += 14.0 * fe_k
    ui_text(float2 { x, y }, "Games on this network", fz(18.0), lk.dim)
    if ui_button(float2 { x + w - 200.0 * fe_k, y - 6.0 * fe_k }, float2 { 200.0 * fe_k, 36.0 * fe_k }, "Look again", false): fe_scanned = false
    y += 40.0 * fe_k
    if not fe_hosts.length:
        ui_text(float2 { x, y + 14.0 * fe_k }, if fe_scanned: "None yet: on the other machine, Play on the network, Host a game." else: "Looking for games...", fz(16.0), lk.dim)
    for(fe_hosts) h:
        let same = h.version == net_version()
        if ui_button(float2 { x, y }, float2 { w, 52.0 * fe_k }, "Join: {h.name}  ({h.ip}, {h.map})" + (if same: "" else: "  - a different version"), false) and same:
            fe_address = h.ip
            go = "join"
        y += 60.0 * fe_k
    if not fe_hosts.length: y += 60.0 * fe_k
    y += 10.0 * fe_k
    fe_box(20, float2 { x, y }, float2 { w - 160.0 * fe_k, 48.0 * fe_k }, fe_address, "or an address: 192.168.1.20", fz(19.0), false)
    if ui_button(float2 { x + w - 150.0 * fe_k, y }, float2 { 150.0 * fe_k, 48.0 * fe_k }, "Join", false) and fe_address.fe_trim() != "": go = "join"
    y += 64.0 * fe_k
    if fe_note != "": ui_text_c(ws.x / 2.0, y, fe_note, fz(16.0), lk.accent, 0, 0.0)
    y += 34.0 * fe_k
    if ui_button(float2 { x, y }, float2 { w, 52.0 * fe_k }, "Back", false): go = "back"
    if gl.button("controller_b") == 1 or (gl.button("escape") == 1 and fe_field != 20): go = "back"
    if gl.button("escape") == 1: fe_field = -1
    return go

// ---- the Race Lab (scenes/race_lab.gd): a prompt per side, each race's card, both armies lined up on the turf

// A race as a card of rows_ (name, prompt, creature and culture, the key, notes, every unit with its stats).
def fe_card_lines(race:JV, rules_name:string) -> [[string]]:  // [text, style]: t title, d dim, f faint, n note, b bold, plain
    let out = []::[string]
    let cr = creature(rstr(race, "creature"))
    out.push([ rstr(race, "name"), "t" ])
    out.push([ "\"" + gstr(race, "prompt", "") + "\"", "" ])
    out.push([ "{gstr(cr, "plural", "")}  -  {rstr(race, "family")}  -  {rules_name}  -  reroll {gint(race, "reroll", 0)}", "d" ])
    out.push([ "key " + substring(gstr(race, "key", ""), 0, min(16, gstr(race, "key", "").length)) + "...", "f" ])
    out.push([ "", "" ])
    for(glist(race, "notes")) n: out.push([ "-  " + as_str(n), "n" ])
    if glist(race, "notes").length: out.push([ "", "" ])
    for(glist(race, "units")) u:
        let r = at(u, "recipe")
        let e = at(u, "eval")
        let cost = gobj(e, "cost")
        out.push([ "{rstr(r, "name")}   ({gstr(r, "role", "")}, tier {gint(r, "tier", 1)})", "b" ])
        out.push([ "   {gint(cost, "food", 0)} food  {gint(cost, "wood", 0)} wood" + (if gint(cost, "gold", 0) > 0: "  {gint(cost, "gold", 0)} gold" else: "") + "  -  {gint(e, "train_time", 0)}s  -  pop {gint(e, "pop", 1)}  -  {gint(e, "points", 0)} pts", "" ])
        let arm = gobj(e, "armour")
        out.push([ "   HP {gint(e, "hp", 0)}  ATK {gint(e, "attack", 0)} {gstr(e, "damage", "")}  ARM {gint(arm, "melee", 0)}/{gint(arm, "pierce", 0)}  RNG {gint(e, "range", 0)}  SPD {gint(e, "speed", 0)}", "" ])
        let bonus = gobj(e, "bonus")
        if bonus.keys.length: out.push([ "   " + concat_string(map(sorted_strs(bonus.keys)) k: "+{gint(bonus, k, 0)} vs {k}", ", "), "" ])
        var tl = "  "
        for(gstrs(e, "tags")) t:
            if tl.length + t.length > 48:
                out.push([ tl, "f" ])
                tl = "  "
            tl += " " + t
        out.push([ tl, "f" ])
        out.push([ "", "" ])
    return out

def fe_lab_page(dt:float) -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    var go = ""
    let rules_name = gstr(fe_rules, "name", FE_RULES[fe_lab_rules])
    // the top row: Menu, then each side's prompt with Reroll and Save, the rules between them
    let top = D(0.0, 14.0)
    if ui_button(float2 { 14.0 * fe_k, top.y }, D(110.0, 46.0), "Menu", false): go = "back"
    let mid_w = 210.0 * fe_k
    let half = (ws.x - 138.0 * fe_k - mid_w) / 2.0
    for(2) k:
        let s = fe_sides[k]
        let x = 138.0 * fe_k + float(k) * (half + mid_w)
        let bw = 96.0 * fe_k
        fe_box(10 + k, float2 { x, top.y }, float2 { half - bw * 2.0 - 30.0 * fe_k, 46.0 * fe_k }, s.typed, "describe a race...", fz(20.0), false)
        if ui_button(float2 { x + half - bw * 2.0 - 20.0 * fe_k, top.y }, float2 { bw, 46.0 * fe_k }, "Reroll", false):
            s.reroll++
            fe_regen(k)
        if ui_button(float2 { x + half - bw - 10.0 * fe_k, top.y }, float2 { bw, 46.0 * fe_k }, "Save", false):
            launch_subprocess([ "/bin/mkdir", "-p", "races" ])
            let path = "races/" + substring(rstr(s.race, "key"), 0, 12) + ".json"
            fe_note = if write_file(path, stringify(s.race)): "Saved " + path else: "Could not save " + path
    if ui_button(float2 { 138.0 * fe_k + half + 10.0 * fe_k, top.y }, float2 { mid_w - 20.0 * fe_k, 46.0 * fe_k }, rules_name, false):
        fe_lab_rules = (fe_lab_rules + 1) % FE_RULES.length
        rules_arg = FE_RULES[fe_lab_rules]
        fe_rules = load_rules(rules_arg)
        for(2) k: fe_regen(k)
    // the body: a card each side, the field between
    let body_y = top.y + 58.0 * fe_k
    let body_h = ws.y - body_y - 92.0 * fe_k
    let card_w = 380.0 * fe_k
    let field_at = float2 { card_w + 22.0 * fe_k, body_y }
    let field_size = float2 { ws.x - card_w * 2.0 - 44.0 * fe_k, body_h }
    for(2) k:
        let s = fe_sides[k]
        let at = float2 { if k == 0: 10.0 * fe_k else: ws.x - card_w - 10.0 * fe_k, body_y }
        ui_box(at, float2 { card_w, body_h }, 1, lk.face, false)
        ui_fill(at + float2 { 6.0, 6.0 } * fe_k, float2 { card_w - 12.0 * fe_k, 4.0 * fe_k }, team_rgb[k])
        let rows_ = fe_card_lines(s.race, rules_name)
        let lh = 19.0 * fe_k
        if fe_over(at, float2 { card_w, body_h }): fe_lab_scroll[k] = clamp(fe_lab_scroll[k] - float(gl.mousewheel_delta()) * 60.0 * fe_k, 0.0, max(0.0, float(rows_.length) * lh - body_h + 40.0 * fe_k))
        for(rows_) l, n:
            let y = at.y + 18.0 * fe_k + float(n) * lh - fe_lab_scroll[k] + (if n > 0: 10.0 * fe_k else: 0.0)
            if y > at.y + 6.0 * fe_k and y < at.y + body_h - 24.0 * fe_k:
                let st = l[1]
                let col = if st == "t": lk.title elif st == "d": lk.dim elif st == "f": lk.dim * float4 { 0.75, 0.75, 0.75, 1.0 } elif st == "n": lk.accent else: lk.text
                ui_text_f(float2 { at.x + 16.0 * fe_k, y }, l[0], fz(if st == "t": 24.0 elif st == "b": 15.0 else: 13.0), col, if st == "t": 2 elif st == "b": 1 else: 0, 0.0)
    fe_well(field_at, field_size)
    let in_at = field_at + float2_1 * 3.0 * fe_k
    let in_size = field_size - float2_1 * 6.0 * fe_k
    ui_paint(in_at, in_size, float4 { 0.337, 0.47, 0.18, 1.0 }, "felt")
    ui_radial(in_at, in_size, float2 { 0.5, 0.5 }, float2 { 0.9, 1.2 }, float4 { 1.0, 0.92, 0.7, 0.06 }, float4 { 0.02, 0.03, 0.0, 0.5 })
    ui_fill(float2 { in_at.x + in_size.x / 2.0 - 1.0, in_at.y }, float2 { 2.0, in_size.y }, float4 { 0.1, 0.08, 0.05, 0.35 })
    for(2) k:
        let s = fe_sides[k]
        if (fe_lab_gen[k] != s.gen and seconds_elapsed() - s.dirty_at > FE_BAKE_AFTER) or (fe_lab_gen[k] == s.gen and fe_lab_bake[k] != bake_gen):
            uv_free_all(fe_lab_views[k])
            fe_lab_views[k] = map(glist(s.race, "units")) u: fe_view(u, k, k == 1)
            fe_lab_gen[k] = s.gen
            fe_lab_bake[k] = bake_gen
        // the lineup: every unit with its name, rows across its half
        let vs = fe_lab_views[k]
        let hw = in_size.x / 2.0
        let per_row = max(1, int(hw / (100.0 * fe_k)))
        let rows_n = (vs.length + per_row - 1) / per_row
        let row_h = min(110.0 * fe_k, in_size.y / float(max(1, rows_n)))
        let spots = map(vs.length) n: in_at + float2 { float(k) * hw + hw * (float(n % per_row) + 0.5) / float(per_row), row_h * (float(n / per_row) + 0.72) }
        fe_draw_units(vs, spots, fe_k * 1.1, k, if fe_lab_gen[k] != s.gen: 0.32 else: 1.0, dt)
        let units = glist(s.race, "units")
        for(vs.length) n:
            if n < units.length:
                let nm = rstr(at(units[n], "recipe"), "name")
                let fs = fz(11.0)
                let short = if nm.length > 15: nm.substring(0, 14) + "." else: nm
                ui_text_c(spots[n].x, spots[n].y + 6.0 * fe_k, short, fs, float4_1, 0, 1.0)
    // the foot: Test (every line against every other, at equal cost), Fight (both armies on the map), the status
    let fy = ws.y - 78.0 * fe_k
    if ui_button(float2 { 10.0 * fe_k, fy }, D(150.0, 56.0), "Test", false) or (has_s(args, "labtest") and fe_frames == 5):
        fe_test_lines = balance_for_match(map(fe_sides) s: s.race, fe_rules, 1)
        reset_world()
        rr_price_pct = dictionary<string, int>(64)
    if ui_button(float2 { 170.0 * fe_k, fy }, D(150.0, 56.0), "Fight", false):
        skirmish = true
        go = "fight"
    let status = if fe_test_lines.length: "Test: " + fe_test_lines[fe_test_lines.length - 1] elif fe_note != "": fe_note else: "Type: a new race as you type  -  Reroll: same prompt, new roll  -  Save: writes the race JSON  -  Fight: both armies on " + lobby_map
    ui_text(float2 { 340.0 * fe_k, fy + 16.0 * fe_k }, status, fz(16.0), lk.dim)
    if gl.button("controller_b") == 1 or (gl.button("escape") == 1 and fe_field < 0): go = "back"
    if gl.button("escape") == 1: fe_field = -1
    return go

// ---- the loader (scenes/match_loader.gd): both armies facing each other, the names with "vs", the map, a bar, a tip

def fe_loader(status:string, frac:float):
    gl.clear(float4 { 0.08, 0.06, 0.05, 1.0 })
    gl.blend(1)
    fe_fit()
    ui_frame(false)
    fe_backdrop()
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    let bronze = float4 { 0.63, 0.53, 0.35, 1.0 }
    let x0 = max(56.0 * fe_k, (ws.x - 1500.0 * fe_k) / 2.0)
    let w = ws.x - x0 * 2.0
    var y = 40.0 * fe_k
    ui_text_c(ws.x / 2.0, y, "PREPARING FOR BATTLE", fz(16.0), bronze, 1, 0.0)
    y += 40.0 * fe_k
    // the names, a team each side of the "vs", each over its side's colour
    let n = fe_sides.length
    let you = fe_sides[0].team
    var ln = 0
    var rn = 0
    let fs = fz(if n <= 2: 52.0 else: 32.0)
    for(fe_sides) s, i:
        let left = s.team == you
        let row = if left: ln else: rn
        let ny = y + float(row) * (float(fs) * 1.5)
        let nm = rstr(s.race, "name")
        if left:
            ui_text_f(float2 { ws.x / 2.0 - 60.0 * fe_k - ui_text_wf(nm, fs, 2), ny }, nm, fs, lk.text, 2, 2.0 * fe_k)
            ui_fill(float2 { ws.x / 2.0 - 60.0 * fe_k - ui_text_wf(nm, fs, 2), ny + float(fs) * 1.15 }, float2 { ui_text_wf(nm, fs, 2), 4.0 * fe_k }, team_rgb[i % team_rgb.length])
            ln++
        else:
            ui_text_f(float2 { ws.x / 2.0 + 60.0 * fe_k, ny }, nm, fs, lk.text, 2, 2.0 * fe_k)
            ui_fill(float2 { ws.x / 2.0 + 60.0 * fe_k, ny + float(fs) * 1.15 }, float2 { ui_text_wf(nm, fs, 2), 4.0 * fe_k }, team_rgb[i % team_rgb.length])
            rn++
    let rows = max(ln, rn)
    ui_text_c(ws.x / 2.0, y + (float(rows) * float(fs) * 1.5 - float(fz(40.0))) / 2.0, "vs", fz(40.0), bronze, 2, 2.0 * fe_k)
    y += float(rows) * float(fs) * 1.5 + 24.0 * fe_k
    // the stage
    let st_h = max(300.0 * fe_k, ws.y - y - 260.0 * fe_k)
    let st_at = float2 { x0, y }
    ui_box(st_at - float2_1 * 3.0 * fe_k, float2 { w, st_h } + float2_1 * 6.0 * fe_k, 0, lk.face, false)
    ui_fill(st_at, float2 { w, st_h }, FE_GRASS)
    ui_shade(st_at, float2 { w, st_h }, 1, 6) u, v: float4 { 0.05, 0.08, 0.02, 0.6 * (1.0 - v) }
    let zm = 2.5 * fe_k * (if st_h >= 450.0 * fe_k: 1.4 else: 1.0)
    for(fe_sides) s, i:
        let left = s.team == you
        let rank = (filter(i) j: (fe_sides[j].team == you) == left).length
        let ranks = (filter(n) j: (fe_sides[j].team == you) == left).length
        let vs = s.views
        let spots = map(vs.length) k:
            let along = (float(k) + 0.5) / float(max(1, vs.length))
            let sx = w * (0.07 + 0.36 * along)
            let sy = if ranks == 1: 0.6 + 0.12 * float(k % 2) else: 0.46 + 0.3 * float(rank) / float(ranks - 1) + 0.05 * float(k % 2)
            st_at + float2 { if left: sx else: w - sx, st_h * sy }
        fe_draw_units(vs, spots, zm / 1.5, i, 1.0, gl.delta_time())
    y += st_h + 28.0 * fe_k
    // the map card, then the bar with what's being made, and a tip
    let card = float2 { 300.0, 190.0 } * fe_k
    fe_panel(float2 { x0, y }, card, lk, false)
    ui_text_c(x0 + card.x / 2.0, y + 12.0 * fe_k, gstr(fe_map_json, "name", lobby_map), fz(19.0), lk.title, 2, 1.0 * fe_k)
    fe_draw_map(float2 { x0 + 16.0 * fe_k, y + 44.0 * fe_k }, float2 { card.x - 32.0 * fe_k, card.y - 60.0 * fe_k }, lobby_map, fe_map_json)
    let bx = x0 + card.x + 28.0 * fe_k
    let bw = w - card.x - 28.0 * fe_k
    let by = y + 40.0 * fe_k
    ui_text(float2 { bx, by - 34.0 * fe_k }, status, fz(17.0), lk.text)
    let pct = "{int(clamp(frac, 0.0, 1.0) * 100.0)}%"
    ui_text(float2 { bx + bw - ui_text_w(pct, fz(17.0)), by - 34.0 * fe_k }, pct, fz(17.0), lk.accent)
    ui_box(float2 { bx, by }, float2 { bw, 26.0 * fe_k }, -1, lk.well, false)
    let fill = (bw - 8.0 * fe_k) * clamp(frac, 0.0, 1.0)
    if fill > 1.0:
        ui_fill(float2 { bx + 4.0 * fe_k, by + 4.0 * fe_k }, float2 { fill, 18.0 * fe_k }, lk.accent * float4 { 0.75, 0.75, 0.75, 1.0 })
        ui_fill(float2 { bx + 4.0 * fe_k, by + 4.0 * fe_k }, float2 { fill, 7.0 * fe_k }, lk.accent + (float4_1 - lk.accent) * 0.1)
    if fe_tips.length:
        if seconds_elapsed() - fe_tip_t > 7.0:
            fe_tip_k = rnd(fe_tips.length)
            fe_tip_t = seconds_elapsed()
        for(fe_wrap("Tip: " + fe_tips[fe_tip_k], fz(16.0), bw)) l, k: ui_text(float2 { bx, by + 44.0 * fe_k + float(k) * 22.0 * fe_k }, l, fz(16.0), lk.dim)
    ui_flush()

// ---- the loop

// The front end from a page; what was chosen ("play", "host", "join", "fight", "load:<path>"), "" to quit. Sets the
// lobby's prompts, rerolls, teams, AI levels, map and mode for the match.
def run_front(page0:string, typed:[string]) -> string:
    fe_rules = load_rules(rules_id())
    if not fe_maps.length: fe_load_maps()
    rnd_seed(int(seconds_elapsed() * 1000.0) + int(date_time()[0]) * 7919 + date_time()[1] * 31 + date_time()[2])
    let start_map = str_index(fe_maps, lobby_map)
    for(fe_sides) s: uv_free_all(s.views)
    fe_sides = []
    fe_set_map(if start_map >= 0: start_map else: 0)
    fe_mode_k = max(0, str_index(map(fe_modes) m: m[0], lobby_mode))
    for(typed) t, i:
        if i < fe_sides.length:
            fe_sides[i].typed = t
            if i < lobby_rerolls.length: fe_sides[i].reroll = lobby_rerolls[i]
            fe_regen(i)
    fe_page = page0
    front_shown = true
    fe_frames = 0
    fe_field = -1
    var typing = false  // text input on: only while a box has the keyboard (on a phone it brings up the keyboard)
    var shot_frame = -1
    pace(PACE_MENU)
    while gl.frame():
        if bake_quit: return ""
        let dt = gl.delta_time()
        fe_fit()
        music_tick("lobby", false, dt)
        let any_pad = gl.button("controller_a") == 1 or gl.button("controller_b") == 1 or gl.button("controller_x") == 1 or gl.button("controller_start") == 1 or gl.button("controller_dpup") == 1 or gl.button("controller_dpdown") == 1 or abs(gl.controller_axis(1)) > 0.6
        if any_pad or has_s(args, "padui"): fe_pad = true
        elif gl.button("mouse1") == 1 or magnitude(float(gl.mouse_delta(0))) > 4.0: fe_pad = false
        if (fe_field >= 0) != typing:
            typing = fe_field >= 0
            if typing:
                gl.start_text_input(int2 { 0, 0 }, int2 { 400, 40 })
                gl.set_text_input(fe_field_text())
            else: gl.end_text_input()
        if fe_field >= 0:
            let text = gl.text_input_state()
            if fe_field < 4 and fe_field < fe_sides.length:
                if text != fe_sides[fe_field].typed:
                    fe_sides[fe_field].typed = text
                    fe_sides[fe_field].reroll = 0
                    fe_regen(fe_field)
            elif fe_field >= 10 and fe_field < 12:
                let s = fe_sides[fe_field - 10]
                if text != s.typed:
                    s.typed = text
                    s.reroll = 0
                    fe_regen(fe_field - 10)
            elif fe_field == 20: fe_address = text
            if gl.button("tab") == 1 and fe_page == "setup": fe_focus((fe_field + 1) % fe_sides.length, fe_sides[(fe_field + 1) % fe_sides.length].typed)
        if fe_page == "net" and not fe_scanned and fe_frames > 1:
            fe_hosts = lan_scan(1.5)
            fe_scanned = true
        if fe_page != "lab": fe_muster(seconds_elapsed())
        gl.clear(float4 { 0.07, 0.06, 0.05, 1.0 })
        gl.blend(1)
        if tree_open and tree_lobby:
            ui_frame(true)
            tree_tick()
            ui_flush()
            fe_frames++
            if shot != "" and fe_frames == shot_frame + 5:  // (captures: lobbytree)
                gl.screenshot(shot)
                return ""
            continue
        ui_frame(true)
        atlas_pack()
        fe_backdrop()
        var go = ""
        ui_batch():  // (the page's fills, lines and studs in as few draws as can be)
            if fe_page == "title": go = fe_title_page(dt)
            elif fe_page == "setup": go = fe_setup_page(dt)
            elif fe_page == "lab": go = fe_lab_page(dt)
            elif fe_page == "saves":
                let picked = fe_saves_card(fe_note)
                if picked == "back": go = "back"
                elif picked != "": go = "load:" + picked
            elif fe_page == "net": go = fe_net_page()
        if fe_page == "setup" or fe_page == "lab" or fe_page == "title":
            ui_flush()
        fe_draw_tip()
        ui_flush()
        bake_wanted_tick(0.012)
        fe_frames++
        // (captures: lobbytree opens the AI's tech tree; loadfirst plays on from the newest save)
        if has_s(args, "lobbytree") and fe_page == "setup" and shot_frame > 0 and fe_frames == shot_frame - 1:
            fe_open_tree(1)
            shot_frame = fe_frames
            fe_frames++
            continue
        if has_s(args, "loadfirst") and fe_page == "saves" and fe_frames == 10:
            let paths = fe_saves()
            if paths.length: go = "load:" + paths[0]
        // (tests: lobbyloop starts a battle from the setup, a map further on each time round)
        if has_s(args, "lobbyloop") and fe_page == "setup" and fe_frames == 20:
            if loop_round > 0: fe_set_map(fe_map_k + 1)
            go = "start"
        // captures: the page once its armies stand
        if shot != "" and not has_s(args, "lobbyloop") and not has_s(args, "loadfirst") and (fe_sides.length == 0 or (filter(fe_sides) s: s.views_gen != s.gen).length == 0 or fe_page == "lab") and not bake_wanted.length and shot_frame < 0: shot_frame = fe_frames + (if fe_page == "lab": 90 else: 20)
        if shot != "" and fe_frames == shot_frame:
            gl.screenshot(shot)
            if fe_page == "setup" and has_s(args, "loadershot"):
                fe_loader("Balancing the armies by fighting them: round 1 of 4", 0.16)
                gl.frame()
                fe_loader("Balancing the armies by fighting them: round 1 of 4", 0.16)
                gl.screenshot(shot + ".loader.png")
                bake_progress = fn(st, f): fe_loader(st, f)  // (the loader as the bake drives it: bake_breath)
                gl.frame()
                bake_progress("Making the armies", 0.5 + 0.45 * 60.0 / 165.0)
                gl.screenshot(shot + ".bake.png")
            return ""
        if go == "": pass()
        elif go == "quit": return ""
        elif go == "back":
            if fe_page == "net" or fe_page == "saves" or fe_page == "lab" or (fe_page == "setup" and fe_hosting): fe_hosting = false
            fe_page = if (fe_page == "saves" or fe_page == "net") and fe_back != "title": fe_back else: "title"
            fe_back = "title"
            fe_field = -1
            fe_note = ""
        elif go == "setup" or go == "lab" or go == "saves" or go == "net":
            fe_page = go
            fe_frames = 0
            fe_note = ""
            fe_field = if go == "setup": 0 elif go == "lab": 10 else: -1
            if go == "setup" or go == "lab": gl.set_text_input(fe_sides[0].typed)
            if go == "net":
                fe_scanned = false
                fe_hosts = []
                fe_field = 20
                gl.set_text_input(fe_address)
            if go == "lab" and fe_sides.length != 2:  // (the lab is two sides)
                fe_set_map(max(0, str_index(fe_maps, "reed_meadow")))
        elif go == "host":  // from the network page: the battle setup, for hosting
            fe_hosting = true
            if fe_sides.length != 2: fe_set_map(max(0, str_index(fe_maps, "reed_meadow")))
            fe_page = "setup"
            fe_frames = 0
        elif go == "join":
            gl.end_text_input()
            join_ip = fe_address.fe_trim()
            return "join"
        elif starts_with(go, "load:"):
            gl.end_text_input()
            return go
        elif go == "start" or go == "fight":
            gl.end_text_input()
            lobby_prompts = map(fe_sides.length) i: fe_prompt(i)
            lobby_rerolls = map(fe_sides) s: s.reroll
            lobby_teams = map(fe_sides) s: s.team
            lobby_levels = map(fe_sides) s, i: if i == 0 or (fe_hosting and i == 1): "" else: FE_LEVELS[s.level].lowercase()
            if fe_hosting:
                hosting = true
                net_people = 2
                return "host"
            fe_loader("Setting up the battle", 0.02)  // (shown at once: the start's work comes before the next frame)
            gl.frame()
            fe_loader("Setting up the battle", 0.02)
            return "play"
    return ""
