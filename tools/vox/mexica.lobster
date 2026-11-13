// The Mexica body (#471): a Mexica man, about 1500, in the base dress every Mexica unit wears under its kit, from the
// approved concept sheet (mexica-base): the Roman body's build and points (so worn models fit both), long black hair cut in a
// straight fringe; a bare chest; a team cloak knotted on the right shoulder and hanging down the back to the knee; a white
// cotton loincloth, its flap down the front ending in a team band; sandals. Headbands, helmets, armour, shields and weapons
// are gear over it.
//   lobster tools/vox/mexica.lobster   (writes data/voxel/models/mexica.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, COTTON, TEAM, KNOT, SANDAL, EYE = 1, 2, 3, 4, 5, 6, 7
let COLOURS = [ 0, 0xb07a50, 0x15110f, 0xf0ebe0, 0xe0a020, 0x2a7a6a, 0xa88a5a, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, the eyes, a small nose; the hair long, a fringe straight across the brow, down
// over the ears to the neck behind
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -7, 59 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let crown = vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 4.6, 5.0, 5.1 }) and c.z > 65.0 and not (c.y > 1.2 and c.z < 71.0)
    let back = vw_taper(c, 60.0, 66.0, float2 { 0.0, -2.4 }, float2 { 0.0, -1.8 }, float2 { 4.0, 2.4 }, float2 { 4.4, 3.0 }) and c.y < -0.4
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.2
    if crown or back: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the cloak over the back: from the shoulders, draped over their tops, down to the knee
def cloak(c:float3) -> bool:
    let back = c.y < -1.4 and vw_taper(c, 24.0, 59.0, float2 { 0.0, -1.2 }, float2 { 0.0, -0.4 }, float2 { 10.2, 6.4 }, float2 { 10.0, 5.6 })
    let over = c.z > 56.0 and c.z < 60.6 and abs(c.x) > 5.4 and vw_taper(c, 56.0, 60.6, float2 { 0.0, -0.3 }, float2 { 0.0, -0.5 }, float2 { 10.2, 5.8 }, float2 { 8.0, 4.6 })
    return back or over

// the chest: broad over a narrower waist, bare, the cloak over the shoulders and the back, its knot on the right shoulder
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -8, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if vw_ball(c, float3 { -6.4, 2.6, 58.6 }, float3 { 1.4, 1.4, 1.4 }): KNOT
    elif cloak(c) and (body or c.y < -3.0): TEAM
    elif body: SKIN
    else: 0
pieces.push(chest)

// the hip: the loincloth round the hips, its flap down the front to a team band; the cloak behind to the knee
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -9, 22 }, int3 { 11, 9, 45 }) c:
    let cloth = vw_taper(c, 36.0, 43.0, float2 { 0.0, 0.0 }, float2 { 0.0, 0.0 }, float2 { 7.6, 5.0 }, float2 { 7.3, 4.7 })
    let flap = abs(c.x) < 2.0 and c.y > 3.8 and c.y < 5.6 and c.z > 28.0 and c.z < 43.0
    if flap: (if c.z < 30.6: TEAM else: COTTON)
    elif cloth: COTTON
    elif cloak(c) and c.y < -3.6: TEAM
    elif vw_taper(c, 34.0, 36.0, float2_0, float2_0, float2 { 7.4, 4.8 }, float2 { 7.6, 5.0 }): SKIN  // (the tops of the thighs)
    else: 0
pieces.push(hip)

// a leg (the right), bare: a strong thigh tapering to the knee, the calf, a sandal with an ankle guard
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): SKIN else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.3, 1.4 }, float2 { 2.0, 2.3 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.0, 2.3 }, float2 { 1.8, 2.0 })
    if not calf: 0
    elif c.z < 3.6: SANDAL
    else: SKIN
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    elif c.z < 1.0 or c.z > 2.6: SANDAL
    else: SKIN
pieces.push(foot)

// an arm (the right), bare, hanging
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.3, 2.4 }, float2 { 2.5, 2.5 }): SKIN
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 1.9, 2.0 }, float2 { 2.1, 2.2 }): SKIN
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.4, 1.5 }, float2 { 1.9, 2.0 }): SKIN else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/mexica.vox", pieces, COLOURS)
