// ------------------------------------------------------------------ each culture's paths (scenes/art_pixel/paths.gd, sim_debug._refresh_paths)
// From a side's Town Center door to its other finished buildings and the nearest bug bushes and
// reeds, in its culture's style (families.json "paths": trail, boardwalk, cobble or road). A* on
// a half-tile grid avoiding blocked ground; cells already on a path are cheap, so routes merge
// into trunk roads; a route that reaches a path stops drawing there. Laid paths stay put (the
// memo); new buildings add branches. Smoothed, then painted into the terrain shader's path mask
// (a channel a style, blurred) and its distance-along texture (boards laid across the walk).

let PATH_STYLES = [ "trail", "boardwalk", "cobble", "road" ]
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
var path_count = -1       // finished buildings when last planned
var path_bytes = []::int  // the path mask (RGBA, MASK_K a tile), for the scatter's on_path

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
    return max(max(path_bytes[o], path_bytes[o + 1]), max(path_bytes[o + 2], path_bytes[o + 3])) > 64  // (> 0.25)

def door_of(b:int) -> float2: return float2 { float(b_cx[b]) + float(b_sx[b]) * 0.5, float(b_cy[b] + b_sy[b]) + 0.45 }

def nearest_resource_edge(kind:int, hub:float2) -> float2:
    var best = float2 { -1.0, -1.0 }
    var best_d = PATH_REACH
    for(resource_cells) c:
        if amount[c] > 0 and tr_res[terrain[c]] == kind:
            let x = c % W
            let y = c / W
            if vlen(float2 { float(x), float(y) } - hub) <= best_d + 2.0:
                for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 } ]) d:
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
    let heap_f = [ path_heur(gw, start, goal) ]
    let heap_c = [ start ]
    let dirs = [ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }, int2 { 1, 1 }, int2 { 1, -1 }, int2 { -1, 1 }, int2 { -1, -1 } ]
    var seen = 0
    var reached = false
    while heap_c.length and seen < 20000:
        var bi = 0
        for(heap_c) c, i:  // (the smallest (f, cell): what sorting the open list and taking its front gives)
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
    let back = [ goal ]
    var c = goal
    while prev.get(c, -1) >= 0:
        c = prev.get(c, -1)
        back.push(c)
    return map(back.length) i: back[back.length - 1 - i]

def path_smooth(pts:[float2]) -> [float2]:
    if pts.length < 3: return pts
    let out = [ pts[0] ]
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

// What paint_paths keeps between calls (#335): a building finished paints only the paths laid since, not the map again.
var path_painted = 0      // path_out's paths painted so far
var path_raw = []::float  // the path mask before the blur (RGBA, MASK_K a tile)
var path_h1 = []::float   // the blur's passes, kept to blur a part of the map
var path_v1 = []::float
var path_h2 = []::float
var path_best = []::float  // per fine cell: the nearest path's distance, and its distance along (arc_tex)
var path_arc = []::float

// Grows the rectangle lo..hi (inclusive) to take in x0..x1, y0..y1 (exclusive ends), when that isn't empty.
def path_grow(lo:int2, hi:int2, x0:int, x1:int, y0:int, y1:int) -> int2, int2:
    if x1 <= x0 or y1 <= y0: return lo, hi
    return min(lo, int2 { x0, y0 }), max(hi, int2 { x1 - 1, y1 - 1 })

// One pass of the blur over x0..x1, y0..y1 (inclusive): the mean of a cell and its neighbours along x (dy 0) or y.
def path_blur(src:[float], dst:[float], w:int, h:int, along_y:bool, x0:int, x1:int, y0:int, y1:int):
    var y = max(y0, 0)
    while y <= min(y1, h - 1):
        var x = max(x0, 0)
        while x <= min(x1, w - 1):
            let a = if along_y: max(y - 1, 0) * w + x else: y * w + max(x - 1, 0)
            let b = if along_y: min(y + 1, h - 1) * w + x else: y * w + min(x + 1, w - 1)
            let o = y * w + x
            for(4) c: dst[o * 4 + c] = (src[a * 4 + c] + src[o * 4 + c] + src[b * 4 + c]) / 3.0
            x++
        y++

// Paths.mask, then the blur (two passes) TerrainView gives it: the textures the terrain shader reads. Only the paths
// laid since the last call are painted, and only around them blurred again (#335: the whole map took 35 to 48 ms).
def paint_paths():
    let w = W * MASK_K
    let h = H * MASK_K
    let fw = W * PATH_FINE
    let fh = H * PATH_FINE
    let first = path_raw.length != w * h * 4 or path_bytes.length != w * h * 4  // (a new match: view_reset empties path_raw)
    if first:
        path_painted = 0
        path_raw = map(w * h * 4): 0.0
        path_h1 = map(w * h * 4): 0.0
        path_v1 = map(w * h * 4): 0.0
        path_h2 = map(w * h * 4): 0.0
        path_best = map(fw * fh): 1000000.0
        path_arc = map(fw * fh): 0.0
        path_bytes = map(w * h * 4): 0
    var lo = int2 { w, h }  // the mask cells painted
    var hi = int2 { -1, -1 }
    var flo = int2 { fw, fh }  // and the fine cells
    var fhi = int2 { -1, -1 }
    for(path_out.length - path_painted) j:
        let p = path_out[path_painted + j]
        let ch = str_index(PATH_STYLES, p.style)
        let pts = p.points
        let r = p.width
        var along = 0.0
        var i = 1
        while i < pts.length:
            let pa = pts[i - 1]
            let pb = pts[i]
            let plo = float2 { min(pa.x, pb.x), min(pa.y, pb.y) } - float2_1 * (r + 0.3)
            let phi = float2 { max(pa.x, pb.x), max(pa.y, pb.y) } + float2_1 * (r + 0.3)
            let mx0 = max(int(plo.x * float(MASK_K)), 0)
            let mx1 = min(int(phi.x * float(MASK_K)) + 1, w)
            let my0 = max(int(plo.y * float(MASK_K)), 0)
            let my1 = min(int(phi.y * float(MASK_K)) + 1, h)
            lo, hi = path_grow(lo, hi, mx0, mx1, my0, my1)
            var y = my0
            while y < my1:
                var x = mx0
                while x < mx1:
                    let q = (float2 { float(x), float(y) } + float2 { 0.5, 0.5 }) / float(MASK_K)
                    if vlen(closest_on_segment(q, pa, pb) - q) < r: path_raw[(y * w + x) * 4 + ch] = 1.0
                    x++
                y++
            let fx0 = max(int(plo.x * float(PATH_FINE)), 0)
            let fx1 = min(int(phi.x * float(PATH_FINE)) + 1, fw)
            let fy0 = max(int(plo.y * float(PATH_FINE)), 0)
            let fy1 = min(int(phi.y * float(PATH_FINE)) + 1, fh)
            flo, fhi = path_grow(flo, fhi, fx0, fx1, fy0, fy1)
            y = fy0
            while y < fy1:
                var x = fx0
                while x < fx1:
                    let q = (float2 { float(x), float(y) } + float2 { 0.5, 0.5 }) / float(PATH_FINE)
                    let on = closest_on_segment(q, pa, pb)
                    let d = vlen(on - q)
                    let idx = y * fw + x
                    if d < r + 0.3 and d < path_best[idx]:
                        path_best[idx] = d
                        path_arc[idx] = along + vlen(on - pa)
                    x++
                y++
            along += vlen(pb - pa)
            i++
    path_painted = path_out.length
    if first:
        lo, hi = int2_0, int2 { w - 1, h - 1 }
        flo, fhi = int2_0, int2 { fw - 1, fh - 1 }
    let fmt = texture_format_clamp | texture_format_nomipmap
    if hi.x >= lo.x:
        // The blur reaches two cells: what's painted changes the mask two cells about it, and each pass reads one further.
        let o0 = max(lo - int2_1 * 2, int2_0)
        let o1 = min(hi + int2_1 * 2, int2 { w - 1, h - 1 })
        path_blur(path_raw, path_h1, w, h, false, o0.x - 1, o1.x + 1, o0.y - 2, o1.y + 2)
        path_blur(path_h1, path_v1, w, h, true, o0.x - 1, o1.x + 1, o0.y - 1, o1.y + 1)
        path_blur(path_v1, path_h2, w, h, false, o0.x, o1.x, o0.y - 1, o1.y + 1)
        let out = path_h1  // (free again: the last pass needs only path_h2)
        path_blur(path_h2, out, w, h, true, o0.x, o1.x, o0.y, o1.y)
        for(o1.y - o0.y + 1) dy:
            for(o1.x - o0.x + 1) dx:
                let k = ((o0.y + dy) * w + o0.x + dx) * 4
                for(4) c: path_bytes[k + c] = clamp(int(out[k + c] * 255.0 + 0.5), 0, 255)
        def px(x:int, y:int) -> float4:
            let k = (y * w + x) * 4
            return float4 { float(path_bytes[k]) / 255.0, float(path_bytes[k + 1]) / 255.0, float(path_bytes[k + 2]) / 255.0, float(path_bytes[k + 3]) / 255.0 }
        let rows = map(o1.y - o0.y + 1) dy: map(o1.x - o0.x + 1) dx: px(o0.x + dx, o0.y + dy)
        if first: paths_tex = gl.create_texture(rows, fmt)
        else: path_patch(assert paths_tex, gl.create_texture(rows, fmt | texture_format_nearest_mag | texture_format_nearest_min), o0, o1, h)
    if fhi.x >= flo.x:
        let rows = map(fhi.y - flo.y + 1) dy: map(fhi.x - flo.x + 1) dx: path_arc[(flo.y + dy) * fw + flo.x + dx]
        if first: arc_tex = gl.create_texture_single_channel(rows, fmt | texture_format_float)
        else: path_patch(assert arc_tex, gl.create_texture_single_channel(rows, fmt | texture_format_float | texture_format_nearest_mag | texture_format_nearest_min), flo, fhi, fh)
    ground_stale = true

// Draws a patch into a texture, its cells lo..hi (inclusive): the GPU updates that part, nothing else is sent again
// (#335: the distance-along texture of a 160-tile map is 26 MB). A framebuffer's rows run bottom up, as in
// draw_ground_cached: the patch goes in upside down.
def path_patch(tex:resource<texture>, patch:resource<texture>, lo:int2, hi:int2, rows:int):
    gl.switch_to_framebuffer(tex)
    gl.ortho()
    let was = gl.blend(blend_none)
    gl.set_shader("sprite_copy")
    gl.set_primitive_texture(0, patch)
    let x0 = float(lo.x)
    let x1 = float(hi.x + 1)
    let top = float(rows - hi.y - 1)
    let bottom = float(rows - lo.y)
    gl.draw_mesh("PT", [ float3 { x0, top, 0.0 }, float3 { x1, top, 0.0 }, float3 { x1, bottom, 0.0 }, float3 { x0, bottom, 0.0 } ], []::float4,
                 []::float3, [ float2 { 0.0, 1.0 }, float2 { 1.0, 1.0 }, float2 { 1.0, 0.0 }, float2 { 0.0, 0.0 } ], []::float2, [ 0, 2, 1, 0, 3, 2 ])
    gl.blend(was)
    gl.switch_to_framebuffer(nil)
    gl.ortho()
