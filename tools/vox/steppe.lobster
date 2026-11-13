// The Steppe body (#465): a horseman of the steppe, about 1200-1300, in the base dress every Steppe unit wears under its
// kit, from the approved concept sheet (steppe-base): the Roman body's build and points (so worn models fit both), a shaved
// crown but for the back and a tuft at the top, a braid behind each ear and a drooping moustache; a long deel in team colour, crossed to the right with a
// trimmed edge and hem, long sleeves, a wide red sash; felt boots. Hats, helmets, armour, shields and weapons are gear over it.
//   lobster tools/vox/steppe.lobster   (writes data/voxel/models/steppe.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, DEEL, TRIM, SASH, BOOT, TROUSER, EYE = 1, 2, 3, 4, 5, 6, 7, 8
let COLOURS = [ 0, 0xc89468, 0x1f1714, 0xc8a064, 0x8a6a3a, 0xa83228, 0x3a2a20, 0x4a3a2e, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes, a small nose; the crown shaved but for the hair at the back and a tuft over the brow; a braid behind each ear down to
// the neck; a moustache drooping past the corners of the mouth
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -6, 60 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let braid = ax > 3.0 and ax < 4.4 and c.y > -1.8 and c.y < -0.4 and c.z > 60.5 and c.z < 68.0
    let moustache = c.y > 3.2 and ((ax < 1.8 and c.z > 65.0 and c.z < 66.0) or (ax > 1.2 and ax < 2.2 and c.z > 63.0 and c.z < 66.0))
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.4
    let back = vw_ball(c, float3 { 0.0, -0.4, 69.6 }, float3 { 4.4, 4.8, 4.8 }) and c.z > 67.6 and (c.y < -0.6 or (ax < 1.0 and c.y < 2.6))
    if braid or back: HAIR
    elif face and moustache: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }) or vw_ball(c, float3 { -3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }): SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: broad over a narrower waist, the deel crossed from the left of the neck down to the right armpit, its edge trimmed
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    let edge = c.y > 2.0 and c.z > 49.0 and abs(c.x - (-2.0 + (60.5 - c.z) * 0.75)) < 0.8
    if not body: 0
    elif c.z > 59.0 and abs(c.x) < 2.4 and c.y > 1.5: SKIN            // the neck
    elif edge or (c.z > 59.0 and abs(c.x) < 3.4 and c.y > 1.0): TRIM  // the crossed edge and the collar
    else: DEEL
pieces.push(chest)

// the hip: the wide sash, and the deel's skirt to below the knee, flaring, its hem trimmed
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 19 }, int3 { 11, 8, 45 }) c:
    let sash = vw_taper(c, 40.6, 44.6, float2_0, float2_0, float2 { 7.4, 4.8 }, float2 { 7.3, 4.7 })
    let outer = vw_taper(c, 21.5, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.8, 6.8 }, float2 { 7.2, 4.6 })
    if sash: SASH
    elif outer: (if c.z < 23.0: TRIM else: DEEL)  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right): the thigh in dark trousers, then the tall felt boot to the knee, its foot
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): TROUSER else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.5, 1.6 }, float2 { 2.2, 2.5 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.2, 2.5 }, float2 { 2.1, 2.3 })
    if calf: BOOT else: 0
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.6, 1.7 }, float2 { 1.5, 1.6 })): 0  // (the ankle reaches into the shin, so they join at every size)
    else: BOOT
pieces.push(foot)

// an arm (the right), hanging: the deel's long sleeve to the wrist, a trimmed cuff, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): DEEL
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.0, 2.1 }, float2 { 2.2, 2.3 }): DEEL
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.6, 1.7 }, float2 { 2.0, 2.1 }): (if c.z < 38.6: TRIM else: DEEL) else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/steppe.vox", pieces, COLOURS)
