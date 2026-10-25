// The Lobster sim spike (2026-10-25): src/sim's movement ported to Lobster, headless.
// Covers what a group MOVE uses: formations (World._formation), order_move, flow fields
// (flow.gd: solve, ahead, clear_path, clear_line, nearest_walkable), World._move with
// _sidestep / _queued / _passed / _plan / _progress, _solve_queued, the spatial buckets and
// World._separate. Reads a scenario written by tests/lobster_spike/export.gd and checks a hash of
// the movement state after every tick against the GDScript sim's.
// Left out (constant in the scenario, asserted by the exporter): jobs (task NONE), fights (foe 0),
// walls (perch 0), rect moves (reach 0), near fields, webs, trails, wading, map changes.
// Run: lobster sim.lobster -- <scenario file>

import std

// ------------------------------------------------------------------ constants

let TILE = 1000
let ONE = 1024
let MASK = 0xFFFFFFFF
let FNV_PRIME = 0x01000193
let FNV_START = 0x811C9DC5
let INF = 1 << 30
let STRAIGHT = 10
let DIAGONAL = 14
let RING = 15
let LINE_STEP = 333
let ROOM_CHUNK = 2

let TICKS_PER_TURN = 4
let ARRIVE_SETTLE = 4          // SETTLE_FACTOR
let SEPARATION_DIV = 4
let REPLAN_EVERY = 8
let LOOKAHEAD = 6
let DIRECT_COST = 160
let STUCK_LIMIT = 60
let PROGRESS_EVERY = 40
let CORRECT_MAX = 150
let RETURN_SLACK = 1000
let FIELD_CACHE = 24
let SOLVE_BUDGET = 1500
let LANES = 32
let FORM_GAP = 160
let SLOT_ARRIVE = 60
let SLOT_SLACK = 400
let QUEUE_GAP = 300
let RETURN_YIELD = 2000
let STRAIGHT_PER_CHECK = 10
let FIELD_CELL = 0
let FIELD_CELL_NEAR = 1
let FIELD_BUILDING_NEAR = 2
let SEP_DX = [0, 1, -1, 0, 1]
let SEP_DY = [0, 0, 1, 1, 1]
let KEY_BITS = 21              // slot bits in a formation sort key

let SIN = [
    0, 25, 50, 75, 100, 125, 150, 175, 200, 224, 249, 273, 297, 321, 345, 369,
    392, 415, 438, 460, 483, 505, 526, 548, 569, 590, 610, 630, 650, 669, 688, 706,
    724, 742, 759, 775, 792, 807, 822, 837, 851, 865, 878, 891, 903, 915, 926, 936,
    946, 955, 964, 972, 980, 987, 993, 999, 1004, 1009, 1013, 1016, 1019, 1021, 1023, 1024,
    1024, 1024, 1023, 1021, 1019, 1016, 1013, 1009, 1004, 999, 993, 987, 980, 972, 964, 955,
    946, 936, 926, 915, 903, 891, 878, 865, 851, 837, 822, 807, 792, 775, 759, 742,
    724, 706, 688, 669, 650, 630, 610, 590, 569, 548, 526, 505, 483, 460, 438, 415,
    392, 369, 345, 321, 297, 273, 249, 224, 200, 175, 150, 125, 100, 75, 50, 25,
    0, -25, -50, -75, -100, -125, -150, -175, -200, -224, -249, -273, -297, -321, -345, -369,
    -392, -415, -438, -460, -483, -505, -526, -548, -569, -590, -610, -630, -650, -669, -688, -706,
    -724, -742, -759, -775, -792, -807, -822, -837, -851, -865, -878, -891, -903, -915, -926, -936,
    -946, -955, -964, -972, -980, -987, -993, -999, -1004, -1009, -1013, -1016, -1019, -1021, -1023, -1024,
    -1024, -1024, -1023, -1021, -1019, -1016, -1013, -1009, -1004, -999, -993, -987, -980, -972, -964, -955,
    -946, -936, -926, -915, -903, -891, -878, -865, -851, -837, -822, -807, -792, -775, -759, -742,
    -724, -706, -688, -669, -650, -630, -610, -590, -569, -548, -526, -505, -483, -460, -438, -415,
    -392, -369, -345, -321, -297, -273, -249, -224, -200, -175, -150, -125, -100, -75, -50, -25,
]

// ------------------------------------------------------------------ fixed.gd

def sin_a(angle:int) -> int: return SIN[angle & 255]
def cos_a(angle:int) -> int: return SIN[(angle + 64) & 255]

// Floor of the square root, for n >= 0 (Fixed.isqrt: Newton's steps from a power of two above the root).
def isqrt(n:int) -> int:
    if n < 2: return n
    var m = n
    var b = 1
    if m >= (1 << 32):
        m = m >> 32
        b += 16
    if m >= (1 << 16):
        m = m >> 16
        b += 8
    if m >= (1 << 8):
        m = m >> 8
        b += 4
    if m >= (1 << 4):
        m = m >> 4
        b += 2
    if m >= (1 << 2):
        b += 1
    var x = 1 << b
    var y = (x + n / x) >> 1
    while y < x:
        x = y
        y = (x + n / x) >> 1
    return x

def dist2(ax:int, ay:int, bx:int, by:int) -> int:
    let dx = bx - ax
    let dy = by - ay
    return dx * dx + dy * dy

def mix(h:int, v:int) -> int:
    let a = ((h ^ (v & MASK)) * FNV_PRIME) & MASK
    return ((a ^ ((v >> 32) & MASK)) * FNV_PRIME) & MASK

// ------------------------------------------------------------------ the scenario

var tokens = []::string
var tp = 0

def next_int() -> int:
    let v, ok = string_to_int(tokens[tp])
    assert ok
    tp++
    return v

def expect(word:string):
    assert tokens[tp] == word
    tp++

def read_ints(n:int) -> [int]:
    let out = []::int
    out.vector_capacity(n)
    for(n): out.push(next_int())
    return out

// ------------------------------------------------------------------ state

// Map (sim_map.gd): walk grids per lane, terrain speed percent per movement class and cell.
var W = 0
var H = 0
var walks = []::[int]
var roomy = []::[int]          // per lane: 1 where the cell and its 8 neighbours are on the map and walkable
var tight = []::[int]          // per lane: cells not roomy per ROOM_CHUNK block
var room_cw = 0
var speed_pct = []::[int]
var lane_base = []::int
var num_players = 0

// Unit types: speed, radius, formation role, form_gap.
var t_speed = []::int
var t_radius = []::int
var t_role = []::int
var t_gap = []::int

// Units (units.gd), slots sorted by id. reach, task, foe, perch, gspot are constant here.
var u_id = []::int
var u_owner = []::int
var u_kind = []::int
var u_x = []::int
var u_y = []::int
var u_tx = []::int
var u_ty = []::int
var u_moving = []::int
var u_arrive = []::int
var u_wx = []::int
var u_wy = []::int
var u_group = []::int
var u_stuck = []::int
var u_prog = []::int
var u_fkey = []::int
var u_speed = []::int
var u_radius = []::int
var u_mclass = []::int
var u_pace = []::int

var tick = 0
var next_group = 1

// The tick's start, for _sidestep / _queued / _passed (World._move's _ox ... copies).
var o_x = []::int
var o_y = []::int
var o_moving = []::int
var o_stuck = []::int
var o_wx = []::int
var o_wy = []::int

// Spatial buckets (spatial.gd): bucket c holds sp_items[sp_start[c] .. sp_end[c] - 1], slots ascending.
var sp_start = []::int
var sp_end = []::int
var sp_items = []::int
var sp_cell = []::int
var sp_cursor = []::int

// Formation scratch: each unit's slot, how far ahead / aside it stands.
var slot_x = []::int
var slot_y = []::int
var f_ahead = []::int
var f_side = []::int

// Separation scratch.
var s_pushx = []::int
var s_pushy = []::int
var s_settle = []::int
var s_stood = []::int
var s_yields = []::int
var s_role = []::int

// ------------------------------------------------------------------ flow fields (flow.gd)

class Flow:
    source:int
    max_cost:int
    pops:int
    dist:[int]
    next:[int]

var field_keys = []::int       // World.field_order: cached field keys, oldest first
var field_vals = []::Flow      // alongside
var field_queue = []::int
var ring = []::[int]

def centre(cell:int) -> int, int:
    return (cell % W) * TILE + TILE / 2, (cell / W) * TILE + TILE / 2

def cell_of(x:int, y:int) -> int:
    return clamp(y / TILE, 0, H - 1) * W + clamp(x / TILE, 0, W - 1)

def walkable(x:int, y:int, k:int) -> bool:
    if x < 0 or y < 0: return false
    let tx = x / TILE
    let ty = y / TILE
    if tx >= W or ty >= H: return false
    return walks[k][ty * W + tx] == 1

def cell_walkable(cx:int, cy:int, k:int) -> bool:
    return cx >= 0 and cy >= 0 and cx < W and cy < H and walks[k][cy * W + cx] == 1

def solve(src:int, cutoff:int, k:int) -> Flow:
    let w = W
    let h = H
    let n = w * h
    let walk = walks[k]
    let dist = []::int
    let next = []::int
    dist.vector_capacity(n)
    next.vector_capacity(n)
    for(n):
        dist.push(INF)
        next.push(-1)
    var pending = 0
    dist[src] = 0
    ring[0].push(src)
    pending++
    var pops = 0
    var cost = 0
    while pending > 0 and cost <= cutoff:
        let bucket = ring[cost % RING]
        var bi = 0
        while bi < bucket.length:
            let c = bucket[bi]
            bi++
            pending--
            if dist[c] != cost: continue
            pops++
            let cx = c % w
            let cy = c / w
            let up = cy > 0 and walk[c - w] == 1
            let down = cy < h - 1 and walk[c + w] == 1
            let left = cx > 0 and walk[c - 1] == 1
            let right = cx < w - 1 and walk[c + 1] == 1
            let from_blocked = walk[c] == 0
            let ne = (up and right) or (from_blocked and cy > 0 and cx < w - 1)
            let se = (down and right) or (from_blocked and cy < h - 1 and cx < w - 1)
            let sw = (down and left) or (from_blocked and cy < h - 1 and cx > 0)
            let nw = (up and left) or (from_blocked and cy > 0 and cx > 0)
            let s = cost + STRAIGHT
            let d = cost + DIAGONAL
            let bs = ring[s % RING]
            let bd = ring[d % RING]
            let n_ = c - w
            let e_ = c + 1
            let s_ = c + w
            let w_ = c - 1
            if up and s < dist[n_]:
                dist[n_] = s
                next[n_] = c
                bs.push(n_)
                pending++
            if right and s < dist[e_]:
                dist[e_] = s
                next[e_] = c
                bs.push(e_)
                pending++
            if down and s < dist[s_]:
                dist[s_] = s
                next[s_] = c
                bs.push(s_)
                pending++
            if left and s < dist[w_]:
                dist[w_] = s
                next[w_] = c
                bs.push(w_)
                pending++
            if ne and walk[n_ + 1] == 1 and d < dist[n_ + 1]:
                dist[n_ + 1] = d
                next[n_ + 1] = c
                bd.push(n_ + 1)
                pending++
            if se and walk[s_ + 1] == 1 and d < dist[s_ + 1]:
                dist[s_ + 1] = d
                next[s_ + 1] = c
                bd.push(s_ + 1)
                pending++
            if sw and walk[s_ - 1] == 1 and d < dist[s_ - 1]:
                dist[s_ - 1] = d
                next[s_ - 1] = c
                bd.push(s_ - 1)
                pending++
            if nw and walk[n_ - 1] == 1 and d < dist[n_ - 1]:
                dist[n_ - 1] = d
                next[n_ - 1] = c
                bd.push(n_ - 1)
                pending++
        bucket.remove_range(0, bucket.length)
        cost++
    for(ring) b: b.remove_range(0, b.length)   // (a cutoff can leave some queued)
    return Flow { src, cutoff, pops, dist, next }

// The walkable cell closest to `cell` (itself if walkable). Ties go to the lower index.
def nearest_walkable(cell:int, k:int) -> int:
    if walks[k][cell] == 1: return cell
    let cx = cell % W
    let cy = cell / W
    var r = 1
    while r < max(W, H):
        var best = -1
        var best_d2 = INF
        var y = cy - r
        while y <= cy + r:
            var x = cx - r
            while x <= cx + r:
                if max(abs(x - cx), abs(y - cy)) == r and cell_walkable(x, y, k):
                    let d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                    if d2 < best_d2:
                        best_d2 = d2
                        best = y * W + x
                x++
            y++
        if best >= 0: return best
        r++
    assert false
    return -1

def clear_line(ax:int, ay:int, bx:int, by:int, k:int) -> bool:
    let dx = bx - ax
    let dy = by - ay
    let steps = max(abs(dx), abs(dy)) / LINE_STEP + 1
    var px = ax
    var py = ay
    var i = 1
    while i <= steps:
        let x = ax + dx * i / steps
        let y = ay + dy * i / steps
        if not walkable(x, y, k): return false
        if x / TILE != px / TILE and y / TILE != py / TILE and not (walkable(x, py, k) and walkable(px, y, k)):
            return false
        px = x
        py = y
        i++
    return true

def open_box(tg:[int], cw:int, cx0:int, cy0:int, cx1:int, cy1:int) -> bool:
    let xb0 = cx0 / ROOM_CHUNK
    let xb1 = cx1 / ROOM_CHUNK
    var yb = cy0 / ROOM_CHUNK
    let yb1 = cy1 / ROOM_CHUNK
    while yb <= yb1:
        let row = yb * cw
        var xb = xb0
        while xb <= xb1:
            if tg[row + xb] != 0: return false
            xb++
        yb++
    return true

def blocked(walk:[int], w:int, h:int, x:int, y:int) -> bool:
    if x < 0 or y < 0: return true
    let cx = x / TILE
    let cy = y / TILE
    return cx >= w or cy >= h or walk[cy * w + cx] == 0

def clear_walk(walk:[int], room:[int], w:int, h:int, ax:int, ay:int, bx:int, by:int, r:int) -> bool:
    let dx = bx - ax
    let dy = by - ay
    let len = max(1, isqrt(dx * dx + dy * dy))
    let ox = -dy * r / len
    let oy = dx * r / len
    let steps = max(abs(dx), abs(dy)) / LINE_STEP + 1
    var px = ax
    var py = ay
    var i = 1
    while i <= steps:
        let x = ax + dx * i / steps
        let y = ay + dy * i / steps
        i++
        var cx = x / TILE
        var cy = y / TILE
        if x < 0 or y < 0 or cx >= w or cy >= h or walk[cy * w + cx] == 0: return false
        if room[cy * w + cx] == 1:
            px = x
            py = y
            continue
        var sx = x + ox
        var sy = y + oy
        cx = sx / TILE
        cy = sy / TILE
        if sx < 0 or sy < 0 or cx >= w or cy >= h or walk[cy * w + cx] == 0: return false
        sx = x - ox
        sy = y - oy
        cx = sx / TILE
        cy = sy / TILE
        if sx < 0 or sy < 0 or cx >= w or cy >= h or walk[cy * w + cx] == 0: return false
        if x / TILE != px / TILE and y / TILE != py / TILE and (blocked(walk, w, h, x, py) or blocked(walk, w, h, px, y)):
            return false
        px = x
        py = y
    return true

def clear_path(ax:int, ay:int, bx:int, by:int, r:int, k:int) -> bool:
    let w = W
    let h = H
    if ax >= 0 and ay >= 0 and bx >= 0 and by >= 0 and ax < w * TILE and bx < w * TILE and ay < h * TILE and by < h * TILE and open_box(tight[k], room_cw, min(ax, bx) / TILE, min(ay, by) / TILE, max(ax, bx) / TILE, max(ay, by) / TILE):
        return true
    return clear_walk(walks[k], roomy[k], w, h, ax, ay, bx, by, r)

// The furthest of the next n cells down field f from `cell` a body of radius r at (x, y) walks to
// in a straight line; -2 - the last clear cell if the walk reached a source.
def ahead(f:Flow, cell:int, x:int, y:int, n:int, r:int, k:int) -> int:
    let room = roomy[k]
    let walk = walks[k]
    let tg = tight[k]
    let cw = room_cw
    let w = W
    let h = H
    let dist = f.dist
    let nxt = f.next
    let inside = x >= 0 and y >= 0 and x < w * TILE and y < h * TILE
    var cx0 = x / TILE
    var cy0 = y / TILE
    var cx1 = cx0
    var cy1 = cy0
    var best = cell
    var c = nxt[cell]
    for(n):
        if c < 0: break
        if dist[c] == 0: return -2 - best
        let gx = c % w
        let gy = c / w
        cx0 = min(cx0, gx)
        cy0 = min(cy0, gy)
        cx1 = max(cx1, gx)
        cy1 = max(cy1, gy)
        var clear = inside and open_box(tg, cw, cx0, cy0, cx1, cy1)
        if not clear and inside:
            clear = open_box(tg, cw, min(x / TILE, gx), min(y / TILE, gy), max(x / TILE, gx), max(y / TILE, gy))
        if not clear and not clear_walk(walk, room, w, h, x, y, gx * TILE + TILE / 2, gy * TILE + TILE / 2, r):
            break
        best = c
        c = nxt[c]
    return best

def field_index(key:int) -> int:
    for(field_keys) k, n:
        if k == key: return n
    return -1

// The flow field for a key, or nil (and queued) if it isn't solved yet (World.field_for).
def field_for(key:int) -> Flow?:
    let n = field_index(key)
    if n >= 0: return field_vals[n]
    var queued = false
    for(field_queue) k:
        if k == key: queued = true
    if not queued: field_queue.push(key)
    return nil

def solve_queued():
    var spent = 0
    while field_queue.length > 0 and (spent == 0 or spent < SOLVE_BUDGET):
        let key = field_queue.remove(0)
        if field_index(key) >= 0: continue
        let mc = key % LANES
        let target = key / (LANES * 4)
        let kind = (key / LANES) % 4
        assert kind == FIELD_CELL   // (cell fields only in the spike)
        let f = solve(target, INF, mc)
        spent += max(f.pops, 1)
        field_keys.push(key)
        field_vals.push(f)
        if field_keys.length > max(24, FIELD_CACHE * num_players):
            field_keys.remove(0)
            field_vals.remove(0)

// ------------------------------------------------------------------ spatial.gd

def spatial_build():
    let n = u_x.length
    let cells = W * H
    for(cells) c: sp_cursor[c] = 0
    for(n) i:
        let c = clamp(u_y[i] / TILE, 0, H - 1) * W + clamp(u_x[i] / TILE, 0, W - 1)
        sp_cell[i] = c
        sp_cursor[c]++
    var acc = 0
    for(cells) c:
        sp_start[c] = acc
        acc += sp_cursor[c]
        sp_end[c] = acc
        sp_cursor[c] = sp_start[c]
    for(n) i:
        let c = sp_cell[i]
        sp_items[sp_cursor[c]] = i
        sp_cursor[c]++

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

def slot_ok(i:int, apx:int, apy:int, x:int, y:int) -> int, int:
    let ln = lane(i)
    let cx, cy = snap(x, y, ln)
    var px = apx
    var py = apy
    for(2):
        var qx = clamp(px, 0, W * TILE - 1)
        var qy = clamp(py, 0, H * TILE - 1)
        if walkable(qx, qy, ln):
            qx, qy = off_walls(qx, qy, u_radius[i], ln)
            if clear_line(cx, cy, qx, qy, ln): return qx, qy
        px = (px + cx) / 2
        py = (py + cy) / 2
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
    var bands = [[]::int, []::int, []::int]
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
        for([fl.slice(0, nl), fl.slice(nl, -1)]) wing0:
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
    let wx, wy = plan(i, u_x[i], u_y[i], 0)
    u_wx[i] = if wx >= 0: wx else: u_x[i]
    u_wy[i] = if wx >= 0: wy else: u_y[i]

def order_move(i:int, x:int, y:int, arrive:int, group:int, fx:int, fy:int, pace:int):
    let ln = lane(i)
    let px, py = snap(x, y, ln)
    var cell = cell_of(px, py)
    if fx >= 0:
        let qx, qy = snap(fx, fy, ln)
        cell = cell_of(qx, qy)
    u_tx[i] = px
    u_ty[i] = py
    u_fkey[i] = (cell * 4 + FIELD_CELL) * LANES + ln
    u_arrive[i] = arrive
    u_group[i] = group
    u_pace[i] = pace
    start(i)

// A MOVE command (World._run: formation, then order_move for each of the player's units).
def run_move(player:int, ids:[int], x:int, y:int):
    let group, fx, fy, pace = formation(player, ids, x, y)
    for(ids) uid:
        let i = index_of(uid)
        if i >= 0 and u_owner[i] == player:
            order_move(i, slot_x[i], slot_y[i], SLOT_ARRIVE, group, fx, fy, pace)

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
            if u_group[i] == 0 or (tick + u_id[i]) % REPLAN_EVERY != 0: continue
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
        if (tick + u_id[i]) % PROGRESS_EVERY == 0:
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
        if d > u_radius[i]:
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
            elif dist2(xs[i], ys[i], txs[i], tys[i]) <= RETURN_YIELD * RETURN_YIELD:
                s_yields[i] = 1
        s_role[i] = if mv[i] == 0 and s_stood[i] == 0: 1 else: 0
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

// ------------------------------------------------------------------ the tick

class Cmd:
    run_tick:int
    player:int
    x:int
    y:int
    ids:[int]

var cmds = []::Cmd
var next_cmd = 0

def step():
    if tick % TICKS_PER_TURN == 0:
        while next_cmd < cmds.length and cmds[next_cmd].run_tick == tick:
            let c = cmds[next_cmd]
            run_move(c.player, c.ids, c.x, c.y)
            next_cmd++
    spatial_build()
    solve_queued()
    trace("start")
    move()
    trace("move")
    spatial_build()
    separate()
    trace("separate")
    tick++

var trace_tick = -1

// Every unit's position after the tick's moves and after separation (export.gd's trace:<tick>).
def trace(what:string):
    if tick != trace_tick: return
    for(u_x.length) i:
        print "{what} {u_id[i]} {u_x[i]} {u_y[i]} {u_wx[i]} {u_wy[i]} {u_moving[i]}"

def state_hash() -> int:
    var h = FNV_START
    h = mix(h, tick)
    h = mix(h, next_group)
    for(field_keys) k: h = mix(h, k)
    h = mix(h, -1)
    for(field_queue) k: h = mix(h, k)
    for(u_x.length) i:
        h = mix(h, u_id[i])
        h = mix(h, u_x[i])
        h = mix(h, u_y[i])
        h = mix(h, u_tx[i])
        h = mix(h, u_ty[i])
        h = mix(h, u_moving[i])
        h = mix(h, u_arrive[i])
        h = mix(h, u_wx[i])
        h = mix(h, u_wy[i])
        h = mix(h, u_group[i])
        h = mix(h, u_stuck[i])
        h = mix(h, u_prog[i])
        h = mix(h, u_fkey[i])
        h = mix(h, u_pace[i])
    return h

def dump_state() -> string:
    var s = "tick {tick} next_group {next_group} fields {field_keys} queue {field_queue}\n"
    for(u_x.length) i:
        s += "{u_id[i]} {u_x[i]} {u_y[i]} {u_tx[i]} {u_ty[i]} {u_moving[i]} {u_arrive[i]} {u_wx[i]} {u_wy[i]} {u_group[i]} {u_stuck[i]} {u_prog[i]} {u_fkey[i]} {u_pace[i]}\n"
    return s

// ------------------------------------------------------------------ main

def load(path:string):
    let text = assert read_file(path)
    tokens = tokenize(text, " \n", "")
    expect("AOWSPIKE")
    assert next_int() == 1
    expect("MAP")
    W = next_int()
    H = next_int()
    let lanes = next_int()
    for(lanes): walks.push(read_ints(W * H))
    expect("SPEED")
    let classes = next_int()
    for(classes): speed_pct.push(read_ints(W * H))
    expect("PLAYERS")
    num_players = next_int()
    lane_base = read_ints(num_players)
    expect("TYPES")
    let nt = next_int()
    for(nt):
        t_speed.push(next_int())
        t_radius.push(next_int())
        t_role.push(next_int())
        t_gap.push(next_int())
    expect("TICK")
    tick = next_int()
    next_int()   // next_id (no spawns in the spike)
    next_group = next_int()
    expect("UNITS")
    let n = next_int()
    for(n):
        u_id.push(next_int())
        u_owner.push(next_int())
        u_kind.push(next_int())
        u_x.push(next_int())
        u_y.push(next_int())
        u_tx.push(next_int())
        u_ty.push(next_int())
        u_moving.push(next_int())
        u_arrive.push(next_int())
        u_wx.push(next_int())
        u_wy.push(next_int())
        u_group.push(next_int())
        u_stuck.push(next_int())
        u_prog.push(next_int())
        u_fkey.push(next_int())
        u_speed.push(next_int())
        u_radius.push(next_int())
        u_mclass.push(next_int())
        u_pace.push(0)
    expect("CMDS")
    let nc = next_int()
    for(nc):
        let rt = next_int()
        let p = next_int()
        let x = next_int()
        let y = next_int()
        let ids = read_ints(next_int())
        cmds.push(Cmd { rt, p, x, y, ids })

def zeros(n:int) -> [int]: return map(n): 0

// Roomy and tight grids per lane (SimMap.roomy_grid): the walk grids never change here.
def make_room():
    room_cw = (W + ROOM_CHUNK - 1) / ROOM_CHUNK
    let ch = (H + ROOM_CHUNK - 1) / ROOM_CHUNK
    for(walks) g:
        let room = zeros(W * H)
        let tg = zeros(room_cw * ch)
        for(W * H) c:
            let cx = c % W
            let cy = c / W
            var ok = cx > 0 and cy > 0 and cx < W - 1 and cy < H - 1
            if ok:
                for(3) dy:
                    for(3) dx:
                        if g[(cy - 1 + dy) * W + cx - 1 + dx] == 0: ok = false
            room[c] = if ok: 1 else: 0
            if not ok: tg[(cy / ROOM_CHUNK) * room_cw + cx / ROOM_CHUNK]++
        roomy.push(room)
        tight.push(tg)

let args = command_line_arguments()
assert args.length >= 1
load(args[0])
let n = u_x.length
let cells = W * H
for(RING): ring.push([]::int)
sp_start = zeros(cells)
sp_end = zeros(cells)
sp_cursor = zeros(cells)
sp_items = zeros(n)
sp_cell = zeros(n)
o_x = zeros(n)
o_y = zeros(n)
o_moving = zeros(n)
o_stuck = zeros(n)
o_wx = zeros(n)
o_wy = zeros(n)
slot_x = zeros(n)
slot_y = zeros(n)
f_ahead = zeros(n)
f_side = zeros(n)
s_pushx = zeros(n)
s_pushy = zeros(n)
s_settle = zeros(n)
s_stood = zeros(n)
s_yields = zeros(n)
s_role = zeros(n)
make_room()

expect("HASHES")
let ticks = next_int()
let expected = read_ints(ticks)
var dump_tick = -1
if args.length >= 2:
    let v, ok = string_to_int(args[1])
    dump_tick = v
if args.length >= 3:
    let v, ok = string_to_int(args[2])
    trace_tick = v

var spent = 0.0
var first_bad = -1
for(ticks) k:
    let t0 = seconds_elapsed()
    step()
    spent += seconds_elapsed() - t0
    if first_bad < 0 and state_hash() != expected[k]:
        first_bad = k
    if tick == dump_tick:
        write_file(args[0] + ".lobster.dump", dump_state(), 0, 1)
print "{n} units, {ticks} ticks, {cmds.length} moves"
print "lobster step: {spent * 1000.0 / ticks} ms a tick"
if first_bad < 0:
    print "hashes: all {ticks} match"
else:
    print "hashes: first mismatch after tick {tick - ticks + first_bad} (index {first_bad})"
