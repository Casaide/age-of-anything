// The Lobster sim spike (2026-10-25): src/sim ported to Lobster, headless, checked against the
// GDScript sim by a hash of its state after every tick (scenarios from tests/lobster_spike/export.gd).
// The modules in lib/ follow src/sim: consts and fixed (fixed.gd), state (the World's and units.gd's
// arrays), flow (flow.gd and the field cache), spatial (spatial.gd), orders (World's orders and
// formations, the MOVE / ATTACK_MOVE / STANCE commands), movement (World._move, _separate), fog
// (fog.gd's visible grid) and combat (combat.gd, shots.gd). The tick and the scenario file are here.
// Left out (constant in the scenarios, asserted by the exporter): jobs and buildings, walls, rect
// moves, near fields, webs, trails, wading, hills, map changes, heroes, siege weapons.
// Run: lobster sim.lobster -- <scenario file> [dump tick] [trace tick]

import std
import .lib.consts
import .lib.fixed
import .lib.tokens
import .lib.state
import .lib.flow
import .lib.spatial
import .lib.orders
import .lib.movement
import .lib.fog
import .lib.combat

// ------------------------------------------------------------------ the tick

class Cmd:
    run_tick:int
    kind:int        // 0 MOVE, 1 ATTACK_MOVE, 2 STANCE
    player:int
    x:int
    y:int
    stance:int
    ids:[int]

var cmds = []::Cmd
var next_cmd = 0

// World.step, for the systems ported: commands, combat, fog, flow-field solves, moves, separation.
def step():
    if tick % TICKS_PER_TURN == 0:
        while next_cmd < cmds.length and cmds[next_cmd].run_tick == tick:
            let c = cmds[next_cmd]
            if c.kind == 0: run_move(c.player, c.ids, c.x, c.y)
            elif c.kind == 1: run_attack_move(c.player, c.ids, c.x, c.y)
            else: run_stance(c.player, c.ids, c.stance)
            next_cmd++
    spatial_build()
    let alive = u_x.length
    combat_tick()
    fog_tick()
    if u_x.length != alive: spatial_build()
    trace("start")
    solve_queued()
    move()
    trace("move")
    spatial_build()
    separate()
    trace("separate")
    tick++

var trace_tick = -1

def unit_fields(i:int) -> [int]:
    return [u_id[i], u_x[i], u_y[i], u_tx[i], u_ty[i], u_moving[i], u_arrive[i], u_wx[i], u_wy[i], u_group[i], u_stuck[i],
            u_prog[i], u_fkey[i], u_pace[i], u_hp[i], u_foe[i], u_cooldown[i], u_stance[i], u_posture[i], u_gx[i], u_gy[i],
            u_amx[i], u_amy[i], u_amc[i]]

def unit_line(i:int) -> string:
    var s = ""
    for(unit_fields(i)) v, k:
        if k: s += " "
        s += string(v)
    return s

// Every unit's fields at the start of the tick's moves, after them and after separation (export.gd's trace:<tick>).
def trace(what:string):
    if tick != trace_tick: return
    for(u_x.length) i: print "{what} {unit_line(i)}"

// export.gd's state_hash: the tick, the next group, the cached and queued fields, every unit, the
// shots in the air, the losses.
def state_hash() -> int:
    var h = FNV_START
    h = mix(h, tick)
    h = mix(h, next_group)
    for(field_keys) k: h = mix(h, k)
    h = mix(h, -1)
    for(field_queue) k: h = mix(h, k)
    h = mix(h, u_x.length)
    for(u_x.length) i:
        h = mix(h, u_id[i])
        h = mix(h, u_x[i])
        h = mix(h, u_y[i])
        h = mix(h, u_tx[i])
        h = mix(h, u_ty[i])
        h = mix(h, u_moving[i])
        h = mix(h, u_arrive[i])
        h = mix(h, u_wx[i])
        h = mix(h, u_wy[i])
        h = mix(h, u_group[i])
        h = mix(h, u_stuck[i])
        h = mix(h, u_prog[i])
        h = mix(h, u_fkey[i])
        h = mix(h, u_pace[i])
        h = mix(h, u_hp[i])
        h = mix(h, u_foe[i])
        h = mix(h, u_cooldown[i])
        h = mix(h, u_stance[i])
        h = mix(h, u_posture[i])
        h = mix(h, u_gx[i])
        h = mix(h, u_gy[i])
        h = mix(h, u_amx[i])
        h = mix(h, u_amy[i])
        h = mix(h, u_amc[i])
    h = mix(h, shots.length / SHOT_STRIDE)
    for(shots) v: h = mix(h, v)
    for(lost) v: h = mix(h, v)
    return h

def dump_state() -> string:
    var s = "tick {tick} next_group {next_group} fields {field_keys} queue {field_queue} shots {shots} lost {lost}\n"
    for(u_x.length) i: s += unit_line(i) + "\n"
    return s

// ------------------------------------------------------------------ the scenario file

def load(path:string):
    let text = assert read_file(path)
    tokens = filter(tokenize(text, " \n", "")): _.length > 0
    expect("AOWSPIKE")
    assert next_int() == 2
    expect("MAP")
    W = next_int()
    H = next_int()
    let lanes = next_int()
    for(lanes): walks.push(read_ints(W * H))
    expect("SPEED")
    let classes = next_int()
    for(classes): speed_pct.push(read_ints(W * H))
    expect("SIGHT")
    opaque = read_ints(W * H)
    level = read_ints(W * H)
    expect("PLAYERS")
    num_players = next_int()
    lane_base = read_ints(num_players)
    teams = read_ints(num_players)
    expect("RULES")
    r_min_damage = next_int()
    r_acquire_every = next_int()
    r_defend_sight = next_int()
    r_counter_pull = next_int()
    r_leash = next_int()
    r_sight = next_int()
    r_shot_lead_pct = next_int()
    r_shot_strays = next_int()
    r_shot_slack = next_int()
    r_high_reach = next_int()
    r_uphill_pct = next_int()
    r_high_sight_unit = next_int()
    has_heights = next_int()
    r_fog_every = next_int()
    r_fog_unit = next_int()
    r_fog_worker = next_int()
    expect("TYPES")
    let nt = next_int()
    num_classes = next_int()
    for(nt):
        t_speed.push(next_int())
        t_radius.push(next_int())
        t_role.push(next_int())
        t_gap.push(next_int())
        t_worker.push(next_int())
        t_harmless.push(next_int())
        t_healer.push(next_int())
        t_ranged.push(next_int())
        t_reach.push(next_int())
        t_reload.push(next_int())
        t_shot_speed.push(next_int())
        t_min_damage.push(next_int())
        t_sight.push(next_int())
        t_mclass.push(next_int())
        t_atk.push(read_ints(num_classes))
        t_arm.push(read_ints(num_classes))
        t_cls.push(read_ints(num_classes))
        t_counters.push(read_ints(next_int()))
    expect("TICK")
    tick = next_int()
    next_int()   // next_id (no spawns in the spike)
    next_group = next_int()
    expect("UNITS")
    let n = next_int()
    for(n):
        let f = read_ints(29)
        // unit_fields order, then owner, kind, speed, radius, mclass
        let cols = [u_id, u_x, u_y, u_tx, u_ty, u_moving, u_arrive, u_wx, u_wy, u_group, u_stuck, u_prog, u_fkey, u_pace,
                    u_hp, u_foe, u_cooldown, u_stance, u_posture, u_gx, u_gy, u_amx, u_amy, u_amc,
                    u_owner, u_kind, u_speed, u_radius, u_mclass]
        for(cols) col, k: col.push(f[k])
    expect("SHOTS")
    shots = read_ints(next_int() * SHOT_STRIDE)
    expect("LOST")
    lost = read_ints(num_players)
    expect("FOG")
    for(num_players):
        let g = read_ints(W * H)
        fog.push(g)
        fog_lit.push(filter_indices(g): _ == VISIBLE)
    expect("CMDS")
    let nc = next_int()
    for(nc):
        let rt = next_int()
        let kind = next_int()
        let p = next_int()
        let x = next_int()
        let y = next_int()
        let stance = next_int()
        let ids = read_ints(next_int())
        cmds.push(Cmd { rt, kind, p, x, y, stance, ids })

def zeros(n:int) -> [int]: return map(n): 0

// Roomy and tight grids per lane (SimMap.roomy_grid): the walk grids never change here.
def make_room():
    room_cw = (W + ROOM_CHUNK - 1) / ROOM_CHUNK
    let ch = (H + ROOM_CHUNK - 1) / ROOM_CHUNK
    for(walks) g:
        let room = zeros(W * H)
        let tg = zeros(room_cw * ch)
        for(W * H) c:
            let cx = c % W
            let cy = c / W
            var ok = cx > 0 and cy > 0 and cx < W - 1 and cy < H - 1
            if ok:
                for(3) dy:
                    for(3) dx:
                        if g[(cy - 1 + dy) * W + cx - 1 + dx] == 0: ok = false
            room[c] = if ok: 1 else: 0
            if not ok: tg[(cy / ROOM_CHUNK) * room_cw + cx / ROOM_CHUNK]++
        roomy.push(room)
        tight.push(tg)

let args = command_line_arguments()
assert args.length >= 1
load(args[0])
let n = u_x.length
let cells = W * H
for(RING): ring.push([]::int)
sp_start = zeros(cells)
sp_end = zeros(cells)
sp_cursor = zeros(cells)
sp_items = zeros(n)
sp_cell = zeros(n)
slot_x = zeros(n)
slot_y = zeros(n)
f_ahead = zeros(n)
f_side = zeros(n)
s_pushx = zeros(n)
s_pushy = zeros(n)
s_settle = zeros(n)
s_stood = zeros(n)
s_yields = zeros(n)
s_role = zeros(n)
c_hurt = zeros(n)
c_hurt_by = zeros(n)
c_engaged = zeros(n)
c_inbound = zeros(n)
make_room()
make_chunks()

expect("HASHES")
let ticks = next_int()
let expected = read_ints(ticks)
var dump_tick = -1
if args.length >= 2:
    let v, ok = string_to_int(args[1])
    dump_tick = v
if args.length >= 3:
    let v, ok = string_to_int(args[2])
    trace_tick = v

var spent = 0.0
var first_bad = -1
for(ticks) k:
    let t0 = seconds_elapsed()
    step()
    spent += seconds_elapsed() - t0
    if first_bad < 0 and state_hash() != expected[k]:
        first_bad = k
    if tick == dump_tick:
        write_file(args[0] + ".lobster.dump", dump_state(), 0, 1)
var left = map(num_players): 0
for(u_owner) p: left[p]++
print "{n} units, {ticks} ticks, {cmds.length} orders; left at the end: {left}"
print "lobster step: {spent * 1000.0 / ticks} ms a tick"
if first_bad < 0:
    print "hashes: all {ticks} match"
else:
    print "hashes: first mismatch after tick {tick - ticks + first_bad} (index {first_bad})"
