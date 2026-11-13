// The Greek body (#451): a man of the 5th-4th century BC in the base dress every Greek unit wears under its kit, from the
// approved concept sheet (greeks-base): the Roman body's build and points (so worn models fit both), with curly dark
// hair and a full beard; a wool chiton pinned at the shoulders, to mid-thigh, in team colour, with a white girdle;
// krepides, sandals laced up the shin. Helmets, armour, shields and weapons are gear over it.
//   lobster tools/vox/greek.lobster   (writes data/voxel/models/greek.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, TUNIC, BELT, BRASS, LEATHER, STRAP, EYE = 1, 2, 3, 4, 5, 6, 7, 8
let COLOURS = [ 0, 0xc08a62, 0x2a1e16, 0x3a5fa0, 0xe8e4d8, 0xc9a24a, 0x7a5236, 0x4a3020, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes (a dark voxel each, apart), a small nose; curly dark hair over
// the crown and down to the nape, a fringe of curls on the brow; a full beard over the jaw and chin
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -6, 61 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let curl = ((int(floor(c.x)) + int(floor(c.y)) + int(floor(c.z))) % 2 + 2) % 2 == 0  // (curls: a bumpy edge)
    let hair = vw_ball(c, float3 { 0.0, -0.5, 69.6 }, float3 { 4.5, 4.9, 4.9 }) and (curl or vw_ball(c, float3 { 0.0, -0.5, 69.6 }, float3 { 4.1, 4.5, 4.5 })) and
        not (c.y > 1.0 and c.z < 71.0) and not (c.y > -1.8 and c.z < 68.2)
    let beard = vw_ball(c, float3 { 0.0, 1.0, 64.4 }, float3 { 3.9, 4.2, 3.2 }) and c.y > 0.0 and c.z < 66.8 and
        not (ax < 1.2 and c.z > 65.4 and c.y > 3.0)  // (the mouth)
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.4
    if hair or beard: HAIR
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

// the hip: the white girdle and the chiton's skirt to mid-thigh, flaring a little to the hem
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 23 }, int3 { 11, 8, 45 }) c:
    let belt = vw_taper(c, 42.0, 45.0, float2_0, float2_0, float2 { 7.3, 4.7 }, float2 { 7.2, 4.6 })
    let outer = vw_taper(c, 28.0, 42.5, float2 { 0.0, -0.5 }, float2 { 0.0, 0.0 }, float2 { 8.8, 5.8 }, float2 { 7.2, 4.6 })
    if belt: BELT
    elif outer: TUNIC  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right), bare below the tunic: a strong thigh tapering to the knee, the calf, then the caligae: a hobnailed
// sole and straps in an open lattice over the foot and up the ankle
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): SKIN else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    // the calf swells below the knee, then the shin tapers to the ankle
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.3, 1.4 }, float2 { 2.0, 2.3 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.0, 2.3 }, float2 { 1.8, 2.0 })
    if not calf: 0
    elif c.z < 9.0 and ((int(floor(c.z + c.x)) % 3 + 3) % 3 == 0 or (int(floor(c.z - c.x)) % 3 + 3) % 3 == 0): STRAP  // the laces, criss-cross
    else: SKIN
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    elif c.z < 1.0: LEATHER                                                                                                                                                                                                               // the sole
    elif c.z < 2.0 and (int(floor(c.y)) % 3 + 3) % 3 == 0: STRAP                                                                                                                                                                          // the sandal's straps over the foot
    else: SKIN
pieces.push(foot)

// an arm (the right), hanging: the tunic's short sleeve, wider than the arm, to above the elbow; the bare arm; the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.7, 2.8 }, float2 { 2.6, 2.6 }): TUNIC
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 1.8, 1.9 }, float2 { 2.0, 2.1 }): SKIN
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.3, 1.4 }, float2 { 1.8, 1.9 }): SKIN else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/greek.vox", pieces, COLOURS)
