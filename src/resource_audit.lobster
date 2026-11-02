// A map's resources and how long they last (tests/resource_audit.gd, ported):
// 1. A count: each resource within `radius` tiles of each start (food from wild bushes and the animals placed
//    there), and in contested ground (near no start).
// 2. Matches, each up to `minutes` game minutes (or a winner), per minute per side: what was gathered that
//    minute, what's left near home, idle workers, workers gathering far from home; then when each resource ran
//    out near each start. bots: bot v bot; passive: a bot v a side that only runs its economy; peace: two bots
//    that never attack, so the economy runs the whole time through the ages.
// Run from src:  lobster resource_audit.lobster -- <map_id> [minutes] [radius] [bots,passive,peace]

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
import testkit.kit

let SEED = 7
let MIN = 1200  // ticks in a minute

let args = plain_args(command_line_arguments())
let map_id = if args.length > 0: args[0] else: "flat_test"
let minutes = if args.length > 1: string_to_int(args[1]) else: 40
let radius = if args.length > 2: string_to_int(args[2]) else: 16
let runs = tokenize(if args.length > 3: args[3] else: "bots,passive,peace", ",", " ")
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let frogs = generate("angry swamp frogs with reed spears", rules, 0)
let rats = generate("sewer rats with cheese hammers", rules, 0)

// Which start a cell belongs to (within radius tiles), or -1 for contested ground.
def owner_of(x:int, y:int) -> int:
    for(start_x.length) p:
        let dx = x - start_x[p] / TILE
        let dy = y - start_y[p] / TILE
        if dx * dx + dy * dy <= radius * radius: return p
    return -1

def region_of(x:int, y:int) -> int:
    let o = owner_of(x, y)
    return if o >= 0: o else: start_x.length

// Resources left per region (starts..., contested) per resource, from the map's cells (farms left out:
// they're bought, not found) and the animals still walking about.
def left_now() -> [[int]]:
    let out = map(start_x.length + 1): map(num_resources): 0
    for(resource_cells) c:
        if pool[c] < 0 and amount[c] > 0:
            let kind = tr_res[terrain[c]]
            if kind > 0: out[region_of(c % W, c / W)][kind - 1] += amount[c]
    let food = resource_index("food")
    for(u_kind) k, i:
        if t_animal[k] != 0: out[region_of(u_x[i] / TILE, u_y[i] / TILE)][food] += t_food[k]
    return out

// "{a n, b m}" of names counted, sorted.
def tally_str(names:[string]) -> string:
    let keys = []::string
    let counts = []::int
    for(names) n:
        let at_n = find_index(keys, n)
        if at_n >= 0: counts[at_n]++
        else:
            keys.push(n)
            counts.push(1)
    let order = map(keys.length) k: k
    insertion_sort(order) x, y: keys[x] < keys[y]
    return "\{" + concat_string(map(order) k: keys[k] + " " + string(counts[k]), ", ") + "\}"

def count_map():
    new_world(SEED, map_id, [ frogs, rats ], rules, [])
    print "== {map_id}: {W} x {H}, {start_x.length} starts, home radius {radius} tiles"
    let left = left_now()
    let regions = start_x.length + 1
    let tiles = map(regions): []::string
    for(resource_cells) c: tiles[region_of(c % W, c / W)].push(tr_names[terrain[c]])
    let beasts = map(regions): []::string
    for(u_kind) k, i:
        if t_animal[k] != 0: beasts[region_of(u_x[i] / TILE, u_y[i] / TILE)].push(su_type_animal[k])
    let total = map(num_resources): 0
    for(regions) k:
        let label = if k < start_x.length: "start {k} [{start_x[k] / TILE}, {start_y[k] / TILE}]" else: "contested"
        let parts = map(num_resources) r: resource_names[r] + " " + string(left[k][r])
        for(num_resources) r: total[r] += left[k][r]
        print "  " + pad_right(label, 18) + " " + concat_string(parts, ", ") + "   tiles " + tally_str(tiles[k]) + "   animals " + tally_str(beasts[k])
    print "  " + pad_right("map total", 18) + " " + concat_string(map(num_resources) r: resource_names[r] + " " + string(total[r]), ", ")

def gathered_of(p:int) -> [int]: return map(num_resources) r: gathered[r][p]

// Player p's workers: how many, idle (no task, not hunting, standing), and far (gathering or carrying from a
// tile beyond the home radius of their start).
def workers_of(p:int) -> int, int, int:
    var count = 0
    var idle = 0
    var far = 0
    for(u_owner) o, i:
        if o == p and t_worker[u_kind[i]]:
            count++
            if u_task[i] == T_NONE and u_foe[i] == 0 and u_moving[i] == 0: idle++
            elif (u_task[i] == GATHER or u_task[i] == T_RETURN) and u_home[i] >= 0:
                let h = u_home[i]
                if owner_of(h % W, h / W) != p: far++
    return count, idle, far

def slash(xs:[int]) -> string: return concat_string(map(xs) v: string(v), "/")

def play(races:[JV], full:[bool], peace:bool, title:string):
    new_world(SEED, map_id, races, rules, [])
    if peace:
        ai_config("normal") c:
            for(glist(at(c, "military"), "waves")) wv: set(wv, "at", jint(1 << 30))
            set(at(c, "military"), "repeat_every", jint(1 << 30))
    let sides = map(2) p: if full[p]: full_side(p) else: eco_side(p)
    let players = races.length
    print "\n== {title} on {map_id} (" + rstr(races[0], "name") + " vs " + rstr(races[1], "name") + "), up to {minutes} minutes"
    print "  per side: age, workers, idle, far (gathering beyond {radius} tiles), gathered this minute F/W/S/G, left near home F/W/S/G"
    let start_left = left_now()
    let ran_out = map(players): map(num_resources): -1
    let last = map(players) p: gathered_of(p)
    let aged = map(players): [ -1, -1 ]
    let idle_sum = map(players): 0
    let far_sum = map(players): 0
    var looks = 0
    var step_s = 0.0
    var bot_s = 0.0
    var worst = 0.0
    while tick < minutes * MIN and winner < 0:
        let t0 = seconds_elapsed()
        think_all(sides)
        let t1 = seconds_elapsed()
        wstep()
        let t2 = seconds_elapsed()
        step_s += t2 - t1
        bot_s += t1 - t0
        worst = max(worst, t2 - t1)
        for(players) p:
            for(2) a:
                if aged[p][a] < 0 and ages[p] >= a + 2: aged[p][a] = tick
        if tick % 200 == 0:  // every 10 s: idle and far workers, and what's run out
            looks++
            let left = left_now()
            for(players) p:
                let _n, idle, far = workers_of(p)
                idle_sum[p] += idle
                far_sum[p] += far
                for(num_resources) r:
                    if ran_out[p][r] < 0 and start_left[p][r] > 0 and left[p][r] <= 0: ran_out[p][r] = tick
        if tick % MIN == 0:
            let left = left_now()
            var line = "  " + pad_left(string(tick / MIN), 2) + ":00"
            for(players) p:
                let g = gathered_of(p)
                let got = map(num_resources) r: g[r] - last[p][r]
                last[p] = g
                let n, idle, far = workers_of(p)
                line += "  | P{p} a{ages[p]} " + pad_left(string(n), 2) + "w " + pad_left(string(idle), 2) + "i " + pad_left(string(far), 2) + "f  +" + slash(got) + "  left " + slash(left[p])
            line += "  | mid " + slash(left[players])
            print line
    print "  ended {clock(tick)}, winner {winner}; sim tick avg " + fixed_str(step_s * 1000.0 / max(1, tick), 2) + " ms (worst " + fixed_str(worst * 1000.0, 1) +
        " ms), bots " + fixed_str(bot_s * 1000.0 / max(1, tick), 2) + " ms a tick"
    for(players) p:
        let outs = map(num_resources) r: resource_names[r] + " " + (if ran_out[p][r] >= 0: clock(ran_out[p][r]) elif start_left[p][r] > 0: "never" else: "none there")
        print "  P{p}: age 2 at {clock(aged[p][0])}, age 3 at {clock(aged[p][1])}; gathered {slash(gathered_of(p))}; units lost {lost[p]}; avg idle " +
            fixed_str(float(idle_sum[p]) / max(1, looks), 1) + ", avg far " + fixed_str(float(far_sum[p]) / max(1, looks), 1) + "; ran out near home: " + concat_string(outs, ", ")

let t_all = seconds_elapsed()
count_map()
if find_index(runs, "bots") >= 0: play([ frogs, rats ], [ true, true ], false, "bot vs bot")
if find_index(runs, "passive") >= 0: play([ rats, frogs ], [ true, false ], false, "bot vs passive")
if find_index(runs, "peace") >= 0: play([ frogs, rats ], [ true, true ], true, "peace (bots that never attack)")
print "({int(seconds_elapsed() - t_all)} s)"
