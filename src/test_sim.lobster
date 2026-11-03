// The sim's checks (tests/test_sim.gd, ported): determinism and tick time (a scripted 10-minute,
// 200-unit match played again, and with every race's keys reversed and its orders shuffled), movement,
// flow fields, the economy, combat, sieges, walls and the rest, part by part.
// Run from src:
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
// - Events the GDScript checks read that Lobster's sim doesn't send (wonder, won, farm_done, trade,
//   research, age, climb, fall, pour, blast) are read from the state instead (the Wonders' list and
//   the winner, the ground, the stock, researched, ages, perches, hits from a building).
// - Tech.why_not's messages become tech_barred / build_barred (barred or not; the reason isn't kept).
// - source_lint reads lib/*.lobster (the sim and the bots) for randomness, floats and clocks.
// Dropped, and why:
// - the float-leak checks: a Lobster Cmd holds typed ints, a float can't get in;
// - a replay's JSON round trip: a replay here is the list of Cmds, played again (that check stays);
// - the gate's look (BuildingArt.gate_open): view code, not the sim's;
// - saves from other builds (migrated stats, padded fields, a refused table, an older save's walls
//   marked for flyers by after_load): Lobster's saves are a flexbuffer of this build's globals;
// - the remembered ground and crops under the fog (fog_ground, fog_left): Lobster keeps only the
//   remembered buildings (fog_seen), which are checked;
// - the sapper: parked (D-128), as in GDScript (a check says so, to bring it back with the unit);
// - the save test's bot plays at the normal level (the hard level isn't ported).

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
import gen.effect_words

let SEED = 20261010
let PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers" ]
let TICKS = 12000      // 10 minutes at 20 Hz
let PER_PLAYER = 99    // soldiers a side, shared over its roster slots
let ORDERS_EVERY = 10  // turns between each player's orders (2 s)
let TICK_BUDGET_MS = 3.0
let HASH_EVERY = 30
let CMD_DELAY = 2
let CROSS_UNITS = 10      // per roster slot: 60 units, in 6 groups of 10
let CROSS_ENGINES = 3     // siege engines cross on their own
let CROSS_LIMIT = 2400    // ticks (2 minutes) to get everyone across
let OPENING_TICKS = 3600  // the 3-minute opening
let STALL_TICKS = 100     // a worker idle this long (5 s) has stalled
let SPAWN_JITTER = 400
let POSTURE_NAMES = [ "aggressive", "defensive", "stand", "passive" ]

// ------------------------------------------------------------------ checks

class SpawnOrder:
    run_tick:int
    player:int
    slot:string
    count:int
    x:int
    y:int

var due = []::SpawnOrder  // SPAWNs issued, waiting for their turn

var checks = 0
var failures = 0

def check(ok:bool, what:string):
    checks++
    if not ok:
        failures++
        print "FAIL: " + what

// ------------------------------------------------------------------ the races and rules (as test_sim.gd's _init)

lib_load("../data")
id_load("../data")
let rules0 = load_rules("default")
set(rules0, "animals", jbool(false))  // these tests count and move every unit; animals have their own test
let races0 = map(PROMPTS) p: generate(p, rules0, 0)

def bare_of(r:JV) -> JV:  // movement only: no town centres or starting workers
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
    events_on = true  // (the checks read them; they aren't state)

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

def fmt_ms(f:float) -> string:  // three decimals
    let us = int(f * 1000.0 + 0.5)
    let frac = string(us % 1000)
    return string(us / 1000) + "." + "000".substring(0, 3 - frac.length) + frac

// ------------------------------------------------------------------ small pieces

def test_fixed():
    var ok = true
    for(70000) n:
        let r = isqrt(n)
        if r * r > n or (r + 1) * (r + 1) <= n: ok = false
    for([ 1 << 31, (1 << 40) + 12345, 4000000000, 999999999999 ]) n:
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
    for([ 2, 0, 1 ]) player:
        for(4) sq:
            all.push(Cmd { tick, CMD_MOVE, player, 0, 0, 0, 0, [ 1 ], sq })
    pending = shuffled(new_rng(5), all)
    let order = map(take_pending()) c: c.player * 10 + c.seq
    check(equal(order, [ 0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23 ]), "commands run in (player, seq) order: {order}")
    check(take_pending().length == 0, "commands run once")

// Banned in lib/ (the sim and the bots): randomness but the sim's rng, floats, clocks.
let BANNED = [ "rnd(", "rnd_float", "rnd_gaussian", "rnd_seed", "rndm", "float", "seconds_elapsed", "time_",
               "sqrt(", "sin(", "cos(", "atan2(", "pow(", "lerp", "gl." ]

def has_decimal(code:string) -> bool:  // a float literal: digits '.' digits
    for(code.length) n:
        if n > 0 and n + 1 < code.length and code[n] == '.' and code[n - 1] >= '0' and code[n - 1] <= '9' and code[n + 1] >= '0' and code[n + 1] <= '9':
            return true
    return false

def ident_char(c:int) -> bool: return c == '_' or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')

def has_word(code:string, w:string) -> bool:  // w in code, not inside a longer name (isqrt isn't sqrt)
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
    let a = solve([ target ], INF, 0)
    let full_ms = (seconds_elapsed() - t0) * 1000.0
    solve([ 5 * W + 5 ], INF, 0)
    let b = solve([ target ], INF, 0)
    check(equal(a.dist, b.dist) and equal(a.next, b.next), "a flow field doesn\'t depend on what was solved before")
    var bad = 0
    for(a.dist) d, c:
        let reachable = d < INF
        if (walks[0][c] == 1) != reachable: bad++
        elif reachable and c != target and a.dist[a.next[c]] >= d: bad++
    check(bad == 0, "every walkable cell reaches the target downhill on flat_test ({bad} bad)")
    t0 = seconds_elapsed()
    let near = solve([ target ], 160, 0)
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
    for(glist(races0[0], "units")) u:  // the foot and horse lines, or (engines) the siege engines on their own
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
    orders:[Cmd]  // in run order: (run tick, player, seq)
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
    let sq = [ 0, 0 ]
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
    for(races.length) p:  // the economy: two workers on food, one on wood, two more trained, a house
        let tc = 1 + p * setup_ids
        let food_cell = nearest_res(start_x[p], start_y[p], "food")
        let wood_cell = nearest_res(start_x[p], start_y[p], "wood")
        cmd(0, p, CMD_GATHER, [ tc + 1, tc + 2 ], food_cell, 0, 0, 0)
        cmd(0, p, CMD_GATHER, [ tc + 3 ], wood_cell, 0, 0, 0)
        cmd(0, p, CMD_RALLY, [], tc, (food_cell % W) * 1000 + 500, (food_cell / W) * 1000 + 500, 0)
        let wk = type_of_slot(p, "worker")
        cmd(0, p, CMD_TRAIN, [], tc, wk, 1, 0)
        cmd(0, p, CMD_TRAIN, [], tc, wk, 1, 0)
        let hx, hy = house_spot(start_x[p], start_y[p])
        cmd(60, p, CMD_BUILD, [ tc + 3 ], house, hx, hy, 0)
    for(races.length) p:  // the armies arrive at 30 s, then march about
        for(glist(races[p], "units")) u:
            spawns.push(SpawnOrder { (150 + CMD_DELAY) * TICKS_PER_TURN, p, rstr(at(u, "recipe"), "slot"), per_slot, start_x[p], start_y[p] })
            sq[p]++
    for(races.length) p:  // a quarter of each army on each stance, so replays and hashes cover them
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
    hashes:[int]  // tick, hash pairs, flattened, every HASH_EVERY ticks
    ms:[float]    // per tick
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

def insertion_sort_f(s:[float]):  // (qsort recursion overflows on 12,000 near-equal times)
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

var match_hashes = []::int  // the first play's, for match_b and match_flipped run in the same process

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

let FIGHT_BUDGET = 600               // resources per side (food, wood and gold)
let FIGHT_LIMIT = 3000               // ticks (2.5 minutes)
let FIGHT_FROM_X = [ 11000, 21000 ]  // open ground on flat_test, 10 tiles apart
let FIGHT_FROM_Y = [ 20500, 20500 ]
// The counter chain (D-196): infantry > spear > large and mounted > ranged > infantry, and skirmishers > archers.
// (Not skirmishers > infantry: the roster gives swords +3 against skirmishers, who are for archers.)
// [counter, countered, the tag the countered unit needs for this to be the counter]. Each pair wins COUNTER_PCT of
// its equal-cost fights (every race, both sides), on its own: a strong pair can't carry a weak one.
let COUNTERS = [ [ "infantry", "spear", "spear" ], [ "spear", "large", "large" ], [ "spear", "scout", "mounted" ],
                 [ "spear", "mounted_archer", "mounted" ], [ "large", "archer", "ranged" ], [ "large", "skirmisher", "ranged" ],
                 [ "scout", "skirmisher", "skirmish" ], [ "archer", "infantry", "infantry" ], [ "archer", "spear", "infantry" ],
                 [ "skirmisher", "archer", "archer" ] ]
let COUNTER_PCT = 70
let COUNTER_PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
                        "greek hoplites", "royal knights", "viking beetle riders" ]

def gen_race(prompt:string) -> JV: return generate(prompt, rules0, 0)

def bare_world(races:[JV]): new_world("flat_test", races, bare0, [])

def posture_of(name:string) -> int: return find_index(POSTURE_NAMES, name)

def stance(p:int, ids:[int], name:string): issue_cmd(p, CMD_STANCE, ids, posture_of(name), 0, 0, 0)

// One unit of `slot` for p at (x, y) with a stance, settled in (test_sim.gd's _lone).
def lone(p:int, slot:string, x:int, y:int, name:string) -> int:
    let uid = spawn(p, slot, 1, x, y)[0]
    stance(p, [ uid ], name)
    steps(TICKS_PER_TURN * (CMD_DELAY + 1))
    return uid

def spawn_at(p:int, slot:string, x:int, y:int) -> int: return spawn(p, slot, 1, x, y)[0]

class Watch:
    far:int
    hits:[int]

// Steps the world, tracking how far unit `id` strays from (x, y) and the hits each side lands.
def watch_from(n:int, uid:int, x:int, y:int) -> Watch:
    let r = Watch { 0, [ 0, 0 ] }
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
    bare_world([ race, race ])
    let healer = spawn_at(0, "healer", 15000, 20500)
    let near = spawn_at(0, "spear", 17000, 20500)
    let far = spawn_at(0, "spear", 15000, 25500)  // 5 tiles off: within sight, out of range
    let foe = spawn_at(1, "spear", 13500, 21500)
    stance(0, [ near, far ], "passive")
    stance(1, [ foe ], "passive")
    let hi = index_of(healer)
    check(u_posture[hi] == PASSIVE, "heal: a healer spawns with the no-attack stance")
    check(as_int(at(su_type_eval[u_kind[hi]], "attack")) == 0, "heal: a healer has no attack")
    issue_cmd(0, CMD_ATTACK, [ healer ], foe, 0, 0, 0)
    steps(8)
    let full = t_hp[u_kind[index_of(near)]]
    for([ near, far, foe ]) uid: u_hp[index_of(uid)] = 4
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
    bare_world([ race, race ])
    let h2 = spawn_at(0, "healer", 15000, 20500)
    stance(0, [ h2 ], "aggressive")
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
    let atk = [ 5, 0, 0, 7 ]  // a spear: 5 melee, +7 vs large
    let arm = [ 2, 4, 0, 0 ]
    let plain = [ 1, 1, 0, 0 ]
    let large = [ 1, 1, 0, 1 ]
    check(damage(atk, arm, plain, 1) == 3, "melee 5 - armour 2 = 3")
    check(damage(atk, arm, large, 1) == 10, "the large bonus only lands on large targets (3 + 7)")
    check(damage(atk, [ 2, 4, 0, 3 ], large, 1) == 7, "class armour blunts a bonus (3 + 7 - 3)")
    check(damage([ 0, 4, 0, 0 ], [ 0, 9, 0, 0 ], plain, 1) == 1, "never less than the minimum")
    check(damage([ 0, 6, 0, 0 ], [ 9, 0, 0, 0 ], plain, 1) == 6, "pierce ignores melee armour")

// Idle soldiers near enemies fight without being told to.
def test_idle_fight():
    let race = gen_race(PROMPTS[0])
    bare_world([ race, race ])
    spawn_cmd(0, "spear", 5, 15000, 20500)
    spawn_cmd(1, "spear", 5, 18000, 20500)
    steps(1200)
    check(lost[0] + lost[1] > 0, "idle spearmen 3 tiles apart fight on their own ({lost[0] + lost[1]} lost)")

// Attack-move spreads out: 10 spearmen against 10 make many duels, not a pile-on.
def test_spread():
    let race = gen_race(PROMPTS[0])
    bare_world([ race, race ])
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
    new_world("flat_test", [ race, race, race, race ], bare0, [ 0, 0, 1, 1 ])
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
    new_world("flat_test", [ race, race ], rules0, [])
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
    new_world("flat_test", [ race, race ], r, [])
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
        let held = []::int  // id, x, y
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
    for([ "move", "attack_move", "queued" ]) kind:
        bare_world([ race, race ])
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
            let ahead = u_x[i] + u_y[i]  // along the way they went: down and right
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
    bare_world([ race, race ])
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
    for([ -1, 0 ]) pull:
        bare_world([ race, race ])
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
        stance(0, [ me ], "aggressive")
        steps(60)
        let want = if pull == 0: foot else: rider
        check(u_foe[index_of(me)] == want, "counter pick (pull {if pull < 0: "rules" else: "0"}): the spearman goes for the {if pull == 0: "footman" else: "rider"} (foe {u_foe[index_of(me)]}; footman {foot}, rider {rider})")

// The Norse shield wall: Norse shield infantry march shoulder to shoulder (form_gap), their riders
// don't, and the frogs keep the usual gap.
def test_shield_wall():
    let gaps = []::int
    for([ "vikings", PROMPTS[0] ]) prompt:
        let race = gen_race(prompt)
        bare_world([ race, race ])
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
    bare_world([ race, race ])
    var me = lone(0, "spear", 15000, y, "aggressive")
    lone(1, "spear", 20000, y, "passive")
    var r = watch(600, me)
    check(r.far > 1500 and r.hits[0] > 0, "aggressive: chases a foe 5 tiles off and hits it (went {r.far}, {r.hits[0]} hits)")
    check(r.hits[1] == 0, "passive: never hits back, even while being hit ({r.hits[1]} hits)")
    // Defensive: ignores a foe 5 tiles off; goes for one that comes near, chases it no further than
    // the leash, then walks back to where it stood.
    bare_world([ race, race ])
    me = lone(0, "spear", 15000, y, "defensive")
    let far = lone(1, "spear", 20000, y, "passive")
    let sx, sy = pos_of(me)
    r = watch(200, me)
    check(r.far < 300 and r.hits[0] == 0, "defensive: ignores a foe 5 tiles off (went {r.far})")
    issue_cmd(1, CMD_MOVE, [ far ], 16500, y, 0, 0)
    r = watch(100, me)
    check(r.hits[0] > 0, "defensive: goes for a foe that comes near ({r.hits[0]} hits)")
    issue_cmd(1, CMD_MOVE, [ far ], 40000, y, 0, 0)
    r = watch_from(600, me, sx, sy)
    let i = index_of(me)
    let home = isqrt(dist2(u_x[i], u_y[i], sx, sy))
    check(r.far > 2000 and r.far < r_leash + 1500, "defensive: chases a fleeing foe to the leash (went {r.far}, leash {r_leash})")
    check(home < 700 and u_foe[i] == 0 and u_moving[i] == 0, "defensive: then walks back to where it stood ({home} off)")
    // Stand ground, melee: never walks to a foe 2 tiles off, but fights one that comes to it.
    bare_world([ race, race ])
    me = lone(0, "spear", 15000, y, "stand")
    lone(1, "spear", 17000, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] == 0, "stand ground: doesn\'t walk to a foe 2 tiles off (went {r.far}, {r.hits[0]} hits)")
    lone(1, "spear", 16000, y, "aggressive")
    r = watch(400, me)
    check(r.hits[0] > 0 and r.far < 700, "stand ground: fights a foe that comes to it, where it stands (went {r.far}, {r.hits[0]} hits)")
    // Stand ground, ranged: shoots what is in reach, never steps closer to what isn't.
    bare_world([ race, race ])
    let reach = t_reach[type_of_slot(0, "archer")]
    me = lone(0, "archer", 15000, y, "stand")
    lone(1, "spear", 15000 + reach + 2500, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] == 0, "stand ground: an archer doesn\'t step towards a foe out of reach (went {r.far})")
    lone(1, "spear", 15000 + reach - 500, y, "passive")
    r = watch(300, me)
    check(r.far < 300 and r.hits[0] > 0, "stand ground: an archer shoots a foe in reach without moving ({r.hits[0]} hits)")
    // Passive: takes blows without answering; an explicit attack order still works.
    bare_world([ race, race ])
    me = lone(0, "spear", 15000, y, "passive")
    var foe = lone(1, "spear", 15800, y, "aggressive")
    r = watch(80, me)
    check(r.hits[1] > 0 and r.hits[0] == 0, "passive: takes {r.hits[1]} hits and answers none")
    issue_cmd(0, CMD_ATTACK, [ me ], foe, 0, 0, 0)
    r = watch(100, me)
    check(r.hits[0] > 0, "passive: an ordered attack still fights ({r.hits[0]} hits)")
    // Stand ground with an ordered target walks to it: orders beat stances.
    bare_world([ race, race ])
    me = lone(0, "spear", 15000, y, "stand")
    foe = lone(1, "spear", 19000, y, "passive")
    issue_cmd(0, CMD_ATTACK, [ me ], foe, 0, 0, 0)
    r = watch(400, me)
    check(r.far > 1500 and r.hits[0] > 0, "stand ground: an ordered attack walks to the target (went {r.far}, {r.hits[0]} hits)")

// Shooters stand still while their target is in reach; one out of reach walks just into reach and stops.
def test_ranged_holds():
    let race = gen_race("sewer rats with crossbows")
    let y = 20500
    bare_world([ race, race ])
    let k = type_of_slot(0, "archer")
    let reach = t_reach[k]
    let n_shots = 20 * t_reload[k]
    // Ordered, in reach: 20 shots without a step.
    var me = lone(0, "archer", 15000, y, "aggressive")
    var foe = lone(1, "large", 15000 + reach - 1000, y, "passive")
    u_hp[index_of(foe)] = 1 << 24
    issue_cmd(0, CMD_ATTACK, [ me ], foe, 0, 0, 0)
    var r = watch(n_shots, me)
    check(r.far == 0 and r.hits[0] >= 19, "an archer in reach doesn\'t move over 20 shots (went {r.far}, {r.hits[0]} hits)")
    // Ordered, out of reach: walks just into reach, then stands.
    bare_world([ race, race ])
    me = lone(0, "archer", 15000, y, "aggressive")
    foe = lone(1, "large", 15000 + reach + 3000, y, "passive")
    u_hp[index_of(foe)] = 1 << 24
    issue_cmd(0, CMD_ATTACK, [ me ], foe, 0, 0, 0)
    watch(200, me)
    let i = index_of(me)
    let g = gap(i, index_of(foe))
    r = watch(n_shots, me)
    check(g <= reach and g > reach - 2 * u_speed[i] and r.far == 0 and r.hits[0] >= 19, "an archer out of reach walks just into it and stands (gap {g} of reach {reach}, then went {r.far}, {r.hits[0]} hits)")
    // Attack-move, a line of shooters: the walk-back to the move's end no longer drags them on.
    bare_world([ race, race ])
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

// Its whole price: food, wood and gold (archers, infantry and the large lines pay part in gold, D-149; counting only
// food and wood fielded twice the archers their price buys).
def eval_cost(e:JV) -> int:
    var total = 0
    for(at(e, "cost").a) v: total += as_int(v)
    return total

// An equal-cost fight between two of a race's roster slots; `flip` swaps the sides. Both attack-move
// at each other; the side with more value left wins.
def counter_fight(race:JV, a_slot:string, b_slot:string, flip:int) -> bool, string:
    bare_world([ race, race ])
    let slots = [ a_slot, b_slot ]
    let value = [ 0, 0 ]
    for(2) side:
        let p = side ^ flip
        let cost = eval_cost(at(unit_of(race, slots[side]), "eval"))
        value[side] = cost
        spawn_cmd(p, slots[side], max(1, (FIGHT_BUDGET + cost / 2) / cost), FIGHT_FROM_X[p], FIGHT_FROM_Y[p])
    while u_id.length == 0: tick_on()
    for(2) p: issue_cmd(p, CMD_ATTACK_MOVE, ids_of(p), FIGHT_FROM_X[1 - p], FIGHT_FROM_Y[1 - p], 0, 0)
    var left = [ 0, 0 ]
    while tick < FIGHT_LIMIT:
        tick_on()
        left = [ 0, 0 ]
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
    let t0 = seconds_elapsed()
    let races = map(COUNTER_PROMPTS) prompt: gen_race(prompt)
    def has_slot(race:JV, slot:string) -> bool: return (filter(glist(race, "units")) u: rstr(at(u, "recipe"), "slot") == slot).length > 0
    for(COUNTERS) pair:
        var wins = 0
        var fights = 0
        for(races) race:
            if has_slot(race, pair[0]) and has_slot(race, pair[1]) and eval_has_tag(at(unit_of(race, pair[1]), "eval"), pair[2]):
                for(2) flip:
                    let won, note = counter_fight(race, pair[0], pair[1], flip)
                    fights++
                    if won: wins++
                    else: print "  counter lost: {rstr(race, "name")} {pair[0]} vs {pair[1]} (side {flip}): {note}"
        print "counters: {pair[0]} > {pair[1]}: {wins} of {fights}"
        if fights: check(wins * 100 >= fights * COUNTER_PCT, "{pair[0]} beats {pair[1]} in at least {COUNTER_PCT}% of equal-cost fights ({wins}/{fights})")
    print "counters: {ms_since(t0)} ms"

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
    issue_cmd(0, CMD_ATTACK, [ a ], t, 0, 0, 0)
    var shot_to = -1
    var shot_ticks = 0
    var fired = -1
    for(200):
        tick_on()
        for(events) e:
            if e.kind == EV_SHOT and e.a == a:
                shot_to = e.b
                shot_ticks = shots[SHOT_LAND] - (tick - 1)  // (the one shot in the air)
        if shot_to >= 0:
            fired = tick - 1  // the tick it was loosed in
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
    issue_cmd(0, CMD_ATTACK, [ s2 ], house, 0, 0, 0)
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
    let offs = [ [ 0, 0 ], [ 700, 0 ], [ 0, 700 ], [ 0, -700 ] ]
    let foes = map(offs) o: lone(1, "spear", 17000 + o[0], 20500 + o[1], "passive")
    let friend = lone(0, "spear", 16400, 20500, "passive")
    for(foes) f, k: place_at(f, 17000 + offs[k][0], 20500 + offs[k][1])
    place_at(friend, 16400, 20500)
    issue_cmd(0, CMD_ATTACK, [ cat ], foes[0], 0, 0, 0)
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
    issue_cmd(0, CMD_ATTACK, [ c2 ], near, 0, 0, 0)
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
    issue_cmd(0, CMD_ATTACK, [ ram ], sentry, 0, 0, 0)
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
    issue_cmd(1, CMD_ATTACK, [ archer ], ram, 0, 0, 0)
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
    for([ 14500, 15500, 16500 ]) x:
        let uid = lone(1, "spear", x, 20500, "passive")
        place_at(uid, x, 20500)
        line.push(uid)
    issue_cmd(0, CMD_ATTACK, [ bolt ], line[2], 0, 0, 0)
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
    issue_cmd(0, CMD_ROUTE, [ cart ], far, 0, 0, 0)
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
    issue_cmd(1, CMD_ATTACK, [ foe ], cart, 0, 0, 0)
    for(400):
        tick_on()
        if index_of(cart) < 0: break
    check(index_of(cart) < 0 and stock[g][0] == gold, "trade: a cart killed on its way home loses its load")
    // Unfinished and enemy markets aren't traded with.
    bare_world(races0)
    put(0, "market", 12, 30, 0)
    let ef = put(1, "market", 42, 30, 0)
    let c2 = spawn_at(0, "trader", 15500, 31500)
    issue_cmd(0, CMD_ROUTE, [ c2 ], ef, 0, 0, 0)
    steps(40)
    check(u_task[index_of(c2)] == T_NONE, "trade: no route to an enemy\'s market")
    new_world("flat_test", races0, bare0, [ 0, 0 ])
    put(0, "market", 12, 30, 0)
    let af = put(1, "market", 42, 30, 0)
    let c3 = spawn_at(0, "trader", 15500, 31500)
    issue_cmd(0, CMD_ROUTE, [ c3 ], af, 0, 0, 0)
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
    issue_cmd(0, CMD_ATTACK, [ sl ], house, 0, 0, 0)
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
    issue_cmd(0, CMD_MOVE, [ sl ], 8000, 21000, 0, 0)
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
        for([ int2 { k, 18 }, int2 { k, 26 }, int2 { 12, k + 6 }, int2 { 20, k + 6 } ]) c:
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
    for([ mine, theirs ]) uid: issue_cmd(u_owner[index_of(uid)], CMD_MOVE, [ uid ], 25500, 22500, 0, 0)
    steps(600)
    var i = index_of(mine)
    check(dist2(u_x[i], u_y[i], 25500, 22500) < 1000 * 1000, "gates: a friendly unit walks out through its gate ({u_x[i]}, {u_y[i]})")
    check(inside_square(theirs), "gates: an enemy shut in the square stays in")
    issue_cmd(0, CMD_MOVE, [ mine ], 16500, 21500, 0, 0)
    steps(600)
    check(inside_square(mine), "gates: ... and back in again")
    // Allies share the gate; the enemy knocks it down, and then the way is open to it.
    gate_id = gate_world([ races0[0], races0[1], races0[0] ], [ 0, 0, 1 ])
    let ally = spawn_in(1, "worker")
    issue_cmd(1, CMD_MOVE, [ ally ], 25500, 22500, 0, 0)
    let foe = spawn_in(2, "spear")
    issue_cmd(2, CMD_MOVE, [ foe ], 25500, 22500, 0, 0)
    steps(600)
    check(not inside_square(ally), "gates: an ally walks through too")
    check(inside_square(foe), "gates: the enemy spearman can\'t")
    issue_cmd(2, CMD_ATTACK, [ foe ], gate_id, 0, 0, 0)
    while tick < 8000 and b_index_of(gate_id) >= 0: tick_on()
    check(b_index_of(gate_id) < 0, "gates: the enemy knocks the gate down (tick {tick})")
    check(walks[lane_base[2]][gc] == 1, "gates: its tile is open to everyone again")
    issue_cmd(2, CMD_MOVE, [ foe ], 25500, 22500, 0, 0)
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
    issue_cmd(0, CMD_BUILD, [ builder ], k, 15, 18, 0)
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
        let c = [ int2 { 16 + q, 18 + q }, int2 { 22 - q, 24 + q }, int2 { 16 - q, 30 - q }, int2 { 10 + q, 24 - q } ][k / 6]
        put(1, "palisade", c.x, c.y, 0)

def in_diamond(uid:int) -> bool:
    let i = index_of(uid)
    return i >= 0 and abs(u_x[i] / 1000 - 16) + abs(u_y[i] / 1000 - 24) < 6

// A wall drawn diagonally still holds: a crowd inside sent out past it must stay in: the fields find
// no way out, and nobody slips between two corners on the move.
def test_diagonal_wall():
    new_world("flat_test", races0, bare0, [])
    diamond()
    let f = solve([ 24 * W + 16 ], INF, 0)
    check(f.dist[24 * W + 26] >= INF, "diagonal wall: no flow field reaches out of the diamond")
    let ids = map(12) n: spawn_at(0, [ "spear", "worker", "large" ][n % 3], 15000 + (n % 4) * 700, 23000 + (n / 4) * 700)
    for([ int2 { 16500, 15500 }, int2 { 25500, 24500 }, int2 { 16500, 33500 }, int2 { 6500, 24500 } ]) corner:
        issue_cmd(0, CMD_MOVE, ids, corner.x, corner.y, 0, 0)
        steps(400)
    let out = (filter(ids) uid: not in_diamond(uid)).length
    check(out == 0, "diagonal wall: a crowd pushed at every side of a corner-to-corner wall stays in ({out} got out)")
    // The movement rule on its own: a unit right at the corner between two wall tiles, stepping
    // diagonally through the gap point, is stopped (no field to help it).
    place_at(ids[0], 21960, 24040)  // in tile (21, 24), inside, by the point where (21, 23) and (22, 24) touch
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
    issue_cmd(1, CMD_BUILD, [ builder ], k, 17, 19, 2)
    issue_cmd(1, CMD_BUILD, [ builder ], k, 19, 25, 3, 1)
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
    let open = [ int2 { 18, 19 }, int2 { 19, 19 }, int2 { 17, 20 }, int2 { 17, 21 }, int2 { 20, 25 }, int2 { 19, 26 }, int2 { 21, 26 } ]
    check(not exists(open) c: occupied[c.y * W + c.x] != 0 or walks[0][c.y * W + c.x] != 1, "diagonal gates: the rest of its square is open ground")
    // Fields: none out of the diamond for side 0; out for side 1, through the gates.
    let f0 = solve([ 24 * W + 16 ], INF, lane_base[0])
    check(f0.dist[24 * W + 26] >= INF, "diagonal gates: no field leads the enemy out (no corner slipped at the gates\' ends)")
    let f1 = solve([ 24 * W + 16 ], INF, lane_base[1])
    check(f1.dist[18 * W + 21] < INF and f1.dist[29 * W + 22] < INF, "diagonal gates: the owner\'s field goes out through both")
    // Side 1 walks out through each gate and back in; side 0's crowd pushed at them stays in.
    let friends = map(3) n: spawn_at(1, [ "spear", "worker", "large" ][n], 15500 + n * 700, 23500)
    for([ int2 { 21000, 18000 }, int2 { 23000, 29000 } ]) dest:
        issue_cmd(1, CMD_MOVE, friends, dest.x, dest.y, 0, 0)
        steps(700)
        let out = (filter(friends) uid: index_of(uid) >= 0 and dist2(u_x[index_of(uid)], u_y[index_of(uid)], dest.x, dest.y) < 2000 * 2000).length
        check(out == friends.length, "diagonal gates: side 1 walks out through its gate to ({dest.x}, {dest.y}) ({out} of {friends.length})")
        issue_cmd(1, CMD_MOVE, friends, 16500, 24500, 0, 0)
        steps(700)
        check(not exists(friends) uid: not in_diamond(uid), "diagonal gates: ... and back in")
    for(friends.append([ builder ])) uid:  // (side 0 would fight them)
        if index_of(uid) >= 0: remove_unit(index_of(uid))
    let crowd = map(9) n: spawn_at(0, [ "spear", "worker", "large" ][n % 3], 15000 + (n % 3) * 700, 25000 + (n / 3) * 700)
    for([ int2 { 21000, 18000 }, int2 { 23000, 29000 } ]) dest:
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
    issue_cmd(0, CMD_ATTACK, [ foe ], g1, 0, 0, 0)
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
    set(spec, "gates", jstrs([ "n", "s" ]))
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

def all_down(ids:[int]) -> bool:  // each gone, or off the wall and standing
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
        if index_of(uid) >= 0: issue_cmd(1, CMD_STOP, [ uid ], 0, 0, 0, 0)
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
    issue_cmd(0, CMD_BUILD, [ worker ], wk, cell % W, cell / W, 0)
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
    issue_cmd(0, CMD_REPAIR, [ worker ], wb_id, 0, 0, 0)
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
    issue_cmd(0, CMD_REPAIR, [ worker ], ram, 0, 0, 0)
    steps(600)
    c(u_hp[index_of(ram)] > 60, "walls: a worker mends a machine ram (40 -> {u_hp[index_of(ram)]} hp)")
    return state_hash()

// Walls run straight over a hill: every wall and palisade piece of a line across Reed Meadow's team
// hill can go down, cliffs and ramps included; a gate never stands on a cliff, but still goes over a
// wall on flat ground.
def test_wall_over_hill():
    new_world("reed_meadow_2v2", [ races0[1], races0[0], races0[1], races0[0] ], bare0, [ 0, 1, 0, 1 ])
    ages[0] = 3
    let y = 18
    var slopes = 0
    for([ "wall", "palisade" ]) kind:
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
    let rats_first = [ races0[1], races0[0] ]  // (the frogs build no stone walls of their own)
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
    fortify_ring(0, 12, 12, 6, ring_spec(""))  // (no wall towers: they would shoot the rats)
    let lk = btype_index("ladder")
    c(can_place(1, lk, 19, 9) and not can_place(0, lk, 19, 9) and not can_place(1, lk, 21, 9), "siege ways: a ladder goes only against an enemy wall")
    let rat = lone(1, "worker", 22500, 9500, "passive")
    issue_cmd(1, CMD_BUILD, [ rat ], lk, 19, 9, 0)
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
    issue_cmd(0, CMD_MOVE, [ archer ], 18500, 9500, 0, 0)
    var pushed = false
    for(600):
        tick_on()
        for(events) e:
            if e.kind == EV_DIE and e.a == ladder: pushed = true
        if pushed: break
    c(pushed and walks[0][9 * W + 19] == 1 and walk_over[9 * W + 19] == 0, "siege ways: a defender at its top pushes the ladder off")
    // A siege tower up to the south wall; swordsmen go up through it and down into the town.
    let tower = lone(1, "siege_tower", 15500, 23500, "passive")
    issue_cmd(1, CMD_MOVE, [ tower ], 15500, 18500, 0, 0)
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
    issue_cmd(0, CMD_MOVE, [ sentry ], 12500, 6500, 0, 0)
    let ram = lone(1, "ram", 12500, 3000, "passive")
    issue_cmd(1, CMD_ATTACK, [ ram ], occupied[6 * W + 12], 0, 0, 0)
    var pours = 0
    var scalded = 0
    for(600):
        tick_on()
        var poured = false
        for(events) e:
            if e.kind == EV_HIT and b_index_of(e.a) >= 0:  // a hit from a building: a pour (towers shoot shots)
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
        if o == 1 and has_s([ "ram", "catapult", "siege_tower" ], t_slot[u_kind[i]]): engines++
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
    let both = [ centaurs, centaurs ]
    new_world("siege_vale", both, rules0, [])
    let ids = [ "wall", "stone_gate", "wall_tower", "palisade" ]
    let wk = btype_index("wall")
    check(bm_lacks[0][wk] != 0, "modes: the centaurs lack stone walls in a normal match (the case this tests)")
    for([ "wall", "stone_gate", "palisade" ]) id:
        check(bm_lacks[0][btype_index(id)] != 0 and build_barred(0, btype_index(id)), "modes: no {id} for centaurs in a normal match")
    fort_put(0, wk, 5, 5, 0)  // (one handed to them all the same)
    let nb = b_id[b_id.length - 1]
    b_hp[b_index_of(nb)] -= 100
    check(not can_mend(0, nb), "modes: centaurs can\'t mend a stone wall in a normal match")
    for([ "siege", "fortress" ]) mode:
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
    new_world("flat_test", [ flyers, rats, frogs ], bare0, [ 0, 0, 0 ])
    let fx = 25500
    let fy = 32500
    let tx = 39500
    let ty = 32500
    spawn_cmd(0, "spear", 1, fx, fy)
    spawn_cmd(1, "spear", 1, fx, fy + 600)
    while u_id.length < 2: tick_on()
    check(u_mclass[0] == 2 and u_mclass[1] == 0, "winged hoplites fly, rats walk ({u_mclass[0]}, {u_mclass[1]})")
    issue_cmd(0, CMD_MOVE, [ u_id[0] ], tx, ty, 0, 0)
    issue_cmd(1, CMD_MOVE, [ u_id[1] ], tx, ty + 600, 0, 0)
    let arrived = [ -1, -1 ]
    let walked = [ 0, 0 ]
    let lx = [ u_x[0], u_x[1] ]
    let ly = [ u_y[0], u_y[1] ]
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
    issue_cmd(2, CMD_MOVE, [ frog ], ax, ay, 0, 0)
    issue_cmd(1, CMD_MOVE, [ rat ], ax, ay, 0, 0)
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
    for([ "wall", "palisade" ]) kind:
        new_world("flat_test", [ flyers, rats ], bare0, [ 0, 1 ])
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
        issue_cmd(0, CMD_MOVE, [ u_id[0] ], 30500, 26500, 0, 0)
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
    let todo = [ from_cell ]
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
    for([ "reed_meadow", "reed_meadow_2v2" ]) id:
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
    new_world("river_test", [ rats, frogs ], bare0, [ 0, 0 ])  // allies: nobody fights
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
    issue_cmd(0, CMD_MOVE, [ rat ], 30500, 11500, 0, 0)
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
    issue_cmd(1, CMD_MOVE, [ frog ], 25500, 11500, 0, 0)
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
    issue_cmd(0, CMD_GATHER, [ builders[0] ], tc, 0, 0, 0)
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
    issue_cmd(0, CMD_ATTACK, [ a ], t, 0, 0, 0)
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
    issue_cmd(0, CMD_MOVE, [ u ], 16500, 6500, 0, 0)
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
    let down = shoot(14800, -(reach + 600), 6500)  // archer on top, target below, beyond its flat reach
    let up = shoot(12600, reach - 400, 6500)       // archer below, target on top, inside its flat reach
    let flat = shoot(9500, reach + 600, 16500)     // on the low ground, beyond reach
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
    let full = solve([ target ], INF, 0)
    let near = solve([ target ], NEAR_CUTOFF, 0)
    for([ 11 * W + 8, 11 * W + 9, 12 * W + 9, 10 * W + 10, 11 * W + 10 ]) c:
        clear_fresh()
        while amount[c] > 0: take(c)
        let opened, closed = fresh_changes()
        if opened.length:
            patch_opened(full, opened, 0, INF)
            patch_opened(near, opened, 0, INF)
        assert closed.length == 0
    let fresh_full = solve([ target ], INF, 0)
    let fresh_near = solve([ target ], NEAR_CUTOFF, 0)
    var same = 0
    var same_near = 0
    for(W * H) c:
        if full.dist[c] == fresh_full.dist[c]: same++
        if (near.dist[c] <= NEAR_CUTOFF) == (fresh_near.dist[c] <= NEAR_CUTOFF) and (near.dist[c] > NEAR_CUTOFF or near.dist[c] == fresh_near.dist[c]): same_near++
    check(same == W * H, "flow patch: a patched field matches a fresh solve ({same} of {W * H} cells)")
    check(same_near == W * H, "flow patch: a patched near field matches within its cutoff ({same_near} of {W * H})")
    var uphill_at = -1
    for(W * H) c:  // every step leads downhill to the target
        if uphill_at < 0 and full.dist[c] > 0 and full.dist[c] < INF and full.dist[full.next[c]] >= full.dist[c]: uphill_at = c
    check(uphill_at < 0, "flow patch: every step leads downhill (next of cell {uphill_at} goes uphill)")

// Fields patched for cells closing and opening together (buildings put up and pulled down, trees
// felled, over a big map) keep a fresh solve's costs, and every step still leads downhill.
def test_flow_patch_mixed():
    new_world("reed_meadow_2v2", [ races0[0], races0[1], races0[0], races0[1] ], bare0, [])
    let targets = [ 40 * W + 44, 10 * W + 12, 70 * W + 20 ]
    let fs = []::Flow
    let cuts = []::int
    for(targets) t:
        fs.push(solve([ t ], INF, 0))
        cuts.push(INF)
        fs.push(solve([ t ], NEAR_CUTOFF, 0))
        cuts.push(NEAR_CUTOFF)
    let r = new_rng(77)
    let standing = []::[int]  // footprints up
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
        let fresh_f = solve([ targets[k / 2] ], cut, 0)
        for(W * H) c:
            let a = f.dist[c]
            let b = fresh_f.dist[c]
            if (a <= cut or b <= cut) and a != b: bad++
            elif a > 0 and a <= cut and f.next[c] >= 0 and f.dist[f.next[c]] >= a: bad++
    check(bad == 0, "flow patch: fields patched through 180 closings and openings on the 2v2 map match fresh solves ({bad} cells off; {work} cells of work)")

// ------------------------------------------------------------------ economy: farms, builders, drop-offs

def own_workers_of(p:int) -> [int]: return filter(ids_of(p)) uid: t_worker[u_kind[index_of(uid)]] != 0

// A unit of type k put down beside building b (Economy.spawn_at).
def spawn_by(b:int, k:int) -> int:
    let c = spawn_cell(b, k)
    let i = add_unit(b_owner[b], k, (c % W) * TILE + 500, (c / W) * TILE + 500)
    grow_scratch()
    return u_id[i]

def kind_of(name:string) -> int: return res_of(name) + 1

// Is unit `uid` working farm `farm` (its pool's first cell)?
def farming(uid:int, farm:int) -> bool:
    let i = index_of(uid)
    let h = u_home[i]
    return (u_task[i] == GATHER or u_task[i] == T_RETURN) and h >= 0 and pool[h] == farm

def builder_class(p:int) -> int: return t_mclass[worker_type(p)]

def bt_reseed_wood(k:int) -> int: return bt_reseed[k][res_of("wood")]

// A second farm beside farm cell a (3-5 tiles over, wherever there's room), or -1.
def farm_beside(a:int) -> int:
    let fk = btype_index("farm")
    for([ 3, 4, 5, -3, -4, -5 ]) d:
        for([ a + d, a + d * W ]) c:
            if can_place(0, fk, c % W, c / W): return c
    return -1

// One farmer per farm: a second worker sent to a worked farm takes a free farm nearby (else other
// food, else waits by it); a farm its farmer leaves is picked up again.
def test_one_farmer():
    new_world("flat_test", races0, rules0, [])
    stock[1][0] = 1000
    let sx = start_x[0]
    let sy = start_y[0]
    var tc = -1
    for(b_owner) o, b:
        if o == 0: tc = b
    for(3): spawn_by(tc, type_of_slot(0, "worker"))
    let ids = ids_of(0)
    let field = terrain_index("field")
    let a = (sy / 1000 + 2) * W + sx / 1000 + 3
    let fk = btype_index("farm")
    let b2 = farm_beside(a)
    check(b2 >= 0 and can_place(0, fk, a % W, a / W), "one farmer: room for two farms")
    issue_cmd(0, CMD_BUILD, [ ids[0] ], fk, a % W, a / W, 0)
    while tick < 1600 and terrain[a] != field: tick_on()
    issue_cmd(0, CMD_BUILD, [ ids[1] ], fk, b2 % W, b2 / W, 0)
    while tick < 3200 and terrain[b2] != field: tick_on()
    check(terrain[a] == field and terrain[b2] == field, "one farmer: both farms are sown")
    check(farming(ids[0], a) and farming(ids[1], b2), "one farmer: each farm\'s builder farms it")
    var rival = -1
    for(u_owner) o, i:
        if rival < 0 and o == 1 and t_worker[u_kind[i]] != 0: rival = i
    check(taken(a, rival), "farms: a rival\'s worker can\'t work your farm")
    check(taken(a, -1) and taken(a + 1, -1), "one farmer: a worked farm is taken (any of its tiles)")
    // A third worker sent to the first farm doesn't join its farmer.
    issue_cmd(0, CMD_GATHER, [ ids[2] ], a + 1, 0, 0, 0)
    steps(20)
    let i2 = index_of(ids[2])
    check(not farming(ids[2], a) and not farming(ids[2], b2) and u_task[i2] == GATHER, "one farmer: a second worker sent to a worked farm goes elsewhere (home {u_home[i2]})")
    // The second farmer walks off: the next worker sent to the first farm takes the freed one.
    issue_cmd(0, CMD_MOVE, [ ids[1] ], sx - 3000, sy, 0, 0)
    issue_cmd(0, CMD_GATHER, [ ids[3] ], a, 0, 0, 0)
    steps(20)
    check(farming(ids[3], b2), "one farmer: a farm its farmer left is picked up by the next worker sent near it")
    check(farming(ids[0], a), "one farmer: the first farm keeps its farmer")
    // With no free farm and no other food about, a worker waits by a full farm and takes it once its farmer goes.
    let food = kind_of("food")
    for(resource_cells) c:
        if pool[c] < 0 and tr_res[terrain[c]] == food: amount[c] = 0
    let i4 = index_of(ids[4])
    u_task[i4] = GATHER
    u_carry_kind[i4] = food
    u_target[i4] = a
    u_home[i4] = -1
    steps(40)
    check(not farming(ids[4], a), "one farmer: a worker waiting by a worked farm doesn\'t join its farmer")
    issue_cmd(0, CMD_MOVE, [ ids[0] ], sx - 3000, sy + 2000, 0, 0)
    steps(40)
    check(farming(ids[4], a), "one farmer: a worker waiting by a farm takes it when its farmer leaves")

// Step until farm cell a, nearly worked out (1 food left), is done: worked out (fallow) or sown
// again. (The GDScript checks read a farm_done event; Lobster's sim has none, so the ground tells.)
def drain(a:int) -> bool:
    amount[pool[a]] = 1
    let t0 = tick
    while tick < t0 + 600:
        tick_on()
        if left_at(a) != 1: return true
    return false

// Auto-reseed: on by default, a worked-out farm is sown again at once (for its reseed cost) and its
// farmer farms on; without the wood the farmer waits by it and it reseeds when the wood comes in;
// with it off, the farmer moves to a free farm nearby. Never off to other work.
def test_auto_reseed():
    new_world("flat_test", races0, rules0, [])
    stock[1][0] = 1000
    let sx = start_x[0]
    let sy = start_y[0]
    let ids = ids_of(0)
    let field = terrain_index("field")
    let fallow_t = terrain_index("fallow")
    let a = (sy / 1000 + 2) * W + sx / 1000 + 3
    let fk = btype_index("farm")
    let b2 = farm_beside(a)
    issue_cmd(0, CMD_BUILD, [ ids[0] ], fk, a % W, a / W, 0)
    while tick < 1600 and terrain[a] != field: tick_on()
    check(auto_reseed[0] == 1, "auto-reseed: on by default")
    let wood = stock[1][0]
    check(drain(a), "auto-reseed: a farm is worked out")
    check(terrain[a] == field and left_at(a) > 1, "auto-reseed: the farm is sown again at once ({left_at(a)} food)")
    check(wood - stock[1][0] == bt_reseed_wood(fk), "auto-reseed: it costs the reseed ({wood - stock[1][0]} wood)")
    steps(100)
    check(farming(ids[0], a), "auto-reseed: the farmer farms on")
    // No wood: it lies fallow and the farmer waits by it, then the wood comes in.
    stock[1][0] = 0
    check(drain(a) and terrain[a] == fallow_t, "auto-reseed: without the wood it lies fallow")
    steps(300)
    let i0 = index_of(ids[0])
    let near_farm = abs(u_x[i0] / 1000 - a % W) <= 3 and abs(u_y[i0] / 1000 - a / W) <= 3
    check(farming(ids[0], a) and u_carry[i0] == 0 and near_farm, "auto-reseed: its farmer waits by it, not off to other work (at {u_x[i0] / 1000},{u_y[i0] / 1000})")
    stock[1][0] = 100
    steps(WAIT_TICKS + 2)
    check(terrain[a] == field and stock[1][0] == 100 - bt_reseed_wood(fk), "auto-reseed: with the wood in, it\'s sown again")
    let food = stock[0][0]
    steps(600)
    check(farming(ids[0], a) and stock[0][0] > food, "auto-reseed: ...and farmed ({food} -> {stock[0][0]} food)")
    // Off, with a free farm nearby: the farmer moves over to it.
    issue_cmd(0, CMD_BUILD, [ ids[1] ], fk, b2 % W, b2 / W, 0)
    while tick < 6000 and terrain[b2] != field: tick_on()
    issue_cmd(0, CMD_MOVE, [ ids[1] ], sx - 4000, sy, 0, 0)
    issue_cmd(0, CMD_AUTO_RESEED, [], 0, 0, 0, 0)
    steps(12)
    check(auto_reseed[0] == 0, "auto-reseed: the player turns it off")
    check(drain(a) and terrain[a] == fallow_t, "auto-reseed: off, the farm lies fallow")
    steps(200)
    check(farming(ids[0], b2), "auto-reseed: off, its farmer takes the free farm nearby")

// A farm becomes a crop field its builder harvests; amphibians may farm the shallows (a rice paddy);
// other races can't build on water. Stone is mined.
def test_farms():
    new_world("flat_test", races0, rules0, [])
    stock[1][0] = 1000
    stock[1][1] = 1000
    let sx = start_x[0]
    let sy = start_y[0]
    let worker = ids_of(0)[0]
    let cx = sx / 1000 + 3
    let cy = sy / 1000 + 2
    let fk = btype_index("farm")
    issue_cmd(0, CMD_BUILD, [ worker ], fk, cx, cy, 0)
    let field = terrain_index("field")
    while tick < 1600 and terrain[cy * W + cx] != field: tick_on()
    check(terrain[cy * W + cx] == field, "farm: the frogs\' farm became a field")
    let food_before = stock[0][0]
    steps(1200)
    let i = index_of(worker)
    check(u_carry_kind[i] == 1 and (u_task[i] == GATHER or u_task[i] == T_RETURN), "farm: its builder farms it")
    check(stock[0][0] > food_before, "farm: food comes in from the field ({food_before} -> {stock[0][0]})")
    // One farm, one pool: its four tiles share one amount, units walk across it, and worked out it
    // lies fallow until a worker reseeds it (for wood).
    let cells = [ cy * W + cx, cy * W + cx + 1, (cy + 1) * W + cx, (cy + 1) * W + cx + 1 ]
    check(not exists(cells) c: left_at(c) != left_at(cells[0]), "farm: its tiles share one pool of food ({left_at(cells[0])})")
    check(not exists(cells) c: walks[0][c] != 1, "farm: units can walk across it")
    let farm_id = occupied[cells[0]]
    check(farm_id != 0, "farm: the farm stays standing after it\'s sown")
    issue_cmd(0, CMD_AUTO_RESEED, [], 0, 0, 0, 0)  // by hand here; auto-reseed has its own test
    steps(12)
    amount[cells[0]] = 1  // nearly worked out
    while tick < 6000 and left_at(cells[0]) > 0: tick_on()
    let fallow_t = terrain_index("fallow")
    check(terrain[cells[0]] == fallow_t and occupied[cells[0]] == farm_id, "farm: worked out, it lies fallow (and is still a farm)")
    let wood_before = stock[1][0]
    issue_cmd(0, CMD_RESEED, [ worker ], farm_id, 0, 0, 0)
    steps(12)
    check(terrain[cells[0]] == field and left_at(cells[0]) > 0, "farm: reseeding brings the crops back")
    check(stock[1][0] < wood_before, "farm: reseeding costs wood ({wood_before} -> {stock[1][0]})")
    // Water: a 2x2 of shallows.
    let sh = terrain_index("shallows")
    var spot_x = -1
    var spot_y = -1
    for(H - 1) y:
        for(W - 1) x:
            if spot_x < 0 and terrain[y * W + x] == sh and terrain[y * W + x + 1] == sh and terrain[(y + 1) * W + x] == sh and terrain[(y + 1) * W + x + 1] == sh:
                spot_x = x
                spot_y = y
    check(spot_x >= 0, "farm: the test map has a 2x2 of shallows")
    check(can_build(spot_x, spot_y, 2, builder_class(0), true, false), "farm: frogs (amphibious) may farm the shallows")
    check(not can_build(spot_x, spot_y, 2, builder_class(1), true, false), "farm: rats may not build on water")
    check(not can_build(spot_x, spot_y, 2, builder_class(0), false, false), "farm: a building that doesn\'t allow water can\'t go there")
    // Stone: a worker mines the deposit by the start and carries it home.
    let stone_cell = nearest_res(sx, sy, "stone")
    let miner = (filter(ids_of(0)) uid: uid != worker)[0]
    let stone_before = stock[2][0]
    issue_cmd(0, CMD_GATHER, [ miner ], stone_cell, 0, 0, 0)
    steps(1200)
    check(stock[2][0] > stone_before, "stone: a worker mines the deposit ({stone_before} -> {stock[2][0]})")
    test_one_farmer()
    test_auto_reseed()

def seen_by(p:int, bid:int) -> bool: return exists(fog_seen[p]) s: s[0] == bid

// Fog memory: an enemy farm sown in the dark isn't known to you; once seen it is, and when you look
// away it stays as you last saw it (torn down) until you look again. (Lobster keeps the remembered
// buildings, fog_seen, but not the remembered ground and crops, fog_ground and fog_left: those
// checks are left out.)
def test_fog_memory():
    new_world("flat_test", races0, rules0, [])
    stock[1][1] = 1000
    let sx = start_x[1]
    let sy = start_y[1]
    let worker = ids_of(1)[0]
    let scout = ids_of(0)[0]
    let cx = sx / 1000 - 5
    let cy = sy / 1000 + 2
    let c = cy * W + cx
    let grass = terrain[c]
    issue_cmd(1, CMD_BUILD, [ worker ], btype_index("farm"), cx, cy, 0)
    let field = terrain_index("field")
    while tick < 1600 and terrain[c] != field: tick_on()
    steps(5)
    let farm_id = occupied[c]
    check(terrain[c] == field, "fog memory: player 1\'s farm became a field")
    check(fog[0][c] == UNSEEN and fog_ground[0][c] == grass, "fog memory: player 0 hasn\'t seen it, so it\'s grass to them")
    check(not seen_by(0, farm_id), "fog memory: nor does player 0 know the farm")
    check(fog_ground[1][c] == field and fog_left[1][c] > 0, "fog memory: its owner sees its crops")
    let hx, hy = pos_of(scout)
    place_at(scout, cx * 1000 - 2000, cy * 1000)  // player 0's worker looks in
    steps(8)
    check(fog_ground[0][c] == field and fog_left[0][c] == left_at(c), "fog memory: seen, it\'s a field with its crops")
    check(seen_by(0, farm_id), "fog memory: seen, player 0 knows the farm")
    place_at(scout, hx, hy)  // and goes home
    u_moving[index_of(scout)] = 0
    steps(8)
    check(fog[0][c] == EXPLORED, "fog memory: away again, the farm is under explored fog")
    let seen_left = fog_left[0][c]
    auto_reseed[1] = 0  // left fallow (auto-reseed would sow it again at once)
    amount[c] = 1       // nearly worked out
    while tick < 6000 and left_at(c) > 0: tick_on()
    check(terrain[c] == terrain_index("fallow"), "fog memory: the farm is worked out")
    check(fog_ground[0][c] == field and fog_left[0][c] == seen_left, "fog memory: player 0 still remembers it full of crops")
    let b = b_index_of(farm_id)  // torn down out of sight
    clear_farm(b)
    occupy(footprint(b), 0)
    remove_building(b)
    steps(8)
    check(seen_by(0, farm_id) and fog_ground[0][c] == field, "fog memory: gone out of sight, player 0 still remembers the farm")
    place_at(scout, cx * 1000 - 2000, cy * 1000)
    steps(8)
    check(not seen_by(0, farm_id) and fog_ground[0][c] == grass, "fog memory: seen again, it\'s gone and the ground is grass")

// Milestone 7's exit criterion: with the economy bot playing, the age-up lands at minutes 4-7.
def test_age_timing():
    new_world("flat_test", races0, rules0, [])
    let bots = map(2) p: EcoBot { p }
    let at_t = [ -1, -1 ]
    while tick < 9600 and (at_t[0] < 0 or at_t[1] < 0):
        for(bots) bot: bot_think(bot)
        tick_on()
        for(2) p:
            if at_t[p] < 0 and ages[p] >= 2: at_t[p] = tick
    for(2) p:
        print "  age 2: {race_name(p)} at {at_t[p] / 1200}:{(at_t[p] % 1200 / 20)} (tick {at_t[p]})"
        check(at_t[p] >= 4800 and at_t[p] <= 8400, "age-up at minutes 4-7: {race_name(p)} at tick {at_t[p]}")

def house_done(x:int, y:int) -> bool:
    for(b_owner) o, b:
        if o == 0 and b_cx[b] == x and b_cy[b] == y: return b_done[b] == 1
    return false

// Done with one house, the builder goes on to finish a foundation nearby.
def test_builder_moves_on():
    new_world("flat_test", races0, rules0, [])
    stock[res_of("wood")][0] = 1000
    let ws = own_workers_of(0)
    let cx = start_x[0] / 1000
    let cy = start_y[0] / 1000
    let hk = btype_index("house")
    let spots = []::int2  // two free spots near the start, 3 tiles apart
    for(13) dy0:
        for(5) dx0:
            let dx = dx0 + 3
            let dy = dy0 - 6
            if spots.length < 2 and can_place(0, hk, cx + dx, cy + dy) and (not spots.length or abs(spots[0].y - (cy + dy)) >= 3):
                spots.push(int2 { cx + dx, cy + dy })
    assert spots.length == 2
    issue_cmd(0, CMD_BUILD, [ ws[0] ], hk, spots[0].x, spots[0].y, 0)
    issue_cmd(0, CMD_BUILD, [ ws[1] ], hk, spots[1].x, spots[1].y, 0)
    steps(16)
    issue_cmd(0, CMD_MOVE, [ ws[1] ], start_x[0] - 6000, start_y[0], 0, 0)  // walks off: the second house is left a foundation
    var houses = []::int
    for(3000):
        tick_on()
        houses = []
        for(b_owner) o, b:
            if o == 0 and bt_name[b_kind[b]] == "house": houses.push(b_done[b])
        if houses.length == 2 and houses[0] == 1 and houses[1] == 1: break
    check(houses.length == 2 and houses[0] == 1 and houses[1] == 1, "builders: done with one house, the builder goes on to finish the foundation nearby ({houses})")

// Builders never wander off: a gatherer sent to build goes back to what it gathered when done, not to
// a foundation across the map; a builder with nothing to go back to stays by its building.
def test_builder_back_to_work():
    new_world("flat_test", races0, rules0, [])
    stock[res_of("wood")][0] = 1000
    let ws = own_workers_of(0)
    let wood = kind_of("wood")
    var a = index_of(ws[0])
    let tree = nearest_resource(u_x[a], u_y[a], wood, a, false, false, false)
    issue_cmd(0, CMD_GATHER, [ ws[0] ], tree, 0, 0, 0)
    steps(200)
    a = index_of(ws[0])
    let home = u_home[a]
    check(home >= 0 and (u_task[a] == GATHER or u_task[a] == T_RETURN), "builders: a woodcutter at work before building (task {u_task[a]})")
    let hk = btype_index("house")
    var near = int2 { -1, -1 }  // a house near the woodcutter's tree
    let tx = home % W
    let ty = home / W
    for(5) r0:
        let r = r0 + 2
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                if near.x < 0 and can_place(0, hk, tx + dx, ty + dy): near = int2 { tx + dx, ty + dy }
                dx++
            dy++
    var far = int2 { -1, -1 }  // and one beyond NEXT_BUILD_TILES of it
    for(6) r0:
        let r = r0 + NEXT_BUILD_TILES + 3
        for([ -r, r ]) dx:
            if far.x < 0 and can_place(0, hk, near.x + dx, near.y): far = int2 { near.x + dx, near.y }
    check(near.x >= 0 and far.x >= 0, "builders: room for the test\'s houses")
    issue_cmd(0, CMD_BUILD, [ ws[0] ], hk, near.x, near.y, 0)
    issue_cmd(0, CMD_BUILD, [ ws[1] ], hk, far.x, far.y, 0)
    steps(16)
    issue_cmd(0, CMD_MOVE, [ ws[1] ], start_x[0], start_y[0], 0, 0)  // walks off: the far house stays a foundation
    var done = false
    for(2000):
        tick_on()
        done = house_done(near.x, near.y)
        if done: break
    steps(40)
    a = index_of(ws[0])
    check(done, "builders: the house near the woodcutter goes up")
    check((u_task[a] == GATHER or u_task[a] == T_RETURN) and u_carry_kind[a] == wood, "builders: done, the woodcutter goes back to its wood (task {u_task[a]}), not to the foundation {abs(far.x - near.x)} tiles off")
    // A builder with nothing gathered before, done far from any foundation: it stays by the building.
    issue_cmd(0, CMD_STOP, [ ws[2] ], 0, 0, 0, 0)
    steps(12)
    var spot2 = int2 { -1, -1 }
    let scx = start_x[0] / 1000
    let scy = start_y[0] / 1000
    for(17) dy0:
        for(17) dx0:
            let dx = dx0 - 8
            let dy = dy0 - 8
            if spot2.x < 0 and abs(dx) + abs(dy) >= 4 and abs(scx + dx - far.x) > NEXT_BUILD_TILES + 2 and can_place(0, hk, scx + dx, scy + dy):
                spot2 = int2 { scx + dx, scy + dy }
    issue_cmd(0, CMD_BUILD, [ ws[2] ], hk, spot2.x, spot2.y, 0)
    var finished = -1
    for(2500):
        tick_on()
        if finished < 0 and house_done(spot2.x, spot2.y): finished = tick
        elif finished >= 0 and tick > finished + 200: break
    let c = index_of(ws[2])
    let d = isqrt(dist2(u_x[c], u_y[c], spot2.x * 1000 + 1000, spot2.y * 1000 + 1000))
    check(finished >= 0 and u_task[c] == T_NONE and d < 3000, "builders: with nothing to go back to and no foundation near, it stays by the building (task {u_task[c]}, {d} milli-tiles off)")

// A worker's own picks are only ever tiles its owner has seen.
def test_no_dark_picks():
    new_world("flat_test", races0, rules0, [])
    let wi = index_of(own_workers_of(0)[0])
    let wood = kind_of("wood")
    let x = u_x[wi]
    let y = u_y[wi]
    let seen = nearest_resource(x, y, wood, wi, false, false, true)
    check(seen >= 0 and fog[0][seen] != 0, "dark picks: the nearest wood a worker picks is on explored ground")
    let anywhere = nearest_resource(x, y, wood, -1, false, false, false)
    for(W * H) c: fog[0][c] = 0  // forget everything
    let got = nearest_resource(x, y, wood, wi, false, false, true)
    check(got == -1, "dark picks: with nothing explored, no wood is picked ({got})")
    check(anywhere >= 0 and nearest_resource(x, y, wood, wi, false, false, false) == anywhere, "dark picks: ... while a pick near where it was sent may still be there (the player sent it)")

// Woodcutters stand at the forest edge, a tree and a side spot each: sent together to one tree, they
// spread along the edge, each beside its own tree on open ground, never at a tree with no open side.
def test_wood_spots():
    new_world("old_forest", races0, rules0, [])
    let worker = type_of_slot(0, "worker")
    while own_workers_of(0).length < 7: spawn_by(0, worker)
    let ids = own_workers_of(0)
    let tree = 13 * W + 29  // the west edge of the wood east of the start
    check(resource_kind_at(tree) == "wood", "wood spots: the test\'s tree is a tree ({resource_kind_at(tree)})")
    issue_cmd(0, CMD_GATHER, ids, tree, 0, 0, 0)
    var bad = 0
    var shared = 0
    var at_work = 0
    for(1200) t:
        tick_on()
        if t >= 300 and t % 20 == 0:
            let held = []::int
            for(ids) uid:
                let i = index_of(uid)
                let h = u_home[i]
                if h >= 0 and u_task[i] == GATHER:
                    var open = false
                    for([ [ 0, -1 ], [ 1, 0 ], [ 0, 1 ], [ -1, 0 ] ]) k: open = open or cell_walkable(h % W + k[0], h / W + k[1], lane(i))
                    if not open or u_gspot[i] % 2 == 1: bad++  // a tree with no open side, or a corner spot
                    let key = h * 8 + u_gspot[i]
                    if u_gspot[i] >= 0 and contains(held, key): shared++
                    held.push(key)
                    if u_moving[i] == 0: at_work++
    let got = gathered[res_of("wood")][0]
    check(bad == 0, "wood spots: woodcutters only work trees with an open side, from a side ({bad} bad samples)")
    check(shared == 0, "wood spots: no two woodcutters hold the same spot ({shared})")
    check(at_work > 0 and got >= 60, "wood spots: they get to work ({at_work} samples) and wood comes in ({got})")

// A long shift-queue of builds (a dragged wall) all goes up.
def test_build_queue():
    new_world("flat_test", races0, rules0, [])
    stock[res_of("stone")][0] = 500
    ages[0] = 2
    let ids = ids_of(0)
    let pk = btype_index("palisade")
    for(7) k: issue_cmd(0, CMD_BUILD, ids, pk, start_x[0] / 1000 + 3, start_y[0] / 1000 - 3 + k, 0, if k > 0: 1 else: 0)
    steps(16)  // past the command delay: every queued foundation is down already
    var laid = 0
    for(b_kind) k:
        if k == pk: laid++
    check(laid == 7, "shift-queued builds: all 7 foundations are laid at once ({laid})")
    steps(3000)
    var done = 0
    for(b_kind) k, b:
        if k == pk: done += b_done[b]
    check(done == 7, "shift-queued builds: all 7 walls of a line go up ({done})")

// Right-clicking your Town Center with a worker half-loaded: it takes the load in and goes back to
// the same patch. A rally point set on a resource sits in the middle of its tile, and a worker
// trained to it gathers there.
def test_drop_off():
    new_world("flat_test", races0, rules0, [])
    var wi = index_of(own_workers_of(0)[0])
    var tc = -1
    for(b_owner) o, b:
        if tc < 0 and o == 0: tc = b
    let wood = kind_of("wood")
    let uid = u_id[wi]
    let cell = nearest_resource(u_x[wi], u_y[wi], wood, -1, false, false, false)
    issue_cmd(0, CMD_GATHER, [ uid ], cell, 0, 0, 0)
    for(2000):
        tick_on()
        wi = index_of(uid)
        if u_carry[wi] >= 2 and u_task[wi] == GATHER: break
    let home = u_home[wi]
    let load = u_carry[wi]
    let before = stock[wood - 1][0]
    issue_cmd(0, CMD_DROP_OFF, [ uid ], b_id[tc], 0, 0, 0)
    steps(12)
    wi = index_of(uid)
    check(u_task[wi] == T_RETURN and u_target[wi] == b_id[tc], "drop off: right-clicking the Town Center sends a loaded worker there")
    for(600):
        tick_on()
        if stock[wood - 1][0] > before: break
    wi = index_of(uid)
    check(load >= 2 and stock[wood - 1][0] >= before + load, "drop off: the load ({load}) is taken in ({before} -> {stock[wood - 1][0]})")
    check(u_task[wi] == GATHER and u_home[wi] == home, "drop off: ... and the worker goes back to its patch")
    // Rally on a resource: the middle of its tile; a worker trained there gathers it.
    let food = kind_of("food")
    let bush = nearest_resource(u_x[wi], u_y[wi], food, -1, false, false, false)
    let bx = (bush % W) * TILE
    let by = (bush / W) * TILE
    let tcid = b_id[tc]
    issue_cmd(0, CMD_RALLY, [], tcid, bx + 120, by + 860, 0)
    issue_cmd(0, CMD_TRAIN, [], tcid, type_of_slot(0, "worker"), 1, 0)
    let n = u_id.length
    steps(12)
    check(b_rally_x[tc] == bx + 500 and b_rally_y[tc] == by + 500, "rally: set on a bush, it sits in the middle of the bush\'s tile")
    issue_cmd(0, CMD_RALLY, [], tcid, 20120, 20860, 0)  // open ground stays where clicked
    steps(12)
    check(resource_kind_at(cell_of(20120, 20860)) != "" or (b_rally_x[tc] == 20120 and b_rally_y[tc] == 20860), "rally: on open ground it stays where you clicked")
    issue_cmd(0, CMD_RALLY, [], tcid, bx + 120, by + 860, 0)
    for(1200):
        tick_on()
        if u_id.length > n: break
    var new_i = -1
    for(u_owner) o, i:
        if new_i < 0 and o == 0 and t_worker[u_kind[i]] != 0 and u_id[i] > uid and u_task[i] == GATHER: new_i = i
    check(new_i >= 0 and u_carry_kind[new_i] == food, "rally: a worker trained to a bush rally gathers food")

// ------------------------------------------------------------------ animals, pens, garrisons, towers

def animal_rules() -> JV:
    let r = deep_copy(rules0)
    set(r, "animals", jbool(true))
    return r

def animal_name(i:int) -> string: return su_type_animal[u_kind[i]]

// Animals: placed by each start and in the wild, nobody's at first; sheep go to the player who comes
// near; a killed animal leaves food the hunters gather; a rival's unguarded sheep is stolen.
def test_animals():
    let ar = animal_rules()
    new_world("flat_test", races0, ar, [])
    var sheep_n = 0
    var boar_n = 0
    var deer_n = 0
    for(u_owner) o, i:
        if o == gaia:
            let a = animal_name(i)
            if a == "sheep": sheep_n++
            if a == "boar": boar_n++
            if a == "deer": deer_n++
    check(sheep_n == 8 and boar_n == 2 and deer_n >= 6, "animals: 4 sheep and a boar per start, deer herds out in the wild ({sheep_n} sheep, {boar_n} boar, {deer_n} deer)")
    let h1 = state_hash()
    new_world("flat_test", races0, ar, [])
    check(state_hash() == h1, "animals: the same seed puts them in the same places")
    // A worker walks to a sheep: it becomes ours.
    var sheep = -1
    var worker = -1
    for(u_owner) o, i:
        if sheep < 0 and o == gaia and animal_name(i) == "sheep": sheep = u_id[i]
        if worker < 0 and o == 0 and t_worker[u_kind[i]] != 0: worker = u_id[i]
    var x, y = pos_of(sheep)
    issue_cmd(0, CMD_MOVE, [ worker ], x, y, 0, 0)
    steps(600)
    var si = index_of(sheep)
    check(si >= 0 and u_owner[si] == 0, "animals: a sheep goes to the player who reaches it")
    // Slaughter it: its food lies on the ground and the worker gathers it.
    issue_cmd(0, CMD_ATTACK, [ worker ], sheep, 0, 0, 0)
    for(1200):
        tick_on()
        if index_of(sheep) < 0: break
    var carcass = -1
    for(resource_cells) c:
        if terrain_name(c) == "carcass" and amount[c] > 0: carcass = c
    let wi = index_of(worker)
    check(index_of(sheep) < 0 and carcass >= 0, "animals: a slaughtered sheep leaves its carcass")
    check(wi >= 0 and u_task[wi] == GATHER, "animals: the worker gathers the carcass")
    // Idle soldiers don't hunt on their own.
    var deer = -1
    for(u_owner) o, i:
        if deer < 0 and o == gaia and animal_name(i) == "deer": deer = i
    check(not is_foe(0, u_owner[deer]) and is_enemy(0, u_owner[deer]), "animals: hunted by choice, not fought by idle soldiers")
    // A rival's sheep, unguarded, is stolen by walking up to it (not killed).
    new_world("flat_test", races0, ar, [])
    var s3 = -1
    var wk3 = -1
    for(u_owner) o, i:
        if s3 < 0 and o == gaia and animal_name(i) == "sheep": s3 = u_id[i]
        if wk3 < 0 and o == 0 and t_worker[u_kind[i]] != 0: wk3 = u_id[i]
    u_owner[index_of(s3)] = 1
    x, y = pos_of(s3)
    issue_cmd(0, CMD_MOVE, [ wk3 ], x, y, 0, 0)
    steps(600)
    si = index_of(s3)
    check(si >= 0 and u_owner[si] == 0, "animals: an unguarded rival sheep is stolen by walking up to it")

def home_sheep(p:int) -> [int]:  // gaia's sheep by p's start
    let out = []::int
    for(u_owner) o, i:
        if o == gaia and animal_name(i) == "sheep" and abs(u_x[i] - start_x[p]) + abs(u_y[i] - start_y[p]) < 15000: out.push(u_id[i])
    return out

def first_worker(p:int) -> int:
    for(u_owner) o, i:
        if o == p and t_worker[u_kind[i]] != 0: return u_id[i]
    return -1

// Claimed sheep: each walks to one spot by its owner's Town Center and stops there for good,
// forgetting what its old owner told it; a sheep takes no fighting orders; a worker slaughters one in
// a few blows, a deer still takes a few more and a boar gets no such help.
def test_sheep_spot():
    new_world("flat_test", races0, animal_rules(), [])
    let sheep = home_sheep(0)
    let worker = first_worker(0)
    var first = index_of(sheep[0])
    u_orders[first] = [ Cmd { 0, CMD_MOVE, gaia, 1000, 1000, 0, 0, [ sheep[0] ], 0 } ]  // an order left over from before
    for(sheep) id:
        let x, y = pos_of(id)
        issue_cmd(0, CMD_MOVE, [ worker ], x, y, 0, 0, 1)
    steps(2400)
    var tc = -1
    for(b_owner) o, b:
        if tc < 0 and o == 0 and bt_name[b_kind[b]] == "town_center": tc = b
    let pen = herd_spots.get(b_id[tc]) or []::int
    var penned = 0
    var still = 0
    var forgot = true
    for(sheep) id:
        let si = index_of(id)
        if si >= 0 and u_owner[si] == 0 and pen.length and dist2(u_x[si], u_y[si], pen[0], pen[1]) <= 1800 * 1800: penned++
        if si >= 0 and u_moving[si] == 0: still++
        if si >= 0 and u_orders[si].length: forgot = false
    check(sheep.length == 4 and penned == 4, "sheep: with no pen, every claimed sheep gathers at one spot by the Town Center ({penned} of {sheep.length})")
    check(still == 4 and forgot, "sheep: ... and stands there, its old owner\'s orders forgotten")
    let bx = b_cx[tc] * 1000 + 1500
    let by = b_cy[tc] * 1000 + 1500
    check(pen.length and max(abs(pen[0] - bx), abs(pen[1] - by)) >= 3000, "sheep: the pen is beside the Town Center, not inside it")
    first = index_of(sheep[0])
    let x0 = u_x[first]
    let y0 = u_y[first]
    steps(1200)
    first = index_of(sheep[0])
    check(u_x[first] == x0 and u_y[first] == y0, "sheep: ... for good (no wandering a minute later)")
    // No fighting orders for a sheep: an attack and a stance do nothing, an attack-move only walks it.
    let foe = ids_of(1)[0]
    issue_cmd(0, CMD_ATTACK, [ sheep[0] ], foe, 0, 0, 0)
    stance(0, [ sheep[0] ], "passive")
    steps(20)
    first = index_of(sheep[0])
    check(u_foe[first] == 0 and u_posture[first] == AGGRESSIVE, "sheep: no attack orders, no stances")
    issue_cmd(0, CMD_ATTACK_MOVE, [ sheep[0] ], x0 + 3000, y0, 0, 0)
    steps(20)
    first = index_of(sheep[0])
    check(u_stance[first] == NONE and u_moving[first] == 1, "sheep: an attack-move just walks it")
    // One worker slaughters a sheep in a few blows.
    var blows = 0
    issue_cmd(0, CMD_ATTACK, [ worker ], sheep[1], 0, 0, 0)
    for(1200):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.b == sheep[1]: blows++
        if index_of(sheep[1]) < 0: break
    check(index_of(sheep[1]) < 0 and blows <= 3, "sheep: a worker slaughters one in a few blows ({blows})")
    // A deer takes more (it's harmless too, but bigger); a boar fights at full armour.
    let dk = animal_type("deer")
    let bk = animal_type("boar")
    let wk = u_kind[index_of(worker)]
    let to_deer = damage(t_atk[wk], t_arm[dk], t_cls[dk], max(r_min_damage, t_min_damage[dk]))
    check(t_hp[dk] / to_deer >= 5, "sheep: a deer still takes a worker {t_hp[dk] / to_deer} blows")
    check(t_min_damage[bk] == 0 and t_harmless[bk] == 0, "sheep: a boar gets no slaughter rule and fights back")

// Somewhere a pen may go near Town Center building tc: the first open spot west of it, then further out.
def pen_spot(tc:int) -> int2:
    let cx = b_cx[tc]
    let cy = b_cy[tc]
    for(7) r0:
        let r = r0 + 5
        var dy = -r
        while dy <= r:
            if can_build(cx - r - 1, cy + dy - 1, 5, 0, false, false): return int2 { cx - r, cy + dy }
            dy++
    assert false
    return int2 { -1, -1 }

def put_pen(tc:int) -> int:
    let k = btype_index("pen")
    let spot = pen_spot(tc)
    let pb = place(0, k, spot.x, spot.y, 0)
    b_done[pb] = 1
    b_hp[pb] = bm_hp[0][k]
    pen_opened(pb)
    return b_id[pb]

def sheep_of(p:int) -> int:
    var n = 0
    for(u_owner) o, i:
        if o == p and animal_name(i) == "sheep": n++
    return n

// Pens: claimed sheep go into their owner's pen; penned ones add food with no worker (exactly the
// pen's food per animal every food_ticks, up to the cap), two or more breed up to the cap, a rival
// outside the pen can't steal them but takes them once it's torn down, and Release walks them out.
def test_pen():
    let ar = animal_rules()
    new_world("flat_test", races0, ar, [])
    var tc = -1
    for(b_owner) o, b:
        if tc < 0 and o == 0: tc = b
    let k = btype_index("pen")
    let pen_id = put_pen(tc)
    let sheep = home_sheep(0)
    let worker = first_worker(0)
    for(sheep) id:
        let x, y = pos_of(id)
        issue_cmd(0, CMD_MOVE, [ worker ], x, y, 0, 0, 1)
    steps(2400)
    var pb = b_index_of(pen_id)
    let penned = pen_animals(pb, true).length
    check(penned == 4, "pen: claimed sheep walk into their owner\'s pen ({penned} of 4)")
    // The trickle: exactly food per animal every food_ticks, with nobody gathering.
    let food = res_of("food")
    let food_ticks = bt_pen_food_ticks[k]
    var t0 = tick
    var before = stock[food][0]
    steps(1200)
    let want = 4 * bt_pen_food[k] * ((tick - 1) / food_ticks - (t0 - 1) / food_ticks)
    check(stock[food][0] - before == want, "pen: 4 penned sheep bring in {want} food a minute ({stock[food][0] - before})")
    // Breeding: by the next breeding beat there's a lamb.
    while tick % bt_pen_breed_ticks[k] != 1: tick_on()
    pb = b_index_of(pen_id)
    check(pen_animals(pb, false).length == 5, "pen: two or more breed ({pen_animals(pb, false).length} now)")
    // The cap: more than it holds are there, but only the cap is paid for, and none are born.
    for(6):  // (Pens._born: a newborn by the pen's centre, to its place)
        let parent = pen_animals(pb, false)[0]
        let cx, cy = b_centre(pb)
        let s = add_unit(u_owner[parent], u_kind[parent], cx, cy)
        u_posture[s] = 0
        let px, py = herd_slot(cx, cy, s)
        order_move(s, px, py, 200, 0, -1, -1, 0)
    grow_scratch()
    steps(600)
    pb = b_index_of(pen_id)
    let inside = pen_animals(pb, true).length
    t0 = tick
    before = stock[food][0]
    steps(food_ticks)
    check(inside > bt_pen_animals[k] and stock[food][0] - before == bt_pen_animals[k] * bt_pen_food[k] and not pen_room(pb),
          "pen: it pays for its cap ({bt_pen_animals[k]}) and no more ({inside} inside, +{stock[food][0] - before} food)")
    // A rival next to the pen, outside it, steals nothing while it stands...
    for(u_owner) o, i:
        if o == 0 and t_animal[u_kind[i]] == 0:
            u_x[i] = 2000
            u_y[i] = 2000
            u_moving[i] = 0
            u_task[i] = T_NONE
    let cx, cy = b_centre(pb)
    spawn_cmd(1, "spear", 4, cx, cy - 2600)
    steps(200)
    check(sheep_of(1) == 0, "pen: a rival outside the pen steals nothing")
    // ...but tear it down and the sheep spill out to them.
    let spears = filter(ids_of(1)) uid: t_slot[u_kind[index_of(uid)]] == "spear"
    issue_cmd(1, CMD_ATTACK, spears, pen_id, 0, 0, 0)
    for(3000):
        tick_on()
        if b_index_of(pen_id) < 0 and sheep_of(1) > 0: break
    check(b_index_of(pen_id) < 0 and sheep_of(1) > 0, "pen: torn down, its sheep are stolen ({sheep_of(1)})")
    check(walk_over[cell_of(cx, cy)] == 0, "pen: torn down, its ground is plain again")
    // Release on a fresh world: a pen, a sheep in it, then Release: it walks out.
    new_world("flat_test", races0, ar, [])
    var tc2 = -1
    for(b_owner) o, b:
        if tc2 < 0 and o == 0: tc2 = b
    let pen2 = put_pen(tc2)
    var one = -1
    for(u_owner) o, i:
        if one < 0 and o == gaia and animal_name(i) == "sheep":
            one = u_id[i]
            u_owner[i] = 0
    issue_cmd(0, CMD_PEN, [ one ], pen2, 0, 0, 0)
    steps(1600)
    let in_before = pen_animals(b_index_of(pen2), true).length
    issue_cmd(0, CMD_RELEASE, [], pen2, 0, 0, 0)
    steps(600)
    let pb2 = b_index_of(pen2)
    check(in_before == 1 and pen_animals(pb2, true).length == 0 and pen_at(index_of(one)) < 0,
          "pen: Release walks its animals out ({in_before} in, then {pen_animals(pb2, true).length})")

// The economy bot herds and hunts: it claims its sheep and pens them (a pen it builds; it keeps
// penned sheep rather than slaughter them), hunts a deer that's near home and takes on a boar once
// it has workers to spare; the hunters gather the meat.
def test_bot_hunts():
    new_world("flat_test", races0, animal_rules(), [])
    var tc = -1
    for(b_owner) o, b:
        if tc < 0 and o == 0: tc = b
    let hx = b_cx[tc] * 1000 + 1500
    let hy = b_cy[tc] * 1000 + 1500
    for(u_kind) k, i:  // this map's deer graze mid-map, far from home: bring one closer
        if su_type_animal[k] == "deer":
            u_x[i] = hx + 8000
            u_y[i] = hy + 2000
            break
    spawn_cmd(0, "spear", 2, hx - 3000, hy - 3000)  // a guard to lead the boar hunt
    let bot = EcoBot { 0 }
    let killed = [ 0, 0, 0 ]  // sheep, deer, boar
    let names = [ "sheep", "deer", "boar" ]
    var meat = 0
    while tick < 20 * 60 * 7:
        let animals_now = dictionary<int, int>(64)  // id -> its animal, of player 0's or gaia's
        for(u_kind) k, i:
            if t_animal[k] != 0 and (u_owner[i] == 0 or u_owner[i] == gaia): animals_now.set(u_id[i], find_index(names, su_type_animal[k]))
        bot_think(bot)
        tick_on()
        for(events) e:
            if e.kind == EV_DIE and e.b == 0:
                let n = animals_now.get(e.a, -1)
                if n >= 0: killed[n]++
        for(u_owner) o, i:
            let h = u_home[i]
            if o == 0 and h >= 0 and terrain_name(h) == "carcass" and u_carry[i] > 0: meat = 1
    var penned = 0
    for(b_owner) o, b:
        if o == 0 and is_pen(b) and b_done[b] == 1: penned += pen_animals(b, true).length
    print "  bot hunting, first 7 minutes: {killed[0]} sheep, {killed[1]} deer, {killed[2]} boar killed; {penned} sheep penned"
    check(penned >= 2 and killed[0] >= 1, "bot hunts: it slaughters its first sheep, then builds a pen and pens the rest ({killed[0]} slaughtered, {penned} penned)")
    check(killed[1] >= 1, "bot hunts: ... a deer near home ({killed[1]})")
    check(killed[2] >= 1, "bot hunts: ... and its boar, with a big party ({killed[2]})")
    check(lost[0] <= 3, "bot hunts: ... losing no more than a few hunters to it ({lost[0]} lost)")
    check(meat > 0, "bot hunts: its workers gather the carcasses")

def inside_n(b:int) -> int: return b_inside[b].length / REC_SIZE

def inside_ids(b:int) -> [int]: return map(inside_n(b)) n: b_inside[b][n * REC_SIZE + REC_ID]

// The open spot for a building of type k nearest (x, y) (rings outwards), for test setups.
def free_spot(k:int, x:int, y:int) -> int2:
    for(12) r:
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                if max(abs(dx), abs(dy)) == r and can_place(0, k, x + dx, y + dy): return int2 { x + dx, y + dy }
                dx++
            dy++
    assert false
    return int2 { x, y }

// Garrisons: workers go into their Town Center, out of the units arrays (pop still counts them),
// heal, and each adds an arrow (the Town Center shoots only with people inside); ungarrison brings
// them back with their ids and health; the call to arms and back to work; a building that falls
// spills its people out; the same commands give the same hashes.
def garrison_run(checks_on:bool) -> int:
    new_world("flat_test", races0, rules0, [])
    let tc_id = b_id[0]
    let tc = b_index_of(tc_id)
    let sx = start_x[0]
    let sy = start_y[0]
    let workers = own_workers_of(0)
    def c(ok:bool, what:string):
        if checks_on: check(ok, what)
    def volleys(n:int) -> [int]:  // hits by the Town Center per volley, over some ticks
        let out = []::int
        for(n):
            tick_on()
            var k = 0
            for(events) e:
                if e.kind == EV_SHOT and e.a == tc_id: k++
            if k > 0: out.push(k)
        return out
    // An enemy spearman beside the Town Center, told never to fight.
    let foe = spawn_at(1, "spear", sx + 2600, sy)
    stance(1, [ foe ], "passive")
    c(volleys(120).length == 0, "garrison: an empty Town Center doesn\'t shoot")
    let pop0 = pop[0]
    let three = workers.slice(0, 3)
    issue_cmd(0, CMD_GARRISON, three, tc_id, 0, 0, 0)
    for(300):
        tick_on()
        if inside_n(tc) == 3: break
    c(inside_n(tc) == 3, "garrison: three workers go into the Town Center ({inside_n(tc)})")
    c(not exists(three) id: index_of(id) >= 0, "garrison: those inside are out of the units (no sight, no target)")
    tick_on()
    c(pop[0] == pop0, "garrison: pop still counts them ({pop[0]}, was {pop0})")
    let vs = volleys(200)
    c(vs.length and not exists(vs) n: n != 3, "garrison: three inside, three arrows a volley ({vs})")
    // Healing inside: 1 hp every heal_every ticks.
    b_inside[tc][REC_HP] = 5
    steps(200)
    let healed = b_inside[tc][REC_HP]
    c(healed >= 5 + 200 / r_garrison_heal_every - 1, "garrison: those inside heal slowly (5 -> {healed})")
    // Ungarrison: out again, the same ids and health, beside the Town Center.
    let hurt_id = b_inside[tc][REC_ID]
    issue_cmd(0, CMD_UNGARRISON, [], tc_id, 0, 0, 0)
    steps(12)
    c(inside_n(tc) == 0 and not exists(three) id: index_of(id) < 0, "garrison: ungarrison brings everyone out under their own ids")
    let hi = index_of(hurt_id)
    c(hi >= 0 and abs(u_hp[hi] - healed) <= 1, "garrison: ... with the health they had inside ({if hi >= 0: u_hp[hi] else: -1})")
    let x0, y0, x1, y1 = building_rect(tc)
    let g = if hi >= 0: max(max(x0 - u_x[hi], u_x[hi] - x1), max(y0 - u_y[hi], u_y[hi] - y1)) else: 9999
    c(g < 1500, "garrison: ... standing beside it ({g} from its wall)")
    // Call to arms: every worker near the Town Center goes in (gathering first, so back to work has a job).
    let bush = nearest_res(sx, sy, "food")
    let kind = kind_of("food")
    issue_cmd(0, CMD_GATHER, workers, bush, 0, 0, 0)
    steps(300)
    issue_cmd(0, CMD_CALL_TO_ARMS, [], tc_id, 0, 0, 0)
    for(600):
        tick_on()
        if inside_n(tc) == workers.length: break
    c(inside_n(tc) == workers.length, "garrison: the call to arms sends every worker nearby inside ({inside_n(tc)} of {workers.length})")
    issue_cmd(0, CMD_BACK_TO_WORK, [], 0, 0, 0, 0)
    steps(12)
    let back = filter(workers) id: index_of(id) >= 0 and (u_task[index_of(id)] == GATHER or u_task[index_of(id)] == T_RETURN) and u_carry_kind[index_of(id)] == kind
    c(back.length == workers.length, "garrison: back to work: every worker out and gathering again ({back.length} of {workers.length})")
    // A tower that falls spills its people out (and holds no more than it takes).
    let more = spawn_at(0, "worker", sx + 3000, sy - 3000)
    let all = copy(workers)
    for(3): all.push(spawn_at(0, "worker", sx + 3000, sy - 3000))
    all.push(more)
    let ts = free_spot(btype_index("watchtower"), sx / 1000 + 5, sy / 1000 - 5)
    let tower = put(0, "watchtower", ts.x, ts.y, 0)
    issue_cmd(0, CMD_GARRISON, all.slice(0, 2), tower, 0, 0, 0)
    for(400):
        tick_on()
        if inside_n(b_index_of(tower)) == 2: break
    var tb = b_index_of(tower)
    c(inside_n(tb) == 2, "garrison: two workers go into a watchtower ({inside_n(tb)})")
    issue_cmd(0, CMD_GARRISON, all.slice(2, all.length - 2), tower, 0, 0, 0)
    steps(400)
    tb = b_index_of(tower)
    let cap = bt_garrison[b_kind[tb]]
    c(inside_n(tb) == cap, "garrison: a watchtower holds {cap}, no more ({inside_n(tb)})")
    let held = inside_ids(tb)
    b_hp[tb] = 1
    spawn_cmd(1, "spear", 6, (ts.x + 3) * 1000, ts.y * 1000 + 500)
    steps(12)
    let killers = filter(ids_of(1)) id: t_slot[u_kind[index_of(id)]] == "spear"
    issue_cmd(1, CMD_ATTACK, killers, tower, 0, 0, 0)
    for(400):
        tick_on()
        if b_index_of(tower) < 0: break
    c(b_index_of(tower) < 0, "garrison: the enemy knocks the tower down")
    c(not exists(held) id: index_of(id) < 0, "garrison: ... and its people spill out alive")
    return state_hash()

def test_garrison():
    let a = garrison_run(true)
    let b = garrison_run(false)
    check(a == b, "garrison: the same commands give the same state hash")

def visible_cells(p:int) -> int: return (filter(fog[p]) v: v == VISIBLE).length

def research_named(id:string) -> int:
    for(research) r, k:
        if r.id == id: return k
    return -1

// A research given to p (researched, its effects applied), as test_sim.gd's _give for one in the data.
def give(p:int, id:string):
    let r = research_named(id)
    assert r >= 0
    researched[p][r] = 1
    retype(p)
    tech_refresh(p)

// Towers: the Outpost sees further than a house and doesn't shoot; the Bastion research turns every
// Watchtower into a Bastion in place, keeping its share of health and its people; after it a
// Watchtower ordered is a Bastion; a second Town Center from age 3.
def test_towers():
    bare_world(races0)
    put(0, "house", 10, 10, 0)
    tick_on()
    let seen_house = visible_cells(0)
    bare_world(races0)
    put(0, "outpost", 10, 10, 0)
    tick_on()
    check(visible_cells(0) > seen_house * 5 / 2, "towers: an outpost sees far ({visible_cells(0)} cells, a house {seen_house}; swamp frogs\' buildings see 2 further)")
    let ok = btype_index("outpost")
    check(bt_attacks[ok] == 0 and bt_garrison[ok] == 0, "towers: an outpost doesn\'t shoot, and nobody goes in")
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 5000
    let sx = start_x[0]
    let sy = start_y[0]
    let wt = btype_index("watchtower")
    let bk = btype_index("bastion")
    let t1 = put(0, "watchtower", sx / 1000 + 5, sy / 1000 - 5, 0)
    let t2 = put(1, "watchtower", sx / 1000 + 7, sy / 1000 - 5, 0)  // the rival's stays a watchtower
    var b1 = b_index_of(t1)
    b_hp[b1] = bm_hp[0][wt] / 2
    for([ 999999, type_of_slot(0, "worker"), 10, 0, 0, 0, -1 ]) v: b_inside[b1].push(v)
    give(0, "bastion")
    b1 = b_index_of(t1)
    check(b_kind[b1] == bk, "towers: the Bastion research makes the watchtower a bastion where it stands")
    check(abs(b_hp[b1] - bm_hp[0][bk] / 2) <= 1, "towers: ... keeping its share of health ({b_hp[b1]} of {bm_hp[0][bk]})")
    check(inside_n(b1) == 1, "towers: ... and the people inside")
    check(b_kind[b_index_of(t2)] == wt, "towers: a rival\'s watchtower stays one")
    check(bt_hp_base[bk] > bt_hp_base[wt] and bt_atk[bk] > bt_atk[wt] and bt_range[bk] > bt_range[wt], "towers: a bastion has more health, attack and range")
    b_inside[b1] = []::int
    ages[0] = 3
    let worker = first_worker(0)
    let spot = free_spot(bk, sx / 1000 - 5, sy / 1000 + 5)
    issue_cmd(0, CMD_BUILD, [ worker ], wt, spot.x, spot.y, 0)
    steps(12)
    let nb = b_index_of(occupied[spot.y * W + spot.x])
    check(nb >= 0 and b_kind[nb] == bk, "towers: after the research a watchtower ordered is a bastion")
    // More Town Centers: not in age 1 while one stands; from age 3, for wood and stone.
    let tck = btype_index("town_center")
    ages[0] = 1
    check(build_barred(0, tck), "towers: no second Town Center in age 1")
    ages[0] = 3
    check(not build_barred(0, tck), "towers: a second Town Center from age 3")
    check(bt_cost[tck][res_of("stone")] > 0 and bt_cost[tck][res_of("wood")] > 0, "towers: it costs wood and stone")
    let stone = stock[res_of("stone")][0]
    let tspot = free_spot(tck, sx / 1000 + 6, sy / 1000 + 4)
    issue_cmd(0, CMD_BUILD, [ worker ], tck, tspot.x, tspot.y, 0)
    steps(12)
    check(stock[res_of("stone")][0] < stone, "towers: ... and one is laid down, paid in stone")

// ------------------------------------------------------------------ camps, the market, research and ages, order queues

// The builder of a lumber camp goes to gather wood.
def test_camp_gather():
    new_world("flat_test", races0, rules0, [])
    var wi = index_of(own_workers_of(0)[0])
    let uid = u_id[wi]
    let wood = kind_of("wood")
    let c = nearest_resource(u_x[wi], u_y[wi], wood, -1, false, false, false)
    let k = btype_index("lumber_camp")
    var spot = -1
    for(4) r0:
        let r = r0 + 2
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                let x = c % W + dx
                let y = c / W + dy
                if spot < 0 and can_build(x, y, bt_size[k], builder_class(0), bt_water[k] != 0, false): spot = y * W + x
                dx++
            dy++
    issue_cmd(0, CMD_BUILD, [ uid ], k, spot % W, spot / W, 0)
    steps(1500)
    wi = index_of(uid)
    check(u_task[wi] == GATHER or u_task[wi] == T_RETURN, "camps: the builder of a lumber camp goes to gather (task {u_task[wi]})")
    check(u_carry_kind[wi] == wood or (u_task[wi] == GATHER and resource_kind_at(u_target[wi]) == "wood"), "camps: ... wood, what the camp takes in")

// The market: buying costs gold and raises the price, selling pays less and lowers it, and nobody
// trades without a finished market of their own.
def test_market():
    new_world("flat_test", races0, rules0, [])
    let g = res_of("gold")
    let f = res_of("food")
    stock[g][0] = 1000
    let m = place(0, btype_index("market"), start_x[0] / 1000 + 4, start_y[0] / 1000 + 3)
    let mid = b_id[m]
    issue_cmd(0, CMD_TRADE, [], mid, f, 1, 0)
    steps(20)
    check(stock[g][0] == 1000, "market: no trade at an unfinished market")
    b_done[m] = 1
    let food = stock[f][0]
    let price = market_price[f]
    issue_cmd(0, CMD_TRADE, [], mid, f, 1, 0)
    steps(20)
    check(stock[f][0] == food + 100 and stock[g][0] == 1000 - price, "market: buying 100 food costs {price} gold")
    check(market_price[f] > price, "market: buying raises the price ({price} -> {market_price[f]})")
    let gold = stock[g][0]
    let pay = market_price[f] * 75 / 100
    issue_cmd(0, CMD_TRADE, [], mid, f, 0, 0)
    steps(20)
    check(stock[g][0] == gold + pay and market_price[f] == price, "market: selling pays {pay} and brings the price back")
    issue_cmd(1, CMD_TRADE, [], mid, f, 1, 0)
    let g1 = stock[g][1]
    steps(20)
    check(stock[g][1] == g1, "market: nobody trades at someone else\'s market")

// A made-up research with these effects (data, as in tech.json), done for p as if just finished
// (test_sim.gd's _give with effects: effect kinds no built research uses yet get tested too).
def give_fx(p:int, id:string, fxs:[JV]):
    let r = research_named(id)
    if r < 0:
        research.push(Research { id, btype_index("town_center"), 20, 1, -1, 0, map(num_resources): 0,
                                 map(num_players): 1, map(num_players): 1, map(num_players): -1, map(fxs) fx: encode_effect(fx) })
        for(researched) row: row.push(0)
    researched[p][research_named(id)] = 1
    retype(p)
    tech_refresh(p)

def fx_of(text:string) -> JV: return parse_json(text)

// Building pct effects of a stat that reach type k for p (Tech.bpct).
def bpct(p:int, k:int, stat:int) -> int:
    var n = 0
    for(effects_of(p)) fx:
        if fx.kind == 6 and fx.stat == stat and covers(fx, k): n += fx.value
    return n

// Every research effect kind, one check or two each: it lands on the units or buildings it names, on
// those already out and those made later, and nowhere else.
def test_effects():
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 5000
    let wk = type_of_slot(0, "worker")
    let sp = type_of_slot(0, "spear")
    let melee = class_index("melee")
    // {tag, stat, add}, armour inside a stat: Thick Skins, researched at the Town Center in age 1.
    let hp0 = t_hp[wk]
    let arm0 = t_arm[wk][melee]
    let ts = research_named("thick_skins")
    issue_cmd(0, CMD_RESEARCH, [], b_id[0], ts, 0, 0)
    while tick < 1000 and researched[0][ts] == 0: tick_on()
    check(t_hp[wk] == hp0 + 15 and t_arm[wk][melee] == arm0 + 1, "effects: Thick Skins gives workers +15 hp, +1 melee armour ({hp0} -> {t_hp[wk]}, {arm0} -> {t_arm[wk][melee]})")
    var full = true
    for(u_kind) k, i:
        if k == wk: full = full and u_hp[i] == t_hp[wk]
    check(full, "effects: workers already out are at their new full health")
    check(t_hp[sp] == as_int(at(su_type_eval[sp], "hp")) and t_hp[sp] == lines[sp][0].hp, "effects: Thick Skins leaves spears alone")
    // A track's next step needs the one before.
    ages[0] = 3
    let ak = btype_index("armoury")
    let arm_b = b_index_of(put(0, "armoury", start_x[0] / 1000 + 4, start_y[0] / 1000 + 3, 0))
    let be = research_named("bronze_edges")
    check(tech_barred(0, arm_b, be), "effects: Bronze Edges needs Sharp Sticks first")
    give(0, "sharp_sticks")
    check(not tech_barred(0, arm_b, be), "effects: after Sharp Sticks, Bronze Edges can be researched")
    check(ak >= 0, "effects: the armoury is built")
    // speed pct and carry add: Big Pockets.
    let speed0 = t_speed[wk]
    give(0, "big_pockets")
    var wi = -1
    for(u_kind) k, i:
        if wi < 0 and u_owner[i] == 0 and k == wk: wi = i
    check(t_speed[wk] == speed0 * 110 / 100 and u_speed[wi] == t_speed[wk], "effects: Big Pockets makes workers 10% faster, those out too ({speed0} -> {t_speed[wk]})")
    check(t_carry_add[wk] == 3, "effects: Big Pockets adds 3 to what a worker carries")
    let carry_max = r_carry + t_carry_add[wk]
    let wid = u_id[wi]
    issue_cmd(0, CMD_GATHER, [ wid ], nearest_res(start_x[0], start_y[0], "wood"), 0, 0, 0)
    var most = 0
    for(1500):
        tick_on()
        most = max(most, u_carry[index_of(wid)])
    check(most == carry_max, "effects: a worker now carries {carry_max} before going back ({most})")
    // speed pct with `not`: Marching Drums, foot melee only.
    var foot = -1
    var mounted = -1
    for(t_slot.length) k:
        if t_player[k] == 0 and t_worker[k] == 0:
            if type_has_tag(k, "melee") and not type_has_tag(k, "mounted") and foot < 0: foot = k
            if type_has_tag(k, "mounted") and mounted < 0: mounted = k
    let fs = t_speed[foot]
    let ms = if mounted >= 0: t_speed[mounted] else: 0
    give(0, "marching_drums")
    check(t_speed[foot] == fs * 110 / 100, "effects: Marching Drums makes foot melee 10% faster ({fs} -> {t_speed[foot]})")
    check(mounted < 0 or t_speed[mounted] == ms, "effects: ...but not mounted units")
    // reload pct: Quick Draw.
    var rk = -1
    for(t_slot.length) k:
        if rk < 0 and t_player[k] == 0 and t_ranged[k] != 0: rk = k
    let reload0 = t_reload[rk]
    give(0, "quick_draw")
    check(t_reload[rk] == reload0 * 85 / 100 and t_reload[rk] < reload0, "effects: Quick Draw reloads 15% sooner ({reload0} -> {t_reload[rk]} ticks)")
    check(t_reload[sp] == r_melee_reload, "effects: ...and leaves melee units alone")
    // cost pct and train_time pct (no research uses them yet: race bonuses, War Drums).
    let cost0 = copy(t_cost[sp])
    let train0 = t_train_ticks[sp]
    let wtrain0 = t_train_ticks[wk]
    give_fx(0, "test.cheaper", [ fx_of("\{\"tag\": \"all\", \"stat\": \"cost\", \"pct\": -10\}"), fx_of("\{\"tag\": \"all\", \"not\": [\"worker\"], \"stat\": \"train_time\", \"pct\": -30\}") ])
    var cheaper = true
    for(cost0) v, c: cheaper = cheaper and t_cost[sp][c] == v * 90 / 100
    check(cheaper, "effects: cost -10% makes spears 10% cheaper ({cost0} -> {t_cost[sp]})")
    check(t_train_ticks[sp] == train0 * 70 / 100 and t_train_ticks[wk] == wtrain0, "effects: train_time -30% trains spears faster, workers as before ({train0} -> {t_train_ticks[sp]})")
    // Farm food pct: Fallow Fields.
    let fk = btype_index("farm")
    let food0 = bt_food_base[fk]
    check(bm_food[1][fk] == food0, "effects: farms hold {food0} food without Fallow Fields")
    let race_pct = bpct(0, fk, 1)  // (player 0's race may have a farm bonus of its own: swamp frogs' rich mud)
    give(0, "fallow_fields")
    check(bm_food[0][fk] == food0 * (150 + race_pct) / 100, "effects: Fallow Fields: farms hold 50% more ({bm_food[0][fk]})")
    // Trade fee: Haggling, selling pays more for the player who has it.
    let f = res_of("food")
    let sell0 = quote(0, f, false)  // (a race may have a fee bonus of its own: sewer rats' black market)
    give(0, "haggling")
    check(quote(0, f, false) == sell0 + market_price[f] * 10 / 100, "effects: Haggling cuts the fee by 10 points (sells for {quote(0, f, false)}, not {sell0})")
    check(quote(0, f, true) == quote(1, f, true), "effects: ...buying costs the same")
    // Every built research's effects say something in words.
    for(su_research) r:
        if not has(r, "line"):
            let words = effect_text(glist(r, "effects"))
            check(words != "", "effects: {rstr(r, "id")} says what it does ({words})")
    // Unit sight: a lone spear sees further.
    bare_world(races0)
    spawn_at(0, "spear", 16500, 22500)
    steps(8)
    var seen0 = visible_cells(0)
    give_fx(0, "test.sight", [ fx_of("\{\"tag\": \"all\", \"stat\": \"sight\", \"add\": 3\}") ])
    steps(8)
    check(visible_cells(0) > seen0, "effects: unit sight +3 shows more of the map ({seen0} -> {visible_cells(0)} cells)")
    // Building sight: Lookouts, on a lone house.
    bare_world(races0)
    let house = put(0, "house", 16, 22, 0)
    steps(8)
    seen0 = visible_cells(0)
    give(0, "lookouts")
    steps(8)
    check(visible_cells(0) > seen0, "effects: Lookouts give buildings +3 sight ({seen0} -> {visible_cells(0)} cells)")
    // Building hp pct and armour: a standing house keeps its share of health; hits do less.
    let hb = b_index_of(house)
    let hk = b_kind[hb]
    let hp_full = bt_hp_base[hk]
    b_hp[hb] = hp_full / 2
    let atk = map(num_classes): 0
    atk[melee] = 10
    let d0 = damage(atk, bm_arm[0][hk], building_cls(), 1)
    give_fx(0, "test.stone", [ fx_of("\{\"building\": \"all\", \"stat\": \"hp\", \"pct\": 10\}"), fx_of("\{\"building\": \"all\", \"stat\": \"armour.melee\", \"add\": 2\}") ])
    check(bm_hp[0][hk] == hp_full * 110 / 100 and b_hp[hb] == hp_full / 2 * bm_hp[0][hk] / hp_full, "effects: buildings +10% hp, a half-hurt house stays half ({b_hp[hb]} of {bm_hp[0][hk]})")
    let d1 = damage(atk, bm_arm[0][hk], building_cls(), 1)
    check(d1 == d0 - 2, "effects: buildings +2 melee armour take 2 less from a blow ({d0} -> {d1})")
    check(bm_hp[1][hk] == hp_full, "effects: ...only the researching player\'s buildings")
    // Build speed: a worker who builds 100% faster finishes a house in about half the time.
    let times = []::int
    var house_ticks = 0
    for([ 0, 100 ]) pct:
        new_world("flat_test", races0, rules0, [])
        stock[1][0] = 1000
        house_ticks = bt_build_ticks[btype_index("house")]
        if pct > 0: give_fx(0, "test.frames", [ fx_of("\{\"tag\": \"worker\", \"stat\": \"build_speed\", \"pct\": {pct}\}") ])
        let builder = ids_of(0)[0]
        issue_cmd(0, CMD_BUILD, [ builder ], btype_index("house"), start_x[0] / 1000 + 4, start_y[0] / 1000 + 3, 0)
        var started = -1
        var done = -1
        while tick < 3000 and done < 0:
            tick_on()
            for(b_owner) o, k:
                if o == 0 and bt_name[b_kind[k]] == "house":
                    if started < 0 and b_progress[k] > 0: started = tick
                    if b_done[k] == 1: done = tick
        times.push(done - started)
    check(times[1] > 0 and abs(times[1] - house_ticks / 2) <= 3 and abs(times[0] - house_ticks) <= 3, "effects: build_speed +100% builds a house in half the time ({times} ticks, alone {house_ticks})")
    // Research time: a building whose research goes 50% faster.
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 5000
    give_fx(0, "test.scholars", [ fx_of("\{\"building\": \"town_center\", \"stat\": \"research_time\", \"pct\": -50\}") ])
    let ts2 = research_named("thick_skins")
    issue_cmd(0, CMD_RESEARCH, [], b_id[0], ts2, 0, 0)
    steps(12)
    let base_ticks = research[ts2].ticks
    check(head_ticks(0) == base_ticks / 2, "effects: research_time -50% halves a research\'s time ({head_ticks(0)} of {base_ticks} ticks)")
    let t0 = tick
    while tick < 2000 and researched[0][ts2] == 0: tick_on()
    check(tick - t0 <= base_ticks / 2, "effects: ...and it\'s done in that time ({tick - t0} ticks)")
    // Fallow Fields on a farm, sown and reseeded.
    new_world("flat_test", races0, rules0, [])
    stock[1][0] = 1000
    give(0, "fallow_fields")
    auto_reseed[0] = 0  // reseeded by hand below
    let farmer = ids_of(0)[0]
    let fcx = start_x[0] / 1000 + 3
    let fcy = start_y[0] / 1000 + 2
    issue_cmd(0, CMD_BUILD, [ farmer ], fk, fcx, fcy, 0)
    let cell = fcy * W + fcx
    while tick < 1600 and pool[cell] < 0: tick_on()
    let want = food0 * (150 + race_pct) / 100
    check(left_at(cell) >= want - 5, "effects: a farm sown after Fallow Fields holds {want} ({left_at(cell)})")
    amount[pool[cell]] = 1
    while tick < 3000 and left_at(cell) > 0: tick_on()
    issue_cmd(0, CMD_RESEED, [ farmer ], occupied[cell], 0, 0, 0)
    steps(12)
    check(left_at(cell) >= want - 5, "effects: ...and so does a reseeded one ({left_at(cell)})")

// The University's research and the Castle: each effect lands where it says and nowhere else, and the
// Castle looses a volley of arrows, one at each of the nearest foes in turn.
def test_university_castle():
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 9000
    let uk = btype_index("university")
    let ck = btype_index("castle")
    check(uk >= 0 and ck >= 0, "university/castle: both are built types (not planned)")
    check(bt_age[uk] == 3 and bt_age[ck] == 3 and bt_size[ck] == 4, "university/castle: age 3; the castle is 4 x 4")
    let castle = at(at(load_json(lib_root + "/buildings.json"), "buildings"), "castle")
    check(gint(castle, "garrison", 0) > 0 and gint(at(castle, "attack"), "arrows", 1) > 1, "castle: a garrison and several arrows in data")
    check(gint(at(castle, "cost"), "stone", 0) > gint(at(castle, "cost"), "wood", 0), "castle: stone-heavy")
    // Research at the University: needs age 3, then it's bought and done there.
    let sx = start_x[0]
    let sy = start_y[0]
    let ub = b_index_of(put(0, "university", sx / 1000 + 4, sy / 1000 + 3, 0))
    ages[0] = 2
    check(tech_barred(0, ub, research_named("stonecutting")), "university: research needs age 3")
    ages[0] = 3
    for([ "stonecutting", "lifting_frames", "slit_windows", "thick_walls", "siege_wrights" ]) id:
        check(not tech_barred(0, ub, research_named(id)), "university: {id} can be researched there")
    let hk = btype_index("house")
    let hp_house = bm_hp[0][hk]
    let arm_house = copy(bm_arm[0][hk])
    let sc = research_named("stonecutting")
    issue_cmd(0, CMD_RESEARCH, [], b_id[ub], sc, 0, 0)
    while tick < 2000 and researched[0][sc] == 0: tick_on()
    let melee = class_index("melee")
    let pierce = class_index("pierce")
    check(researched[0][sc] == 1, "stonecutting: researched at the University")
    check(bm_hp[0][hk] == hp_house * 110 / 100 and bm_arm[0][hk][melee] == arm_house[melee] + 1 and bm_arm[0][hk][pierce] == arm_house[pierce] + 1,
          "stonecutting: buildings +10% HP, +1/+1 armour (house {hp_house} -> {bm_hp[0][hk]} hp)")
    check(bm_hp[1][hk] == hp_house, "stonecutting: ...only the researcher\'s")
    // Lifting Frames: workers build 20% faster.
    let wk = type_of_slot(0, "worker")
    give(0, "lifting_frames")
    check(t_build_pct[wk] == 20, "lifting frames: workers build 20% faster ({t_build_pct[wk]})")
    // Thick Walls: walls and gates double, houses don't.
    let wall_ids = [ "palisade", "palisade_gate", "wall", "stone_gate" ]
    let house_before = bm_hp[0][hk]
    give(0, "thick_walls")
    for(wall_ids) id:
        let k = btype_index(id)
        check(bm_hp[0][k] == bt_hp_base[k] * 210 / 100, "thick walls (after Stonecutting): {id} +100% HP ({bm_hp[0][k]})")
    check(bm_hp[0][hk] == house_before, "thick walls: ...houses as they were")
    // Siege Wrights: +1 range for siege (none yet: a ranged line stands in, tagged siege).
    var rk = -1
    for(t_slot.length) k:
        if rk < 0 and t_player[k] == 0 and t_ranged[k] != 0: rk = k
    let sp = type_of_slot(0, "spear")
    let range0 = t_reach[rk]
    let sp_range0 = t_reach[sp]
    let siege_c = class_index("siege")
    for(lines[rk]) l: l.tags = l.tags.append([ siege_c ])
    give(0, "siege_wrights")
    check(t_reach[rk] == range0 + TILE, "siege wrights: siege +1 range ({range0 / TILE} -> {t_reach[rk] / TILE})")
    check(t_reach[sp] == sp_range0, "siege wrights: ...spears as they were")
    // The Castle's research: War Drums and the race's own.
    let cb = b_index_of(put(0, "castle", sx / 1000 - 2, sy / 1000 + 8, 0))
    for([ "war_drums", "bog_poultice" ]) id:  // (player 0 is swamp frogs: the swamp's own research is at the Castle)
        check(not tech_barred(0, cb, research_named(id)), "castle: {id} can be researched there")
    check(tech_barred(0, cb, research_named("gnawing_teeth")), "castle: ...not another race\'s own (the rats\' Gnawing Teeth)")
    let hl = type_of_slot(0, "healer")
    let train_sp = t_train_ticks[sp]
    let train_wk = t_train_ticks[wk]
    let train_hl = if hl >= 0: t_train_ticks[hl] else: 0
    give(0, "war_drums")
    check(t_train_ticks[sp] == train_sp * 70 / 100, "war drums: soldiers train 30% faster ({train_sp} -> {t_train_ticks[sp]} ticks)")
    check(t_train_ticks[wk] == train_wk and (hl < 0 or t_train_ticks[hl] == train_hl), "war drums: ...workers and healers as before")
    give(0, "bog_poultice")
    check(hl < 0 or t_heal_pct[hl] == 30, "own research: Bog Poultice, healers heal 30% more ({if hl >= 0: t_heal_pct[hl] else: 0})")
    // The Castle's arrows: a volley of `arrows`, one at each of the nearest foes in turn.
    let arrows = gint(at(castle, "attack"), "arrows", 1)
    for([ 1, arrows + 2 ]) n:
        bare_world(races0)
        let gid = put(1, "castle", 14, 14, 0)  // centre (16, 16)
        spawn_cmd(0, "spear", n, 20500, 16000)
        let first = []::int
        for(40):
            tick_on()
            for(events) e:
                if e.kind == EV_SHOT and e.a == gid: first.push(e.b)
            if first.length: break
        let distinct = []::int
        for(first) id:
            if not contains(distinct, id): distinct.push(id)
        check(first.length == arrows, "castle: a volley is {arrows} arrows ({first.length}, {n} foes)")
        check(distinct.length == min(n, arrows), "castle: the arrows go to {min(n, arrows)} different foes ({n} foes in reach: {distinct.length} hit)")
    // Slit Windows: +1 tile of reach for the Castle (and towers, Town Centers).
    let reach = []::int
    for([ false, true ]) slit:
        bare_world(races0)
        let gid = put(1, "castle", 14, 14, 0)
        if slit: give(1, "slit_windows")
        spawn_cmd(0, "spear", 1, 16000 + 10500, 16000)  // just past 8 tiles (+ half the castle)
        var shot = 0
        for(60):
            tick_on()
            for(events) e:
                if e.kind == EV_HIT and e.a == gid: shot++
        reach.push(shot)
    check(reach[0] == 0 and reach[1] > 0, "slit windows: a foe just out of the castle\'s reach is shot once it has them ({reach})")
    new_world("flat_test", races0, rules0, [])
    give(0, "slit_windows")
    for([ "watchtower", "castle", "town_center" ]) id: check(bm_range[0][btype_index(id)] == 1, "slit windows: {id} +1 range")
    check(bm_range[0][btype_index("house")] == 0, "slit windows: ...houses nothing")

def put_done(p:int, id:string, cx:int, cy:int) -> int:  // place + done + full hp: its slot
    let k = btype_index(id)
    let b = place(p, k, cx, cy)
    b_done[b] = 1
    b_hp[b] = bm_hp[p][k]
    return b

// Research and the age-up queue with units, the genre's way: in the order clicked, paid when queued,
// refunded on cancel, never queued twice.
def test_research_queue():
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 5000
    ages[0] = 2  // player 0 is frogs: Strong Legs is theirs
    let sx = start_x[0]
    let sy = start_y[0]
    var b = put_done(0, "barracks", sx / 1000 + 4, sy / 1000 - 6)
    put_done(0, "stable", sx / 1000 - 7, sy / 1000 - 6)  // what the age-3 age-up asks for
    let bid = b_id[b]
    let up = research_named("line.spear.2")
    let leap = research_named("frog_leap")
    let k = type_of_slot(0, "spear")
    let food = stock[0][0]
    issue_cmd(0, CMD_RESEARCH, [], bid, up, 0, 0)
    issue_cmd(0, CMD_RESEARCH, [], bid, leap, 0, 0)
    issue_cmd(0, CMD_TRAIN, [], bid, k, 1, 0)
    issue_cmd(0, CMD_RESEARCH, [], bid, leap, 0, 0)  // a second click: refused
    steps(12)
    b = b_index_of(bid)
    check(equal(b_queue[b], [ entry_of(up), entry_of(leap), k ]), "research queue: two research then a spear, in the order clicked ({b_queue[b]})")
    let paid = research[up].cost[0] + research[leap].cost[0] + t_cost[k][0]
    check(stock[0][0] == food - paid, "research queue: each paid when queued (food {food} -> {stock[0][0]}, {paid})")
    check(tech_barred(0, b, leap) and tech_queued(0, leap), "research queue: a queued research can\'t be queued again")
    // The age-up queues too; a second one is refused; cancelling refunds it.
    let tc = b_id[0]
    let before = map(stock) row: row[0]
    issue_cmd(0, CMD_AGE_UP, [], tc, 0, 0, 0)
    issue_cmd(0, CMD_AGE_UP, [], tc, 0, 0, 0)
    steps(12)
    check((filter(b_queue[0]) e: e == AGE_UP_ENTRY).length == 1 and tech_barred(0, 0, -1), "research queue: one age-up queued, the second refused")
    let at_up = find(b_queue[0]) e: e == AGE_UP_ENTRY
    issue_cmd(0, CMD_CANCEL, [], tc, at_up, 0, 0)
    steps(12)
    let after = map(stock) row: row[0]
    check(equal(after, before) and not tech_queued(0, AGE_UP_ENTRY), "research queue: cancelling the age-up refunds it")
    issue_cmd(0, CMD_CANCEL, [], bid, 1, 0, 0)  // frog_leap, and then queue it again
    steps(12)
    check(stock[0][0] == food - paid + research[leap].cost[0] and equal(b_queue[b_index_of(bid)], [ entry_of(up), k ]), "research queue: cancelling a queued research refunds it")
    issue_cmd(0, CMD_RESEARCH, [], bid, leap, 0, 0)
    steps(12)
    // Run it: the spear line's upgrade, then the spear, then Strong Legs (queued last now).
    def spears() -> int: return (filter(u_kind) x: x == k).length
    let n0 = spears()
    var t_up = -1
    var t_spear = -1
    var t_leap = -1
    while tick < 4000 and (t_up < 0 or t_spear < 0 or t_leap < 0):
        tick_on()
        if t_up < 0 and researched[0][up] == 1: t_up = tick
        if t_leap < 0 and researched[0][leap] == 1: t_leap = tick
        if t_spear < 0 and spears() > n0: t_spear = tick
    check(t_up > 0 and t_spear > t_up and t_leap > t_spear, "research queue: they finish in queue order (upgrade {t_up}, spear {t_spear}, Strong Legs {t_leap})")
    check(t_spear - t_up >= t_train_ticks[k], "research queue: the spear waited for the research ahead of it")

def b_named(p:int, id:string) -> int:
    for(b_owner) o, b:
        if o == p and bt_name[b_kind[b]] == id: return b
    return -1

// Ageing up moves a player's units along their lines; research adds to stats by tag.
def test_tech():
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][0] = 5000
    let tc = b_id[0]
    let sx = start_x[0]
    let sy = start_y[0]
    spawn_cmd(0, "spear", 2, sx + 3000, sy)
    let k = type_of_slot(0, "spear")
    let hp1 = t_hp[k]
    let atk1 = t_eval_attack[k]
    let off_ids = [ "barracks", "stable", "armoury", "house" ]
    let off_x = [ 4, -7, 4, -6 ]
    let off_y = [ -6, -6, 3, 3 ]
    for(off_ids) id, n:  // what each age-up asks for, the armoury, and room for the worker, already standing
        put_done(0, id, sx / 1000 + off_x[n], sy / 1000 + off_y[n])
    let food = stock[0][0]
    issue_cmd(0, CMD_AGE_UP, [], tc, 0, 0, 0)
    issue_cmd(0, CMD_TRAIN, [], tc, type_of_slot(0, "worker"), 1, 0)
    steps(40)
    check(stock[0][0] < food, "tech: ageing up is paid for")
    check(head_tech(0) == AGE_UP_ENTRY, "tech: the Town Center is ageing up")
    let units_then = u_id.length
    var aged = -1
    while tick < 2000:
        tick_on()
        if ages[0] >= 2:
            aged = tick
            break
    check(aged > 0 and ages[0] == 2, "tech: player 0 reaches age 2 (tick {aged})")
    check(u_id.length == units_then, "tech: no worker trained while the Town Center was ageing up")
    steps(t_train_ticks[type_of_slot(0, "worker")] + 8)
    check(u_id.length == units_then + 1, "tech: the worker queued behind the age-up trains once it\'s done")
    let line = lines[k]
    check(t_hp[k] == hp1 and t_eval_attack[k] == atk1, "tech: the age-up alone doesn\'t change the spears (D-100)")
    let barracks = b_named(0, "barracks")
    let up2 = research_named("line.spear.2")
    issue_cmd(0, CMD_RESEARCH, [], b_id[barracks], up2, 0, 0)
    while tick < 3500 and researched[0][up2] == 0: tick_on()
    check(t_hp[k] - hp1 == line[1].hp - line[0].hp and t_eval_attack[k] - atk1 == line[1].attack - line[0].attack and
          (line[1].hp != line[0].hp or line[1].attack != line[0].attack or not equal(line[1].tags, line[0].tags)),
          "tech: the spear line\'s upgrade moves spears to their age-2 step ({hp1} -> {t_hp[k]} hp, attack {atk1} -> {t_eval_attack[k]})")
    var full = true
    for(u_kind) kk, i:
        if kk == k: full = full and u_hp[i] == t_hp[k]
    check(full, "tech: existing spearmen take the new kit at full health ({t_hp[k]} hp)")
    let atk = t_eval_attack[k]
    let armoury = b_named(0, "armoury")  // Sharp Sticks is researched at the Armoury
    let ss = research_named("sharp_sticks")
    issue_cmd(0, CMD_RESEARCH, [], b_id[armoury], ss, 0, 0)
    while tick < 4000 and researched[0][ss] == 0: tick_on()
    check(t_eval_attack[k] == atk + 1, "tech: Sharp Sticks gives spears +1 attack ({atk} -> {t_eval_attack[k]})")
    issue_cmd(0, CMD_AGE_UP, [], tc, 0, 0, 0)
    while tick < 7000 and ages[0] < 3: tick_on()
    let up3 = research_named("line.spear.3")
    researched[0][up2] = 0  // a line's age-3 upgrade waits for its age-2 one (Dominic, 2026-10-13)
    check(tech_barred(0, barracks, up3), "tech: the spears\' age-3 upgrade waits for the age-2 one")
    researched[0][up2] = 1
    check(not tech_barred(0, barracks, up3), "tech: ...and is there once it\'s done")
    issue_cmd(0, CMD_RESEARCH, [], b_id[barracks], up3, 0, 0)
    while tick < 9000 and researched[0][up3] == 0: tick_on()
    check(ages[0] == 3 and t_eval_attack[k] == line[2].attack + 1, "tech: research still counts after the next age-up")
    // Tech-tree layer: Strong Legs is frogs only (player 0 here is frogs, player 1 rats).
    let rb = put_done(1, "barracks", start_x[1] / 1000 + 4, start_y[1] / 1000 - 6)
    ages[1] = 2
    for(num_resources) r: stock[r][1] = 5000
    let leap = research_named("frog_leap")
    check(tech_barred(1, rb, leap) and research[leap].open[1] == 0, "tech tree: rats can\'t research the frogs\' Strong Legs")
    let full_rules = deep_copy(rules0)
    set(full_rules, "full_tech_tree", jbool(true))
    new_world("flat_test", races0, full_rules, [])
    let rb2 = put_done(1, "barracks", start_x[1] / 1000 + 4, start_y[1] / 1000 - 6)
    ages[1] = 2
    for(num_resources) r: stock[r][1] = 5000
    check(not tech_barred(1, rb2, leap), "tech tree: the host\'s full tech tree lifts it")
    // Age gates and towers, on a fresh world.
    new_world("flat_test", races0, rules0, [])
    for(num_resources) r: stock[r][1] = 5000
    let gx = start_x[1]
    let gy = start_y[1]
    let w1 = ids_of(1)[ids_of(1).length - 1]
    let nb = b_id.length
    issue_cmd(1, CMD_BUILD, [ w1 ], btype_index("stable"), gx / 1000 - 6, gy / 1000 - 6, 0)
    steps(12)
    check(b_id.length == nb, "gates: no Stable before age 2")
    let ti = put_done(1, "watchtower", gx / 1000 - 4, gy / 1000)
    let tid = b_id[ti]
    // A lone enemy spear five tiles off (in range, not attacking anything): the tower hurts it.
    let ids_before = copy(u_id)
    spawn_cmd(0, "spear", 1, gx - 8500, gy + 500)
    steps(16)
    var foe = 0
    for(u_id) id:
        if not contains(ids_before, id): foe = id
    check(foe != 0, "towers: the target spawned")
    let hp0 = u_hp[index_of(foe)]
    var n_shots = 0
    var dealt = 0
    for(120):
        tick_on()
        for(events) e:
            if e.kind == EV_HIT and e.a == tid and e.b == foe:
                n_shots++
                dealt += e.c
    let fi = index_of(foe)
    let hp1b = if fi >= 0: u_hp[fi] else: 0
    check(n_shots >= 2 and dealt > 0 and hp1b <= hp0 - dealt, "towers: a finished watchtower damages an enemy unit in range ({n_shots} shots, {dealt} damage, hp {hp0} -> {hp1b})")

// Shift-queuing: a worker builds a house, then goes foraging, from one queued order.
def test_queue():
    new_world("flat_test", races0, rules0, [])
    let worker = ids_of(0)[0]
    let sx = start_x[0]
    let sy = start_y[0]
    let food_cell = nearest_res(sx, sy, "food")
    issue_cmd(0, CMD_BUILD, [ worker ], btype_index("house"), sx / 1000 + 3, sy / 1000 - 1, 0)
    issue_cmd(0, CMD_GATHER, [ worker ], food_cell, 0, 0, 0, 1)
    steps(12)  // orders run two turns (8 ticks) after they're issued
    var i = index_of(worker)
    check(u_task[i] == BUILD and u_orders[i].length == 1, "queue: the worker builds first, the gather order waits")
    var house_done = -1
    while tick < 2400:
        tick_on()
        i = index_of(worker)
        if house_done < 0:
            for(b_owner) o, b:
                if o == 0 and b_done[b] == 1 and b_sx[b] == 2: house_done = tick
        elif u_task[i] == GATHER or u_task[i] == T_RETURN: break
    check(house_done > 0, "queue: the house got built (tick {house_done})")
    check((u_task[i] == GATHER or u_task[i] == T_RETURN) and u_orders[i].length == 0, "queue: then the worker went foraging, queue empty")
    issue_cmd(0, CMD_MOVE, [ worker ], sx, sy, 0, 0)
    issue_cmd(0, CMD_GATHER, [ worker ], food_cell, 0, 0, 0, 1)
    issue_cmd(0, CMD_MOVE, [ worker ], sx + 2000, sy, 0, 0)
    steps(12)
    i = index_of(worker)
    check(u_orders[i].length == 0, "queue: a plain order empties the queue")
    test_queue_after_build("house")
    test_queue_after_build("farm")

// Build, then shift-told to go somewhere else: the builder finishes the building, then walks to the
// queued point: not on to another foundation nearby, and a farm's builder doesn't stay to work it.
def test_queue_after_build(kind:string):
    new_world("flat_test", races0, rules0, [])
    stock[res_of("wood")][0] = 1000
    let ws = own_workers_of(0)
    let sx = start_x[0]
    let sy = start_y[0]
    let bk = btype_index(kind)
    let hk = btype_index("house")
    let spots = []::int2  // where it goes, and a house foundation nearby that nobody builds
    for(13) dy0:
        for(6) dx0:
            let c = int2 { sx / 1000 + dx0 + 3, sy / 1000 + dy0 - 6 }
            if not spots.length and can_place(0, bk, c.x, c.y): spots.push(c)
            elif spots.length == 1 and abs(spots[0].y - c.y) >= 4 and can_place(0, hk, c.x, c.y): spots.push(c)
    assert spots.length == 2
    issue_cmd(0, CMD_BUILD, [ ws[0] ], bk, spots[0].x, spots[0].y, 0)
    issue_cmd(0, CMD_BUILD, [ ws[1] ], hk, spots[1].x, spots[1].y, 0)
    let tx = sx - 5000
    let ty = sy + 3000
    issue_cmd(0, CMD_MOVE, [ ws[0] ], tx, ty, 0, 0, 1)
    steps(16)
    issue_cmd(0, CMD_STOP, [ ws[1] ], 0, 0, 0, 0)  // the second house stays a foundation
    var built = -1
    var i = -1
    while tick < 4000:
        tick_on()
        i = index_of(ws[0])
        let b = occupied[spots[0].y * W + spots[0].x]
        if built < 0 and b != 0 and b_done[b_index_of(b)] == 1: built = tick
        if built >= 0 and u_moving[i] == 0 and u_task[i] == T_NONE: break
    let d = isqrt(dist2(u_x[i], u_y[i], tx, ty))
    check(built > 0 and d < 1500 and u_task[i] == T_NONE, "queue: build a {kind}, then shift-move: built it (tick {built}), then walked to the point ({d} milli-tiles off, task {u_task[i]})")

// ------------------------------------------------------------------ Wonders, saves

// Two players on flat_test with their Town Centers and no workers to wander about.
def wonder_world(r:JV):
    let rr = deep_copy(r)
    set(at(at(rr, "economy"), "start"), "workers", jint(0))
    new_world("flat_test", [ races0[0], races0[1] ], rr, [])

// A finished Wonder for player p, a few tiles beside their Town Center; its id.
def put_wonder(p:int) -> int:
    let k = btype_index("wonder")
    let x = start_x[p] / 1000 + 4
    var y = start_y[p] / 1000 - 2
    while not can_build(x, y, 5, 0, false, false): y++
    let b = place(p, k, x, y)
    b_done[b] = 1
    b_hp[b] = bm_hp[p][k]
    return b_id[b]

def wonder_ticks_left() -> int: return if wonder_ids.length: wonder_hold - (tick - wonder_since[0]) else: -1

// Wonder victory: a finished Wonder that stands for the hold time wins for its owner's team; one
// knocked down stops its countdown (and another starts from the top); with the host switch off it's
// just a building. (The GDScript checks also read the "wonder" and "won" events, which Lobster's sim
// has no need of: the Wonders' list and the winner say the same.)
def test_wonder():
    let hold = 30  // seconds, so the test is quick
    let r = deep_copy(rules0)
    set(at(r, "wonder"), "hold_seconds", jint(hold))
    // 1. It stands: the countdown wins, not a second early.
    wonder_world(r)
    let wid = put_wonder(0)
    var seen = false
    while tick < (hold + 3) * 20 and winner < 0:
        tick_on()
        seen = seen or (wonder_ids.length == 1 and wonder_ids[0] == wid)
        if tick == (hold - 2) * 20:
            check(winner < 0 and wonder_ids.length == 1 and wonder_ticks_left() > 0, "wonder: no win while the countdown runs ({wonder_ticks_left()} ticks left)")
    check(seen, "wonder: its countdown starts once it\'s finished")
    check(winner == teams[0] and wonder_ids.length == 1 and wonder_ids[0] == wid, "wonder: standing {hold} s wins for its team (winner {winner} at tick {tick})")
    check(tick <= (hold + 2) * 20, "wonder: it wins on time (tick {tick})")
    let end_tick = tick
    let end_hash = state_hash()
    let end_winner = winner
    wonder_world(r)
    put_wonder(0)
    while tick < end_tick: tick_on()
    check(state_hash() == end_hash and winner == end_winner, "wonder: the same match twice, the same hash and winner")
    // 2. It falls: the countdown stops, and a new one starts from the top.
    wonder_world(r)
    let wid2 = put_wonder(0)
    steps(10 * 20)
    let b = b_index_of(wid2)
    b_hp[b] = 40  // nearly down: spearmen finish it
    spawn_cmd(1, "spear", 6, b_cx[b] * 1000 - 1500, b_cy[b] * 1000 + 2500)
    var spawned = false
    var fell = false
    while tick < (hold + 10) * 20 and not fell:
        tick_on()
        if not spawned:
            let mine = filter(ids_of(1)) id: t_worker[u_kind[index_of(id)]] == 0
            if mine.length == 6:
                issue_cmd(1, CMD_ATTACK, mine, wid2, 0, 0, 0)
                spawned = true
        fell = b_index_of(wid2) < 0
    steps(CHECK_EVERY)  // (the Wonders' list is kept once a second)
    check(fell and b_index_of(wid2) < 0 and wonder_ids.length == 0, "wonder: knocked down, its countdown stops (tick {tick})")
    let second = put_wonder(0)
    let started = tick
    while tick < started + (hold + 3) * 20 and winner < 0:
        tick_on()
        if tick == (hold + 12) * 20: check(winner < 0, "wonder: the fallen one\'s time doesn\'t count for the next")
    check(winner == teams[0] and tick - started >= hold * 20, "wonder: a new one counts from the top (won {(tick - started) / 20} s after it went up)")
    check(second != wid2, "wonder: (a different building)")
    // 3. The switch off: no countdown, no win.
    let off = deep_copy(r)
    set(at(off, "wonder"), "victory", jbool(false))
    wonder_world(off)
    put_wonder(0)
    steps((hold + 5) * 20)
    check(winner < 0 and wonder_ids.length == 0 and wonder_hold == 0, "wonder: with Wonder victory off it never wins")

// A match against a bot, saved at 4 minutes (a person's order still waiting to run), loaded and played
// on to 7 minutes: the same hashes as the match never stopped, so the bot came back as it was (D-140).
// (Lobster's saves are a flexbuffer of the sim's globals and the bots, for this build only: the
// GDScript checks of saves from other builds, migrated or refused, have nothing to check here. The
// bot plays at the normal level: the hard level isn't ported.)
def test_save_load():
    let at_t = 4800
    let to_t = 8400
    let rules = load_rules("default")
    let races = map(PROMPTS) p: generate(p, rules, 0)
    new_world("reed_meadow", races, rules, [])
    let you = EcoBot { 0 }  // "you": what it orders is like a person's clicks
    let bot = new_bot(1)
    while tick < at_t:
        bot_think(you)
        full_bot_think(bot)
        tick_on()
    issue_cmd(0, CMD_RALLY, [], b_id[0], 9000, 9000, 0)  // issued, not run yet
    let t0 = seconds_elapsed()
    let saved = world_bytes([ bot ])
    let save_ms = ms_since(t0)
    let save_hash = state_hash()
    let hashes = []::int
    let you_after = EcoBot { 0 }  // after the save "you" plays on the same way in both matches
    while tick < to_t:
        bot_think(you_after)
        full_bot_think(bot)
        tick_on()
        hashes.push(state_hash())
    let units_then = u_id.length
    reset_world()
    let t1 = seconds_elapsed()
    let loaded = load_world_bytes(saved)
    let load_ms = ms_since(t1)
    check(loaded.length == 1 and tick == at_t and state_hash() == save_hash, "the save loads as it was (tick {tick})")
    // a save from an older build has no column for a per-unit variable added since (D-141): it's padded with 0
    let carry_was = u_carry_kind
    u_carry_kind = []
    pad_saved_columns()
    check(u_carry_kind.length == u_id.length and not exists(u_carry_kind) k: k != 0, "a per-unit column a save lacks comes back padded with 0 ({u_carry_kind.length} units)")
    u_carry_kind = carry_was
    let you_b = EcoBot { 0 }
    var same = 0
    var n = 0
    while tick < to_t:
        bot_think(you_b)
        full_bot_think(loaded[0])
        tick_on()
        if hashes[n] == state_hash(): same++
        n++
    check(same == hashes.length, "played on from the save, the match matches one never stopped ({same} of {hashes.length} ticks)")
    check(hashes.length and state_hash() == hashes[hashes.length - 1], "and ends at the same state")
    reset_world()
    load_world_bytes(saved)
    check(state_hash() == save_hash, "playing on from a save leaves the save as it was")
    check(units_then > 40, "it was a real match ({units_then} units)")
    print "save/load: {saved.length / 1024} KB; save {save_ms} ms, load {load_ms} ms"

// ------------------------------------------------------------------ the parts

let PARTS = [ "fixed", "command_order", "source_lint", "flow", "crossing_flat", "crossing_choke", "crossing_engines",
              "combat", "opening", "shots", "engines", "trade", "sapper_sling", "gates", "diagonal_wall", "diagonal_gates",
              "walls", "siege_ways", "modes", "movement_classes", "land", "hills", "flow_patch", "flow_patch_mixed",
              "farms", "fog_memory", "age_timing", "builder_moves_on", "builder_back_to_work", "no_dark_picks", "wood_spots",
              "build_queue", "drop_off", "animals", "sheep_spot", "pen", "bot_hunts", "garrison", "towers",
              "camp_gather", "market", "effects", "university_castle", "research_queue", "tech", "queue", "wonder", "save_load", "match", "match_b", "match_flipped" ]

def run_part(name:string):
    if name == "fixed": test_fixed()
    elif name == "command_order": test_command_order()
    elif name == "source_lint": test_source_lint()
    elif name == "flow": test_flow()
    elif name == "crossing_flat": test_crossing("flat_test", false)
    elif name == "crossing_choke": test_crossing("choke_test", false)
    elif name == "crossing_engines":
        for([ "flat_test", "choke_test", "hill_test" ]) m: test_crossing(m, true)
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
    elif name == "farms": test_farms()
    elif name == "fog_memory": test_fog_memory()
    elif name == "age_timing": test_age_timing()
    elif name == "builder_moves_on": test_builder_moves_on()
    elif name == "builder_back_to_work": test_builder_back_to_work()
    elif name == "no_dark_picks": test_no_dark_picks()
    elif name == "wood_spots": test_wood_spots()
    elif name == "build_queue": test_build_queue()
    elif name == "drop_off": test_drop_off()
    elif name == "animals": test_animals()
    elif name == "sheep_spot": test_sheep_spot()
    elif name == "pen": test_pen()
    elif name == "bot_hunts": test_bot_hunts()
    elif name == "garrison": test_garrison()
    elif name == "towers": test_towers()
    elif name == "camp_gather": test_camp_gather()
    elif name == "market": test_market()
    elif name == "effects": test_effects()
    elif name == "university_castle": test_university_castle()
    elif name == "research_queue": test_research_queue()
    elif name == "tech": test_tech()
    elif name == "queue": test_queue()
    elif name == "wonder": test_wonder()
    elif name == "save_load": test_save_load()
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
