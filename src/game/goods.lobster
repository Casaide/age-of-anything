// ------------------------------------------------------------------ a building's goods, in the command panel (#98)
// In a stocked economy, selecting one of your buildings shows what it holds: a well per good it has, with the good's
// icon (icons/res_<id>.png) or, for a good with none (a pack's own), its initial in its colour, and the amount. Hovering
// a well names the good. Resources' names, initials and colours come from resources.json (a pack's merged in).
// Imported by game.lobster before the panel.

let GOODS_COLS = 7

class GoodLook:
    title:string
    short:string
    colour:float4

var goods_looks = []::GoodLook

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

// What building b shows: the goods it holds (resource, amount), in resource order. None outside a stocked economy.
def goods_of(b:int) -> [int], [int]:
    let rs = []::int
    let ns = []::int
    if r_stocked and b >= 0 and b_owner[b] == ME and b_done[b] != 0:
        for(num_resources) r:
            if b_hold[b][r] > 0:
                rs.push(r)
                ns.push(b_hold[b][r])
    return rs, ns

def goods_rows(n:int) -> int: return (n + GOODS_COLS - 1) / GOODS_COLS

def goods_at(at:float2, n:int, s:float) -> float2: return at + float2 { float(n % GOODS_COLS) * 43.0 * s, float(n / GOODS_COLS) * 43.0 * s }

// The wells (with the frame, before the sprites).
def goods_wells(at:float2, rs:[int], s:float):
    for(rs.length) n: hud_well(goods_at(at, n, s), float2_1 * 40.0 * s)

// The icons, the initials and the amounts (after the sprites). The good under the mouse, or -1.
def goods_texts(at:float2, rs:[int], ns:[int], s:float, m:float2) -> int:
    var over = -1
    for(rs) r, n:
        let p = goods_at(at, n, s)
        let look = good_look(r)
        if tb_icon_tex("res_" + resource_names[r]):
            tb_icon("res_" + resource_names[r], p + float2_1 * 6.0 * s, 28.0 * s, 1.0)
        else:
            let fs = int(22.0 * s)
            edged_text(p + float2 { (40.0 * s - tb_text_w(look.short, fs, 1)) / 2.0, 6.0 * s }, look.short, fs, look.colour, 1)
        let ct = string(ns[n])
        edged_text(p + float2 { 38.0 * s - tb_text_w(ct, int(13.0 * s), 1), 22.0 * s }, ct, int(13.0 * s), float4_1, 1)
        if m.x >= p.x and m.y >= p.y and m.x <= p.x + 40.0 * s and m.y <= p.y + 40.0 * s: over = r
    return over
