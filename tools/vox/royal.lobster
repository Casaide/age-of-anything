// The Royal body (#462): a man of a high-medieval kingdom, about 1200-1300, in the base dress every Royal unit wears under its
// kit, from the approved concept sheet (royal-base): the Roman body's build and points (so worn models fit both), with
// bowl-cut brown hair and no beard; a wool tunic to the knee with long sleeves, in team colour, a belt with a hanging strap
// end; dark hose and leather turnshoes. Helmets, armour, shields and weapons are gear over it.
//   lobster tools/vox/royal.lobster   (writes data/voxel/models/royal.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, TUNIC, BELT, BRASS, LEATHER, HOSE, EYE = 1, 2, 3, 4, 5, 6, 7, 8
let COLOURS = [ 0, 0xd8a882, 0x6a4a2a, 0x5a3f8f, 0x5e4029, 0xc8c8c0, 0x3e2a1c, 0x3a3436, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes (a dark voxel each, apart), a small nose; bowl-cut hair, round
// over the crown to the tops of the ears, cut straight across the brow; clean-shaven
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -6, 61 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let hair = vw_ball(c, float3 { 0.0, -0.4, 69.6 }, float3 { 4.4, 4.8, 4.8 }) and c.z > 67.6 and not (c.y > 1.6 and c.z < 71.2)
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.4
    if hair: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }) or vw_ball(c, float3 { -3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }): SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: broad (two heads across the shoulders) over a narrower waist, all tunic but a round neck
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if not body: 0
    elif c.z > 59.0 and abs(c.x) < 2.4 and c.y > 1.5: SKIN  // the neck opening
    else: TUNIC
pieces.push(chest)

// the hip: the belt, its buckle and the strap end hanging in front, and the tunic's skirt to the knee, flaring a little
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 21 }, int3 { 11, 8, 45 }) c:
    let belt = vw_taper(c, 42.2, 44.4, float2_0, float2_0, float2 { 7.3, 4.7 }, float2 { 7.2, 4.6 })
    let tail = c.y > 4.2 and c.y < 5.6 and abs(c.x - 1.6) < 0.7 and c.z > 36.0 and c.z < 42.2
    let outer = vw_taper(c, 24.0, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.4, 6.4 }, float2 { 7.2, 4.6 })
    if belt: (if c.y > 4.0 and abs(c.x) < 1.0: BRASS else: BELT)
    elif tail: BELT
    elif outer: TUNIC  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right), in dark hose: a strong thigh tapering to the knee, the calf, then a leather turnshoe
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): HOSE else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    // the calf swells below the knee, then the shin tapers to the ankle
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.3, 1.4 }, float2 { 2.0, 2.3 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.0, 2.3 }, float2 { 1.8, 2.0 })
    if not calf: 0
    else: HOSE
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    else: LEATHER  // the turnshoe
pieces.push(foot)

// an arm (the right), hanging: the tunic's long sleeve to the wrist, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): TUNIC
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.0, 2.1 }, float2 { 2.2, 2.3 }): TUNIC
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.5, 1.6 }, float2 { 2.0, 2.1 }): TUNIC else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/royal.vox", pieces, COLOURS)
