// The Nile body (#467): a man of the Nile kingdom, about 1300 BC, in the base dress every Nile unit wears under its kit, from
// the approved concept sheet (nile-base): the Roman body's build and points (so worn models fit both), a short black wig cut
// straight at the brow and the jaw, kohl round the eyes, a bare chest under a broad bead collar (blue, gold and red bands); a
// pleated white linen kilt, a team sash and its stiff front panel; bare legs, papyrus sandals. Headcloths, armour, shields
// and weapons are gear over it.
//   lobster tools/vox/nile.lobster   (writes data/voxel/models/nile.vox; paths are from this file)
import .voxwrite

let SKIN, WIG, LINEN, TEAM, GOLD, BLUE, RED, SANDAL, EYE = 1, 2, 3, 4, 5, 6, 7, 8, 9
let COLOURS = [ 0, 0xa86a44, 0x15110f, 0xece6d6, 0x2a5a9a, 0xe2b44c, 0x3a7ab0, 0xa83228, 0xc8a46a, 0x15110f ]
let pieces = []::vw_piece

// the head: an oval face over a firm jaw, ears, the eyes ringed in kohl, a small nose; the wig a bob round the head, cut
// straight across the brow and level with the jaw, the face open
let head = vw_piece { "head", 0 }
vw_fill(head, int3 { -6, -7, 60 }, int3 { 6, 6, 75 }) c:
    let ax = abs(c.x)
    let face = vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.7, 4.1, 5.3 }) or
        vw_taper(c, 62.0, 65.0, float2 { 0.0, 0.2 }, float2 { 0.0, 0.6 }, float2 { 2.6, 3.0 }, float2 { 3.0, 3.4 })
    let wig = vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 4.7, 5.1, 5.2 }) and c.z > 64.4 and not (c.y > 1.2 and c.z < 71.0)
    let eye = c.y > 2.4 and ax > 0.8 and ax < 2.4 and c.z > 68.2 and c.z < 69.6
    if wig: WIG
    elif face and eye: EYE
    elif face: SKIN
    elif vw_ball(c, float3 { 0.0, 4.5, 67.5 }, float3 { 0.8, 0.8, 1.2 }): SKIN  // the nose
    else: 0
pieces.push(head)

// the chest: broad over a narrower waist, bare, the bead collar over the shoulders and the top of the chest in three bands
let chest = vw_piece { "chest", 0 }
vw_fill(chest, int3 { -11, -7, 43 }, int3 { 11, 7, 62 }) c:
    let body = vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0, 4.4 }, float2 { 9.4, 5.0 }) or
        vw_taper(c, 57.0, 61.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4, 5.0 }, float2 { 7.0, 3.8 })
    let r = sqrt(c.x * c.x + vw_sq(c.y + 1.0))
    if not body: 0
    elif c.y > -1.0 and c.z > 55.0 and r > 2.6 and r < 7.0 and c.z > 61.0 - (r - 2.6) * 1.4:
        if r < 4.0: BLUE elif r < 5.2: GOLD elif r < 6.2: BLUE else: RED
    else: SKIN
pieces.push(chest)

// the hip: the team sash, its stiff front panel hanging to the kilt's hem, the white kilt to above the knee
let hip = vw_piece { "hip", 0 }
vw_fill(hip, int3 { -11, -8, 21 }, int3 { 11, 9, 45 }) c:
    let sash = vw_taper(c, 41.0, 44.2, float2_0, float2_0, float2 { 7.4, 4.8 }, float2 { 7.3, 4.7 })
    let panel = abs(c.x) < 1.6 and c.y > 4.2 and c.y < 5.8 - (c.z - 29.0) * 0.04 and c.z > 30.0 and c.z < 41.0
    let kilt = vw_taper(c, 29.6, 41.5, float2 { 0.0, 0.0 }, float2 { 0.0, 0.0 }, float2 { 9.0, 6.4 }, float2 { 7.2, 4.6 })
    if sash or panel: TEAM
    elif kilt: LINEN  // solid, so the thighs never show through it
    else: 0
pieces.push(hip)

// a leg (the right), bare: a strong thigh tapering to the knee, the calf, a sandal under the foot
let thigh = vw_piece { "thigh.r", 0 }
vw_fill(thigh, int3 { 0, -5, 20 }, int3 { 8, 5, 37 }) c:
    if vw_taper(c, 20.0, 37.0, float2 { 3.8, 0.0 }, float2 { 4.0, 0.0 }, float2 { 2.0, 2.2 }, float2 { 2.9, 3.1 }): SKIN else: 0
pieces.push(thigh)
let shin = vw_piece { "shin.r", 0 }
vw_fill(shin, int3 { 0, -4, 1 }, int3 { 7, 4, 19 }) c:
    let calf = vw_taper(c, 1.5, 12.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.4 }, float2 { 1.3, 1.4 }, float2 { 2.0, 2.3 }) or
        vw_taper(c, 12.0, 19.0, float2 { 3.8, -0.4 }, float2 { 3.8, 0.0 }, float2 { 2.0, 2.3 }, float2 { 1.8, 2.0 })
    if calf: SKIN else: 0
pieces.push(shin)
let foot = vw_piece { "foot.r", 0 }
vw_fill(foot, int3 { 1, -3, 0 }, int3 { 7, 6, 3 }) c:
    if not (vw_taper(c, 0.0, 2.6, float2 { 3.9, 1.0 }, float2 { 3.9, 0.6 }, float2 { 2.0, 4.2 }, float2 { 1.6, 3.2 }) or vw_taper(c, 2.6, 4.0, float2 { 3.8, -0.2 }, float2 { 3.8, -0.2 }, float2 { 1.5, 1.6 }, float2 { 1.4, 1.5 })): 0  // (the ankle reaches into the shin, so they join at every size)
    elif c.z < 1.0: SANDAL
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
vw_write("../../data/voxel/models/nile.vox", pieces, COLOURS)
