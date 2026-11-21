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

// A building laid before it's unlocked (its prerequisite not yet built, buildings.json "after") waits here, and is laid
// once it can be: the scripted towns lay their plan in order, as a player does (#124).
class LayLater:
    id:string
    x:int
    y:int
    cell:int  // (sent: the cell its order laid it at, and the tick)
    at:int

var lay_later = []::LayLater
var lay_sent = []::LayLater  // laid by an order not yet seen through: if the ground was taken meanwhile, it's laid again

// Whether an s-square at (cx, cy) would overlap one laid by an order still on its way (two laid in a tick took one place).
def sent_near(cx:int, cy:int, s:int) -> bool:
    for(lay_sent) l:
        let ls = bt_size[btype_index(l.id)]
        if cx < l.cell % W + ls and l.cell % W < cx + s and cy < l.cell / W + ls and l.cell / W < cy + s: return true
    return false

// Lay building `id` for player 0 near (x, y) in tiles, with a road to its door: the first place, spiralling out, where
// it fits and its door can be reached (road_to_door), then the building.
def lay_with_road(id:string, x:int, y:int) -> bool:
    let k = btype_index(id)
    assert k >= 0
    if bt_drag[k] != 0:  // (a field: just there, no door and no road, creel #123)
        if not can_place(0, k, x, y, 0): return false
        issue_cmd(0, CMD_BUILD, []::int, k, x, y, 0, 0)
        return true
    let s = bt_size[k]
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let cx = x + ex - d
                let cy = y + ey - d
                if max(abs(ex - d), abs(ey - d)) == d and cx >= 0 and cy >= 0 and cx + s <= W and cy + s < H and open_square(cx, cy, s):
                    if road_to_door(k, cx, cy) and can_place(0, k, cx, cy, 0) and not sent_near(cx, cy, s):
                        issue_cmd(0, CMD_BUILD, []::int, k, cx, cy, 0)
                        lay_sent.push(LayLater { id, x, y, cy * W + cx, tick })
                        return true
    return false

// Lay a w by h block of field plans (`id`: wheat_field, vine_field) at (x, y), now or once they're unlocked (their farm
// built, #122). How many were laid or wait.
def lay_fields(id:string, x:int, y:int, w:int, h:int) -> int:
    var n = 0
    for(h) j:
        for(w) i:
            if lay_or_wait(id, x + i, y + j): n++
    return n

// The cells of the nearest open w by h block for field plans of type `id` round building b, within its reach, as a player
// picks one (#122); empty if there's none.
def field_block(b:int, id:string, w:int, h:int) -> [int]:
    let fk = btype_index(id)
    for(13) dy:
        for(13) dx:
            let x0 = b_cx[b] - 6 + dx
            let y0 = b_cy[b] - 6 + dy
            if w > 0 and abs(x0 + w / 2 - b_cx[b]) <= 5 and abs(y0 + h / 2 - b_cy[b]) <= 5 and x0 >= 3 and y0 >= 3 and x0 + w + 3 <= W and y0 + h + 3 <= H:
                let block = []::int
                for(h) j:
                    for(w) i:
                        if can_place(0, fk, x0 + i, y0 + j, 0): block.push((y0 + j) * W + x0 + i)
                if block.length == w * h: return block
    return []

var auto_fields = false  // the scripted towns: each farm and vineyard gets its fields once it's built (a player lays them)
var fielded = []::int    // the ids of those that have

// A scripted town lays its farms' and vineyards' fields itself (on), or leaves them to the player; either way afresh.
def fields_by_script(on:bool):
    auto_fields = on
    fielded = []

let AUTO_FIELD_OF = [ "farm", "vineyard" ]  // and the fields each gets: their type and size
let AUTO_FIELD_TYPE = [ "wheat_field", "vine_field" ]
let AUTO_FIELD_SIZE = [ [ 4, 3 ], [ 3, 2 ] ]

def lay_auto_fields():
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and not contains(fielded, b_id[b]):
            let a = find(AUTO_FIELD_OF) id: id == bt_name[b_kind[b]]
            if a >= 0:
                fielded.push(b_id[b])
                let wh = AUTO_FIELD_SIZE[a]
                let cells = field_block(b, AUTO_FIELD_TYPE[a], wh[0], wh[1])
                if cells.length: lay_fields(AUTO_FIELD_TYPE[a], cells[0] % W, cells[0] / W, wh[0], wh[1])

// Lay `id` near (x, y) now, or once it's unlocked. False only if it was open and found no room.
def lay_or_wait(id:string, x:int, y:int) -> bool:
    if build_barred(0, btype_index(id)):
        lay_later.push(LayLater { id, x, y, -1, 0 })
        return true
    return lay_with_road(id, x, y)

// Once a second: lay what's waiting and now unlocked, in the order it was asked for.
def lay_waiting():
    if tick % TICK_HZ != 0: return
    if auto_fields: lay_auto_fields()
    // (an order runs a few ticks after it's sent: one whose ground was taken by then, by a road or a field, is laid again)
    let sent = lay_sent
    lay_sent = []
    for(sent) l:
        if tick < l.at + TICK_HZ: lay_sent.push(l)
        else:
            let b = b_index_of(occupied[l.cell])
            if (b < 0 or b_kind[b] != btype_index(l.id)) and not lay_with_road(l.id, l.x, l.y): print "steading: no room for {l.id} near {l.x},{l.y} with a road to its door"
    let still = []::LayLater
    for(lay_later) l:
        if build_barred(0, btype_index(l.id)): still.push(l)
        elif not lay_with_road(l.id, l.x, l.y): print "steading: no room for {l.id} near {l.x},{l.y} with a road to its door"
    lay_later = still

// A tick of the world, with the waiting buildings laid first.
def lay_step():
    lay_waiting()
    wstep()
