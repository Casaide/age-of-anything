// ------------------------------------------------------------------ each culture's paths (scenes/art_pixel/paths.gd, sim_debug._refresh_paths)
// From a side's Town Center door to its other finished buildings and the nearest bug bushes and
// reeds, in its culture's style (families.json "paths": trail, boardwalk, cobble or road). A* on
// a half-tile grid avoiding blocked ground; cells already on a path are cheap, so routes merge
// into trunk roads; a route that reaches a path stops drawing there. Laid paths stay put (the
// memo); new buildings add branches. Smoothed, then painted into the terrain shader's path mask
// (a channel a style, blurred) and its distance-along texture (boards laid across the walk).

let PATH_STYLES = ["trail", "boardwalk", "cobble", "road"]
let PATH_SUB = 2
let PATH_REACH = 10.0
let PATH_FINE = 16

class PathOwner:
    style:string
    width:float
    hub:float2
    targets:[float2]

class PathLaid:
    style:string
    width:float
    points:[float2]

var path_used = []::int
let path_done = dictionary<string, int>(64)
var path_out = []::PathLaid
let path_anchor_hub = dictionary<int, float2>(8)
let path_anchor_res = dictionary<int, [float2]>(8)
var path_count = -1                 // finished buildings when last planned
var path_bytes = []::int            // the path mask (RGBA, MASK_K a tile), for the scatter's on_path

def ground_blocked(t:float2) -> bool:
    if t.x < 0.2 or t.y < 0.2 or t.x > float(W) - 0.2 or t.y > float(H) - 0.2: return true
    if walks[0][int(t.y) * W + int(t.x)] == 0: return true
    return mask_at(t).x > 0.3

def on_path(t:float2) -> bool:
    if not path_bytes.length: return false
    let w = W * MASK_K
    let x = clamp(int(t.x * float(MASK_K)), 0, w - 1)
    let y = clamp(int(t.y * float(MASK_K)), 0, H * MASK_K - 1)
    let o = (y * w + x) * 4
    return max(max(path_bytes[o], path_bytes[o + 1]), max(path_bytes[o + 2], path_bytes[o + 3])) > 64   // (> 0.25)

def door_of(b:int) -> float2: return float2 { float(b_cx[b]) + float(b_sx[b]) * 0.5, float(b_cy[b] + b_sy[b]) + 0.45 }

def nearest_resource_edge(kind:int, hub:float2) -> float2:
    var best = float2 { -1.0, -1.0 }
    var best_d = PATH_REACH
    for(resource_cells) c:
        if amount[c] > 0 and tr_res[terrain[c]] == kind:
            let x = c % W
            let y = c / W
            if vlen(float2 { float(x), float(y) } - hub) <= best_d + 2.0:
                for([int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }]) d:
                    let t = float2 { float(x + d.x) + 0.5, float(y + d.y) + 0.5 }
                    if not ground_blocked(t) and vlen(t - hub) < best_d:
                        best_d = vlen(t - hub)
                        best = t
    return best

def path_cell(gw:int, gh:int, t:float2) -> int:
    return clamp(int(t.y * float(PATH_SUB)), 0, gh - 1) * gw + clamp(int(t.x * float(PATH_SUB)), 0, gw - 1)

def path_heur(gw:int, a:int, b:int) -> float:
    let dx = float(a % gw - b % gw)
    let dy = float(a / gw - b / gw)
    return sqrt(dx * dx + dy * dy)

// A* (paths.gd _route): the open list ordered by (cost + heuristic, cell), as its sort does.
def path_route(gw:int, gh:int, src:float2, dst:float2) -> [int]:
    let start = path_cell(gw, gh, src)
    let goal = path_cell(gw, gh, dst)
    let dist = dictionary<int, float>(1024)
    let prev = dictionary<int, int>(1024)
    dist.set(start, 0.0)
    let heap_f = [path_heur(gw, start, goal)]
    let heap_c = [start]
    let dirs = [int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }, int2 { 1, 1 }, int2 { 1, -1 }, int2 { -1, 1 }, int2 { -1, -1 }]
    var seen = 0
    var reached = false
    while heap_c.length and seen < 20000:
        var bi = 0
        for(heap_c) c, i:   // (the smallest (f, cell): what sorting the open list and taking its front gives)
            if heap_f[i] < heap_f[bi] or (heap_f[i] == heap_f[bi] and c < heap_c[bi]): bi = i
        let cur = heap_c[bi]
        heap_c.remove(bi)
        heap_f.remove(bi)
        seen++
        if cur == goal:
            reached = true
            break
        let cx = cur % gw
        let cy = cur / gw
        for(dirs) d:
            let nx = cx + d.x
            let ny = cy + d.y
            if nx >= 0 and ny >= 0 and nx < gw and ny < gh:
                let nc = ny * gw + nx
                let p = float2 { float(nx) + 0.5, float(ny) + 0.5 } / float(PATH_SUB)
                if nc == goal or not ground_blocked(p):
                    let step = if d.x != 0 and d.y != 0: 1.414 else: 1.0
                    let nd = dist.get(cur, 0.0) + step * (if path_used[nc] != 0: 0.35 else: 1.0)
                    let had = dist.get(nc, -1.0)
                    if had < 0.0 or nd < had:
                        dist.set(nc, nd)
                        prev.set(nc, cur)
                        heap_f.push(nd + path_heur(gw, nc, goal))
                        heap_c.push(nc)
    if prev.get(goal, -1) < 0: return []
    let back = [goal]
    var c = goal
    while prev.get(c, -1) >= 0:
        c = prev.get(c, -1)
        back.push(c)
    return map(back.length) i: back[back.length - 1 - i]

def path_smooth(pts:[float2]) -> [float2]:
    if pts.length < 3: return pts
    let out = [pts[0]]
    for(pts.length - 1) i:
        out.push(pts[i] + (pts[i + 1] - pts[i]) * 0.25)
        out.push(pts[i] + (pts[i + 1] - pts[i]) * 0.75)
    out.push(pts[pts.length - 1])
    return out

def path_emit(o:PathOwner, run:[int], gw:int):
    if run.length < 2: return
    let pts = map(run) c: (float2 { float(c % gw), float(c / gw) } + float2 { 0.5, 0.5 }) / float(PATH_SUB)
    path_out.push(PathLaid { o.style, o.width, path_smooth(path_smooth(pts)) })

def path_plan(owners:[PathOwner]):
    let gw = W * PATH_SUB
    let gh = H * PATH_SUB
    if not path_used.length: path_used = map(gw * gh): 0
    for(owners) o:
        let mine = str_index(PATH_STYLES, o.style) + 1
        for(o.targets) target:
            if vlen(o.hub - target) <= PATH_REACH:
                let key = "{mine}|{o.hub}|{target}"
                if not path_done.get(key, 0):
                    path_done.set(key, 1)
                    let cells = path_route(gw, gh, o.hub, target)
                    var run = []::int
                    for(cells) c:
                        if path_used[c] != 0:
                            if run.length:
                                run.push(c)
                                path_emit(o, run, gw)
                            run = []
                        else: run.push(c)
                    path_emit(o, run, gw)
                    for(cells) c:
                        if path_used[c] == 0: path_used[c] = mine

def closest_on_segment(q:float2, a:float2, b:float2) -> float2:
    let ab = b - a
    let l2 = vdot(ab, ab)
    if l2 == 0.0: return a
    return a + ab * clamp(vdot(q - a, ab) / l2, 0.0, 1.0)

// Paths.mask, then the blur (two passes) TerrainView gives it: the textures the terrain shader reads.
def paint_paths():
    let w = W * MASK_K
    let h = H * MASK_K
    let a = map(w * h * 4): 0.0
    let fw = W * PATH_FINE
    let fh = H * PATH_FINE
    let best = map(fw * fh): 1000000.0
    let arc = map(fw * fh): 0.0
    for(path_out) p:
        let ch = str_index(PATH_STYLES, p.style)
        let pts = p.points
        let r = p.width
        var along = 0.0
        var i = 1
        while i < pts.length:
            let pa = pts[i - 1]
            let pb = pts[i]
            let lo = float2 { min(pa.x, pb.x), min(pa.y, pb.y) } - float2_1 * (r + 0.3)
            let hi = float2 { max(pa.x, pb.x), max(pa.y, pb.y) } + float2_1 * (r + 0.3)
            var y = max(int(lo.y * float(MASK_K)), 0)
            while y < min(int(hi.y * float(MASK_K)) + 1, h):
                var x = max(int(lo.x * float(MASK_K)), 0)
                while x < min(int(hi.x * float(MASK_K)) + 1, w):
                    let q = (float2 { float(x), float(y) } + float2 { 0.5, 0.5 }) / float(MASK_K)
                    if vlen(closest_on_segment(q, pa, pb) - q) < r: a[(y * w + x) * 4 + ch] = 1.0
                    x++
                y++
            y = max(int(lo.y * float(PATH_FINE)), 0)
            while y < min(int(hi.y * float(PATH_FINE)) + 1, fh):
                var x = max(int(lo.x * float(PATH_FINE)), 0)
                while x < min(int(hi.x * float(PATH_FINE)) + 1, fw):
                    let q = (float2 { float(x), float(y) } + float2 { 0.5, 0.5 }) / float(PATH_FINE)
                    let on = closest_on_segment(q, pa, pb)
                    let d = vlen(on - q)
                    let idx = y * fw + x
                    if d < r + 0.3 and d < best[idx]:
                        best[idx] = d
                        arc[idx] = along + vlen(on - pa)
                    x++
                y++
            along += vlen(pb - pa)
            i++
    let b = map(w * h * 4): 0.0
    for(2):
        for(h) y:
            for(w) x:
                let x0 = max(x - 1, 0)
                let x1 = min(x + 1, w - 1)
                for(4) c: b[(y * w + x) * 4 + c] = (a[(y * w + x0) * 4 + c] + a[(y * w + x) * 4 + c] + a[(y * w + x1) * 4 + c]) / 3.0
        for(h) y:
            let y0 = max(y - 1, 0)
            let y1 = min(y + 1, h - 1)
            for(w) x:
                for(4) c: a[(y * w + x) * 4 + c] = (b[(y0 * w + x) * 4 + c] + b[(y * w + x) * 4 + c] + b[(y1 * w + x) * 4 + c]) / 3.0
    path_bytes = map(w * h * 4) k: clamp(int(a[k] * 255.0 + 0.5), 0, 255)
    paths_tex = gl.create_texture(map(h) y: map(w) x: float4 { path_bytes[(y * w + x) * 4] / 255.0, path_bytes[(y * w + x) * 4 + 1] / 255.0,
                                                               path_bytes[(y * w + x) * 4 + 2] / 255.0, path_bytes[(y * w + x) * 4 + 3] / 255.0 },
                                  texture_format_clamp | texture_format_nomipmap)
    arc_tex = gl.create_texture(map(fh) y: map(fw) x: float4 { arc[y * fw + x], 0.0, 0.0, 0.0 },
                                texture_format_clamp | texture_format_nomipmap | texture_format_float)
