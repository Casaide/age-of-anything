// The Nile body's kit (#467), drawn around nile.vox (the Roman body's proportions) in its voxels (2 a body unit) from the
// approved concept sheet (human-redesign/nile-foot.png, nile-riders.png), one model each, worn on the body point it rides or
// held in the hand (its offset printed for gear.json):
//   nile_khat.vox       helm.nile_khat: a plain white headcloth over the wig, gathered behind, a gold band at the brow
//   nile_headcloth.vox  helm.nile_headcloth: the headcloth striped in team colour, its lappets down on the chest
//   nile_crown.vox      helm.nile_bronze: the war crown, tall and swept back, team colour studded with gold, a gold cobra
//   nile_scale.vox      armour.bronze: a corselet of bronze scales on shoulder straps, the collar showing above it
//   nile_cuirass.vox    armour.leather: a red leather cuirass edged in gold
//   nile_bands.vox      armour.bands: the archer's linen bands crossed over the chest and the back
//   nile_feather.vox    hat.feather: a team headband, an ostrich feather standing at the back
//   nile_priest.vox     hat.priest: the priest's long white robe to the ankles, a leopard skin over the shoulder
//   nile_cowhide.vox    shield.cowhide: the tall shield rounded at the top, spotted cowhide on it, a red-brown rim
//   nile_khopesh.vox    weapon.khopesh: the sickle sword, a bronze hook on a straight neck, a dark grip
//   lobster tools/vox/nile_gear.lobster
import .voxwrite
import .worn

let LINEN, TEAM, GOLD, BRONZE, BRONZE2, RED, HIDE, SPOT, RIM, GRIP, WHITE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
let COLOURS = [ 0, 0xece6d6, 0x2a5a9a, 0xe2b44c, 0xbd8f4d, 0x8a6a3a, 0xa8402a, 0xe8dcc0, 0x4a2e1c, 0x8a3a24, 0x2a1d16, 0xf4f0e8 ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- headcloths and crowns

// a headcloth over the wig: round over the crown, wider than the wig at the sides, open at the face, gathered behind
def cloth(c:float3) -> bool:
    let over = vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 5.2, 5.6, 5.6 }) and c.z > 64.0 and not (c.y > 1.0 and c.z < 71.2)
    let tail = abs(c.x) < 1.4 and c.y < -4.4 and c.y > -6.4 and c.z > 60.0 and c.z < 66.0
    return over or tail

let khat = vw_piece { "khat", 0 }
vw_fill(khat, int3 { -7, -8, 59 }, int3 { 7, 6, 76 }) c:
    if not cloth(c): 0
    elif c.y > 0.6 and c.z > 71.0 and c.z < 72.2: GOLD
    else: LINEN
save("nile_khat", khat, HEAD, "head")

let nemes = vw_piece { "headcloth", 0 }
vw_fill(nemes, int3 { -7, -8, 55 }, int3 { 7, 6, 76 }) c:
    let lappet = abs(c.x) > 3.2 and abs(c.x) < 5.4 and c.y > -0.6 and c.y < 1.8 and c.z > 56.0 and c.z < 66.0
    if not (cloth(c) or lappet): 0
    elif (int(floor(c.z)) % 3) == 0: TEAM
    else: LINEN
save("nile_headcloth", nemes, HEAD, "head")

let crown = vw_piece { "crown", 0 }
vw_fill(crown, int3 { -7, -10, 63 }, int3 { 7, 7, 82 }) c:
    let shell = vw_ball(c, float3 { 0.0, -1.6, 71.6 }, float3 { 5.2, 6.6, 7.0 }) and c.z > 66.4 and not (c.y > 1.0 and c.z < 71.0)
    let cobra = abs(c.x) < 0.7 and c.y > 3.6 and c.y < 5.4 and c.z > 70.6 and c.z < 73.4
    let stud = (int(floor(c.x + 20.0)) % 3) == 0 and (int(floor(c.z)) % 3) == 0
    if cobra: GOLD
    elif not shell: 0
    elif c.z < 67.6: GOLD
    elif stud: GOLD
    else: TEAM
save("nile_crown", crown, HEAD, "head")

// ---- body armour

// the scale corselet: bronze scales in rows from the chest to the waist, held up by straps over the shoulders
let scale = vw_piece { "scale", 0 }
vw_fill(scale, int3 { -13, -9, 40 }, int3 { 13, 9, 63 }) c:
    let strap = abs(abs(c.x) - 4.6) < 1.2 and c.z > 55.0 and torso(c, 1.2)
    let coat = torso(c, 1.4) and c.z > 41.0 and c.z < 55.6 and not neck(c)
    if strap or coat: (if (int(floor(c.z)) % 2) == 0 and ((int(floor(c.x + 20.0)) % 2) == 0): BRONZE2 else: BRONZE)
    else: 0
save("nile_scale", scale, CHEST, "chest")

// the leather cuirass: red, from under the collar to the sash, gold at its top and bottom edges
let cuir = vw_piece { "cuirass", 0 }
vw_fill(cuir, int3 { -13, -9, 40 }, int3 { 13, 9, 63 }) c:
    let strap = abs(abs(c.x) - 4.6) < 1.2 and c.z > 54.0 and torso(c, 1.2)
    if strap: RED
    elif torso(c, 1.3) and c.z > 41.0 and c.z < 54.6 and not neck(c): (if c.z < 42.2 or c.z > 53.4: GOLD else: RED)
    else: 0
save("nile_cuirass", cuir, CHEST, "chest")

// the bands: two strips of linen crossed over the chest and the back, from each shoulder to the other hip
let bands = vw_piece { "bands", 0 }
vw_fill(bands, int3 { -13, -9, 40 }, int3 { 13, 9, 63 }) c:
    let t = (c.z - 42.0) / 16.0  // (0 at the hip, 1 at the shoulder)
    let a = abs(c.x - (-6.0 + t * 12.0)) < 1.1
    let b = abs(c.x - (6.0 - t * 12.0)) < 1.1
    if t > 0.0 and t < 1.0 and (a or b) and torso(c, 0.8) and not torso(c, -0.4): LINEN
    else: 0
save("nile_bands", bands, CHEST, "chest")

// ---- the feather and the priest

let feather = vw_piece { "feather", 0 }
vw_fill(feather, int3 { -7, -8, 66 }, int3 { 7, 7, 92 }) c:
    let band = vw_taper(c, 70.6, 72.0, float2 { 0.0, -0.6 }, float2 { 0.0, -0.6 }, float2 { 4.9, 5.3 }, float2 { 4.9, 5.3 })
    let t = (c.z - 72.0) / 18.0
    let plume = t > 0.0 and t < 1.0 and abs(c.x) < 0.6 and abs(c.y - (-4.8 - t * 1.6)) < 1.4 * (1.0 - t) + 0.4
    if band: TEAM
    elif plume: WHITE
    else: 0
save("nile_feather", feather, HEAD, "head")

// the priest: the white robe from the chest to the ankles over his kilt, a leopard skin slung from the left shoulder to the
// right hip, spotted
let priest = vw_piece { "priest", 0 }
vw_fill(priest, int3 { -14, -10, 4 }, int3 { 14, 10, 63 }) c:
    let robe = (torso(c, 1.0) and c.z > 44.0 and c.z < 58.0 and not neck(c)) or
        vw_taper(c, 5.0, 44.0, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.6, 7.0 }, float2 { 8.4, 5.8 })
    let t = (60.0 - c.z) / 34.0
    let pelt = c.y > -1.0 and t > 0.0 and t < 1.0 and abs(c.x - (-5.0 + t * 9.0)) < 3.4 and
        ((torso(c, 1.8) and c.z > 44.0) or vw_taper(c, 24.0, 44.0, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 10.4, 7.8 }, float2 { 9.2, 6.6 }))
    let spot = (int(floor(c.x * 0.7 + c.z * 0.5)) % 3) == 0 and (int(floor(c.z)) % 3) == 0
    if pelt: (if spot: SPOT else: GOLD)
    elif robe: LINEN
    else: 0
save("nile_priest", priest, HEAD, "head")

// ---- held (drawn as the hand's frame holds them: x up the held direction, z across, the face out along +y)

// the cowhide shield: tall, round at the top, flat at the bottom, a red-brown rim, the hide pale with dark spots
let cow = vw_piece { "cowhide", 0 }
vw_fill(cow, int3 { -22, -2, -9 }, int3 { 15, 3, 9 }) c:
    let top = c.x > 6.0 and vw_sq((c.x - 6.0) / 8.0) + vw_sq(c.z / 8.0) <= 1.0
    let shape = top or (c.x <= 6.0 and c.x > -21.0 and abs(c.z) < 8.0)
    let inner = (c.x > 6.0 and vw_sq((c.x - 6.0) / 6.8) + vw_sq(c.z / 6.8) <= 1.0) or (c.x <= 6.0 and c.x > -19.8 and abs(c.z) < 6.8)
    let d = c.y - 1.0 * (1.0 - vw_sq(c.z / 9.0))
    let spot = vw_ball(c, float3 { 5.0, 1.0, -2.0 }, float3 { 2.4, 3.0, 2.0 }) or vw_ball(c, float3 { -4.0, 1.0, 3.0 }, float3 { 2.0, 3.0, 2.4 }) or
        vw_ball(c, float3 { -13.0, 1.0, -2.6 }, float3 { 2.6, 3.0, 2.0 }) or vw_ball(c, float3 { 0.0, 1.0, -4.6 }, float3 { 1.2, 3.0, 1.2 })
    if not shape or d > 0.0 or d < -1.6: 0
    elif not inner: RIM
    elif spot: SPOT
    else: HIDE
save("nile_cowhide", cow, float3_0, "hand")

// the khopesh: a dark grip, a straight bronze neck, then the hook curving out and back, its edge on the outside
let kh = vw_piece { "khopesh", 0 }
vw_fill(kh, int3 { -3, -8, -1 }, int3 { 26, 4, 1 }) c:
    let grip = c.x > -2.0 and c.x < 4.0 and vw_sq(c.y / 0.9) + vw_sq(c.z / 0.9) <= 1.0
    let neck = c.x >= 4.0 and c.x < 12.0 and abs(c.y) < 0.8 and abs(c.z) < 0.6
    let r = sqrt(vw_sq(c.x - 17.0) + vw_sq(c.y + 1.0))
    let hook = r > 4.4 and r < 6.6 and abs(c.z) < 0.6 and (c.x > 12.0) and c.y > -4.0
    if grip: GRIP
    elif neck or hook: BRONZE
    else: 0
save("nile_khopesh", kh, float3_0, "hand")
