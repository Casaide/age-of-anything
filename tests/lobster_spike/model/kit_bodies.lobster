// ------------------------------------------------------------------ the creature kit (scenes/art_pixel/creature_kit.gd)
// Bodies, heads and legs built from the parametric skeletons in data/creature_kit.json (the bears: "body.bear",
// "head.bear", "leg.bear" and their colour and kind variants, the bear mount; the comparison cats), each
// function creature_kit.gd's of the same name without the underscore, line for line; its comments are
// there. It uses the cat's tack and tail from model/units3.lobster (cat_tail, cat_saddle, cat_bridle).
// Kits are read once from the data (bases and head_of resolved as CreatureKit._resolved does). Staging
// data/later files (CreatureKit.stage) is for tests and sheets only: not here.

let KIT_PATH = "../../data/creature_kit.json"   // (the model check runs from tests/lobster_spike)
let KIT_INF = 1000000000.0

let kit_kits = dictionary<string, JV>(17)       // kit name -> its parameters (bases merged in)
let kit_part = dictionary<string, string>(31)   // part id -> its kit
let kit_role = dictionary<string, string>(31)   // part id -> "body", "head", "leg", "hind"
var kit_loaded = false

// ---- data

def kit_merge(a:JV, b:JV) -> JV:
    let out = deep_copy(a)
    for(b.keys) key, i:
        let v = b.a[i]
        let o = get(out, key)
        if o and o.kind == J_OBJ and v.kind == J_OBJ: set(out, key, kit_merge(o, v))
        else: set(out, key, deep_copy(v))
    return out

def kit_resolved(name:string, all:JV) -> JV:
    let k = at(all, name)
    var out = deep_copy(k)
    if has(k, "base"):
        out = kit_merge(kit_resolved(as_str(at(k, "base")), all), k)
        erase(out, "base")
    if has(k, "head_of"):
        set(out, "head", kit_merge(at(kit_resolved(as_str(at(k, "head_of")), all), "head"), gobj(k, "head")))
        erase(out, "head_of")
    return out

def kit_register(name:string, k:JV):
    kit_kits.set(name, k)
    let p = at(k, "parts")
    for(["body", "head", "leg", "hind"]) role:
        if has(p, role) and (role != "head" or has(k, "head")):
            let id = as_str(at(p, role))
            kit_part.set(id, name)
            kit_role.set(id, role)

def kit_load():
    if kit_loaded: return
    kit_loaded = true
    let all = at(load_json(KIT_PATH), "kits")
    for(all.keys) name: kit_register(name, kit_resolved(name, all))

// A value that's there and not null (GDScript's `d.get(k) != null`).
def kget(o:JV, k:string) -> JV?:
    let v = get(o, k)
    return if v and v.kind != J_NULL: v else: nil
def kf(o:JV, k:string, fallback:float) -> float:
    let v = kget(o, k)
    return if v: as_float(v) else: fallback
def kobj(o:JV, k:string) -> JV:   // k.get(name, {})
    let v = kget(o, k)
    return v or jobj()
def kv3(a:JV) -> float3: return float3 { as_float(a.a[0]), as_float(a.a[1]), if a.a.length > 2: as_float(a.a[2]) else: 0.0 }
def kp2(a:JV) -> float2: return float2 { as_float(a.a[0]), as_float(a.a[1]) }
def kv3_or(o:JV, k:string, fallback:float3) -> float3:
    let v = kget(o, k)
    return if v: kv3(v) else: fallback
def kn(a:JV, i:int) -> float: return as_float(a.a[i])
def kpair(a:JV, i:int, j:int) -> float: return as_float(a.a[i].a[j])

def kit_quad(k:JV) -> bool: return gstr(k, "posture", "") == "quadruped"

def kit_idle(k:JV) -> [string]:
    if kit_quad(k): return gstrs(kobj(k, "sit"), "order")
    return kobj(k, "idle").keys

def kit_sit_pose(k:JV, pose:string) -> JV: return kobj(kobj(kobj(k, "sit"), "poses"), pose)

// ---- skeleton

class KitSk:
    sockets:dictionary<string, float3>
    names:[string]                   // the sockets in order
    anchors:[Anchor]
    t:Xform

def kit_has_s(xs:[string], x:string) -> bool:
    for(xs) y:
        if y == x: return true
    return false

def ksock(s:KitSk, name:string, p:float3):
    if not kit_has_s(s.names, name): s.names.push(name)
    s.sockets.set(name, p)
def ksock_at(s:KitSk, name:string) -> float3: return s.sockets.get(name, float3_0)

def kit_skeleton(k:JV, pose:string) -> KitSk: return if kit_quad(k): quad_skeleton(k, pose) else: biped_skeleton(k, pose)

def quad_skeleton(k:JV, pose:string) -> KitSk:
    let t = sit_xf(k, pose)
    let sh = kv3(at(k, "shoulder"))
    let hip = kv3(at(k, "hip"))
    let s = kobj(k, "sockets")
    let seat_x = kf(s, "seat_x", u3_lerpf(hip.x, sh.x, 0.4))
    let seat = kv3_or(s, "seat", float3 { seat_x, top_at(k, seat_x) + kf(kobj(k, "tack"), "saddle", 1.0), 0.0 })
    let mid_y = (top_at(k, seat.x) + bottom_at(k, seat.x)) * 0.5
    let half = half_width_at(k, seat.x) + 0.4
    let hrj = kget(s, "hand")
    let hr = if hrj: map(hrj.a) v: as_float(v) else: [3.0, mid_y - seat.y]
    let hz = if hr.length > 2: hr[2] else: half
    let sk = KitSk { dictionary<string, float3>(11), [], [], t }
    ksock(sk, "head", kv3(at(at(k, "neck"), "to")) + head_lift(k, pose))
    ksock(sk, "seat", seat)
    ksock(sk, "girth", kv3_or(s, "girth", float3 { seat.x, bottom_at(k, seat.x) + 1.0, 0.0 }))
    ksock(sk, "hand_r", seat + float3 { hr[0], hr[1], hz })
    ksock(sk, "hand_l", seat + float3 { hr[0] - 1.0, hr[1], -hz })
    ksock(sk, "torso", kv3_or(s, "torso", float3 { 0.0, seat.y - 5.0, 0.0 }))
    ksock(sk, "back", kv3_or(s, "back", seat + float3 { -7.0, -1.5, 0.0 }))
    ksock(sk, "wings", kv3_or(s, "wings", seat + float3 { 7.0, -1.5, 0.0 }))
    for(sk.names) n: sk.sockets.set(n, xf(t, ksock_at(sk, n)))
    let z = float3 { 0.0, 0.0, kf(k, "leg_z", 0.0) }
    let phj = kget(kobj(k, "walk"), "phases")
    let ph = if phj: map(phj.a) v: as_float(v) else: [1.5, 0.0, 0.5, 1.0]
    sk.anchors = [anchor(xf(t, sh + z), MPI * ph[0], 1, [0.0, 0.0]), anchor(xf(t, hip + z), MPI * ph[1], 1, [0.0, 1.0]),
                  anchor(xf(t, sh - z), MPI * ph[2], -1, [0.0, 0.0]), anchor(xf(t, hip - z), MPI * ph[3], -1, [0.0, 1.0])]
    return sk

def head_lift(k:JV, pose:string) -> float3:
    let sp = kit_sit_pose(k, pose)
    return kv3_or(sp, "head", float3_0)

def sit_xf(k:JV, pose:string) -> Xform:
    let sp = kit_sit_pose(k, pose)
    if not sp.keys.length: return XF_ID
    let hip = kv3(at(k, "hip"))
    let p = float3 { hip.x, kf(sp, "hip_y", 0.0), 0.0 }
    return xmul(Xform { axis_angle(U3_ZUP, kf(sp, "pitch", 0.0)), p }, Xform { BASIS_ID, -hip })

def biped_skeleton(k:JV, pose:string) -> KitSk:
    let hip = kv3(at(k, "hip"))
    let s = kobj(k, "sockets")
    let chest = at(at(k, "body"), "chest")
    let fit = torso_fit(k)
    let arm = at(k, "arm")
    let sk = KitSk { dictionary<string, float3>(11), [], [], XF_ID }
    ksock(sk, "head", kit_lean(k, kv3(at(at(k, "neck"), "to"))))
    ksock(sk, "hand_r", kv3(at(arm, "hand")))
    ksock(sk, "hand_l", kv3(at(arm, "hand_l")))
    ksock(sk, "torso", kit_lean(k, kv3(at(chest, "at"))) - bxf(axis_angle(U3_ZUP, -kf(k, "lean", 0.0)), float3 { 1.5 * fit.x, 0.5 * fit.y, 0.0 }))
    let bj = kget(s, "back")
    ksock(sk, "back", if bj: kit_lean(k, kv3(bj)) else: kit_lean(k, kv3(at(chest, "at")) + float3 { -kn(at(chest, "r"), 0) - 0.2, 1.5, 0.0 }))
    ksock(sk, "sit", hip + float3 { 0.0, -1.0, 0.0 })
    for(s.keys) n, i:
        if n != "back": ksock(sk, n, kit_lean(k, kv3(s.a[i])))
    let leg_hip = hip + float3 { kf(at(k, "leg"), "hip_dx", 0.0), 0.0, 0.0 }
    let z = float3 { 0.0, 0.0, kf(k, "leg_z", 0.0) }
    sk.anchors = [anchor(leg_hip - z, 0.0, -1, [0.0, 0.0]), anchor(leg_hip + z, MPI, 1, [0.0, 0.0])]
    return sk

def kit_lean(k:JV, p:float3) -> float3:
    let hip = kv3(at(k, "hip"))
    return hip + bxf(axis_angle(U3_ZUP, -kf(k, "lean", 0.0)), p - hip)

def torso_fit(k:JV) -> float3:
    let r = at(at(at(k, "body"), "chest"), "r")
    let pad = kf(k, "armour_pad", 0.6)
    return float3 { (kn(r, 0) + pad) / 8.8, (kn(r, 1) + pad) / 8.2, (kn(r, 2) + pad) / 10.4 }

class KitVol:
    at:float3
    r:float3
    mat:string
    rot:float
    name:string

def kit_volumes(k:JV) -> [KitVol]:
    let out = []::KitVol
    let body = at(k, "body")
    for(["rump", "waist", "belly", "chest", "pelvis", "hump"]) name:
        let v = kget(body, name)
        if v: out.push(KitVol { kv3(at(v, "at")), kv3(at(v, "r")), gstr(v, "mat", "fur"), kf(v, "rot", 0.0), name })
    return out

def top_at(k:JV, x:float) -> float:
    var y = -KIT_INF
    for(kit_volumes(k)) v:
        let u = (x - v.at.x) / v.r.x
        if abs(u) < 1.0: y = max(y, v.at.y + v.r.y * sqrt(1.0 - u * u))
    return y

def bottom_at(k:JV, x:float) -> float:
    var y = KIT_INF
    for(kit_volumes(k)) v:
        let u = (x - v.at.x) / v.r.x
        if abs(u) < 1.0: y = min(y, v.at.y - v.r.y * sqrt(1.0 - u * u))
    return y

def half_width_at(k:JV, x:float) -> float:
    var w = 0.0
    for(kit_volumes(k)) v:
        let u = (x - v.at.x) / v.r.x
        if abs(u) < 1.0: w = max(w, v.r.z * sqrt(1.0 - u * u))
    return w

// ---- legs

def kit_is_step(pose:string) -> bool: return starts_with(pose, "w") and find_string(pose, "_") >= 0

def quad_joints(k:JV, hind:bool, pose:string) -> CatJ:
    let l = at(k, if hind: "hind" else: "fore")
    let b = at(l, "bones")
    let w = at(k, "walk")
    let pad = kf(k, "pad", 0.75)
    var h = if hind: kn(at(k, "hip"), 1) else: kn(at(k, "shoulder"), 1)
    let x0 = kf(l, "x", 0.0)
    var x = x0
    var tilt = kf(l, "tilt", 0.0)
    var lift = 0.0
    var down = 0.0
    let sit = kit_sit_pose(k, pose)
    if kit_is_step(pose):
        let p = u3_walk_frac(pose)
        let stance = kf(w, "stance", 0.0)
        let wt = at(l, "walk_tilt")
        if p < stance:
            let s = p / stance
            x = x0 + kf(w, "stride", 0.0) * (0.5 - s)
            tilt = u3_lerpf(kn(wt, 0), kn(wt, 1), s)
            down = sin(s * 180.0)
        else:
            let q = (p - stance) / (1.0 - stance)
            x = x0 + kf(w, "stride", 0.0) * (u3_smooth(0.0, 1.0, q) - 0.5)
            lift = kf(w, "lift", 0.0) * sin(q * 180.0)
            tilt = u3_lerpf(kn(wt, 1), kn(wt, 0), q) + kf(l, "swing_tilt", 0.0) * sin(q * 180.0)
    elif sit.keys.length:
        let t = sit_xf(k, pose)
        h = if hind: kf(sit, "hip_y", 0.0) else: xf(t, kv3(at(k, "shoulder"))).y
        if hind:
            let f = kget(sit, "fold")
            if f:
                let j = CatJ {}
                j.hock = float2 { kn(at(f, "hock"), 0), -h + kn(at(f, "hock"), 1) }
                j.paw = float2 { kf(f, "paw", 0.0), -h + pad }
                j.knee = ik(float2_0, j.hock, kn(b, 0), kn(b, 1), 1.0)
                j.toe = float2 { 1.0, 0.0 }
                j.out = kf(f, "out", 0.0)
                return j
            x = kn(at(sit, "hind"), 0)
            tilt = kn(at(sit, "hind"), 1)
        else:
            x = kn(at(at(k, "sit"), "fore"), 0)
            tilt = kn(at(at(k, "sit"), "fore"), 1)
    var paw = float2 { x, -h + pad + lift }
    let r = tilt   // (degrees)
    let j = CatJ {}
    if hind:
        var hock = paw + float2 { -sin(r), cos(r) } * kn(b, 2)
        let reach = kn(b, 0) + kn(b, 1) - 0.05
        if magnitude(hock) > reach:
            let fix = normalize(hock) * reach - hock
            hock += fix
            paw += fix
        j.hock = hock
        j.paw = paw
        j.knee = ik(float2_0, hock, kn(b, 0), kn(b, 1), 1.0)
        j.toe = if lift > 0.0: float2 { cos(r * 0.5), -sin(r * 0.5) } else: float2 { 1.0, 0.0 }
        return j
    var wrist = paw + float2 { sin(r), cos(r) } * kn(b, 2)
    let reach2 = kn(b, 0) + kn(b, 1) - 0.05
    if magnitude(wrist) > reach2:
        let fix2 = normalize(wrist) * reach2 - wrist
        wrist += fix2
        paw += fix2
    let sj = kget(l, "scapula")
    let scap0 = if sj: kp2(sj) else: float2 { -1.4, 5.6 }
    var scap = scap0 + float2 { -0.25 * (x - x0), 0.9 * down }
    if sit.keys.length: scap = u3_rot2(scap0 * 0.8, kf(sit, "pitch", 0.0) * 0.6)
    var toe = float2 { 1.0, 0.0 }
    if lift > 0.0:
        toe = u3_rot2(normalize(paw - wrist), 90.0)
        if toe.x < -0.2: toe = float2 { 1.0, 0.0 }
    j.wrist = wrist
    j.paw = paw
    j.elbow = ik(float2_0, wrist, kn(b, 0), kn(b, 1), -1.0)
    j.scapula = scap
    j.toe = toe
    return j

class BipJ:
    knee = float2_0
    ankle = float2_0
    heel = float2_0
    toe = float2_0
    out = 0.0

def biped_joints(k:JV, pose:string) -> BipJ:
    let l = at(k, "leg")
    let w = at(k, "walk")
    let h = kn(at(k, "hip"), 1)
    let pad = kf(k, "pad", 0.8)
    let foot = kf(l, "foot", 0.0)
    let heel_back = kf(l, "heel", 0.0)
    let ankle_h = kf(l, "ankle", 0.0)
    var x = kf(l, "x", 0.0)
    var lift = 0.0
    var pitch = 0.0
    var out = 0.0
    if kit_is_step(pose):
        let p = u3_walk_frac(pose)
        let stance = kf(w, "stance", 0.0)
        let toe_off = kf(w, "toe_off", 25.0)
        if p < stance:
            let s = p / stance
            x += kf(w, "stride", 0.0) * (0.5 - s)
            pitch = toe_off * clamp((s - 0.65) / 0.35, 0.0, 1.0)
        else:
            let q = (p - stance) / (1.0 - stance)
            x += kf(w, "stride", 0.0) * (u3_smooth(0.0, 1.0, q) - 0.5)
            lift = kf(w, "lift", 0.0) * sin(q * 180.0)
            pitch = toe_off * pow(1.0 - q, 2.0)
    else:
        let ip = kget(kobj(k, "idle"), pose)
        if ip:
            x += kf(ip, "forward", 0.0)
            out = kf(ip, "out", 0.0)
            pitch = kf(ip, "pitch", 0.0)
    var toe = float2 { x - heel_back + foot, -h + pad + lift }
    let r = pitch   // (degrees)
    var heel = toe + float2 { -foot * cos(r), foot * sin(r) }
    var ankle = heel + u3_rot2(float2 { heel_back, ankle_h - pad }, -r)
    let bones = at(l, "bones")
    let thigh = kn(bones, 0)
    let shin = kn(bones, 1)
    let reach = thigh + shin - 0.05
    if magnitude(ankle) > reach:
        let fix = normalize(ankle) * reach - ankle
        ankle += fix
        heel += fix
        toe += fix
    let j = BipJ {}
    j.knee = ik(float2_0, ankle, thigh, shin, 1.0)
    j.ankle = ankle
    j.heel = heel
    j.toe = toe
    j.out = out
    return j

// ---- models

def kit_build(id:string, c:Colours) -> Spec:
    let name = kit_part.get(id, "")
    let role = kit_role.get(id, "")
    let k = kit_kits.get(name)
    assert k
    let pose = if rest_pose != "": rest_pose elif hold == "low": "" else: hold
    let idle_pose = if kit_has_s(kit_idle(k), pose): pose else: ""
    var spec = spec_of(mnode())
    if role == "body":
        spec = if kit_quad(k): quad_body(k, c, idle_pose) else: biped_body(k, c, idle_pose)
    elif role == "head":
        spec = kit_head(k, c)
    else:
        spec = if kit_quad(k): quad_leg(k, c, role == "hind", pose) else: biped_leg(k, c, pose)
    let sc = kf(k, "scale", 1.0)
    let sr = spec.nums.get("seam_r", float3 { -1.0, 0.0, 0.0 })
    if sr.x >= 0.0: spec_num(spec, "seam_r", sr * sc)
    return scaled(spec, sc)

def kit_hexcol(o:JV, key:string, fallback:string) -> float3: return html(gstr(o, key, fallback))

def kit_coat(k:JV, c:Colours) -> dictionary<string, MMat>:
    let tex = gstr(k, "fur", "hide")
    let units = kf(k, "fur_units", 4.0)
    let pale = u3_col_or(c, "skin3", lightened(col(c, "skin"), 0.35))
    let h = kobj(k, "head")
    return mats_of([surf(tex, col(c, "skin"), units), surf(tex, col(c, "skin2"), units), surf(tex, col(c, "skin2"), units),
                    surf(tex, pale, units), surf(tex, u3_col_or(c, "skin4", col(c, "skin")), units),
                    plain(kit_hexcol(k, "pad_colour", "#2a2020")), plain(kit_hexcol(k, "claw_colour", "#e8e0cc")),
                    plain(kit_hexcol(kobj(h, "nose"), "colour", "#1c1614")), plain(INK),
                    plain(kit_hexcol(kobj(h, "eyes"), "iris", "#3a2412")), plain(kit_hexcol(kobj(h, "ears"), "inner", "#3a2a24"))],
                   ["fur", "dark", "stripe", "pale", "sock", "pad", "claw", "nose", "eye", "iris", "ear_in"])

// The torso's volumes as blobs (or the body's mesh); `leaning`: a biped's, turned by its lean.
def kit_torso(k:JV, mats:dictionary<string, MMat>, into:MNode, leaning:bool, lift:float3 = float3_0, pose_basis:Basis = BASIS_ID):
    let body = at(k, "body")
    let mesh = kget(body, "mesh")
    if mesh:
        let low = mnode()
        low.pos = float3 { 0.0, -kf(body, "drop", 0.0), 0.0 }
        add_child(low, glb(as_str(mesh), mats))
        add_child(into, low)
        return
    for(kit_volumes(k)) v:
        let p = if leaning: kit_lean(k, v.at) else: v.at
        add_child(into, blob(v.r, u3_mat(mats, v.mat), p, float3 { 0.0, 0.0, v.rot - kf(k, "lean", 0.0) * (if kit_quad(k): 0.0 else: 1.0) }))
    for(glist(body, "patches")) patch:
        let pa = kv3(at(patch, "at"))
        add_child(into, blob(kv3(at(patch, "r")), u3_mat(mats, gstr(patch, "mat", "pale")), if leaning: kit_lean(k, pa) else: pa, float3 { 0.0, 0.0, kf(patch, "rot", 0.0) }))
    let nk = kget(k, "neck")
    if nk:
        let fr = kv3(at(nk, "from"))
        add_child(into, rod(if leaning: kit_lean(k, fr) else: fr, neck_end(k, lift, pose_basis), kn(at(nk, "r"), 0), kn(at(nk, "r"), 1), u3_mat(mats, "fur")))

def neck_end(k:JV, lift:float3, pose_basis:Basis) -> float3:
    let nk = at(k, "neck")
    let p = kv3(at(nk, "to")) + lift
    let into = kget(nk, "into")
    if not into: return p + float3 { -0.4, -0.6, 0.0 }
    let h = kobj(k, "head")
    let local = bxf(axis_angle(U3_ZUP, kf(h, "tilt", 0.0)), kv3(into) * kf(h, "k", 1.0))
    return p + bxf(binverse(pose_basis), local)

def kit_tail(k:JV, mats:dictionary<string, MMat>, into:MNode, t:Xform, pose:string):
    let tl = kget(k, "tail")
    if not tl: return
    let stub = kget(tl, "stub")
    if stub:
        add_child(into, blob(kv3(at(stub, "r")), u3_mat(mats, "fur"), xf(t, kv3(at(stub, "at")))))
        return
    let r = at(tl, "r")
    let fur = u3_mat(mats, "fur")
    let dark = if gbool(tl, "rings", false): u3_mat(mats, "stripe") else: fur
    let sit = kit_sit_pose(k, pose)
    let root = kv3(kget(tl, "sit_root") or glist(tl, "pts")[0])
    if sit.keys.length and kget(sit, "fold"):
        let b = xf(t, root)
        let paw = xf(t, kv3(at(k, "shoulder"))).x + 0.9
        cat_tail(into, [b, float3 { b.x + 0.5, 1.1, 1.8 }, float3 { b.x + 1.6, 1.0, 3.4 }, float3 { b.x + 3.4, 1.0, 4.8 },
                        float3 { paw - 6.5, 1.0, 5.2 }, float3 { paw - 3.0, 1.1, 4.9 }, float3 { paw - 1.2, 2.0, 4.3 }],
                 kn(r, 0) * 0.85, kn(r, 1) * 0.85, fur, dark)
    elif sit.keys.length:
        let b = xf(t, root + float3 { 0.0, 0.4, 0.0 })
        cat_tail(into, [b, b + float3 { -2.8, -0.9, 0.2 }, float3 { b.x - 4.8, max(2.6, b.y - 3.6), 0.5 },
                        float3 { b.x - 5.6, 1.2, 0.9 }, float3 { b.x - 4.6, 1.0, 1.6 }], kn(r, 0), kn(r, 1), fur, dark)
    else:
        let pts = map(glist(tl, "pts")) p: xf(t, kv3(p))
        cat_tail(into, pts, kn(r, 0), kn(r, 1), fur, dark)

def kit_spec(n:MNode, sk:KitSk) -> Spec:
    let s = spec_of(n)
    for(sk.names) name: sock(s, name, ksock_at(sk, name))
    s.anchors = sk.anchors
    return s

def quad_body(k:JV, c:Colours, pose:string) -> Spec:
    let sk = kit_skeleton(k, pose)
    let t = sk.t
    let n = mnode()
    let inner = mnode()
    set_xform(inner, t)
    add_child(n, inner)
    let mats = kit_coat(k, c)
    kit_torso(k, mats, inner, false, head_lift(k, pose), t.b)
    kit_tail(k, mats, if pose != "": n else: inner, if pose != "": t else: XF_ID, pose)
    let tack = kobj(k, "tack")
    let cl = kget(tack, "cloth")
    if cl:
        let seat = ksock_at(kit_skeleton(k, ""), "seat")
        let girth = kv3_or(cl, "girth", float3 { seat.x + 4.6, (top_at(k, seat.x) + bottom_at(k, seat.x)) * 0.5, 0.0 })
        let half = half_width_at(k, seat.x)
        cat_saddle(inner, c, seat.x, seat.y - kf(cl, "below", 1.4), kf(cl, "half", half * 0.85), girth,
                   kf(cl, "ry", (top_at(k, girth.x) - bottom_at(k, girth.x)) * 0.5 + 0.2), kf(cl, "rz", half_width_at(k, girth.x) + 0.2),
                   kf(cl, "length", 6.0), kf(cl, "drop", 2.6))
    let s = kit_spec(n, sk)
    spec_num(s, "torso_scale", float3 { 1.3, 1.0, 0.0 })
    spec_str(s, "carry", "harness")
    if has(k, "head") and kget(at(k, "neck"), "into"):
        spec_str(s, "seam_head", as_str(at(at(k, "parts"), "head")))
        sock(s, "join", xf(t, neck_end(k, head_lift(k, pose), t.b)))
        spec_num(s, "seam_r", kn(at(at(k, "neck"), "r"), 1) * 1.6)
    return s

def biped_body(k:JV, c:Colours, pose:string) -> Spec:
    let sk = kit_skeleton(k, pose)
    let n = mnode()
    let mats = kit_coat(k, c)
    kit_torso(k, mats, n, true)
    kit_tail(k, mats, n, XF_ID, pose)
    let a = at(k, "arm")
    let head = ksock_at(sk, "head")
    var near_hand = float3_0
    let front = mnode()
    let ar = at(a, "r")
    for([1.0, -1.0]) side:
        let into = if side == 1.0: front else: n
        let sh = kit_lean(k, kv3(at(a, "shoulder")) * float3 { 1.0, 1.0, side })
        var elbow = sh + kv3(at(a, "elbow")) * float3 { 1.0, 1.0, side }
        var hand = if side == 1.0: kv3(at(a, "hand")) else: kv3(at(a, "hand_l"))
        if side == 1.0:
            let e, h = arm_pose(sh, elbow, hand, head)
            elbow = e
            hand = h
            near_hand = hand
        add_child(into, blob(float3_1 * kpair(ar, 0, 0) * 1.05, u3_mat(mats, "fur"), sh))
        add_child(into, rod(sh, elbow, kpair(ar, 0, 0), kpair(ar, 0, 1), u3_mat(mats, "fur")))
        add_child(into, rod(elbow, hand, kpair(ar, 1, 0), kpair(ar, 1, 1), u3_mat(mats, "fur")))
        add_child(into, blob(kv3(at(a, "paw")), u3_mat(mats, if gbool(a, "dark_paws", true): "dark" else: "fur"), hand))
    ksock(sk, "hand_r", near_hand)
    if gbool(k, "kerchief", false):
        let nk = at(k, "neck")
        kerchief(front, c, kit_lean(k, kv3(at(nk, "from"))) + float3 { 0.6, 0.4, 0.0 }, kn(at(nk, "r"), 0) * 0.95, kf(k, "lean", 0.0))
    let s = kit_spec(n, sk)
    s.front = front
    spec_num(s, "torso_scale", float3 { 0.9, 1.1, 0.0 })
    spec_num(s, "torso_fit", torso_fit(k))
    return spec_num(s, "torso_tilt", -kf(k, "lean", 0.0))

def quad_leg(k:JV, c:Colours, hind:bool, pose:string) -> Spec:
    let j = quad_joints(k, hind, pose)
    let l = at(k, if hind: "hind" else: "fore")
    let mats = kit_coat(k, c)
    let r = at(l, "r")
    let msj = kget(l, "mats")
    let ms = if msj: map(msj.a) v: as_str(v) else: ["fur", "fur", "fur", "fur", "fur"]
    let n = mnode()
    let out = float3 { 0.0, 0.0, j.out }
    if hind:
        let top = kv3_or(l, "thigh_top", float3 { 0.3, 1.6, 0.0 })
        add_child(n, rod(top, u3_v3(j.knee) + out * 0.5, kpair(r, 0, 0), kpair(r, 0, 1), u3_mat(mats, ms[0])))
        add_child(n, rod(u3_v3(j.knee) + out * 0.5, u3_v3(j.hock) + out, kpair(r, 1, 0), kpair(r, 1, 1), u3_mat(mats, ms[1])))
        add_child(n, rod(u3_v3(j.hock) + out, u3_v3(j.paw) + out, kpair(r, 2, 0), kpair(r, 2, 1), u3_mat(mats, ms[2])))
    else:
        add_child(n, rod(float3_0, u3_v3(j.scapula), kpair(r, 0, 0), kpair(r, 0, 1), u3_mat(mats, ms[0])))
        add_child(n, rod(float3_0, u3_v3(j.elbow), kpair(r, 1, 0), kpair(r, 1, 1), u3_mat(mats, ms[1])))
        add_child(n, rod(u3_v3(j.elbow), u3_v3(j.wrist), kpair(r, 2, 0), kpair(r, 2, 1), u3_mat(mats, ms[2])))
        add_child(n, rod(u3_v3(j.wrist), u3_v3(j.paw), kpair(r, 3, 0), kpair(r, 3, 1), u3_mat(mats, ms[3])))
    let toe = j.toe
    let paw_out = if hind: out else: float3_0
    let p = u3_v3(j.paw + toe * 0.45) + paw_out
    add_child(n, blob(kv3(at(l, "paw")), u3_mat(mats, gstr(l, "paw_mat", "pale")), p, float3 { 0.0, 0.0, atan2(toe) }))
    if gbool(l, "claws", false):
        let ps = kv3(at(l, "paw"))
        for([-1.0, 0.0, 1.0]) t:
            add_child(n, blob(float3 { 0.45, 0.28, 0.3 }, u3_mat(mats, "claw"), p + float3 { toe.x * ps.x * 0.95, toe.y * ps.x * 0.95 - ps.y * 0.6, t * ps.z * 0.55 }))
    return spec_of(n)

def biped_leg(k:JV, c:Colours, pose:string) -> Spec:
    let j = biped_joints(k, pose)
    let l = at(k, "leg")
    let mats = kit_coat(k, c)
    let fur = u3_mat(mats, "fur")
    let r = at(l, "r")
    let n = mnode()
    let out = float3 { 0.0, 0.0, j.out }
    let knee = u3_v3(j.knee) + out * 0.5
    let ankle = u3_v3(j.ankle) + out
    let heel = u3_v3(j.heel) + out
    let toe = u3_v3(j.toe) + out
    let frj = kget(l, "foot_r")
    let fr = if frj: kp2(frj) else: float2 { 1.0, 1.5 }
    add_child(n, rod(kv3_or(l, "thigh_top", float3 { 0.2, 0.8, 0.0 }), knee, kpair(r, 0, 0), kpair(r, 0, 1), fur))
    add_child(n, rod(knee, ankle, kpair(r, 1, 0), kpair(r, 1, 1), fur))
    let mid = (heel + toe) * 0.5 + float3 { 0.0, kf(l, "foot_h", 0.5), 0.0 }
    let d = toe - heel
    add_child(n, blob(float3 { magnitude(d) * 0.55, fr.x, fr.y }, fur, mid, float3 { 0.0, 0.0, atan2(float2 { d.x, d.y }) }))
    add_child(n, rod(ankle, mid, kpair(r, 1, 1), fr.x, fur))
    for([-1.0, 0.0, 1.0]) t:
        let tip = toe + float3 { 0.2, 0.1, t * fr.y * 0.55 }
        add_child(n, blob(float3 { 0.45, 0.3, 0.32 }, u3_mat(mats, "claw"), tip + float3 { 0.35, -0.05, 0.0 }))
    return spec_of(n)

def kit_head(k:JV, c:Colours) -> Spec:
    let h = at(k, "head")
    let mats = kit_coat(k, c)
    let fur = u3_mat(mats, "fur")
    let root = mnode()
    let hk = kf(h, "k", 1.0)
    let tilt = kf(h, "tilt", 0.0)
    let mesh = kget(h, "mesh")
    if mesh:
        let g = glb(as_str(mesh), mats)
        u3_rot_z(g, tilt)
        g.scl = float3_1 * hk
        add_child(root, g)
    else:
        let n = mnode()
        n.rot = float3 { 0.0, 0.0, tilt }
        n.scl = float3_1 * hk
        add_child(root, n)
        let sk = at(h, "skull")
        let sc = kv3(at(sk, "at"))
        let sr = kv3(at(sk, "r"))
        add_child(n, blob(sr, fur, sc))
        let ch = kget(h, "cheeks")
        if ch: add_child(n, blob(kv3(at(ch, "r")), u3_mat(mats, gstr(ch, "mat", "fur")), kv3(at(ch, "at"))))
        let st = kget(h, "stop")
        if st: add_child(n, blob(kv3(at(st, "r")), fur, kv3(at(st, "at"))))
        let mz = at(h, "muzzle")
        let tip = kv3(at(mz, "to"))
        let mzr = at(mz, "r")
        let mzm = u3_mat(mats, gstr(mz, "mat", "fur"))
        add_child(n, rod(kv3(at(mz, "from")), tip, kn(mzr, 0), kn(mzr, 1), mzm))
        let br = kget(mz, "bridge")
        if br: add_child(n, blob(kv3(at(br, "r")), mzm, kv3(at(br, "at"))))
        let ns = kget(h, "nose")
        if ns:
            add_child(n, blob(kv3(at(ns, "r")), u3_mat(mats, "nose"), tip + kv3_or(ns, "at", float3 { kn(mzr, 1) * 0.55, kn(mzr, 1) * 0.35, 0.0 })))
        let mouth = tip + float3 { -kn(mzr, 1) * 0.2, -kn(mzr, 1) * 0.75, 0.0 }
        add_child(n, rod(mouth + float3 { -1.6, 0.1, 0.0 }, mouth, 0.18, 0.15, u3_mat(mats, "eye"), false))
        let e = kget(h, "eyes")
        if e:
            let er = kf(e, "r", 0.0)
            for([1.0, -1.0]) side:
                let look = kv3(at(e, "look")) * float3 { 1.0, 1.0, side }
                let p = on_surface(sc, sr, look, -0.15)
                let eye = blob(float3_1 * er, u3_mat(mats, "eye"), p)
                eye.meta = "eye"
                add_child(n, eye)
                if has(e, "iris"):
                    add_child(n, blob(float3 { 0.35, 0.45, 0.35 } * er / 0.55, u3_mat(mats, "iris"), p + normalize(look) * er * 0.6))
                let bw = kget(h, "brow")
                if bw:
                    let brow = blob(kv3(at(bw, "r")), fur, p + kv3(at(bw, "at")) * float3 { 1.0, 1.0, side })
                    brow.meta = "brow"
                    add_child(n, brow)
        let ea = kget(h, "ears")
        if ea:
            for([1.0, -1.0]) side:
                let p = kv3(at(ea, "at")) * float3 { 1.0, 1.0, side }
                let size = kv3(at(ea, "size"))
                if gstr(ea, "shape", "round") == "point":
                    let lean = kf(ea, "lean", 8.0)
                    add_child(n, cone(0.0, size.x, size.y, fur, p, float3 { -12.0 * side, 0.0, lean }))
                    add_child(n, cone(0.0, size.x * 0.6, size.y * 0.75, u3_mat(mats, "ear_in"), p + float3 { 0.25, -0.1, 0.15 * side }, float3 { -12.0 * side, 0.0, lean }))
                else:
                    let lean = kf(ea, "lean", -10.0)
                    add_child(n, blob(size, fur, p, float3 { 0.0, 0.0, lean }))
                    add_child(n, blob(size * float3 { 0.5, 0.62, 0.62 }, u3_mat(mats, "ear_in"), p + float3 { 0.45, -0.1, 0.12 * side }, float3 { 0.0, 0.0, lean }))
    let wh = kget(h, "whiskers")
    if wh:
        let wn = mnode()
        wn.rot = float3 { 0.0, 0.0, tilt }
        wn.scl = float3_1 * hk
        add_child(root, wn)
        let white = plain(lightened(u3_col_or(c, "skin3", html("#e8e2d6")), 0.3))
        for([1.0, -1.0]) s:
            for([-0.5, 0.0, 0.5]) w:
                let a = kv3(wh) + float3 { 0.0, w * 0.5, 1.2 * s }
                add_child(wn, rod(a, a + float3 { 1.2, w, 2.4 * s }, 0.09, 0.06, white, false))
    let b = kget(h, "bridle")
    if b:
        cat_bridle(root, c, kv3(at(b, "snout")) * hk, kf(b, "snout_r", 0.0) * hk, kv3(at(b, "crown")) * hk, kf(b, "crown_r", 0.0) * hk, tilt)
    let spec = sock(spec_of(root), "top", kv3(at(h, "top")) * hk)
    if kget(h, "gear_scale"): spec_num(spec, "gear_scale", kf(h, "gear_scale", 0.0) * hk)
    return spec

// ------------------------------------------------------------------ this file's parts by id
def build_kit(base:string, c:Colours) -> Spec?:
    kit_load()
    if kit_part.get(base, "") == "": return nil
    return kit_build(base, c)
