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

// The drawn facing against the real movement through a battle (#252): a unit that walks somewhere must look that way, on the
// march, at its foe, or going back to its place. Movement over a second, so a shove in a crowd doesn't count as walking; nor
// does being carried back against the way it's making for (a push, #174: printed, not checked).
let FACE_WINDOW = 20   // ticks
let FACE_WALKED = 400  // milli-tiles in that window: it's really walking
let FACE_OFF = 45.0    // degrees on screen, more than this is sideways
let FACE_OFF_MAX = 10  // percent of a type's walking

def scene_facing(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let one = army(0, n, start_x[0] + 4000, start_y[0] + 4000)
    let two = army(1, n, start_x[1] + 4000, start_y[1] + 4000)
    issue_cmd(0, CMD_ATTACK_MOVE, one, start_x[1], start_y[1], 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, two, start_x[0], start_y[0], 0, 0)
    while tick < 200 and (find(fb_state) s: s != 0) < 0: wstep()
    blocks_snap()
    let everyone = one.append(two)
    let hist_x = map(everyone): map(FACE_WINDOW): -1
    let hist_y = map(everyone): map(FACE_WINDOW): -1
    let face = map(everyone): 2
    let walked = map(2): map(t_slot.length): 0  // on the march, then from first contact (the march is most of a battle: it would hide the fight)
    let off_by = map(2): map(t_slot.length): 0
    var met = 0
    var shoved = 0
    let name = "facing {n}"
    while tick < 3000:
        let was_x = map(everyone) id: if index_of(id) >= 0: u_x[index_of(id)] else: 0
        let was_y = map(everyone) id: if index_of(id) >= 0: u_y[index_of(id)] else: 0
        wstep()
        if met == 0 and (find(everyone) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0) >= 0: met = 1
        for(everyone) id, a:
            let i = index_of(id)
            if i >= 0:
                let h = tick % FACE_WINDOW
                let ox = hist_x[a][h]
                let oy = hist_y[a][h]
                hist_x[a][h] = u_x[i]
                hist_y[a][h] = u_y[i]
                let walking, nd = unit_walk(i, face[a], was_x[a], was_y[a])
                if walking:
                    face[a] = nd
                    if ox >= 0 and dist2(ox, oy, u_x[i], u_y[i]) >= FACE_WALKED * FACE_WALKED:
                        let mx = u_x[i] - ox
                        let my = u_y[i] - oy
                        if mx * (u_wx[i] - u_x[i]) + my * (u_wy[i] - u_y[i]) < 0 and not with_block(i): shoved++
                        else:
                            let way = atan2(normalize(iso(float(mx), float(my))))
                            walked[met][u_kind[i]]++
                            if abs((way - float(nd) * 45.0 + 540.0) % 360.0 - 180.0) > FACE_OFF: off_by[met][u_kind[i]]++
    print "{name}: {shoved} samples carried back against their way"
    for(2) phase:
        for(t_slot.length) k:
            let n_walked = walked[phase][k]
            let share = off_by[phase][k] * 100 / max(1, n_walked)
            let what = "{name}: p{t_player[k]} {t_slot[k]} {if phase == 0: "on the march" else: "in the fight"}"
            if n_walked > 0:
                print "{what}: {share}% of {n_walked} walking off by over {int(FACE_OFF)} degrees"
                check(share <= FACE_OFF_MAX, "{what} faces the way it walks ({share}% off)")

// Engines and war beasts with their crews, on the ground in their slots (#253): no two footprints overlap, measured from the
// voxels drawn. Rectangles in the block's frame, as they all march its way.
let MT_A_VOXEL = 1.1 / 2.0 / (sqrt(2.0) * 0.048)  // milli-tiles of ground a voxel (VX_DRAW_K canvas px a voxel, a tile's width on screen)
let FOOT_SLACK = 250                              // milli-tiles: form_radius may be this much over what it needs (its culture's styles differ)
let WALKED_THROUGH_MAX = 2                        // percent of looks at an engine on the march finding it in another block
let SHOWN_PCT = 60                                // how much of an engine's picture stays shown behind the one in front, marching up the screen
let SCREEN_DEPTH = sqrt(2.0) * 0.024              // canvas px up the screen a milli-tile (iso)

class Foot:
    lo_ac:int
    hi_ac:int
    lo_al:int
    hi_al:int
    px_tall:int = 0  // canvas px its picture stands from the near edge of its ground to its top

def vx_id_of(body_id:string) -> string:
    if starts_with(body_id, "body."): return body_id.substring(5, body_id.length - 5)
    if vx_bodies.get(body_id): return body_id
    return body_id.substring(0, find_string_reverse(body_id, "."))

def foot_of(k:int) -> Foot:
    let r = gobj(su_units[k], "look")
    if not has(r, "crew"): return Foot { -u_r_of(k), u_r_of(k), -u_r_of(k), u_r_of(k) }
    let cr = at(r, "crew")
    let plain = float3 { 0.5, 0.3, 0.2 }
    var mount = ""
    if has(cr, "mount"):
        let c = creature(rstr(at(cr, "mount"), "creature"))
        mount = vx_id_of(gstr(c, "mount_body", gstr(c, "body", "")))
    let crew = vx_unit_def { "crew", vx_id_of(rstr(cr, "body")), plain, plain, float3_0, [], mount, has(cr, "mount") and gbool(at(cr, "mount"), "fused", false), plain, plain, float3_0, nil }
    let id = vx_id_of(rstr(r, "body"))
    let b = vx_body_of(id)
    let u = vx_unit_def { id, id, b.style_cols[0], b.style_cols[1], b.style_cols[2], [], "", false, float3_0, float3_0, float3_0, crew }
    let sh = vx_fill(vx_unit_prims(u, 0.0), b.size)
    var f = Foot { 1 << 30, -(1 << 30), 1 << 30, -(1 << 30) }
    for(sh.pos) v:
        f.lo_ac = min(f.lo_ac, v.x)
        f.hi_ac = max(f.hi_ac, v.x)
        f.lo_al = min(f.lo_al, v.y)
        f.hi_al = max(f.hi_al, v.y)
    var top = 0.0
    for(sh.pos) v: top = max(top, (float(v.z) * cos(30.0) + float(v.y - f.lo_al) * sin(30.0)) * 0.55)
    return Foot { int(float(f.lo_ac) * MT_A_VOXEL), int(float(f.hi_ac) * MT_A_VOXEL), int(float(f.lo_al) * MT_A_VOXEL), int(float(f.hi_al) * MT_A_VOXEL), px_tall: int(top) }

def u_r_of(k:int) -> int: return t_radius[k]

// How far apart its slots must be: clear on the ground, and enough of its picture shown (the worst case, marching up the screen).
def foot_need(f:Foot) -> int: return max(max(f.hi_ac - f.lo_ac, f.hi_al - f.lo_al), int(float(f.px_tall * SHOWN_PCT / 100) / SCREEN_DEPTH))

def scene_footprints(rules:JV, races:[JV], n:int):
    new_world(SEED, MAP, races, rules, [])
    let one = army(0, n, start_x[0] + 4000, start_y[0] + 4000)
    let two = army(1, n, start_x[1] + 4000, start_y[1] + 4000)
    issue_cmd(0, CMD_ATTACK_MOVE, one, start_x[1], start_y[1], 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, two, start_x[0], start_y[0], 0, 0)
    while tick < 200 and (find(fb_state) s: s != 0) < 0: wstep()
    let name = "footprints {n}"
    let feet = map(t_slot.length) k: foot_of(k)
    for(t_slot.length) k:
        if has(gobj(su_units[k], "look"), "crew"):
            let f = feet[k]
            print "{name}: p{t_player[k]} {t_slot[k]} {rstr(gobj(su_units[k], "look"), "body")}: {f.hi_ac - f.lo_ac} across, {f.hi_al - f.lo_al} along, {f.px_tall} px tall, form_radius {t_form_r[k]}"
    let overlaps = map(t_slot.length): 0
    let engines = map(t_slot.length): 0
    for([ one, two ]) side:
        let idx = filter(map(side) id: index_of(id)) i: i >= 0 and u_block[i] > 0
        for(idx) i:
            if has(gobj(su_units[u_kind[i]], "look"), "crew"):
                engines[u_kind[i]]++
                let bi = u_block[i] - 1
                let px = fb_x[bi] + u_bx[i]
                let py = fb_y[bi] + u_by[i]
                let ux = fb_dx[bi]
                let uy = fb_dy[bi]
                let fi = feet[u_kind[i]]
                var hit = false
                for(idx) j:
                    if j != i:
                        let bj = u_block[j] - 1
                        let gx = fb_x[bj] + u_bx[j] - px
                        let gy = fb_y[bj] + u_by[j] - py
                        let along = (gx * ux + gy * uy) / ONE
                        let across = (gx * uy - gy * ux) / ONE
                        let fj = feet[u_kind[j]]
                        if across + fj.hi_ac > fi.lo_ac and across + fj.lo_ac < fi.hi_ac and along + fj.hi_al > fi.lo_al and along + fj.lo_al < fi.hi_al: hit = true
                if hit: overlaps[u_kind[i]]++
    for(t_slot.length) k:
        if engines[k] > 0:
            print "{name}: p{t_player[k]} {t_slot[k]}: {overlaps[k]} of {engines[k]} overlap a neighbour in their slots"
            check(overlaps[k] == 0, "{name}: p{t_player[k]} {t_slot[k]} clear of its neighbours ({overlaps[k]} of {engines[k]} overlap)")
            let f = feet[k]
            let need = (foot_need(f) - FORM_GAP) / 2
            let space = form_space(filter(u_x.length) i: u_kind[i] == k)
            print "{name}: p{t_player[k]} {t_slot[k]}: slots {space} apart, needs {foot_need(f)}; the one in front hides {max(0, 100 - int(float(space) * SCREEN_DEPTH) * 100 / f.px_tall)}% of it"
            check(space >= foot_need(f), "{name}: p{t_player[k]} {t_slot[k]} slots leave its picture shown ({space}, wants {foot_need(f)})")
            check(t_form_r[k] <= need + FOOT_SLACK, "{name}: p{t_player[k]} {t_slot[k]} form_radius is not stale ({t_form_r[k]}, needs {need})")
    // ...and on the march: a slower block in front is walked through by the faster ones behind it (real places, not slots)
    blocks_snap()
    let met = fn() -> bool: (find(one.append(two)) id: index_of(id) >= 0 and u_foe[index_of(id)] != 0) >= 0
    var samples = 0
    var through = 0
    while tick < 3000 and not met():
        for(20): wstep()
        for([ one, two ]) side:
            let idx = filter(map(side) id: index_of(id)) i: i >= 0 and u_block[i] > 0
            for(idx) i:
                if has(gobj(su_units[u_kind[i]], "look"), "crew"):
                    samples++
                    let b = u_block[i] - 1
                    let fi = feet[u_kind[i]]
                    var hit = false
                    for(idx) j:
                        if u_block[j] != u_block[i]:
                            let gx = u_x[j] - u_x[i]
                            let gy = u_y[j] - u_y[i]
                            let along = (gx * fb_dx[b] + gy * fb_dy[b]) / ONE
                            let across = (gx * fb_dy[b] - gy * fb_dx[b]) / ONE
                            let fj = feet[u_kind[j]]
                            if across + fj.hi_ac > fi.lo_ac and across + fj.lo_ac < fi.hi_ac and along + fj.hi_al > fi.lo_al and along + fj.lo_al < fi.hi_al: hit = true
                    if hit: through++
    print "{name}: on the march, {through} of {samples} looks at an engine find it among another block"
    check(through * 100 <= samples * WALKED_THROUGH_MAX, "{name}: no block walks through an engine on the march ({through} of {samples})")

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
vx_load([ "../data/voxel" ])
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
    scene_facing(rules, races, n)
    scene_footprints(rules, races, n)
// the other cultures' engines and war beasts
for([ [ "sewer rats", "giant spiders" ], [ "forest beetles", "romans" ] ]) prompts: scene_footprints(rules, map(prompts) p: generate(p, rules, 0), 125)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
