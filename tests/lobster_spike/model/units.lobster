// ------------------------------------------------------------------ unit parts I (unit_models.gd: poses, frog, rat, spider, human)
// Each builder is unit_models.gd's of the same name (`_body_frog` -> body_frog), line for line; its
// comments are there. Part units are about one 2D pixel: x the way the unit faces, y up, z the near side.

var hold = "low"                     // the body being built: how its near hand holds the weapon (arm_pose)
var rest = ""                        // ...and the idle pose it rests in while holding it (creature kit)

let INK = html("#2a1a12")
let REACH_FLOOR = 8.0
let SHIELD_FACE = float3 { 1.0, 0.1, 0.45 }

// The near arm's elbow and hand for the body's hold (unit_models.gd arm_pose).
def arm_pose(sh:float3, elbow:float3, hand:float3, head:float3) -> float3, float3:
    let z = sh.z
    switch hold:
        case "throw": return sh + float3 { 1.0, 3.5, 2.2 }, sh + float3 { -2.5, 9.0, 2.4 }
        case "mouth": return float3 { sh.x + 4.5, sh.y - 3.5, z + 1.2 }, float3 { head.x + 6.0, head.y + 1.0, z * 0.45 }
        case "overhead": return sh + float3 { 1.5, 4.5, 2.0 }, sh + float3 { 0.5, 9.0, 2.2 }
        case "draw": return sh + float3 { 4.5, 0.2, 1.0 }, sh + float3 { 9.5, 0.6, 0.8 }
        case "shoulder": return sh + float3 { 2.0, -4.5, 2.2 }, sh + float3 { 3.5, -2.0, 2.4 }
        case "aim": return sh + float3 { 3.0, -3.0, 1.4 }, sh + float3 { 7.5, -1.0, 0.6 }
        case "reach":
            let to = sh + float3 { 6.5, -6.5, 1.8 }
            return sh + float3 { 3.5, -3.0, 1.3 }, float3 { to.x, max(to.y, REACH_FLOOR), to.z }
        case "raise": return sh + float3 { -1.0, 3.5, 2.2 }, sh + float3 { -2.5, 8.0, 2.6 }
        case "thrust": return sh + float3 { 4.0, -0.5, 1.4 }, sh + float3 { 9.0, -1.0, 0.9 }
        default: return elbow, hand

// A shield slung on the back ("<shield>@slung" upright behind the shoulders, "@slung_flat" lying on top).
def slung(built:Spec, how:string) -> Spec:
    let f = normalize(SHIELD_FACE)
    let u = normalize(float3 { 0.0, 1.0, 0.0 } - f * f.y)
    let from_ = Basis { f, u, cross(f, u) }
    let face = if how == "@slung": float3 { -1.0, 0.2, 0.0 } else: float3 { -0.45, 1.0, 0.0 }
    let up = if how == "@slung": float3 { 0.0, 1.0, 0.0 } else: float3 { -1.0, -0.45, 0.0 }
    let tf = normalize(face)
    let tu = normalize(up - tf * dot(tf, up))
    let to = Basis { tf, tu, cross(tf, tu) }
    let turn = bmul(to, binverse(from_))
    let n = mnode()
    let inner = built.node
    set_xform(inner, Xform { turn, bxf(turn, -float3 { 3.0, 0.4, 1.5 }) })
    add_child(n, inner)
    return spec_of(n)

// ------------------------------------------------------------------ frog

let FROG_SCALE = 1.25

def vivid(c:float3) -> float3:
    let h, s, v = hsv(c)
    return from_hsv(h, min(1.0, s * 1.25 + 0.05), min(1.0, v * 1.08 + 0.02))

def frog_mats(c:Colours) -> [MMat]:
    return [surf("frog_skin", vivid(col(c, "skin")), 7.0), surf("frog_belly", lightened(col(c, "skin2"), 0.25), 6.0)]

def frog_hand(into:MNode, hand:float3, dir:float3, skin:MMat, pad:MMat):
    add_child(into, blob(float3 { 1.2, 0.9, 1.2 }, skin, hand))
    for(3) f:
        let tip = hand + dir * 2.6 + float3 { 0.0, 0.0, float(f - 1) * 1.3 }
        add_child(into, rod(hand, tip, 0.42, 0.38, skin, false))
        add_child(into, blob(float3 { 0.75, 0.6, 0.75 }, pad, tip))

def frog_eyes(n:MNode, at:float3, spread:float, r:float, skin:MMat):
    for([1.0, -1.0]) side:
        let d = at + float3 { 0.0, 0.0, spread * side }
        add_child(n, blob(float3 { r, r * 1.05, r }, skin, d))
        let look = float3 { 0.6, 0.35, 0.75 * side }
        add_child(n, decal("frog_eye", r * 1.45, r * 1.45, on_surface(d, float3 { r, r * 1.05, r }, look, 0.1), look, false))

let LIMP_ARM = [float3 { 7.5, 13.0, 8.5 }, float3 { 11.0, 15.0, 10.0 }]

def body_frog(c:Colours) -> Spec: return scaled(body_frog_built(c), FROG_SCALE)

def body_frog_built(c:Colours) -> Spec:
    let n = mnode()
    let m = frog_mats(c)
    let slump = if hold == "limp": float3 { 1.1, 0.75, 1.15 } else: float3_1
    add_child(n, blob(float3 { 8.2, 5.6, 6.6 } * slump, m[0], float3 { -0.5, 9.5, 0.0 }, float3 { 0.0, 0.0, 32.0 }))
    add_child(n, blob(float3 { 6.0, 3.8, 5.0 } * slump, m[1], float3 { 1.6, if hold != "limp": 8.0 else: 7.0, 0.0 }, float3 { 0.0, 0.0, 32.0 }))
    let front = mnode()
    var near_hand = float3_0
    for([1.0, -1.0]) side:
        let into = if side == 1.0: front else: n
        let sh = float3 { 4.2, 11.0, 4.6 * side }
        var elbow = float3 { 6.0, 6.5, 5.6 * side }
        var hand = if side == 1.0: float3 { 8.0, 1.2, 5.4 } else: float3 { 8.0, 4.5, -5.4 }
        if hold == "limp":
            elbow = float3 { LIMP_ARM[0].x, LIMP_ARM[0].y, LIMP_ARM[0].z * side }
            hand = float3 { LIMP_ARM[1].x, LIMP_ARM[1].y, LIMP_ARM[1].z * side }
            if side == 1.0: near_hand = hand
        elif side == 1.0:
            let e, h = arm_pose(sh, elbow, float3 { 8.5, 8.5, 7.8 }, float3 { 8.4, 13.5, 0.0 })
            elbow = e
            hand = h
            near_hand = hand
        add_child(into, rod(sh, elbow, 1.5, 1.3, m[0]))
        add_child(into, rod(elbow, hand, 1.3, 1.1, m[0]))
        frog_hand(into, hand, if side == -1.0: float3 { 1.0, -0.15, 0.0 } else: float3 { 0.8, 0.5, 0.0 }, m[0], m[1])
    kerchief(front, c, float3 { 5.0, 12.2, 0.0 }, 3.2, 40.0)
    let s = spec_of(n)
    s.front = front
    sock(s, "head", float3 { 6.6, 13.5, 0.0 })
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", float3 { 8.0, 4.5, -5.4 })
    sock(s, "torso", float3 { 1.0, 10.0, 0.0 })
    sock(s, "back", float3 { -4.5, 13.0, 0.0 })
    sock(s, "sit", float3 { -0.5, 3.6, 0.0 })
    sock(s, "drape", float3 { -7.5, 12.5, 0.0 })
    sock(s, "sling", float3 { -7.4, 12.5, 0.0 })
    s.anchors = [anchor(float3 { -4.5, 6.0, -5.2 }, 0.0, -1), anchor(float3 { -4.5, 6.0, 5.2 }, MPI, 1)]
    return spec_num(s, "torso_scale", float3 { 0.75, 0.6, 0.0 })

def head_frog(c:Colours) -> Spec: return scaled(head_frog_built(c), FROG_SCALE)

def head_frog_built(c:Colours) -> Spec:
    let n = mnode()
    let m = frog_mats(c)
    add_child(n, blob(float3 { 5.8, 3.0, 5.4 }, m[0], float3 { 2.4, 2.4, 0.0 }))
    add_child(n, blob(float3 { 4.6, 1.6, 4.4 }, m[1], float3 { 2.8, 0.9, 0.0 }))
    add_child(n, rod(float3 { 7.6, 1.9, -3.6 }, float3 { 7.9, 1.9, 0.0 }, 0.32, 0.32, plain(INK)))
    add_child(n, rod(float3 { 7.9, 1.9, 0.0 }, float3 { 7.6, 1.9, 3.6 }, 0.32, 0.32, plain(INK)))
    frog_eyes(n, float3 { 3.2, 5.2, 0.0 }, 3.0, 2.2, m[0])
    return spec_num(sock(spec_of(n), "top", float3 { -0.6, 5.0, 0.0 }), "gear_scale", 0.62)

def leg_frog(c:Colours) -> Spec: return scaled(leg_frog_built(c), FROG_SCALE)

def leg_frog_built(c:Colours) -> Spec:
    let n = mnode()
    let m = frog_mats(c)
    var knee = float3 { 5.5, 3.8, 1.6 }
    var ankle = float3 { -2.0, -3.2, 1.2 }
    var heel = ankle + float3 { 0.0, -2.4, 0.0 }
    var toe_dir = float3 { 6.5, -0.4, 0.0 }
    if hold == "limp":
        knee = float3 { -5.2, -1.2, 1.6 }
        ankle = float3 { -10.4, -1.8, 1.3 }
        heel = ankle + float3 { -2.2, -0.3, 0.0 }
        toe_dir = float3 { -5.5, -0.3, 0.0 }
    add_child(n, rod(float3_0, knee, 2.6, 1.8, m[0]))
    add_child(n, rod(knee, ankle, 1.7, 1.1, m[0]))
    add_child(n, rod(ankle, heel, 1.1, 0.9, m[0]))
    for(4) t:
        let toe = heel + toe_dir + float3 { 0.0, 0.0, (float(t) - 1.5) * 1.6 }
        add_child(n, rod(heel, toe, 0.5, 0.42, m[0], false))
        add_child(n, blob(float3 { 0.8, 0.55, 0.8 }, m[1], toe))
    return spec_of(n)

def tool_basket(c:Colours) -> Spec:
    let n = mnode()
    let b = add_child(n, mesh_node(cylinder_mesh(4.6, 3.6, 6.0, 20, 4, true, true), surf("wicker", float3_1, 4.0)))
    b.pos = float3 { 1.0, -5.5, 0.5 }
    add_child(n, ring(4.3, 5.1, surf("bark_plate", html("#c8a070"), 6.0), float3 { 1.0, -2.5, 0.5 }))
    add_child(n, ring(4.3, 4.9, surf("wicker", html("#d8b880"), 3.0), float3 { 1.0, -2.0, 0.5 }, float3 { 90.0, 0.0, 0.0 }, float3 { 1.0, 1.0, 0.9 }))
    for(6) k:
        add_child(n, blob(float3 { 1.1, 0.8, 1.1 }, plain(html("#e0607f")), float3 { -1.5 + float(k) * 1.0, -2.2, -1.5 + float(k % 3) * 1.4 }))
    return spec_of(n)

def weapon_spear_reed(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -4.0, -8.0, 0.0 }
    let b = float3 { 6.0, 19.0, 0.0 }
    add_child(n, rod(a, b, 1.05, 1.0, surf("reed_stalk", float3_1, 5.0), false))
    let d = normalize(b - a)
    let tip = add_child(n, mesh_node(cylinder_mesh(0.0, 3.4, 9.5, 4, 4, true, true), surf("bone", float3_1, 4.0)))
    tip.pos = b + d * 4.0
    set_basis(tip, bscaled_global(arc(float3 { 0.0, 1.0, 0.0 }, d), float3 { 1.0, 1.0, 0.45 }))
    for(3) k:
        add_child(n, ring(0.7, 1.1, surf("leather", float3_1, 3.0), b - d * (0.6 + float(k) * 0.9), float3 { 0.0, 0.0, atan2(float2 { d.x, d.y }) - 90.0 }))
    return spec_of(n)

def armour_bark(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, blob(float3 { 9.0, 8.4, 10.8 }, surf("bark_plate", float3_1, 9.0), float3 { 2.0, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    for([1.0, -1.0]) side:
        add_child(n, ring(9.6, 10.6, surf("leather", float3_1, 4.0), float3 { 1.5, 1.0, 0.0 }, float3 { 0.0, 0.0, 70.0 * side }, float3_1))
    add_child(n, blob(float3 { 1.2, 1.2, 0.6 }, plain(html("#c08a3e")), float3 { 10.6, 2.0, 2.0 }))
    return spec_of(n)

def shield_lilypad(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, decal("lily_pad", 15.0, 15.0, float3 { 4.0, 0.5, 2.0 }, float3 { 1.0, 0.1, 0.45 }))
    return spec_of(n)

def helm_acorn(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, blob(float3 { 6.6, 3.8, 6.6 }, surf("acorn_cap", float3_1, 3.5), float3 { 0.0, 0.6, 0.0 }))
    add_child(n, rod(float3 { 0.0, 3.8, 0.0 }, float3 { 0.8, 6.8, 0.0 }, 0.8, 0.55, surf("bark_plate", html("#8a6a40"), 3.0)))
    return spec_of(n)

def hat_leaf(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, decal("leaf", 10.0, 13.0, float3 { 0.0, 2.2, 0.0 }, float3 { 0.25, 1.0, 0.35 }, true, float3 { 1.0, 0.0, 0.0 }, float3_1))
    add_child(n, rod(float3 { -5.5, 1.5, -0.5 }, float3 { -7.5, 3.0, -0.8 }, 0.35, 0.3, plain(html("#6b4a2a"))))
    return spec_of(n)

def cape_leaf(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, decal("leaf", 13.0, 17.0, float3 { -3.0, -6.0, 1.5 }, float3 { -0.5, 0.2, 0.85 }, true, float3 { 0.4, 1.0, 0.0 }, float3_1))
    return spec_of(n)

// ------------------------------------------------------------------ rat

var rat_hunch = 15.0
var rat_torso_x = 0.8
let RAT_BANNER_Y = 22.0
let RAT_HAND_L = float3 { 8.3, 18.5, -4.6 }

def body_rat(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 7.0)
    let pink = surf("frog_belly", col(c, "skin2"), 6.0)
    add_child(n, blob(float3 { 5.4, 10.4, 5.0 }, fur, float3 { 0.2, 15.0, 0.0 }, float3 { 0.0, 0.0, -rat_hunch }))
    add_child(n, blob(float3 { 3.4, 7.0, 3.6 }, pink, float3 { 2.6, 13.6, 0.4 }, float3 { 0.0, 0.0, -rat_hunch }))
    let pts = [float3 { -5.0, 7.0, 0.0 }, float3 { -11.0, 4.5, 1.5 }, float3 { -16.5, 5.5, 2.5 }, float3 { -19.5, 9.5, 3.0 }, float3 { -19.0, 14.0, 3.0 }, float3 { -16.5, 16.0, 2.5 }]
    for(pts.length - 1) i:
        let k = i + 1
        add_child(n, rod(pts[k - 1], pts[k], 1.25 - float(k) * 0.17, 1.25 - float(k + 1) * 0.17, pink))
    var near_hand = float3_0
    let front = mnode()
    for([1.0, -1.0]) side:
        let into = if side == 1.0: front else: n
        let sh = float3 { 5.6, 19.5, 4.4 * side }
        var elbow = float3 { 6.6, 16.5, 5.8 * side }
        var hand = if side == 1.0: float3 { 8.6, 15.5, 4.6 * side } else: RAT_HAND_L
        if side == 1.0:
            let e, h = arm_pose(sh, elbow, hand, float3 { 4.0, 24.5, 0.0 })
            elbow = e
            hand = h
            near_hand = hand
        add_child(into, rod(sh, elbow, 1.9, 1.7, fur))
        add_child(into, rod(elbow, hand, 1.7, 1.5, fur))
        add_child(into, blob(float3 { 1.7, 1.4, 1.7 }, pink, hand))
    kerchief(front, c, float3 { 3.2, 22.2, 0.0 }, 3.0, 15.0)
    let s = spec_of(n)
    s.front = front
    sock(s, "head", float3 { 4.0, 24.5, 0.0 })
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", RAT_HAND_L)
    sock(s, "torso", float3 { rat_torso_x, 17.5, 0.0 })
    sock(s, "back", float3 { -5.2, 19.5, 0.0 })
    sock(s, "banner", float3 { -4.0, RAT_BANNER_Y, 0.0 })
    s.anchors = [anchor(float3 { -0.5, 7.0, -3.2 }, 0.0, -1), anchor(float3 { -0.5, 7.0, 3.2 }, MPI, 1)]
    spec_num(s, "torso_scale", float3 { 0.58, 0.74, 0.0 })
    spec_num(s, "torso_tilt", -rat_hunch)
    return spec_num(s, "torso_fit", float3 { 0.7, 0.76, 0.6 })

def head_rat(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 6.0)
    let pink = surf("frog_belly", col(c, "skin2"), 5.0)
    let skull_c = float3 { 1.0, 4.5, 0.0 }
    let skull_r = float3 { 5.2, 4.8, 4.6 }
    add_child(n, blob(skull_r, fur, skull_c))
    add_child(n, rod(float3 { 3.0, 4.0, 0.0 }, float3 { 11.0, 2.6, 0.0 }, 3.4, 1.1, fur))
    add_child(n, blob(float3 { 1.3, 1.1, 1.3 }, plain(html("#e8909c")), float3 { 11.4, 2.7, 0.0 }))
    add_child(n, blob(float3 { 0.6, 1.0, 1.4 }, plain(html("#f4f0e0")), float3 { 9.6, 0.9, 0.0 }))
    for([1.0, -1.0]) side:
        let look = float3 { 0.5, 0.35, 0.8 * side }
        add_child(n, decal("rat_eye", 2.6, 2.6, on_surface(skull_c, skull_r, look, 0.1), look, false))
        add_child(n, blob(float3 { 0.8, 4.0, 3.6 }, fur, float3 { -1.2, 9.0, 3.4 * side }, float3 { 0.0, 20.0 * side, -10.0 }))
        add_child(n, blob(float3 { 0.5, 3.0, 2.6 }, pink, float3 { -0.7, 9.0, 3.6 * side }, float3 { 0.0, 20.0 * side, -10.0 }))
        for(3) w:
            add_child(n, rod(float3 { 9.5, 2.8, 1.2 * side }, float3 { 12.5, 2.2 + float(w) * 1.0, (3.5 + float(w) * 0.4) * side }, 0.12, 0.08, plain(html("#3a3430")), false))
    return sock(spec_of(n), "top", float3 { 0.0, 9.5, 0.0 })

def leg_rat(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 6.0)
    let pink = surf("frog_belly", col(c, "skin2"), 5.0)
    add_child(n, blob(float3 { 2.8, 3.4, 2.6 }, fur, float3 { 0.3, -1.8, 0.0 }))
    add_child(n, rod(float3 { 0.5, -3.5, 0.0 }, float3 { 0.2, -6.0, 0.0 }, 1.0, 0.8, pink))
    add_child(n, blob(float3 { 3.0, 0.6, 1.3 }, pink, float3 { 2.4, -6.4, 0.0 }))
    for(3) t: add_child(n, blob(float3 { 0.5, 0.4, 0.4 }, pink, float3 { 5.3, -6.5, float(t - 1) * 0.8 }))
    return spec_of(n)

def tool_axe(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 3.0, 9.5, 0.0 }, 0.75, 0.7, surf("wood_grain", float3_1, 6.0)))
    add_child(n, slab([float2 { 2.2, 9.0 }, float2 { 7.5, 10.5 }, float2 { 7.0, 4.5 }, float2 { 3.0, 6.5 }], 0.9, surf("bronze", float3_1, 4.0)))
    add_child(n, ring(0.6, 1.1, surf("leather", float3_1, 3.0), float3 { 2.6, 8.0, 0.0 }, float3 { 0.0, 0.0, -17.0 }))
    return spec_of(n)

def weapon_spear_bronze(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -4.0, -8.0, 0.0 }
    let b = float3 { 6.0, 18.5, 0.0 }
    add_child(n, rod(a, b, 0.85, 0.8, surf("wood_grain", float3_1, 8.0), false))
    let d = normalize(b - a)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade([float2 { 0.0, -1.6 }, float2 { 6.5, 0.0 }, float2 { 0.0, 1.6 }, float2 { -1.2, 0.0 }], 0.8, surf("bronze", float3_1, 3.0), b, ang))
    add_child(n, ring(0.7, 1.15, surf("bronze", float3_1, 3.0), b - d * 0.4, float3 { 0.0, 0.0, ang - 90.0 }))
    return spec_of(n)

def shield_bottlecap(c:Colours) -> Spec:
    let n = mnode()
    let holder = facing(n, float3 { 3.0, 0.5, 1.5 }, normalize(SHIELD_FACE))
    let iron = surf("iron", float3_1, 4.0)
    let body = add_child(holder, mesh_node(cylinder_mesh(6.0, 6.4, 1.6, 24, 4, true, true), iron))
    body.rot = float3 { 90.0, 0.0, 0.0 }
    for(21) k:
        let a = 360.0 * float(k) / 21.0
        add_child(holder, blob(float3 { 0.75, 0.75, 0.9 }, iron, float3 { cos(a) * 6.3, sin(a) * 6.3, 0.1 }))
    let centre = add_child(holder, mesh_node(cylinder_mesh(4.3, 4.3, 0.3, 24, 4, true, true), plain(col(c, "team"))))
    centre.rot = float3 { 90.0, 0.0, 0.0 }
    centre.pos = float3 { 0.0, 0.0, 0.85 }
    add_child(holder, ring(4.2, 4.6, plain(darkened(col(c, "team"), 0.4)), float3 { 0.0, 0.0, 0.9 }, float3 { 90.0, 0.0, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ spider

let SPIDER_FAN = [45.0, -60.0, -30.0]

def body_spider(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("rat_fur", col(c, "skin"), 6.0)
    let fr = surf("rat_fur", col(c, "skin2"), 5.0)
    add_child(n, blob(float3 { 7.5, 6.0, 6.5 }, hair, float3 { -7.5, 9.5, 0.0 }, float3 { 0.0, 0.0, 10.0 }))
    add_child(n, blob(float3 { 5.0, 1.0, 5.4 }, plain(col(c, "team")), float3 { -8.0, 15.2, 0.0 }, float3 { 0.0, 0.0, 10.0 }))
    add_child(n, blob(float3 { 4.2, 6.0, 4.6 }, fr, float3 { 1.5, 14.5, 0.0 }, float3 { 0.0, 0.0, -30.0 }))
    let limb = surf("rat_fur", col(c, "skin"), 4.0)
    let hand_r = float3 { 7.0, 17.5, 5.2 }
    let hand_l = float3 { 7.0, 17.5, -5.2 }
    for([1.0, -1.0]) side:
        let elbow = float3 { 5.5, 19.0, 6.0 * side }
        add_child(n, rod(float3 { 2.5, 18.0, 3.5 * side }, elbow, 1.0, 0.85, limb))
        add_child(n, rod(elbow, if side == 1.0: hand_r else: hand_l, 0.85, 0.6, limb))
    let s = spec_of(n)
    let xs = [0.5, -2.5, -6.5]
    for(3) k:
        let pair = if k >= 1: 1.0 else: 0.0
        s.anchors.push(anchor(float3 { xs[k], 10.5, 3.5 }, float(k), 1, [pair, 0.0, SPIDER_FAN[k]]))
        s.anchors.push(anchor(float3 { xs[k], 10.5, -3.5 }, float(k) + MPI, -1, [pair, 0.0, SPIDER_FAN[k]]))
    sock(s, "head", float3 { 3.5, 20.0, 0.0 })
    sock(s, "hand_r", hand_r)
    sock(s, "hand_l", hand_l)
    sock(s, "torso", float3 { 1.5, 14.5, 0.0 })
    sock(s, "back", float3 { -14.5, 14.5, 0.0 })
    sock(s, "seat", float3 { -8.0, 16.5, 0.0 })
    sock(s, "wings", float3 { -1.0, 17.0, 0.0 })
    sock(s, "sit", float3 { -4.0, 4.5, 0.0 })
    sock(s, "sling", float3 { -7.6, 17.9, 0.0 })
    return spec_num(s, "torso_scale", float3 { 0.5, 0.6, 0.0 })

def head_spider(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("rat_fur", col(c, "skin2"), 4.0)
    let head_c = float3 { 3.0, 1.0, 0.0 }
    let head_r = float3 { 4.2, 3.6, 4.0 }
    add_child(n, blob(head_r, hair, head_c))
    let eyes = [float3 { 1.0, 0.45, 0.3 }, float3 { 1.0, 0.45, -0.3 }, float3 { 0.8, 0.8, 0.6 }, float3 { 0.8, 0.8, -0.6 },
                float3 { 0.6, 1.0, 0.25 }, float3 { 0.6, 1.0, -0.25 }, float3 { 0.9, 0.2, 0.75 }, float3 { 0.9, 0.2, -0.75 }]
    let sizes = [1.3, 1.3, 0.8, 0.8, 0.7, 0.7, 0.6, 0.6]
    for(eyes) e, i:
        add_child(n, decal("rat_eye", sizes[i] * 2.0, sizes[i] * 2.0, on_surface(head_c, head_r, e, 0.05), e, false))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { 6.2, -0.5, 1.2 * side }, float3 { 7.4, -3.2, 0.8 * side }, 0.9, 0.35, plain(html("#1e1612"))))
    return spec_num(sock(spec_of(n), "top", float3 { 2.0, 4.0, 0.0 }), "gear_scale", 0.62)

def leg_spider(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("rat_fur", col(c, "skin"), 4.0)
    let knee = float3 { 6.0, 7.0, 1.5 }
    let tip = float3 { 11.0, -10.0, 2.5 }
    let mid = knee + (tip - knee) * 0.6
    add_child(n, rod(float3_0, knee, 1.4, 1.2, hair))
    add_child(n, rod(knee, mid, 1.2, 0.9, hair))
    add_child(n, rod(mid, tip, 0.9, 0.5, plain(darkened(col(c, "skin"), 0.5))))
    return spec_of(n)

// ------------------------------------------------------------------ more gear

def weapon_cheese_hammer(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 3.0, 10.0, 0.0 }, 0.8, 0.75, surf("wood_grain", float3_1, 6.0)))
    add_child(n, slab([float2 { -3.0, 9.5 }, float2 { 8.0, 13.5 }, float2 { 8.5, 7.5 }, float2 { -0.5, 5.5 }], 4.5, surf("cheese", float3_1, 5.0)))
    add_child(n, blob(float3 { 1.2, 1.2, 0.6 }, plain(html("#b0841a")), float3 { 3.5, 9.5, 2.3 }))
    return spec_of(n)

def armour_mail(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, blob(float3 { 8.6, 8.2, 10.4 }, surf("mail", float3_1, 2.5), float3 { 1.5, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, ring(9.0, 10.2, surf("iron", float3_1, 3.0), float3 { 1.5, 6.0, 0.0 }, float3 { 0.0, 0.0, -10.0 }, float3 { 0.95, 1.0, 1.1 }))
    return spec_of(n)

def weapon_sling(c:Colours) -> Spec:
    let n = mnode()
    let cord = surf("leather", col(c, "cloth2"), 2.0)
    add_child(n, rod(float3_0, float3 { -6.5, 3.5, 0.6 }, 0.4, 0.4, cord))
    add_child(n, rod(float3 { 0.5, 0.0, 0.0 }, float3 { -6.0, 4.5, -0.6 }, 0.4, 0.4, cord))
    add_child(n, blob(float3 { 1.9, 1.3, 1.5 }, cord, float3 { -6.6, 4.3, 0.0 }))
    add_child(n, blob(float3 { 1.5, 1.5, 1.5 }, surf("iron", html("#b8b4a8"), 3.0), float3 { -7.0, 5.0, 0.0 }))
    return spec_of(n)

def weapon_crossbow(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, slab([float2 { -5.0, -0.8 }, float2 { 10.0, 0.6 }, float2 { 10.0, 2.4 }, float2 { -5.0, 1.4 }, float2 { -6.0, -1.8 }], 1.8, surf("wood_grain", float3_1, 6.0)))
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, rod(float3 { 9.0, 1.5, 0.0 }, float3 { 7.5, 2.0, 7.0 }, 0.55, 0.4, iron))
    add_child(n, rod(float3 { 9.0, 1.5, 0.0 }, float3 { 7.5, 2.0, -7.0 }, 0.55, 0.4, iron))
    add_child(n, rod(float3 { 7.5, 2.0, 7.0 }, float3 { 1.0, 1.6, 0.0 }, 0.12, 0.12, plain(html("#e8e0c8")), false))
    add_child(n, rod(float3 { 7.5, 2.0, -7.0 }, float3 { 1.0, 1.6, 0.0 }, 0.12, 0.12, plain(html("#e8e0c8")), false))
    add_child(n, rod(float3 { 1.0, 2.4, 0.0 }, float3 { 10.5, 2.6, 0.0 }, 0.25, 0.25, plain(html("#6b4a2a")), false))
    return spec_of(n)

def helm_dome(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, blob(float3 { 6.4, 4.4, 6.4 }, iron, float3 { 0.0, 0.5, 0.0 }))
    add_child(n, ring(6.2, 7.4, iron, float3 { 0.0, 0.6, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, ring(0.7, 1.4, iron, float3 { -1.0, 1.6, 6.9 * side }, float3 { 90.0, 0.0, 0.0 }))
    return spec_of(n)

def weapon_blowgun(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -2.5, -0.6, 0.0 }, float3 { 15.0, 2.6, 0.0 }, 1.0, 0.9, surf("reed_stalk", float3_1, 5.0), false))
    add_child(n, ring(0.9, 1.4, surf("leather", float3_1, 3.0), float3 { 0.6, 0.0, 0.0 }, float3 { 0.0, 0.0, -77.0 }))
    add_child(n, blob(float3 { 0.6, 0.6, 0.6 }, plain(html("#1a1a1a")), float3 { 15.2, 2.65, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ human

let HUMAN_HAND_L = float3 { 5.5, 20.5, -4.8 }

def body_human(c:Colours) -> Spec:
    let n = mnode()
    let tunic = surf("cloth", col(c, "team"), 6.0)
    let cloth = surf("cloth", col(c, "cloth"), 6.0)
    let skin = surf("skin", col(c, "skin"), 8.0)
    let belt = surf("leather", float3_1, 3.0)
    add_child(n, glb("torso_human", mats_of([tunic, cloth, belt, skin], ["team", "cloth", "leather", "skin"])))
    add_child(n, blob(float3 { 1.0, 1.0, 0.5 }, surf("bronze", float3_1, 2.0), float3 { 4.6, 15.2, 0.6 }))
    var near_hand = float3_0
    let front = mnode()
    for([1.0, -1.0]) side:
        let into = if side == 1.0: front else: n
        let sh = float3 { 0.3, 22.9, 4.4 * side }
        var elbow = float3 { 1.4, 18.4, 5.8 * side }
        var hand = if side == 1.0: float3 { 6.0, 16.2, 5.6 } else: HUMAN_HAND_L
        if side == 1.0:
            let e, h = arm_pose(sh, elbow, hand, float3 { 0.6, 27.0, 0.0 })
            elbow = e
            hand = h
            near_hand = hand
        add_child(into, blob(float3 { 2.1, 2.1, 2.1 }, cloth, sh))
        add_child(into, rod(sh, elbow, 1.6, 1.45, cloth))
        add_child(into, rod(elbow, hand, 1.35, 1.15, skin))
        add_child(into, blob(float3 { 1.5, 1.6, 1.3 }, skin, hand))
    let s = spec_of(n)
    s.front = front
    sock(s, "head", float3 { 0.6, 25.6, 0.0 })
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", HUMAN_HAND_L)
    sock(s, "torso", float3 { 0.0, 19.4, 0.0 })
    sock(s, "back", float3 { -4.2, 22.0, 0.0 })
    s.anchors = [anchor(float3 { -2.3, 11.0, -2.4 }, 0.0, -1), anchor(float3 { 2.0, 11.0, 2.4 }, MPI, 1)]
    spec_num(s, "torso_scale", float3 { 0.66, 0.82, 0.0 })
    spec_num(s, "torso_fit", float3 { 0.43, 0.74, 0.52 })
    return spec_flag(s, "legs_under")

def head_human(c:Colours) -> Spec:
    let face = surf("skin", col(c, "skin") * 0.4, 6.0)
    face.emission = col(c, "skin") * 0.82
    let n = glb("head_human", mats_of([face, surf("mane", darkened(col(c, "skin2"), 0.45), 3.0), plain(html("#1a1210"))], ["skin", "hair", "eye"]))
    return spec_num(sock(spec_of(n), "top", float3 { 0.3, 10.3, 0.0 }), "gear_scale", 0.86)

def leg_human(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, glb("leg_human", mats_of([surf("cloth", col(c, "cloth2"), 5.0), surf("leather", html("#6a4a30"), 3.0)], ["cloth", "leather"])))
    return spec_of(n)

// ------------------------------------------------------------------ this file's parts by id
def build_units(base:string, c:Colours) -> Spec?:
    switch base:
        case "body.frog": return body_frog(c)
        case "head.frog": return head_frog(c)
        case "leg.frog": return leg_frog(c)
        case "tool.basket": return tool_basket(c)
        case "weapon.spear_reed": return weapon_spear_reed(c)
        case "armour.bark": return armour_bark(c)
        case "shield.lilypad": return shield_lilypad(c)
        case "helm.acorn": return helm_acorn(c)
        case "hat.leaf": return hat_leaf(c)
        case "cape.leaf": return cape_leaf(c)
        case "body.rat": return body_rat(c)
        case "head.rat": return head_rat(c)
        case "leg.rat": return leg_rat(c)
        case "tool.axe": return tool_axe(c)
        case "weapon.spear_bronze": return weapon_spear_bronze(c)
        case "shield.bottlecap": return shield_bottlecap(c)
        case "body.spider": return body_spider(c)
        case "head.spider": return head_spider(c)
        case "leg.spider": return leg_spider(c)
        case "weapon.cheese_hammer": return weapon_cheese_hammer(c)
        case "armour.mail": return armour_mail(c)
        case "weapon.sling": return weapon_sling(c)
        case "weapon.crossbow": return weapon_crossbow(c)
        case "helm.dome": return helm_dome(c)
        case "weapon.blowgun": return weapon_blowgun(c)
        case "body.human": return body_human(c)
        case "head.human": return head_human(c)
        case "leg.human": return leg_human(c)
        default: return nil
