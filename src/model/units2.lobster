// ------------------------------------------------------------------ unit parts II (unit_models.gd 1037-1557: pony, horse, capybara)
// Each builder is unit_models.gd's of the same name (`_body_pony` -> body_pony), line for line; its
// comments are there. pony_look and capybara_look pick the look, as the GDScript's static vars do.

let PONY_LIFT = 3.0

def pony_barrel(n:MNode, c:Colours):
    let hide = surf("hide", col(c, "skin"), 6.0)
    let mane = surf("mane", darkened(col(c, "skin2"), 0.35), 3.0)
    add_child(n, blob(float3 { 10.5, 6.6, 6.0 }, hide, float3 { 0.0, 19.0, 0.0 }))
    add_child(n, blob(float3 { 5.6, 6.6, 5.6 }, hide, float3 { 8.0, 19.6, 0.0 }))
    add_child(n, blob(float3 { 6.4, 7.0, 6.0 }, hide, float3 { -8.5, 20.2, 0.0 }))
    let tail = [float3 { -14.0, 23.0, 0.0 }, float3 { -17.0, 19.5, 0.5 }, float3 { -18.6, 14.0, 1.0 }, float3 { -18.2, 9.0, 1.2 }]
    let r = [2.2, 2.1, 1.7, 1.0]
    for(tail.length - 1) j:
        let k = j + 1
        add_child(n, rod(tail[k - 1], tail[k], r[k - 1], r[k], mane))

def pony_anchors() -> [Anchor]:
    let y = 14.0 + PONY_LIFT
    return [anchor(float3 { 8.5, y, 3.4 }, 0.0, 1, [0.0, 0.0]), anchor(float3 { -9.5, y, 3.4 }, MPI, 1, [0.0, 1.0]),
        anchor(float3 { 7.0, y, -3.4 }, MPI, -1, [0.0, 0.0]), anchor(float3 { -10.0, y, -3.4 }, 0.0, -1, [0.0, 1.0])]   // [flip, hind]

let PONY_LOOKS = ["classic", "h1", "h2"]
let pony_look = "h2"

def body_pony(c:Colours) -> Spec: return if pony_look == "classic": body_pony_classic(c) else: horse_body(c, "head.pony")

def head_pony(c:Colours) -> Spec:
    switch pony_look:
        case "classic": return head_pony_classic(c)
        case "h1": return head_pony_h1(c)
        default: return head_pony_h2(c)

// The sockets moved up by the lift (unit_models.gd _lifted).
def lifted(s:Spec) -> Spec:
    for(s.sockets.get_keys()) k: s.sockets.set(k, s.sockets.get(k, float3_0) + float3 { 0.0, PONY_LIFT, 0.0 })
    return s

def body_pony_classic(c:Colours) -> Spec:
    let n = mnode()
    let lift = mnode()
    lift.pos = float3 { 0.0, PONY_LIFT, 0.0 }
    add_child(n, lift)
    pony_barrel(lift, c)
    let hide = surf("hide", col(c, "skin"), 6.0)
    add_child(lift, rod(float3 { 8.0, 21.5, 0.0 }, float3 { 14.4, 31.5, 0.0 }, 5.4, 4.0, hide))
    add_child(lift, rod(float3 { 6.4, 24.0, 0.0 }, float3 { 12.4, 33.4, 0.0 }, 2.1, 1.7, surf("mane", darkened(col(c, "skin2"), 0.35), 3.0)))
    harness(lift, float3 { 4.0, 19.0, 0.0 }, 7.0, 6.3, float3 { 3.0, 18.0, 6.4 }, float3 { 3.0, 18.0, -6.4 })
    let s = spec_of(n)
    sock(s, "head", float3 { 15.0, 32.5, 0.0 })
    sock(s, "hand_r", float3 { 3.0, 18.0, 6.9 })
    sock(s, "hand_l", float3 { 3.0, 18.0, -6.9 })
    sock(s, "torso", float3 { 0.0, 19.0, 0.0 })
    sock(s, "back", float3 { -8.0, 24.0, 0.0 })
    sock(s, "seat", float3 { -1.0, 25.8, 0.0 })
    sock(s, "wings", float3 { 7.5, 25.5, 0.0 })
    lifted(s)
    s.anchors = pony_anchors()
    spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })
    return spec_str(s, "carry", "harness")

def body_pony_fused(c:Colours) -> Spec:
    let n = mnode()
    let lift = mnode()
    lift.pos = float3 { 0.0, PONY_LIFT, 0.0 }
    add_child(n, lift)
    pony_barrel(lift, c)
    let hide = surf("hide", col(c, "skin"), 6.0)
    add_child(lift, blob(float3 { 5.4, 7.4, 5.4 }, hide, float3 { 9.0, 24.0, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    add_child(lift, blob(float3 { 4.4, 3.0, 4.6 }, hide, float3 { 10.5, 28.6, 0.0 }))
    let s = spec_of(n)
    sock(s, "head", float3 { 14.6, 31.5, 0.0 })
    sock(s, "hand_r", float3 { 10.0, 18.0, 4.0 })
    sock(s, "hand_l", float3 { 8.0, 18.0, -4.0 })
    sock(s, "torso", float3 { 0.0, 19.0, 0.0 })
    sock(s, "back", float3 { -8.0, 24.0, 0.0 })
    sock(s, "seat", float3 { 10.0, 16.5, 0.0 })
    lifted(s)
    s.anchors = pony_anchors()
    return spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })

def head_pony_classic(c:Colours) -> Spec:
    let root = mnode()
    let n = mnode()
    n.scl = float3_1 * 1.25
    add_child(root, n)
    let hide = surf("hide", col(c, "skin"), 5.0)
    let a = float3 { 0.5, 0.5, 0.0 }
    let b = float3 { 6.6, -4.0, 0.0 }
    add_child(n, rod(a, b, 3.3, 2.6, hide))
    add_child(n, blob(float3 { 3.6, 3.4, 2.8 }, hide, float3 { 1.6, -0.6, 0.0 }))
    add_child(n, blob(float3 { 2.6, 2.3, 2.2 }, surf("hide", darkened(col(c, "skin"), 0.15), 4.0), float3 { 6.8, -4.1, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.5, 0.45, 0.4 }, plain(html("#1a1210")), float3 { 8.6, -3.8, 1.1 * side }))
        add_child(n, decal("rat_eye", 1.7, 1.7, float3 { 2.3, 0.9, 2.45 * side }, float3 { 0.3, 0.3, side }, false))
        add_child(n, cone(0.0, 0.85, 2.8, hide, float3 { -0.2, 2.8, 1.2 * side }, float3 { -12.0 * side, 0.0, 8.0 }))
    add_child(n, blob(float3 { 1.3, 1.7, 1.4 }, surf("mane", col(c, "skin2"), 3.0), float3 { 1.4, 1.8, 0.0 }))
    let ang = atan2(float2 { b.x - a.x, b.y - a.y }) - 90.0
    add_child(n, ring(2.5, 3.0, surf("leather", float3_1, 3.0), float3 { 5.4, -3.2, 0.0 }, float3 { 0.0, 0.0, ang }))
    add_child(n, ring(2.5, 3.0, plain(col(c, "team")), float3 { 1.4, 0.4, 0.0 }, float3 { 0.0, 0.0, ang }))
    return sock(spec_of(root), "top", float3 { 0.5, 2.6, 0.0 } * 1.25)

let HORSE_TOP = [float3 { 5.6, 25.4, 0.0 }, float3 { 9.8, 33.4, 0.0 }, float3 { 15.0, 35.6, 0.0 }]
let HORSE_THROAT = [float3 { 12.4, 17.0, 0.0 }, float3 { 15.6, 24.0, 0.0 }, float3 { 17.0, 30.6, 0.0 }]
let HORSE_HEAD = float3 { 16.2, 33.0, 0.0 }
let HORSE_TILT = -52.0
let HORSE_HEAD_K = 1.2

def horse_lerp(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t

def bez(p:[float3], t:float) -> float3:
    return horse_lerp(horse_lerp(p[0], p[1], t), horse_lerp(p[1], p[2], t), t)

def horse_body(c:Colours, head_id:string) -> Spec:
    let n = mnode()
    let lift = mnode()
    lift.pos = float3 { 0.0, PONY_LIFT, 0.0 }
    add_child(n, lift)
    pony_barrel(lift, c)
    let hide = surf("hide", col(c, "skin"), 6.0)
    let mane = surf("mane", darkened(col(c, "skin2"), 0.35), 3.0)
    for(9) i:
        let t = float(i) / 8.0
        let top = bez(HORSE_TOP, t)
        let low = bez(HORSE_THROAT, t)
        let across = top - low
        let r = float3 { 2.8, magnitude(across) * 0.5 + 0.2, 4.4 + (2.5 - 4.4) * t }
        add_child(lift, blob(r, hide, (top + low) * 0.5, float3 { 0.0, 0.0, atan2(float2 { across.x, across.y }) - 90.0 }))
    for(12) i:
        let t = 0.04 + float(i) / 11.0 * 0.96
        let a = bez(HORSE_TOP, t)
        let b = bez(HORSE_TOP, min(t + 0.1, 1.0))
        let d = normalize(b - a)
        let up = float3 { -d.y, d.x, 0.0 }
        add_child(lift, blob(float3 { 1.6, 1.3, 1.0 }, mane, a + up * 0.6 + float3 { 0.0, 0.0, 0.4 }, float3 { 0.0, 0.0, atan2(float2 { d.x, d.y }) }))
    harness(lift, float3 { 4.0, 19.0, 0.0 }, 7.0, 6.3, float3 { 3.0, 18.0, 6.4 }, float3 { 3.0, 18.0, -6.4 })
    let s = spec_of(n)
    sock(s, "head", HORSE_HEAD)
    sock(s, "hand_r", float3 { 3.0, 18.0, 6.9 })
    sock(s, "hand_l", float3 { 3.0, 18.0, -6.9 })
    sock(s, "torso", float3 { 0.0, 19.0, 0.0 })
    sock(s, "back", float3 { -8.0, 24.0, 0.0 })
    sock(s, "seat", float3 { -1.0, 25.8, 0.0 })
    sock(s, "wings", float3 { 7.5, 25.5, 0.0 })
    sock(s, "join", HORSE_HEAD)
    lifted(s)
    s.anchors = pony_anchors()
    spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })
    spec_str(s, "carry", "harness")
    spec_str(s, "seam_head", head_id)
    return spec_num(s, "seam_r", 4.5)

def horse_top(x:float) -> float: return 3.0 - 0.17 * (x - 1.0)

def horse_head_top() -> float3: return bxf(axis_angle(float3 { 0.0, 0.0, 1.0 }, HORSE_TILT), float3 { 1.0, 3.2, 0.0 }) * HORSE_HEAD_K

def head_pony_h1(c:Colours) -> Spec:
    let root = mnode()
    let n = mnode()
    n.rot = float3 { 0.0, 0.0, HORSE_TILT }
    n.scl = float3_1 * HORSE_HEAD_K
    add_child(root, n)
    let hide = surf("hide", col(c, "skin"), 5.0)
    let muzzle = surf("hide", darkened(col(c, "skin"), 0.25), 4.0)
    let ink = plain(html("#1a1210"))
    add_child(n, blob(float3 { 2.4, 2.1, 2.2 }, hide, float3 { 1.0, 0.9, 0.0 }))
    add_child(n, blob(float3 { 2.7, 2.4, 2.15 }, hide, float3 { 1.3, -1.0, 0.0 }))
    for([[4.4, 2.2, 1.95, 1.75], [6.6, 2.0, 1.7, 1.5], [8.6, 1.7, 1.5, 1.35]]) f:
        add_child(n, blob(float3 { f[1], f[2], f[3] }, hide, float3 { f[0], horse_top(f[0]) - f[2], 0.0 }))
    add_child(n, blob(float3 { 1.55, 1.55, 1.45 }, muzzle, float3 { 10.0, horse_top(10.0) - 1.5, 0.0 }))
    add_child(n, blob(float3 { 1.2, 0.7, 1.0 }, muzzle, float3 { 9.5, horse_top(9.5) - 3.0, 0.0 }))
    add_child(n, rod(float3 { 1.4, -3.0, 0.0 }, float3 { 8.6, horse_top(8.6) - 3.0, 0.0 }, 1.0, 0.75, hide))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.32, 0.5, 0.28 }, ink, float3 { 11.3, horse_top(11.3) - 1.2, 0.85 * side }))
        let eye = blob(float3 { 0.5, 0.45, 0.4 }, ink, float3 { 3.1, 1.6, 1.95 * side })
        eye.meta = "eye"
        add_child(n, eye)
        let brow = blob(float3 { 0.8, 0.35, 0.6 }, hide, float3 { 3.1, 2.15, 1.85 * side })
        brow.meta = "brow"
        add_child(n, brow)
    add_child(n, rod(float3 { 10.4, horse_top(10.4) - 2.4, 0.0 }, float3 { 11.4, horse_top(11.4) - 2.3, 0.0 }, 0.15, 0.12, ink, false))
    horse_ears(n, c)
    return sock(spec_of(root), "top", horse_head_top())

def horse_ears(n:MNode, c:Colours):
    let hide = surf("hide", col(c, "skin"), 5.0)
    let leather = surf("leather", float3_1, 3.0)
    for([1.0, -1.0]) side:
        add_child(n, cone(0.0, 0.7, 2.5, hide, float3 { 0.0, 3.4, 1.05 * side }, float3 { -10.0 * side, 0.0, -HORSE_TILT - 8.0 }))
        add_child(n, cone(0.0, 0.4, 1.8, plain(darkened(col(c, "skin"), 0.45)), float3 { 0.12, 3.35, 1.15 * side }, float3 { -10.0 * side, 0.0, -HORSE_TILT - 8.0 }))
        add_child(n, rod(float3 { 1.0, 0.6, 2.25 * side }, float3 { 7.4, horse_top(7.4) - 1.8, 1.75 * side }, 0.2, 0.2, leather))
    add_child(n, blob(float3 { 1.5, 0.75, 1.0 }, surf("mane", darkened(col(c, "skin2"), 0.35), 3.0), float3 { 1.8, 3.1, 0.0 }, float3 { 0.0, 0.0, -15.0 }))
    add_child(n, ring(1.9, 2.3, leather, float3 { 7.6, horse_top(7.6) - 1.65, 0.0 }, float3 { 0.0, 0.0, 90.0 }, float3 { 1.0, 1.0, 0.92 }))
    add_child(n, ring(2.2, 2.6, plain(col(c, "team")), float3 { 0.6, 1.0, 0.0 }, float3 { 0.0, 0.0, 80.0 }, float3 { 1.0, 1.05, 1.02 }))

def head_pony_h2(c:Colours) -> Spec:
    let root = mnode()
    let n = mnode()
    n.rot = float3 { 0.0, 0.0, HORSE_TILT }
    n.scl = float3_1 * HORSE_HEAD_K
    add_child(root, n)
    let ink = plain(html("#1a1210"))
    add_child(n, glb("head_horse", mats_of([surf("hide", col(c, "skin"), 5.0), surf("hide", darkened(col(c, "skin"), 0.25), 4.0), ink, ink], ["hide", "muzzle", "nostril", "eye"])))
    horse_ears(n, c)
    return sock(spec_of(root), "top", horse_head_top())

def body_pony_h1(c:Colours) -> Spec: return horse_body(c, "head.pony_h1")
def body_pony_h2(c:Colours) -> Spec: return horse_body(c, "head.pony_h2")

let HOOF_KNEE = float2 { 0.0, -6.0 }
let HOOF_FETLOCK = float2 { 0.3, -13.8 }
let HOOF_PASTERN = float2 { 0.8, -14.8 }
let HOOF_HOOF = float2 { 1.0, -15.4 }
let HOOF_STRIDE = 10.0
let HOOF_STANCE = 0.6
let HOOF_LIFT = 3.0

def leg_hoof(c:Colours) -> Spec: return hoof_leg(c, false)
def leg_hoof_hind(c:Colours) -> Spec: return hoof_leg(c, true)

// A horse's leg in the pose `hold` names ("" standing, "w<i>_<n>" a walk step; D-179): the thigh up inside the barrel,
// the upper leg to the knee (or hock), the cannon bone to the fetlock, the pastern and hoof; walking, the knee bends by
// two-bone IK, forward on a foreleg (the hoof curling back as it lifts), back on a hind leg.
def hoof_leg(c:Colours, hind:bool) -> Spec:
    let jk, jf, curl = hoof_joints(hind, if hold == "low": "" else: hold)
    let n = mnode()
    let hide = surf("hide", col(c, "skin"), 5.0)
    let knee = v3of(jk)
    let fet = v3of(jf)
    let past = fet + v3of(rot2d(HOOF_PASTERN - HOOF_FETLOCK, curl))
    let hoof = fet + v3of(rot2d(HOOF_HOOF - HOOF_FETLOCK, curl))
    add_child(n, blob(float3 { 3.0, 5.8, 2.6 }, hide, float3 { 0.0, -1.6, 0.0 }))
    add_child(n, rod(float3 { 0.0, -3.0, 0.0 }, knee, 1.9, 1.35, hide))
    add_child(n, blob(float3 { 1.4, 1.3, 1.3 }, hide, knee))
    add_child(n, rod(knee, fet, 1.3, 0.95, hide))
    add_child(n, blob(float3 { 1.3, 1.2, 1.2 }, hide, fet))
    add_child(n, rod(fet, past, 1.0, 1.0, hide))
    let h = add_child(n, cone(1.1, 1.6, 1.4, plain(html("#2a2420")), hoof))
    h.rot = float3 { h.rot.x, h.rot.y, curl }
    return spec_of(n)


// Where a horse leg's knee and fetlock are in a walk step (2D, the hip at the origin), and how far the pastern and
// hoof curl back from the fetlock (degrees). `knee`: where the knee (or hock) is standing (a sculpted leg may set its own).
def hoof_joints(hind:bool, pose:string, knee:float2 = HOOF_KNEE) -> float2, float2, float:
    let upper = magnitude(knee)
    let lower = magnitude(HOOF_FETLOCK - knee)
    let reach = 0.999 * (upper + lower)
    let p = walk_step(pose)
    if p < 0.0: return knee, HOOF_FETLOCK, 0.0   // standing: as modelled
    var x = HOOF_FETLOCK.x
    var lift = 0.0
    var curl = 0.0
    if p < HOOF_STANCE:
        x += HOOF_STRIDE * (0.5 - p / HOOF_STANCE)
    else:
        let q = (p - HOOF_STANCE) / (1.0 - HOOF_STANCE)
        x += HOOF_STRIDE * (smoothstep(0.0, 1.0, q) - 0.5)
        lift = HOOF_LIFT * sin(q * 180.0)
        curl = (if not hind: 0.9 else: 0.5) * RAD_DEG * sin(q * 180.0)   // (the hoof flicks back under it, more so in front)
    let fet = float2 { x, max(HOOF_FETLOCK.y, -sqrt(max(reach * reach - x * x, 1.0))) + lift }
    return ik2(fet, upper, lower, not hind), fet, curl

// The centaur's horse half sculpted (round BA1; tools/blender/centaur.py, body_centaur_<look>.glb): one surface from
// croup to breast, the man's waist rising out of the withers; its sockets the fused pony's.
def body_centaur(c:Colours, look:string) -> Spec:
    let n = mnode()
    let lift = mnode()
    lift.pos = float3 { 0.0, PONY_LIFT, 0.0 }
    add_child(n, lift)
    add_child(lift, glb("body_centaur_" + look, horse_mats(c)))
    let s = spec_of(n)
    sock(s, "head", float3 { 14.6, 31.5, 0.0 })
    sock(s, "hand_r", float3 { 10.0, 18.0, 4.0 })
    sock(s, "hand_l", float3 { 8.0, 18.0, -4.0 })
    sock(s, "torso", float3 { 0.0, 19.0, 0.0 })
    sock(s, "back", float3 { -8.0, 24.0, 0.0 })
    sock(s, "seat", float3 { 10.0, 16.5, 0.0 })
    lifted(s)
    s.anchors = pony_anchors()
    return spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })

def horse_mats(c:Colours, mane_dark:float = 0.35) -> dictionary<string, MMat>:
    return mats_of([surf("hide", col(c, "skin"), 6.0), surf("hide", darkened(col(c, "skin"), 0.3), 5.0), surf("mane", darkened(col(c, "skin2"), mane_dark), 3.0),
        plain(html("#2a2420"))], ["hide", "points", "mane", "horn"])

// Round BA2 (tools/blender/centaur.py looks c, d, e): the man standing up out of the breast, over the forelegs; the
// horse half's frame at look c's size, each look scaled by centaur_k.
// round BA2 (c, d, e) and BA3 (f, g; tools/blender/centaur.py: a level back, the man growing out of the chest); h is
// concept C1's option B (docs/concepts/centaur): f shorter behind the shoulder
def centaur_seat(look:string) -> float3: return if look < "f": float3 { 12.5, 10.5, 0.0 } else: float3 { 11.7, 11.2, 0.0 }
let CENTAUR_WAIST = 19.1   // the waist's top over the seat (his hem 15.3 over it, 3.8 under the top)
def centaur_hips(look:string) -> [float3]:
    if look < "f": return [float3 { 10.0, 14.0, 2.9 }, float3 { -11.0, 14.0, 2.9 }, float3 { 8.5, 14.0, -2.9 }, float3 { -11.5, 14.0, -2.9 }]
    if look == "h": return [float3 { 8.5, 11.6, 2.9 }, float3 { -7.0, 11.6, 2.9 }, float3 { 7.0, 11.6, -2.9 }, float3 { -7.4, 11.6, -2.9 }]
    return [float3 { 8.5, 14.0, 2.9 }, float3 { -9.0, 14.0, 2.9 }, float3 { 7.0, 14.0, -2.9 }, float3 { -9.5, 14.0, -2.9 }]

def centaur_k(look:string) -> float: return if look == "d": 1.2 elif look == "e": 1.1 elif look == "g": 1.15 else: 1.0
def centaur_legk(look:string) -> float: return if look == "h": 0.85 else: 1.0   // h: short legs, its hips 2.4 lower
def centaur_knee(look:string) -> float2: return if look == "h": float2 { 0.0, -8.4 } else: HOOF_KNEE   // h: a long forearm, a short cannon

def body_centaur2(c:Colours, look:string) -> Spec:
    let k = centaur_k(look)
    let n = mnode()
    let lift = mnode()
    lift.pos = float3 { 0.0, PONY_LIFT * k, 0.0 }
    add_child(n, lift)
    add_child(lift, glb("body_centaur_" + look, horse_mats(c, 0.1)))
    let s = spec_of(n)
    let up = float3 { 0.0, PONY_LIFT, 0.0 }
    let seat = centaur_seat(look)
    let moved = seat - centaur_seat("c")
    sock(s, "head", (float3 { 16.0, 31.5, 0.0 } + moved + up) * k)
    sock(s, "hand_r", (float3 { 12.0, 18.0, 3.6 } + moved + up) * k)
    sock(s, "hand_l", (float3 { 10.0, 18.0, -3.6 } + moved + up) * k)
    sock(s, "torso", (float3 { 0.0, 19.0, 0.0 } + up) * k)
    sock(s, "back", (float3 { -8.0, 24.0, 0.0 } + up) * k)
    // the man stays his size: his seat goes up with the waist, less the waist's top to his seat at look c's size
    sock(s, "seat", (seat + up) * k + float3 { 0.0, CENTAUR_WAIST * (k - 1.0), 0.0 })
    s.anchors = map(centaur_hips(look)) h: anchor((h + up) * k, if (h.x > 0.0) == (h.z > 0.0): 0.0 else: MPI, if h.z > 0.0: 1 else: -1, [0.0, if h.x < 0.0: 1.0 else: 0.0])
    spec_num(s, "seam_legs", float3 { (if look == "h": 11.0 else: 7.0) * k, 0.0, 0.0 })   // (h: the upper legs reach high on the flank)
    return spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })

// A pieced leg's pieces turned about their joints: a piece whose name starts with prefixes[i] turns turns[i] degrees
// about pivots[i] and moves on to tos[i] (2D, in the leg's own plane; no prefix starts another).
def turn_pieces(leg:MNode, prefixes:[string], pivots:[float2], tos:[float2], turns:[float]):
    for(leg.kids) piece:
        let name = if piece.kids.length: piece.kids[0].meta else: ""
        for(prefixes) pre, i:
            if starts_with(name, pre):
                let t = xmul(Xform { axis_angle(float3 { 0.0, 0.0, 1.0 }, turns[i]), v3of(tos[i]) }, Xform { BASIS_ID, -v3of(pivots[i]) })
                set_xform(piece, xmul(t, node_xform(piece)))

// The sculpted horse leg (centaur.py leg_horse[_hind]_<look>.glb) in a walk step: the upper leg about the hip, the
// cannon about the knee or hock, the pastern and hoof about the fetlock, by hoof_joints.
def hoof_leg_sculpted(c:Colours, hind:bool, look:string) -> Spec:
    let k = centaur_k(look) * centaur_legk(look)
    let knee = centaur_knee(look)
    let jk0, jf0, curl = hoof_joints(hind, if hold == "low": "" else: hold, knee)
    let jk = jk0 * k
    let jf = jf0 * k
    let leg = glb("leg_horse" + (if hind: "_hind_" else: "_") + look, horse_mats(c, if look < "c": 0.35 else: 0.1))
    turn_pieces(leg, ["upper", "cannon", "hoof"], [float2_0, knee * k, HOOF_FETLOCK * k], [float2_0, jk, jf],
        [atan2(jk) - atan2(knee), atan2(jf - jk) - atan2(HOOF_FETLOCK - knee), curl])
    let n = mnode()
    add_child(n, leg)
    return spec_of(n)

// ------------------------------------------------------------------ capybara

let CAPYBARA_LOOKS = ["box", "soft", "sculpt", "full", "long", "long_tan"]
let capybara_look = "long"
let CAPYBARA_LONG_HEAD = 1.35
let CAPYBARA_NECK_FROM = float3 { 4.0, 14.5, 0.0 }
let CAPYBARA_NECK_END = float3 { -2.0, 1.4, 0.0 }
let CAPYBARA_NECK_R = [3.5, 3.0]
let CAPYBARA_HEAD = 1.25

def body_capybara(c:Colours) -> Spec:
    switch capybara_look:
        case "box": return body_capybara_box(c)
        case "soft": return body_capybara_soft(c)
        case "sculpt": return body_capybara_sculpt(c)
        case "full": return body_capybara_full(c)
        case "long_tan": return body_capybara_long_tan(c)
        default: return body_capybara_long(c)

def head_capybara(c:Colours) -> Spec:
    switch capybara_look:
        case "box": return head_capybara_box(c)
        case "soft": return head_capybara_soft(c)
        case "sculpt": return head_capybara_sculpt(c)
        case "full": return head_capybara_full(c)
        case "long_tan": return head_capybara_long_tan(c)
        default: return head_capybara_long(c)

def leg_capybara(c:Colours) -> Spec:
    switch capybara_look:
        case "box": return leg_capybara_box(c)
        case "soft": return leg_capybara_soft(c)
        case "sculpt": return leg_capybara_sculpt(c)
        case "full": return leg_capybara_full(c)
        case "long_tan": return leg_capybara_long_tan(c)
        default: return leg_capybara_long(c)

def body_capybara_box(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 13.0, 8.0, 8.5 }, fur, float3 { 0.0, 13.0, 0.0 }))
    add_child(n, blob(float3 { 6.0, 4.0, 6.4 }, surf("rat_fur", lightened(col(c, "skin"), 0.12), 4.0), float3 { 3.0, 9.5, 0.0 }))
    add_child(n, blob(float3 { 4.6, 5.0, 4.8 }, fur, float3 { -11.0, 13.5, 0.0 }))
    add_child(n, box(float3 { 9.0, 0.9, 13.0 }, plain(html("#e8e0d0")), float3 { -1.0, 20.9, 0.0 }))
    add_child(n, box(float3 { 9.2, 1.0, 2.4 }, plain(col(c, "team")), float3 { -1.0, 21.0, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 9.0, 4.0, 0.5 }, plain(html("#e8e0d0")), float3 { -1.0, 18.6, 6.6 * side }, float3 { 10.0 * side, 0.0, 0.0 }))
    let s = spec_of(n)
    sock(s, "head", float3 { 12.5, 17.5, 0.0 })
    sock(s, "hand_r", float3 { 4.0, 16.0, 7.6 })
    sock(s, "hand_l", float3 { 3.0, 16.0, -7.6 })
    sock(s, "torso", float3 { 0.0, 14.0, 0.0 })
    sock(s, "back", float3 { -8.0, 20.0, 0.0 })
    sock(s, "seat", float3 { -1.0, 22.5, 0.0 })
    sock(s, "wings", float3 { 6.0, 20.0, 0.0 })
    s.anchors = [anchor(float3 { 8.0, 7.5, 5.0 }, 0.0, 1, [0.0]), anchor(float3 { -8.0, 7.5, 5.2 }, MPI, 1, [0.0]),
        anchor(float3 { 7.0, 7.5, -5.0 }, MPI, -1, [0.0]), anchor(float3 { -9.0, 7.5, -5.2 }, 0.0, -1, [0.0])]
    spec_num(s, "torso_scale", float3 { 1.4, 0.9, 0.0 })
    return spec_str(s, "carry", "harness")

def head_capybara_box(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, box(float3 { 8.5, 6.0, 6.0 }, fur, float3 { 3.5, 0.0, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    add_child(n, box(float3 { 2.0, 3.6, 5.0 }, surf("rat_fur", darkened(col(c, "skin"), 0.4), 4.0), float3 { 7.6, -1.4, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.9, 1.0, 0.7 }, fur, float3 { -0.4, 3.4, 2.5 * side }))
        add_child(n, blob(float3 { 0.5, 0.5, 0.45 }, plain(INK), float3 { 3.4, 1.8, 3.0 * side }))
    return sock(spec_of(n), "top", float3 { 1.0, 3.2, 0.0 })

def leg_capybara_box(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, rod(float3_0, float3 { 0.4, -6.4, 0.0 }, 2.4, 1.9, fur))
    add_child(n, blob(float3 { 2.4, 0.9, 1.8 }, surf("rat_fur", darkened(col(c, "skin"), 0.45), 3.0), float3 { 1.0, -7.0, 0.0 }))
    return spec_of(n)

def capybara_towel(n:MNode, c:Colours, y:float, half:float):
    let towel = plain(html("#e8e0d0"))
    add_child(n, box(float3 { 9.0, 0.9, half * 1.6 }, towel, float3 { -1.0, y, 0.0 }))
    add_child(n, box(float3 { 9.2, 1.0, 2.4 }, plain(col(c, "team")), float3 { -1.0, y + 0.1, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, box(float3 { 9.0, 4.0, 0.5 }, towel, float3 { -1.0, y - 2.4, (half * 0.8 - 0.2) * side }, float3 { 12.0 * side, 0.0, 0.0 }))

def capybara_rig(n:MNode, head:float3, seat_y:float) -> Spec:
    let s = spec_of(n)
    sock(s, "head", head)
    sock(s, "hand_r", float3 { 4.0, 16.0, 7.6 })
    sock(s, "hand_l", float3 { 3.0, 16.0, -7.6 })
    sock(s, "torso", float3 { 0.0, 14.0, 0.0 })
    sock(s, "back", float3 { -8.0, seat_y - 2.5, 0.0 })
    sock(s, "seat", float3 { -1.0, seat_y, 0.0 })
    sock(s, "wings", float3 { 6.0, seat_y - 2.5, 0.0 })
    s.anchors = [anchor(float3 { 8.0, 6.5, 4.6 }, 0.0, 1, [0.0]), anchor(float3 { -8.5, 7.0, 5.0 }, MPI, 1, [0.0]),
        anchor(float3 { 7.0, 6.5, -4.6 }, MPI, -1, [0.0]), anchor(float3 { -9.5, 7.0, -5.0 }, 0.0, -1, [0.0])]
    spec_num(s, "torso_scale", float3 { 1.4, 0.9, 0.0 })
    return spec_str(s, "carry", "harness")

def body_capybara_soft(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 12.5, 7.4, 8.2 }, fur, float3 { 0.0, 11.8, 0.0 }, float3 { 0.0, 0.0, -4.0 }))
    add_child(n, blob(float3 { 6.8, 7.2, 7.8 }, fur, float3 { -7.5, 12.4, 0.0 }))
    add_child(n, blob(float3 { 5.6, 4.8, 5.4 }, fur, float3 { 9.5, 13.0, 0.0 }, float3 { 0.0, 0.0, 28.0 }))
    add_child(n, blob(float3 { 7.0, 3.2, 6.2 }, surf("rat_fur", lightened(col(c, "skin"), 0.08), 4.0), float3 { 1.5, 7.0, 0.0 }))
    capybara_towel(n, c, 19.4, 8.0)
    return capybara_rig(n, float3 { 11.5, 15.4, 0.0 }, 20.8)

def body_capybara_full(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, glb("body_capybara", mats_of([surf("rat_fur", col(c, "skin"), 5.0)], ["fur"])))
    capybara_towel(n, c, 19.8, 8.4)
    return capybara_rig(n, float3 { 12.0, 14.6, 0.0 }, 21.2)

def body_capybara_sculpt(c:Colours) -> Spec: return body_capybara_soft(c)

def head_capybara_soft(c:Colours) -> Spec:
    let root = mnode()
    let n = mnode()
    n.rot = float3 { 0.0, 0.0, -10.0 }
    n.scl = float3_1 * CAPYBARA_HEAD
    add_child(root, n)
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 3.6, 2.5, 2.2 }, fur, float3 { 1.6, 0.5, 0.0 }))
    add_child(n, blob(float3 { 3.2, 2.8, 2.5 }, fur, float3 { 2.8, -1.0, 0.0 }))
    add_child(n, blob(float3 { 3.4, 1.7, 1.9 }, fur, float3 { 5.0, 0.9, 0.0 }))
    add_child(n, blob(float3 { 2.3, 2.8, 1.9 }, fur, float3 { 6.4, -0.5, 0.0 }))
    let dark = surf("rat_fur", darkened(col(c, "skin"), 0.5), 3.0)
    add_child(n, blob(float3 { 0.9, 0.8, 1.4 }, dark, float3 { 8.0, 1.0, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 0.3, 0.2, 0.22 }, plain(INK), float3 { 8.4, 1.6, 0.6 * side }))
        add_child(n, blob(float3 { 0.48, 0.42, 0.3 }, plain(INK), float3 { 2.9, 1.6, 2.05 * side }))
        add_child(n, blob(float3 { 0.55, 0.6, 0.3 }, surf("rat_fur", darkened(col(c, "skin"), 0.3), 3.0), float3 { -0.3, 2.7, 1.5 * side }, float3 { 20.0 * side, 0.0, 0.0 }))
    return sock(spec_of(root), "top", float3 { 1.0, 3.0, 0.0 } * CAPYBARA_HEAD)

def head_capybara_sculpt(c:Colours) -> Spec:
    let root = mnode()
    let n = glb("head_capybara", mats_of([surf("rat_fur", col(c, "skin"), 5.0), surf("rat_fur", darkened(col(c, "skin"), 0.55), 3.0),
        plain(INK), surf("rat_fur", darkened(col(c, "skin"), 0.3), 3.0)], ["fur", "nose", "eye", "ear"]))
    n.rot = float3 { 0.0, 0.0, -10.0 }
    n.scl = float3_1 * CAPYBARA_HEAD
    add_child(root, n)
    return sock(spec_of(root), "top", float3 { 1.0, 3.0, 0.0 } * CAPYBARA_HEAD)

def head_capybara_full(c:Colours) -> Spec: return head_capybara_sculpt(c)

def leg_capybara_soft(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    add_child(n, blob(float3 { 3.2, 3.8, 2.9 }, fur, float3 { 0.0, -0.4, 0.0 }))
    add_child(n, rod(float3 { 0.2, -3.0, 0.0 }, float3 { 0.5, -5.6, 0.0 }, 2.2, 1.9, fur))
    add_child(n, blob(float3 { 2.4, 0.9, 1.9 }, surf("rat_fur", darkened(col(c, "skin"), 0.45), 3.0), float3 { 1.2, -6.0, 0.0 }))
    return spec_of(n)

def leg_capybara_sculpt(c:Colours) -> Spec: return leg_capybara_soft(c)
def leg_capybara_full(c:Colours) -> Spec: return leg_capybara_soft(c)

def capybara_long_mats(c:Colours) -> dictionary<string, MMat>:
    let skin = col(c, "skin")
    let tan = html("#d8b888")
    return mats_of([surf("rat_fur", skin, 5.0), surf("rat_fur", html("#3a2a22"), 3.0), plain(INK), surf("rat_fur", darkened(skin, 0.5), 3.0),
        surf("rat_fur", skin + (tan - skin) * 0.6, 4.0)], ["fur", "nose", "eye", "ear", "face"])

def capybara_long_body(kind:string, c:Colours, head:float3, seat_y:float) -> Spec:
    let n = mnode()
    let mats = capybara_long_mats(c)
    add_child(n, glb("body_capybara_" + kind, mats))
    add_child(n, rod(CAPYBARA_NECK_FROM, head + CAPYBARA_NECK_END, CAPYBARA_NECK_R[0], CAPYBARA_NECK_R[1], surf("rat_fur", col(c, "skin"), 5.0)))
    capybara_towel(n, c, seat_y - 1.4, 8.0)
    let s = capybara_rig(n, head, seat_y)
    spec_str(s, "seam_head", "head.capybara")
    spec_num(s, "seam_r", 4.0)
    return sock(s, "join", head + CAPYBARA_NECK_END)

def capybara_long_head(kind:string, c:Colours, tilt:float) -> Spec:
    let root = mnode()
    let n = glb("head_capybara_" + kind, capybara_long_mats(c))
    n.rot = float3 { 0.0, 0.0, tilt }
    n.scl = float3_1 * CAPYBARA_LONG_HEAD
    add_child(root, n)
    return sock(spec_of(root), "top", float3 { 1.0, 2.6, 0.0 } * CAPYBARA_LONG_HEAD)

def body_capybara_long(c:Colours) -> Spec: return capybara_long_body("long", c, float3 { 11.0, 14.4, 0.0 }, 20.6)
def head_capybara_long(c:Colours) -> Spec: return capybara_long_head("long", c, -3.0)
def body_capybara_long_tan(c:Colours) -> Spec: return capybara_long_body("long_tan", c, float3 { 11.0, 14.2, 0.0 }, 20.8)
def head_capybara_long_tan(c:Colours) -> Spec: return capybara_long_head("long_tan", c, 0.0)

def leg_capybara_long(c:Colours) -> Spec:
    let n = mnode()
    let fur = surf("rat_fur", col(c, "skin"), 5.0)
    let dark = surf("rat_fur", darkened(col(c, "skin"), 0.5), 3.0)
    let knee, ankle = stepped(float3 { 0.2, -3.0, 0.0 }, float3 { 0.5, -5.6, 0.0 }, if hold == "low": "" else: hold, 4.5)   // (D-179: baked per walk step)
    let at = ankle - float3 { 0.5, -5.6, 0.0 }   // the foot goes where the ankle goes
    add_child(n, blob(float3 { 3.2, 3.8, 2.9 }, fur, float3 { 0.0, -0.4, 0.0 }))
    add_child(n, rod(float3 { 0.0, -1.0, 0.0 }, knee, 2.3, 2.1, fur))
    add_child(n, rod(knee, ankle, 2.1, 1.8, fur))
    add_child(n, blob(float3 { 2.6, 0.8, 2.2 }, dark, float3 { 1.3, -6.0, 0.0 } + at))
    for([-1.0, 0.0, 1.0]) k:
        add_child(n, blob(float3 { 0.9, 0.55, 0.5 }, dark, float3 { 3.3, -6.2, 0.9 * k } + at, float3 { 0.0, 20.0 * k, 0.0 }))
    return spec_of(n)

def leg_capybara_long_tan(c:Colours) -> Spec: return leg_capybara_long(c)

// ------------------------------------------------------------------ this file's parts by id
def build_units2(base:string, c:Colours) -> Spec?:
    switch base:
        case "body.pony": return body_pony(c)
        case "head.pony": return head_pony(c)
        case "body.pony_classic": return body_pony_classic(c)
        case "head.pony_classic": return head_pony_classic(c)
        case "body.pony_h1": return body_pony_h1(c)
        case "head.pony_h1": return head_pony_h1(c)
        case "body.pony_h2": return body_pony_h2(c)
        case "head.pony_h2": return head_pony_h2(c)
        case "body.pony_fused": return body_pony_fused(c)
        case "leg.hoof": return leg_hoof(c)
        case "leg.hoof_hind": return leg_hoof_hind(c)
        case "body.pony_fused_a": return body_centaur(c, "a")
        case "body.pony_fused_b": return body_centaur(c, "b")
        case "leg.hoof_a": return hoof_leg_sculpted(c, false, "a")
        case "leg.hoof_hind_a": return hoof_leg_sculpted(c, true, "a")
        case "leg.hoof_b": return hoof_leg_sculpted(c, false, "b")
        case "leg.hoof_hind_b": return hoof_leg_sculpted(c, true, "b")
        case "body.pony_fused_c": return body_centaur2(c, "c")
        case "body.pony_fused_d": return body_centaur2(c, "d")
        case "body.pony_fused_e": return body_centaur2(c, "e")
        case "leg.hoof_c": return hoof_leg_sculpted(c, false, "c")
        case "leg.hoof_hind_c": return hoof_leg_sculpted(c, true, "c")
        case "leg.hoof_d": return hoof_leg_sculpted(c, false, "d")
        case "leg.hoof_hind_d": return hoof_leg_sculpted(c, true, "d")
        case "leg.hoof_e": return hoof_leg_sculpted(c, false, "e")
        case "leg.hoof_hind_e": return hoof_leg_sculpted(c, true, "e")
        case "body.pony_fused_f": return body_centaur2(c, "f")
        case "body.pony_fused_g": return body_centaur2(c, "g")
        case "leg.hoof_f": return hoof_leg_sculpted(c, false, "f")
        case "leg.hoof_hind_f": return hoof_leg_sculpted(c, true, "f")
        case "leg.hoof_g": return hoof_leg_sculpted(c, false, "g")
        case "leg.hoof_hind_g": return hoof_leg_sculpted(c, true, "g")
        case "body.pony_fused_h": return body_centaur2(c, "h")
        case "leg.hoof_h": return hoof_leg_sculpted(c, false, "h")
        case "leg.hoof_hind_h": return hoof_leg_sculpted(c, true, "h")
        case "body.capybara": return body_capybara(c)
        case "head.capybara": return head_capybara(c)
        case "leg.capybara": return leg_capybara(c)
        case "body.capybara_box": return body_capybara_box(c)
        case "head.capybara_box": return head_capybara_box(c)
        case "leg.capybara_box": return leg_capybara_box(c)
        case "body.capybara_soft": return body_capybara_soft(c)
        case "head.capybara_soft": return head_capybara_soft(c)
        case "leg.capybara_soft": return leg_capybara_soft(c)
        case "body.capybara_sculpt": return body_capybara_sculpt(c)
        case "head.capybara_sculpt": return head_capybara_sculpt(c)
        case "leg.capybara_sculpt": return leg_capybara_sculpt(c)
        case "body.capybara_full": return body_capybara_full(c)
        case "head.capybara_full": return head_capybara_full(c)
        case "leg.capybara_full": return leg_capybara_full(c)
        case "body.capybara_long": return body_capybara_long(c)
        case "head.capybara_long": return head_capybara_long(c)
        case "leg.capybara_long": return leg_capybara_long(c)
        case "body.capybara_long_tan": return body_capybara_long_tan(c)
        case "head.capybara_long_tan": return head_capybara_long_tan(c)
        case "leg.capybara_long_tan": return leg_capybara_long_tan(c)
        default: return nil
