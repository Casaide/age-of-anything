// ------------------------------------------------------------------ a little scene graph (Godot's Node2D, as UnitView uses it)
// Nodes with a position, rotation, scale, a layer ("z" meta: children are ordered by it, not drawn
// by z_index), visibility and an alpha; a node may be a part (PartShape): a bake drawn at its origin.
// Godot's 2D maths in radians, and its RandomNumberGenerator (PCG32), for the cosmetic animation.

let PI = 3.14159265358979323846
let TAU = 6.28318530717958647692
let RAD = 57.29577951308232  // degrees a radian (Lobster's trig takes degrees)

def rsin(a:float) -> float: return sin(a * RAD)
def rcos(a:float) -> float: return cos(a * RAD)
def rasin(x:float) -> float: return asin(x) / RAD  // (Lobster: degrees out)
def ratan2(y:float, x:float) -> float: return atan2(float2 { x, y }) / RAD
def rot2(v:float2, a:float) -> float2:
    let c = rcos(a)
    let s = rsin(a)
    return float2 { v.x * c - v.y * s, v.x * s + v.y * c }
def vangle(v:float2) -> float: return ratan2(v.y, v.x)
def vlen(v:float2) -> float: return sqrt(v.x * v.x + v.y * v.y)
def vnorm(v:float2) -> float2:
    let l = vlen(v)
    return if l == 0.0: float2_0 else: v / l
def vdot(a:float2, b:float2) -> float: return a.x * b.x + a.y * b.y
def lerpf(a:float, b:float, w:float) -> float: return a + (b - a) * w
def clampf(x:float, lo:float, hi:float) -> float: return if x < lo: lo elif x > hi: hi else: x
def smoothstep(a:float, b:float, x:float) -> float:
    if a == b: return if x < a: 0.0 else: 1.0
    let s = clampf((x - a) / (b - a), 0.0, 1.0)
    return s * s * (3.0 - 2.0 * s)
def fposmod(x:float, y:float) -> float:
    var v = x - y * floor(x / y)
    if v < 0.0: v += y
    return v
def fmodf(x:float, y:float) -> float:  // C's fmod: the sign of x
    let q = x / y
    let t = if q < 0.0: ceiling(q) else: floor(q)
    return x - t * y
def lerp_angle(a:float, b:float, w:float) -> float:
    let diff = fmodf(b - a, TAU)
    let dist = fmodf(2.0 * diff, TAU) - diff
    return a + dist * w
def move_toward(f:float, to:float, d:float) -> float:
    if abs(to - f) <= d: return to
    return f + (if to > f: d else: -d)
def vmove_toward(v:float2, to:float2, d:float) -> float2:
    let dv = to - v
    let l = vlen(dv)
    return if l <= d or l < 0.00001: to else: v + dv / l * d
def signf(x:float) -> float: return if x > 0.0: 1.0 elif x < 0.0: -1.0 else: 0.0
def roundf(x:float) -> float: return if x >= 0.0: floor(x + 0.5) else: -floor(-x + 0.5)

// ---- Godot's RandomNumberGenerator (PCG32; randf: the exponent from one draw, the significand from the next)

class Pcg:
    state = 0
    inc = 0
    seed = 0

let M32 = 0xFFFFFFFF
def shr64(x:int, n:int) -> int: return (x >> n) & ((1 << (64 - n)) - 1)

def pcg_next(r:Pcg) -> int:
    let old = r.state
    r.state = old * 6364136223846793005 + r.inc
    let xorshifted = shr64(shr64(old, 18) ^ old, 27) & M32
    let rot = shr64(old, 59)
    return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & M32

def pcg_seed(s:int) -> Pcg:
    let r = Pcg {}
    r.seed = s
    r.inc = (1442695040888963407 << 1) | 1
    pcg_next(r)
    r.state += s
    pcg_next(r)
    return r

def clz32(x:int) -> int:
    var n = 0
    var b = 31
    while b >= 0 and ((x >> b) & 1) == 0:
        n++
        b--
    return n

def f32_of(m:int) -> float:  // an int in [2^31, 2^32) rounded to a float32's 24 bits (to nearest, ties even)
    let low = m & 255
    var top = m >> 8
    if low > 128 or (low == 128 and (top & 1) == 1): top++
    return float(top) * 256.0

def randf(r:Pcg) -> float:
    let e = pcg_next(r)
    if e == 0: return 0.0
    return f32_of(pcg_next(r) | 0x80000001) * pow(2.0, float(-32 - clz32(e)))

let f32_buf = ensure_size("", 4, 0)
def f32(x:float) -> float:  // rounded to a 32-bit float (Godot's real_t)
    write_float32_le(f32_buf, 0, x)
    let v, _n = read_float32_le(f32_buf, 0)
    return v

def randf_range(r:Pcg, a:float, b:float) -> float: return f32(randf(r) * f32(b - a) + a)
def randi(r:Pcg) -> int: return pcg_next(r)

// ---- nodes

// Colours by channel (team-neutral hex for the bake key) and the team colour it's tinted with.
class Colours:
    hex:dictionary<string, string>
    team:float3

class VNode:
    pos = float2_0
    rot = 0.0
    scl = float2_1
    z = 0.0
    visible = true
    alpha = 1.0  // modulate.a (children inherit it)
    kids:[VNode] = []
    parent:VNode? = nil
    // a part (PartShape)
    part = false
    part_id = ""
    pshapes:[JV] = []  // its shapes (they name the colour channels its bake key holds)
    cols:Colours? = nil
    facing = 0
    front = false
    size = 100   // the percent of the art scale its unit is drawn at: baked at that size (D-180)
    shade = 1.0  // self_modulate.a (the far leg in shadow)
    // metas
    rest = 0.0  // a back part's resting turn and scale (wings)
    rest_scale = 1.0
    buzz = false  // a wing blur
    has_tool_z = false
    tool_z = 0.0
    has_seat_rest = false
    seat_rest = float2_0

def add_child(p:VNode, c:VNode):
    c.parent = p
    p.kids.push(c)

// Drop a subtree: its parent links cut (they're cycles to Lobster's reference counting).
def free_tree(n:VNode) -> void:
    for(n.kids) k: free_tree(k)
    n.kids = []
    n.parent = nil

def remove_child(p:VNode, c:VNode):
    var n = 0
    while n < p.kids.length:
        if p.kids[n] == c:
            p.kids.remove(n)
            c.parent = nil
            return
        n++

def add_sibling(n:VNode, c:VNode):  // right after n
    let p = n.parent
    if p:
        var i = 0
        while i < p.kids.length:
            if p.kids[i] == n:
                p.kids.insert(i + 1, c)
                c.parent = p
                return
            i++

// Children by their layer ("z" meta), stable, all the way down (UnitView._sort_layers).
def sort_layers(n:VNode) -> void:
    let order = map(n.kids.length) i: i
    let ks = n.kids
    insertion_sort(order) a, b: ks[a].z < ks[b].z
    n.kids = map(order) i: ks[i]
    for(n.kids) k: sort_layers(k)

// Affine transforms: [xx, xy, yx, yy, ox, oy] (Godot's Transform2D columns and origin).
def xf_local(n:VNode) -> [float]:
    let c = rcos(n.rot)
    let s = rsin(n.rot)
    return [ c * n.scl.x, s * n.scl.x, -s * n.scl.y, c * n.scl.y, n.pos.x, n.pos.y ]

def xf_mul(a:[float], b:[float]) -> [float]:
    return [ a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1],
             a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3],
             a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5] ]

def xf_apply(a:[float], p:float2) -> float2: return float2 { a[0] * p.x + a[2] * p.y + a[4], a[1] * p.x + a[3] * p.y + a[5] }

def xf_global(n:VNode) -> [float]:
    let p = n.parent
    if p: return xf_mul(xf_global(p), xf_local(n))
    return xf_local(n)

// Transform2D.get_scale: the x column's length, the y column's signed by the determinant.
def xf_scale(a:[float]) -> float2:
    let det = a[0] * a[3] - a[1] * a[2]
    return float2 { sqrt(a[0] * a[0] + a[1] * a[1]), signf(det) * sqrt(a[2] * a[2] + a[3] * a[3]) }

def new_node() -> VNode: return VNode {}

// Named points (sockets).
class Socks:
    names:[string] = []
    pts:[float2] = []

def sidx(s:Socks, k:string) -> int:
    for(s.names) n, i:
        if n == k: return i
    return -1
def shas(s:Socks, k:string) -> bool: return sidx(s, k) >= 0
def sget(s:Socks, k:string, fallback:float2) -> float2:
    let i = sidx(s, k)
    return if i >= 0: s.pts[i] else: fallback
def sset(s:Socks, k:string, v:float2):
    let i = sidx(s, k)
    if i >= 0: s.pts[i] = v
    else:
        s.names.push(k)
        s.pts.push(v)
