// ------------------------------------------------------------------ laying roads (#68)
// A road plan (a building type with "road": the road kind it lays, built over and then gone: lib/economy) is laid by
// dragging, as a wall is: press at one end, release at the other, a plan a cell (shift: keep placing). Laid roads and the
// plans are painted into the ground's path mask (game/paths): a road in its kind's style (rules economy.roads[].style,
// else "road"), a plan as a faint trail. Plans have no baked look (game/art_kit_buildings).
// A field (a type with "drag" that "becomes" a terrain, creel #123) is dragged the same way.

let ROAD_WIDTH = 0.42  // a road's half width in tiles, painted (a tile's road joins its neighbours')
let PLAN_WIDTH = 0.16  // and a plan's

var road_from = int2 { -1, -1 }  // where the drag began, -1 when none
var road_painted = []::int       // per cell: what's painted there (0 nothing, 1 a plan, 2 a road)

def is_road_plan(k:int) -> bool: return k >= 0 and k < bt_road.length and bt_road[k] >= 0

def is_dragged(k:int) -> bool: return k >= 0 and k < bt_drag.length and bt_drag[k] != 0  // (a road plan, or a field: creel #123)

// The mouse while a road plan is picked: true when it took the mouse (else Creel's mouse() has it).
def road_mouse() -> bool:
    if placing < 0 or not is_dragged(placing) or touch_play:
        road_from = int2 { -1, -1 }
        return false
    if gl.button("mouse1") == 1: road_from = place_cell()
    elif gl.button("mouse1") == 0 and road_from.x >= 0:
        place_wall(road_from, place_cell(), gl.button("left shift") >= 1)  // (a plan a cell, in order; placing ends unless shift)
        road_from = int2 { -1, -1 }
    if gl.button("mouse3") == 1 or gl.button("escape") == 1:
        placing = -1
        road_from = int2 { -1, -1 }
    return true

// The line being dragged, a diamond a cell: green where a plan can go. In draw_town (the world at 1.5).
def draw_road_drag():
    if placing < 0 or not is_dragged(placing) or road_from.x < 0: return
    gl.set_shader("color")
    for(wall_cells(road_from, place_cell())) g:
        let ok = view_can_place(ME, placing, g.x, g.y)
        let pts = map([ int2 { 0, 0 }, int2 { 1, 0 }, int2 { 1, 1 }, int2 { 0, 1 } ]) d: iso(float((g.x + d.x) * 1000), float((g.y + d.y) * 1000)) / 1.5
        gl.color(if ok: float4 { 0.3, 0.9, 0.3, 0.35 } else: float4 { 0.9, 0.2, 0.2, 0.35 }):
            gl.polygon(pts)

def road_style(kind:int) -> string:
    let roads = glist(rules_part("economy"), "roads")
    let st = if kind < roads.length: gstr(roads[kind], "style", "road") else: "road"
    return if str_index(PATH_STYLES, st) >= 0: st else: "road"

// What is on cell c now, as road_painted counts it.
def road_here(c:int, plans:[int]) -> int: return if road.length and road[c] > 0: 2 elif plans[c] != 0: 1 else: 0

// The roads and plans seen since the last call, added to the paths (game/paths' path_out): a cell's centre joined to
// each neighbour's with as much, or a dot alone. True if any were added. A cell keeps the most it has shown.
def road_paths() -> bool:
    if not rd_names.length: return false
    if road_painted.length != W * H: road_painted = map(W * H): 0
    let plans = map(W * H): 0
    for(b_id.length) b:
        if is_road_plan(b_kind[b]) and b_done[b] == 0: plans[b_cy[b] * W + b_cx[b]] = 1
    var added = false
    for(W * H) c:
        let now = road_here(c, plans)
        if now > road_painted[c] and fog[ME][c] != 0:
            road_painted[c] = now
            added = true
            let style = if now == 2: road_style(road[c] - 1) else: "trail"
            let width = if now == 2: ROAD_WIDTH else: PLAN_WIDTH
            let mid = float2 { float(c % W) + 0.5, float(c / W) + 0.5 }
            path_out.push(PathLaid { style, width, [ mid - float2 { 0.01, 0.0 }, mid + float2 { 0.01, 0.0 } ] })
            for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }, int2 { 1, 1 }, int2 { 1, -1 }, int2 { -1, 1 }, int2 { -1, -1 } ]) d:
                let x = c % W + d.x
                let y = c / W + d.y
                if x >= 0 and y >= 0 and x < W and y < H and road_here(y * W + x, plans) >= now:
                    path_out.push(PathLaid { style, width, [ mid, mid + float2 { float(d.x), float(d.y) } ] })
    return added
