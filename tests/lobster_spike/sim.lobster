// The Lobster sim spike (2026-10-25): src/sim ported to Lobster, headless, checked against the
// GDScript sim by a hash of its state after every tick (scenarios from tests/lobster_spike/export.gd).
// The modules in lib/ follow src/sim: consts and fixed (fixed.gd), state (the World's, units.gd's and
// buildings.gd's arrays), flow (flow.gd: fields, patching, the field cache), spatial (spatial.gd),
// orders (World's orders and formations, MOVE / ATTACK_MOVE / STANCE), movement (World._move,
// _separate, the spots round a rect), fog (fog.gd's visible grid), map (sim_map.gd's changes and
// World._sync_map), economy (economy.gd: buildings, jobs, farms, training, its commands) and combat
// (combat.gd, shots.gd). The tick and the scenario file are here.
// Left out (none in the scenarios, asserted by the exporter): walls, gates, bridges, pens, towers,
// research and ageing up, heroes, healers, animals, siege weapons, trade, garrisons, webs, trails,
// wading, shift-queued orders.
// Run: lobster sim.lobster -- <scenario file> [dump tick] [trace tick]

import std
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
import .lib.eco_bot
import .lib.garrison
import .lib.heal
import .lib.heroes
import .lib.match

// ------------------------------------------------------------------ the tick

class Cmd:
    run_tick:int
    code:int        // 0 MOVE, 1 ATTACK_MOVE, 2 STANCE, 3 GATHER, 4 BUILD, 5 HELP_BUILD, 6 TRAIN, 7 RALLY, 8 RESEED, 9 AGE_UP
    player:int
    a:int
    b:int
    c:int
    d:int
    ids:[int]
    seq:int

var cmds = []::Cmd             // recorded orders, in run order (replaying a scenario's)
var next_cmd = 0
var pending = []::Cmd          // orders the bots issued, waiting for their turn (bots mode)
var next_seq = []::int         // per player

// Issue an order this turn: it runs at the start of turn + 2, after the turn's earlier orders,
// by (player, seq) (Commands.issue and take).
def issue_cmd(p:int, code:int, ids:[int], a:int, b:int, c:int, d:int):
    pending.push(Cmd { (tick / TICKS_PER_TURN + 2) * TICKS_PER_TURN, code, p, a, b, c, d, ids, next_seq[p] })
    next_seq[p]++

// The pending orders that run now, in (player, seq) order (all were issued in one turn).
def take_pending() -> [Cmd]:
    let keys = []::int
    for(pending) c, k:
        if c.run_tick == tick: keys.push((c.player << 40) | (c.seq << 20) | k)
    sort_ints(keys)
    let out = map(keys) key: pending[key & ((1 << 20) - 1)]
    pending = filter(pending): _.run_tick != tick
    return out

def run(c:Cmd):
    let p = c.player
    switch c.code:
        case 0: run_move(p, c.ids, c.a, c.b)
        case 1: run_attack_move(p, c.ids, c.a, c.b)
        case 2: run_stance(p, c.ids, c.a)
        case 3: cmd_gather(p, own_units_cleared(p, c.ids), c.a)
        case 4: cmd_build(p, own_units_cleared(p, c.ids), c.a, c.b, c.c)
        case 5: cmd_help_build(p, own_units_cleared(p, c.ids), c.a)
        case 6: cmd_train(p, c.a, c.b, c.c)
        case 7: cmd_rally(p, c.a, c.b, c.c)
        case 8: cmd_reseed(p, c.ids, c.a)
        case 9: cmd_age_up(p, c.a)
        case 10: cmd_research(p, c.a, c.b)
        case 11: cmd_call_to_arms(p, c.a)
        case 12: cmd_back_to_work(p)
        case 13: cmd_attack(p, filter(c.ids) uid: index_of(uid) >= 0 and u_owner[index_of(uid)] == p, c.a)
        default: assert false

// The scratch arrays grow with the units (training adds them).
def grow_scratch():
    let n = u_x.length
    for([sp_items, sp_cell, slot_x, slot_y, f_ahead, f_side, s_pushx, s_pushy, s_settle, s_stood, s_yields, s_role, s_planted,
         c_hurt, c_hurt_by, c_engaged, c_inbound]) a:
        while a.length < n: a.push(0)

// World.step, for the systems ported: commands, training, jobs, combat, fog, map changes,
// flow-field solves, moves, separation.
def step():
    if tick % TICKS_PER_TURN == 0:
        while next_cmd < cmds.length and cmds[next_cmd].run_tick == tick:
            run(cmds[next_cmd])
            next_cmd++
        for(take_pending()) c: run(c)
    train()
    grow_scratch()
    tech_tick()
    work()
    garrison_tick()
    spatial_build()
    let alive = unit_changes
    heal_tick()
    combat_tick()
    hero_tick()
    match_tick()
    fog_tick()
    if unit_changes != alive: spatial_build()
    trace("start")
    sync_map()
    solve_queued()
    move()
    trace("move")
    spatial_build()
    separate()
    trace("separate")
    tick++

var trace_tick = -1

def unit_line(i:int) -> string:
    var s = ""
    for(unit_columns()) col, k:
        if k < UNIT_HASHED:
            if k: s += " "
            s += string(col[i])
    return s

// Every unit's fields at the start of the tick's moves, after them and after separation (export.gd's trace:<tick>).
def trace(what:string):
    if tick != trace_tick: return
    for(u_x.length) i: print "{what} {unit_line(i)}"

// export.gd's state_hash.
def state_hash() -> int:
    var h = FNV_START
    h = mix(h, tick)
    h = mix(h, next_id)
    h = mix(h, next_group)
    for(field_keys) k: h = mix(h, k)
    h = mix(h, -1)
    for(field_queue) k: h = mix(h, k)
    let n = u_x.length
    h = mix(h, n)
    let cols = unit_columns()
    for(n) i:
        for(UNIT_HASHED) k: h = mix(h, cols[k][i])
    let bcols = building_columns()
    h = mix(h, b_id.length)
    for(b_id.length) b:
        for(bcols) col: h = mix(h, col[b])
        h = mix(h, b_queue[b].length)
        for(b_queue[b]) k: h = mix(h, k)
        h = mix(h, b_inside[b].length / REC_SIZE)
        for(b_inside[b]) v: h = mix(h, v)
    for(hero_types) hk, hn: h = mix(mix(h, hero_id[hn]), hero_fell[hn])
    h = mix(h, winner)
    h = mix(h, shots.length / SHOT_STRIDE)
    for(shots) v: h = mix(h, v)
    for(num_players) p:
        h = mix(h, lost[p])
        h = mix(h, pop[p])
        h = mix(h, pop_cap[p])
        h = mix(h, ages[p])
        h = mix(h, defeated[p])
        for(researched[p]) v: h = mix(h, v)
        for(num_resources) r:
            h = mix(h, stock[r][p])
            h = mix(h, gathered[r][p])
    for(resource_cells) c:
        h = mix(h, amount[c])
        h = mix(h, terrain[c])
    return h

def dump_state() -> string:
    var s = "tick {tick} next_id {next_id} next_group {next_group} fields {field_keys} queue {field_queue} shots {shots} lost {lost} stock {stock} gathered {gathered} pop {pop} cap {pop_cap}\n"
    for(u_x.length) i: s += unit_line(i) + "\n"
    for(b_id.length) b:
        s += "b"
        for(building_columns()) col: s += " {col[b]}"
        s += " q {b_queue[b]}\n"
    for(t_hp.length) k:
        var v = [t_hp[k], t_speed[k], t_reach[k], t_reload[k], t_pop[k], t_train_ticks[k], t_carry_add[k], t_build_pct[k], t_shot_speed[k],
                 t_ranged[k], t_sight_add[k]]
        for([t_cost[k], t_atk[k], t_arm[k]]) xs:
            for(xs) x: v.push(x)
        var line = "type {k}"
        for(v) x: line += " {x}"
        s += line + "\n"
    return s

// ------------------------------------------------------------------ the scenario file

def load(path:string):
    let text = assert read_file(path)
    tokens = filter(tokenize(text, " \n", "")): _.length > 0
    expect("AOWSPIKE")
    assert next_int() == 3
    expect("MAP")
    W = next_int()
    H = next_int()
    let lanes = next_int()
    has_heights = next_int()
    for(lanes): walks.push(read_ints(W * H))
    terrain = read_ints(W * H)
    amount = read_ints(W * H)
    pool = read_ints(W * H)
    occupied = read_ints(W * H)
    walk_over = read_ints(W * H)
    cliff = read_ints(W * H)
    ramp = read_ints(W * H)
    level = read_ints(W * H)
    deck = read_ints(W * H)
    high = read_ints(W * H)
    opaque = read_ints(W * H)
    for(read_ints(W * H)) g: assert g == 0   // (no gates)
    resource_cells = read_ints(next_int())
    expect("TERRAIN")
    for(next_int()):
        tr_walk.push(next_int())
        tr_move.push(next_int())
        tr_res.push(next_int())
        tr_amount.push(next_int())
        tr_depleted.push(next_int())
        tr_reseed.push(next_int())
        tr_cleared.push(next_int())
        tr_opaque.push(next_int())
    expect("SPEED")
    for(next_int()): speed_pct.push(read_ints(W * H))
    expect("PLAYERS")
    num_players = next_int()
    num_resources = next_int()
    lane_base = read_ints(num_players)
    teams = read_ints(num_players)
    gather_spots = read_ints(num_resources)
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
    r_high_sight_building = next_int()
    r_fog_every = next_int()
    r_fog_unit = next_int()
    r_fog_worker = next_int()
    r_fog_building = next_int()
    r_carry = next_int()
    r_queue_max = next_int()
    r_pop_max = next_int()
    r_fog_tower = next_int()
    r_garrison_heal_every = next_int()
    r_call_range = next_int()
    garrison_not = read_ints(next_int())
    r_heal_amount = next_int()
    r_heal_reload = next_int()
    r_heal_range = next_int()
    r_heal_sight = next_int()
    heal_not = read_ints(next_int())
    expect("TYPES")
    let nt = next_int()
    num_classes = next_int()
    for(nt):
        let v = read_ints(22)
        for([t_speed, t_radius, t_role, t_gap, t_worker, t_harmless, t_healer, t_ranged, t_reach, t_reload, t_shot_speed,
             t_min_damage, t_sight, t_mclass, t_pop, t_train_ticks, t_hp, t_posture, t_carry_add, t_build_pct, t_player, t_age]) col, k:
            col.push(v[k])
        t_cost.push(read_ints(num_resources))
        t_atk.push(read_ints(num_classes))
        t_arm.push(read_ints(num_classes))
        t_cls.push(read_ints(num_classes))
        t_counters.push(read_ints(next_int()))
    expect("BTYPES")
    let nb = next_int()
    for(num_players):
        bm_hp.push([]::int)
        bm_pop.push([]::int)
        bm_sight.push([]::int)
        bm_food.push([]::int)
        bm_lacks.push([]::int)
        bm_trains.push([]::[int])
        bm_cost.push([]::[int])
    for(nb):
        let v = read_ints(14)
        for([bt_size, bt_build_ticks, bt_pop, bt_sight, bt_age, bt_more_from_age, bt_water, bt_line, bt_tower, bt_farm, bt_land,
             bt_wet, bt_workers, bt_special]) col, k:
            col.push(v[k])
        bt_name.push(tokens[tp])
        tp++
        let a = read_ints(10)
        for([bt_attacks, bt_atk_class, bt_atk, bt_range, bt_reload, bt_arrows, bt_garrison, bt_gate, bt_wall, bt_over_trees]) col, n:
            col.push(a[n])
        bt_cost.push(read_ints(num_resources))
        bt_drop.push(read_ints(num_resources))
        bt_reseed.push(read_ints(num_resources))
        for(num_players) p:
            bm_hp[p].push(next_int())
            bm_pop[p].push(next_int())
            bm_sight[p].push(next_int())
            bm_food[p].push(next_int())
            bm_lacks[p].push(next_int())
            bm_trains[p].push(read_ints(next_int()))
            bm_cost[p].push(read_ints(num_resources))
    load_tech(nt)
    expect("ECON")
    for(num_resources):
        stock.push(map(num_players): 0)
        gathered.push(map(num_players): 0)
    for(num_players) p:
        ages.push(next_int())
        auto_reseed.push(next_int())
        pop.push(next_int())
        pop_cap.push(next_int())
        lost.push(next_int())
        let gt = []::int
        for(num_resources) r:
            stock[r][p] = next_int()
            gathered[r][p] = next_int()
            gt.push(next_int())
        gather_ticks.push(gt)
    expect("TICK")
    tick = next_int()
    next_id = next_int()
    next_group = next_int()
    expect("UNITS")
    let cols = unit_columns()
    for(next_int()):
        let f = read_ints(cols.length)
        for(cols) col, k: col.push(f[k])
    expect("BUILDINGS")
    let bcols = building_columns()
    for(next_int()):
        let f = read_ints(bcols.length)
        for(bcols) col, k: col.push(f[k])
        b_queue.push(read_ints(next_int()))
        b_inside.push([]::int)   // (nobody sheltering at the start: asserted)
    expect("SHOTS")
    shots = read_ints(next_int() * SHOT_STRIDE)
    expect("FOG")
    for(num_players):
        fog.push(read_ints(W * H))
        fog_lit.push(read_ints(next_int()))
    expect("CMDS")
    for(next_int()):
        let v = read_ints(7)
        cmds.push(Cmd { v[0], v[1], v[2], v[3], v[4], v[5], v[6], read_ints(next_int()), 0 })

def read_effect() -> Effect:
    let kind = next_int()
    let stat = next_int()
    let value = next_int()
    let tag = next_int()
    let ands = read_ints(next_int())
    let nots = read_ints(next_int())
    let blds = read_ints(next_int())
    return Effect { kind, stat, value, tag, ands, nots, blds }

def read_effects() -> [Effect]:
    return map(next_int()): read_effect()

// The TECH section (export.gd _write_tech): ages, research, race effects, buildings' base numbers,
// every unit type's line, and what each player has.
def load_tech(nt:int):
    expect("TECH")
    let na = next_int()
    let nr = next_int()
    r_melee_reach = next_int()
    r_melee_reload = next_int()
    r_ranged_reload = next_int()
    r_shot_speed = next_int()
    class_machine = next_int()
    class_mounted = next_int()
    shot_speeds = read_ints(num_classes)
    base_gather_ticks = read_ints(num_resources)
    for(na):
        let age = next_int()
        let building = next_int()
        let ticks = next_int()
        let cost = read_ints(num_resources)
        let needs = map(num_players): read_ints(next_int())
        ages_list.push(Age { age, building, ticks, cost, needs })
    for(nr):
        let id = tokens[tp]
        tp++
        let building = next_int()
        let ticks = next_int()
        let age = next_int()
        let after = next_int()
        let line_age = next_int()
        let cost = read_ints(num_resources)
        let open = []::int
        let line_has = []::int
        let before = []::int
        for(num_players):
            open.push(next_int())
            line_has.push(next_int())
            before.push(next_int())
        research.push(Research { id, building, ticks, age, after, line_age, cost, open, line_has, before, read_effects() })
    for(num_players): race_fx.push(read_effects())
    for(bt_size.length):
        bt_hp_base.push(next_int())
        bt_food_base.push(next_int())
        bt_arm.push(read_ints(num_classes))
    for(nt):
        t_hero.push(next_int())
        let steps = []::LineStep
        for(next_int()):
            let age = next_int()
            let up = next_int()
            let speed = next_int()
            let hp = next_int()
            let pop_ = next_int()
            let train_time = next_int()
            let cost = read_ints(num_resources)
            let damage = next_int()
            let attack = next_int()
            let bonus = read_ints(num_classes)
            let armour = read_ints(num_classes)
            let tags = read_ints(next_int())
            let v = read_ints(12)
            steps.push(LineStep { age, up, speed, hp, pop_, train_time, cost, damage, attack, bonus, armour, tags,
                                  v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11] })
        lines.push(steps)
    expect("RESEARCHED")
    for(num_players):
        next_int()   // (its age: in ECON)
        researched.push(read_ints(nr))
    for(num_players):
        bm_arm.push(map(bt_size.length): []::int)
        for([bm_research_time, bm_age_time, bm_research_cost, bm_range, bm_cost_pct]) col: col.push(map(bt_size.length): 0)
    for([t_heal_pct, t_kill_gold, t_wade, t_slow_on_hit, t_min_range, t_splash, t_pass_len, t_buildings_only, t_unpack, t_pack,
         t_blast, t_blast_line, t_eval_sight, t_sight_add, t_machine, t_mounted, t_damage, t_heal]) col:
        for(nt): col.push(0)
    for(nt): t_tags.push([]::int)
    expect("HEROES")
    let nh = next_int()
    r_aura = next_int()
    r_regen = next_int()
    r_revive = next_int()
    r_revive_pct = next_int()
    for(nh):
        hero_types.push(next_int())
        hero_id.push(next_int())
        hero_fell.push(next_int())
        hero_fx.push(read_effects())
    expect("MATCH")
    winner = next_int()
    started_with_town = read_ints(num_players)
    defeated = read_ints(num_players)

def zeros(n:int) -> [int]: return map(n): 0

// Roomy and tight grids per lane (SimMap.roomy_grid), worked out at the start; refresh keeps them.
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
let n0 = u_x.length
let cells = W * H
for(RING): ring.push([]::int)
sp_start = zeros(cells)
sp_end = zeros(cells)
sp_cursor = zeros(cells)
fresh_at = zeros(cells)
grow_scratch()
make_room()
make_chunks()
for(num_players) p:   // the numbers research and bonuses give, worked out here as the sim does
    retype(p)
    tech_refresh(p)
for(b_id.length) b: assert not bt_special[b_kind[b]]

expect("HASHES")
let ticks = next_int()
let expected = read_ints(ticks)
// Arguments after the file: "bots" (the eco bots play, in Lobster, instead of the orders recorded
// from GDScript's), dump:<tick>, trace:<tick>.
var dump_tick = -1
var bots_mode = false
for(args) a, k:
    if k > 0:
        if a == "bots": bots_mode = true
        let key, val = split_string(a, ":")
        let v, ok = string_to_int(val)
        if key == "dump": dump_tick = v
        if key == "trace": trace_tick = v
next_seq = map(num_players): 0
let bots = map(num_players) p: EcoBot { p }
if bots_mode:
    cmds = []::Cmd
    for(u_kind) k: assert t_player[k] >= 0   // (no animals: the bots' herding and hunting aren't ported)

var spent = 0.0
var first_bad = -1
for(ticks) k:
    let t0 = seconds_elapsed()
    if bots_mode:
        for(bots) bot: bot_think(bot)
    step()
    spent += seconds_elapsed() - t0
    if first_bad < 0 and state_hash() != expected[k]:
        first_bad = k
    if tick == dump_tick:
        write_file(args[0] + ".lobster.dump", dump_state(), 0, 1)
var left = map(num_players): 0
for(u_owner) p: left[p]++
print "{n0} units, {ticks} ticks, {cmds.length} orders; at the end: units {left}, buildings {b_id.length}, gathered {gathered}"
print "lobster step: {spent * 1000.0 / ticks} ms a tick"
if first_bad < 0:
    print "hashes: all {ticks} match"
else:
    print "hashes: first mismatch after tick {tick - ticks + first_bad} (index {first_bad})"
