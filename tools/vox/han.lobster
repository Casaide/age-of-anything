// The Han body (#469): a man of the Han, about 100 BC, in the base dress every Han unit wears under its kit, from the
// approved concept sheet (han-base): the Roman body's build and points (so worn models fit both), black hair drawn up into a
// topknot tied with white cloth; a knee-length robe in team colour wrapped right over left, its black-trimmed edge running
// from the neck to the hem, a black girdle with a gold hook; light trousers wrapped below the knee, black shoes. Headwraps,
// helmets, armour, shields and weapons are gear over it.
//   lobster tools/vox/han.lobster   (writes data/voxel/models/han.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, ROBE, TRIM, GOLD, CLOTH, TROUSER, WRAP, EYE = 1, 2, 3, 4, 5, 6, 7, 8, 9
let COLOURS = [ 0, 0xdcaa7c, 0x15110f, 0x9a2a24, 0x2a2422, 0xe2b44c, 0xf0ebe0, 0xe6dcc8, 0xc8bca4, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes, a small nose; the hair drawn back smooth over the crown into a
// topknot, a white cloth round its base
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -6, 60 }, int3 { 6, 6, 79 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let hair = vw_ball(c, float3 { 0.0, -0.5, 69.2 }, float3 { 4.1, 4.5, 4.6 }) and c.z > 68.0 and not (c.y > 2.0 and c.z < 71.4)
    let knot = vw_ball(c, float3 { 0.0, -0.6, 74.0 }, float3 { 1.4, 1.4, 1.4 })
    let tie = vw_taper(c, 72.6, 73.4, float2 { 0.0, -0.6 }, float2 { 0.0, -0.6 }, float2 { 1.8, 1.8 }, float2 { 1.7, 1.7 })
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.2
    if tie: CLOTH
    elif hair or knot: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }) or vw_ball(c, float3 { -3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }): SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the robe's black edge: from the left of the neck across the chest to under the right arm, then straight down the right
// side to the hem (the right front laps over the left)
def edge(c:float3) -> bool:
    if c.y < 1.6: return false
    if c.z > 48.0: return abs(c.x - (-2.6 + (60.6 - c.z) * 0.62)) < 0.8
    return c.z > 23.0 and abs(c.x - 5.2) < 0.8

// the chest: broad over a narrower waist, the robe with its edge and a black collar
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if not body: 0
    elif c.z > 59.0 and abs(c.x) < 2.4 and c.y > 1.5: SKIN  // the neck
    elif edge(c) or (c.z > 59.0 and abs(c.x) < 3.4 and c.y > 1.0): TRIM
    else: ROBE
pieces.push(chest)

// the hip: the black girdle and its gold hook, the robe's skirt to the knee with a black hem
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 20 }, int3 { 11, 8, 45 }) c:
    let girdle = vw_taper(c, 41.4, 44.2, float2_0, float2_0, float2 { 7.4, 4.8 }, float2 { 7.3, 4.7 })
    let skirt = vw_taper(c, 22.6, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.8, 6.8 }, float2 { 7.2, 4.6 })
    if girdle: (if c.y > 4.0 and abs(c.x) < 0.9: GOLD else: TRIM)
    elif skirt: (if c.z < 24.0 or edge(c): TRIM else: ROBE)  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right): light trousers, wrapped from the knee down in bands, a black shoe
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): TROUSER else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.4, 1.5 }, float2 { 2.1, 2.4 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.1, 2.4 }, float2 { 1.9, 2.1 })
    if not calf: 0
    elif (int(floor(c.z * 0.5 + c.x * 0.3)) % 2) == 0: WRAP
    else: TROUSER
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    else: TRIM                                                                                                                                                                                                                            // the black shoe
pieces.push(foot)

// an arm (the right), hanging: the robe's long sleeve to the wrist, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): ROBE
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.0, 2.1 }, float2 { 2.2, 2.3 }): ROBE
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.6, 1.7 }, float2 { 2.0, 2.1 }): ROBE else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/han.vox", pieces, COLOURS)
