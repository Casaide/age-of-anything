// The mouse cursor, drawn by the game (#116). Lobster can hide the OS cursor only in relative mode, where gl.mouse_pos
// stops, so in a match a virtual cursor adds up gl.mouse_delta and mouse_px() reads it. Let go in the pause menu and
// when the window loses the focus; the lobby keeps the OS cursor. Pad and touch play draw none.
//
// Lobster's limits here: gl.mouse_delta is in window points and rounds towards zero after adding a half (-1 reads 0, -2
// reads -1), and gl.cursor(true) warps the OS cursor back to where it was captured, not to the virtual spot.

let CURSOR_SIZE = 0.65                    // of the 32 px art: about 21 points
let CURSOR_TIP = 0.5                      // a tool's pointer, at half size
let CURSOR_TOOL_AT = float2 { 7.0, 7.0 }  // where the tool sits after its pointer

var vc_waiting = false  // no focus at the start, or lost: not taken until a click in the window (not the title bar's)
var vc_focused = false

def vc_axis(v:int) -> int: return if v < 0: v - 1 else: v  // (undoes the rounding but for -1)

def vc_capture():
    let ws = float(gl.window_size())
    let m = float(gl.mouse_pos(0))
    vc_pos = if m.x > 0.0 or m.y > 0.0: m else: ws / 2.0
    gl.cursor(false)
    vc_on = true

def vc_release():
    if not vc_on: return
    gl.cursor(true)
    vc_on = false

// Once a frame in a match, before the mouse is read.
def vc_tick():
    if vc_free or touch_play or frame_no < 1: return  // (not during the load: frame 1 bakes)
    let focused = gl.window_focused()
    if frame_no == 1: vc_waiting = not focused
    elif vc_focused and not focused:
        vc_release()
        vc_waiting = true
    vc_focused = focused
    if gl.button("mouse1") >= 1: vc_waiting = false  // (a click in the window: it's ours, whatever the flag says)
    if menu_open or vc_waiting: vc_release()
    elif not vc_on: vc_capture()
    if vc_on:
        let d = gl.mouse_delta(0)
        let moved = float2 { float(vc_axis(d.x)), float(vc_axis(d.y)) } * vc_scale
        vc_pos = clamp(vc_pos + moved, float2_1, float(gl.window_size()) - float2_1)

// What a right click would do at m (order in game.lobster), as a cursor's name.
def cursor_kind(m:float2) -> string:
    if placing >= 0 or tree_open or typing_race or end_screen_up() or panel_click(m) or in_minimap(m): return "pointer"
    if arming_attack or arming_ability: return "attack"
    let all = selected_units()
    if not all.length: return "pointer"
    let ids = filter(all) id: not is_animal(index_of(id))
    if not ids.length: return "move"
    let mm = mouse_milli()
    let x = int(mm.x)
    let y = int(mm.y)
    if x < 0 or y < 0 or x >= W * TILE or y >= H * TILE: return "pointer"
    let workers = selected_workers().length > 0
    let c = cell_of(x, y)
    let b = building_at(mm)
    let mine = unit_at_screen(m, true)
    if unit_at_screen(m, false) >= 0: return "attack"
    if mine >= 0 and u_owner[mine] == ME and is_animal(mine) and workers: return "attack"
    if b >= 0 and is_enemy(b_owner[b], ME) and fog[ME][c] != 0: return "attack"
    if workers:
        let bridge = bridge_on(c)
        if res_at(c) != 0: return cursor_of_resource(res_at(c))
        if bridge >= 0 and br_up[bridge] == 0: return "build"
        if mine >= 0 and can_mend(ME, u_id[mine]): return "build"
        if b >= 0:
            if can_mend(ME, b_id[b]): return "build"
            if b_owner[b] == ME:
                if b_done[b] == 0 or pool[c] >= 0: return "build"
                for(ids) id:
                    let i = index_of(id)
                    if takes_in(b, i): return cursor_of_resource(u_carry_kind[i])
    return "move"

def cursor_of_resource(res:int) -> string:
    let name = resource_names[res - 1]
    return if name == "food": "forage" elif name == "wood": "chop" else: "mine"

// Drawn last, over the HUD and its cards.
def draw_cursor():
    if not vc_on and fake_mouse.x < 0.0: return
    if pad_on or touch_play: return
    let m = mouse_px()
    let kind = cursor_kind(m)
    let k = CURSOR_SIZE * vc_scale
    tb_flush()
    ui_flush()
    if kind == "pointer" or kind == "move" or kind == "attack":
        let spot = float2 { 3.0, if kind == "attack": 3.0 else: 2.0 }  // (in the art)
        tb_icon("cursor_" + kind, m - spot * k, 32.0 * k, 1.0)
    else:  // a tool, with a small pointer at its top left: the pointer's tip is the spot
        let at = m - float2 { 3.0, 2.0 } * k * CURSOR_TIP
        tb_icon("cursor_" + kind, at + CURSOR_TOOL_AT * k, 32.0 * k, 1.0)
        tb_icon("cursor_pointer", at, 32.0 * k * CURSOR_TIP, 1.0)
    ui_flush()
