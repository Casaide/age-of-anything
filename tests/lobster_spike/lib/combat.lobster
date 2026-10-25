// ------------------------------------------------------------------ combat (combat.gd, shots.gd)
// Targets, chasing, blows, shots in flight and deaths, unit against unit. Damage uses armour
// classes: max(min_damage, sum over the attack's classes the target belongs to of max(0, attack -
// armour)). Hits within a tick land together. Left out (none in the scenarios, asserted by the
// exporter): buildings (towers, pouring, surrounding a building), bridges, walls, high ground,
// siege weapons (minimum range, splash, bolts, packing, blasts), heroes' auras, bounties,
// sticky hits, healers, animals.

var c_hurt = []::int
var c_hurt_by = []::int
var c_engaged = []::int
var c_inbound = []::int

def is_foe(a:int, b:int) -> bool: return teams[a] != teams[b]

def combat_clear(i:int):
    u_foe[i] = 0
    u_stance[i] = NONE

def damage(atk:[int], arm:[int], cls:[int], min_damage:int) -> int:
    var d = 0
    for(atk) a, k:
        if a > 0 and cls[k] == 1: d += max(0, a - arm[k])
    return max(min_damage, d)

// Starting a fight on its own: remember where it stood, for defensive units to walk back to.
def engage(i:int, foe:int):
    if u_stance[i] != RETURN:
        u_gx[i] = u_x[i]
        u_gy[i] = u_y[i]
    u_foe[i] = foe
    u_stance[i] = AUTO

// How far a unit looks for a fight at most: rules sight, or as far as it can shoot.
def sight_of(i:int) -> int:
    return max(r_sight, t_reach[u_kind[i]] + u_radius[i] + TILE / 2)

// How far a unit with its posture looks for a fight on its own.
def look(i:int) -> int:
    let k = u_kind[i]
    if u_posture[i] == DEFENSIVE: return max(r_defend_sight, t_reach[k] + u_radius[i] + TILE / 2)
    if u_posture[i] == STAND: return t_reach[k] + u_radius[i] + TILE / 2
    return sight_of(i)

// Done with a fight it found itself: a defensive unit walks back to where it stood.
def go_back(i:int):
    u_foe[i] = 0
    if dist2(u_x[i], u_y[i], u_gx[i], u_gy[i]) > TILE * TILE / 4:
        u_stance[i] = RETURN
        order_move(i, u_gx[i], u_gy[i], 0, 0, -1, -1, 0)
    else:
        u_stance[i] = NONE
        u_moving[i] = 0

// The target is gone (or out of reach for good): attack-movers carry on, defensive units walk back, others stop.
def lost_foe(i:int):
    u_foe[i] = 0
    if u_stance[i] == AUTO and u_posture[i] == DEFENSIVE:
        go_back(i)
    elif u_stance[i] == ATTACK_MOVE:
        resume_attack_move(i)
    else:
        u_stance[i] = NONE
        u_moving[i] = 0

// High ground: 1 if unit i stands a level above unit j, -1 if below, 0 on the level or a flat map
// (a ramp counts as its foot). (Combat._height_step; nobody stands on walls here.)
def height_step(i:int, j:int) -> int:
    if not has_heights: return 0
    let d = level[cell_of(u_x[i], u_y[i])] - level[cell_of(u_x[j], u_y[j])]
    return if d > 0: 1 elif d < 0: -1 else: 0

// A shot up a hill: part of it falls short (rules.high_ground.uphill_damage_pct; at least 1).
def uphill(d:int) -> int:
    return max(1, d * r_uphill_pct / 100)

// The edge-to-edge gap between two units.
def gap(i:int, j:int) -> int:
    return isqrt(dist2(u_x[i], u_y[i], u_x[j], u_y[j])) - u_radius[i] - u_radius[j]

// Close in: re-aim at a moving target on re-plan beats (straight at it when the way is clear).
def chase(i:int, j:int):
    if u_moving[i] == 0 or (tick + u_id[i]) % REPLAN_EVERY == 0:
        if clear_line(u_x[i], u_y[i], u_x[j], u_y[j], lane(i)):
            order_direct(i, u_x[j], u_y[j])
        else:
            order_move(i, u_x[j], u_y[j], 0, 0, -1, -1, 0)

// The best enemy unit within `sight` (centre to centre) its side can see: nearest, each of its
// attackers counting `spread` further, a foe it counters counter_pull nearer, lowest id on ties;
// with `use_inbound`, skipping those the shots in the air will kill. An id or 0.
def nearest_foe(i:int, sight:int, spread:int, use_inbound:bool, near:int) -> int:
    let me = u_owner[i]
    var best = 0
    var best_d = 1 << 40
    let r = sight / TILE + 1
    let cx = u_x[i] / TILE
    let cy = u_y[i] / TILE
    let counters = t_counters[u_kind[i]]
    let xi = u_x[i]
    let yi = u_y[i]
    var yy = max(cy - r, 0)
    let y1 = min(cy + r + 1, H)
    while yy < y1:
        var xx = max(cx - r, 0)
        let x1 = min(cx + r + 1, W)
        while xx < x1:
            let cell = yy * W + xx
            var k = sp_start[cell]
            let e = sp_end[cell]
            while k < e:
                let j = sp_items[k]
                k++
                if not is_foe(u_owner[j], me): continue
                if use_inbound and c_inbound[j] >= u_hp[j]: continue
                let d2 = dist2(xi, yi, u_x[j], u_y[j])
                if d2 > sight * sight or d2 < near * near or not fog_visible(me, u_x[j], u_y[j]): continue
                var d = isqrt(d2) + c_engaged[j] * spread
                if r_counter_pull > 0:
                    let cls = t_cls[u_kind[j]]
                    for(counters) c:
                        if cls[c] != 0:
                            d -= r_counter_pull
                            break
                if d < best_d or (d == best_d and u_id[j] < best):
                    best_d = d
                    best = u_id[j]
            xx++
        yy++
    return best

// Ticks a shot takes from one spot to another (at least one).
def flight(x0:int, y0:int, x1:int, y1:int, speed:int) -> int:
    return max(1, (isqrt(dist2(x0, y0, x1, y1)) + speed - 1) / speed)

// Loose a shot from (sx, sy) at unit j: it flies at the spot the unit stands on (led by
// shot_lead_pct of its pace) and lands a flight later.
def loose(by:int, owner:int, sx:int, sy:int, j:int, d:int, src:int, up:int, speed:int):
    var ax = u_x[j]
    var ay = u_y[j]
    if u_moving[j] == 1 and r_shot_lead_pct > 0:
        let vx = u_wx[j] - ax
        let vy = u_wy[j] - ay
        let len = isqrt(vx * vx + vy * vy)
        if len > 0:
            let pace = if u_pace[j] > 0: u_pace[j] else: u_speed[j]
            let ahead = min(len, pace * flight(sx, sy, ax, ay, speed) * r_shot_lead_pct / 100)
            ax += vx * ahead / len
            ay += vy * ahead / len
    let f = flight(sx, sy, ax, ay, speed)
    for([tick + f, u_id[j], by, owner, d, src, up, ax, ay, sx, sy]) v: shots.push(v)

// The shots landing at `t`, taken out of the air (in loosing order).
def take_shots(t:int) -> [int]:
    let out = []::int
    let n = shots.length / SHOT_STRIDE
    var keep = 0
    for(n) k:
        let o = k * SHOT_STRIDE
        if shots[o + SHOT_LAND] <= t:
            for(SHOT_STRIDE) f: out.push(shots[o + f])
        else:
            if keep != k:
                for(SHOT_STRIDE) f: shots[keep * SHOT_STRIDE + f] = shots[o + f]
            keep++
    if keep != n: shots.remove_range(keep * SHOT_STRIDE, (n - keep) * SHOT_STRIDE)
    return out

// The foe of `owner` whose body covers (x, y), nearest its centre (lowest slot on ties); -1 if none.
def stray(owner:int, x:int, y:int, slack:int) -> int:
    let cx = x / TILE
    let cy = y / TILE
    var best = -1
    var best_d = 1 << 40
    var yy = max(cy - 1, 0)
    while yy < min(cy + 2, H):
        var xx = max(cx - 1, 0)
        while xx < min(cx + 2, W):
            let cell = yy * W + xx
            var q = sp_start[cell]
            while q < sp_end[cell]:
                let k = sp_items[q]
                q++
                if not is_foe(u_owner[k], owner): continue
                let r = u_radius[k] + slack
                let d = dist2(x, y, u_x[k], u_y[k])
                if d <= r * r and (d < best_d or (d == best_d and k < best)):
                    best_d = d
                    best = k
            xx++
        yy++
    return best

// The shots landing this tick: on the target if its body still covers the spot, else (with
// shot_strays) on another foe whose body does, else in the ground.
def land():
    if not shots.length: return
    let recs = take_shots(tick)
    let slack = r_shot_slack
    var o = 0
    while o < recs.length:
        let to = recs[o + SHOT_TO]
        let by = recs[o + SHOT_BY]
        let ax = recs[o + SHOT_X]
        let ay = recs[o + SHOT_Y]
        var d = recs[o + SHOT_DAMAGE]
        var j = index_of(to)
        if j >= 0:
            let r = u_radius[j] + slack
            if dist2(ax, ay, u_x[j], u_y[j]) > r * r: j = -1
        if j < 0 and r_shot_strays == 1:
            j = stray(recs[o + SHOT_OWNER], ax, ay, slack)
            if j >= 0:
                let kj = u_kind[j]
                d = damage(t_atk[recs[o + SHOT_SRC]], t_arm[kj], t_cls[kj], max(r_min_damage, t_min_damage[kj]))
                if recs[o + SHOT_UP] < 0: d = uphill(d)
        if j >= 0:
            c_hurt[j] += d
            c_hurt_by[j] = by
        o += SHOT_STRIDE

// Damage on its way to each unit (by slot).
def shots_inbound():
    for(u_x.length) i: c_inbound[i] = 0
    var o = 0
    while o < shots.length:
        let j = index_of(shots[o + SHOT_TO])
        if j >= 0: c_inbound[j] += shots[o + SHOT_DAMAGE]
        o += SHOT_STRIDE

// Land this tick's hits together, then remove the dead (by descending slot). Units hit while idle
// (or walking back) turn on the attacker, unless passive.
def apply_hits(n:int):
    for(n) j:
        if c_hurt[j] != 0:
            u_hp[j] -= c_hurt[j]
            let k = u_kind[j]
            if u_foe[j] == 0 and (u_stance[j] == NONE or u_stance[j] == RETURN) and not t_worker[k] and not t_harmless[k] and not t_healer[k] and u_posture[j] != PASSIVE:
                engage(j, c_hurt_by[j])
    var j = n - 1
    while j >= 0:
        if u_hp[j] <= 0:
            lost[u_owner[j]]++
            remove_unit(j)
        j--

// One tick of fighting (Combat.tick). w.spatial must be built from the current positions.
def combat_tick():
    let n = u_x.length
    for(n) i:
        c_hurt[i] = 0
        c_hurt_by[i] = 0
        c_engaged[i] = 0
    for(n) i:
        if u_foe[i] != 0:
            let j = index_of(u_foe[i])
            if j >= 0: c_engaged[j]++
    for(n) i:
        if u_cooldown[i] > 0: u_cooldown[i]--
    land()
    shots_inbound()
    for(n) i:
        let k = u_kind[i]
        if u_stance[i] == RETURN and u_moving[i] == 0: u_stance[i] = NONE
        if t_healer[k] or t_harmless[k]: continue
        let stance = u_stance[i]
        let posture = u_posture[i]
        if (tick + u_id[i]) % r_acquire_every == 0:
            let idle = stance == NONE and u_moving[i] == 0 and not t_worker[k] and posture != PASSIVE
            let free = stance == AUTO or stance == ATTACK_MOVE
            var crowded = false
            if u_foe[i] != 0 and free:
                let cur = index_of(u_foe[i])
                crowded = cur >= 0 and c_engaged[cur] > CROWDED
            if (u_foe[i] == 0 and (idle or stance == ATTACK_MOVE)) or crowded:
                let am = stance == ATTACK_MOVE
                var f = nearest_foe(i, if am: sight_of(i) else: look(i), if posture == STAND and not am: 0 else: SPREAD, false, 0)
                if crowded and t_ranged[k] and f != 0 and gap(i, index_of(u_foe[i])) <= t_reach[k]:
                    let fj = index_of(f)
                    if fj < 0 or gap(i, fj) > t_reach[k]: f = 0
                if f != 0 and f != u_foe[i]:
                    let old = if u_foe[i] != 0: index_of(u_foe[i]) else: -1
                    if old >= 0: c_engaged[old]--
                    u_foe[i] = f
                    let nj = index_of(f)
                    if nj >= 0: c_engaged[nj]++
                    if idle: engage(i, f)
        if u_foe[i] == 0: continue
        var j = index_of(u_foe[i])
        if j < 0:
            // An attack-mover whose foe fell takes the next one at once.
            let next = if u_stance[i] == ATTACK_MOVE: nearest_foe(i, sight_of(i), SPREAD, false, 0) else: 0
            if next != 0:
                u_foe[i] = next
                let nj = index_of(next)
                if nj >= 0: c_engaged[nj]++
            else:
                lost_foe(i)
            continue
        let g = gap(i, j)
        var up = if t_ranged[k]: height_step(i, j) else: 0   // shooters reach further down, less far up
        if g <= t_reach[k] + up * r_high_reach + (if t_ranged[k] and u_moving[i] == 0: HOLD else: 0):
            u_moving[i] = 0
            if u_cooldown[i] == 0 and t_ranged[k] and c_inbound[j] >= u_hp[j] and u_stance[i] != ORDERED:
                // Enough already flying at it to kill it: another foe in reach, or hold this shot.
                let f = nearest_foe(i, t_reach[k] + u_radius[i] + TILE / 2, SPREAD, true, 0)
                let fj = if f != 0: index_of(f) else: -1
                if fj < 0 or gap(i, fj) > t_reach[k] + height_step(i, fj) * r_high_reach: continue
                c_engaged[j]--
                c_engaged[fj]++
                u_foe[i] = f
                j = fj
                up = height_step(i, j)
            if u_cooldown[i] == 0:
                u_cooldown[i] = t_reload[k]
                let kj = u_kind[j]
                var d = damage(t_atk[k], t_arm[kj], t_cls[kj], max(r_min_damage, t_min_damage[kj]))
                if up < 0: d = uphill(d)
                if t_ranged[k]:
                    c_inbound[j] += d
                    loose(u_id[i], u_owner[i], u_x[i], u_y[i], j, d, k, up, t_shot_speed[k])
                else:
                    c_hurt[j] += d
                    c_hurt_by[j] = u_id[i]
        elif u_stance[i] == AUTO and posture == STAND:
            u_foe[i] = 0
            u_stance[i] = NONE
            u_moving[i] = 0
        elif u_stance[i] == AUTO and posture == DEFENSIVE and dist2(u_x[i], u_y[i], u_gx[i], u_gy[i]) > r_leash * r_leash:
            go_back(i)
        elif u_stance[i] == AUTO and (g > r_sight + 2 * TILE or not fog_visible(u_owner[i], u_x[j], u_y[j])):
            lost_foe(i)
        else:
            chase(i, j)
    apply_hits(n)
