// The Greek body's worn kit (#451), drawn around greek.vox in its voxels (2 a body unit) from the approved concept sheet
// (human-redesign/greeks-foot.png), one model each, worn on the body point it rides (its offset printed for gear.json's
// `greek` fits):
//   greek_linen.vox       armour.leather: a linen corslet, its yokes over the shoulders, a team band, strips below
//   greek_scale.vox       armour.bronze: the corslet faced with bronze scales
//   greek_cuirass.vox     armour.cuirass: a bronze muscle cuirass, linen strips below
//   greek_pilos.vox       helm.cap: a bronze cone
//   greek_thracian.vox    helm.bronze: a peak curling forward, a brim over the brow, cheek guards
//   greek_corinthian.vox  helm.corinthian: closed but for a T at the eyes and mouth, a tall team crest
//   greek_attic.vox       helm.attic: open face, a brow peak, cheek guards, a tall team crest on a stand
//   greek_hoplon.vox      shield.hoplon: big, round and dished, team colour, a white lambda, a bronze rim
//   greek_thureos.vox     shield.thureos: a white oval, a team rim, an iron spine and boss
//   greek_pelte.vox       shield.pelte: a wicker crescent, a team rim
//   greek_band.vox        hat.band: the Cretan archer's band round his curls, its ends down the back
//   greek_fox.vox         hood.fox: the skirmisher's tall fox-skin cap, ear flaps, the fox's face on top
//   greek_wreath.vox      hat.wreath: the healer priest's laurel wreath, long grey beard, mantle off one shoulder
//   lobster tools/vox/greek_gear.lobster
import .voxwrite
import .worn

let BRONZE, BRONZE_HI, LINEN, TEAM, LEATHER, IRON, WICKER, FOX, LAUREL, MANTLE, GREY = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
let COLOURS = [ 0, 0xb8893a, 0xe0b860, 0xece6d4, 0x3a5fa0, 0x5e4029, 0x8e9298, 0xa88a52, 0xb86a32, 0x54853a, 0xcdb98a, 0xd8d4cc ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- body armour: the corslet's parts, shared

// the yokes: a doubled layer over each shoulder, tied down on the chest
def yoke(c:float3) -> bool: return torso(c, 2.3) and c.z > 57.0 and abs(c.x) > 3.4 and not neck(c)
// the strips (pteruges) below the waist: every other one, so the chiton shows between them
def pteruges(c:float3) -> bool:
    return skirt(c, 37.0, 1.4) and c.z < 44.5 and (int(floor(around(c) / 18.0)) % 2 + 2) % 2 == 0

let linen = vw_piece { "linen", 0 }
vw_fill(linen, int3 { -13, -8, 35 }, int3 { 13, 8, 63 }) c:
    if yoke(c): LINEN
    elif torso(c, 1.5) and c.z > 44.5 and not neck(c): (if c.z > 47.0 and c.z < 49.6: TEAM else: LINEN)
    elif pteruges(c): LINEN
    else: 0
save("greek_linen", linen, CHEST, "chest")

// scales: rows of bronze, every other row a brighter edge, each row's scales offset by half
let scale = vw_piece { "scale", 0 }
vw_fill(scale, int3 { -13, -8, 35 }, int3 { 13, 8, 63 }) c:
    let row = int(floor(c.z)) / 2
    let lit = (int(floor(c.x + 20.0)) + row) % 3 == 0
    if yoke(c): LINEN
    elif torso(c, 1.5) and c.z > 44.5 and not neck(c):
        if c.z > 44.5 and c.z < 46.4: TEAM  // (the belt)
        elif c.z < 56.5: (if lit: BRONZE_HI else: BRONZE)
        else: LINEN
    elif pteruges(c): LINEN
    else: 0
save("greek_scale", scale, CHEST, "chest")

// the muscle cuirass: bronze shaped as a chest, the pectorals and a line down the middle bright, linen strips below
let cuirass = vw_piece { "cuirass", 0 }
vw_fill(cuirass, int3 { -13, -8, 35 }, int3 { 13, 8, 63 }) c:
    let ax = abs(c.x)
    let pec = vw_ball(c, float3 { 3.4, 4.8, 54.4 }, float3 { 3.2, 1.6, 2.4 }) or vw_ball(c, float3 { -3.4, 4.8, 54.4 }, float3 { 3.2, 1.6, 2.4 })
    let line = c.y > 3.6 and ax < 0.6 and c.z > 46.0 and c.z < 56.0
    if torso(c, 1.6) and c.z > 43.6 and not neck(c): (if pec or line: BRONZE_HI elif c.z < 45.0: BRONZE_HI else: BRONZE)
    elif pteruges(c): (if c.z > 43.0: LEATHER else: LINEN)
    else: 0
save("greek_cuirass", cuirass, CHEST, "chest")

// ---- helmets

// the pilos: a bronze cone straight up from a brighter band at the brow
let pilos = vw_piece { "pilos", 0 }
vw_fill(pilos, int3 { -6, -7, 66 }, int3 { 6, 6, 81 }) c:
    let band = vw_taper(c, 69.4, 70.8, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.0, 5.4 }, float2 { 4.9, 5.3 }) and not face_cut(c)
    let top = vw_taper(c, 70.8, 79.6, float2 { 0.0, -0.5 }, float2 { 0.0, -0.8 }, float2 { 4.8, 5.2 }, float2 { 0.5, 0.5 })
    if band: BRONZE_HI
    elif top: BRONZE
    else: 0
save("greek_pilos", pilos, HEAD, "head")

// the Thracian: a bowl whose top curls forward into a peak, a brim jutting over the brow, long cheek guards
let thracian = vw_piece { "thracian", 0 }
vw_fill(thracian, int3 { -6, -8, 63 }, int3 { 6, 9, 79 }) c:
    let ax = abs(c.x)
    let peak = vw_ball(c, float3 { 0.0, 1.6, 74.6 }, float3 { 1.6, 4.4, 2.4 }) and c.z > 73.0
    let brim = c.z > 70.4 and c.z < 71.6 and c.y > 0.0 and c.y < 7.0 and ax < 4.6 - max(0.0, c.y - 4.0) * 0.6
    let cheek = ax > 3.8 and ax < 4.8 and c.y > -0.6 and c.y < 3.0 and c.z > 63.6 and c.z < 70.4
    if peak: BRONZE
    elif brim: BRONZE_HI
    elif bowl(c): BRONZE
    elif cheek: (if c.z < 64.8: BRONZE_HI else: BRONZE)
    else: 0
save("greek_thracian", thracian, HEAD, "head")

// a crest fore and aft in team colour (3 voxels thick end to end: thinner, the bake loses it)
def crest(c:float3, z:float, h:float) -> bool:
    return abs(c.x) < 1.2 and vw_ball(c, float3 { 0.0, -1.0, z }, float3 { 1.2, 5.6, h }) and c.z > z

// the Corinthian: the whole head closed in bronze to the chin, a T of dark at the eyes and down to the mouth, a tall crest
let corinthian = vw_piece { "corinthian", 0 }
vw_fill(corinthian, int3 { -6, -8, 62 }, int3 { 6, 7, 84 }) c:
    let shell = vw_ball(c, float3 { 0.0, 0.0, 69.2 }, float3 { 5.0, 5.8, 6.6 }) and c.z > 63.0
    let eyes = c.z > 67.8 and c.z < 69.4 and abs(c.x) > 0.7 and abs(c.x) < 3.6
    let mouth = c.z < 67.8 and abs(c.x) < 1.2
    let open = c.y > 2.4 and (eyes or mouth)
    if crest(c, 75.0, 5.6): TEAM
    elif shell and not open: (if c.z < 64.4 or (c.y > 3.6 and c.z > 69.4 and c.z < 70.8): BRONZE_HI else: BRONZE)
    else: 0
save("greek_corinthian", corinthian, HEAD, "head")

// the Attic: an open bowl, a brow peak, cheek guards, a crest on a stand above it
let attic = vw_piece { "attic", 0 }
vw_fill(attic, int3 { -6, -8, 63 }, int3 { 6, 7, 86 }) c:
    let ax = abs(c.x)
    let peak = c.z > 70.6 and c.z < 72.0 and c.y > 0.6 and c.y < 5.8 and ax < 4.4
    let cheek = ax > 3.8 and ax < 4.8 and c.y > -0.6 and c.y < 3.2 and c.z > 64.0 and c.z < 70.6
    let stand = vw_taper(c, 74.0, 77.4, float2 { 0.0, -0.8 }, float2 { 0.0, -0.8 }, float2 { 1.0, 1.0 }, float2 { 1.0, 1.0 })
    if crest(c, 77.0, 5.0): TEAM
    elif stand: BRONZE_HI
    elif peak: BRONZE_HI
    elif bowl(c): BRONZE
    elif cheek: BRONZE
    else: 0
save("greek_attic", attic, HEAD, "head")

// ---- shields (drawn as the hand's frame holds them: x up, z across, the face out along +y)

// the hoplon: big and round, dished out to the front, the face in team colour with a white lambda, a bronze rim
let hoplon = vw_piece { "hoplon", 0 }
vw_fill(hoplon, int3 { -18, -2, -18 }, int3 { 18, 6, 18 }) c:
    let r = sqrt(c.x * c.x + c.z * c.z) / 17.0
    let d = c.y - 3.6 * (1.0 - r * r)
    // the lambda: two strokes from the apex at the top down to the bottom at each side
    let t = (10.0 - c.x) / 20.0
    let lam = t > 0.0 and t < 1.0 and abs(abs(c.z) - t * 8.0) < 1.3
    if r > 1.0 or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER
    elif r > 0.86: (if r > 0.93: BRONZE_HI else: BRONZE)
    elif lam: LINEN
    else: TEAM
save("greek_hoplon", hoplon, float3_0, "hand")

// the thureos: a tall white oval, a team rim, an iron spine and a long boss
let thureos = vw_piece { "thureos", 0 }
vw_fill(thureos, int3 { -21, -2, -13 }, int3 { 21, 7, 13 }) c:
    let e = vw_sq(c.x / 20.5) + vw_sq(c.z / 12.5)
    let d = c.y - 3.6 * (1.0 - vw_sq(c.z / 13.0))
    let boss = vw_ball(c, float3 { 0.0, 4.4, 0.0 }, float3 { 4.4, 2.0, 2.4 })
    if boss: IRON
    elif e > 1.0 or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER
    elif e > 0.84: TEAM
    elif abs(c.z) < 0.8: IRON
    else: LINEN
save("greek_thureos", thureos, float3_0, "hand")

// the pelte: a crescent of wicker, the bite out of its top, a team rim
let pelte = vw_piece { "pelte", 0 }
vw_fill(pelte, int3 { -13, -2, -13 }, int3 { 13, 5, 13 }) c:
    let r = sqrt(c.x * c.x + c.z * c.z) / 12.5
    let bite = vw_sq((c.x - 11.0) / 7.0) + vw_sq(c.z / 7.5) < 1.0
    let d = c.y - 2.4 * (1.0 - r * r)
    let weave = (int(floor(c.x + 20.0)) / 2 + int(floor(c.z + 20.0)) / 2) % 2 == 0
    if r > 1.0 or bite or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER
    elif r > 0.84 or vw_sq((c.x - 11.0) / 8.6) + vw_sq(c.z / 9.1) < 1.0: TEAM
    else: (if weave: WICKER else: LEATHER)
save("greek_pelte", pelte, float3_0, "hand")

// ---- hats and hoods

// the Cretan archer's band: round his curls above the brow, its tied ends down the back of his head
let band = vw_piece { "band", 0 }
vw_fill(band, int3 { -7, -8, 63 }, int3 { 7, 7, 74 }) c:
    let ring = vw_taper(c, 70.0, 71.8, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 5.3, 5.7 }, float2 { 5.3, 5.7 }) and
        not vw_taper(c, 69.0, 73.0, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 4.1, 4.5 }, float2 { 4.1, 4.5 })
    let ends = c.y < -4.4 and c.y > -6.4 and c.z > 64.0 and c.z < 70.0 and abs(abs(c.x) - 0.9 - (70.0 - c.z) * 0.12) < 0.7
    if ring or ends: TEAM
    else: 0
save("greek_band", band, HEAD, "head")

// the fox-skin cap: tall and round, its flaps down over the ears and the nape, the fox's face and ears on top
let fox = vw_piece { "fox", 0 }
vw_fill(fox, int3 { -7, -8, 60 }, int3 { 7, 9, 84 }) c:
    let ax = abs(c.x)
    let cap = vw_ball(c, float3 { 0.0, -0.6, 72.0 }, float3 { 5.0, 5.4, 7.6 }) and c.z > 69.4 and not face_cut(c)
    let flap = ax > 3.8 and ax < 5.4 and c.y > -2.6 and c.y < 1.6 and c.z > 62.0 and c.z < 70.0
    let nape = c.y < -3.6 and c.y > -6.0 and ax < 4.0 and c.z > 63.0 and c.z < 70.0
    let snout = vw_ball(c, float3 { 0.0, 4.2, 76.0 }, float3 { 1.6, 2.8, 1.4 })
    let ear = vw_ball(c, float3 { 2.4, -0.6, 79.4 }, float3 { 0.9, 0.7, 1.6 }) or vw_ball(c, float3 { -2.4, -0.6, 79.4 }, float3 { 0.9, 0.7, 1.6 })
    if snout: (if c.y > 6.0: LEATHER elif c.z < 75.4: GREY else: FOX)
    elif ear: FOX
    elif flap or nape: (if c.z < 63.4: GREY else: FOX)
    elif cap: FOX
    else: 0
save("greek_fox", fox, HEAD, "head")

// the healer priest: a laurel wreath on his curls, a long grey beard, his mantle over the left shoulder and round his
// back, the right shoulder bare
let wreath = vw_piece { "wreath", 0 }
vw_fill(wreath, int3 { -13, -8, 44 }, int3 { 13, 8, 75 }) c:
    let ring = vw_taper(c, 70.6, 72.6, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 5.4, 5.8 }, float2 { 5.0, 5.4 }) and
        not vw_taper(c, 69.0, 74.0, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 4.2, 4.6 }, float2 { 4.2, 4.6 })
    let leaf = (int(floor(around(c) / 24.0)) % 2 + 2) % 2 == 0
    let beard = vw_ball(c, float3 { 0.0, 1.8, 62.4 }, float3 { 3.9, 4.4, 5.4 }) and c.y > 1.4 and c.z < 66.8 and
        not (abs(c.x) < 1.2 and c.z > 65.4)  // (the mouth)
    let mantle = torso(c, 1.2) and c.z > 45.0 and not neck(c) and c.x < 3.0 - (c.z - 46.0) * 0.55
    if ring and c.y > -4.0: (if leaf: LAUREL else: BRONZE_HI)
    elif beard: GREY
    elif mantle: MANTLE
    else: 0
save("greek_wreath", wreath, HEAD, "head")
