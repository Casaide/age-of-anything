// ------------------------------------------------------------------ heroes' signature gear (hero_models.gd: "hero.*")
// Each builder is hero_models.gd's of the same name (`_hero_tricorn` -> hero_tricorn), line for line; its
// comments are there. Angles the GDScript works in radians stay in radians here (hero_cos, hero_sin);
// node rotations are degrees.

var hero_lowering = false            // hero_models.gd `low`: a low-slung variant is being built
let HERO_LOW_K = 0.8
let HERO_TAU = MPI * 2.0
let HERO_ROPE = html("#c8b48a")

def hero_cos(r:float) -> float: return cos(rad(r))
def hero_sin(r:float) -> float: return sin(rad(r))

// _low: the hat built with `low` set (hero_lowering = true before the build), then raised and set back.
def hero_low(s:Spec) -> Spec:
    hero_lowering = false
    for(s.node.kids) ch:
        ch.pos = ch.pos * HERO_LOW_K + float3 { -2.0, 1.0, 0.0 }
        ch.scl *= HERO_LOW_K
    return s

def hero_gold(k:float = 1.0) -> MMat: return plain(float3 { 0.98, 0.78, 0.25 } * k)

def hero_chain_rods(n:MNode, pts:[float3], r:[float], m:MMat):
    for(pts.length - 1) i:
        let k = i + 1
        add_child(n, rod(pts[k - 1], pts[k], r[k - 1], r[k], m))

def hero_crown(n:MNode, m:MMat, y0:float, h:float, r:float, points:int, ph:float, skip:int = -1):
    add_child(n, cone(r, r * 0.95, h, m, float3 { 0.0, y0 + h * 0.5, 0.0 }, float3_0, 24))
    add_child(n, cone(r - 0.6, r - 0.65, h + 0.1, plain(html("#2a1a12")), float3 { 0.0, y0 + h * 0.5 + 0.05, 0.0 }, float3_0, 24))
    for(points) k:
        if k != skip:
            let a = HERO_TAU * float(k) / float(points)
            let at = float3 { hero_cos(a) * r * 0.97, y0 + h, hero_sin(a) * r * 0.97 }
            add_child(n, cone(0.05, 1.2, ph, m, at + float3 { 0.0, ph * 0.5, 0.0 }, float3_0, 6))
            add_child(n, blob(float3_1 * 0.55, plain(if k % 2 == 0: html("#c02030") else: html("#2050c0")), at + float3 { 0.0, ph + 0.2, 0.0 }))

// ================================================================== head gear

def hero_crown_gnawed(c:Colours) -> Spec:
    let n = mnode()
    hero_crown(n, hero_gold(), -1.6, 3.4, 5.6, 7, 4.2, 2)
    let dent = plain(html("#6a5020"))
    for(3) k:
        let a = HERO_TAU * 2.0 / 7.0 + float(k - 1) * 0.22
        add_child(n, blob(float3 { 0.6, 1.0, 0.6 }, dent, float3 { hero_cos(a) * 5.5, 1.4, hero_sin(a) * 5.5 }))
    return spec_of(n)

def hero_crown_tiny(c:Colours) -> Spec:
    let n = mnode()
    let w = mnode()
    w.pos = float3 { -0.5, 0.6, 0.0 }
    w.rot = float3 { 12.0, 0.0, 10.0 }
    hero_crown(w, hero_gold(1.1), 0.0, 1.6, 2.2, 5, 1.8)
    add_child(n, w)
    add_child(n, blob(float3 { 2.4, 0.6, 2.4 }, plain(html("#8a1a2a")), float3 { -0.5, 0.9, 0.0 }))
    return spec_of(n)

def hero_tricorn(c:Colours) -> Spec:
    let n = mnode()
    let felt = surf("bld_felt", float3 { 0.35, 0.3, 0.28 }, 4.0)
    add_child(n, dome(float3 { 4.6, 3.6, 4.6 }, felt, float3 { -0.3, -1.2, 0.0 }))
    for(3) k:
        let a = HERO_TAU * float(k) / 3.0 + MPI
        let at = float3 { hero_cos(a) * 4.8, -0.2, hero_sin(a) * 4.8 }
        add_child(n, box(float3 { 1.0, 3.2, 7.6 }, felt, at, float3 { 0.0, -rad(a), 18.0 }))
    add_child(n, ring(4.5, 5.2, plain(html("#e8e0cc")), float3 { 0.2, -2.4, 0.0 }, float3 { 0.0, 0.0, -8.0 }))
    add_child(n, blob(float3 { 0.8, 0.8, 0.6 }, plain(html("#a02020")), float3 { 1.5, -2.2, 5.0 }))
    if not hero_lowering:
        add_child(n, blob(float3 { 0.8, 2.6, 0.6 }, plain(html("#e8e0cc")), float3 { -4.0, -3.4, 2.6 }, float3 { 0.0, 0.0, 20.0 }))
    lift_kids(n, 0.25)
    return spec_of(n)

def hero_weed_crown(c:Colours) -> Spec:
    let n = mnode()
    let weed = surf("reed_leaf", float3 { 0.55, 0.75, 0.45 }, 4.0)
    add_child(n, ring(4.4, 5.6, weed, float3 { 0.0, -1.6, 0.0 }))
    for(7) k:
        let a = MPI * 0.55 + float(k) * MPI * 0.15
        let at = float3 { hero_cos(a) * 5.0, -1.6, hero_sin(a) * 5.0 }
        hero_chain_rods(n, [at, at + float3 { -1.2, -3.0, 0.0 }, at + float3 { -1.6, -6.5 - float(k % 3), 0.0 }], [0.6, 0.5, 0.3], weed)
    hero_chain_rods(n, [float3 { -1.0, 0.6, 0.0 }, float3 { 1.0, 4.0, 1.0 }, float3 { 0.0, 7.0, 0.5 }], [0.4, 0.35, 0.2], plain(html("#e8e4d4")))
    for(3) k:
        let kf = float(k)
        add_child(n, rod(float3 { 0.6 - kf * 0.4, 3.0 + kf * 1.3, 0.8 }, float3 { 2.2 - kf * 0.3, 3.6 + kf * 1.3, 0.8 }, 0.15, 0.1, plain(html("#e8e4d4"))))
    return spec_of(n)

def hero_lily_hat(c:Colours) -> Spec:
    let n = mnode()
    let petal = plain(html("#f0a0c0"))
    add_child(n, cone(5.0, 5.2, 1.0, plain(html("#4f9d4a")), float3 { 0.0, -0.6, 0.0 }, float3_0, 24))
    for(9) k:
        let a = HERO_TAU * float(k) / 9.0
        add_child(n, blob(float3 { 4.2, 0.9, 1.8 }, petal, float3 { hero_cos(a) * 5.6, 0.6 + float(k % 2) * 0.8, hero_sin(a) * 5.6 }, float3 { 0.0, -rad(a), 25.0 }))
    add_child(n, blob(float3 { 2.0, 1.6, 2.0 }, plain(html("#f0d040")), float3 { 0.0, 1.4, 0.0 }))
    hero_chain_rods(n, [float3 { -0.5, 2.0, 0.0 }, float3 { -2.0, 9.0, 0.0 }, float3 { -5.0, 14.0, 0.0 }], [0.4, 0.3, 0.2], surf("reed_stalk", float3_1, 4.0))
    add_child(n, blob(float3 { 1.2, 3.0, 1.2 }, plain(html("#6a4a2a")), float3 { -5.2, 15.5, 0.0 }, float3 { 0.0, 0.0, 30.0 }))
    return spec_of(n)

def hero_helm_transverse(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    let bronze = hero_gold(0.9)
    add_child(n, dome(float3 { 5.0, 5.0, 4.8 }, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.8, 5.4, bronze, float3 { 0.3, -2.8, 0.0 }))
    if not hero_lowering:
        add_child(n, blob(float3 { 3.0, 0.6, 5.0 }, iron, float3 { -4.0, -4.2, 0.0 }, float3 { 0.0, 0.0, -25.0 }))
        for([1.0, -1.0]) side:
            add_child(n, blob(float3 { 1.6, 2.6, 0.5 }, iron, float3 { 2.0, -5.6, 4.3 * side }))
    add_child(n, box(float3 { 1.0, 1.6, 9.0 }, bronze, float3 { -0.2, 1.4, 0.0 }))
    add_child(n, decal("plume", 22.0, 9.0, float3 { -0.2, 6.6, 0.0 }, float3 { 1.0, 0.0, 0.0 }, true, float3 { 0.0, 1.0, 0.0 }, col(c, "crimson")))
    add_child(n, decal("plume", 22.0, 9.0, float3 { -0.4, 6.6, 0.0 }, float3 { -1.0, 0.0, 0.0 }, true, float3 { 0.0, 1.0, 0.0 }, col(c, "crimson")))
    return spec_of(n)

def hero_lion_hood(c:Colours) -> Spec:
    let n = mnode()
    let pelt = surf("hide", float3 { 0.95, 0.72, 0.42 }, 5.0)
    let mane = surf("mane", float3 { 0.62, 0.4, 0.22 }, 3.0)
    add_child(n, dome(float3 { 5.6, 5.6, 5.4 }, pelt, float3 { -0.4, -3.4, 0.0 }))
    let jaw = if hero_lowering: float3 { 1.0, 1.8, 0.0 } else: float3_0
    add_child(n, blob(float3 { 4.0, 2.2, 3.6 }, pelt, float3 { 4.2, -1.0, 0.0 } + jaw))
    add_child(n, blob(float3 { 1.4, 1.0, 2.0 }, plain(html("#3a2418")), float3 { 7.8, -1.2, 0.0 } + jaw))
    for([1.0, -1.0]) side:
        add_child(n, cone(0.1, 0.6, 2.0, plain(html("#f0ead8")), float3 { 6.4, -2.6, 1.6 * side } + jaw, float3 { 0.0, 0.0, 180.0 }, 6))
        add_child(n, blob(float3 { 1.2, 1.4, 0.7 }, pelt, float3 { 0.5, 2.2, 3.6 * side }))
        add_child(n, blob(float3 { 0.6, 0.4, 0.5 }, plain(html("#c89020")), float3 { 5.6, 0.6, 2.2 * side }))
    for(if hero_lowering: 0 else: 9) k:
        let a = MPI * 0.6 + float(k) * MPI * 0.1
        add_child(n, blob(float3 { 2.6, 4.0, 2.4 }, mane, float3 { hero_cos(a) * 5.4 - 0.6, -4.2, hero_sin(a) * 5.4 }))
    lift_kids(n, 0.4)
    return spec_of(n)

def hero_helm_plume(c:Colours) -> Spec:
    let n = mnode()
    let steel = surf("iron", float3 { 1.1, 1.1, 1.15 }, 3.0)
    add_child(n, dome(float3 { 5.0, 6.4, 4.8 }, steel, float3 { -0.4, -3.6, 0.0 }))
    add_child(n, ring(4.8, 5.4, hero_gold(), float3 { -0.2, -2.8, 0.0 }))
    add_child(n, cone(0.6, 1.0, 2.0, hero_gold(), float3 { -0.6, 3.6, 0.0 }))
    let cols = [col(c, "team"), html("#f4f0e4"), html("#d8b030"), col(c, "team"), html("#f4f0e4")]
    for(5) k:
        let a = float(k - 2) * 0.32
        let off = abs(float(k - 2))
        add_child(n, decal("plume", 7.0, 15.0, float3 { -2.0 - off * 1.0, 11.0 - off * 1.4, hero_sin(a) * 4.0 }, float3 { hero_sin(a) * 0.4, 0.0, hero_cos(a) }, true, normalize(float3 { -0.5, 1.0, hero_sin(a) }), cols[k]))
    lift_kids(n, 0.5)
    return spec_of(n)

def hero_wolf_hat(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", float3 { 0.62, 0.6, 0.58 }, 4.0)
    let dark = surf("rat_fur", float3 { 0.35, 0.33, 0.32 }, 4.0)
    add_child(n, dome(float3 { 5.4, 5.0, 5.2 }, fur, float3 { -0.4, -3.0, 0.0 }))
    let jaw = if hero_lowering: float3 { 0.6, 1.6, 0.0 } else: float3_0
    add_child(n, rod(float3 { 2.5, 0.0, 0.0 } + jaw, float3 { 8.0, -0.8, 0.0 } + jaw, 2.4, 1.3, fur))
    add_child(n, blob(float3 { 0.9, 0.7, 0.9 }, plain(html("#1a1412")), float3 { 8.8, -0.6, 0.0 } + jaw))
    for([1.0, -1.0]) side:
        add_child(n, cone(0.1, 1.5, 3.6, dark, float3 { 0.6, 2.8, 2.4 * side }, float3 { 10.0 * side, 0.0, -8.0 }, 6))
        add_child(n, blob(float3 { 0.5, 0.4, 0.4 }, plain(html("#e0c040")), float3 { 4.2, 0.9, 1.8 * side }))
    if not hero_lowering:
        add_child(n, blob(float3 { 2.6, 4.0, 3.8 }, fur, float3 { -4.0, -5.0, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    return spec_of(n)

def hero_helm_wings(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3 { 0.85, 0.85, 0.9 }, 3.0)
    let black = plain(html("#1c1a22"))
    add_child(n, dome(float3 { 5.0, 5.2, 4.8 }, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.8, 5.4, plain(col(c, "team")), float3 { 0.0, -3.4, 0.0 }))
    for([1.0, -1.0]) side:
        for(3) k:
            let kf = float(k)
            add_child(n, blob(float3 { 0.9, 3.6 - kf * 0.5, 0.35 }, black, float3 { -0.6 - kf * 1.5, 0.6 + kf * 0.2, (4.6 + kf * 0.3) * side }, float3 { 10.0 * side, 0.0, 30.0 + kf * 16.0 }))
    add_child(n, rod(float3 { 5.0, -3.6, 0.0 }, float3 { 5.5, -7.0, 0.0 }, 0.6, 0.5, iron))
    return spec_of(n)

def hero_double_crown(c:Colours) -> Spec:
    let n = mnode()
    let white = plain(html("#f2eee2"))
    add_child(n, cone(4.6, 5.2, 4.0, plain(html("#b02828")), float3 { -0.3, -1.2, 0.0 }, float3_0, 24))
    add_child(n, cone(1.6, 3.6, 7.0, white, float3 { -0.6, 4.2, 0.0 }, float3_0, 20))
    add_child(n, blob(float3 { 1.8, 1.8, 1.8 }, white, float3 { -0.6, 7.8, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.4, 8.0, 0.5 }, hero_gold(), float3 { -1.6, 9.0, 1.2 * side }, float3 { 0.0, 0.0, 8.0 }))
    hero_chain_rods(n, [float3 { 4.6, -1.0, 0.0 }, float3 { 5.4, 0.6, 0.0 }, float3 { 5.0, 2.0, 0.0 }], [0.6, 0.5, 0.7], hero_gold())
    lift_kids(n, 0.2)
    return spec_of(n)

def hero_jaguar_helm(c:Colours) -> Spec:
    let n = mnode()
    let pelt = surf("hide", float3 { 1.0, 0.75, 0.32 }, 4.0)
    let spot = plain(html("#2a1c12"))
    add_child(n, dome(float3 { 5.6, 5.4, 5.4 }, pelt, float3 { -0.4, -3.2, 0.0 }))
    let jaw = if hero_lowering: float3 { 1.0, 1.8, 0.0 } else: float3_0
    add_child(n, blob(float3 { 4.2, 2.6, 4.2 }, pelt, float3 { 4.0, -0.8, 0.0 } + jaw))
    add_child(n, blob(float3 { 1.4, 1.0, 2.0 }, spot, float3 { 8.0, -0.4, 0.0 } + jaw))
    for([1.0, -1.0]) side:
        add_child(n, cone(0.1, 0.7, 2.6, plain(html("#f4eedc")), float3 { 6.6, -2.8, 2.2 * side } + jaw, float3 { 0.0, 0.0, 180.0 }, 6))
        add_child(n, blob(float3 { 1.2, 1.3, 0.7 }, pelt, float3 { -0.2, 2.4, 3.6 * side }))
        add_child(n, blob(float3 { 0.6, 0.5, 0.5 }, plain(html("#d8c020")), float3 { 5.6, 1.0, 2.4 * side }))
        if not hero_lowering:
            add_child(n, blob(float3 { 2.4, 4.2, 1.2 }, pelt, float3 { 1.0, -8.6, 5.0 * side }, float3 { 0.0, 0.0, 10.0 }))
    for(12) k:
        let a = float(k) * 2.39996
        add_child(n, blob(float3_1 * 0.55, spot, on_surface(float3 { -0.4, -3.2, 0.0 }, float3 { 5.6, 5.4, 5.4 }, float3 { hero_cos(a) * 0.8 - 0.3, 0.4 + (float(k) * 0.37) % 0.6, hero_sin(a) }, 0.05)))
    let feather = [html("#20a060"), html("#e8c030"), html("#2060c0")]
    for(3) k:
        add_child(n, blob(float3 { 0.6, 4.0, 1.2 }, plain(feather[k]), float3 { -2.0 - float(k) * 0.8, 3.8, float(k - 1) * 1.6 }, float3 { 0.0, 0.0, 24.0 }))
    lift_kids(n, 0.35)
    return spec_of(n)

def hero_acorn_plume(c:Colours) -> Spec:
    let n = mnode()
    let cap = hero_gold()
    add_child(n, dome(float3 { 6.4, 5.6, 6.2 }, cap, float3 { -0.3, -2.4, 0.0 }))
    add_child(n, ring(6.0, 7.0, hero_gold(), float3 { -0.3, -2.2, 0.0 }))
    add_child(n, rod(float3 { -0.6, 3.0, 0.0 }, float3 { -0.8, 5.0, 0.0 }, 0.6, 0.4, hero_gold()))
    add_child(n, decal("plume", 8.0, 16.0, float3 { -3.0, 12.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }, true, float3 { -0.3, 1.0, 0.0 }, html("#e8c040")))
    return spec_of(n)

def hero_top_hat(c:Colours) -> Spec:
    let n = mnode()
    let felt = surf("bld_felt", float3 { 0.16, 0.15, 0.17 }, 3.0)
    let w = mnode()
    w.rot = float3 { 8.0, 0.0, -8.0 }
    w.scl = float3_1 * (if hero_lowering: 1.1 else: 1.4)
    w.pos = float3 { -3.2, 1.2, 0.0 }
    add_child(n, w)
    add_child(w, cone(5.6, 5.6, 0.6, felt, float3 { 0.0, -0.4, 0.0 }, float3_0, 24))
    add_child(w, cone(3.9, 3.4, 9.0, felt, float3 { 0.0, 4.4, 0.0 }, float3_0, 20))
    add_child(w, cone(3.55, 3.45, 1.4, plain(col(c, "team")), float3 { 0.0, 0.8, 0.0 }, float3_0, 20))
    return spec_of(n)

def hero_widow_hat(c:Colours) -> Spec:
    let n = mnode()
    let lace = surf("cloth", float3 { 0.14, 0.12, 0.16 }, 3.0)
    add_child(n, cone(1.2, 4.0, 8.0, lace, float3 { -0.8, 2.6, 0.0 }, float3 { 0.0, 0.0, 14.0 }, 16))
    add_child(n, cone(5.4, 5.4, 0.5, lace, float3 { 0.0, -1.0, 0.0 }, float3_0, 24))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 0.3, 9.0, 4.0 }, lace, float3 { -4.6, -5.2, 2.0 * side }, float3 { 0.0, 20.0 * side, -6.0 }))
    add_child(n, rod(float3 { 1.0, 1.0, 3.0 }, float3 { -2.0, 6.0, -1.0 }, 0.3, 0.3, surf("bone", float3_1, 2.0)))
    add_child(n, blob(float3_1 * 0.9, surf("bone", float3_1, 2.0), float3 { -2.0, 6.0, -1.0 }))
    return spec_of(n)

def hero_laurel_gold(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, ring(4.6, 5.2, hero_gold(), float3 { 0.0, -1.8, 0.0 }))
    for(14) k:
        let a = MPI * 0.2 + float(k) * MPI * 0.115
        for([1.0, -1.0]) side:
            let at = float3 { hero_cos(a) * 5.0, -1.5 + 0.35 * hero_sin(float(k) * 1.3), hero_sin(a) * 5.0 * side }
            add_child(n, blob(float3 { 1.4, 0.4, 0.7 }, hero_gold(1.05), at + float3 { 0.0, 0.6, 0.0 }, float3 { 0.0, -rad(a) * side, 35.0 }))
    return spec_of(n)

def hero_honey_crown(c:Colours) -> Spec:
    let n = mnode()
    let comb = plain(html("#e8b030"))
    let honey = plain(html("#d88a10"))
    add_child(n, cone(4.6, 5.0, 3.6, comb, float3 { -0.4, -0.6, 0.0 }, float3_0, 6))
    for(6) k:
        let a = HERO_TAU * float(k) / 6.0 + 0.5
        add_child(n, cone(0.1, 1.4, 3.0, comb, float3 { hero_cos(a) * 4.4 - 0.4, 2.6, hero_sin(a) * 4.4 }, float3_0, 6))
    for(5) k:
        let a = MPI * 0.7 + float(k) * 0.3
        add_child(n, blob(float3 { 0.6, 1.6, 0.6 }, honey, float3 { hero_cos(a) * 4.9 - 0.4, -2.6, hero_sin(a) * 4.9 }))
    add_child(n, blob(float3 { 0.9, 0.9, 0.9 }, plain(html("#f0d040")), float3 { -0.8, 4.6, 1.0 }))
    add_child(n, blob(float3 { 0.5, 0.5, 0.5 }, plain(html("#2a2010")), float3 { -0.2, 4.7, 1.2 }))
    return spec_of(n)

def hero_nightcap(c:Colours) -> Spec:
    let n = mnode()
    let a = plain(html("#e8e0f0"))
    let b = plain(html("#4a5ab0"))
    add_child(n, ring(4.5, 5.2, a, float3 { -0.5, -1.6, 0.0 }))
    let pts = [float3 { -0.5, -1.0, 0.0 }, float3 { 0.2, 3.0, 0.6 }, float3 { -0.6, 5.6, 3.2 }, float3 { -2.2, 5.0, 6.2 }, float3 { -3.4, 2.0, 7.8 }]
    let r = [4.6, 3.4, 2.4, 1.5, 0.8]
    for(pts.length - 1) i:
        let k = i + 1
        add_child(n, rod(pts[k - 1], pts[k], r[k - 1], r[k], if k % 2 == 0: a else: b))
    add_child(n, blob(float3_1 * 1.6, plain(html("#f4f0e8")), float3 { -3.6, 0.8, 8.2 }))
    return spec_of(n)

// ================================================================== back gear

def hero_cape_ermine(c:Colours) -> Spec:
    let n = mnode()
    let velvet = surf("cloth", col(c, "team"), 4.0)
    let ermine = plain(html("#f4f0e8"))
    for([1.0, -1.0]) side:
        let panel = slab([float2 { 2.0, 1.0 }, float2 { 3.0, -1.0 }, float2 { -2.0, -15.0 }, float2 { -14.0, -16.5 }, float2 { -15.0, -14.0 }, float2 { -1.5, 0.5 }], 0.7, velvet)
        panel.pos = float3 { 0.0, 0.0, 3.2 * side }
        panel.rot = float3 { 0.0, -8.0 * side, 0.0 }
        add_child(n, panel)
    add_child(n, ring(3.6, 4.8, ermine, float3 { 0.6, 0.6, 0.0 }, float3 { 0.0, 0.0, 10.0 }, float3 { 1.0, 1.6, 1.2 }))
    for(6) k:
        let kf = float(k)
        let z = (float(k % 2) - 0.5) * 5.0
        add_child(n, blob(float3 { 2.0, 1.0, 1.4 }, ermine, float3 { -3.0 - kf * 2.2, -14.8 - kf * 0.25, z }))
        add_child(n, blob(float3 { 0.3, 0.6, 0.3 }, plain(html("#141010")), float3 { -3.0 - kf * 2.2, -14.3 - kf * 0.25, z + 1.3 }))
    return spec_of(n)

def hero_roach_pet(c:Colours) -> Spec:
    let root = mnode()
    let shell = surf("chitin", html("#6a3a1a"), 3.0)
    add_child(root, rod(float3 { -1.0, -4.0, 0.0 }, float3 { 1.0, 3.4, -4.0 }, 0.4, 0.4, surf("leather", float3_1, 2.0)))
    add_child(root, blob(float3 { 2.4, 0.8, 2.0 }, surf("leather", float3_1, 2.0), float3 { 1.0, 3.6, -4.4 }))
    let n = mnode()
    n.pos = float3 { 1.0, 4.6, -4.4 }
    n.scl = float3_1 * 1.5
    add_child(root, n)
    let at = float3_0
    add_child(n, blob(float3 { 3.0, 1.4, 2.0 }, shell, at))
    add_child(n, blob(float3 { 1.0, 0.9, 1.2 }, plain(html("#2a1a10")), at + float3 { 3.0, 0.0, 0.0 }))
    for([1.0, -1.0]) side:
        hero_chain_rods(n, [at + float3 { 3.6, 0.4, 0.5 * side }, at + float3 { 7.0, 3.0, 2.0 * side }, at + float3 { 9.0, 2.0, 3.0 * side }], [0.15, 0.12, 0.1], plain(html("#2a1a10")))
        for(3) k:
            let kf = float(k)
            add_child(n, rod(at + float3 { 1.5 - kf * 1.5, -0.6, 1.2 * side }, at + float3 { 2.0 - kf * 2.0, -1.6, 2.6 * side }, 0.18, 0.12, plain(html("#2a1a10"))))
    return spec_of(root)

def hero_moss_mantle(c:Colours) -> Spec:
    let n = mnode()
    let moss = surf("foliage", float3 { 0.7, 0.9, 0.45 }, 5.0)
    add_child(n, blob(float3 { 4.0, 3.6, 6.0 }, moss, float3 { -4.6, 0.5, 0.0 }))
    add_child(n, blob(float3 { 3.0, 4.0, 5.0 }, moss, float3 { -6.4, -4.0, 0.0 }))
    for(3) k:
        let kf = float(k)
        let at = float3 { -5.6 + kf * 1.2, 3.4 - kf * 0.5, (kf - 1.0) * 3.0 }
        add_child(n, rod(at, at + float3 { 0.0, 2.2, 0.0 }, 0.5, 0.45, plain(html("#f0e8d0")), false))
        add_child(n, dome(float3 { 1.8, 1.3, 1.8 }, plain(html("#c83a2a")), at + float3 { 0.0, 2.2, 0.0 }))
    for(4) k:
        let kf = float(k)
        let a = -0.6 + kf * 0.4
        hero_chain_rods(n, [float3 { -6.0, 2.0, -2.0 }, float3 { -8.0, 6.0, -2.0 + hero_sin(a) * 2.0 }, float3 { -11.0, 8.0 + kf * 0.5, -2.0 + hero_sin(a) * 4.0 }], [0.4, 0.5, 0.2], surf("reed_leaf", float3 { 0.6, 0.85, 0.4 }, 3.0))
    return spec_of(n)

def hero_conch_horn(c:Colours) -> Spec:
    let n = mnode()
    let shell = surf("bone", float3 { 1.05, 0.88, 0.75 }, 3.0)
    let pink = plain(html("#f0a090"))
    add_child(n, rod(float3 { -1.0, -2.0, -2.0 }, float3 { -1.0, -2.0, 2.0 }, 0.4, 0.4, surf("leather", float3_1, 2.0)))
    add_child(n, cone(0.3, 3.4, 13.0, shell, float3 { -3.0, 1.0, 0.0 }, float3 { 0.0, 0.0, 55.0 }, 14))
    add_child(n, blob(float3 { 3.8, 3.8, 3.4 }, shell, float3 { -7.4, -2.6, 0.0 }))
    for(3) k:
        let kf = float(k)
        add_child(n, cone(0.1, 0.9, 2.4, shell, float3 { -7.4 + kf * 1.6, 1.0 - kf * 0.6, 2.4 }, float3 { 0.0, 0.0, -20.0 }, 6))
    add_child(n, cone(3.5, 3.6, 0.6, pink, float3 { -8.4, -4.0, 0.0 }, float3 { 0.0, 0.0, 55.0 }, 14))
    return spec_of(n)

def hero_cape_long(c:Colours) -> Spec:
    let n = mnode()
    let cloth = surf("cloth", col(c, "crimson"), 4.0)
    for([1.0, -1.0]) side:
        let panel = slab([float2 { 2.0, 1.0 }, float2 { 3.0, -1.0 }, float2 { -5.0, -15.0 }, float2 { -13.0, -16.0 }, float2 { -13.5, -12.0 }, float2 { -1.5, 0.5 }], 0.6, cloth)
        panel.pos = float3 { 0.0, 0.0, 3.0 * side }
        panel.rot = float3 { 0.0, -10.0 * side, 0.0 }
        add_child(n, panel)
    add_child(n, blob(float3 { 1.2, 1.2, 0.7 }, hero_gold(), float3 { 1.5, 0.0, 1.4 }))
    return spec_of(n)

def hero_lion_pelt(c:Colours) -> Spec:
    let n = mnode()
    let pelt = surf("hide", float3 { 0.95, 0.72, 0.42 }, 5.0)
    add_child(n, slab([float2 { 2.0, 1.0 }, float2 { 2.0, -2.0 }, float2 { -1.0, -15.0 }, float2 { -6.0, -16.0 }, float2 { -7.0, -12.0 }, float2 { -2.0, 1.0 }], 1.4, pelt, float3_0))
    for([1.0, -1.0]) side:
        hero_chain_rods(n, [float3 { 0.5, 0.0, 3.0 * side }, float3 { 3.0, -2.0, 3.6 * side }], [1.2, 1.0], pelt)
    hero_chain_rods(n, [float3 { -5.0, -15.0, 0.0 }, float3 { -8.0, -17.0, 0.0 }, float3 { -9.5, -18.0, 0.0 }], [0.6, 0.5, 0.4], pelt)
    add_child(n, blob(float3 { 1.0, 1.6, 1.0 }, surf("mane", float3 { 0.5, 0.3, 0.18 }, 2.0), float3 { -10.0, -18.4, 0.0 }))
    return spec_of(n)

def hero_cape_heraldic(c:Colours) -> Spec:
    let n = mnode()
    let team = surf("cloth", col(c, "team"), 4.0)
    let gold_cloth = surf("cloth", html("#d8b030"), 4.0)
    for([1, -1]) side:
        for(2) half:
            let hf = float(half)
            let top = if half == 0: 1.0 else: -7.0
            let back = hf * 1.5
            let pts = [float2 { 2.0 - back, top }, float2 { 2.5 - back, top - 1.0 }, float2 { 0.5 - hf * 1.5 - back * 2.0, top - 8.5 }, float2 { -4.5 - hf * 3.0 - back * 2.0, top - 9.0 }, float2 { -4.0 - hf * 1.5 - back, top - 1.0 }]
            let panel = slab(pts, 0.6, if (half + (side + 1) / 2) % 2 == 0: team else: gold_cloth)
            panel.pos = float3 { 0.0, 0.0, 3.0 * float(side) }
            panel.rot = float3 { 0.0, -10.0 * float(side), 0.0 }
            add_child(n, panel)
    return spec_of(n)

def hero_horsetail_standard(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { 0.0, -4.0, 0.0 }, float3 { 0.0, 26.0, 0.0 }, 0.5, 0.45, surf("wood_grain", float3_1, 5.0), false))
    add_child(n, ring(1.0, 2.6, hero_gold(), float3 { 0.0, 24.0, 0.0 }))
    for(3) k:
        add_child(n, cone(0.05, 0.5, 4.0, hero_gold(), float3 { 0.0, 28.0, float(k - 1) * 1.6 }, float3_0, 6))
    for(7) k:
        let a = HERO_TAU * float(k) / 7.0
        let hair = if k % 2 == 0: float3 { 0.85, 0.82, 0.75 } else: float3 { 0.25, 0.2, 0.18 }
        hero_chain_rods(n, [float3 { hero_cos(a) * 1.8, 23.6, hero_sin(a) * 1.8 }, float3 { hero_cos(a) * 2.4, 18.0, hero_sin(a) * 2.4 }, float3 { hero_cos(a) * 2.0, 13.0 + float(k % 2), hero_sin(a) * 2.0 }], [0.6, 0.6, 0.3], surf("mane", hair, 2.0))
    return spec_of(n)

def hero_cat_pet(c:Colours) -> Spec:
    let root = mnode()
    let fur = surf("rat_fur", float3 { 0.8, 0.66, 0.45 }, 3.0)
    add_child(root, rod(float3 { -1.0, -4.0, 0.0 }, float3 { 0.5, 2.6, -6.0 }, 0.4, 0.4, surf("leather", float3_1, 2.0)))
    let n = mnode()
    n.pos = float3 { 0.5, 3.0, -6.4 }
    n.scl = float3_1 * 1.4
    add_child(root, n)
    let at = float3 { 0.0, 0.6, 0.0 }
    add_child(n, blob(float3 { 2.0, 0.6, 2.0 }, plain(html("#2050a0")), at + float3 { 0.0, -0.6, 0.0 }))
    add_child(n, blob(float3 { 2.0, 2.8, 1.8 }, fur, at + float3 { -0.4, 2.0, 0.0 }))
    add_child(n, blob(float3 { 1.5, 1.4, 1.4 }, fur, at + float3 { 0.8, 5.0, 0.0 }))
    add_child(n, ring(1.2, 1.7, hero_gold(), at + float3 { 0.2, 3.6, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, cone(0.05, 0.6, 1.6, fur, at + float3 { 0.6, 6.6, 0.8 * side }, float3 { 0.0, 0.0, -8.0 }, 6))
        add_child(n, blob(float3 { 0.3, 0.35, 0.25 }, plain(html("#30a040")), at + float3 { 2.0, 5.3, 0.6 * side }))
    hero_chain_rods(n, [at + float3 { -1.8, 0.4, 0.0 }, at + float3 { -3.4, -1.6, -0.6 }, at + float3 { -3.0, -4.2, -1.0 }], [0.4, 0.35, 0.3], fur)
    return spec_of(root)

def hero_raven_pet(c:Colours) -> Spec:
    let root = mnode()
    let n = mnode()
    n.pos = float3 { 0.5, 3.0, -6.4 }
    n.scl = float3_1 * 1.4
    add_child(root, n)
    let black = surf("mane", float3 { 0.16, 0.15, 0.2 }, 2.0)
    add_child(n, blob(float3 { 2.2, 1.6, 1.4 }, black, float3 { -0.2, 1.4, 0.0 }, float3 { 0.0, 0.0, 20.0 }))
    add_child(n, blob(float3 { 1.1, 1.1, 1.0 }, black, float3 { 1.6, 2.8, 0.0 }))
    add_child(n, cone(0.05, 0.45, 1.6, plain(html("#3a3640")), float3 { 2.9, 2.6, 0.0 }, float3 { 0.0, 0.0, -100.0 }, 6))
    add_child(n, blob(float3 { 1.6, 0.4, 1.0 }, black, float3 { -2.4, 0.6, 0.0 }, float3 { 0.0, 0.0, 25.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.22, 0.22, 0.2 }, plain(html("#e0c040")), float3 { 2.1, 3.1, 0.75 * side }))
    add_child(n, ring(0.7, 1.1, plain(col(c, "team")), float3 { 0.2, 0.2, 0.0 }))
    return spec_of(root)

def hero_back_flags(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("wood_grain", float3 { 0.6, 0.35, 0.25 }, 4.0)
    add_child(n, box(float3 { 1.6, 4.0, 5.0 }, surf("leather", float3 { 0.5, 0.3, 0.2 }, 2.0), float3 { -0.8, -1.0, 0.0 }))
    for(4) k:
        let z = (float(k) - 1.5) * 1.6
        let tilt = (float(k) - 1.5) * 9.0
        let foot = float3 { -1.0, -2.0, z }
        let top = foot + float3 { -1.5, 17.0, z * 2.4 }
        add_child(n, rod(foot, top, 0.3, 0.25, wood, false))
        let flag = slab([float2 { 0.0, 0.0 }, float2 { 0.0, -7.0 }, float2 { -5.0, -0.5 }], 0.3, surf("cloth", if k % 2 == 0: col(c, "team") else: html("#e8d040"), 3.0), top + float3 { 0.0, -0.5, 0.0 })
        flag.rot = float3 { tilt, 0.0, 0.0 }
        add_child(n, flag)
    return spec_of(n)

def hero_quetzal_fan(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, box(float3 { 1.4, 4.0, 5.0 }, surf("wicker", float3_1, 3.0), float3 { -0.8, -0.6, 0.0 }))
    let cols = [html("#1aa060"), html("#18c080"), html("#e8c030"), html("#c02828")]
    let from_ = float3 { -2.4, 1.0, 0.0 }
    for(9) k:
        let a = float(k - 4) * 0.28
        let tip = float3 { -4.0, 14.0 * hero_cos(a) + 2.0, 14.0 * hero_sin(a) }
        add_child(n, decal("plume", 4.0, 15.0, from_ + (tip - from_) * 0.55, float3 { 1.0, 0.0, 0.0 }, true, normalize(tip - from_), cols[k % 4]))
    return spec_of(n)

def hero_sapling(c:Colours) -> Spec:
    let n = mnode()
    let bark = surf("bark_plate", float3 { 0.8, 0.7, 0.6 }, 4.0)
    let moss = surf("foliage", float3 { 0.7, 0.9, 0.45 }, 5.0)
    let leaves = surf("foliage", float3 { 0.85, 1.05, 0.6 }, 6.0)
    add_child(n, blob(float3 { 3.6, 3.0, 5.4 }, moss, float3 { -2.0, -1.0, 0.0 }))
    hero_chain_rods(n, [float3 { -2.0, 0.0, 0.0 }, float3 { -3.0, 8.0, 0.0 }, float3 { -2.0, 16.0, 0.0 }], [1.2, 0.9, 0.6], bark)
    hero_chain_rods(n, [float3 { -3.0, 8.0, 0.0 }, float3 { -6.0, 12.0, 2.0 }], [0.6, 0.4], bark)
    add_child(n, blob(float3 { 5.0, 4.4, 5.0 }, leaves, float3 { -2.0, 18.0, 0.0 }))
    add_child(n, blob(float3 { 3.2, 3.0, 3.2 }, leaves, float3 { -6.4, 13.6, 2.4 }))
    add_child(n, blob(float3 { 0.7, 0.7, 0.7 }, plain(html("#c83a2a")), float3 { 0.0, 17.0, 4.0 }))
    return spec_of(n)

def hero_web_wheel(c:Colours) -> Spec:
    let n = mnode()
    let bone = surf("bone", float3_1, 2.0)
    let silk = plain(html("#e4e0ec"))
    let at = float3 { -3.0, 8.0, 0.0 }
    add_child(n, rod(float3 { -0.6, -2.0, 0.0 }, at, 0.4, 0.4, bone))
    add_child(n, ring(7.4, 8.2, bone, at, float3 { 0.0, 0.0, 90.0 }))
    for(8) k:
        let a = HERO_TAU * float(k) / 8.0
        add_child(n, rod(at, at + float3 { 0.0, hero_cos(a) * 7.6, hero_sin(a) * 7.6 }, 0.12, 0.12, silk, false))
    for([2.6, 5.0]) r:
        add_child(n, ring(r - 0.1, r + 0.1, silk, at, float3 { 0.0, 0.0, 90.0 }))
    add_child(n, blob(float3 { 1.0, 1.0, 1.0 }, plain(html("#1a1418")), at + float3 { 0.2, 2.0, 2.4 }))
    return spec_of(n)

def hero_aquila(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { 0.0, -4.0, 0.0 }, float3 { 0.0, 24.0, 0.0 }, 0.5, 0.45, surf("wood_grain", float3_1, 5.0), false))
    add_child(n, box(float3 { 0.5, 5.0, 4.0 }, surf("cloth", col(c, "team"), 3.0), float3 { 0.4, 19.0, 0.0 }))
    add_child(n, box(float3 { 0.7, 0.6, 4.4 }, hero_gold(), float3 { 0.4, 21.6, 0.0 }))
    add_child(n, blob(float3 { 1.6, 1.4, 1.2 }, hero_gold(), float3 { 0.4, 25.2, 0.0 }))
    add_child(n, blob(float3 { 0.9, 0.8, 0.7 }, hero_gold(), float3 { 1.8, 26.4, 0.0 }))
    add_child(n, cone(0.05, 0.4, 1.0, hero_gold(), float3 { 2.8, 26.2, 0.0 }, float3 { 0.0, 0.0, -100.0 }, 6))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.0, 3.0, 2.6 }, hero_gold(), float3 { -0.2, 27.0, 2.6 * side }, float3 { 30.0 * side, 0.0, 0.0 }))
    add_child(n, ring(1.4, 2.2, hero_gold(), float3 { 0.0, 23.6, 0.0 }))
    return spec_of(n)

def hero_beehive(c:Colours) -> Spec:
    let n = mnode()
    let straw = surf("thatch", float3 { 1.0, 0.9, 0.7 }, 3.0)
    for(5) k:
        let w = 4.6 - abs(float(k) - 1.5) * 0.7
        add_child(n, ring(1.0, 1.25, straw, float3 { -4.0, -2.0 + float(k) * 2.0, 0.0 }, float3_0, float3 { w, 2.2, w }))
    add_child(n, dome(float3 { 3.2, 2.4, 3.2 }, straw, float3 { -4.0, 7.4, 0.0 }))
    add_child(n, blob(float3 { 0.8, 1.0, 0.6 }, plain(html("#1a1208")), float3 { -4.0, -0.6, 4.6 }))
    add_child(n, rod(float3 { 0.5, 2.0, -3.0 }, float3 { 0.5, 2.0, 3.0 }, 0.4, 0.4, surf("leather", float3_1, 2.0)))
    for(4) k:
        let kf = float(k)
        let at = float3 { -6.0 + kf * 2.4, 6.0 + float(k % 2) * 3.0, 5.0 - kf * 2.6 }
        add_child(n, blob(float3_1 * 0.6, plain(html("#f0d040")), at))
    return spec_of(n)

def hero_pillow(c:Colours) -> Spec:
    let n = mnode()
    let linen = surf("cloth", float3 { 0.92, 0.9, 0.96 }, 4.0)
    add_child(n, blob(float3 { 2.4, 6.0, 5.4 }, linen, float3 { -2.8, -2.0, 0.0 }, float3 { 0.0, 0.0, 8.0 }))
    for([float3 { -2.6, 3.6, 4.6 }, float3 { -2.6, 3.6, -4.6 }, float3 { -3.4, -7.4, 4.4 }, float3 { -3.4, -7.4, -4.4 }]) corner:
        add_child(n, blob(float3 { 1.0, 1.0, 1.0 }, linen, corner))
    add_child(n, ring(5.0, 5.6, surf("leather", float3_1, 2.0), float3 { -1.6, -2.0, 0.0 }, float3 { 90.0, 0.0, 0.0 }, float3 { 0.6, 1.0, 1.2 }))
    for(3) k:
        let kf = float(k)
        add_child(n, blob(float3 { 0.4, 0.8, 0.4 }, plain(html("#4a5ab0")), float3 { -5.1, 1.0 - kf * 3.0, (kf - 1.0) * 2.4 }))
    return spec_of(n)

// ================================================================== held

def hero_sceptre_cheese(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -4.0, 0.0 }, float3 { 3.0, 14.0, 0.0 }, 0.6, 0.6, hero_gold()))
    add_child(n, ring(0.6, 1.2, hero_gold(), float3 { 1.2, 6.0, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    add_child(n, cone(2.4, 0.8, 2.0, hero_gold(), float3 { 3.2, 15.0, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    add_child(n, slab([float2 { -2.5, 0.0 }, float2 { 3.0, 0.0 }, float2 { 0.5, 4.5 }], 3.0, surf("cheese", float3_1, 3.0), float3 { 3.4, 16.0, 0.0 }))
    return spec_of(n)

def hero_cleaver(c:Colours) -> Spec:
    let n = mnode()
    let rust = surf("iron", float3 { 1.15, 1.05, 1.0 }, 3.0)
    add_child(n, rod(float3 { 4.0, -4.0, 0.0 }, float3 { -2.0, 7.0, 0.0 }, 0.8, 0.8, surf("wood_grain", float3_1, 3.0)))
    let b = slab([float2 { 0.0, 0.0 }, float2 { 15.0, 0.0 }, float2 { 16.0, 8.0 }, float2 { 1.0, 8.0 }], 0.7, rust)
    b.pos = float3 { -2.0, 7.0, 0.0 }
    b.rot = float3 { 0.0, 0.0, 118.0 }
    add_child(n, b)
    add_child(n, blob(float3 { 1.0, 1.0, 0.6 }, plain(html("#2a2420")), float3 { -4.6, 10.0, 0.4 }))
    return spec_of(n)

def hero_lantern_staff(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("bark_plate", float3 { 0.75, 0.65, 0.55 }, 3.0)
    hero_chain_rods(n, [float3 { -1.0, -8.0, 0.0 }, float3 { 1.0, 6.0, 0.0 }, float3 { 3.0, 16.0, 0.0 }, float3 { 7.0, 19.0, 0.0 }, float3 { 8.0, 17.0, 0.0 }], [0.8, 0.75, 0.7, 0.6, 0.5], wood)
    add_child(n, rod(float3 { 8.0, 17.0, 0.0 }, float3 { 8.0, 14.5, 0.0 }, 0.15, 0.15, plain(HERO_ROPE), false))
    add_child(n, cone(1.2, 1.6, 3.0, surf("wicker", float3_1, 2.0), float3 { 8.0, 13.0, 0.0 }))
    add_child(n, blob(float3 { 1.1, 1.3, 1.1 }, glow(html("#d8f060")), float3 { 8.0, 13.0, 0.0 }))
    return spec_of(n)

def hero_anchor(c:Colours) -> Spec:
    let n = mnode()
    let rust = surf("iron", float3 { 0.7, 0.55, 0.45 }, 3.0)
    let a = float3 { 5.0, -5.0, 0.0 }
    let b = float3 { -8.0, 18.0, 0.0 }
    add_child(n, rod(a, b, 0.9, 0.9, rust))
    let d = normalize(b - a)
    let across = float3 { -d.y, d.x, 0.0 }
    add_child(n, rod(b - across * 3.5, b + across * 3.5, 0.6, 0.6, rust))
    add_child(n, ring(1.0, 1.7, rust, b + d * 1.6, float3 { 90.0, 0.0, 0.0 }))
    for([1.0, -1.0]) side:
        hero_chain_rods(n, [a, a + across * 3.5 * side - d * 1.0, a + across * 5.0 * side + d * 2.5], [0.9, 0.8, 0.4], rust)
    hero_chain_rods(n, [b + d * 0.5, b - across * 2.0 - d * 4.0, b + across * 1.0 - d * 8.0], [0.4, 0.3, 0.2], surf("reed_leaf", float3 { 0.55, 0.75, 0.45 }, 3.0))
    return spec_of(n)

def hero_guandao(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { 6.0, -7.0, 0.0 }
    let b = float3 { -11.0, 22.0, 0.0 }
    add_child(n, rod(a, b, 0.75, 0.7, surf("wood_grain", float3 { 0.7, 0.35, 0.25 }, 4.0), false))
    let d = normalize(b - a)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade([float2 { 0.0, -1.0 }, float2 { 5.0, -2.6 }, float2 { 10.0, -2.4 }, float2 { 12.5, 0.5 }, float2 { 9.0, 1.2 }, float2 { 7.0, 2.6 }, float2 { 6.0, 1.2 }, float2 { 0.0, 1.4 }], 0.6, surf("iron", float3 { 1.1, 1.1, 1.15 }, 3.0), b, ang))
    add_child(n, ring(0.7, 1.4, hero_gold(), b - d * 0.3, float3 { 0.0, 0.0, ang - 90.0 }))
    add_child(n, blob(float3 { 1.0, 1.6, 1.0 }, plain(html("#c02828")), b - d * 1.6))
    return spec_of(n)

def hero_root_club(c:Colours) -> Spec:
    let n = mnode()
    let bark = surf("bark_plate", float3 { 0.8, 0.7, 0.6 }, 3.0)
    hero_chain_rods(n, [float3 { 1.5, -1.5, 0.0 }, float3 { -3.0, 5.0, 1.5 }, float3 { -10.0, 12.0, 3.5 }], [0.9, 1.3, 2.4], bark)
    add_child(n, blob(float3 { 3.2, 2.8, 2.8 }, bark, float3 { -11.5, 13.5, 3.5 }))
    for(3) k:
        let a = float(k) * 2.1
        hero_chain_rods(n, [float3 { -11.5, 13.5, 3.5 }, float3 { -11.5 + hero_cos(a) * 3.5, 16.0 + hero_sin(a) * 2.0, 3.5 + hero_sin(a) * 2.5 }], [1.0, 0.4], bark)
    add_child(n, blob(float3 { 1.4, 0.5, 1.0 }, surf("leaf", float3 { 0.7, 1.0, 0.5 }, 3.0), float3 { -9.0, 16.5, 5.0 }, float3 { 0.0, 0.0, 30.0 }))
    return spec_of(n)

def hero_cane(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { 0.0, 1.0, 0.0 }, float3 { 1.0, -11.0, 0.0 }, 0.4, 0.35, plain(html("#141216"))))
    add_child(n, blob(float3 { 1.3, 1.4, 1.2 }, surf("iron", float3 { 1.2, 1.2, 1.25 }, 2.0), float3 { 0.0, 1.8, 0.0 }))
    add_child(n, blob(float3 { 0.6, 0.5, 0.4 }, surf("iron", float3 { 1.2, 1.2, 1.25 }, 2.0), float3 { 0.9, 1.0, 0.0 }))
    return spec_of(n)

def hero_trunk_club(c:Colours) -> Spec:
    let n = mnode()
    let bark = surf("bark_plate", float3 { 0.85, 0.75, 0.62 }, 4.0)
    hero_chain_rods(n, [float3 { 5.0, -5.0, 0.0 }, float3 { -4.0, 9.0, 0.0 }, float3 { -11.0, 21.0, 0.0 }], [1.2, 1.9, 2.8], bark)
    add_child(n, cone(2.6, 2.6, 0.6, plain(html("#d8b888")), float3 { -11.3, 21.5, 0.0 }, float3 { 0.0, 0.0, 30.0 }, 14))
    hero_chain_rods(n, [float3 { -6.0, 12.0, 0.0 }, float3 { -3.0, 16.0, 1.6 }], [0.6, 0.3], bark)
    return spec_of(n)

def hero_log_club(c:Colours) -> Spec:
    let n = mnode()
    let bark = surf("bark_plate", float3 { 0.7, 0.6, 0.5 }, 4.0)
    hero_chain_rods(n, [float3 { -1.0, -3.0, 0.0 }, float3 { 2.0, 6.0, 0.0 }, float3 { 5.0, 16.0, 0.0 }], [1.1, 1.8, 2.6], bark)
    add_child(n, cone(2.5, 2.5, 0.5, plain(html("#d8b888")), float3 { 5.2, 16.6, 0.0 }, float3 { 0.0, 0.0, -16.0 }, 14))
    add_child(n, blob(float3 { 2.0, 1.0, 1.6 }, plain(html("#c8d0f0")), float3 { 3.2, 10.0, 1.8 }, float3 { 0.0, 0.0, 20.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ shields

def hero_cheese_wheel(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 4.6, 0.5, 0.4 }, SHIELD_FACE)
    let cheese = surf("cheese", float3_1, 4.0)
    let rind = plain(html("#c89a30"))
    add_child(h, disc(7.2, 2.4, rind, 0.0))
    add_child(h, disc(6.7, 2.6, cheese, 0.0))
    for(5) k:
        let kf = float(k)
        let a = kf * 2.39996
        let hole = disc(0.6 + (kf * 0.37) % 0.6, 0.4, plain(html("#b08420")), 1.35)
        hole.pos = float3 { hero_cos(a) * (1.8 + kf * 0.8), hero_sin(a) * (1.8 + kf * 0.8), 1.35 }
        add_child(h, hole)
    let bite = slab([float2 { 0.0, 0.0 }, float2 { 7.4, 2.3 }, float2 { 7.4, -2.3 }], 2.8, plain(html("#3a2a1a")))
    bite.rot = float3 { 0.0, 0.0, rad(0.9) }
    add_child(h, bite)
    return spec_of(n)

def hero_gold_shield(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 4.4, 0.5, 0.4 }, SHIELD_FACE)
    let outline = [float2 { 0.0, 9.0 }, float2 { 4.0, 5.0 }, float2 { 5.0, -1.0 }, float2 { 3.0, -6.0 }, float2 { 0.0, -9.0 }, float2 { -3.0, -6.0 }, float2 { -5.0, -1.0 }, float2 { -4.0, 5.0 }]
    add_child(h, slab(outline, 0.8, hero_gold(1.1)))
    add_child(h, rod(float3 { 0.0, 8.5, 0.5 }, float3 { 0.0, -8.5, 0.5 }, 0.35, 0.35, hero_gold(0.8)))
    for(3) k:
        let kf = float(k)
        add_child(h, rod(float3 { 0.0, 4.0 - kf * 4.0, 0.5 }, float3 { 3.5, 6.0 - kf * 4.0, 0.5 }, 0.25, 0.2, hero_gold(0.8)))
        add_child(h, rod(float3 { 0.0, 4.0 - kf * 4.0, 0.5 }, float3 { -3.5, 6.0 - kf * 4.0, 0.5 }, 0.25, 0.2, hero_gold(0.8)))
    add_child(h, disc(1.8, 0.6, plain(col(c, "team")), 0.6))
    return spec_of(n)

// ------------------------------------------------------------------ this file's parts by id
def build_heroes(base:string, c:Colours) -> Spec?:
    switch base:
        case "hero.crown_gnawed": return hero_crown_gnawed(c)
        case "hero.crown_tiny": return hero_crown_tiny(c)
        case "hero.tricorn": return hero_tricorn(c)
        case "hero.weed_crown": return hero_weed_crown(c)
        case "hero.lily_hat": return hero_lily_hat(c)
        case "hero.helm_transverse": return hero_helm_transverse(c)
        case "hero.lion_hood": return hero_lion_hood(c)
        case "hero.helm_plume": return hero_helm_plume(c)
        case "hero.wolf_hat": return hero_wolf_hat(c)
        case "hero.helm_wings": return hero_helm_wings(c)
        case "hero.double_crown": return hero_double_crown(c)
        case "hero.jaguar_helm": return hero_jaguar_helm(c)
        case "hero.acorn_plume": return hero_acorn_plume(c)
        case "hero.top_hat": return hero_top_hat(c)
        case "hero.widow_hat": return hero_widow_hat(c)
        case "hero.laurel_gold": return hero_laurel_gold(c)
        case "hero.honey_crown": return hero_honey_crown(c)
        case "hero.nightcap": return hero_nightcap(c)
        case "hero.cape_ermine": return hero_cape_ermine(c)
        case "hero.roach_pet": return hero_roach_pet(c)
        case "hero.moss_mantle": return hero_moss_mantle(c)
        case "hero.conch_horn": return hero_conch_horn(c)
        case "hero.cape_long": return hero_cape_long(c)
        case "hero.lion_pelt": return hero_lion_pelt(c)
        case "hero.cape_heraldic": return hero_cape_heraldic(c)
        case "hero.horsetail_standard": return hero_horsetail_standard(c)
        case "hero.cat_pet": return hero_cat_pet(c)
        case "hero.raven_pet": return hero_raven_pet(c)
        case "hero.back_flags": return hero_back_flags(c)
        case "hero.quetzal_fan": return hero_quetzal_fan(c)
        case "hero.sapling": return hero_sapling(c)
        case "hero.web_wheel": return hero_web_wheel(c)
        case "hero.aquila": return hero_aquila(c)
        case "hero.beehive": return hero_beehive(c)
        case "hero.pillow": return hero_pillow(c)
        case "hero.sceptre_cheese": return hero_sceptre_cheese(c)
        case "hero.cleaver": return hero_cleaver(c)
        case "hero.lantern_staff": return hero_lantern_staff(c)
        case "hero.anchor": return hero_anchor(c)
        case "hero.guandao": return hero_guandao(c)
        case "hero.root_club": return hero_root_club(c)
        case "hero.cane": return hero_cane(c)
        case "hero.trunk_club": return hero_trunk_club(c)
        case "hero.log_club": return hero_log_club(c)
        case "hero.cheese_wheel": return hero_cheese_wheel(c)
        case "hero.gold_shield": return hero_gold_shield(c)
        case "hero.lion_hood_low":
            hero_lowering = true
            return hero_low(hero_lion_hood(c))
        case "hero.wolf_hat_low":
            hero_lowering = true
            return hero_low(hero_wolf_hat(c))
        case "hero.jaguar_helm_low":
            hero_lowering = true
            return hero_low(hero_jaguar_helm(c))
        case "hero.helm_transverse_low":
            hero_lowering = true
            return hero_low(hero_helm_transverse(c))
        case "hero.tricorn_low":
            hero_lowering = true
            return hero_low(hero_tricorn(c))
        case "hero.top_hat_low":
            hero_lowering = true
            return hero_low(hero_top_hat(c))
        default: return nil
