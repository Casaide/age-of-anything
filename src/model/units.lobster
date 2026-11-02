// ------------------------------------------------------------------ unit parts I (unit_models.gd: poses, frog, rat, spider, human)
// Each builder is unit_models.gd's of the same name (`_body_frog` -> body_frog), line for line; its
// comments are there. Part units are about one 2D pixel: x the way the unit faces, y up, z the near side.

var hold = "low"    // the body being built: how its near hand holds the weapon (arm_pose)
var rest_pose = ""  // ...and the idle pose it rests in while holding it (creature kit)

let INK = html("#2a1a12")
let REACH_FLOOR = 8.0
let SHIELD_FACE = float3 { 1.0, 0.1, 0.45 }

var arm_reach = 1.0  // the body being built: how much longer its arm is than the poses were made for (arm_pose)

// The near arm's elbow and hand for the body's hold (unit_models.gd arm_pose): a longer arm (the heroic human,
// D-173) reaches as far out.
def arm_pose(sh:float3, elbow:float3, hand:float3, head:float3) -> float3, float3:
    let e, h = arm_pose_at(sh, elbow, hand, head)
    if arm_reach == 1.0 or hold == "low" or hold == "mouth" or hold == "draw": return e, h
    return sh + (e - sh) * arm_reach, sh + (h - sh) * arm_reach

def arm_pose_at(sh:float3, elbow:float3, hand:float3, head:float3) -> float3, float3:
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
        case "follow":  // the blow carried through, low and across the body (art-quality study; baked only with AOW_STUDY_HOLDS)
            let low = sh + float3 { 5.0, -7.5, -2.5 }
            return sh + float3 { 3.0, -3.5, -0.4 }, float3 { low.x, max(low.y, REACH_FLOOR), low.z }
        case "thrust": return sh + float3 { 4.0, -0.5, 1.4 }, sh + float3 { 9.0, -1.0, 0.9 }
        default: return elbow, hand

// A shield slung on the back ("<shield>@slung" upright behind the shoulders, "@slung_flat" lying on top,
// "@slung_lean" along a back sloping 55 degrees forward: the frog, D-178).
def slung(built:Spec, how:string) -> Spec:
    let f = normalize(SHIELD_FACE)
    let u = normalize(float3 { 0.0, 1.0, 0.0 } - f * f.y)
    let from_ = Basis { f, u, cross(f, u) }
    let face = if how == "@slung": float3 { -1.0, 0.2, 0.0 } elif how == "@slung_lean": float3 { -0.574, 0.819, 0.0 } else: float3 { -0.45, 1.0, 0.0 }
    let up = if how == "@slung": float3 { 0.0, 1.0, 0.0 } elif how == "@slung_lean": float3 { 0.819, 0.574, 0.0 } else: float3 { -1.0, -0.45, 0.0 }
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
    return [ surf("frog_skin", vivid(col(c, "skin")), 7.0), surf("frog_belly", lightened(col(c, "skin2"), 0.25), 6.0) ]

def frog_hand(into:MNode, hand:float3, dir:float3, skin:MMat, pad:MMat):
    add_child(into, blob(float3 { 1.2, 0.9, 1.2 }, skin, hand))
    for(3) f:
        let tip = hand + dir * 2.6 + float3 { 0.0, 0.0, float(f - 1) * 1.3 }
        add_child(into, rod(hand, tip, 0.42, 0.38, skin, false))
        add_child(into, blob(float3 { 0.75, 0.6, 0.75 }, pad, tip))

def frog_eyes(n:MNode, at:float3, spread:float, r:float, skin:MMat):
    for([ 1.0, -1.0 ]) side:
        let d = at + float3 { 0.0, 0.0, spread * side }
        add_child(n, blob(float3 { r, r * 1.05, r }, skin, d))
        let look = float3 { 0.6, 0.35, 0.75 * side }
        add_child(n, decal("frog_eye", r * 1.45, r * 1.45, on_surface(d, float3 { r, r * 1.05, r }, look, 0.1), look, false))

let LIMP_ARM = [ float3 { 7.5, 13.0, 8.5 }, float3 { 11.0, 15.0, 10.0 } ]

// The crouched leaper (2026-10-11 to 2026-10-28; the frog before D-178, kept for the old concept sheets: _crouched).
def body_frog_crouched(c:Colours) -> Spec: return scaled(body_frog_built(c), FROG_SCALE)

def body_frog_built(c:Colours) -> Spec:
    let n = mnode()
    let m = frog_mats(c)
    let slump = if hold == "limp": float3 { 1.1, 0.75, 1.15 } else: float3_1
    add_child(n, blob(float3 { 8.2, 5.6, 6.6 } * slump, m[0], float3 { -0.5, 9.5, 0.0 }, float3 { 0.0, 0.0, 32.0 }))
    add_child(n, blob(float3 { 6.0, 3.8, 5.0 } * slump, m[1], float3 { 1.6, if hold != "limp": 8.0 else: 7.0, 0.0 }, float3 { 0.0, 0.0, 32.0 }))
    let front = mnode()
    var near_hand = float3_0
    for([ 1.0, -1.0 ]) side:
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
    s.anchors = [ anchor(float3 { -4.5, 6.0, -5.2 }, 0.0, -1), anchor(float3 { -4.5, 6.0, 5.2 }, MPI, 1) ]
    return spec_num(s, "torso_scale", float3 { 0.75, 0.6, 0.0 })

def head_frog_crouched(c:Colours) -> Spec: return scaled(head_frog_built(c), FROG_SCALE)

def head_frog_built(c:Colours) -> Spec:
    let n = mnode()
    let m = frog_mats(c)
    add_child(n, blob(float3 { 5.8, 3.0, 5.4 }, m[0], float3 { 2.4, 2.4, 0.0 }))
    add_child(n, blob(float3 { 4.6, 1.6, 4.4 }, m[1], float3 { 2.8, 0.9, 0.0 }))
    add_child(n, rod(float3 { 7.6, 1.9, -3.6 }, float3 { 7.9, 1.9, 0.0 }, 0.32, 0.32, plain(INK)))
    add_child(n, rod(float3 { 7.9, 1.9, 0.0 }, float3 { 7.6, 1.9, 3.6 }, 0.32, 0.32, plain(INK)))
    frog_eyes(n, float3 { 3.2, 5.2, 0.0 }, 3.0, 2.2, m[0])
    return spec_num(sock(spec_of(n), "top", float3 { -0.6, 5.0, 0.0 }), "gear_scale", 0.62)

def leg_frog_crouched(c:Colours) -> Spec: return scaled(leg_frog_built(c), FROG_SCALE)

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

// ------------------------------------------------------------------ the frog as a frog is (D-178)
// Round F2's B: squat, the trunk leaning 55 degrees forward from the hips, a wide flat head with the eyes on top, one
// forelimb planted, the other holding what it carries; the hind legs folded in a Z beside it, baked per phase of the
// hop (D-179). The trunk and head are modelled in Blender (tools/blender/frog.py); arms and legs here.

let FROG_LEAN = 55.0
let FROG_HIP = float3 { 0.0, 8.625, 0.0 }
let FROG_HIP_Z = 4.35
let FROG_NECK = float3 { 12.246, 17.2, 0.0 }
let FROG_SHOULDER = float3 { 11.15, 15.2, 6.0 }
let FROG_HAND_L = float3 { 16.3, 5.5, -8.0 }
let FROG_KNEE = float2 { 8.625, -3.68 }
let FROG_ANKLE = float2 { -2.3, -7.4 }
let FROG_TOE = float2 { 7.6, -8.15 }
let FROG_THIGH = 9.38
let FROG_SHANK = 11.36
let FROG_KNEE_OUT = 4.2
let FROG_ANKLE_OUT = 3.1
// A hop's keys (UnitModels.HOP_KEYS; the composer has its own copy, view/unit_view.lobster HOP_KEYS, which model
// checks don't import): p, how far the legs are squashed, how far they're flung back (-) or forward.
let FROG_HOP_KEYS = [ [ 0.0, 1.0, 0.0 ], [ 0.15, 0.7, 0.0 ], [ 0.25, 0.7, 0.0 ], [ 0.36, 1.15, -0.7 ], [ 0.52, 0.75, -0.25 ],
                      [ 0.66, 0.9, 0.3 ], [ 0.75, 1.0, 0.0 ], [ 0.82, 0.72, 0.0 ], [ 1.0, 1.0, 0.0 ] ]

def frog_hop_key(p:float) -> float2:
    var i = 1
    while i < FROG_HOP_KEYS.length:
        if p <= FROG_HOP_KEYS[i][0]:
            let a = FROG_HOP_KEYS[i - 1]
            let b = FROG_HOP_KEYS[i]
            let w = smoothstep(a[0], b[0], p)
            return float2 { lerpf(a[1], b[1], w), lerpf(a[2], b[2], w) }
        i++
    return float2 { 1.0, 0.0 }

def frog_coat(c:Colours) -> dictionary<string, MMat>:
    let m = frog_mats(c)
    return mats_of([ m[0], m[1], plain(INK), plain(html("#f0e6b0")) ], [ "skin", "belly", "eye", "eyeball" ])

def body_frog(c:Colours) -> Spec:
    let n = mnode()
    let coat = frog_coat(c)
    let skin = coat_mat(coat, "skin")
    let belly = coat_mat(coat, "belly")
    add_child(n, glb("body_frog", coat))
    let front = mnode()
    var near_hand = float3_0
    let limp = hold == "limp"  // dead (corpse.lobster): the arms flung forward and out, to lie on the ground
    for([ 1.0, -1.0 ]) side:
        let into = if side == 1.0: front else: n
        let sh = float3 { FROG_SHOULDER.x, FROG_SHOULDER.y, FROG_SHOULDER.z * side }
        var elbow = if side == 1.0: float3 { 14.0, 11.2, 7.6 } else: float3 { 13.45, 10.0, -8.0 }
        var hand = if side == 1.0: float3 { 17.7, 12.9, 8.3 } else: FROG_HAND_L
        if limp:
            elbow = sh + float3 { 3.5, 1.0, 3.0 * side }
            hand = sh + float3 { 7.5, 1.6, 5.0 * side }
        elif side == 1.0:
            let e, h = arm_pose(sh, elbow, hand, FROG_NECK + float3 { 2.5, 0.8, 0.0 })
            elbow = e
            hand = h
            if hold == "reach":
                elbow += float3 { 0.0, 1.2, 0.0 }
                hand += float3 { 0.0, 2.5, 0.0 }
            elif hold == "raise":
                elbow += float3 { 0.8, 0.0, 0.8 }
                hand += float3 { 1.5, 0.0, 1.2 }
        if side == 1.0: near_hand = hand
        add_child(into, rod(sh, elbow, 1.55, 1.3, skin))
        add_child(into, rod(elbow, hand, 1.3, 1.0, skin))
        frog_hand(into, hand, if side == -1.0 and not limp: float3 { 1.0, -0.2, 0.0 } else: float3 { 0.8, 0.4, 0.0 }, skin, belly)
    let lean = float2 { sin(FROG_LEAN), cos(FROG_LEAN) }  // up the trunk
    let out = float2 { -lean.y, lean.x }                  // off its back
    def on(along:float, off:float) -> float3:
        let q = float2 { FROG_HIP.x, FROG_HIP.y } + lean * along + out * off
        return float3 { q.x, q.y, 0.0 }
    kerchief(front, c, on(11.8, 0.0), 4.3, -FROG_LEAN)
    let s = spec_of(n)
    s.front = front
    sock(s, "head", FROG_NECK)
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", FROG_HAND_L)
    sock(s, "torso", on(6.5, 0.0))
    sock(s, "back", on(8.0, 6.0))
    sock(s, "sling", on(6.5, 7.4))
    sock(s, "drape", on(9.5, 5.5))
    sock(s, "banner", on(8.0, 7.0))
    sock(s, "sit", float3 { 3.4, 3.7, 0.0 })
    s.anchors = [ anchor(FROG_HIP + float3 { 0.0, 0.0, -FROG_HIP_Z }, 0.0, -1), anchor(FROG_HIP + float3 { 0.0, 0.0, FROG_HIP_Z }, MPI, 1) ]
    spec_num(s, "torso_scale", float3 { 0.75, 0.6, 0.0 })
    spec_num(s, "torso_tilt", -FROG_LEAN)
    return spec_num(s, "torso_fit", float3 { 0.62, 0.62, 0.66 })

def head_frog(c:Colours) -> Spec:
    return spec_num(sock(spec_of(glb("head_frog", frog_coat(c))), "top", float3 { 1.4, 5.6, 0.0 }), "gear_scale", 0.62)

// The leg in the pose `hold` names ("" standing, "w<i>_<n>" step i of a hop in n, "limp" dead), from the hip.
def leg_frog(c:Colours) -> Spec:
    let jk, ja, jt = frog_joints(if hold == "low": "" else: hold)
    let n = mnode()
    let coat = frog_coat(c)
    let skin = coat_mat(coat, "skin")
    let belly = coat_mat(coat, "belly")
    let knee = float3 { jk.x, jk.y, FROG_KNEE_OUT }
    let ankle = float3 { ja.x, ja.y, FROG_ANKLE_OUT }
    let toe = float3 { jt.x, jt.y, FROG_ANKLE_OUT }
    add_child(n, blob(float3 { 3.6, 3.4, 3.2 }, skin, float3 { 0.8, -0.6, 0.8 }))  // the haunch
    add_child(n, rod(float3 { 0.6, -0.4, 0.6 }, knee, 3.0, 2.0, skin))
    add_child(n, rod(knee, ankle, 2.0, 1.15, skin))
    for(3) t:
        let tip = toe + float3 { 0.0, 0.0, float(t - 1) * 2.0 }
        let mid = lerp3(ankle, tip, 0.55) + float3 { 0.0, 0.0, float(t - 1) * 0.8 }
        add_child(n, rod(ankle, mid, 0.85, 0.6, skin, false))
        add_child(n, rod(mid, tip, 0.6, 0.42, skin, false))
        add_child(n, blob(float3 { 0.65, 0.42, 0.65 }, belly, tip))
    return spec_of(n)

// Where a frog leg's joints are in a pose (2D, the hip at the origin, up +y): knee, ankle, toe.
def frog_joints(pose:string) -> float2, float2, float2:
    if pose == "limp":
        let lk = float2 { -FROG_THIGH * 0.98, -1.6 }
        let la = lk + float2 { -FROG_SHANK * 0.99, -0.8 }
        return lk, la, la + float2 { -8.5, -0.4 }
    var k = float2 { 1.0, 0.0 }
    let p = walk_step(pose)
    if p >= 0.0: k = frog_hop_key(p)
    let ankle = float2 { FROG_ANKLE.x + 11.0 * k.y, FROG_ANKLE.y * k.x - 3.5 * max(-k.y, 0.0) }
    let turn = (-2.0 * max(-k.y, 0.0) + 0.4 * max(k.y, 0.0)) * RAD_DEG  // flung back the foot points down and back; reaching, toes up
    let toe = ankle + rot2d(FROG_TOE - FROG_ANKLE, turn)
    return ik2(ankle, FROG_THIGH, FROG_SHANK, true), ankle, toe

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
    for([ 1.0, -1.0 ]) side:
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
// The rat as a rat is (D-177, round F2's B): hunched forward on its hind legs, a long body, short arms, the head
// carried low. The trunk, tail and head are modelled in Blender (tools/blender/rat.py); the arms here, posed for what
// the near hand holds; the legs here too, digitigrade, baked in 8 walk steps with the knees bending (D-179).

let RAT_LEAN = 42.0  // degrees the trunk leans forward from the hips (as modelled)
let RAT_HIP = float3 { 0.0, 11.0, 0.0 }
let RAT_HIP_Z = 2.7
let RAT_BANNER_Y = 22.6
let RAT_HAND_L = float3 { 12.6, 17.8, -8.6 }
let RAT_THIGH = 5.9
let RAT_SHANK = 6.66
let RAT_HEEL = float2 { -0.8, -8.4 }
let RAT_FOOT = 6.2         // heel to toes
let RAT_STRIDE = 9.0       // how far a heel travels along the ground in a step
let RAT_STANCE = 0.55      // the share of a step a foot is down
let RAT_SWING = 2.6        // how far the near hand swings forward and back walking (D-179)
let RAT_SWING_FAR = 1.0    // the far (shield) hand
let RAT_TAIL_SWEEP = 14.0  // degrees the tail sweeps to each side walking

def rat_coat(c:Colours, units:float) -> dictionary<string, MMat>:
    return mats_of([ surf("rat_fur", col(c, "skin"), units), surf("rat_fur", lightened(col(c, "skin"), 0.25), units),
                     surf("frog_belly", col(c, "skin2"), units - 1.0), plain(html("#1a1210")), plain(html("#f4f0e0")) ],
                   [ "fur", "belly", "pink", "eye", "tooth" ])

def body_rat(c:Colours) -> Spec:
    let n = mnode()
    let coat = rat_coat(c, 7.0)
    let fur = coat_mat(coat, "fur")
    let pink = coat_mat(coat, "pink")
    // The modelled trunk turns about the hips by however far it leans from how it was modelled (an old bug).
    let hunch = if old_bugs.rat_leans_back: -15.0 else: RAT_LEAN
    let lean = mnode()
    lean.pos = RAT_HIP
    lean.rot = float3 { 0.0, 0.0, RAT_LEAN - hunch }
    add_child(n, lean)
    let body = glb("body_rat", coat)
    body.pos = -RAT_HIP
    add_child(lean, body)
    let t = xmul(Xform { axis_angle(float3 { 0.0, 0.0, 1.0 }, RAT_LEAN - hunch), RAT_HIP }, Xform { BASIS_ID, -RAT_HIP })
    // Walking ("w<i>_<n>", D-179): the arms swing against the legs, the tail sweeps a beat behind the hips.
    let step = walk_step(hold)
    let swing = if step >= 0.0: cos(360.0 * step) else: 0.0
    if step >= 0.0:
        let tail = glb_named(body, "tail")
        assert tail
        let root = float3 { -2.6, 9.8, 0.0 }  // where it leaves the haunch (tools/blender/rat.py)
        let sweep = axis_angle(float3 { 0.0, 1.0, 0.0 }, RAT_TAIL_SWEEP * sin(360.0 * (step - 0.2)))
        set_xform(tail, xmul(Xform { sweep, root - bxf(sweep, root) }, node_xform(tail)))
    var near_hand = float3_0
    let far_hand = RAT_HAND_L + float3 { -RAT_SWING_FAR * swing, 0.3 * swing * swing, 0.0 }
    let front = mnode()
    for([ 1.0, -1.0 ]) side:
        let into = if side == 1.0: front else: n
        let sh = xf(t, float3 { 8.6, 19.9, 3.4 * side })
        var elbow = if side == 1.0: float3 { 10.4, 15.7, 4.2 } else: float3 { 8.0, 15.5, -4.4 }
        var hand = if side == 1.0: float3 { 13.6, 14.8, 4.4 } else: RAT_HAND_L
        if side == 1.0:
            let e, h = arm_pose(sh, elbow, hand, xf(t, float3 { 11.2, 23.1, 0.0 }))
            elbow = e
            hand = h
            if hold == "raise" or hold == "reach" or hold == "follow":  // a blow swung out beside the hunched trunk
                elbow += float3 { if hold == "raise": 1.0 else: 0.0, 0.0, 1.2 }
                hand += float3 { if hold == "raise": 1.6 else: 0.0, 0.0, 1.6 }
            elif hold == "draw":  // a bow drawn at the leaning shoulders' height
                elbow += float3 { 0.0, 2.0, 0.0 }
                hand += float3 { 0.0, 4.0, 0.0 }
            // Forward, rising a little; back half as far, dipping.
            let arc = if swing >= 0.0: float3 { RAT_SWING * swing, 0.8 * swing * swing, 0.0 } else: float3 { 0.5 * RAT_SWING * swing, -1.2 * swing * swing, 0.0 }
            elbow += arc * 0.4
            hand += arc
            near_hand = hand
        else:
            hand = far_hand
            elbow += float3 { -0.4 * RAT_SWING_FAR * swing, 0.0, 0.0 }
        add_child(into, rod(sh, elbow, 1.55, 1.3, fur))
        add_child(into, rod(elbow, hand, 1.3, 0.95, fur))
        add_child(into, blob(float3 { 0.95, 0.8, 0.8 }, pink, hand))
    let s = spec_of(n)
    s.front = front
    sock(s, "head", if old_bugs.rat_head_stays: float3 { 11.2, 23.1, 0.0 } else: xf(t, float3 { 11.2, 23.1, 0.0 }))
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", far_hand)
    sock(s, "torso", xf(t, float3 { 4.1 + (if old_bugs.rat_armour_off: 1.4 else: 0.8), 16.4, 0.0 }))
    sock(s, "back", xf(t, float3 { 3.4, 20.1, 0.0 }))
    sock(s, "banner", xf(t, float3 { 2.8, RAT_BANNER_Y, 0.0 }))
    sock(s, "drape", xf(t, float3 { -0.4, 20.6, 0.0 }))
    sock(s, "sit", RAT_HIP + float3 { 6.0, 0.0, 0.0 })
    s.anchors = [ anchor(RAT_HIP + float3 { 0.0, 0.0, -RAT_HIP_Z }, 0.0, -1), anchor(RAT_HIP + float3 { 0.0, 0.0, RAT_HIP_Z }, MPI, 1) ]
    spec_num(s, "torso_scale", float3 { 0.58, 0.74, 0.0 })
    spec_num(s, "torso_tilt", -hunch)
    return spec_num(s, "torso_fit", float3 { 0.57, 0.57, 0.62 })

def head_rat(c:Colours) -> Spec:
    return spec_num(sock(spec_of(glb("head_rat", rat_coat(c, 6.0))), "top", float3 { 0.4, 4.4, 0.0 }), "gear_scale", 0.63)

// The leg in the pose `hold` names ("" standing, "w<i>_<n>" step i of an n-step walk), from the hip at the origin.
def leg_rat(c:Colours) -> Spec:
    let jk, jh, jt = rat_joints(if hold == "low": "" else: hold)
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 6.0)
    let pink = surf("frog_belly", col(c, "skin2"), 5.0)
    let knee = v3of(jk)
    let heel = v3of(jh)
    let toe = v3of(jt)
    add_child(n, blob(float3 { 3.2, 3.6, 2.9 }, fur, float3 { 0.6, -1.4, 0.0 }))  // the haunch
    add_child(n, rod(float3 { 0.4, -1.0, 0.0 }, knee, 2.9, 1.9, fur))
    add_child(n, rod(knee, heel, 1.8, 1.05, fur))
    add_child(n, rod(heel, lerp3(heel, toe, 0.7), 0.95, 0.7, pink))
    for(3) k:
        add_child(n, rod(lerp3(heel, toe, 0.65), toe + float3 { 0.3, 0.0, float(k - 1) * 0.85 }, 0.42, 0.32, pink))
    return spec_of(n)

// Where a rat's leg's joints are in a pose (2D, the hip at the origin, up +y): knee, heel, toe.
def rat_joints(pose:string) -> float2, float2, float2:
    let ground = -RAT_HIP.y
    var heel = RAT_HEEL
    var lift = 0.0
    let p = walk_step(pose)
    if p >= 0.0:
        if p < RAT_STANCE:
            heel += float2 { RAT_STRIDE * (0.5 - p / RAT_STANCE), 0.0 }
        else:
            let q = (p - RAT_STANCE) / (1.0 - RAT_STANCE)
            heel += float2 { RAT_STRIDE * (smoothstep(0.0, 1.0, q) - 0.5), 0.0 }
            lift = 3.2 * sin(q * 180.0)
    heel += float2 { 0.0, lift }
    var toe = float2 { heel.x + RAT_FOOT, ground + 0.35 + lift * 0.45 }  // a lifted foot hangs, toes down
    if lift == 0.0: toe = float2 { toe.x, ground + 0.35 }
    return ik2(heel, RAT_THIGH, RAT_SHANK, true), heel, toe

def tool_axe(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 3.0, 9.5, 0.0 }, 0.75, 0.7, surf("wood_grain", float3_1, 6.0)))
    add_child(n, slab([ float2 { 2.2, 9.0 }, float2 { 7.5, 10.5 }, float2 { 7.0, 4.5 }, float2 { 3.0, 6.5 } ], 0.9, surf("bronze", float3_1, 4.0)))
    add_child(n, ring(0.6, 1.1, surf("leather", float3_1, 3.0), float3 { 2.6, 8.0, 0.0 }, float3 { 0.0, 0.0, -17.0 }))
    return spec_of(n)

def weapon_spear_bronze(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -4.0, -8.0, 0.0 }
    let b = float3 { 6.0, 18.5, 0.0 }
    add_child(n, rod(a, b, 0.85, 0.8, surf("wood_grain", float3_1, 8.0), false))
    let d = normalize(b - a)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade([ float2 { 0.0, -1.6 }, float2 { 6.5, 0.0 }, float2 { 0.0, 1.6 }, float2 { -1.2, 0.0 } ], 0.8, surf("bronze", float3_1, 3.0), b, ang))
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

let SPIDER_FAN = [ 45.0, -60.0, -30.0 ]

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
    for([ 1.0, -1.0 ]) side:
        let elbow = float3 { 5.5, 19.0, 6.0 * side }
        add_child(n, rod(float3 { 2.5, 18.0, 3.5 * side }, elbow, 1.0, 0.85, limb))
        add_child(n, rod(elbow, if side == 1.0: hand_r else: hand_l, 0.85, 0.6, limb))
    let s = spec_of(n)
    let xs = [ 0.5, -2.5, -6.5 ]
    for(3) k:
        let pair = if k >= 1: 1.0 else: 0.0
        s.anchors.push(anchor(float3 { xs[k], 10.5, 3.5 }, float(k), 1, [ pair, 0.0, SPIDER_FAN[k] ]))
        s.anchors.push(anchor(float3 { xs[k], 10.5, -3.5 }, float(k) + MPI, -1, [ pair, 0.0, SPIDER_FAN[k] ]))
    sock(s, "head", float3 { 3.5, 20.0, 0.0 })
    sock(s, "hand_r", hand_r)
    sock(s, "hand_l", hand_l)
    sock(s, "torso", float3 { 1.5, 14.5, 0.0 })
    sock(s, "back", float3 { -14.5, 14.5, 0.0 })
    sock(s, "seat", float3 { -8.0, 16.5, 0.0 })
    sock(s, "wings", float3 { -1.0, 17.0, 0.0 })
    sock(s, "sit", float3 { -4.0, 4.5, 0.0 })
    sock(s, "sling", float3 { -7.6, 18.3, 0.0 })
    return spec_num(s, "torso_scale", float3 { 0.5, 0.6, 0.0 })

def head_spider(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("rat_fur", col(c, "skin2"), 4.0)
    let head_c = float3 { 3.0, 1.0, 0.0 }
    let head_r = float3 { 4.2, 3.6, 4.0 }
    add_child(n, blob(head_r, hair, head_c))
    let eyes = [ float3 { 1.0, 0.45, 0.3 }, float3 { 1.0, 0.45, -0.3 }, float3 { 0.8, 0.8, 0.6 }, float3 { 0.8, 0.8, -0.6 },
                 float3 { 0.6, 1.0, 0.25 }, float3 { 0.6, 1.0, -0.25 }, float3 { 0.9, 0.2, 0.75 }, float3 { 0.9, 0.2, -0.75 } ]
    let sizes = [ 1.3, 1.3, 0.8, 0.8, 0.7, 0.7, 0.6, 0.6 ]
    for(eyes) e, i:
        add_child(n, decal("rat_eye", sizes[i] * 2.0, sizes[i] * 2.0, on_surface(head_c, head_r, e, 0.05), e, false))
    for([ 1.0, -1.0 ]) side:
        add_child(n, rod(float3 { 6.2, -0.5, 1.2 * side }, float3 { 7.4, -3.2, 0.8 * side }, 0.9, 0.35, plain(html("#1e1612"))))
    return spec_num(sock(spec_of(n), "top", float3 { 2.0, 4.0, 0.0 }), "gear_scale", 0.62)

def leg_spider(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("rat_fur", col(c, "skin"), 4.0)
    let knee, tip = stepped(float3 { 6.0, 7.0, 1.5 }, float3 { 11.0, -10.0, 2.5 }, if hold == "low": "" else: hold, 4.0, 0.6, 0.7)  // (D-179: baked per walk step; a short, low step)
    let mid = knee + (tip - knee) * 0.6
    add_child(n, rod(float3_0, knee, 1.4, 1.2, hair))
    add_child(n, rod(knee, mid, 1.2, 0.9, hair))
    add_child(n, rod(mid, tip, 0.9, 0.5, plain(darkened(col(c, "skin"), 0.5))))
    return spec_of(n)

// ------------------------------------------------------------------ more gear

def weapon_cheese_hammer(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 3.0, 10.0, 0.0 }, 0.8, 0.75, surf("wood_grain", float3_1, 6.0)))
    add_child(n, slab([ float2 { -3.0, 9.5 }, float2 { 8.0, 13.5 }, float2 { 8.5, 7.5 }, float2 { -0.5, 5.5 } ], 4.5, surf("cheese", float3_1, 5.0)))
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
    add_child(n, slab([ float2 { -5.0, -0.8 }, float2 { 10.0, 0.6 }, float2 { 10.0, 2.4 }, float2 { -5.0, 1.4 }, float2 { -6.0, -1.8 } ], 1.8, surf("wood_grain", float3_1, 6.0)))
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
    for([ 1.0, -1.0 ]) side:
        add_child(n, ring(0.7, 1.4, iron, float3 { -1.0, 1.6, 6.9 * side }, float3 { 90.0, 0.0, 0.0 }))
    return spec_of(n)

def weapon_blowgun(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -2.5, -0.6, 0.0 }, float3 { 15.0, 2.6, 0.0 }, 1.0, 0.9, surf("reed_stalk", float3_1, 5.0), false))
    add_child(n, ring(0.9, 1.4, surf("leather", float3_1, 3.0), float3 { 0.6, 0.0, 0.0 }, float3 { 0.0, 0.0, -77.0 }))
    add_child(n, blob(float3 { 0.6, 0.6, 0.6 }, plain(html("#1a1a1a")), float3 { 15.2, 2.65, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ human
// The human, heroic build (D-173): about 5.5 heads tall, broad shoulders, hips at 18 on long legs. The torso, legs
// and worn armour are modelled in Blender (*_heroic.glb); the arms here, posed for what the near hand holds.

let HUMAN_LOOK = "_heroic"
let HUMAN_HAND_L = float3 { 6.1, 27.3, -5.4 }  // the shield hand, forearm up
let HUMAN_WOOL = html("#a39478")               // undyed wool: the cloth the culture's colour is mixed into (the team's stays bright)
let HUMAN_ARM = 1.15                           // its arm against the one the holds were posed for (arm_pose)

def body_human(c:Colours) -> Spec:
    let n = mnode()
    // A wool tunic in the culture's colour with the team colour on a sash and the hem (D-175).
    let team = surf("cloth", col(c, "team"), 4.0)
    let cloth = surf("cloth", lerp3(HUMAN_WOOL, col(c, "cloth"), 0.45), 4.0)
    let skin = surf("skin", col(c, "skin"), 8.0)
    let belt = surf("leather", html("#8a6a4a"), 3.0)
    add_child(n, glb("torso_human" + HUMAN_LOOK, mats_of([ team, cloth, belt, skin ], [ "team", "cloth", "leather", "skin" ])))
    add_child(n, blob(float3 { 0.45, 0.55, 0.5 }, surf("bronze", float3_1, 2.0), float3 { 3.15, 22.05, 0.0 }))  // the buckle
    var near_hand = float3_0
    let front = mnode()
    for([ 1.0, -1.0 ]) side:
        let into = if side == 1.0: front else: n
        let sh = float3 { 0.3, 29.3, 4.7 * side }
        var elbow = float3 { 1.3, 23.9, 5.9 * side }
        var hand = if side == 1.0: float3 { 6.2, 23.7, 6.8 } else: HUMAN_HAND_L
        if side == 1.0:
            arm_reach = HUMAN_ARM
            let e, h = arm_pose(sh, elbow, hand, float3 { 0.6, 34.0, 0.0 })
            arm_reach = 1.0
            elbow = e
            hand = h
            near_hand = hand
        // A short wool sleeve over the shoulder, then a bare arm shaped like one, a hand.
        add_child(into, blob(float3 { 1.95, 1.75, 1.75 }, cloth, sh + float3 { 0.0, -0.2, 0.0 }))
        add_child(into, rod(sh, lerp3(sh, elbow, 0.45), 1.75, 1.55, cloth))
        add_child(into, rod(lerp3(sh, elbow, 0.2), elbow, 1.4, 1.05, skin))
        add_child(into, rod(elbow, lerp3(elbow, hand, 0.35), 1.15, 1.2, skin))
        add_child(into, rod(lerp3(elbow, hand, 0.3), hand, 1.2, 0.8, skin))
        add_child(into, blob(float3 { 1.05, 1.25, 0.9 }, skin, hand))
    let s = spec_of(n)
    s.front = front
    sock(s, "head", float3 { 0.6, 31.6, 0.0 })
    sock(s, "hand_r", near_hand)
    sock(s, "hand_l", HUMAN_HAND_L)
    sock(s, "torso", float3 { 0.0, 26.0, 0.0 })
    sock(s, "back", float3 { -3.8, 27.2, 0.0 })
    sock(s, "cape.cloth", float3 { -4.4, 29.2, 0.0 })  // a cape from behind the shoulders (parts.json drape_scale)
    sock(s, "cape.leaf", float3 { -4.4, 29.2, 0.0 })
    s.anchors = [ anchor(float3 { -2.4, 18.0, -2.5 }, 0.0, -1), anchor(float3 { 2.1, 18.0, 2.5 }, MPI, 1) ]
    spec_num(s, "torso_scale", float3 { 0.66, 0.82, 0.0 })
    spec_num(s, "torso_fit", float3 { 0.46, 0.70, 0.55 })
    return spec_flag(s, "legs_under")

def head_human(c:Colours) -> Spec:
    let face = surf("skin", col(c, "skin") * 0.4, 6.0)
    face.emission = col(c, "skin") * 0.82
    let hs = 0.68  // the heroic build's head (D-173)
    let n = glb("head_human", mats_of([ face, surf("mane", darkened(col(c, "skin2"), 0.45), 3.0), plain(html("#1a1210")) ], [ "skin", "hair", "eye" ]))
    n.scl = n.scl * hs
    return spec_num(sock(spec_of(n), "top", float3 { 0.3, 10.3, 0.0 } * hs + float3 { 0.0, 0.2, 0.0 }), "gear_scale", 0.86 * hs)

// The heroic leg's joints as modelled (tools/blender/human_leg.py, in the game's units) and its walk (D-179).
let HUMAN_KNEE = float2 { 0.784, -9.0 }
let HUMAN_ANKLE = float2 { 0.112, -15.667 }
let HUMAN_STRIDE = 10.0  // how far an ankle travels along the ground in a step
let HUMAN_STANCE = 0.6   // the share of a step a foot is down
let HUMAN_LIFT = 3.2     // how high a foot swings through

// The leg in pieces bent at the knee and ankle for the pose ("w<i>_<n>", a walk step; "" as modelled).
def leg_human(c:Colours) -> Spec:
    let n = mnode()
    let leg = glb("leg_human" + HUMAN_LOOK, mats_of([ surf("cloth", col(c, "cloth2"), 5.0), surf("leather", html("#6a4a30"), 3.0) ], [ "cloth", "leather" ]))
    if HUMAN_LOOK != "" and hold != "low" and hold != "":
        let jk, ja, jf = human_joints(hold)
        def at(pivot:float2, to:float2, turn:float) -> Xform:
            return xmul(Xform { axis_angle(float3 { 0.0, 0.0, 1.0 }, turn), v3of(to) }, Xform { BASIS_ID, -v3of(pivot) })
        let thigh = at(float2_0, float2_0, atan2(jk) - atan2(HUMAN_KNEE))
        let shin = at(HUMAN_KNEE, jk, atan2(ja - jk) - atan2(HUMAN_ANKLE - HUMAN_KNEE))
        let foot = at(HUMAN_ANKLE, ja, jf)
        for(leg.kids) piece:
            let name = if piece.kids.length: piece.kids[0].meta else: ""
            if starts_with(name, "thigh"): set_xform(piece, xmul(thigh, node_xform(piece)))
            elif starts_with(name, "shin"): set_xform(piece, xmul(shin, node_xform(piece)))
            elif starts_with(name, "foot"): set_xform(piece, xmul(foot, node_xform(piece)))
    add_child(n, leg)
    return spec_of(n)

// Where a heroic leg's knee and ankle are in a walk step (2D, the hip at the origin), and the foot's turn (degrees).
def human_joints(pose:string) -> float2, float2, float:
    let thigh = magnitude(HUMAN_KNEE)
    let shin = magnitude(HUMAN_ANKLE - HUMAN_KNEE)
    let reach = 0.985 * (thigh + shin)
    let p = walk_step(pose)
    var x = HUMAN_ANKLE.x
    var lift = 0.0
    var turn = 0.0
    if p >= 0.0:
        if p < HUMAN_STANCE:
            x += HUMAN_STRIDE * (0.5 - p / HUMAN_STANCE)
        else:
            let q = (p - HUMAN_STANCE) / (1.0 - HUMAN_STANCE)
            x += HUMAN_STRIDE * (smoothstep(0.0, 1.0, q) - 0.5)
            lift = HUMAN_LIFT * sin(q * 180.0)
            turn = -0.35 * RAD_DEG * sin(q * 180.0)
    let ankle = float2 { x, max(HUMAN_ANKLE.y, -sqrt(max(reach * reach - x * x, 1.0))) + lift }
    return ik2(ankle, thigh, shin, true), ankle, turn

// ------------------------------------------------------------------ this file's parts by id
def build_units(base:string, c:Colours) -> Spec?:
    switch base:
        case "body.frog": return body_frog(c)
        case "head.frog": return head_frog(c)
        case "leg.frog": return leg_frog(c)
        case "tool.basket": return tool_basket(c)
        case "weapon.spear.reed", "weapon.spear_reed": return weapon_spear_reed(c)  // (Godot finds a model by the id with . as _)
        case "armour.bark": return armour_bark(c)
        case "shield.lilypad": return shield_lilypad(c)
        case "helm.acorn": return helm_acorn(c)
        case "hat.leaf": return hat_leaf(c)
        case "cape.leaf": return cape_leaf(c)
        case "body.rat": return body_rat(c)
        case "head.rat": return head_rat(c)
        case "leg.rat": return leg_rat(c)
        case "tool.axe": return tool_axe(c)
        case "weapon.spear.bronze", "weapon.spear_bronze": return weapon_spear_bronze(c)
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
