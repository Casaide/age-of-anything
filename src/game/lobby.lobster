// ------------------------------------------------------------------ the front end (scenes/match_setup.gd, race_lab.gd, match_loader.gd,
// src/view/ui/saves_page.gd, net_page.gd, trait_strip.gd, ui_banner.gd)
// The title screen (the two rolled armies facing each other on a hill under the title; battle the AI, play on
// the network, load a game, the Race Lab, quit) leads to the battle setup: a side panel per player in its race's
// culture (frame, crest, banner with the race's name, its army idling on a lit stage, dice and prompt, the roster
// as its lines' names with every line age by age on hover, one line of bonuses, lacks and notes with the lists on
// hover), a cast "vs" in the middle, the map card, the AI's level and Start. A map with more than two starts is a
// team game: a panel per player, you and an AI ally against two AIs, each with its dice, prompt and AI level. Each
// banner's Tech tree opens that race's page (game/techtree.lobster). Laid out at 1600 x 950 and scaled as Godot's at
// its default UI size (fe_fit; fixed sizes: nothing moves when a race changes). The pages are immediate mode on the UI layer
// (game/ui.lobster); a pad walks them by focus (ui_frame), X rolls the focused panel's dice, Start starts, B goes back.
// run_front returns what was chosen: "play", "host", "join", "load:<path>", or "" (quit). Imported by game.lobster
// after the lobby's helpers (roster_views, balance_for_match for the Race Lab's Test).

let FE_DESIGN = float2 { 1600.0, 950.0 }
let FE_SIZE = 0.76                                  // the share of filling the window the lobby draws at (Godot's default UI size)
let FE_UNIT_INCHES = 0.6                            // the setup page's stage: a unit for each this much of its width on the screen
let FE_GRASS = float4 { 0.306, 0.431, 0.165, 1.0 }  // #4e6e2a
let FE_LEVELS = [ "Easy", "Normal", "Hard" ]
let TREECHECK_MS = 1000                                        // treecheck: the longest a frame of the lobby's tech tree may take while its pictures are made (#430)
let FRAMECHECK_MS = 50                                         // framecheck: the longest the title page may spend on a frame while its armies bake (#494)
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
    dirty_at = -1.0
    picks:[JV] = []         // the few the stage shows (fe_stage_pick)
    traits:[[string]] = []  // per group (bonuses, own research, lacks, heroes, notes): its lines

class FeTrait:
    title:string
    one:string

let FE_TRAITS = [ FeTrait { "Bonuses", "bonus" }, FeTrait { "Own research", "own research" }, FeTrait { "Lacks", "lack" }, FeTrait { "Heroes", "hero" }, FeTrait { "Notes", "note" } ]

var fe_sides = []::FeSide
var fe_page = "title"  // title, setup, lab, saves, net, settings
var fe_back = "title"  // where the saves and network pages go back to
var fe_k = 1.0         // screen px per design px
var fe_w = 1600.0      // the window's width in design px
var fe_h = 950.0       // its height
var fe_field = -1      // the box that has the keyboard: a side (0..3), 10 + a lab side, 20 the address; -1 none
var fe_field_at = 0.0  // when that box was last clicked or typed in (its caret is lit for a moment after; #431)
var fe_bs_held = -1.0  // how long backspace has been down, -1 up (it repeats when held; #431)
var fe_maps = []::string
var fe_map_k = 0
var fe_map_json = jobj()
var fe_mode_k = 0
var fe_modes = []::[string]  // id, name, desc
var fe_rules = jobj()
var fe_tip_lines = []::string  // the hover card this frame
var fe_hosting = false         // the battle setup is for hosting a network game
var fe_rooms = []::Room        // the host's room while the battle setup hosts (#519): joiners take sides in it
var fe_swarm = Swarm {}        // online play's sidecar for the room, or the guest page (#514)
var fe_guests = []::Guest      // the guest page's link to a host's room
var fe_join_what = ""          // what the joiner joins: a join code or an address
var fe_joining = false         // the battle setup is a joiner's view of a host's room (#521)
var fe_my_side = -1            // the side the joiner holds, as last seen
var fe_guest_words = ""        // captures: the joiner's army, typed on the side it's given
var fe_code_copied = ""        // the join code last put on the clipboard
var fe_note = ""               // a line at the foot (the saves page, the network page)
var fe_frames = 0
var fe_pad = false  // the pad was used last (its hints shown)
var fe_hosts = []::LanHost
var fe_scanned = false
var fe_address = ""
var fe_lab_rules = 0
let fe_lab_scroll = [ 0.0, 0.0 ]
var fe_lab_units = [ []::JV, []::JV ]  // the Race Lab's lineups: every unit of each side's race
let fe_lab_gen = [ -1, -1 ]

// The lobby's armies let go (their voxel looks stay baked, in the bake cache too).
def fe_free_views():
    for(fe_sides) s: s.picks = []
    fe_lab_units = [ []::JV, []::JV ]
var fe_test_lines = []::string
var fe_tip_k = 0
var fe_tip_t = 0.0
var fe_tips = []::string
var loop_round = 0  // (tests: lobbyloop's matches so far)

// ---- layout

def fe_trim(s:string) -> string:
    let t = tokenize(s, "\n", " \t")
    return if t.length: t[0] else: ""

// Godot's lobby at its default UI size (40%: 0.6 + 0.4 * 0.4 of filling the window, match_setup.gd's _rescale), never
// below 1 where the design fits at 1, all of the window where it doesn't (the Steam Deck).
def fe_fit():
    let ws = float(gl.window_size())
    let fill = min(ws.x / FE_DESIGN.x, ws.y / FE_DESIGN.y)
    fe_k = min(fill, max(min(1.0, fill), fill * FE_SIZE) * float(hud_size) / 115.0)  // (the player's UI scale, 115% the default)
    fe_w = ws.x / fe_k
    fe_h = ws.y / fe_k

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

// A caption's colour: the look's metal, lit (theme.gd's "Caption").
def fe_caption(lk:UiLook) -> float4: return lk.metal + (float4_1 - lk.metal) * 0.25

// A rule under a heading: a fine line with a diamond at its middle (theme.gd's Rule), its middle at y.
def fe_rule(x:float, y:float, w:float, col:float4):
    let t = max(1.0, fe_k)
    ui_fill(float2 { x + 6.0 * fe_k, y + t }, float2 { w - 12.0 * fe_k, t }, float4 { 0.0, 0.0, 0.0, 0.55 })
    ui_fill(float2 { x + 6.0 * fe_k, y }, float2 { w - 12.0 * fe_k, t }, float4 { col.x, col.y, col.z, 0.7 })
    let c = float2 { x + w / 2.0, y + t / 2.0 }
    let d = 4.5 * fe_k
    let pts = [ c + float2 { 0.0, -d }, c + float2 { d, 0.0 }, c + float2 { 0.0, d }, c + float2 { -d, 0.0 } ]
    ui_paint_poly(pts, [ col, col, col, col ], [ 0, 1, 2, 0, 2, 3 ], ui_material("bronze"))
    for(4) k: ui_line(pts[k], pts[(k + 1) % 4], t, float4 { 0.0, 0.0, 0.0, 0.6 })

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
    if ui_clicked() and fe_over(at, size): fe_focus(id, text)
    let focused = fe_field == id
    let acc = ui_look.accent
    if focused:                        // the box with the keyboard: tinted, and ringed in the accent inside its frame (#431)
        let fw = max(3.0, 6.0 * ui())  // (the frame's width, as ui_box draws it)
        ui_fill(at + float2_1 * fw, size - float2_1 * fw * 2.0, float4 { acc.x, acc.y, acc.z, 0.16 })
        ui_outline(at + float2_1 * (fw - 1.0), size - float2_1 * (fw - 1.0) * 2.0, max(2.0, 3.0 * fe_k), acc)
    let s = if text == "": placeholder else: text  // (empty: the placeholder stays, the caret before it)
    let col = if text == "": ui_look.dim else: ui_look.text
    var f = fs
    while f > 10 and ui_text_wf(s, f, 0) > size.x - 34.0 * fe_k: f -= 2
    let y = at.y + (size.y - float(f)) / 2.0 - 2.0 * fe_k
    let cw = max(2.0, 2.5 * fe_k)  // the caret's width; an empty focused box starts the placeholder after it
    let lead = if focused and text == "": cw + 6.0 * fe_k else: 0.0
    let x = lead + (if centred: at.x + (size.x - ui_text_wf(s, f, 0)) / 2.0 else: at.x + 14.0 * fe_k)
    ui_text(float2 { x, y }, s, f, col)
    if focused and tf_caret_on(fe_clock() - fe_field_at):  // the caret: a bar after the text (before the placeholder)
        let cx = if text == "": x - lead else: x + ui_text_wf(text, f, 0) + 2.0 * fe_k
        ui_fill(float2 { cx, y + float(f) * 0.08 }, float2 { cw, float(f) * 1.05 }, ui_look.text)  // (the text's colour: it stands off the ring)

// The text in the box that has the keyboard.
def fe_field_text() -> string:
    if fe_field >= 0 and fe_field < 4 and fe_field < fe_sides.length: return fe_sides[fe_field].typed
    if fe_field >= 10 and fe_field < 12: return fe_sides[fe_field - 10].typed
    if fe_field == 20: return fe_address
    return ""

def fe_focus(id:int, text:string):
    fe_field = id
    fe_field_at = fe_clock()
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
    let d = at(lib_data("modes.json"), "modes")
    fe_modes = map(d.keys) id: [ id, gstr(at(d, id), "name", id), gstr(at(d, id), "desc", "") ]
    fe_tips = map(glist(lib_data("tips.json"), "tips")) t: as_str(t)

let fe_map_meshes = dictionary<string, resource<mesh>>(16)

// The map as a small isometric diamond, coloured from data/terrain.json, the starts in gold; 1 unit = a tile's half width.
def fe_map_mesh(id:string, m:JV) -> resource<mesh>:
    let had = fe_map_meshes.get(id)
    if had: return had
    let terr = at(lib_data("terrain.json"), "terrain")
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

// The clock the army waits on: a recording's frames take far longer than they play for.
def rec_frames(s:float) -> int: return int(s * rec_fps)  // (the typing's waits in frames of the take, at any fps:)
def fe_clock() -> float: return if rec_dir != "": float(rec_n) / rec_fps else: seconds_elapsed()

// A prompt changed: the name, roster and traits at once (generation is instant), the army once typing stops.
def fe_regen(i:int):
    let s = fe_sides[i]
    let race = generate(fe_prompt(i), fe_rules, s.reroll)
    s.race = race
    s.gen++
    s.dirty_at = fe_clock()
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

// A side's stage army once its race has settled (no typing for a moment): its voxel looks asked for as they're drawn.
def fe_muster(now:float):
    for(fe_sides) s:
        if s.views_gen != s.gen and now - s.dirty_at > FE_BAKE_AFTER:
            s.picks = fe_stage_pick(glist(s.race, "units"), 6)
            s.views_gen = s.gen

// Units (their recipes' voxel looks, standing) at screen spots (their feet), z screen px per canvas px, drawn back to
// front, facing the other side; a unit not baked yet is asked for (between frames) and shows when it is.
def fe_draw_units(units:[JV], spots:[float2], z:float, p:int, alpha:float, right:bool):
    let tc = team_rgb[p % team_rgb.length]
    let order = map(units.length) k: k
    insertion_sort(order) a, b: spots[a].y < spots[b].y
    let figs = map(units) u: vx_figure_facing(at(u, "recipe"), float2 { if right: -1.0 else: 1.0, 0.45 })
    def draw(f:int, k:int, col:float4):
        let fr = frames[f]
        let sc = z * 1.5 * fr.k
        sprite_xf(f, [ sc, 0.0, 0.0, sc, spots[k].x - float(fr.ox) * sc, spots[k].y - float(fr.oy) * sc ], col)
    b_sheet = -1
    for(order) k:  // the shadows first, on the ground under every figure (as in a match: world_draw)
        if figs[k] >= 0:
            let sf = vx_shadow_for(figs[k])
            if sf >= 0: draw(sf, k, float4 { 1.0, 1.0, 1.0, alpha })
    for(order) k:
        if figs[k] >= 0: draw(figs[k], k, float4 { tc.x, tc.y, tc.z, alpha })
    flush_sprites()

// The roster in words: each line's name, the creature's noun left off when most share it; a line the race lacks
// struck through (as the tech tree page crosses it out) and not counted. Returns the words and which are struck.
def fe_lacks(race:JV, slot:string) -> bool:
    let ident = identity_of(rstr(race, "creature"), rstr(race, "family"))
    return race_lacks(ident, slot, fe_rules) or has_s(gstrs(race, "lacks"), slot)

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
    let blds = at(lib_data("buildings.json"), "buildings")
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
    open_tree_of(race, identity_of(rstr(race, "creature"), rstr(race, "family")), fe_rules, i)

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
            let cw = ui_text_wf(label, fs, 3) + 16.0 * fe_k
            if x + cw <= at.x + w:
                ui_fill(float2 { x, at.y }, float2 { cw, h }, float4 { 0.0, 0.0, 0.0, 0.55 })
                ui_outline(float2 { x, at.y }, float2 { cw, h }, max(1.0, fe_k), ui_look.frame * float4 { 0.7, 0.7, 0.7, 1.0 })
                ui_text_f(float2 { x + 8.0 * fe_k, at.y + (h - float(fs)) / 2.0 - 1.0 * fe_k }, label, fs, FE_TRAIT_COLS[g], 3, 0.0)
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
// The game's own ground under a stage (Dominic, 2026-11-04: "just put them on our ground texture"): the terrain shader
// over a patch of plain grass (blank masks: no paths, reeds, swamp or rock), at the units' scale (k screen px a world
// px), each side's patch a different stretch of it.
var fe_turf_tex:resource<texture>? = nil
def fe_turf(at:float2, size:float2, k:float, side:int):
    if not fe_turf_tex: fe_turf_tex = gl.create_texture(map(2): map(2): float4_0, texture_format_clamp | texture_format_nomipmap)
    let tex = fe_turf_tex
    ui_batch_flush()
    let local = size / k
    let o = float2 { float(side) * 200.0 - 300.0, 1400.0 }  // (world px: well inside the 128 x 128 map it says)
    gl.set_shader("terrain")
    gl.set_uniform("map_size", float2 { 128.0, 128.0 })
    gl.set_uniform("art_px", k / ART_K)  // (screen px an art px, as the match passes it)
    gl.set_uniform("dev_px", k)
    gl.set_uniform("time", 0.0)
    for(4) u: gl.set_primitive_texture(u, tex)
    gl.set_primitive_texture(4, ground_atlas())
    gl.set_primitive_texture(5, tex)
    gl.translate(at):
        gl.scale(k):
            gl.translate(-o):
                gl.draw_mesh("PT", [ float3 { o.x, o.y, 0.0 }, float3 { o.x + local.x, o.y, 0.0 }, float3 { o.x + local.x, o.y + local.y, 0.0 }, float3 { o.x, o.y + local.y, 0.0 } ],
                             []::float4, []::float3, map(4): float2_0, []::float2, [ 0, 2, 1, 0, 3, 2 ])
    gl.set_shader("color")

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
    ui_text_f(float2 { x + 26.0 * fe_k, y + top_h / 2.0 - 10.0 * fe_k }, who.uppercase(), fz(17.0), fe_caption(lk), 3, 0.0)
    let tw = ui_text_wf("Tech tree", fz(18.0), 1) + 56.0 * fe_k  // (sized to its words, as a Godot button)
    if ui_button(float2 { x + w - tw, y }, float2 { tw, top_h }, "", false): fe_open_tree(i)
    tb_icon("research", float2 { x + w - tw + 12.0 * fe_k, y + 7.0 * fe_k }, 22.0 * fe_k, 1.0)
    ui_text_f(float2 { x + w - tw + 40.0 * fe_k, y + 6.0 * fe_k }, "Tech tree", fz(18.0), lk.text, 1, 0.0)
    if fe_over(float2 { x + w - tw, y }, float2 { tw, top_h }): fe_tip([ "Everything this race can build, train and research, and its bonuses" ])
    if fe_joining and fe_lobby_who(i) == ROOM_AI:               // (a joiner takes any side an AI holds, ally or enemy, #521)
        let kw = ui_text_wf("Join", fz(18.0), 1) + 56.0 * fe_k  // (a call to arms, as the Tech tree button beside it)
        let kx = x + w - tw - 8.0 * fe_k - kw
        if ui_button(float2 { kx, y }, float2 { kw, top_h }, "", true): guest_take(fe_guests[0], i)
        tb_icon("call_to_arms", float2 { kx + 12.0 * fe_k, y + 7.0 * fe_k }, 22.0 * fe_k, 1.0)
        ui_text_f(float2 { kx + 40.0 * fe_k, y + 6.0 * fe_k }, "Join", fz(18.0), lk.title, 1, 0.0)
        if fe_over(float2 { kx, y }, float2 { kw, top_h }): fe_tip([ "Play this side yourself, with your own army" ])
    if compact and i > 0 and not fe_player_side(i) and not fe_joining:
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
    let line = "{gstr(cr, "plural", rstr(s.race, "creature"))}  ·  {capitalize(rstr(s.race, "family"))} culture"
    let line_y = y + (if compact: 42.0 else: 56.0) * fe_k
    let lfs = fz(if compact: 17.0 else: 19.0)
    ui_text_f(float2 { x + 20.0 * fe_k, line_y }, line, lfs, lk.text, 1, 1.5 * fe_k)
    if fe_over(float2 { x, y }, float2 { w, bh }) and glist(s.race, "notes").length: fe_tip(append([ "The generator\'s notes" ], map(glist(s.race, "notes")) n: as_str(n)))
    if compact:
        let tx = x + 20.0 * fe_k + ui_text_wf(line, lfs, 1) + 14.0 * fe_k
        fe_traits(s, float2 { tx, line_y - 1.0 * fe_k }, x + w - tx - 8.0 * fe_k, 24.0 * fe_k, fz(12.0))
    y += bh + 12.0 * fe_k
    // the stage: the army idling on the game's ground, sunk in the panel
    let foot_h = (if compact: 48.0 + 9.0 + 22.0 else: 68.0 + 9.0 + 48.0 + 9.0 + 30.0) * fe_k
    let st_at = float2 { x, y }
    let st_size = float2 { w, at.y + size.y - pad - foot_h - 12.0 * fe_k - y }
    fe_well(st_at, st_size)
    let in_at = st_at + float2_1 * 3.0 * fe_k
    let in_size = st_size - float2_1 * 6.0 * fe_k
    let turf_zm = max((if st_size.y >= 144.0 * 1.45 * fe_k: 3.0 else: 2.0) * fe_k, min(in_size.x / (float(max(1, min(s.picks.length, 6))) * 40.0), in_size.y / 62.0))
    fe_turf(in_at, in_size, turf_zm / 1.5, i)
    let forging = s.views_gen != s.gen
    if s.picks.length:
        // as many as the stage has room for: one each FE_UNIT_INCHES at 96 dpi, at most six (gl.dpi(0) isn't a
        // display under SDL3: it logged an error every frame and gave 96 anyway)
        let inches = in_size.x / 96.0
        let n = min(s.picks.length, clamp(int(inches / FE_UNIT_INCHES), 2, 6))
        let zm = max((if st_size.y >= 144.0 * 1.45 * fe_k: 3.0 else: 2.0) * fe_k, min(in_size.x / (float(n) * 40.0), in_size.y / 62.0))
        let right = s.team != fe_sides[0].team or (fe_sides.length == 2 and i == 1)
        let vs = s.picks.slice(0, n)
        let spots = map(n) k:
            let feet = if in_size.y / zm >= 40.0: (if k % 2 == 0: 0.62 else: 0.8) else: 0.92
            let along = (float(k) + 0.75) / (float(n) + 0.5)
            in_at + float2 { in_size.x * (if right: 1.0 - along else: along), in_size.y * feet }
        fe_draw_units(vs, spots, zm / 1.5, i, if forging: 0.32 else: 1.0, right)
    if forging:  // the forge veil: the old army dims while the new one is made
        ui_fill(in_at, in_size, float4 { 0.05, 0.03, 0.01, 0.35 })
        ui_text_c(in_at.x + in_size.x / 2.0, in_at.y + in_size.y / 2.0 - 12.0 * fe_k, "Forging the army...", fz(20.0), lk.accent, 2, 1.5 * fe_k)
    elif not compact:
        ui_text_f(float2 { in_at.x + 8.0 * fe_k, in_at.y + in_size.y - 24.0 * fe_k }, "{glist(s.race, "units").length} units, every one priced by its parts", fz(15.0), float4 { 0.96, 0.93, 0.83, 0.85 }, 0, 1.0 * fe_k)
    y = st_at.y + st_size.y + 12.0 * fe_k
    // the dice, then the prompt
    let ph = (if compact: 48.0 else: 68.0) * fe_k
    let mine = if fe_joining: fe_guests.length > 0 and i == fe_guests[0].side else: not fe_player_side(i)
    if not mine:  // (a joiner's on the host, everyone else's on a joiner: the words come from them)
        fe_well(float2 { x, y }, float2 { w, ph })
        ui_text_f(float2 { x + 14.0 * fe_k, y + ph / 2.0 - 12.0 * fe_k }, if s.typed != "": s.typed elif fe_joining: "the host is choosing..." else: "the player is choosing...", fz(if compact: 18.0 else: 22.0), lk.dim, 1, 0.0)
    else:
        if fe_dice(float2 { x, y }, ph): fe_roll(i)
        fe_box(i, float2 { x + ph + 10.0 * fe_k, y }, float2 { w - ph - 10.0 * fe_k, ph }, s.typed, "...or describe your race", fz(if compact: 20.0 else: 25.0), false)
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
    ui_text_c(ws.x / 2.0, ws.y - 26.0 * fe_k, build_label_now(net_version()), fz(15.0), lk.dim, 0, 0.0)  // which build this is (#500)
    let zm = 3.0 * fe_k
    let cw = ws.x / zm
    for(min(2, fe_sides.length)) i:
        let s = fe_sides[i]
        if s.picks.length and s.views_gen == s.gen:
            let n = s.picks.length
            let vs = map(n) k: s.picks[n - 1 - k]  // the big ones at the front
            let spots = map(n) k: float2 { (if i == 0: cw * (0.42 - 0.055 * float(k)) else: cw * (0.58 + 0.055 * float(k))) * zm, hill_at.y + hill_h * (if k % 2 == 0: 0.7 else: 0.86) }
            fe_draw_units(vs, spots, zm / 1.5, i, 1.0, i == 1)
    def standing(s:FeSide) -> bool: return s.views_gen == s.gen and (find(s.picks) u: vx_engine_made(at(u, "recipe")) and not vx_ready(vx_look_for(at(u, "recipe")))) < 0
    if (find(min(2, fe_sides.length)) i: not standing(fe_sides[i])) >= 0:  // (while they bake, so the hill isn't just empty, #494)
        ui_text_c(ws.x / 2.0, hill_at.y + hill_h * 0.7, "Mustering the armies...", fz(20.0), lk.dim, 0, 0.0)
    // the column (match_setup.gd's _menu): crest, title, tag line, the plaque of buttons, the foot; centred
    // over the hill's upper half
    let cx = ws.x / 2.0
    let foot = fe_wrap("Type \"centaur romans\" or \"sewer rats with cheese hammers\": the game builds the race and prices every unit fairly.", fz(17.0), 640.0 * fe_k)
    let plaque_size = float2 { 400.0 + 48.0, 88.0 + 62.0 * 5.0 + 14.0 * 5.0 + 44.0 }
    let col_h = 90.0 + 130.0 + 33.0 + 26.0 + plaque_size.y + 20.0 + 22.0 * float(foot.length) + 10.0 * 7.0
    var y = max(0.0, (fe_h - 270.0 * 0.55 - col_h) / 2.0)
    tb_icon_wide("crest_" + lk.ornament, float2 { cx, (y + 45.0) * fe_k }, 90.0 * fe_k)
    y += 100.0
    ui_text_c(cx, (y + 6.0) * fe_k, "Age of Anything", fz(104.0), lk.title, 2, 3.5 * fe_k)
    y += 140.0
    ui_text_c(cx, y * fe_k, "Your civilisation is whatever you can describe.", fz(26.0), lk.dim, 0, 0.0)
    y += 33.0 + 10.0 + 26.0 + 10.0
    let plaque_at = float2 { cx - plaque_size.x / 2.0 * fe_k, y * fe_k }
    ui_box(plaque_at, plaque_size * fe_k, 1, lk.frame * float4 { 0.6, 0.6, 0.6, 1.0 }, true)
    var by = y + 22.0
    var go = ""
    for([ [ "Battle the AI", "setup" ], [ "Play on the network", "net" ], [ "Load game", "saves" ], [ "Race Lab", "lab" ], [ "Settings", "settings" ], [ "Quit", "quit" ] ]) item, k:
        let h = if k == 0: 88.0 else: 62.0
        if ui_button(D(cx / fe_k - 200.0, by), D(400.0, h), "", k == 0): go = item[1]
        if k == 0: ui_text_c(cx, (by + h / 2.0 - 21.0) * fe_k, item[0], fz(31.0), lk.title, 2, 1.5 * fe_k)
        else: ui_text_c(cx, (by + h / 2.0 - 15.0) * fe_k, item[0], fz(24.0), lk.text, 1, 1.0 * fe_k)
        by += h + 14.0
    y += plaque_size.y + 20.0
    for(foot) l, k: ui_text_c(cx, (y + 22.0 * float(k)) * fe_k, l, fz(17.0), lk.dim, 0, 0.0)
    if gl.button("escape") == 1 or gl.button("controller_b") == 1: go = "quit"
    return go

// Settings (the title's and the pause menu's): a card like the saves', the music, the sound and the UI scale, each a
// row with - and + either side of the level (saved to settings.txt as it changes). Returns "back" when it's left.
def fe_settings_card() -> string:
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    ui_fill(float2_0, ws, float4 { 0.0, 0.0, 0.0, 0.5 })
    let size = D(560.0, 26.0 + 66.0 + 14.0 + 3.0 * 58.0 + 58.0 + 40.0 + 50.0 + 30.0)
    let at = (ws - size) / 2.0
    fe_panel(at, size, lk, true)
    var y = at.y + 26.0 * fe_k
    ui_text_c(ws.x / 2.0, y, "Settings", fz(44.0), lk.title, 2, 2.0 * fe_k)
    y += 66.0 * fe_k
    fe_rule(at.x + 40.0 * fe_k, y, size.x - 80.0 * fe_k, lk.metal)
    y += 14.0 * fe_k
    let w = size.x - 80.0 * fe_k
    for([ "Music", "Sound", "UI scale" ]) name, k:
        let h = 48.0 * fe_k
        let lv = if k == 0: music_level elif k == 1: sound_level else: hud_size
        let step = if k == 2: 10 else: 1
        var nv = lv
        if ui_button(float2 { at.x + 40.0 * fe_k, y }, float2 { h, h }, "-", false): nv = max(if k == 2: 70 else: 0, lv - step)
        if ui_button(float2 { at.x + 40.0 * fe_k + w - h, y }, float2 { h, h }, "+", false): nv = min(if k == 2: 200 else: 10, lv + step)
        let fs = fz(21.0)
        let shown = if k == 2: "{nv}%" elif nv == 0: "off" else: "{nv * 10}%"
        ui_text_c(ws.x / 2.0, y + (h - float(fs)) / 2.0 - 2.0 * fe_k, "{name}: {shown}", fs, lk.text, 1, 0.0)
        if nv != lv:
            if k == 0: music_level = nv
            elif k == 1: sound_level = nv
            else: hud_size = nv
            volume_save()
        y += 58.0 * fe_k
    if ui_button(float2 { at.x + 40.0 * fe_k, y }, float2 { w, 48.0 * fe_k }, if window_fullscreen: "Fullscreen: on" else: "Fullscreen: off", false): window_toggle()
    y += 58.0 * fe_k
    ui_text_c(ws.x / 2.0, y + 4.0 * fe_k, "In a match, Ctrl/Cmd + and - change the UI scale too. Cmd or Alt + Enter: fullscreen.", fz(16.0), lk.dim, 0, 0.0)
    y += 40.0 * fe_k
    var go = ""
    if ui_button(float2 { at.x + 40.0 * fe_k, y }, float2 { w, 50.0 * fe_k }, "Back", false): go = "back"
    if gl.button("escape") == 1 or gl.button("controller_b") == 1: go = "back"
    return go

// The battle setup: a panel per player (your team on the left), the middle column, Start.
// ---- the network lobby (#519): the host's room and the guest page

// A side a joiner holds in the host's room.
def fe_player_side(i:int) -> bool:
    if not fe_hosting or not fe_rooms.length: return false
    let r = fe_rooms[0]
    return i < r.sides.length and r.sides[i].who == ROOM_PLAYER

def fe_room_open():
    fe_room_close()
    fe_rooms = [ room_open(NET_PORT, "Battle", fe_maps[fe_map_k]) ]
    fe_swarm = swarm_host(NET_PORT)
    fe_code_copied = ""

def fe_room_close():
    swarm_stop(fe_swarm)
    fe_swarm = Swarm {}
    fe_rooms = []
    fe_guests = []
    fe_joining = false
    fe_my_side = -1

// The room each frame: our sides into it, joiners' words out of it into their sides, the code onto the clipboard.
def fe_room_tick():
    if not fe_rooms.length: return
    let r = fe_rooms[0]
    r.map_id = fe_maps[fe_map_k]
    r.mode = lobby_mode
    room_sides(r, map(fe_sides) side: side.team, map(fe_sides.length) i: fe_prompt(i), map(fe_sides) side: side.reroll)
    room_tick(r)
    for(r.sides) rs, i:
        if rs.who == ROOM_PLAYER and i < fe_sides.length and (fe_sides[i].typed != rs.prompt or fe_sides[i].reroll != rs.reroll):
            fe_sides[i].typed = rs.prompt
            fe_sides[i].reroll = rs.reroll
            fe_regen(i)
    swarm_poll(fe_swarm)
    if fe_swarm.code != "" and fe_swarm.code != fe_code_copied:
        gl.set_clipboard(fe_swarm.code)
        fe_code_copied = fe_swarm.code

// The host's line under the title: how others join.
def fe_room_line() -> string:
    let here = my_ipv4()
    let lan = if here != "": "on this network: {here}" else: ""
    if fe_swarm.code != "": return "Join code: {fe_swarm.code} (copied; C or Y copies again)" + (if lan != "": "  ·  or " + lan else: "")
    if fe_swarm.error != "": return "Online play is off ({fe_swarm.error})" + (if lan != "": "  ·  join " + lan else: "")
    return "Opening the game to players..."

// The guest page: from the network page's Join; connect (through the sidecar for a code), then the host's room.
def fe_guest_start(what:string):
    fe_room_close()
    fe_join_what = what
    fe_joining = true
    let code = join_code_in(what)
    if code != "": fe_swarm = swarm_join(code, 0)
    else: fe_guests = [ guest_new(net_join(what, NET_PORT)) ]

def fe_guest_status() -> string:
    if fe_swarm.error != "": return "No online play: {fe_swarm.error}"
    if not fe_guests.length: return "Starting online play..."
    let g = fe_guests[0]
    if g.error != "": return "Could not join: {g.error}"
    if fe_swarm.out != "" and fe_swarm.peers == 0: return "Looking for the host of {fe_join_what}..."
    if g.side < 0: return "Joining {fe_join_what}..."
    return "In the host\'s lobby: take a side, describe your army, and the host starts the battle"

// Who holds a side in the host's room, as the joiner last heard: ROOM_HOST, ROOM_AI, ROOM_PLAYER ("" before the lobby comes).
def fe_lobby_who(i:int) -> string:
    if not fe_guests.length: return ""
    let sides = glist(fe_guests[0].lobby, "sides")
    return if i < sides.length: gstr(sides[i], "who", "") else: ""

// What a side is, on the joiner's setup: its own, the host's, another player's, or an AI's (an ally of the joiner's or not).
def fe_joiner_who(i:int, who:string, my_team:int) -> string:
    if i == fe_my_side: return "You"
    if who == ROOM_HOST: return "The host"
    if who == ROOM_PLAYER: return "A player"
    return if fe_sides[i].team == my_team: "Ally (AI)" else: "The AI"

// The joiner's setup, each frame: connect (through the sidecar for a code), then the host's room into our sides (its
// map, mode, teams and every other side's words), and our side's words out to it. "join" once the host starts.
def fe_guest_sync() -> string:
    if fe_swarm.out != "":
        swarm_poll(fe_swarm)
        if not fe_guests.length and fe_swarm.port > 0: fe_guests = [ guest_new(net_join("127.0.0.1", fe_swarm.port)) ]
    if not fe_guests.length: return ""
    let g = fe_guests[0]
    guest_tick(g)
    if g.world != "": return "join"
    let map_id = gstr(g.lobby, "map", "")
    if map_id != "" and map_id != fe_maps[fe_map_k] and str_index(fe_maps, map_id) >= 0: fe_set_map(str_index(fe_maps, map_id))
    let mode = str_index(map(fe_modes) m: m[0], gstr(g.lobby, "mode", ""))
    if mode >= 0: fe_mode_k = mode
    if g.side != fe_my_side and g.side >= 0 and g.side < fe_sides.length:  // (a side taken: our army goes with us)
        if fe_my_side >= 0 and fe_my_side < fe_sides.length:
            let was = fe_sides[fe_my_side]
            let now = fe_sides[g.side]
            now.typed = was.typed
            now.rolled = was.rolled
            now.reroll = was.reroll
            fe_regen(g.side)
        elif fe_guest_words != "":  // (captures: the words to join with)
            fe_sides[g.side].typed = fe_guest_words
            fe_sides[g.side].reroll = 0
            fe_regen(g.side)
        fe_my_side = g.side
    for(glist(g.lobby, "sides")) sd, i:
        if i < fe_sides.length:
            let s = fe_sides[i]
            s.team = gint(sd, "team", s.team)
            let words = gstr(sd, "prompt", "")
            let reroll = gint(sd, "reroll", 0)
            if i != g.side and words != "" and (s.typed != words or s.reroll != reroll):
                s.typed = words
                s.reroll = reroll
                fe_regen(i)
    if g.side >= 0 and g.side < fe_sides.length: guest_prompt(g, fe_prompt(g.side), fe_sides[g.side].reroll)
    return ""

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
    let row_h = fe_h - 22.0 - row_y
    let centre_w = 420.0
    let col_w = (fe_w - 52.0 - centre_w - 44.0) / 2.0
    let left = filter(n) i: fe_sides[i].team == fe_sides[0].team
    let right = filter(n) i: fe_sides[i].team != fe_sides[0].team
    for([ left, right ]) col, c:
        let x = 26.0 + float(c) * (col_w + 22.0 + centre_w + 22.0)
        let each = (row_h - 30.0 * float(col.length - 1)) / float(max(1, col.length))
        for(col) i, r:
            let mine_t = if fe_joining and fe_my_side >= 0: fe_sides[fe_my_side].team else: fe_sides[0].team
            let jw = fe_lobby_who(i)
            let who = if fe_joining: fe_joiner_who(i, jw, mine_t) elif i == 0: "You" elif fe_player_side(i): "A player" elif fe_hosting and c == 0: "Ally (AI): a player can take it" elif fe_hosting: "The AI: a player can take it" elif c == 0: "Ally (AI)" else: "The AI"
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
    ui_text_c(mid * fe_k, y * fe_k, "BATTLEFIELD", fz(14.0), fe_caption(lk), 3, 0.0)
    y += 26.0
    if not fe_joining:  // (a joiner's map and mode are the host's)
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
    ui_text_c(mid * fe_k, y * fe_k, "{gint(fe_map_json, "width", 0)} x {gint(fe_map_json, "height", 0)} tiles  ·  " + (if starts == 2: "1 v 1" else: "{starts / 2} v {starts - starts / 2}"), fz(16.0), lk.dim, 0, 0.0)
    y += 32.0
    if not fe_joining:
        if ui_button(D(cx + 30.0, y), D(36.0, 36.0), "<", false): fe_mode_k = (fe_mode_k + fe_modes.length - 1) % fe_modes.length
        if ui_button(D(cx + centre_w - 66.0, y), D(36.0, 36.0), ">", false): fe_mode_k = (fe_mode_k + 1) % fe_modes.length
    ui_text_c(mid * fe_k, (y + 6.0) * fe_k, "Mode: " + fe_modes[fe_mode_k][1], fz(19.0), lk.text, 0, 0.0)
    if fe_over(D(cx + 70.0, y), D(centre_w - 140.0, 36.0)) and fe_modes[fe_mode_k][2] != "": fe_tip(append([ fe_modes[fe_mode_k][1] ], fe_wrap(fe_modes[fe_mode_k][2], fz(15.0), 520.0 * fe_k)))
    lobby_mode = fe_modes[fe_mode_k][0]
    // the AI's level (1v1; a team game has it in each AI's panel), Start, the hint
    let by = fe_h - 22.0 - 30.0 - 100.0
    if not compact and not fe_player_side(1) and not fe_joining:
        let lc_y = by - 18.0 - 92.0
        ui_box(D(cx + 8.0, lc_y), D(card_w, 92.0), 1, lk.face, false)
        ui_text_c(mid * fe_k, (lc_y + 12.0) * fe_k, "THE AI PLAYS", fz(14.0), fe_caption(lk), 3, 0.0)
        let bw = (card_w - 40.0 - 16.0) / 3.0
        for(FE_LEVELS) l, k:
            if fe_toggle(D(cx + 28.0 + float(k) * (bw + 8.0), lc_y + 36.0), D(bw, 44.0), l, fe_sides[1].level == k): fe_sides[1].level = k
    let breathe = 1.0 + 0.06 * (0.5 + 0.5 * sin(seconds_elapsed() * 128.0))
    let start_k = ui_hits.length
    if ui_button(D(cx + 8.0, by), D(card_w, 100.0), "", true): go = "start"
    let players = if fe_rooms.length: room_players(fe_rooms[0]) else: 0
    let held = (fe_hosting and not players) or fe_joining  // (Start isn't ours yet, or at all)
    ui_text_c(mid * fe_k, (by + 24.0) * fe_k, "Start Battle", fz(40.0), lk.title * float4 { breathe, breathe, breathe, 1.0 } * (if held: float4 { 0.6, 0.6, 0.6, 1.0 } else: float4_1), 2, 2.0 * fe_k)
    ui_text_c(mid * fe_k, (by + 112.0) * fe_k, if fe_joining: "Waiting for the host to start" elif fe_hosting and not players: "Waiting for a player to join" elif fe_hosting: "{players} player{if players == 1: "" else: "s"} in: Start when everyone is ready" elif fe_pad: "X: roll the dice  -  Start: start  -  B: back" else: "Esc in battle: pause and menu", fz(16.0), lk.dim, 0, 0.0)
    if fe_hosting:
        ui_text_c(ws.x / 2.0, 66.0 * fe_k, fe_room_line(), fz(18.0), lk.accent, 0, 0.0)
        if (gl.button("c") == 1 and fe_field < 0) or gl.button("controller_y") == 1:
            if fe_swarm.code != "": gl.set_clipboard(fe_swarm.code)
    if fe_joining: ui_text_c(ws.x / 2.0, 66.0 * fe_k, fe_guest_status(), fz(18.0), lk.accent, 0, 0.0)
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
        if fe_joining: k = fe_my_side  // (a joiner rolls only its own)
        if k >= 0: fe_roll(k)
    if gl.button("controller_start") == 1: go = "start"
    if go == "start" and held: go = ""
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
    fe_rule(at.x + 40.0 * fe_k, y, size.x - 80.0 * fe_k, lk.metal)
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

// Play on the network: host (the battle setup, then wait for a player) or join a game: on the home network (the
// hosts found nearby, or an address), or anywhere with the host's join code (#514).
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
    ui_text_c(ws.x / 2.0, y, "On the same home network, or anywhere with the host\'s join code.", fz(17.0), lk.dim, 0, 0.0)
    y += 36.0 * fe_k
    var go = ""
    if ui_button(float2 { x, y }, float2 { w, 64.0 * fe_k }, "Host a game", true): go = "host"
    y += 78.0 * fe_k
    fe_rule(x, y, w, lk.metal)
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
    if fe_scanned and lan_scan_note() != "":  // what the scan saw (#506): this machine's address, who took the call
        let note = fe_wrap(lan_scan_note(), fz(13.0), w)
        for(note) line, k: ui_text(float2 { x, y - 18.0 * fe_k + float(k) * 17.0 * fe_k }, line, fz(13.0), lk.dim)
        y += float(note.length - 1) * 17.0 * fe_k
    y += 10.0 * fe_k
    fe_box(20, float2 { x, y }, float2 { w - 300.0 * fe_k, 48.0 * fe_k }, fe_address, "a join code or an address", fz(19.0), false)
    if ui_button(float2 { x + w - 290.0 * fe_k, y }, float2 { 130.0 * fe_k, 48.0 * fe_k }, "Paste", false):
        let pasted = gl.get_clipboard().fe_trim()
        if pasted != "":
            fe_address = pasted
            fe_focus(20, pasted)
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
        if fe_lab_gen[k] != s.gen and seconds_elapsed() - s.dirty_at > FE_BAKE_AFTER:
            fe_lab_units[k] = glist(s.race, "units")
            fe_lab_gen[k] = s.gen
        // the lineup: every unit with its name, rows across its half
        let vs = fe_lab_units[k]
        let hw = in_size.x / 2.0
        let per_row = max(1, int(hw / (100.0 * fe_k)))
        let rows_n = (vs.length + per_row - 1) / per_row
        let row_h = min(110.0 * fe_k, in_size.y / float(max(1, rows_n)))
        let spots = map(vs.length) n: in_at + float2 { float(k) * hw + hw * (float(n % per_row) + 0.5) / float(per_row), row_h * (float(n / per_row) + 0.72) }
        fe_draw_units(vs, spots, fe_k * 1.1, k, if fe_lab_gen[k] != s.gen: 0.32 else: 1.0, k == 1)
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

// ---- the loader (scenes/match_loader.gd, loader_style.gd): both armies facing each other, the names with "vs", the
// map, a bar, a tip; its own plain look (dark, bronze, gold), centred on the window

let FE_LOADER_ROLES = [ "spear", "infantry", "archer", "large", "catapult" ]  // a few that show each army off, one rank each
let FE_LD_BRONZE = float4 { 0.63, 0.53, 0.35, 1.0 }                           // #a08858
let FE_LD_EDGE = float4 { 0.42, 0.35, 0.25, 1.0 }                             // #6a5a40
let FE_LD_TEXT = float4 { 0.94, 0.89, 0.78, 1.0 }                             // #efe4c8
let FE_LD_DIM = float4 { 0.72, 0.68, 0.58, 1.0 }                              // #b8ad94
let FE_LD_GOLD = float4 { 0.95, 0.79, 0.3, 1.0 }                              // #f2c94c

def fe_loader_pick(race:JV) -> [JV]:
    let units = glist(race, "units")
    let out = []::JV
    for(FE_LOADER_ROLES) role:
        let k = find(units) u: gstr(at(u, "recipe"), "role", "") == role
        if k >= 0: out.push(units[k])
    return out

// The loader's stage (Dominic, 2026-11-04: "just green behind them"): a meadow under a hazy sky, hills far off, the
// grass in tufts and a few flowers, smaller towards the horizon. Fixed (no randomness from frame to frame).
def fe_h01(n:int) -> float: return float(((n * 2654435761) >> 9) & 0xffff) / 65536.0  // a fixed 0..1 for n

def fe_ld_meadow(at:float2, size:float2, k:float):
    let hz = size.y * 0.3  // the horizon
    ui_shade(at, float2 { size.x, hz }, 1, 4) u, v: float4 { 0.55 + 0.3 * v, 0.68 + 0.14 * v, 0.80 - 0.16 * v, 1.0 }
    let strip = max(2.0, 3.0 * k)
    var x = 0.0
    while x < size.x:  // two ranges of hills, the far one paler
        let t = x / size.x
        let far = hz * (0.42 + 0.16 * sin(t * 760.0 + 40.0) + 0.1 * sin(t * 1900.0))
        ui_fill(float2 { at.x + x, at.y + hz - far }, float2 { strip, far }, float4 { 0.47, 0.58, 0.48, 1.0 })
        let near = hz * (0.2 + 0.12 * sin(t * 1300.0 + 200.0) + 0.06 * sin(t * 3100.0 + 15.0))
        ui_fill(float2 { at.x + x, at.y + hz - near }, float2 { strip, near }, float4 { 0.34, 0.47, 0.25, 1.0 })
        x += strip
    ui_shade(float2 { at.x, at.y + hz }, float2 { size.x, size.y - hz }, 1, 6) u, v:
        float4 { 0.52 - 0.22 * v, 0.6 - 0.18 * v, 0.27 - 0.13 * v, 1.0 }
    for(420) n:
        let d = fe_h01(n * 16)  // 0 at the horizon, 1 at the front
        let depth = d * d
        let p = float2 { at.x + fe_h01(n * 16 + 1) * size.x, at.y + hz + 4.0 * k + depth * (size.y - hz - 6.0 * k) }
        let h = (3.0 + 11.0 * depth) * k * (0.7 + 0.6 * fe_h01(n * 16 + 2))
        let shade = 0.75 + 0.5 * fe_h01(n * 16 + 3)
        let col = float4 { 0.2 * shade, 0.33 * shade, 0.1 * shade, 0.55 + 0.4 * depth }
        let lw = max(1.0, (0.8 + 1.4 * depth) * k)
        for(3) b:
            let lean = (float(b) - 1.0) * h * 0.35 + (fe_h01(n * 16 + 4 + b) - 0.5) * h * 0.3
            ui_line(p + float2 { (float(b) - 1.0) * lw, 0.0 }, p + float2 { lean, -h }, lw, col)
        if n % 9 == 0:  // a flower
            let fc = if n % 2 == 0: float4 { 0.95, 0.9, 0.75, 0.9 } else: float4 { 0.95, 0.78, 0.25, 0.9 }
            let r = (1.2 + 2.0 * depth) * k
            ui_fill(p + float2 { -r, -h * 0.8 - r }, float2_1 * r * 2.0, fc)
    ui_shade(float2 { at.x, at.y + size.y * 0.8 }, float2 { size.x, size.y * 0.2 }, 1, 3) u, v: float4 { 0.0, 0.0, 0.0, 0.25 * v }  // the front, darker

// A plain box with an edge (loader_style.gd's box).
def fe_ld_box(at:float2, size:float2, fill:float4, edge:float4, w:float):
    ui_fill(at, size, edge)
    ui_fill(at + float2_1 * w, size - float2_1 * w * 2.0, fill)

def fe_loader(status:string, frac:float):
    gl.clear(float4 { 0.078, 0.063, 0.047, 1.0 })  // #14100c
    gl.blend(1)
    fe_fit()
    ui_frame(false)
    let ws = float(gl.window_size())
    let lk = ui_look_of("")
    ui_use(lk)
    let k = fe_k
    let x0 = max(56.0, (fe_w - 1500.0) / 2.0) * k
    let w = ws.x - x0 * 2.0
    // the column's height first (it's centred): head, names, stage, the row below; 18 between
    let n = fe_sides.length
    let you = fe_sides[0].team
    let lefts = (filter(n) i: fe_sides[i].team == you).length
    let rows = max(lefts, n - lefts)
    let nfs = if n <= 2: 52.0 else: 32.0
    let block_h = nfs * 1.25 + 4.0 + 17.0 * 1.3 + 4.0 + 5.0
    let names_h = float(rows) * block_h + float(rows - 1) * 10.0
    let st_h = clamp(fe_h * 0.46, 300.0, 540.0)
    let low_h = 124.0
    var y = max(40.0, (fe_h - (15.0 * 1.3 + 18.0 + names_h + 18.0 + st_h + 18.0 + low_h)) / 2.0)
    ui_text_c(ws.x / 2.0, y * k, "PREPARING FOR BATTLE", fz(15.0), FE_LD_BRONZE, 0, 0.0)
    y += 15.0 * 1.3 + 18.0
    // the names: a team each side of the "vs", each name over its side's colour, its creature and culture under it
    let vs_w = ui_text_wf("vs", fz(40.0), 0)
    let half = (w - vs_w - 56.0 * k) / 2.0
    var ln = 0
    var rn = 0
    for(fe_sides) s, i:
        let left = s.team == you
        let row = if left: ln else: rn
        let by = (y + float(row) * (block_h + 10.0)) * k
        let bx = if left: x0 else: x0 + half + vs_w + 56.0 * k
        let nm = rstr(s.race, "name")
        let who = "{gstr(creature(rstr(s.race, "creature")), "plural", rstr(s.race, "creature"))}, {capitalize(rstr(s.race, "family"))}"
        let nx = if left: bx + half - ui_text_wf(nm, fz(nfs), 0) else: bx  // (each name towards the "vs")
        let wx = if left: bx + half - ui_text_wf(who, fz(17.0), 0) else: bx
        ui_text_f(float2 { nx, by }, nm, fz(nfs), FE_LD_TEXT, 0, 3.0 * k)
        ui_text(float2 { wx, by + (nfs * 1.25 + 4.0) * k }, who, fz(17.0), FE_LD_DIM)
        ui_fill(float2 { bx, by + (block_h - 5.0) * k }, float2 { half, 5.0 * k }, team_rgb[i % team_rgb.length] * float4 { 0.9, 0.9, 0.9, 1.0 })
        if left: ln++
        else: rn++
    ui_text_c(ws.x / 2.0, (y + names_h / 2.0) * k - float(fz(40.0)) * 0.6, "vs", fz(40.0), FE_LD_BRONZE, 0, 4.0 * k)
    y += names_h + 18.0
    // the stage: the game's ground, both armies facing the middle, the big ones nearest the foe
    let st_at = float2 { x0, y * k }
    let st_size = float2 { w, st_h * k }
    fe_ld_box(st_at - float2_1 * 3.0 * k, st_size + float2_1 * 6.0 * k, FE_GRASS, FE_LD_EDGE, 3.0 * k)
    let zm = 2.5 * k * (if st_h >= 480.0: 1.6 elif st_h >= 360.0: 1.3 else: 1.0)
    fe_turf(st_at, st_size, zm / 1.5, 1)  // the game's own ground (Dominic, 2026-11-04: "game loading still has no bg, just ugly green")
    for(fe_sides) s, i:
        let left = s.team == you
        let rank = (filter(i) j: (fe_sides[j].team == you) == left).length
        let ranks = (filter(n) j: (fe_sides[j].team == you) == left).length
        let vs = fe_loader_pick(s.race)
        let spots = map(vs.length) u:
            let along = (float(u) + 0.5) / float(max(1, vs.length))
            let sx = w * (0.07 + 0.36 * along)
            let sy = if ranks == 1: 0.6 + 0.12 * float(u % 2) else: 0.46 + 0.3 * float(rank) / float(ranks - 1) + 0.05 * float(u % 2)
            st_at + float2 { if left: sx else: w - sx, st_size.y * sy }
        fe_draw_units(vs, spots, zm / 1.5, i, 1.0, not left)
    y += st_h + 18.0
    // below: the map card (its picture, BATTLEFIELD, its name and size), then what's being made, the bar and a tip
    let starts = glist(fe_map_json, "starts").length
    let mname = gstr(fe_map_json, "name", lobby_map)
    let msize = "{gint(fe_map_json, "width", 0)} x {gint(fe_map_json, "height", 0)} tiles"
    let words_w = max(ui_text_wf(mname, fz(22.0), 0), ui_text_wf(msize, fz(15.0), 0)) / k
    let card = float2 { 14.0 + 190.0 + 14.0 + max(110.0, words_w) + 14.0, 104.0 + 20.0 }
    let cy = y * k
    fe_ld_box(float2 { x0, cy }, card * k, float4 { 0.165, 0.137, 0.106, 0.96 }, FE_LD_EDGE, 2.0 * k)
    fe_draw_map(float2 { x0 + 14.0 * k, cy + 10.0 * k }, float2 { 190.0, 104.0 } * k, lobby_map, fe_map_json)
    let wx = x0 + (14.0 + 190.0 + 14.0) * k
    let wy = cy + (card.y - (13.0 + 22.0 + 15.0) * 1.3) / 2.0 * k
    ui_text(float2 { wx, wy }, "BATTLEFIELD", fz(13.0), FE_LD_BRONZE)
    ui_text(float2 { wx, wy + 13.0 * 1.3 * k }, mname, fz(22.0), FE_LD_TEXT)
    ui_text(float2 { wx, wy + (13.0 + 22.0) * 1.3 * k }, msize + (if starts > 2: "  ·  {starts / 2} v {starts - starts / 2}" else: ""), fz(15.0), FE_LD_DIM)
    let bx = x0 + card.x * k + 28.0 * k
    let bw = w - card.x * k - 28.0 * k
    let by = cy + (card.y - (17.0 * 1.3 + 10.0 + 18.0 + 10.0 + 48.0)) / 2.0 * k
    ui_text(float2 { bx, by }, status, fz(17.0), FE_LD_TEXT)
    let pct = "{int(clamp(frac, 0.0, 1.0) * 100.0 + 0.5)}%"
    ui_text(float2 { bx + bw - ui_text_wf(pct, fz(17.0), 0), by }, pct, fz(17.0), FE_LD_GOLD)
    let bar_y = by + (17.0 * 1.3 + 10.0) * k
    fe_ld_box(float2 { bx, bar_y }, float2 { bw, 18.0 * k }, float4 { 0.07, 0.055, 0.04, 1.0 }, FE_LD_EDGE, 2.0 * k)
    let fill = (bw - 8.0 * k) * clamp(frac, 0.0, 1.0)
    if fill > 1.0:
        ui_fill(float2 { bx + 4.0 * k, bar_y + 4.0 * k }, float2 { fill, 10.0 * k }, FE_LD_GOLD * float4 { 0.75, 0.75, 0.75, 1.0 })
        ui_fill(float2 { bx + 4.0 * k, bar_y + 4.0 * k }, float2 { fill, 4.0 * k }, FE_LD_GOLD + (float4_1 - FE_LD_GOLD) * 0.1)
    if fe_tips.length:
        if seconds_elapsed() - fe_tip_t > 7.0:
            fe_tip_k = rnd(fe_tips.length)
            fe_tip_t = seconds_elapsed()
        for(fe_wrap("Tip: " + fe_tips[fe_tip_k], fz(16.0), bw)) l, r: ui_text(float2 { bx, bar_y + (28.0 + 22.0 * float(r)) * k }, l, fz(16.0), FE_LD_DIM)
    ui_flush()

// ---- the loop

// Captures wait for the armies drawn to stand: no unit's first look still to bake.
def fe_looks_waiting() -> bool:
    let d = vx_doing
    return (d and d.v == 0) or (find(vx_queue) j: vx_first_job(j)) >= 0

// The front end from a page; what was chosen ("play", "host", "join", "fight", "load:<path>"), "" to quit. Sets the
// lobby's prompts, rerolls, teams, AI levels, map and mode for the match.
def run_front(page0:string, typed:[string]) -> string:
    fe_rules = load_rules(rules_id())
    if not fe_maps.length: fe_load_maps()
    rnd_seed(int(seconds_elapsed() * 1000.0) + int(date_time()[0]) * 7919 + date_time()[1] * 31 + date_time()[2])
    let start_map = str_index(fe_maps, lobby_map)
    fe_sides = []
    fe_set_map(if start_map >= 0: start_map else: 0)
    fe_mode_k = max(0, str_index(map(fe_modes) m: m[0], lobby_mode))
    for(typed) t, i:
        if i < fe_sides.length:
            fe_sides[i].typed = t
            if i < lobby_rerolls.length: fe_sides[i].reroll = lobby_rerolls[i]
            fe_regen(i)
    fe_page = page0
    if page0 == "host":  // (captures: the battle setup, hosting; guest:<code or address>: a joiner's, #519, #521)
        fe_hosting = true
        fe_page = "setup"
        fe_room_open()
    elif starts_with(page0, "guest:"):
        fe_guest_start(page0.substring(6, page0.length - 6))
        fe_page = "setup"
        if typed.length: fe_guest_words = typed[0]
    front_shown = true
    fe_frames = 0
    fe_field = if page0 == "setup": 0 elif page0 == "lab": 10 else: -1  // (as the title's buttons do: side 1's box has the keyboard)
    var typing = false                                                  // text input on: only while a box has the keyboard (on a phone it brings up the keyboard)
    var shot_frame = -1
    var tc_at = -1.0  // (treecheck: when the last frame of the open tech tree began, the longest, how many)
    var tc_worst = 0.0
    var tc_frames = 0
    var fc_worst = 0.0  // (framecheck: the longest title frame's work, how many frames, how many over, when the armies stood)
    var fc_frames = 0
    var fc_over = 0
    var fc_stood = -1
    pace(PACE_MENU)
    while gl.frame():
        let frame_t0 = seconds_elapsed()
        ui_click_tick()
        window_tick()
        if bake_quit: return ""
        let dt = gl.delta_time()
        fe_fit()
        music_tick("lobby", false, dt)
        let any_pad = gl.button("controller_a") == 1 or gl.button("controller_b") == 1 or gl.button("controller_x") == 1 or gl.button("controller_start") == 1 or gl.button("controller_dpup") == 1 or gl.button("controller_dpdown") == 1 or abs(gl.controller_axis(1)) > 0.6
        if any_pad or has_s(args, "padui"): fe_pad = true
        elif gl.button("mouse1") == 1 or magnitude(float(gl.mouse_delta(0))) > 4.0: fe_pad = false
        for(args) a: if starts_with(a, "padfocus:") and fe_frames >= 5: ui_focus = string_to_int(a.substring(9, a.length - 9))  // (captures: the pad's focus on a button, #493)
        pace_menu(fe_page == "title", any_pad or gl.button("mouse1") >= 1 or gl.mouse_delta(0) != int2_0 or fe_field >= 0)
        if (fe_field >= 0) != typing:
            typing = fe_field >= 0
            if typing:
                gl.start_text_input(int2 { 0, 0 }, int2 { 400, 40 })
                gl.set_text_input(fe_field_text())
            else: gl.end_text_input()
        if fe_field >= 0:
            let bs_was = fe_bs_held
            fe_bs_held = if gl.button("backspace") >= 1: max(0.0, fe_bs_held) + dt else: -1.0
            let typed_now, editing = gl.text_input_state()
            let n_bs = if editing == "": tf_repeats(bs_was, fe_bs_held) else: 0  // (while an IME composes, its own)
            if n_bs > 0:                                                         // SDL's text input only adds; backspace is ours (#431)
                var t = typed_now
                for(n_bs): t = tf_drop_last(t)
                gl.set_text_input(t)
            let text = gl.text_input_state()
            if text != fe_field_text() or n_bs > 0: fe_field_at = fe_clock()
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
            fe_hosts = lan_scan(4.0, NET_PORT)  // (Wi-Fi in power saving can take a while to answer: #506)
            fe_scanned = true
        if fe_page == "setup" and fe_hosting: fe_room_tick()
        var joined_now = false
        if fe_page == "setup" and fe_joining: joined_now = fe_guest_sync() == "join"
        if fe_page != "lab": fe_muster(fe_clock())
        gl.clear(float4 { 0.07, 0.06, 0.05, 1.0 })
        gl.blend(1)
        if tree_open and tree_lobby:
            ui_frame(true)
            tree_tick()
            ui_flush()
            fe_frames++
            if tc_at >= 0.0:  // (treecheck: the page answers every frame while its pictures come, #430)
                let now = seconds_elapsed()
                tc_worst = max(tc_worst, now - tc_at)
                tc_at = now
                tc_frames++
                if (tree_waiting == 0 and tc_frames > 2) or tc_frames > 3000:
                    print "treecheck: the longest frame {int(tc_worst * 1000.0)} ms (at most {TREECHECK_MS}), {tc_frames} frames, {tree_waiting} pictures left"
                    if tc_worst * 1000.0 > float(TREECHECK_MS) or tree_waiting > 0: set_exit_code(1)
                    return ""
            if shot != "" and fe_frames >= shot_frame + 5 and (tree_waiting == 0 or fe_frames > shot_frame + 600):  // (captures: lobbytree, once its pictures are painted)
                gl.screenshot(shot)
                return ""
            continue
        ui_frame(true)
        atlas_pack()
        fe_backdrop()
        ui_label_px = fz(20.0)  // (match_setup.gd's base type)
        var go = ""
        ui_batch():  // (the page's fills, lines and studs in as few draws as can be)
            if fe_page == "title": go = fe_title_page(dt)
            elif fe_page == "setup": go = fe_setup_page(dt)
            elif fe_page == "lab": go = fe_lab_page(dt)
            elif fe_page == "saves":
                let picked = fe_saves_card(fe_note)
                if picked == "back": go = "back"
                elif picked != "":
                    let why = save_refusal_of(picked)
                    if why != "": fe_note = why
                    else: go = "load:" + picked
            elif fe_page == "net": go = fe_net_page()
            elif fe_page == "settings": go = fe_settings_card()
        if fe_page == "setup" or fe_page == "lab" or fe_page == "title":
            ui_flush()
        fe_draw_tip()
        ui_flush()
        ui_label_px = 0
        vx_bake_tick(0.025, true, false)  // (the armies' voxel looks, as they're asked for; kept on quitting or in a match: a PNG's save is a frame's time, #494)
        fe_frames++
        if has_s(args, "framecheck") and fe_page == "title":  // (the title answers every frame while its armies bake from nothing, #494)
            let work = seconds_elapsed() - frame_t0
            fc_worst = max(fc_worst, work)
            fc_frames++
            if work * 1000.0 > float(FRAMECHECK_MS):
                fc_over++
                print "framecheck: frame {fe_frames} took {int(work * 1000.0)} ms ({vx_queue.length} bakes queued, {vx_unsaved.length} unsaved)"
            let stood = fe_sides.length and (filter(fe_sides) s: s.views_gen != s.gen).length == 0 and not fe_looks_waiting()
            if stood and fc_stood < 0: fc_stood = fe_frames
            if shot != "" and fe_sides.length and (find(fe_sides) s: s.views_gen != s.gen) < 0:  // (a capture of the title as its armies are first asked for, then quit)
                gl.screenshot(shot)
                return ""
            if (stood and not vx_queue.length and not vx_doing) or fc_frames > 6000:
                print "framecheck: the longest frame {int(fc_worst * 1000.0)} ms (at most {FRAMECHECK_MS}), {fc_over} over, {fc_frames} frames, the armies stood at frame {fc_stood}, {vx_queue.length} bakes left"
                if fc_over > 0 or fc_stood < 0: set_exit_code(1)
                return ""
        // (treecheck: the AI's tech tree opened with nothing baked, each frame timed till its pictures are all painted)
        if has_s(args, "treecheck") and fe_page == "setup" and fe_frames == 10:
            fe_open_tree(1)
            tc_at = seconds_elapsed()
            continue
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
        let room_waits = has_s(args, "roomshot") and not (if fe_joining: fe_guests.length and fe_guests[0].side >= 0 and glist(fe_guests[0].lobby, "sides").length > 0 else: fe_rooms.length and room_players(fe_rooms[0]) > 0)  // (captures: a player in the room)
        if shot != "" and has_s(args, "roomshot") and not room_waits and shot_frame < 0 and fe_joining and (filter(fe_sides) sd: sd.views_gen != sd.gen).length == 0: shot_frame = fe_frames + 3                                 // (the host may start any moment)
        if shot != "" and not room_waits and not has_s(args, "lobbyloop") and not has_s(args, "loadfirst") and (fe_sides.length == 0 or (filter(fe_sides) s: s.views_gen != s.gen).length == 0 or fe_page == "lab") and (not fe_looks_waiting() or fe_frames > 900) and shot_frame < 0: shot_frame = fe_frames + (if fe_page == "lab": 90 else: 20)
        if rec_dir != "" and rec_type.length > 0:  // (filming: the prompts typed in, side by side, each given time to muster)
            if rec_n == 0:
                gl.set_fixed_delta_time(1.0 / rec_fps, 0.0)
                rec_wait = rec_frames(1.0)
            if fe_page == "setup":
                let rs = rec_side
                if rec_wait > 0: rec_wait--
                elif rs < rec_type.length:
                    if rec_char == 0: fe_focus(rs, "")
                    rec_char++
                    gl.set_text_input(rec_type[rs].substring(0, min(rec_char, rec_type[rs].length)))
                    if rec_char >= rec_type[rs].length:
                        rec_side++
                        rec_char = 0
                        rec_wait = rec_frames(2.5)
                    else: rec_wait = rec_frames(0.07)
                gl.screenshot("{rec_dir}/{100000 + rec_n}.png")
                rec_n++
                if rec_side >= rec_type.length and rec_wait == 0:
                    return ""
        if shot != "" and fe_frames == shot_frame:
            gl.screenshot(shot)
            if fe_page == "setup" and has_s(args, "loadershot"):
                fe_loader("Setting up the battle", 0.16)
                gl.frame()
                fe_loader("Setting up the battle", 0.16)
                gl.screenshot(shot + ".loader.png")
                bake_progress = fn(st, f): fe_loader(st, f)  // (the loader as the bake drives it: bake_breath)
                gl.frame()
                bake_progress("Making the armies", 0.5 + 0.45 * 60.0 / 165.0)
                gl.screenshot(shot + ".bake.png")
            return ""
        if joined_now: go = "join"  // (the host started)
        if go == "": pass()
        elif go == "quit": return ""
        elif go == "back":
            if fe_page == "setup" and (fe_hosting or fe_joining): fe_back = "net"
            if fe_page == "setup" and (fe_hosting or fe_joining): fe_room_close()
            if fe_page == "net" or fe_page == "saves" or fe_page == "lab" or (fe_page == "setup" and fe_hosting): fe_hosting = false
            fe_page = if (fe_page == "saves" or fe_page == "net" or fe_page == "setup") and fe_back != "title": fe_back else: "title"
            fe_back = "title"
            fe_field = -1
            fe_note = ""
        elif go == "setup" or go == "lab" or go == "saves" or go == "net" or go == "settings":
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
            fe_room_open()
        elif go == "join" and fe_page == "net":  // the host's lobby first: a side and an army, then the host starts (#519)
            fe_guest_start(fe_address.fe_trim())
            fe_page = "setup"
            fe_frames = 0
            fe_field = -1
        elif go == "join":
            gl.end_text_input()
            join_ip = fe_join_what
            return "join"
        elif starts_with(go, "load:"):
            gl.end_text_input()
            return go
        elif go == "start" or go == "fight":
            gl.end_text_input()
            lobby_prompts = map(fe_sides.length) i: fe_prompt(i)
            lobby_rerolls = map(fe_sides) s: s.reroll
            lobby_teams = map(fe_sides) s: s.team
            lobby_levels = map(fe_sides) s, i: if i == 0 or fe_player_side(i): "" else: FE_LEVELS[s.level].lowercase()
            if fe_hosting:
                hosting = true
                net_people = 1 + (if fe_rooms.length: room_players(fe_rooms[0]) else: 1)
                return "host"
            fe_loader("Setting up the battle", 0.02)  // (shown at once: the start's work comes before the next frame)
            gl.frame()
            fe_loader("Setting up the battle", 0.02)
            return "play"
    return ""
