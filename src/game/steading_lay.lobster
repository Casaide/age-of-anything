// Laying a Steading building as a player does with doors_on_roads on (#119): a road plan from the tile in front of its
// door to the nearest road or road plan (or the town centre's door, for the first), then the building. For the
// scripted towns: steading_town.lobster and test_steading.lobster.

// Whether cell c is road, or a road plan of player 0's.
def is_road_at(c:int) -> bool:
    if road.length and road[c] > 0: return true
    let b = b_index_of(occupied[c])
    return b >= 0 and b_owner[b] == 0 and bt_road[b_kind[b]] >= 0

// The tile in front of building b's door (below its bottom edge's middle, as the mod's economy.lua has it).
def door_of(b:int) -> int: return (b_cy[b] + b_sy[b]) * W + b_cx[b] + b_sx[b] / 2

// The cells a road needs from cell `start` to the nearest road or plan, or to `home`: a breadth-first search over the
// cells a road could go on, never through the s by s square at (sqx, sqy) (the building to come). From `start` on; empty
// if there's no way.
def road_path(start:int, home:int, sqx:int, sqy:int, s:int) -> [int]:
    let rk = btype_index("road")
    let prev = map(W * H) c: -1
    prev[start] = start
    let q = [ start ]
    var qi = 0
    while qi < q.length:
        let c = q[qi]
        qi++
        if c != start and (is_road_at(c) or c == home):
            let path = []::int
            var p = if is_road_at(c): prev[c] else: c
            while p != start:
                path.push(p)
                p = prev[p]
            path.push(start)
            return path
        let x = c % W
        let y = c / W
        for([ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ]) o:
            let nx = x + o[0]
            let ny = y + o[1]
            if nx >= 0 and ny >= 0 and nx < W and ny < H and not (nx >= sqx and nx < sqx + s and ny >= sqy and ny < sqy + s):
                let n = ny * W + nx
                if prev[n] < 0 and (is_road_at(n) or can_place(0, rk, nx, ny, 0)):
                    prev[n] = c
                    q.push(n)
    return []

// Whether the s by s square at (sqx, sqy) is open ground: a road plan could go on each of its cells.
def open_square(sqx:int, sqy:int, s:int) -> bool:
    let rk = btype_index("road")
    for(s) j:
        for(s) i:
            if is_road_at((sqy + j) * W + sqx + i) or not can_place(0, rk, sqx + i, sqy + j, 0): return false
    return true

// Lay road plans from the tile in front of the door of a building of type k at (cx, cy) to the nearest road or plan (from
// the town's end, as the road tool drags), and wait till they're in. Whether its door is on one now.
def road_to_door(k:int, cx:int, cy:int) -> bool:
    let rk = btype_index("road")
    let s = bt_size[k]
    let door = (cy + s) * W + cx + s / 2
    if cy + s >= H: return false
    let path = if is_road_at(door): []::int else: road_path(door, door_of(0), cx, cy, s)  // (building 0: the town centre)
    for(path.length) j:
        let c = path[path.length - 1 - j]
        issue_cmd(0, CMD_BUILD, []::int, rk, c % W, c / W, 0, if j > 0: 1 else: 0)
    for(20):  // (a command lands a few ticks after it's issued)
        if not is_road_at(door): wstep()
    return is_road_at(door)

// Lay building `id` for player 0 near (x, y) in tiles, with a road to its door: the first place, spiralling out, where
// it fits and its door can be reached (road_to_door), then the building.
def lay_with_road(id:string, x:int, y:int) -> bool:
    let k = btype_index(id)
    assert k >= 0
    let s = bt_size[k]
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let cx = x + ex - d
                let cy = y + ey - d
                if max(abs(ex - d), abs(ey - d)) == d and cx >= 0 and cy >= 0 and cx + s <= W and cy + s < H and open_square(cx, cy, s):
                    if road_to_door(k, cx, cy) and can_place(0, k, cx, cy, 0):
                        issue_cmd(0, CMD_BUILD, []::int, k, cx, cy, 0)
                        return true
    return false

// A building laid before it's unlocked (its prerequisite not yet built, buildings.json "after") waits here, and is laid
// once it can be: the scripted towns lay their plan in order, as a player does (#124).
class LayLater:
    id:string
    x:int
    y:int

var lay_later = []::LayLater

// Lay `id` near (x, y) now, or once it's unlocked. False only if it was open and found no room.
def lay_or_wait(id:string, x:int, y:int) -> bool:
    if build_barred(0, btype_index(id)):
        lay_later.push(LayLater { id, x, y })
        return true
    return lay_with_road(id, x, y)

// Once a second: lay what's waiting and now unlocked, in the order it was asked for.
def lay_waiting():
    if tick % TICK_HZ != 0: return
    let still = []::LayLater
    for(lay_later) l:
        if build_barred(0, btype_index(l.id)): still.push(l)
        elif not lay_with_road(l.id, l.x, l.y): print "steading: no room for {l.id} near {l.x},{l.y} with a road to its door"
    lay_later = still

// A tick of the world, with the waiting buildings laid first.
def lay_step():
    lay_waiting()
    wstep()
