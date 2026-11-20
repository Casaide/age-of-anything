// ------------------------------------------------------------------ a town builder's build menu: pages and cards (#127)
// In a town builder (economy.town_builds) whose buildings.json "menu" has "pages" ([{"name", "ids"}], a pack's), the
// command panel with nothing selected shows the buildings a page at a time instead of the button grid: tabs along the
// top (the page's name), and a card per building you can build: its picture, its name and its cost in big type (each
// part red when short). A click picks it to place. Hovering a card shows a big card: the name, the cost large, then the
// building's lines (what it does, who works there, what stops you).
// Imported by game.lobster before the panel (its globals first; it calls the panel's pictures and tips).

let TB_CARD_W = 118.0  // UI px (times hud_s())
let TB_CARD_H = 152.0
let TB_GAP = 8.0
let TB_TAB_H = 34.0
let TB_PIC = 84.0

var tb_page = 0
var tb_pages_read = false
let tb_page_names = []::string
let tb_page_ids = []::[string]

def town_pages_read():
    if tb_pages_read: return
    tb_pages_read = true
    for(glist(gobj(lib_data("buildings.json"), "menu"), "pages")) p:
        tb_page_names.push(gstr(p, "name", "?"))
        tb_page_ids.push(gstrs(p, "ids"))

// Page n's buildings you can build now, in its order; the first page also takes any on no page.
def town_page(n:int) -> [int]:
    let can = buildable()
    let out = []::int
    for(tb_page_ids[n]) id:
        for(can) k:
            if bt_name[k] == id: out.push(k)
    if n == 0:
        for(can) k:
            var listed = false
            for(tb_page_ids) ids:
                if has_s(ids, bt_name[k]): listed = true
            if not listed: out.push(k)
    return out

// The pages with something on them.
def town_page_list() -> [int]: return filter(tb_page_names.length) n: town_page(n).length > 0

def town_build_on() -> bool:
    if pad_on or not town_bar(): return false
    town_pages_read()
    return town_page_list().length > 0

def town_build_cols() -> int:
    var most = 1
    for(tb_page_names.length) n: most = max(most, town_page(n).length)
    return min(most, 7)

def town_build_size(s:float) -> float2:
    let cols = town_build_cols()
    var rows = 1
    for(tb_page_names.length) n: rows = max(rows, (town_page(n).length + cols - 1) / cols)
    return float2 { float(cols) * (TB_CARD_W + TB_GAP) - TB_GAP, TB_TAB_H + TB_GAP + float(rows) * (TB_CARD_H + TB_GAP) - TB_GAP } * s

class TownLay:
    tabs:[float4]  // x, y, w, h
    tab_page:[int]
    cards:[float2]
    card_k:[int]

def town_lay(at:float2, s:float) -> TownLay:
    let pages = town_page_list()
    if not contains(pages, tb_page): tb_page = pages[0]
    let tabs = []::float4
    var x = at.x
    for(pages) n:
        let w = tb_text_w(tb_page_names[n], int(16.0 * s), 1) + 28.0 * s
        tabs.push(float4 { x, at.y, w, TB_TAB_H * s })
        x += w + 6.0 * s
    let ks = town_page(tb_page)
    let cols = town_build_cols()
    let cards = map(ks.length) i: at + float2 { float(i % cols) * (TB_CARD_W + TB_GAP), TB_TAB_H + TB_GAP + float(i / cols) * (TB_CARD_H + TB_GAP) } * s
    return TownLay { tabs, pages, cards, ks }

def in_box(m:float2, at:float2, size:float2) -> bool: return m.x >= at.x and m.y >= at.y and m.x <= at.x + size.x and m.y <= at.y + size.y

// The boxes and the clicks (with the panel's frame, before the sprites). The building clicked, to place, or -1.
def town_build_frame(at:float2, s:float) -> int:
    let lay = town_lay(at, s)
    var tab = -1
    for(lay.tabs) t, n:
        if hud_button(float2 { t.x, t.y }, float2 { t.z, t.w }, lay.tab_page[n] == tb_page, true): tab = lay.tab_page[n]
    var pick = -1
    for(lay.cards) p, n:
        if hud_button(p, float2 { TB_CARD_W, TB_CARD_H } * s, false, can_afford(ME, bm_cost[ME][lay.card_k[n]])): pick = lay.card_k[n]
        hud_well(p + float2 { (TB_CARD_W - TB_PIC - 8.0) / 2.0, 6.0 } * s, float2 { TB_PIC + 8.0, TB_PIC } * s)
    town_build_plain(at, s)
    if tab >= 0 and tab != tb_page:
        tb_page = tab
        play_sound("ui_click", -6.0)
    return pick

// The buildings' pictures (sprites: before flush_sprites).
def town_build_pictures(at:float2, s:float):
    let lay = town_lay(at, s)
    for(lay.cards) p, n: draw_building_icon(lay.card_k[n], ME, p + float2 { (TB_CARD_W - TB_PIC) / 2.0, 8.0 } * s, (TB_PIC - 4.0) * s)

var tb_ground_cols = []::float4  // each terrain's colour, then the colour of what it grows into (field cards, #122)

// A terrain's colour and its ripe one (terrain.json's "colour", and its "grows" "into"'s), read once.
def ground_cols(t:int) -> float4, float4:
    if not tb_ground_cols.length:
        let d = lib_data("terrain.json")
        let col = map(tr_names) n: html(gstr(gobj(d, n), "colour", "#808080"))
        for(tr_names) n, i:
            let into = find(tr_names) m: m == gstr(gobj(gobj(d, n), "grows"), "into", "")
            let c = if into >= 0: col[into] else: col[i]
            tb_ground_cols.push(float4 { col[i].x, col[i].y, col[i].z, 1.0 })
            tb_ground_cols.push(float4 { c.x, c.y, c.z, 1.0 })
    return tb_ground_cols[t * 2], tb_ground_cols[t * 2 + 1]

// A building with no picture: a road, a cobbled strip across its well (with the frame); a field plan, rows of its
// ground and what grows on it.
def town_build_plain(at:float2, s:float):
    let lay = town_lay(at, s)
    for(lay.cards) p, n:
        let k = lay.card_k[n]
        if not looks.get(building_key(arch_of[ME], bt_name[k], ages[ME], 0)):
            let a = p + float2 { TB_CARD_W / 2.0 - 34.0, 70.0 } * s
            let b = p + float2 { TB_CARD_W / 2.0 + 34.0, 22.0 } * s
            if bt_ground[k] >= 0:
                let bare, ripe = ground_cols(bt_ground[k])
                for(4) r:
                    let off = float2 { -9.0, -9.0 } * s * (float(r) - 1.5)
                    ui_line(a + off, b + off, 9.0 * s, bare)
                    ui_line(a + off, b + off, 5.0 * s, ripe)
            else:
                ui_line(a, b, 22.0 * s, float4 { 0.55, 0.52, 0.47, 1.0 })
                ui_line(a, b, 14.0 * s, float4 { 0.66, 0.63, 0.57, 1.0 })

// The words (with the panel's text). The building under the mouse, or -1.
def town_build_texts(at:float2, s:float, m:float2) -> int:
    let lay = town_lay(at, s)
    for(lay.tabs) t, n:
        let name = tb_page_names[lay.tab_page[n]]
        let fs = int(16.0 * s)
        tb_text(float2 { t.x + (t.z - tb_text_w(name, fs, 1)) / 2.0, t.y + (t.w - float(fs)) / 2.0 - 1.0 * s }, name, fs, if lay.tab_page[n] == tb_page: ui_look.title else: ui_look.dim, 1)
    var over = -1
    for(lay.cards) p, n:
        let k = lay.card_k[n]
        let cx = p.x + TB_CARD_W * s / 2.0
        let name = bname(k)
        var fs = 15.0 * s
        while tb_text_w(name, int(fs), 0) > (TB_CARD_W - 8.0) * s and fs > 10.0 * s: fs -= 1.0
        centred(cx, p.y + (TB_PIC + 12.0) * s, name, int(fs), ui_look.text, 0)
        big_cost(bm_cost[ME][k], cx, p.y + (TB_PIC + 34.0) * s, 20.0 * s)
        if in_box(m, p, float2 { TB_CARD_W, TB_CARD_H } * s): over = k
    return over

// The big card over the panel: the name, the cost large, the building's lines (marked as tip_card's: ! red, + green, ~ dim).
def big_tip(m:float2, name:string, costv:[int], tip:string):
    tb_flush()
    ui_flush()
    let s = hud_s()
    let fs = int(17.0 * s)
    let lh = 23.0 * s
    let maxw = 440.0 * s
    let rows = []::string
    let cols = []::float4
    for(tokenize(tip, "\n", "")) raw:
        if raw == "": continue
        let mark = raw.substring(0, 1)
        let col = if mark == "!": PANEL_SHORT elif mark == "+": TIP_GOOD elif mark == "~": ui_look.dim else: TIP_TEXT
        let body = if tip_line_marked(raw): raw.substring(1, raw.length - 1) else: raw
        for(wrap(body, fs, 0, maxw)) l:
            rows.push(l)
            cols.push(col)
    var w = max(tb_text_w(name, int(26.0 * s), 2), 260.0 * s)
    for(rows) l: w = max(w, tb_text_w(l, fs, 0))
    w += 36.0 * s
    let h = 18.0 * s + 34.0 * s + 46.0 * s + float(rows.length) * lh + 14.0 * s
    let at = float2 { clamp(m.x - w * 0.3, 4.0, float(gl.window_size().x) - w - 4.0), max(4.0, m.y - h - 18.0 * s) }
    hud_box(at, float2 { w, h }, 3.0, ui_look.face * float4 { 1.08, 1.08, 1.08, 1.0 }, false, 4.0)
    tb_text(at + float2 { 18.0 * s, 14.0 * s }, name, int(26.0 * s), ui_look.title, 2)
    big_cost(costv, at.x + w / 2.0, at.y + 54.0 * s, 30.0 * s)
    let y = at.y + 18.0 * s + 34.0 * s + 46.0 * s
    for(rows) l, n: tb_text(float2 { at.x + 18.0 * s, y + float(n) * lh }, l, fs, cols[n], 0)
    tb_flush()
    ui_flush()
