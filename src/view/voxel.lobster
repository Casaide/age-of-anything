// Procedural voxel units (round 2, 2026-11-01): each creature built in code from slim capsules on a posed skeleton
// with its signature parts made big (a rat's snout, ears and long bare tail; a frog's eyes, wide mouth and crouch; a
// cat's face out in front of its rider), filled into a voxel grid at a voxel a baked pixel and drawn in the game's
// 3/4 view in 8 facings: each surface voxel splatted with a depth test, banded light, fur flecked by a hash of the
// voxel, a dark outline and a softer line where a limb crosses the body.
// The game draws them with the `voxels` option (game/voxel_units.lobster); voxel_proto.lobster draws a sheet.

let vx_ELEV = 30.0              // the camera's elevation, degrees
let vx_RES = 2.0                // voxels a body unit (a body unit is about a world pixel; a voxel a baked pixel)
let vx_CELL = int2 { int(52.0 * vx_RES), int(74.0 * vx_RES) }   // a sprite cell
let vx_ANCHOR = int2 { vx_CELL.x / 2, vx_CELL.y - int(14.0 * vx_RES) }   // the ground under the unit, in its cell
let vx_BLEND = 0.8              // how far body parts melt into each other, body units (round 1's 2.2 made muscles)

enum vx_mat_kind:
    vx_mat_skin, vx_mat_pale, vx_mat_cloth, vx_mat_leather, vx_mat_hair, vx_mat_wood, vx_mat_metal, vx_mat_coat,
    vx_mat_mane, vx_mat_team, vx_mat_eye, vx_mat_white, vx_mat_pink, vx_mat_cat, vx_mat_gold, vx_mat_mouth,
    vx_mat_tail, vx_mat_bronze, vx_mat_kilt, vx_mat_laurel, vx_mat_hide, vx_mat_trousers

let vx_MAT_BASE = [
    float3 { 0.86, 0.66, 0.50 },   // skin or fur (the race's)
    float3 { 0.92, 0.82, 0.68 },   // pale: a muzzle, a belly (the race's)
    float3 { 0.52, 0.45, 0.34 },   // undyed cloth: trousers, a frog's vest
    float3 { 0.42, 0.28, 0.16 },   // leather
    float3 { 0.12, 0.09, 0.08 },   // hair, darker than any skin
    float3 { 0.55, 0.38, 0.20 },   // wood
    float3 { 0.70, 0.72, 0.76 },   // metal
    float3 { 0.50, 0.32, 0.19 },   // a horse's coat
    float3 { 0.20, 0.14, 0.10 },   // mane and hooves
    float3 { 0.80, 0.16, 0.13 },   // team colour
    float3 { 0.07, 0.05, 0.04 },   // eyes
    float3 { 0.94, 0.92, 0.88 },   // white: eye whites, a cat's chest and paws, a bowstring
    float3 { 0.90, 0.58, 0.60 },   // pink: a rat's nose, ears' insides, hands and feet
    float3 { 0.14, 0.13, 0.15 },   // a black cat
    float3 { 0.92, 0.74, 0.20 },   // gold: a frog's or a cat's eyes
    float3 { 0.30, 0.10, 0.10 },   // a mouth
    float3 { 0.86, 0.70, 0.66 },   // a rat's bare tail
    float3 { 0.74, 0.56, 0.30 },   // bronze: a human's armour
    float3 { 0.21, 0.13, 0.12 },   // a dark kilt
    float3 { 0.33, 0.52, 0.22 },   // laurel
    float3 { 0.80, 0.62, 0.36 },   // tanned hide: leather armour (lighter than skin and kilt, to read apart)
    float3 { 0.27, 0.18, 0.16 },   // dark trousers
]
let vx_mat_cols = copy(vx_MAT_BASE)
let vx_MAT_FUR = [ 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 ]   // per material: flecked like fur
var vx_fur = 0.07               // how strongly fur is flecked (the race's: frogs are smooth)

class vx_prim:
    a:float3
    b:float3
    ra:float
    rb:float
    mat:int
    hard:bool   // gear and fine details: no melting into the body
    disc:bool   // a disc round a, facing along b - a, ra across and rb thick
    box:float3  // not zero: a box round a, these half sizes (across, thick, up), facing along b - a, edges rounded by ra

def vx_dist(p:float3, s:vx_prim) -> float:
    let ba = s.b - s.a
    if s.box.x > 0.0:
        let n = normalize(ba)
        let x = normalize(cross(n, float3 { 0.0, 0.0, 1.0 }))
        let z = cross(x, n)
        let q = p - s.a
        let d = abs(float3 { dot(q, x), dot(q, n), dot(q, z) }) - s.box
        return magnitude(max(d, float3_0)) + min(max(d.x, max(d.y, d.z)), 0.0) - s.ra
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

def vx_cap(a:float3, b:float3, ra:float, rb:float, m:int) -> vx_prim: return vx_prim { a, b, ra, rb, m, false, false, float3_0 }
def vx_hard(a:float3, b:float3, ra:float, rb:float, m:int) -> vx_prim: return vx_prim { a, b, ra, rb, m, true, false, float3_0 }
def vx_ball(c:float3, r:float, m:int) -> vx_prim: return vx_prim { c, c, r, r, m, false, false, float3_0 }
def vx_bead(c:float3, r:float, m:int) -> vx_prim: return vx_prim { c, c, r, r, m, true, false, float3_0 }
def vx_disc(c:float3, n:float3, r:float, thick:float, m:int) -> vx_prim: return vx_prim { c, c + n, r, thick, m, true, true, float3_0 }
def vx_box(c:float3, n:float3, half:float3, round:float, m:int) -> vx_prim: return vx_prim { c, c + n, round, round, m, true, false, half }

// Two bones from a towards t (lengths l1, l2), the joint bent towards pole: the joint and where the end lands.
def vx_ik(a:float3, t:float3, l1:float, l2:float, pole:float3) -> float3, float3:
    let d = t - a
    let n = normalize(d)
    let dist = min(magnitude(d), (l1 + l2) * 0.999)
    let x = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    let h = sqrt(max(l1 * l1 - x * x, 0.0))
    let side = normalize(pole - n * dot(pole, n))
    let joint = a + n * x + side * h
    return joint, joint + normalize(t - joint) * l2

// ---- races and units

class vx_race:
    kind:string     // human, rat, frog
    skin:float3
    pale:float3
    size:float      // the whole body scaled
    fur:float       // flecks

let vx_HUMAN = vx_race { "human", float3 { 0.86, 0.66, 0.50 }, float3 { 0.92, 0.75, 0.60 }, 1.15, 0.0 }
let vx_ROMAN = vx_race { "human", float3 { 0.48, 0.29, 0.16 }, float3 { 0.35, 0.20, 0.13 }, 1.15, 0.0 }   // (human_dark, as the romans)
let vx_RAT = vx_race { "rat", float3 { 0.48, 0.35, 0.25 }, float3 { 0.78, 0.66, 0.58 }, 1.0, 0.09 }   // (rat_brown)
let vx_FROG = vx_race { "frog", float3 { 0.38, 0.56, 0.22 }, float3 { 0.86, 0.84, 0.56 }, 1.15, 0.03 }

// A race's skin as drawn: a human's lighter than its palette (the composed humans light the face from within, so the
// skin reads apart from a dark kilt and hair).
def vx_skin_of(rc:vx_race) -> float3: return if rc.kind == "human": min(rc.skin * 1.3, float3_1) else: rc.skin

class vx_unit_def:
    label:string
    rc:vx_race
    right:string    // in the right hand: axe, spear, sword or ""
    left:string     // in the left: shield, bow or ""
    helm:bool
    armour:bool
    mount:string    // "", horse or cat
    helm_kind:string    // galea, or "": a plain cap
    armour_kind:string  // lorica, bronze, leather, or "": plain plate
    back:string         // quiver or ""
    coat:float3         // the mount's coat (zero: its own)

var vx_seated = false   // a rider being built: no legs or tail of its own
let vx_heads = 4.5           // a human's height in heads (Dominic picked 4.5 from 7.5, 6.5, 5.5 as the composed, 4.5)
var vx_team_wear = "scarf"   // where a creature without a tunic wears the team: scarf or vest (a concept option)
var vx_act = ""      // the pose being drawn: "" (standing or walking) or "attack", at a step through it

// How far into its blow an attack is at t: a wind-up, a fast strike, a hold, back.
def vx_blow(t:float) -> float:
    return if t < 0.45: 0.0 elif t < 0.6: (t - 0.45) / 0.15 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25

def vx_raise(t:float) -> float:   // raised through the wind-up, held, lowered
    return if t < 0.45: t / 0.45 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25

def vx_mix(a:float3, b:float3, k:float) -> float3: return a + (b - a) * k

// What a creature's upper body gives the arms and gear.
class vx_frame:
    sh_r:float3     // shoulders
    sh_l:float3
    arm:float       // each arm bone's length
    thick:float     // the upper arm's radius
    sleeve:int      // the upper arm's material
    hand:int        // the forearm's and hand's
    head_top:float3 // where a helmet sits
    head_r:float

// ---- gear

def vx_gear_right(out:[vx_prim], kind:string, hand:float3, d:float3):
    switch kind:
        case "axe":
            let top = hand + d * 9.0
            out.push(vx_hard(hand - d * 2.0, top, 0.5, 0.5, vx_mat_wood))
            let fwd = normalize(cross(d, float3 { 1.0, 0.0, 0.0 })) * -1.0   // the blade: flat, out the front of the shaft
            out.push(vx_hard(top - d * 0.8, top + fwd * 1.2 - d * 0.8, 0.6, 0.6, vx_mat_metal))
            out.push(vx_disc(top + fwd * 2.0 - d * 0.9, float3 { 1.0, 0.0, 0.0 }, 2.2, 0.3, vx_mat_metal))
        case "spear":
            out.push(vx_hard(hand - d * 8.0, hand + d * 18.0, 0.5, 0.5, vx_mat_wood))
            out.push(vx_hard(hand + d * 18.0, hand + d * 22.5, 0.95, 0.1, vx_mat_metal))
        case "pike":
            out.push(vx_hard(hand - d * 11.0, hand + d * 25.0, 0.5, 0.5, vx_mat_wood))
            out.push(vx_hard(hand + d * 25.0, hand + d * 29.0, 0.9, 0.1, vx_mat_metal))
        case "pilum":   // a heavy javelin: a wooden shaft, a long thin iron shank, a small point
            out.push(vx_hard(hand - d * 6.0, hand + d * 11.0, 0.55, 0.5, vx_mat_wood))
            out.push(vx_bead(hand + d * 11.0, 0.8, vx_mat_metal))
            out.push(vx_hard(hand + d * 11.0, hand + d * 18.5, 0.25, 0.25, vx_mat_metal))
            out.push(vx_hard(hand + d * 18.5, hand + d * 20.0, 0.6, 0.1, vx_mat_metal))
        case "club", "bone_club":   // thickening to the end
            out.push(vx_hard(hand - d * 1.5, hand + d * 8.0, 0.5, 1.3, if kind == "club": vx_mat_wood else: vx_mat_white))
        case "staff":   // a tall staff with a laurel at the top
            out.push(vx_hard(hand - d * 9.0, hand + d * 13.0, 0.5, 0.45, vx_mat_wood))
            for([ -1.0, 1.0 ]) side: out.push(vx_ball(hand + d * 13.0 + float3 { side * 0.9, 0.0, 0.3 }, 1.0, vx_mat_laurel))
        case "gladius":   // a short broad blade, made bigger than life to read: a bronze guard, a round pommel
            out.push(vx_bead(hand - d * 1.5, 0.75, vx_mat_bronze))
            out.push(vx_hard(hand - d * 1.2, hand + d * 0.9, 0.45, 0.45, vx_mat_leather))
            out.push(vx_box(hand + d * 1.1, d, float3 { 1.3, 0.35, 0.3 }, 0.1, vx_mat_bronze))
            out.push(vx_hard(hand + d * 1.5, hand + d * 8.5, 0.75, 0.6, vx_mat_metal))
            out.push(vx_hard(hand + d * 8.5, hand + d * 9.6, 0.6, 0.1, vx_mat_metal))
        case "sword":
            let x = float3 { 1.4, 0.0, 0.0 }
            out.push(vx_hard(hand - x + d * 0.8, hand + x + d * 0.8, 0.45, 0.45, vx_mat_metal))
            out.push(vx_hard(hand + d * 0.8, hand + d * 9.0, 0.6, 0.25, vx_mat_metal))
        case "": return
        default: assert false

def vx_gear_left(out:[vx_prim], kind:string, hand:float3, string_hand:float3, drawn:bool):
    switch kind:
        case "shield":   // a round shield, its face in team colour, a wooden rim, a boss
            let n = normalize(float3 { -0.35, 1.0, 0.0 })
            let face = hand + n * 0.8
            out.push(vx_disc(face, n, 4.6, 0.4, vx_mat_wood))
            out.push(vx_disc(face + n * 0.35, n, 3.7, 0.2, vx_mat_team))
            out.push(vx_bead(face + n * 0.7, 1.0, vx_mat_metal))
        case "scutum":   // a tall curved shield: three panels in team colour on a wooden back, a boss, a gold bar
            let n = normalize(float3 { -0.3, 1.0, 0.0 })
            let x = normalize(cross(n, float3 { 0.0, 0.0, 1.0 }))
            let c = hand + n * 1.0 + float3 { 0.0, 0.0, 1.8 }
            let half = float3 { 2.8, 0.3, 8.8 }
            out.push(vx_box(c - n * 0.25, n, half + float3 { 0.2, 0.0, 0.3 }, 0.15, vx_mat_wood))
            out.push(vx_box(c, n, half, 0.1, vx_mat_team))
            for([ -1.0, 1.0 ]) side:
                let ns = normalize(n * 0.87 - x * side * 0.5)   // the sides curved back
                let cs = c + x * side * 4.1 - n * 0.75
                out.push(vx_box(cs - ns * 0.25, ns, float3 { 1.5, 0.3, 9.1 }, 0.15, vx_mat_wood))
                out.push(vx_box(cs, ns, float3 { 1.4, 0.3, 8.8 }, 0.1, vx_mat_team))
            out.push(vx_bead(c + n * 0.5, 1.4, vx_mat_metal))
            out.push(vx_hard(c + n * 0.45 + float3 { 0.0, 0.0, 2.6 }, c + n * 0.45 + float3 { 0.0, 0.0, 7.6 }, 0.35, 0.35, vx_mat_gold))
            out.push(vx_hard(c + n * 0.45 - float3 { 0.0, 0.0, 2.6 }, c + n * 0.45 - float3 { 0.0, 0.0, 7.6 }, 0.35, 0.35, vx_mat_gold))
        case "bow":
            let top = hand + float3 { 0.0, 0.0, 7.5 }
            let bot = hand + float3 { 0.0, 0.0, -7.5 }
            var last = bot
            for(6) k:
                let t = float(k + 1) / 6.0 * 2.0 - 1.0
                let p = hand + float3 { 0.0, 1.6 * (1.0 - t * t), 7.5 * t }
                out.push(vx_hard(last, p, 0.5, 0.5, vx_mat_wood))
                last = p
            let back = if drawn: string_hand else: hand + float3 { 0.0, -0.4, 0.0 }
            out.push(vx_hard(top, back, 0.15, 0.15, vx_mat_white))
            out.push(vx_hard(bot, back, 0.15, 0.15, vx_mat_white))
        case "": return
        default: assert false

// The arms and what's in the hands, posed by the kit and the act. L: an arm bone's length (the reach is 2L).
def vx_arms(out:[vx_prim], u:vx_unit_def, fr:vx_frame, swing:float, t:float):
    let L = fr.arm * 2.0
    let k = vx_blow(t)
    let up = vx_raise(t)
    let attack = vx_act == "attack"
    var hr = fr.sh_r + float3 { 0.15, 0.1 + swing * 0.18, -0.92 } * L   // hanging, swung
    var dr = float3 { 0.0, 0.12, 1.0 }
    var hl = fr.sh_l + float3 { -0.15, 0.1 - swing * 0.18, -0.92 } * L
    var drawn = false
    switch u.right:
        case "spear", "pike", "pilum", "staff":
            hr = fr.sh_r + float3 { 0.25, 0.45, -0.55 } * L
            dr = float3 { 0.0, 0.12, 1.0 }
            if attack:   // drawn back, then thrust level
                hr = vx_mix(vx_mix(hr, fr.sh_r + float3 { 0.3, -0.25, -0.35 } * L, up), fr.sh_r + float3 { 0.15, 0.95, -0.1 } * L, k)
                dr = vx_mix(vx_mix(dr, float3 { 0.0, 0.5, 1.0 }, up), float3 { 0.0, 1.0, 0.06 }, k)
        case "axe", "sword", "gladius", "club", "bone_club":
            hr = fr.sh_r + float3 { 0.25, 0.5, -0.6 } * L
            dr = if u.right == "gladius": float3 { 0.0, 0.8, 0.35 } else: float3 { 0.0, 0.85, 0.6 }
            if attack:   // up over the head, then down through the arm held out
                hr = vx_mix(vx_mix(hr, fr.sh_r + float3 { 0.15, -0.1, 0.85 } * L, up), fr.sh_r + float3 { 0.15, 0.85, -0.35 } * L, k)
                dr = vx_mix(vx_mix(dr, float3 { 0.0, -0.7, 0.7 }, up), float3 { 0.0, 0.6, -0.8 }, k)
    switch u.left:
        case "shield": hl = fr.sh_l + float3 { -0.3, 0.55, -0.5 } * L
        case "scutum": hl = fr.sh_l + float3 { -0.05, 0.5, -0.62 } * L
        case "bow":
            hl = fr.sh_l + float3 { -0.3, 0.5, -0.55 } * L
            if attack:   // raised and drawn, loosed
                hl = vx_mix(hl, fr.sh_l + float3 { 0.25, 0.95, 0.05 } * L, up)
                hr = vx_mix(hr, fr.sh_r + float3 { -0.15, 0.1, 0.0 } * L, up * (1.0 - k))
                drawn = up * (1.0 - k) > 0.5
    for([ 1.0, -1.0 ]) side:
        let sh = if side > 0.0: fr.sh_r else: fr.sh_l
        let target = if side > 0.0: hr else: hl
        let elbow, hand = vx_ik(sh, target, fr.arm, fr.arm, float3 { side * 0.5, -1.0, -0.4 })
        out.push(vx_cap(sh, elbow, fr.thick, fr.thick * 0.8, fr.sleeve))
        out.push(vx_cap(elbow, hand, fr.thick * 0.75, fr.thick * 0.6, fr.hand))
        out.push(vx_ball(hand, fr.thick * 0.8, fr.hand))
        if side > 0.0: hr = hand
        else: hl = hand
    vx_gear_right(out, u.right, hr, normalize(dr))
    vx_gear_left(out, u.left, hl, hr, drawn)

// A helmet: a cap over the top of the skull, head sized, no brim (Dominic: "Helmets should just be head sized").
// The frame's head_top is the cap's centre, head_r its radius: the skull's, a little more.
def vx_helm(out:[vx_prim], fr:vx_frame):
    out.push(vx_hard(fr.head_top, fr.head_top + float3 { 0.0, -0.15, 0.15 }, fr.head_r, fr.head_r, vx_mat_metal))

// A scarf at the neck in team colour: the team on creatures that wear no tunic.
def vx_scarf(out:[vx_prim], c:float3, r:float, tilt:float):
    var last = float3_0
    for(9) k:
        let a = float(k) * 45.0
        let p = c + float3 { sin(a) * r, cos(a) * r, -cos(a) * tilt }
        if k > 0: out.push(vx_hard(last, p, 0.9, 0.9, vx_mat_team))
        last = p
    out.push(vx_hard(c + float3 { 0.6, r, -tilt }, c + float3 { 1.0, r + 0.6, -tilt - 2.6 }, 0.9, 0.6, vx_mat_team))   // its knot

// ---- creatures (z up, y forward, x right; body units, the ground at z 0)

// A leg from the hip to a foot planted at `foot`, the joint bent towards `pole` (a knee forward; a beast's front
// leg's elbow back), a boot or bare foot forward of it.
def vx_leg(out:[vx_prim], hip:float3, foot:float3, l1:float, l2:float, r:float, m:int, boot:int, flen:float, pole:float3):
    let knee, ankle = vx_ik(hip, foot, l1, l2, pole)
    out.push(vx_cap(hip, knee, r, r * 0.8, m))
    out.push(vx_cap(knee, ankle, r * 0.8, r * 0.6, boot))
    out.push(vx_cap(ankle, ankle + float3 { 0.0, flen, -0.3 }, r * 0.6, r * 0.55, boot))

// A human, a soldier's build: sturdy limbs, a waist narrower than the shoulders, a tunic in team colour (Dominic,
// round 1) showing as short sleeves and a hem; armour by kind (lorica bands, a bronze cuirass, leather), leather strips
// over the skirt, bare shins in short boots, a head in proportion. A galea: a bowl with a brow, cheek guards, a neck
// guard and a crest in team colour.
def vx_human(out:[vx_prim], u:vx_unit_def, ph:float) -> vx_frame:
    // the composed heroic human's measurements (model/units.lobster, D-173), 5.5 heads: the top of the head at 38.8,
    // hips at 18 (the knee 9 under them, the ankle 2.3 over the sole), shoulders at 29.3 and 4.7 out, the neck at
    // 31.6; at vx_heads' count the height is kept and the head, the legs and the build scale from it
    let hh = 38.8 / vx_heads   // the head's height
    let hs = hh / 4.9 * 0.9    // the head's scale against the build these head sizes were first drawn at
    let bs = 0.85 + 0.15 * hs  // the limbs' and body's
    let hipz = hh * (3.93 - (7.5 - vx_heads) * 0.69)
    let s = sin(ph)
    let hip = float3 { 0.0, 0.0, hipz + 0.5 * abs(sin(ph * 2.0)) }
    if not vx_seated:
        for([ -1.0, 1.0 ]) side:
            let st = s * side * 4.6
            let lift = max(0.0, cos(ph) * side) * 2.2
            let h = hip + float3 { side * 1.6 * bs, 0.0, 0.0 }
            let knee, ankle = vx_ik(h, float3 { side * 1.8 * bs, st, 2.3 + lift }, (hipz - 2.3) * 0.5 + 0.06, (hipz - 2.3) * 0.5 + 0.06, float3 { 0.0, 1.0, 0.0 })
            out.push(vx_cap(h, knee, 1.75 * bs, 1.4 * bs, vx_mat_trousers))   // dark trousers, as the composed humans wear
            out.push(vx_cap(knee, ankle, 1.4 * bs, 0.95 * bs, vx_mat_trousers))
            out.push(vx_hard(ankle + float3 { 0.0, 0.0, 1.8 }, ankle - float3 { 0.0, 0.0, 1.0 }, 1.1 * bs, 1.05 * bs, vx_mat_leather))   // a short boot
            out.push(vx_hard(ankle - float3 { 0.0, 0.0, 1.2 }, ankle + float3 { 0.0, 2.4 * bs, -1.5 }, 1.0 * bs, 0.9 * bs, vx_mat_leather))
    let chest = float3 { 0.0, 0.5, 38.8 - hh * 1.35 + 0.5 * abs(sin(ph * 2.0)) }
    // an undyed tunic, bare arms, a dark kilt with its hem in team colour (Dominic, 2026-11-01: less red)
    out.push(vx_disc(hip + float3 { 0.0, 0.2, -0.7 }, float3 { 0.0, 0.08, 1.0 }, 2.6 * bs, 2.6, vx_mat_kilt))
    out.push(vx_disc(hip + float3 { 0.0, 0.42, -3.0 }, float3 { 0.0, 0.08, 1.0 }, 3.05 * bs, 0.65, vx_mat_team))   // the hem, out past the strips
    out.push(vx_cap(hip + float3 { 0.0, 0.0, 1.0 }, chest, 2.2 * bs, 2.75 * bs, vx_mat_cloth))
    out.push(vx_cap(chest + float3 { -3.5 * bs, 0.0, -0.1 }, chest + float3 { 3.5 * bs, 0.0, -0.1 }, 1.6 * bs, 1.6 * bs, vx_mat_cloth))   // the shoulders
    if u.back == "quiver":   // across the back, arrows' feathers out of the top
        let qt = chest + float3 { 1.6, -2.7, 1.8 }
        let qb = chest + float3 { -1.2, -2.5, -6.0 }
        out.push(vx_hard(qt, qb, 1.1, 0.95, vx_mat_leather))
        for([ -0.5, 0.5 ]) dx: out.push(vx_bead(qt + float3 { dx, 0.0, 1.0 }, 0.55, vx_mat_white))
    out.push(vx_disc(hip + float3 { 0.0, 0.1, 1.9 }, float3 { 0.0, 0.0, 1.0 }, 2.5 * bs, 0.45, vx_mat_leather))   // a belt
    if u.armour:
        for(11) k:   // leather strips over the skirt, the hem showing under them
            let a = float(k) * 32.7 - 163.5
            out.push(vx_hard(hip + float3 { sin(a) * 2.3 * bs, cos(a) * 2.3 * bs, 1.4 }, hip + float3 { sin(a) * 2.7 * bs, cos(a) * 2.7 * bs, -1.9 }, 0.5, 0.5, vx_mat_leather))
        switch u.armour_kind:
            case "lorica":   // bands of iron round the body over dark leather, curved plates over the shoulders
                out.push(vx_hard(hip + float3 { 0.0, 0.2, 2.8 }, chest + float3 { 0.0, 0.0, -0.3 }, 2.35 * bs, 2.85 * bs, vx_mat_mouth))
                for(6) k:
                    let t = (float(k) + 0.5) / 6.0
                    let c = hip + float3 { 0.0, 0.2, 2.8 } + (chest + float3 { 0.0, 0.0, -1.4 } - hip - float3 { 0.0, 0.2, 2.8 }) * t
                    out.push(vx_disc(c, float3 { 0.0, 0.06, 1.0 }, (2.35 + 0.5 * t) * bs + 0.12, 0.42, vx_mat_metal))
                for([ -1.0, 1.0 ]) side:   // a plate curved over each shoulder
                    out.push(vx_hard(chest + float3 { side * 2.9 * bs, 1.1, 0.3 }, chest + float3 { side * 2.9 * bs, -1.1, 0.3 }, 1.15 * bs, 1.15 * bs, vx_mat_metal))
            case "bronze":   // a bronze cuirass, leather shoulder guards
                out.push(vx_hard(hip + float3 { 0.0, 0.2, 2.8 }, chest + float3 { 0.0, 0.0, -0.3 }, 2.45 * bs, 2.95 * bs, vx_mat_bronze))
                for([ -1.0, 1.0 ]) side: out.push(vx_hard(chest + float3 { side * 3.0 * bs, 0.0, 0.0 }, chest + float3 { side * 3.5 * bs, 0.0, -1.3 }, 1.4 * bs, 1.25 * bs, vx_mat_leather))
            default:   // leather (or plain plate)
                out.push(vx_hard(hip + float3 { 0.0, 0.2, 2.8 }, chest + float3 { 0.0, 0.0, -0.3 }, 2.45 * bs, 2.95 * bs, if u.armour_kind == "leather": vx_mat_hide else: vx_mat_metal))
    let h = float3 { 0.0, 1.2, 38.8 - 2.8 * hs }   // the head's centre
    let neck = h - float3 { 0.0, 0.4, 2.4 } * hs
    out.push(vx_cap(chest, neck, 1.3 * bs, 1.2 * bs, vx_mat_skin))
    out.push(vx_cap(h + float3 { 0.0, 0.5, -1.0 } * hs, h + float3 { 0.0, -0.1, 0.5 } * hs, 2.0 * hs, 2.3 * hs, vx_mat_skin))
    out.push(vx_cap(h + float3 { 0.0, 2.3, -0.1 } * hs, h + float3 { 0.0, 2.65, -0.7 } * hs, 0.55 * hs, 0.5 * hs, vx_mat_skin))   // the nose
    for([ -1.0, 1.0 ]) side:
        out.push(vx_bead(h + float3 { side * 0.85, 2.15, 0.3 } * hs, 0.35, vx_mat_eye))   // an eye: a dark pixel at game size, no white
        if u.helm_kind != "galea": out.push(vx_ball(h + float3 { side * 2.35, -0.1, -0.2 } * hs, 0.6 * hs, vx_mat_skin))   // ears
    if u.helm_kind == "galea":
        // (head sized, seen from any side: the bowl hugs the skull, the neck guard sits close, the crest is narrow;
        // Dominic: "from behind always look too large", "helmets should just be head sized")
        out.push(vx_hard(h + float3 { 0.0, -0.3, 0.8 } * hs, h + float3 { 0.0, -0.35, 0.95 } * hs, 2.15 * hs, 2.15 * hs, vx_mat_metal))   // the bowl, the face open
        out.push(vx_hard(h + float3 { 0.0, -1.7, -0.2 } * hs, h + float3 { 0.0, -1.85, -0.9 } * hs, 0.9 * hs, 0.8 * hs, vx_mat_metal))   // the neck guard, close
        // (no brow band or cheek guards: at this size they framed the eyes like goggles and stuck out past the
        // head; Dominic: "silver sticking out the sides of the head?")
        for(5) k:   // a small crest, front to back over the top
            let a = float(k) * 30.0 - 60.0
            out.push(vx_bead(h + float3 { 0.0, sin(a) * 1.7 - 0.35, 2.8 + cos(a) * 0.55 } * hs, 0.5 * hs, vx_mat_team))
    elif not u.helm:   // hair: a crown down to just above the eyes, and down the back of the head
        out.push(vx_bead(h + float3 { 0.0, -0.25, 1.3 } * hs, 2.3 * hs, vx_mat_hair))   // short, close to the skull
        out.push(vx_bead(h + float3 { 0.0, -0.6, 0.2 } * hs, 2.35 * hs, vx_mat_hair))
    return vx_frame { chest + float3 { 4.3 * bs, 0.0, -0.4 }, chest + float3 { -4.3 * bs, 0.0, -0.4 }, (chest.z - hip.z) * 0.52, 1.35 * bs, vx_mat_skin, vx_mat_skin,
                      h + float3 { 0.0, -0.25, 1.35 } * hs, 2.1 * hs }

// A rat: a small hunched body, pear-shaped (narrow shoulders over a round belly and big haunches), thin shins on
// pink feet, a long pointed snout with a pink nose, big round ears pink inside, a beady eye, and a long bare tail
// trailing on the ground. No tunic: the team is its scarf (and its shield).
def vx_rat(out:[vx_prim], u:vx_unit_def, ph:float) -> vx_frame:
    let s = sin(ph)
    let bob = 0.5 * abs(sin(ph * 2.0))
    let pelvis = float3 { 0.0, -1.5, 8.6 + bob }
    if not vx_seated: for([ -1.0, 1.0 ]) side:
        let hip = pelvis + float3 { side * 2.3, 0.0, -0.5 }
        let st = s * side * 5.5
        let lift = max(0.0, cos(ph) * side) * 2.4   // (lifted while it swings forward)
        let knee = hip + float3 { side * 0.6, 4.0 + st * 0.5, -3.4 + lift * 0.5 }   // the haunch forward to the knee
        let ankle = float3 { side * 2.6, -1.6 + st, 1.6 + lift }                     // the shin back down
        out.push(vx_cap(hip, knee, 3.0, 1.5, vx_mat_skin))
        out.push(vx_cap(knee, ankle, 1.0, 0.7, vx_mat_skin))
        out.push(vx_cap(ankle, ankle + float3 { side * 0.2, 3.4, -1.0 }, 0.7, 0.6, vx_mat_pink))
    let chest = float3 { 0.0, 4.6, 14.6 + bob }   // hunched: the shoulders well forward of the hips
    out.push(vx_cap(pelvis, chest, 4.0, 2.4, vx_mat_skin))
    out.push(vx_cap(pelvis + float3 { 0.0, 1.8, 0.6 }, chest + float3 { 0.0, 0.6, -2.2 }, 3.0, 1.8, vx_mat_pale))   // the belly
    // the tail: out from the rump, down to the ground and trailing back in a long S
    var last = pelvis + float3 { 0.0, -3.2, -0.6 }
    var r = 1.0
    if not vx_seated: for([ float3 { 0.0, -3.5, -2.6 }, float3 { 0.5, -6.5, -4.6 }, float3 { 2.0, -9.5, -5.5 }, float3 { 3.8, -12.5, -5.8 },
          float3 { 4.4, -16.0, -5.8 }, float3 { 3.4, -19.5, -5.6 }, float3 { 1.6, -22.5, -5.0 } ]) d, k:
        let p = pelvis + d
        out.push(vx_cap(last, p, r, r - 0.1, if k == 0: vx_mat_skin else: vx_mat_tail))
        last = p
        r = max(0.35, r - 0.11)
    // the head: a skull forward of the shoulders, a long tapered snout, a pink nose
    let h = chest + float3 { 0.0, 2.8, 2.2 }
    out.push(vx_cap(chest + float3 { 0.0, 0.2, 0.4 }, h, 2.0, 1.9, vx_mat_skin))
    out.push(vx_cap(h + float3 { 0.0, -0.4, 0.2 }, h + float3 { 0.0, 0.9, 0.0 }, 2.3, 2.1, vx_mat_skin))
    out.push(vx_cap(h + float3 { 0.0, 1.2, -0.3 }, h + float3 { 0.0, 6.4, -1.6 }, 1.75, 0.55, vx_mat_skin))
    out.push(vx_cap(h + float3 { 0.0, 1.4, -1.4 }, h + float3 { 0.0, 5.0, -2.2 }, 1.1, 0.45, vx_mat_pale))   // the chin
    out.push(vx_bead(h + float3 { 0.0, 6.7, -1.65 }, 0.85, vx_mat_pink))
    for([ -1.0, 1.0 ]) side:
        out.push(vx_bead(h + float3 { side * 1.4, 2.4, 0.65 }, 0.42, vx_mat_eye))
        // a big round ear, turned out and forward, pink inside
        let ec = h + float3 { side * 2.4, -0.8, 2.6 }
        let en = normalize(float3 { side * 0.6, 1.0, 0.25 })
        out.push(vx_disc(ec, en, 2.3, 0.35, vx_mat_skin))
        out.push(vx_disc(ec + en * 0.3, en, 1.6, 0.15, vx_mat_pink))
    if vx_team_wear == "vest": out.push(vx_hard(pelvis + (chest - pelvis) * 0.35 + float3 { 0.0, 0.2, 0.4 }, chest + float3 { 0.0, -0.2, -0.2 }, 3.75, 2.75, vx_mat_team))
    else: vx_scarf(out, chest + float3 { 0.0, 0.6, 0.6 }, 2.1, 0.5)
    if u.armour: out.push(vx_hard(pelvis + float3 { 0.0, 1.0, 2.2 }, chest + float3 { 0.0, 0.2, -1.4 }, 3.5, 2.6, vx_mat_metal))
    return vx_frame { chest + float3 { 2.2, 0.2, -0.6 }, chest + float3 { -2.2, 0.2, -0.6 }, 3.8, 0.9, vx_mat_skin, vx_mat_pink,
                      h + float3 { 0.0, 0.2, 1.0 }, 2.0 }

// A frog: a squat round body tipped up at the front, on folded hind legs (knees out, long webbed feet) and thin
// front legs, a wide flat head with a mouth seam and two big gold eyes on top. Smooth skin; a pale throat.
def vx_frog(out:[vx_prim], u:vx_unit_def, ph:float) -> vx_frame:
    let s = sin(ph)
    let bob = 0.8 * abs(sin(ph * 2.0))
    let rump = float3 { 0.0, -3.0, 5.4 + bob }
    let front = float3 { 0.0, 1.8, 7.6 + bob }
    out.push(vx_cap(rump, front, 4.4, 3.9, vx_mat_skin))
    out.push(vx_cap(rump + float3 { -1.8, 2.0, 0.6 }, rump + float3 { 1.8, 2.0, 0.6 }, 4.4, 4.4, vx_mat_skin))   // wide
    out.push(vx_cap(rump + float3 { 0.0, 2.0, -1.2 }, front + float3 { 0.0, 0.9, -1.6 }, 3.4, 2.9, vx_mat_pale))   // the belly
    if not vx_seated: for([ -1.0, 1.0 ]) side:
        let st = s * side * 2.0
        let hip = rump + float3 { side * 3.2, 0.0, -1.0 }
        let knee = float3 { side * 7.6, 1.4 + st, 5.0 + max(0.0, st) * 0.6 }   // folded: knees up and out past the body
        let ankle = float3 { side * 5.6, -3.4 + st, 1.2 }
        out.push(vx_cap(hip, knee, 2.5, 1.8, vx_mat_skin))
        out.push(vx_cap(knee, ankle, 1.6, 1.0, vx_mat_skin))
        for([ -0.6, 0.0, 0.6 ]) toe:
            out.push(vx_cap(ankle, ankle + float3 { side * 0.8 + toe * 1.6, 4.4, -0.5 }, 0.6, 0.5, vx_mat_skin))
    let h = front + float3 { 0.0, 3.2, 1.4 }
    out.push(vx_cap(h + float3 { -2.0, 0.0, 0.0 }, h + float3 { 2.0, 0.0, 0.0 }, 3.0, 3.0, vx_mat_skin))
    out.push(vx_cap(h + float3 { -1.6, 0.4, -1.4 }, h + float3 { 1.6, 0.4, -1.4 }, 2.3, 2.3, vx_mat_pale))   // the throat
    out.push(vx_hard(h + float3 { -3.4, 1.9, -0.9 }, h + float3 { 3.4, 1.9, -0.9 }, 0.3, 0.3, vx_mat_mouth))  // the mouth
    for([ -1.0, 1.0 ]) side:
        let e = h + float3 { side * 2.5, 0.6, 3.2 }   // big eyes, bulging up off the top of the head
        out.push(vx_ball(e, 2.1, vx_mat_skin))
        out.push(vx_bead(e + float3 { side * 0.2, 0.9, 0.5 }, 1.65, vx_mat_gold))
        out.push(vx_hard(e + float3 { side * 0.0, 2.3, 0.6 }, e + float3 { side * 0.7, 2.3, 0.6 }, 0.6, 0.6, vx_mat_eye))
    vx_scarf(out, front + float3 { 0.0, 1.6, 0.2 }, 3.2, 0.8)
    if u.armour: out.push(vx_hard(rump + float3 { 0.0, 0.0, 1.0 }, front + float3 { 0.0, -0.6, 0.8 }, 4.0, 3.5, vx_mat_metal))
    return vx_frame { front + float3 { 3.3, 1.2, -0.4 }, front + float3 { -3.3, 1.2, -0.4 }, 4.2, 1.0, vx_mat_skin, vx_mat_skin,
                      h + float3 { 0.0, -1.0, 1.9 }, 1.7 }

// A horse to ride; returns where its rider sits.
def vx_horse(out:[vx_prim], ph:float) -> float3:
    let front = float3 { 0.0, 7.5, 20.0 }
    let back = float3 { 0.0, -8.5, 20.5 }
    out.push(vx_cap(back, front, 5.4, 5.8, vx_mat_coat))
    out.push(vx_hard(back + float3 { 0.0, -1.5, 1.5 }, back + float3 { 0.0, -5.5, -6.0 }, 1.3, 0.8, vx_mat_mane))
    let s = sin(ph)
    for([ -1.0, 1.0 ]) side:
        for([ front + float3 { side * 3.0, 1.0, -2.0 }, back + float3 { side * 3.2, -1.0, -2.0 } ]) hip, k:
            let st = s * side * (if k == 0: 4.0 else: -4.0)
            let lift = max(0.0, (if k == 0: -s else: s) * side) * 2.0
            vx_leg(out, hip, float3 { hip.x, hip.y + st, 1.0 + lift }, if k == 0: 8.4 else: 9.0, if k == 0: 8.8 else: 9.5, 2.0, vx_mat_coat, vx_mat_mane, 1.0,
                   float3 { 0.0, if k == 0: -1.0 else: 1.0, 0.0 })
    let top = front + float3 { 0.0, 8.0, 9.0 }
    out.push(vx_cap(front + float3 { 0.0, 1.0, 2.0 }, top, 3.2, 2.0, vx_mat_coat))
    out.push(vx_hard(top + float3 { 0.0, -1.2, 0.8 }, front + float3 { 0.0, 0.5, 6.0 }, 0.9, 0.9, vx_mat_mane))
    out.push(vx_cap(top, top + float3 { 0.0, 4.6, -3.2 }, 2.0, 1.4, vx_mat_coat))
    for([ -1.0, 1.0 ]) side:
        out.push(vx_bead(top + float3 { side * 1.5, 1.4, 0.4 }, 0.45, vx_mat_eye))
        out.push(vx_cap(top + float3 { side * 1.0, -0.6, 1.6 }, top + float3 { side * 1.1, -0.4, 3.4 }, 0.7, 0.35, vx_mat_coat))
    return float3 { 0.0, -1.0, 27.0 }

// A cat to ride (black, white chest, muzzle and paws): its head held low and well out in front so the rider
// never hides its face; big ears, gold eyes, a pink nose, a tail curled up behind.
def vx_cat(out:[vx_prim], ph:float) -> float3:
    let front = float3 { 0.0, 5.0, 13.5 }
    let back = float3 { 0.0, -7.0, 14.0 }
    out.push(vx_cap(back, front, 4.4, 4.6, vx_mat_cat))
    out.push(vx_ball(front + float3 { 0.0, 2.2, -2.0 }, 3.2, vx_mat_white))   // the chest
    let s = sin(ph)
    for([ -1.0, 1.0 ]) side:
        for([ front + float3 { side * 2.6, 1.0, -2.5 }, back + float3 { side * 2.8, -1.0, -2.5 } ]) hip, k:
            let st = s * side * (if k == 0: 3.4 else: -3.4)
            let lift = max(0.0, (if k == 0: -s else: s) * side) * 1.8
            // front legs near straight, the elbow back; hind legs with the knee forward
            vx_leg(out, hip, float3 { hip.x, hip.y + st + (if k == 0: 0.0 else: -1.0), 0.9 + lift }, if k == 0: 5.1 else: 6.0, if k == 0: 5.3 else: 6.5,
                   1.6, vx_mat_cat, vx_mat_cat, 0.0, float3 { 0.0, if k == 0: -1.0 else: 1.0, 0.0 })
            let paw = float3 { hip.x, hip.y + st + (if k == 0: 0.5 else: -0.5), 0.9 + lift }
            out.push(vx_ball(paw, 1.3, vx_mat_white))
    var last = back + float3 { 0.0, -3.5, 1.0 }
    for([ float3 { 0.0, -7.0, 4.0 }, float3 { 0.0, -8.0, 8.5 }, float3 { 0.0, -7.0, 12.0 }, float3 { 0.0, -5.0, 13.5 } ]) d:
        let p = back + d
        out.push(vx_cap(last, p, 1.3, 1.1, vx_mat_cat))
        last = p
    let head = front + float3 { 0.0, 7.6, 1.6 }
    out.push(vx_cap(front + float3 { 0.0, 1.5, 1.2 }, head + float3 { 0.0, -1.2, -0.4 }, 3.2, 2.8, vx_mat_cat))
    out.push(vx_ball(head, 4.0, vx_mat_cat))
    out.push(vx_ball(head + float3 { 0.0, 3.0, -1.5 }, 2.2, vx_mat_white))   // the muzzle
    out.push(vx_bead(head + float3 { 0.0, 5.0, -0.8 }, 0.8, vx_mat_pink))
    for([ -1.0, 1.0 ]) side:
        out.push(vx_bead(head + float3 { side * 1.7, 3.2, 0.8 }, 1.05, vx_mat_gold))
        out.push(vx_bead(head + float3 { side * 1.8, 4.0, 0.9 }, 0.5, vx_mat_eye))
        let ear = head + float3 { side * 2.2, 0.0, 2.6 }
        out.push(vx_cap(ear, ear + float3 { side * 0.7, 0.2, 3.4 }, 1.5, 0.25, vx_mat_cat))
        out.push(vx_hard(ear + float3 { 0.0, 0.7, 0.3 }, ear + float3 { side * 0.6, 0.8, 2.6 }, 0.8, 0.15, vx_mat_pink))
    return float3 { 0.0, -3.5, 17.8 }

let vx_CAT_SIZE = 1.45

def vx_body(out:[vx_prim], u:vx_unit_def, ph:float) -> vx_frame:
    return switch u.rc.kind:
        case "rat": vx_rat(out, u, ph)
        case "frog": vx_frog(out, u, ph)
        default: vx_human(out, u, ph)

// A whole unit's parts, walking at phase ph0 (degrees) or, when acting, at ph0 / 360 through the act.
def vx_unit_prims(u:vx_unit_def, ph0:float) -> [vx_prim]:
    let out = []::vx_prim
    let ph = if vx_act == "": ph0 else: 0.0
    let t = ph0 / 360.0
    if u.mount == "":
        let fr = vx_body(out, u, ph)
        if u.helm and u.helm_kind != "galea": vx_helm(out, fr)
        vx_arms(out, u, fr, sin(ph), t)
        return out
    // a rider: the mount walks (in its own coat), the rider sits astride, legs down its sides
    vx_mat_cols[vx_mat_coat] = if u.coat != float3_0: u.coat else: vx_MAT_BASE[vx_mat_coat]
    vx_mat_cols[vx_mat_mane] = if u.coat != float3_0: u.coat * 0.45 else: vx_MAT_BASE[vx_mat_mane]
    var seat = float3_0
    if u.mount == "cat":   // a big cat, its rider rat-sized
        let cat = []::vx_prim
        seat = vx_cat(cat, ph) * vx_CAT_SIZE
        for(cat) p: out.push(vx_prim { p.a * vx_CAT_SIZE, p.b * vx_CAT_SIZE, p.ra * vx_CAT_SIZE, p.rb * vx_CAT_SIZE, p.mat, p.hard, p.disc, p.box * vx_CAT_SIZE })
    else: seat = vx_horse(out, ph)
    let rider = []::vx_prim
    vx_seated = true
    let fr = vx_body(rider, u, 0.0)
    vx_seated = false
    let wide = if u.mount == "cat": 4.6 * vx_CAT_SIZE else: 5.4
    let lift = seat - float3 { 0.0, 0.0, if u.rc.kind == "rat": 9.0 elif u.rc.kind == "frog": 5.8 else: 20.5 }
    for(rider) p: out.push(vx_prim { p.a + lift, p.b + lift, p.ra, p.rb, p.mat, p.hard, p.disc, p.box })   // raised onto the seat
    let lm = if u.rc.kind == "human": vx_mat_cloth else: vx_mat_skin
    let foot = if u.rc.kind == "human": vx_mat_leather else: vx_mat_pink
    for([ -1.0, 1.0 ]) side:
        let hip = seat + float3 { side * 2.0, 0.0, 0.6 }
        let knee = seat + float3 { side * wide, 3.4, -3.6 }
        let ankle = knee + float3 { 0.0, -0.8, -5.0 }
        out.push(vx_cap(hip, knee, 2.0, 1.7, lm))
        out.push(vx_cap(knee, ankle, 1.4, 1.1, lm))
        out.push(vx_cap(ankle, ankle + float3 { 0.0, 2.0, -0.4 }, 1.1, 1.0, foot))
    let fr2 = vx_frame { fr.sh_r + lift, fr.sh_l + lift, fr.arm, fr.thick, fr.sleeve, fr.hand, fr.head_top + lift, fr.head_r }
    if u.helm and u.helm_kind != "galea": vx_helm(out, fr2)
    vx_arms(out, u, fr2, 0.0, t)
    return out

// ---- the voxel grid

class vx_shape:     // a filled grid's surface: the voxels with air beside them (none of the rest can show)
    pos:[int3]      // voxels from the unit's ground point
    mats:[int]
    normals:[float3]   // the shape's smooth normal (the grid's stairs would speckle the shading)
    occl:[float]    // how hemmed in (0 open to 1 deep in a crease): ambient occlusion
    lo:int3         // the grid (for shadows): its corner, size, and per voxel a material or -1
    dims:int3
    grid:[int]

def vx_scaled(p:vx_prim, s:float, lift:float) -> vx_prim:
    let up = float3 { 0.0, 0.0, lift }
    return vx_prim { (p.a + up) * s, (p.b + up) * s, p.ra * s, p.rb * s, p.mat, p.hard, p.disc, p.box * s }

def vx_bounds(p:vx_prim) -> float3, float3:
    let r = max(p.ra, p.rb) + (if p.disc: p.ra else: 0.0) + magnitude(p.box)
    return min(p.a, p.b) - float3_1 * r, max(p.a, p.b) + float3_1 * r

// The shape's distance at p from the parts in `near`, and the material of the part nearest it. (Capsules, most of
// the parts, measured inline: this is the bake's hot loop.)
def vx_field(ps:[vx_prim], near:[int], p:float3, k:float) -> float, int:
    var body = 1000.0
    var gear = 1000.0
    var best = 1000.0
    var m = -1
    for(near) i:
        let s = ps[i]
        var d = 0.0
        if s.disc or s.box.x > 0.0: d = vx_dist(p, s)
        else:
            let ba = s.b - s.a
            let pa = p - s.a
            let l2 = dot(ba, ba)
            let h = if l2 > 0.0: clamp(dot(pa, ba) / l2, 0.0, 1.0) else: 0.0
            d = magnitude(pa - ba * h) - (s.ra + (s.rb - s.ra) * h)
        if s.hard: gear = min(gear, d)
        else:
            let e = max(k - abs(body - d), 0.0) / k
            body = min(body, d) - e * e * k * 0.25
        if d < best:
            best = d
            m = s.mat
    return min(body, gear - 0.5), m   // (gear thickened half a voxel: a shaft thinner than a voxel would break up)

let vx_AO_TAPS = [ int3 { 2, 0, 0 }, int3 { -2, 0, 0 }, int3 { 0, 2, 0 }, int3 { 0, -2, 0 }, int3 { 0, 0, 2 }, int3 { 0, 0, -2 },
                   int3 { 2, 2, 2 }, int3 { -2, 2, 2 }, int3 { 2, -2, 2 }, int3 { -2, -2, 2 },
                   int3 { 2, 2, -2 }, int3 { -2, 2, -2 }, int3 { 2, -2, -2 }, int3 { -2, -2, -2 } ]

def vx_solid_at(grid:[int], lo:int3, dims:int3, v:int3) -> bool:
    let q = v - lo
    if q.z < 0: return true   // (the ground)
    if q.x < 0 or q.y < 0 or q.x >= dims.x or q.y >= dims.y or q.z >= dims.z: return false
    return grid[(q.z * dims.y + q.y) * dims.x + q.x] >= 0

// The parts filled into a grid at a voxel a baked pixel (the unit's size scaled in). The grid is cut in blocks of 4
// voxels; each part is listed in the blocks its bounds touch, so a voxel only measures the parts near it. A block
// is tested at its centre first: clearly outside is skipped, clearly inside filled whole (none of it shows);
// only blocks the surface crosses are measured voxel by voxel.
def vx_fill(parts:[vx_prim], unit_size:float) -> vx_shape:
    let s = unit_size * vx_RES
    var low = 1000.0
    for(parts) p:
        let a, b = vx_bounds(p)
        low = min(low, a.z)
    let ps = map(parts) p: vx_scaled(p, s, -low)
    let k = vx_BLEND * s
    var a = float3_1 * 1000.0
    var b = float3_1 * -1000.0
    for(ps) p:
        let pa, pb = vx_bounds(p)
        a = min(a, pa)
        b = max(b, pb)
    let lo = int3 { int(floor(a.x)) - 2, int(floor(a.y)) - 2, 0 }
    let nb = (int3 { int(-floor(-b.x)) + 2, int(-floor(-b.y)) + 2, int(-floor(-b.z)) + 2 } - lo + int3_1 * 3) / 4
    let dims = nb * 4
    let blocks = map(nb.x * nb.y * nb.z): []::int
    let margin = k + 4.0
    for(ps) p, i:
        let pa, pb = vx_bounds(p)
        let qa = max(int3_0, (int3 { int(floor(pa.x - margin)), int(floor(pa.y - margin)), int(floor(pa.z - margin)) } - lo) / 4)
        let qb = min(nb - int3_1, (int3 { int(floor(pb.x + margin)), int(floor(pb.y + margin)), int(floor(pb.z + margin)) } - lo) / 4)
        for(qb.z - qa.z + 1) z: for(qb.y - qa.y + 1) y: for(qb.x - qa.x + 1) x:
            blocks[((qa.z + z) * nb.y + qa.y + y) * nb.x + qa.x + x].push(i)
    let n = dims.x * dims.y * dims.z
    let mats = map(n): -1
    let field = map(n): 1.0   // the distance where it was measured (air elsewhere, -1 deep inside), for normals
    let base = float(lo) + float3_1 * 0.5
    let reach = 3.5   // a block's half diagonal, voxels
    for(nb.z) bz: for(nb.y) by: for(nb.x) bx:
        let near = blocks[(bz * nb.y + by) * nb.x + bx]
        if near.length:
            let b0 = int3 { bx, by, bz } * 4
            let pc = base + float(b0) + float3_1 * 1.5
            // the block's centre, and the parts close enough to matter anywhere in it (the bins are loose boxes)
            let close = []::int
            var body = 1000.0
            var gear = 1000.0
            var best = 1000.0
            var mc = -1
            for(near) j:
                let pj = ps[j]
                let d = vx_dist(pc, pj)
                if pj.hard: gear = min(gear, d)
                else: body = vx_smin(body, d, k)
                if d < best:
                    best = d
                    mc = pj.mat
                if d < reach + k + 3.0: close.push(j)
            let dc = min(body, gear - 0.5)
            if dc < reach:
                for(4) z: for(4) y: for(4) x:
                    let v = b0 + int3 { x, y, z }
                    let i = (v.z * dims.y + v.y) * dims.x + v.x
                    if dc < -reach:
                        mats[i] = mc
                        field[i] = -1.0
                    else:
                        let d, m = vx_field(ps, close, base + float(v), k)
                        field[i] = d
                        if d <= 0.0: mats[i] = m
    // the surface, each voxel's normal from the distances around it
    let pos = []::int3
    let smat = []::int
    let nrm = []::float3
    let sy = dims.x
    let sz = dims.x * dims.y
    for(dims.z - 2) z0: for(dims.y - 2) y0: for(dims.x - 2) x0:
        let i = ((z0 + 1) * dims.y + y0 + 1) * dims.x + x0 + 1
        let m = mats[i]
        if m >= 0 and (mats[i - 1] < 0 or mats[i + 1] < 0 or mats[i - sy] < 0 or mats[i + sy] < 0 or mats[i - sz] < 0 or mats[i + sz] < 0):
            pos.push(lo + int3 { x0 + 1, y0 + 1, z0 + 1 })
            smat.push(m)
            nrm.push(normalize(float3 { field[i + 1] - field[i - 1], field[i + sy] - field[i - sy], field[i + sz] - field[i - sz] }))
    // ambient occlusion: how many of 14 voxels round it (2 out along the axes and the diagonals) are solid; an open
    // flat surface has about half
    let occl = map(pos) v:
        var hit = 0
        for(vx_AO_TAPS) t: if vx_solid_at(mats, lo, dims, v + t): hit++
        clamp((float(hit) / 14.0 - 0.45) / 0.35, 0.0, 1.0)
    return vx_shape { pos, smat, nrm, occl, lo, dims, mats }


// ---- drawing: each surface voxel splatted into the cell over the pixels its cube covers, the nearest kept

def vx_hash(v:int3) -> int:
    var h = v.x * 73856093 ^ v.y * 19349663 ^ v.z * 83492791
    h = (h ^ (h >> 13)) * 1274126177
    return (h ^ (h >> 16)) & 1023

let vx_LIGHT = normalize(float3 { -0.65, 0.1, 0.75 })   // the body's key light, as the camera sees it: high on the sun's side
var vx_shadows = true       // shadows on the body (its own, and occlusion in creases), and on the ground
let vx_SUN = normalize(float3 { -0.55, 0.45, 1.0 })   // towards the sun, as the camera sees it: upper left (the world's)
var vx_depth = []::float   // the cell being drawn (reused: only the last one's box is cleared)
var vx_cols = []::float3
var vx_mat = []::int
var vx_out = []::float4
var vx_box = int4_0          // the last cell's box, outline included: x0, y0, x1, y1

// One facing of a shape as a sprite cell (alpha 0 around it; drawn in vx_box): the cell is reused by the next call,
// so copy what's wanted first. The team colour's key (magenta) survives the shading, so the game's sprite shader can
// recolour it.
def vx_cell(sh:vx_shape, facing:int) -> [float4]:
    let yaw = float(facing) * 45.0
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let ru = rot(float3 { 1.0, 0.0, 0.0 })
    let rv = rot(float3 { 0.0, sin(vx_ELEV), cos(vx_ELEV) })
    let rd = rot(float3 { 0.0, cos(vx_ELEV), -sin(vx_ELEV) })
    let light = rot(vx_LIGHT)
    let hx = 0.5 * (abs(ru.x) + abs(ru.y) + abs(ru.z))   // the cube's half extent on screen
    let hy = 0.5 * (abs(rv.x) + abs(rv.y) + abs(rv.z))
    let cw = vx_CELL.x
    let ch = vx_CELL.y
    if not vx_depth.length:
        vx_depth = map(cw * ch): 1000000.0
        vx_cols = map(cw * ch): float3_0
        vx_mat = map(cw * ch): -1
        vx_out = map(cw * ch): float4_0
    else:   // the last cell's box cleared
        for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
            let j = (vx_box.y + yy) * cw + vx_box.x + xx
            vx_depth[j] = 1000000.0
            vx_mat[j] = -1
            vx_out[j] = float4_0
    var box = int4 { cw, ch, -1, -1 }
    for(sh.pos) v, i:
        let m = sh.mats[i]
        let p = float(v) + float3_1 * 0.5
        let u = dot(p, ru)
        let w = dot(p, rv)
        let d = dot(p, rd)
        var k = dot(sh.normals[i], light) * 0.5 + 0.5
        if vx_shadows:
            // in its own shadow? a few steps towards the light through the grid
            var q = p + sh.normals[i] * 1.2 + light * 1.0
            for(8):
                if k > 0.42 and vx_solid_at(sh.grid, sh.lo, sh.dims, int3 { int(floor(q.x)), int(floor(q.y)), int(floor(q.z)) }) and q.z > 0.0:
                    k = 0.3
                q += light * 1.7
            k -= sh.occl[i] * 0.3
        var c = vx_mat_cols[m] * (if k > 0.8: 1.08 elif k > 0.62: 0.94 elif k > 0.45: 0.76 elif k > 0.28: 0.6 else: 0.47)
        if vx_MAT_FUR[m] != 0: c *= 1.0 + vx_fur * (float(vx_hash(v)) / 511.5 - 1.0)
        c = min(c, float3_1)   // (over 1 wraps round in the game's texture: a bright pink came out cyan)
        let x0 = max(1, int(-floor(-(float(vx_ANCHOR.x) + u - hx - 0.5))))
        let x1 = min(cw - 2, int(floor(float(vx_ANCHOR.x) + u + hx - 0.5)))
        let y0 = max(1, int(-floor(-(float(vx_ANCHOR.y) - w - hy - 0.5))))
        let y1 = min(ch - 2, int(floor(float(vx_ANCHOR.y) - w + hy - 0.5)))
        box = int4 { min(box.x, x0), min(box.y, y0), max(box.z, x1), max(box.w, y1) }
        for(y1 - y0 + 1) yy: for(x1 - x0 + 1) xx:
            let j = (y0 + yy) * cw + x0 + xx
            if d < vx_depth[j]:
                vx_depth[j] = d
                vx_cols[j] = c
                vx_mat[j] = m
    vx_box = int4 { box.x - 1, box.y - 1, box.z + 1, box.w + 1 }   // (the outline round it)
    for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
        let px = vx_box.x + xx
        let py = vx_box.y + yy
        let j = py * cw + px
        if vx_mat[j] >= 0:
            // a softer line where this pixel stands well in front of the one beside it (a limb across the body)
            var c = vx_cols[j]
            for([ 1, -1, cw, -cw ]) dj:
                if vx_mat[j + dj] >= 0 and vx_depth[j + dj] > vx_depth[j] + 5.0: c = vx_cols[j] * 0.72
            vx_out[j] = float4 { c.x, c.y, c.z, 1.0 }
        else:
            for([ 1, -1, cw, -cw ]) dj:
                let q = j + dj
                if q >= 0 and q < cw * ch and vx_mat[q] >= 0:
                    let m = vx_mat[q]
                    let c = if m == vx_mat_team: float3 { 0.22, 0.07, 0.06 } else: vx_mat_cols[m] * 0.3
                    vx_out[j] = float4 { c.x, c.y, c.z, 1.0 }
    return vx_out

// One facing's shadow on the ground (the sun's, as the world's props and buildings cast it): a cell of its own, drawn
// under every unit. vx_SCELL wide and high round vx_SANCHOR; drawn in vx_sbox; reused by the next call.
let vx_SCELL = int2 { vx_CELL.x * 2, vx_CELL.y }
let vx_SANCHOR = int2 { vx_SCELL.x / 2 - int(14.0 * vx_RES), vx_SCELL.y - int(30.0 * vx_RES) }
let vx_SHADOW = float4 { 0.05, 0.04, 0.02, 0.5 }
var vx_sout = []::float4
var vx_sbox = int4_0

def vx_ground_shadow(sh:vx_shape, facing:int) -> [float4]:
    let yaw = float(facing) * 45.0
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let ru = rot(float3 { 1.0, 0.0, 0.0 })
    let rv = rot(float3 { 0.0, sin(vx_ELEV), cos(vx_ELEV) })
    let sun = rot(vx_SUN)
    let cw = vx_SCELL.x
    let ch = vx_SCELL.y
    if not vx_sout.length: vx_sout = map(cw * ch): float4_0
    else:
        for(vx_sbox.w - vx_sbox.y + 1) yy: for(vx_sbox.z - vx_sbox.x + 1) xx: vx_sout[(vx_sbox.y + yy) * cw + vx_sbox.x + xx] = float4_0
    var box = int4 { cw, ch, -1, -1 }
    for(sh.pos) v:
        let p = float(v) + float3_1 * 0.5
        let g = p - sun * (p.z / sun.z)
        let u = dot(g, ru)
        let w = dot(g, rv)
        let x0 = max(0, int(floor(float(vx_SANCHOR.x) + u - 0.7)))
        let y0 = max(0, int(floor(float(vx_SANCHOR.y) - w - 0.7)))
        let x1 = min(cw - 1, x0 + 1)
        let y1 = min(ch - 1, y0 + 1)
        box = int4 { min(box.x, x0), min(box.y, y0), max(box.z, x1), max(box.w, y1) }
        for(y1 - y0 + 1) yy: for(x1 - x0 + 1) xx: vx_sout[(y0 + yy) * cw + x0 + xx] = vx_SHADOW
    vx_sbox = box
    return vx_sout

// A facing drawn into an image at (cx, cy), its ground shadow under it when shadows are on.
def vx_draw(sh:vx_shape, facing:int, img:[float3], iw:int, cx:int, cy:int):
    if vx_shadows:
        let sc = vx_ground_shadow(sh, facing)
        let ox = cx + vx_ANCHOR.x - vx_SANCHOR.x
        let oy = cy + vx_ANCHOR.y - vx_SANCHOR.y
        for(vx_sbox.w - vx_sbox.y + 1) yy: for(vx_sbox.z - vx_sbox.x + 1) xx:
            let c = sc[(vx_sbox.y + yy) * vx_SCELL.x + vx_sbox.x + xx]
            let x = ox + vx_sbox.x + xx
            let y = oy + vx_sbox.y + yy
            if c.w > 0.0 and x >= 0 and x < iw and y >= 0 and y * iw < img.length:
                let j = y * iw + x
                img[j] = img[j] * (1.0 - c.w) + xyz(c) * c.w
    let cell = vx_cell(sh, facing)
    for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
        let c = cell[(vx_box.y + yy) * vx_CELL.x + vx_box.x + xx]
        if c.w > 0.0: img[(cy + vx_box.y + yy) * iw + cx + vx_box.x + xx] = xyz(c)
