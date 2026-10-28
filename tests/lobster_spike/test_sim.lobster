// The sim's checks (tests/test_sim.gd, ported): determinism and tick time (a scripted 10-minute,
// 200-unit match played again, and with every race's keys reversed and its orders shuffled), movement,
// flow fields, the economy, combat, sieges, walls and the rest, part by part.
// Run from tests/lobster_spike:
//   lobster test_sim.lobster                    every part, one after another
//   lobster test_sim.lobster -- part:<name>[,<name>...]
//   lobster test_sim.lobster -- shard:<i>/<n>   every n-th part from the i-th (0-based): n processes side by side
// Prints "N passed, M failed" and exits 1 on a failure.
//
// Differences from test_sim.gd:
// - The Lobster sim has no SPAWN command: spawn_cmd() queues one and tick_on() runs it at the start of
//   its turn + 2, jittered by the world's rng, as World's SPAWN does; so a part plays tick for tick as
//   in GDScript (the counter fights end the same, unit for unit).
// - The tick-time check takes the best of up to three plays of the match and fails only past the budget
//   (a busy machine slows one play, rarely all three).
// - Dropped: the float-leak checks (a Lobster Cmd holds typed ints: a float can't get in) and the JSON
//   round trip of a replay (a replay here is the list of Cmds, played again: that check stays).
// - source_lint reads lib/*.lobster (the sim and the bots) for randomness, floats and clocks.

import std
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
import gen.setup
import gen.modes
import gen.start
import gen.reset
import gen.save

let SEED = 20261010
let PROMPTS = ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
let TICKS = 12000               // 10 minutes at 20 Hz
let PER_PLAYER = 99             // soldiers a side, shared over its roster slots
let ORDERS_EVERY = 10           // turns between each player's orders (2 s)
let TICK_BUDGET_MS = 3.0
let HASH_EVERY = 30
let CMD_DELAY = 2
let CROSS_UNITS = 10            // per roster slot: 60 units, in 6 groups of 10
let CROSS_ENGINES = 3           // siege engines cross on their own
let CROSS_LIMIT = 2400          // ticks (2 minutes) to get everyone across
let OPENING_TICKS = 3600        // the 3-minute opening
let STALL_TICKS = 100           // a worker idle this long (5 s) has stalled
let SPAWN_JITTER = 400
let POSTURE_NAMES = ["aggressive", "defensive", "stand", "passive"]

// ------------------------------------------------------------------ checks

class SpawnOrder:
    run_tick:int
    player:int
    slot:string
    count:int
    x:int
    y:int

var due = []::SpawnOrder      // SPAWNs issued, waiting for their turn


var checks = 0
var failures = 0

def check(ok:bool, what:string):
    checks++
    if not ok:
        failures++
        print "FAIL: " + what

// ------------------------------------------------------------------ the races and rules (as test_sim.gd's _init)

lib_load("../../data")
id_load("../../data")
let rules0 = load_rules("default")
set(rules0, "animals", jbool(false))   // these tests count and move every unit; animals have their own test
let races0 = map(PROMPTS) p: generate(p, rules0, 0)

def bare_of(r:JV) -> JV:   // movement only: no town centres or starting workers
    let b = deep_copy(r)
    let st = at(at(b, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))
    return b

let bare0 = bare_of(rules0)

// A fresh world (World.new): the old one's globals reset first.
def new_world(map_id:string, races:[JV], rules:JV, team_ids:[int]):
    reset_world()
    due = []
    setup_world(SEED, map_id, races, rules, team_ids)
    events_on = true   // (the checks read them; they aren't state)

// World's SPAWN as it runs: `count` of p's `slot` round (x, y), jittered by the world's rng, onto open ground.
def spawn_now(p:int, slot:string, count:int, x:int, y:int) -> [int]:
    let k = type_of_slot(p, slot)
    assert k >= 0
    let out = []::int
    for(count):
        var sx = x + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
        var sy = y + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
        let ln = lane_base[p] + t_mclass[k]
        if not walkable(sx, sy, ln):
            sx, sy = centre(nearest_walkable(cell_of(sx, sy), ln))
        let i = add_unit(p, k, sx, sy)
        if t_hero[k] and hero_id[hero_slot(k)] == 0: hero_spawned(i)
        out.push(u_id[i])
    grow_scratch()
    return out

// Issue a SPAWN (the Lobster sim has no SPAWN command): it runs at the start of turn + 2, as World's does.
def spawn_cmd(p:int, slot:string, count:int, x:int, y:int):
    due.push(SpawnOrder { (tick / TICKS_PER_TURN + CMD_DELAY) * TICKS_PER_TURN, p, slot, count, x, y })

// A tick: the SPAWNs due now (by player, then as issued), then the world's step.
def tick_on():
    if due.length and tick % TICKS_PER_TURN == 0:
        for(num_players) p:
            for(due) s:
                if s.run_tick == tick and s.player == p: spawn_now(p, s.slot, s.count, s.x, s.y)
        due = filter(due): _.run_tick != tick
    step()

// A SPAWN issued and played until it has run (test_sim.gd's _spawn_n): the new units' ids.
def spawn(p:int, slot:string, count:int, x:int, y:int) -> [int]:
    let before = next_id
    spawn_cmd(p, slot, count, x, y)
    while next_id == before: tick_on()
    return map(next_id - before) n: before + n

def steps(n:int):
    for(n): tick_on()

def ids_of(p:int) -> [int]:
    let out = []::int
    for(u_owner) o, i:
        if o == p: out.push(u_id[i])
    return out

def pos_of(uid:int) -> int, int:
    let i = index_of(uid)
    return u_x[i], u_y[i]

def res_index(name:string) -> int: return find_index(resource_names, name)

def any1(xs:[int]) -> bool: return exists(xs) v: v == 1

def ms_since(t0:float) -> int: return int((seconds_elapsed() - t0) * 1000.0)

def fmt_ms(f:float) -> string:   // three decimals
    let us = int(f * 1000.0 + 0.5)
    let frac = string(us % 1000)
    return string(us / 1000) + "." + "000".substring(0, 3 - frac.length) + frac

// ------------------------------------------------------------------ small pieces

def test_fixed():
    var ok = true
    for(70000) n:
        let r = isqrt(n)
        if r * r > n or (r + 1) * (r + 1) <= n: ok = false
    for([1 << 31, (1 << 40) + 12345, 4000000000, 999999999999]) n:
        let r = isqrt(n)
        ok = ok and r * r <= n and (r + 1) * (r + 1) > n
    check(ok, "isqrt is the exact floor square root")
    var sym = true
    for(256) a:
        sym = sym and sin_a(a) == -sin_a(a + 128) and cos_a(a) == sin_a(a + 64)
        let len2 = sin_a(a) * sin_a(a) + cos_a(a) * cos_a(a)
        sym = sym and abs(len2 - ONE * ONE) < 2 * ONE
    check(sym, "sin/cos table is symmetric and unit length")

def test_command_order():
    new_world("flat_test", races0, bare0, [])
    let all = []::Cmd
    for([2, 0, 1]) player:
        for(4) sq:
            all.push(Cmd { tick, CMD_MOVE, player, 0, 0, 0, 0, [1], sq })
    pending = shuffled(new_rng(5), all)
    let order = map(take_pending()) c: c.player * 10 + c.seq
    check(equal(order, [0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23]), "commands run in (player, seq) order: {order}")
    check(take_pending().length == 0, "commands run once")

// Banned in lib/ (the sim and the bots): randomness but the sim's rng, floats, clocks.
let BANNED = ["rnd(", "rnd_float", "rnd_gaussian", "rnd_seed", "rndm", "float", "seconds_elapsed", "time_",
              "sqrt(", "sin(", "cos(", "atan2(", "pow(", "lerp", "gl."]

def has_decimal(code:string) -> bool:   // a float literal: digits '.' digits
    for(code.length) n:
        if n > 0 and n + 1 < code.length and code[n] == '.' and code[n - 1] >= '0' and code[n - 1] <= '9' and code[n + 1] >= '0' and code[n + 1] <= '9':
            return true
    return false

def ident_char(c:int) -> bool: return c == '_' or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')

def has_word(code:string, w:string) -> bool:   // w in code, not inside a longer name (isqrt isn't sqrt)
    var at_n = 0
    while true:
        let n = find_string(code, w, at_n)
        if n < 0: return false
        if n == 0 or not ident_char(code[n - 1]): return true
        at_n = n + 1
    return false

def test_source_lint():
    var files = 0
    let names = filter(scan_folder("lib", true) or []) f: ends_with(f, ".lobster")
    let sorted_names = sorted_strs(names)
    for(sorted_names) f:
        files++
        let src_lines = tokenize(read_file("lib/" + f) or "", "\n", "")
        for(src_lines) line, n:
            let cut = find_string(line, "//")
            let code = if cut >= 0: substring(line, 0, cut) else: line
            for(BANNED) b:
                if has_word(code, b): check(false, "lib/{f}:{n + 1} uses banned \'{b}\': {line}")
            if has_decimal(code): check(false, "lib/{f}:{n + 1} has a float literal: {line}")
    check(files >= 20, "lint saw the sim and AI sources ({files} files)")

// ------------------------------------------------------------------ flow fields

def test_flow():
    new_world("flat_test", races0, bare0, [])
    let target = start_y[1] / TILE * W + start_x[1] / TILE
    var t0 = seconds_elapsed()
    let a = solve([target], INF, 0)
    let full_ms = (seconds_elapsed() - t0) * 1000.0
    solve([5 * W + 5], INF, 0)
    let b = solve([target], INF, 0)
    check(equal(a.dist, b.dist) and equal(a.next, b.next), "a flow field doesn\'t depend on what was solved before")
    var bad = 0
    for(a.dist) d, c:
        let reachable = d < INF
        if (walks[0][c] == 1) != reachable: bad++
        elif reachable and c != target and a.dist[a.next[c]] >= d: bad++
    check(bad == 0, "every walkable cell reaches the target downhill on flat_test ({bad} bad)")
    t0 = seconds_elapsed()
    let near = solve([target], 160, 0)
    let near_ms = (seconds_elapsed() - t0) * 1000.0
    var far = 0
    for(near.dist) d, c:
        if d < INF and a.dist[c] > 160 + DIAGONAL: far++
    check(far == 0 and near.pops < a.pops / 2, "a near field stops at its cutoff ({near.pops} of {a.pops} cells)")
    print "flow field solve, {W}x{H}: {fmt_ms(full_ms)} ms full, {fmt_ms(near_ms)} ms within 16 tiles"

// ------------------------------------------------------------------ movement: the milestone 2 crossing

def has_crew(u:JV) -> bool: return has(at(u, "recipe"), "crew")

def test_crossing(map_id:string, engines:bool):
    new_world(map_id, races0, bare0, [])
    let sx = start_x[0]
    let sy = start_y[0]
    let dx = start_x[1]
    let dy = start_y[1]
    for(glist(races0[0], "units")) u:   // the foot and horse lines, or (engines) the siege engines on their own
        if has_crew(u) == engines:
            spawn_cmd(0, rstr(at(u, "recipe"), "slot"), if engines: CROSS_ENGINES else: CROSS_UNITS, sx, sy)
    while u_id.length == 0: tick_on()
    let ids = copy(u_id)
    let groups = (ids.length + CROSS_UNITS - 1) / CROSS_UNITS
    for(groups) g:
        issue_cmd(0, CMD_MOVE, ids.slice(g * CROSS_UNITS, min(CROSS_UNITS, ids.length - g * CROSS_UNITS)),
            dx + (g - groups / 2) * 1500, dy + ((g % 2) * 2 - 1) * 1000, 0, 0)
    tick_on()
    var settled = -1
    var worst = 0.0
    let t0 = seconds_elapsed()
    var n = 0
    let t_first = tick
    while tick < t_first + CROSS_LIMIT and settled < 0:
        let s = seconds_elapsed()
        tick_on()
        n++
        worst = max(worst, seconds_elapsed() - s)
        if tick % 20 == 0 and tick > t_first + 40 and not any1(u_moving): settled = tick - t_first
    let avg = (seconds_elapsed() - t0) * 1000.0 / max(1, n)
    steps(200)
    check(not any1(u_moving), "{map_id}: still settled 10 s later (no endless jostling)")
    var gave_up = 0
    var far = 0
    for(u_id.length) i:
        if u_moving[i] == 1: print "  moving: #{u_id[i]} {t_slot[u_kind[i]]} at {u_x[i]},{u_y[i]} target {u_tx[i]},{u_ty[i]} group {u_group[i]} stuck {u_stuck[i]}"
        if u_stuck[i] >= STUCK_LIMIT: gave_up++
        let near = u_arrive[i] * ARRIVE_SETTLE + 1000
        if dist2(u_x[i], u_y[i], u_tx[i], u_ty[i]) > near * near:
            far++
            print "  far: #{u_id[i]} {t_slot[u_kind[i]]} at {u_x[i]},{u_y[i]} target {u_tx[i]},{u_ty[i]} arrive {u_arrive[i]} group {u_group[i]} stuck {u_stuck[i]}"
    check(settled > 0, "{map_id}: all {ids.length} units settle within {CROSS_LIMIT} ticks")
    check(gave_up == 0, "{map_id}: nobody gives up stuck ({gave_up} did)")
    check(far == 0, "{map_id}: everyone ends near their own target ({far} far)")
    print "{map_id} crossing{if engines: " (engines)" else: ""}: {ids.length} units settled at tick {settled} ({settled / 20} s), avg tick {fmt_ms(avg)} ms, worst {fmt_ms(worst * 1000.0)} ms"

// ------------------------------------------------------------------ the scripted match

class Script:
    orders:[Cmd]          // in run order: (run tick, player, seq)
    spawns:[SpawnOrder]

def resource_kind_at(c:int) -> string:
    let r = tr_res[terrain[c]]
    return if r > 0: resource_names[r - 1] else: ""

// The resource cell of a kind nearest a point (ties: lower cell).
def nearest_res(x:int, y:int, kind:string) -> int:
    var best = -1
    var best_d2 = 1 << 62
    for(resource_cells) c:
        if resource_kind_at(c) == kind:
            let cx, cy = centre(c)
            let d2 = dist2(x, y, cx, cy)
            if d2 < best_d2:
                best_d2 = d2
                best = c
    return best

// A free 2x2 spot (with a tile of space around it) near a start, spiralling out.
def house_spot(x:int, y:int) -> int, int:
    let cx = x / TILE
    let cy = y / TILE
    for(8) r0:
        let r = r0 + 4
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                if max(abs(dx), abs(dy)) == r and can_build(cx + dx - 1, cy + dy - 1, 4, 0, false, false): return cx + dx, cy + dy
                dx++
            dy++
    return -1, -1

def walkable_point(r:Rng) -> int, int:
    while true:
        let x = range_int(r, 1000, W * 1000 - 1000)
        let y = range_int(r, 1000, H * 1000 - 1000)
        if walkable(x, y, 0): return x, y
    return 0, 0

// Every order of the match, stamped in advance (needs a world set up on the map, for its cells). Ids:
// the setup gives each player a Town Center then its starting workers (player 0 first), and the
// armies spawn in player order after that.
def make_script(races:[JV]) -> Script:
    let r = new_rng(SEED ^ 0x5C51)
    let out = []::Cmd
    let spawns = []::SpawnOrder
    let sq = [0, 0]
    let start = at(at(rules0, "economy"), "start")
    let setup_ids = glist(start, "buildings").length + as_int(at(start, "workers"))
    let nslots = glist(races[0], "units").length
    let per_slot = PER_PLAYER / nslots
    let per_player = per_slot * nslots
    let army_first = 1 + races.length * setup_ids
    def cmd(turn:int, p:int, code:int, ids:[int], a:int, b:int, c:int, d:int):
        out.push(Cmd { (turn + CMD_DELAY) * TICKS_PER_TURN, code, p, a, b, c, d, ids, sq[p] })
        sq[p]++
    let house = btype_index("house")
    for(races.length) p:   // the economy: two workers on food, one on wood, two more trained, a house
        let tc = 1 + p * setup_ids
        let food_cell = nearest_res(start_x[p], start_y[p], "food")
        let wood_cell = nearest_res(start_x[p], start_y[p], "wood")
        cmd(0, p, CMD_GATHER, [tc + 1, tc + 2], food_cell, 0, 0, 0)
        cmd(0, p, CMD_GATHER, [tc + 3], wood_cell, 0, 0, 0)
        cmd(0, p, CMD_RALLY, [], tc, (food_cell % W) * 1000 + 500, (food_cell / W) * 1000 + 500, 0)
        let wk = type_of_slot(p, "worker")
        cmd(0, p, CMD_TRAIN, [], tc, wk, 1, 0)
        cmd(0, p, CMD_TRAIN, [], tc, wk, 1, 0)
        let hx, hy = house_spot(start_x[p], start_y[p])
        cmd(60, p, CMD_BUILD, [tc + 3], house, hx, hy, 0)
    for(races.length) p:   // the armies arrive at 30 s, then march about
        for(glist(races[p], "units")) u:
            spawns.push(SpawnOrder { (150 + CMD_DELAY) * TICKS_PER_TURN, p, rstr(at(u, "recipe"), "slot"), per_slot, start_x[p], start_y[p] })
            sq[p]++
    for(races.length) p:   // a quarter of each army on each stance, so replays and hashes cover them
        let first = army_first + p * per_player
        for(3) k0:
            let k = k0 + 1
            let ids = filter(per_player) n: (first + n) % 4 == k
            cmd(151, p, CMD_STANCE, map(ids) n: first + n, k, 0, 0, 0)
    var turn = 150 + ORDERS_EVERY
    while turn < TICKS / TICKS_PER_TURN - CMD_DELAY:
        for(races.length) p:
            let first = army_first + p * per_player
            let mode = range_int(r, 0, 3)
            let ids = []::int
            for(per_player) n:
                if mode == 0 or (first + n) % 4 == mode: ids.push(first + n)
            let x, y = walkable_point(r)
            cmd(turn, p, CMD_MOVE, ids, x, y, 0, 0)
        turn += ORDERS_EVERY
    return Script { out, spawns }

def order_key(c:Cmd) -> int: return (c.run_tick << 40) | (c.player << 32) | c.seq

// Insertion sort by run tick, player, seq (the queue's order; qsort's recursion overflows on long near-sorted lists).
def run_order(cs:[Cmd]) -> [Cmd]:
    let out = copy(cs)
    var i = 1
    while i < out.length:
        let c = out[i]
        let key = order_key(c)
        var j = i - 1
        while j >= 0 and order_key(out[j]) > key:
            out[j + 1] = out[j]
            j--
        out[j + 1] = c
        i++
    return out

class Played:
    hashes:[int]          // tick, hash pairs, flattened, every HASH_EVERY ticks
    ms:[float]            // per tick
    units:int

// Play the script on a fresh world (`cs`: its orders as queued, maybe shuffled).
def play_match(races:[JV], cs:[Cmd], spawns:[SpawnOrder]) -> Played:
    new_world("flat_test", races, rules0, [])
    cmds = run_order(cs)
    next_cmd = 0
    let hashes = []::int
    let ms = []::float
    var next_spawn = 0
    for(TICKS):
        while next_spawn < spawns.length and spawns[next_spawn].run_tick == tick:
            let s = spawns[next_spawn]
            spawn_now(s.player, s.slot, s.count, s.x, s.y)
            next_spawn++
        let t0 = seconds_elapsed()
        tick_on()
        ms.push((seconds_elapsed() - t0) * 1000.0)
        if tick % HASH_EVERY == 0:
            hashes.push(tick)
            hashes.push(state_hash())
    return Played { hashes, ms, u_id.length }

def same_hashes(a:[int], b:[int], what:string):
    let n = min(a.length, b.length)
    var differs = -1
    var k = 0
    while k < n:
        if a[k] != b[k] or a[k + 1] != b[k + 1]:
            differs = a[k]
            break
        k += 2
    check(differs < 0 and n == a.length and n == b.length, "{what}: same hashes, same number of checkpoints (first differs at tick {differs}; {a.length / 2} and {b.length / 2} checkpoints)")
    if differs < 0: print "{what}: {n / 2} checkpoints match" else: print "{what}: hash differs at tick {differs}"

// Sanity: the script actually moves things, so matching hashes mean something.
def test_moved(pl:Played):
    let distinct = dictionary<int, int>(1024)
    var k = 1
    while k < pl.hashes.length:
        distinct.set(pl.hashes[k], 1)
        k += 2
    let nh = pl.hashes.length / 2
    check(distinct.get_keys().length > nh * 9 / 10, "state keeps changing ({distinct.get_keys().length} distinct hashes)")
    let start = at(at(rules0, "economy"), "start")
    let lost_n = lost[0] + lost[1]
    let nslots = glist(races0[0], "units").length
    check(u_id.length + lost_n == 2 * (nslots * (PER_PLAYER / nslots) + as_int(at(start, "workers")) + 2), "armies, starting workers and 2 trained each, alive or lost ({u_id.length} alive, {lost_n} lost)")
    check(lost_n > 0, "the armies fought ({lost_n} lost)")
    var built = 0
    for(b_done) d: built += d
    check(built == 4, "both Town Centers and both houses stand ({built} built)")
    let food0 = as_int(at(start, "food"))
    check(stock[0][0] > food0 and stock[0][1] > food0, "both sides gathered food ({stock[0][0]}, {stock[0][1]})")
    check(map_version > 0, "the map changed during the match (houses, cut reeds): version {map_version}")

def timing_line(pl:Played) -> float:
    let s = copy(pl.ms)
    insertion_sort_f(s)
    var total = 0.0
    for(s) v: total += v
    let avg = total / s.length
    print "tick time, {pl.units} units over {s.length} ticks: avg {fmt_ms(avg)} ms, p50 {fmt_ms(s[s.length / 2])}, p99 {fmt_ms(s[s.length * 99 / 100])}, max {fmt_ms(s[s.length - 1])}"
    return avg

def insertion_sort_f(s:[float]):   // (qsort recursion overflows on 12,000 near-equal times)
    // a counting pass would do; times are small, so a shell sort is plenty
    var gap = s.length / 2
    while gap > 0:
        var i = gap
        while i < s.length:
            let v = s[i]
            var j = i
            while j >= gap and s[j - gap] > v:
                s[j] = s[j - gap]
                j -= gap
            s[j] = v
            i++
        gap /= 2

var match_hashes = []::int    // the first play's, for match_b and match_flipped run in the same process

def first_match() -> [int]:
    if not match_hashes.length:
        new_world("flat_test", races0, rules0, [])
        let sc = make_script(races0)
        match_hashes = play_match(races0, sc.orders, sc.spawns).hashes
    return match_hashes

// The scripted 10-minute, 200-unit match: checkpoints, it moved, a replay of its orders plays back
// the same and one nudged by a milli-tile doesn't; the tick time.
def test_match():
    new_world("flat_test", races0, rules0, [])
    let sc = make_script(races0)
    print "script: {sc.orders.length + sc.spawns.length} commands over {TICKS} ticks"
    let a = play_match(races0, sc.orders, sc.spawns)
    match_hashes = a.hashes
    check(a.hashes.length / 2 == TICKS / HASH_EVERY, "a checkpoint every {HASH_EVERY} ticks")
    check(next_cmd == cmds.length, "every scripted command ran ({next_cmd} of {cmds.length})")
    test_moved(a)
    var best = timing_line(a)
    // A replay: the same orders on a fresh world play back hash-identical; a one milli-tile nudge is caught.
    let again = play_match(races0, sc.orders, sc.spawns)
    check(equal(again.hashes, a.hashes), "a replay of the orders plays back hash-identical")
    best = min(best, timing_line(again))
    let tampered = map(sc.orders) c: c
    for(tampered) c, n:
        if c.code == CMD_MOVE:
            let t = Cmd { c.run_tick, c.code, c.player, c.a + 1, c.b, c.c, c.d, c.ids, c.seq }
            tampered[n] = t
            break
    let nudged = play_match(races0, tampered, sc.spawns)
    check(not equal(nudged.hashes, a.hashes), "a one milli-tile change in a replay is caught")
    // The tick time: the best of the plays (a third if the first two were slow), failing only past the budget.
    if best > TICK_BUDGET_MS: best = min(best, timing_line(play_match(races0, sc.orders, sc.spawns)))
    print "tick time: best average {fmt_ms(best)} ms (budget {fmt_ms(TICK_BUDGET_MS)} ms)"
    check(best <= TICK_BUDGET_MS, "average tick within {fmt_ms(TICK_BUDGET_MS)} ms (best of the plays: {fmt_ms(best)})")

// The same match again: the same hashes as the first run's.
def test_match_b():
    let first = first_match()
    new_world("flat_test", races0, rules0, [])
    let sc = make_script(races0)
    same_hashes(first, play_match(races0, sc.orders, sc.spawns).hashes, "second run")

// Deep copy with every object's keys in reverse order.
def reversed_jv(v:JV) -> JV:
    if v.kind == J_OBJ:
        let o = jobj()
        var n = v.keys.length - 1
        while n >= 0:
            set(o, v.keys[n], reversed_jv(v.a[n]))
            n--
        return o
    if v.kind == J_ARR: return jarr(map(v.a) x: reversed_jv(x))
    return v

// Key-order leaks: every race rebuilt with its keys reversed, stats re-priced from the reversed
// recipes, the orders queued shuffled.
def test_match_flipped():
    let first = first_match()
    let flipped = []::JV
    for(races0) r:
        let fr = reversed_jv(r)
        let units = glist(fr, "units")
        for(units) u, n:
            let orig = glist(r, "units")[n]
            let e = evaluate(at(u, "recipe"), rules0, as_int(at(glist(orig, "line")[0], "age")))
            check(jequal(e, at(orig, "eval")), "pricing ignores key order ({rstr(at(orig, "recipe"), "name")})")
            set(u, "eval", e)
        flipped.push(fr)
    new_world("flat_test", races0, rules0, [])
    let sc = make_script(races0)
    same_hashes(first, play_match(flipped, shuffled(new_rng(99), sc.orders), sc.spawns).hashes, "reversed dicts + shuffled commands")

// ------------------------------------------------------------------ economy: the milestone 3 opening

def count_workers(p:int) -> int:
    var n = 0
    for(u_owner) o, i:
        if o == p and t_worker[u_kind[i]] != 0: n++
    return n

def count_houses(p:int) -> int:
    let house = btype_index("house")
    var n = 0
    for(b_owner) o, b:
        if o == p and b_kind[b] == house and b_done[b] == 1: n++
    return n

def race_name(p:int) -> string: return rstr(su_races[p], "name")

def test_opening():
    new_world("flat_test", races0, rules0, [])
    let bots = map(2) p: EcoBot { p }
    let idle_since = dictionary<int, int>(64)
    var stalls = 0
    var over_cap = 0
    let t0 = seconds_elapsed()
    var worst = 0.0
    while tick < OPENING_TICKS:
        for(bots) bot: bot_think(bot)
        let s = seconds_elapsed()
        tick_on()
        worst = max(worst, seconds_elapsed() - s)
        for(2) p:
            if pop[p] > pop_cap[p]: over_cap++
        for(u_id) uid, i:
            if u_task[i] == T_NONE and u_moving[i] == 0:
                let since = idle_since.get(uid, -1)
                if since < 0: idle_since.set(uid, tick)
                elif tick - since == STALL_TICKS: stalls++
            else:
                idle_since.del(uid)
        if tick % 1200 == 0:
            for(2) p:
                print "  opening {tick / 1200}:00  {race_name(p)}  workers {count_workers(p)}  pop {pop[p]}/{pop_cap[p]}  houses {count_houses(p)}  gathered {gathered[0][p]} food {gathered[1][p]} wood  bank {stock[0][p]}/{stock[1][p]}"
    var gave_up = 0
    for(u_id.length) i:
        if u_stuck[i] >= STUCK_LIMIT and u_task[i] != T_NONE: gave_up++
    check(stalls == 0, "opening: no worker sits idle for 5 s ({stalls} stalls)")
    check(over_cap == 0, "opening: pop never goes over the cap")
    check(gave_up == 0, "opening: no worker is stuck on a job ({gave_up})")
    for(2) p:
        let total = gathered[0][p] + gathered[1][p]
        check(total >= 600 and total <= 3000, "opening: {race_name(p)} gathers a sensible amount in 3 min ({total})")
        check(count_houses(p) >= 2, "opening: {race_name(p)} builds houses ({count_houses(p)})")
    check(count_workers(1) > count_workers(0), "opening: rats (cheap, quick to train) out-breed frogs ({count_workers(1)} vs {count_workers(0)})")
    check(pop_cap[1] - 5 == 6 * count_houses(1), "opening: rat houses give 6 pop")
    print "opening: avg tick {fmt_ms((seconds_elapsed() - t0) * 1000.0 / OPENING_TICKS)} ms, worst {fmt_ms(worst * 1000.0)} ms"

// ------------------------------------------------------------------ combat

let FIGHT_BUDGET = 600          // food + wood per side
let FIGHT_LIMIT = 3000          // ticks (2.5 minutes)
let FIGHT_FROM_X = [11000, 21000]   // open ground on flat_test, 10 tiles apart
let FIGHT_FROM_Y = [20500, 20500]
// Counter fights: [counter, countered, the tag the countered unit needs for this to be the counter].
let COUNTERS = [["spear", "large", "large"], ["large", "archer", "ranged"], ["archer", "spear", "infantry"], ["skirmisher", "archer", "archer"],
    ["infantry", "spear", "spear"], ["archer", "infantry", "infantry"]]
let COUNTER_PROMPTS = ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
    "greek hoplites", "royal knights", "viking beetle riders"]

def gen_race(prompt:string) -> JV: return generate(prompt, rules0, 0)

def bare_world(races:[JV]): new_world("flat_test", races, bare0, [])

def posture_of(name:string) -> int: return find_index(POSTURE_NAMES, name)

def stance(p:int, ids:[int], name:string): issue_cmd(p, CMD_STANCE, ids, posture_of(name), 0, 0, 0)

// One unit of `slot` for p at (x, y) with a stance, settled in (test_sim.gd's _lone).
def lone(p:int, slot:string, x:int, y:int, name:string) -> int:
    let uid = spawn(p, slot, 1, x, y)[0]
    stance(p, [uid], name)
    steps(TICKS_PER_TURN * (CMD_DELAY + 1))
    return uid

def spawn_at(p:int, slot:string, x:int, y:int) -> int: return spawn(p, slot, 1, x, y)[0]

class Watch:
    far:int
    hits:[int]

// Steps the world, tracking how far unit `id` strays from (x, y) and the hits each side lands.
def watch_from(n:int, uid:int, x:int, y:int) -> Watch:
    let r = Watch { 0, [0, 0] }
    for(n):
        tick_on()
        let i = index_of(uid)
        if i >= 0: r.far = max(r.far, isqrt(dist2(u_x[i], u_y[i], x, y)))
        for(events) e:
            if e.kind == EV_HIT:
                let by = index_of(e.a)
                if by >= 0 and u_owner[by] < 2: r.hits[u_owner[by]]++
    return r

def watch(n:int, uid:int) -> Watch:
    let x, y = pos_of(uid)
    return watch_from(n, uid, x, y)

def unit_of(race:JV, slot:string) -> JV:
    for(glist(race, "units")) u:
        if rstr(at(u, "recipe"), "slot") == slot: return u
    assert false
    return jobj()

def eval_has_tag(e:JV, tag:string) -> bool: return has_str(glist(e, "tags"), tag)

def type_has_tag(k:int, tag:string) -> bool: return eval_has_tag(su_type_eval[k], tag)

// Healers: one heals a wounded friend in range to full, walks to one further off, never heals an
// enemy, and never fights, not even when told to or when struck.
def test_heal():
    let race = gen_race("romans")
    bare_world([race, race])
    let healer = spawn_at(0, "healer", 15000, 20500)
    let near = spawn_at(0, "spear", 17000, 20500)
    let far = spawn_at(0, "spear", 15000, 25500)   // 5 tiles off: within sight, out of range
    let foe = spawn_at(1, "spear", 13500, 21500)
    stance(0, [near, far], "passive")
    stance(1, [foe], "passive")
    let hi = index_of(healer)
    check(u_posture[hi] == PASSIVE, "heal: a healer spawns with the no-attack stance")
    check(as_int(at(su_type_eval[u_kind[hi]], "attack")) == 0, "heal: a healer has no attack")
    issue_cmd(0, CMD_ATTACK, [healer], foe, 0, 0, 0)
    steps(8)
    let full = t_hp[u_kind[index_of(near)]]
    for([near, far, foe]) uid: u_hp[index_of(uid)] = 4
    var heals = 0
    let healed = []::int
    var healer_hits = 0
    var fought = false
    var near_full_at = -1
    for(2400) t:
        tick_on()
        for(events) e:
            if e.kind == EV_HEAL:
                heals++
                healed.push(e.b)
            elif e.kind == EV_HIT and e.a == healer: healer_hits++
        fought = fought or u_foe[index_of(healer)] != 0
        if near_full_at < 0 and u_hp[index_of(near)] == full: near_full_at = t
    check(near_full_at > 0, "heal: the wounded friend in range is healed to full (tick {near_full_at}, {heals} heals)")
    check(u_hp[index_of(far)] == full, "heal: a wounded friend 5 tiles off is walked to and healed ({u_hp[index_of(far)]}/{full} hp)")
    check(u_hp[index_of(foe)] == 4 and not contains(healed, foe), "heal: never an enemy ({u_hp[index_of(foe)]} hp)")
    check(not contains(healed, healer), "heal: not itself")
    check(healer_hits == 0 and not fought, "heal: told to attack, it doesn\'t ({healer_hits} hits)")
    let per_heal = r_heal_amount
    check(heals <= (full - 4) * 2 / per_heal + 2, "heal: {per_heal} hp a heal, no more heals than the wounds need ({heals})")
    // Struck by an aggressive enemy, it doesn't strike back (and heals nobody who isn't hurt).
    bare_world([race, race])
    let h2 = spawn_at(0, "healer", 15000, 20500)
    stance(0, [h2], "aggressive")
    let attacker = spawn_at(1, "spear", 16500, 20500)
    var hits_back = 0
    var heals2 = 0
    for(600):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == h2: hits_back++
            elif e.kind == EV_HEAL: heals2++
    check(index_of(h2) < 0, "heal: an enemy spearman kills a lone healer")
    check(hits_back == 0 and heals2 == 0, "heal: even on aggressive it never fights back ({hits_back} hits), and heals no one unhurt or itself ({heals2})")
    let ai = index_of(attacker)
    check(ai >= 0 and u_hp[ai] == t_hp[u_kind[ai]], "heal: the attacker is untouched and unhealed")

// The formula: base type, bonuses only against targets with the tag, class armour, the minimum.
def test_damage():
    // classes: melee, pierce, building, large
    let atk = [5, 0, 0, 7]    // a spear: 5 melee, +7 vs large
    let arm = [2, 4, 0, 0]
    let plain = [1, 1, 0, 0]
    let large = [1, 1, 0, 1]
    check(damage(atk, arm, plain, 1) == 3, "melee 5 - armour 2 = 3")
    check(damage(atk, arm, large, 1) == 10, "the large bonus only lands on large targets (3 + 7)")
    check(damage(atk, [2, 4, 0, 3], large, 1) == 7, "class armour blunts a bonus (3 + 7 - 3)")
    check(damage([0, 4, 0, 0], [0, 9, 0, 0], plain, 1) == 1, "never less than the minimum")
    check(damage([0, 6, 0, 0], [9, 0, 0, 0], plain, 1) == 6, "pierce ignores melee armour")

// Idle soldiers near enemies fight without being told to.
def test_idle_fight():
    let race = gen_race(PROMPTS[0])
    bare_world([race, race])
    spawn_cmd(0, "spear", 5, 15000, 20500)
    spawn_cmd(1, "spear", 5, 18000, 20500)
    steps(1200)
    check(lost[0] + lost[1] > 0, "idle spearmen 3 tiles apart fight on their own ({lost[0] + lost[1]} lost)")

// Attack-move spreads out: 10 spearmen against 10 make many duels, not a pile-on.
def test_spread():
    let race = gen_race(PROMPTS[0])
    bare_world([race, race])
    for(2) p: spawn_cmd(p, "spear", 10, FIGHT_FROM_X[p], FIGHT_FROM_Y[p])
    while u_id.length < 20: tick_on()
    for(2) p: issue_cmd(p, CMD_ATTACK_MOVE, ids_of(p), FIGHT_FROM_X[1 - p], FIGHT_FROM_Y[1 - p], 0, 0)
    var most = 0
    for(600):
        tick_on()
        let foes = []::int
        for(u_id.length) i:
            if u_owner[i] == 0 and u_foe[i] != 0 and not contains(foes, u_foe[i]): foes.push(u_foe[i])
        most = max(most, foes.length)
    check(most >= 7, "attack-move spreads: up to {most} different foes fought at once by 10 spearmen")

// Two teams of two: allies stand side by side in peace; the teams fight each other.
def test_teams():
    let race = gen_race(PROMPTS[0])
    new_world("flat_test", [race, race, race, race], bare0, [0, 0, 1, 1])
    check(not is_enemy(0, 1) and is_enemy(1, 2) and not is_enemy(2, 3), "teams: 0+1 vs 2+3")
    spawn_cmd(0, "spear", 4, 14000, 20500)
    spawn_cmd(1, "spear", 4, 14500, 21000)
    steps(600)
    check(lost[0] + lost[1] == 0, "teams: allies side by side never fight")
    spawn_cmd(2, "spear", 4, 17500, 20500)
    spawn_cmd(3, "spear", 4, 18000, 21000)
    steps(1500)
    check(lost[0] + lost[1] + lost[2] + lost[3] > 0, "teams: the two teams fight ({lost} lost)")

// A dozen large units knock down a Town Center; its footprint is free again.
def test_siege_tc():
    let race = gen_race(PROMPTS[0])
    new_world("flat_test", [race, race], rules0, [])
    let tc = b_id[1]
    let cells = footprint(1)
    spawn_cmd(0, "large", 12, start_x[1] - 4000, start_y[1])
    while u_id.length < 2 * as_int(at(at(at(rules0, "economy"), "start"), "workers")) + 12: tick_on()
    let mine = filter(ids_of(0)) uid: t_worker[u_kind[index_of(uid)]] == 0
    issue_cmd(0, CMD_ATTACK, mine, tc, 0, 0, 0)
    var hits = 0
    while tick < 6000 and b_index_of(tc) >= 0:
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.b == tc: hits++
    check(b_index_of(tc) < 0, "a dozen large units knock down a Town Center ({hits} hits by tick {tick})")
    check(cells.length > 0 and not exists(cells) c: occupied[c] != 0, "its footprint is free again")

// Twenty melee units on a Town Center: they spread round its walls, most of them strike within
// half a minute, from every side, and nobody hitting it is shoved about.
def test_surround():
    let race = gen_race(PROMPTS[0])
    let r = deep_copy(rules0)
    set(at(at(r, "economy"), "start"), "workers", jint(0))
    new_world("flat_test", [race, race], r, [])
    let b = 1
    let tc = b_id[b]
    let ids = spawn(0, "spear", 20, b_cx[b] * 1000 - 5000, b_cy[b] * 1000 - 5000)
    issue_cmd(0, CMD_ATTACK, ids, tc, 0, 0, 0)
    let struck = []::int
    var shoved = 0
    let sides = []::int
    let mx = b_cx[b] * 1000 + b_sx[b] * 500
    let my = b_cy[b] * 1000 + b_sy[b] * 500
    let t_start = tick
    while tick < t_start + 600 and b_index_of(tc) >= 0:
        let held = []::int   // id, x, y
        let bi = b_index_of(tc)
        for(u_id.length) i:
            if u_foe[i] == tc and u_moving[i] == 0 and gap_b(i, bi) <= r_melee_reach:
                held.push(u_id[i])
                held.push(u_x[i])
                held.push(u_y[i])
        tick_on()
        var k = 0
        while k < held.length:
            let i = index_of(held[k])
            if i >= 0: shoved = max(shoved, abs(u_x[i] - held[k + 1]) + abs(u_y[i] - held[k + 2]))
            k += 3
        for(events) e:
            if e.kind == EV_HIT and e.b == tc and not contains(struck, e.a):
                struck.push(e.a)
                let i = index_of(e.a)
                let dx = u_x[i] - mx
                let dy = u_y[i] - my
                let side = if abs(dx) > abs(dy): (if dx > 0: 0 else: 1) else: (if dy > 0: 2 else: 3)
                if not contains(sides, side): sides.push(side)
    check(struck.length >= 15, "surround: {struck.length} of 20 melee units strike a Town Center within 30 s")
    check(sides.length == 4, "surround: they hit it from all sides ({sides.length})")
    check(shoved <= 10, "surround: a unit hitting the wall isn\'t shoved (most in a tick {shoved} milli-tiles)")

def overlapping_pairs() -> int:
    var n = 0
    for(u_id.length) i:
        var j = i + 1
        while j < u_id.length:
            let rr = u_radius[i] + u_radius[j]
            if dist2(u_x[i], u_y[i], u_x[j], u_y[j]) < rr * rr * 81 / 100: n++
            j++
    return n

def no_orders() -> bool: return not exists(u_orders) o: o.length > 0

// A group move ends in a formation: every unit in a slot of its own, nobody overlaps, the archers
// behind the spearmen, arrivals not shoved about, and it holds still. Attack-move and a shift-queued move too.
def test_formation():
    let race = gen_race(PROMPTS[0])
    for(["move", "attack_move", "queued"]) kind:
        bare_world([race, race])
        let spears = spawn(0, "spear", 20, 12000, 14000)
        let archers = spawn(0, "archer", 10, 12000, 16000)
        let ids = spears.append(archers)
        if kind == "queued":
            issue_cmd(0, CMD_MOVE, ids, 30000, 22000, 0, 0)
            issue_cmd(0, CMD_MOVE, ids, 40000, 40000, 0, 0, 1)
        else:
            issue_cmd(0, if kind == "move": CMD_MOVE else: CMD_ATTACK_MOVE, ids, 40000, 40000, 0, 0)
        var shoved = 0
        var settled = -1
        while tick < 4000 and settled < 0:
            let qx = copy(u_x)
            let qy = copy(u_y)
            let qm = copy(u_moving)
            tick_on()
            for(u_id.length) i:
                if qm[i] == 0 and u_moving[i] == 0 and tick > 60: shoved += abs(u_x[i] - qx[i]) + abs(u_y[i] - qy[i])
            if tick % 20 == 0 and tick > 200 and not any1(u_moving) and no_orders(): settled = tick
        let what = "formation ({kind})"
        check(settled > 0, "{what}: settles (tick {settled})")
        let x0 = copy(u_x)
        let y0 = copy(u_y)
        steps(200)
        var still = true
        var off_slot = 0
        let slots = []::int
        var front = 1 << 30
        var back = -(1 << 30)
        for(u_id.length) i:
            still = still and u_x[i] == x0[i] and u_y[i] == y0[i]
            let key = u_tx[i] * 1000000 + u_ty[i]
            if not contains(slots, key): slots.push(key)
            if dist2(u_x[i], u_y[i], u_tx[i], u_ty[i]) > 400 * 400: off_slot++
            let ahead = u_x[i] + u_y[i]   // along the way they went: down and right
            if contains(archers, u_id[i]): back = max(back, ahead)
            else: front = min(front, ahead)
        let overlaps = overlapping_pairs()
        check(slots.length == ids.length, "{what}: {slots.length} slots for {ids.length} units")
        check(off_slot <= 2, "{what}: everyone stands in its slot ({off_slot} off)")
        check(overlaps == 0, "{what}: no one overlaps ({overlaps} pairs)")
        check(back < front, "{what}: the archers stand behind the spearmen")
        check(shoved < 2000, "{what}: arrivals aren\'t shoved about ({shoved} milli-tiles in all)")
        check(still, "{what}: it holds still afterwards")

def ahead_of(uid:int) -> int:
    let i = index_of(uid)
    return u_tx[i] + u_ty[i]

def across_of(uid:int) -> int:
    let i = index_of(uid)
    return u_tx[i] - u_ty[i]

def lo_ahead(ids:[int]) -> int:
    var v = 1 << 40
    for(ids) uid: v = min(v, ahead_of(uid))
    return v

def hi_ahead(ids:[int]) -> int:
    var v = -(1 << 40)
    for(ids) uid: v = max(v, ahead_of(uid))
    return v

def lo_across(ids:[int]) -> int:
    var v = 1 << 40
    for(ids) uid: v = min(v, across_of(uid))
    return v

def hi_across(ids:[int]) -> int:
    var v = -(1 << 40)
    for(ids) uid: v = max(v, across_of(uid))
    return v

// A mixed group's formation goes by role: foot in front, shooters behind, healers at the back,
// riders on both flanks; it settles without overlaps and holds still.
def test_role_formation():
    let race = gen_race("romans")
    bare_world([race, race])
    let spears = spawn(0, "spear", 12, 12000, 14000)
    let archers = spawn(0, "archer", 8, 12000, 16000)
    let riders = spawn(0, "large", 6, 14000, 15000)
    let healers = spawn(0, "healer", 2, 11000, 15000)
    check(not exists(riders) uid: not type_has_tag(u_kind[index_of(uid)], "mounted"), "role formation: the large slot rides")
    let ids = spears.append(archers).append(riders).append(healers)
    issue_cmd(0, CMD_MOVE, ids, 40000, 40000, 0, 0)
    var settled = -1
    while tick < 4000 and settled < 0:
        tick_on()
        if tick % 20 == 0 and tick > 200 and not any1(u_moving): settled = tick
    check(settled > 0, "role formation: settles (tick {settled})")
    let x0 = copy(u_x)
    let y0 = copy(u_y)
    steps(200)
    check(lo_ahead(spears) > hi_ahead(archers), "role formation: the spearmen stand ahead of the archers")
    check(lo_ahead(archers) > hi_ahead(healers), "role formation: the healers stand behind the archers")
    let foot = spears.append(archers).append(healers)
    let flo = lo_across(foot)
    let fhi = hi_across(foot)
    var left = 0
    var right = 0
    for(riders) uid:
        let a = across_of(uid)
        if a < flo: left++
        elif a > fhi: right++
    check(left + right == riders.length and left > 0 and right > 0, "role formation: the riders stand on both flanks ({left} left, {right} right of {riders.length}; centre {(flo + fhi) / 2})")
    var still = true
    for(u_id.length) i: still = still and u_x[i] == x0[i] and u_y[i] == y0[i]
    let overlaps = overlapping_pairs()
    check(overlaps == 0, "role formation: no one overlaps ({overlaps} pairs)")
    check(still, "role formation: it holds still afterwards")

// Counter-aware targeting: a spearman with a footman and a rider ahead, the rider a little further,
// goes for the rider; with counter_pull 0 it goes for the nearest, the footman.
def test_counter_pick():
    let race = gen_race(PROMPTS[0])
    for([-1, 0]) pull:
        bare_world([race, race])
        if pull == 0: r_counter_pull = 0
        let foot = lone(1, "infantry", 17000, 20500, "passive")
        let rider = lone(1, "large", 18000, 20500, "passive")
        let me = lone(0, "spear", 15000, 20500, "passive")
        let i = index_of(me)
        let fx, fy = pos_of(foot)
        let rx, ry = pos_of(rider)
        let d_foot = isqrt(dist2(u_x[i], u_y[i], fx, fy))
        let d_rider = isqrt(dist2(u_x[i], u_y[i], rx, ry))
        check(d_foot < d_rider and d_rider - d_foot < as_int(at(at(rules0, "combat"), "counter_pull")), "counter pick: the rider is a little further than the footman ({d_rider} v {d_foot})")
        stance(0, [me], "aggressive")
        steps(60)
        let want = if pull == 0: foot else: rider
        check(u_foe[index_of(me)] == want, "counter pick (pull {if pull < 0: "rules" else: "0"}): the spearman goes for the {if pull == 0: "footman" else: "rider"} (foe {u_foe[index_of(me)]}; footman {foot}, rider {rider})")

// The Norse shield wall: Norse shield infantry march shoulder to shoulder (form_gap), their riders
// don't, and the frogs keep the usual gap.
def test_shield_wall():
    let gaps = []::int
    for(["vikings", PROMPTS[0]]) prompt:
        let race = gen_race(prompt)
        bare_world([race, race])
        let spears = spawn(0, "spear", 12, 12000, 14000)
        let i = index_of(spears[0])
        let k = u_kind[i]
        if prompt == "vikings": check(type_has_tag(k, "shield"), "shield wall: Norse spearmen carry shields")
        issue_cmd(0, CMD_MOVE, spears, 40000, 40000, 0, 0)
        tick_on()
        while tick < 4000 and (tick < 200 or any1(u_moving)): tick_on()
        var best = 1 << 30
        for(spears) a:
            for(spears) b:
                if a < b:
                    let ia = index_of(a)
                    let ib = index_of(b)
                    best = min(best, isqrt(dist2(u_x[ia], u_y[ia], u_x[ib], u_y[ib])))
        gaps.push(best - 2 * u_radius[i])
        if prompt == "vikings":
            let riders = spawn(0, "large", 1, 12000, 16000)
            let rk = u_kind[index_of(riders[0])]
            check(t_gap[k] < 0 and (not type_has_tag(rk, "mounted") or t_gap[rk] == 0), "shield wall: the Norse foot close up (form_gap {t_gap[k]}), their riders don\'t ({t_gap[rk]})")
    check(abs(gaps[0]) <= SLOT_ARRIVE and gaps[1] >= FORM_GAP - SLOT_ARRIVE, "shield wall: Norse spearmen stand {gaps[0]} milli-tiles apart (body to body), frogs {gaps[1]}")

// The four stances. Foes that should not fight back are passive, so each check sees one side's choice.
def test_stances():
    let race = gen_race(PROMPTS[0])
    let y = 20500
    // Aggressive (the default): chases a foe across most of its sight; the passive foe never hits back.
    bare_world([race, race])
    var me = lone(0, "spear", 15000, y, "aggressive")
    lone(1, "spear", 20000, y, "passive")
    var r = watch(600, me)
    check(r.far > 1500 and r.hits[0] > 0, "aggressive: chases a foe 5 tiles off and hits it (went {r.far}, {r.hits[0]} hits)")
    check(r.hits[1] == 0, "passive: never hits back, even while being hit ({r.hits[1]} hits)")
    // Defensive: ignores a foe 5 tiles off; goes for one that comes near, chases it no further than
    // the leash, then walks back to where it stood.
    bare_world([race, race])
    me = lone(0, "spear", 15000, y, "defensive")
    let far = lone(1, "spear", 20000, y, "passive")
    let sx, sy = pos_of(me)
    r = watch(200, me)
    check(r.far < 300 and r.hits[0] == 0, "defensive: ignores a foe 5 tiles off (went {r.far})")
    issue_cmd(1, CMD_MOVE, [far], 16500, y, 0, 0)
    r = watch(100, me)
    check(r.hits[0] > 0, "defensive: goes for a foe that comes near ({r.hits[0]} hits)")
    issue_cmd(1, CMD_MOVE, [far], 40000, y, 0, 0)
    r = watch_from(600, me, sx, sy)
    let i = index_of(me)
    let home = isqrt(dist2(u_x[i], u_y[i], sx, sy))
    check(r.far > 2000 and r.far < r_leash + 1500, "defensive: chases a fleeing foe to the leash (went {r.far}, leash {r_leash})")
    check(home < 700 and u_foe[i] == 0 and u_moving[i] == 0, "defensive: then walks back to where it stood ({home} off)")
    // Stand ground, melee: never walks to a foe 2 tiles off, but fights one that comes to it.
    bare_world([race, race])
    me = lone(0, "spear", 15000, y, "stand")
    lone(1, "spear", 17000, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] == 0, "stand ground: doesn\'t walk to a foe 2 tiles off (went {r.far}, {r.hits[0]} hits)")
    lone(1, "spear", 16000, y, "aggressive")
    r = watch(400, me)
    check(r.hits[0] > 0 and r.far < 700, "stand ground: fights a foe that comes to it, where it stands (went {r.far}, {r.hits[0]} hits)")
    // Stand ground, ranged: shoots what is in reach, never steps closer to what isn't.
    bare_world([race, race])
    let reach = t_reach[type_of_slot(0, "archer")]
    me = lone(0, "archer", 15000, y, "stand")
    lone(1, "spear", 15000 + reach + 2500, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] == 0, "stand ground: an archer doesn\'t step towards a foe out of reach (went {r.far})")
    lone(1, "spear", 15000 + reach - 500, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] > 0, "stand ground: an archer shoots a foe in reach without moving ({r.hits[0]} hits)")
    // Passive: takes blows without answering; an explicit attack order still works.
    bare_world([race, race])
    me = lone(0, "spear", 15000, y, "passive")
    var foe = lone(1, "spear", 15800, y, "aggressive")
    r = watch(80, me)
    check(r.hits[1] > 0 and r.hits[0] == 0, "passive: takes {r.hits[1]} hits and answers none")
    issue_cmd(0, CMD_ATTACK, [me], foe, 0, 0, 0)
    r = watch(100, me)
    check(r.hits[0] > 0, "passive: an ordered attack still fights ({r.hits[0]} hits)")
    // Stand ground with an ordered target walks to it: orders beat stances.
    bare_world([race, race])
    me = lone(0, "spear", 15000, y, "stand")
    foe = lone(1, "spear", 19000, y, "passive")
    issue_cmd(0, CMD_ATTACK, [me], foe, 0, 0, 0)
    r = watch(400, me)
    check(r.far > 1500 and r.hits[0] > 0, "stand ground: an ordered attack walks to the target (went {r.far}, {r.hits[0]} hits)")

// Shooters stand still while their target is in reach; one out of reach walks just into reach and stops.
def test_ranged_holds():
    let race = gen_race("sewer rats with crossbows")
    let y = 20500
    bare_world([race, race])
    let k = type_of_slot(0, "archer")
    let reach = t_reach[k]
    let n_shots = 20 * t_reload[k]
    // Ordered, in reach: 20 shots without a step.
    var me = lone(0, "archer", 15000, y, "aggressive")
    var foe = lone(1, "large", 15000 + reach - 1000, y, "passive")
    u_hp[index_of(foe)] = 1 << 24
    issue_cmd(0, CMD_ATTACK, [me], foe, 0, 0, 0)
    var r = watch(n_shots, me)
    check(r.far == 0 and r.hits[0] >= 19, "an archer in reach doesn\'t move over 20 shots (went {r.far}, {r.hits[0]} hits)")
    // Ordered, out of reach: walks just into reach, then stands.
    bare_world([race, race])
    me = lone(0, "archer", 15000, y, "aggressive")
    foe = lone(1, "large", 15000 + reach + 3000, y, "passive")
    u_hp[index_of(foe)] = 1 << 24
    issue_cmd(0, CMD_ATTACK, [me], foe, 0, 0, 0)
    watch(200, me)
    let i = index_of(me)
    let g = gap(i, index_of(foe))
    r = watch(n_shots, me)
    check(g <= reach and g > reach - 2 * u_speed[i] and r.far == 0 and r.hits[0] >= 19, "an archer out of reach walks just into it and stands (gap {g} of reach {reach}, then went {r.far}, {r.hits[0]} hits)")
    // Attack-move, a line of shooters: the walk-back to the move's end no longer drags them on.
    bare_world([race, race])
    foe = lone(1, "large", 24000, y, "passive")
    u_hp[index_of(foe)] = 1 << 24
    spawn_cmd(0, "archer", 8, 14000, y)
    while u_id.length < 9: tick_on()
    let mine = ids_of(0)
    issue_cmd(0, CMD_ATTACK_MOVE, mine, 40000, y, 0, 0)
    steps(400)
    let was_x = map(mine) uid: u_x[index_of(uid)]
    let was_y = map(mine) uid: u_y[index_of(uid)]
    var hits = 0
    for(n_shots):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and contains(mine, e.a): hits++
    var crept = 0
    for(mine) uid, n:
        let x, yy = pos_of(uid)
        crept = max(crept, isqrt(dist2(x, yy, was_x[n], was_y[n])))
    check(crept < 100 and hits >= 8 * 19, "8 attack-moving archers hold their line over 20 shots (most moved {crept}, {hits} hits)")

def eval_cost(e:JV) -> int:
    let c = at(e, "cost")
    return gint(c, "food", 0) + gint(c, "wood", 0)

// An equal-cost fight between two of a race's roster slots; `flip` swaps the sides. Both attack-move
// at each other; the side with more value left wins.
def counter_fight(race:JV, a_slot:string, b_slot:string, flip:int) -> bool, string:
    bare_world([race, race])
    let slots = [a_slot, b_slot]
    let value = [0, 0]
    for(2) side:
        let p = side ^ flip
        let cost = eval_cost(at(unit_of(race, slots[side]), "eval"))
        value[side] = cost
        spawn_cmd(p, slots[side], max(1, (FIGHT_BUDGET + cost / 2) / cost), FIGHT_FROM_X[p], FIGHT_FROM_Y[p])
    while u_id.length == 0: tick_on()
    for(2) p: issue_cmd(p, CMD_ATTACK_MOVE, ids_of(p), FIGHT_FROM_X[1 - p], FIGHT_FROM_Y[1 - p], 0, 0)
    var left = [0, 0]
    while tick < FIGHT_LIMIT:
        tick_on()
        left = [0, 0]
        for(u_owner) o: left[o]++
        if left[0] == 0 or left[1] == 0: break
    let a_left = left[flip] * value[0]
    let b_left = left[1 - flip] * value[1]
    return a_left > b_left, "{left[flip]} {a_slot} worth {a_left} left vs {left[1 - flip]} {b_slot} worth {b_left}, tick {tick}"

def test_combat():
    test_heal()
    test_damage()
    test_idle_fight()
    test_spread()
    test_teams()
    test_siege_tc()
    test_surround()
    test_formation()
    test_role_formation()
    test_counter_pick()
    test_shield_wall()
    test_stances()
    test_ranged_holds()
    var wins = 0
    var fights = 0
    let t0 = seconds_elapsed()
    for(COUNTER_PROMPTS) prompt:
        let race = gen_race(prompt)
        for(COUNTERS) pair:
            if not eval_has_tag(at(unit_of(race, pair[1]), "eval"), pair[2]):
                print "  n/a: {rstr(race, "name")} {pair[0]} vs {pair[1]} (the {pair[1]} isn\'t {pair[2]})"
                continue
            for(2) flip:
                let won, note = counter_fight(race, pair[0], pair[1], flip)
                fights++
                if won: wins++
                else: print "  counter lost: {rstr(race, "name")} {pair[0]} vs {pair[1]} (side {flip}): {note}"
    print "counters: {wins} of {fights} equal-cost fights won by the counter ({wins * 100 / fights}%), {ms_since(t0)} ms"
    check(wins * 100 >= fights * 75, "counters win at least 75% of equal-cost fights ({wins}/{fights})")

// ------------------------------------------------------------------ the parts

let PARTS = ["fixed", "command_order", "source_lint", "flow", "crossing_flat", "crossing_choke", "crossing_engines",
             "opening", "combat", "match", "match_b", "match_flipped"]

def run_part(name:string):
    if name == "fixed": test_fixed()
    elif name == "command_order": test_command_order()
    elif name == "source_lint": test_source_lint()
    elif name == "flow": test_flow()
    elif name == "crossing_flat": test_crossing("flat_test", false)
    elif name == "crossing_choke": test_crossing("choke_test", false)
    elif name == "crossing_engines":
        for(["flat_test", "choke_test", "hill_test"]) m: test_crossing(m, true)
    elif name == "opening": test_opening()
    elif name == "combat": test_combat()
    elif name == "match": test_match()
    elif name == "match_b": test_match_b()
    elif name == "match_flipped": test_match_flipped()
    else:
        check(false, "test_sim: no part {name}")

let args = command_line_arguments()
var chosen = PARTS
for(args) a:
    if starts_with(a, "part:"): chosen = tokenize(a.substring(5, a.length - 5), ",", " ")
    elif starts_with(a, "shard:"):
        let i, n = split_string(a.substring(6, a.length - 6), "/")
        let si = string_to_int(i)
        let sn = string_to_int(n)
        chosen = []
        for(PARTS) pn, k:
            if k % sn == si: chosen.push(pn)
    elif a != "serial": check(false, "test_sim: unknown argument {a}")
let t_all = seconds_elapsed()
for(chosen) name:
    let t0 = seconds_elapsed()
    let f0 = failures
    run_part(name)
    print "@@ {name}: {ms_since(t0)} ms{if failures > f0: ", " + string(failures - f0) + " failed" else: ""}"
print "\n{checks - failures} passed, {failures} failed ({chosen.length} parts, {ms_since(t_all) / 1000} s)"
if failures > 0: set_exit_code(1)
