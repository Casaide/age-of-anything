// ------------------------------------------------------------------ unit parts III (unit_models.gd 1520-2233: cat, hummingbird, animals, beetles, newt)
// Each builder is unit_models.gd's of the same name (`_body_cat` -> body_cat), line for line; its
// comments are there. The cat's helpers (cat_tail, cat_saddle, cat_bridle) are the creature kit's too
// (model/kit_bodies.lobster).

// ---- small helpers this file shares with the kit

def u3_col_or(c:Colours, ch:string, fallback:float3) -> float3: return if has_col(c, ch): col(c, ch) else: fallback   // c.get(ch, fallback)
def u3_lerpf(a:float, b:float, t:float) -> float: return a + (b - a) * t
def u3_lerp(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t
def u3_smooth(a:float, b:float, s:float) -> float:   // Godot's smoothstep
    let t = clamp((s - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
def u3_rot2(v:float2, deg:float) -> float2:   // Vector2.rotated (degrees here)
    let cs = cos(deg)
    let sn = sin(deg)
    return float2 { v.x * cs - v.y * sn, v.x * sn + v.y * cs }
def u3_v3(p:float2) -> float3: return float3 { p.x, p.y, 0.0 }
def u3_mat(d:dictionary<string, MMat>, k:string) -> MMat:
    let m = d.get(k)
    assert m
    return m
def u3_rot_z(n:MNode, deg:float):   // rotation_degrees.z = deg
    n.rot = float3 { n.rot.x, n.rot.y, deg }
let U3_ZUP = float3 { 0.0, 0.0, 1.0 }

// ------------------------------------------------------------------ cat (the rats' mount)

let CAT_K = 1.25
let CAT_HEAD_K = 1.3
let CAT_DROP = 1.0
let CAT_HIP = float3 { -8.0, 13.5 - CAT_DROP, 0.0 }
let CAT_SHOULDER = float3 { 8.5, 12.5 - CAT_DROP, 0.0 }
let CAT_LEG_Z = 3.0
let CAT_HEAD_AT = float3 { 15.2, 15.2 - CAT_DROP, 0.0 }
let CAT_SEAT = float3 { -2.0, 19.3 - CAT_DROP, 0.0 }
let CAT_SIT_LIFT = 0.8
let CAT_SIT_OUT = 1.6
let CAT_HIND = [5.4, 5.9, 4.3]
let CAT_FORE = [5.0, 5.5, 1.4]
let CAT_PAD = 0.75
let CAT_STRIDE = 7.5
let CAT_STANCE = 0.62
let CAT_SCAPULA = float2 { -1.4, 5.6 }
let CAT_EYE = html("#c8c23a")
let CAT_NOSE = html("#c88080")

// CAT_SIT: body pitch (degrees, nose up), hip height
def cat_sit_has(pose:string) -> bool: return pose == "sit" or pose == "sit2" or pose == "sit1"
def cat_sit(pose:string) -> float2:
    if pose == "sit": return float2 { 34.0, 3.8 }
    if pose == "sit2": return float2 { 25.0, 6.4 }
    return float2 { 13.0, 9.4 }

def cat_xf(pose:string) -> Xform:
    if not cat_sit_has(pose): return XF_ID
    let s = cat_sit(pose)
    let hip = float3 { CAT_HIP.x, s.y, 0.0 }
    return xmul(Xform { axis_angle(U3_ZUP, s.x), hip }, Xform { BASIS_ID, -CAT_HIP })

def cat_coat(c:Colours) -> dictionary<string, MMat>:
    let pale = u3_col_or(c, "skin3", html("#e8e2d6"))
    return mats_of([surf("hide", col(c, "skin"), 4.0), surf("hide", col(c, "skin2"), 4.0), surf("hide", pale, 4.0),
                    plain(CAT_NOSE), plain(INK), plain(CAT_EYE), plain(lightened(CAT_NOSE, 0.2))],
                   ["fur", "stripe", "pale", "nose", "eye", "iris", "ear_in"])

def body_cat(c:Colours) -> Spec:
    let pose = if hold == "low": "" else: hold
    let t = cat_xf(pose)
    let n = mnode()
    let inner = mnode()
    set_xform(inner, t)
    add_child(n, inner)
    let low = mnode()
    low.pos = float3 { 0.0, -CAT_DROP, 0.0 }
    add_child(inner, low)
    let m = cat_coat(c)
    add_child(low, glb("body_cat_lean", m))
    cat_saddle(low, c, CAT_SEAT.x, CAT_SEAT.y + CAT_DROP - 1.4, 4.1, float3 { 2.6, 13.2, 0.0 }, 4.9, 4.9, 6.0, 2.6)
    if pose == "sit":
        let b = xf(t, float3 { -12.0, 14.0 - CAT_DROP, 0.0 })
        let paw = xf(t, CAT_SHOULDER).x + 0.9
        cat_tail(n, [b, float3 { b.x + 0.5, 1.1, 1.8 }, float3 { b.x + 1.6, 1.0, 3.4 }, float3 { b.x + 3.4, 1.0, 4.8 },
                     float3 { paw - 6.5, 1.0, 5.2 }, float3 { paw - 3.0, 1.1, 4.9 }, float3 { paw - 1.2, 2.0, 4.3 }],
                 1.35, 0.95, u3_mat(m, "fur"), u3_mat(m, "stripe"))
    elif pose == "sit1" or pose == "sit2":
        let b = xf(t, float3 { -12.0, 14.4 - CAT_DROP, 0.0 })
        cat_tail(n, [b, b + float3 { -2.8, -0.9, 0.2 }, float3 { b.x - 4.8, max(2.6, b.y - 3.6), 0.5 },
                     float3 { b.x - 5.6, 1.2, 0.9 }, float3 { b.x - 4.6, 1.0, 1.6 }], 1.6, 1.1, u3_mat(m, "fur"), u3_mat(m, "stripe"))
    else:
        cat_tail(low, [float3 { -12.0, 14.6, 0.0 }, float3 { -15.2, 18.8, 0.0 }, float3 { -16.6, 23.4, 0.3 }, float3 { -16.2, 27.6, 0.5 },
                       float3 { -14.5, 30.0, 0.6 }, float3 { -12.6, 30.2, 0.6 }], 1.6, 1.1, u3_mat(m, "fur"), u3_mat(m, "stripe"))
    let seat = CAT_SEAT + (if pose == "sit": float3 { 0.0, CAT_SIT_LIFT, 0.0 } else: float3_0)
    let s = spec_of(n)
    sock(s, "head", xf(t, CAT_HEAD_AT))
    sock(s, "hand_r", xf(t, seat + float3 { 5.0, -6.0, 5.0 }))
    sock(s, "hand_l", xf(t, seat + float3 { 4.0, -6.0, -5.0 }))
    sock(s, "torso", xf(t, float3 { 0.0, seat.y - 5.0, 0.0 }))
    sock(s, "back", xf(t, seat + float3 { -7.0, -1.5, 0.0 }))
    sock(s, "seat", xf(t, seat))
    sock(s, "wings", xf(t, seat + float3 { 7.0, -1.5, 0.0 }))
    sock(s, "girth", xf(t, float3 { seat.x, 11.5, 0.0 }))
    let z = float3 { 0.0, 0.0, CAT_LEG_Z }
    s.anchors = [anchor(xf(t, CAT_SHOULDER + z), MPI * 1.5, 1, [0.0, 0.0]), anchor(xf(t, CAT_HIP + z), 0.0, 1, [0.0, 1.0]),
                 anchor(xf(t, CAT_SHOULDER - z), MPI * 0.5, -1, [0.0, 0.0]), anchor(xf(t, CAT_HIP - z), MPI, -1, [0.0, 1.0])]
    spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })
    spec_str(s, "carry", "harness")
    return scaled(s, CAT_K)

def head_cat(c:Colours) -> Spec:
    let root = mnode()
    let n = glb("head_cat_lean", cat_coat(c))
    u3_rot_z(n, -4.0)
    n.scl = float3_1 * CAT_HEAD_K
    add_child(root, n)
    cat_bridle(root, c, float3 { 4.6, -0.4, 0.0 } * CAT_HEAD_K, 1.8 * CAT_HEAD_K, float3 { -0.3, 1.2, 0.0 } * CAT_HEAD_K, 3.35 * CAT_HEAD_K, -4.0)
    let white = plain(lightened(u3_col_or(c, "skin3", html("#e8e2d6")), 0.3))
    let q = axis_angle(U3_ZUP, -4.0)
    for([1.0, -1.0]) s:
        for([-0.5, 0.0, 0.5]) w:
            let a = float3 { 4.9, -0.7 + w * 0.5, 1.2 * s }
            add_child(root, rod(bxf(q, a) * CAT_HEAD_K, bxf(q, a + float3 { 1.2, w, 2.4 * s }) * CAT_HEAD_K, 0.09, 0.06, white, false))
    return scaled(sock(spec_of(root), "top", float3 { 1.6, 4.2, 0.0 } * CAT_HEAD_K), CAT_K)

def leg_cat(c:Colours) -> Spec: return cat_leg(c, false)
def leg_cat_hind(c:Colours) -> Spec: return cat_leg(c, true)

// A leg's joints in a pose (cat_joints' dictionary; `out` 0 when it has none).
class CatJ:
    paw = float2_0
    toe = float2_0
    knee = float2_0
    hock = float2_0
    wrist = float2_0
    elbow = float2_0
    scapula = float2_0
    out = 0.0

def cat_leg(c:Colours, hind:bool) -> Spec:
    let j = cat_joints(hind, if hold == "low": "" else: hold)
    let n = mnode()
    let fur = surf("hide", col(c, "skin"), 4.0)
    let pale = surf("hide", u3_col_or(c, "skin3", html("#e8e2d6")), 4.0)
    let sk = surf("hide", u3_col_or(c, "skin4", col(c, "skin")), 4.0)
    if hind:
        let out = float3 { 0.0, 0.0, j.out }
        add_child(n, rod(float3 { 0.3, 1.6, 0.0 }, u3_v3(j.knee) + out * 0.5, 2.8, 1.8, fur))
        add_child(n, rod(u3_v3(j.knee) + out * 0.5, u3_v3(j.hock) + out, 1.7, 1.0, fur))
        add_child(n, rod(u3_v3(j.hock) + out, u3_v3(j.paw) + out, 1.05, 0.9, sk))
    else:
        add_child(n, rod(float3_0, u3_v3(j.scapula), 2.4, 1.4, fur))
        add_child(n, rod(float3_0, u3_v3(j.elbow), 2.6, 1.7, sk))
        add_child(n, rod(u3_v3(j.elbow), u3_v3(j.wrist), 1.55, 1.1, sk))
        add_child(n, rod(u3_v3(j.wrist), u3_v3(j.paw), 1.0, 0.95, pale))
    let toe = j.toe
    let paw_out = if hind: float3 { 0.0, 0.0, j.out } else: float3_0
    add_child(n, blob(float3 { 1.5, 0.75, 1.3 }, pale, u3_v3(j.paw + toe * 0.45) + paw_out, float3 { 0.0, 0.0, atan2(toe) }))
    return scaled(spec_of(n), CAT_K)

// A walk step "w<i>_<n>" as its fraction of the cycle.
def u3_walk_frac(pose:string) -> float:
    let nums = tokenize(pose.substring(1, pose.length - 1), "_", "")
    let a, _a = string_to_int(nums[0])
    let b, _b = string_to_int(nums[1])
    return float(a) / float(b)

def cat_joints(hind:bool, pose:string) -> CatJ:
    var h = if hind: CAT_HIP.y else: CAT_SHOULDER.y
    var lift = 0.0
    var x = if hind: -0.5 else: 0.6
    var tilt = if hind: 18.0 else: 4.0
    var down = 0.0
    if starts_with(pose, "w"):
        let p = u3_walk_frac(pose)
        let x0 = x
        if p < CAT_STANCE:
            let s = p / CAT_STANCE
            x = x0 + CAT_STRIDE * (0.5 - s)
            tilt = if hind: u3_lerpf(8.0, 38.0, s) else: u3_lerpf(-4.0, 22.0, s)
            down = sin(s * 180.0)
        else:
            let q = (p - CAT_STANCE) / (1.0 - CAT_STANCE)
            x = x0 + CAT_STRIDE * (u3_smooth(0.0, 1.0, q) - 0.5)
            lift = 2.4 * sin(q * 180.0)
            tilt = if hind: u3_lerpf(38.0, 8.0, q) + 22.0 * sin(q * 180.0) else: u3_lerpf(22.0, -4.0, q) + 60.0 * sin(q * 180.0)
    elif cat_sit_has(pose):
        let t = cat_xf(pose)
        h = if hind: cat_sit(pose).y else: xf(t, CAT_SHOULDER).y
        if hind:
            if pose == "sit":
                let j = CatJ {}
                j.hock = float2 { -0.8, -h + 0.9 }
                j.paw = float2 { 3.6, -h + CAT_PAD }
                j.knee = ik(float2_0, j.hock, CAT_HIND[0], CAT_HIND[1], 1.0)
                j.toe = float2 { 1.0, 0.0 }
                j.out = CAT_SIT_OUT
                return j
            x = if pose == "sit1": 1.2 else: 2.4
            tilt = if pose == "sit1": 44.0 else: 66.0
        else:
            x = 0.9
            tilt = 2.0
    var paw = float2 { x, -h + CAT_PAD + lift }
    let r = tilt   // (degrees)
    let j = CatJ {}
    if hind:
        var hock = paw + float2 { -sin(r), cos(r) } * CAT_HIND[2]
        let reach = CAT_HIND[0] + CAT_HIND[1] - 0.05
        if magnitude(hock) > reach:
            let fix = normalize(hock) * reach - hock
            hock += fix
            paw += fix
        j.hock = hock
        j.paw = paw
        j.knee = ik(float2_0, hock, CAT_HIND[0], CAT_HIND[1], 1.0)
        j.toe = if lift > 0.0: float2 { cos(r * 0.5), -sin(r * 0.5) } else: float2 { 1.0, 0.0 }
        return j
    var wrist = paw + float2 { sin(r), cos(r) } * CAT_FORE[2]
    let reach2 = CAT_FORE[0] + CAT_FORE[1] - 0.05
    if magnitude(wrist) > reach2:
        let fix2 = normalize(wrist) * reach2 - wrist
        wrist += fix2
        paw += fix2
    var scap = CAT_SCAPULA + float2 { -0.25 * (x - 0.6), 0.9 * down }
    if cat_sit_has(pose):
        scap = u3_rot2(CAT_SCAPULA * 0.8, cat_sit(pose).x * 0.6)
    var toe = float2 { 1.0, 0.0 }
    if lift > 0.0:
        toe = u3_rot2(normalize(paw - wrist), 90.0)
        if toe.x < -0.2: toe = float2 { 1.0, 0.0 }
    j.wrist = wrist
    j.paw = paw
    j.elbow = ik(float2_0, wrist, CAT_FORE[0], CAT_FORE[1], -1.0)
    j.scapula = scap
    j.toe = toe
    return j

def cat_saddle(n:MNode, c:Colours, x:float, y:float, half:float, girth_c:float3, ry:float, rz:float, length:float = 9.0, drop:float = 4.4):
    let cloth = plain(col(c, "team"))
    let trim = surf("cloth", html("#e8e0d0"), 3.0)
    add_child(n, box(float3 { length, 0.7, half * 1.7 }, cloth, float3 { x, y, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { length, drop, 0.5 }, cloth, float3 { x, y - drop * 0.5 - 0.2, (half * 0.85) * side }, float3 { 10.0 * side, 0.0, 0.0 }))
        add_child(n, box(float3 { length + 0.2, 0.7, 0.6 }, trim, float3 { x, y - drop - 0.1, (half * 0.85 + 0.35) * side }, float3 { 10.0 * side, 0.0, 0.0 }))
    add_child(n, box(float3 { min(5.5, length - 1.5), 1.2, half * 1.2 }, surf("leather", float3 { 0.7, 0.5, 0.35 }, 3.0), float3 { x, y + 0.8, 0.0 }))
    harness(n, girth_c, ry, rz, girth_c + float3 { -1.0, -1.0, rz + 0.4 }, girth_c + float3 { -1.0, -1.0, -rz - 0.4 })

def cat_tail(n:MNode, pts:[float3], r0:float, r1:float, fur:MMat, dark:MMat, tip_dark:bool = true):
    let count = pts.length - 1
    for(count) k:
        let ra = u3_lerpf(r0, r1, float(k) / float(count))
        let rb = u3_lerpf(r0, r1, float(k + 1) / float(count))
        let m = if k % 2 == 1 or (tip_dark and k == count - 1): dark else: fur
        add_child(n, rod(pts[k], pts[k + 1], ra, rb, m))

def cat_bridle(n:MNode, c:Colours, snout:float3, sr:float, crown:float3, cr:float, tilt:float):
    let leather = surf("leather", float3 { 0.55, 0.4, 0.28 }, 2.0)
    let q = axis_angle(U3_ZUP, tilt)
    add_child(n, ring(sr * 0.92, sr * 1.08, leather, bxf(q, snout), float3 { 0.0, 0.0, 90.0 + tilt }, float3 { 1.0, 1.4, 1.0 }))
    add_child(n, ring(cr * 0.9, cr * 1.04, leather, bxf(q, crown), float3 { 0.0, 0.0, 70.0 + tilt }, float3 { 1.0, 1.6, 1.0 }))
    add_child(n, rod(bxf(q, snout + float3 { -0.6, sr * 0.6, 0.0 }), bxf(q, crown + float3 { 1.6, cr * 0.7, 0.0 }), 0.3, 0.3, leather))
    add_child(n, blob(float3 { 0.5, 0.5, 0.5 }, surf("bronze", float3_1, 2.0), bxf(q, snout + float3 { -0.8, 0.0, sr * 1.02 })))

// ------------------------------------------------------------------ hummingbird (forest cavalry, HB1)

let HB_BELLY = html("#e6e2d2")
let HB_BEAK = html("#1c1816")
let HB_BLUR = html("#e2f6e8")

def hb_gloss(cl:float3) -> MMat: return plain(cl)   // (metallic, roughness, rim: not the baker's)
def hb_blur_mat(cl:float3) -> MMat: return glow(cl)

def hb_wing(m:MMat, root:float3, tip:float3, w:float, up:float3) -> MNode:
    let d = tip - root
    let l = magnitude(d)
    let pts = [float2 { 0.0, -w * 0.2 }, float2 { l * 0.3, w }, float2 { l * 0.75, w * 0.85 }, float2 { l, w * 0.2 }, float2 { l * 0.95, -w * 0.2 }, float2 { l * 0.5, -w * 0.3 }]
    let mi = slab(pts, 0.4, m, float3_0)
    let x = normalize(d)
    let z = normalize(cross(x, up))
    let y = cross(z, x)
    set_basis(mi, Basis { x, y, z })
    mi.pos = root
    return mi

def hb_ghosts(count:int, spread:float, tones:[float3]) -> MNode:
    let n = mnode()
    for([1.0, -1.0]) side:
        for(count) k:
            let a = 8.0 + float(k) * spread
            let tip = float3 { -2.0 - float(k) * 1.5, 3.0 + 21.0 * cos(a), (2.0 + 19.0 * sin(a)) * side }
            add_child(n, hb_wing(hb_blur_mat(tones[k % tones.length]), float3 { 0.0, 0.0, 1.6 * side }, tip, 4.2, float3 { 1.0, 0.0, 0.0 }))
    return n

def body_hummingbird(c:Colours) -> Spec:
    let n = mnode()
    let green = hb_gloss(col(c, "skin"))
    let dark = hb_gloss(darkened(col(c, "skin"), 0.45))
    add_child(n, blob(float3 { 9.5, 5.4, 5.4 }, green, float3 { 0.0, 14.0, 0.0 }, float3 { 0.0, 0.0, 24.0 }))
    add_child(n, blob(float3 { 6.5, 3.2, 4.4 }, plain(HB_BELLY), float3 { 1.5, 11.0, 0.0 }, float3 { 0.0, 0.0, 24.0 }))
    add_child(n, blob(float3 { 5.4, 6.0, 5.4 }, green, float3 { 5.5, 17.5, 0.0 }))
    add_child(n, blob(float3 { 3.8, 3.6, 4.4 }, hb_gloss(col(c, "skin2")), float3 { 8.6, 20.0, 0.0 }))
    add_child(n, blob(float3 { 3.2, 3.6, 3.4 }, green, float3 { 9.4, 22.6, 0.0 }))
    for(5) f:
        let base = float3 { -7.5, 10.5, 0.0 }
        let end = base + float3 { -9.0 + abs(float(f - 2)) * 1.2, -4.5, sin(-30.0 + float(f) * 15.0) * 4.5 }
        add_child(n, rod(base, end, 0.9, 1.3, dark))
        add_child(n, blob(float3 { 1.1, 0.5, 1.0 }, plain(HB_BELLY), end + float3 { -0.6, -0.2, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.3, 0.7, 0.7 }, plain(INK), float3 { 1.5, 7.6, 1.8 * side }))
    let seat = float3 { -2.5, 19.6, 0.0 }
    add_child(n, blob(float3 { 4.8, 1.2, 5.6 }, plain(col(c, "team")), seat + float3 { 0.0, -0.5, 0.0 }, float3 { 0.0, 0.0, 20.0 }))
    harness(n, float3 { -1.0, 14.0, 0.0 }, 5.8, 5.9, float3 { 0.0, 13.0, 5.9 }, float3 { 0.0, 13.0, -5.9 })
    let s = spec_of(n)
    sock(s, "head", float3 { 10.5, 25.0, 0.0 })
    sock(s, "hand_r", float3 { 0.0, 13.0, 6.4 })
    sock(s, "hand_l", float3 { 0.0, 13.0, -6.4 })
    sock(s, "torso", float3 { 0.0, 14.0, 0.0 })
    sock(s, "back", float3 { 5.5, 20.5, 0.0 })
    sock(s, "seat", seat + float3 { 0.0, 0.8, 0.0 })
    spec_num(s, "torso_scale", float3 { 1.1, 0.85, 0.0 })
    return spec_str(s, "carry", "harness")

def head_hummingbird(c:Colours) -> Spec:
    let n = mnode()
    let green = hb_gloss(col(c, "skin"))
    add_child(n, blob(float3 { 4.5, 4.2, 4.0 }, green, float3_0))
    add_child(n, blob(float3 { 3.2, 1.6, 3.1 }, hb_gloss(darkened(col(c, "skin"), 0.45)), float3 { -0.7, 2.9, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.1, 1.1, 0.7 }, plain(INK), float3 { 1.9, 0.9, 3.1 * side }))
        add_child(n, blob(float3 { 0.4, 0.4, 0.3 }, plain(float3_1), float3 { 2.4, 1.4, 3.5 * side }))
        add_child(n, blob(float3 { 1.0, 0.5, 0.4 }, plain(float3_1), float3 { -0.1, 1.8, 3.4 * side }))
    let tip = float3 { 20.5, -1.4, 0.0 }
    add_child(n, rod(float3 { 4.0, 0.2, 0.0 }, tip, 0.95, 0.3, plain(HB_BEAK)))
    let bronze = surf("bronze", float3_1, 2.0)
    add_child(n, cone(0.0, 0.9, 4.0, bronze, tip + float3 { -1.2, 0.1, 0.0 }, float3 { 0.0, 0.0, -95.0 }))
    add_child(n, ring(0.8, 1.15, bronze, float3 { 12.5, -0.6, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    add_child(n, slab([float2 { 0.0, 0.0 }, float2 { -6.0, 1.0 }, float2 { -4.5, -1.6 }, float2 { -6.5, -3.8 }, float2 { 0.0, -2.4 }], 0.3, plain(col(c, "team")), float3 { 13.0, -0.8, 0.0 }))
    return sock(spec_of(n), "top", float3 { -0.5, 4.0, 0.0 })

def wings_hummingbird(c:Colours) -> Spec:
    return spec_of(hb_ghosts(3, 36.0, [HB_BLUR, lightened(col(c, "skin"), 0.55), darkened(HB_BLUR, 0.08)]))

// ------------------------------------------------------------------ animals (milestone 11)

def four_legs(front:float, back:float, y:float, z:float) -> [Anchor]:
    return [anchor(float3 { front, y, z }, 0.0, 1, [0.0]), anchor(float3 { back, y, z }, MPI, 1, [0.0]),
            anchor(float3 { front - 1.0, y, -z }, MPI, -1, [0.0]), anchor(float3 { back - 1.0, y, -z }, 0.0, -1, [0.0])]

def body_deer(c:Colours) -> Spec:
    let n = mnode()
    let coat = surf("hide", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 9.0, 5.2, 4.4 }, coat, float3 { 0.0, 17.0, 0.0 }))
    add_child(n, blob(float3 { 4.5, 2.4, 3.6 }, surf("hide", lightened(col(c, "skin"), 0.35), 4.0), float3 { 1.0, 13.6, 0.0 }))
    add_child(n, rod(float3 { 6.5, 18.5, 0.0 }, float3 { 10.5, 25.0, 0.0 }, 2.4, 1.7, coat))
    add_child(n, blob(float3 { 1.6, 1.9, 1.2 }, plain(html("#f2ece0")), float3 { -9.0, 18.6, 0.0 }))
    let s = spec_of(n)
    sock(s, "head", float3 { 10.8, 25.5, 0.0 })
    sock(s, "torso", float3 { 0.0, 17.0, 0.0 })
    sock(s, "back", float3 { -5.0, 21.0, 0.0 })
    s.anchors = four_legs(5.5, -5.5, 14.2, 2.2)
    return spec_str(s, "carry", "harness")

def head_deer(c:Colours) -> Spec:
    let n = mnode()
    let coat = surf("hide", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 2.4, 2.1, 1.9 }, coat, float3 { 0.6, 0.5, 0.0 }))
    add_child(n, rod(float3 { 1.5, 0.3, 0.0 }, float3 { 5.2, -1.6, 0.0 }, 1.5, 0.8, coat))
    add_child(n, blob(float3 { 0.7, 0.6, 0.7 }, plain(INK), float3 { 5.3, -1.6, 0.0 }))
    let antler = plain(html("#d8c8a4"))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.5, 1.3, 0.7 }, coat, float3 { -0.6, 2.4, 1.6 * side }, float3 { 0.0, 0.0, -20.0 }))
        add_child(n, blob(float3 { 0.45, 0.45, 0.4 }, plain(INK), float3 { 2.0, 1.2, 1.5 * side }))
        let base = float3 { 0.2, 2.2, 0.8 * side }
        let tip = base + float3 { -1.0, 5.5, 2.2 * side }
        add_child(n, rod(base, tip, 0.35, 0.18, antler))
        add_child(n, rod(u3_lerp(base, tip, 0.45), u3_lerp(base, tip, 0.45) + float3 { 1.8, 1.6, 0.4 * side }, 0.25, 0.12, antler))
        add_child(n, rod(u3_lerp(base, tip, 0.75), u3_lerp(base, tip, 0.75) + float3 { 1.5, 1.4, 0.2 * side }, 0.22, 0.1, antler))
    return sock(spec_of(n), "top", float3 { 0.0, 2.5, 0.0 })

def leg_deer(c:Colours) -> Spec:
    let n = mnode()
    let coat = surf("hide", col(c, "skin"), 4.0)
    let knee, foot = stepped(float3 { 0.3, -7.0, 0.0 }, float3 { 0.6, -13.0, 0.0 }, if hold == "low": "" else: hold, 9.0)   // (D-179: baked per walk step)
    add_child(n, rod(float3_0, knee, 1.2, 0.6, coat))
    add_child(n, rod(knee, foot, 0.55, 0.45, coat))
    add_child(n, blob(float3 { 0.7, 0.6, 0.6 }, plain(col(c, "skin2")), foot + float3 { 0.2, -0.3, 0.0 }))
    return spec_of(n)

def body_boar(c:Colours) -> Spec:
    let n = mnode()
    let hide = surf("hide", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 9.5, 6.4, 5.6 }, hide, float3 { 0.0, 11.0, 0.0 }))
    add_child(n, blob(float3 { 5.5, 5.0, 4.6 }, hide, float3 { 5.5, 12.5, 0.0 }))
    let bristle = plain(col(c, "skin2"))
    for(8) k:
        let x = 7.0 - float(k) * 1.9
        add_child(n, rod(float3 { x, 16.5 - abs(x - 3.0) * 0.18, 0.0 }, float3 { x - 0.9, 19.0 - abs(x - 3.0) * 0.2, 0.0 }, 0.5, 0.15, bristle, false))
    add_child(n, rod(float3 { -9.0, 12.0, 0.0 }, float3 { -11.0, 9.0, 0.0 }, 0.4, 0.2, hide))
    let s = spec_of(n)
    sock(s, "head", float3 { 10.5, 11.5, 0.0 })
    sock(s, "torso", float3 { 0.0, 11.0, 0.0 })
    sock(s, "back", float3 { -4.0, 16.0, 0.0 })
    s.anchors = four_legs(5.5, -6.0, 7.5, 3.4)
    return spec_str(s, "carry", "harness")

def head_boar(c:Colours) -> Spec:
    let n = mnode()
    let hide = surf("hide", col(c, "skin"), 5.0)
    add_child(n, rod(float3 { -0.5, 0.5, 0.0 }, float3 { 5.5, -1.5, 0.0 }, 3.0, 1.6, hide))
    add_child(n, rod(float3 { 3.0, -1.2, 0.0 }, float3 { 5.6, -2.0, 0.0 }, 1.9, 1.5, plain(html("#9a6e58"))))
    add_child(n, blob(float3 { 1.0, 1.9, 2.0 }, plain(html("#e0a898")), float3 { 6.1, -1.9, 0.0 }))
    let tusk = plain(html("#f8f2e2"))
    for([1.0, -1.0]) side:
        add_child(n, rod(float3 { 4.4, -2.6, 1.5 * side }, float3 { 5.6, 0.4, 2.6 * side }, 0.6, 0.2, tusk))
        add_child(n, blob(float3 { 0.4, 0.4, 0.4 }, plain(INK), float3 { 2.6, 1.0, 1.9 * side }))
        add_child(n, blob(float3 { 0.6, 1.2, 0.5 }, hide, float3 { 0.4, 2.6, 1.8 * side }, float3 { 0.0, 0.0, -25.0 }))
    return sock(spec_of(n), "top", float3 { 0.0, 2.5, 0.0 })

def leg_boar(c:Colours) -> Spec:
    let n = mnode()
    let knee, foot = stepped(float3 { 0.35, -3.3, 0.0 }, float3 { 0.3, -6.6, 0.0 }, if hold == "low": "" else: hold, 5.0)   // (D-179: baked per walk step)
    let hide = surf("hide", col(c, "skin"), 4.0)
    add_child(n, rod(float3_0, knee, 1.6, 1.25, hide))
    add_child(n, rod(knee, foot, 1.25, 0.9, hide))
    add_child(n, blob(float3 { 0.9, 0.6, 0.8 }, plain(col(c, "skin2")), foot + float3 { 0.2, -0.4, 0.0 }))
    return spec_of(n)

def body_sheep(c:Colours) -> Spec:
    let n = mnode()
    let wool = plain(col(c, "skin"))
    let shade = plain(darkened(col(c, "skin"), 0.22))
    add_child(n, blob(float3 { 7.5, 5.0, 4.6 }, wool, float3 { -0.5, 10.5, 0.0 }))
    add_child(n, blob(float3 { 4.2, 3.6, 4.0 }, wool, float3 { 4.0, 11.0, 0.0 }))
    let rng = grng(31)
    for(22) k:
        let a = randf(rng) * 360.0
        let up = randf_range(rng, -0.2, 1.0)
        let px = randf_range(rng, -7.0, 6.0)
        let p = float3 { px, 10.5 + up * 4.3, cos(a) * 4.2 * sqrt(1.0 - up * up * 0.5) }
        add_child(n, blob(float3 { 1.4, 1.1, 1.3 }, if k % 3 != 0: wool else: shade, p))
    add_child(n, blob(float3 { 1.4, 1.6, 1.3 }, wool, float3 { -8.0, 11.5, 0.0 }))
    add_child(n, ring(2.1, 3.1, plain(col(c, "team")), float3 { 7.9, 12.6, 0.0 }, float3 { 0.0, 0.0, 65.0 }, float3 { 1.0, 1.8, 1.0 }))
    let s = spec_of(n)
    sock(s, "head", float3 { 8.0, 12.5, 0.0 })
    sock(s, "torso", float3 { 0.0, 10.5, 0.0 })
    sock(s, "back", float3 { -3.0, 14.0, 0.0 })
    s.anchors = four_legs(4.5, -4.5, 7.0, 2.4)
    return spec_str(s, "carry", "harness")

def head_sheep(c:Colours) -> Spec:
    let n = mnode()
    let face = surf("hide", col(c, "skin2"), 4.0)
    add_child(n, blob(float3 { 1.8, 1.4, 1.6 }, plain(col(c, "skin")), float3 { -0.4, 1.2, 0.0 }))
    add_child(n, blob(float3 { 2.6, 1.7, 1.5 }, face, float3 { 1.6, -0.6, 0.0 }, float3 { 0.0, 0.0, -25.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.5, 0.4, 0.7 }, face, float3 { 0.0, 0.4, 1.9 * side }, float3 { 0.0, 25.0 * side, -10.0 }))
        add_child(n, blob(float3 { 0.3, 0.3, 0.3 }, plain(html("#d8c8a0")), float3 { 1.2, 0.0, 1.1 * side }))
    return sock(spec_of(n), "top", float3 { 0.0, 2.0, 0.0 })

def leg_sheep(c:Colours) -> Spec:
    let n = mnode()
    let knee, foot = stepped(float3 { 0.3, -3.3, 0.0 }, float3 { 0.2, -6.6, 0.0 }, if hold == "low": "" else: hold, 4.5)   // (D-179: baked per walk step)
    let shank = surf("hide", col(c, "skin2"), 4.0)
    add_child(n, rod(float3_0, knee, 0.8, 0.7, shank))
    add_child(n, rod(knee, foot, 0.7, 0.6, shank))
    add_child(n, blob(float3 { 0.7, 0.45, 0.6 }, plain(darkened(col(c, "skin2"), 0.3)), foot + float3 { 0.2, -0.2, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ beetle soldier (rearing, BG1)

def body_beetle_rear(c:Colours) -> Spec:
    let n = mnode()
    let shell = surf("chitin", col(c, "skin"), 5.0)
    let plate = surf("chitin", col(c, "skin2"), 4.0)
    let limb = surf("chitin", darkened(col(c, "skin"), 0.45), 3.0)
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 8.0, 4.6, 3.4 }, shell, float3 { -4.5, 9.5, 2.3 * side }, float3 { 0.0, 0.0, 12.0 }))
    add_child(n, rod(float3 { -11.5, 8.0, 0.0 }, float3 { 1.5, 12.5, 0.0 }, 0.35, 0.35, plain(darkened(col(c, "skin"), 0.6)), false))
    add_child(n, blob(float3 { 4.2, 7.0, 5.4 }, plate, float3 { 2.5, 16.0, 0.0 }, float3 { 0.0, 0.0, -18.0 }))
    add_child(n, blob(float3 { 4.0, 1.0, 5.6 }, plain(col(c, "team")), float3 { -4.5, 14.0, 0.0 }, float3 { 0.0, 0.0, 12.0 }))
    let front = mnode()
    let hand_r = float3 { 7.5, 13.5, 7.0 }
    let pe, ph = arm_pose(float3 { 3.5, 18.0, 4.0 }, float3 { 6.0, 15.5, 6.0 }, hand_r, float3 { 4.0, 22.5, 0.0 })
    add_child(front, rod(float3 { 3.5, 18.0, 4.0 }, pe, 0.95, 0.8, limb))
    add_child(front, rod(pe, ph, 0.8, 0.6, limb))
    add_child(n, rod(float3 { 3.5, 18.0, -4.0 }, float3 { 6.5, 14.5, -6.0 }, 0.95, 0.75, limb))
    let s = spec_of(n)
    s.front = front
    sock(s, "head", float3 { 4.0, 22.5, 0.0 })
    sock(s, "hand_r", ph)
    sock(s, "hand_l", float3 { 6.5, 14.5, -6.0 })
    sock(s, "torso", float3 { 2.5, 16.0, 0.0 })
    sock(s, "back", float3 { -6.0, 14.0, 0.0 })
    sock(s, "drape", float3 { -10.5, 12.5, 0.0 })
    sock(s, "sling", float3 { -9.5, 14.4, 0.0 })
    s.anchors = [anchor(float3 { 0.5, 8.0, 3.2 }, 0.0, 1, [0.0]), anchor(float3 { -6.0, 8.0, 3.2 }, MPI, 1, [1.0]),
                 anchor(float3 { 0.5, 8.0, -3.2 }, MPI, -1, [0.0]), anchor(float3 { -6.0, 8.0, -3.2 }, 0.0, -1, [1.0])]
    return spec_num(s, "torso_scale", float3 { 0.55, 0.65, 0.0 })

// ------------------------------------------------------------------ beetle (a mount)

def body_beetle(c:Colours) -> Spec:
    let n = mnode()
    let shell = surf("chitin", col(c, "skin"), 5.0)
    let plate = surf("chitin", col(c, "skin2"), 4.0)
    let under = plain(darkened(col(c, "skin"), 0.55))
    add_child(n, blob(float3 { 13.5, 4.0, 7.6 }, under, float3 { 0.0, 9.6, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 14.0, 6.8, 4.6 }, shell, float3 { -2.5, 13.5, 3.0 * side }))
    add_child(n, rod(float3 { -15.5, 14.5, 0.0 }, float3 { 10.0, 19.4, 0.0 }, 0.45, 0.45, plain(darkened(col(c, "skin"), 0.6)), false))
    add_child(n, blob(float3 { 5.6, 5.4, 7.4 }, plate, float3 { 11.0, 13.0, 0.0 }))
    add_child(n, blob(float3 { 5.0, 1.2, 6.6 }, plain(col(c, "team")), float3 { -1.5, 20.0, 0.0 }, float3 { 0.0, 0.0, -6.0 }))
    harness(n, float3 { 4.0, 13.5, 0.0 }, 7.2, 8.0, float3 { 4.0, 13.5, 8.0 }, float3 { 3.0, 13.5, -8.0 })
    let s = spec_of(n)
    sock(s, "head", float3 { 16.0, 12.5, 0.0 })
    sock(s, "hand_r", float3 { 4.0, 13.5, 8.6 })
    sock(s, "hand_l", float3 { 3.0, 13.5, -8.6 })
    sock(s, "torso", float3 { 11.0, 14.0, 0.0 })
    sock(s, "back", float3 { -8.0, 19.0, 0.0 })
    sock(s, "seat", float3 { -1.5, 21.5, 0.0 })
    sock(s, "wings", float3 { 6.0, 19.5, 0.0 })
    s.anchors = [anchor(float3 { 10.0, 9.5, 6.0 }, 0.0, 1, [0.0]), anchor(float3 { 2.0, 9.5, 6.5 }, 2.1, 1, [0.0]), anchor(float3 { -7.0, 9.5, 6.0 }, 4.2, 1, [1.0]),
                 anchor(float3 { 11.0, 9.5, -6.0 }, 3.14, -1, [0.0]), anchor(float3 { 3.0, 9.5, -6.5 }, 5.2, -1, [0.0]), anchor(float3 { -6.0, 9.5, -6.0 }, 1.0, -1, [1.0])]
    spec_num(s, "torso_scale", float3 { 0.65, 0.6, 0.0 })
    return spec_str(s, "carry", "harness")

def head_beetle(c:Colours) -> Spec:
    let n = mnode()
    let shell = surf("chitin", col(c, "skin"), 4.0)
    let horn = surf("chitin", col(c, "skin2"), 3.0)
    add_child(n, blob(float3 { 4.6, 3.6, 4.4 }, shell, float3 { 2.5, 0.0, 0.0 }))
    let pts = [float3 { 5.5, 1.0, 0.0 }, float3 { 9.5, 3.5, 0.0 }, float3 { 12.0, 8.0, 0.0 }, float3 { 12.6, 12.0, 0.0 }]
    let r = [2.0, 1.5, 1.0, 0.4]
    for(pts.length - 1) i:
        let k = i + 1
        add_child(n, rod(pts[k - 1], pts[k], r[k - 1], r[k], horn))
    add_child(n, rod(float3 { 10.6, 5.5, 0.0 }, float3 { 13.4, 6.5, 0.0 }, 0.6, 0.3, horn))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.1, 1.1, 0.8 }, plain(html("#141018")), float3 { 4.6, 0.8, 3.3 * side }))
        add_child(n, blob(float3 { 0.4, 0.4, 0.3 }, plain(html("#c8c0d8")), float3 { 5.0, 1.2, 3.8 * side }))
        add_child(n, rod(float3 { 6.2, -1.0, 2.0 * side }, float3 { 9.0, -0.5, 4.2 * side }, 0.25, 0.2, plain(darkened(col(c, "skin"), 0.5))))
        add_child(n, blob(float3 { 0.7, 0.45, 0.7 }, plain(darkened(col(c, "skin"), 0.5)), float3 { 9.2, -0.5, 4.3 * side }))
    return sock(spec_of(n), "top", float3 { 2.0, 3.6, 0.0 })

def leg_insect(c:Colours) -> Spec:
    let n = mnode()
    let shell = surf("chitin", darkened(col(c, "skin"), 0.45), 3.0)
    let knee, foot = stepped(float3 { 4.0, -1.8, 2.0 }, float3 { 6.2, -8.2, 3.0 }, if hold == "low": "" else: hold, 5.5)   // (D-179: baked per walk step)
    add_child(n, rod(float3_0, knee, 1.3, 1.0, shell))
    add_child(n, rod(knee, foot, 0.9, 0.6, shell))
    add_child(n, rod(foot, foot + float3 { 1.8, -0.4, 0.3 }, 0.45, 0.3, shell))
    return spec_of(n)

// ------------------------------------------------------------------ giant newt (a mount, D-122)

let NEWT_SEAT = 17.2
let NEWT_SCALE = 1.2

def body_newt(c:Colours) -> Spec: return scaled(newt_body(c), NEWT_SCALE)
def head_newt(c:Colours) -> Spec: return scaled(newt_head(c), NEWT_SCALE)
def leg_newt(c:Colours) -> Spec: return scaled(newt_leg(c), NEWT_SCALE)

class NewtMats:
    skin:MMat
    belly:MMat
    spot:MMat
    ring:MMat
    ringed:bool
    crest:MMat?

def newt_mats(c:Colours) -> NewtMats:
    let skin = surf("frog_skin", col(c, "skin"), 7.0)
    let belly = surf("frog_belly", col(c, "skin2"), 5.0)
    let rc = u3_col_or(c, "skin4", col(c, "skin"))
    let sc = col(c, "skin")
    let crest = if has_col(c, "skin5"): surf("frog_skin", col(c, "skin5"), 7.0) else: nil
    return NewtMats { skin, belly, plain(u3_col_or(c, "skin3", col(c, "skin2"))), plain(rc), rc.x != sc.x or rc.y != sc.y or rc.z != sc.z, crest }

class NewtLobe:
    at:float3
    r:float3

def newt_spots(n:MNode, m:NewtMats, centres:[NewtLobe], big:float = 1.0):
    let dirs = [float3 { 0.2, 0.8, 0.55 }, float3 { -0.3, 0.7, -0.6 }, float3 { 0.1, 0.35, 0.95 }, float3 { -0.25, 0.4, -0.9 },
                float3 { 0.35, 0.9, 0.1 }]
    var i = 0
    for(centres) c:
        let pair = [dirs[i % dirs.length], dirs[(i + 2) % dirs.length]]
        for(pair) d:
            let at = on_surface(c.at, c.r, d, -0.15)
            let r = (1.6 + 0.5 * float(i % 3)) * big
            if m.ringed:
                add_child(n, blob(float3 { r * 1.35, r * 0.6, r * 1.35 }, m.ring, at + normalize(d) * -0.1))
            add_child(n, blob(float3 { r, r * 0.55, r }, m.spot, at + normalize(d) * 0.25))
            i++

def newt_body(c:Colours) -> Spec:
    let n = mnode()
    let m = newt_mats(c)
    let lobes = [NewtLobe { float3 { 9.0, 9.8, 0.0 }, float3 { 9.0, 5.4, 7.6 } }, NewtLobe { float3 { -1.0, 10.2, 0.0 }, float3 { 10.0, 5.8, 8.4 } },
                 NewtLobe { float3 { -11.0, 9.8, 0.0 }, float3 { 8.5, 5.4, 7.6 } }]
    for(lobes) l: add_child(n, blob(l.r, m.skin, l.at))
    add_child(n, blob(float3 { 19.0, 3.0, 7.2 }, m.belly, float3 { -1.0, 6.4, 0.0 }))
    add_child(n, blob(float3 { 5.0, 4.2, 6.2 }, m.skin, float3 { 16.0, 9.8, 0.0 }))
    let tail = [float3 { -18.0, 9.8, 0.0 }, float3 { -27.0, 8.4, 1.5 }, float3 { -35.0, 6.4, 3.5 }, float3 { -43.0, 4.2, 4.0 }, float3 { -49.0, 2.4, 2.5 }]
    let r = [4.8, 3.9, 2.8, 1.7, 0.5]
    for(tail.length - 1) i:
        let k = i + 1
        let seg = rod(tail[k - 1], tail[k], r[k - 1], r[k], m.skin)
        seg.scl = float3 { 1.0, 1.0, 0.62 }
        seg.pos = tail[k - 1] * float3 { 0.0, 0.0, 0.38 }
        add_child(n, seg)
        add_child(n, blob(float3 { magnitude(tail[k] - tail[k - 1]) * 0.5, r[k] * 0.45, r[k] * 0.5 }, m.belly,
                          (tail[k - 1] + tail[k]) * 0.5 + float3 { 0.0, -r[k] * 0.55, 0.0 }))
    let crest = m.crest
    if crest:
        for(9) k:
            let at = u3_lerp(tail[0], tail[3], float(k) / 8.0)
            let h = 3.6 - float(k) * 0.3
            add_child(n, cone(0.1, 1.3, h, crest, at + float3 { 0.0, u3_lerpf(r[0], r[3], float(k) / 8.0) * 0.92 + h * 0.4, 0.0 }, float3 { 0.0, 0.0, 18.0 }, 6))
        for(3) k:
            add_child(n, cone(0.1, 1.1, 2.8, crest, float3 { 13.0 - float(k) * 3.0, 15.4, 0.0 }, float3 { 0.0, 0.0, 18.0 }, 6))
    let spot_on = [lobes[0], lobes[1], lobes[2],
                   NewtLobe { float3 { -26.0, 9.0, 1.0 }, float3 { 8.0, 3.9, 2.6 } }, NewtLobe { float3 { -36.0, 6.2, 3.0 }, float3 { 7.0, 2.8, 1.9 } }]
    newt_spots(n, m, spot_on)
    add_child(n, blob(float3 { 7.5, 1.4, 8.8 }, plain(col(c, "team")), float3 { -1.5, 15.8, 0.0 }, float3 { 0.0, 0.0, -4.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 10.0, 6.0, 0.5 }, plain(col(c, "team")), float3 { -1.5, 12.4, 8.6 * side }, float3 { 12.0 * side, 0.0, 0.0 }))
    let reed = surf("thatch", float3 { 1.0, 0.95, 0.82 }, 7.0)
    add_child(n, rod(float3 { -7.6, 16.8, -5.5 }, float3 { -7.6, 16.8, 5.5 }, 1.9, 1.9, reed))
    add_child(n, rod(float3 { 4.6, 16.2, -4.0 }, float3 { 4.6, 16.2, 4.0 }, 1.2, 1.2, reed))
    harness(n, float3 { 2.5, 10.2, 0.0 }, 6.2, 9.0, float3 { 3.5, 10.5, 9.2 }, float3 { 2.5, 10.5, -9.2 })
    let s = spec_of(n)
    sock(s, "head", float3 { 19.0, 9.8, 0.0 })
    sock(s, "hand_r", float3 { 3.5, 10.5, 9.8 })
    sock(s, "hand_l", float3 { 2.5, 10.5, -9.8 })
    sock(s, "torso", float3 { 0.0, 10.2, 0.0 })
    sock(s, "back", float3 { -9.0, 15.5, 0.0 })
    sock(s, "seat", float3 { -1.0, NEWT_SEAT, 0.0 })
    sock(s, "wings", float3 { 6.0, 15.5, 0.0 })
    s.anchors = [anchor(float3 { 10.0, 7.6, 6.4 }, 0.0, 1, [0.0]), anchor(float3 { -10.0, 7.6, 6.4 }, MPI, 1, [0.0]),
                 anchor(float3 { 11.0, 7.6, -6.4 }, MPI, -1, [0.0]), anchor(float3 { -9.0, 7.6, -6.4 }, 0.0, -1, [0.0])]
    spec_num(s, "torso_scale", float3 { 0.8, 0.6, 0.0 })
    return spec_str(s, "carry", "harness")

def newt_head(c:Colours) -> Spec:
    let n = mnode()
    let m = newt_mats(c)
    add_child(n, blob(float3 { 8.0, 3.6, 6.4 }, m.skin, float3 { 5.0, 0.6, 0.0 }))
    add_child(n, blob(float3 { 6.6, 1.8, 5.6 }, m.belly, float3 { 4.6, -1.6, 0.0 }))
    add_child(n, rod(float3 { 11.8, -0.5, -4.4 }, float3 { 13.0, -0.4, 0.0 }, 0.32, 0.32, plain(INK)))
    add_child(n, rod(float3 { 13.0, -0.4, 0.0 }, float3 { 11.8, -0.5, 4.4 }, 0.32, 0.32, plain(INK)))
    add_child(n, rod(float3 { 11.8, -0.5, 4.4 }, float3 { 4.0, -0.2, 6.2 }, 0.3, 0.3, plain(INK)))
    add_child(n, rod(float3 { 11.8, -0.5, -4.4 }, float3 { 4.0, -0.2, -6.2 }, 0.3, 0.3, plain(INK)))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.9, 1.7, 1.6 }, m.skin, float3 { 7.6, 3.0, 3.6 * side }))
        add_child(n, blob(float3 { 1.1, 1.1, 0.9 }, plain(html("#c8a030")), float3 { 8.4, 3.4, 4.3 * side }))
        add_child(n, blob(float3 { 0.45, 0.8, 0.4 }, plain(html("#100c08")), float3 { 9.0, 3.5, 4.8 * side }))
        add_child(n, blob(float3 { 0.4, 0.3, 0.3 }, plain(INK), float3 { 12.6, 1.2, 1.4 * side }))
    newt_spots(n, m, [NewtLobe { float3 { 5.0, 0.6, 0.0 }, float3 { 8.0, 3.6, 6.4 } }], 0.7)
    let crest = m.crest
    if crest:
        add_child(n, cone(0.1, 1.0, 2.4, crest, float3 { 1.0, 4.4, 0.0 }, float3 { 0.0, 0.0, 18.0 }, 6))
    add_child(n, ring(5.2, 5.9, plain(col(c, "team")), float3 { 3.6, 0.8, 0.0 }, float3 { 0.0, 0.0, 90.0 }, float3 { 1.0, 0.62, 1.15 }))
    add_child(n, ring(3.0, 3.5, surf("leather", float3_1, 3.0), float3 { 9.8, 0.2, 0.0 }, float3 { 0.0, 0.0, 90.0 }, float3 { 1.0, 0.75, 1.4 }))
    return sock(spec_of(n), "top", float3 { 3.0, 3.6, 0.0 })

def newt_leg(c:Colours) -> Spec:
    let n = mnode()
    let m = newt_mats(c)
    let elbow, wrist = stepped(float3 { 1.8, 1.4, 6.0 }, float3 { 3.4, -5.6, 8.0 }, if hold == "low": "" else: hold, 7.0)   // (D-179: baked per walk step)
    add_child(n, rod(float3_0, elbow, 3.0, 2.4, m.skin))
    add_child(n, rod(elbow, wrist, 2.3, 1.7, m.skin))
    for(4) t:
        let toe = wrist + float3 { 3.2, -1.2, (float(t) - 1.5) * 1.5 }
        add_child(n, rod(wrist + float3 { 0.0, -0.6, 0.0 }, toe, 0.75, 0.55, m.skin))
        add_child(n, blob(float3_1 * 0.6, m.belly, toe))
    return spec_of(n)

// ------------------------------------------------------------------ this file's parts by id
def build_units3(base:string, c:Colours) -> Spec?:
    switch base:
        case "body.cat": return body_cat(c)
        case "head.cat": return head_cat(c)
        case "leg.cat": return leg_cat(c)
        case "leg.cat_hind": return leg_cat_hind(c)
        case "body.hummingbird": return body_hummingbird(c)
        case "head.hummingbird": return head_hummingbird(c)
        case "wings.hummingbird": return wings_hummingbird(c)
        case "body.deer": return body_deer(c)
        case "head.deer": return head_deer(c)
        case "leg.deer": return leg_deer(c)
        case "body.boar": return body_boar(c)
        case "head.boar": return head_boar(c)
        case "leg.boar": return leg_boar(c)
        case "body.sheep": return body_sheep(c)
        case "head.sheep": return head_sheep(c)
        case "leg.sheep": return leg_sheep(c)
        case "body.beetle_rear": return body_beetle_rear(c)
        case "body.beetle": return body_beetle(c)
        case "head.beetle": return head_beetle(c)
        case "leg.insect": return leg_insect(c)
        case "body.newt": return body_newt(c)
        case "head.newt": return head_newt(c)
        case "leg.newt": return leg_newt(c)
        default: return nil
