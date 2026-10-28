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

// ------------------------------------------------------------------ shots, engines, trade, sappers

// A finished building of type `id` for p (test_sim.gd's _put): its id.
def put(p:int, id:string, cx:int, cy:int, along:int) -> int:
    let k = btype_index(id)
    assert k >= 0
    let b = place(p, k, cx, cy, along)
    b_done[b] = 1
    b_hp[b] = bm_hp[p][k]
    return b_id[b]

def res_of(name:string) -> int: return str_index(resource_names, name)

// Shots fly: an arrow lands a flight after it is loosed and only then hurts; one at a target that has
// stepped off the spot falls in the ground; one at a building always lands.
def test_shots():
    bare_world(races0)
    let a = lone(0, "archer", 15000, 20500, "stand")
    let t = lone(1, "spear", 19000, 20500, "passive")
    issue_cmd(0, CMD_ATTACK, [a], t, 0, 0, 0)
    var shot_to = -1
    var shot_ticks = 0
    var fired = -1
    for(200):
        tick_on()
        for(events) e:
            if e.kind == EV_SHOT and e.a == a:
                shot_to = e.b
                shot_ticks = shots[SHOT_LAND] - (tick - 1)   // (the one shot in the air)
        if shot_to >= 0:
            fired = tick - 1   // the tick it was loosed in
            break
    check(shot_to == t and shot_ticks > 1, "shots: an archer looses a shot that takes a while to land (to {shot_to}, {shot_ticks} ticks)")
    check(shots.length / SHOT_STRIDE == 1, "shots: one in the air ({shots.length / SHOT_STRIDE})")
    var hp = u_hp[index_of(t)]
    var landed = -1
    var hit_damage = -1
    for(60):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == a: hit_damage = e.c
        if hit_damage >= 0:
            landed = tick - 1
            break
        check(u_hp[index_of(t)] == hp, "shots: no harm before it lands (tick {tick})")
    check(landed == fired + shot_ticks, "shots: it lands its flight after loosing ({landed}, loosed {fired}, {shot_ticks} ticks)")
    check(hit_damage >= 0 and u_hp[index_of(t)] == hp - hit_damage, "shots: a standing target is hit ({hit_damage})")
    // The next shot: the target steps a tile and a half aside while it flies.
    var missed = false
    var miss_ok = false
    var aside = false
    var aim_x = 0
    var aim_y = 0
    for(200):
        tick_on()
        for(events) e:
            if e.kind == EV_SHOT and e.a == a and not aside:
                u_y[index_of(t)] += 1500
                aside = true
                aim_x = e.x
                aim_y = e.y
            elif e.kind == EV_MISS and e.a == a:
                missed = true
                miss_ok = e.b == t and e.x == aim_x and e.y == aim_y
        if missed: break
    hp = u_hp[index_of(t)]
    check(missed and miss_ok, "shots: a target that stepped away is missed, the shot lands where it stood")
    check(u_hp[index_of(t)] == hp and lost[1] == 0, "shots: a miss does no harm")
    // A building never dodges.
    bare_world(races0)
    let house = put(1, "house", 18, 20, 0)
    let bhp = b_hp[b_index_of(house)]
    let s2 = lone(0, "archer", 15000, 20500, "stand")
    issue_cmd(0, CMD_ATTACK, [s2], house, 0, 0, 0)
    var n_shots = 0
    var hits = 0
    for(300):
        tick_on()
        for(events) e:
            if e.a == s2 and e.kind == EV_SHOT: n_shots++
            elif e.a == s2 and e.kind == EV_HIT: hits++
    check(hits > 2 and hits >= n_shots - 1 and b_hp[b_index_of(house)] < bhp, "shots: every shot at a house lands ({hits} of {n_shots})")

def place_at(uid:int, x:int, y:int):
    let i = index_of(uid)
    u_x[i] = x
    u_y[i] = y

// Siege engines: a catapult's stone hurts everyone round where it lands, less further out, friends
// at half; it can't hit what is under its nose and steps back; a ram goes for buildings only, hits
// them very hard and shrugs off arrows; a bolt goes through a line.
def test_engines():
    bare_world(races0)
    let cat = lone(0, "catapult", 9000, 20500, "stand")
    let offs = [[0, 0], [700, 0], [0, 700], [0, -700]]
    let foes = map(offs) o: lone(1, "spear", 17000 + o[0], 20500 + o[1], "passive")
    let friend = lone(0, "spear", 16400, 20500, "passive")
    for(foes) f, k: place_at(f, 17000 + offs[k][0], 20500 + offs[k][1])
    place_at(friend, 16400, 20500)
    issue_cmd(0, CMD_ATTACK, [cat], foes[0], 0, 0, 0)
    var splashed = false
    let hit_ids = []::int
    let hit_dmg = []::int
    for(400):
        tick_on()
        for(events) e:
            if e.kind == EV_SPLASH and e.a == cat: splashed = true
            elif e.kind == EV_HIT and e.a == cat:
                hit_ids.push(e.b)
                hit_dmg.push(e.c)
        if splashed: break
    def dmg_of(uid:int) -> int:
        for(hit_ids) h, n:
            if h == uid: return hit_dmg[n]
        return 0
    let on_foes = filter(foes) f: contains(hit_ids, f)
    check(splashed and on_foes.length >= 3, "catapult: its stone lands and hurts {on_foes.length} of 4 foes round the spot ({hit_ids} {hit_dmg})")
    check(dmg_of(foes[0]) > dmg_of(foes[1]) and dmg_of(foes[1]) > 0, "catapult: the target takes the most, a body further out less ({hit_ids} {hit_dmg})")
    check(contains(hit_ids, friend) and dmg_of(friend) < dmg_of(foes[1]) + 1, "catapult: a friend in the splash is hurt too, at half ({dmg_of(friend)})")
    // Minimum range: a foe a tile and a half off isn't shot at; the catapult steps back, then shoots.
    bare_world(races0)
    let c2 = lone(0, "catapult", 12000, 20500, "aggressive")
    let near = lone(1, "spear", 13900, 20500, "passive")
    place_at(near, 13900, 20500)
    issue_cmd(0, CMD_ATTACK, [c2], near, 0, 0, 0)
    var close_shot = false
    var shot_at = -1
    for(600):
        tick_on()
        let g = gap(index_of(c2), index_of(near))
        for(events) e:
            if e.kind == EV_SHOT and e.a == c2:
                if g < 3000: close_shot = true
                shot_at = g
        if shot_at >= 0: break
    check(not close_shot and shot_at >= 3000, "catapult: no shot inside its minimum range; it steps back and shoots from {shot_at} milli-tiles")
    // The ram: ordered at a soldier, it won't; left be, it finds the house and hits it very hard.
    bare_world(races0)
    let house = put(1, "house", 18, 20, 0)
    let ram = lone(0, "ram", 15500, 22500, "aggressive")
    let sentry = lone(1, "spear", 15500, 24000, "passive")
    issue_cmd(0, CMD_ATTACK, [ram], sentry, 0, 0, 0)
    var blow = 0
    var on_guard = 0
    for(400):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == ram:
                if e.b == house: blow = max(blow, e.c)
                elif e.b == sentry: on_guard++
        if blow > 0: break
    check(on_guard == 0 and blow >= 30, "ram: never hits soldiers, hits a house hard ({blow} a blow)")
    let archer = lone(1, "archer", 14000, 24500, "stand")
    issue_cmd(1, CMD_ATTACK, [archer], ram, 0, 0, 0)
    var arrow = 0
    for(300):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == archer and e.b == ram: arrow = e.c
        if arrow > 0: break
    check(arrow == 1, "ram: arrows barely scratch it ({arrow})")
    let rk = type_of_slot(0, "ram")
    var heals_ok = true
    for(t_slot.length) k:
        if type_has_tag(k, "siege") and (t_no_heal[k] != 0) != type_has_tag(k, "machine"): heals_ok = false
    check(heals_ok and t_buildings_only[rk] != 0, "engines: machines aren\'t healed (beasts are), rams go for buildings")
    // A bolt through a line: aimed at the far one, it hits those in its way too.
    bare_world(races0)
    let bolt = lone(0, "bolt_thrower", 8000, 20500, "stand")
    let line = []::int
    for([14500, 15500, 16500]) x:
        let uid = lone(1, "spear", x, 20500, "passive")
        place_at(uid, x, 20500)
        line.push(uid)
    issue_cmd(0, CMD_ATTACK, [bolt], line[2], 0, 0, 0)
    let struck = []::int
    for(400):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == bolt and not contains(struck, e.b): struck.push(e.b)
        if struck.length: break
    check(struck.length == 3, "bolt thrower: a bolt goes through a line of three ({struck.length} hit)")

// Trade carts: a cart sent from its market to another 30 tiles off walks there, loads the trip's gold
// and is paid on coming home; gold per trip grows faster than the distance; markets too close,
// unfinished or an enemy's aren't traded with; one killed on the way home loses its load; it carries on.
def test_trade():
    bare_world(races0)
    let g = res_of("gold")
    let home = put(0, "market", 12, 30, 0)
    let far = put(0, "market", 42, 30, 0)
    let hb = b_index_of(home)
    let fb = b_index_of(far)
    let d = market_tiles(hb, fb)
    let pay = trip_gold(hb, fb)
    check(d == 30 and pay == 30 * 30 / 50 + 30 * 50 / 100, "trade: 30 tiles apart, a round trip pays d*d/50 + d/2 = {pay} ({d} tiles)")
    let near = put(0, "market", 24, 30, 0)
    check(trip_gold(hb, b_index_of(near)) * 30 < pay * 12, "trade: half as far pays well under half as much")
    check(route_barred(0, hb, b_index_of(near)), "trade: markets 12 tiles apart are too close")
    let cart = spawn_at(0, "trader", 15500, 31500)
    let k = type_of_slot(0, "trader")
    check(t_trader[k] != 0 and t_harmless[k] != 0 and t_posture[k] == PASSIVE, "trade: carts are traders, harmless and passive")
    var gold = stock[g][0]
    issue_cmd(0, CMD_ROUTE, [cart], far, 0, 0, 0)
    var loaded = -1
    var paid = -1
    for(3000):
        tick_on()
        let ci = index_of(cart)
        if loaded < 0 and u_carry[ci] > 0: loaded = tick
        if paid < 0 and stock[g][0] > gold: paid = tick
        if paid >= 0: break
    check(loaded > 0 and paid > loaded, "trade: the cart loads at the far market ({loaded}) and is paid at home ({paid})")
    check(stock[g][0] == gold + pay, "trade: one round trip brings home {pay} gold ({stock[g][0] - gold})")
    check(paid > 20 * 2 * 25 and paid < 20 * 2 * 60, "trade: a 60-tile round trip at a cart\'s pace takes about a minute ({paid} ticks)")
    var ci = index_of(cart)
    check(ci >= 0 and u_task[ci] == T_TRADE and u_work[ci] == TRADE_OUT, "trade: it sets out again")
    // A second round, then kill it on its way home: the load is lost.
    for(3000):
        tick_on()
        ci = index_of(cart)
        if u_carry[ci] > 0 and u_work[ci] == TRADE_HOME: break
    gold = stock[g][0]
    u_hp[ci] = 1
    let foe = spawn_at(1, "spear", u_x[ci], u_y[ci])
    issue_cmd(1, CMD_ATTACK, [foe], cart, 0, 0, 0)
    for(400):
        tick_on()
        if index_of(cart) < 0: break
    check(index_of(cart) < 0 and stock[g][0] == gold, "trade: a cart killed on its way home loses its load")
    // Unfinished and enemy markets aren't traded with.
    bare_world(races0)
    put(0, "market", 12, 30, 0)
    let ef = put(1, "market", 42, 30, 0)
    let c2 = spawn_at(0, "trader", 15500, 31500)
    issue_cmd(0, CMD_ROUTE, [c2], ef, 0, 0, 0)
    steps(40)
    check(u_task[index_of(c2)] == T_NONE, "trade: no route to an enemy\'s market")
    new_world("flat_test", races0, bare0, [0, 0])
    put(0, "market", 12, 30, 0)
    let af = put(1, "market", 42, 30, 0)
    let c3 = spawn_at(0, "trader", 15500, 31500)
    issue_cmd(0, CMD_ROUTE, [c3], af, 0, 0, 0)
    steps(40)
    check(u_task[index_of(c3)] == T_TRADE, "trade: an ally\'s market is traded with")
    let cart_eval = su_type_eval[k]
    let cost = at(cart_eval, "cost")
    check(gint(cost, "gold", 0) > 0 and gint(cost, "wood", 0) > 0 and gint(cart_eval, "pop", 0) == 1, "trade: a cart costs wood and gold, 1 pop ({stringify(cost)})")

// The great sling: buildings only, from far off; it unpacks for a while after it stops before its
// first throw, and packs up before it can move again. The sapper (parked, D-128: none to test while
// its slot is planned).
def test_sapper_sling():
    bare_world(races0)
    let k = type_of_slot(0, "great_sling")
    let house = put(1, "house", 30, 20, 0)
    let sl = lone(0, "great_sling", 15000, 21000, "aggressive")
    let sentry = lone(1, "spear", 26000, 21000, "passive")
    issue_cmd(0, CMD_ATTACK, [sl], house, 0, 0, 0)
    var stopped = -1
    var thrown = -1
    var at_guard = false
    for(1200):
        tick_on()
        let i = index_of(sl)
        if stopped < 0 and u_moving[i] == 0 and u_ready[i] == 1: stopped = tick
        for(events) e:
            if e.kind == EV_SHOT and e.a == sl:
                if thrown < 0: thrown = tick
                at_guard = at_guard or e.b == sentry
        if thrown >= 0: break
    let ti = index_of(sl)
    let reach = gap_b(ti, b_index_of(house))
    check(thrown > 0 and stopped > 0 and thrown - stopped >= t_unpack[k] - 1, "great sling: it stops, unpacks ({t_unpack[k]} ticks) and throws (stopped {stopped}, threw {thrown})")
    check(reach > 8000 and not at_guard, "great sling: throws at the house from {reach} milli-tiles, never at the soldier")
    let x0 = u_x[ti]
    issue_cmd(0, CMD_MOVE, [sl], 8000, 21000, 0, 0)
    var left = -1
    for(200) t:
        tick_on()
        if left < 0 and u_x[index_of(sl)] != x0: left = t
    check(left >= t_pack[k], "great sling: it packs up ({t_pack[k]} ticks) before it rolls ({left})")
    check(type_of_slot(0, "sapper") < 0, "the sapper is still parked (D-128): when it comes back, port its checks from test_sim.gd")

// ------------------------------------------------------------------ gates and walls

// A closed square of palisade on flat_test (tiles 12..20 by 18..26) with player 0's gate in its east
// side, three tiles along y at (20, 21..23). Inside is 13..19 by 19..25. Returns the gate's id.
def gate_world(races:[JV], team_ids:[int]) -> int:
    new_world("flat_test", races, bare0, team_ids)
    for(9) n:
        let k = n + 12
        for([int2 { k, 18 }, int2 { k, 26 }, int2 { 12, k + 6 }, int2 { 20, k + 6 }]) c:
            if occupied[c.y * W + c.x] == 0 and not (c.x == 20 and c.y >= 21 and c.y <= 23): put(0, "palisade", c.x, c.y, 0)
    check(walks.length == 3, "gates: without a gate the map keeps one walk grid per movement class ({walks.length})")
    let g = put(0, "palisade_gate", 20, 21, 1)
    let gb = b_index_of(g)
    check(b_sx[gb] == 1 and b_sy[gb] == 3, "gates: a gate along y is 1 x 3 tiles ({b_sx[gb]} x {b_sy[gb]})")
    return g

def inside_square(uid:int) -> bool:
    let i = index_of(uid)
    return i >= 0 and u_x[i] < 20000 and u_x[i] >= 13000 and u_y[i] >= 19000 and u_y[i] < 26000

def spawn_in(p:int, slot:string) -> int: return spawn_at(p, slot, 16500, 22500)

// Gates: a gate lets its own team through and nobody else; knocked down, it opens the way for
// everyone; dropped on a wall tile, it takes that tile's place.
def test_gates():
    var gate_id = gate_world(races0, [])
    let gc = 22 * W + 20
    check(walks.length == 6, "gates: the gate\'s team gets walk grids of its own ({walks.length})")
    check(walks[lane_base[0]][gc] == 1 and walks[lane_base[1]][gc] == 0, "gates: open to its owner, shut to the enemy")
    let mine = spawn_in(0, "worker")
    let theirs = spawn_in(1, "worker")
    for([mine, theirs]) uid: issue_cmd(u_owner[index_of(uid)], CMD_MOVE, [uid], 25500, 22500, 0, 0)
    steps(600)
    var i = index_of(mine)
    check(dist2(u_x[i], u_y[i], 25500, 22500) < 1000 * 1000, "gates: a friendly unit walks out through its gate ({u_x[i]}, {u_y[i]})")
    check(inside_square(theirs), "gates: an enemy shut in the square stays in")
    issue_cmd(0, CMD_MOVE, [mine], 16500, 21500, 0, 0)
    steps(600)
    check(inside_square(mine), "gates: ... and back in again")
    // Allies share the gate; the enemy knocks it down, and then the way is open to it.
    gate_id = gate_world([races0[0], races0[1], races0[0]], [0, 0, 1])
    let ally = spawn_in(1, "worker")
    issue_cmd(1, CMD_MOVE, [ally], 25500, 22500, 0, 0)
    let foe = spawn_in(2, "spear")
    issue_cmd(2, CMD_MOVE, [foe], 25500, 22500, 0, 0)
    steps(600)
    check(not inside_square(ally), "gates: an ally walks through too")
    check(inside_square(foe), "gates: the enemy spearman can\'t")
    issue_cmd(2, CMD_ATTACK, [foe], gate_id, 0, 0, 0)
    while tick < 8000 and b_index_of(gate_id) >= 0: tick_on()
    check(b_index_of(gate_id) < 0, "gates: the enemy knocks the gate down (tick {tick})")
    check(walks[lane_base[2]][gc] == 1, "gates: its tile is open to everyone again")
    issue_cmd(2, CMD_MOVE, [foe], 25500, 22500, 0, 0)
    steps(600)
    i = index_of(foe)
    check(i >= 0 and dist2(u_x[i], u_y[i], 25500, 22500) < 1000 * 1000, "gates: ... and walks out where it stood")
    // A gate dropped on a wall tile replaces it; the wrong wall or someone else's won't do.
    gate_world(races0, [])
    let builder = spawn_in(0, "worker")
    stock[res_of("wood")][0] = 500
    let wall_ids = map(3) n: occupied[18 * W + 15 + n]
    let k = btype_index("palisade_gate")
    check(can_place(0, k, 15, 18) and not can_place(1, k, 15, 18), "gates: a gate goes on your own wall, not on a rival\'s")
    check(not can_place(0, btype_index("stone_gate"), 15, 18), "gates: a stone gate doesn\'t go on a palisade")
    issue_cmd(0, CMD_BUILD, [builder], k, 15, 18, 0)
    steps(900)
    let nb = occupied[18 * W + 16]
    let b = b_index_of(nb)
    let gone = not exists(wall_ids) id: b_index_of(id) >= 0
    check(gone and b >= 0 and bt_name[b_kind[b]] == "palisade_gate" and b_done[b] == 1 and occupied[18 * W + 15] == nb and occupied[18 * W + 17] == nb,
        "gates: dropped on a palisade line, a gate takes the place of the three tiles under it and is built")

// A diamond of side 1's palisade round (16, 24), every tile corner to corner with the next.
def diamond():
    for(24) k:
        let q = k % 6
        let c = [int2 { 16 + q, 18 + q }, int2 { 22 - q, 24 + q }, int2 { 16 - q, 30 - q }, int2 { 10 + q, 24 - q }][k / 6]
        put(1, "palisade", c.x, c.y, 0)

def in_diamond(uid:int) -> bool:
    let i = index_of(uid)
    return i >= 0 and abs(u_x[i] / 1000 - 16) + abs(u_y[i] / 1000 - 24) < 6

// A wall drawn diagonally still holds: a crowd inside sent out past it must stay in: the fields find
// no way out, and nobody slips between two corners on the move.
def test_diagonal_wall():
    new_world("flat_test", races0, bare0, [])
    diamond()
    let f = solve([24 * W + 16], INF, 0)
    check(f.dist[24 * W + 26] >= INF, "diagonal wall: no flow field reaches out of the diamond")
    let ids = map(12) n: spawn_at(0, ["spear", "worker", "large"][n % 3], 15000 + (n % 4) * 700, 23000 + (n / 4) * 700)
    for([int2 { 16500, 15500 }, int2 { 25500, 24500 }, int2 { 16500, 33500 }, int2 { 6500, 24500 }]) corner:
        issue_cmd(0, CMD_MOVE, ids, corner.x, corner.y, 0, 0)
        steps(400)
    let out = (filter(ids) uid: not in_diamond(uid)).length
    check(out == 0, "diagonal wall: a crowd pushed at every side of a corner-to-corner wall stays in ({out} got out)")
    // The movement rule on its own: a unit right at the corner between two wall tiles, stepping
    // diagonally through the gap point, is stopped (no field to help it).
    place_at(ids[0], 21960, 24040)   // in tile (21, 24), inside, by the point where (21, 23) and (22, 24) touch
    order_direct(index_of(ids[0]), 22600, 23400)
    steps(40)
    check(in_diamond(ids[0]), "diagonal wall: a unit steered straight at the corner gap doesn\'t slip through")

// Diagonal gates: a gate dropped into a diagonal wall run lies on it corner to corner, three cells.
// Its own side walks through; the enemy doesn't, neither through it nor between its ends and the
// wall pieces they touch at a corner; the cells beside it stay open ground.
def test_diagonal_gates():
    new_world("flat_test", races0, bare0, [])
    diamond()
    let k = btype_index("palisade_gate")
    let ax, ay = dims(k, 2)
    let bx, by = dims(k, 3)
    check(ax == 3 and ay == 3 and bx == 3 and by == 3, "diagonal gates: a diagonal gate spans a 3 x 3 square")
    check(can_place(1, k, 17, 19, 2) and can_place(1, k, 19, 25, 3), "diagonal gates: one goes on each diagonal of your own wall")
    check(not can_place(0, k, 17, 19, 2), "diagonal gates: ... not on a rival\'s")
    check(not can_place(1, btype_index("stone_gate"), 17, 19, 2), "diagonal gates: a stone gate doesn\'t go on a palisade")
    check(not can_place(1, k, 62, 30, 2) and not can_place(1, k, -1, 30, 3), "diagonal gates: not off the map\'s edge")
    put(1, "house", 34, 10, 0)
    check(not can_place(1, k, 33, 9, 2) and not can_place(1, k, 33, 9, 3), "diagonal gates: not over another building")
    check(can_place(1, k, 32, 8, 3), "diagonal gates: only its diagonal counts (its square\'s corner may overlap a house)")
    // Built by a worker from inside (along 2, then along 3, shift-queued).
    let builder = spawn_at(1, "worker", 16500, 24500)
    stock[res_of("wood")][1] = 500
    let walls = map(3) q: occupied[(19 + q) * W + 17 + q]
    issue_cmd(1, CMD_BUILD, [builder], k, 17, 19, 2)
    issue_cmd(1, CMD_BUILD, [builder], k, 19, 25, 3, 1)
    for(3000):
        tick_on()
        let a = b_index_of(occupied[20 * W + 18])
        let b = b_index_of(occupied[26 * W + 20])
        if a >= 0 and b >= 0 and b_done[a] == 1 and b_done[b] == 1 and bt_gate[b_kind[b]] != 0: break
    let g1 = occupied[20 * W + 18]
    let g2 = occupied[26 * W + 20]
    let b1 = b_index_of(g1)
    let b2 = b_index_of(g2)
    check(b1 >= 0 and bt_gate[b_kind[b1]] != 0 and b_done[b1] == 1 and b_diag[b1] == 1, "diagonal gates: built down the screen (along 2)")
    check(b2 >= 0 and bt_gate[b_kind[b2]] != 0 and b_done[b2] == 1 and b_diag[b2] == 2, "diagonal gates: ... and across it (along 3)")
    check(not exists(walls) id: b_index_of(id) >= 0, "diagonal gates: the three wall tiles under it are gone")
    check(occupied[19 * W + 17] == g1 and occupied[21 * W + 19] == g1 and occupied[25 * W + 21] == g2 and occupied[27 * W + 19] == g2,
        "diagonal gates: each holds the three cells of its diagonal")
    let open = [int2 { 18, 19 }, int2 { 19, 19 }, int2 { 17, 20 }, int2 { 17, 21 }, int2 { 20, 25 }, int2 { 19, 26 }, int2 { 21, 26 }]
    check(not exists(open) c: occupied[c.y * W + c.x] != 0 or walks[0][c.y * W + c.x] != 1, "diagonal gates: the rest of its square is open ground")
    // Fields: none out of the diamond for side 0; out for side 1, through the gates.
    let f0 = solve([24 * W + 16], INF, lane_base[0])
    check(f0.dist[24 * W + 26] >= INF, "diagonal gates: no field leads the enemy out (no corner slipped at the gates\' ends)")
    let f1 = solve([24 * W + 16], INF, lane_base[1])
    check(f1.dist[18 * W + 21] < INF and f1.dist[29 * W + 22] < INF, "diagonal gates: the owner\'s field goes out through both")
    // Side 1 walks out through each gate and back in; side 0's crowd pushed at them stays in.
    let friends = map(3) n: spawn_at(1, ["spear", "worker", "large"][n], 15500 + n * 700, 23500)
    for([int2 { 21000, 18000 }, int2 { 23000, 29000 }]) dest:
        issue_cmd(1, CMD_MOVE, friends, dest.x, dest.y, 0, 0)
        steps(700)
        let out = (filter(friends) uid: index_of(uid) >= 0 and dist2(u_x[index_of(uid)], u_y[index_of(uid)], dest.x, dest.y) < 2000 * 2000).length
        check(out == friends.length, "diagonal gates: side 1 walks out through its gate to ({dest.x}, {dest.y}) ({out} of {friends.length})")
        issue_cmd(1, CMD_MOVE, friends, 16500, 24500, 0, 0)
        steps(700)
        check(not exists(friends) uid: not in_diamond(uid), "diagonal gates: ... and back in")
    for(friends.append([builder])) uid:   // (side 0 would fight them)
        if index_of(uid) >= 0: remove_unit(index_of(uid))
    let crowd = map(9) n: spawn_at(0, ["spear", "worker", "large"][n % 3], 15000 + (n % 3) * 700, 25000 + (n / 3) * 700)
    for([int2 { 21000, 18000 }, int2 { 23000, 29000 }]) dest:
        issue_cmd(0, CMD_MOVE, crowd, dest.x, dest.y, 0, 0)
        steps(700)
    let esc = (filter(crowd) uid: not in_diamond(uid)).length
    check(esc == 0, "diagonal gates: the enemy crowd pushed at both gates stays in ({esc} got out)")
    // Right at the corner where the gate's end meets the next wall tile, stepping straight through the point: stopped.
    place_at(crowd[0], 16960, 19040)
    order_direct(index_of(crowd[0]), 17600, 18400)
    steps(40)
    check(in_diamond(crowd[0]), "diagonal gates: no slipping between the gate\'s end and the wall at their corner")
    for(crowd) uid: remove_unit(index_of(uid))
    // The enemy knocks it down from outside, and the way is open.
    let foe = spawn_at(0, "spear", 21000, 18000)
    issue_cmd(0, CMD_ATTACK, [foe], g1, 0, 0, 0)
    let t0 = tick
    while tick < t0 + 12000 and b_index_of(g1) >= 0: tick_on()
    check(b_index_of(g1) < 0, "diagonal gates: an enemy spearman knocks one down ({tick - t0} ticks)")
    check(walks[lane_base[0]][20 * W + 18] == 1, "diagonal gates: ... and its cells are open to everyone")

// Knock a building down at once (Combat._apply with a deadly hurt for it).
def knock_down(b:int):
    grow_scratch()
    for(u_id.length) j:
        c_hurt[j] = 0
        c_hurt_by[j] = 0
    c_bhurt = map(b_id.length): 0
    c_bhurt[b] = 99999
    apply_hits(u_id.length)

def terrain_name(c:int) -> string: return tr_names[terrain[c]]

// What p may rebuild on a breach's rubble (Walls.rebuild_of's building), or "".
def rebuild_of(p:int, c:int) -> string:
    let rec = rubble.get(c)
    if not rec or rec[1] != p: return ""
    return bt_name[rec[2]]

def ring_spec(tower:string) -> JV:
    let spec = jobj()
    set(spec, "wall", jstr("wall"))
    set(spec, "gate", jstr("stone_gate"))
    set(spec, "tower", jstr(tower))
    set(spec, "tower_every", jint(4))
    set(spec, "gates", jstrs(["n", "s"]))
    return spec

def in_age3():
    for(2) p:
        ages[p] = 3
        retype(p)
        tech_refresh(p)

def count_up(ids:[int]) -> int:
    var n = 0
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_perch[i] != 0: n++
    return n

def all_down(ids:[int]) -> bool:   // each gone, or off the wall and standing
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and (u_perch[i] != 0 or u_moving[i] != 0): return false
    return true

def in_town(uid:int) -> bool:
    let i = index_of(uid)
    return i >= 0 and u_perch[i] == 0 and u_x[i] > 6999 and u_x[i] < 18000 and u_y[i] > 6999 and u_y[i] < 18000

// Walls you stand on: the rats (player 0) in a stone ring round their start with gatehouses north and
// south and wall towers; archers sent onto the east wall climb up and spread over its standing places;
// up there they aren't pushed about, shoot a tile further, and melee below can't touch them; sent into
// the town they climb down; a wall tile knocked down becomes rubble (those on it fall) that a worker
// rebuilds for less; a worker mends a wall and a machine ram. Run twice: the same hash.
def walls_run(races:[JV], checks_on:bool) -> int:
    new_world("flat_test", races, rules0, [])
    in_age3()
    def c(ok:bool, what:string):
        if checks_on: check(ok, what)
    let before = b_id.length
    fortify_ring(0, 12, 12, 6, ring_spec("wall_tower"))
    c(b_id.length - before > 30, "walls: a ring goes up ({b_id.length - before} pieces)")
    let tk = btype_index("wall_tower")
    c(can_place(0, tk, 18, 9) and not can_place(1, tk, 18, 9), "walls: a wall tower drops onto its owner\'s wall tile")
    let archers = spawn(0, "archer", 6, 12500, 12500)
    issue_cmd(0, CMD_MOVE, archers, 18500, 8500, 0, 0)
    def settled_up() -> int:
        var n = 0
        for(archers) uid:
            let i = index_of(uid)
            if i >= 0 and u_perch[i] != 0 and u_wgoal[i] == 0: n++
        return n
    for(900):
        tick_on()
        if settled_up() == archers.length: break
    c(settled_up() == archers.length, "walls: six archers climb onto the east wall ({settled_up()} up)")
    let cells_held = []::int
    var on_walk = true
    for(archers) uid:
        let i = index_of(uid)
        let cell = u_perch[i] - 1
        cells_held.push(cell)
        on_walk = on_walk and places(cell) > 0 and cell_of(u_x[i], u_y[i]) == cell and abs(u_x[i] / 1000 - 18) <= 1
    c(on_walk, "walls: they stand on walkway cells of the east wall")
    var crowded = false
    for(cells_held) cell:
        if (filter(cells_held) x: x == cell).length > places(cell): crowded = true
    c(not crowded, "walls: no more on a cell than its places ({cells_held})")
    // Still up there (once on their places): nobody shoves them about.
    steps(40)
    let ax = map(archers) uid: u_x[index_of(uid)]
    let ay = map(archers) uid: u_y[index_of(uid)]
    steps(40)
    var still = true
    for(archers) uid, n: still = still and u_x[index_of(uid)] == ax[n] and u_y[index_of(uid)] == ay[n]
    c(still, "walls: up there they stand still")
    // A foe a tile beyond an archer's reach, out in the field east of the wall: shot from up there.
    let a0 = index_of(archers[0])
    let reach = t_reach[u_kind[a0]]
    let rad = u_radius[a0]
    spawn_cmd(1, "spear", 1, u_x[a0] + reach + 700 + rad + 300, u_y[a0])
    var far_shot = false
    for(200):
        tick_on()
        for(events) e:
            if e.kind == EV_SHOT and contains(archers, e.a):
                let si = index_of(e.a)
                if isqrt(dist2(u_x[si], u_y[si], e.x, e.y)) > reach + 2 * rad + 200: far_shot = true
    c(far_shot, "walls: from the wall an archer reaches a tile further")
    // Spears under the wall can't hit those on it.
    let spears = map(4) k: lone(1, "spear", 19700, 7000 + k * 600, "aggressive")
    var melee_hits = 0
    for(300):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and contains(archers, e.b) and contains(spears, e.a): melee_hits++
    c(melee_hits == 0, "walls: spears below can\'t reach those on the wall ({melee_hits} hits)")
    for(spears) uid:
        if index_of(uid) >= 0: issue_cmd(1, CMD_STOP, [uid], 0, 0, 0, 0)
    // Down into the town.
    let stay = archers[5]
    let five = archers.slice(0, 5)
    issue_cmd(0, CMD_MOVE, five, 12500, 12000, 0, 0)
    for(900):
        tick_on()
        if all_down(five): break
    let inside = (filter(five) uid: in_town(uid)).length
    c(inside == 5, "walls: sent into the town, they climb down inside ({inside} of 5)")
    // A wall tile knocked down: rubble, and the one standing on it falls.
    var si = index_of(stay)
    let cell = u_perch[si] - 1
    knock_down(b_index_of(occupied[cell]))
    steps(3)
    si = index_of(stay)
    c(si >= 0 and u_perch[si] == 0, "walls: the archer on a fallen wall tile falls (and lives)")
    c(terrain_name(cell) == "wall_rubble" and walks[0][cell] == 1 and rubble.get(cell) != nil, "walls: a fallen wall tile is walkable rubble")
    c(rebuild_of(0, cell) == "wall", "walls: its owner may rebuild the wall there")
    let worker = spawn_at(0, "worker", 16500, 12500)
    let stone_r = res_of("stone")
    stock[stone_r][0] = 100
    var stone = stock[stone_r][0]
    let wk = btype_index("wall")
    issue_cmd(0, CMD_BUILD, [worker], wk, cell % W, cell / W, 0)
    for(600):
        tick_on()
        let nb = b_index_of(occupied[cell])
        if nb >= 0 and b_done[nb] == 1: break
    let paid = stone - stock[stone_r][0]
    let full = bt_cost[wk][stone_r]
    c(paid == full * rubble_repair_pct / 100, "walls: rebuilding a breach costs {rubble_repair_pct}% ({paid} of {full} stone)")
    let nb2 = b_index_of(occupied[cell])
    c(nb2 >= 0 and b_done[nb2] == 1 and terrain_name(cell) != "wall_rubble" and rubble.get(cell) == nil, "walls: the breach is walled up again, the rubble gone")
    // Repair: a wall at half health mended by the worker (paying some stone), and a ram.
    let wb = b_index_of(occupied[cell + W])
    let full_hp = bm_hp[0][b_kind[wb]]
    b_hp[wb] = full_hp / 2
    stone = stock[stone_r][0]
    let wb_id = b_id[wb]
    issue_cmd(0, CMD_REPAIR, [worker], wb_id, 0, 0, 0)
    for(2400):
        tick_on()
        if b_hp[b_index_of(wb_id)] >= full_hp: break
    let hp_now = b_hp[b_index_of(wb_id)]
    c(hp_now == full_hp, "walls: a worker mends a damaged wall ({hp_now} of {full_hp} hp)")
    c(stock[stone_r][0] < stone or full * r_repair_cost / 100 / 20 == 0, "walls: mending costs a little stone")
    // The frogs' ram is a beast (healers mend it, not carpenters); the rats' is a machine their workers mend.
    let turtle = lone(1, "ram", 40500, 40500, "passive")
    u_hp[index_of(turtle)] = 40
    c(not can_mend(1, turtle), "walls: a beast ram isn\'t for mending")
    let ram = lone(0, "ram", 16500, 13500, "passive")
    u_hp[index_of(ram)] = 40
    stock[res_of("wood")][0] = 500
    stock[res_of("gold")][0] = 500
    issue_cmd(0, CMD_REPAIR, [worker], ram, 0, 0, 0)
    steps(600)
    c(u_hp[index_of(ram)] > 60, "walls: a worker mends a machine ram (40 -> {u_hp[index_of(ram)]} hp)")
    return state_hash()

// Walls run straight over a hill: every wall and palisade piece of a line across Reed Meadow's team
// hill can go down, cliffs and ramps included; a gate never stands on a cliff, but still goes over a
// wall on flat ground.
def test_wall_over_hill():
    new_world("reed_meadow_2v2", [races0[1], races0[0], races0[1], races0[0]], bare0, [0, 1, 0, 1])
    ages[0] = 3
    let y = 18
    var slopes = 0
    for(["wall", "palisade"]) kind:
        let k = btype_index(kind)
        let refused = []::int
        for(19) n:
            let x = n + 10
            if not can_place(0, k, x, y): refused.push(x)
            if kind == "wall" and (cliff[y * W + x] == 1 or ramp[y * W + x] == 1): slopes++
        check(refused.length == 0, "wall over a hill: every {kind} piece of a line across the hill can go down (refused at x {refused})")
    check(slopes >= 4, "wall over a hill: the line crosses cliffs and ramps ({slopes} cells)")
    let wk = btype_index("wall")
    for(19) n: fort_put(0, wk, n + 10, y, 0)
    let gk = btype_index("stone_gate")
    var cliff_x = -1
    for(16) n:
        if cliff_x < 0 and cliff[y * W + n + 11] == 1: cliff_x = n + 11
    check(cliff_x > 0 and not can_place(0, gk, cliff_x - 1, y, 0) and not can_place(0, gk, cliff_x, y, 0), "wall over a hill: no gate over the wall on a cliff (x {cliff_x})")
    check(can_place(0, gk, 25, y, 0), "wall over a hill: a gate still goes over the wall on flat ground")

def test_walls():
    let rats_first = [races0[1], races0[0]]   // (the frogs build no stone walls of their own)
    let a = walls_run(rats_first, true)
    let b = walls_run(rats_first, false)
    check(a == b, "walls: the same commands give the same state hash")
    test_wall_over_hill()

// Ways over a wall: the rats (player 1) besiege the frogs' stone ring. A rat worker raises a ladder
// against the east wall (only against an enemy walkway); rat spears climb it onto the frogs' wall; a
// frog archer settling at its top with no rat there pushes it off. A siege tower pushed up to the
// south wall docks; rat swordsmen climb through it, and sent into the town they come down the
// frogs' own stairs inside. A manned gatehouse pours on a ram. Twice: the same hash.
def ways_run(checks_on:bool) -> int:
    new_world("flat_test", races0, rules0, [])
    in_age3()
    for(2) p:
        stock[res_of("wood")][p] = 2000
        stock[res_of("gold")][p] = 2000
    def c(ok:bool, what:string):
        if checks_on: check(ok, what)
    fortify_ring(0, 12, 12, 6, ring_spec(""))   // (no wall towers: they would shoot the rats)
    let lk = btype_index("ladder")
    c(can_place(1, lk, 19, 9) and not can_place(0, lk, 19, 9) and not can_place(1, lk, 21, 9), "siege ways: a ladder goes only against an enemy wall")
    let rat = lone(1, "worker", 22500, 9500, "passive")
    issue_cmd(1, CMD_BUILD, [rat], lk, 19, 9, 0)
    var ladder = 0
    for(600):
        tick_on()
        let b = b_index_of(occupied[9 * W + 19])
        if b >= 0 and b_done[b] == 1:
            ladder = b_id[b]
            break
    c(ladder != 0 and walks[0][9 * W + 19] == 1, "siege ways: the ladder goes up (walked over at the wall\'s foot)")
    let spears = map(3) k: lone(1, "spear", 23500, 8500 + k * 700, "stand")
    issue_cmd(1, CMD_MOVE, spears, 18500, 9500, 0, 0)
    for(600):
        tick_on()
        if count_up(spears) == spears.length: break
    c(count_up(spears) == spears.length, "siege ways: rat spears climb the ladder onto the frogs\' wall ({count_up(spears)} up)")
    // Down off the wall again by their ladder, then a frog archer takes the ladder's top: pushed off.
    issue_cmd(1, CMD_MOVE, spears, 23500, 9500, 0, 0)
    for(400):
        tick_on()
        if count_up(spears) == 0: break
    c(count_up(spears) == 0, "siege ways: they climb down their ladder")
    let archer = lone(0, "archer", 15500, 9500, "stand")
    issue_cmd(0, CMD_MOVE, [archer], 18500, 9500, 0, 0)
    var pushed = false
    for(600):
        tick_on()
        for(events) e:
            if e.kind == EV_DIE and e.a == ladder: pushed = true
        if pushed: break
    c(pushed and walks[0][9 * W + 19] == 1 and walk_over[9 * W + 19] == 0, "siege ways: a defender at its top pushes the ladder off")
    // A siege tower up to the south wall; swordsmen go up through it and down into the town.
    let tower = lone(1, "siege_tower", 15500, 23500, "passive")
    issue_cmd(1, CMD_MOVE, [tower], 15500, 18500, 0, 0)
    var docked = false
    for(600):
        tick_on()
        if docked_at(index_of(tower)) >= 0:
            docked = true
            break
    c(docked, "siege ways: the siege tower docks against the south wall")
    let swords = map(3) k: lone(1, "infantry", 14500 + k * 700, 24500, "stand")
    issue_cmd(1, CMD_MOVE, swords, 15500, 18500, 0, 0)
    for(600):
        tick_on()
        if count_up(swords) == swords.length: break
    c(count_up(swords) == swords.length, "siege ways: swordsmen climb through the tower onto the wall ({count_up(swords)} up)")
    issue_cmd(1, CMD_MOVE, swords, 11500, 14500, 0, 0)
    for(900):
        tick_on()
        if count_up(swords) == 0: break
    let inside = (filter(swords) uid: in_town(uid)).length
    c(inside == swords.length, "siege ways: sent into the town, they come down the frogs\' stairs inside ({inside} of {swords.length})")
    // The defenders' tools: a frog on the north gatehouse pours on a rat ram at the gate.
    let sentry = lone(0, "spear", 12500, 9500, "stand")
    issue_cmd(0, CMD_MOVE, [sentry], 12500, 6500, 0, 0)
    let ram = lone(1, "ram", 12500, 3000, "passive")
    issue_cmd(1, CMD_ATTACK, [ram], occupied[6 * W + 12], 0, 0, 0)
    var pours = 0
    var scalded = 0
    for(600):
        tick_on()
        var poured = false
        for(events) e:
            if e.kind == EV_HIT and b_index_of(e.a) >= 0:   // a hit from a building: a pour (towers shoot shots)
                poured = true
                if e.b == ram: scalded += e.c
        if poured: pours++
    c(pours >= 2 and scalded > 0, "siege ways: a manned gatehouse pours on the ram at its gate ({pours} pours, {scalded} damage)")
    return state_hash()

def test_siege_ways():
    let a = ways_run(true)
    let b = ways_run(false)
    check(a == b, "siege ways: the same commands give the same state hash")

// ------------------------------------------------------------------ game modes

def walled(p:int) -> int:
    var n = 0
    for(b_owner) o, b:
        if o == p and bt_walkway[b_kind[b]] > 0: n++
    return n

def up_count(p:int) -> int:
    var n = 0
    for(u_owner) o, i:
        if o == p and u_perch[i] != 0: n++
    return n

def mode_rules(mode:string) -> JV:
    let r = deep_copy(rules0)
    set(r, "mode", jstr(mode))
    return r

// Game modes on Siege Vale. Fortress: both sides in age 2 behind a stone ring with their garrison up
// on it, the stockpile set. Siege: player 0 walled in age 3, player 1 with an army and engines and no
// town; the attackers are out when the hold timer runs out, or when they've nothing left.
def test_modes():
    new_world("siege_vale", races0, mode_rules("fortress"), [])
    let fm = at(at(load_json(lib_root + "/modes.json"), "modes"), "fortress")
    for(2) p:
        check(ages[p] == 2 and walled(p) >= 50, "modes: Fortress walls side {p} in, in age 2 ({walled(p)} pieces)")
        let gar = at(fm, "garrison")
        check(up_count(p) == gint(gar, "archer", 0) + gint(gar, "skirmisher", 0), "modes: Fortress garrison side {p} up on its wall ({up_count(p)})")
        check(stock[res_of("stone")][p] == gint(at(fm, "stock"), "stone", -1), "modes: Fortress stockpile")
    let sr = mode_rules("siege")
    new_world("siege_vale", races0, sr, [])
    let h1 = state_hash()
    new_world("siege_vale", races0, sr, [])
    check(h1 == state_hash(), "modes: the same mode sets up the same")
    check(started_with_town[0] == 1 and started_with_town[1] == 0 and walled(0) >= 50 and walled(1) == 0, "modes: Siege walls the defenders in, the attackers have no town")
    var engines = 0
    for(u_owner) o, i:
        if o == 1 and has_s(["ram", "catapult", "siege_tower"], t_slot[u_kind[i]]): engines++
    check(engines >= 5 and ages[1] == 3, "modes: the attackers bring engines ({engines})")
    steps(60)
    check(winner < 0 and defeated[1] == 0, "modes: an attacker with an army is in the game")
    tick = mode_hold - 40
    steps(80)
    check(winner == teams[0], "modes: the defenders win when the hold timer runs out")
    new_world("siege_vale", races0, sr, [])
    var i = u_id.length - 1
    while i >= 0:
        if u_owner[i] == 1: remove_unit(i)
        i--
    steps(40)
    check(winner == teams[0], "modes: an attacker with nothing left is out")
    test_modes_lift_lacks()

// The modes fill the gap: a race that lacks walls (the centaurs) can't build or mend them in a normal
// match; in Siege and Fortress every side can, defenders and attackers alike, and rebuild a breach.
def test_modes_lift_lacks():
    let centaurs = gen_race("centaur romans")
    let both = [centaurs, centaurs]
    new_world("siege_vale", both, rules0, [])
    let ids = ["wall", "stone_gate", "wall_tower", "palisade"]
    let wk = btype_index("wall")
    check(bm_lacks[0][wk] != 0, "modes: the centaurs lack stone walls in a normal match (the case this tests)")
    for(["wall", "stone_gate", "palisade"]) id:
        check(bm_lacks[0][btype_index(id)] != 0 and build_barred(0, btype_index(id)), "modes: no {id} for centaurs in a normal match")
    fort_put(0, wk, 5, 5, 0)   // (one handed to them all the same)
    let nb = b_id[b_id.length - 1]
    b_hp[b_index_of(nb)] -= 100
    check(not can_mend(0, nb), "modes: centaurs can\'t mend a stone wall in a normal match")
    for(["siege", "fortress"]) mode:
        new_world("siege_vale", both, mode_rules(mode), [])
        for(2) p:
            for(ids) id: check(not build_barred(p, btype_index(id)), "modes: {mode} side {p} (centaurs) may build a {id}")
        var wall = -1
        for(b_owner) o, b:
            if wall < 0 and o == 0 and bt_name[b_kind[b]] == "wall": wall = b
        check(wall >= 0, "modes: {mode} walls the centaurs in")
        let id = b_id[wall]
        b_hp[wall] -= 100
        check(can_mend(0, id), "modes: {mode} centaurs may mend their stone wall")
        let cell = b_cy[wall] * W + b_cx[wall]
        knock_down(wall)
        tick_on()
        check(rebuild_of(0, cell) == "wall" and can_place(0, wk, cell % W, cell / W), "modes: {mode} centaurs may rebuild a breach in their wall")
    new_world("siege_vale", both, rules0, [])
    check(bm_lacks[0][wk] != 0, "modes: a mode\'s lift doesn\'t reach a later normal match\'s centaurs")

// ------------------------------------------------------------------ movement classes, the land, hills, flow patches

def terrain_index(name:string) -> int: return str_index(tr_names, name)

// A bare map (SimMap.load_id): the terrain and its walk grids, nothing set up on it (no bridge decks).
def bare_map(map_id:string):
    reset_world()
    due = []
    load_map(map_id)

// Flyers cross the lake straight; walkers go round; amphibians wade the shallows.
def test_movement_classes():
    let flyers = gen_race("flying greeks with wings")
    let rats = gen_race(PROMPTS[1])
    let frogs = gen_race(PROMPTS[0])
    new_world("flat_test", [flyers, rats, frogs], bare0, [0, 0, 0])
    let fx = 25500
    let fy = 32500
    let tx = 39500
    let ty = 32500
    spawn_cmd(0, "spear", 1, fx, fy)
    spawn_cmd(1, "spear", 1, fx, fy + 600)
    while u_id.length < 2: tick_on()
    check(u_mclass[0] == 2 and u_mclass[1] == 0, "winged hoplites fly, rats walk ({u_mclass[0]}, {u_mclass[1]})")
    issue_cmd(0, CMD_MOVE, [u_id[0]], tx, ty, 0, 0)
    issue_cmd(1, CMD_MOVE, [u_id[1]], tx, ty + 600, 0, 0)
    let arrived = [-1, -1]
    let walked = [0, 0]
    let lx = [u_x[0], u_x[1]]
    let ly = [u_y[0], u_y[1]]
    var over_water = false
    let water = terrain_index("water")
    let t0 = tick
    while tick < t0 + 2400 and (arrived[0] < 0 or arrived[1] < 0):
        tick_on()
        for(2) i:
            walked[i] += isqrt(dist2(u_x[i], u_y[i], lx[i], ly[i]))
            lx[i] = u_x[i]
            ly[i] = u_y[i]
            if arrived[i] < 0 and u_moving[i] == 0 and tick > t0 + 20: arrived[i] = tick - t0
        if terrain[cell_of(u_x[0], u_y[0])] == water: over_water = true
    check(over_water, "the flyer crossed over open water")
    let straight = tx - fx
    check(arrived[0] > 0 and walked[0] < straight * 11 / 10, "the flyer goes straight over the lake ({walked[0]} for {straight})")
    check(arrived[1] > 0 and walked[1] > straight * 115 / 100, "the walker goes round it ({walked[1]} for {straight})")
    // Amphibians wade the shallows; walkers stop at the edge.
    let shallows = terrain_index("shallows")
    var cell = -1
    for(W * H) c:
        if cell < 0 and terrain[c] == shallows: cell = c
    let ax, ay = centre(cell)
    spawn_cmd(2, "spear", 1, fx, fy)
    while u_id.length < 3: tick_on()
    let frog = u_id[2]
    let rat = u_id[1]
    check(u_mclass[2] == 1, "frogs are amphibious")
    issue_cmd(2, CMD_MOVE, [frog], ax, ay, 0, 0)
    issue_cmd(1, CMD_MOVE, [rat], ax, ay, 0, 0)
    steps(1600)
    let fi = index_of(frog)
    let ri = index_of(rat)
    check(terrain[cell_of(u_x[fi], u_y[fi])] == shallows, "the frog wades into the shallows")
    check(terrain[cell_of(u_x[ri], u_y[ri])] != shallows, "the rat stops at the water\'s edge")
    test_deep_river()
    test_flyers_and_walls(flyers, rats)

// Stone walls stop flyers; palisades don't (D-158). A wall line across the whole of flat_test keeps a
// flyer on its side; a palisade line it flies over. (The GDScript check of a save from before D-158,
// its walls marked on load, is left out: Lobster's saves are its own.)
def test_flyers_and_walls(flyers:JV, rats:JV):
    for(["wall", "palisade"]) kind:
        new_world("flat_test", [flyers, rats], bare0, [0, 1])
        ages[1] = 3
        let k = btype_index(kind)
        let y = 20
        for(W) x: place(1, k, x, y)
        var closed = 0
        for(W) x:
            if walks[FLYING][y * W + x] == 0: closed++
        if kind == "wall": check(closed == W, "flyers and walls: a stone wall is closed to flyers ({closed} of {W} cells)")
        else: check(closed == 0, "flyers and walls: a palisade is open to flyers ({closed} of {W} closed)")
        spawn_cmd(0, "spear", 1, 30500, 15500)
        while u_id.length < 1: tick_on()
        issue_cmd(0, CMD_MOVE, [u_id[0]], 30500, 26500, 0, 0)
        steps(600)
        let past = u_y[0] > (y + 1) * 1000
        check(past == (kind == "palisade"), "flyers and walls: the flyer {if past: "crosses" else: "stays behind"} the {kind} (y {u_y[0]})")

// Flood fill over a class's walk grid (8-way, no corner cutting), not into terrain `skip`.
def flood(mc:int, from_cell:int, skip:int) -> [int]:
    let seen = map(W * H): 0
    def ok(x:int, y:int) -> bool:
        if x < 0 or y < 0 or x >= W or y >= H: return false
        let c = y * W + x
        return walks[mc][c] == 1 and terrain[c] != skip
    seen[from_cell] = 1
    let todo = [from_cell]
    while todo.length:
        let c = todo.pop()
        let x = c % W
        let y = c / W
        for(N8) d:
            let n = (y + d.y) * W + x + d.x
            if ok(x + d.x, y + d.y) and seen[n] == 0 and not (d.x != 0 and d.y != 0 and not (ok(x + d.x, y) and ok(x, y + d.y))):
                seen[n] = 1
                todo.push(n)
    return seen

// Reed Meadow's rivers have a deep middle: no class gets across but at a ford or a bridge, and no
// flyer crosses a tree (bridge decks aren't laid on a bare map).
def test_deep_river():
    for(["reed_meadow", "reed_meadow_2v2"]) id:
        bare_map(id)
        let ford = terrain_index("ford")
        let tree = terrain_index("tree")
        let deep = terrain_index("deep_river")
        check(tr_move[tree] == 0 and tr_move[deep] == 0, "{id}: nobody crosses trees or the deep river")
        let a = cell_of(start_x[0], start_y[0])
        let b = cell_of(start_x[1], start_y[1])
        for(NUM_CLASSES) mc:
            let cut = flood(mc, a, ford)
            let joined = flood(mc, a, -1)
            check(cut[b] == 0 and joined[b] == 1, "{id}: {CLASS_NAMES[mc]} units cross the river only at a ford (cut {cut[b]}, with fords {joined[b]})")

// On river_test: trees block sight and movement until felled, then leave a walkable stump; walkers
// cross the river only at the ford or the bridge, a frog swims it anywhere; a bridge broken by attack
// is gone for walkers until workers rebuild it (paying wood).
def test_land():
    let rats = gen_race(PROMPTS[1])
    let frogs = gen_race(PROMPTS[0])
    new_world("river_test", [rats, frogs], bare0, [0, 0])   // allies: nobody fights
    let tree = terrain_index("tree")
    let river = terrain_index("river")
    let ford = terrain_index("ford")
    check(opaque[10 * W + 8] == 1, "land: a tree blocks sight")
    // Sight: a rat west of the forest sees the first tree, not past the forest.
    spawn_cmd(0, "spear", 1, 5500, 11500)
    while u_id.length < 1: tick_on()
    let rat = u_id[0]
    place_at(rat, 5500, 11500)
    steps(8)
    check(fog[0][11 * W + 8] == VISIBLE, "land: the first tree of the forest is seen")
    check(fog[0][11 * W + 12] != VISIBLE, "land: the ground behind the forest isn\'t")
    check(fog[0][8 * W + 5] == VISIBLE, "land: open ground round it is")
    // Crossing: every river cell the rat stands on is the ford or the bridge's deck.
    var cheat = false
    issue_cmd(0, CMD_MOVE, [rat], 30500, 11500, 0, 0)
    var t0 = tick
    while tick < t0 + 1600:
        tick_on()
        let ri = index_of(rat)
        let c = cell_of(u_x[ri], u_y[ri])
        if terrain[c] == river and deck[c] == 0: cheat = true
        if u_moving[ri] == 0 and tick > t0 + 20: break
    check(not cheat, "land: the rat never stands in the river")
    check(u_x[index_of(rat)] > 26000, "land: the rat got across (x {u_x[index_of(rat)]})")
    // A frog swims straight over.
    spawn_cmd(1, "spear", 1, 15500, 11500)
    while u_id.length < 2: tick_on()
    let frog = u_id[1]
    issue_cmd(1, CMD_MOVE, [frog], 25500, 11500, 0, 0)
    var swam = false
    t0 = tick
    while tick < t0 + 600:
        tick_on()
        let fi = index_of(frog)
        if terrain[cell_of(u_x[fi], u_y[fi])] == river: swam = true
    check(swam, "land: the frog swims the river")
    check(u_x[index_of(frog)] > 24000, "land: and gets across")
    // Break the bridge: rats attack it till it falls; then walkers can't use it.
    let bridge = br_id[0]
    spawn_cmd(0, "spear", 6, 24500, 16500)
    while u_id.length < 8: tick_on()
    issue_cmd(0, CMD_ATTACK, ids_of(0), bridge, 0, 0, 0)
    t0 = tick
    while tick < t0 + 6000 and br_up[0] == 1: tick_on()
    check(br_up[0] == 0, "land: the bridge falls (after {tick - t0} ticks)")
    let deck_cell = 16 * W + 20
    check(walks[0][deck_cell] == 0, "land: its deck is gone for walkers")
    check(walks[1][deck_cell] == 1, "land: amphibians still swim there")
    // Rebuild: workers pay and build; the deck is back.
    spawn_cmd(0, "worker", 2, 24500, 15500)
    while u_id.length < 10: tick_on()
    let builders = filter(ids_of(0)) uid: t_worker[u_kind[index_of(uid)]] != 0
    let wood = res_of("wood")
    stock[wood][0] = 200
    issue_cmd(0, CMD_HELP_BUILD, builders, bridge, 0, 0, 0)
    t0 = tick
    while tick < t0 + 3000 and br_up[0] == 0: tick_on()
    check(stock[wood][0] == 50, "land: the rebuild cost 150 wood ({stock[wood][0]} left)")
    check(br_up[0] == 1 and walks[0][deck_cell] == 1, "land: the workers rebuilt the bridge (in {tick - t0} ticks)")
    // Felling: a worker cuts the forest's first tree: wood, a stump, sight and a way through.
    let tc = 11 * W + 8
    amount[tc] = 3
    issue_cmd(0, CMD_GATHER, [builders[0]], tc, 0, 0, 0)
    t0 = tick
    while tick < t0 + 2000 and terrain[tc] == tree: tick_on()
    check(terrain_name(tc) == "stump" and walks[0][tc] == 1 and opaque[tc] == 0, "land: the felled tree is a walkable stump that doesn\'t block sight")
    check(terrain[5 * W + 20] == ford, "land: the map has its ford")

class Shot:
    hit:bool
    far:int
    dmg:int

// An archer of side 0 at (ax, ay) and a passive spear of side 1 `gap` milli-tiles (edge to edge) off
// along x; until the first shot lands: did it, how far the archer walked first, how hard.
def shoot(ax:int, g:int, ay:int) -> Shot:
    new_world("hill_test", races0, bare0, [])
    let a = lone(0, "archer", ax, ay, "aggressive")
    let t = lone(1, "spear", ax, ay + 4000, "passive")
    let ai = index_of(a)
    let ti = index_of(t)
    let r = u_radius[ai] + u_radius[ti]
    u_x[ai] = ax
    u_y[ai] = ay
    u_x[ti] = if g < 0: ax - (abs(g) + r) else: ax + g + r
    u_y[ti] = ay
    issue_cmd(0, CMD_ATTACK, [a], t, 0, 0, 0)
    let out = Shot { false, 0, 0 }
    for(400):
        tick_on()
        let i = index_of(a)
        out.far = max(out.far, abs(u_x[i] - ax) + abs(u_y[i] - ay))
        for(events) e:
            if e.kind == EV_HIT and e.a == a:
                out.hit = true
                out.dmg = e.c
        if out.hit: break
    return out

// Two small armies fight over the hill's ramp (attack-moves both ways): the hashes every 30 ticks.
def hill_match() -> [int]:
    new_world("hill_test", races0, bare0, [])
    spawn_cmd(0, "archer", 4, 6500, 12500)
    spawn_cmd(0, "spear", 4, 6500, 13500)
    spawn_cmd(1, "archer", 4, 16500, 12500)
    spawn_cmd(1, "spear", 4, 16500, 13500)
    steps(20)
    issue_cmd(0, CMD_ATTACK_MOVE, ids_of(0), 18500, 12500, 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, ids_of(1), 5500, 12500, 0, 0)
    let hashes = []::int
    for(1200):
        tick_on()
        if tick % HASH_EVERY == 0:
            hashes.push(tick)
            hashes.push(state_hash())
    return hashes

// On hill_test (high ground): cliffs block walkers but not flyers and can't be built on; walkers climb
// only by the ramp; shooters reach a level further down a hill and a level less far up it (and hit
// for less); from below you see a hill's rim, not its top; from on top you see further; the same
// fight twice gives the same hashes.
def test_hills():
    bare_map("hill_test")
    def cat(x:int, y:int) -> int: return y * W + x
    check(has_heights != 0 and level[cat(15, 9)] == 1 and level[cat(19, 8)] == 2, "hills: levels load")
    check(cliff[cat(13, 9)] == 1 and walks[0][cat(13, 9)] == 0, "hills: the foot of the west face is a cliff, closed to walkers")
    check(walks[2][cat(13, 9)] == 1, "hills: flyers cross the cliff")
    check(ramp[cat(13, 12)] == 1 and walks[0][cat(13, 12)] == 1 and cliff[cat(13, 12)] == 0, "hills: the ramp is open")
    check(cliff[cat(17, 7)] == 1 and cliff[cat(17, 8)] == 0, "hills: the knoll\'s face is a cliff, its ramp isn\'t")
    check(not can_build(12, 8, 2, 0, false, false) and not can_build(13, 11, 1, 0, false, false), "hills: nothing built on a cliff or a ramp")
    check(can_build(15, 12, 2, 0, false, false) and not can_build(16, 9, 3, 0, false, false), "hills: buildings stand on one level")
    let lv = copy(level)
    let cl = copy(cliff)
    bare_map("hill_test")
    check(equal(lv, level) and equal(cl, cliff), "hills: the map loads the same twice")
    // Climbing: a walker below the west face goes onto the plateau by the ramp, never on a cliff.
    new_world("hill_test", races0, bare0, [])
    let u = lone(0, "spear", 9500, 6500, "passive")
    issue_cmd(0, CMD_MOVE, [u], 16500, 6500, 0, 0)
    var on_cliff = false
    var by_ramp = false
    let t0 = tick
    while tick < t0 + 1200:
        tick_on()
        let i = index_of(u)
        let c = cell_of(u_x[i], u_y[i])
        on_cliff = on_cliff or cliff[c] == 1
        by_ramp = by_ramp or ramp[c] == 1
        if u_moving[i] == 0 and tick > t0 + 20: break
    let px, py = pos_of(u)
    check(not on_cliff, "hills: the walker never stands on a cliff")
    check(by_ramp, "hills: it went up by the ramp")
    check(level[cell_of(px, py)] == 1 and abs(px - 16500) < 1200, "hills: it got onto the plateau ({px},{py})")
    // Sight: from below at (11, 9) the rim (14, 9) is seen, the plateau beyond (16, 9) isn't; from on
    // top at (16, 9) the low ground 7 tiles off is (sight 6 + 1 for the level).
    place_at(u, 11500, 9500)
    steps(8)
    check(fog[0][cat(14, 9)] == VISIBLE, "hills: from below, the rim is seen")
    check(fog[0][cat(16, 9)] != VISIBLE, "hills: from below, the top beyond the rim isn\'t")
    check(fog[0][cat(11, 15)] == VISIBLE, "hills: open low ground round it is")
    place_at(u, 16500, 9500)
    steps(8)
    check(fog[0][cat(9, 9)] == VISIBLE, "hills: from on top you see further (7 tiles)")
    // Range: an archer reaches a level further down, a level less far up; uphill hits are weaker.
    let reach = t_reach[type_of_slot(0, "archer")]
    let down = shoot(14800, -(reach + 600), 6500)   // archer on top, target below, beyond its flat reach
    let up = shoot(12600, reach - 400, 6500)        // archer below, target on top, inside its flat reach
    let flat = shoot(9500, reach + 600, 16500)      // on the low ground, beyond reach
    check(down.hit and down.far < 200, "hills: shooting down, it hits from 600 beyond its reach without moving (moved {down.far})")
    check(up.hit and up.far > 300, "hills: shooting up, it must close in first (moved {up.far})")
    check(flat.hit and flat.far > 300, "hills: on the flat, the same gap needs closing (moved {flat.far})")
    check(up.dmg < flat.dmg, "hills: an uphill shot hits for less ({up.dmg} vs {flat.dmg})")
    check(uphill(8) == 6 and uphill(1) == 1, "hills: uphill damage is 75%, at least 1")
    // Determinism: the walkers' crossing onto the plateau, and the fight twice.
    test_crossing("hill_test", false)
    let a = hill_match()
    let b = hill_match()
    same_hashes(a, b, "hill_test fight")

// The cells a map change opened and closed in lane 0 since the last clear_fresh (then cleared).
def fresh_changes() -> [int], [int]:
    let opened = []::int
    let closed = []::int
    for(fresh) c, n:
        let was = fresh_was[n][0]
        if walks[0][c] != was:
            if walks[0][c] == 1: opened.push(c) else: closed.push(c)
    clear_fresh()
    return opened, closed

// A field patched for opened cells (trees felled, one by one and side by side) has the same costs as
// one solved from scratch on the changed map.
def test_flow_patch():
    new_world("river_test", races0, bare0, [])
    let target = 12 * W + 4
    let full = solve([target], INF, 0)
    let near = solve([target], NEAR_CUTOFF, 0)
    for([11 * W + 8, 11 * W + 9, 12 * W + 9, 10 * W + 10, 11 * W + 10]) c:
        clear_fresh()
        while amount[c] > 0: take(c)
        let opened, closed = fresh_changes()
        if opened.length:
            patch_opened(full, opened, 0, INF)
            patch_opened(near, opened, 0, INF)
        assert closed.length == 0
    let fresh_full = solve([target], INF, 0)
    let fresh_near = solve([target], NEAR_CUTOFF, 0)
    var same = 0
    var same_near = 0
    for(W * H) c:
        if full.dist[c] == fresh_full.dist[c]: same++
        if (near.dist[c] <= NEAR_CUTOFF) == (fresh_near.dist[c] <= NEAR_CUTOFF) and (near.dist[c] > NEAR_CUTOFF or near.dist[c] == fresh_near.dist[c]): same_near++
    check(same == W * H, "flow patch: a patched field matches a fresh solve ({same} of {W * H} cells)")
    check(same_near == W * H, "flow patch: a patched near field matches within its cutoff ({same_near} of {W * H})")
    var uphill_at = -1
    for(W * H) c:   // every step leads downhill to the target
        if uphill_at < 0 and full.dist[c] > 0 and full.dist[c] < INF and full.dist[full.next[c]] >= full.dist[c]: uphill_at = c
    check(uphill_at < 0, "flow patch: every step leads downhill (next of cell {uphill_at} goes uphill)")

// Fields patched for cells closing and opening together (buildings put up and pulled down, trees
// felled, over a big map) keep a fresh solve's costs, and every step still leads downhill.
def test_flow_patch_mixed():
    new_world("reed_meadow_2v2", [races0[0], races0[1], races0[0], races0[1]], bare0, [])
    let targets = [40 * W + 44, 10 * W + 12, 70 * W + 20]
    let fs = []::Flow
    let cuts = []::int
    for(targets) t:
        fs.push(solve([t], INF, 0))
        cuts.push(INF)
        fs.push(solve([t], NEAR_CUTOFF, 0))
        cuts.push(NEAR_CUTOFF)
    let r = new_rng(77)
    let standing = []::[int]   // footprints up
    var bad = 0
    var work = 0
    for(60) sn:
        let before = copy(walks[0])
        for(3):
            let roll = range_int(r, 0, 3 - 1)
            if roll == 0 or not standing.length:
                let cx = 2 + range_int(r, 0, W - 6 - 1)
                let cy = 2 + range_int(r, 0, H - 6 - 1)
                let cells = []::int
                for(3) dy:
                    for(3) dx:
                        let c = (cy + dy) * W + cx + dx
                        if not contains(targets, c) and occupied[c] == 0: cells.push(c)
                occupy(cells, 900 + sn)
                standing.push(cells)
            elif roll == 1:
                occupy(standing[0], 0)
                standing.remove(0)
            else:
                let c = resource_cells[range_int(r, 0, resource_cells.length - 1)]
                while amount[c] > 0: take(c)
        clear_fresh()
        let opened = []::int
        let closed = []::int
        for(W * H) c:
            if before[c] != walks[0][c]:
                if walks[0][c] == 1: opened.push(c) else: closed.push(c)
        for(fs) f:
            if closed.length: work += patch_closed(f, closed, 0, INF)
            if opened.length: work += patch_opened(f, opened, 0, INF)
    for(fs) f, k:
        let cut = cuts[k]
        let fresh_f = solve([targets[k / 2]], cut, 0)
        for(W * H) c:
            let a = f.dist[c]
            let b = fresh_f.dist[c]
            if (a <= cut or b <= cut) and a != b: bad++
            elif a > 0 and a <= cut and f.next[c] >= 0 and f.dist[f.next[c]] >= a: bad++
    check(bad == 0, "flow patch: fields patched through 180 closings and openings on the 2v2 map match fresh solves ({bad} cells off; {work} cells of work)")

// ------------------------------------------------------------------ the parts

let PARTS = ["fixed", "command_order", "source_lint", "flow", "crossing_flat", "crossing_choke", "crossing_engines",
             "opening", "combat", "shots", "engines", "trade", "sapper_sling", "gates", "diagonal_wall", "diagonal_gates",
             "walls", "siege_ways", "modes", "movement_classes", "land", "hills", "flow_patch", "flow_patch_mixed", "match", "match_b", "match_flipped"]

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
    elif name == "shots": test_shots()
    elif name == "engines": test_engines()
    elif name == "trade": test_trade()
    elif name == "sapper_sling": test_sapper_sling()
    elif name == "gates": test_gates()
    elif name == "diagonal_wall": test_diagonal_wall()
    elif name == "diagonal_gates": test_diagonal_gates()
    elif name == "walls": test_walls()
    elif name == "siege_ways": test_siege_ways()
    elif name == "modes": test_modes()
    elif name == "movement_classes": test_movement_classes()
    elif name == "land": test_land()
    elif name == "hills": test_hills()
    elif name == "flow_patch": test_flow_patch()
    elif name == "flow_patch_mixed": test_flow_patch_mixed()
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
