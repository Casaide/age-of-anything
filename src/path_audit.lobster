// A pathing audit (tests/path_audit.gd, ported): bot vs bot on each map, watching every unit every tick
// for the ways movement goes wrong, and where: give-ups (stuck for STUCK_LIMIT ticks), snaps (moved further
// in a tick than it can walk), jitter (reversing direction many times in a short window while moving),
// treading (moving but going nowhere for a while) and crowding (two of a player's workers overlapping by
// more than a third of their bodies, per pair-tick; "stacked" when both stand). Prints counts per map and
// a few examples each with the cell, the ground round it and what the unit was doing. A diagnostic.
// Gathering scenes on Reed Meadow, player 0 alone at work (no bots), with food gathered:
//   bushes  12 workers sent to one bug bush of the clump by the Town Center, a mill beside it
//   hunt    6 workers on one carcass (1,000 food) south of the Town Center
//   farms   6 workers each building a farm round the Town Center, then farming it
//   reeds   8 workers on the reed bed east of the Town Center (wood, for comparison)
// Run from src:  lobster path_audit.lobster -- [minutes] [map|bushes|hunt|farms|reeds ...] [seeds:7,8,9]
// (8 minutes on flat_test and choke_test by default; seeds: each map once per seed, AUDIT_SEEDS in GDScript)

import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
import lib.steering
import lib.fog
import lib.map
import lib.economy
import lib.tech
import lib.combat
import lib.siege
import lib.eco_bot
import lib.garrison
import lib.heal
import lib.heroes
import lib.match
import lib.trade
import lib.carry
import lib.animals
import lib.bridges
import lib.walls
import lib.abilities
import lib.trails
import lib.commands
import lib.ai_cfg
import lib.scout
import lib.land
import lib.expand
import lib.bot
import lib.walls_ai
import lib.world
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import gen.reset
import testkit.kit

let SEED = 7
let WINDOW = 20  // ticks of history per unit for jitter and treading
let EXAMPLES = 8
let SCENES = [ "bushes", "hunt", "farms", "reeds" ]
let KINDS = [ "give_up", "snap", "jitter", "tread", "moves", "crowd", "stacked" ]
let EXAMPLE_KINDS = [ "give_up", "snap", "jitter", "tread", "crowd" ]
let JOB_KINDS = [ "give_up", "jitter", "tread" ]

let hist = dictionary<int, [int]>(1024)     // id -> x, y, moving for its last WINDOW ticks (flat)
let stuck_seen = dictionary<int, int>(256)  // id -> tick of the last counted give-up
let tread_seen = dictionary<int, int>(256)
let jitter_seen = dictionary<int, int>(256)
var counts = map(KINDS.length): 0
var wcounts = map(KINDS.length): 0  // workers only
var examples = map(EXAMPLE_KINDS.length): []::string
var job_names = map(JOB_KINDS.length): []::string  // per kind: the workers' jobs ("gather food") ...
var job_counts = map(JOB_KINDS.length): []::int    // ... and how often

def count(kind:string, worker:bool):
    let k = find_index(KINDS, kind)
    counts[k]++
    if worker: wcounts[k]++

def task_name(t:int) -> string:
    return if t == T_NONE: "idle" elif t == GATHER: "gather" elif t == T_RETURN: "return" elif t == BUILD: "build" else: string(t)

// Tally a worker's trouble by what it was doing (and with which resource).
def job(i:int, kind:string):
    if not t_worker[u_kind[i]]: return
    var task = if u_task[i] == T_NONE: "idle" elif u_task[i] == GATHER: "gather" elif u_task[i] == T_RETURN: "return" elif u_task[i] == BUILD: "build" else: "other"
    if u_task[i] == GATHER or u_task[i] == T_RETURN:
        task += " " + (if u_carry_kind[i] > 0: resource_names[u_carry_kind[i] - 1] else: "?")
    let k = find_index(JOB_KINDS, kind)
    let at_n = find_index(job_names[k], task)
    if at_n >= 0: job_counts[k][at_n]++
    else:
        job_names[k].push(task)
        job_counts[k].push(1)

def example(kind:string, i:int, what0:string):
    let list = examples[find_index(EXAMPLE_KINDS, kind)]
    if list.length >= EXAMPLES: return
    var what = what0
    let c = cell_of(u_x[i], u_y[i])
    var around = ""
    for([ -1, 0, 1 ]) dy:
        for([ -1, 0, 1 ]) dx:
            around += if cell_walkable(c % W + dx, c / W + dy, u_mclass[i]): "." else: "#"
        around += "/"
    if u_reach[i] == 1:
        let ex = max(max(u_rx0[i] - u_x[i], 0), u_x[i] - u_rx1[i])
        let ey = max(max(u_ry0[i] - u_y[i], 0), u_y[i] - u_ry1[i])
        what += " [rect gap {ex},{ey} reach {u_radius[i] + REACH}]"
    let fi = field_index(u_fkey[i])  // (the cache only: asking field_for would queue a solve)
    let field = if fi >= 0: "dist {field_vals[fi].dist[c]} next {field_vals[fi].next[c]}" else: "no field"
    list.push("{clock(tick)}: {what} (P{u_owner[i]} {unit_name(u_kind[i])}, {task_name(u_task[i])}, foe {u_foe[i]}, group {u_group[i]}) at ({u_x[i]},{u_y[i]}) cell {c} ({c % W},{c / W}) {around}; wp ({u_wx[i]},{u_wy[i]}) target ({u_tx[i]},{u_ty[i]}) reach {u_reach[i]} arrive {u_arrive[i]} stuck {u_stuck[i]}; {field}")

def watch_units():
    for(u_id.length) i:
        let id = u_id[i]
        let wk = t_worker[u_kind[i]] != 0
        let h = hist.get(id, []::int)
        if h.length:
            let n = h.length
            let dx = u_x[i] - h[n - 3]
            let dy = u_y[i] - h[n - 2]
            let s = u_speed[i]
            if dx * dx + dy * dy > (3 * s + 60) * (3 * s + 60):
                count("snap", wk)
                example("snap", i, "jumped {isqrt(dx * dx + dy * dy)} milli-tiles")
            if u_moving[i] == 1: count("moves", wk)
            if u_stuck[i] >= STUCK_LIMIT and u_moving[i] == 0 and tick - stuck_seen.get(id, -1000) > 100:
                stuck_seen.set(id, tick)
                count("give_up", wk)
                job(i, "give_up")
                example("give_up", i, "gave up towards cell {cell_of(u_tx[i], u_ty[i])}")
        h.push(u_x[i])
        h.push(u_y[i])
        h.push(u_moving[i])
        if h.length > WINDOW * 3: h.remove_range(0, 3)
        hist.set(id, h)
        if wk:
            // Crowding: another of the player's workers deep inside this one's body.
            var j = i + 1
            while j < u_id.length:
                if u_owner[j] == u_owner[i] and t_worker[u_kind[j]]:
                    let rr = (u_radius[i] + u_radius[j]) * 2 / 3
                    let ex = u_x[j] - u_x[i]
                    let ey = u_y[j] - u_y[i]
                    if ex * ex + ey * ey < rr * rr:
                        count("crowd", true)
                        if u_moving[i] == 0 and u_moving[j] == 0 and tick > 20:
                            count("stacked", true)
                            example("crowd", i, "stands in worker {u_id[j]} (" + (if u_task[j] == GATHER: "gather" else: string(u_task[j])) + " at ({u_x[j]},{u_y[j]})) by {(u_radius[i] + u_radius[j]) - isqrt(ex * ex + ey * ey)}")
                j++
        var all_moving = h.length == WINDOW * 3
        var k = 0
        while all_moving and k < WINDOW:
            if h[k * 3 + 2] != 1: all_moving = false
            k++
        if all_moving:
            let fx = h[0]
            let fy = h[1]
            let dd = (u_x[i] - fx) * (u_x[i] - fx) + (u_y[i] - fy) * (u_y[i] - fy)
            let s = u_speed[i]
            if dd < s * s * 4 and tick - tread_seen.get(id, -1000) > WINDOW * 3:
                tread_seen.set(id, tick)
                count("tread", wk)
                job(i, "tread")
                example("tread", i, "moving for {WINDOW} ticks, went {isqrt(dd)} milli-tiles")
            var flips = 0
            var q = 2
            while q < WINDOW:
                let ax = h[(q - 1) * 3] - h[(q - 2) * 3]
                let ay = h[(q - 1) * 3 + 1] - h[(q - 2) * 3 + 1]
                let bx = h[q * 3] - h[(q - 1) * 3]
                let by = h[q * 3 + 1] - h[(q - 1) * 3 + 1]
                if ax * bx + ay * by < 0: flips++
                q++
            if flips >= 6 and tick - jitter_seen.get(id, -1000) > WINDOW * 3:
                jitter_seen.set(id, tick)
                count("jitter", wk)
                job(i, "jitter")
                example("jitter", i, "{flips} direction reversals in {WINDOW} ticks")

def workers_of(p:int) -> [int]:
    let out = []::int
    for(u_owner) o, i:
        if o == p and t_worker[u_kind[i]]: out.push(u_id[i])
    return out

// A gathering scene for player 0 on Reed Meadow (its Town Center at 11..13, 11..13; the bug bush clump at
// 17..18, 11..14).
def set_up(scene:string):
    let tc = 0
    let worker = worker_type(0)
    let want = if scene == "bushes": 12 elif scene == "hunt": 6 elif scene == "farms": 6 else: 8
    while workers_of(0).length < want:
        let c = spawn_cell(tc, worker)
        add_unit(0, worker, (c % W) * TILE + 500, (c / W) * TILE + 500)
    grow_scratch()
    let ids = workers_of(0)
    if scene == "bushes":
        let mk = btype_index("mill")
        let mill = place(0, mk, 20, 12)
        b_done[mill] = 1
        b_hp[mill] = bm_hp[0][mk]
        issue_cmd(0, CMD_GATHER, ids, 12 * W + 17, 0, 0, 0)
    elif scene == "reeds":
        issue_cmd(0, CMD_GATHER, ids, 12 * W + 24, 0, 0, 0)
    elif scene == "hunt":
        let cell = 18 * W + 12
        set_terrain(cell, terrain_named("carcass"))
        amount[cell] = 1000
        issue_cmd(0, CMD_GATHER, ids, cell, 0, 0, 0)
    elif scene == "farms":
        let fk = btype_index("farm")
        var n = 0
        for([ int2 { 8, 10 }, int2 { 8, 12 }, int2 { 8, 14 }, int2 { 11, 15 }, int2 { 13, 15 }, int2 { 11, 8 }, int2 { 13, 8 }, int2 { 15, 10 }, int2 { 15, 13 } ]) spot:
            if n < ids.length and can_place(0, fk, spot.x, spot.y):
                issue_cmd(0, CMD_BUILD, [ ids[n] ], fk, spot.x, spot.y, 0)
                n++
        assert n == ids.length
    stock[resource_index("wood")][0] = 5000

def audit(map_id:string, races:[JV], rules:JV, minutes:int, sd:int):
    let scene = find_index(SCENES, map_id) >= 0
    new_world(sd, if scene: "reed_meadow" else: map_id, races, rules, [])
    let sides = if scene: []::Side else: [ full_side(0), full_side(1) ]
    if scene: set_up(map_id)
    hist.clear()
    stuck_seen.clear()
    tread_seen.clear()
    jitter_seen.clear()
    counts = map(KINDS.length): 0
    wcounts = map(KINDS.length): 0
    examples = map(EXAMPLE_KINDS.length): []::string
    job_names = map(JOB_KINDS.length): []::string
    job_counts = map(JOB_KINDS.length): []::int
    let limit = 20 * 60 * minutes
    let t0 = seconds_elapsed()
    while tick < limit and winner < 0:
        think_all(sides)
        wstep()
        watch_units()
    let ms = (seconds_elapsed() - t0) * 1000.0
    def c(kind:string) -> int: return counts[find_index(KINDS, kind)]
    def wc(kind:string) -> int: return wcounts[find_index(KINDS, kind)]
    print "\n== {map_id} (seed {sd}), {clock(tick)} of match, winner {winner}, " + fixed_str(ms / max(tick, 1), 2) + " ms a tick"
    let cs = map(KINDS) kind: c(kind)
    let ws = map(KINDS) kind: wc(kind)
    print "unit-ticks moving {cs[4]}; give-ups {cs[0]}, snaps {cs[1]}, jitter {cs[2]}, treading {cs[3]}, crowding {cs[5]} (stacked {cs[6]})"
    print "  workers: unit-ticks moving {ws[4]}; give-ups {ws[0]}, snaps {ws[1]}, jitter {ws[2]}, treading {ws[3]}"
    for(JOB_KINDS) kind, k:
        let order = map(job_names[k].length) n: n
        insertion_sort(order) x, y: job_names[k][x] < job_names[k][y]
        print "  workers\' {kind} by job: " + concat_string(map(order) n: job_names[k][n] + " " + string(job_counts[k][n]), ", ")
    if scene:
        let food = gathered[resource_index("food")][0]
        let wood = gathered[resource_index("wood")][0]
        print "  gathered by player 0: food {food} ({food * 1200 / max(tick, 1)} a minute), wood {wood} ({wood * 1200 / max(tick, 1)} a minute)"
    for(EXAMPLE_KINDS) kind, k:
        for(examples[k]) e: print "  " + pad_right(kind, 8) + " " + e

let args = plain_args(command_line_arguments())
let seeds_arg = filter(args) a: starts_with(a, "seeds:")
let rest = filter(args) a: not starts_with(a, "seeds:")
let minutes = if rest.length > 0: string_to_int(rest[0]) else: 8
let maps = if rest.length > 1: rest.slice(1, -1) else: [ "flat_test", "choke_test" ]
let seeds = if seeds_arg.length: map(tokenize(seeds_arg[0].substring(6, seeds_arg[0].length - 6), ",", " ")) s: string_to_int(s) else: [ SEED ]
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let races = [ generate("angry swamp frogs with reed spears", rules, 0), generate("centaur romans", rules, 0) ]
let t_all = seconds_elapsed()
for(maps) m:
    for(seeds) sd: audit(m, races, rules, minutes, sd)
print "({int(seconds_elapsed() - t_all)} s)"
