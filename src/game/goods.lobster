// ------------------------------------------------------------------ a building's goods, in the command panel (#98, #127)
// In a stocked economy, selecting one of your buildings shows what it holds, large, in its own part of the panel: a well
// per good with the good's icon (icons/res_<id>.png) or, for a good with none (a pack's own), its initial in its colour,
// big; the amount under it and the good's name at the foot. The town's hub (the storehouse) shows every good it can keep,
// those it has none of dimmed, so what's missing shows too. Hovering a well names the good. Resources' names, initials and
// colours come from resources.json (a pack's merged in).
// Imported by game.lobster before the panel.

let GOOD_W = 84.0  // a well, in UI px (times hud_s())
let GOOD_H = 96.0
let GOOD_GAP = 8.0
let GOOD_DIM = float4 { 1.0, 1.0, 1.0, 0.4 }
class GoodLook:
    title:string
    short:string
    colour:float4

var goods_looks = []::GoodLook
let goods_icons = dictionary<string, int>(16)  // a good's icon: 1 there is one, 0 there isn't (tb_icon falls back to another)

def good_has_icon(r:int) -> bool:
    let name = "res_" + resource_names[r]
    var got = goods_icons.get(name, -1)
    if got < 0:
        got = if read_file("icons/" + name + ".png"): 1 else: 0
        goods_icons.set(name, got)
    return got == 1

def good_look(r:int) -> GoodLook:
    if goods_looks.length != num_resources:
        goods_looks = []
        let rd = at(lib_data("resources.json"), "resources")
        for(resource_names) id:
            var found = GoodLook { id, id.substring(0, 1).uppercase(), float4_1 }
            for(rd.a) e:
                if gstr(e, "id", "") == id:
                    found = GoodLook { gstr(e, "name", id), gstr(e, "short", found.short), hex4(gstr(e, "colour", "#ffffff")) }
            goods_looks.push(found)
    return goods_looks[r]

// What building b shows: the goods it holds (resource, amount), in resource order; the hub also those it can keep but
// has none of (amount 0). None outside a stocked economy.
def goods_of(b:int) -> [int], [int]:
    let rs = []::int
    let ns = []::int
    if r_stocked and b >= 0 and b_owner[b] == ME and b_done[b] != 0:
        let hub = has_role(b_kind[b], ROLE_HUB)
        for(num_resources) r:
            if b_hold[b][r] > 0 or (hub and bt_hold[b_kind[b]][r] > 0):
                rs.push(r)
                ns.push(b_hold[b][r])
    return rs, ns

// Columns: at least 5 a row, and at most two rows till there are more than 16.
def goods_cols(n:int) -> int: return min(n, max(min(8, (n + 1) / 2), 5))

def goods_size(n:int, s:float) -> float2:
    if n == 0: return float2_0
    let cols = goods_cols(n)
    let rows = (n + cols - 1) / cols
    return float2 { float(cols) * (GOOD_W + GOOD_GAP) - GOOD_GAP, float(rows) * (GOOD_H + GOOD_GAP) - GOOD_GAP } * s

def goods_at(at:float2, n:int, total:int, s:float) -> float2:
    let cols = goods_cols(total)
    return at + float2 { float(n % cols) * (GOOD_W + GOOD_GAP), float(n / cols) * (GOOD_H + GOOD_GAP) } * s

// The wells (with the frame, before the sprites).
def goods_wells(at:float2, rs:[int], s:float):
    for(rs.length) n: hud_well(goods_at(at, n, rs.length, s), float2 { GOOD_W, GOOD_H } * s)

// The icons, the amounts and the names (after the sprites). The good under the mouse, or -1.
def goods_texts(at:float2, rs:[int], ns:[int], s:float, m:float2) -> int:
    var over = -1
    for(rs) r, n:
        let p = goods_at(at, n, rs.length, s)
        let look = good_look(r)
        let some = ns[n] > 0
        let fade = if some: float4_1 else: GOOD_DIM
        let side = 44.0 * s
        let ix = p.x + (GOOD_W * s - side) / 2.0
        if good_has_icon(r):
            tb_icon("res_" + resource_names[r], float2 { ix, p.y + 8.0 * s }, side, if some: 1.0 else: 0.4)
        else:
            let fs = int(34.0 * s)
            edged_text(float2 { p.x + (GOOD_W * s - tb_text_w(look.short, fs, 1)) / 2.0, p.y + 10.0 * s }, look.short, fs, look.colour * fade, 1)
        let ct = string(ns[n])
        let cfs = int(22.0 * s)
        edged_text(float2 { p.x + (GOOD_W * s - tb_text_w(ct, cfs, 1)) / 2.0, p.y + 54.0 * s }, ct, cfs, fade, 1)
        let nfs = int(13.0 * s)
        tb_text(float2 { p.x + (GOOD_W * s - tb_text_w(look.title, nfs, 0)) / 2.0, p.y + 78.0 * s }, look.title, nfs, ui_look.dim * fade, 0)
        if m.x >= p.x and m.y >= p.y and m.x <= p.x + GOOD_W * s and m.y <= p.y + GOOD_H * s: over = r
    return over
