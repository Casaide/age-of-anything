// ------------------------------------------------------------------ movement (world.gd)

// Unit i's next waypoint from (x, y) (World._plan, point moves). `stuck` is its count at the tick's start.
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
    if cost == 0 or (cost <= DIRECT_COST and stuck < STUCK_LIMIT / 2 and clear_path(x, y, tx, ty, u_radius[i], lane(i))):
        return tx, ty
    let best = ahead(f, cell, x, y, if stuck >= STUCK_LIMIT / 2: 1 else: LOOKAHEAD, u_radius[i], lane(i))
    if best < 0: return tx, ty
    return centre(best)

def progress(i:int, x:int, y:int) -> int, int:
    if u_fkey[i] >= 0:
        let n = field_index(u_fkey[i])
        if n >= 0:
            let d = field_vals[n].dist[cell_of(x, y)]
            if d < INF and d > DIAGONAL and not (d <= DIRECT_COST and u_arrive[i] == SLOT_ARRIVE):
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

def move():
    let n = u_x.length
    // World._move means these as the tick's start, but Godot's packed arrays are shared, not copied
    // on write: its _ox, _om, _ost, _owx are the live arrays. The port follows what GDScript does.
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
            if u_group[i] == 0 or u_foe[i] != 0 or (tick + u_id[i]) % REPLAN_EVERY != 0: continue
            let back = u_arrive[i] * ARRIVE_SETTLE + (if u_arrive[i] == SLOT_ARRIVE: SLOT_SLACK else: RETURN_SLACK)
            if dist2(xs[i], ys[i], u_tx[i], u_ty[i]) <= back * back:
                st[i] = 0
                continue
            if st[i] >= STUCK_LIMIT: continue
            mv[i] = 1
        let x = xs[i]
        let y = ys[i]
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
        let pct = speed_pct[mci][here]
        if pct != 100: s = s * pct / 100
        if (tick + u_id[i]) % PROGRESS_EVERY == 0 and u_foe[i] == 0:
            let px, py = progress(i, x, y)
            if u_prog[i] >= 0 and px > u_prog[i] - py and u_group[i] > 0 and (queued(i, x, y) or passed(i, x, y)):
                pass()
            elif u_prog[i] >= 0 and px > u_prog[i] - py:
                st[i] += STUCK_LIMIT / (if u_group[i] > 0: 6 else: 2)
                if st[i] >= STUCK_LIMIT:
                    let near = u_arrive[i] * ARRIVE_SETTLE + RETURN_SLACK
                    if dist2(x, y, u_tx[i], u_ty[i]) <= near * near: st[i] = 0
                    mv[i] = 0
                    continue
            else:
                st[i] = 0
            u_prog[i] = px
        if (tick + u_id[i]) % REPLAN_EVERY == 0 or dist2(x, y, wxs[i], wys[i]) <= s * s:
            let wx, wy = plan(i, x, y, st[i])
            assert wx != -2 and wx != -3   // (no near fields, no rects in the spike)
            if wx < 0:
                mv[i] = 0
                st[i] = STUCK_LIMIT
                continue
            wxs[i] = wx
            wys[i] = wy
        var dx = wxs[i] - x
        var dy = wys[i] - y
        var d = isqrt(dx * dx + dy * dy)
        if d > u_radius[i] and u_foe[i] == 0:
            let vx, vy = sidestep(i, x, y, dx * ONE / d, dy * ONE / d, s)
            if vx != 0 or vy != 0:
                dx = vx
                dy = vy
                d = isqrt(dx * dx + dy * dy)
        var nx = x
        var ny = y
        if d > 0:
            nx = x + dx * min(s, d) / d
            ny = y + dy * min(s, d) / d
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
        if nx == x and ny == y:
            st[i]++
            if st[i] >= STUCK_LIMIT:
                mv[i] = 0
            else:
                let wx, wy = plan(i, x, y, st[i])
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
        if grp[i] > 0 and ar[i] == SLOT_ARRIVE:
            if mv[i] == 0:
                s_stood[i] = 1
                s_yields[i] = 1
            elif u_foe[i] == 0 and dist2(xs[i], ys[i], txs[i], tys[i]) <= RETURN_YIELD * RETURN_YIELD:
                s_yields[i] = 1
        s_role[i] = if mv[i] == 0 and u_foe[i] == 0 and s_stood[i] == 0: 1 else: 0
    for(n) u:
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
                if q == 0 and v <= u: continue
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
                    if dist2(xs[m], ys[m], txs[m], tys[m]) <= near * near: s_settle[m] = 1
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
                if grp[i] == grp[j] and ((s_stood[i] == 1 and mv[j] == 1) or (s_stood[j] == 1 and mv[i] == 1)): continue
                if s_stood[i] == 1 and s_stood[j] == 1: continue
                if owners[i] == owners[j] and grp[i] != grp[j] and ((s_stood[i] == 1 and s_yields[j] == 1 and mv[j] == 1) or (s_stood[j] == 1 and s_yields[i] == 1 and mv[i] == 1)): continue
                let hi = s_yields[j] == 1 and mv[i] == 1 and grp[i] > 0 and grp[i] != grp[j] and owners[i] == owners[j]
                let hj = s_yields[i] == 1 and mv[j] == 1 and grp[j] > 0 and grp[j] != grp[i] and owners[i] == owners[j]
                if hi and hj: continue
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

