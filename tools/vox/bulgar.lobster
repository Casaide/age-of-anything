// The Bulgar body (#477): a Bulgar or Slav of about 900, in the base dress every Bulgar unit wears under its kit, from the
// approved concept sheet (bulgar-base): the Roman body's build and points (so worn models fit both), short dark hair with a
// lock behind each ear, a drooping moustache; a white shirt with red stitching at the collar and red cuffs, a long
// sleeveless coat in team colour (black on the sheet; team colour so the unit reads at game size and its shape check
// counts it as its own, as the Roman's tunic), open down the front with a red braid at its edges and hem, the wide red sash over a studded
// belt, white breeches, black leg wraps crossed with cords, leather opanci. Caps, helmets, armour, shields and weapons are
// gear over it.
//   lobster tools/vox/bulgar.lobster   (writes data/voxel/models/bulgar.vox; paths are from this file)
import .voxwrite

let SKIN, HAIR, SASH, BRAID, COAT, SHIRT, BREECH, WRAP, CORD, BELT, STUD, EYE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
let COLOURS = [ 0, 0xc99a78, 0x3a2c22, 0xa8322b, 0xb8352c, 0x2e2620, 0xece6d6, 0xd9d2c0, 0x1e1b19, 0x7a5a3a, 0x6b4a2c, 0xc9a24a, 0x2a1d16 ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes, a small nose; short hair over the crown, a lock behind each ear;
// a moustache drooping past the corners of the mouth
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -6, 60 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let crown = vw_ball(c, float3 { 0.0, -0.5, 69.4 }, float3 { 4.3, 4.7, 4.9 }) and c.z > 67.0 and not (c.y > 1.6 and c.z < 71.4)
    let lock = ax > 3.0 and ax < 4.4 and c.y > -2.0 and c.y < -0.6 and c.z > 61.5 and c.z < 68.0
    let moustache = c.y > 3.2 and ((ax < 1.8 and c.z > 65.0 and c.z < 66.0) or (ax > 1.2 and ax < 2.2 and c.z > 63.0 and c.z < 66.0))
    let eye = c.y > 2.4 and ax > 1.0 and ax < 2.0 and c.z > 68.4 and c.z < 69.4
    if crown or lock: HAIR
    elif face and moustache: HAIR
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }) or vw_ball(c, float3 { -3.8, -0.2, 67.5 }, float3 { 0.8, 1.2, 1.6 }): SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: broad over a narrower waist; the coat over it, open in front so the shirt shows down the middle, a red braid at
// the opening's edges; red stitching round the shirt's collar
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let ax = abs(c.x)
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    let open = c.y > 1.0 and ax < 1.6 + (c.z - 44.0) * 0.08
    if not body: 0
    elif c.z > 59.0 and ax < 2.4 and c.y > 1.5: SKIN       // the neck
    elif c.z > 58.6 and ax < 3.4 and c.y > 1.0: BRAID      // the stitched collar
    elif open: (if ax < 0.6 and c.z > 55.0: BRAID else: SHIRT)
    elif c.y > 1.0 and ax < 2.6 + (c.z - 44.0) * 0.08: BRAID  // the coat's edge
    elif ax > 7.6 and c.z > 55.0: SHIRT                     // the shirt's shoulders, the coat has no sleeves
    else: COAT
pieces.push(chest)

// the hip: the wide sash, a studded belt below it, the coat's skirt to below the knee, open in front over the breeches, a
// red braid at its edges and hem
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 20 }, int3 { 11, 8, 46 }) c:
    let ax = abs(c.x)
    let sash = vw_taper(c, 41.0, 45.0, float2_0, float2_0, float2 { 7.6, 4.9 }, float2 { 7.4, 4.8 })
    let belt = vw_taper(c, 38.8, 41.0, float2_0, float2_0, float2 { 7.6, 4.9 }, float2 { 7.6, 4.9 })
    let skirt = vw_taper(c, 22.4, 42.5, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 10.0, 7.0 }, float2 { 7.2, 4.6 })
    let gap = c.y > 2.0 and ax < 1.0 + (42.5 - c.z) * 0.08
    if sash: SASH
    elif belt: (if c.y > 4.0 and ax < 2.4 and (int(floor(c.x + 10.0)) % 2) == 0: STUD else: BELT)
    elif skirt and gap: (if c.z < 37.0: 0 else: SHIRT)    // the shirt's tail under the belt, then the breeches show
    elif skirt and c.y > 1.0 and ax < 2.0 + (42.5 - c.z) * 0.08: BRAID
    elif skirt: (if c.z < 23.8: BRAID else: COAT)           // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right): the thigh in white breeches, then the black wraps crossed with cords to the knee, the opanak
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): BREECH else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.5, 1.6 }, float2 { 2.2, 2.5 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.2, 2.5 }, float2 { 2.0, 2.2 })
    let d = c.x - 3.8 + c.y * 0.5
    let cross = (int(floor(c.z + d * 1.6 + 40.0)) % 4) == 0 or (int(floor(c.z - d * 1.6 + 40.0)) % 4) == 0
    if not calf: 0
    elif c.z > 17.4: BREECH
    elif cross: CORD
    else: WRAP
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.6, 1.7 }, float2 { 1.5, 1.6 })): 0  // (the ankle reaches into the shin, so they join at every size)
    else: BELT
pieces.push(foot)

// an arm (the right), hanging: the shirt's full white sleeve, a red cuff, the hand
let upper = vw_piece { "upper_arm.r", 0 }
vw_fill(upper, int3 { 6, -4, 48 }, int3 { 14, 4, 60 }) c:
    if vw_taper(c, 52.5, 60.0, float2 { 10.1, 0.0 }, float2 { 9.7, -0.2 }, float2 { 2.5, 2.6 }, float2 { 2.6, 2.6 }): SHIRT
    elif vw_taper(c, 48.0, 52.5, float2 { 9.9, 0.0 }, float2 { 9.9, 0.0 }, float2 { 2.1, 2.2 }, float2 { 2.3, 2.4 }): SHIRT
    else: 0
pieces.push(upper)
let fore = vw_piece { "forearm.r", 0 }
vw_fill(fore, int3 { 7, -4, 37 }, int3 { 14, 4, 47 }) c:
    if vw_taper(c, 37.0, 47.0, float2 { 10.2, 0.4 }, float2 { 10.0, 0.1 }, float2 { 1.7, 1.8 }, float2 { 2.1, 2.2 }): (if c.z < 38.8: BRAID else: SHIRT) else: 0
pieces.push(fore)
let hand = vw_piece { "hand.r", 0 }
vw_fill(hand, int3 { 8, -3, 32 }, int3 { 14, 4, 37 }) c:
    if vw_ball(c, float3 { 10.3, 0.5, 35.0 }, float3 { 1.4, 1.6, 2.5 }): SKIN else: 0
pieces.push(hand)

// the points: the hip between the legs' tops, the chest at the armpits, the head's middle
vw_points(pieces, [ [ 0, 0, 38 ], [ 0, 0, 57 ], [ 0, 1, 67 ] ], [ "hip", "chest", "head" ], SKIN)
vw_write("../../data/voxel/models/bulgar.vox", pieces, COLOURS)
