// ------------------------------------------------------------------ the map changing (sim_map.gd)
// Terrain, what's left of each resource, building cells, and _refresh: a cell's walk grids, the
// roomy grids and sight blockers follow its terrain and what stands on it, and the change is
// recorded (fresh) for World._sync_map to patch the cached flow fields. One lane group only (no
// gates in the spike), no bridges' decks changing, no walls.

var terrain = []::int
var amount = []::int          // resource left (a pooled cell's is on its anchor)
var pool = []::int            // a farm's cells: the anchor cell holding the shared amount, or -1
var occupied = []::int        // building id standing on the cell, or 0
var walk_over = []::int       // 1 where a building may be walked across (farms)
var cliff = []::int
var ramp = []::int
var deck = []::int
var high = []::int            // 1 under a building flyers can't cross
var resource_cells = []::int  // every cell that started with a resource, ascending (and farms' anchors)

// Terrain tables, by terrain index.
var tr_walk = []::int
var tr_move = []::int         // bitmask of the movement classes that cross it
var tr_res = []::int          // resource kind (index + 1), or 0
var tr_amount = []::int
var tr_depleted = []::int     // what it turns into when used up, or -1
var tr_reseed = []::int
var tr_cleared = []::int
var tr_opaque = []::int

// Cells changed this tick, each with its walk value per lane before the tick's first change.
var fresh = []::int
var fresh_was = []::[int]
var fresh_at = []::int        // per cell: its index in fresh + 1, or 0

let FLYING = 2
let PATCH_BUDGET = 3000

def anchor(cell:int) -> int: return if pool[cell] >= 0: pool[cell] else: cell

// The resource kind at a cell (index + 1), or 0 for a cell that has (or had) none left.
def res_at(cell:int) -> int:
    if amount[anchor(cell)] <= 0: return 0
    return tr_res[terrain[cell]]

def left_at(cell:int) -> int: return amount[anchor(cell)]

// Every cell pooled on this anchor, ascending.
def pool_cells(a:int) -> [int]:
    let out = []::int
    for(pool) p, c:
        if p == a: out.push(c)
    return out

// Take one unit of resource. When the last one goes, the tile turns into its depleted terrain.
def take(cell:int):
    let a = anchor(cell)
    assert amount[a] > 0
    amount[a]--
    if amount[a] > 0: return
    let cells = if pool[cell] < 0: [cell] else: pool_cells(a)
    for(cells) c:
        let dep = tr_depleted[terrain[c]]
        if dep >= 0: terrain[c] = dep
        refresh(c)

// Pool some cells into one resource (a farm), held on the first cell.
def make_pool(cells:[int], k:int, total:int):
    let a = cells[0]
    for(cells) c:
        terrain[c] = k
        amount[c] = 0
        pool[c] = a
        walk_over[c] = 1
        refresh(c)
    amount[a] = total
    let found, at = binary_search(resource_cells, a)
    if not found: resource_cells.insert(at, a)

// Mark a building's footprint (id) or clear it (0).
def occupy(cells:[int], building_id:int):
    for(cells) c:
        occupied[c] = building_id
        high[c] = 0
        refresh(c)

// Can a building of this size go here (SimMap.can_build)?
def can_build(cx:int, cy:int, size:int, mc:int, water_ok:bool, slope_ok:bool) -> bool:
    var y = cy
    while y < cy + size:
        var x = cx
        while x < cx + size:
            if x < 0 or y < 0 or x >= W or y >= H: return false
            let c = y * W + x
            if occupied[c] != 0 or amount[c] > 0 or deck[c] == 1: return false
            if ((cliff[c] == 1 or ramp[c] == 1) and not slope_ok) or level[c] != level[cy * W + cx]: return false
            let t = terrain[c]
            if not tr_walk[t] and not (water_ok and mc != FLYING and (tr_move[t] & (1 << mc)) != 0): return false
            x++
        y++
    return true

def roomy_cell(k:int, c:int):
    let g = walks[k]
    let cx = c % W
    let cy = c / W
    var ok = cx > 0 and cy > 0 and cx < W - 1 and cy < H - 1
    if ok:
        for(3) dy:
            for(3) dx:
                if g[(cy - 1 + dy) * W + cx - 1 + dx] == 0: ok = false
    let v = if ok: 1 else: 0
    let was = roomy[k][c]
    if was == v: return
    roomy[k][c] = v
    let b = (cy / ROOM_CHUNK) * room_cw + cx / ROOM_CHUNK
    if v == 0: tight[k][b]++
    elif was == 0: tight[k][b]--

def roomy_round(k:int, cell:int):
    let cx = cell % W
    let cy = cell / W
    var y = max(cy - 1, 0)
    while y < min(cy + 2, H):
        var x = max(cx - 1, 0)
        while x < min(cx + 2, W):
            roomy_cell(k, y * W + x)
            x++
        y++

// A cell's terrain or what stands on it changed (SimMap._refresh).
def refresh(cell:int):
    let was = map(walks) g: g[cell]
    if not fresh_at[cell]:
        fresh.push(cell)
        fresh_was.push(was)
        fresh_at[cell] = fresh.length
    let clear = (occupied[cell] == 0 or walk_over[cell] == 1) and cliff[cell] == 0
    let ground = tr_walk[terrain[cell]] or deck[cell] == 1
    let mask = tr_move[terrain[cell]] | (if deck[cell] == 1: 7 else: 0)
    let op = tr_opaque[terrain[cell]]
    if op != opaque[cell]:
        opaque_chunks[(cell / W / CHUNK) * chunk_w + (cell % W) / CHUNK] += op - opaque[cell]
        opaque[cell] = op
        sight_cache_version++
    for(walks.length) k:
        walks[k][cell] = if (mask & (1 << k)) != 0 and ((k == FLYING and high[cell] == 0) or clear): 1 else: 0
    walks[0][cell] = if ground and clear: 1 else: 0
    for(roomy.length) k:
        if was[k] != walks[k][cell]: roomy_round(k, cell)
    map_version++

def clear_fresh():
    for(fresh) c: fresh_at[c] = 0
    fresh.remove_range(0, fresh.length)
    fresh_was.remove_range(0, fresh_was.length)

// The map changed this tick: patch the cached fields the change touches, newest first while the
// tick's patch budget lasts; past it, or where a source cell itself changed, the field is dropped
// (World._sync_map).
def sync_map():
    if not fresh.length: return
    let order = []::int
    for(fresh) c, n: order.push(c * (1 << 20) + n)   // the cells ascending (with where their old values are)
    sort_ints(order)
    let lanes = walks.length
    let opened = map(lanes): []::int
    let closed = map(lanes): []::int
    for(order) o:
        let c = o >> 20
        let was = fresh_was[o & ((1 << 20) - 1)]
        for(min(was.length, lanes)) k:
            let now = walks[k][c]
            if now != was[k]:
                if now == 1: opened[k].push(c)
                else: closed[k].push(c)
    var budget = PATCH_BUDGET
    let keep_keys = []::int
    let keep_vals = []::Flow
    var n = field_keys.length - 1
    while n >= 0:
        let key = field_keys[n]
        let f = field_vals[n]
        n--
        let ln = key % LANES
        let op = []::int
        let cl = []::int
        var stale = false
        if ln < lanes:
            for(opened[ln]) c:
                if touches(f, c):
                    stale = stale or contains(f.sources, c)
                    op.push(c)
            for(closed[ln]) c:
                if touches(f, c):
                    stale = stale or contains(f.sources, c)
                    cl.push(c)
        if not stale and not (not op.length and not cl.length):
            var limit = min(budget, W * H / 4)
            stale = limit <= 0
            if not stale and cl.length:
                let spent = patch_closed(f, cl, ln, limit)
                stale = spent < 0
                budget -= if stale: limit else: spent
                limit = min(budget, limit - max(spent, 0))
            if not stale and op.length:
                stale = limit <= 0
                if not stale:
                    let spent = patch_opened(f, op, ln, limit)
                    stale = spent < 0
                    budget -= if stale: limit else: spent
        if not stale:
            keep_keys.push(key)
            keep_vals.push(f)
    field_keys = reverse_list(keep_keys)
    field_vals = reverse_list(keep_vals)
    clear_fresh()
