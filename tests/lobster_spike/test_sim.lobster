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
// - The Lobster sim has no SPAWN command: spawn() puts units down at once, jittered by the world's rng
//   as World's SPAWN does. So the scripted match's hashes are this port's own, not GDScript's (they're
//   compared run against run, as before).
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
    setup_world(SEED, map_id, races, rules, team_ids)

// World's SPAWN, now: `count` of p's `slot` round (x, y), jittered by the world's rng, onto open ground.
def spawn(p:int, slot:string, count:int, x:int, y:int) -> [int]:
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

def steps(n:int):
    for(n): step()

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
            spawn(0, rstr(at(u, "recipe"), "slot"), if engines: CROSS_ENGINES else: CROSS_UNITS, sx, sy)
    step()
    let ids = copy(u_id)
    let groups = (ids.length + CROSS_UNITS - 1) / CROSS_UNITS
    for(groups) g:
        issue_cmd(0, CMD_MOVE, ids.slice(g * CROSS_UNITS, min(CROSS_UNITS, ids.length - g * CROSS_UNITS)),
            dx + (g - groups / 2) * 1500, dy + ((g % 2) * 2 - 1) * 1000, 0, 0)
    step()
    var settled = -1
    var worst = 0.0
    let t0 = seconds_elapsed()
    var n = 0
    let t_first = tick
    while tick < t_first + CROSS_LIMIT and settled < 0:
        let s = seconds_elapsed()
        step()
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

class SpawnOrder:
    run_tick:int
    player:int
    slot:string
    count:int
    x:int
    y:int

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
            spawn(s.player, s.slot, s.count, s.x, s.y)
            next_spawn++
        let t0 = seconds_elapsed()
        step()
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
        step()
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

// ------------------------------------------------------------------ the parts

let PARTS = ["fixed", "command_order", "source_lint", "flow", "crossing_flat", "crossing_choke", "crossing_engines",
             "opening", "match", "match_b", "match_flipped"]

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
