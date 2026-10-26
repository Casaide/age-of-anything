// ------------------------------------------------------------------ the command panel (src/view/command_panel.gd, unit_card.gd)
// Along the foot of the screen: on the left the unit card (a portrait drawn from the unit's own parts,
// its name, hit points and stats), then the selection's buttons with their hotkeys: a building trains
// (each unit's portrait), researches and ages up; workers build (each building's picture), and stop.
// A click on a button does what its key does; hovering shows its cost. Imported by game.lobster after
// its controls and the tech tree page (box, page_text).

class Btn:
    label:string
    hotkey:string
    act:int                       // 0 train slot, 1 research, 2 age up, 3 build, 4 stop, 5 cancel the last in the queue
    arg:int
    unit = -1                     // a unit type to draw on it
    building = -1                 // or a building type
    cost = ""

let PANEL_H = 150.0               // ui px
let BTN = 64.0
var portraits = dictionary<int, UV>(64)

def panel_top() -> float: return float(gl.window_size().y) - PANEL_H * ui()

def in_panel(m:float2) -> bool: return m.y >= panel_top() and not in_minimap(m)

def cost_words(c:[int]) -> string:
    let parts = []::string
    for(c) v, n:
        if v > 0: parts.push("{v} {resource_names[n]}")
    return concat_string(parts, ", ")

def panel_buttons() -> [Btn]:
    let out = []::Btn
    if build_menu or selected_workers().length:   // (workers in the selection: what they can build)
        for(buildable()) k, n:
            let b = Btn { bname(k), if n < 9: string(n + 1) else: "", 3, k }
            b.building = k
            b.cost = cost_words(bm_cost[ME][k])
            out.push(b)
        out.push(Btn { "Stop", "S", 4, 0 })
        return out
    let bi = b_index_of(sel_building)
    if bi >= 0 and b_owner[bi] == ME and not selected.length:
        for(trainable(bi)) k, n:
            let b = Btn { unit_name(k), if n < 9: string(n + 1) else: "", 0, n }
            b.unit = k
            b.cost = cost_words(t_cost[k])
            out.push(b)
        for(offered(bi)) r, n:
            let b = Btn { research_name(r), if n < RESEARCH_KEYS.length: RESEARCH_KEYS[n].uppercase() else: "", 1, r }
            b.cost = cost_words(research_cost(ME, r))
            out.push(b)
        if bt_name[b_kind[bi]] == "town_center": out.push(Btn { "Age up", "U", 2, 0 })
        if b_queue[bi].length: out.push(Btn { "Cancel", "X", 5, 0 })
        return out
    if selected_units().length: out.push(Btn { "Stop", "S", 4, 0 })
    return out

def press(b:Btn):
    switch b.act:
        case 0: train_slot(b.arg)
        case 1: issue_cmd(ME, CMD_RESEARCH, []::int, sel_building, b.arg, 0, 0)
        case 2: issue_cmd(ME, CMD_AGE_UP, []::int, sel_building, 0, 0, 0)
        case 3:
            placing = b.arg
            build_menu = false
        case 4: issue_cmd(ME, CMD_STOP, selected_units(), 0, 0, 0, 0)
        default:
            let bi = b_index_of(sel_building)
            if bi >= 0 and b_queue[bi].length: issue_cmd(ME, CMD_CANCEL, []::int, sel_building, b_queue[bi].length - 1, 0, 0)

def btn_at(n:int) -> float2:
    let u = ui()
    let per_row = 9
    return float2 { 420.0 * u + float(n % per_row) * (BTN + 8.0) * u, panel_top() + 14.0 * u + float(n / per_row) * (BTN + 8.0) * u }

// A click on the panel: true if it took it (the world doesn't get it).
def panel_click(m:float2) -> bool:
    if not in_panel(m): return false
    if gl.button("mouse1") == 1:
        let u = ui()
        for(panel_buttons()) b, n:
            let at = btn_at(n)
            if m.x >= at.x and m.y >= at.y and m.x <= at.x + BTN * u and m.y <= at.y + BTN * u: press(b)
    return true

// A unit's figure from its own parts, drawn at a screen point (feet there), z screen px a canvas unit.
def draw_portrait(k:int, at:float2, z:float):
    var v = portraits.get(k)
    if not v:
        let made = uv_new()
        let tc = team_col(t_player[k])
        uv_build(made, su_type_recipe[k], float3 { tc.x, tc.y, tc.z }, 20)
        made.node.scl = float2_1 * 0.85
        made.pose_steps = 8
        made.art_px = 1.5
        face_vec(made, float2 { 1.0, 1.0 })
        portraits.set(k, made)
        v = made
    let pv = v
    if not pv: return
    pv.node.pos = float2_0
    uv_process(pv, gl.delta_time())
    let tc = team_col(t_player[k])
    for(draw_list(pv, ID_XF)) d:
        let f = frame_index("p:" + d.key)
        if f >= 0: sprite_xf(f, xf_mul([1.5 * z, 0.0, 0.0, 1.5 * z, at.x, at.y], d.xf), float4 { tc.x, tc.y, tc.z, d.alpha })

// A building's picture scaled into a box (its look's body bake; sprite_xf places the frame's corner).
def draw_building_icon(k:int, at:float2, size:float):
    let lk = looks.get(building_key(arch_of[ME], bt_name[k], ages[ME], 0))
    if not lk: return
    let f = frame_index(lk.body)
    if f < 0: return
    let fr = frames[f]
    let s = size / float(max(fr.w, fr.h))
    let tc = team_col(ME)
    sprite_xf(f, [s, 0.0, 0.0, s, at.x + size / 2.0 - float(fr.w) / 2.0 * s, at.y + size / 2.0 - float(fr.h) / 2.0 * s], float4 { tc.x, tc.y, tc.z, 1.0 })

def draw_panel():
    let u = ui()
    let ws = float(gl.window_size())
    let top = panel_top()
    box(float2 { 0.0, top }, float2 { ws.x, PANEL_H * u }, float4 { 0.1, 0.075, 0.05, 0.94 })
    box(float2 { 0.0, top }, float2 { ws.x, 3.0 * u }, float4 { 0.45, 0.33, 0.18, 1.0 })
    // The unit card: the first selected unit (or the building).
    let ids = selected_units()
    let bi = b_index_of(sel_building)
    box(float2 { 12.0 * u, top + 12.0 * u }, float2 { 110.0 * u, PANEL_H * u - 24.0 * u }, float4 { 0.16, 0.12, 0.08, 1.0 })
    let btns = panel_buttons()
    let m = float(gl.mouse_pos(0))
    var hover = -1
    for(btns) b, n:
        let at = btn_at(n)
        let on = m.x >= at.x and m.y >= at.y and m.x <= at.x + BTN * u and m.y <= at.y + BTN * u
        if on: hover = n
        box(at, float2_1 * BTN * u, if on: float4 { 0.36, 0.27, 0.15, 1.0 } else: float4 { 0.22, 0.17, 0.11, 1.0 })
        box(at, float2 { BTN * u, 2.0 * u }, float4 { 0.55, 0.42, 0.24, 1.0 })
        if b.act == 1: box(at + float2 { 4.0 * u, 4.0 * u }, float2_1 * (BTN - 8.0) * u, float4 { 0.2, 0.28, 0.17, 1.0 })
        if b.act == 2: box(at + float2 { 4.0 * u, 4.0 * u }, float2_1 * (BTN - 8.0) * u, float4 { 0.4, 0.3, 0.1, 1.0 })
    // Pictures (sprites) after the boxes, text last.
    b_sheet = -1
    if ids.length:
        draw_portrait(u_kind[index_of(ids[0])], float2 { 67.0 * u, top + 128.0 * u }, 1.7 * u)
    elif bi >= 0:
        draw_building_icon(b_kind[bi], float2 { 22.0 * u, top + 30.0 * u }, 90.0 * u)
    for(btns) b, n:
        let at = btn_at(n)
        if b.unit >= 0: draw_portrait(b.unit, at + float2 { BTN * 0.5 * u, BTN * 0.86 * u }, 1.1 * u)
        if b.building >= 0: draw_building_icon(b.building, at + float2 { 4.0 * u, 4.0 * u }, (BTN - 8.0) * u)
    flush_sprites()
    let fs = int(13.0 * u)
    let light = float4 { 0.95, 0.9, 0.75, 1.0 }
    if ids.length:
        let i = index_of(ids[0])
        let k = u_kind[i]
        page_text(float2 { 132.0 * u, top + 14.0 * u }, (if ids.length > 1: string(ids.length) + " x " else: "") + unit_name(k), int(18.0 * u), light)
        page_text(float2 { 132.0 * u, top + 42.0 * u }, "hp {u_hp[i]} / {t_hp[k]}", fs, light)
        page_text(float2 { 132.0 * u, top + 62.0 * u }, "attack {fold(t_atk[k], 0) a, b: max(a, b)}   armour {fold(t_arm[k], 0) a, b: max(a, b)}", fs, light)
        page_text(float2 { 132.0 * u, top + 82.0 * u }, "speed {t_speed[k]}   cost {cost_words(t_cost[k])}", fs, light)
    elif bi >= 0:
        page_text(float2 { 132.0 * u, top + 14.0 * u }, bname(b_kind[bi]), int(18.0 * u), light)
        page_text(float2 { 132.0 * u, top + 42.0 * u }, "hp {b_hp[bi]} / {bm_hp[b_owner[bi]][b_kind[bi]]}" + (if b_done[bi] == 0: "   (building)" else: ""), fs, light)
        page_text(float2 { 132.0 * u, top + 62.0 * u }, "queue {b_queue[bi].length}" + (if b_queue[bi].length: ": " + concat_string(map(b_queue[bi]) q: unit_name(q), ", ") else: ""), fs, light)
    else:
        page_text(float2 { 132.0 * u, top + 14.0 * u }, "Left click or drag to select. Arrows or edges scroll, wheel zooms, space pauses, +/- speed. F1: tech tree.", fs, light)
    for(btns) b, n:
        let at = btn_at(n)
        if b.hotkey != "": page_text(at + float2 { 4.0 * u, 2.0 * u }, b.hotkey, int(12.0 * u), float4 { 1.0, 0.85, 0.4, 1.0 })
        if b.unit < 0 and b.building < 0: page_text(at + float2 { 6.0 * u, BTN * 0.4 * u }, if b.label.length > 9: b.label.substring(0, 8) + "." else: b.label, int(11.0 * u), light)
    if hover >= 0:
        let b = btns[hover]
        page_text(float2 { 420.0 * u, top - 26.0 * u }, b.label + (if b.cost != "": "   " + b.cost else: ""), int(15.0 * u), float4 { 1.0, 0.92, 0.7, 1.0 })
    page_flush()
