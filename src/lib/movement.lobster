// ------------------------------------------------------------------ movement (world.gd)

// Unit i's next waypoint from (x, y) (World._plan). Point moves aim at the target if the way is
// clear; reach moves aim at a free spot round their rect once beside it; otherwise the furthest
// clear cell a few steps down the flow field. (-1, -1): unreachable. (-2, -2): outside a near
// field's cutoff. (-3, -3): every spot round its rect has a worker at work in it.
// `stuck` is its stuck count as GDScript reads it (units.stuck: live during the tick's moves).
def plan(i:int, x:int, y:int, stuck:int) -> int, int:
    let tx = u_tx[i]
    let ty = u_ty[i]
    if u_fkey[i] < 0: return tx, ty
    let f = field_for(u_fkey[i])
    if not f: return tx, ty
    let cell = cell_of(x, y)
    let cost = f.dist[cell]
    if cost >= INF:
        let kind = (u_fkey[i] / LANES) % 4
        if kind == FIELD_CELL_NEAR or kind == FIELD_BUILDING_NEAR: return -2, -2
        return -1, -1
    if u_reach[i] == 1:
        if cost <= 2 * DIAGONAL:  // within two cells: make for a free spot before meeting the crowd
            if u_task[i] == T_RETURN and u_gspot[i] >= 0: return drop_spot(i, x, y)
            return spot(i, x, y)
    elif cost == 0 or (cost <= DIRECT_COST and stuck < STUCK_LIMIT / 2 and clear_path(x, y, tx, ty, u_radius[i], lane(i))):
        return tx, ty
    elif u_reach[i] == 2 and cost <= 4 * STRAIGHT:
        let cx, cy = round_corner(i, x, y, tx, ty)  // its place is round the far side of the building
        if cx >= 0: return cx, cy
    var best = ahead(f, cell, x, y, if stuck >= STUCK_LIMIT / 2: 1 else: LOOKAHEAD, u_radius[i], lane(i))
    if best < 0:
        if u_reach[i] == 0: return tx, ty
        best = -2 - best
    return centre(best)

// The nearest free spot round unit i's rect (a body's width from it, clear of every stopped unit
// there); the same spot while it stays free; one only an idle body stands in after free ones.
// (-3, -3) when every spot has a worker at work in it (World._spot).
def spot(i:int, x:int, y:int) -> int, int:
    let r = u_radius[i]
    let ln = lane(i)
    let x0 = u_rx0[i]
    let y0 = u_ry0[i]
    let x1 = u_rx1[i] + 1
    let y1 = u_ry1[i] + 1
    let o = r + SPOT_GAP
    let near = []::int
    var cy = max((y0 - o) / TILE - 1, 0)
    while cy < min((y1 + o) / TILE + 2, H):
        var cx = max((x0 - o) / TILE - 1, 0)
        while cx < min((x1 + o) / TILE + 2, W):
            let c = cy * W + cx
            var k = sp_start[c]
            while k < sp_end[c]:
                let j = sp_items[k]
                k++
                if j != i and j < u_x.length and u_moving[j] == 0: near.push(j)
            cx++
        cy++
    let space = 2 * r + SPOT_GAP / 2
    let wd = x1 - x0 + 2 * o
    let ht = y1 - y0 + 2 * o
    let perim = 2 * (wd + ht)
    let count = max(perim / space, 4)
    var bx = -1
    var by = -1
    var best_d = 1 << 62
    let rr0 = r + REACH - SPOT_GAP / 2
    for(count) k:
        let along = k * perim / count
        var px = 0
        var py = 0
        if along < wd:
            px = x0 - o + along
            py = y0 - o
        elif along < wd + ht:
            px = x1 + o
            py = y0 - o + along - wd
        elif along < 2 * wd + ht:
            px = x1 + o - (along - wd - ht)
            py = y1 + o
        else:
            px = x0 - o
            py = y1 + o - (along - 2 * wd - ht)
        let ex = max(max(x0 - px, 0), px - x1)
        let ey = max(max(y0 - py, 0), py - y1)
        if ex * ex + ey * ey > rr0 * rr0 or not walkable(px, py, ln): continue
        px, py = off_walls(px, py, r, ln)
        var lv = 0
        for(near) j:
            let rr = r + u_radius[j] - SPOT_GAP / 2
            if dist2(px, py, u_x[j], u_y[j]) < rr * rr:
                if u_task[j] == GATHER or u_task[j] == BUILD:
                    lv = 2
                    break
                lv = 1
        if lv == 2: continue
        var d = dist2(x, y, px, py) + lv * (1 << 40)
        if px == u_wx[i] and py == u_wy[i]: d -= 1 << 39
        if d < best_d:
            best_d = d
            bx = px
            by = py
    if bx < 0: return -3, -3
    if clear_path(x, y, bx, by, r, ln): return bx, by
    return rect_near(i, x, y)

// Where a worker carrying home makes for round its drop-off: the point of the ring a body's width
// out nearest what it gathers, moved round the ring by a lane of its own (World._drop_spot).
def drop_spot(i:int, x:int, y:int) -> int, int:
    let r = u_radius[i]
    let o = r + SPOT_GAP
    let x0 = u_rx0[i] - o
    let y0 = u_ry0[i] - o
    let x1 = u_rx1[i] + o
    let y1 = u_ry1[i] + o
    var ax = x
    var ay = y
    if u_home[i] >= 0:
        ax = (u_home[i] % W) * TILE + TILE / 2
        ay = (u_home[i] / W) * TILE + TILE / 2
    var px = clamp(ax, x0, x1)
    var py = clamp(ay, y0, y1)
    if px > x0 and px < x1 and py > y0 and py < y1:
        let d = min(min(px - x0, x1 - px), min(py - y0, y1 - py))
        if d == px - x0: px = x0
        elif d == x1 - px: px = x1
        elif d == py - y0: py = y0
        else: py = y1
    let wd = x1 - x0
    let ht = y1 - y0
    let perim = 2 * (wd + ht)
    var along = 0
    if py == y0: along = px - x0
    elif px == x1: along = wd + py - y0
    elif py == y1: along = wd + ht + x1 - px
    else: along = 2 * wd + ht + y1 - py
    along = along + (u_id[i] * 7 % 5 - 2) * r / 2
    along = ((along % perim) + perim) % perim
    var qx = 0
    var qy = 0
    if along < wd:
        qx = x0 + along
        qy = y0
    elif along < wd + ht:
        qx = x1
        qy = y0 + along - wd
    elif along < 2 * wd + ht:
        qx = x1 - (along - wd - ht)
        qy = y1
    else:
        qx = x0
        qy = y1 - (along - 2 * wd - ht)
    let c = (r + REACH - 50) * 707 / 1000
    if (qx < u_rx0[i] or qx > u_rx1[i]) and (qy < u_ry0[i] or qy > u_ry1[i]):
        qx = clamp(qx, u_rx0[i] - c, u_rx1[i] + c)
        qy = clamp(qy, u_ry0[i] - c, u_ry1[i] + c)
    let ln = lane(i)
    if not walkable(qx, qy, ln) or not clear_path(x, y, qx, qy, r, ln): return spot(i, x, y)
    return qx, qy

// A corner of unit i's rect, stood off by a body and a row, to walk round it towards (tx, ty): of
// the corners it can walk straight to (not the one it's at), the shortest way on. (-1, -1) if none.
def round_corner(i:int, x:int, y:int, tx:int, ty:int) -> int, int:
    let e = 3 * u_radius[i] + FORM_GAP
    let ln = lane(i)
    var bx = -1
    var by = -1
    var best_d = 1 << 62
    let cxs = [ u_rx0[i] - e, u_rx1[i] + e, u_rx1[i] + e, u_rx0[i] - e ]
    let cys = [ u_ry0[i] - e, u_ry0[i] - e, u_ry1[i] + e, u_ry1[i] + e ]
    for(4) k:
        let cx = cxs[k]
        let cy = cys[k]
        let d0 = dist2(x, y, cx, cy)
        if d0 >= 200 * 200 and walkable(cx, cy, ln) and clear_path(x, y, cx, cy, u_radius[i], ln):
            let d = isqrt(d0) + isqrt(dist2(cx, cy, tx, ty))
            if d < best_d:
                best_d = d
                bx = cx
                by = cy
    return bx, by

// The nearest point of unit i's rect.
def rect_near(i:int, x:int, y:int) -> int, int:
    return clamp(x, u_rx0[i], u_rx1[i]), clamp(y, u_ry0[i], u_ry1[i])

// How far unit i still has to go, and how much nearer it should be by the next check (World._progress).
def progress(i:int, x:int, y:int) -> int, int:
    if u_fkey[i] >= 0:
        let n = field_index(u_fkey[i])
        if n >= 0:
            let d = field_vals[n].dist[cell_of(x, y)]
            if d < INF and d > DIAGONAL and not (d <= DIRECT_COST and u_arrive[i] == SLOT_ARRIVE and u_reach[i] != 1):
                return d, STRAIGHT_PER_CHECK
    return isqrt(dist2(x, y, u_tx[i], u_ty[i])), u_speed[i] * PROGRESS_EVERY / 4

def queued(i:int, x:int, y:int) -> bool:
    let ux = o_wx[i] - x
    let uy = o_wy[i] - y
    let near = u_arrive[i] * ARRIVE_SETTLE + RETURN_SLACK
    if (ux == 0 and uy == 0) or dist2(x, y, u_tx[i], u_ty[i]) <= near * near: return false
    let cx = x / TILE
    let cy = y / TILE
    let oi = u_owner[i]
    let ri = u_radius[i]
    var yy = max(cy - 1, 0)
    let y1 = min(cy + 2, H)
    while yy < y1:
        var xx = max(cx - 1, 0)
        let x1 = min(cx + 2, W)
        while xx < x1:
            let c = yy * W + xx
            var k = sp_start[c]
            let e = sp_end[c]
            while k < e:
                let j = sp_items[k]
                k++
                if j == i or o_moving[j] == 0 or u_owner[j] != oi or (u_tx[j] == u_tx[i] and u_ty[j] == u_ty[i]): continue
                let rx = o_x[j] - x
                let ry = o_y[j] - y
                let reach = ri + u_radius[j] + QUEUE_GAP
                if rx * ux + ry * uy <= 0 or rx * rx + ry * ry > reach * reach: continue
                if o_stuck[j] == 0 and (o_wx[j] - o_x[j]) * ux + (o_wy[j] - o_y[j]) * uy > 0: return true
            xx++
        yy++
    return false

def passed(i:int, x:int, y:int) -> bool:
    if u_arrive[i] != SLOT_ARRIVE or dist2(x, y, u_tx[i], u_ty[i]) > RETURN_YIELD * RETURN_YIELD: return false
    let cx = x / TILE
    let cy = y / TILE
    let oi = u_owner[i]
    let gi = u_group[i]
    let ri = u_radius[i]
    var yy = max(cy - 1, 0)
    let y1 = min(cy + 2, H)
    while yy < y1:
        var xx = max(cx - 1, 0)
        let x1 = min(cx + 2, W)
        while xx < x1:
            let c = yy * W + xx
            var k = sp_start[c]
            let e = sp_end[c]
            while k < e:
                let j = sp_items[k]
                k++
                if j == i or o_moving[j] == 0 or u_owner[j] != oi or u_group[j] == gi or u_group[j] == 0: continue
                let reach = ri + u_radius[j] + QUEUE_GAP
                if dist2(o_x[j], o_y[j], x, y) <= reach * reach: return true
            xx++
        yy++
    return false

// Local avoidance (World._sidestep): (0, 0) if nothing is in the way.
def sidestep(i:int, x:int, y:int, ux:int, uy:int, s:int) -> int, int:
    let cx = x / TILE
    let cy = y / TILE
    var best = -1
    var best_ahead = 1 << 30
    var best_side = 0
    let ri = u_radius[i]
    let gi = u_group[i]
    let oi = u_owner[i]
    let x0 = if ux > ONE / 2: cx else: cx - 1
    let x1 = if ux < -ONE / 2: cx else: cx + 1
    let y0 = if uy > ONE / 2: cy else: cy - 1
    let y1 = if uy < -ONE / 2: cy else: cy + 1
    var yy = max(y0, 0)
    let ye = min(y1 + 1, H)
    while yy < ye:
        var xx = max(x0, 0)
        let xe = min(x1 + 1, W)
        while xx < xe:
            let c = yy * W + xx
            var k = sp_start[c]
            let e = sp_end[c]
            while k < e:
                let j = sp_items[k]
                k++
                if j == i or (gi > 0 and (u_group[j] == gi or u_owner[j] != oi)): continue
                var head_on = false
                if o_moving[j] == 1:
                    if u_owner[j] != oi: continue
                    if (o_wx[j] - o_x[j]) * ux + (o_wy[j] - o_y[j]) * uy >= 0: continue
                    head_on = true
                let rx = o_x[j] - x
                let ry = o_y[j] - y
                let rr = ri + u_radius[j]
                let ah = (rx * ux + ry * uy) / ONE
                if ah <= 0 or ah > rr + (if head_on: 4 else: 2) * s or ah >= best_ahead: continue
                var side = (rx * uy - ry * ux) / ONE
                if side >= rr or side <= -rr: continue
                if head_on:
                    side = 1
                elif side == 0:
                    side = if (u_id[i] + u_id[j]) % 2 == 0: 1 else: -1
                best = j
                best_ahead = ah
                best_side = side
            xx++
        yy++
    if best < 0: return 0, 0
    let sgn = if best_side > 0: 1 else: -1
    let vx = ux * 2 - sgn * uy
    let vy = uy * 2 + sgn * ux
    if not walkable(x + vx * s / (2 * ONE), y + vy * s / (2 * ONE), lane(i)): return 0, 0
    return vx, vy

// Where unit i goes this tick when it wants to go from (x, y) to (nx, ny): its velocity turns towards that by at most a
// share of its speed s a tick, so a push one way then the other evens out instead of swaying it (#346).
def steer(i:int, x:int, y:int, nx:int, ny:int, s:int) -> int, int:
    var vx = u_vx[i]
    var vy = u_vy[i]
    var ex = nx - x - vx
    var ey = ny - y - vy
    let e = isqrt(ex * ex + ey * ey)
    let acc = max(1, s / ACCEL_DIV)
    if e > acc:
        ex = ex * acc / e
        ey = ey * acc / e
    vx += ex
    vy += ey
    let v = isqrt(vx * vx + vy * vy)
    if v > s:
        vx = vx * s / v
        vy = vy * s / v
    return x + vx, y + vy

def move():
    let n = u_x.length
    // World._move means these as the tick's start, but Godot's packed arrays are shared, not copied
    // on write: its _ox, _om, _ost, _owx are the live arrays. The port follows what GDScript does.
    blocks_tick()
    o_x = u_x
    o_y = u_y
    o_moving = u_moving
    o_stuck = u_stuck
    o_wx = u_wx
    o_wy = u_wy
    let xs = u_x
    let ys = u_y
    let mv = u_moving
    let st = u_stuck
    let wxs = u_wx
    let wys = u_wy
    let mw = W
    let mh = H
    for(n) i:
        if mv[i] == 0:
            u_vx[i] = 0
            u_vy[i] = 0
            if u_group[i] == 0 or u_foe[i] != 0 or (tick + u_id[i]) % REPLAN_EVERY != 0: continue
            let back = if u_block[i] > 0 and not place_free(i): u_arrive[i] * ARRIVE_SETTLE + TILE else: u_arrive[i] * ARRIVE_SETTLE + (if u_arrive[i] == SLOT_ARRIVE: SLOT_SLACK else: RETURN_SLACK)  // (in a block: back to its place once it's clear, #347)
            if dist2(xs[i], ys[i], u_tx[i], u_ty[i]) <= back * back:
                st[i] = 0
                continue
            if st[i] >= STUCK_LIMIT: continue
            mv[i] = 1
        let x = xs[i]
        let y = ys[i]
        if u_reach[i] == 1:
            let ex = max(max(u_rx0[i] - x, 0), x - u_rx1[i])
            let ey = max(max(u_ry0[i] - y, 0), y - u_ry1[i])
            let reach = u_radius[i] + REACH
            if ex * ex + ey * ey <= reach * reach:
                mv[i] = 0
                st[i] = 0
                continue
        else:
            let gx = u_tx[i] - x
            let gy = u_ty[i] - y
            if gx * gx + gy * gy <= u_arrive[i] * u_arrive[i]:
                mv[i] = 0
                st[i] = 0
                continue
        var s = if u_pace[i] == 0: u_speed[i] else: min(u_speed[i], u_pace[i])
        let mci = u_mclass[i]
        let mc = lane_base[u_owner[i]] + mci
        let here = cell_of(x, y)
        var pct = speed_pct[mci][here]
        if pct < 100 and t_wade[u_kind[i]] > 0: pct = 100  // the swamp folk's bonus: no terrain slows them
        if slow_ids.length:
            let found, at = binary_search(slow_ids, u_id[i])
            if found: pct = pct * slow_pcts[at] / 100  // in an enemy web, or hit by sticky silk
        if pct != 100: s = s * pct / 100
        if tr_speed_pct != 0 and mci != 2: s = s * trail_pct(here) / 100  // quicker on a worn trail (a rule, off by default)
        if steered(i):                                                    // in a formation block: steering for its place (lib/steering.lobster, #355)
            steer_group(i, x, y, s, mc)
            continue
        if (tick + u_id[i]) % PROGRESS_EVERY == 0 and u_foe[i] == 0:
            let px, py = progress(i, x, y)
            if u_prog[i] >= 0 and px > u_prog[i] - py and u_group[i] > 0 and u_reach[i] == 0 and (queued(i, x, y) or passed(i, x, y)):
                pass()
            elif u_prog[i] >= 0 and px > u_prog[i] - py:
                st[i] += STUCK_LIMIT / (if u_group[i] > 0 and u_reach[i] == 0: 6 else: 2)
                if st[i] >= STUCK_LIMIT:
                    let near = u_arrive[i] * ARRIVE_SETTLE + RETURN_SLACK
                    if u_reach[i] != 1 and dist2(x, y, u_tx[i], u_ty[i]) <= near * near: st[i] = 0
                    mv[i] = 0
                    continue
            else:
                st[i] = 0
            u_prog[i] = px
        if (tick + u_id[i]) % REPLAN_EVERY == 0 or dist2(x, y, wxs[i], wys[i]) <= s * s:
            var wx, wy = plan(i, x, y, st[i])
            if wx == -2:
                // Past a near field's edge: switch to the full field, straight on meanwhile.
                let key = u_fkey[i]
                var base = key / LANES
                base = base - base % 4 + (if base % 4 == FIELD_CELL_NEAR: FIELD_CELL else: FIELD_BUILDING)
                u_fkey[i] = base * LANES + key % LANES
                wx = u_tx[i]
                wy = u_ty[i]
            elif wx == -3:
                // Nowhere free round its rect: a few looks like that and it gives the place up.
                st[i] += STUCK_LIMIT / SPOT_BUSY
                if st[i] >= STUCK_LIMIT:
                    mv[i] = 0
                    continue
                wx, wy = rect_near(i, x, y)
            elif wx < 0:
                mv[i] = 0
                st[i] = STUCK_LIMIT
                continue
            wxs[i] = wx
            wys[i] = wy
        var dx = wxs[i] - x
        var dy = wys[i] - y
        var d = isqrt(dx * dx + dy * dy)
        var stepping = false
        if d > u_radius[i] and u_foe[i] == 0:
            let vx, vy = sidestep(i, x, y, dx * ONE / d, dy * ONE / d, s)
            if vx != 0 or vy != 0:
                dx = vx
                dy = vy
                d = isqrt(dx * dx + dy * dy)
                stepping = true
        var nx = x
        var ny = y
        if d > 0:
            nx = x + dx * min(s, d) / d
            ny = y + dy * min(s, d) / d
            if not stepping and u_foe[i] == 0: nx, ny = steer(i, x, y, nx, ny, s)  // (a sidestep or a foe: straight)
        let wk = walks[mc]
        let ok_xy = nx >= 0 and ny >= 0 and nx / TILE < mw and ny / TILE < mh and wk[ny / TILE * mw + nx / TILE] == 1
        let ok_x = nx >= 0 and y >= 0 and nx / TILE < mw and y / TILE < mh and wk[y / TILE * mw + nx / TILE] == 1
        let ok_y = x >= 0 and ny >= 0 and x / TILE < mw and ny / TILE < mh and wk[ny / TILE * mw + x / TILE] == 1
        if ok_xy and (nx / TILE == x / TILE or ny / TILE == y / TILE or (ok_x and ok_y)):
            pass()
        elif ok_x:
            ny = y
        elif ok_y:
            nx = x
        else:
            nx = x
            ny = y
        u_vx[i] = nx - x
        u_vy[i] = ny - y
        if nx == x and ny == y:
            st[i]++
            if st[i] >= STUCK_LIMIT:
                mv[i] = 0
            else:
                var wx, wy = plan(i, x, y, st[i])
                if wx == -3: wx, wy = rect_near(i, x, y)
                wxs[i] = if wx >= 0: wx else: x
                wys[i] = if wx >= 0: wy else: y
            continue
        xs[i] = nx
        ys[i] = ny

// The nearest walkable point for a centre on blocked ground (World._step_out).
def step_out(x:int, y:int, mc:int) -> int, int:
    let cx = x / TILE
    let cy = y / TILE
    var bx = -1
    var by = -1
    var best_d = 1 << 30
    def try(ncx:int, ncy:int, px:int, py:int):
        if cell_walkable(ncx, ncy, mc):
            let d = abs(px - x) + abs(py - y)
            if d < best_d:
                best_d = d
                bx = px
                by = py
    try(cx - 1, cy, cx * TILE - 1, y)
    try(cx + 1, cy, (cx + 1) * TILE, y)
    try(cx, cy - 1, x, cy * TILE - 1)
    try(cx, cy + 1, x, (cy + 1) * TILE)
    if bx >= 0: return bx, by
    return centre(nearest_walkable(cy * W + cx, mc))

let GUN_SHOT_SPEED = 800  // milli-tiles a tick: a shot this fast is a gun's

// Push overlapping pairs apart (World._separate; nobody is at a job or fighting here).
def separate():
    let n = u_x.length
    let xs = u_x
    let ys = u_y
    let rs = u_radius
    let ids = u_id
    let mv = u_moving
    let grp = u_group
    let txs = u_tx
    let tys = u_ty
    let ar = u_arrive
    let owners = u_owner
    let w = W
    let h = H
    for(n) i:
        s_settle[i] = 0
        s_pushx[i] = 0
        s_pushy[i] = 0
        s_stood[i] = 0
        s_yields[i] = 0
        if grp[i] > 0 and ar[i] == SLOT_ARRIVE and u_reach[i] == 0:
            if mv[i] == 0:
                s_stood[i] = 1
                s_yields[i] = 1
            elif u_foe[i] == 0 and dist2(xs[i], ys[i], txs[i], tys[i]) <= RETURN_YIELD * RETURN_YIELD:
                s_yields[i] = 1
        // 1: standing idle (gives way), 2: walking to or from a job, 3: making for its own gather
        // spot or carrying home from it (it won't stop in the crowd).
        let task = u_task[i]
        s_role[i] = 0
        if mv[i] == 0 and task == T_NONE and u_foe[i] == 0 and s_stood[i] == 0: s_role[i] = 1
        elif mv[i] == 1 and u_gspot[i] >= 0 and (task == GATHER or task == T_RETURN): s_role[i] = 3
        elif mv[i] == 1 and task != T_NONE: s_role[i] = 2
        // Workers standing at their job are planted: nobody moves them. (Hitting a building, too: none here.)
        s_planted[i] = if mv[i] == 0 and (task == GATHER or task == BUILD): 1 else: 0
        if mv[i] == 0 and s_planted[i] == 0 and u_foe[i] != 0:
            // So is a unit hitting a building: the crowd round a wall walks round it.
            let b = b_index_of(u_foe[i])
            if b >= 0 and gap_b(i, b) <= t_reach[u_kind[i]] + HOLD: s_planted[i] = 1
            // A gun standing to fire: its own side goes round it (#262). A foe still shoves it, and so do bows, whose crush is what's balanced.
            if s_planted[i] == 0 and t_ranged[u_kind[i]] != 0 and t_shot_speed[u_kind[i]] >= GUN_SHOT_SPEED: s_planted[i] = 2
    for(n) u:
        if u_perch[u] == 0:  // units on walls stand apart from the crowd below
            let cx = sp_cell[u] % w
            let cy = sp_cell[u] / w
            let xu = xs[u]
            let yu = ys[u]
            let ru = rs[u]
            for(5) q:
                let nx = cx + SEP_DX[q]
                let ny = cy + SEP_DY[q]
                if nx < 0 or nx >= w or ny >= h: continue
                let c = ny * w + nx
                var k = sp_start[c]
                let e = sp_end[c]
                while k < e:
                    let v = sp_items[k]
                    k++
                    if (q == 0 and v <= u) or u_perch[v] != 0 or t_air[u_kind[u]] != t_air[u_kind[v]]: continue  // (aircraft pass over)
                    let rr = ru + rs[v]
                    var dx = xs[v] - xu
                    var dy = ys[v] - yu
                    if dx >= rr or dx <= -rr or dy >= rr or dy <= -rr: continue
                    let d2 = dx * dx + dy * dy
                    if d2 >= rr * rr: continue
                    var i = u
                    var j = v
                    if v < u:
                        i = v
                        j = u
                        dx = -dx
                        dy = -dy
                    if grp[i] == grp[j] and grp[i] > 0 and mv[i] != mv[j]:
                        let m = if mv[i] == 1: i else: j
                        let near = ar[m] * (if ar[m] == SLOT_ARRIVE: 2 else: ARRIVE_SETTLE)
                        if dist2(xs[m], ys[m], txs[m], tys[m]) <= near * near and not steered(m): s_settle[m] = 1  // (steering, it brakes into its place itself)
                    let d = isqrt(d2)
                    var ux = 0
                    var uy = 0
                    if d == 0:
                        let ang = (ids[i] * 31 + ids[j] * 17) & 255
                        ux = cos_a(ang)
                        uy = sin_a(ang)
                    else:
                        ux = dx * ONE / d
                        uy = dy * ONE / d
                    let si = steered(i)
                    let sj = steered(j)
                    if u_block[i] > 0 and u_block[j] > 0 and grp[i] == grp[j] and d > rr / 4 and not (si != sj and mv[if si: j else: i] == 0 and u_block[i] == u_block[j] and u_stuck[if si: i else: j] >= 6): continue  // (an army's blocks: their places keep them apart, and a unit crossing to its place isn't shoved back)
                    if si and sj and owners[i] == owners[j] and grp[i] == grp[j]: continue                                                                                                                               // (two of a side's steering units keep off each other themselves, #355)
                    if si != sj and owners[i] == owners[j]:
                        // One of the side's own steering through another standing about: the standing one is eased aside, the
                        // walker steers round it (#355). One at work or set to fire stays put.
                        let o = if si: j else: i
                        if mv[o] == 0 and u_foe[o] == 0 and s_planted[o] == 0:
                            let ease = (rr - d) / (SEPARATION_DIV * 2) + 1
                            let sg = if o == i: -1 else: 1
                            let wk = if si: i else: j
                            let wv = isqrt(u_vx[wk] * u_vx[wk] + u_vy[wk] * u_vy[wk])
                            var ex = sg * ux
                            var ey = sg * uy
                            if wv > 0:  // (aside: off the walker's line, never shoved along ahead of it)
                                let px = -u_vy[wk] * ONE / wv
                                let py = u_vx[wk] * ONE / wv
                                let across = (ex * px + ey * py) / ONE
                                ex = px * (if across >= 0: 1 else: -1)
                                ey = py * (if across >= 0: 1 else: -1)
                            s_pushx[o] += ex * ease / ONE
                            s_pushy[o] += ey * ease / ONE
                            continue
                    if grp[i] == grp[j] and ((s_stood[i] == 1 and mv[j] == 1) or (s_stood[j] == 1 and mv[i] == 1)): continue
                    if s_stood[i] == 1 and s_stood[j] == 1: continue
                    if owners[i] == owners[j] and grp[i] != grp[j] and ((s_stood[i] == 1 and s_yields[j] == 1 and mv[j] == 1) or (s_stood[j] == 1 and s_yields[i] == 1 and mv[i] == 1)): continue
                    // (a marching block doesn't give way to a sheep)
                    // (a soldier standing idle holds its ground against its own side just walking through, #262)
                    let own = owners[i] == owners[j]
                    let idle_i = own and s_role[i] == 1 and mv[j] == 1 and s_role[j] < 2 and t_worker[u_kind[i]] == 0 and t_animal[u_kind[i]] == 0
                    let idle_j = own and s_role[j] == 1 and mv[i] == 1 and s_role[i] < 2 and t_worker[u_kind[j]] == 0 and t_animal[u_kind[j]] == 0
                    let hi = (si and own and not sj and u_foe[j] == 0) or s_planted[i] == 1 or (own and s_planted[i] == 2) or idle_i or (u_block[i] > 0 and t_animal[u_kind[j]] != 0) or (s_role[i] >= 2 and s_role[j] == 1) or
                        (s_yields[j] == 1 and mv[i] == 1 and grp[i] > 0 and grp[i] != grp[j] and owners[i] == owners[j])
                    let hj = (sj and own and not si and u_foe[i] == 0) or s_planted[j] == 1 or (own and s_planted[j] == 2) or idle_j or (u_block[j] > 0 and t_animal[u_kind[i]] != 0) or (s_role[j] >= 2 and s_role[i] == 1) or
                        (s_yields[i] == 1 and mv[j] == 1 and grp[j] > 0 and grp[j] != grp[i] and owners[i] == owners[j])
                    if hi and hj: continue
                    // One of the side's own at work and a gatherer making for its spot: the walker slips past.
                    if owners[i] == owners[j] and ((s_planted[i] == 1 and s_role[j] == 3) or (s_planted[j] == 1 and s_role[i] == 3)): continue
                    let push = (rr - d) / SEPARATION_DIV + 1
                    let px = ux * push / ONE
                    let py = uy * push / ONE
                    if not hi:
                        s_pushx[i] -= px * (if hj: 2 else: 1)
                        s_pushy[i] -= py * (if hj: 2 else: 1)
                    if not hj:
                        s_pushx[j] += px * (if hi: 2 else: 1)
                        s_pushy[j] += py * (if hi: 2 else: 1)
    let t = TILE
    let mw = W
    let mh = H
    for(n) i:
        if s_settle[i] == 1: mv[i] = 0
        if u_perch[i] == 0:  // (up on a wall: the walkway places it)
            let mc = lane_base[owners[i]] + u_mclass[i]
            let wk = walks[mc]
            let x0 = xs[i]
            let y0 = ys[i]
            if x0 < 0 or y0 < 0 or x0 / t >= mw or y0 / t >= mh or wk[y0 / t * mw + x0 / t] == 0:
                let px, py = step_out(xs[i], ys[i], mc)
                xs[i] = px
                ys[i] = py
                continue
            if s_pushx[i] != 0:
                let nx = x0 + s_pushx[i]
                if nx >= 0 and nx / t < mw and wk[y0 / t * mw + nx / t] == 1: xs[i] = nx
            if s_pushy[i] != 0:
                let ny = y0 + s_pushy[i]
                if ny >= 0 and ny / t < mh and wk[ny / t * mw + xs[i] / t] == 1: ys[i] = ny
            let cx = xs[i] / t
            let cy = ys[i] / t
            let r = rs[i]
            let c = cy * mw + cx
            if xs[i] - cx * t < r and (cx == 0 or wk[c - 1] == 0):
                xs[i] = min(cx * t + r, xs[i] + CORRECT_MAX)
            elif (cx + 1) * t - xs[i] < r and (cx + 1 >= mw or wk[c + 1] == 0):
                xs[i] = max((cx + 1) * t - r, xs[i] - CORRECT_MAX)
            if ys[i] - cy * t < r and (cy == 0 or wk[c - mw] == 0):
                ys[i] = min(cy * t + r, ys[i] + CORRECT_MAX)
            elif (cy + 1) * t - ys[i] < r and (cy + 1 >= mh or wk[c + mw] == 0):
                ys[i] = max((cy + 1) * t - r, ys[i] - CORRECT_MAX)
            let pen = pen_holding(i)  // (a pen is walked over: its fence is only here)
            if pen >= 0:
                let hx, hy = pen_inside(pen, i, xs[i], ys[i])
                xs[i] += clamp(hx - xs[i], -CORRECT_MAX, CORRECT_MAX)
                ys[i] += clamp(hy - ys[i], -CORRECT_MAX, CORRECT_MAX)
