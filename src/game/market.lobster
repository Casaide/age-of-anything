// ------------------------------------------------------------------ the marketplace's panel (#43)
// A building of yours with "market": true in buildings.json, finished, gets its own part of the command panel: the good
// it gives (left) and the good it gets (right), each large in a well with arrows under it to walk through the goods it
// trades (those it holds), a big arrow between with the rate (so many of one for one of the other), and the trades still
// ordered with less and more buttons (shift: ten). Its rules are Steading's Lua (hooks/market.lua): a pick is the order
// MARKET_SET (give + 1, get + 1), a count MARKET_MORE (how many more); what it shows is read from the hook's columns.
// Imported by game.lobster before the panel: the panel calls market_on, market_size, market_frame and market_texts.

let MARKET_W = 470.0  // UI px (times hud_s())
let MARKET_H = 335.0
let MARKET_WELL = 128.0
let MARKET_ARROW = 40.0
let MARKET_SET = 140
let MARKET_MORE = 141

def market_col(name:string) -> int: return find(hook_building_names) n: n == name

def market_get(name:string, bi:int) -> int:
    let c = market_col(name)
    return if c >= 0: hook_building_get(c, bi) else: 0

// Building bi's panel is the market's: yours, finished, its type a market.
def market_on(bi:int) -> bool:
    if bi < 0 or b_owner[bi] != ME or b_done[bi] == 0 or b_kind[bi] >= su_btypes.length: return false
    return gbool(su_btypes[b_kind[bi]], "market", false)

def market_size(s:float) -> float2: return float2 { MARKET_W, MARKET_H } * s

// The goods it trades: those it holds.
def market_goods(bi:int) -> [int]: return filter(num_resources) r: bt_hold[b_kind[bi]][r] > 0

// The next good from r (-1: none yet) by step, skipping the other side's.
def market_step(goods:[int], r:int, by:int, other:int) -> int:
    var at = find(goods) g: g == r
    if at < 0: at = if by > 0: -1 else: 0
    for(goods.length):
        at = (at + by + goods.length) % goods.length
        if goods[at] != other: return goods[at]
    return r

class MarketLay:
    give:float2
    get:float2
    turns:[float2]  // give back, give on, get back, get on
    less:float2
    more:float2

def market_lay(at:float2, s:float) -> MarketLay:
    let wy = at.y + 20.0 * s
    let give = float2 { at.x + 10.0 * s, wy }
    let get = float2 { at.x + (MARKET_W - 10.0 - MARKET_WELL) * s, wy }
    let ty = wy + (MARKET_WELL + 8.0) * s
    let half = MARKET_WELL / 2.0 - 4.0
    let turns = [ float2 { give.x, ty }, float2 { give.x + (half + 8.0) * s, ty }, float2 { get.x, ty }, float2 { get.x + (half + 8.0) * s, ty } ]
    let by = ty + (MARKET_ARROW + 22.0) * s
    let cx = at.x + MARKET_W * s / 2.0
    return MarketLay { give, get, turns, float2 { cx - 150.0 * s, by }, float2 { cx + 98.0 * s, by } }

def market_turn_w() -> float: return MARKET_WELL / 2.0 - 4.0

// The boxes, the buttons and the clicks (with the panel's frame).
def market_frame(at:float2, bi:int, s:float):
    let lay = market_lay(at, s)
    let goods = market_goods(bi)
    let give = market_get("m_give", bi) - 1
    let get = market_get("m_get", bi) - 1
    hud_well(lay.give, float2_1 * MARKET_WELL * s)
    hud_well(lay.get, float2_1 * MARKET_WELL * s)
    var g2 = give
    var t2 = get
    for(lay.turns) p, n:
        let side = float2 { market_turn_w(), MARKET_ARROW } * s
        if hud_button(p, side, false, goods.length > 1):
            let by = if n % 2 == 0: -1 else: 1
            if n < 2: g2 = market_step(goods, give, by, get)
            else: t2 = market_step(goods, get, by, give)
        school_chevron(p + float2 { (market_turn_w() - MARKET_ARROW) / 2.0, 0.0 } * s, MARKET_ARROW * s, n % 2 == 0, ui_look.accent)
    if g2 != give or t2 != get:
        issue_cmd(ME, MARKET_SET, [ sel_building ], g2 + 1, t2 + 1, 0, 0)
        play_sound("ui_click", -6.0)
    let by = if shift_held(): 10 else: 1
    let set = give >= 0 and get >= 0
    if hud_button(lay.less, float2 { 52.0, 52.0 } * s, false, set and market_get("m_left", bi) > 0):
        issue_cmd(ME, MARKET_MORE, [ sel_building ], -by, 0, 0, 0)
        play_sound("ui_click", -6.0)
    if hud_button(lay.more, float2 { 52.0, 52.0 } * s, true, set):
        issue_cmd(ME, MARKET_MORE, [ sel_building ], by, 0, 0, 0)
        play_sound("ui_click", -6.0)

// A good, big, in a well: its icon (or initial) and its name under it.
def market_good(p:float2, r:int, s:float):
    let cx = p.x + MARKET_WELL * s / 2.0
    if r < 0:
        centred(cx, p.y + 50.0 * s, "pick", int(20.0 * s), ui_look.dim, 0)
        return
    let look = good_look(r)
    let side = 76.0 * s
    if good_has_icon(r): tb_icon("res_" + resource_names[r], float2 { cx - side / 2.0, p.y + 12.0 * s }, side, 1.0)
    else: centred(cx, p.y + 18.0 * s, look.short, int(60.0 * s), look.colour, 1)
    centred(cx, p.y + (MARKET_WELL - 30.0) * s, look.title, int(16.0 * s), ui_look.text, 0)

// The words and the goods (after the sprites).
def market_texts(at:float2, bi:int, s:float):
    let lay = market_lay(at, s)
    let give = market_get("m_give", bi) - 1
    let get = market_get("m_get", bi) - 1
    let rate = market_get("m_rate", bi)
    let caption = ui_look.metal + (float4_1 - ui_look.metal) * 0.25
    tb_text(float2 { lay.give.x, at.y - 1.0 * s }, "GIVE", int(13.0 * s), caption, 3)
    tb_text(float2 { lay.get.x, at.y - 1.0 * s }, "GET", int(13.0 * s), caption, 3)
    market_good(lay.give, give, s)
    market_good(lay.get, get, s)
    // The arrow between, with the rate over it.
    let ax0 = lay.give.x + (MARKET_WELL + 18.0) * s
    let ax1 = lay.get.x - 18.0 * s
    let ay = lay.give.y + MARKET_WELL * s / 2.0 + 12.0 * s
    let col = if give >= 0 and get >= 0: ui_look.accent else: ui_look.dim
    ui_line(float2 { ax0, ay }, float2 { ax1, ay }, 6.0 * s, col)
    ui_line(float2 { ax1, ay }, float2 { ax1 - 18.0 * s, ay - 14.0 * s }, 6.0 * s, col)
    ui_line(float2 { ax1, ay }, float2 { ax1 - 18.0 * s, ay + 14.0 * s }, 6.0 * s, col)
    let cx = (ax0 + ax1) / 2.0
    if give >= 0 and get >= 0 and rate > 0:
        centred(cx, ay - 52.0 * s, "{rate} for 1", int(24.0 * s), ui_look.title, 2)
        let paid = market_get("m_paid", bi)
        centred(cx, ay + 18.0 * s, "{min(paid, rate)} of {rate} in", int(14.0 * s), ui_look.dim, 0)
    else: centred(cx, ay - 44.0 * s, "Pick two goods", int(16.0 * s), ui_look.dim, 0)
    // The trades ordered, between less and more.
    let left = market_get("m_left", bi)
    let ox = at.x + MARKET_W * s / 2.0
    centred(ox, lay.less.y + 2.0 * s, string(left), int(30.0 * s), ui_look.title, 2)
    centred(ox, lay.less.y + 36.0 * s, if left == 1: "trade ordered" else: "trades ordered", int(13.0 * s), ui_look.dim, 0)
    centred(lay.less.x + 26.0 * s, lay.less.y + 8.0 * s, "-", int(30.0 * s), ui_look.title, 2)
    centred(lay.more.x + 26.0 * s, lay.more.y + 8.0 * s, "+", int(30.0 * s), ui_look.title, 2)
    centred(ox, lay.less.y + 58.0 * s, "shift: ten at a time", int(12.0 * s), ui_look.dim, 0)
