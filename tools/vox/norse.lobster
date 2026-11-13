// The Norse body (#473): a Norseman, about 900, in the base dress every Norse unit wears under its kit, from the approved
// concept sheet (norse-base): the Roman body's build and points (so worn models fit both), long blond hair, a full beard
// with a braid; a wool tunic to the knee in team colour, a woven red-and-gold border at the neck, the cuffs and the hem; a
// leather belt with a brass buckle and a hanging strap; trousers with white leg wraps, leather shoes. Helmets, armour, shields
// and weapons are gear over it.
//   lobster tools/vox/norse.lobster   (writes data/voxel/models/norse.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, TUNIC, TRIM, GOLD, TROUSER, WRAP, BELT, EYE = 1, 2, 3, 4, 5, 6, 7, 8, 9
let COLOURS = [ 0, 0xe0b090, 0xc8a060, 0x2a4a7a, 0x8a3020, 0xe2b44c, 0x857560, 0xece6d6, 0x4a3020, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face, the eyes, a small nose; long hair round the crown and down to the shoulders behind; a full beard
// from the cheeks to below the chin, a braid hanging from its point
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -7, 55 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let crown = vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 4.5, 4.9, 5.0 }) and c.z > 66.0 and not (c.y > 1.4 and c.z < 71.2)
    let back = vw_taper(c, 60.0, 67.0, float2 { 0.0, -2.4 }, float2 { 0.0, -1.6 }, float2 { 4.2, 2.6 }, float2 { 4.4, 3.2 }) and c.y < -0.6
    let beard = (vw_ball(c, float3 { 0.0, 2.2, 63.8 }, float3 { 3.4, 2.6, 3.4 }) and c.y > 0.8) or
        (face and c.y > 1.2 and c.z < 66.2 and not (ax < 1.2 and c.z > 64.4 and c.z < 65.4)) or
        (ax < 0.8 and c.y > 2.6 and c.y < 4.0 and c.z > 57.0 and c.z < 61.0)
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.2
    if crown or back or beard: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: broad over a narrower waist, the tunic, its border round the neck opening
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if not body: 0
    elif c.z > 59.0 and abs(c.x) < 2.4 and c.y > 1.5: SKIN  // the neck
    elif c.z > 59.0 and abs(c.x) < 3.6 and c.y > 0.6: (if c.z > 60.4: GOLD else: TRIM)
    else: TUNIC
pieces.push(chest)

// the hip: the belt, its buckle and strap end, the tunic's skirt to the knee, a red border with a gold line at the hem
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 20 }, int3 { 11, 8, 45 }) c:
    let belt = vw_taper(c, 41.6, 43.8, float2_0, float2_0, float2 { 7.3, 4.7 }, float2 { 7.2, 4.6 })
    let tail = c.y > 4.2 and c.y < 5.6 and abs(c.x - 2.0) < 0.7 and c.z > 36.0 and c.z < 41.6
    let skirt = vw_taper(c, 22.4, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 10.0, 7.0 }, float2 { 7.2, 4.6 })
    if belt: (if c.y > 4.0 and abs(c.x) < 1.0: GOLD else: BELT)
    elif tail: BELT
    elif skirt: (if c.z < 23.6: TRIM elif c.z < 24.4: GOLD else: TUNIC)  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right): the trousers, wrapped from the knee down with white bands wound slantwise, a leather shoe
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): TROUSER else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.4, 1.5 }, float2 { 2.1, 2.4 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.1, 2.4 }, float2 { 1.9, 2.1 })
    if not calf: 0
    elif (int(floor(c.z + (c.x - 3.8) * 1.2 + c.y * 0.8 + 40.0)) % 4) == 0: WRAP
    else: TROUSER
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    else: BELT                                                                                                                                                                                                                            // the leather shoe
pieces.push(foot)

// an arm (the right), hanging: the tunic's long sleeve, a border at the cuff, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): TUNIC
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.0, 2.1 }, float2 { 2.2, 2.3 }): TUNIC
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.6, 1.7 }, float2 { 2.0, 2.1 }): (if c.z < 38.6: TRIM else: TUNIC) else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/norse.vox", pieces, COLOURS)
