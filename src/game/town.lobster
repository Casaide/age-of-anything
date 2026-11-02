// ------------------------------------------------------------------ living towns (src/view/town_life.gd)
// The town at work and at rest, read from the sim and never written back: piles at the drop-offs
// that grow with each load home and empty slowly; dust where a builder's blow lands; idle workers
// near home sweep, sit or chat, herd animals graze, farmers till; a house grows a yard, then a
// garden; a few critters of the culture round each Town Center (dragonflies by reed towns, pigeons
// by junk towns, small birds elsewhere). Imported by game.lobster after its views (it uses them).
// Buildings (BuildingArt): chimneys smoke while they work (houses always), windows and lanterns
// glow and flicker, and a building badly hurt burns in a few places with black smoke.
// The town's sound follows your town: its size and how near the camera is (town_level).
// Damaged buildings show their broken-up stages from 30% (D-171; one baked without them cracks, drawn over the
// walls), and a fallen one's ruin burns on a while (game/fx.lobster). A stable keeps one of its race's mounts
// tethered by the door, idling and grazing.

let LOAD_DECAY_S = 14.0
let PILE_STAGE_AT = [ 0.5, 3.0, 7.0 ]
let PILE_MAX = 10.0
let CHORE_AFTER_S = 3.0
let CHORE_NEAR_HOME = 6000
let CHORE_SPELL_S = 18.0
let CHAT_REACH = 1600
let YARD_AT_S = [ 60.0, 150.0, 270.0, 420.0 ]
let CRITTERS_PER_TOWN = 6

class Was:
    task:int
    carry:int
    kind:int
    target:int

class Puff:
    p:float2
    t:float
    v:float2

class Critter:
    kind:string
    home:float2
    p:float2
    t:float
    air:float
    goal:float2
    face:float
    flying:bool = false

let town_last = dictionary<int, Was>(256)
let town_idle_since = dictionary<int, float>(256)
var chores = dictionary<int, string>(64)
let piles = dictionary<string, float>(64)  // "bid:resource index" -> loads
let house_born = dictionary<int, float>(64)
var town_puffs = []::Puff
var critters = []::Critter
let critter_towns = dictionary<int, int>(8)
var town_tick_seen = -1

// Smoke, flames and black smoke (BuildingArt's particles): canvas units.
class Puff2:
    p:float2
    v:float2
    t:float
    life:float
    kind:int  // 0 chimney smoke, 1 flame, 2 black smoke
    size:float

var town_parts = []::Puff2
let town_emit = dictionary<string, float>(128)  // "<building id>:<what>" -> particles owed
var town_builders = []::int

def is_house(k:int) -> bool: return k < su_btypes.length and gbool(su_btypes[k], "house", false)

def town_now() -> float: return float(tick) / 20.0

def ground_of_cell(i:int) -> string:
    let c = u_home[i]
    return if c < 0: "" else: tr_names[terrain[c]]

// What a unit is seen doing on top of its job from the sim (TownLife.job_for).
def town_job(i:int, job:string) -> string:
    if job == "forage" and (ground_of_cell(i) == "field" or ground_of_cell(i) == "paddy"): return "till"
    if job == "" and u_moving[i] == 0 and t_behave[u_kind[i]] == 3: return "graze"
    if job == "": return chores.get(u_id[i], "")
    return job

// What a worker holds on top of the usual pick (TownLife.tool_for).
def town_tool(i:int, tool:string) -> string:
    if u_task[i] == T_RETURN and u_carry[i] > 0 and ground_of_cell(i) == "carcass": return "load.meat"
    if u_task[i] == T_RETURN and u_carry[i] > 0 and u_carry_kind[i] > 0:
        let p = u_owner[i]
        if p < su_races.length:
            let push = gstr(gobj(creature(rstr(su_races[p], "creature")), "push_home"), resource_names[u_carry_kind[i] - 1], "")
            if push != "": return "push:" + push
    if u_task[i] == GATHER and (ground_of_cell(i) == "field" or ground_of_cell(i) == "paddy"): return "tool.hoe"
    if chores.get(u_id[i], "") == "sweep": return "tool.broom"
    return tool

def near_home(i:int) -> bool:
    for(b_id.length) b:
        if b_owner[b] == u_owner[i] and b_done[b] != 0 and (is_house(b_kind[b]) or bt_name[b_kind[b]] == "town_center"):
            let cx = (b_cx[b] * 2 + b_sx[b]) * 500
            let cy = (b_cy[b] * 2 + b_sy[b]) * 500
            if abs(cx - u_x[i]) + abs(cy - u_y[i]) < CHORE_NEAR_HOME: return true
    return false

def town_deliveries():
    let seen = dictionary<int, int>(256)
    for(u_id.length) i:
        let id = u_id[i]
        seen.set(id, 1)
        let was = town_last.get(id)
        if was:
            if was.task == T_RETURN and was.carry > 0 and u_carry[i] == 0 and b_index_of(was.target) >= 0:
                let key = "{was.target}:{was.kind - 1}"
                piles.set(key, min(piles.get(key, 0.0) + 1.0, PILE_MAX))
            was.task = u_task[i]
            was.carry = u_carry[i]
            was.kind = u_carry_kind[i]
            was.target = u_target[i]
        else: town_last.set(id, Was { u_task[i], u_carry[i], u_carry_kind[i], u_target[i] })
    for(town_last.get_keys()) id:
        if not seen.get(id, 0):
            town_last.del(id)
            town_idle_since.del(id)

def town_workers():
    let now = town_now()
    let idle = []::int
    town_builders = []
    for(u_id.length) i:
        let id = u_id[i]
        if t_worker[u_kind[i]] and views.get(id):
            if u_task[i] == BUILD: town_builders.push(i)
            if u_task[i] == T_NONE and u_moving[i] == 0 and not u_orders[i].length:
                if town_idle_since.get(id, -1.0) < 0.0: town_idle_since.set(id, now)
                if now - town_idle_since.get(id, now) >= CHORE_AFTER_S and near_home(i): idle.push(i)
            else: town_idle_since.del(id)
    let talking = dictionary<int, int>(16)
    for(idle) i, a:
        if talking.get(i, -1) < 0:
            var b2 = a + 1
            while b2 < idle.length:
                let j = idle[b2]
                if talking.get(j, -1) < 0 and u_owner[j] == u_owner[i] and abs(u_x[j] - u_x[i]) + abs(u_y[j] - u_y[i]) < CHAT_REACH:
                    talking.set(i, j)
                    talking.set(j, i)
                    break
                b2++
    chores = dictionary<int, string>(64)
    for(idle) i:
        let id = u_id[i]
        let spell = int((now - town_idle_since.get(id, now)) / CHORE_SPELL_S) + id
        var chore = [ "sweep", "sit", "sweep", "sit" ][spell % 4]
        let other = talking.get(i, -1)
        if other >= 0 and spell % 3 != 0:
            chore = "chat"
            let v = views.get(id)
            let o = views.get(u_id[other])
            if v and o: face_vec(v, o.node.pos - v.node.pos)
        chores.set(id, chore)

def town_houses():
    for(b_id.length) b:
        if is_house(b_kind[b]) and b_done[b] == 1 and house_born.get(b_id[b], -1.0) < 0.0: house_born.set(b_id[b], town_now())

def town_dust():
    for(town_builders) i:
        if i < u_id.length:
            let v = views.get(u_id[i])
            if v and v.job == "build" and v.struck and v.node.visible:
                let at = work_point(i)
                let d = at - v.node.pos
                let hit = v.node.pos - float2 { 0.0, v.lift } + (if magnitude(d) > 0.0: normalize(d) * min(10.0, magnitude(d)) else: float2_0)
                for(3): town_puffs.push(Puff { hit + float2 { rnd_range(-2.0, 2.0), rnd_range(-1.0, 1.0) }, 0.0, float2 { rnd_range(-7.0, 7.0), rnd_range(-6.0, -2.0) } })

let DAMAGE_FIRE = 0.6

def rnd_dir(dir:float2, spread:float, lo:float, hi:float) -> float2:
    let a = atan2(normalize(dir)) + rnd_range(-spread, spread)
    return float2 { cos(a), sin(a) } * rnd_range(lo, hi)

// Where building b stands on the canvas (its look's anchor), and its look's bake, if seen.
def building_anchor(b:int) -> float2:
    return ground_at(b_cx[b] * 1000 + b_sx[b] * 500, b_cy[b] * 1000 + b_sy[b] * 500)

def building_look(b:int) -> string: return building_key(arch_of[b_owner[b]], bt_name[b_kind[b]], ages[b_owner[b]], (b_id[b] * 7 + b_cx[b] * 3 + b_cy[b]) % 4)

// A few points on a building's walls, where it catches, low enough to stay on it as the roof falls in (the same
// ones always).
def fire_spots(b:int, look:string) -> [float2]:
    let lk = looks.get(look)
    if not lk: return []
    return fire_spots_on(b_id[b], lk.body)

def fire_spots_on(id:int, body:string) -> [float2]:
    let fi = frame_index(body)
    if fi < 0: return []
    let fr = frames[fi]
    var h = (id * 2654435761) & 0xffffffff
    def next() -> float:
        h = (h * 1103515245 + 12345) & 0x7fffffff
        return float(h % 10000) / 10000.0
    // (the middle of the bake: its top is often a mast or a spire with sky round it; Godot checks the
    // bake's pixels, which the pack doesn't keep)
    return map(3): float2 { (float(fr.w) * (0.3 + next() * 0.4) - float(fr.ox)) * fr.k / 1.5, (float(fr.h) * (0.48 + next() * 0.2) - float(fr.oy)) * fr.k / 1.5 }

def emit(key:string, rate:float, dt:float, make):
    var owed = town_emit.get(key, 0.0) + rate * dt
    while owed >= 1.0:
        town_parts.push(make())
        owed -= 1.0
    town_emit.set(key, owed)

def building_fx_tick(dt:float):
    for(b_id.length) b:
        let cell = b_cy[b] * W + b_cx[b]
        if b_done[b] == 1 and (teams[b_owner[b]] == teams[ME] or fog[ME][cell] == 2) and b_owner[b] < arch_of.length:
            let look = building_look(b)
            let at = building_anchor(b)
            let fx = bfx.get(look)
            if fx and fx.has_smoke and (is_house(b_kind[b]) or b_queue[b].length > 0):
                emit("{b_id[b]}:s", 2.5, dt)(): Puff2 { at + fx.smoke, rnd_dir(float2 { 0.2, -1.0 }, 12.0, 4.0, 7.0), 0.0, 4.0, 0, rnd_range(0.12, 0.2) * 16.0 }
            let full = bm_hp[b_owner[b]][b_kind[b]]
            let damage = if full > 0: 1.0 - float(b_hp[b]) / float(full) else: 0.0
            if damage >= DAMAGE_FIRE:
                let spots = fire_spots(b, look)
                let burning = min(spots.length, 1 + int((damage - DAMAGE_FIRE) / (1.0 - DAMAGE_FIRE) * 3.0))
                for(burning) k:
                    let sp = at + spots[k]
                    emit("{b_id[b]}:f{k}", 20.0, dt)(): Puff2 { sp + float2 { rnd_range(-3.0, 3.0), rnd_range(-2.0, 2.0) }, rnd_dir(float2 { 0.0, -1.0 }, 14.0, 7.0, 13.0), 0.0, 0.8, 1, rnd_range(0.14, 0.24) * 16.0 }
                    emit("{b_id[b]}:b{k}", 4.0, dt)(): Puff2 { sp + float2 { 0.0, -5.0 }, rnd_dir(float2 { 0.15, -1.0 }, 14.0, 6.0, 10.0), 0.0, 3.5, 2, rnd_range(0.16, 0.26) * 16.0 }
    for(fx_ruins) r:  // a fallen building burns on a while in its ruin
        if clock_s - r.t0 < RUIN_BURN:
            let at = r.at / 1.5
            let spots = fire_spots_on(r.id, r.body)
            for(min(r.fires, spots.length)) k:
                let sp = at + spots[k]
                emit("r{r.id}:f{k}", 20.0, dt)(): Puff2 { sp + float2 { rnd_range(-3.0, 3.0), rnd_range(-2.0, 2.0) }, rnd_dir(float2 { 0.0, -1.0 }, 14.0, 7.0, 13.0), 0.0, 0.8, 1, rnd_range(0.14, 0.24) * 16.0 }
                emit("r{r.id}:b{k}", 4.0, dt)(): Puff2 { sp + float2 { 0.0, -5.0 }, rnd_dir(float2 { 0.15, -1.0 }, 14.0, 6.0, 10.0), 0.0, 3.5, 2, rnd_range(0.16, 0.26) * 16.0 }
    for(town_parts) q:
        q.t += dt
        let g = if q.kind == 0: float2 { 2.0, -1.0 } elif q.kind == 1: float2 { 0.0, -8.0 } else: float2 { 2.5, -1.5 }
        q.v += g * dt
        q.p += q.v * dt
    town_parts = filter(town_parts) q: q.t < q.life

def mix4(a:float4, b:float4, f:float) -> float4: return a + (b - a) * f

def ramp3(a:float4, b:float4, c:float4, mid:float, k:float) -> float4:
    return if k < mid: mix4(a, b, k / mid) else: mix4(b, c, (k - mid) / (1.0 - mid))

let DAMAGE_CRACKS = 0.3

// Cracks (BuildingArt._make_cracks): short jagged lines down the walls from points across the
// body's middle band, the same ones always, in canvas units from its anchor.
def crack_lines(b:int, look:string) -> [[float2]]:
    let lk = looks.get(look)
    if not lk: return []
    let fi = frame_index(lk.body)
    if fi < 0: return []
    let fr = frames[fi]
    var h = (b_id[b] * 2246822519 + 17) & 0x7fffffff
    def next() -> float:
        h = (h * 1103515245 + 12345) & 0x7fffffff
        return float(h % 10000) / 10000.0
    return map(6):
        var p = float2 { (float(fr.w) * (0.25 + next() * 0.5) - float(fr.ox)) * fr.k / 1.5, (float(fr.h) * (0.42 + next() * 0.2) - float(fr.oy)) * fr.k / 1.5 }
        let line = [ p ]
        let dir = normalize(float2 { next() * 1.2 - 0.6, 1.0 })
        for(3 + int(next() * 3.0)):
            p += normalize(dir + float2 { next() * 1.8 - 0.9, 0.0 }) * (1.8 + next() * 1.5)
            line.push(p)
        line

// The cracks of building b, if it's hurt enough (drawn in the world's sort, just after the building).
def draw_cracks_of(b:int):
    let full = bm_hp[b_owner[b]][b_kind[b]]
    let damage = if full > 0: 1.0 - float(b_hp[b]) / float(full) else: 0.0
    if damage < DAMAGE_CRACKS: return
    let cracks = crack_lines(b, building_look(b))
    let n = min(cracks.length, 1 + int((damage - DAMAGE_CRACKS) / (1.0 - DAMAGE_CRACKS) * float(cracks.length)))
    let at = building_anchor(b)
    for(n) k:
        let l = cracks[k]
        for(l.length - 1) i:
            ui_line(at + l[i] + float2 { 0.7, 0.35 }, at + l[i + 1] + float2 { 0.7, 0.35 }, 0.7, float4 { 1.0, 0.95, 0.85, 0.25 })
            ui_line(at + l[i], at + l[i + 1], 0.7, float4 { 0.16, 0.11, 0.07, 0.85 })

// Into the draw list: each hurt building's cracks just after it.
def collect_cracks():
    for(b_id.length) b:
        if b_done[b] == 1 and fog[ME][b_cy[b] * W + b_cx[b]] != 0 and b_owner[b] < arch_of.length:
            let full = bm_hp[b_owner[b]][b_kind[b]]
            let lk = looks.get(building_look(b))
            if full > 0 and float(full - b_hp[b]) / float(full) >= DAMAGE_CRACKS and lk and not lk.ruins.length:  // (cracks: a look baked without its broken-up stages)
                let at = iso(float(b_cx[b] * 1000 + b_sx[b] * 500), float(b_cy[b] * 1000 + b_sy[b] * 500))
                draws.push(Drawable { at.y + 0.5, draws.length, -3, float(b), 0.0, float4_1, [] })

def draw_building_fx():
    gl.set_shader("color")
    for(town_parts) q:
        let k = q.t / q.life
        if q.kind == 0:
            fx_circle(q.p, q.size * lerpf(0.4, 1.5, k), ramp3(float4 { 0.8, 0.8, 0.78, 0.0 }, float4 { 0.78, 0.78, 0.76, 0.33 }, float4 { 0.7, 0.7, 0.7, 0.0 }, 0.15, k))
        elif q.kind == 2:
            fx_circle(q.p, q.size * lerpf(0.6, 2.4, k), ramp3(float4 { 0.12, 0.1, 0.09, 0.0 }, float4 { 0.1, 0.09, 0.08, 0.55 }, float4 { 0.2, 0.19, 0.18, 0.0 }, 0.12, k))
    for(town_parts) q:
        if q.kind == 1:
            let k = q.t / q.life
            fx_circle(q.p, q.size * lerpf(1.0, 0.2, k), ramp3(float4 { 1.0, 0.92, 0.5, 1.0 }, float4 { 1.0, 0.5, 0.1, 1.0 }, float4 { 0.75, 0.15, 0.05, 0.0 }, 0.35, k))
    // Lit windows and lanterns: a warm glow, flickering, added on (BuildingArt._glow).
    let old = gl.blend(blend_add_alpha)
    let now = gl.time()
    for(b_id.length) b:
        if b_done[b] == 1 and fog[ME][b_cy[b] * W + b_cx[b]] == 2 and b_owner[b] < arch_of.length:
            let fx = bfx.get(building_look(b))
            if fx:
                let at = building_anchor(b)
                for(fx.lights) l, n:
                    let ph = float(b_id[b] * 13 + n * 7)
                    let f = 0.8 + 0.2 * sin((now * 7.0 + ph) * 57.29578) * sin((now * 2.3 + ph * 2.0) * 57.29578)
                    let r = if n == 0 and fx.lights.length > 0: 9.0 else: 7.0
                    for(3) layer: fx_circle(at + l, r * (1.0 - float(layer) * 0.3), float4 { 1.0 * f, 0.78 * f, 0.4 * f, 0.12 })
    gl.blend(old)

def make_critters():
    for(b_id.length) b:
        if bt_name[b_kind[b]] == "town_center" and b_done[b] != 0 and not critter_towns.get(b_id[b], 0) and b_owner[b] < arch_of.length:
            critter_towns.set(b_id[b], 1)
            let arch = arch_of[b_owner[b]]
            let kind = if arch == "reed": "dragonfly" elif arch == "junk": "pigeon" else: "bird"
            let home = ground_at((b_cx[b] * 2 + b_sx[b]) * 500, (b_cy[b] * 2 + b_sy[b]) * 500)
            for(CRITTERS_PER_TOWN) k:
                let a = float(k) * 360.0 / float(CRITTERS_PER_TOWN) + rnd_float() * 34.0
                let r = rnd_range(70.0, 130.0)
                let p = home + float2 { cos(a) * r, sin(a) * r * 0.5 }
                critters.push(Critter { kind, home, p, rnd_float() * 5.0, if kind == "dragonfly": 8.0 else: 0.0, p, 1.0 })

def move_toward2(p:float2, to:float2, d:float) -> float2:
    let left = magnitude(to - p)
    return if left <= d: to else: p + (to - p) / left * d

def critter_tick(c:Critter, dt:float):
    c.t += dt
    if c.kind == "dragonfly":  // hover, then a quick dart to a new spot near home; bob a little
        if magnitude(c.p - c.goal) < 1.0:
            if rnd_float() < dt * 0.8:
                let a = rnd_float() * 360.0
                c.goal = c.home + float2 { cos(a), sin(a) * 0.5 } * rnd_range(40.0, 140.0)
        else:
            c.p = move_toward2(c.p, c.goal, dt * 60.0)
            if abs(c.goal.x - c.p.x) > 0.5: c.face = sign(c.goal.x - c.p.x)
        c.air = 8.0 + sin(c.t * 3.0 * 57.29578) * 1.5
        return
    if c.air > 0.0 or c.flying:  // flying off (or back): up, across to a new spot, down
        let d = c.goal - c.p
        let left = magnitude(d)
        c.p = move_toward2(c.p, c.goal, dt * 55.0)
        if abs(d.x) > 0.5: c.face = sign(d.x)
        c.air = if left > 1.0: min(18.0, left * 0.25 + 2.0) else: 0.0
        c.flying = left > 1.0
        return
    if fmodf(c.t, 0.5) < dt and rnd_float() < 0.35:  // hop a step now and then, peck
        let step = float2 { rnd_range(-4.0, 4.0), rnd_range(-2.0, 2.0) }
        c.p += step
        if abs(step.x) > 0.5: c.face = sign(step.x)
    var scare = false
    for(views.get_values()) v:
        if v.walking and magnitude(v.node.pos - c.p) < 18.0:
            scare = true
            break
    if scare or magnitude(c.p - c.home) > 170.0:
        let a = rnd_float() * 360.0
        c.goal = c.home + float2 { cos(a), sin(a) * 0.5 } * rnd_range(60.0, 130.0)
        c.flying = true

// Every frame, after the views are synced.
def town_tick(dt:float):
    if tick != town_tick_seen:  // what's read from the sim changes only on its ticks
        town_tick_seen = tick
        town_deliveries()
        town_houses()
        town_workers()
    town_dust()
    for(piles.get_keys()) k: piles.set(k, max(0.0, piles.get(k, 0.0) - dt / LOAD_DECAY_S))
    make_critters()
    building_fx_tick(dt)
    for(critters) c: critter_tick(c, dt)
    for(town_puffs) p:
        p.t += dt
        p.p += p.v * dt
    town_puffs = filter(town_puffs) p: p.t < 0.6

def pile_stage(loads:float) -> int:
    var st = 0
    for(PILE_STAGE_AT) at, k:
        if loads >= at: st = k + 1
    return st

def town_cell_free(m:float2) -> bool:  // milli-tiles
    let cx = int(m.x) / 1000
    let cy = int(m.y) / 1000
    if cx < 0 or cy < 0 or cx >= W or cy >= H: return false
    let c = cy * W + cx
    return occupied[c] == 0 and amount[c] <= 0 and walks[0][c] != 0 and not on_path(m / 1000.0)

// The piles, yards and gardens as sprites (in the draw list), and the cracks.
def collect_town():
    collect_cracks()
    collect_tethers()
    for(b_id.length) b:
        let cell = b_cy[b] * W + b_cx[b]
        if teams[b_owner[b]] == teams[ME] or fog[ME][cell] != 0:
            let shade = if fog[ME][cell] == 2 or teams[b_owner[b]] == teams[ME]: 1.0 else: 0.6
            let x0 = b_cx[b]
            let y0 = b_cy[b]
            let sx = b_sx[b]
            let sy = b_sy[b]
            // Piles: just outside the two front faces, spread along them, a resource a slot in their order.
            var slot = 0
            let k = b_kind[b]
            for(num_resources) r:
                if bt_drop[k][r] != 0:
                    let st = pile_stage(piles.get("{b_id[b]}:{r}", 0.0))
                    let name = "pile.{resource_names[r]}.{st}"
                    if st > 0 and frame_index(name) >= 0:
                        var n = 0
                        for([ float2 { float((x0 + sx) * 1000 + 300), (float(y0) + float(sy) * 0.25) * 1000.0 }, float2 { float((x0 + sx) * 1000 + 300), (float(y0) + float(sy) * 0.75) * 1000.0 },
                              float2 { (float(x0) + float(sx) * 0.75) * 1000.0, float((y0 + sy) * 1000 + 300) }, float2 { (float(x0) + float(sx) * 0.25) * 1000.0, float((y0 + sy) * 1000 + 300) } ]) s:
                            let c = cell_of(int(s.x), int(s.y))
                            if int(s.x) / 1000 < W and int(s.y) / 1000 < H and occupied[c] == 0 and amount[c] <= 0:
                                if n == slot:
                                    let at = iso(s.x, s.y)
                                    add(frame_index(name), at.x, at.y - lift_at(s.x, s.y) * 1.5, at.y, float4 { 1.0, 1.0, 1.0, shade })
                                n++
                    slot++
            // A house's yard and garden, growing with its age, on its side corners (else along its front).
            let born = house_born.get(b_id[b], -1.0)
            if born >= 0.0:
                let age = town_now() - born
                var st = 0
                for(YARD_AT_S) a, i:
                    if age >= a: st = i + 1
                if st > 0:
                    let x1 = x0 + sx
                    let y1 = y0 + sy
                    var spots = [ float2 { float(x1 * 1000 + 250), float(y0 * 1000 + 350) }, float2 { float(x0 * 1000 + 350), float(y1 * 1000 + 250) },
                                  float2 { float(x1 * 1000 + 300), float(y1 * 1000 - 700) }, float2 { float(x1 * 1000 - 700), float(y1 * 1000 + 300) } ]
                    if b_id[b] % 2 == 1: spots = [ spots[1], spots[0], spots[3], spots[2] ]
                    let free = filter(spots) p: town_cell_free(p)
                    if free.length > 0:
                        let at = iso(free[0].x, free[0].y)
                        let f = frame_index("yard{min(st, 3)}")
                        if f >= 0: add(f, at.x, at.y - lift_at(free[0].x, free[0].y) * 1.5, at.y, float4 { 1.0, 1.0, 1.0, shade })
                    if st >= 2 and free.length > 1:
                        let at = iso(free[1].x, free[1].y)
                        let f = frame_index("garden{st - 1}")
                        if f >= 0: add(f, at.x, at.y - lift_at(free[1].x, free[1].y) * 1.5, -100000.0 + at.y, float4 { 1.0, 1.0, 1.0, shade })

def town_rect(at:float2, size:float2, col:float4):
    ui_fill(at, size, col)

def lighten(c:float4, k:float) -> float4: return float4 { c.x + (1.0 - c.x) * k, c.y + (1.0 - c.y) * k, c.z + (1.0 - c.z) * k, c.w }

// Dust and critters, in canvas units (under the 1.5 scale), a few art pixels each.
def draw_town():
    draw_building_fx()
    gl.set_shader("color")
    let px = 1.0 / 1.5
    for(town_puffs) p:
        let k = p.t / 0.6
        fx_circle(p.p, (1.2 + 2.5 * k) * px * 1.5, float4 { 0.62, 0.52, 0.38, 0.55 * (1.0 - k) })
    for(critters) c:
        let m = iso_inv(c.p * 1.5)
        if m.x >= 0.0 and m.y >= 0.0 and m.x < float(W * 1000) and m.y < float(H * 1000) and seen_at(int(m.x), int(m.y)):
            let at = float2 { floor(c.p.x / px + 0.5), floor(c.p.y / px + 0.5) } * px
            let b = at - float2 { 0.0, floor(c.air + 0.5) * px }
            if c.kind == "dragonfly":
                town_rect(at + float2 { -px, 0.0 }, float2 { px * 2.0, px }, float4 { 0.0, 0.0, 0.0, 0.18 })
                town_rect(b + float2 { -2.0 * px, 0.0 }, float2 { px * 4.0, px }, hex_col("2e8a8a"))
                town_rect(b + float2 { if c.face > 0.0: 2.0 * px else: -3.0 * px, -px * 0.5 }, float2 { px, px }, hex_col("1a5a5a"))
                let wc = float4 { 0.85, 0.95, 1.0, if int(c.t * 30.0) % 2 == 0: 0.75 else: 0.4 }
                town_rect(b + float2 { -px, -px }, float2 { px, px }, wc)
                town_rect(b + float2 { px, -px }, float2 { px, px }, wc)
            else:
                let body = if c.kind == "pigeon": hex_col("8a8e96") else: hex_col("7a5a3a")
                let head = if c.kind == "pigeon": hex_col("5a6a70") else: hex_col("4a3a2a")
                if c.air > 0.5:
                    town_rect(at + float2 { -px, 0.0 }, float2 { px * 2.0, px }, float4 { 0.0, 0.0, 0.0, 0.18 })
                    let flap = if int(c.t * 14.0) % 2 == 0: -px else: px
                    town_rect(b + float2 { -px, 0.0 }, float2 { px * 3.0, px }, body)
                    town_rect(b + float2 { -px * 2.0, flap }, float2 { px * 2.0, px }, lighten(body, 0.1))
                    town_rect(b + float2 { px, flap }, float2 { px * 2.0, px }, lighten(body, 0.1))
                else:
                    let peck = fmodf(c.t, 1.3) < 0.25
                    town_rect(b + float2 { -px, -px * 2.0 }, float2 { px * 3.0, px * 2.0 }, body)
                    let hx = if c.face > 0.0: 2.0 * px else: -2.0 * px
                    town_rect(b + float2 { hx, -px * (if peck: 1.0 else: 3.0) }, float2 { px, px }, head)
                    town_rect(b + float2 { if c.face > 0.0: -px else: px, 0.0 }, float2 { px, px * 0.5 }, float4 { 0.0, 0.0, 0.0, 0.25 })

// The town's sound (TownLife._ambience): its size (finished buildings and workers) times how near
// the camera is to your Town Center (half as loud a screen away, gone further out).
def town_level() -> float:
    var buildings = 0
    var centre = float2 { -1.0, -1.0 }
    for(b_id.length) b:
        if b_owner[b] == ME and b_done[b] == 1:
            buildings++
            if centre.x < 0.0 and bt_name[b_kind[b]] == "town_center":
                centre = iso(float((b_cx[b] * 2 + b_sx[b]) * 500), float((b_cy[b] * 2 + b_sy[b]) * 500))
    var workers = 0
    for(u_id.length) i:
        if u_owner[i] == ME and t_worker[u_kind[i]]: workers++
    let size = clamp(float(buildings - 1) / 14.0 * 0.6 + float(workers) / 40.0 * 0.4, 0.0, 1.0)
    if centre.x < 0.0: return 0.0
    let half = float(gl.window_size()) * 0.5 / zoom
    let off = (centre - cam) / half
    let near = clamp(1.6 - max(abs(off.x), abs(off.y)), 0.0, 1.0)
    return size * near

// ---- the stable's tethered mount (TownLife._sync_tethers)

let tethered = dictionary<int, UV>(8)

// The mount a race's large unit rides, as a recipe of its own (no rider), or nil (giants, Heavy elites,
// centaurs: no separate mount).
def mount_recipe(p:int) -> JV?:
    for(glist(su_races[p], "units")) u:
        let r = at(u, "recipe")
        if rstr(r, "slot") == "large" and has(r, "mount") and not gbool(at(r, "mount"), "fused", false):
            let m = at(r, "mount")
            let mc = creature(rstr(m, "creature"))
            let out = jobj()
            set(out, "slot", jstr("mount"))
            set(out, "name", jstr(""))
            set(out, "body", jstr(gstr(mc, "mount_body", gstr(mc, "body", ""))))
            set(out, "head", jstr(gstr(mc, "mount_head", gstr(mc, "head", ""))))
            set(out, "parts", jobj())
            set(out, "scale", jint(100))
            set(out, "skin", at(m, "skin"))
            set(out, "family", at(r, "family"))
            set(out, "creature", at(m, "creature"))
            return out
    return nil

def tether_spot(b:int) -> float2: return float2 { float((b_cx[b] + b_sx[b]) * 1000 + 350), (float(b_cy[b]) + float(b_sy[b]) * 0.5) * 1000.0 }

def collect_tethers():
    let keep = dictionary<int, int>(8)
    for(b_id.length) b:
        let cell = b_cy[b] * W + b_cx[b]
        if bt_name[b_kind[b]] == "stable" and b_done[b] == 1 and (teams[b_owner[b]] == teams[ME] or fog[ME][cell] != 0):
            let r = mount_recipe(b_owner[b])
            if r:
                keep.set(b_id[b], 1)
                let t = tether_spot(b)
                var v = tethered.get(b_id[b])
                if not v:
                    let made = uv_new()
                    let tc = team_col(b_owner[b])
                    uv_build(made, r, float3 { tc.x, tc.y, tc.z }, 20)
                    made.node.scl = float2_1 * 0.85
                    made.pose_steps = 4
                    made.art_px = ART_SCALE
                    made.node.pos = canvas(t.x + 300.0, t.y + 250.0)
                    made.lift = lift_at(t.x + 300.0, t.y + 250.0)
                    face_vec(made, canvas(t.x, t.y) - made.node.pos)
                    tethered.set(b_id[b], made)
                    v = made
                let mv = v
                mv.job = if int(gl.time() / 7.0 + float(b_id[b])) % 3 == 0: "graze" else: ""
                uv_process(mv, gl.delta_time())
                let at = iso(t.x + 300.0, t.y + 250.0)
                add_view(mv, at.y, team_col(b_owner[b]), if fog[ME][cell] == 2 or teams[b_owner[b]] == teams[ME]: 1.0 else: 0.6)
                let post = frame_index("tether_post")
                let pa = iso(t.x, t.y)
                if post >= 0: add(post, pa.x, pa.y - lift_at(t.x, t.y) * 1.5, pa.y, float4 { 1.0, 1.0, 1.0, 1.0 })
    for(tethered.get_keys()) id:
        if not keep.get(id, 0):
            let v = tethered.get(id)
            if v: uv_free(v)
            tethered.del(id)
