// ------------------------------------------------------------------ playing on a pad (src/view/pad_play.gd, pad_wheel.gd)
// A reticle near the screen's middle stands in for the mouse (it's the fake mouse the match's own
// functions read, so there's no second way to play): the left stick pans the camera and the reticle
// rides along, the right stick nudges it off centre. A taps to select, held it grows a circle that
// sweeps up your units; tapped on what's already selected it opens the selection's wheel (train,
// research, age up for a building; build for workers), where a stick points and A chooses. X is the
// smart order, Y attack-move, B backs out, RB your soldiers on screen, LT / RT zoom, the d-pad an idle
// worker (down), the Town Center (up), groups 1 and 2 (left, right; held: kept). Last input wins:
// the mouse moving hands play back to it. Imported by game.lobster after its controls.

let PAD_PAN = 1300.0
let PAD_NUDGE = 900.0
let PAD_NUDGE_MAX = 0.42
let PAD_TAP = 0.22
let PAD_CIRCLE_START = 34.0
let PAD_CIRCLE_GROW = 300.0
let PAD_CIRCLE_MAX = 0.42
let PAD_GROUP_HOLD = 0.5
let PAD_BUTTONS = ["a", "b", "x", "y", "leftshoulder", "rightshoulder", "dpup", "dpdown", "dpleft", "dpright", "start", "back", "leftstick", "rightstick"]

// One frame of the pad: the sticks and triggers (SDL's order: left x, y, right x, y, LT, RT) and the
// buttons held. Read from the pad, or made up by a test.
class PadIn:
    axes:[float]
    down:[string]

class WheelItem:
    label:string
    act:int                       // 0 train (arg: slot), 1 research (arg: research), 2 age up, 3 build (arg: building type)
    arg:int

var pad_on = false
var pad_off = float2_0            // the reticle off the screen's middle, screen px
var pad_prev = []::string
var pad_held_t = dictionary<string, float>(16)
var pad_circle = 0.0
var pad_wheel = []::WheelItem
var pad_pick = 0
var pad_last_mouse = float2 { -1.0, -1.0 }
var pad_lt = false
var pad_kept = []::string         // d-pad buttons held long enough to keep a group (once a hold)
var pad_rt = false

def read_pad() -> PadIn:
    return PadIn { map(6) i: gl.controller_axis(i), filter(PAD_BUTTONS) b: gl.button("controller_" + b) >= 1 }

def reticle() -> float2: return float(gl.window_size()) / 2.0 + pad_off

def wheel_items() -> [WheelItem]:
    let out = []::WheelItem
    let b = b_index_of(sel_building)
    if b >= 0 and b_owner[b] == ME and not selected.length:
        for(trainable(b)) k, n: out.push(WheelItem { "Train " + unit_names.get(k, t_slot[k]), 0, n })
        if bt_name[b_kind[b]] == "town_center": out.push(WheelItem { "Age up", 2, 0 })
        for(offered(b)) r: out.push(WheelItem { research_name(r), 1, r })
    elif selected_workers().length:
        for(buildable()) k: out.push(WheelItem { "Build " + replace_string(bt_name[k], "_", " "), 3, k })
    return out

def wheel_choose(w:WheelItem):
    switch w.act:
        case 0: train_slot(w.arg)
        case 1: issue_cmd(ME, CMD_RESEARCH, []::int, sel_building, w.arg, 0, 0)
        case 2: issue_cmd(ME, CMD_AGE_UP, []::int, sel_building, 0, 0, 0)
        default:
            placing = w.arg
            pad_wheel = []

def is_selected_here(m:float2) -> bool:
    let i = unit_at_screen(m, true)
    if i >= 0: return contains(selected, u_id[i])
    let b = building_at(mouse_milli())
    return b >= 0 and sel_building != 0 and b_id[b] == sel_building

def go_to(i:int):
    selected = [u_id[i]]
    sel_building = 0
    cam = iso(float(u_x[i]), float(u_y[i]))

def soldiers_on_screen() -> [int]:
    let ws = float(gl.window_size())
    let out = []::int
    for(u_id.length) i:
        if u_owner[i] == ME and not t_worker[u_kind[i]] and t_animal[u_kind[i]] == 0:
            let s = to_screen(iso(float(u_x[i]), float(u_y[i])))
            if s.x >= 0.0 and s.y >= 0.0 and s.x <= ws.x and s.y <= ws.y: out.push(u_id[i])
    return out

// One frame of pad play. Returns true while the pad has the controls (the mouse's are skipped).
def pad_tick(pin:PadIn, dt:float) -> bool:
    let m = float(gl.mouse_pos(0))
    let moved = pad_last_mouse.x >= 0.0 and magnitude(m - pad_last_mouse) > 2.0
    pad_last_mouse = m
    let any_pad = pin.down.length > 0 or (filter(pin.axes) x: abs(x) > 0.2).length > 0
    if moved and not any_pad and pad_on:   // last input wins: the mouse takes over
        pad_on = false
        fake_mouse = float2 { -1.0, -1.0 }
        pad_wheel = []
    if any_pad: pad_on = true
    if not pad_on:
        pad_prev = pin.down
        return false
    def pressed(b:string) -> bool: return has_s(pin.down, b) and not has_s(pad_prev, b)
    def released(b:string) -> bool: return not has_s(pin.down, b) and has_s(pad_prev, b)
    for(pin.down) b:
        if not has_s(pad_prev, b): pad_held_t.set(b, 0.0)
        else: pad_held_t.set(b, pad_held_t.get(b, 0.0) + dt)
    let ws = float(gl.window_size())
    let left = float2 { pin.axes[0], pin.axes[1] }
    let right = float2 { pin.axes[2], pin.axes[3] }
    if pad_wheel.length:   // the wheel: either stick points, A chooses (it stays up), B closes
        let d = if magnitude(left) > magnitude(right): left else: right
        if magnitude(d) > 0.5:
            let a = atan2(d)
            pad_pick = (int(floor(((a + 90.0 + 360.0) % 360.0) / 360.0 * float(pad_wheel.length) + 0.5))) % pad_wheel.length
        if pressed("a"): wheel_choose(pad_wheel[pad_pick])
        if pressed("b"): pad_wheel = []
        pad_prev = pin.down
        return true
    cam += left * PAD_PAN * dt / zoom
    let lim = ws * 0.5 * PAD_NUDGE_MAX
    pad_off = float2 { clamp(pad_off.x + right.x * PAD_NUDGE * dt, -lim.x, lim.x), clamp(pad_off.y + right.y * PAD_NUDGE * dt, -lim.y, lim.y) }
    if pressed("rightstick"): pad_off = float2_0
    fake_mouse = reticle()
    // A: tap selects (or opens the wheel on what's selected, or lays what's being placed); held, the circle sweeps.
    if has_s(pin.down, "a") and pad_held_t.get("a", 0.0) >= PAD_TAP and placing < 0:
        if pad_circle == 0.0:
            pad_circle = PAD_CIRCLE_START
            selected = []
            sel_building = 0
        pad_circle = min(pad_circle + PAD_CIRCLE_GROW * dt, min(ws.x, ws.y) * PAD_CIRCLE_MAX)
        let c = reticle()
        for(u_id.length) i:
            if u_owner[i] == ME and t_animal[u_kind[i]] == 0 and not contains(selected, u_id[i]):
                let s = to_screen(iso(float(u_x[i]), float(u_y[i])))
                if magnitude((s - c) * float2 { 1.0, 2.0 }) <= pad_circle: selected.push(u_id[i])
    if released("a"):
        if pad_circle > 0.0: pad_circle = 0.0
        elif placing >= 0: place_here(false)
        elif is_selected_here(reticle()):
            pad_wheel = wheel_items()
            pad_pick = 0
        else: click_select(reticle())
    if pressed("x"):
        if placing >= 0: place_here(false)
        else: order(reticle())
    if pressed("y") and selected_units().length:
        let mm = mouse_milli()
        issue_cmd(ME, CMD_ATTACK_MOVE, selected_units(), int(mm.x), int(mm.y), 0, 0, 0)
    if pressed("b"):
        if placing >= 0: placing = -1
        elif build_menu: build_menu = false
        else:
            selected = []
            sel_building = 0
    if pressed("rightshoulder"):
        selected = soldiers_on_screen()
        sel_building = 0
    let lt = pin.axes[4] > 0.5
    let rt = pin.axes[5] > 0.5
    if lt and not pad_lt: zoom = max(1.0, zoom - 1.0)
    if rt and not pad_rt: zoom = min(8.0, zoom + 1.0)
    pad_lt = lt
    pad_rt = rt
    if pressed("dpdown"):   // the next idle worker
        let idle = filter(u_id.length) i: u_owner[i] == ME and t_worker[u_kind[i]] and u_task[i] == T_NONE and u_moving[i] == 0
        if idle.length:
            let after = if selected.length: (filter(idle) i: u_id[i] > selected[0]) else: []
            go_to(if after.length: after[0] else: idle[0])
    if pressed("dpup"):
        let tc = town_center(ME)
        if tc >= 0:
            selected = []
            sel_building = b_id[tc]
            cam = iso(float(b_cx[tc] * 1000 + b_sx[tc] * 500), float(b_cy[tc] * 1000 + b_sy[tc] * 500))
    for(["dpleft", "dpright"]) b, n:
        if has_s(pin.down, b) and pad_held_t.get(b, 0.0) >= PAD_GROUP_HOLD and not has_s(pad_kept, b):
            store_group(n)
            banner = "Group {n + 1} kept"
            banner_t = gl.time()
            pad_kept.push(b)
        if released(b):
            if not has_s(pad_kept, b): recall_group(n)
            pad_kept = filter(pad_kept) k: k != b
    pad_prev = pin.down
    return true

def pad_draw():
    if not pad_on: return
    gl.set_shader("color")
    let u = ui()
    let c = reticle()
    let rcol = float4 { 0.949, 0.914, 0.788, 0.9 }
    gl.color(rcol):
        gl.translate(c):
            gl.scale(float2 { 1.0, 0.5 }): gl.open_circle(12.0 * u, 24, 0.16)
            gl.line(float2 { -18.0 * u, 0.0 }, float2 { -8.0 * u, 0.0 }, 2.0 * u)
            gl.line(float2 { 8.0 * u, 0.0 }, float2 { 18.0 * u, 0.0 }, 2.0 * u)
    if pad_circle > 0.0:
        gl.color(float4 { rcol.x, rcol.y, rcol.z, 0.6 }):
            gl.translate(c):
                gl.scale(float2 { 1.0, 0.5 }): gl.open_circle(pad_circle, 48, 2.0 * u / pad_circle)
    if pad_wheel.length:
        let r = 150.0 * u
        let mid = float(gl.window_size()) / 2.0
        gl.color(float4 { 0.0, 0.0, 0.0, 0.45 }):
            gl.translate(mid): gl.circle(r + 70.0 * u, 48)
        gl.set_font_size(int(18.0 * u))
        for(pad_wheel) w, n:
            let a = float(n) / float(pad_wheel.length) * 360.0 - 90.0
            let at = mid + float2 { cos(a), sin(a) } * r
            let size = gl.text_size(w.label)
            let col = if n == pad_pick: float4 { 1.0, 0.85, 0.4, 1.0 } else: float4 { 0.9, 0.86, 0.75, 1.0 }
            if n == pad_pick:
                gl.color(float4 { 0.3, 0.2, 0.1, 0.9 }):
                    gl.translate(at - float(size) / 2.0 - float2_1 * 6.0 * u): gl.rect(float(size) + float2_1 * 12.0 * u)
            lobby_text(at - float(size) / 2.0, w.label, col)
