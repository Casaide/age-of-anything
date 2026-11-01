// Procedural voxel units, a prototype: a body as capsules blended on a posed skeleton, filled into a voxel grid at
// one voxel per art pixel, drawn in the game's 3/4 view in 8 facings with face shading and an outline. A race is a
// handful of numbers (proportions, colours, a head); a unit is a race with a kit of gear.
// The game draws them with the `voxels` option (game/voxel_units.lobster); voxel_proto.lobster draws a sheet.

let vx_ELEV = 30.0              // the camera's elevation, degrees
let vx_RES = 2.0             // voxels a body unit (2: a voxel a baked pixel, the composed units' detail)
let vx_CELL = int2 { int(52.0 * vx_RES), int(74.0 * vx_RES) }   // a sprite cell at game scale
let vx_BLEND = 2.2              // how far shapes melt into each other, voxels

enum vx_mat_kind:
    vx_mat_skin, vx_mat_pale, vx_mat_trousers, vx_mat_leather, vx_mat_hair, vx_mat_wood, vx_mat_metal, vx_mat_coat, vx_mat_mane, vx_mat_team,
    vx_mat_eye, vx_mat_white, vx_mat_pink, vx_mat_cat, vx_mat_yellow

let vx_MAT_BASE = [
    float3 { 0.86, 0.66, 0.50 },   // skin or fur (the race's)
    float3 { 0.92, 0.82, 0.68 },   // pale: a muzzle, a belly (the race's)
    float3 { 0.36, 0.30, 0.24 },   // trousers
    float3 { 0.45, 0.30, 0.17 },   // leather
    float3 { 0.42, 0.25, 0.12 },   // hair
    float3 { 0.55, 0.38, 0.20 },   // wood
    float3 { 0.70, 0.72, 0.76 },   // metal
    float3 { 0.50, 0.32, 0.19 },   // a horse's coat
    float3 { 0.20, 0.14, 0.10 },   // mane and tail
    float3 { 0.80, 0.16, 0.13 },   // team colour: the whole tunic (Dominic, 2026-11-01)
    float3 { 0.10, 0.07, 0.05 },   // eyes
    float3 { 0.92, 0.90, 0.84 },   // eye whites
    float3 { 0.86, 0.56, 0.56 },   // pink: a rat's nose, ears and tail
    float3 { 0.13, 0.12, 0.14 },   // a black cat
    float3 { 0.95, 0.80, 0.22 },   // a cat's eyes
]
let vx_mat_cols = copy(vx_MAT_BASE)

class vx_prim:
    a:float3
    b:float3
    ra:float
    rb:float
    mat:int
    hard:bool   // gear: no melting into the body
    disc:bool   // a shield: a disc round a, facing along b - a, ra across and rb thick

def vx_dist(p:float3, s:vx_prim) -> float:
    let ba = s.b - s.a
    if s.disc:
        let n = normalize(ba)
        let q = p - s.a
        let h = dot(q, n)
        let w = float2 { magnitude(q - n * h) - s.ra, abs(h) - s.rb }
        return magnitude(max(w, float2_0)) + min(max(w.x, w.y), 0.0)
    let l2 = dot(ba, ba)
    let h = if l2 > 0.0: clamp(dot(p - s.a, ba) / l2, 0.0, 1.0) else: 0.0
    return magnitude(p - s.a - ba * h) - (s.ra + (s.rb - s.ra) * h)

def vx_smin(a:float, b:float, k:float) -> float:
    let h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

def vx_ball(c:float3, r:float, m:int, hard:bool) -> vx_prim: return vx_prim { c, c, r, r, m, hard, false }

// A limb bent forward by `deg` (0 hangs straight down).
def vx_down(deg:float) -> float3: return float3 { 0.0, sin(deg), -cos(deg) }

// ---- races: a few numbers each

class vx_race:
    skin:float3
    pale:float3
    vx_head:string
    size:float      // the whole body scaled
    hip:float       // hip height
    thigh:float
    shin:float
    foot:float
    limb:float      // a leg's radius at the hip
    stance:float    // half the hips' width
    spine:float
    waist:float
    chest:float
    lean:float      // the torso leaned forward, degrees
    vx_arm:float       // arm segments' length
    tail:string
    sleeves:bool    // the tunic's sleeves (a frog's arms stay bare)

let vx_HUMAN = vx_race { float3 { 0.86, 0.66, 0.50 }, float3 { 0.92, 0.75, 0.60 }, "human", 1.0,
                   21.0, 10.5, 10.0, 2.6, 2.6, 2.9, 11.0, 4.0, 4.7, 4.0, 7.2, "", true }
let vx_RAT = vx_race { float3 { 0.47, 0.40, 0.36 }, float3 { 0.74, 0.68, 0.62 }, "rat", 0.85,
                 15.0, 7.5, 7.5, 3.6, 2.4, 2.6, 10.0, 4.2, 4.6, 22.0, 6.2, "rat", true }
let vx_FROG = vx_race { float3 { 0.40, 0.58, 0.24 }, float3 { 0.82, 0.80, 0.50 }, "frog", 0.85,
                  9.0, 6.5, 6.0, 4.0, 2.8, 3.6, 8.0, 5.6, 5.0, 30.0, 6.0, "", false }
let vx_BEAR = vx_race { float3 { 0.42, 0.28, 0.17 }, float3 { 0.62, 0.48, 0.34 }, "bear", 1.12,
                  19.0, 9.5, 9.0, 3.2, 3.4, 3.6, 12.0, 6.0, 6.6, 6.0, 7.0, "bear", true }

class vx_unit_def:
    label:string
    rc:vx_race
    right:string    // in the right hand: axe, spear, sword or ""
    left:string     // in the left: shield, bow or ""
    helm:bool
    armour:bool
    mount:string    // "", horse or centaur

// ---- bodies: parts as capsules on a posed skeleton (z up, y forward, x right)

def vx_leg(out:[vx_prim], rc:vx_race, hip:float3, swing:float, bend:float, m:int, boot:int):
    let knee = hip + vx_down(swing) * rc.thigh
    let ankle = knee + vx_down(swing - bend) * rc.shin
    out.push(vx_prim { hip, knee, rc.limb, rc.limb * 0.8, m, false, false })
    out.push(vx_prim { knee, ankle, rc.limb * 0.8, rc.limb * 0.6, boot, false, false })
    out.push(vx_prim { ankle, ankle + float3 { 0.0, rc.foot, -0.6 }, rc.limb * 0.65, rc.limb * 0.55, boot, false, false })

// A frog's leg folded under it: the knee up and out, the shin back down to a long webbed foot on the ground.
def vx_frog_leg(out:[vx_prim], rc:vx_race, hip:float3, side:float, step:float):
    let h = hip + float3 { side * rc.stance, 0.0, 0.0 }
    let knee = h + float3 { side * 3.4, 3.0 + step * 2.0, 0.8 }
    let ankle = float3 { h.x + side * 2.6, h.y - 1.5 + step * 2.0, 1.4 }
    out.push(vx_prim { h, knee, rc.limb, rc.limb * 0.85, vx_mat_skin, false, false })
    out.push(vx_prim { knee, ankle, rc.limb * 0.8, rc.limb * 0.55, vx_mat_skin, false, false })
    for([ -0.5, 0.5 ]) toe:
        out.push(vx_prim { ankle, ankle + float3 { side * 0.6 + toe * 1.8, 4.2, -0.6 }, 1.1, 0.8, vx_mat_skin, false, false })

def vx_arm(out:[vx_prim], rc:vx_race, shoulder:float3, side:float, swing:float, bend:float) -> float3:
    let elbow = shoulder + vx_down(swing) * rc.vx_arm + float3 { side * 0.6, 0.0, 0.0 }
    let wrist = elbow + vx_down(swing + bend) * rc.vx_arm * 0.95
    out.push(vx_prim { shoulder, elbow, 1.8, 1.55, if rc.sleeves: vx_mat_team else: vx_mat_skin, false, false })
    out.push(vx_prim { elbow, wrist, 1.55, 1.25, vx_mat_skin, false, false })
    out.push(vx_ball(wrist + vx_down(swing + bend) * 0.9, 1.3, vx_mat_skin, false))
    return wrist + vx_down(swing + bend) * 0.9

def vx_head(out:[vx_prim], rc:vx_race, vx_at:float3, helm:bool):
    switch rc.vx_head:
        case "human":
            out.push(vx_prim { vx_at + float3 { 0.0, 0.5, -1.2 }, vx_at + float3 { 0.0, 0.0, 0.8 }, 2.7, 3.1, vx_mat_skin, false, false })
            out.push(vx_prim { vx_at + float3 { 0.0, 3.0, -0.3 }, vx_at + float3 { 0.0, 3.3, -0.7 }, 0.6, 0.5, vx_mat_skin, false, false })
            for([ -1.0, 1.0 ]) side: out.push(vx_ball(vx_at + float3 { side * 1.15, 2.75, 0.35 }, 0.45, vx_mat_eye, true))
            if not helm:   // hair: a crown down to just above the eyes, and down the back of the head
                out.push(vx_ball(vx_at + float3 { 0.0, -0.3, 2.1 }, 3.15, vx_mat_hair, true))
                out.push(vx_ball(vx_at + float3 { 0.0, -0.9, 0.2 }, 3.25, vx_mat_hair, true))
        case "rat":
            out.push(vx_prim { vx_at + float3 { 0.0, -0.6, 0.2 }, vx_at + float3 { 0.0, 0.8, 0.0 }, 2.5, 2.4, vx_mat_skin, false, false })
            out.push(vx_prim { vx_at + float3 { 0.0, 1.2, -0.3 }, vx_at + float3 { 0.0, 6.6, -1.5 }, 2.3, 0.95, vx_mat_skin, false, false })   // a long snout
            out.push(vx_ball(vx_at + float3 { 0.0, 6.9, -1.4 }, 1.05, vx_mat_pink, true))
            for([ -1.0, 1.0 ]) side:
                out.push(vx_ball(vx_at + float3 { side * 1.4, 2.0, 0.8 }, 0.5, vx_mat_eye, true))
                if not helm: out.push(vx_prim { vx_at + float3 { side * 2.2, -0.5, 2.0 }, vx_at + float3 { side * 2.6, -0.2, 2.9 }, 1.5, 1.4, vx_mat_skin, true, false })
        case "frog":
            out.push(vx_prim { vx_at + float3 { -1.6, 1.0, 0.0 }, vx_at + float3 { 1.6, 1.0, 0.0 }, 2.9, 2.9, vx_mat_skin, false, false })
            out.push(vx_prim { vx_at + float3 { 0.0, 2.6, -1.2 }, vx_at + float3 { 0.0, 2.6, -1.2 }, 2.6, 2.6, vx_mat_pale, false, false })
            for([ -1.0, 1.0 ]) side:
                out.push(vx_ball(vx_at + float3 { side * 2.2, 1.6, 2.2 }, 1.45, vx_mat_white, true))
                out.push(vx_ball(vx_at + float3 { side * 2.5, 2.8, 2.4 }, 0.6, vx_mat_eye, true))
        case "bear":
            out.push(vx_ball(vx_at, 3.6, vx_mat_skin, false))
            out.push(vx_prim { vx_at + float3 { 0.0, 2.2, -0.8 }, vx_at + float3 { 0.0, 4.4, -1.2 }, 1.9, 1.4, vx_mat_pale, false, false })
            out.push(vx_ball(vx_at + float3 { 0.0, 5.6, -0.9 }, 0.75, vx_mat_eye, true))
            for([ -1.0, 1.0 ]) side:
                out.push(vx_ball(vx_at + float3 { side * 1.5, 2.9, 0.8 }, 0.45, vx_mat_eye, true))
                if not helm: out.push(vx_ball(vx_at + float3 { side * 2.6, -0.4, 2.8 }, 1.3, vx_mat_skin, false))
        default: assert false
    if helm: out.push(vx_ball(vx_at + float3 { 0.0, -0.4, 1.6 }, 3.3 * (if rc.vx_head == "bear": 1.15 else: 1.0), vx_mat_metal, true))

// The upper body from the pelvis p: returns the right and left hands.
def vx_torso(out:[vx_prim], rc:vx_race, p:float3, ph:float, rs:float, rb:float, ls:float, lb:float, armour:bool, helm:bool) -> float3, float3:
    let chest = p + float3 { 0.0, sin(rc.lean), cos(rc.lean) } * rc.spine
    if rc.sleeves: out.push(vx_prim { p, chest, rc.waist, rc.chest, vx_mat_team, false, false })
    else:   // a short vest over a bare body (frogs)
        out.push(vx_prim { p, chest, rc.waist, rc.chest, vx_mat_skin, false, false })
        out.push(vx_prim { p + (chest - p) * 0.5, chest, rc.waist + 0.35, rc.chest + 0.35, vx_mat_team, true, false })
    out.push(vx_prim { chest + float3 { -rc.chest - 0.7, 0.0, -0.6 }, chest + float3 { rc.chest + 0.7, 0.0, -0.6 }, 2.1, 2.1, if rc.sleeves: vx_mat_team else: vx_mat_skin, false, false })
    if armour:
        out.push(vx_prim { p + float3 { 0.0, 0.0, 3.5 }, chest + float3 { 0.0, 0.0, -1.2 }, rc.waist + 0.4, rc.chest + 0.3, vx_mat_metal, true, false })
    let neck = chest + float3 { 0.0, 0.3 + sin(rc.lean) * 2.0, rc.chest * 0.5 }   // (a bigger chest, a longer neck: the head sits on it)
    out.push(vx_prim { chest, neck + float3 { 0.0, 0.0, 0.8 }, 1.9, 1.7, vx_mat_skin, false, false })
    vx_head(out, rc, neck + float3 { 0.0, 0.5, if rc.vx_head == "frog": 1.4 else: 3.6 }, helm)
    let sw = 18.0 * sin(ph)
    let sh = rc.chest + 0.9
    let right = vx_arm(out, rc, chest + float3 { sh, 0.0, -0.8 }, 1.0, rs + sw, rb)
    let left = vx_arm(out, rc, chest + float3 { -sh, 0.0, -0.8 }, -1.0, ls - sw, lb)
    return right, left

// ---- gear

// What's in the right hand, its shaft tilted forward by `tilt` degrees from straight up.
def vx_gear_right(out:[vx_prim], kind:string, hand:float3, tilt:float):
    let d = float3 { 0.0, sin(tilt), cos(tilt) }
    switch kind:
        case "axe":
            let top = hand + d * 9.0
            out.push(vx_prim { hand - d * 2.5, top, 0.55, 0.55, vx_mat_wood, true, false })
            out.push(vx_prim { top - d * 1.0 + float3 { 0.0, 0.6, 0.0 }, top + float3 { 0.0, 3.2, -0.6 }, 1.1, 1.8, vx_mat_metal, true, false })
        case "spear":
            out.push(vx_prim { hand - d * 9.0, hand + d * 19.0, 0.55, 0.55, vx_mat_wood, true, false })
            out.push(vx_prim { hand + d * 19.0, hand + d * 23.0, 0.9, 0.15, vx_mat_metal, true, false })
        case "sword":
            out.push(vx_prim { hand + float3 { -1.6, 0.0, 0.0 } + d * 0.8, hand + float3 { 1.6, 0.0, 0.0 } + d * 0.8, 0.5, 0.5, vx_mat_metal, true, false })
            out.push(vx_prim { hand + d * 0.8, hand + d * 9.5, 0.65, 0.3, vx_mat_metal, true, false })
        case "": return
        default: assert false

def vx_gear_left(out:[vx_prim], kind:string, hand:float3):
    switch kind:
        case "shield":
            let face = hand + float3 { -1.6, 0.6, 0.6 }
            out.push(vx_prim { face, face + float3 { -1.0, 0.25, 0.0 }, 4.4, 0.45, vx_mat_wood, true, true })
            out.push(vx_ball(face + float3 { -0.7, 0.2, 0.0 }, 1.1, vx_mat_metal, true))
        case "bow":
            var last = hand + float3 { 0.0, 0.0, -7.5 }
            for(6) k:
                let t = float(k + 1) / 6.0 * 2.0 - 1.0
                let p = hand + float3 { 0.0, 1.8 * (1.0 - t * t), 7.5 * t }
                out.push(vx_prim { last, p, 0.55, 0.55, vx_mat_wood, true, false })
                last = p
            out.push(vx_prim { hand + float3 { 0.0, -0.6, -7.5 }, hand + float3 { 0.0, -0.6, 7.5 }, 0.25, 0.25, vx_mat_white, true, false })
        case "": return
        default: assert false

// ---- whole units

// A weapon's tilt at rest, degrees forward from straight up.
def vx_rest_tilt(kind:string) -> float:
    return switch kind:
        case "axe": 60.0
        case "sword": 56.0
        default: 7.0

def vx_lerpd(a:float, b:float, k:float) -> float: return a + (b - a) * k

// How an arm holds what's in its hand: the upper arm's swing forward and the elbow's bend, degrees.
def vx_arm_pose(kind:string) -> float, float:
    switch kind:
        case "spear": return 20.0, 70.0
        case "sword": return 25.0, 45.0
        case "shield", "bow": return 25.0, 45.0
        case "": return -10.0, 15.0
        default: return 10.0, 25.0


var vx_act = ""      // the pose being drawn: "" (standing or walking) or "attack", at act_t (0 to 1) through it

// How far into its blow an attack is at t: a wind-up, a fast strike, a hold, back.
def vx_blow(t:float) -> float:
    return if t < 0.45: 0.0 elif t < 0.6: (t - 0.45) / 0.15 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25

def vx_biped(u:vx_unit_def, ph0:float) -> [vx_prim]:
    let rc = u.rc
    let out = []::vx_prim
    let ph = if vx_act == "": ph0 else: 0.0
    let t = ph0 / 360.0
    let s = 26.0 * sin(ph)
    let hip = float3 { 0.0, 0.0, rc.hip + 0.6 * abs(sin(ph * 2.0)) }
    if rc.vx_head == "frog":
        vx_frog_leg(out, rc, hip, -1.0, sin(ph))
        vx_frog_leg(out, rc, hip, 1.0, -sin(ph))
    else:
        vx_leg(out, rc, hip + float3 { -rc.stance, 0.0, 0.0 }, s, 40.0 * max(0.0, sin(ph + 90.0)), vx_mat_trousers, vx_mat_leather)
        vx_leg(out, rc, hip + float3 { rc.stance, 0.0, 0.0 }, -s, 40.0 * max(0.0, sin(ph - 90.0)), vx_mat_trousers, vx_mat_leather)
    if rc.vx_head != "frog": out.push(vx_prim { hip + float3 { 0.0, 0.0, -1.0 }, hip + float3 { 0.0, 0.0, 2.0 }, rc.waist + 0.3, rc.waist + 0.4, vx_mat_leather, false, false })
    if rc.tail == "rat":
        var last = hip + float3 { 0.0, -3.0, 0.0 }
        for(5) k:
            let p = last + float3 { 0.0, -2.6, -1.6 + float(k) * 0.5 }
            out.push(vx_prim { last, p, 0.9 - float(k) * 0.12, 0.8 - float(k) * 0.12, vx_mat_pink, false, false })
            last = p
    if rc.tail == "bear": out.push(vx_ball(hip + float3 { 0.0, -rc.waist, 0.5 }, 1.4, vx_mat_skin, false))
    var rs, rb = vx_arm_pose(u.right)
    var ls, lb = vx_arm_pose(u.left)
    var tilt = vx_rest_tilt(u.right)
    if vx_act == "attack":
        let k = vx_blow(t)
        let up = if t < 0.45: t / 0.45 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25   // (raised through the wind-up)
        switch u.right:
            case "spear":   // drawn back, then thrust level
                rs, rb, tilt = vx_lerpd(20.0 - 25.0 * up, 75.0, k), vx_lerpd(70.0 + 20.0 * up, 15.0, k), vx_lerpd(7.0, 85.0, k)
            case "axe", "sword":   // up over the head, then down through the arm held out
                rs, rb, tilt = vx_lerpd(rs + (160.0 - rs) * up, 55.0, k), vx_lerpd(rb, 10.0, k), vx_lerpd(tilt + (-40.0 - tilt) * up, 115.0, k)
            default:   // a bow: raised and drawn, loosed
                ls, lb = vx_lerpd(25.0, 85.0, up), vx_lerpd(45.0, 5.0, up)
                rs, rb = vx_lerpd(10.0, 80.0, up), vx_lerpd(25.0, 125.0, up * (1.0 - k))
    let right, left = vx_torso(out, rc, hip + float3 { 0.0, 0.0, 1.0 }, ph, rs, rb, ls, lb, u.armour, u.helm)
    vx_gear_right(out, u.right, right, tilt)
    vx_gear_left(out, u.left, left)
    return out

// A horse's body and legs; returns the top of its withers (where a rider sits or a centaur's man begins).
def vx_horse(out:[vx_prim], ph:float, with_head:bool) -> float3:
    let front = float3 { 0.0, 7.5, 20.0 }
    let back = float3 { 0.0, -8.5, 20.5 }
    out.push(vx_prim { back, front, 6.2, 6.6, vx_mat_coat, false, false })
    out.push(vx_prim { back + float3 { 0.0, -1.5, 1.5 }, back + float3 { 0.0, -6.0, -5.0 }, 1.4, 0.9, vx_mat_mane, true, false })
    let s = 24.0 * sin(ph)
    let legs = vx_race { float3_0, float3_0, "", 1.0, 0.0, 9.0, 9.5, 2.2, 2.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "", false }
    for([ -1.0, 1.0 ]) side:
        let lift = 30.0 * max(0.0, sin(ph + 90.0 * side))
        vx_leg(out, legs, front + float3 { side * 3.2, 1.0, -2.0 }, s * side, lift, vx_mat_coat, vx_mat_mane)
        vx_leg(out, legs, back + float3 { side * 3.4, -1.0, -2.0 }, -s * side, lift * 0.8, vx_mat_coat, vx_mat_mane)
    if with_head:
        let top = front + float3 { 0.0, 8.0, 9.0 }   // (forward enough to show past a rider)
        out.push(vx_prim { front + float3 { 0.0, 1.0, 2.0 }, top, 3.6, 2.2, vx_mat_coat, false, false })
        out.push(vx_prim { top + float3 { 0.0, -1.2, 0.8 }, front + float3 { 0.0, 0.5, 6.0 }, 1.0, 1.0, vx_mat_mane, true, false })   // mane
        out.push(vx_prim { top, top + float3 { 0.0, 4.6, -3.2 }, 2.2, 1.5, vx_mat_coat, false, false })
        for([ -1.0, 1.0 ]) side:
            out.push(vx_ball(top + float3 { side * 1.6, 1.4, 0.4 }, 0.45, vx_mat_eye, true))
            out.push(vx_prim { top + float3 { side * 1.0, -0.6, 1.6 }, top + float3 { side * 1.1, -0.4, 3.4 }, 0.8, 0.4, vx_mat_coat, false, false })
    return front

// A cat to ride (black, white chest and paws, a tail curled up); returns where its rider sits.
def vx_cat(out:[vx_prim], ph:float) -> float3:
    let front = float3 { 0.0, 6.0, 14.0 }
    let back = float3 { 0.0, -7.0, 14.5 }
    out.push(vx_prim { back, front, 5.2, 5.6, vx_mat_cat, false, false })
    out.push(vx_ball(front + float3 { 0.0, 1.5, -2.5 }, 4.0, vx_mat_white, false))   // chest
    let s = 22.0 * sin(ph)
    let legs = vx_race { float3_0, float3_0, "", 1.0, 0.0, 6.0, 6.5, 2.0, 2.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "", false }
    for([ -1.0, 1.0 ]) side:
        let lift = 30.0 * max(0.0, sin(ph + 90.0 * side))
        vx_leg(out, legs, front + float3 { side * 3.0, 1.0, -3.5 }, s * side, lift, vx_mat_cat, vx_mat_white)
        vx_leg(out, legs, back + float3 { side * 3.2, -1.0, -3.5 }, -s * side, lift * 0.8, vx_mat_cat, vx_mat_white)
    var last = back + float3 { 0.0, -3.0, 1.0 }
    for([ float3 { 0.0, -6.0, 4.0 }, float3 { 0.0, -7.0, 8.5 }, float3 { 0.0, -6.0, 12.0 }, float3 { 0.0, -4.0, 13.5 } ]) t:
        let p = back + t
        out.push(vx_prim { last, p, 1.4, 1.2, vx_mat_cat, false, false })
        last = p
    let head = front + float3 { 0.0, 5.0, 6.0 }
    out.push(vx_prim { front + float3 { 0.0, 1.0, 2.0 }, head, 3.6, 3.2, vx_mat_cat, false, false })
    out.push(vx_ball(head, 4.0, vx_mat_cat, false))
    out.push(vx_ball(head + float3 { 0.0, 3.2, -1.3 }, 2.0, vx_mat_white, false))   // muzzle
    out.push(vx_ball(head + float3 { 0.0, 4.9, -0.8 }, 0.7, vx_mat_pink, true))
    for([ -1.0, 1.0 ]) side:
        out.push(vx_ball(head + float3 { side * 1.7, 3.3, 0.9 }, 0.85, vx_mat_yellow, true))
        out.push(vx_prim { head + float3 { side * 2.2, 0.2, 2.4 }, head + float3 { side * 2.7, 0.0, 5.6 }, 1.5, 0.3, vx_mat_cat, false, false })
    return float3 { 0.0, -1.5, 19.6 }

def vx_unit_prims(u:vx_unit_def, ph:float) -> [vx_prim]:
    if u.mount == "": return vx_biped(u, ph)
    let out = []::vx_prim
    let rc = u.rc
    if u.mount == "centaur":
        let front = vx_horse(out, ph, false)
        out.push(vx_prim { front + float3 { 0.0, 1.0, 1.0 }, front + float3 { 0.0, 1.8, 7.0 }, 5.2, 4.4, vx_mat_coat, false, false })
        let right, left = vx_torso(out, rc, front + float3 { 0.0, 2.0, 7.0 }, ph, 20.0, 70.0, 25.0, 45.0, u.armour, u.helm)
        vx_gear_right(out, u.right, right, vx_rest_tilt(u.right))
        vx_gear_left(out, u.left, left)
        return out
    let seat = if u.mount == "cat": vx_cat(out, ph) else: vx_horse(out, ph, true) + float3 { 0.0, -8.5, 7.0 }
    let wide = if u.mount == "cat": 4.8 else: 5.6   // the rider astride: thighs forward and out, shins down the mount's sides
    for([ -1.0, 1.0 ]) side:
        let knee = seat + float3 { side * wide, 3.8, -4.5 }
        let ankle = knee + float3 { 0.0, -0.8, -6.5 }
        out.push(vx_prim { seat + float3 { side * 2.6, 0.0, 0.0 }, knee, 2.4, 2.0, vx_mat_trousers, false, false })
        out.push(vx_prim { knee, ankle, 2.0, 1.5, vx_mat_leather, false, false })
        out.push(vx_prim { ankle, ankle + float3 { 0.0, 2.2, -0.4 }, 1.6, 1.4, vx_mat_leather, false, false })
    let right, left = vx_torso(out, rc, seat + float3 { 0.0, 0.0, 1.0 }, 0.0, 20.0, 70.0, 25.0, 45.0, u.armour, u.helm)
    vx_gear_right(out, u.right, right, vx_rest_tilt(u.right))
    vx_gear_left(out, u.left, left)
    return out

// ---- the voxel grid: one voxel per art pixel

let vx_GRID = int3 { int(44.0 * vx_RES), int(48.0 * vx_RES), int(72.0 * vx_RES) }
let vx_ORIGIN = float3 { -22.0, -24.0, -1.0 } * vx_RES

// The whole shape's distance at p, and the material of the part nearest it.
def vx_field(ps:[vx_prim], p:float3, thick:float) -> float, int:
    var body = 1000.0
    var gear = 1000.0
    var near = 1000.0
    var m = -1
    for(ps) s:
        let d = vx_dist(p, s)
        if s.hard: gear = min(gear, d)
        else: body = vx_smin(body, d, vx_BLEND)
        if d < near:
            near = d
            m = s.mat
    return min(body, gear - thick), m   // (gear thickened: a shaft thinner than a voxel would fill in pieces)

var vx_normals = []::float3   // per filled voxel: the shape's smooth normal (the grid's stairs would speckle the shading)

// The shape filled into the grid. Blocks of 4 voxels a side are tested at their centre first: one clearly outside
// is skipped, one clearly inside filled whole (its voxels can't be seen); only blocks the surface crosses are tested
// voxel by voxel. Most of the grid is air, so this is most of the speed.
def vx_fill(ps:[vx_prim], unit_size:float) -> [int]:
    let size = unit_size * vx_RES
    let g = map(vx_GRID.x * vx_GRID.y * vx_GRID.z): -1
    vx_normals = map(vx_GRID.x * vx_GRID.y * vx_GRID.z): float3_0
    var low = 1000.0
    for(ps) s: low = min(low, min(s.a.z - s.ra, s.b.z - s.rb))
    let thick = 0.5 / size
    let shape = fn(v:float3) -> float3: (vx_ORIGIN + v) / size + float3 { 0.0, 0.0, low }
    let reach = 3.5 / size   // a block's half diagonal, in shape units
    for(vx_GRID.z / 4) bz: for(vx_GRID.y / 4) by: for(vx_GRID.x / 4) bx:
        let b0 = int3 { bx, by, bz } * 4
        let dc, mc = vx_field(ps, shape(float(b0) + float3_1 * 2.0), thick)
        if dc < reach:
            for(4) z: for(4) y: for(4) x:
                let v = b0 + int3 { x, y, z }
                let i = (v.z * vx_GRID.y + v.y) * vx_GRID.x + v.x
                if dc < -reach: g[i] = mc
                else:
                    let p = shape(float(v) + float3_1 * 0.5)
                    let d, m = vx_field(ps, p, thick)
                    if d <= 0.0:
                        g[i] = m
                        if d > -1.8:
                            let e = 0.5
                            let dx, mx = vx_field(ps, p + float3 { e, 0.0, 0.0 }, thick)
                            let dy, my = vx_field(ps, p + float3 { 0.0, e, 0.0 }, thick)
                            let dz, mz = vx_field(ps, p + float3 { 0.0, 0.0, e }, thick)
                            vx_normals[i] = normalize(float3 { dx - d, dy - d, dz - d })
    return g

def vx_at(g:[int], v:int3) -> int:
    if any(v < int3_0) or any(v >= vx_GRID): return -1
    return g[(v.z * vx_GRID.y + v.y) * vx_GRID.x + v.x]

// ---- drawing: a ray per pixel through the grid; the shape's normal where it enters gives the shade

// One facing of a filled grid as a sprite cell (alpha 0 around it, a one-pixel dark outline). The team colour's
// key (magenta) survives the shading, so the game's sprite shader can recolour it.
def vx_cell(g:[int], facing:int) -> [float4]:
    let yaw = float(facing) * 45.0
    let fwd = float3 { 0.0, cos(vx_ELEV), -sin(vx_ELEV) }
    let upv = float3 { 0.0, sin(vx_ELEV), cos(vx_ELEV) }
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let centre = float3 { 0.0, 0.0, 28.0 * vx_RES } - vx_ORIGIN
    let light = normalize(float3 { -0.75, -0.45, 0.6 })
    let shade = map(vx_CELL.x * vx_CELL.y): -1
    let cols = map(vx_CELL.x * vx_CELL.y): float3_0
    for(vx_CELL.y) py: for(vx_CELL.x) px:
        let u = float(px - vx_CELL.x / 2)
        let v = float(vx_CELL.y / 2 - py) - 2.0
        // the ray walked voxel by voxel (each voxel it crosses, once), from where it enters the grid
        let d = rot(fwd)
        var o = centre + rot(float3 { u, 0.0, 0.0 } + upv * v)
        var t0 = -1000.0
        var t1 = 1000.0
        for(3) ax:
            let lo = (0.0 - o[ax]) / d[ax]
            let hi = (float(vx_GRID[ax]) - o[ax]) / d[ax]
            t0 = max(t0, min(lo, hi))
            t1 = min(t1, max(lo, hi))
        if t0 < t1:
            o += d * (t0 + 0.001)
            var c = int3 { int(floor(o.x)), int(floor(o.y)), int(floor(o.z)) }
            let st = int3 { if d.x > 0.0: 1 else: -1, if d.y > 0.0: 1 else: -1, if d.z > 0.0: 1 else: -1 }
            let dt = float3 { abs(1.0 / d.x), abs(1.0 / d.y), abs(1.0 / d.z) }
            var tm = float3 { (if d.x > 0.0: float(c.x) + 1.0 - o.x else: o.x - float(c.x)) * dt.x,
                              (if d.y > 0.0: float(c.y) + 1.0 - o.y else: o.y - float(c.y)) * dt.y,
                              (if d.z > 0.0: float(c.z) + 1.0 - o.z else: o.z - float(c.z)) * dt.z }
            while all(c >= int3_0) and all(c < vx_GRID):
                let m = g[(c.z * vx_GRID.y + c.y) * vx_GRID.x + c.x]
                if m >= 0:
                    let n = vx_normals[(c.z * vx_GRID.y + c.y) * vx_GRID.x + c.x]
                    let k = dot(n, rot(light)) * 0.5 + 0.5
                    let band = if k > 0.8: 1.15 elif k > 0.58: 0.95 elif k > 0.36: 0.75 else: 0.56
                    cols[py * vx_CELL.x + px] = vx_mat_cols[m] * band
                    shade[py * vx_CELL.x + px] = m
                    break
                if tm.x < tm.y and tm.x < tm.z:
                    c.x += st.x
                    tm.x += dt.x
                elif tm.y < tm.z:
                    c.y += st.y
                    tm.y += dt.y
                else:
                    c.z += st.z
                    tm.z += dt.z
    let out = map(vx_CELL.x * vx_CELL.y): float4_0
    for(vx_CELL.y) py: for(vx_CELL.x) px:
        let i = py * vx_CELL.x + px
        if shade[i] >= 0: out[i] = float4 { cols[i].x, cols[i].y, cols[i].z, 1.0 }
        else:
            for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 } ]) dd:
                let q = int2 { px, py } + dd
                if q.x >= 0 and q.y >= 0 and q.x < vx_CELL.x and q.y < vx_CELL.y and shade[q.y * vx_CELL.x + q.x] >= 0:
                    let m = shade[q.y * vx_CELL.x + q.x]
                    let c = if m == vx_mat_team: float3 { 0.22, 0.07, 0.06 } else: vx_mat_cols[m] * 0.3
                    out[i] = float4 { c.x, c.y, c.z, 1.0 }
    return out

// Ground point of the unit in a cell (where its feet stand), px.
let vx_ANCHOR = int2 { vx_CELL.x / 2, vx_CELL.y / 2 - 2 + int(28.0 * vx_RES * cos(vx_ELEV) + 0.5) }

def vx_draw(g:[int], facing:int, img:[float3], iw:int, cx:int, cy:int):
    let cell = vx_cell(g, facing)
    for(vx_CELL.y) py: for(vx_CELL.x) px:
        let c = cell[py * vx_CELL.x + px]
        if c.w > 0.0: img[(cy + py) * iw + cx + px] = xyz(c)

