// ------------------------------------------------------------------ the School: one trade at a time, shown large (#127)
// In a town builder (economy.town_builds), a building of yours that teaches more than one trade, and does nothing else,
// gets its own part of the command panel instead of a grid of train buttons: the trade picked stands large in a framed
// view (its own figure, up close, as the panel's portraits are cut), with arrows either side to walk through the trades
// (Q and E too); under it the trade's name, what it does, where it works and how many of those workplaces have no one;
// then a strip of every trade's small figure, a click away, a gold mark on those the town is short of. Teach (the
// queue's column, over the queue) queues the trade picked: shift five.
// Imported by game.lobster before the panel (its globals first; it calls the panel's portraits): the panel calls it (school_on, school_size, school_frame, school_pictures,
// school_texts, school_teach), and game.lobster calls school_keys after the controls' keys.

let SCHOOL_W = 480.0  // UI px (times hud_s())
let SCHOOL_H = 352.0
let SCHOOL_VIEW = 200.0  // the framed view of the trade picked
let SCHOOL_ARROW = 60.0
let SCHOOL_CHIP = 34.0  // a trade in the strip
let SCHOOL_TEACH_H = 92.0
let SCHOOL_SKY = float4 { 0.75, 0.86, 0.92, 1.0 }    // #bfdcea
let SCHOOL_GRASS = float4 { 0.52, 0.66, 0.36, 1.0 }  // #85a85c
let SCHOOL_NEED = float4 { 0.56, 0.82, 0.45, 1.0 }   // #8fd172: the town's short of it

var school_pick = 0  // the trade shown: an index into trainable(b)
var school_of = -1   // the building it's for (sel_building's id): another one starts from its first trade

// Building bi's panel is the School's: yours, finished, in a town builder, teaching two trades or more and nothing else.
def school_on(bi:int) -> bool:
    if bi < 0 or not town_builds() or b_owner[bi] != ME or b_done[bi] == 0: return false
    if trainable(bi).length < 2 or offered(bi).length: return false
    if sel_building != school_of:
        school_of = sel_building
        school_pick = 0
    school_pick = clamp(school_pick, 0, trainable(bi).length - 1)
    return true

def school_size(s:float) -> float2: return float2 { SCHOOL_W, SCHOOL_H } * s

def school_turn(bi:int, by:int):
    let n = trainable(bi).length
    school_pick = (school_pick + by + n) % n
    play_sound("ui_click", -6.0)

// Q and E walk through the trades (the School's panel up; the keys' research does nothing there).
def school_keys():
    let bi = b_index_of(sel_building)
    if not school_on(bi): return
    if gl.button("q") == 1: school_turn(bi, -1)
    if gl.button("e") == 1: school_turn(bi, 1)

// The workplaces that want trade k (buildings.json "staff"), and how many of their places have no one: yours finished,
// less the trade's people and those queued.
def school_workplaces(k:int) -> [int]:
    let out = []::int
    for(su_btypes) bt, bk:
        if gobj(bt, "staff").keys.length and gint(gobj(bt, "staff"), t_slot[k], 0) > 0: out.push(bk)
    return out

def school_short(k:int) -> int:
    var need = 0
    for(b_id.length) b:
        if b_owner[b] == ME and b_done[b] != 0 and b_kind[b] < su_btypes.length:
            need += gint(gobj(su_btypes[b_kind[b]], "staff"), t_slot[k], 0)
    if need == 0: return 0
    var have = 0
    for(u_kind) uk, i:
        if u_owner[i] == ME and uk == k: have++
    for(b_id.length) b:
        if b_owner[b] == ME:
            for(b_queue[b]) e:
                if e == k: have++
    return max(0, need - have)

def school_where(k:int) -> string:  // the trade's line under its words
    let places = school_workplaces(k)
    if not places.length:
        var n = 0
        for(u_kind) uk, i:
            if u_owner[i] == ME and uk == k: n++
        return "{n} in the town"
    let short = school_short(k)
    return "Works at: " + names_list(map(places) bk: bname(bk), 2) + (if short > 0: ", {short} waiting for one" else: "")

// The who column's lines: the trades the town's workplaces are waiting for.
def school_needs() -> [string]:
    let bi = b_index_of(sel_building)
    let rows = []::string
    for(trainable(bi)) k:
        let n = school_short(k)
        if n > 0: rows.push("{unit_name(k)}: {n} wanted")
    if not rows.length: return [ "Every workplace has its worker." ]
    return append([ "The town wants:" ], rows)

// What trade k does: its roster line's "desc" (the rules').
def school_desc(k:int) -> string:
    for(glist(su_rules, "roster")) sd:
        if gstr(sd, "slot", "") == t_slot[k]: return gstr(sd, "desc", "")
    return ""

// The hover card's lines: what the trade does, where it works, what stops it.
def school_tip(k:int, room:bool) -> string:
    let rows = [ school_desc(k) + "." ]
    rows.push((if school_short(k) > 0: "+" else: "~") + school_where(k))
    if not room: rows.push("!The queue is full.")
    else:
        let short = short_of(t_cost[k])
        if short != "": rows.push(short)
    return concat_string(rows, "\n")

class SchoolLay:  // where the parts are this frame
    view:float2
    left:float2
    right:float2
    chips:[float2]

def school_lay(at:float2, n:int, s:float) -> SchoolLay:
    let cx = at.x + SCHOOL_W * s / 2.0
    let view = float2 { cx - SCHOOL_VIEW * s / 2.0, at.y }
    let ay = at.y + (SCHOOL_VIEW - SCHOOL_ARROW) * s / 2.0
    let gap = 4.0 * s
    let strip_w = float(n) * SCHOOL_CHIP * s + float(n - 1) * gap
    let chips = map(n) i: float2 { cx - strip_w / 2.0 + float(i) * (SCHOOL_CHIP * s + gap), at.y + (SCHOOL_H - SCHOOL_CHIP - 2.0) * s }
    return SchoolLay { view, float2 { view.x - 28.0 * s - SCHOOL_ARROW * s, ay }, float2 { view.x + SCHOOL_VIEW * s + 28.0 * s, ay }, chips }

// A chevron in a box (left or right), drawn with lines.
def school_chevron(at:float2, side:float, left:bool, col:float4):
    let c = at + float2_1 * side / 2.0
    let d = side * 0.16
    let tip = if left: c - float2 { d, 0.0 } else: c + float2 { d, 0.0 }
    let back = if left: c + float2 { d, 0.0 } else: c - float2 { d, 0.0 }
    ui_line(tip, back - float2 { 0.0, d * 1.6 }, side * 0.1, col)
    ui_line(tip, back + float2 { 0.0, d * 1.6 }, side * 0.1, col)

// The boxes, the buttons and the clicks (with the panel's frame, before the sprites).
def school_frame(at:float2, bi:int, s:float):
    let tr = trainable(bi)
    let lay = school_lay(at, tr.length, s)
    hud_well(lay.view - float2_1 * 4.0 * s, float2_1 * (SCHOOL_VIEW + 8.0) * s)
    let inner = SCHOOL_VIEW * s
    ui_fill(lay.view, float2 { inner, inner * 0.62 }, SCHOOL_SKY)
    ui_fill(lay.view + float2 { 0.0, inner * 0.62 }, float2 { inner, inner * 0.38 }, SCHOOL_GRASS)
    if hud_button(lay.left, float2_1 * SCHOOL_ARROW * s, false, true): school_turn(bi, -1)
    if hud_button(lay.right, float2_1 * SCHOOL_ARROW * s, false, true): school_turn(bi, 1)
    school_chevron(lay.left, SCHOOL_ARROW * s, true, ui_look.accent)
    school_chevron(lay.right, SCHOOL_ARROW * s, false, ui_look.accent)
    var picked = -1
    for(lay.chips) p, n:
        if hud_button(p, float2_1 * SCHOOL_CHIP * s, n == school_pick, true): picked = n
        ui_fill(p + float2_1 * 3.0 * s, float2 { SCHOOL_CHIP - 6.0, (SCHOOL_CHIP - 6.0) * 0.62 } * s, SCHOOL_SKY * float4 { 1.0, 1.0, 1.0, 0.8 })
        ui_fill(p + float2 { 3.0, 3.0 + (SCHOOL_CHIP - 6.0) * 0.62 } * s, float2 { SCHOOL_CHIP - 6.0, (SCHOOL_CHIP - 6.0) * 0.38 } * s, SCHOOL_GRASS * float4 { 1.0, 1.0, 1.0, 0.8 })
    if picked >= 0 and picked != school_pick:
        school_pick = picked
        play_sound("ui_click", -6.0)

// The figures (after the sprites: busts render into their own textures).
def school_pictures(at:float2, bi:int, s:float):
    let tr = trainable(bi)
    let lay = school_lay(at, tr.length, s)
    draw_type_bust(tr[school_pick], lay.view + float2_1 * 2.0 * s, (SCHOOL_VIEW - 4.0) * s)
    for(lay.chips) p, n: draw_type_bust(tr[n], p + float2_1 * 3.0 * s, (SCHOOL_CHIP - 6.0) * s)

def centred(cx:float, y:float, t:string, size:int, col:float4, font:int): tb_text(float2 { cx - tb_text_w(t, size, font) / 2.0, y }, t, size, col, font)

// The words (with the panel's text). The trade under the mouse in the strip, or -1.
def school_texts(at:float2, bi:int, s:float, m:float2) -> int:
    let tr = trainable(bi)
    let k = tr[school_pick]
    let lay = school_lay(at, tr.length, s)
    let cx = at.x + SCHOOL_W * s / 2.0
    var y = at.y + (SCHOOL_VIEW + 12.0) * s
    centred(cx, y, unit_name(k), int(28.0 * s), ui_look.title, 2)
    y += 36.0 * s
    let desc = school_desc(k)
    for(wrap(desc + (if desc != "": "." else: ""), int(15.0 * s), 0, (SCHOOL_W - 20.0) * s)) l, n:
        if n < 2: centred(cx, y + float(n) * 19.0 * s, l, int(15.0 * s), ui_look.text, 0)
    y += 40.0 * s
    let short = school_short(k)
    centred(cx, y, school_where(k), int(15.0 * s), if short > 0: SCHOOL_NEED else: ui_look.dim, 0)
    var over = -1
    for(lay.chips) p, n:
        if school_short(tr[n]) > 0: ui_fill(p + float2 { SCHOOL_CHIP - 9.0, 2.0 } * s, float2_1 * 7.0 * s, SCHOOL_NEED)
        if m.x >= p.x and m.y >= p.y and m.x <= p.x + SCHOOL_CHIP * s and m.y <= p.y + SCHOOL_CHIP * s: over = tr[n]
    return over

// A cost in big type, centred on cx: each part its number and its resource's icon (or initial), red when short.
def big_cost(c:[int], cx:float, y:float, fs:float):
    let parts = filter(c.length) r: c[r] > 0
    var w = 0.0
    for(parts) r: w += tb_text_w(string(c[r]), int(fs), 1) + fs * 1.25 + fs * 0.6
    w -= fs * 0.6
    var x = cx - w / 2.0
    for(parts) r:
        let txt = string(c[r])
        let tw = tb_text_w(txt, int(fs), 1)
        edged_text(float2 { x, y }, txt, int(fs), if stock[r][ME] < c[r]: PANEL_SHORT else: float4_1, 1)
        if good_has_icon(r): tb_icon("res_" + resource_names[r], float2 { x + tw + 3.0, y }, fs * 1.15, 1.0)
        else:
            let look = good_look(r)
            edged_text(float2 { x + tw + 4.0, y }, look.short, int(fs), look.colour, 1)
        x += tw + fs * 1.25 + fs * 0.6

// Teach, over the queue: the button's box (and its click), then its words. Its size: w by SCHOOL_TEACH_H.
def school_teach(at:float2, w:float, bi:int, s:float) -> bool:  // true when it's under the mouse
    let k = trainable(bi)[school_pick]
    let room = b_queue[bi].length < r_queue_max
    let ok = room and can_afford(ME, t_cost[k])
    if hud_button(at, float2 { w, SCHOOL_TEACH_H * s }, true, ok): train_slot(school_pick)
    let m = mouse_px()
    return m.x >= at.x and m.y >= at.y and m.x <= at.x + w and m.y <= at.y + SCHOOL_TEACH_H * s

def school_teach_text(at:float2, w:float, bi:int, s:float):
    let k = trainable(bi)[school_pick]
    centred(at.x + w / 2.0, at.y + 10.0 * s, "Teach " + unit_name(k), int(22.0 * s), ui_look.title, 2)
    big_cost(t_cost[k], at.x + w / 2.0, at.y + 42.0 * s, 24.0 * s)
    centred(at.x + w / 2.0, at.y + 72.0 * s, "click: one   shift: five", int(12.0 * s), ui_look.dim, 0)
