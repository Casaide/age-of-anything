// Procedural voxel units, a prototype: a body as capsules blended on a posed skeleton, filled into a voxel grid at
// one voxel per art pixel, drawn in the game's 3/4 view in 8 facings with face shading and an outline. A race is a
// handful of numbers (proportions, colours, a head); a unit is a race with a kit of gear.
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter point -resize 400% out.png)
import std
import vec

let ELEV = 30.0              // the camera's elevation, degrees
let CELL = int2 { 52, 74 }   // a sprite cell at game scale
let BLEND = 2.2              // how far shapes melt into each other, voxels

enum mat_kind:
    mat_skin, mat_pale, mat_trousers, mat_leather, mat_hair, mat_wood, mat_metal, mat_coat, mat_mane, mat_team,
    mat_eye, mat_white, mat_pink

let MAT_BASE = [
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
]
let mat_cols = copy(MAT_BASE)

class prim:
    a:float3
    b:float3
    ra:float
    rb:float
    mat:int
    hard:bool   // gear: no melting into the body
    disc:bool   // a shield: a disc round a, facing along b - a, ra across and rb thick

def dist(p:float3, s:prim) -> float:
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

def smin(a:float, b:float, k:float) -> float:
    let h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

def ball(c:float3, r:float, m:int, hard:bool) -> prim: return prim { c, c, r, r, m, hard, false }

// A limb bent forward by `deg` (0 hangs straight down).
def down(deg:float) -> float3: return float3 { 0.0, sin(deg), -cos(deg) }

// ---- races: a few numbers each

class race:
    skin:float3
    pale:float3
    head:string
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
    arm:float       // arm segments' length
    tail:string

let HUMAN = race { float3 { 0.86, 0.66, 0.50 }, float3 { 0.92, 0.75, 0.60 }, "human", 1.0,
                   21.0, 10.5, 10.0, 2.6, 2.6, 2.9, 11.0, 4.0, 4.7, 4.0, 7.2, "" }
let RAT = race { float3 { 0.47, 0.40, 0.36 }, float3 { 0.74, 0.68, 0.62 }, "rat", 0.85,
                 15.0, 7.5, 7.5, 3.6, 2.4, 2.6, 10.0, 4.2, 4.6, 22.0, 6.2, "rat" }
let FROG = race { float3 { 0.40, 0.58, 0.24 }, float3 { 0.82, 0.80, 0.50 }, "frog", 0.85,
                  12.0, 6.5, 6.0, 4.0, 2.8, 3.6, 8.5, 5.4, 5.2, 8.0, 6.0, "" }
let BEAR = race { float3 { 0.42, 0.28, 0.17 }, float3 { 0.62, 0.48, 0.34 }, "bear", 1.12,
                  19.0, 9.5, 9.0, 3.2, 3.4, 3.6, 12.0, 6.0, 6.6, 6.0, 7.0, "bear" }

class unit_def:
    label:string
    rc:race
    right:string    // in the right hand: axe, spear, sword or ""
    left:string     // in the left: shield, bow or ""
    helm:bool
    armour:bool
    mount:string    // "", horse or centaur

// ---- bodies: parts as capsules on a posed skeleton (z up, y forward, x right)

def leg(out:[prim], rc:race, hip:float3, swing:float, bend:float, m:int, boot:int):
    let knee = hip + down(swing) * rc.thigh
    let ankle = knee + down(swing - bend) * rc.shin
    out.push(prim { hip, knee, rc.limb, rc.limb * 0.8, m, false, false })
    out.push(prim { knee, ankle, rc.limb * 0.8, rc.limb * 0.6, boot, false, false })
    out.push(prim { ankle, ankle + float3 { 0.0, rc.foot, -0.6 }, rc.limb * 0.65, rc.limb * 0.55, boot, false, false })

def arm(out:[prim], rc:race, shoulder:float3, side:float, swing:float, bend:float) -> float3:
    let elbow = shoulder + down(swing) * rc.arm + float3 { side * 0.6, 0.0, 0.0 }
    let wrist = elbow + down(swing + bend) * rc.arm * 0.95
    out.push(prim { shoulder, elbow, 1.8, 1.55, mat_team, false, false })
    out.push(prim { elbow, wrist, 1.55, 1.25, mat_skin, false, false })
    out.push(ball(wrist + down(swing + bend) * 0.9, 1.3, mat_skin, false))
    return wrist + down(swing + bend) * 0.9

def head(out:[prim], rc:race, at:float3, helm:bool):
    switch rc.head:
        case "human":
            out.push(prim { at + float3 { 0.0, 0.5, -1.2 }, at + float3 { 0.0, 0.0, 0.8 }, 2.7, 3.1, mat_skin, false, false })
            out.push(prim { at + float3 { 0.0, 3.0, -0.3 }, at + float3 { 0.0, 3.3, -0.7 }, 0.6, 0.5, mat_skin, false, false })
            for([ -1.0, 1.0 ]) side: out.push(ball(at + float3 { side * 1.15, 2.75, 0.35 }, 0.45, mat_eye, true))
            if not helm: out.push(ball(at + float3 { 0.0, -0.8, 0.65 }, 3.35, mat_hair, true))
        case "rat":
            out.push(ball(at, 2.8, mat_skin, false))
            out.push(prim { at + float3 { 0.0, 1.5, -0.4 }, at + float3 { 0.0, 5.2, -1.6 }, 2.2, 0.8, mat_skin, false, false })
            out.push(ball(at + float3 { 0.0, 5.5, -1.6 }, 0.7, mat_pink, true))
            for([ -1.0, 1.0 ]) side:
                out.push(ball(at + float3 { side * 1.4, 2.0, 0.8 }, 0.5, mat_eye, true))
                if not helm: out.push(prim { at + float3 { side * 2.0, -0.4, 2.0 }, at + float3 { side * 2.1, 0.0, 2.4 }, 1.25, 1.1, mat_skin, false, false })
        case "frog":
            out.push(prim { at + float3 { -1.6, 1.0, 0.0 }, at + float3 { 1.6, 1.0, 0.0 }, 2.9, 2.9, mat_skin, false, false })
            out.push(prim { at + float3 { 0.0, 2.6, -1.2 }, at + float3 { 0.0, 2.6, -1.2 }, 2.6, 2.6, mat_pale, false, false })
            for([ -1.0, 1.0 ]) side:
                out.push(ball(at + float3 { side * 2.2, 1.6, 2.2 }, 1.45, mat_white, true))
                out.push(ball(at + float3 { side * 2.5, 2.8, 2.4 }, 0.6, mat_eye, true))
        case "bear":
            out.push(ball(at, 3.6, mat_skin, false))
            out.push(prim { at + float3 { 0.0, 2.2, -0.8 }, at + float3 { 0.0, 4.4, -1.2 }, 1.9, 1.4, mat_pale, false, false })
            out.push(ball(at + float3 { 0.0, 5.6, -0.9 }, 0.75, mat_eye, true))
            for([ -1.0, 1.0 ]) side:
                out.push(ball(at + float3 { side * 1.5, 2.9, 0.8 }, 0.45, mat_eye, true))
                if not helm: out.push(ball(at + float3 { side * 2.6, -0.4, 2.8 }, 1.3, mat_skin, false))
        default: assert false
    if helm: out.push(ball(at + float3 { 0.0, -0.4, 1.6 }, 3.3 * (if rc.head == "bear": 1.15 else: 1.0), mat_metal, true))

// The upper body from the pelvis p: returns the right and left hands.
def torso(out:[prim], rc:race, p:float3, ph:float, rs:float, rb:float, ls:float, lb:float, armour:bool, helm:bool) -> float3, float3:
    let chest = p + float3 { 0.0, sin(rc.lean), cos(rc.lean) } * rc.spine
    out.push(prim { p, chest, rc.waist, rc.chest, mat_team, false, false })
    out.push(prim { chest + float3 { -rc.chest - 0.7, 0.0, -0.6 }, chest + float3 { rc.chest + 0.7, 0.0, -0.6 }, 2.1, 2.1, mat_team, false, false })
    if armour:
        out.push(prim { p + float3 { 0.0, 0.0, 3.5 }, chest + float3 { 0.0, 0.0, -1.2 }, rc.waist + 0.4, rc.chest + 0.3, mat_metal, true, false })
    let neck = chest + float3 { 0.0, 0.3 + sin(rc.lean) * 2.0, rc.chest * 0.5 }   // (a bigger chest, a longer neck: the head sits on it)
    out.push(prim { chest, neck + float3 { 0.0, 0.0, 0.8 }, 1.9, 1.7, mat_skin, false, false })
    head(out, rc, neck + float3 { 0.0, 0.5, if rc.head == "frog": 1.4 else: 3.6 }, helm)
    let sw = 18.0 * sin(ph)
    let sh = rc.chest + 0.9
    let right = arm(out, rc, chest + float3 { sh, 0.0, -0.8 }, 1.0, rs + sw, rb)
    let left = arm(out, rc, chest + float3 { -sh, 0.0, -0.8 }, -1.0, ls - sw, lb)
    return right, left

// ---- gear

def gear_right(out:[prim], kind:string, hand:float3):
    switch kind:
        case "axe":
            let d = float3 { 0.0, sin(60.0), cos(60.0) }
            let top = hand + d * 9.0
            out.push(prim { hand - d * 2.5, top, 0.55, 0.55, mat_wood, true, false })
            out.push(prim { top - d * 1.0 + float3 { 0.0, 0.6, 0.0 }, top + float3 { 0.0, 3.2, -0.6 }, 1.1, 1.8, mat_metal, true, false })
        case "spear":
            let d = normalize(float3 { 0.0, 0.12, 1.0 })
            out.push(prim { hand - d * 9.0, hand + d * 19.0, 0.55, 0.55, mat_wood, true, false })
            out.push(prim { hand + d * 19.0, hand + d * 23.0, 0.9, 0.15, mat_metal, true, false })
        case "sword":
            let d = normalize(float3 { 0.0, 0.9, 0.6 })
            out.push(prim { hand + float3 { -1.6, 0.0, 0.0 } + d * 0.8, hand + float3 { 1.6, 0.0, 0.0 } + d * 0.8, 0.5, 0.5, mat_metal, true, false })
            out.push(prim { hand + d * 0.8, hand + d * 9.5, 0.65, 0.3, mat_metal, true, false })
        case "": return
        default: assert false

def gear_left(out:[prim], kind:string, hand:float3):
    switch kind:
        case "shield":
            let face = hand + float3 { -1.6, 0.6, 0.6 }
            out.push(prim { face, face + float3 { -1.0, 0.25, 0.0 }, 4.4, 0.45, mat_wood, true, true })
            out.push(ball(face + float3 { -0.7, 0.2, 0.0 }, 1.1, mat_metal, true))
        case "bow":
            var last = hand + float3 { 0.0, 0.0, -7.5 }
            for(6) k:
                let t = float(k + 1) / 6.0 * 2.0 - 1.0
                let p = hand + float3 { 0.0, 1.8 * (1.0 - t * t), 7.5 * t }
                out.push(prim { last, p, 0.55, 0.55, mat_wood, true, false })
                last = p
            out.push(prim { hand + float3 { 0.0, -0.6, -7.5 }, hand + float3 { 0.0, -0.6, 7.5 }, 0.25, 0.25, mat_white, true, false })
        case "": return
        default: assert false

// ---- whole units

// How an arm holds what's in its hand: the upper arm's swing forward and the elbow's bend, degrees.
def arm_pose(kind:string) -> float, float:
    switch kind:
        case "spear": return 20.0, 70.0
        case "sword": return 25.0, 45.0
        case "shield", "bow": return 25.0, 45.0
        case "": return -10.0, 15.0
        default: return 10.0, 25.0


def biped(u:unit_def, ph:float) -> [prim]:
    let rc = u.rc
    let out = []::prim
    let s = 26.0 * sin(ph)
    let hip = float3 { 0.0, 0.0, rc.hip + 0.6 * abs(sin(ph * 2.0)) }
    leg(out, rc, hip + float3 { -rc.stance, 0.0, 0.0 }, s, 40.0 * max(0.0, sin(ph + 90.0)), mat_trousers, mat_leather)
    leg(out, rc, hip + float3 { rc.stance, 0.0, 0.0 }, -s, 40.0 * max(0.0, sin(ph - 90.0)), mat_trousers, mat_leather)
    out.push(prim { hip + float3 { 0.0, 0.0, -1.0 }, hip + float3 { 0.0, 0.0, 2.0 }, rc.waist + 0.3, rc.waist + 0.4, mat_leather, false, false })
    if rc.tail == "rat":
        var last = hip + float3 { 0.0, -3.0, 0.0 }
        for(5) k:
            let p = last + float3 { 0.0, -2.6, -1.6 + float(k) * 0.5 }
            out.push(prim { last, p, 0.9 - float(k) * 0.12, 0.8 - float(k) * 0.12, mat_pink, false, false })
            last = p
    if rc.tail == "bear": out.push(ball(hip + float3 { 0.0, -rc.waist, 0.5 }, 1.4, mat_skin, false))
    let rs, rb = arm_pose(u.right)
    let ls, lb = arm_pose(u.left)
    let right, left = torso(out, rc, hip + float3 { 0.0, 0.0, 1.0 }, ph, rs, rb, ls, lb, u.armour, u.helm)
    gear_right(out, u.right, right)
    gear_left(out, u.left, left)
    return out

// A horse's body and legs; returns the top of its withers (where a rider sits or a centaur's man begins).
def horse(out:[prim], ph:float, with_head:bool) -> float3:
    let front = float3 { 0.0, 7.5, 20.0 }
    let back = float3 { 0.0, -8.5, 20.5 }
    out.push(prim { back, front, 6.2, 6.6, mat_coat, false, false })
    out.push(prim { back + float3 { 0.0, -1.5, 1.5 }, back + float3 { 0.0, -6.0, -5.0 }, 1.4, 0.9, mat_mane, true, false })
    let s = 24.0 * sin(ph)
    let legs = race { float3_0, float3_0, "", 1.0, 0.0, 9.0, 9.5, 2.2, 2.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "" }
    for([ -1.0, 1.0 ]) side:
        let lift = 30.0 * max(0.0, sin(ph + 90.0 * side))
        leg(out, legs, front + float3 { side * 3.2, 1.0, -2.0 }, s * side, lift, mat_coat, mat_mane)
        leg(out, legs, back + float3 { side * 3.4, -1.0, -2.0 }, -s * side, lift * 0.8, mat_coat, mat_mane)
    if with_head:
        let top = front + float3 { 0.0, 5.0, 10.0 }
        out.push(prim { front + float3 { 0.0, 1.0, 2.0 }, top, 3.6, 2.2, mat_coat, false, false })
        out.push(prim { top + float3 { 0.0, -1.2, 0.8 }, front + float3 { 0.0, 0.5, 6.0 }, 1.0, 1.0, mat_mane, true, false })   // mane
        out.push(prim { top, top + float3 { 0.0, 4.6, -3.2 }, 2.2, 1.5, mat_coat, false, false })
        for([ -1.0, 1.0 ]) side:
            out.push(ball(top + float3 { side * 1.6, 1.4, 0.4 }, 0.45, mat_eye, true))
            out.push(prim { top + float3 { side * 1.0, -0.6, 1.6 }, top + float3 { side * 1.1, -0.4, 3.4 }, 0.8, 0.4, mat_coat, false, false })
    return front

def unit_prims(u:unit_def, ph:float) -> [prim]:
    if u.mount == "": return biped(u, ph)
    let out = []::prim
    let rc = u.rc
    if u.mount == "centaur":
        let front = horse(out, ph, false)
        out.push(prim { front + float3 { 0.0, 1.0, 1.0 }, front + float3 { 0.0, 1.8, 7.0 }, 5.2, 4.4, mat_coat, false, false })
        let right, left = torso(out, rc, front + float3 { 0.0, 2.0, 7.0 }, ph, 20.0, 70.0, 25.0, 45.0, u.armour, u.helm)
        gear_right(out, u.right, right)
        gear_left(out, u.left, left)
        return out
    horse(out, ph, true)
    let seat = float3 { 0.0, -1.0, 27.0 }   // the rider astride: thighs forward and out, shins down the horse's sides
    for([ -1.0, 1.0 ]) side:
        let knee = seat + float3 { side * 5.6, 3.8, -4.5 }
        let ankle = knee + float3 { 0.0, -0.8, -6.5 }
        out.push(prim { seat + float3 { side * 2.6, 0.0, 0.0 }, knee, 2.4, 2.0, mat_trousers, false, false })
        out.push(prim { knee, ankle, 2.0, 1.5, mat_leather, false, false })
        out.push(prim { ankle, ankle + float3 { 0.0, 2.2, -0.4 }, 1.6, 1.4, mat_leather, false, false })
    let right, left = torso(out, rc, seat + float3 { 0.0, 0.0, 1.0 }, 0.0, 20.0, 70.0, 25.0, 45.0, u.armour, u.helm)
    gear_right(out, u.right, right)
    gear_left(out, u.left, left)
    return out

// ---- the voxel grid: one voxel per art pixel

let GRID = int3 { 44, 48, 72 }
let ORIGIN = float3 { -22.0, -24.0, -1.0 }

// The whole shape's distance at p, and the material of the part nearest it.
def field(ps:[prim], p:float3) -> float, int:
    var body = 1000.0
    var gear = 1000.0
    var near = 1000.0
    var m = -1
    for(ps) s:
        let d = dist(p, s)
        if s.hard: gear = min(gear, d)
        else: body = smin(body, d, BLEND)
        if d < near:
            near = d
            m = s.mat
    return min(body, gear), m

var normals = []::float3   // per filled voxel: the shape's smooth normal (the grid's stairs would speckle the shading)

def fill(ps:[prim], size:float) -> [int]:
    let g = map(GRID.x * GRID.y * GRID.z): -1
    normals = map(GRID.x * GRID.y * GRID.z): float3_0
    var low = 1000.0
    for(ps) s: low = min(low, min(s.a.z - s.ra, s.b.z - s.rb))
    for(GRID.z) z: for(GRID.y) y: for(GRID.x) x:
        let p = (ORIGIN + float(int3 { x, y, z }) + float3_1 * 0.5) / size + float3 { 0.0, 0.0, low }
        let d, m = field(ps, p)
        if d <= 0.0:
            let i = (z * GRID.y + y) * GRID.x + x
            g[i] = m
            if d > -1.8:
                let e = 0.5
                let dx, mx = field(ps, p + float3 { e, 0.0, 0.0 })
                let dy, my = field(ps, p + float3 { 0.0, e, 0.0 })
                let dz, mz = field(ps, p + float3 { 0.0, 0.0, e })
                normals[i] = normalize(float3 { dx - d, dy - d, dz - d })
    return g

def at(g:[int], v:int3) -> int:
    if any(v < int3_0) or any(v >= GRID): return -1
    return g[(v.z * GRID.y + v.y) * GRID.x + v.x]

// ---- drawing: a ray per pixel through the grid; the shape's normal where it enters gives the shade

def draw(g:[int], facing:int, img:[float3], iw:int, cx:int, cy:int):
    let yaw = float(facing) * 45.0
    let fwd = float3 { 0.0, cos(ELEV), -sin(ELEV) }
    let upv = float3 { 0.0, sin(ELEV), cos(ELEV) }
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let centre = float3 { 0.0, 0.0, 28.0 } - ORIGIN
    let light = normalize(float3 { -0.75, -0.45, 0.6 })
    let shade = map(CELL.x * CELL.y): -1
    let cols = map(CELL.x * CELL.y): float3_0
    for(CELL.y) py: for(CELL.x) px:
        let u = float(px - CELL.x / 2)
        let v = float(CELL.y / 2 - py) - 2.0
        var o = centre + rot(float3 { u, 0.0, 0.0 } + upv * v - fwd * 70.0)
        let d = rot(fwd) * 0.25
        for(600):
            let c = int3 { int(floor(o.x)), int(floor(o.y)), int(floor(o.z)) }
            let m = at(g, c)
            if m >= 0:
                let n = normals[(c.z * GRID.y + c.y) * GRID.x + c.x]
                let k = dot(n, rot(light)) * 0.5 + 0.5
                let band = if k > 0.8: 1.15 elif k > 0.58: 0.95 elif k > 0.36: 0.75 else: 0.56
                cols[py * CELL.x + px] = mat_cols[m] * band
                shade[py * CELL.x + px] = m
                break
            o += d
    for(CELL.y) py: for(CELL.x) px:
        let i = py * CELL.x + px
        var col = img[(cy + py) * iw + cx + px]
        if shade[i] >= 0: col = cols[i]
        else:
            for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 } ]) dd:
                let q = int2 { px, py } + dd
                if q.x >= 0 and q.y >= 0 and q.x < CELL.x and q.y < CELL.y and shade[q.y * CELL.x + q.x] >= 0:
                    col = mat_cols[shade[q.y * CELL.x + q.x]] * 0.3
        img[(cy + py) * iw + cx + px] = col

// ---- the sheet: a row of 8 facings per unit (a walk in facing 1 where asked)

class row:
    u:unit_def
    walk:bool

let units = [
    unit_def { "human worker", HUMAN, "axe", "", false, false, "" },
    unit_def { "human spearman", HUMAN, "spear", "shield", false, false, "" },
    unit_def { "human archer", HUMAN, "", "bow", false, false, "" },
    unit_def { "human swordsman", HUMAN, "sword", "shield", true, true, "" },
    unit_def { "human rider", HUMAN, "spear", "shield", true, false, "horse" },
    unit_def { "centaur", HUMAN, "spear", "shield", false, false, "centaur" },
    unit_def { "rat worker", RAT, "axe", "", false, false, "" },
    unit_def { "rat spearman", RAT, "spear", "shield", false, false, "" },
    unit_def { "frog spearman", FROG, "spear", "shield", false, false, "" },
    unit_def { "frog archer", FROG, "", "bow", false, false, "" },
    unit_def { "bear warrior", BEAR, "axe", "shield", true, true, "" },
    unit_def { "bear archer", BEAR, "", "bow", false, false, "" },
]
let rows = []::row
for(units) u, k:
    rows.push(row { u, false })
    if k == 4 or k == 7 or k == 10: rows.push(row { u, true })

let out_path = if command_line_arguments().length: command_line_arguments()[0] else: "voxel_proto.ppm"
let iw = CELL.x * 8
let ih = CELL.y * rows.length
let img = map(iw * ih): float3 { 0.33, 0.47, 0.18 }
for(rows) rw, r:
    let u = rw.u
    mat_cols[mat_skin] = u.rc.skin
    mat_cols[mat_pale] = u.rc.pale
    if not rw.walk:
        let stand = fill(unit_prims(u, 0.0), u.rc.size)
        for(8) f: draw(stand, f, img, iw, f * CELL.x, r * CELL.y)
    else:
        for(8) k: draw(fill(unit_prims(u, float(k) * 45.0), u.rc.size), 1, img, iw, k * CELL.x, r * CELL.y)
    print "{u.label}{if rw.walk: " (walking)" else: ""}: drawn"
let ppm = "P6\n{iw} {ih}\n255\n"
let bytes = []::int
for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
print "wrote {out_path}"
