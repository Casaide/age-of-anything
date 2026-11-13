// The Royal body's worn kit (#462), drawn around royal.vox (the Roman body's proportions) in its voxels (2 a body unit)
// from the approved concept sheet (human-redesign/royal-foot.png), one model each, worn on the body point it rides (its
// offset printed for gear.json's `royal` fits):
//   royal_gambeson.vox   armour.leather: a quilted gambeson to mid-thigh
//   royal_mail.vox       armour.mail: a mail hauberk to the knee, belted
//   royal_surcoat.vox    armour.surcoat: mail under a long team surcoat with a gold cross
//   royal_kettle.vox     helm.cap: an iron kettle hat, its brim wide and sloping
//   royal_nasal.vox      helm.nasal: a conical helmet with a nose guard, over a mail coif
//   royal_greathelm.vox  helm.iron: a flat-topped great helm, an eye slit, a gold cross on the face
//   royal_hood.vox       hat.hood: the archer's team hood, its cape on his shoulders, its tail down his back
//   royal_coif.vox       hood.coif: the slinger's mail coif round his face and over his shoulders
//   royal_cowl.vox       hat.cowl: the monk's black habit and cowl, a rope belt, his tonsure
//   royal_heater.vox     shield.heater: a heater shield in team colour, a gold chevron
//   lobster tools/vox/royal_gear.lobster
import .voxwrite
import .worn

let IRON, GOLD, GAMB, TEAM, LEATHER, WOOD, HABIT, ROPE, WHITE, SKIN = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
let COLOURS = [ 0, 0x8e9298, 0xf2c94c, 0xddd2b8, 0x5a3f8f, 0x5e4029, 0x8a6a42, 0x3a2e26, 0xc8b48a, 0xece6d6, 0xd8a882 ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- body armour

// the gambeson: quilted in upright channels, from the neck to mid-thigh
let gamb = vw_piece { "gambeson", 0 }
vw_fill(gamb, int3 { -13, -9, 29 }, int3 { 13, 9, 63 }) c:
    let seam = (int(floor(c.x + 20.0)) % 3) == 0 or (int(floor(c.z)) % 6) == 0
    if (torso(c, 1.6) and c.z > 44.0 and not neck(c)) or (skirt(c, 30.0, 1.8) and c.z <= 44.0): (if seam: ROPE else: GAMB)
    else: 0
save("royal_gambeson", gamb, CHEST, "chest")

// mail: the hauberk from the neck to the knee, a belt at the waist; rings shown by a light and dark checker
let mail = vw_piece { "mail", 0 }
vw_fill(mail, int3 { -13, -9, 22 }, int3 { 13, 9, 63 }) c:
    if (torso(c, 1.5) and c.z > 44.0 and not neck(c)) or (skirt(c, 23.0, 1.7) and c.z <= 44.0):
        if c.z > 42.4 and c.z < 44.2: LEATHER
        else: IRON
    else: 0
save("royal_mail", mail, CHEST, "chest")

// the surcoat: mail at the neck and the shoulders, a long team coat without sleeves over it to below the knee, a gold
// cross on the chest
let surcoat = vw_piece { "surcoat", 0 }
vw_fill(surcoat, int3 { -14, -10, 20 }, int3 { 14, 10, 63 }) c:
    let coat = (torso(c, 2.0) and c.z > 44.0 and c.z < 58.6 and not neck(c)) or (skirt(c, 21.0, 2.2) and c.z <= 44.0)
    let cross = c.y > 3.0 and ((abs(c.x) < 1.0 and c.z > 47.0 and c.z < 57.0) or (abs(c.x) < 4.0 and c.z > 52.0 and c.z < 54.0))
    if coat: (if cross: GOLD elif c.z > 42.6 and c.z < 44.0: LEATHER else: TEAM)
    elif torso(c, 1.5) and c.z > 44.0 and not neck(c): IRON
    else: 0
save("royal_surcoat", surcoat, CHEST, "chest")

// ---- helmets

// the kettle hat: an iron bowl, a wide brim sloping down all round
let kettle = vw_piece { "kettle", 0 }
vw_fill(kettle, int3 { -9, -10, 64 }, int3 { 9, 9, 77 }) c:
    let r = sqrt(c.x * c.x + vw_sq(c.y + 0.5))
    let brim = r > 4.6 and r < 8.4 and abs(c.z - (70.6 - (r - 4.6) * 0.45)) < 0.7
    if brim: (if r > 7.6: LEATHER else: IRON)
    elif bowl(c) and c.z > 69.6: IRON
    else: 0
save("royal_kettle", kettle, HEAD, "head")

// mail round the face and over the shoulders (the coif), the face open
def coif(c:float3) -> bool:
    let around = vw_ball(c, float3 { 0.0, -0.4, 67.6 }, float3 { 5.2, 5.6, 6.6 }) and not (c.y > 0.6 and c.z > 63.6 and c.z < 71.4)
    let cape = vw_taper(c, 58.0, 63.0, float2 { 0.0, -0.3 }, float2 { 0.0, -0.4 }, float2 { 8.6, 5.4 }, float2 { 5.4, 5.4 })
    return (around or cape) and c.z > 58.0

// the nasal helmet: a conical iron bowl, a band at its brim, the nose guard down the face, over the coif
let nasal = vw_piece { "nasal", 0 }
vw_fill(nasal, int3 { -10, -8, 57 }, int3 { 10, 8, 80 }) c:
    let cone = vw_taper(c, 70.4, 78.6, float2 { 0.0, -0.5 }, float2 { 0.0, -0.6 }, float2 { 5.0, 5.4 }, float2 { 0.6, 0.6 })
    let band = vw_taper(c, 69.6, 70.8, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.2, 5.6 }, float2 { 5.1, 5.5 })
    let nose = abs(c.x) < 0.8 and c.y > 3.6 and c.y < 5.8 and c.z > 66.0 and c.z < 70.6
    if cone or nose: IRON
    elif band: LEATHER
    elif coif(c): IRON
    else: 0
save("royal_nasal", nasal, HEAD, "head")

// the great helm: a flat-topped iron pot over the whole head to the chin, a dark slit for the eyes, a gold cross on the face
let great = vw_piece { "greathelm", 0 }
vw_fill(great, int3 { -7, -7, 61 }, int3 { 7, 8, 77 }) c:
    let pot = vw_taper(c, 62.4, 75.4, float2 { 0.0, 0.0 }, float2 { 0.0, -0.2 }, float2 { 5.3, 5.8 }, float2 { 5.1, 5.6 })
    let slit = c.y > 3.2 and c.z > 68.6 and c.z < 69.8 and abs(c.x) > 0.8 and abs(c.x) < 4.0
    let cross = c.y > 3.6 and ((abs(c.x) < 0.8 and c.z > 63.6 and c.z < 71.6) or (abs(c.x) < 4.2 and c.z > 69.8 and c.z < 70.8))
    if not pot: 0
    elif slit: LEATHER
    elif cross: GOLD
    else: IRON
save("royal_greathelm", great, HEAD, "head")

// ---- hoods and hats

// the archer's hood: over his head, open at the face, a short cape on his shoulders, its long tail down his back
let hood = vw_piece { "hood", 0 }
vw_fill(hood, int3 { -10, -12, 50 }, int3 { 10, 8, 77 }) c:
    let over = vw_ball(c, float3 { 0.0, -0.6, 69.0 }, float3 { 5.0, 5.6, 6.2 }) and not (c.y > 0.4 and c.z < 71.6 and c.z > 63.0)
    let cape = vw_taper(c, 57.6, 64.0, float2 { 0.0, -0.3 }, float2 { 0.0, -0.4 }, float2 { 9.4, 5.8 }, float2 { 5.0, 5.2 })
    let t = (72.0 - c.z) / 20.0
    let tail = t > 0.0 and t < 1.0 and abs(c.x) < 1.2 and abs(c.y - (-5.6 - t * 1.6)) < 0.9
    if over or cape or tail: TEAM
    else: 0
save("royal_hood", hood, HEAD, "head")

// the slinger's coif: mail round the face and over the shoulders
let coif_m = vw_piece { "coif", 0 }
vw_fill(coif_m, int3 { -10, -8, 57 }, int3 { 10, 8, 76 }) c:
    if coif(c): IRON else: 0
save("royal_coif", coif_m, HEAD, "head")

// the monk: the cowl down round his neck, the black habit to his ankles over his tunic, a rope belt, the tonsure (a bald
// crown in a ring of his hair)
let cowl = vw_piece { "cowl", 0 }
vw_fill(cowl, int3 { -14, -10, 4 }, int3 { 14, 10, 76 }) c:
    let tonsure = c.z > 73.6 and c.z < 75.2 and c.x * c.x + vw_sq(c.y + 0.4) < 2.6 * 2.6
    let collar = vw_taper(c, 59.0, 64.0, float2 { 0.0, -0.8 }, float2 { 0.0, -1.2 }, float2 { 8.0, 5.8 }, float2 { 5.2, 5.4 }) and not (c.y > 0.0 and c.z > 61.0 and abs(c.x) < 3.4)
    let habit = (torso(c, 1.2) and c.z > 44.0 and not neck(c)) or
        vw_taper(c, 6.0, 44.0, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 9.4, 6.8 }, float2 { 8.4, 5.8 })
    if tonsure: SKIN
    elif collar: HABIT
    elif habit: (if c.z > 42.4 and c.z < 44.0: ROPE elif c.y > 3.0 and abs(c.x - 1.4) < 0.6 and c.z > 30.0 and c.z < 42.4: ROPE else: HABIT)
    else: 0
save("royal_cowl", cowl, HEAD, "head")

// ---- shields (drawn as the hand's frame holds them: x up, z across, the face out along +y)

// a heater's outline: a flat top, straight sides, curving in to a point at the bottom
def heater(c:float3, top:float, w:float, low:float) -> bool:
    if c.x > top: return false
    if c.x >= 2.0: return abs(c.z) < w
    let t = (2.0 - c.x) / (2.0 - low)  // (0 at the bend, 1 at the point)
    return t <= 1.0 and abs(c.z) < w * sqrt(max(0.0, 1.0 - t * t))

def face_of(c:float3, w:float) -> float: return c.y - 1.4 * (1.0 - vw_sq(c.z / (w + 1.0)))

let heat = vw_piece { "heater", 0 }
vw_fill(heat, int3 { -14, -2, -10 }, int3 { 12, 4, 10 }) c:
    let d = face_of(c, 9.0)
    let inner = heater(c, 10.0, 8.0, -11.6)
    let chev = abs(c.x - (2.0 + abs(c.z) * -0.75 + 4.0)) < 1.4
    if not heater(c, 11.0, 9.0, -13.0) or d > 0.0 or d < -1.6: 0
    elif d < -0.8: WOOD
    elif not inner: LEATHER
    elif chev: GOLD
    else: TEAM
save("royal_heater", heat, float3_0, "hand")

