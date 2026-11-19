// The forest body (#497): one of the woodland folk, in the base dress every forest unit wears under its kit, from the approved
// concept sheet (culture-kits-animals/forest-look.png): the Roman body's build and points (so worn models fit both), short
// brown hair, no beard; a moss-green tunic to the knee with a hem of leaves, a team sash slung from the left shoulder to the
// right hip, darker moss sleeves with bark bracers at the wrists, bark-brown trousers, bark boots bound with lighter bark.
// Helmets (the acorn cap), hats (the leaf), bark plates, shields and weapons are gear over it.
//   lobster tools/vox/forest.lobster   (writes data/voxel/models/forest.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, MOSS, MOSS_D, LEAF, LEAF_L, TEAM, BARK, BARK_L, EYE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
let COLOURS = [ 0, 0xd0a080, 0x1f1714, 0x3f6b3a, 0x2d4a29, 0x4e8a34, 0x7ab048, 0xb8302a, 0x6a4a2e, 0x8e6a44, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face, the eyes, a small nose; short hair over the crown, to the nape behind and over the ears
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -7, 58 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let crown = vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 4.4, 4.8, 4.8 }) and c.z > 67.0 and not (c.y > 1.6 and c.z < 71.4)
    let nape = vw_ball(c, float3 { 0.0, -1.4, 67.0 }, float3 { 4.0, 3.6, 3.6 }) and c.y < -1.0 and c.z > 64.4
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.2
    if crown or nape: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the sash: a band slung from the left shoulder to the right hip, over the chest and the back
def sash(c:float3) -> bool:
    let d = c.z - 50.0 - c.x * 0.75  // (the band's line: high at the left shoulder, low at the right hip)
    return abs(d) < 1.6

// the chest: broad over a narrower waist, the tunic, the sash across it, the neck open
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    if not body: 0
    elif c.z > 59.0 and abs(c.x) < 2.4 and c.y > 1.5: SKIN  // the neck
    elif c.z > 59.6 and abs(c.x) < 3.4 and c.y > 0.6: MOSS_D  // the neck's edge
    elif sash(c): TEAM
    else: MOSS
pieces.push(chest)

// the hip: a bark belt, the tunic's skirt to the knee, ending in a hem of leaves (each leaf a point, light and dark in turn)
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 20 }, int3 { 11, 8, 45 }) c:
    let belt = vw_taper(c, 41.6, 43.4, float2_0, float2_0, float2 { 7.3, 4.7 }, float2 { 7.2, 4.6 })
    let skirt = vw_taper(c, 21.6, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 10.0, 7.0 }, float2 { 7.2, 4.6 })
    let a = atan2(float2 { c.x, c.y })                // the way round, in degrees
    let k = int(floor((a + 360.0) / 36.0))            // which leaf
    let t = (a + 360.0) / 36.0 - float(k) - 0.5       // across it, -0.5 to 0.5
    let tip = 22.0 + abs(t) * 4.0                     // a leaf's point hangs lowest at its middle
    if belt: BARK
    elif sash(c) and c.z > 40.0: TEAM
    elif skirt and c.z < 27.0: (if c.z < tip: 0 elif k % 2 == 0: LEAF else: LEAF_L)
    elif skirt: MOSS  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right): bark-brown trousers, a bark boot to the calf bound with lighter strips, a dark sole
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): BARK else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.5, 1.6 }, float2 { 2.2, 2.5 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.2, 2.5 }, float2 { 1.9, 2.1 })
    if not calf: 0
    elif c.z < 12.0 and (int(floor(c.z + 40.0)) % 3) == 0: BARK_L
    else: BARK
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    elif c.z < 1.0: MOSS_D
    else: BARK_L
pieces.push(foot)

// an arm (the right), hanging: a darker moss sleeve, a bark bracer at the wrist, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): MOSS_D
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.0, 2.1 }, float2 { 2.2, 2.3 }): MOSS_D
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.7, 1.8 }, float2 { 2.0, 2.1 }): (if c.z < 42.0: BARK_L else: MOSS_D) else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/forest.vox", pieces, COLOURS)
