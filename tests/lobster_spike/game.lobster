// Age of Anything in Lobster (docs/milestones/lobster-port.md): the ported sim and bots, the art
// from a match pack (art_pack.gd), a window to play in. You are player 0; the ported bot plays the
// rest ("watch": the bot plays you too).
// Run: lobster game.lobster -- <pack dir> <scenario file> [watch]
//   left click / drag: select;  right click: move, attack, gather, build, rally;  shift: queue
//   A + right click: attack-move;  S: stop;  B then 1-9: build;  1-9 on a building: train;  U: age up
//   Q W E R T Y I O P on a building: research;  M: sound on / off;  the minimap (bottom right): click to look there
//   arrows / screen edges: scroll;  wheel: zoom;  space: pause;  + / -: speed

import std
import vec
import color
import gl
import texture
import dictionary
import .lib.consts
import .lib.fixed
import .lib.tokens
import .lib.state
import .lib.flow
import .lib.spatial
import .lib.orders
import .lib.movement
import .lib.fog
import .lib.map
import .lib.economy
import .lib.tech
import .lib.combat
import .lib.siege
import .lib.eco_bot
import .lib.garrison
import .lib.heal
import .lib.heroes
import .lib.match
import .lib.trade
import .lib.animals
import .lib.bridges
import .lib.walls
import .lib.abilities
import .lib.trails
import .lib.commands
import .lib.ai_cfg
import .lib.scout
import .lib.land
import .lib.expand
import .lib.bot
import .lib.walls_ai
import .lib.world
import .game.audio
import .game.pack

let args = command_line_arguments()
// Options after the two paths: watch (the bot plays you too), speed:<x>, shot:<png> with at:<seconds>
// (a screenshot after that much play, then quit), look:<x>,<y> (the camera on that tile).
var watch = false
var follow = false              // the camera follows the fighting (captures)
var selftest = false            // play a few orders through the controls, check the sim took them, quit
var shot = ""
var shot_at = 0.0
var start_speed = 1.0
var look_x = -1
var look_y = -1
for(args) a, k:
    if k >= 2:
        if a == "watch": watch = true
        let key, val = split_string(a, ":")
        if key == "shot": shot = val
        if key == "at": shot_at = string_to_float(val)
        if key == "speed": start_speed = string_to_float(val)
        if a == "selftest": selftest = true
        if a == "follow": follow = true
        if key == "look":
            let lx, ly = split_string(val, ",")
            look_x = string_to_int(lx)
            look_y = string_to_int(ly)

let ME = 0
let TEAM_COLS = [float4 { 0.85, 0.22, 0.18, 1.0 }, float4 { 0.20, 0.42, 0.85, 1.0 }, float4 { 0.85, 0.75, 0.2, 1.0 },
                 float4 { 0.25, 0.7, 0.3, 1.0 }]
let WHITE = float4 { 1.0, 1.0, 1.0, 1.0 }
let ANIMAL_COL = float4 { 0.54, 0.48, 0.35, 1.0 }   // ArtKit.ANIMAL_TEAM: nobody's

def team_col(p:int) -> float4:
    if p == gaia: return ANIMAL_COL
    return if p < team_rgb.length: team_rgb[p] else: TEAM_COLS[p % TEAM_COLS.length]

// ------------------------------------------------------------------ iso (Iso.to_screen * 1.5: art px)

def iso(x:float, y:float) -> float2: return float2 { (x - y) * 0.048, (x + y) * 0.024 }
def iso_inv(p:float2) -> float2:
    let a = p.x / 0.048
    let b = p.y / 0.024
    return float2 { (a + b) / 2.0, (b - a) / 2.0 }

var cam = float2_0          // art px at the middle of the window
var zoom = 2.0              // screen px per art px

def to_screen(p:float2) -> float2: return (p - cam) * zoom + float(gl.window_size()) / 2.0
def from_screen(p:float2) -> float2: return (p - float(gl.window_size()) / 2.0) / zoom + cam
var fake_mouse = float2 { -1.0, -1.0 }   // the self-test's mouse (screen px), when set
def mouse_px() -> float2: return if fake_mouse.x >= 0.0: fake_mouse else: float(gl.mouse_pos(0))
def mouse_milli() -> float2: return iso_inv(from_screen(mouse_px()))

// ------------------------------------------------------------------ the ground

var ground_mesh:resource<mesh>? = nil
var ground_tick = -1000

def cell_noise(c:int) -> float: return float((c * 2654435761) % 1000) / 1000.0

// Each cell a fan of four triangles: its own colour in the middle, its corners the average of the
// cells round them, so the ground blends from tile to tile.
def build_ground():
    let fg = fog[ME]
    let cols = map(W * H) c:
        let t = terrain[c]
        let k = 0.35 + 0.65 * cell_noise(c)
        let shade = if fg[c] == 0: 0.12 elif fg[c] == 1: 0.55 else: 1.0
        (ground_a[t] * k + ground_b[t] * (1.0 - k)) * shade
    let corner = map((W + 1) * (H + 1)) v:
        let vx = v % (W + 1)
        let vy = v / (W + 1)
        var sum = float4_0
        var n = 0
        for([int2 { -1, -1 }, int2 { 0, -1 }, int2 { -1, 0 }, int2 { 0, 0 }]) d:
            let x = vx + d.x
            let y = vy + d.y
            if x >= 0 and y >= 0 and x < W and y < H:
                sum += cols[y * W + x]
                n++
        sum / float(max(1, n))
    let pos = []::float3
    let col = []::float4
    let idx = []::int
    for(W * H) c:
        let cx = c % W
        let cy = c / W
        let n = pos.length
        let m = iso(float(cx * 1000 + 500), float(cy * 1000 + 500))
        pos.push(float3 { m.x, m.y, 0.0 })
        col.push(float4 { cols[c].x, cols[c].y, cols[c].z, 1.0 })
        for([int2 { 0, 0 }, int2 { 1, 0 }, int2 { 1, 1 }, int2 { 0, 1 }]) d:
            let p = iso(float((cx + d.x) * 1000), float((cy + d.y) * 1000))
            let k = corner[(cy + d.y) * (W + 1) + cx + d.x]
            pos.push(float3 { p.x, p.y, 0.0 })
            col.push(float4 { k.x, k.y, k.z, 1.0 })
        for([0, 2, 1, 0, 3, 2, 0, 4, 3, 0, 1, 4]) v: idx.push(n + v)
    ground_mesh = gl.new_mesh("PC", pos, col, []::float3, []::float2, []::float2, idx)

// ------------------------------------------------------------------ what the view remembers

class Corpse:
    kind:int
    owner:int
    x:float
    y:float
    dir:int
    t0:float

var clock_s = 0.0                       // seconds of play shown
var p_id = []::int                  // the last tick's positions, for drawing between ticks
var p_x = []::int
var p_y = []::int
var unit_dir = dictionary<int, int>(1024)
var attack_t0 = dictionary<int, float>(1024)
var corpses = []::Corpse
var hit_t0 = dictionary<int, float>(1024)      // when a unit was last hit (the flash)
var shot_from = dictionary<int, int>(1024)     // a shot (its by * 65536 + landing tick) -> the tick it was first seen
var last_kind = dictionary<int, int>(1024)
var last_owner = dictionary<int, int>(1024)

def prev_pos(i:int) -> int, int:
    let found, at = binary_search(p_id, u_id[i])
    return if found: p_x[at] else: u_x[i], if found: p_y[at] else: u_y[i]

def dir_of(v:float2) -> int:
    if v.x == 0.0 and v.y == 0.0: return -1
    let a = atan2(normalize(v))
    return (int(floor(a / 45.0 + 0.5)) % 8 + 8) % 8

// Is this milli-tile spot on screen (with a margin)? Sounds only play for what you can see.
def on_screen(x:int, y:int) -> bool:
    let s = to_screen(iso(float(x), float(y)))
    let ws = float(gl.window_size())
    return s.x > -100.0 and s.y > -100.0 and s.x < ws.x + 100.0 and s.y < ws.y + 100.0

var my_units = 0
var my_age = 1
var my_researched = 0
var my_done = []::int        // ids of my finished buildings, last tick

def sounds_after_step():
    for(events) e:
        if e.kind == EV_SHOT and on_screen(e.x, e.y) and fog[ME][cell_of(e.x, e.y)] == 2:
            let i = index_of(e.a)
            if i >= 0: play_sound(unit_shot.get(u_kind[i], "shoot_arrow"), -4.0)
        elif e.kind == EV_HIT and on_screen(e.x, e.y) and fog[ME][cell_of(e.x, e.y)] == 2:
            let i = index_of(e.a)
            if i >= 0:
                if t_ranged[u_kind[i]]: play_sound("arrow_land", -8.0)
                else: play_sound(unit_blow.get(u_kind[i], "hit_pierce"), 0.0)
        elif e.kind == EV_DIE and on_screen(e.x, e.y) and fog[ME][cell_of(e.x, e.y)] != 0:
            if e.b == 1: play_sound("building_fall", -2.0)
            else:
                play_sound("fall", -3.0)
                if last_owner.get(e.a, -1) == ME: say(ME, "die")
    var n = 0
    for(u_owner) p: n += if p == ME: 1 else: 0
    if n > my_units and tick > 40: play_sound("trained", -6.0)
    my_units = n
    if ages[ME] > my_age: play_sound("age", 0.0)
    my_age = ages[ME]
    var r = 0
    for(researched[ME]) v: r += v
    if r > my_researched: play_sound("research", -4.0)
    my_researched = r
    let done = []::int
    for(b_id.length) b:
        if b_owner[b] == ME and b_done[b] == 1:
            done.push(b_id[b])
            if tick > 40 and not contains(my_done, b_id[b]): play_sound("built", -4.0)
    my_done = done

def after_step():
    sounds_after_step()
    for(events) e:
        if e.kind == EV_SHOT: attack_t0.set(e.a, clock_s)
        elif e.kind == EV_HIT:
            hit_t0.set(e.b, clock_s)
            let i = index_of(e.a)
            if i >= 0 and not t_ranged[u_kind[i]]: attack_t0.set(e.a, clock_s)
        elif e.kind == EV_DIE and e.b == 0:
            let found, at = binary_search(p_id, e.a)
            if found:
                let x = float(p_x[at])
                let y = float(p_y[at])
                corpses.push(Corpse { last_kind.get(e.a, -1), last_owner.get(e.a, 0), x, y, unit_dir.get(e.a, 0), clock_s })

// ------------------------------------------------------------------ drawing the world

class Drawable:
    y:float          // sort point (art px)
    f:int            // frame
    x:float
    ay:float         // anchor y
    col:float4

var draws = []::Drawable

def add(f:int, x:float, y:float, sort_y:float, col:float4):
    if f >= 0: draws.push(Drawable { sort_y, f, x, y, col })

def unit_state(i:int, moving:bool) -> string, int:
    let k = u_kind[i]
    let t0 = attack_t0.get(u_id[i], -10.0)
    let na = anims.get("{k}.attack", 0)
    if clock_s - t0 < na / 8.0 and clock_s - t0 < 0.5: return "attack", int((clock_s - t0) * 8.0)
    let res = if u_carry_kind[i] > 0: resource_names[u_carry_kind[i] - 1] else: ""
    let phase = int(clock_s * 8.0) + u_id[i]
    if moving:
        if t_worker[k] and u_task[i] == T_RETURN and u_carry[i] > 0: return "carry_" + res, phase % 16
        return "walk", phase % 16
    if u_task[i] == GATHER and t_worker[k]:
        let job = if res == "wood": "chop" elif res == "stone" or res == "gold": "mine" else: "forage"
        return "work_" + job, phase % 8
    if u_task[i] == BUILD and t_worker[k]: return "work_build", phase % 8
    return "idle", 0

def visible_to_me(c:int) -> bool: return fog[ME][c] == 2

def collect_units(alpha:float):
    for(u_x.length) i:
        let px, py = prev_pos(i)
        let x = px + (u_x[i] - px) * alpha
        let y = py + (u_y[i] - py) * alpha
        let mine = teams[u_owner[i]] == teams[ME]
        if mine or visible_to_me(cell_of(u_x[i], u_y[i])):
            let moving = px != u_x[i] or py != u_y[i]
            var d = unit_dir.get(u_id[i], 2)
            if moving:
                let nd = dir_of(iso(float(u_x[i] - px), float(u_y[i] - py)))
                if nd >= 0 and (abs(u_x[i] - px) + abs(u_y[i] - py)) > 4: d = nd
            elif u_foe[i] != 0:
                let j = index_of(u_foe[i])
                var tx = -1.0
                var ty = -1.0
                if j >= 0:
                    tx = float(u_x[j])
                    ty = float(u_y[j])
                else:
                    let b = b_index_of(u_foe[i])
                    if b >= 0:
                        tx = float(b_cx[b] * 1000 + b_sx[b] * 500)
                        ty = float(b_cy[b] * 1000 + b_sy[b] * 500)
                if tx >= 0.0:
                    let nd = dir_of(iso(tx - x, ty - y))
                    if nd >= 0: d = nd
            elif (u_task[i] == GATHER or u_task[i] == BUILD) and u_target[i] >= 0:
                var tx = 0.0
                var ty = 0.0
                if u_task[i] == GATHER:
                    tx = float((u_target[i] % W) * 1000 + 500)
                    ty = float((u_target[i] / W) * 1000 + 500)
                else:
                    let b = b_index_of(u_target[i])
                    if b >= 0:
                        tx = float(b_cx[b] * 1000 + b_sx[b] * 500)
                        ty = float(b_cy[b] * 1000 + b_sy[b] * 500)
                let nd = dir_of(iso(tx - x, ty - y))
                if nd >= 0: d = nd
            unit_dir.set(u_id[i], d)
            last_kind.set(u_id[i], u_kind[i])
            last_owner.set(u_id[i], u_owner[i])
            let state, n = unit_state(i, moving)
            var f = frame_index("u{u_kind[i]}.{state}.{d}.{n}")
            if f < 0: f = frame_index("u{u_kind[i]}.idle.{d}.0")
            let p = iso(x, y)
            let tc = team_col(u_owner[i])
            let since = clock_s - hit_t0.get(u_id[i], -10.0)
            let flash = if since < 0.12: 1.0 + 1.8 * (1.0 - since / 0.12) else: 1.0
            add(f, p.x, p.y, p.y, float4 { tc.x, tc.y, tc.z, flash })

def collect_corpses():
    corpses = filter(corpses) c: clock_s - c.t0 < 4.0
    for(corpses) c:
        if c.kind >= 0:
            let n = min(int((clock_s - c.t0) * 8.0), 17)
            let f = frame_index("u{c.kind}.die.{c.dir}.{n}")
            let p = iso(c.x, c.y)
            let fade = clamp(1.0 - (clock_s - c.t0 - 2.2) / 1.8, 0.0, 1.0)
            let tc = team_col(c.owner)
            add(f, p.x, p.y, p.y - 2.0, float4 { tc.x, tc.y, tc.z, 0.35 + 0.65 * fade })

def collect_buildings():
    for(b_id.length) b:
        let k = b_kind[b]
        let p = b_owner[b]
        let cell = b_cy[b] * W + b_cx[b]
        if teams[p] == teams[ME] or fog[ME][cell] != 0:
            let pick = (b_id[b] * 7 + b_cx[b] * 3 + b_cy[b]) % 4
            let key = building_key(arch_of[p], bt_name[k], ages[p], pick)
            let look = looks.get(key)
            if look:
                var name = look.body
                if b_done[b] == 0:
                    let st = clamp(b_progress[b] * 4 / max(1, bt_build_ticks[k]), 0, 3)
                    if look.stages[st] != "-": name = look.stages[st]
                let at = iso(float(b_cx[b] * 1000 + b_sx[b] * 500), float(b_cy[b] * 1000 + b_sy[b] * 500))
                let shade = if fog[ME][cell] == 2 or teams[p] == teams[ME]: 1.0 else: 0.6
                let tc = team_col(p)
                let flat = walk_over[cell] == 1
                add(frame_index(name), at.x, at.y, if flat: -100000.0 + at.y else: at.y, float4 { tc.x, tc.y, tc.z, shade })
                if look.front != "-": add(frame_index(look.front), at.x, at.y, at.y + 2.0, float4 { tc.x, tc.y, tc.z, shade })

def collect_props():
    for(W * H) c:
        if fog[ME][c] != 0 and (tr_res[terrain[c]] != 0 or species[c] != "-"):
            let tname = tr_names[terrain[c]]
            var kind = prop_of.get(tname, "")
            if kind == "tree": kind = species[c]
            elif tname == "stump" and species[c] != "-": kind = species[c]
            if kind != "" and kind != "-" and doodads.get(kind, 0) > 0:
                let left = amount[anchor(c)]
                let full = max(left, tr_amount[terrain[c]])
                let pick = c * 7 + c / W
                let stage = if tname == "stump": 3 else: resource_stage(kind, left, full)
                let name = staged(kind, pick % doodads.get(kind, 1), stage)
                let at = iso(float((c % W) * 1000 + 500), float((c / W) * 1000 + 500))
                let shade = if fog[ME][c] == 2: 1.0 else: 0.6
                let flat = pool[c] >= 0
                add(frame_index(name), at.x, at.y, if flat: -100000.0 + at.y else: at.y, float4 { 1.0, 1.0, 1.0, shade })
                let sh = frame_index(name + "~shadow")
                if sh >= 0: add(sh, at.x, at.y, -200000.0 + at.y, float4 { 1.0, 1.0, 1.0, shade })

def draw_world(alpha:float):
    if tick - ground_tick >= 10 or not ground_mesh:
        build_ground()
        ground_tick = tick
    let ws = float(gl.window_size())
    gl.translate(ws / 2.0):
        gl.scale(zoom):
            gl.translate(-float2 { floor(cam.x), floor(cam.y) }):
                gl.set_shader("color_attr")
                let gm = ground_mesh
                if gm: gl.render_mesh(gm)
                draws = []::Drawable
                collect_props()
                collect_buildings()
                collect_units(alpha)
                collect_corpses()
                qsort_in_place(draws) a, b: a.y < b.y
                b_sheet = -1
                for(draws) d: sprite(d.f, d.x, d.ay, d.col)
                flush_sprites()
                draw_shots(alpha)
                draw_marks(alpha)

// ------------------------------------------------------------------ selection and orders

var selected = []::int          // unit ids
var sel_building = 0            // building id
var drag_from = float2_0
var dragging = false
var build_menu = false
var placing = -1                // building type being placed

def selected_units() -> [int]: return filter(selected) id: index_of(id) >= 0
def selected_workers() -> [int]: return filter(selected_units()) id: t_worker[u_kind[index_of(id)]] != 0

def unit_at_screen(m:float2, mine:bool) -> int:
    var best = -1
    var best_d = 24.0 * zoom
    for(u_x.length) i:
        if (teams[u_owner[i]] == teams[ME]) == mine and (mine or visible_to_me(cell_of(u_x[i], u_y[i]))):
            let s = to_screen(iso(float(u_x[i]), float(u_y[i])) - float2 { 0.0, 14.0 })
            let d = magnitude(s - m)
            if d < best_d:
                best_d = d
                best = i
    return best

def building_at(mm:float2) -> int:
    let x = int(mm.x)
    let y = int(mm.y)
    if x < 0 or y < 0 or x >= W * TILE or y >= H * TILE: return -1
    let bid = occupied[cell_of(x, y)]
    return if bid != 0: b_index_of(bid) else: -1

def click_select(m:float2):
    sel_building = 0
    let i = unit_at_screen(m, true)
    if i >= 0 and u_owner[i] == ME:
        selected = [u_id[i]]
        say(ME, "select")
        return
    selected = []::int
    let b = building_at(mouse_milli())
    if b >= 0 and b_owner[b] == ME: sel_building = b_id[b]

def box_select(a:float2, b:float2):
    let lo = float2 { min(a.x, b.x), min(a.y, b.y) }
    let hi = float2 { max(a.x, b.x), max(a.y, b.y) }
    selected = []::int
    sel_building = 0
    for(u_x.length) i:
        if u_owner[i] == ME:
            let s = to_screen(iso(float(u_x[i]), float(u_y[i])))
            if s.x >= lo.x and s.x <= hi.x and s.y >= lo.y and s.y <= hi.y: selected.push(u_id[i])
    if selected.length: say(ME, "select")

def order(m:float2):
    let mm = mouse_milli()
    let x = int(mm.x)
    let y = int(mm.y)
    if x < 0 or y < 0 or x >= W * TILE or y >= H * TILE: return
    let q = if gl.button("left shift") >= 1: 1 else: 0
    if sel_building != 0 and not selected.length:
        issue_cmd(ME, CMD_RALLY, []::int, sel_building, x, y, 0)
        return
    let ids = selected_units()
    if not ids.length: return
    say(ME, "ack")
    let foe = unit_at_screen(m, false)
    if foe >= 0:
        issue_cmd(ME, CMD_ATTACK, ids, u_id[foe], 0, 0, 0, q)
        return
    let b = building_at(mm)
    let workers = selected_workers()
    let others = filter(ids) id: not contains(workers, id)
    if b >= 0 and is_enemy(b_owner[b], ME) and fog[ME][cell_of(x, y)] != 0:
        issue_cmd(ME, CMD_ATTACK, ids, b_id[b], 0, 0, 0, q)
        return
    let c = cell_of(x, y)
    if workers.length:
        if b >= 0 and b_owner[b] == ME and b_done[b] == 0:
            issue_cmd(ME, CMD_HELP_BUILD, workers, b_id[b], 0, 0, 0, q)
            if others.length: issue_cmd(ME, CMD_MOVE, others, x, y, 0, 0, q)
            return
        if res_at(c) != 0:
            issue_cmd(ME, CMD_GATHER, workers, c, 0, 0, 0, q)
            if others.length: issue_cmd(ME, CMD_MOVE, others, x, y, 0, 0, q)
            return
        if b >= 0 and b_owner[b] == ME and b_done[b] == 1 and (filter(workers) id: u_carry[index_of(id)] > 0).length:
            issue_cmd(ME, CMD_DROP_OFF, workers, b_id[b], 0, 0, 0, q)
            return
    let code = if gl.button("a") >= 1: CMD_ATTACK_MOVE else: CMD_MOVE
    issue_cmd(ME, code, ids, x, y, 0, 0, q)

// What player 0 may build clock_s: (type) in menu order.
def buildable() -> [int]:
    let out = []::int
    for(bt_name) name, k:
        if not build_barred(ME, k) and not bt_special[k] and name != "wonder": out.push(k)
    return out

def trainable(b:int) -> [int]:
    return bm_trains[ME][b_kind[b]]

let RESEARCH_KEYS = ["q", "w", "e", "r", "t", "y", "i", "o", "p"]

// The research building b offers player 0 now (not done, not queued, open to its race, its age and
// the one before it reached; affordable or not), in research order.
def offered(b:int) -> [int]:
    let out = []::int
    for(research) item, r:
        if item.building == b_kind[b] and researched[ME][r] == 0 and (item.after < 0 or researched[ME][item.after] != 0) and
           item.line_has[ME] and (item.before[ME] < 0 or researched[ME][item.before[ME]] != 0) and ages[ME] >= item.age and
           item.open[ME] and not tech_queued(ME, r): out.push(r)
    return out

def research_name(r:int) -> string: return research_names.get(r, research[r].id)

def place_at() -> int, int:
    let mm = mouse_milli()
    let s = bt_size[placing]
    return int(mm.x) / TILE - (s - 1) / 2, int(mm.y) / TILE - (s - 1) / 2

// Lay the foundation being placed at the mouse with the selected workers (shift: keep placing).
def place_here(more:bool):
    let cx, cy = place_at()
    let ws = selected_workers()
    if ws.length: issue_cmd(ME, CMD_BUILD, ws, placing, cx, cy, 0, if more: 1 else: 0)
    if not more: placing = -1

def train_slot(n:int):
    let b = b_index_of(sel_building)
    if b >= 0 and b_owner[b] == ME:
        let tr = trainable(b)
        if n < tr.length: issue_cmd(ME, CMD_TRAIN, []::int, sel_building, tr[n], 1, 0)

def keys():
    if gl.button("m") == 1: sound_on = not sound_on
    let digit = map(9) n: gl.button("{n + 1}") == 1
    if gl.button("b") == 1 and selected_workers().length: build_menu = not build_menu
    if build_menu:
        let menu = buildable()
        for(digit) hit, n:
            if hit and n < menu.length:
                placing = menu[n]
                build_menu = false
        return
    let b = b_index_of(sel_building)
    if b >= 0 and b_owner[b] == ME:
        for(digit) hit, n:
            if hit: train_slot(n)
        if gl.button("u") == 1: issue_cmd(ME, CMD_AGE_UP, []::int, sel_building, 0, 0, 0)
        let offer = offered(b)
        for(RESEARCH_KEYS) key, n:
            if gl.button(key) == 1 and n < offer.length: issue_cmd(ME, CMD_RESEARCH, []::int, sel_building, offer[n], 0, 0)
        if gl.button("x") == 1 and b_queue[b].length: issue_cmd(ME, CMD_CANCEL, []::int, sel_building, b_queue[b].length - 1, 0, 0)
    if gl.button("s") == 1 and selected.length and gl.button("left shift") == 0: issue_cmd(ME, CMD_STOP, selected_units(), 0, 0, 0, 0)

def mouse():
    let m = mouse_px()
    if placing >= 0:
        if gl.button("mouse1") == 1: place_here(gl.button("left shift") >= 1)
        if gl.button("mouse3") == 1 or gl.button("escape") == 1: placing = -1
        return
    if in_minimap(m):
        if gl.button("mouse1") >= 1: cam = (m - mm_top()) / mm_scale()   // look there
        if gl.button("mouse3") == 1:
            let p = iso_inv((m - mm_top()) / mm_scale())
            let ids = selected_units()
            if ids.length:
                say(ME, "ack")
                issue_cmd(ME, if gl.button("a") >= 1: CMD_ATTACK_MOVE else: CMD_MOVE, ids, int(p.x), int(p.y), 0, 0, if gl.button("left shift") >= 1: 1 else: 0)
        return
    if gl.button("mouse1") == 1:
        drag_from = m
        dragging = true
    if dragging and gl.button("mouse1") == 0:
        dragging = false
        if magnitude(m - drag_from) < 6.0: click_select(m)
        else: box_select(drag_from, m)
    if gl.button("mouse3") == 1: order(m)

def scroll():
    let ws = float(gl.window_size())
    let m = float(gl.mouse_pos(0))
    let sp = 900.0 * gl.delta_time() / zoom
    var d = float2_0
    if gl.button("left") >= 1: d.x -= 1.0
    if gl.button("right") >= 1: d.x += 1.0
    if gl.button("up") >= 1: d.y -= 1.0
    if gl.button("down") >= 1: d.y += 1.0
    let inside = m.x > 0.0 and m.y > 0.0 and m.x < ws.x and m.y < ws.y   // (outside the window the mouse reads 0, 0)
    if inside and shot == "":
        if m.x <= 3.0: d.x -= 1.0
        if m.y <= 3.0: d.y -= 1.0
        if m.x >= ws.x - 4.0: d.x += 1.0
        if m.y >= ws.y - 4.0: d.y += 1.0
    cam += d * sp
    let wheel = gl.mousewheel_delta()
    if wheel > 0: zoom = min(8.0, zoom + 1.0)
    if wheel < 0: zoom = max(1.0, zoom - 1.0)

// ------------------------------------------------------------------ marks and the HUD

def draw_ring(p:float2, r:float, col:float4):
    gl.color(col):
        gl.translate(p):
            gl.scale(float2 { 1.0, 0.5 }):
                gl.open_circle(r, 20, 1.2)

// Shots in flight (shots.gd): a dart on an arc from where it was loosed to where it lands.
def draw_shots(alpha:float):
    gl.set_shader("color")
    let n = shots.length / SHOT_STRIDE
    for(n) k:
        let o = k * SHOT_STRIDE
        let land = shots[o]
        let key = shots[o + 2] * 65536 + land % 65536
        var t_from = shot_from.get(key, -1)
        if t_from < 0:
            t_from = tick - 1
            shot_from.set(key, t_from)
        let t = clamp((float(tick - t_from) + alpha) / float(max(1, land - t_from)), 0.0, 1.0)
        let ax = float(shots[o + 7])
        let ay = float(shots[o + 8])
        let sx = float(shots[o + 9])
        let sy = float(shots[o + 10])
        if fog[ME][cell_of(int(ax), int(ay))] == 2 or fog[ME][cell_of(int(sx), int(sy))] == 2:
            let a = iso(sx, sy)
            let b = iso(ax, ay)
            let arc = magnitude(b - a) * 0.25
            def at(u:float) -> float2: return a + (b - a) * u - float2 { 0.0, 14.0 + arc * 4.0 * u * (1.0 - u) }
            gl.color(float4 { 0.2, 0.15, 0.1, 1.0 }):
                gl.line(at(max(0.0, t - 0.06)), at(t), 1.0)
    if tick % 200 == 0: shot_from = dictionary<int, int>(1024)   // (forget the landed ones now and then)

// Health bars over hurt units you can see, and over the selected.
def draw_bars(alpha:float):
    for(u_x.length) i:
        let k = u_kind[i]
        if u_hp[i] < t_hp[k] and (teams[u_owner[i]] == teams[ME] or visible_to_me(cell_of(u_x[i], u_y[i]))):
            let px, py = prev_pos(i)
            let p = iso(px + (u_x[i] - px) * alpha, py + (u_y[i] - py) * alpha)
            let hpk = float(u_hp[i]) / float(max(1, t_hp[k]))
            gl.color(float4 { 0.0, 0.0, 0.0, 0.6 }):
                gl.translate(p + float2 { -9.0, -38.0 }): gl.rect(float2 { 18.0, 3.0 })
            gl.color(float4 { 1.0 - hpk, 0.3 + 0.6 * hpk, 0.15, 1.0 }):
                gl.translate(p + float2 { -9.0, -38.0 }): gl.rect(float2 { 18.0 * hpk, 3.0 })

def draw_marks(alpha:float):
    gl.set_shader("color")
    draw_bars(alpha)
    for(selected_units()) id:
        let i = index_of(id)
        let px, py = prev_pos(i)
        let p = iso(px + (u_x[i] - px) * alpha, py + (u_y[i] - py) * alpha)
        draw_ring(p, float(u_radius[i]) * 0.068 + 3.0, float4 { 0.95, 0.91, 0.79, 1.0 })
        let hpk = float(u_hp[i]) / float(max(1, t_hp[u_kind[i]]))
        gl.color(float4 { 0.0, 0.0, 0.0, 0.6 }):
            gl.translate(p + float2 { -9.0, -38.0 }): gl.rect(float2 { 18.0, 3.0 })
        gl.color(float4 { 1.0 - hpk, 0.3 + 0.6 * hpk, 0.15, 1.0 }):
            gl.translate(p + float2 { -9.0, -38.0 }): gl.rect(float2 { 18.0 * hpk, 3.0 })
    let b = b_index_of(sel_building)
    if b >= 0:
        let at = iso(float(b_cx[b] * 1000 + b_sx[b] * 500), float(b_cy[b] * 1000 + b_sy[b] * 500))
        draw_ring(at, float(b_sx[b]) * 68.0 * 0.75, float4 { 0.95, 0.91, 0.79, 1.0 })
    if placing >= 0:
        let cx, cy = place_at()
        let ok = can_place(ME, placing, cx, cy)
        let s = bt_size[placing]
        let pts = map([int2 { 0, 0 }, int2 { s, 0 }, int2 { s, s }, int2 { 0, s }]) d: iso(float((cx + d.x) * 1000), float((cy + d.y) * 1000))
        gl.color(if ok: float4 { 0.3, 0.9, 0.3, 0.35 } else: float4 { 0.9, 0.2, 0.2, 0.35 }):
            gl.polygon(pts)

// ------------------------------------------------------------------ the minimap
// The ground mesh again, small, in the bottom bar's right end; your units and buildings and the
// enemy's you see as dots; the camera's view outlined. A click there looks there.

let MM_HALF = 110.0          // half its width, screen px (at a 1000 px high window)

// The UI's size: its numbers are for a window 1000 px high (a retina screen has twice the pixels).
def ui() -> float: return max(1.0, float(gl.window_size().y) / 1000.0)

def mm_top() -> float2:
    let ws = float(gl.window_size())
    return float2 { ws.x - MM_HALF * ui() - 20.0 * ui(), ws.y - 118.0 * ui() }

def mm_scale() -> float: return MM_HALF * ui() / (48.0 * float(max(W, H)))

def mm_point(p:float2) -> float2: return mm_top() + p * mm_scale()

def in_minimap(m:float2) -> bool:
    let top = mm_top()
    return m.x >= top.x - MM_HALF * ui() and m.x <= top.x + MM_HALF * ui() and m.y >= top.y and m.y <= top.y + MM_HALF * ui()

def draw_minimap():
    let gm = ground_mesh
    if not gm: return
    gl.translate(mm_top()):
        gl.scale(mm_scale()):
            gl.set_shader("color_attr")
            gl.render_mesh(gm)
    gl.set_shader("color")
    for(b_id.length) b:
        let cell = b_cy[b] * W + b_cx[b]
        if teams[b_owner[b]] == teams[ME] or fog[ME][cell] != 0:
            let p = mm_point(iso(float(b_cx[b] * 1000 + b_sx[b] * 500), float(b_cy[b] * 1000 + b_sy[b] * 500)))
            gl.color(team_col(b_owner[b])):
                gl.translate(p - float2 { 2.0, 2.0 }): gl.rect(float2 { 4.0, 4.0 })
    for(u_x.length) i:
        if teams[u_owner[i]] == teams[ME] or visible_to_me(cell_of(u_x[i], u_y[i])):
            let p = mm_point(iso(float(u_x[i]), float(u_y[i])))
            gl.color(team_col(u_owner[i])):
                gl.translate(p - float2 { 1.0, 1.0 }): gl.rect(float2 { 2.0, 2.0 })
    let ws = float(gl.window_size())
    let corners = map([float2_0, float2 { ws.x, 0.0 }, float2 { ws.x, ws.y - 120.0 * ui() }, float2 { 0.0, ws.y - 120.0 * ui() }]) c: mm_point(from_screen(c))
    gl.color(float4 { 0.95, 0.91, 0.79, 0.9 }):
        for(4) k: gl.line(corners[k], corners[(k + 1) % 4], 1.0)

def text_at(p:float2, s:string):
    gl.translate(p): gl.text(s)

def stock_text() -> string:
    var s = ""
    for(resource_names) r, k:
        s += "{r} {stock[k][ME]}   "
    return s + "pop {pop[ME]}/{pop_cap[ME]}   age {ages[ME]}"

def unit_name(k:int) -> string: return unit_names.get(k, t_slot[k])
def bname(k:int) -> string: return building_names.get(k, bt_name[k])

def draw_hud(paused:bool, speed:float):
    gl.set_shader("color")
    let ws = float(gl.window_size())
    let u = ui()
    gl.color(float4 { 0.08, 0.06, 0.04, 0.85 }): gl.rect(float2 { ws.x, 30.0 * u })
    gl.color(float4 { 0.08, 0.06, 0.04, 0.85 }):
        gl.translate(float2 { 0.0, ws.y - 120.0 * u }): gl.rect(float2 { ws.x, 120.0 * u })
    gl.set_font_size(int(18.0 * u))
    gl.color(float4 { 0.95, 0.9, 0.75, 1.0 }):
        text_at(float2 { 10.0 * u, 5.0 * u }, stock_text())
        let clock = tick / 20
        text_at(float2 { ws.x - 260.0 * u, 5.0 * u }, "{clock / 60}:{if clock % 60 < 10: "0" else: ""}{clock % 60}  x{speed}{if paused: "  paused" else: ""}")
        var line = ws.y - 112.0 * u
        def say(s:string):
            text_at(float2 { 12.0 * u, line }, s)
            line += 22.0 * u
        if build_menu:
            var s = "Build: "
            for(buildable()) k, n: s += "{n + 1} {bname(k)} ({bm_cost[ME][k]})  "
            say(s)
            say("Esc or B: close")
        elif placing >= 0:
            say("Placing {bname(placing)}: left click to place (shift: more), right click to cancel")
        else:
            let ids = selected_units()
            let b = b_index_of(sel_building)
            if ids.length:
                let i = index_of(ids[0])
                say("{ids.length} selected: {unit_name(u_kind[i])}  hp {u_hp[i]}/{t_hp[u_kind[i]]}")
                if selected_workers().length: say("B: build   S: stop   right click: gather / build / move   A + right click: attack-move")
                else: say("S: stop   right click: move / attack   A + right click: attack-move   shift: queue")
            elif b >= 0:
                say("{bname(b_kind[b])}  hp {b_hp[b]}/{bm_hp[ME][b_kind[b]]}{if b_done[b] == 0: "  (building)" else: ""}   queue {b_queue[b].length}")
                var s = ""
                for(trainable(b)) k, n: s += "{n + 1} {unit_name(k)} ({t_cost[k]})  "
                if s.length: say("Train: " + s)
                var rs = ""
                for(offered(b)) r, n:
                    if n < RESEARCH_KEYS.length: rs += "{RESEARCH_KEYS[n].uppercase()} {research_name(r)} ({research_cost(ME, r)})  "
                if rs.length: say("Research: " + rs)
                say("U: age up (at the Town Center)   X: cancel the last in the queue   right click: rally")
            else:
                say("Left click or drag to select. Arrows or edges scroll, wheel zooms, space pauses, +/- speed.")
    if winner >= 0:
        gl.set_font_size(int(48.0 * u))
        gl.color(float4 { 1.0, 0.85, 0.3, 1.0 }):
            text_at(ws / 2.0 - float2 { 160.0, 40.0 }, if winner == teams[ME]: "Victory!" else: "Defeat")
    draw_minimap()
    if dragging:
        let m = float(gl.mouse_pos(0))
        let lo = float2 { min(m.x, drag_from.x), min(m.y, drag_from.y) }
        let hi = float2 { max(m.x, drag_from.x), max(m.y, drag_from.y) }
        gl.color(float4 { 0.95, 0.91, 0.79, 0.8 }):
            for([[lo, float2 { hi.x, lo.y }], [float2 { hi.x, lo.y }, hi], [hi, float2 { lo.x, hi.y }], [float2 { lo.x, hi.y }, lo]]) e:
                gl.line(e[0], e[1], 1.5)

// ------------------------------------------------------------------ the self-test

var test_step = 0
var test_log = ""

def screen_of_cell(c:int) -> float2: return to_screen(iso(float((c % W) * 1000 + 500), float((c / W) * 1000 + 500)))

def expect_ok(ok:bool, what:string):
    test_log += (if ok: "PASS " else: "FAIL ") + what + "\n"

// The nearest cell to (x, y) (tiles) whose test passes, or -1.
def nearest_cell(x:int, y:int, test) -> int:
    var best = -1
    var best_d = 1 << 30
    for(W * H) c:
        if test(c):
            let d = (c % W - x) * (c % W - x) + (c / W - y) * (c / W - y)
            if d < best_d:
                best_d = d
                best = c
    return best

def self_test() -> bool:
    let tc = town_center(ME)
    let tx = b_cx[tc] + 1
    let ty = b_cy[tc] + 1
    let ws = float(gl.window_size())
    if test_step == 0 and clock_s >= 1.0:
        box_select(float2 { 1.0, 1.0 }, ws - 1.0)
        expect_ok(selected.length >= 3, "a drag over the screen selects my {selected.length} units")
        let wood = nearest_cell(tx, ty) c: res_at(c) == resource_index("wood") + 1
        let some = selected.slice(0, 2)
        selected = some
        fake_mouse = screen_of_cell(wood)
        order(fake_mouse)
        test_step++
    elif test_step == 1 and clock_s >= 2.0:
        let pick = selected_units()
        expect_ok((filter(pick) id: u_task[index_of(id)] == GATHER).length == pick.length, "right click on reeds sends the workers gathering")
        let all = filter(u_id) id: u_owner[index_of(id)] == ME and t_worker[u_kind[index_of(id)]]
        selected = [all[all.length - 1]]
        placing = btype_named("house")
        let spot = nearest_cell(tx, ty) c: can_place(ME, placing, c % W - 0, c / W - 0) and (c % W - tx) * (c % W - tx) + (c / W - ty) * (c / W - ty) > 9
        fake_mouse = screen_of_cell(spot)
        place_here(false)
        test_step++
    elif test_step == 2 and clock_s >= 3.0:
        expect_ok((filter(b_id.length) b: b_owner[b] == ME and bt_name[b_kind[b]] == "house").length >= 1, "B, a house and a click lays a house down")
        fake_mouse = screen_of_cell(b_cy[tc] * W + b_cx[tc] + 1)
        click_select(fake_mouse)
        expect_ok(sel_building == b_id[tc], "a click on the Town Center selects it")
        train_slot(0)
        test_step++
    elif test_step == 3 and clock_s >= 4.0:
        expect_ok(b_queue[tc].length >= 1 or pop[ME] > 3, "1 on the Town Center trains a worker")
        let army = filter(u_id) id: u_owner[index_of(id)] == ME
        selected = army
        fake_mouse = to_screen(iso(float(tx * 1000 + 4000), float(ty * 1000 + 4000)))
        order(fake_mouse)
        test_step++
    elif test_step == 4 and clock_s >= 4.5:
        expect_ok((filter(selected_units()) id: u_moving[index_of(id)] == 1 or u_task[index_of(id)] != T_NONE).length > 0, "right click on open ground moves them")
        print test_log
        return true
    return false

// ------------------------------------------------------------------ main

assert args.length >= 2
var trail = ""
def note(s:string):
    trail += "{seconds_elapsed()}: {s}\n"
    write_file("/tmp/aoa_lobster_trail.txt", trail, 0, 1)

note("start")
// (a capture runs without vsync: with the display asleep, vsync never lets a frame through)
fatal(gl.window("Age of Anything (Lobster)", 1600, 1000, if shot != "" or selftest: gl.window_init_no_vsync else: 0))
if shot != "" or selftest: gl.set_target_delta_time(1.0 / 60.0)
note("window")
fatal(gl.load_materials(SPRITE_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
zoom = 2.0 * floor(ui() + 0.5)   // two screen points an art pixel, as the game's camera
load_pack(args[0])
note("pack")
start_world(args[1])
note("world")
events_on = true
let bots = map(num_players) p: new_bot(p)
note("bots")
let tc0 = town_center(ME)
if tc0 >= 0: cam = iso(float(b_cx[tc0] * 1000 + 1500), float(b_cy[tc0] * 1000 + 1500))
if look_x >= 0: cam = iso(float(look_x * 1000 + 500), float(look_y * 1000 + 500))
var acc = 0.0
var paused = false
var speed = start_speed
var steps = 0
var frame_no = 0
var step_time = 0.0
note("loop")
while gl.frame() and not (gl.button("escape") == 1 and placing < 0 and not build_menu):
    if gl.button("escape") == 1: build_menu = false
    if gl.button("space") == 1: paused = not paused
    if gl.button("=") == 1: speed = min(8.0, speed * 2.0)
    if gl.button("-") == 1: speed = max(0.25, speed / 2.0)
    let dt = gl.delta_time()
    frame_no++
    if shot != "" and frame_no < 3: note("frame {frame_no} cam {cam} zoom {zoom} ws {gl.window_size()} fb {gl.framebuffer_size()} tc {tc0} draws {draws.length} W {W} H {H} first {iso(0.0, 0.0)} last {iso(float(W * 1000), float(H * 1000))}")
    if shot != "" and frame_no % 60 == 0: print "frame {frame_no}: {dt * 1000.0} ms, play {clock_s} s"
    if not paused and winner < 0: acc += dt * speed
    acc = min(acc, 0.5)
    while acc >= 0.05:
        p_id = copy(u_id)
        p_x = copy(u_x)
        p_y = copy(u_y)
        let t0 = seconds_elapsed()
        for(bots) bot, p:
            if p != ME or watch: full_bot_think(bot)
        step()
        step_time += seconds_elapsed() - t0
        steps++
        clock_s += 0.05
        after_step()
        acc -= 0.05
    if follow:
        var fx = 0
        var fy = 0
        var nf = 0
        for(u_x.length) i:
            if u_foe[i] != 0:
                fx += u_x[i]
                fy += u_y[i]
                nf++
        if nf > 0: cam = cam + (iso(float(fx / nf), float(fy / nf)) - cam) * 0.05
    scroll()
    keys()
    mouse()
    gl.clear(float4 { 0.05, 0.05, 0.05, 1.0 })
    gl.blend(1)
    draw_world(acc / 0.05)
    draw_hud(paused, speed)
    if selftest and self_test():
        if shot != "": gl.screenshot(shot)
        return
    if shot != "" and clock_s >= shot_at and not selftest:
        gl.screenshot(shot)
        print "shot {shot} at {clock_s} s, tick {tick}; sim {step_time * 1000.0 / max(1, steps)} ms a tick"
        return
