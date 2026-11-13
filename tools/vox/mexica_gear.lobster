// The Mexica body's kit (#471), drawn around mexica.vox (the Roman body's proportions) in its voxels (2 a body unit) from the
// approved concept sheet (human-redesign/mexica-foot.png), one model each, worn on the body point it rides or held in the hand
// (its offset printed for gear.json):
//   mexica_band.vox      helm.aztec_band: a red headband, a green feather standing at the back
//   mexica_cap.vox       helm.aztec_quilted: the tall pointed cap in team colour, ringed
//   mexica_eagle.vox     helm.aztec_eagle: the eagle helmet, brown feathers, the face looking out of the open beak
//   mexica_quilted.vox   armour.leather: quilted cotton armour, a vest to the hips
//   mexica_suit.vox      armour.feather_suit: the feather suit in team colour, rows of feathers, to mid-thigh
//   mexica_priest.vox    hat.priest_black: the priest's long matted hair and black fringed tunic, red bands
//   mexica_chimalli.vox  shield.chimalli: a round shield, team colour, a teal ring, a red centre, a fringe of red feathers
//   mexica_club.vox      weapon.macuahuitl: the flat wooden club edged with obsidian blades
//   lobster tools/vox/mexica_gear.lobster
import .voxwrite
import .worn

let COTTON, COTTON2, TEAM, TEAM2, TEAL, RED, GREEN, BROWN, BROWN2, BEAK, BLACK, WOOD, OBSIDIAN, WHITE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
let COLOURS = [ 0, 0xf0ebe0, 0xc8bca4, 0xe0a020, 0x9a7a50, 0x2a7a6a, 0xa83228, 0x54853a, 0x5e4029, 0x3a2a1c, 0xe2b44c, 0x1f1714, 0x8a6a42, 0x1c1a24, 0xf4f0e8 ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- headgear

let band = vw_piece { "band", 0 }
vw_fill(band, int3 { -7, -8, 66 }, int3 { 7, 7, 86 }) c:
    let ring = vw_taper(c, 70.2, 71.6, float2 { 0.0, -0.6 }, float2 { 0.0, -0.6 }, float2 { 4.9, 5.3 }, float2 { 4.9, 5.3 })
    let t = (c.z - 71.0) / 13.0
    let feather = t > 0.0 and t < 1.0 and abs(c.x - 1.6) < 0.6 and abs(c.y - (-4.6 - t * 0.8)) < 1.2 * (1.0 - t) + 0.4
    if ring: RED
    elif feather: GREEN
    else: 0
save("mexica_band", band, HEAD, "head")

let cap = vw_piece { "cap", 0 }
vw_fill(cap, int3 { -7, -7, 66 }, int3 { 7, 7, 88 }) c:
    let cone = vw_taper(c, 70.0, 86.0, float2 { 0.0, -0.6 }, float2 { 0.0, -0.8 }, float2 { 5.0, 5.4 }, float2 { 0.6, 0.6 }) and not face_cut(c)
    if not cone: 0
    elif (int(floor(c.z - 70.0)) % 4) == 0: TEAM2
    else: TEAM
save("mexica_cap", cap, HEAD, "head")

let eagle = vw_piece { "eagle", 0 }
vw_fill(eagle, int3 { -8, -8, 59 }, int3 { 8, 11, 81 }) c:
    let dome = vw_ball(c, float3 { 0.0, -0.4, 69.6 }, float3 { 5.8, 6.2, 7.0 }) and c.z > 62.0 and not (c.y > 0.4 and c.z < 72.0 and c.z > 62.6)
    let upper = vw_ball(c, float3 { 0.0, 4.6, 73.0 }, float3 { 3.4, 4.6, 1.8 }) and c.y > 2.0
    let hook = vw_ball(c, float3 { 0.0, 8.4, 72.0 }, float3 { 1.4, 1.4, 1.8 })
    let lower = vw_ball(c, float3 { 0.0, 4.2, 61.6 }, float3 { 2.8, 3.4, 1.0 }) and c.y > 2.0
    let eye = abs(abs(c.x) - 3.6) < 0.8 and c.y > 2.6 and c.y < 4.0 and abs(c.z - 74.6) < 0.8
    if eye: WHITE
    elif upper or hook or lower: BEAK
    elif dome: (if (int(floor(c.z)) % 3) == 0: BROWN2 else: BROWN)
    else: 0
save("mexica_eagle", eagle, HEAD, "head")

let priest = vw_piece { "priest", 0 }
vw_fill(priest, int3 { -14, -10, 20 }, int3 { 14, 10, 76 }) c:
    let hair = (vw_ball(c, float3 { 0.0, -0.6, 69.4 }, float3 { 5.0, 5.4, 5.4 }) and c.z > 64.0 and not (c.y > 1.0 and c.z < 71.4)) or
        (abs(abs(c.x) - 3.6) < 1.0 and c.y > 0.6 and c.y < 3.2 and c.z > 50.0 and c.z < 66.0) or
        (c.y < -2.0 and c.z > 46.0 and c.z < 66.0 and abs(c.x) < 4.4 and vw_taper(c, 46.0, 66.0, float2 { 0.0, -2.0 }, float2 { 0.0, -2.4 }, float2 { 5.2, 4.2 }, float2 { 4.6, 3.0 }))
    let tunic = (torso(c, 1.0) and c.z > 44.0 and c.z < 58.6 and not neck(c)) or
        vw_taper(c, 22.0, 44.0, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.6, 7.0 }, float2 { 8.2, 5.6 })
    let fringe = c.z < 24.0 and (int(floor(around(c) * 8.0 + 40.0)) % 2) == 0
    if hair: BLACK
    elif tunic and c.z < 24.0 and not fringe: 0
    elif tunic: (if abs(c.z - 30.0) < 0.6 or abs(c.z - 40.0) < 0.6 or abs(c.z - 50.0) < 0.6: RED else: BLACK)
    else: 0
save("mexica_priest", priest, HEAD, "head")

// ---- body armour

let quilt = vw_piece { "quilted", 0 }
vw_fill(quilt, int3 { -13, -9, 33 }, int3 { 13, 9, 63 }) c:
    let grid = (int(floor(c.z)) % 4) == 0 or (int(floor(c.x + 20.0)) % 4) == 0
    if (torso(c, 1.8) and c.z > 44.0 and not neck(c)) or (skirt(c, 34.0, 2.2) and c.z <= 44.0): (if grid: COTTON2 else: COTTON)
    else: 0
save("mexica_quilted", quilt, CHEST, "chest")

let suit = vw_piece { "suit", 0 }
vw_fill(suit, int3 { -13, -9, 27 }, int3 { 13, 9, 63 }) c:
    let row = (int(floor(c.z + abs(c.x) * 0.4)) % 4) == 0
    if (torso(c, 1.8) and c.z > 44.0 and not neck(c)) or (skirt(c, 28.0, 2.2) and c.z <= 44.0): (if row: TEAM2 else: TEAM)
    else: 0
save("mexica_suit", suit, CHEST, "chest")

// ---- held (drawn as the hand's frame holds them: x up the held direction, z across, the face out along +y)

let shield = vw_piece { "chimalli", 0 }
vw_fill(shield, int3 { -14, -2, -9 }, int3 { 9, 3, 9 }) c:
    let r = sqrt(c.x * c.x + c.z * c.z)
    let d = c.y - 1.0 * (1.0 - vw_sq(r / 9.0))
    let fringe = c.x < -6.0 and c.x > -13.0 and abs(c.z) < 6.0 and abs(c.y + 0.6) < 0.6 and (int(floor(c.z + 20.0)) % 2) == 0 and c.x > -13.0 + abs(c.z) * 0.4
    if fringe and r > 7.0: RED
    elif r > 8.4 or d > 0.0 or d < -1.4: 0
    elif r < 2.2: RED
    elif r > 4.0 and r < 5.8: TEAL
    else: TEAM
save("mexica_chimalli", shield, float3_0, "hand")

let club = vw_piece { "macuahuitl", 0 }
vw_fill(club, int3 { -3, -4, -1 }, int3 { 24, 4, 1 }) c:
    let grip = c.x > -2.0 and c.x < 5.0 and abs(c.y) < 0.9 and abs(c.z) < 0.9
    let paddle = c.x >= 5.0 and c.x < 23.0 and abs(c.y) < 1.6 + min(1.0, (c.x - 5.0) * 0.2) and abs(c.z) < 0.6
    let blade = c.x >= 6.0 and c.x < 22.0 and abs(c.y) >= 1.6 + min(1.0, (c.x - 5.0) * 0.2) and abs(c.y) < 3.4 + min(1.0, (c.x - 5.0) * 0.2) and abs(c.z) < 0.6 and (int(floor(c.x)) % 3) != 0
    if grip: BLACK
    elif paddle: WOOD
    elif blade: OBSIDIAN
    else: 0
save("mexica_club", club, float3_0, "hand")
