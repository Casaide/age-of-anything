// ------------------------------------------------------------------ orders (world.gd)

def lane(i:int) -> int: return lane_base[u_owner[i]] + u_mclass[i]

def index_of(uid:int) -> int:
    let found, at = binary_search(u_id, uid)
    return if found: at else: -1

def snap(ax:int, ay:int, ln:int) -> int, int:
    let x = clamp(ax, 0, W * TILE - 1)
    let y = clamp(ay, 0, H * TILE - 1)
    let cell = cell_of(x, y)
    if walks[ln][cell] == 0: return centre(nearest_walkable(cell, ln))
    return x, y

def off_walls(ax:int, ay:int, r:int, ln:int) -> int, int:
    var x = ax
    var y = ay
    let cx = x / TILE
    let cy = y / TILE
    if x - cx * TILE < r and not cell_walkable(cx - 1, cy, ln):
        x = cx * TILE + min(r, TILE / 2)
    elif (cx + 1) * TILE - x < r and not cell_walkable(cx + 1, cy, ln):
        x = (cx + 1) * TILE - min(r, TILE / 2)
    if y - cy * TILE < r and not cell_walkable(cx, cy - 1, ln):
        y = cy * TILE + min(r, TILE / 2)
    elif (cy + 1) * TILE - y < r and not cell_walkable(cx, cy + 1, ln):
        y = (cy + 1) * TILE - min(r, TILE / 2)
    return x, y

let SLOT_STEPS = 8  // a formation slot that isn't open steps in towards the centre in this many steps

def slot_ok(i:int, apx:int, apy:int, x:int, y:int) -> int, int:
    let ln = lane(i)
    let cx, cy = snap(x, y, ln)
    // (the first open point stepping in along the line to the centre: falling straight back to the centre gave two
    // units one spot, and one gave up, the hill crossing)
    for(SLOT_STEPS) k:
        var qx = clamp(apx + (cx - apx) * k / SLOT_STEPS, 0, W * TILE - 1)
        var qy = clamp(apy + (cy - apy) * k / SLOT_STEPS, 0, H * TILE - 1)
        if walkable(qx, qy, ln):
            qx, qy = off_walls(qx, qy, u_radius[i], ln)
            if clear_line(cx, cy, qx, qy, ln): return qx, qy
    return cx, cy

// Sorts ints ascending (bottom-up merge sort; the keys are unique, so any sort gives this order).
def sort_ints(xs:[int]):
    let n = xs.length
    var src = xs
    var dst = copy(xs)
    var width = 1
    var into_dst = true
    while width < n:
        var lo = 0
        while lo < n:
            let mid = min(lo + width, n)
            let hi = min(lo + 2 * width, n)
            var a = lo
            var b = mid
            var o = lo
            while o < hi:
                if a < mid and (b >= hi or src[a] <= src[b]):
                    dst[o] = src[a]
                    a++
                else:
                    dst[o] = src[b]
                    b++
                o++
            lo += 2 * width
        let t = src
        src = dst
        dst = t
        into_dst = not into_dst
        width *= 2
    if src != xs:
        for(n) k: xs[k] = src[k]

// Slots in (ahead desc, slot asc) order: World._formation's by_ahead.
def by_ahead(part:[int]) -> [int]:
    let keys = map(part) i: -f_ahead[i] * (1 << KEY_BITS) + i
    sort_ints(keys)
    return map(keys) k: k & ((1 << KEY_BITS) - 1)

// Slots in (side asc, slot asc) order: by_side.
def by_side(part:[int]) -> [int]:
    let keys = map(part) i: f_side[i] * (1 << KEY_BITS) + i
    sort_ints(keys)
    return map(keys) k: k & ((1 << KEY_BITS) - 1)

def form_rmax(part:[int]) -> int:
    var r = 0
    for(part) i: r = max(r, u_radius[i])
    return r

def form_space(part:[int]) -> int:
    var g = -(1 << 20)
    for(part) i: g = max(g, t_gap[u_kind[i]])
    return 2 * form_rmax(part) + max(FORM_GAP + g, 0)

// A group move's formation (World._formation): every unit's slot into slot_x / slot_y.
// Returns the group, its centre (fx, fy) and pace.
def formation(player:int, ids:[int], ax:int, ay:int) -> int, int, int, int:
    let idx = []::int
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_owner[i] == player: idx.push(i)
    let group = next_group
    next_group++
    let x = clamp(ax, 0, W * TILE - 1)
    let y = clamp(ay, 0, H * TILE - 1)
    if not idx.length: return group, x, y, 0
    let n = idx.length
    var sx = 0
    var sy = 0
    var pace = 1 << 30
    for(idx) i:
        sx += u_x[i]
        sy += u_y[i]
        pace = min(pace, u_speed[i])
    let cx = sx / n
    let cy = sy / n
    let dx = x - cx
    let dy = y - cy
    let d = isqrt(dx * dx + dy * dy)
    var ux = 0
    var uy = ONE
    if d > 0:
        ux = dx * ONE / d
        uy = dy * ONE / d
    let bands = [ []::int, []::int, []::int ]
    var flank = []::int
    for(idx) i:
        let role = t_role[u_kind[i]]
        if role == 3: flank.push(i)
        else: bands[role].push(i)
    if not bands[0].length and not bands[1].length:
        bands[0] = flank
        flank = []::int
    for(idx) i:
        f_ahead[i] = (u_x[i] - cx) * ux + (u_y[i] - cy) * uy
        f_side[i] = (u_y[i] - cy) * ux - (u_x[i] - cx) * uy
    let nc = bands[0].length + bands[1].length + bands[2].length
    let cols = clamp(isqrt(2 * nc), 1, nc)
    var total = 0
    var half = 0
    var deep = 0
    for(bands) part, k:
        if part.length:
            let rows = (part.length + cols - 1) / cols
            let sp = form_space(part)
            total += rows * sp
            half = max(half, (min(cols, part.length) - 1) * sp / 2 + form_rmax(part))
            if k < 2: deep += rows
    def put(i:int, along:int, across:int):
        let px = x + (ux * along - uy * across) / ONE
        let py = y + (uy * along + ux * across) / ONE
        let qx, qy = slot_ok(i, px, py, x, y)
        slot_x[i] = qx
        slot_y[i] = qy
    var top = total / 2
    for(bands) band:
        if band.length:
            let sp = form_space(band)
            let part = by_ahead(band)
            var first = 0
            while first < part.length:
                let line = by_side(part.slice(first, min(cols, part.length - first)))
                let k = line.length
                for(line) i, c: put(i, top - sp / 2, (2 * c - (k - 1)) * sp / 2)
                top -= sp
                first += cols
    if flank.length:
        let fl = by_side(flank)
        let nl = (fl.length + 1) / 2
        let sp = form_space(fl)
        let inner = half + FORM_GAP + form_rmax(fl)
        for([ fl.slice(0, nl), fl.slice(nl, -1) ]) wing0:
            if wing0.length:
                let left = wing0[0] == fl[0]
                let depth = clamp(deep, 1, wing0.length)
                let wc = (wing0.length + depth - 1) / depth
                let wing = by_ahead(wing0)
                var along = total / 2 - sp / 2
                var first = 0
                while first < wing.length:
                    let line = by_side(wing.slice(first, min(wc, wing.length - first)))
                    let k = line.length
                    for(line) i, c:
                        put(i, along, if left: -(inner + (k - 1 - c) * sp) else: inner + c * sp)
                    along -= sp
                    first += wc
    return group, x, y, if n > 1: pace else: 0

def start(i:int):
    u_moving[i] = 1
    u_stuck[i] = 0
    u_prog[i] = -1
    var wx, wy = plan(i, u_x[i], u_y[i], 0)
    if wx == -3: wx, wy = rect_near(i, u_x[i], u_y[i])
    u_wx[i] = if wx >= 0: wx else: u_x[i]
    u_wy[i] = if wx >= 0: wy else: u_y[i]

// Field keys: ((target * 4 + kind) * LANES + lane).
def cell_field(cell:int, near:bool, ln:int) -> int:
    return (cell * 4 + (if near: FIELD_CELL_NEAR else: FIELD_CELL)) * LANES + ln

def building_field(bid:int, near:bool, ln:int) -> int:
    return (bid * 4 + (if near: FIELD_BUILDING_NEAR else: FIELD_BUILDING)) * LANES + ln

// Head for "next to" a rect of milli-tiles (inclusive), following field `key` (World.order_reach).
def order_reach(i:int, x0:int, y0:int, x1:int, y1:int, key:int):
    if u_perch[i] != 0: return  // on a wall: it walks the walkway, never the ground
    u_tx[i] = x0 + (x1 - x0) / 2
    u_ty[i] = y0 + (y1 - y0) / 2
    u_reach[i] = 1
    u_rx0[i] = x0
    u_ry0[i] = y0
    u_rx1[i] = x1
    u_ry1[i] = y1
    u_fkey[i] = key
    u_arrive[i] = 0
    u_group[i] = 0
    start(i)

// Head for a point (snapped to walkable ground) and stop within `arrive` (World.order_move). In a
// group move, its own slot by the field of the group's centre (fx, fy); `near`: a near field.
def order_move(i:int, x:int, y:int, arrive:int, group:int, fx:int, fy:int, pace:int, near:bool = false):
    if u_perch[i] != 0: return
    let ln = lane(i)
    let px, py = snap(x, y, ln)
    var cell = cell_of(px, py)
    if fx >= 0:
        let qx, qy = snap(fx, fy, ln)
        cell = cell_of(qx, qy)
    u_tx[i] = px
    u_ty[i] = py
    u_reach[i] = 0
    u_fkey[i] = cell_field(cell, near, ln)
    u_arrive[i] = arrive
    u_group[i] = group
    u_pace[i] = pace
    start(i)

// Head for a point of its own beside a rect (a place round a building it attacks), following the
// rect's field `key` there and stepping round the rect's corners near it (World.order_beside).
def order_beside(i:int, x:int, y:int, x0:int, y0:int, x1:int, y1:int, key:int):
    if u_perch[i] != 0: return
    u_tx[i] = x
    u_ty[i] = y
    u_reach[i] = 2
    u_rx0[i] = x0
    u_ry0[i] = y0
    u_rx1[i] = x1
    u_ry1[i] = y1
    u_fkey[i] = key
    u_arrive[i] = SLOT_ARRIVE
    u_group[i] = 0
    u_pace[i] = 0
    start(i)

// Head straight for a point with no flow field (World.order_direct).
def order_direct(i:int, x:int, y:int):
    if u_perch[i] != 0: return
    u_tx[i] = x
    u_ty[i] = y
    u_reach[i] = 0
    u_fkey[i] = -1
    u_arrive[i] = 0
    u_group[i] = 0
    start(i)

// Back on an attack-move after a fight: to its own slot, by the group's field (World.resume_attack_move).
def resume_attack_move(i:int):
    var cx = u_amx[i]
    var cy = u_amy[i]
    if u_amc[i] >= 0:
        cx, cy = centre(u_amc[i])
    order_move(i, u_amx[i], u_amy[i], SLOT_ARRIVE, 0, cx, cy, 0)

// A MOVE command (World._run, after the formation: for each of the player's units its job and fight
// forgotten (Economy.clear_task, Combat.clear) and order_move to its slot).
def run_move(player:int, ids:[int], group:int, fx:int, fy:int, pace:int):
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_owner[i] == player:
            clear_task(i)
            combat_clear(i)
            order_move(i, slot_x[i], slot_y[i], SLOT_ARRIVE, group, fx, fy, pace)

// An ATTACK_MOVE command (Combat.cmd_attack_move, after the formation).
def run_attack_move(player:int, ids:[int], group:int, fx:int, fy:int, pace:int):
    let slots = []::int
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_owner[i] == player: slots.push(i)
    if not slots.length: return
    let centre_cell = cell_of(fx, fy)
    for(slots) i:
        if t_harmless[u_kind[i]]:
            combat_clear(i)
            clear_task(i)
            order_move(i, slot_x[i], slot_y[i], SLOT_ARRIVE, group, fx, fy, pace)
            continue
        clear_task(i)
        u_foe[i] = 0
        u_patient[i] = 0
        u_stance[i] = ATTACK_MOVE
        u_amx[i] = slot_x[i]
        u_amy[i] = slot_y[i]
        u_amc[i] = centre_cell
        order_move(i, slot_x[i], slot_y[i], SLOT_ARRIVE, group, fx, fy, pace)

// A STANCE command (Combat.cmd_stance).
def run_stance(player:int, ids:[int], posture:int):
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_owner[i] == player and t_animal[u_kind[i]] == 0:  // (animals have no stance)
            u_posture[i] = posture
            if u_stance[i] == AUTO and posture == PASSIVE:
                u_foe[i] = 0
                u_stance[i] = NONE
                u_moving[i] = 0
