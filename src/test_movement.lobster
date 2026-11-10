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
import view.vox
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
let DUEL_TICKS = 600      // 30 s of the fight
let DUEL_ENGAGED = 65     // percent of the living with a foe, at best (74 when it was written)
let DUEL_PILE = 3         // hand to hand on one foe at most (2 when it was written)
let DUEL_SUITED = 40      // percent of picks a foe it counters, at least (55 when it was written)
let GATHER_TICKS = 2400   // two minutes of trips
let FACE_BACK = 112.5     // degrees: facing more than this from where it walks is walking backwards
let BACK_WINDOW = 4       // ticks: where it walks, over a turn's worth of steps
let BACK_WALKED = 100     // milli-tiles in them: it's really walking
let FACE_OFF_MAX = 10     // percent of looks at a walking unit finding it facing over FACE_OFF from where it walks
let FACE_OFF = 50.0       // degrees
let FACE_WINDOW = 10      // ticks over which "where it walks" is taken
let FACE_WALKED = 300     // milli-tiles it must cover in that window to count as walking
let OVERLAP_MAX = 0.02    // share of watched units, a sample, standing within half their summed radii of another unit
let PAST_SETTLE = 200     // ticks for the archers to stand and shoot
let PAST_TICKS = 600      // the spearmen's time to get to the building
let HERD_TICKS = 2400     // two minutes for the herd to get through
let HERD_PAST = 30000     // milli-tiles: the far side of the gap
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

// The other side's start units taken off: a move, not a fight (by an enemy, a group doesn't form up, #347).
def no_foes():
    var k = u_x.length
    while k > 0:
        k--
        if u_owner[k] == 1: remove_unit(k)

def flat(races:[JV], rules:JV):
    new_world(SEED, "flat_test", races, rules, [])
    no_foes()  // (they stand by where the head-on group starts)

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

// 4c. Spearmen sent at a building past their own archers, who stand shooting it in their way (#391): they get round them.
def scene_past_archers(rules:JV, races:[JV]):
    flat(races, rules)
    let hk = btype_index("town_center")
    let hb = place(1, hk, 40, 30)
    b_done[hb] = 1
    b_hp[hb] = bm_hp[1][hk] * 50  // (it stands the whole scene)
    let sk = btype_index("house")
    let sb = place(0, sk, 35, 31)  // (their own house in the way)
    b_done[sb] = 1
    let bows = group(0, "archer", 16, 36500, 32000)
    issue_cmd(0, CMD_ATTACK, bows, b_id[hb], 0, 0, 0)
    for(PAST_SETTLE): wstep()
    let a = group(0, "spear", 6, 32500, 32000)
    issue_cmd(0, CMD_ATTACK, a, b_id[hb], 0, 0, 0)
    for(PAST_TICKS): wstep()
    var there = 0
    for(a) id:
        let i = index_of(id)
        if gap_b(i, hb) <= t_reach[u_kind[i]] + REACH: there++
    print "past archers: {there} of {a.length} spearmen at the building after {PAST_TICKS / 20} s"
    check(there == a.length, "past archers: every spearman gets past its own archers to the building ({there} of {a.length})")

// 5. Cavalry funnel through the pass (choke_test: a 2-tile gap in a rock wall).
def scene_funnel(rules:JV, races:[JV]):
    new_world(SEED, "choke_test", races, rules, [])
    no_foes()  // (the other side's start units stand 5 tiles past the gap)
    let a = group(0, "large", 16, 12000, 16000)
    let w = watch_new(a)
    issue_cmd(0, CMD_MOVE, a, 36000, 16000, 0, 0)
    run_settle("funnel", w, a, 2400)

// 5b. A crowd of loose units, each on its own way (workers, a herd: no group, no block), through the same gap (#382): nobody
// held up behind the others gives up short of the far side.
def scene_herd(rules:JV, races:[JV]):
    new_world(SEED, "choke_test", races, rules, [])
    no_foes()
    let a = group(0, "spear", 30, 12000, 16000)
    for(a) id, n: order_move(index_of(id), 36000 + (n % 4) * 1000, 14500 + (n / 4) * 1000, u_radius[index_of(id)], 0, -1, -1, 0)
    let t0 = tick
    while tick < t0 + HERD_TICKS and any_moving(a): wstep()
    var short = 0
    for(a) id:
        if u_x[index_of(id)] < HERD_PAST: short++
    print "herd: {short} of {a.length} stopped short of the far side after {(tick - t0) / 20} s"
    check(short == 0, "herd: every loose unit gets through the gap ({short} short)")

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

// 10. Two mixed groups meet (#350): the fight breaks into one-on-ones, each going for a foe it's suited to, not a pile on one.
def scene_duel(rules:JV, races:[JV]):
    flat(races, rules)
    let a = mixed(0, 30, 14000, 30000)
    let b = mixed(1, 30, 40000, 30000)
    issue_cmd(0, CMD_ATTACK_MOVE, a, 42000, 31000, 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, b, 14000, 31000, 0, 0)
    let all = a.append(b)
    var contact = -1
    while tick < 3000 and contact < 0:
        wstep()
        if (find(all) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0) >= 0: contact = tick
    check(contact > 0, "duel: they meet")
    var engaged_best = 0
    var pile_worst = 0
    var suited = 0
    var picked = 0
    let t0 = tick
    while tick < t0 + DUEL_TICKS:
        wstep()
        var alive = 0
        var engaged = 0
        let on = map(u_x.length): 0
        for(all) id:
            let i = index_of(id)
            if i >= 0:
                alive++
                let j = if u_foe[i] != 0: index_of(u_foe[i]) else: -1
                if j >= 0:
                    engaged++
                    if t_ranged[u_kind[i]] == 0 and gap(i, j) <= t_reach[u_kind[i]] + 100: on[j]++
                    if (tick - t0) % 20 == 0:
                        picked++
                        let cls = t_cls[u_kind[j]]
                        if (find(t_counters[u_kind[i]]) c: cls[c] != 0) >= 0: suited++
        engaged_best = max(engaged_best, engaged * 100 / max(1, alive))
        for(on) n: pile_worst = max(pile_worst, n)
        if (tick - t0) % 100 == 0: print "duel: {(tick - t0) / 20} s after contact: {engaged} of {alive} have a foe"
    print "duel: at best {engaged_best}% have a foe; at worst {pile_worst} hand to hand on one foe; {suited * 100 / max(1, picked)}% of picks are a foe it counters"
    check(engaged_best >= DUEL_ENGAGED, "duel: the fight spreads to most of them ({engaged_best}% at best have a foe)")
    check(pile_worst <= DUEL_PILE, "duel: no pile on one foe (at worst {pile_worst} hand to hand on one)")
    check(suited * 100 >= picked * DUEL_SUITED, "duel: they go for foes they counter ({suited * 100 / max(1, picked)}% of picks)")

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
            // units in their places in a block found among another block's units in their places: the blocks inside each other
            def placed(i:int) -> bool:
                let b = u_block[i] - 1
                return b >= 0 and u_foe[i] == 0 and dist2(u_x[i], u_y[i], fb_x[b] + u_bx[i], fb_y[b] + u_by[i]) <= TILE * TILE
            var mixed = 0
            for(ids) id:
                let i = index_of(id)
                if i >= 0 and placed(i):
                    var inside = false
                    for(ids) jd:
                        let j = index_of(jd)
                        if not inside and j >= 0 and u_block[j] != u_block[i] and placed(j):
                            let rr = (u_radius[i] + u_radius[j]) / 2
                            if dist2(u_x[i], u_y[i], u_x[j], u_y[j]) < rr * rr: inside = true
                    if inside: mixed++
            mixed_worst = max(mixed_worst, mixed)
    print "queue: after contact, up to {mixed_worst} units inside another block ({foes.length} foes)"
    check(after > 0, "queue: the front meets the foe")
    check(mixed_worst * 50 <= ids.length, "queue: blocks behind don\'t walk into the ones ahead ({mixed_worst})")

// 9. Workers gathering by their Town Center: walking to the patch and back with a load, they face the way they walk.
def scene_gather(rules:JV, races:[JV]):
    new_world(SEED, "reed_meadow", races, rules, [])
    let ids = []::int
    for(u_x.length) i:
        if u_owner[i] == 0 and t_worker[u_kind[i]] != 0: ids.push(u_id[i])
    for([ "wood", "food" ]) kind, n:
        var best = -1
        var best_d2 = 1 << 62
        for(resource_cells) c:
            let r = tr_res[terrain[c]]
            if r > 0 and resource_names[r - 1] == kind:
                let cx, cy = centre(c)
                let d2 = dist2(start_x[0], start_y[0], cx, cy)
                if d2 < best_d2:
                    best_d2 = d2
                    best = c
        assert best >= 0
        issue_cmd(0, CMD_GATHER, filter(ids) id, k: k % 2 == n, best, 0, 0, 0)
    let face = map(ids): 2
    let hist_x = map(ids): map(BACK_WINDOW): -1
    let hist_y = map(ids): map(BACK_WINDOW): -1
    var looks = 0
    var back = 0
    for(GATHER_TICKS):
        let was_x = map(ids) id: u_x[index_of(id)]
        let was_y = map(ids) id: u_y[index_of(id)]
        wstep()
        for(ids) id, a:
            let i = index_of(id)
            let h = tick % BACK_WINDOW
            let ox = hist_x[a][h]
            let oy = hist_y[a][h]
            hist_x[a][h] = u_x[i]
            hist_y[a][h] = u_y[i]
            let walking, nd = unit_walk(i, face[a], was_x[a], was_y[a])
            if walking:
                face[a] = nd
                if ox >= 0 and dist2(ox, oy, u_x[i], u_y[i]) >= BACK_WALKED * BACK_WALKED:
                    let way = atan2(normalize(iso(float(u_x[i] - ox), float(u_y[i] - oy))))
                    looks++
                    let now = atan2(normalize(iso(float(u_x[i] - was_x[a]), float(u_y[i] - was_y[a]))))  // (and this tick's step: not just the turn itself)
                    if abs((way - float(nd) * 45.0 + 540.0) % 360.0 - 180.0) > FACE_BACK and abs((now - float(nd) * 45.0 + 540.0) % 360.0 - 180.0) > FACE_BACK: back++
    print "gather: {ids.length} workers, {back} of {looks} looks at one walking find it facing back the way it came"
    check(looks > 0, "gather: they walk")
    check(back == 0, "gather: workers never walk backwards ({back} of {looks} looks)")

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
if on("gather"): scene_gather(rules, races)
if on("duel"): scene_duel(rules, races)
if on("crossing"): scene_cross(rules, races, false)
if on("head_on"): scene_cross(rules, races, true)
if on("through"): scene_through(rules, races)
if on("past_archers"): scene_past_archers(rules, races)
if on("funnel"): scene_funnel(rules, races)
if on("herd"): scene_herd(rules, races)
if on("meet"): scene_meet(rules, races)
if on("queue"): scene_queue(rules, races)
if on("blocks"): scene_blocks(rules, races)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
