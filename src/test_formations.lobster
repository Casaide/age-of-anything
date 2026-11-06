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
import gen.mods
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
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import gen.reset
import testkit.kit
import view.facing

// Big armies in formation, headless and seeded (#171): an army of several blocks on open ground, a plain move and an
// attack-move. Fails when a unit drifts from its place, walks back and forth, turns on the march, overlaps its neighbours,
// keeps moving once it's there, or doesn't come back to its place after a fight. It prints the numbers.
// Run from src:  lobster test_formations.lobster -- [units a side...]   (125 1000)

let SEED = 2026
let MAP = "open_field"
let MOD = "big_battle"
let PROMPTS = [ "norse frogs", "centaurs" ]
let DRIFT_P99 = 1000      // milli-tiles from its place on the march, 99% of units
let DRIFT_MAX = 4000      // and the worst
let REVERSALS_MAX = 0.05  // steps back the way it came, a unit, a second, on the march
let FLIPS_MAX = 0.05      // turns of facing, a unit, a second, on the march
let OVERLAP_MAX = 0.01    // units a sample standing within half their summed radii of another of their block
let SETTLED_DIST = 600    // milli-tiles from its final place once it's there

def fields(p:int) -> [int]:
    let kinds = []::int
    for(t_slot.length) k:
        if t_player[k] == p and not t_worker[k] and t_animal[k] == 0 and t_trader[k] == 0 and t_healer[k] == 0: kinds.push(k)
    return kinds

// n of p's soldiers of every type (an eighth of the engines) in ranks by (x, y): their ids.
def army(p:int, n:int, x:int, y:int) -> [int]:
    let kinds = fields(p)
    let ids = []::int
    let side = int(ceiling(sqrt(float(n)))) * 700
    var round = 0
    while ids.length < n:
        for(kinds) k:
            if ids.length < n and (round % 8 == 0 or not has(gobj(su_units[k], "look"), "crew")):
                let at = ids.length
                let w = side / 700
                ids.push(u_id[add_unit(p, k, x - side / 2 + (at % w) * 700, y - side / 2 + (at / w) * 700)])
        round++
    return ids

def p99(xs:[int]) -> int:
    let s = copy(xs)
    sort_ints(s)
    return if s.length: s[(s.length * 99) / 100] else: 0

class FormWatch:
    ids:[int]
    last_x:[int] = []
    last_y:[int] = []
    step_x:[int] = []
    step_y:[int] = []
    face:[int] = []
    unit_ticks:int = 0
    reversals:int = 0
    flips:int = 0
    drifts:[int] = []
    overlap_worst:float = 0.0

def begin(w:FormWatch):
    w.last_x = map(w.ids) id: if index_of(id) >= 0: u_x[index_of(id)] else: 0
    w.last_y = map(w.ids) id: if index_of(id) >= 0: u_y[index_of(id)] else: 0
    w.step_x = map(w.ids): 0
    w.step_y = map(w.ids): 0
    w.face = map(w.ids): 2

def overlap(ids:[int]) -> float:
    var close = 0
    let xs = filter(map(ids) id: index_of(id)) i: i >= 0
    for(xs) i, a:
        var near = false
        for(xs) j, b:
            if a != b and u_block[i] > 0 and u_block[i] == u_block[j] and fb_state[u_block[i] - 1] == BLOCK_MARCHING:
                let rr = (u_radius[i] + u_radius[j]) / 2
                if dist2(u_x[i], u_y[i], u_x[j], u_y[j]) < rr * rr: near = true
        if near: close++
    return float(close) / float(max(1, xs.length))

// One tick seen: the units marching in formation, by their steps and their facing.
def watch_march(w:FormWatch):
    for(w.ids) id, a:
        let i = index_of(id)
        if i >= 0:
            let b = u_block[i] - 1
            let x = u_x[i]
            let y = u_y[i]
            let dx = x - w.last_x[a]
            let dy = y - w.last_y[a]
            if b >= 0 and fb_state[b] == BLOCK_MARCHING and u_foe[i] == 0:
                w.unit_ticks++
                if (dx != 0 or dy != 0) and (w.step_x[a] != 0 or w.step_y[a] != 0) and dx * w.step_x[a] + dy * w.step_y[a] < 0: w.reversals++
                let walking, nd = unit_walk(i, w.face[a], w.last_x[a], w.last_y[a])
                if walking:
                    if nd != w.face[a] and w.step_x[a] != 0: w.flips++
                    w.face[a] = nd
                if tick % 20 == 0: w.drifts.push(isqrt(dist2(x, y, fb_x[b] + u_bx[i], fb_y[b] + u_by[i])))
            if dx != 0 or dy != 0:
                w.step_x[a] = dx
                w.step_y[a] = dy
            w.last_x[a] = x
            w.last_y[a] = y
    if tick % 100 == 0: w.overlap_worst = max(w.overlap_worst, overlap(w.ids))

def report(name:string, w:FormWatch):
    let secs = float(w.unit_ticks) / 20.0
    let rev = float(w.reversals) / max(secs, 1.0)
    let flips = float(w.flips) / max(secs, 1.0)
    var worst = 0
    for(w.drifts) d: worst = max(worst, d)
    print "{name}: on the march {int(secs)} unit-seconds; drift p99 {p99(w.drifts)}, worst {worst}; reversals {fixed_str(rev, 3)}, turns {fixed_str(flips, 3)} a unit a second; overlap {fixed_str(w.overlap_worst, 3)}"
    check(w.unit_ticks > 0, "{name}: units march in blocks")
    check(p99(w.drifts) <= DRIFT_P99, "{name}: 99% within {DRIFT_P99} of their places on the march ({p99(w.drifts)})")
    check(worst <= DRIFT_MAX, "{name}: nobody over {DRIFT_MAX} from its place on the march ({worst})")
    check(rev <= REVERSALS_MAX, "{name}: no walking back and forth ({fixed_str(rev, 3)} a unit a second)")
    check(flips <= FLIPS_MAX, "{name}: no turning on the march ({fixed_str(flips, 3)} a unit a second)")
    check(w.overlap_worst <= max(OVERLAP_MAX, 2.0 / float(w.ids.length)),  // (a small army: one pair passing, for a moment, is allowed)
          "{name}: inside a block nobody overlaps ({fixed_str(w.overlap_worst, 3)})")

def blocks_in_use(ids:[int]) -> int:
    let seen = []::int
    for(ids) id:
        let i = index_of(id)
        if i >= 0 and u_block[i] > 0 and not contains(seen, u_block[i]): seen.push(u_block[i])
    return seen.length

def scene_move(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let mid_x = (start_x[0] + start_x[1]) / 2
    let mid_y = (start_y[0] + start_y[1]) / 2
    let ids = army(0, n, start_x[0], start_y[0])
    let w = FormWatch { ids }
    begin(w)
    issue_cmd(0, CMD_MOVE, ids, mid_x, mid_y, 0, 0)
    for(60): wstep()
    let name = "move {n}"
    let blocks = blocks_in_use(ids)
    print "{name}: {blocks} blocks"
    check(blocks >= n / BLOCK_MAX, "{name}: a big army is several blocks ({blocks})")
    begin(w)
    var arrived_at = -1
    while tick < 6000 and arrived_at < 0:
        wstep()
        watch_march(w)
        if (find(ids) id: index_of(id) >= 0 and u_moving[index_of(id)] == 1) < 0: arrived_at = tick
    report(name, w)
    check(arrived_at >= 0, "{name}: everyone gets there (tick {tick})")
    for(40): wstep()
    let left = filter(ids) id: index_of(id) >= 0
    let was = map(left) id: u_x[index_of(id)] * (1 << 20) + u_y[index_of(id)]
    for(40): wstep()
    var moved = 0
    var off = []::int
    for(left) id, a:
        let i = index_of(id)
        if u_x[i] * (1 << 20) + u_y[i] != was[a] or u_moving[i] == 1: moved++
        off.push(isqrt(dist2(u_x[i], u_y[i], u_tx[i], u_ty[i])))
    print "{name}: settled: {moved} still moving, p99 {p99(off)} from their places"
    check(moved == 0, "{name}: everyone stands still once there ({moved} moving)")
    check(p99(off) <= SETTLED_DIST, "{name}: settled in their places ({p99(off)})")

def scene_attack(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let mid_x = (start_x[0] + start_x[1]) / 2
    let mid_y = (start_y[0] + start_y[1]) / 2
    let mine = army(0, n, start_x[0], start_y[0])
    let foes = army(1, n, start_x[1], start_y[1])
    let w = FormWatch { mine }
    begin(w)
    issue_cmd(0, CMD_ATTACK_MOVE, mine, mid_x, mid_y, 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, foes, mid_x, mid_y, 0, 0)
    for(60): wstep()
    begin(w)
    let name = "attack-move {n}"
    def fighting() -> int: return (filter(mine) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0).length
    while tick < 6000 and fighting() * 20 < n:
        wstep()
        watch_march(w)
    report(name, w)
    check(fighting() * 20 >= n, "{name}: the armies meet (tick {tick})")
    for(200): wstep()
    // the foes gone: back to their places and on
    for(foes) id:
        let i = index_of(id)
        if i >= 0: remove_unit(i)
    for(400): wstep()
    let left = filter(mine) id: index_of(id) >= 0
    let off = []::int
    var chasing = 0
    var strayed = 0
    for(left) id:
        let i = index_of(id)
        let b = u_block[i] - 1
        if u_foe[i] != 0: chasing++
        if b < 0: strayed++
        else: off.push(isqrt(dist2(u_x[i], u_y[i], fb_x[b] + u_bx[i], fb_y[b] + u_by[i])))
    print "{name}: after the fight: {left.length} left, {strayed} out of their blocks, {chasing} still chasing, p99 {p99(off)} from their places"
    check(strayed * 20 <= left.length, "{name}: they stay in their blocks through a fight ({strayed} out)")
    check(p99(off) <= DRIFT_P99 * 2, "{name}: back in their places after the fight ({p99(off)})")

// The filming setup: each army ordered at the other's base, put straight in its blocks. They must meet still formed.
def scene_film(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let one = army(0, n, start_x[0] + 4000, start_y[0] + 4000)
    let two = army(1, n, start_x[1] + 4000, start_y[1] + 4000)
    issue_cmd(0, CMD_ATTACK_MOVE, one, start_x[1], start_y[1], 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, two, start_x[0], start_y[0], 0, 0)
    while tick < 200 and (find(fb_state) s: s != 0) < 0: wstep()
    blocks_snap()
    let name = "film {n}"
    var contact = -1
    let everyone = one.append(two)
    while tick < 6000 and contact < 0:
        wstep()
        if (find(everyone) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0) >= 0: contact = tick
    let off = []::int
    for(everyone) id:
        let i = index_of(id)
        if i >= 0 and u_block[i] > 0 and u_foe[i] == 0:
            let b = u_block[i] - 1
            off.push(isqrt(dist2(u_x[i], u_y[i], fb_x[b] + u_bx[i], fb_y[b] + u_by[i])))
    print "{name}: first contact at tick {contact} ({contact / 20} s), p99 {p99(off)} from their places"
    check(contact >= 400, "{name}: a march to film before they meet ({contact / 20} s)")
    check(p99(off) <= DRIFT_P99, "{name}: formed when they meet ({p99(off)})")

// A bot gives its army the same order again and again: that mustn't stop the march to form up each time.
def scene_reissue(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let mid_x = (start_x[0] + start_x[1]) / 2
    let mid_y = (start_y[0] + start_y[1]) / 2
    let ids = army(0, n, start_x[0], start_y[0])
    issue_cmd(0, CMD_ATTACK_MOVE, ids, mid_x, mid_y, 0, 0)
    def arrive(again:int) -> int:
        while tick < 6000:
            if again > 0 and tick % again == 0: issue_cmd(0, CMD_ATTACK_MOVE, filter(ids) id: index_of(id) >= 0, mid_x, mid_y, 0, 0)
            wstep()
            if tick > 100 and (find(ids) id: index_of(id) >= 0 and u_moving[index_of(id)] == 1) < 0: return tick
        return tick
    let once = arrive(0)
    new_world(SEED, MAP, races, rules, [])
    let ids2 = army(0, n, start_x[0], start_y[0])
    issue_cmd(0, CMD_ATTACK_MOVE, ids2, mid_x, mid_y, 0, 0)
    var at = 0
    while tick < 6000 and at == 0:
        if tick % 200 == 0: issue_cmd(0, CMD_ATTACK_MOVE, filter(ids2) id: index_of(id) >= 0, mid_x, mid_y, 0, 0)
        wstep()
        if tick > 100 and (find(ids2) id: index_of(id) >= 0 and u_moving[index_of(id)] == 1) < 0: at = tick
    print "reissue {n}: there at tick {once} with one order, {at} told every 10 s"
    check(at > 0 and at <= once + once / 5, "reissue {n}: the same order again does not hold them up ({at} against {once})")

// The trailer's field: a wide clear middle along the line between the starts, framed by hills, a river on one side,
// groves, rocks and a ruin; nothing in the way of 2,000 units.
def scene_map():
    let launch = mods_launch_args([ MOD ])
    print "the mod starts with: {launch}"
    for([ "map:open_field", "skirmish", "reveal", "watch", "army:107", "zoom:1", "races:norse frogs|centaurs" ]) want:
        check(has_s(launch, want), "the mod starts with {want}")
    let d = load_json("../mods/" + MOD + "/data/maps/" + MAP + ".json")
    let w = gint(d, "width", 0)
    let h = gint(d, "height", 0)
    check(w >= 150 and h >= 150, "the map is big enough for 2,000 ({w} by {h})")
    let legend = gobj(d, "legend")
    let rows = gstrs(d, "rows")
    let heights = gstrs(d, "heights")
    let counts = dictionary<string, int>(32)
    var in_middle = 0
    var rivers_a = 0
    var rivers_b = 0
    var river_near = 0
    var uphill = 0
    var slopes = 0
    let starts = glist(d, "starts")
    let ax = as_int(starts[0].a[0])
    let ay = as_int(starts[0].a[1])
    let bx = as_int(starts[1].a[0])
    let by = as_int(starts[1].a[1])
    let lx = bx - ax
    let ly = by - ay
    let len2 = max(1, lx * lx + ly * ly)
    for(rows) row, y:
        for(w) x:
            let name = as_str(at(legend, unicode_to_string([ row[x] ])))
            counts.set(name, counts.get(name, 0) + 1)
            let along = (x - ax) * lx + (y - ay) * ly
            let across = ((x - ax) * ly - (y - ay) * lx) * 1000 / isqrt(len2)
            let river = name == "river" or name == "deep_river" or name == "water"
            if along >= 0 and along <= len2 and abs(across) <= 35000 and name != "grass": in_middle++
            if river:
                if across > 0: rivers_a++
                else: rivers_b++
                if abs(across) < 50000: river_near++
            if heights.length:
                if heights[y][x] >= '1' and heights[y][x] <= '3': uphill++
                if heights[y][x] >= 'a' and heights[y][x] <= 'c': slopes++
    // groves on a 12-tile lattice read as a pattern: the flanks' trees within 5 tiles of a lattice square's middle (spread evenly: about 0.55)
    var on_lattice = 0
    var flank_trees = 0
    for(rows) row, y:
        for(w) x:
            if row[x] == 'T' and abs(x - y) > 58 and abs(x - y) < 74:
                flank_trees++
                let dx = x % 12 - 6
                let dy = y % 12 - 6
                if dx * dx + dy * dy < 25: on_lattice++
    let lattice = float(on_lattice) / float(max(1, flank_trees))
    print "the map: groves repeat {fixed_str(lattice, 3)}"
    check(lattice <= 0.75, "the groves don\'t sit on a lattice ({fixed_str(lattice, 3)})")
    print "the map: {w} by {h}, {counts.get("tree", 0)} trees, {counts.get("rock", 0)} rock, {counts.get("rubble", 0)} rubble, river {rivers_a}/{rivers_b}, {uphill} high, {slopes} slope, {in_middle} in the middle"
    check(in_middle == 0, "the middle is clear ({in_middle} cells in the way)")
    check(rivers_a + rivers_b >= 100 and min(rivers_a, rivers_b) == 0 and river_near == 0, "a river on one side, off the field ({rivers_a}/{rivers_b}, {river_near} near)")
    check(counts.get("tree", 0) >= 400, "groves frame it ({counts.get("tree", 0)} trees)")
    check(counts.get("rock", 0) >= 40, "rocks on the edges ({counts.get("rock", 0)})")
    check(counts.get("rubble", 0) >= 12, "a ruin by the edge ({counts.get("rubble", 0)})")
    check(uphill >= 300 and slopes >= 40, "hills on the flank that can be crested ({uphill} high, {slopes} slope)")

let args = plain_args(command_line_arguments())
lib_load("../data")
id_load("../data")
let used = mods_use([ MOD ])
check(used.length == 1, "the mod loads ({used})")
let rules = load_rules("default")
let races = map(PROMPTS) p: generate(p, rules, 0)
scene_map()
for(if args.length: map(args) a: string_to_int(a) else: [ 125, 1000 ]) n:
    scene_move(rules, races, n)
    scene_attack(rules, races, n)
    scene_reissue(rules, races, n)
    scene_film(rules, races, n)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
