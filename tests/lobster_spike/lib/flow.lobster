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

