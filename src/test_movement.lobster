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
import view.voxel

// Group movement, headless and seeded (#345, for the rewrite in #344): small groups and formations crossing, passing, going
// through a group that stands, funnelling through a gap, and two lines meeting. Every unit that walks is watched, in a block
// or not. Fails when a unit walks back and forth, turns while walking, faces away from where it walks, overlaps another,
// or doesn't settle. It prints the numbers.
// Run from src:  lobster test_movement.lobster -- [scene ...]   (every scene by default)

let SEED = 2026
let MOD = "big_battle"
let PROMPTS = [ "norse frogs", "centaurs" ]
let REVERSALS_MAX = 0.05  // steps back the way it was walking, a unit, a second
let FLIPS_MAX = 0.05      // facing flickers (to a facing and back within ZIGZAG_TICKS), a unit, a second
let FACE_OFF_MAX = 10     // percent of looks at a walking unit finding it facing over FACE_OFF from where it walks
let FACE_OFF = 50.0       // degrees
let FACE_WINDOW = 10      // ticks over which "where it walks" is taken
let FACE_WALKED = 300     // milli-tiles it must cover in that window to count as walking
let OVERLAP_MAX = 0.02    // share of watched units, a sample, standing within half their summed radii of another unit
let SETTLE_SECS = 2       // after the last one arrives, nobody still moving this long after
let SHOVED_MAX = 1500     // milli-tiles a standing group's units may be pushed from where they stood
let ZIGZAG_MAX = 0.1      // swerves one way then the other within ZIGZAG_TICKS, a unit, a second (a sway as it walks)
let ZIGZAG_TICKS = 20
let ZIGZAG_SIN = 260   // a swerve: a turn between ticks over about 15 degrees (sin, of 1024)
let WOBBLE_MAX = 0.05  // path walked over a FACE_WINDOW past the straight line, on average (0: dead straight)

class MoveWatch:
    ids:[int]
    last_x:[int] = []
    last_y:[int] = []
    step_x:[int] = []
    step_y:[int] = []
    face:[int] = []
    face_was:[int] = []
    face_tick:[int] = []
    turns:int = 0
    hist_x:[[int]] = []
    hist_y:[[int]] = []
    unit_ticks:int = 0
    reversals:int = 0
    flips:int = 0
    zigzags:int = 0
    turn_sign:[int] = []
    turn_tick:[int] = []
    path:[[int]] = []
    windows:int = 0
    wobble_sum:float = 0.0
    looks:int = 0
    off:int = 0
    samples:int = 0
    overlap_sum:float = 0.0
    overlap_worst:float = 0.0

def watch_new(ids:[int]) -> MoveWatch:
    let w = MoveWatch { ids }
    w.last_x = map(ids) id: u_x[index_of(id)]
    w.last_y = map(ids) id: u_y[index_of(id)]
    w.step_x = map(ids): 0
    w.step_y = map(ids): 0
    w.face = map(ids): 2
    w.face_was = map(ids): -1
    w.face_tick = map(ids): -1000
    w.hist_x = map(ids): map(FACE_WINDOW): -1
    w.hist_y = map(ids): map(FACE_WINDOW): -1
    w.turn_sign = map(ids): 0
    w.turn_tick = map(ids): -1000
    w.path = map(ids): map(FACE_WINDOW): 0
    return w

// The share of the watched units deep in another unit (any side, any group): within half their summed radii.
def overlap_of(ids:[int]) -> float:
    var close = 0
    var seen = 0
    for(ids) id:
        let i = index_of(id)
        if i >= 0:
            seen++
            var near = false
            for(u_id.length) j:
                if j != i and not near and t_air[u_kind[j]] == t_air[u_kind[i]]:
                    let rr = (u_radius[i] + u_radius[j]) / 2
                    if dist2(u_x[i], u_y[i], u_x[j], u_y[j]) < rr * rr: near = true
            if near: close++
    return float(close) / float(max(1, seen))

// One tick seen (after wstep): every watched unit walking by its own order, by its steps and its facing.
def watch_tick(w:MoveWatch):
    for(w.ids) id, a:
        let i = index_of(id)
        if i >= 0:
            let x = u_x[i]
            let y = u_y[i]
            let dx = x - w.last_x[a]
            let dy = y - w.last_y[a]
            let h = tick % FACE_WINDOW
            let ox = w.hist_x[a][h]
            let oy = w.hist_y[a][h]
            w.hist_x[a][h] = x
            w.hist_y[a][h] = y
            let walked_then = w.path[a][h]
            let step = isqrt(dx * dx + dy * dy)
            w.path[a][h] = step
            if u_moving[i] == 1 and u_foe[i] == 0:
                w.unit_ticks++
                let px = w.step_x[a]
                let py = w.step_y[a]
                let pl = isqrt(px * px + py * py)
                if step >= 10 and pl >= 10:
                    let sn = (px * dy - py * dx) * 1024 / (step * pl)
                    if abs(sn) >= ZIGZAG_SIN:
                        let sg = if sn > 0: 1 else: -1
                        if w.turn_sign[a] == -sg and tick - w.turn_tick[a] <= ZIGZAG_TICKS: w.zigzags++
                        w.turn_sign[a] = sg
                        w.turn_tick[a] = tick
                if ox >= 0:
                    let line = isqrt(dist2(ox, oy, x, y))
                    if line >= FACE_WALKED:
                        var total = 0
                        for(w.path[a]) p: total += p
                        total -= step - walked_then  // (the window's steps: this tick's in, the oldest out)
                        w.windows++
                        w.wobble_sum += float(max(0, total - line)) / float(line)
                if (dx != 0 or dy != 0) and (w.step_x[a] != 0 or w.step_y[a] != 0) and dx * w.step_x[a] + dy * w.step_y[a] < 0: w.reversals++
                let walking, nd = unit_walk(i, w.face[a], w.last_x[a], w.last_y[a])
                if walking:
                    if nd != w.face[a] and (w.step_x[a] != 0 or w.step_y[a] != 0):
                        w.turns++
                        if nd == w.face_was[a] and tick - w.face_tick[a] <= ZIGZAG_TICKS: w.flips++
                        w.face_was[a] = w.face[a]
                        w.face_tick[a] = tick
                    w.face[a] = nd
                    if ox >= 0 and dist2(ox, oy, x, y) >= FACE_WALKED * FACE_WALKED:
                        let way = atan2(normalize(iso(float(x - ox), float(y - oy))))
                        w.looks++
                        if abs((way - float(nd) * 45.0 + 540.0) % 360.0 - 180.0) > FACE_OFF: w.off++
            if dx != 0 or dy != 0:
                w.step_x[a] = dx
                w.step_y[a] = dy
            w.last_x[a] = x
            w.last_y[a] = y
    if tick % 10 == 0:
        let o = overlap_of(w.ids)
        w.samples++
        w.overlap_sum += o
        w.overlap_worst = max(w.overlap_worst, o)

def watch_report(name:string, w:MoveWatch):
    let secs = float(w.unit_ticks) / 20.0
    let rev = float(w.reversals) / max(secs, 1.0)
    let flips = float(w.flips) / max(secs, 1.0)
    let turns = float(w.turns) / max(secs, 1.0)
    let off = w.off * 100 / max(1, w.looks)
    let mean = w.overlap_sum / float(max(1, w.samples))
    let zig = float(w.zigzags) / max(secs, 1.0)
    let wob = w.wobble_sum / float(max(1, w.windows))
    print "{name}: swerves {fixed_str(zig, 3)} a unit a second; wobble {fixed_str(wob, 3)}"
    check(zig <= ZIGZAG_MAX, "{name}: no swaying side to side ({fixed_str(zig, 3)} a unit a second)")
    check(wob <= WOBBLE_MAX, "{name}: they walk straight ({fixed_str(wob, 3)} past the line)")
    print "{name}: {int(secs)} unit-seconds walking; reversals {fixed_str(rev, 3)}, turns {fixed_str(turns, 3)}, flickers {fixed_str(flips, 3)} a unit a second; facing off {off}% of {w.looks}; overlap mean {fixed_str(mean, 3)}, worst {fixed_str(w.overlap_worst, 3)}"
    check(w.unit_ticks > 0, "{name}: they walk")
    check(rev <= REVERSALS_MAX, "{name}: no walking back and forth ({fixed_str(rev, 3)} a unit a second)")
    check(flips <= FLIPS_MAX, "{name}: no facing flicker ({fixed_str(flips, 3)} a unit a second)")
    check(off <= FACE_OFF_MAX, "{name}: they face the way they walk ({off}% off)")
    check(mean <= OVERLAP_MAX, "{name}: nobody walks inside another ({fixed_str(mean, 3)} on average)")

// n of p's units of slot `slot` in a block of rows round (x, y), facing along +x: their ids.
def group(p:int, slot:string, n:int, x:int, y:int) -> [int]:
    var k = -1
    for(t_slot.length) kk:
        if k < 0 and t_player[kk] == p and t_slot[kk] == slot: k = kk
    assert k >= 0
    let ids = []::int
    let gap = t_radius[k] * 2 + 300
    let w = int(ceiling(sqrt(float(n))))
    for(n) at: ids.push(u_id[add_unit(p, k, x - (w * gap) / 2 + (at / w) * gap, y - (w * gap) / 2 + (at % w) * gap)])
    return ids

def any_moving(ids:[int]) -> bool: return (find(ids) id: index_of(id) >= 0 and u_moving[index_of(id)] == 1) >= 0

// Run until every one of ids has stopped (or `limit` ticks), watching; then they must stay still SETTLE_SECS.
def run_settle(name:string, w:MoveWatch, ids:[int], limit:int):
    let t0 = tick
    var done = -1
    while tick < t0 + limit and done < 0:
        wstep()
        watch_tick(w)
        if tick > t0 + 20 and not any_moving(ids): done = tick - t0
    watch_report(name, w)
    check(done >= 0, "{name}: everyone gets there within {limit / 20} s ({if done >= 0: done / 20 else: -1} s)")
    let was = map(ids) id: u_x[index_of(id)] * (1 << 20) + u_y[index_of(id)]
    for(SETTLE_SECS * 20): wstep()
    var moved = 0
    for(ids) id, a:
        let i = index_of(id)
        if u_x[i] * (1 << 20) + u_y[i] != was[a] or u_moving[i] == 1: moved++
    print "{name}: settled at {if done >= 0: string(done / 20) + " s" else: "never"}; {moved} still moving {SETTLE_SECS} s later"
    check(moved == 0, "{name}: everyone stands still once there ({moved} moving)")

def flat(races:[JV], rules:JV):
    new_world(SEED, "flat_test", races, rules, [])

// 1. A small group crosses open ground and stops.
def scene_small(rules:JV, races:[JV]):
    flat(races, rules)
    let a = group(0, "spear", 12, 16000, 32000)
    let w = watch_new(a)
    issue_cmd(0, CMD_MOVE, a, 46000, 32000, 0, 0)
    run_settle("small group", w, a, 1200)

// 2, 3. Two of the side's groups crossing at right angles, and passing head-on.
def scene_cross(rules:JV, races:[JV], head_on:bool):
    flat(races, rules)
    let a = group(0, "spear", 16, 16000, 32000)
    let b = if head_on: group(0, "large", 12, 48000, 32000) else: group(0, "large", 12, 32000, 14000)
    let both = a.append(b)
    let w = watch_new(both)
    issue_cmd(0, CMD_MOVE, a, 48000, 32000, 0, 0)
    issue_cmd(0, CMD_MOVE, b, if head_on: 16000 else: 32000, if head_on: 32000 else: 50000, 0, 0)
    run_settle(if head_on: "head-on" else: "crossing", w, both, 1600)

// 4. A group walks through a group of the side's own that stands; the standing one isn't shoved far.
def scene_through(rules:JV, races:[JV]):
    flat(races, rules)
    let still = group(0, "spear", 25, 32000, 32000)
    for(40): wstep()
    let was_x = map(still) id: u_x[index_of(id)]
    let was_y = map(still) id: u_y[index_of(id)]
    let a = group(0, "large", 12, 18000, 32000)
    let w = watch_new(a)
    issue_cmd(0, CMD_MOVE, a, 46000, 32000, 0, 0)
    run_settle("through a standing group", w, a, 1200)
    var worst = 0
    for(still) id, n:
        let i = index_of(id)
        worst = max(worst, isqrt(dist2(u_x[i], u_y[i], was_x[n], was_y[n])))
    print "through a standing group: the standing ones pushed up to {worst}"
    check(worst <= SHOVED_MAX, "through a standing group: the standing ones aren\'t shoved about ({worst})")

// 5. Cavalry funnel through the pass (choke_test: a 2-tile gap in a rock wall).
def scene_funnel(rules:JV, races:[JV]):
    new_world(SEED, "choke_test", races, rules, [])
    let a = group(0, "large", 16, 12000, 16000)
    let w = watch_new(a)
    issue_cmd(0, CMD_MOVE, a, 36000, 16000, 0, 0)
    run_settle("funnel", w, a, 2400)

// 6. Two enemy lines ordered at each other meet (#293): most of the front is fighting within the time it takes to walk there.
def scene_meet(rules:JV, races:[JV]):
    flat(races, rules)
    let a = group(0, "spear", 36, 14000, 32000)
    let b = group(1, "spear", 36, 50000, 32000)
    issue_cmd(0, CMD_ATTACK_MOVE, a, 50000, 32000, 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, b, 14000, 32000, 0, 0)
    let speed = min(u_speed[index_of(a[0])], u_speed[index_of(b[0])])
    let limit = 18000 / max(1, speed) + 200  // half the gap at the slower pace, plus 10 s to form and close
    let t0 = tick
    var best = 0
    while tick < t0 + limit:
        wstep()
        var fighting = 0
        for(a.append(b)) id:
            let i = index_of(id)
            if i >= 0 and u_foe[i] != 0:
                let f = index_of(u_foe[i])
                if f >= 0:
                    let reach = t_reach[u_kind[i]] + u_radius[i] + u_radius[f] + 300
                    if dist2(u_x[i], u_y[i], u_x[f], u_y[f]) <= reach * reach: fighting++
        best = max(best, fighting)
    print "lines meet: at best {best} of {a.length + b.length} trading blows within {limit / 20} s"
    check(best * 2 >= a.length + b.length, "lines meet: half of them trade blows within {limit / 20} s ({best})")

// n of p's soldiers of every type, 20 to a row from (x, y): their ids.
def mixed(p:int, n:int, x:int, y:int) -> [int]:
    let kinds = []::int
    for(t_slot.length) k:
        if t_player[k] == p and not t_worker[k] and t_animal[k] == 0 and t_trader[k] == 0 and t_healer[k] == 0: kinds.push(k)
    return map(n) at: u_id[add_unit(p, kinds[at % kinds.length], x + (at % 20) * 800, y + (at / 20) * 800)]

// 8. Two of the side's big armies (marching blocks) cross at right angles on the framed field (#328's picture).
def scene_blocks(rules:JV, races:[JV]):
    new_world(SEED, "open_field", races, rules, [])
    let mx = (start_x[0] + start_x[1]) / 2
    let my = (start_y[0] + start_y[1]) / 2
    let ax = mx - 30000
    let by = my - 30000
    let a = mixed(0, 200, ax - 8000, my - 4000)
    let b = mixed(0, 200, mx - 8000, by - 4000)
    let both = a.append(b)
    let w = watch_new(both)
    issue_cmd(0, CMD_MOVE, a, mx + 30000, my, 0, 0)
    issue_cmd(0, CMD_MOVE, b, mx, my + 30000, 0, 0)
    run_settle("blocks crossing", w, both, 4000)

// 7. Once the front halts, the blocks behind don't walk into it (#312), on the framed field with the filming armies.
def scene_queue(rules:JV, races:[JV]):
    new_world(SEED, "open_field", races, rules, [])
    let ids = mixed(0, 400, start_x[0], start_y[0])
    let foes = group(1, "spear", 100, (start_x[0] + start_x[1]) / 2, (start_y[0] + start_y[1]) / 2)
    issue_cmd(0, CMD_ATTACK_MOVE, ids, start_x[1], start_y[1], 0, 0)
    var mixed_worst = 0
    var after = 0
    while tick < 3000:
        wstep()
        if (find(ids) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0) >= 0: after++
        if after > 0 and tick % 20 == 0:
            // units marching with their block found among another block's marchers
            var mixed = 0
            for(ids) id:
                let i = index_of(id)
                if i >= 0 and u_block[i] > 0 and u_foe[i] == 0:
                    var inside = false
                    for(ids) jd:
                        let j = index_of(jd)
                        if not inside and j >= 0 and u_block[j] > 0 and u_block[j] != u_block[i] and u_foe[j] == 0:
                            let rr = (u_radius[i] + u_radius[j]) / 2
                            if dist2(u_x[i], u_y[i], u_x[j], u_y[j]) < rr * rr: inside = true
                    if inside: mixed++
            mixed_worst = max(mixed_worst, mixed)
    print "queue: after contact, up to {mixed_worst} units inside another block ({foes.length} foes)"
    check(after > 0, "queue: the front meets the foe")
    check(mixed_worst * 50 <= ids.length, "queue: blocks behind don\'t walk into the ones ahead ({mixed_worst})")

let args = plain_args(command_line_arguments())
vx_load([ "../data/voxel" ])
lib_load("../data")
id_load("../data")
let used = mods_use([ MOD ])
check(used.length == 1, "the mod loads ({used})")
let rules = load_rules("default")
let races = map(PROMPTS) p: generate(p, rules, 0)
def on(s:string) -> bool: return args.length == 0 or (find(args) a: a == s) >= 0
if on("small"): scene_small(rules, races)
if on("crossing"): scene_cross(rules, races, false)
if on("head_on"): scene_cross(rules, races, true)
if on("through"): scene_through(rules, races)
if on("funnel"): scene_funnel(rules, races)
if on("meet"): scene_meet(rules, races)
if on("queue"): scene_queue(rules, races)
if on("blocks"): scene_blocks(rules, races)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
