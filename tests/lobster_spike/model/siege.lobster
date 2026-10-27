// ------------------------------------------------------------------ siege engines, carts, war beasts, shots (scenes/art_pixel/siege_models.gd)
// Each builder is siege_models.gd's of the same name, line for line (its comments are there). The generic
// helpers carry a siege_ prefix here (siege_beam, siege_wheel...) so they can't clash with other model files.
// Ids: "siege.<engine>.<take>" (engines, carts, the great sling, war beasts), "shot.<look>", and the war beasts'
// cut parts "leg.beast_*" / "head.beast_*" (legs in a walk step after "@": `hold`).

let SIEGE_ROPE = html("#c8b48a")
let SIEGE_DARK_WOOD = float3 { 0.45, 0.38, 0.36 }
let SIEGE_WIDE_CREW = 17.0
let SIEGE_UP = float3 { 0.0, 1.0, 0.0 }
let SIEGE_RIGHT = float3 { 1.0, 0.0, 0.0 }
let SIEGE_BACK = float3 { 0.0, 0.0, 1.0 }
let SIEGE_E = 2.718281828459045
let SIEGE_NOMAT = plain(float3 { 1.0, 0.0, 1.0 })   // a material the family doesn't have (s.get / s.has)

def siege_lerp(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t
def siege_lerpf(a:float, b:float, t:float) -> float: return a + (b - a) * t
def siege_sign(x:float) -> float: return if x > 0.0: 1.0 elif x < 0.0: -1.0 else: 0.0
def siege_smoothstep(a:float, b:float, x:float) -> float:
    if x <= a: return 0.0
    if x >= b: return 1.0
    let s = (x - a) / (b - a)
    return s * s * (3.0 - 2.0 * s)
def siege_cosr(a:float) -> float: return cos(rad(a))   // cos/sin of an angle in radians (Godot's)
def siege_sinr(a:float) -> float: return sin(rad(a))
def siege_approx(a:float3, b:float3) -> bool:
    def ok(x:float, y:float) -> bool:
        if x == y: return true
        let tol = max(0.00001, 0.00001 * abs(x))
        return abs(x - y) < tol
    return ok(a.x, b.x) and ok(a.y, b.y) and ok(a.z, b.z)

// ------------------------------------------------------------------ the family's materials (_style)

class SStyle:
    fam:string
    team:MMat
    rope:MMat
    wood = SIEGE_NOMAT
    dark = SIEGE_NOMAT
    metal = SIEGE_NOMAT
    roof = SIEGE_NOMAT
    trim = SIEGE_NOMAT
    ammo = SIEGE_NOMAT
    reed = SIEGE_NOMAT
    stalk = SIEGE_NOMAT
    wicker = SIEGE_NOMAT
    daub = SIEGE_NOMAT
    clay = SIEGE_NOMAT
    stone = SIEGE_NOMAT
    lash = SIEGE_NOMAT
    plank = SIEGE_NOMAT
    net = SIEGE_NOMAT
    wood2 = SIEGE_NOMAT
    pipe = SIEGE_NOMAT
    plate = SIEGE_NOMAT
    plate2 = SIEGE_NOMAT
    rivet = SIEGE_NOMAT

def siege_style(fam:string, c:Colours) -> SStyle:
    let s = SStyle { fam, surf("cloth", col(c, "team"), 3.0), plain(SIEGE_ROPE) }
    switch fam:
        case "timber":
            s.wood = surf("wood_grain", float3_1, 8.0)
            s.dark = surf("wood_grain", float3 { 0.7, 0.62, 0.55 }, 6.0)
            s.metal = surf("iron", float3_1, 4.0)
            s.roof = surf("hide", float3 { 0.72, 0.56, 0.42 }, 6.0)
            s.trim = surf("cloth", col(c, "cloth"), 3.0)
            s.ammo = surf("rock", float3_1, 4.0)
        case "forest":
            s.wood = surf("bark_plate", float3 { 0.95, 0.9, 0.8 }, 6.0)
            s.dark = surf("wood_grain", float3 { 0.8, 0.7, 0.6 }, 6.0)
            s.metal = surf("chitin", html("#4a3a5a"), 4.0)
            s.roof = surf("foliage", float3 { 0.95, 1.05, 0.85 }, 7.0)
            s.trim = surf("acorn_cap", float3_1, 3.0)
            s.ammo = surf("acorn_cap", float3 { 1.1, 1.0, 0.9 }, 3.0)
        case "spooky":
            s.wood = surf("wood_grain", SIEGE_DARK_WOOD, 7.0)
            s.dark = surf("wood_grain", float3 { 0.3, 0.26, 0.28 }, 6.0)
            s.metal = surf("bone", float3_1, 3.0)
            s.roof = surf("hide", float3 { 0.38, 0.33, 0.4 }, 6.0)
            s.trim = surf("bone", float3_1, 3.0)
            s.ammo = surf("bone", float3 { 0.9, 0.95, 1.0 }, 3.0)
        case "frog":
            s.wood = surf("wood_grain", float3 { 0.58, 0.44, 0.34 }, 7.0)
            s.dark = surf("wood_grain", float3 { 0.42, 0.32, 0.26 }, 6.0)
            s.reed = surf("thatch", float3 { 1.0, 0.95, 0.82 }, 7.0)
            s.stalk = surf("reed_stalk", float3 { 0.95, 0.92, 0.75 }, 5.0)
            s.wicker = surf("wicker", float3 { 0.95, 0.88, 0.75 }, 6.0)
            s.daub = surf("bld_daub", float3 { 0.92, 0.82, 0.68 }, 9.0)
            s.clay = surf("bld_daub", float3 { 1.05, 0.62, 0.42 }, 7.0)
            s.stone = surf("rock", float3 { 0.72, 0.76, 0.7 }, 5.0)
            s.lash = plain(html("#4a3a2a"))
            s.plank = surf("wood_grain", float3 { 1.0, 0.86, 0.68 }, 8.0)
            s.net = surf("wicker", float3 { 0.72, 0.66, 0.5 }, 2.5)
            s.metal = s.stone
            s.trim = s.lash
            s.ammo = s.clay
        case "junk":
            s.wood = surf("wood_grain", float3 { 0.78, 0.7, 0.6 }, 7.0)
            s.wood2 = surf("bld_wood", float3 { 0.62, 0.5, 0.4 }, 8.0)
            s.dark = surf("wood_grain", float3 { 0.52, 0.46, 0.42 }, 6.0)
            s.metal = surf("iron", float3 { 0.8, 0.56, 0.4 }, 4.0)
            s.pipe = surf("iron", float3 { 0.58, 0.6, 0.58 }, 5.0)
            s.plate = surf("bld_tin", float3 { 0.72, 0.5, 0.36 }, 9.0)
            s.plate2 = surf("bld_tin", float3 { 0.5, 0.52, 0.5 }, 9.0)
            s.rivet = plain(html("#3a302a"))
            s.trim = s.metal
            s.roof = s.plate
            s.ammo = surf("cheese", float3_1, 4.0)
        default: assert false
    s.rope.rope = true   // (ropes are tied at both ends: the placement check, C3, finds them by it)
    if s.lash != SIEGE_NOMAT: s.lash.rope = true
    return s

// ------------------------------------------------------------------ helpers

def siege_beam(a:float3, b:float3, w:float, h:float, m:MMat) -> MNode:
    let mi = mesh_node(box_mesh(float3 { magnitude(b - a), h, w }, 0, 0, 0), m)
    mi.pos = (a + b) * 0.5
    let d = normalize(b - a)
    set_basis(mi, if not siege_approx(d, float3 { -1.0, 0.0, 0.0 }): arc(SIEGE_RIGHT, d) else: axis_angle(SIEGE_UP, 180.0))
    return mi

let SIEGE_X90 = float3 { 90.0, 0.0, 0.0 }

def siege_wheel(n:MNode, at:float3, r:float, thick:float, s:SStyle):
    switch s.fam:
        case "junk":
            if at.x > 0.0:
                add_child(n, cone(r, r, thick, s.wood2, at, SIEGE_X90, 16))
                add_child(n, ring(r * 0.88, r * 1.02, s.metal, at, SIEGE_X90, float3 { 1.0, thick * 1.1, 1.0 }))
                add_child(n, box(float3 { r * 1.8, 0.5, thick + 0.4 }, s.rivet, at))
            else:
                add_child(n, ring(r * 0.8, r, s.metal, at, SIEGE_X90, float3 { 1.0, thick * 1.2, 1.0 }))
                for(8) k:
                    let a = 2.0 * MPI * float(k) / 8.0 + 0.2
                    add_child(n, rod(at, at + float3 { siege_cosr(a), siege_sinr(a), 0.0 } * r * 0.85, 0.4, 0.35, s.dark, false))
                add_child(n, cone(r * 0.25, r * 0.25, thick + 0.6, s.metal, at, SIEGE_X90, 10))
        case "forest":
            add_child(n, cone(r, r, thick, s.wood, at, SIEGE_X90, 16))
            add_child(n, cone(r * 0.85, r * 0.85, thick + 0.3, plain(html("#c8a070")), at, SIEGE_X90, 16))
            add_child(n, cone(r * 0.4, r * 0.4, thick + 0.5, plain(html("#a07848")), at, SIEGE_X90, 12))
        case "spooky":
            add_child(n, ring(r * 0.78, r, s.wood, at, SIEGE_X90, float3 { 1.0, thick * 1.2, 1.0 }))
            for(6) k:
                let a = 2.0 * MPI * float(k) / 6.0 + 0.3
                add_child(n, rod(at, at + float3 { siege_cosr(a), siege_sinr(a), 0.0 } * r * 0.85, 0.35, 0.3, s.metal, false))
            add_child(n, blob(float3_1 * (r * 0.22), s.metal, at))
        default:
            add_child(n, ring(r * 0.8, r, if s.fam == "timber": s.metal else: s.wood, at, SIEGE_X90, float3 { 1.0, thick * 1.2, 1.0 }))
            for(6) k:
                let a = 2.0 * MPI * float(k) / 6.0
                add_child(n, rod(at, at + float3 { siege_cosr(a), siege_sinr(a), 0.0 } * r * 0.85, 0.45, 0.4, s.wood, false))
            add_child(n, cone(r * 0.25, r * 0.25, thick + 0.6, s.dark, at, SIEGE_X90, 10))

def siege_undercarriage(n:MNode, s:SStyle, len:float, wide:float, r:float, x0:float = 0.0):
    for([-1.0, 1.0]) fx:
        for([1.0, -1.0]) side:
            siege_wheel(n, float3 { x0 + fx * len * 0.3, r, (wide * 0.5 + 1.2) * side }, r, 1.6, s)
    for([-1.0, 1.0]) fx:
        add_child(n, rod(float3 { x0 + fx * len * 0.3, r, -wide * 0.5 - 1.0 }, float3 { x0 + fx * len * 0.3, r, wide * 0.5 + 1.0 }, 0.6, 0.6, s.dark, false))

def siege_pennant(n:MNode, s:SStyle, at:float3, h:float, size:float = 4.0):
    add_child(n, rod(at, at + float3 { 0.0, h, 0.0 }, 0.35, 0.3, s.dark))
    let top = at + float3 { 0.0, h - 0.3, 0.0 }
    add_child(n, slab([float2 { 0.0, 0.0 }, float2 { -size * 1.3, -size * 0.25 }, float2 { -size * 1.1, -size * 0.6 }, float2 { 0.0, -size * 0.75 }], 0.3, s.team, top))

def ram_head(n:MNode, s:SStyle, tip:float3, r:float):
    switch s.fam:
        case "timber":
            add_child(n, cone(r * 0.35, r * 1.15, 5.0, s.metal, tip + float3 { 2.5, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }))
            add_child(n, ring(r * 0.9, r * 1.3, s.metal, tip + float3 { -1.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
            add_child(n, ring(r * 0.9, r * 1.3, s.metal, tip + float3 { -12.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
        case "forest":
            let pts = [tip, tip + float3 { 4.5, 0.6, 0.0 }, tip + float3 { 8.0, 2.8, 0.0 }, tip + float3 { 9.5, 6.0, 0.0 }]
            let rr = [r * 1.0, r * 0.75, r * 0.45, 0.3]
            for(pts.length - 1) i:
                let k = i + 1
                add_child(n, rod(pts[k - 1], pts[k], rr[k - 1], rr[k], s.metal))
        case "spooky":
            add_child(n, blob(float3 { 4.6, 4.2, 4.0 }, s.metal, tip + float3 { 2.6, 0.8, 0.0 }))
            add_child(n, blob(float3 { 2.8, 1.6, 3.0 }, s.metal, tip + float3 { 5.0, -2.2, 0.0 }))
            for([1.0, -1.0]) side:
                add_child(n, blob(float3 { 1.1, 1.3, 1.0 }, plain(html("#141018")), tip + float3 { 6.0, 1.2, 1.7 * side }))
        default: return

def ram_log(n:MNode, s:SStyle, x0:float, x1:float, y:float, r:float):
    add_child(n, rod(float3 { x0, y, 0.0 }, float3 { x1, y, 0.0 }, r, r * 0.95, if s.fam != "timber": s.wood else: s.dark))
    ram_head(n, s, float3 { x1, y, 0.0 }, r)

// ------------------------------------------------------------------ ram

// _ram_b (its "forest" branch, the beetle-pushed log, is concept-only: not ported)
def ram_b(s:SStyle) -> Spec:
    let n = mnode()
    let L = 42.0
    let wd = 12.0
    let wr = 4.2
    let top = 25.0
    siege_undercarriage(n, s, L, wd, wr)
    let base = wr + 1.0
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { -L * 0.5, base, wd * 0.5 * side }, float3 { L * 0.5, base, wd * 0.5 * side }, 1.4, 1.4, s.dark))
    for([-L * 0.32, L * 0.32]) x:
        for([1.0, -1.0]) side:
            add_child(n, rod(float3 { x, base, wd * 0.5 * side }, float3 { x, top, 0.0 }, 0.8, 0.7, s.wood))
    add_child(n, siege_beam(float3 { -L * 0.4, top, 0.0 }, float3 { L * 0.4, top, 0.0 }, 1.3, 1.3, s.dark))
    let y = top - 9.0
    for([-L * 0.25, L * 0.25]) x:
        add_child(n, rod(float3 { x, top, 0.0 }, float3 { x, y + 2.0, 0.0 }, 0.35, 0.35, s.rope, false))
    ram_log(n, s, -L * 0.55, L * 0.5 + 8.0, y, 3.0)
    switch s.fam:
        case "timber":
            add_child(n, box(float3 { 5.0, 3.5, 0.4 }, s.team, float3 { 0.0, top - 2.6, 0.9 }))
            add_child(n, box(float3 { 5.0, 3.5, 0.4 }, s.team, float3 { 0.0, top - 2.6, -0.9 }))
        case "spooky":
            add_child(n, blob(float3 { 1.6, 1.8, 1.6 }, s.metal, float3 { L * 0.4 + 1.0, top + 0.5, 0.0 }))
            add_child(n, box(float3 { 4.0, 4.0, 0.3 }, s.team, float3 { 0.0, top - 2.6, 0.9 }))
            add_child(n, box(float3 { 4.0, 4.0, 0.3 }, s.team, float3 { 0.0, top - 2.6, -0.9 }))
        default:
            siege_pennant(n, s, float3 { -L * 0.42, top - 2.0, 0.0 }, 8.0)
    let sp = spec_of(n)
    sock(sp, "crew0", float3 { -L * 0.22, 0.0, wd * 0.5 + 8.0 })
    sock(sp, "crew1", float3 { L * 0.15, 0.0, -wd * 0.5 - 8.0 })
    return sp

// ------------------------------------------------------------------ catapult

def throw_arm(n:MNode, s:SStyle, pivot:float3, tip:float3):
    switch s.fam:
        case "forest":
            let mid = siege_lerp(pivot, tip, 0.5) + float3 { -1.5, 0.0, 0.0 }
            add_child(n, rod(pivot, mid, 1.1, 0.9, s.dark))
            add_child(n, rod(mid, tip, 0.9, 0.7, s.dark))
            add_child(n, dome(float3 { 3.0, 1.6, 3.0 }, s.trim, tip + float3 { 0.0, -0.3, 0.0 }))
            add_child(n, blob(float3 { 1.4, 1.8, 1.4 }, plain(html("#a8743a")), tip + float3 { 0.0, 1.4, 0.0 }))
        case "spooky":
            add_child(n, rod(pivot, tip, 0.9, 0.9, s.metal))
            add_child(n, blob(float3 { 1.4, 1.2, 1.4 }, s.metal, pivot))
            add_child(n, dome(float3 { 2.8, 2.2, 2.6 }, s.metal, tip + float3 { 0.0, -0.6, 0.0 }))
            add_child(n, blob(float3_1 * 2.0, surf("cloth", html("#e8e4f0"), 2.0), tip + float3 { 0.0, 1.4, 0.0 }))
        default:
            add_child(n, siege_beam(pivot, tip, 1.6, 1.6, s.wood))
            add_child(n, dome(float3 { 2.8, 1.8, 2.8 }, s.dark, tip + float3 { 0.0, -0.6, 0.0 }))
            add_child(n, ring(2.4, 2.9, s.metal, tip + float3 { 0.0, -0.4, 0.0 }))
            add_child(n, blob(float3_1 * 2.0, s.ammo, tip + float3 { 0.0, 1.2, 0.0 }))

def catapult_a(s:SStyle) -> Spec:
    let n = mnode()
    let L = 30.0
    let wd = 11.0
    let wr = 3.8
    siege_undercarriage(n, s, L, wd, wr)
    let base = wr + 1.0
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { -L * 0.5, base, wd * 0.5 * side }, float3 { L * 0.5, base, wd * 0.5 * side }, 1.6, 1.6, s.dark))
    for([-L * 0.42, -L * 0.1, L * 0.42]) x:
        add_child(n, siege_beam(float3 { x, base, -wd * 0.5 }, float3 { x, base, wd * 0.5 }, 1.4, 1.4, s.dark))
    let bar = base + 12.0
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { L * 0.12, base, wd * 0.5 * side }, float3 { L * 0.12, bar, wd * 0.5 * side }, 1.4, 1.4, s.wood))
        add_child(n, rod(float3 { L * 0.4, base, wd * 0.5 * side }, float3 { L * 0.12, bar - 3.0, wd * 0.5 * side }, 0.6, 0.6, s.dark))
    add_child(n, siege_beam(float3 { L * 0.12, bar, -wd * 0.5 - 1.0 }, float3 { L * 0.12, bar, wd * 0.5 + 1.0 }, 1.6, 1.6, s.dark))
    add_child(n, rod(float3 { L * 0.12 - 1.2, bar, -wd * 0.3 }, float3 { L * 0.12 - 1.2, bar, wd * 0.3 }, 1.3, 1.3, s.team))
    let pivot = float3 { -L * 0.25, base + 1.2, 0.0 }
    add_child(n, rod(pivot + float3 { 0.0, 0.0, -wd * 0.5 }, pivot + float3 { 0.0, 0.0, wd * 0.5 }, 1.6, 1.6, s.rope))
    let tip = float3 { L * 0.12 - 0.5, base + 22.0, 0.0 }
    throw_arm(n, s, pivot, tip)
    add_child(n, rod(float3 { -L * 0.45, base + 1.6, -wd * 0.5 }, float3 { -L * 0.45, base + 1.6, wd * 0.5 }, 1.0, 1.0, s.dark))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { -L * 0.45, base + 1.6, wd * 0.5 * side }, float3 { -L * 0.45 - 2.0, base + 4.0, wd * 0.5 * side }, 0.4, 0.4, s.dark))
    if s.fam == "spooky":
        add_child(n, blob(float3 { 1.8, 2.0, 1.8 }, s.metal, float3 { L * 0.5, base + 2.2, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ bolt thrower

def bow_and_bolt(n:MNode, s:SStyle, x0:float, x1:float, y:float, span:float):
    add_child(n, siege_beam(float3 { x0, y, 0.0 }, float3 { x1, y, 0.0 }, 2.2, 1.6, s.dark))
    let bx = x1 - 3.0
    var bow_mat = s.wood
    if s.fam == "timber":
        bow_mat = s.dark
        add_child(n, box(float3 { 3.0, 3.0, 3.6 }, s.metal, float3 { bx, y + 0.4, 0.0 }))
    elif s.fam == "spooky": bow_mat = s.metal
    elif s.fam == "forest": bow_mat = surf("wood_grain", float3 { 0.8, 0.7, 0.55 }, 5.0)
    for([1.0, -1.0]) side:
        let mid = float3 { bx - 1.0, y + 0.5, span * 0.55 * side }
        let end = float3 { bx - 4.5, y + 0.5, span * side }
        add_child(n, rod(float3 { bx, y + 0.5, 1.4 * side }, mid, 0.8, 0.65, bow_mat))
        add_child(n, rod(mid, end, 0.65, 0.4, bow_mat))
        add_child(n, rod(end, float3 { x0 + 4.0, y + 0.9, 0.0 }, 0.14, 0.14, if s.fam != "spooky": s.rope else: plain(html("#e8e4f0")), false))
    let head = float3 { x1 + 5.0, y + 1.3, 0.0 }
    if s.fam == "forest":
        add_child(n, rod(float3 { x0 + 4.0, y + 1.3, 0.0 }, head - float3 { 3.0, 0.0, 0.0 }, 0.4, 0.4, s.wood))
        add_child(n, cone(0.05, 0.7, 3.5, plain(html("#6a4a2a")), head - float3 { 1.3, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 8))
    else:
        add_child(n, rod(float3 { x0 + 4.0, y + 1.3, 0.0 }, head - float3 { 1.5, 0.0, 0.0 }, 0.35, 0.35, if s.fam != "spooky": s.wood else: s.metal))
        add_child(n, cone(0.05, 0.75, 2.4, if s.fam != "timber": s.metal else: surf("iron", float3 { 0.7, 0.7, 0.75 }, 3.0), head, float3 { 0.0, 0.0, -90.0 }, 8))
        for([1.0, -1.0]) side:
            add_child(n, slab([float2 { 0.0, 0.0 }, float2 { 2.4, 0.0 }, float2 { 0.4, 1.2 * side }], 0.2, s.team, float3 { x0 + 4.0, y + 1.3, 0.0 }))

def bolt_a(s:SStyle) -> Spec:
    let n = mnode()
    let wr = 5.0
    let y = 13.0
    for([1.0, -1.0]) side:
        siege_wheel(n, float3 { 0.0, wr, 6.5 * side }, wr, 1.6, s)
    add_child(n, rod(float3 { 0.0, wr, -7.5 }, float3 { 0.0, wr, 7.5 }, 0.7, 0.7, s.dark, false))
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { 1.5, wr + 0.5, 3.0 * side }, float3 { -17.0, 0.8, 0.8 * side }, 1.4, 1.4, s.dark))
    add_child(n, siege_beam(float3 { 0.0, wr, 0.0 }, float3 { 0.0, y - 1.0, 0.0 }, 2.0, 2.0, s.dark))
    add_child(n, box(float3 { 6.0, 0.4, 2.8 }, s.team, float3 { -10.5, 3.6, 0.0 }, float3 { 0.0, 0.0, 18.0 }))
    bow_and_bolt(n, s, -10.0, 10.0, y, 9.0)
    return spec_of(n)

// ------------------------------------------------------------------ round 2: the crewed engines

def siege_chain(n:MNode, a:float3, b:float3, m:MMat, link:float = 0.9):
    let count = max(2, int(magnitude(b - a) / (link * 1.6)))
    let d = normalize(b - a)
    let tilt = atan2(float2 { d.y, d.x })
    for(count) k:
        let at = siege_lerp(a, b, (float(k) + 0.5) / float(count))
        add_child(n, ring(link * 0.45, link * 0.8, m, at, float3 { 90.0 * float(k % 2), 0.0, -tilt + 90.0 }, float3 { 1.4, 1.0, 1.0 }))

def siege_grate(n:MNode, s:SStyle, at:float3, w:float, h:float, lean:float = 0.0):
    let g = mnode()
    g.pos = at
    g.rot = float3 { 0.0, 0.0, lean }
    let iron = surf("iron", float3 { 0.5, 0.48, 0.46 }, 4.0)
    for([1.0, -1.0]) side:
        add_child(g, box(float3 { 1.0, h, 1.2 }, iron, float3 { 0.0, h * 0.5, w * 0.5 * side }))
        add_child(g, box(float3 { 1.0, 1.2, w }, iron, float3 { 0.0, h * 0.5 + (h * 0.5 - 0.6) * side, 0.0 }))
    for(5) i:
        let k = i + 1
        add_child(g, box(float3 { 0.7, h, 0.6 }, iron, float3 { 0.0, h * 0.5, -w * 0.5 + w * float(k) / 6.0 }))
    add_child(g, box(float3 { 0.7, 0.6, w }, iron, float3 { 0.0, h * 0.5, 0.0 }))
    add_child(g, box(float3 { 0.9, h * 0.35, w * 0.3 }, s.metal, float3 { 0.3, h * 0.7, w * 0.15 }))
    add_child(n, g)

def siege_patch(n:MNode, s:SStyle, at:float3, size:float2, rot:float3, m:MMat):
    let p = mnode()
    p.pos = at
    p.rot = rot
    add_child(p, box(float3 { size.x, size.y, 0.5 }, m, float3_0))
    for([-1.0, 1.0]) cx:
        for([-1.0, 1.0]) cy:
            add_child(p, blob(float3_1 * 0.45, s.rivet, float3 { cx * (size.x * 0.5 - 0.7), cy * (size.y * 0.5 - 0.7), 0.3 }))
    add_child(n, p)

def junk_head(n:MNode, s:SStyle, tip:float3, r:float):
    add_child(n, cone(r * 1.05, r * 1.05, 5.0, s.pipe, tip + float3 { 1.5, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 14))
    add_child(n, cone(r * 1.7, r * 1.7, 1.4, s.metal, tip + float3 { 4.6, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 16))
    add_child(n, cone(r * 0.9, r * 1.4, 2.0, surf("iron", float3 { 0.45, 0.42, 0.4 }, 4.0), tip + float3 { 6.2, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 14))
    for(6) k:
        let a = 2.0 * MPI * float(k) / 6.0
        add_child(n, blob(float3_1 * 0.5, s.rivet, tip + float3 { 5.3, siege_cosr(a) * r * 1.4, siege_sinr(a) * r * 1.4 }))

def junk_log(n:MNode, s:SStyle, x0:float, x1:float, y:float, r:float):
    add_child(n, siege_beam(float3 { x0, y, 0.0 }, float3 { x1, y, 0.0 }, r * 1.8, r * 1.8, s.wood))
    add_child(n, siege_beam(float3 { x0 + 6.0, y + r * 0.95, 0.4 }, float3 { x0 + 18.0, y + r * 0.95, 0.4 }, r * 1.2, 0.6, s.wood2))
    for([x0 + 3.0, (x0 + x1) * 0.5, x1 - 3.0]) x:
        add_child(n, box(float3 { 1.2, r * 2.1, r * 2.1 }, s.metal, float3 { x, y, 0.0 }))
    junk_head(n, s, float3 { x1, y, 0.0 }, r)

let TIMBER_RAM_ROOF = "hides"

def ram_c(s:SStyle) -> Spec:
    let spec = if s.fam == "junk": ram_c_junk(s) elif s.fam == "timber" and TIMBER_RAM_ROOF != "": ram_covered(s, TIMBER_RAM_ROOF) else: ram_b(s)
    let L = 42.0
    spec.sockets = dictionary<string, float3>(11)
    sock(spec, "crew0_f0_reach_in", float3 { -L * 0.3, 0.0, -2.5 })
    sock(spec, "crew1_f0_reach_in", float3 { L * 0.1, 0.0, -2.5 })
    sock(spec, "crew2_f0_reach", float3 { -L * 0.5 - 5.0, 0.0, 5.0 })
    sock(spec, "crew2_f0_reach_wide", float3 { -L * 0.5 - 12.0, 0.0, 5.0 })
    if s.fam == "timber" and TIMBER_RAM_ROOF != "":
        sock(spec, "crew0_f0_reach_in", float3 { -L * 0.3, 0.0, 3.0 })
        sock(spec, "crew1_f0_reach_in", float3 { L * 0.1, 0.0, -3.0 })
    elif s.fam == "junk":
        sock(spec, "crew0_f0_reach_in", float3 { -L * 0.3, 0.0, -3.2 })
        sock(spec, "crew1_f0_reach_in", float3 { L * 0.1, 0.0, -3.2 })
    return spec

def ram_covered(s:SStyle, roof:string) -> Spec:
    let n = mnode()
    let L = 42.0
    let wd = 12.0
    let wr = 4.2
    let base = wr + 1.0
    let eave = 23.0
    let ridge = 30.5
    let px = L * 0.36
    siege_undercarriage(n, s, L, wd, wr)
    for([1.0, -1.0]) side:
        let z = wd * 0.5 * side
        add_child(n, siege_beam(float3 { -L * 0.5, base, z }, float3 { L * 0.5, base, z }, 1.4, 1.4, s.dark))
        add_child(n, siege_beam(float3 { -px - 1.5, eave, z }, float3 { px + 1.5, eave, z }, 1.2, 1.2, s.dark))
        for([-px, px]) x:
            add_child(n, siege_beam(float3 { x, base, z }, float3 { x, eave, z }, 1.2, 1.2, s.wood))
        add_child(n, rod(float3 { -px, base + 0.5, z }, float3 { 0.0, eave - 0.5, z }, 0.4, 0.4, s.wood, false))
    for([-px, px]) x:
        add_child(n, siege_beam(float3 { x, eave, -wd * 0.5 }, float3 { x, eave, wd * 0.5 }, 1.2, 1.2, s.dark))
        add_child(n, siege_beam(float3 { x, eave, 0.0 }, float3 { x, ridge, 0.0 }, 1.0, 1.0, s.wood))
        for([1.0, -1.0]) side:
            add_child(n, rod(float3 { x, eave - 0.6, (wd * 0.5 + 1.6) * side }, float3 { x, ridge, 0.0 }, 0.55, 0.5, s.wood, false))
    let rx = px + 3.5
    add_child(n, siege_beam(float3 { -rx, ridge, 0.0 }, float3 { rx, ridge, 0.0 }, 1.3, 1.3, s.dark))
    let y = 17.0
    for([-L * 0.25, L * 0.25]) x:
        add_child(n, rod(float3 { x, ridge, 0.0 }, float3 { x, y + 2.0, 0.0 }, 0.35, 0.35, s.rope, false))
    ram_log(n, s, -L * 0.55, L * 0.5 + 8.0, y, 3.0)
    let ze = wd * 0.5 + 1.8
    let ye = eave - 0.6
    if roof == "hides":
        hide_roof(n, s, rx, ridge, ze, ye)
    else:
        plank_roof(n, s, rx, ridge, ze, ye)
    let a = atan2(float2 { ze, ridge - ye })   // degrees
    for([1.0, -1.0]) side:
        let d = 2.8
        let at = float3 { -rx * 0.35, ridge + 0.75 - sin(a) * d * 0.5, cos(a) * d * 0.5 * side }
        add_child(n, box(float3 { 7.0, 0.35, d }, s.team, at, float3 { a * side, 0.0, 0.0 }))
    return spec_of(n)

def roof_slope(m:MMat, x:float, len:float, ridge:float, ze:float, ye:float, side:float, thick:float, lift:float = 0.0) -> MNode:
    let a = atan2(float2 { ze, ridge - ye })
    let d = magnitude(float2 { ze, ridge - ye })
    let mid = float3 { x, (ridge + ye) * 0.5 + lift, ze * 0.5 * side }
    return box(float3 { len, thick, d }, m, mid, float3 { a * side, 0.0, 0.0 })

def hide_roof(n:MNode, s:SStyle, rx:float, ridge:float, ze:float, ye:float):
    let hides = [surf("hide", float3 { 0.6, 0.44, 0.31 }, 6.0), s.roof, surf("hide", float3 { 0.48, 0.34, 0.24 }, 6.0)]
    let lash = plain(html("#3e2e20"))
    let count = 3
    let w = rx * 2.0 / float(count)
    for([1.0, -1.0]) side:
        let o = if side < 0.0: 1 else: 0
        for(count) k:
            let x = -rx + w * (float(k) + 0.5) + (if (k + o) % 2 == 0: 0.8 else: -0.6)
            let drop = [0.4, 1.4, 0.8][(k + o) % 3]
            let hide = roof_slope(hides[(k + o) % 3], x, w + 2.2, ridge + 0.5, ze + drop * 0.5, ye - drop, side, 0.5, 0.15 * float((k + o) % 2))
            hide.rot = float3 { hide.rot.x, [4.0, -3.0, 5.0][(k + o) % 3], hide.rot.z }
            add_child(n, hide)
        for(count * 2 + 1) k:
            let x0 = -rx + w * 0.5 * float(k)
            let x1 = x0 + (if k % 2 == 0: w * 0.5 else: -w * 0.5)
            if abs(x1) <= rx + 0.1:
                add_child(n, rod(float3 { x0, ridge + 1.0, 0.0 }, float3 { x1, ye - 0.4, (ze + 0.4) * side }, 0.3, 0.3, lash, false))
        let p = float3 { 0.0, ridge + 1.0 + (ye - ridge) * 0.55, ze * 0.55 * side }
        add_child(n, rod(p - float3 { rx + 0.3, 0.0, 0.0 }, p + float3 { rx + 0.3, 0.0, 0.0 }, 0.3, 0.3, lash, false))

def plank_roof(n:MNode, s:SStyle, rx:float, ridge:float, ze:float, ye:float):
    let count = 10
    let w = rx * 2.0 / float(count)
    for([1.0, -1.0]) side:
        for(count) k:
            let m = if (k + (if side < 0.0: 1 else: 0)) % 3 != 0: s.wood else: s.dark
            add_child(n, roof_slope(m, -rx + w * (float(k) + 0.5), w - 0.25, ridge + 0.4, ze, ye, side, 0.6, 0.1 * float(k % 2)))
        for([0.3, 0.8]) t:
            let p = float3 { 0.0, ridge + 0.9 + (ye - ridge) * t, ze * t * side }
            add_child(n, siege_beam(p - float3 { rx, 0.0, 0.0 }, p + float3 { rx, 0.0, 0.0 }, 0.6, 0.5, s.dark))
        add_child(n, box(float3 { rx * 2.0, 2.6, 0.35 }, s.roof, float3 { 0.0, ye - 1.3, (ze + 0.1) * side }, float3 { -8.0 * side, 0.0, 0.0 }))

def ram_c_junk(s:SStyle) -> Spec:
    let n = mnode()
    let L = 42.0
    let wd = 12.0
    let wr = 4.2
    let top = 25.0
    siege_undercarriage(n, s, L, wd, wr)
    let base = wr + 1.0
    for([1.0, -1.0]) side:
        if side > 0.0:
            add_child(n, siege_beam(float3 { -L * 0.5, base, wd * 0.5 }, float3 { L * 0.5, base, wd * 0.5 }, 1.6, 1.6, s.wood2))
        else:
            add_child(n, rod(float3 { -L * 0.5, base, -wd * 0.5 }, float3 { L * 0.5, base, -wd * 0.5 }, 0.8, 0.8, s.pipe))
    for([-L * 0.32, L * 0.32]) x:
        for([1.0, -1.0]) side:
            add_child(n, rod(float3 { x, base, wd * 0.5 * side }, float3 { x, top, 0.0 }, 0.75, 0.75, s.pipe))
        add_child(n, blob(float3 { 1.4, 1.4, 1.6 }, s.metal, float3 { x, top, 0.0 }))
    add_child(n, rod(float3 { -L * 0.4, top, 0.0 }, float3 { L * 0.4, top, 0.0 }, 0.9, 0.9, s.pipe))
    let y = top - 9.0
    for([-L * 0.25, L * 0.25]) x:
        siege_chain(n, float3 { x, top - 0.6, 0.0 }, float3 { x, y + 2.0, 0.0 }, s.metal, 0.75)
    junk_log(n, s, -L * 0.55, L * 0.5 + 6.0, y, 2.6)
    add_child(n, box(float3 { 3.0, 4.0, 0.4 }, s.team, float3 { -L * 0.12, top - 2.4, 1.0 }, float3 { 0.0, 0.0, 8.0 }))
    add_child(n, ring(0.8, 1.4, s.team, float3 { -L * 0.12, top, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    return spec_of(n)

def catapult_c(s:SStyle) -> Spec:
    let spec = if s.fam != "junk": catapult_a(s) else: catapult_c_junk(s)
    let L = 30.0
    let wd = 11.0
    spec.sockets = dictionary<string, float3>(11)
    sock(spec, "crew0_f0_raise", float3 { -L * 0.5 - 6.0, 0.0, 0.0 })
    sock(spec, "crew1_f0_reach", float3 { -L * 0.3, 0.0, wd * 0.5 + 7.0 })
    for(3) k:
        let at = float3 { -L * 0.12 + float(k % 2) * 2.4, 1.0 + float(k / 2) * 1.6, wd * 0.5 + 3.5 + float(k % 2) * 1.2 }
        if s.fam == "junk":
            add_child(spec.node, cone(1.6, 1.6, 1.4, s.ammo, at, float3_0, 12))
        else:
            add_child(spec.node, blob(float3_1 * 1.5, s.ammo, at))
    return spec

def catapult_c_junk(s:SStyle) -> Spec:
    let n = mnode()
    let L = 30.0
    let wd = 11.0
    let wr = 3.8
    siege_undercarriage(n, s, L, wd, wr)
    let base = wr + 1.0
    add_child(n, siege_beam(float3 { -L * 0.5, base, wd * 0.5 }, float3 { L * 0.5, base, wd * 0.5 }, 1.6, 1.6, s.wood2))
    add_child(n, siege_beam(float3 { -L * 0.5, base, -wd * 0.5 }, float3 { L * 0.5, base, -wd * 0.5 }, 1.8, 1.4, s.dark))
    for([-L * 0.42, -L * 0.1, L * 0.42]) x:
        add_child(n, siege_beam(float3 { x, base, -wd * 0.5 }, float3 { x, base, wd * 0.5 }, 1.4, 1.4, if x < 0.0: s.wood else: s.wood2))
    let bar = base + 12.0
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { L * 0.12, base, wd * 0.5 * side }, float3 { L * 0.12, bar, wd * 0.5 * side }, 0.8, 0.8, s.pipe))
        add_child(n, siege_beam(float3 { L * 0.4, base, wd * 0.5 * side }, float3 { L * 0.12, bar - 3.0, wd * 0.5 * side }, 0.9, 0.4, s.metal))
    add_child(n, rod(float3 { L * 0.12, bar, -wd * 0.5 - 1.0 }, float3 { L * 0.12, bar, wd * 0.5 + 1.0 }, 0.9, 0.9, s.pipe))
    add_child(n, rod(float3 { L * 0.12 - 1.2, bar, -wd * 0.3 }, float3 { L * 0.12 - 1.2, bar, wd * 0.3 }, 1.3, 1.3, s.team))
    let pivot = float3 { -L * 0.25, base + 1.2, 0.0 }
    add_child(n, rod(pivot + float3 { 0.0, 0.0, -wd * 0.5 }, pivot + float3 { 0.0, 0.0, wd * 0.5 }, 1.6, 1.6, s.rope))
    siege_chain(n, pivot + float3 { 0.0, 1.7, -wd * 0.45 }, pivot + float3 { 0.0, 1.7, wd * 0.45 }, s.metal, 0.7)
    let tip = float3 { L * 0.12 - 0.5, base + 22.0, 0.0 }
    add_child(n, siege_beam(pivot, tip, 1.7, 1.5, s.wood))
    for([0.3, 0.65]) t:
        add_child(n, box(float3 { 2.0, 0.9, 2.0 }, s.metal, siege_lerp(pivot, tip, t), float3 { 0.0, 0.0, atan2(float2 { tip.x - pivot.x, tip.y - pivot.y }) }))
    add_child(n, cone(2.8, 2.0, 3.2, s.metal, tip + float3 { 0.0, 0.4, 0.0 }, float3_0, 14))
    add_child(n, ring(2.6, 3.0, s.rivet, tip + float3 { 0.0, 2.0, 0.0 }))
    add_child(n, box(float3 { 3.8, 2.8, 3.8 }, s.ammo, tip + float3 { 0.0, 3.0, 0.0 }, float3 { 0.0, 30.0, 12.0 }))
    add_child(n, rod(float3 { -L * 0.45, base + 1.6, -wd * 0.5 }, float3 { -L * 0.45, base + 1.6, wd * 0.5 + 1.0 }, 0.8, 0.8, s.pipe))
    add_child(n, ring(1.8, 2.4, s.metal, float3 { -L * 0.45, base + 1.6, wd * 0.5 + 1.2 }, SIEGE_X90))
    return spec_of(n)

def bolt_c(s:SStyle) -> Spec:
    let spec = if s.fam != "junk": bolt_a(s) else: bolt_c_junk(s)
    spec.sockets = dictionary<string, float3>(11)
    sock(spec, "crew0_f0_reach", float3 { -19.0, 0.0, 3.5 })
    sock(spec, "crew1_f0_reach", float3 { -13.0, 0.0, -9.5 })
    return spec

let PART_PER_MODEL = 55.0
let WALL_WALK = 1.36 * PART_PER_MODEL

def tower_c(s:SStyle) -> Spec:
    let n = mnode()
    let L = 34.0
    let wd = 26.0
    let wr = 4.6
    siege_undercarriage(n, s, L, wd, wr)
    let base = wr + 1.2
    let deck_y = WALL_WALK + 1.0
    let top = deck_y + 0.8 * PART_PER_MODEL
    def taper(y:float) -> float: return 1.0 - (y - base) / (top - base) * 0.12
    for([-L * 0.45, L * 0.45]) x:
        for([-wd * 0.45, wd * 0.45]) z:
            add_child(n, siege_beam(float3 { x, base, z }, float3 { x * taper(top), top, z * taper(top) }, 2.0, 2.0, s.wood))
    for([base, (base + deck_y) * 0.5, deck_y, top]) y:
        let k = taper(y)
        for([-wd * 0.45 * k, wd * 0.45 * k]) z:
            add_child(n, siege_beam(float3 { -L * 0.45 * k, y, z }, float3 { L * 0.45 * k, y, z }, 1.4, 1.4, s.dark))
        for([-L * 0.45 * k, L * 0.45 * k]) x:
            add_child(n, siege_beam(float3 { x, y, -wd * 0.45 * k }, float3 { x, y, wd * 0.45 * k }, 1.4, 1.4, s.dark))
    let hide = if s.roof != SIEGE_NOMAT: s.roof else: s.wood
    for([float2 { base + 2.0, deck_y - 1.0 }, float2 { deck_y + 1.0, top - 1.0 }]) lo_hi:
        let y0 = lo_hi.x
        let y1 = lo_hi.y
        let k = taper((y0 + y1) * 0.5)
        for([-wd * 0.43 * k, wd * 0.43 * k]) z:
            add_child(n, box(float3 { L * 0.84 * k, y1 - y0, 0.5 }, hide, float3 { 0.0, (y0 + y1) * 0.5, z }))
        add_child(n, box(float3 { 0.5, y1 - y0, wd * 0.84 * k }, hide, float3 { L * 0.43 * k, (y0 + y1) * 0.5, 0.0 }))
    let kt = taper(top)
    add_child(n, box(float3 { L * 0.86 * kt, 1.2, wd * 0.86 * kt }, s.dark, float3 { 0.0, top, 0.0 }))
    for([-wd * 0.4 * kt, wd * 0.4 * kt]) z:
        add_child(n, box(float3 { L * 0.8 * kt, 4.0, 1.0 }, s.wood, float3 { 0.0, top + 2.0, z }))
    add_child(n, box(float3 { 1.0, 4.0, wd * 0.8 * kt }, s.wood, float3 { L * 0.4 * kt, top + 2.0, 0.0 }))
    let kd = taper(deck_y)
    let gx = L * 0.45 * kd + 1.4
    let g_len = 30.0
    add_child(n, box(float3 { 1.2, g_len, wd * 0.6 }, s.wood, float3 { gx, deck_y + g_len * 0.5, 0.0 }))
    for([-wd * 0.26, wd * 0.26]) z:
        add_child(n, rod(float3 { gx, deck_y + g_len - 1.0, z }, float3 { L * 0.4 * kt, top + 3.0, z }, 0.3, 0.3, s.rope, false))
    siege_pennant(n, s, float3 { -L * 0.35 * kt, top + 1.0, -wd * 0.35 * kt }, 14.0, 6.0)
    let sp = spec_of(n)
    sock(sp, "crew0_f0_reach", float3 { -L * 0.5 - 9.0, 0.0, -10.0 })
    sock(sp, "crew1_f0_reach", float3 { -L * 0.5 - 15.0, 0.0, 10.0 })
    sock(sp, "crew0_f0_reach_wide", float3 { -L * 0.5 - 13.0, 0.0, -10.0 })
    return sp

def bolt_c_junk(s:SStyle) -> Spec:
    let n = mnode()
    let wr = 5.0
    let y = 13.0
    siege_wheel(n, float3 { 0.0, wr, 6.5 }, wr, 1.6, s)
    siege_wheel(n, float3 { 0.01, wr * 0.92, -6.5 }, wr * 0.92, 1.8, s)
    add_child(n, rod(float3 { 0.0, wr, -7.5 }, float3 { 0.0, wr, 7.5 }, 0.7, 0.7, s.pipe, false))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { 1.5, wr + 0.5, 3.0 * side }, float3 { -17.0, 0.8, 0.8 * side }, 0.75, 0.75, s.pipe))
    add_child(n, siege_beam(float3 { 0.0, wr, 0.0 }, float3 { 0.0, y - 1.0, 0.0 }, 2.0, 2.0, s.wood2))
    add_child(n, box(float3 { 6.0, 0.4, 2.8 }, s.team, float3 { -10.5, 3.6, 0.0 }, float3 { 0.0, 0.0, 18.0 }))
    siege_grate(n, s, float3 { 3.0, wr - 2.0, 0.0 }, 11.0, 9.5, 8.0)
    add_child(n, siege_beam(float3 { -10.0, y, 0.0 }, float3 { 10.0, y, 0.0 }, 2.2, 1.6, s.wood))
    add_child(n, box(float3 { 3.0, 3.0, 3.6 }, s.metal, float3 { 7.0, y + 0.4, 0.0 }))
    for([1.0, -1.0]) side:
        for(3) leaf:
            let a = float3 { 7.0, y + 0.5 - float(leaf) * 0.5, 1.4 * side }
            let e = float3 { 3.0 + float(leaf) * 1.2, y + 0.5 - float(leaf) * 0.5, (11.0 - float(leaf) * 2.6) * side }
            add_child(n, siege_beam(a, e, 0.9, 0.45, if leaf != 1: s.metal else: s.pipe))
        add_child(n, rod(float3 { 3.0, y + 0.5, 11.0 * side }, float3 { -6.0, y + 0.9, 0.0 }, 0.14, 0.14, s.rope, false))
    add_child(n, rod(float3 { -6.0, y + 1.3, 0.0 }, float3 { 13.5, y + 1.3, 0.0 }, 0.35, 0.35, s.pipe))
    add_child(n, cone(0.05, 0.6, 2.6, s.metal, float3 { 15.0, y + 1.3, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 8))
    for([1.0, -1.0]) side:
        add_child(n, slab([float2 { 0.0, 0.0 }, float2 { 2.4, 0.0 }, float2 { 0.4, 1.2 * side }], 0.2, s.plate2, float3 { -6.0, y + 1.3, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ the giant beetle (D-117)

let BEETLE_DROP = 5.0

// A chain of rods through `pts`, radii `r` (limb).
def siege_limb(n:MNode, pts:[float3], r:[float], m:MMat):
    for(pts.length - 1) i:
        add_child(n, rod(pts[i], pts[i + 1], r[i], r[i + 1], m))

def giant_beetle(n:MNode, s:SStyle) -> MNode:
    let shell = surf("chitin", html("#5a3424"), 5.0)
    let dark = surf("chitin", html("#2e1c16"), 4.0)
    let under = plain(html("#24160f"))
    let iron = surf("iron", float3 { 0.72, 0.72, 0.76 }, 4.0)
    let bark = surf("bark_plate", float3 { 0.85, 0.75, 0.62 }, 6.0)
    let b = mnode()
    b.pos = float3 { 0.0, -BEETLE_DROP, 0.0 }
    add_child(n, b)
    for([float3 { 14.0, 7.0, 15.0 }, float3 { 2.0, 1.0, 2.0 }, float3 { -10.0, -6.0, -14.0 }]) leg:
        for([1.0, -1.0]) side:
            let hip = float3 { leg.x, 16.0 - BEETLE_DROP, 9.0 * side }
            let knee = float3 { leg.x + leg.y, 20.0 - BEETLE_DROP, 21.0 * side }
            let foot = float3 { leg.x + leg.z, 0.8, 25.0 * side }
            add_child(n, rod(hip, knee, 3.2, 2.6, dark))
            add_child(n, rod(knee, foot, 2.5, 1.4, dark))
            add_child(n, rod(foot, foot + float3 { 2.0 * siege_sign(leg.z + 0.1), -0.5, 1.0 * side }, 0.8, 0.5, dark))
    add_child(b, blob(float3 { 26.0, 7.5, 13.0 }, under, float3 { -2.0, 17.0, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(b, blob(float3 { 24.0, 12.5, 8.6 }, shell, float3 { -8.0, 25.0, 7.4 * side }, float3 { 0.0, 0.0, 4.0 }))
    add_child(b, rod(float3 { -31.0, 25.0, 0.0 }, float3 { 11.0, 37.5, 0.0 }, 0.5, 0.5, dark, false))
    add_child(b, blob(float3 { 11.0, 10.5, 14.5 }, shell, float3 { 16.0, 25.0, 0.0 }))
    add_child(b, dome(float3 { 10.6, 8.0, 14.0 }, bark, float3 { 17.5, 27.5, 0.0 }))
    add_child(b, ring(9.8, 11.2, iron, float3 { 17.5, 27.6, 0.0 }, float3_0, float3 { 1.0, 1.2, 1.32 }))
    for(5) k:
        let a = -0.9 + float(k) * 0.45
        add_child(b, blob(float3_1 * 0.9, iron, float3 { 17.5 + siege_cosr(a) * 9.5, 30.5, siege_sinr(a) * 12.0 }))
    siege_limb(b, [float3 { 22.0, 33.0, 0.0 }, float3 { 31.0, 35.5, 0.0 }, float3 { 39.0, 33.0, 0.0 }, float3 { 43.5, 27.5, 0.0 }], [3.0, 2.3, 1.6, 0.8], dark)
    add_child(b, blob(float3 { 7.5, 6.5, 8.5 }, shell, float3 { 29.0, 18.0, 0.0 }))
    siege_limb(b, [float3 { 33.0, 17.0, 0.0 }, float3 { 43.0, 17.0, 0.0 }, float3 { 52.0, 18.5, 0.0 }, float3 { 58.0, 22.0, 0.0 }], [4.4, 3.7, 3.0, 2.5], dark)
    add_child(b, ring(3.5, 4.6, iron, float3 { 43.0, 17.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    add_child(b, cone(0.8, 3.6, 6.5, iron, float3 { 60.5, 24.0, 0.0 }, float3 { 0.0, 0.0, -50.0 }, 14))
    for([1.0, -1.0]) side:
        add_child(b, blob(float3 { 1.6, 1.6, 1.2 }, plain(html("#120c0a")), float3 { 31.0, 20.0, 6.8 * side }))
        add_child(b, blob(float3 { 0.5, 0.5, 0.4 }, plain(html("#d8c8b8")), float3 { 31.8, 20.8, 7.6 * side }))
        add_child(b, rod(float3 { 34.0, 15.0, 4.5 * side }, float3 { 39.0, 14.0, 7.5 * side }, 0.35, 0.3, dark))
        add_child(b, blob(float3 { 1.0, 0.7, 1.0 }, dark, float3 { 39.5, 14.0, 7.8 * side }))
    add_child(b, ring(0.9, 1.0, surf("leather", float3 { 0.6, 0.45, 0.32 }, 3.0), float3 { 2.0, 25.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }, float3 { 14.5, 2.2, 17.5 }))
    return b

def ram_ridden(s:SStyle) -> Spec:
    let n = mnode()
    let b = giant_beetle(n, s)
    let deck_y = 37.6
    let wood = surf("wood_grain", float3 { 0.75, 0.62, 0.5 }, 6.0)
    add_child(b, box(float3 { 22.0, 1.4, 16.0 }, wood, float3 { -6.0, deck_y, 0.0 }))
    for([-16.5, 4.5]) x:
        for([1.0, -1.0]) side:
            add_child(b, rod(float3 { x, deck_y, 7.6 * side }, float3 { x, deck_y + 4.5, 7.6 * side }, 0.45, 0.45, s.dark))
    for([1.0, -1.0]) side:
        add_child(b, rod(float3 { -16.5, deck_y + 4.5, 7.6 * side }, float3 { 4.5, deck_y + 4.5, 7.6 * side }, 0.4, 0.4, s.dark))
    add_child(b, rod(float3 { -16.5, deck_y + 4.5, -7.6 }, float3 { -16.5, deck_y + 4.5, 7.6 }, 0.4, 0.4, s.dark))
    for([1.0, -1.0]) side:
        add_child(b, box(float3 { 12.0, 6.5, 0.4 }, s.team, float3 { -6.0, deck_y - 3.0, 8.4 * side }, float3 { 16.0 * side, 0.0, 0.0 }))
    siege_pennant(b, s, float3 { -16.5, deck_y, -6.5 }, 11.0, 3.6)
    let sp = spec_of(n)
    sock(sp, "crew0_f0_reach_top", float3 { 1.5, deck_y + 0.7 - BEETLE_DROP, 2.5 })
    sock(sp, "crew1_f0_top", float3 { -13.0, deck_y + 0.7 - BEETLE_DROP, -3.0 })
    return sp

// ------------------------------------------------------------------ the frogs' engines (rounds 3 and 4: what's in play)

def siege_band(n:MNode, at:float3, dir:float3, r:float, m:MMat):
    let t = ring(r * 0.92, r * 1.18, m, at)
    set_basis(t, arc(SIEGE_UP, normalize(dir)))
    add_child(n, t)

def siege_bundle(n:MNode, a:float3, b:float3, r:float, s:SStyle, ties:int = 3, r2:float = -1.0):
    let rb = if r2 < 0.0: r else: r2
    add_child(n, rod(a, b, r, rb, s.reed))
    for(ties) k:
        let t = (float(k) + 0.5) / float(ties)
        siege_band(n, siege_lerp(a, b, t), b - a, siege_lerpf(r, rb, t), s.lash)

def siege_sledge(n:MNode, s:SStyle, L:float, wd:float, x0:float = 0.0):
    for([1.0, -1.0]) side:
        let z = wd * 0.5 * side
        add_child(n, siege_beam(float3 { x0 - L * 0.5, 1.4, z }, float3 { x0 + L * 0.38, 1.4, z }, 2.6, 2.6, s.dark))
        add_child(n, rod(float3 { x0 + L * 0.38, 1.4, z }, float3 { x0 + L * 0.48, 3.4, z }, 1.3, 1.2, s.dark))
        add_child(n, rod(float3 { x0 + L * 0.48, 3.4, z }, float3 { x0 + L * 0.5, 6.0, z }, 1.2, 0.9, s.dark))
        siege_band(n, float3 { x0 + L * 0.48, 3.4, z }, float3 { 0.4, 1.0, 0.0 }, 1.3, s.lash)
    for(4) k:
        let x = x0 - L * 0.42 + float(k) * L * 0.26
        add_child(n, siege_beam(float3 { x, 3.2, -wd * 0.5 - 1.0 }, float3 { x, 3.2, wd * 0.5 + 1.0 }, 2.0, 1.4, s.wood))

def clay_cup(n:MNode, s:SStyle, at:float3, r:float):
    add_child(n, cone(r, r * 0.68, r * 0.9, s.wicker, at, float3_0, 16))
    add_child(n, ring(r * 0.9, r * 1.08, s.reed, at + float3 { 0.0, r * 0.45, 0.0 }))
    add_child(n, blob(float3_1 * (r * 0.8), s.clay, at + float3 { 0.0, r * 0.8, 0.0 }))

def ram_beast(s:SStyle) -> Spec:
    let n = mnode()
    let deck_y = snapping_turtle(n, s)
    add_child(n, cone(10.5, 9.0, 6.0, s.wicker, float3 { -6.0, deck_y + 1.0, 0.0 }, float3_0, 20))
    add_child(n, ring(10.0, 11.2, s.reed, float3 { -6.0, deck_y + 4.0, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 14.0, 0.6, 13.0 }, s.team, float3 { -6.0, deck_y - 6.0, 15.5 * side }, float3 { 48.0 * side, 0.0, 0.0 }))
    siege_pennant(n, s, float3 { -15.0, deck_y + 2.0, -5.0 }, 14.0, 4.0)
    let sp = spec_of(n)
    sock(sp, "crew0_f0_reach_top", float3 { -4.0, deck_y + 0.5, 0.0 })
    sock(sp, "crew1_f0_reach", float3 { -46.0, 0.0, 22.0 })
    return sp

def snapping_turtle(n:MNode, s:SStyle) -> float:
    let skin = surf("hide", float3 { 0.4, 0.41, 0.36 }, 6.0)
    let shell = surf("chitin", html("#5e5a32"), 8.0)
    let keel = surf("chitin", html("#4a4626"), 5.0)
    let horn = plain(html("#2c2a20"))
    let C = float3 { -4.0, 12.0, 0.0 }
    let R = float3 { 33.0, 23.0, 25.0 }
    for([float2 { 16.0, 1.0 }, float2 { 16.0, -1.0 }, float2 { -20.0, 1.0 }, float2 { -20.0, -1.0 }]) leg:
        let x = leg.x
        let side = leg.y
        let hip = float3 { x, 11.0, 18.0 * side }
        let foot = float3 { x + 4.0, 1.2, 26.0 * side }
        add_child(n, rod(hip, foot, 6.0, 4.6, skin))
        add_child(n, blob(float3 { 5.5, 2.2, 5.0 }, skin, foot))
        for(3) t:
            add_child(n, cone(0.1, 0.9, 3.0, horn, foot + float3 { 5.5, -0.6, float(t - 1) * 2.4 }, float3 { 0.0, 0.0, -90.0 }, 6))
    add_child(n, blob(float3 { 29.0, 6.0, 22.0 }, plain(html("#8a7c52")), C + float3 { 0.0, -1.5, 0.0 }))
    add_child(n, dome(R, shell, C))
    add_child(n, blob(float3 { R.x + 1.0, 2.6, R.z + 1.0 }, keel, C))
    for(5) k:
        let a = MPI * 0.6 + float(k) * MPI * 0.2
        add_child(n, cone(0.2, 2.4, 5.0, keel, C + float3 { siege_cosr(a) * (R.x + 2.0), -0.5, siege_sinr(a) * (R.z + 2.0) }, float3 { 0.0, -rad(a), 90.0 }, 6))
    for([-12.0, 0.0, 12.0]) z:
        for(6) k:
            let x = -28.0 + float(k) * 9.0
            let q = 1.0 - pow((x - C.x) / R.x, 2.0) - pow(z / R.z, 2.0)
            if q > 0.05:
                add_child(n, blob(float3 { 4.4, 2.0, 2.4 }, keel, float3 { x, C.y + R.y * sqrt(q) - 0.6, z }))
    add_child(n, rod(float3 { 22.0, 16.0, 0.0 }, float3 { 38.0, 15.0, 0.0 }, 7.5, 6.2, skin))
    add_child(n, blob(float3 { 10.0, 7.5, 8.5 }, skin, float3 { 44.0, 15.0, 0.0 }))
    add_child(n, blob(float3 { 4.5, 4.0, 5.0 }, horn, float3 { 52.0, 13.5, 0.0 }))
    add_child(n, cone(0.3, 3.4, 6.0, horn, float3 { 55.5, 10.5, 0.0 }, float3 { 0.0, 0.0, -135.0 }, 10))
    add_child(n, dome(float3 { 6.4, 3.0, 6.0 }, s.stone, float3 { 45.0, 19.8, 0.0 }))
    for(4) k:
        add_child(n, blob(float3_1 * 1.3, s.stone, float3 { 42.0 + float(k) * 2.4, 22.6 - abs(float(k) - 1.5) * 0.6, float(k % 2) * 2.6 - 1.3 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.4, 1.4, 1.0 }, plain(html("#c8a040")), float3 { 48.0, 17.5, 7.0 * side }))
        add_child(n, blob(float3 { 0.6, 0.8, 0.5 }, plain(html("#141008")), float3 { 48.8, 17.6, 7.6 * side }))
    add_child(n, rod(float3 { -33.0, 15.0, 0.0 }, float3 { -46.0, 9.0, 0.0 }, 4.0, 2.4, skin))
    add_child(n, rod(float3 { -46.0, 9.0, 0.0 }, float3 { -56.0, 4.0, 0.0 }, 2.4, 0.6, skin))
    for(4) k:
        add_child(n, cone(0.1, 1.2, 2.6, keel, float3 { -36.0 - float(k) * 5.0, 17.5 - float(k) * 2.4, 0.0 }, float3 { 0.0, 0.0, 20.0 }, 6))
    return C.y + R.y - 1.0

def deck_catapult(n:MNode, s:SStyle, d:float, x0:float, h:float = 42.0):
    let bar = d + h * 24.0 / 42.0
    for([1.0, -1.0]) side:
        siege_bundle(n, float3 { x0 + 10.0, d, 8.5 * side }, float3 { x0 + 10.0, bar, 8.5 * side }, 1.9, s, 2)
        siege_bundle(n, float3 { x0 + 17.0, d, 8.5 * side }, float3 { x0 + 10.0, bar - 7.0, 8.5 * side }, 1.1, s, 1)
    siege_bundle(n, float3 { x0 + 10.0, bar, -10.5 }, float3 { x0 + 10.0, bar, 10.5 }, 1.8, s, 3)
    add_child(n, rod(float3 { x0 + 7.8, bar, -6.0 }, float3 { x0 + 7.8, bar, 6.0 }, 2.2, 2.2, s.team))
    let pivot = float3 { x0 - 8.0, d + 3.0, 0.0 }
    add_child(n, rod(pivot + float3 { 0.0, 0.0, -8.0 }, pivot + float3 { 0.0, 0.0, 8.0 }, 2.6, 2.6, s.reed))
    let tip = float3 { x0 + 7.0, d + h, 0.0 }
    siege_bundle(n, pivot, tip, 2.0, s, 3, 1.4)
    clay_cup(n, s, tip + float3 { 0.0, 0.8, 0.0 }, 4.0)

def bolt_beast(s:SStyle) -> Spec:
    let n = mnode()
    giant_toad(n, s)
    let top = 33.0
    add_child(n, box(float3 { 20.0, 0.8, 24.0 }, s.team, float3 { -4.0, top - 1.0, 0.0 }, float3 { 0.0, 0.0, 10.0 }))
    post_bolt(n, s, top, -2.0)
    let sp = spec_of(n)
    sock(sp, "crew0_f0_reach_top", float3 { -20.0, 25.2, 0.0 })
    sock(sp, "crew1_f0_reach", float3 { -6.0, 0.0, -30.0 })
    return sp

def post_bolt(n:MNode, s:SStyle, top:float, x0:float):
    add_child(n, box(float3 { 10.0, 2.0, 10.0 }, s.dark, float3 { x0, top, 0.0 }))
    add_child(n, rod(float3 { x0, top, 0.0 }, float3 { x0, top + 6.0, 0.0 }, 1.6, 1.4, s.dark))
    let y = top + 7.0
    add_child(n, siege_beam(float3 { x0 - 18.0, y, 0.0 }, float3 { x0 + 20.0, y, 0.0 }, 2.8, 2.2, s.dark))
    let bx = x0 + 18.0
    for([1.0, -1.0]) side:
        let mid = float3 { bx - 2.0, y + 0.5, 13.0 * side }
        let end = float3 { bx - 9.0, y + 0.5, 24.0 * side }
        siege_bundle(n, float3 { bx, y + 0.5, 1.8 * side }, mid, 2.0, s, 1, 1.6)
        siege_bundle(n, mid, end, 1.6, s, 1, 1.0)
        add_child(n, rod(end, float3 { x0 - 12.0, y + 1.2, 0.0 }, 0.4, 0.4, s.lash, false))
    add_child(n, box(float3 { 4.6, 4.0, 4.6 }, s.lash, float3 { bx, y + 0.5, 0.0 }))
    add_child(n, rod(float3 { x0 - 12.0, y + 2.2, 0.0 }, float3 { x0 + 34.0, y + 2.2, 0.0 }, 1.0, 0.9, s.stalk))
    add_child(n, cone(0.1, 1.2, 6.0, plain(html("#3a2a1c")), float3 { x0 + 37.0, y + 2.2, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 8))

def giant_toad(n:MNode, s:SStyle):
    let skin = surf("frog_skin", html("#a08a52"), 6.0)
    let wart = plain(html("#5a4a26"))
    let belly = surf("frog_belly", html("#b8a478"), 5.0)
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 13.0, 8.5, 6.5 }, skin, float3 { -12.0, 9.0, 15.0 * side }, float3 { 0.0, 0.0, 18.0 }))
        add_child(n, rod(float3 { -4.0, 1.0, 18.0 * side }, float3 { 6.0, 0.8, 21.0 * side }, 2.4, 1.6, skin))
        add_child(n, rod(float3 { 12.0, 15.0, 11.0 * side }, float3 { 17.0, 1.0, 16.0 * side }, 3.6, 2.8, skin))
        for(4) t:
            add_child(n, rod(float3 { 17.0, 1.0, 16.0 * side }, float3 { 21.0, 0.6, (16.0 + (float(t) - 1.5) * 1.8) * side }, 0.8, 0.6, skin))
    add_child(n, blob(float3 { 21.0, 15.0, 19.0 }, skin, float3 { -3.0, 18.0, 0.0 }, float3 { 0.0, 0.0, 12.0 }))
    add_child(n, blob(float3 { 14.0, 6.0, 12.0 }, belly, float3 { 5.0, 9.0, 0.0 }))
    add_child(n, blob(float3 { 11.0, 8.0, 14.0 }, skin, float3 { 16.0, 20.0, 0.0 }))
    add_child(n, rod(float3 { 24.5, 17.5, -11.0 }, float3 { 26.6, 17.5, 0.0 }, 0.5, 0.5, plain(INK)))
    add_child(n, rod(float3 { 26.6, 17.5, 0.0 }, float3 { 24.5, 17.5, 11.0 }, 0.5, 0.5, plain(INK)))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 3.2, 3.0, 3.0 }, skin, float3 { 18.0, 27.0, 8.0 * side }))
        add_child(n, blob(float3 { 1.8, 1.8, 1.4 }, plain(html("#d8a830")), float3 { 20.0, 27.8, 9.4 * side }))
        add_child(n, blob(float3 { 0.6, 1.0, 0.5 }, plain(html("#140c06")), float3 { 21.2, 28.0, 10.0 * side }))
        add_child(n, blob(float3 { 5.0, 2.4, 3.0 }, wart, float3 { 10.0, 27.0, 10.0 * side }, float3 { 0.0, 0.0, -15.0 }))
    for(26) k:
        let a = float(k) * 2.39996
        let b = (float(k) * 0.618034 % 1.0) * 1.2
        let at = on_surface(float3 { -3.0, 18.0, 0.0 }, float3 { 21.0, 15.0, 19.0 }, float3 { siege_cosr(a) * siege_sinr(b), siege_cosr(b), siege_sinr(a) * siege_sinr(b) }, -0.6)
        add_child(n, blob(float3_1 * (1.0 + float(k) * 0.37 % 0.8), wart, at))

def swamp_snail(n:MNode, s:SStyle) -> float:
    let body = surf("frog_skin", html("#8a7a5a"), 8.0)
    let sole = surf("frog_belly", html("#c8b892"), 5.0)
    add_child(n, blob(float3 { 38.0, 5.5, 12.5 }, body, float3 { -2.0, 5.0, 0.0 }))
    add_child(n, blob(float3 { 37.0, 1.6, 13.9 }, sole, float3 { -2.0, 1.8, 0.0 }))
    add_child(n, rod(float3 { -30.0, 8.0, 0.0 }, float3 { -52.0, 1.8, 0.0 }, 8.0, 1.6, body))
    add_child(n, rod(float3 { 20.0, 6.0, 0.0 }, float3 { 37.0, 13.0, 0.0 }, 8.0, 6.4, body))
    add_child(n, blob(float3 { 8.0, 6.4, 7.4 }, body, float3 { 41.0, 14.0, 0.0 }))
    add_child(n, rod(float3 { 46.5, 11.0, -3.5 }, float3 { 48.0, 11.2, 0.0 }, 0.4, 0.4, plain(INK)))
    add_child(n, rod(float3 { 48.0, 11.2, 0.0 }, float3 { 46.5, 11.0, 3.5 }, 0.4, 0.4, plain(INK)))
    let eye = plain(html("#141210"))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { 43.0, 18.0, 3.0 * side }, float3 { 52.0, 36.0, 7.5 * side }, 2.4, 1.6, body))
        add_child(n, blob(float3_1 * 2.9, eye, float3 { 52.4, 37.0, 7.7 * side }))
        add_child(n, blob(float3_1 * 0.8, plain(html("#e8e4d8")), float3 { 53.6, 38.4, 8.6 * side }))
        add_child(n, rod(float3 { 47.0, 12.0, 4.0 * side }, float3 { 57.0, 7.0, 8.5 * side }, 1.9, 0.8, body))
    let whorls = [html("#c88a3c"), html("#9a6428"), html("#6e4420"), html("#4e3018")]
    let band = surf("chitin", html("#3a2410"), 6.0)
    let lip = plain(html("#ecdcb4"))
    let R0 = 19.0
    let O = float3 { -8.0, 29.0, 0.0 }
    var top = 0.0
    for(70) k:
        let th = float(k) * 0.16
        let R = R0 * pow(SIEGE_E, -0.12 * th)
        let r = R * 0.5
        let phi = -50.0 * MPI / 180.0 + th
        let at = O + float3 { siege_cosr(phi) * R, siege_sinr(phi) * R, 0.0 }
        let shell = surf("chitin", whorls[min(int(th / (2.0 * MPI)), 3)], 6.0)
        add_child(n, blob(float3 { r * 1.1, r * 1.1, r * 1.35 }, if k % 8 == 4: band else: shell, at))
        top = max(top, at.y + r * 1.1)
        if k > 4:
            let inward = float3 { -siege_cosr(phi), -siege_sinr(phi), 0.0 } * r * 0.8
            for([1.0, -1.0]) side:
                add_child(n, blob(float3_1 * clamp(r * 0.28, 0.7, 2.0), band, at + inward + float3 { 0.0, 0.0, r * 1.05 * side }))
    add_child(n, ring(R0 * 0.42, R0 * 0.56, lip, O + float3 { cos(-50.0) * R0 + 2.0, sin(-50.0) * R0, 0.0 }, float3 { 90.0, 0.0, 40.0 }, float3 { 1.0, 1.0, 1.3 }))
    return top

def catapult_snail(s:SStyle) -> Spec:
    let n = mnode()
    let top = swamp_snail(n, s)
    let x0 = -8.0
    let d = top + 1.0
    add_child(n, box(float3 { 30.0, 2.0, 19.0 }, s.dark, float3 { x0 - 3.0, d - 1.0, 0.0 }))
    for([x0 - 15.0, x0 + 9.0]) x:
        add_child(n, siege_beam(float3 { x, d - 2.4, -10.5 }, float3 { x, d - 2.4, 10.5 }, 2.4, 2.4, s.wood))
        for([1.0, -1.0]) side:
            add_child(n, rod(float3 { x, d - 2.4, 10.0 * side }, float3 { x * 1.3, 7.0, (if x > 0.0: 13.0 else: 7.0) * side }, 0.45, 0.45, s.rope, false))
    add_child(n, box(float3 { 30.4, 2.4, 1.2 }, s.team, float3 { x0 - 3.0, d - 1.0, 9.9 }))
    add_child(n, box(float3 { 30.4, 2.4, 1.2 }, s.team, float3 { x0 - 3.0, d - 1.0, -9.9 }))
    deck_catapult(n, s, d, x0, 32.0)
    clay_cup(n, s, float3 { x0 + 4.0, 4.0, -22.0 }, 4.0)
    let sp = spec_of(n)
    sock(sp, "crew0_f0_raise_top", float3 { x0 - 17.0, d, 0.0 })
    sock(sp, "crew1_f0_reach", float3 { x0 - 8.0, 0.0, -30.0 })
    return sp

// ------------------------------------------------------------------ carts (D-127)

def handcart(s:SStyle, loaded:bool = true) -> Spec:
    let n = mnode()
    let wr = 6.5
    let y = wr + 1.6
    for([1.0, -1.0]) side:
        siege_wheel(n, float3 { 2.0, wr, 8.6 * side }, wr, 1.6, s)
    add_child(n, rod(float3 { 2.0, wr, -9.6 }, float3 { 2.0, wr, 9.6 }, 0.6, 0.6, s.dark, false))
    let plank = surf("wood_grain", float3_1, 8.0)
    add_child(n, box(float3 { 22.0, 1.2, 13.0 }, plank, float3 { 2.0, y, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 22.0, 3.6, 0.8 }, plank, float3 { 2.0, y + 2.3, 6.3 * side }))
    for([-8.6, 12.6]) x:
        add_child(n, box(float3 { 0.8, 3.6, 13.0 }, plank, float3 { x, y + 2.3, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { -8.0, y + 0.5, 4.6 * side }, float3 { -18.5, y + 3.6, 4.6 * side }, 1.0, 1.0, s.dark))
        add_child(n, rod(float3 { -7.0, y, 4.6 * side }, float3 { -7.6, 0.4, 4.6 * side }, 0.45, 0.45, s.dark))
    if loaded:
        cart_load(n, s, float3 { 2.0, y, 0.0 })
    return sock(spec_of(n), "crew0_f0_reach", float3 { -24.5, 0.0, 0.0 })

def cart_load(n:MNode, s:SStyle, at:float3):
    let plank = surf("wood_grain", float3_1, 8.0)
    add_child(n, box(float3 { 7.5, 6.0, 7.5 }, s.dark, at + float3 { 4.5, 3.6, 1.8 }))
    add_child(n, box(float3 { 8.2, 0.5, 8.2 }, s.team, at + float3 { 4.5, 6.9, 1.8 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 5.0, 3.2, 0.4 }, s.team, at + float3 { 4.5, 5.2, 1.8 + 4.0 * side }))
    add_child(n, box(float3 { 5.0, 4.0, 5.0 }, plank, at + float3 { -5.0, 2.6, -3.0 }, float3 { 0.0, 20.0, 0.0 }))
    let sack = surf("cloth", html("#c8b48a"), 3.0)
    add_child(n, blob(float3 { 3.2, 2.4, 2.6 }, sack, at + float3 { -5.5, 2.6, 3.4 }))
    add_child(n, blob(float3 { 2.8, 2.2, 2.4 }, sack, at + float3 { -2.5, 5.6, -2.6 }))
    let jar = surf("bld_daub", float3 { 1.05, 0.62, 0.42 }, 6.0)
    add_child(n, cone(1.2, 2.6, 5.5, jar, at + float3 { 7.5, 3.0, -4.0 }))
    add_child(n, cone(0.8, 1.2, 1.2, jar, at + float3 { 7.5, 6.2, -4.0 }))

def cart_beast(take:string) -> string:
    switch take:
        case "timber": return "pony"
        case "junk": return "cat"
        case "forest": return "beetle"
        case "spooky": return "spider"
        default: return ""

def trade_cart(take:string, c:Colours) -> Spec:
    let s = siege_style(take, c)
    return if take == "frog": cart_snail(s) else: hauled_cart(cart_beast(take), s, c)

let SHAFT = 8.0
let CART_FRONT = 12.4
let LEAD_GAP = 6.0
let LEAD_AHEAD = 16.0
def lead_legs(beast:string) -> float: return if beast == "spider": 9.0 elif beast == "newt": 3.0 else: 0.0
def hitch_drop(beast:string) -> float: return if beast == "newt": -1.2 else: 0.0

def hauled_cart(beast:string, s:SStyle, c:Colours, k:float = 1.0) -> Spec:
    let lay = harness_layout("body." + beast, c)
    let te = lay.ends[0] / k
    let n = mnode()
    let y = cart_body(n, s)
    let haul = float3 { CART_FRONT + SHAFT - te.x, 0.0, 0.0 }
    let sp = spec_of(n)
    sock(sp, "haul0_f0", haul)
    for([1.0, -1.0]) side:
        let hitch = haul + float3 { te.x, te.y - hitch_drop(beast) / k, te.z * side }
        add_child(n, siege_beam(float3 { CART_FRONT - 1.0, y + 1.0, 6.3 * side }, hitch, 1.0, 1.0, s.dark))
        sock(sp, "hitch0_" + (if side > 0.0: "near" else: "far"), hitch)
    sock(sp, "crew0_f0", haul + float3 { (lay.front_x + LEAD_AHEAD) / k, 0.0, (lay.half_width + LEAD_GAP + lead_legs(beast)) / k })
    return scaled(sp, k)

def cart_body(n:MNode, s:SStyle) -> float:
    let wr = 6.5
    let y = wr + 1.6
    for([1.0, -1.0]) side:
        siege_wheel(n, float3 { 0.0, wr, 8.6 * side }, wr, 1.6, s)
    add_child(n, rod(float3 { 0.0, wr, -9.6 }, float3 { 0.0, wr, 9.6 }, 0.6, 0.6, s.dark, false))
    let plank = if s.fam != "spooky": surf("wood_grain", float3_1, 8.0) else: s.wood
    add_child(n, box(float3 { 24.0, 1.2, 13.0 }, plank, float3 { 0.0, y, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 24.0, 3.6, 0.8 }, plank, float3 { 0.0, y + 2.3, 6.3 * side }))
    for([-11.6, 11.6]) x:
        add_child(n, box(float3 { 0.8, 3.6, 13.0 }, plank, float3 { x, y + 2.3, 0.0 }))
    cart_load(n, s, float3 { 0.0, y, 0.0 })
    add_child(n, rod(float3 { -11.0, y, 0.0 }, float3 { -13.0, 0.3, 0.0 }, 0.5, 0.5, s.dark))
    return y

let SNAIL_K = 0.55
let SNAIL_BAND_X = -24.0

def cart_snail(s:SStyle) -> Spec:
    let n = mnode()
    let y = cart_body(n, s)
    let beast = mnode()
    beast.scl = float3_1 * SNAIL_K
    let at = CART_FRONT + SHAFT + (-SNAIL_BAND_X + 3.0) * SNAIL_K
    beast.pos = float3 { at, 0.0, 0.0 }
    add_child(n, beast)
    swamp_snail(beast, s)
    let f = sqrt(1.0 - pow((SNAIL_BAND_X + 2.0) / 38.0, 2.0))
    let pad = surf("leather", float3 { 0.42, 0.27, 0.16 }, 3.0)
    let pts = []::float3
    for(9) i:
        let a = 180.0 * float(i) / 8.0
        pts.push(float3 { SNAIL_BAND_X, 5.0 + (5.5 * f + 0.6) * sin(a), (12.5 * f + 0.6) * cos(a) } * SNAIL_K + beast.pos)
    for(8) i:
        add_child(n, rod(pts[i], pts[i + 1], 0.55, 0.55, pad))
    let sp = spec_of(n)
    for([1.0, -1.0]) side:
        let end = pts[if side > 0.0: 0 else: 8]
        add_child(n, siege_beam(float3 { CART_FRONT - 1.0, y + 1.0, 6.3 * side }, end, 1.0, 1.0, s.dark))
        add_child(n, blob(float3_1 * 0.9, surf("bronze", float3_1, 3.0), end))
    sock(sp, "crew0_f0", float3 { at + 50.0 * SNAIL_K, 0.0, 12.5 * SNAIL_K + LEAD_GAP + 7.0 })
    return scaled(sp, 1.25)

// ------------------------------------------------------------------ the draught harness

let HARNESS_GAP = 0.5
let TRACE_TAIL = 2.5

class HarnessLayout:
    band:[float3]
    backs:[[float3]]
    traces:[[float3]]
    ends:[float3]
    half_width:float
    front_x:float

let harness_layouts = dictionary<string, HarnessLayout>(8)

// Every mesh vertex under n, in n's parent's space (_cloud).
def siege_cloud_into(n:MNode, t:Xform, out:[float3]) -> void:
    let m = n.mesh
    if m:
        for(m.p) v: out.push(xf(t, v))
    for(n.kids) k: siege_cloud_into(k, xmul(t, node_xform(k)), out)

def siege_cloud(n:MNode) -> [float3]:
    let out = []::float3
    siege_cloud_into(n, node_xform(n), out)
    return out

// harness_fitted: a draught harness fitted on its beast (nil for any other harness).
def harness_fitted(armour_id:string, body_id:string, c:Colours) -> Spec?:
    if armour_id != "harness.draught": return nil
    let lay = harness_layout(body_id, c)
    let n = mnode()
    let leather = surf("leather", float3 { 0.42, 0.27, 0.16 }, 3.0)
    let loops = append(append([lay.band], lay.backs), lay.traces)
    for(loops) lp:
        for(lp.length - 1) i:
            add_child(n, rod(lp[i], lp[i + 1], 0.55, 0.55, leather))
    let brass = surf("bronze", float3_1, 3.0)
    for(lay.traces) t:
        add_child(n, blob(float3_1 * 0.85, brass, t[0]))
        add_child(n, blob(float3_1 * 0.85, brass, t[t.length - 1]))
    let sp = spec_of(n)
    sock(sp, "trace_near", lay.ends[0])
    sock(sp, "trace_far", lay.ends[1])
    return sp

def harness_layout(body_id:string, c:Colours) -> HarnessLayout:
    let known = harness_layouts.get(body_id)
    if known: return known
    let built = build_model(body_id, c)
    assert built
    let b = built
    let pts = siege_cloud(b.node)
    let fore = []::float
    let hind = []::float
    var hip_y = -1000000000.0
    for(b.anchors) a:
        if a.more.length > 1 and a.more[1] != 0.0: hind.push(a.pos.x) else: fore.push(a.pos.x)
        hip_y = max(hip_y, a.pos.y)
    var xf_ = 0.0
    if fore.length:
        xf_ = -1000000000.0
        for(fore) x: xf_ = max(xf_, x)
    var xh = xf_ - 10.0
    if hind.length:
        xh = 1000000000.0
        for(hind) x: xh = min(xh, x)
    let xm = (xf_ + xh) * 0.5
    var lo = 1000000000.0
    var hi = -1000000000.0
    for(pts) p:
        if abs(p.x - xm) < 1.5:
            lo = min(lo, p.y)
            hi = max(hi, p.y)
    var y = lo + 0.55 * (hi - lo)
    if hip_y + 1.0 < hi - 1.0:
        y = max(y, hip_y + 1.0)
    let band = siege_contour(pts, float3 { xm, y, 0.0 }, true, 0.0, 180.0, 12)
    var half = 0.0
    var front = -1000000000.0
    for(band) p:
        half = max(half, abs(p.z))
        front = max(front, p.x)
    var rear = xh
    for(pts) p:
        if abs(p.y - y) < 1.5 and abs(p.z) >= 0.4 * half:
            rear = min(rear, p.x)
    let backs = []::[float3]
    for([xf_ - 2.5, xh + 2.5]) bx:
        backs.push(siege_contour(pts, float3 { bx, y, 0.0 }, false, 0.0, 180.0, 9))
    let traces = [[band[0]], [band[band.length - 1]]]
    var x = xm - 2.0
    while x > rear + 1.0:
        var w = 0.0
        for(pts) p:
            if abs(p.y - y) < 1.0 and abs(p.x - x) < 0.8:
                w = max(w, abs(p.z))
        if w > 0.0:
            traces[0].push(float3 { x, y, w + HARNESS_GAP })
            traces[1].push(float3 { x, y, -w - HARNESS_GAP })
        x -= 2.0
    let ends = [float3 { rear - TRACE_TAIL, y, traces[0][traces[0].length - 1].z }, float3 { rear - TRACE_TAIL, y, traces[1][traces[1].length - 1].z }]
    traces[0].push(ends[0])
    traces[1].push(ends[1])
    let lay = HarnessLayout { band, backs, traces, ends, half, front }
    harness_layouts.set(body_id, lay)
    return lay

// _contour, its angles in degrees: `up` a horizontal band (else over the back).
def siege_contour(pts:[float3], centre:float3, up:bool, a0:float, a1:float, n:int) -> [float3]:
    let bins = []::float
    for(n + 1): bins.push(0.0)
    let step = (a1 - a0) / float(n)
    for(pts) p:
        let d = p - centre
        let u = d.z
        let v = if up: d.x else: d.y
        let skip = if up: abs(d.y) > 1.0 else: abs(d.x) > 1.0 or d.y < -1.0
        if not skip:
            var ang = (atan2(float2 { u, v }) - a0) % 360.0
            if ang < 0.0: ang += 360.0
            let i = round(ang / step)
            if i >= 0 and i <= n:
                bins[i] = max(bins[i], magnitude(float2 { u, v }))
    for(n + 1) i:
        if bins[i] == 0.0:
            bins[i] = max(bins[max(i - 1, 0)], bins[min(i + 1, n)])
    return map(n + 1) i:
        let ang = a0 + step * float(i)
        let r = bins[i] + HARNESS_GAP
        centre + (if up: float3 { sin(ang) * r, 0.0, cos(ang) * r } else: float3 { 0.0, sin(ang) * r, cos(ang) * r })

// ------------------------------------------------------------------ pushed home (D-127)

def pushed_home(kind:string, s:SStyle) -> Spec:
    if kind == "barrow": return scrap_barrow(s, "stone")
    let spec = handcart(s, false)
    gold_load(spec.node, s, float3 { 2.0, 8.1, 0.0 })
    return spec

def scrap_barrow(s:SStyle, load:string) -> Spec:
    let n = mnode()
    let wr = 6.0
    siege_wheel(n, float3 { 13.0, wr, 0.0 }, wr, 2.0, s)
    let y = 9.0
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { 13.0, wr, 1.8 * side }, float3 { -6.0, y, 5.5 * side }, 0.7, 0.7, s.pipe))
        add_child(n, rod(float3 { -6.0, y, 5.5 * side }, float3 { -18.0, y + 3.0, 5.0 * side }, 0.7, 0.7, s.pipe))
        add_child(n, rod(float3 { -4.0, y, 5.5 * side }, float3 { -5.0, 0.4, 5.5 * side }, 0.6, 0.6, s.pipe))
    add_child(n, box(float3 { 20.0, 1.0, 12.0 }, s.wood2, float3 { 2.0, y + 0.5, 0.0 }))
    if load == "stone":
        let rock = surf("rock", float3 { 0.85, 0.82, 0.76 }, 3.0)
        for([[float3 { -2.0, y + 3.0, 2.0 }, float3 { 3.6, 2.4, 3.0 }], [float3 { 4.0, y + 2.8, -1.5 }, float3 { 3.2, 2.2, 3.4 }],
             [float3 { 1.0, y + 5.0, 0.0 }, float3 { 2.8, 2.0, 2.6 }], [float3 { 8.0, y + 2.2, 2.4 }, float3 { 2.4, 1.8, 2.2 }]]) b:
            add_child(n, blob(b[1], rock, b[0], float3 { 0.0, b[0].x * 11.0, 12.0 }))
        add_child(n, box(float3 { 5.0, 0.4, 5.0 }, s.team, float3 { -4.0, y + 1.2, -3.6 }, float3 { 0.0, 20.0, 8.0 }))
    else:
        add_child(n, box(float3 { 6.0, 5.0, 6.0 }, s.wood, float3 { -2.0, y + 3.5, 2.5 }))
        add_child(n, cone(2.6, 2.6, 6.0, s.plate, float3 { 6.0, y + 4.0, -2.5 }))
        add_child(n, ring(2.4, 2.8, s.metal, float3 { 6.0, y + 5.5, -2.5 }))
        add_child(n, cone(3.2, 3.2, 2.2, s.ammo, float3 { 2.0, y + 2.0, -3.0 }, float3_0, 14))
        add_child(n, box(float3 { 6.4, 0.4, 6.4 }, s.team, float3 { -2.0, y + 6.2, 2.5 }))
    return sock(spec_of(n), "crew0_f0_reach", float3 { -24.0, 0.0, 0.0 })

def gold_load(n:MNode, s:SStyle, at:float3):
    let sack = surf("cloth", html("#c8b48a"), 3.0)
    let gold = plain(html("#f2c440"))
    for([float3 { -3.0, 2.6, 2.2 }, float3 { 3.0, 2.4, -2.0 }, float3 { 0.0, 4.6, 0.4 }]) b:
        add_child(n, blob(float3 { 3.2, 2.6, 3.0 }, sack, at + b))
        for(3) k:
            add_child(n, blob(float3 { 0.8, 0.65, 0.75 }, gold, at + b + float3 { -0.8 + float(k) * 0.8, 2.3, 0.6 - float(k) * 0.5 }))
    add_child(n, box(float3 { 5.0, 0.4, 4.0 }, s.team, at + float3 { 4.5, 1.0, 3.4 }))

// ------------------------------------------------------------------ war beasts (D-129)

// howdah: its riders' sockets go on `sp`.
def howdah(sp:Spec, n:MNode, s:SStyle, at:float3, L:float, wd:float, riders:int = 2):
    add_child(n, box(float3 { L, 1.4, wd }, s.dark, at))
    for([-L * 0.5 + 0.6, L * 0.5 - 0.6]) x:
        for([1.0, -1.0]) side:
            add_child(n, rod(at + float3 { x, 0.0, wd * 0.5 * side }, at + float3 { x, 5.0, wd * 0.5 * side }, 0.45, 0.45, s.dark))
    for([1.0, -1.0]) side:
        add_child(n, rod(at + float3 { -L * 0.5, 5.0, wd * 0.5 * side }, at + float3 { L * 0.5, 5.0, wd * 0.5 * side }, 0.4, 0.4, s.dark))
        add_child(n, box(float3 { L * 0.8, 8.0, 0.4 }, s.team, at + float3 { 0.0, -4.0, (wd * 0.5 + 0.3) * side }, float3 { 10.0 * side, 0.0, 0.0 }))
    for([-L * 0.5, L * 0.5]) x:
        add_child(n, rod(at + float3 { x, 5.0, -wd * 0.5 }, at + float3 { x, 5.0, wd * 0.5 }, 0.4, 0.4, s.dark))
    sp.sockets = dictionary<string, float3>(11)
    if riders == 1:
        sock(sp, "crew0_f0_top", at + float3 { 0.0, 0.7, 0.0 })
    else:
        sock(sp, "crew0_f0_top", at + float3 { L * 0.05, 0.7, wd * 0.3 })
        sock(sp, "crew1_f0_top", at + float3 { -L * 0.05, 0.7, -wd * 0.3 })

class EleMats:
    hide:MMat
    dark:MMat
    ivory:MMat
    bronze:MMat

let ELEPHANT_NECK = float3 { 28.5, 42.0, 0.0 }

def elephant_mats() -> EleMats:
    return EleMats { surf("hide", float3 { 0.62, 0.6, 0.58 }, 6.0), surf("hide", float3 { 0.45, 0.43, 0.42 }, 6.0), plain(html("#ece2c8")), surf("bronze", float3_1, 3.0) }

def elephant(s:SStyle, with_howdah:bool, play:bool = false) -> Spec:
    let n = mnode()
    let m = elephant_mats()
    let hips = []::float3
    for([13.0, -13.0]) lx:
        for([1.0, -1.0]) side:
            let x = lx + (if side > 0.0: 2.0 else: -1.0)
            let hip = float3 { x, 30.0, 8.5 * side }
            if play: hips.push(hip)
            else: elephant_leg(n, hip, side, m)
    add_child(n, blob(float3 { 26.0, 16.0, 14.5 }, m.hide, float3 { 0.0, 36.0, 0.0 }))
    add_child(n, blob(float3 { 12.0, 13.0, 12.0 }, m.hide, float3 { 18.0, 40.0, 0.0 }))
    if not play:
        elephant_head(n, ELEPHANT_NECK, m)
    add_child(n, rod(float3 { -25.0, 38.0, 0.0 }, float3 { -29.0, 22.0, 0.0 }, 1.0, 0.6, m.hide))
    let out = spec_of(n)
    if with_howdah:
        howdah(out, n, s, float3 { -3.0, 52.5, 0.0 }, 22.0, 18.0)
        add_child(n, box(float3 { 26.0, 0.6, 30.0 }, s.trim, float3 { -3.0, 51.6, 0.0 }))
    else:
        for([1.0, -1.0]) side:
            add_child(n, box(float3 { 30.0, 13.0, 0.5 }, s.trim, float3 { -1.0, 40.0, 15.0 * side }, float3 { 8.0 * side, 0.0, 0.0 }))
            add_child(n, box(float3 { 30.0, 1.8, 0.6 }, s.team, float3 { -1.0, 33.5, 15.9 * side }, float3 { 8.0 * side, 0.0, 0.0 }))
        add_child(n, dome(float3 { 5.5, 3.0, 8.5 }, m.bronze, float3 { 30.5, 49.5, 0.0 }))
        add_child(n, box(float3 { 10.0, 1.0, 12.0 }, s.dark, float3 { 17.0, 51.5, 0.0 }))
        sock(out, "crew0_f0_top", float3 { 17.0, 52.2, 0.0 })
    if play:
        sock(out, "head", ELEPHANT_NECK)
        out.anchors = beast_hips(hips)
    return out

def elephant_leg(n:MNode, hip:float3, side:float, m:EleMats):
    add_child(n, rod(hip, hip + float3 { 0.0, -25.0, 0.5 * side }, 5.6, 5.0, m.hide))
    add_child(n, cone(5.6, 5.8, 2.4, m.dark, hip + float3 { 0.0, -28.8, 0.5 * side }))
    for(3) t:
        let a = -40.0 + float(t) * 40.0
        add_child(n, blob(float3 { 1.2, 1.0, 1.0 }, m.ivory, hip + float3 { 5.2 * cos(a), -28.6, 0.5 * side + 5.2 * sin(a) }))

def elephant_head(n:MNode, at:float3, m:EleMats):
    let o = at - ELEPHANT_NECK
    add_child(n, blob(float3 { 10.0, 10.5, 9.5 }, m.hide, o + float3 { 28.0, 41.0, 0.0 }))
    add_child(n, blob(float3 { 5.0, 4.0, 8.0 }, m.dark, o + float3 { 30.0, 49.0, 0.0 }))
    let trunk = [float3 { 35.0, 38.0, 0.0 }, float3 { 39.0, 30.0, 0.0 }, float3 { 40.5, 20.0, 0.0 }, float3 { 40.0, 11.0, 0.0 }, float3 { 42.5, 6.0, 0.0 }]
    let tr = [4.2, 3.4, 2.8, 2.2, 1.6]
    siege_limb(n, map(trunk) p: o + p, tr, m.hide)
    for([1.0, -1.0]) side:
        let ear = cone(9.5, 9.5, 0.8, m.dark, o + float3 { 24.0, 42.0, 9.0 * side }, SIEGE_X90, 20)
        ear.scl = float3 { 0.8, 1.0, 1.15 }
        add_child(n, ear)
        add_child(n, rod(o + float3 { 34.0, 34.0, 4.0 * side }, o + float3 { 43.0, 30.0, 6.0 * side }, 1.4, 0.7, m.ivory))
        add_child(n, cone(0.4, 1.2, 2.2, m.bronze, o + float3 { 43.5, 29.8, 6.1 * side }, float3 { 0.0, 0.0, -75.0 }))
        add_child(n, blob(float3 { 1.1, 1.1, 0.8 }, plain(html("#1a1412")), o + float3 { 32.5, 44.0, 6.8 * side }))

def beast_hips(hips:[float3], hind:bool = false) -> [Anchor]:
    return map(hips) h:
        let front = h.x > 0.0
        let near = h.z > 0.0
        anchor(h, if front == near: 0.0 else: MPI, if near: 1 else: -1, [0.0, if hind and not front: 1.0 else: 0.0])

def siege_deck(n:MNode, s:SStyle, at:float3, L:float, wd:float, cloth:float = 7.0) -> float:
    add_child(n, box(float3 { L, 1.6, wd }, s.dark, at + float3 { 0.0, -0.8, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { L * 0.8, cloth, 0.4 }, s.team, at + float3 { 0.0, -cloth * 0.5 - 0.6, (wd * 0.5 + 0.4) * side }, float3 { 10.0 * side, 0.0, 0.0 }))
        for([-L * 0.5 + 0.6, L * 0.5 - 0.6]) x:
            add_child(n, rod(at + float3 { x, 0.0, wd * 0.5 * side }, at + float3 { x, 4.5, wd * 0.5 * side }, 0.45, 0.45, s.dark))
        add_child(n, rod(at + float3 { -L * 0.5, 4.5, wd * 0.5 * side }, at + float3 { L * 0.5, 4.5, wd * 0.5 * side }, 0.4, 0.4, s.dark))
    return at.y

class BoarMats:
    fur:MMat
    dark:MMat
    bristle:MMat
    hoof:MMat
    ivory:MMat
    snout:MMat

let BOAR_NECK = float3 { 24.0, 32.0, 0.0 }

def boar_mats() -> BoarMats:
    return BoarMats { surf("rat_fur", float3 { 0.42, 0.33, 0.27 }, 5.0), surf("rat_fur", float3 { 0.26, 0.21, 0.18 }, 4.0),
        surf("mane", float3 { 0.78, 0.68, 0.54 }, 3.0), plain(html("#1e1814")), plain(html("#f0e6cc")), surf("skin", float3 { 0.62, 0.45, 0.4 }, 4.0) }

def war_boar(s:SStyle, with_howdah:bool, play:bool = false) -> Spec:
    let n = mnode()
    let m = boar_mats()
    let hips = []::float3
    for([18.0, -19.0]) x:
        for([1.0, -1.0]) side:
            if play:
                hips.push(float3 { x - (if x > 0.0: 4.0 else: 0.0), 28.0, (if x > 0.0: 11.0 else: 9.5) * side })
            else:
                boar_leg(n, float3 { x, 28.0, 9.0 * side }, side, x > 0.0, m)
    add_child(n, blob(float3 { 26.0, 13.0, 13.0 }, m.fur, float3 { -4.0, 30.0, 0.0 }))
    add_child(n, blob(float3 { 16.0, 18.0, 15.0 }, m.fur, float3 { 12.0, 34.0, 0.0 }))
    add_child(n, blob(float3 { 11.0, 10.0, 10.0 }, m.dark, float3 { -20.0, 30.0, 0.0 }))
    if not play:
        boar_head(n, BOAR_NECK, m)
    for(14) k:
        let x = 28.0 - float(k) * 4.0
        var top = if x > -3.0: 34.0 + 18.0 * sqrt(max(0.0, 1.0 - pow((x - 12.0) / 17.0, 2.0))) else: 30.0 + 13.0 * sqrt(max(0.0, 1.0 - pow((x + 4.0) / 26.0, 2.0)))
        if x > 24.0: top = 40.0
        let h = (if x > 4.0: 11.0 else: 6.0) + float(k % 3) * 1.5
        add_child(n, cone(0.2, 2.6, h, m.bristle, float3 { x, top + h * 0.3, (float(k % 2) - 0.5) * 1.6 }, float3 { 0.0, 0.0, 32.0 }, 6))
    siege_limb(n, [float3 { -30.0, 34.0, 0.0 }, float3 { -33.0, 27.0, 0.0 }, float3 { -32.0, 22.0, 0.0 }], [1.0, 0.7, 0.5], m.dark)
    add_child(n, blob(float3 { 1.2, 2.4, 1.2 }, m.bristle, float3 { -32.0, 21.0, 0.0 }))
    for([1.0, -1.0]) side:
        for(3) k:
            let fk = float(k)
            let at = float3 { 10.0 - fk * 11.0, 31.0 - abs(fk - 0.5) * 1.0, (14.2 - abs(fk - 1.0) * 0.6) * side }
            add_child(n, box(float3 { 10.5, 12.0, 0.8 }, if k != 1: s.plate else: s.plate2, at, float3 { 8.0 * side, 0.0, 4.0 - fk * 4.0 }))
            for([float2 { -4.0, 5.0 }, float2 { 4.0, 5.0 }, float2 { -4.0, -5.0 }, float2 { 4.0, -5.0 }]) r:
                add_child(n, blob(float3_1 * 0.6, s.rivet, at + float3 { r.x, r.y, 0.6 * side }))
    let sp = spec_of(n)
    if with_howdah:
        let y = siege_deck(n, s, float3 { -6.0, 46.5, 0.0 }, 22.0, 18.0)
        add_child(n, box(float3 { 26.0, 0.8, 28.0 }, s.wood2, float3 { -6.0, 45.3, 0.0 }))
        for([1.0, -1.0]) side:
            siege_chain(n, float3 { -6.0, 45.0, 14.0 * side }, float3 { -6.0, 22.0, 12.5 * side }, s.metal)
        siege_pennant(n, s, float3 { -16.4, y, -8.0 }, 14.0, 4.5)
        sock(sp, "crew0_f0_top", float3 { 0.0, y + 0.7, 3.0 })
        sock(sp, "crew1_f0_top", float3 { -11.5, y + 0.7, -3.0 })
    else:
        add_child(n, dome(float3 { 18.0, 4.0, 15.0 }, s.plate, float3 { -6.0, 42.5, 0.0 }))
        add_child(n, dome(float3 { 8.0, 4.5, 9.0 }, s.plate2, float3 { 32.0, 38.5, 0.0 }))
        add_child(n, cone(0.3, 1.8, 8.0, s.pipe, float3 { 34.5, 44.5, 0.0 }, float3 { 0.0, 0.0, -35.0 }, 10))
        add_child(n, box(float3 { 12.0, 1.6, 12.0 }, s.team, float3 { 9.0, 52.4, 0.0 }))
        add_child(n, box(float3 { 9.0, 1.4, 9.0 }, s.dark, float3 { 9.0, 53.6, 0.0 }))
        add_child(n, rod(float3 { -8.0, 46.0, 0.0 }, float3 { -8.0, 70.0, 0.0 }, 0.6, 0.5, s.pipe))
        add_child(n, slab([float2 { 0.0, 0.0 }, float2 { -10.0, -1.0 }, float2 { -9.0, -6.0 }, float2 { -11.0, -11.0 }, float2 { 0.0, -10.0 }], 0.4, s.team, float3 { -8.2, 69.0, 0.0 }))
        sock(sp, "crew0_f0_top", float3 { 9.0, 54.3, 0.0 })
    if play:
        sock(sp, "head", BOAR_NECK)
        sp.anchors = beast_hips(hips, true)
    return sp

def boar_leg(n:MNode, hip:float3, side:float, fore:bool, m:BoarMats):
    let d = if fore: 1.0 else: -1.0
    siege_limb(n, [hip, hip + float3 { 2.5 * d, -16.0, 0.5 * side }, hip + float3 { 1.0, -25.4, 0.5 * side }], [6.0, 3.2, 2.3], if fore: m.fur else: m.dark)
    add_child(n, cone(1.8, 2.6, 2.8, m.hoof, hip + float3 { 1.5, -26.6, 0.5 * side }))

def boar_head(n:MNode, at:float3, m:BoarMats):
    let o = at - BOAR_NECK
    add_child(n, blob(float3 { 13.0, 10.5, 9.0 }, m.fur, o + float3 { 32.0, 31.0, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    add_child(n, rod(o + float3 { 37.0, 28.0, 0.0 }, o + float3 { 51.0, 22.0, 0.0 }, 7.0, 4.6, m.fur))
    add_child(n, cone(4.8, 4.8, 1.6, m.snout, o + float3 { 52.0, 21.6, 0.0 }, float3 { 0.0, 0.0, -68.0 }, 16))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.7, 0.9, 0.6 }, m.hoof, o + float3 { 52.8, 22.0, 1.8 * side }))
        siege_limb(n, [o + float3 { 45.0, 21.0, 4.5 * side }, o + float3 { 51.0, 22.5, 8.5 * side }, o + float3 { 54.5, 29.0, 9.5 * side }, o + float3 { 52.0, 34.0, 8.5 * side }], [2.3, 1.9, 1.2, 0.4], m.ivory)
        add_child(n, blob(float3 { 1.3, 1.1, 0.9 }, plain(html("#120c08")), o + float3 { 37.5, 33.0, 7.0 * side }))
        add_child(n, blob(float3 { 0.45, 0.45, 0.4 }, plain(html("#d8a040")), o + float3 { 38.3, 33.4, 7.7 * side }))
        add_child(n, cone(0.4, 3.2, 7.0, m.dark, o + float3 { 27.0, 42.0, 6.0 * side }, float3 { 25.0 * side, 0.0, 20.0 }, 8))

let TARANTULA_MOUTH = float3 { 23.0, 15.0, 0.0 }
let TARANTULA_FAN = [-45.0, -12.0, 25.0, 55.0]
let TARANTULA_HIP_Z = [9.0, 11.5, 11.5, 9.5]

def tarantula(s:SStyle, with_crew:bool, patterned:bool = false, play:bool = false) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", float3 { 0.28, 0.24, 0.24 }, 4.0)
    let dark = surf("rat_fur", float3 { 0.17, 0.15, 0.16 }, 3.5)
    let band = surf("rat_fur", float3 { 0.95, 0.55, 0.25 }, 3.0)
    let eye = plain(html("#0c0a0e"))
    let C = float3 { 12.0, 18.0, 0.0 }
    let A = float3 { -16.0, 22.0, 0.0 }
    let legs = [float3 { 22.0, 30.0, 50.0 }, float3 { 16.0, 14.0, 20.0 }, float3 { 9.0, -2.0, -12.0 }, float3 { 3.0, -14.0, -34.0 }]
    let hips = []::Anchor
    for(legs) leg, i:
        for([1.0, -1.0]) side:
            hips.push(anchor(float3 { leg.x, 17.0, TARANTULA_HIP_Z[i] * side }, MPI * 0.5 * float(i) + (if side > 0.0: 0.0 else: MPI), int(side), [0.0, 0.0, TARANTULA_FAN[i]]))
    let drawn = if play: []::float3 else: legs
    for(drawn) leg:
        for([1.0, -1.0]) side:
            let hip = float3 { leg.x, 17.0, 9.0 * side }
            let knee = float3 { leg.x + (leg.y - leg.x) * 0.55, 34.0, 24.0 * side }
            let ankle = float3 { leg.x + (leg.z - leg.x) * 0.85, 12.0, 36.0 * side }
            let foot = float3 { leg.z, 0.8, 39.0 * side }
            siege_limb(n, [hip, knee], [3.4, 3.0], fur)
            add_child(n, blob(float3 { 3.2, 3.2, 3.2 }, band, knee))
            siege_limb(n, [knee, ankle, foot], [2.8, 2.2, 1.4], dark)
    add_child(n, blob(float3 { 15.0, 8.0, 13.0 }, fur, C))
    let coat = if patterned: surf("rat_fur", float3 { 0.5, 0.27, 0.18 }, 4.0) else: fur
    add_child(n, blob(float3 { 19.0, 14.0, 16.0 }, coat, A, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, blob(float3 { 10.0, 6.0, 9.0 }, dark, A + float3 { -12.0, -1.0, 0.0 }))
    if not play:
        tarantula_jaws(n, TARANTULA_MOUTH, fur, dark)
    for(8) k:
        let a = 360.0 * float(k) / 8.0
        add_child(n, blob(float3_1 * (if k % 2 == 0: 1.1 else: 0.7), eye, float3 { 21.0 + cos(a) * 1.8, 25.5 + sin(a) * 0.8, sin(a) * 2.6 }))
    if patterned:
        tarantula_pattern(n, C, A, drawn)
    let sp = spec_of(n)
    let top = A + float3 { 2.0, 13.6, 0.0 }
    add_child(n, ring(0.9, 1.0, surf("cloth", html("#d8d2e4"), 3.0), A, float3 { 0.0, 0.0, 80.0 }, float3 { 17.0, 3.0, 17.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 14.0, 9.0, 0.4 }, s.team, A + float3 { 2.0, 3.0, 15.0 * side }, float3 { 30.0 * side, 0.0, 0.0 }))
        add_child(n, blob(float3 { 1.2, 1.2, 1.2 }, s.metal, A + float3 { 2.0, 9.0, 13.5 * side }))
    if with_crew:
        let y = siege_deck(n, s, top + float3 { 0.0, 1.4, 0.0 }, 18.0, 14.0, 4.0)
        sock(sp, "crew0_f0_top", float3 { top.x + 4.5, y + 0.7, 2.5 })
        sock(sp, "crew1_f0_top", float3 { top.x - 4.5, y + 0.7, -2.5 })
    else:
        add_child(n, box(float3 { 10.0, 1.4, 12.0 }, s.dark, top))
        add_child(n, rod(top, top + float3 { -2.0, 30.0, 0.0 }, 0.6, 0.5, s.wood))
        add_child(n, blob(float3 { 1.6, 2.0, 1.6 }, s.metal, top + float3 { -2.0, 31.2, 0.0 }))
        add_child(n, slab([float2 { 0.0, 0.0 }, float2 { -12.0, 0.0 }, float2 { -12.0, -10.0 }, float2 { -9.0, -8.0 }, float2 { -6.0, -11.0 }, float2 { -3.0, -8.0 }, float2 { 0.0, -10.0 }], 0.4, s.team, top + float3 { -2.2, 29.0, 0.0 }))
    if play:
        sock(sp, "head", TARANTULA_MOUTH)
        sp.anchors = hips
    return sp

def tarantula_jaws(n:MNode, at:float3, fur:MMat, dark:MMat):
    let o = at - TARANTULA_MOUTH
    let fang = plain(html("#141012"))
    add_child(n, blob(float3 { 3.0, 3.0, 6.5 }, dark, o + float3 { 24.0, 14.5, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 4.0, 5.0, 3.0 }, dark, o + float3 { 26.0, 14.0, 3.4 * side }, float3 { 0.0, 0.0, -20.0 }))
        add_child(n, cone(0.1, 1.2, 5.0, fang, o + float3 { 28.5, 9.0, 3.0 * side }, float3 { 0.0, 0.0, -15.0 }, 8))
        siege_limb(n, [o + float3 { 24.0, 15.0, 6.0 * side }, o + float3 { 32.0, 18.0, 9.0 * side }, o + float3 { 36.0, 6.0, 10.0 * side }], [1.8, 1.6, 1.4], fur)

def tarantula_pattern(n:MNode, C:float3, A:float3, legs:[float3]):
    let pale = plain(html("#e6d2a4"))
    let straw = surf("rat_fur", float3 { 1.1, 0.95, 0.7 }, 3.0)
    let ray = plain(html("#141012"))
    add_child(n, blob(float3 { 15.6, 6.8, 13.6 }, pale, C + float3 { 0.0, -1.0, 0.0 }))
    add_child(n, blob(float3 { 12.0, 7.4, 10.4 }, straw, C + float3 { 0.5, 0.4, 0.0 }))
    for(8) k:
        let a = 360.0 * (float(k) + 0.5) / 8.0
        let tip = C + float3 { cos(a) * 9.0, 4.6, sin(a) * 8.0 }
        add_child(n, rod(C + float3 { 0.5, 7.9, 0.0 }, tip, 0.55, 0.3, ray))
    add_child(n, blob(float3 { 2.2, 0.8, 1.6 }, ray, C + float3 { 0.5, 7.8, 0.0 }))
    let tilt = axis_angle(SIEGE_BACK, -10.0)
    let R = float3 { 19.0, 14.0, 16.0 }
    def skin(lx:float, lz:float, lift:float) -> float3, float3:
        let ly = R.y * sqrt(max(0.0, 1.0 - pow(lx / R.x, 2.0) - pow(lz / R.z, 2.0)))
        let local = float3 { lx, ly, lz }
        let nrm = normalize(float3 { lx / (R.x * R.x), ly / (R.y * R.y), lz / (R.z * R.z) })
        return A + bxf(tilt, local + nrm * lift), normalize(bxf(tilt, nrm))
    for([8.5, -7.5, -12.5]) lx:
        for([1.0, -1.0]) side:
            let a, _an = skin(lx + 2.6, 0.6 * side, 0.3)
            let b, _bn = skin(lx - 1.4, 7.0 * side, 0.3)
            add_child(n, rod(a, b, 1.4, 1.1, pale))
    for([4.0, -3.5, -10.0]) lx:
        var prev, _pn = skin(lx, -13.0, 0.2)
        for(8) i:
            let t = i + 1
            let nxt, _nn = skin(lx, -13.0 + float(t) * 26.0 / 8.0, 0.2)
            add_child(n, rod(prev, nxt, 0.75, 0.75, straw))
            prev = nxt
    let spine, _sn = skin(-15.5, 0.0, 0.3)
    add_child(n, blob(float3 { 2.0, 0.6, 1.6 }, pale, spine))
    for(18) k:
        let lx = 12.0 - float(k % 9) * 3.0
        let lz = (10.0 + float(k % 3) * 2.0) * (if k < 9: 1.0 else: -1.0)
        let at, an = skin(lx, lz, 0.0)
        add_child(n, rod(at, at + an * 2.8 + float3 { -0.8, 0.4, 0.0 }, 0.55, 0.1, if k % 2 == 0: pale else: straw))
    for(legs) leg:
        for([1.0, -1.0]) side:
            let hip = float3 { leg.x, 17.0, 9.0 * side }
            let knee = float3 { leg.x + (leg.y - leg.x) * 0.55, 34.0, 24.0 * side }
            for([0.35, 0.65]) t:
                let at = siege_lerp(hip, knee, t)
                add_child(n, rod(at + float3 { 0.0, 2.6, 0.0 }, at + float3 { -0.6, 5.4, 0.8 * side }, 0.6, 0.1, pale))
            let ankle = float3 { leg.x + (leg.z - leg.x) * 0.85, 12.0, 36.0 * side }
            add_child(n, blob(float3_1 * 2.7, pale, siege_lerp(knee, ankle, 0.45)))

let HERON_NECK = float3 { 12.5, 52.0, 0.0 }

def heron(s:SStyle, play:bool = false) -> Spec:
    let n = mnode()
    let grey = surf("hide", float3 { 0.72, 0.74, 0.78 }, 6.0)
    let dark = plain(html("#3a3c44"))
    let hips = []::Anchor
    for([1.0, -1.0]) side:
        if play:
            hips.push(anchor(float3 { 0.0, 40.0, 5.0 * side }, if side > 0.0: 0.0 else: MPI, int(side), [0.0]))
        else:
            heron_leg(n, float3 { 0.0, 40.0, 5.0 * side }, side)
    add_child(n, blob(float3 { 17.0, 9.5, 10.0 }, grey, float3 { -2.0, 46.0, 0.0 }, float3 { 0.0, 0.0, 12.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 17.0, 6.0, 3.0 }, grey, float3 { -5.0, 47.0, 8.5 * side }, float3 { 0.0, 0.0, 14.0 }))
        add_child(n, blob(float3 { 10.0, 3.0, 2.4 }, dark, float3 { -17.0, 43.5, 7.0 * side }, float3 { 0.0, 0.0, 20.0 }))
    if not play:
        heron_neck(n, HERON_NECK)
    add_child(n, box(float3 { 11.0, 0.8, 18.0 }, s.team, float3 { -7.0, 55.0, 0.0 }, float3 { 0.0, 0.0, 8.0 }))
    add_child(n, box(float3 { 8.0, 1.6, 9.0 }, s.dark, float3 { -7.0, 56.0, 0.0 }))
    let out = sock(spec_of(n), "crew0_f0_top", float3 { -7.0, 56.8, 0.0 })
    if play:
        sock(out, "head", HERON_NECK)
        out.anchors = hips
    return out

def heron_leg(n:MNode, hip:float3, side:float):
    let leg = plain(html("#8a7a4a"))
    siege_limb(n, [hip, hip + float3 { 2.0, -14.0, 1.0 * side }, hip + float3 { -2.0, -28.0, 1.0 * side }, hip + float3 { 0.0, -39.0, 1.5 * side }], [2.4, 1.3, 1.2, 1.0], leg)
    let foot = hip + float3 { 0.0, -39.2, 1.5 * side }
    for(3) t:
        add_child(n, rod(foot, hip + float3 { 6.0, -39.4, (1.5 + float(t - 1) * 3.0) * side }, 0.6, 0.4, leg))
    add_child(n, rod(foot, hip + float3 { -4.0, -39.4, 1.5 * side }, 0.6, 0.4, leg))

def heron_neck(n:MNode, at:float3):
    let o = at - HERON_NECK
    let white = surf("hide", float3 { 0.95, 0.95, 0.93 }, 6.0)
    let dark = plain(html("#3a3c44"))
    siege_limb(n, [o + float3 { 10.0, 50.0, 0.0 }, o + float3 { 16.0, 58.0, 0.0 }, o + float3 { 12.0, 66.0, 0.0 }, o + float3 { 16.0, 74.0, 0.0 }], [4.0, 3.0, 2.8, 2.8], white)
    add_child(n, blob(float3 { 4.6, 3.6, 3.4 }, white, o + float3 { 18.0, 75.0, 0.0 }))
    add_child(n, cone(0.2, 1.8, 14.0, plain(html("#c8a040")), o + float3 { 28.0, 74.0, 0.0 }, float3 { 0.0, 0.0, -93.0 }, 10))
    siege_limb(n, [o + float3 { 15.0, 77.0, 0.0 }, o + float3 { 6.0, 79.0, 0.0 }, o + float3 { 0.0, 77.0, 0.0 }], [1.0, 0.7, 0.3], dark)
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.9, 0.9, 0.6 }, plain(html("#d8b020")), o + float3 { 20.0, 76.0, 3.0 * side }))
        add_child(n, rod(o + float3 { 17.0, 75.5, 3.4 * side }, o + float3 { 22.0, 75.0, 2.4 * side }, 0.4, 0.3, dark))

let MANTIS_NECK = float3 { 4.0, 24.0, 0.0 }
let MANTIS_FAN = [-27.0, 27.0]

def mantis(s:SStyle, play:bool = false) -> Spec:
    let n = mnode()
    let green = surf("chitin", html("#6a9a3a"), 5.0)
    let dark = surf("chitin", html("#4a7028"), 4.0)
    let wing = surf("leaf", float3 { 0.75, 0.9, 0.55 }, 10.0)
    let hips = []::Anchor
    for([float2 { 2.0, 12.0 }, float2 { -6.0, -16.0 }]) leg:
        for([1.0, -1.0]) side:
            if play:
                let fore = leg.x > 0.0
                hips.push(anchor(float3 { leg.x, 22.0, 4.0 * side }, if fore == (side > 0.0): 0.0 else: MPI, int(side), [0.0, 0.0, MANTIS_FAN[if fore: 0 else: 1]]))
            else:
                siege_limb(n, [float3 { leg.x, 22.0, 4.0 * side }, float3 { leg.x + (leg.y - leg.x) * 0.4, 34.0, 18.0 * side }, float3 { leg.y, 0.8, 24.0 * side }], [1.8, 1.4, 0.8], dark)
    add_child(n, blob(float3 { 22.0, 6.5, 7.5 }, green, float3 { -20.0, 26.0, 0.0 }, float3 { 0.0, 0.0, 10.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 20.0, 2.0, 5.0 }, wing, float3 { -18.0, 31.0, 3.0 * side }, float3 { 0.0, 0.0, 10.0 }))
    add_child(n, blob(float3 { 7.0, 5.0, 6.0 }, green, float3 { 0.0, 23.0, 0.0 }))
    if not play:
        mantis_fore(n, MANTIS_NECK, green, dark)
    add_child(n, box(float3 { 12.0, 0.8, 16.0 }, s.team, float3 { -8.0, 31.0, 0.0 }, float3 { 0.0, 0.0, 8.0 }))
    add_child(n, box(float3 { 9.0, 1.6, 8.0 }, s.dark, float3 { -8.0, 32.2, 0.0 }, float3 { 0.0, 0.0, 8.0 }))
    let out = sock(spec_of(n), "crew0_f0_top", float3 { -8.0, 33.4, 0.0 })
    if play:
        sock(out, "head", MANTIS_NECK)
        out.anchors = hips
    return out

def mantis_fore(n:MNode, at:float3, green:MMat, dark:MMat):
    let o = at - MANTIS_NECK
    let spike = plain(html("#2a3a14"))
    siege_limb(n, [o + float3 { 4.0, 24.0, 0.0 }, o + float3 { 16.0, 42.0, 0.0 }], [3.4, 2.6], green)
    add_child(n, blob(float3 { 3.6, 4.0, 5.6 }, green, o + float3 { 19.0, 46.0, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 2.4, 2.6, 2.2 }, plain(html("#c8d870")), o + float3 { 19.5, 48.0, 5.0 * side }))
        siege_limb(n, [o + float3 { 20.0, 49.0, 1.5 * side }, o + float3 { 26.0, 58.0, 5.0 * side }, o + float3 { 32.0, 62.0, 8.0 * side }], [0.5, 0.35, 0.2], dark)
        let cox = o + float3 { 13.0, 37.0, 3.5 * side }
        let elbow = o + float3 { 20.0, 26.0, 6.0 * side }
        let wrist = o + float3 { 25.0, 40.0, 6.5 * side }
        siege_limb(n, [cox, elbow, wrist], [2.2, 2.4, 1.8], green)
        siege_limb(n, [wrist, o + float3 { 22.0, 31.0, 7.0 * side }], [1.6, 0.6], dark)
        for(4) t:
            add_child(n, cone(0.1, 0.5, 2.4, spike, siege_lerp(elbow, wrist, 0.2 + float(t) * 0.2) + float3 { -1.4, 0.0, 0.0 }, float3 { 0.0, 0.0, 70.0 }, 6))

// ------------------------------------------------------------------ war beasts' heads and legs in play (posed per walk step: `hold`)

def head_beast_elephant() -> Spec:
    let n = mnode()
    elephant_head(n, float3_0, elephant_mats())
    return sock(spec_of(n), "top", float3 { 6.0, 9.0, 0.0 })

def head_beast_boar() -> Spec:
    let n = mnode()
    boar_head(n, float3_0, boar_mats())
    return sock(spec_of(n), "top", float3 { 6.0, 10.0, 0.0 })

def head_beast_heron() -> Spec:
    let n = mnode()
    heron_neck(n, float3_0)
    return sock(spec_of(n), "top", float3 { 10.0, 29.0, 0.0 })

def head_beast_mantis() -> Spec:
    let n = mnode()
    let green = surf("chitin", html("#6a9a3a"), 5.0)
    mantis_fore(n, float3_0, green, surf("chitin", html("#4a7028"), 4.0))
    return sock(spec_of(n), "top", float3 { 15.0, 24.0, 0.0 })

def head_beast_tarantula() -> Spec:
    let n = mnode()
    tarantula_jaws(n, float3_0, surf("rat_fur", float3 { 0.28, 0.24, 0.24 }, 4.0), surf("rat_fur", float3 { 0.17, 0.15, 0.16 }, 3.5))
    return sock(spec_of(n), "top", float3 { 6.0, 4.0, 0.0 })

// Where the foot is in this walk step, from where it stands: forward (x), up (y).
def beast_step(stride:float, lift:float, stance:float = 0.6) -> float2:
    if not starts_with(hold, "w"): return float2_0
    let nums = tokenize(hold.substring(1, hold.length - 1), "_", "")
    let i, _i_ok = string_to_int(nums[0])
    let k, _k_ok = string_to_int(nums[1])
    let p = float(i) / float(k)
    if p < stance: return float2 { stride * (0.5 - p / stance), 0.0 }
    let q = (p - stance) / (1.0 - stance)
    return float2 { stride * (siege_smoothstep(0.0, 1.0, q) - 0.5), lift * sin(q * 180.0) }

def ik3(a:float3, b:float3, l1:float, l2:float, bend:float3) -> float3, float3:
    let d = b - a
    let l = clamp(magnitude(d), 0.01, l1 + l2 - 0.02)
    let u = normalize(d)
    let along = (l1 * l1 - l2 * l2 + l * l) / (2.0 * l)
    let h = sqrt(max(0.0, l1 * l1 - along * along))
    let nrm = normalize(bend - u * dot(bend, u))
    return a + u * along + nrm * h, a + u * l

def leg_beast_elephant() -> Spec:
    let n = mnode()
    let m = elephant_mats()
    let st = beast_step(13.0, 4.5)
    let knee, ankle = ik3(float3_0, float3 { st.x, -27.6 + st.y, 0.5 }, 14.0, 14.0, SIEGE_RIGHT)
    add_child(n, rod(float3_0, knee, 5.6, 5.3, m.hide))
    add_child(n, blob(float3_1 * 5.3, m.hide, knee))
    add_child(n, rod(knee, ankle, 5.3, 5.0, m.hide, false))
    add_child(n, cone(5.6, 5.8, 2.4, m.dark, ankle + float3 { 0.0, -1.2, 0.0 }))
    for(3) t:
        let a = -40.0 + float(t) * 40.0
        add_child(n, blob(float3 { 1.2, 1.0, 1.0 }, m.ivory, ankle + float3 { 5.2 * cos(a), -1.0, 5.2 * sin(a) }))
    return spec_of(n)

def boar_leg_posed(fore:bool) -> Spec:
    let n = mnode()
    let m = boar_mats()
    let st = beast_step(12.0, 5.0)
    let j0, foot = ik3(float3_0, float3 { 1.0 + st.x, -25.4 + st.y, 0.5 }, 16.2, 9.6, SIEGE_RIGHT * (if fore: 1.0 else: -1.0))
    siege_limb(n, [float3_0, j0, foot], [6.0, 3.2, 2.3], if fore: m.fur else: m.dark)
    add_child(n, cone(1.8, 2.6, 2.8, m.hoof, foot + float3 { 0.5, -1.2, 0.0 }))
    return spec_of(n)

def leg_beast_tarantula() -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", float3 { 0.28, 0.24, 0.24 }, 4.0)
    let dark = surf("rat_fur", float3 { 0.17, 0.15, 0.16 }, 3.5)
    let band = surf("rat_fur", float3 { 0.95, 0.55, 0.25 }, 3.0)
    let pale = plain(html("#e6d2a4"))
    let st = beast_step(10.0, 6.0, 0.5)
    let knee, foot = ik3(float3_0, float3 { st.x, -16.2 + st.y, 30.0 }, 22.7, 36.4, SIEGE_UP)
    let ankle = siege_lerp(knee, foot, 0.66) + float3 { 0.0, 0.0, 1.5 }
    siege_limb(n, [float3_0, knee], [3.4, 3.0], fur)
    add_child(n, blob(float3 { 3.2, 3.2, 3.2 }, band, knee))
    siege_limb(n, [knee, ankle, foot], [2.8, 2.2, 1.4], dark)
    for([0.35, 0.65]) t:
        let at = knee * t
        add_child(n, rod(at + float3 { 0.0, 2.6, 0.0 }, at + float3 { -0.6, 5.4, 0.8 }, 0.6, 0.1, pale))
    add_child(n, blob(float3 { 2.7, 2.7, 2.7 }, pale, siege_lerp(knee, ankle, 0.45)))
    return spec_of(n)

def leg_beast_heron() -> Spec:
    let n = mnode()
    let leg = plain(html("#8a7a4a"))
    let st = beast_step(18.0, 7.0, 0.55)
    let k = st.y / 7.0
    var foot = float3 { st.x, -39.0 + st.y, 1.5 }
    let a = atan2(float2 { 11.0, -2.0 }) - rad(0.75 * k)   // degrees
    var heel = foot + float3 { sin(a) * 11.18, cos(a) * 11.18, -0.5 }
    let j0, j1 = ik3(float3_0, heel, 14.14, 14.56, SIEGE_RIGHT)
    heel = j1
    foot = heel - float3 { sin(a) * 11.18, cos(a) * 11.18, -0.5 }
    siege_limb(n, [float3_0, j0, heel, foot], [2.4, 1.3, 1.2, 1.0], leg)
    let curl = rad(-0.9 * k)
    for(3) t:
        add_child(n, rod(foot, foot + float3 { 6.0 * cos(curl), 6.0 * sin(curl) - 0.2, float(t - 1) * 3.0 }, 0.6, 0.4, leg))
    add_child(n, rod(foot, foot + float3 { -4.0 * cos(curl * 0.5), -0.2 - 2.0 * k, 0.0 }, 0.6, 0.4, leg))
    return spec_of(n)

def leg_beast_mantis() -> Spec:
    let n = mnode()
    let st = beast_step(10.0, 5.0, 0.55)
    let j0, j1 = ik3(float3_0, float3 { st.x, -21.2 + st.y, 20.0 }, 18.4, 33.7, SIEGE_UP)
    siege_limb(n, [float3_0, j0, j1], [1.8, 1.4, 0.8], surf("chitin", html("#4a7028"), 4.0))
    return spec_of(n)

def leg_beast(kind:string, hind:bool) -> Spec?:
    switch kind:
        case "elephant": return leg_beast_elephant()
        case "boar": return boar_leg_posed(not hind)
        case "tarantula": return leg_beast_tarantula()
        case "heron": return leg_beast_heron()
        case "mantis": return leg_beast_mantis()
        default: return nil

// UnitModels.leg_basis (cut): a leg built for the near side turned to its own, fanned at its hip.
def siege_leg_basis(a:Anchor) -> Basis:
    let flip = a.more.length > 0 and a.more[0] == 1.0
    let side = if a.pos.z < 0.0: -1.0 else: 1.0
    let fan = if a.more.length > 2: axis_angle(SIEGE_UP, a.more[2] * -side) else: BASIS_ID
    return bmul(fan, Basis { float3 { if flip: -1.0 else: 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, 0.0, side } })

let BESIDE_GAP = 11.0

def beside(spec:Spec, kind:string) -> Spec:
    var zmax = 0.0
    for(siege_cloud(spec.node)) q: zmax = max(zmax, abs(q.z))
    hold = "low"
    for(spec.anchors) a:
        let leg = leg_beast(kind, a.more.length > 1 and a.more[1] != 0.0)
        assert leg
        let ln = leg.node
        set_xform(ln, Xform { siege_leg_basis(a), a.pos })
        for(siege_cloud(ln)) q: zmax = max(zmax, abs(q.z))
    var k = 0
    let names = spec.sockets.get_keys()
    insertion_sort(names) x, y: x < y
    for(names) name:
        if ends_with(name, "_top"):
            let at = spec.sockets.get(name, float3_0)
            let side = if abs(at.z) > 0.5: siege_sign(at.z) else: (if k % 2 == 0: 1.0 else: -1.0)
            spec.sockets.set(name.substring(0, name.length - 4) + "_wide", float3 { at.x, 0.0, side * (zmax + BESIDE_GAP) })
            k++
    return spec

def war_beast(kind:string, c:Colours) -> Spec?:
    switch kind:
        case "elephant": return beside(elephant(siege_style("timber", c), true, true), kind)
        case "boar": return beside(war_boar(siege_style("junk", c), true, true), kind)
        case "tarantula": return beside(tarantula(siege_style("spooky", c), false, true, true), kind)
        case "heron": return beside(heron(siege_style("frog", c), true), kind)
        case "mantis": return beside(mantis(siege_style("forest", c), true), kind)
        default: return nil

// ------------------------------------------------------------------ the great sling (D-129, GS2)

// sling_frame: the short end (where the pull ropes hang) and the long end.
def sling_frame(n:MNode, s:SStyle, base:float = 0.0, k:float = 1.0) -> float3, float3:
    let top = sling_towers(n, s, base, k)
    let short = float3 { 18.0 * k, top - 10.0 * k, 0.0 }
    let long = float3 { -48.0 * k, top + 26.0 * k, 0.0 }
    sling_arm(n, s, short, long, k)
    add_child(n, rod(short + float3 { 0.0, -2.0, -8.0 } * k, short + float3 { 0.0, -2.0, 8.0 } * k, 1.0 * k, 1.0 * k, s.dark))
    return short + float3 { 0.0, -2.0, 0.0 } * k, long

def sling_towers(n:MNode, s:SStyle, base:float = 0.0, k:float = 1.0) -> float:
    let T = 4.2 * k
    let top = base + 50.0 * k
    let L = 28.0 * k
    let wd = 15.0 * k
    for([1.0, -1.0]) side:
        add_child(n, siege_beam(float3 { -L, base + T * 0.5, wd * side }, float3 { L, base + T * 0.5, wd * side }, T, T, s.dark))
        add_child(n, siege_beam(float3 { -16.0 * k, base + T, wd * side }, float3 { 0.0, top, 7.0 * k * side }, T * 0.9, T * 0.9, s.wood))
        add_child(n, siege_beam(float3 { 16.0 * k, base + T, wd * side }, float3 { 0.0, top, 7.0 * k * side }, T * 0.9, T * 0.9, s.wood))
        add_child(n, siege_beam(float3 { -8.0 * k, base + 25.0 * k, 11.0 * k * side }, float3 { 8.0 * k, base + 25.0 * k, 11.0 * k * side }, T * 0.7, T * 0.7, s.dark))
        add_child(n, siege_beam(float3 { -L + 2.0 * k, base + T, wd * side }, float3 { -9.0 * k, base + 30.0 * k, 10.0 * k * side }, T * 0.7, T * 0.7, s.dark))
        add_child(n, siege_beam(float3 { L - 2.0 * k, base + T, wd * side }, float3 { 9.0 * k, base + 30.0 * k, 10.0 * k * side }, T * 0.7, T * 0.7, s.dark))
        add_child(n, box(float3 { T + 1.2, 2.2 * k, T + 1.2 }, s.metal, float3 { 0.0, top - 1.0 * k, 7.0 * k * side }))
    for([-L + 2.0 * k, 0.0, L - 2.0 * k]) x:
        add_child(n, siege_beam(float3 { x, base + T * 1.5, -wd - 2.0 * k }, float3 { x, base + T * 1.5, wd + 2.0 * k }, T, T, s.dark))
    add_child(n, rod(float3 { 0.0, top, -10.0 * k }, float3 { 0.0, top, 10.0 * k }, 1.8 * k, 1.8 * k, s.metal, false))
    return top

def sling_arm(n:MNode, s:SStyle, short:float3, long:float3, k:float = 1.0, pouch_drop:float3 = float3 { -3.0, -20.0, 0.0 }, loaded:bool = true) -> float3:
    let mid = siege_lerp(short, long, 0.3)
    add_child(n, siege_beam(short, mid, 5.4 * k, 5.4 * k, s.wood))
    add_child(n, siege_beam(mid, long, 3.6 * k, 3.6 * k, s.wood))
    let dv = long - short
    let ang = atan2(float2 { dot(dv, SIEGE_RIGHT), magnitude(cross(dv, SIEGE_RIGHT)) })   // angle_to, degrees
    for([0.08, 0.22, 0.42, 0.62]) t:
        add_child(n, ring(2.2 * k, 3.4 * k, s.metal, siege_lerp(short, long, t), float3 { 0.0, 0.0, 90.0 + ang }))
    add_child(n, box(float3 { 14.0 * k, 0.6, 5.8 * k }, s.team, siege_lerp(short, long, 0.48) + float3 { 0.0, 2.4 * k, 0.0 }, float3 { 0.0, 0.0, ang }))
    let pouch = long + pouch_drop * k
    for([1.2, -1.2]) z:
        add_child(n, rod(long, pouch + float3 { 0.0, 1.0, z } * k, 0.35, 0.35, s.rope, false))
    add_child(n, blob(float3 { 3.6, 2.4, 3.6 } * k, surf("leather", float3_1, 2.0), pouch))
    if loaded:
        add_child(n, blob(float3_1 * 3.2 * k, s.ammo, pouch + float3 { 0.0, 1.4, 0.0 } * k))
    return pouch

let SLING_FILE = float3 { 36.0, 18.0, 15.0 }

def great_sling(s:SStyle) -> Spec:
    let n = mnode()
    let short, _long = sling_frame(n, s)
    let sp = spec_of(n)
    for([1.0, -1.0]) side:
        let stake = float3 { SLING_FILE.x + 2.0 * SLING_FILE.y + 12.0, 0.0, 9.0 * side }
        add_child(n, rod(short + float3 { 0.0, 0.0, 7.0 * side }, stake + float3 { 0.0, 1.5, 0.0 }, 0.4, 0.4, s.rope, false))
        add_child(n, cone(0.25, 0.9, 5.0, s.dark, stake + float3 { 0.0, 1.5, 0.0 }, float3 { 0.0, 0.0, -20.0 }, 8))
    for(6) k:
        let side = if k < 3: 1.0 else: -1.0
        let at = float3 { SLING_FILE.x + float(k % 3) * SLING_FILE.y, 0.0, SLING_FILE.z * side }
        sock(sp, "crew{k}_f4_raise" + (if k == 0 or k == 3: "" else: "_narrow"), at)
    sock(sp, "crew0_f4_raise_wide", float3 { 46.0, 0.0, 26.0 })
    sock(sp, "crew3_f4_raise_wide", float3 { 46.0, 0.0, -26.0 })
    for(7) k:
        let a = float(k) * 2.4
        add_child(n, blob(float3_1 * (2.8 - float(k % 3) * 0.4), s.ammo, float3 { -36.0 + siege_cosr(a) * 3.5, 2.4 + (if k == 6: 1.6 else: 0.0), 22.0 + siege_sinr(a) * 3.0 }))
    sock(sp, "crew6_f6_reach", float3 { -36.0, 0.0, 13.0 })
    sock(sp, "crew6_f6_reach_wide", float3 { -38.0, 0.0, 34.0 })
    siege_pennant(n, s, float3 { 0.0, 51.0, -10.0 }, 12.0, 5.0)
    if s.fam == "junk":
        for([1.0, -1.0]) side:
            siege_patch(n, s, float3 { -8.0, 14.0, 15.6 * side }, float2 { 7.0, 9.0 }, float3 { 0.0, 0.0, 32.0 }, s.plate)
            siege_chain(n, float3 { -26.0, 4.0, 15.0 * side }, float3 { 0.0, 48.0, 7.0 * side }, s.metal)
    return sp

def great_packed(s:SStyle) -> Spec:
    let n = mnode()
    siege_undercarriage(n, s, 54.0, 20.0, 6.0)
    add_child(n, box(float3 { 58.0, 2.4, 20.0 }, s.dark, float3 { 0.0, 12.0, 0.0 }))
    for([-7.0, 0.0, 7.0]) z:
        add_child(n, siege_beam(float3 { -26.0, 15.4, z }, float3 { 26.0, 15.4, z }, 4.2, 4.2, s.wood))
    add_child(n, siege_beam(float3 { -34.0, 20.0, 0.0 }, float3 { 34.0, 20.0, 0.0 }, 5.0, 5.0, s.wood))
    for([-20.0, 0.0, 20.0]) t:
        add_child(n, ring(2.6, 3.8, s.metal, float3 { t, 20.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    add_child(n, ring(2.4, 3.6, s.rope, float3 { -14.0, 23.2, 0.0 }))
    add_child(n, ring(2.4, 3.6, s.rope, float3 { 12.0, 23.2, 0.0 }))
    add_child(n, box(float3 { 18.0, 0.5, 21.0 }, s.team, float3 { 0.0, 13.4, 0.0 }))
    let sp = spec_of(n)
    sock(sp, "crew0_f0", float3 { 8.0, 0.0, 18.0 })
    sock(sp, "crew1_f0", float3 { -14.0, 0.0, -18.0 })
    return sp

// ------------------------------------------------------------------ the frogs' great sling (D-131: the bullfrog leaper)

def bullfrog(n:MNode, at:float3, k:float = 1.0):
    let skin = surf("frog_skin", html("#6a8a3a"), 6.0)
    let dark = surf("frog_skin", html("#3e5a24"), 5.0)
    let throat = surf("frog_belly", html("#e0c860"), 5.0)
    let b = mnode()
    b.pos = at
    b.scl = float3_1 * k
    add_child(n, b)
    add_child(b, blob(float3 { 13.0, 8.5, 10.5 }, skin, float3 { -2.0, 9.5, 0.0 }, float3 { 0.0, 0.0, 22.0 }))
    add_child(b, blob(float3 { 9.0, 4.5, 8.0 }, throat, float3 { 4.0, 6.0, 0.0 }, float3 { 0.0, 0.0, 22.0 }))
    add_child(b, blob(float3 { 8.5, 6.0, 9.5 }, skin, float3 { 9.0, 13.5, 0.0 }))
    add_child(b, blob(float3 { 7.0, 3.2, 8.4 }, throat, float3 { 10.0, 10.0, 0.0 }))
    add_child(b, rod(float3 { 16.6, 12.0, -6.0 }, float3 { 17.4, 12.0, 0.0 }, 0.4, 0.4, plain(INK)))
    add_child(b, rod(float3 { 17.4, 12.0, 0.0 }, float3 { 16.6, 12.0, 6.0 }, 0.4, 0.4, plain(INK)))
    for([1.0, -1.0]) side:
        add_child(b, blob(float3 { 2.8, 2.8, 2.6 }, skin, float3 { 10.0, 19.0, 5.0 * side }))
        add_child(b, blob(float3 { 1.6, 1.6, 1.2 }, plain(html("#d8a830")), float3 { 11.6, 19.6, 6.0 * side }))
        add_child(b, blob(float3 { 0.5, 0.9, 0.4 }, plain(html("#140c06")), float3 { 12.8, 19.8, 6.6 * side }))
        add_child(b, cone(2.2, 2.2, 0.5, plain(html("#7a5a30")), float3 { 5.0, 15.0, 8.4 * side }, SIEGE_X90, 14))
        add_child(b, blob(float3 { 11.0, 6.0, 4.5 }, dark, float3 { -8.0, 6.5, 9.5 * side }, float3 { 0.0, 0.0, 25.0 }))
        add_child(b, rod(float3 { -2.0, 1.0, 11.5 * side }, float3 { 8.0, 0.8, 13.0 * side }, 1.8, 1.2, dark))
        add_child(b, rod(float3 { 8.0, 10.0, 6.0 * side }, float3 { 12.0, 0.8, 8.5 * side }, 2.0, 1.5, skin))
        for(4) t:
            add_child(b, rod(float3 { 12.0, 0.8, 8.5 * side }, float3 { 15.0, 0.6, (8.5 + (float(t) - 1.5) * 1.4) * side }, 0.6, 0.45, skin))
    for(10) t:
        let a = float(t) * 2.39996
        add_child(b, blob(float3 { 2.4, 0.8, 1.8 }, dark, float3 { -4.0 + siege_cosr(a) * 7.0, 15.0 + siege_sinr(a * 0.5) * 1.5, siege_sinr(a) * 6.0 }))

let FROG_SLING_K = 0.9
let FROG_TOWER = float3 { -48.0, 62.0, 6.0 }
let FROG_HAUL_STAKE = float3 { 106.0, 0.0, -7.0 }

def frog_sling(s:SStyle, thrown:bool = false) -> Spec:
    let n = mnode()
    let k = FROG_SLING_K
    let top = sling_towers(n, s, 0.0, k)
    let e0 = if thrown: float2 { -12.2, -14.6 } else: float2 { -15.0, 15.0 }
    let e1 = if thrown: float2 { 34.7, 41.4 } else: float2 { 40.0, -35.0 }
    let short = float3 { e0.x, top + e0.y, 0.0 }
    let long = float3 { e1.x, top + e1.y, 0.0 }
    sling_arm(n, s, short, long, k, if thrown: float3 { 14.0, 10.0, 0.0 } else: float3 { 6.0, -5.0, 0.0 }, not thrown)
    add_child(n, box(float3 { 13.0, 2.0, 13.0 }, s.wicker, short + float3 { -1.0, 2.2, 0.0 }))
    add_child(n, box(float3 { 11.0, 0.6, 11.0 }, s.team, short + float3 { -1.0, 3.5, 0.0 }))
    let T = FROG_TOWER
    for([T.x - T.z, T.x + T.z]) x:
        for([-T.z, T.z]) z:
            siege_bundle(n, float3 { x, 0.0, z }, float3 { x, T.y, z * 0.9 }, 1.6, s, 4, 1.3)
    for([20.0, 42.0]) y:
        for([-T.z, T.z]) z:
            add_child(n, rod(float3 { T.x - T.z, y, z }, float3 { T.x + T.z, y + 8.0, z }, 0.6, 0.6, s.lash))
    add_child(n, box(float3 { 16.0, 2.0, 16.0 }, s.plank, float3 { T.x, T.y + 1.0, 0.0 }))
    if thrown:
        bullfrog(n, short + float3 { -9.0, 3.8, 0.0 }, 1.0)
    else:
        bullfrog(n, float3 { T.x - 2.0, T.y + 2.0, 0.0 }, 1.05)
    if thrown:
        add_child(n, ring(1.8, 3.0, s.rope, FROG_HAUL_STAKE + float3 { -4.0, 0.6, 0.0 }, float3_0, float3 { 1.0, 1.4, 1.0 }))
    else:
        add_child(n, rod(long + float3 { 0.0, 0.0, -1.5 }, FROG_HAUL_STAKE + float3 { 0.0, 1.5, 0.0 }, 0.4, 0.4, s.rope, false))
    add_child(n, cone(0.25, 0.9, 5.0, s.dark, FROG_HAUL_STAKE + float3 { 0.0, 1.5, 0.0 }, float3 { 0.0, 0.0, -20.0 }, 8))
    for(5) kk:
        let a = float(kk) * 2.4
        add_child(n, blob(float3_1 * (2.6 - float(kk % 3) * 0.4), if kk % 2 == 0: s.ammo else: s.stone, float3 { 60.0 + siege_cosr(a) * 3.0, 2.2, 24.0 + siege_sinr(a) * 2.6 }))
    siege_pennant(n, s, float3 { T.x + T.z, T.y + 2.0, -T.z }, 12.0, 4.5)
    let sp = spec_of(n)
    sock(sp, "crew0_f4_reach", float3 { 54.0, 0.0, 13.0 })
    sock(sp, "crew1_f4_raise", float3 { 68.0, 0.0, -17.0 })
    sock(sp, "crew2_f4_raise", float3 { 89.0, 0.0, -17.0 })
    sock(sp, "crew3_f0", float3 { -26.0, 0.0, 22.0 })
    return sp

def frog_packed(s:SStyle) -> Spec:
    let n = mnode()
    let L = 64.0
    let wd = 24.0
    let x0 = -8.0
    siege_sledge(n, s, L, wd, x0)
    for([-7.5, -2.5, 2.5, 7.5]) z:
        siege_bundle(n, float3 { x0 - 28.0, 5.6, z }, float3 { x0 + 22.0, 5.6, z }, 1.8, s, 4, 1.6)
    for([-5.0, 5.0]) z:
        add_child(n, siege_beam(float3 { x0 - 24.0, 9.6, z }, float3 { x0 + 20.0, 9.6, z }, 3.8, 3.8, s.dark))
    add_child(n, siege_beam(float3 { x0 - 30.0, 13.8, 0.0 }, float3 { x0 + 26.0, 13.8, 0.0 }, 4.6, 4.6, s.wood))
    for([x0 - 18.0, x0, x0 + 16.0]) x:
        add_child(n, ring(2.4, 3.4, s.lash, float3 { x, 13.8, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
        add_child(n, rod(float3 { x, 3.2, -wd * 0.5 - 0.4 }, float3 { x, 11.0, -6.0 }, 0.35, 0.35, s.lash))
        add_child(n, rod(float3 { x, 3.2, wd * 0.5 + 0.4 }, float3 { x, 11.0, 6.0 }, 0.35, 0.35, s.lash))
    add_child(n, box(float3 { 12.0, 2.0, 12.0 }, s.wicker, float3 { x0 - 20.0, 17.2, 0.0 }))
    add_child(n, box(float3 { 10.0, 0.6, 10.0 }, s.team, float3 { x0 - 20.0, 18.5, 0.0 }))
    add_child(n, ring(2.4, 3.6, s.rope, float3 { x0 + 8.0, 17.0, 0.0 }))
    let bx = x0 + L * 0.5 + 24.0
    let bk = 0.9
    bullfrog(n, float3 { bx, 0.0, 0.0 }, bk)
    let band_at = float3 { bx, 10.0 * bk, 0.0 }
    add_child(n, ring(10.6 * bk, 11.6 * bk, s.lash, band_at, float3 { 0.0, 0.0, 90.0 }, float3 { 0.86, 1.0, 1.0 }))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { x0 + L * 0.5, 6.0, wd * 0.5 * side }, band_at + float3 { 0.0, 0.0, 11.1 * bk * side }, 0.4, 0.4, s.rope, false))
    siege_pennant(n, s, float3 { x0 - 34.0, 3.2, -wd * 0.5 }, 14.0, 4.5)
    let sp = spec_of(n)
    sock(sp, "crew0_f0", float3 { x0 + 6.0, 0.0, 21.0 })
    sock(sp, "crew1_f0", float3 { x0 - 18.0, 0.0, -21.0 })
    return sp

// ------------------------------------------------------------------ siege shots ("shot.<look>", built round their middle)

def shot_boulder(n:MNode, k:float):
    let rock = surf("rock", float3 { 0.92, 0.9, 0.84 }, 2.5)
    let dark = surf("rock", float3 { 0.6, 0.58, 0.54 }, 2.5)
    let pale = surf("rock", float3 { 1.15, 1.12, 1.05 }, 2.5)
    add_child(n, blob(float3 { 3.3, 2.9, 3.1 } * k, rock, float3_0, float3 { 10.0, 25.0, 15.0 }))
    let dirs = [float3 { 1.0, 0.6, 0.4 }, float3 { -0.8, 0.2, 0.9 }, float3 { 0.1, -0.9, -0.6 }, float3 { -0.3, 0.9, -0.5 }, float3 { 0.7, -0.4, -0.9 }]
    let sizes = [1.8, 1.6, 1.7, 1.5, 1.3]
    let mats = [rock, dark, dark, pale, rock]
    for(dirs) d, i:
        add_child(n, blob(float3_1 * sizes[i] * k, mats[i], normalize(d) * 2.2 * k))
    add_child(n, blob(float3 { 1.6, 0.4, 1.2 } * k, plain(html("#5a6a32")), float3 { -0.6, 2.4, 1.6 } * k))

def shot_cheese(n:MNode, k:float):
    let cheese = surf("cheese", float3_1, 3.0)
    let rind = surf("cheese", float3 { 0.82, 0.62, 0.3 }, 3.0)
    add_child(n, slab(map([float2 { -3.4, -2.0 }, float2 { 3.6, -2.0 }, float2 { -3.4, 2.6 }]) v: v * k, 4.2 * k, cheese))
    add_child(n, box(float3 { 0.6, 4.6, 4.3 } * k, rind, float3 { -3.6, 0.3, 0.0 } * k))
    let hole = plain(html("#b88a28"))
    for([float4 { -1.2, -0.6, 2.15, 0.8 }, float4 { 0.8, -1.2, 2.15, 0.6 }, float4 { -2.2, 1.0, 2.15, 0.55 }, float4 { -0.6, -0.8, -2.15, 0.75 }]) h:
        add_child(n, blob(float3 { h.w, h.w, 0.3 } * k, hole, float3 { h.x, h.y, h.z } * k))

def shot_acorn(n:MNode, k:float):
    add_child(n, blob(float3 { 2.6, 3.4, 2.6 } * k, surf("wood_grain", float3 { 0.95, 0.68, 0.4 }, 3.0), float3 { 0.0, -0.8, 0.0 } * k))
    add_child(n, blob(float3 { 0.6, 0.5, 0.6 } * k, plain(html("#4a3018")), float3 { 0.0, -4.0, 0.0 } * k))
    add_child(n, dome(float3 { 3.0, 2.0, 3.0 } * k, surf("acorn_cap", float3_1, 3.0), float3 { 0.0, 1.2, 0.0 } * k))
    add_child(n, rod(float3 { 0.0, 3.0, 0.0 } * k, float3 { 0.6, 4.4, 0.0 } * k, 0.45 * k, 0.35 * k, plain(html("#5a4028"))))

def shot_bone(n:MNode, k:float):
    let bone = surf("bone", float3_1, 3.0)
    let silk = surf("cloth", html("#cfc8d8"), 2.0)
    add_child(n, blob(float3_1 * 2.6 * k, silk, float3_0))
    for([[float3 { -3.0, 0.6, 1.0 }, float3 { 3.0, -0.4, 1.4 }], [float3 { -1.0, -2.6, -1.6 }, float3 { 1.4, 2.8, -1.2 }], [float3 { 0.6, 0.4, -3.0 }, float3 { -0.4, -0.2, 3.0 }]]) b:
        add_child(n, rod(b[0] * k, b[1] * k, 0.55 * k, 0.55 * k, bone))
        for(b) end:
            add_child(n, blob(float3_1 * 0.85 * k, bone, end * k))
    add_child(n, blob(float3 { 1.7, 1.6, 1.5 } * k, bone, float3 { 1.6, 1.4, 0.6 } * k))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.4, 0.45, 0.3 } * k, plain(html("#1a1418")), float3 { 2.9, 1.6, 0.6 + 0.6 * side } * k))
    for([SIEGE_X90, float3 { 0.0, 0.0, 90.0 }, float3 { 45.0, 45.0, 0.0 }]) rot:
        add_child(n, ring(2.5 * k, 2.8 * k, silk, float3_0, rot, float3 { 1.0, 0.5, 1.0 }))

def shot_clay(n:MNode, k:float):
    let clay = surf("bld_daub", float3 { 1.05, 0.62, 0.42 }, 3.0)
    add_child(n, blob(float3 { 3.0, 2.8, 3.0 } * k, clay, float3_0))
    let cord = plain(html("#4a3a2a"))
    add_child(n, ring(2.85 * k, 3.15 * k, cord, float3_0, SIEGE_X90, float3 { 1.0, 0.4, 1.0 }))
    add_child(n, ring(2.85 * k, 3.15 * k, cord, float3_0, float3 { 0.0, 0.0, 90.0 }, float3 { 1.0, 0.4, 1.0 }))
    add_child(n, cone(0.7 * k, 0.9 * k, 1.2 * k, surf("thatch", float3_1, 2.0), float3 { 0.0, 2.9, 0.0 } * k))

def shot_bolt(n:MNode):
    let shaft = surf("wood_grain", float3 { 1.0, 0.9, 0.72 }, 4.0)
    add_child(n, rod(float3 { -9.0, 0.0, 0.0 }, float3 { 7.0, 0.0, 0.0 }, 0.8, 0.8, shaft))
    add_child(n, cone(0.0, 1.5, 4.0, surf("iron", float3_1, 2.0), float3 { 8.6, 0.0, 0.0 }, float3 { 0.0, 0.0, -90.0 }, 8))
    add_child(n, cone(0.7, 0.7, 0.8, surf("iron", float3 { 0.7, 0.7, 0.7 }, 2.0), float3 { 6.8, 0.0, 0.0 }, float3 { 0.0, 0.0, 90.0 }, 8))
    let vane = surf("leather", float3 { 0.95, 0.88, 0.75 }, 2.0)
    for([0.0, 120.0, 240.0]) a:
        let d = float3 { 0.0, cos(a), sin(a) }
        let v = slab([float2 { 0.0, 0.0 }, float2 { -4.0, 0.0 }, float2 { -4.6, 1.8 }, float2 { -1.2, 1.2 }], 0.25, vane)
        set_basis(v, axis_angle(SIEGE_RIGHT, a))
        v.pos = float3 { -4.6, 0.0, 0.0 } + d * 0.3
        add_child(n, v)

// shot_model: "shot.<look>[_big]" (nil for a look it doesn't know).
def shot_model_spec(id:string, c:Colours) -> Spec?:
    if not starts_with(id, "shot."): return nil
    var name = id.substring(5, id.length - 5)
    let big = ends_with(name, "_big")
    if big: name = name.substring(0, name.length - 4)
    let k = if big: 2.3 else: 1.4
    let n = mnode()
    switch name:
        case "boulder": shot_boulder(n, k)
        case "cheese": shot_cheese(n, k)
        case "acorn": shot_acorn(n, k)
        case "bone": shot_bone(n, k)
        case "clay": shot_clay(n, k)
        case "bolt": shot_bolt(n)
        default: return nil
    return spec_of(n)

// ------------------------------------------------------------------ the dispatcher (siege_models.gd build, has)

def siege_take(take:string) -> bool: return take == "timber" or take == "junk" or take == "forest" or take == "spooky" or take == "frog"

def siege_scale_of(engine:string) -> float:
    switch engine:
        case "ram": return 1.5
        case "catapult": return 1.8
        case "bolt": return 2.1
        case "tower": return 1.0
        default: return 0.0

// The engines a take builds its own way (OWN), nil for the crewed "c" ones.
def siege_own(key:string, s:SStyle) -> Spec?:
    switch key:
        case "ram.forest": return ram_ridden(s)
        case "ram.frog": return ram_beast(s)
        case "catapult.frog": return catapult_snail(s)
        case "bolt.frog": return bolt_beast(s)
        case "sling.timber", "sling.junk", "sling.forest", "sling.spooky": return great_sling(s)
        case "sling_packed.timber", "sling_packed.junk", "sling_packed.forest", "sling_packed.spooky": return great_packed(s)
        case "sling.frog": return frog_sling(s)
        case "sling_throw.frog": return frog_sling(s, true)
        case "sling_packed.frog": return frog_packed(s)
        default: return nil

def siege_engine(id:string, c:Colours) -> Spec?:
    let p = tokenize(id, ".", "")
    let engine = p[1]
    let take = p[2]
    if engine == "beast": return war_beast(take, c)
    if not siege_take(take): return nil
    if engine == "cart": return trade_cart(take, c)
    if engine == "barrow" or engine == "handcart": return pushed_home(engine, siege_style(take, c))
    let s = siege_style(take, c)
    var spec = siege_own(engine + "." + take, s)
    if not spec:
        switch engine:
            case "ram": spec = ram_c(s)
            case "catapult": spec = catapult_c(s)
            case "bolt": spec = bolt_c(s)
            case "tower": spec = tower_c(s)
            default: return nil
        spec = scaled(spec, siege_scale_of(engine))
    let sp = spec
    for(sp.sockets.get_keys()) name:
        if ends_with(name, "_in"):
            let at = sp.sockets.get(name, float3_0)
            sp.sockets.set(name.substring(0, name.length - 3) + "_wide", float3 { at.x, at.y, (if at.z > 0.0: 1.0 else: -1.0) * SIEGE_WIDE_CREW })
    return sp

def build_siege(base:string, c:Colours) -> Spec?:
    if starts_with(base, "shot."): return shot_model_spec(base, c)
    if starts_with(base, "siege."):
        if tokenize(base, ".", "").length != 3: return nil
        return siege_engine(base, c)
    switch base:
        case "harness.draught": return spec_of(mnode())   // (no model off its wearer: always fitted on the beast, harness_fitted)
        case "leg.beast_elephant": return leg_beast_elephant()
        case "leg.beast_boar": return boar_leg_posed(true)
        case "leg.beast_boar_hind": return boar_leg_posed(false)
        case "leg.beast_tarantula": return leg_beast_tarantula()
        case "leg.beast_heron": return leg_beast_heron()
        case "leg.beast_mantis": return leg_beast_mantis()
        case "head.beast_elephant": return head_beast_elephant()
        case "head.beast_boar": return head_beast_boar()
        case "head.beast_tarantula": return head_beast_tarantula()
        case "head.beast_heron": return head_beast_heron()
        case "head.beast_mantis": return head_beast_mantis()
        default: return nil

// not ported (concept-only, not reachable from build): the "swamp" and "sewer" families (_style and their
// branches in wheel, undercarriage, pennant, ram_head, ram_log, throw_arm, bow_and_bolt), _ram_a, _ram_b's
// "forest" branch and _creature, _catapult_b, _bolt_a's swamp branch, _bolt_b, _ram_shed, _tower_hide,
// _tower_open, _tower_belfry, _tower_beast, _ram_mount, _ram_led, _ram_reed, _catapult_reed, _bolt_reed,
// _catapult_beast, _ram_river, _catapult_river, _bolt_river, punt, eel_trap, draped_net, _catapult_toad,
// _bolt_turtle, _catapult_turtle, _catapult_haul, _cart_placeholder.
