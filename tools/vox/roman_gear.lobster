// The Roman body's worn kit (#417), drawn around roman.vox in its voxels (2 a body unit) from the approved concept
// sheet, one model each, worn on the body point it rides (its offset printed for gear.json's `roman` fits):
//   roman_galea.vox        helm.galea: iron bowl, a brass band over the brow, cheek guards, a flared neck guard, a crest
//   roman_montefortino.vox helm.cap: a tall bronze bowl, a knob with a black horsehair tail down the back, a short neck lip
//   roman_leather.vox      armour.leather: a leather jerkin to the waist, strips (pteruges) at the shoulders and hips
//   roman_mail.vox         armour.bronze: mail to the hip, doubled over the shoulders
//   roman_segmentata.vox   armour.lorica: iron bands round the body and over the shoulders, a studded apron below
//   roman_scutum.vox       shield.scutum: a tall curved shield in team colour, rim, spina, boss, gold wings (#442)
//   roman_centurion.vox    hero.helm_transverse: a silvered galea, a team crest across it (#442)
//   roman_petasus.vox      hat.petasus: the spearman's broad sun hat (#448)
//   roman_pectoral.vox     armour.pectoral: a bronze plate on the chest on leather straps (#448)
//   roman_scutum_oval.vox  shield.scutum_oval: the spearman's oval scutum, a pale spine and boss (#448)
//   roman_cone.vox         helm.cone: the eastern archer's cone helmet, with his beard (#448)
//   roman_wolf.vox         hood.wolf: the skirmisher's wolf pelt, its muzzle on his brow, down his back (#448)
//   roman_veil.vox         hat.veil: the healer priest's mantle drawn over his head, and his long white beard (#448)
//   roman_lion.vox         hero.lion_hood: a lion's scalp over the head, its mane to the shoulders (#448)
//   roman_parma.vox        shield.parma: the cavalryman's flat oval, smaller than the scutum, clear of his horse (#455)
//   lobster tools/vox/roman_gear.lobster
import .voxwrite
import .worn

let METAL, BRASS, HIDE, LEATHER, BRONZE, TEAM, GOLD, HAIR, WOLF, WHITE, MANE, MANTLE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
let COLOURS = [ 0, 0x8e9298, 0xc9a24a, 0x8a6a48, 0x5e4029, 0xb8893a, 0x9b2f2f, 0xe8c86a, 0x1e1b19, 0x8a8276, 0xf0ebe0, 0x6b4423, 0xcdb98a ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

let galea = vw_piece { "galea", 0 }
vw_fill(galea, int3 { -6, -8, 63 }, int3 { 6, 5, 79 }) c:
    let ax = abs(c.x)
    let nape = c.y < -3.0 and c.y > -7.6 and c.z > 64.6 and c.z < 66.2 and ax < 5.0 - (c.y + 3.0) * -0.4
    let cheek = ax > 3.8 and ax < 4.8 and c.y > 0.0 and c.y < 2.6 and c.z > 64.6 and c.z < 68.3
    let knob = vw_ball(c, float3 { 0.0, -0.5, 75.0 }, float3 { 0.8, 0.8, 0.9 })
    // a crest of horsehair fore and aft in team colour, standing on the knob: what makes it a galea at game size
    let crest = abs(c.x) < 1.0 and vw_ball(c, float3 { 0.0, -0.8, 74.0 }, float3 { 1.0, 4.6, 4.4 }) and c.z > 73.2
    if crest: TEAM
    elif knob: BRASS
    elif bowl(c): (if c.z < 71.9 and c.y > -1.0 and c.z > 70.0: BRASS else: METAL)
    elif nape: (if c.y < -6.0: BRASS else: METAL)
    elif cheek: BRASS
    else: 0
save("roman_galea", galea, HEAD, "head")

let monte = vw_piece { "montefortino", 0 }
vw_fill(monte, int3 { -6, -12, 60 }, int3 { 6, 5, 80 }) c:
    let lip = c.y < -3.0 and c.y > -6.4 and c.z > 65.6 and c.z < 66.8 and abs(c.x) < 4.0
    // a taller bowl than the galea's, rising to a point under the knob: its shape tells it at game size
    let tall = vw_ball(c, float3 { 0.0, -0.5, 70.4 }, float3 { 4.8, 5.2, 6.0 }) and not face_cut(c)
    let knob = vw_taper(c, 75.6, 77.6, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 1.1, 1.1 }, float2 { 0.7, 0.7 })
    // the black horsehair tail from the knob, hanging down the back
    let t = (77.0 - c.z) / 14.0  // 0 at the knob, 1 at the shoulders
    let tail = t > 0.0 and t < 1.0 and abs(c.x) < 1.6 - t * 0.6 and abs(c.y - (-1.5 - 5.5 * sqrt(t) - 1.0 * t)) < 1.1
    if knob: BRONZE
    elif tail and not tall: HAIR
    elif lip: BRONZE
    elif tall and c.z > 67.0: (if c.z < 68.4: BRASS else: BRONZE)
    else: 0
save("roman_montefortino", monte, HEAD, "head")

// the leather jerkin: over the tunic to the waist, its strips hanging at the shoulders and over the hips
let leather = vw_piece { "leather", 0 }
vw_fill(leather, int3 { -13, -8, 36 }, int3 { 13, 8, 63 }) c:
    let a = around(c)
    let strip = (int(floor(a / 18.0)) % 2 + 2) % 2 == 0
    if torso(c, 1.5) and c.z > 45.0 and not neck(c): HIDE
    elif skirt(c, 38.0, 1.4) and c.z < 45.0 and strip: LEATHER
    elif c.z > 57.5 and c.z < 61.0 and abs(c.x) > 9.0 and abs(c.x) < 12.4 and abs(c.y) < 2.8 and (int(floor(c.y + 8.0)) % 2 == 0): LEATHER
    else: 0
save("roman_leather", leather, CHEST, "chest")

// mail: from the hip to the neck, a doubled cape of it over the shoulders, brass hooks on the chest
let mail = vw_piece { "mail", 0 }
vw_fill(mail, int3 { -13, -8, 34 }, int3 { 13, 8, 63 }) c:
    let doubler = torso(c, 2.2) and c.z > 57.0 and not neck(c)
    if doubler: (if c.y > 3.5 and abs(c.x) < 3.0 and c.z < 59.0: BRASS else: METAL)
    elif torso(c, 1.5) and not neck(c): METAL
    elif skirt(c, 36.0, 1.4) and c.z < 44.5: METAL
    else: 0
save("roman_mail", mail, CHEST, "chest")

// the segmentata: iron bands round the body, the gap between each a dark line; bands over the shoulders; below the
// belt an apron of studded straps hanging in front
let seg = vw_piece { "segmentata", 0 }
vw_fill(seg, int3 { -13, -8, 33 }, int3 { 13, 8, 64 }) c:
    let ax = abs(c.x)
    let band = (int(floor(c.z)) - 44) % 4 == 0
    let shoulder = torso(c, 2.4) and c.z > 57.5 and ax > 3.6 and not neck(c)
    let apron = c.z > 34.0 and c.z < 44.0 and c.y > 4.0 and c.y < 6.6 and ax < 3.5 and (int(floor(c.x + 10.0)) % 2 == 0)
    if shoulder: (if (int(floor(ax)) % 4 == 0): LEATHER else: METAL)
    elif torso(c, 1.5) and c.z > 44.0 and not neck(c): (if band: LEATHER elif c.y > 4.0 and ax < 1.0 and c.z > 52.0 and c.z < 54.0: BRASS else: METAL)
    elif apron: (if (int(floor(c.z)) % 3 == 0): BRASS else: LEATHER)
    else: 0
save("roman_segmentata", seg, CHEST, "chest")

// the scutum: a tall rectangle curved round the bearer (the face bowed out in front, +y), team colour, a bronze rim and
// spina, a boss in the middle, gold wings and bolts out from it; held on the hand at its middle
let scutum = vw_piece { "scutum", 0 }
// (drawn lying on its side: the hand's frame holds it with its x up, so the shield's height runs along x, its width along z)
vw_fill(scutum, int3 { -22, -2, -14 }, int3 { 22, 8, 14 }) c:
    let ax = abs(c.z)
    let az = abs(c.x)
    let face = 5.0 * (1.0 - vw_sq(c.z / 14.0))  // the curve: the face's y across the shield
    let d = c.y - face
    let boss = vw_ball(c, float3 { 0.0, 5.6, 0.0 }, float3 { 3.0, 2.4, 3.0 })
    if boss: BRASS
    elif ax > 13.0 or az > 21.0 or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER                           // the wooden back
    elif ax > 12.0 or az > 20.0 or ax < 0.8: BRONZE  // the rim and the spina
    // the wings: two rays up and out, two down and out, one straight out, each side
    elif ax > 3.0 and ax < 11.5 and (abs(az - (ax - 3.0) * 0.7 - 1.5) < 0.8 or az < 0.8): GOLD
    else: TEAM
save("roman_scutum", scutum, float3_0, "hand")

// the centurion's helmet (the hero): a silvered galea with a tall crest across it, ear to ear, in team colour
let cent = vw_piece { "centurion", 0 }
vw_fill(cent, int3 { -10, -8, 63 }, int3 { 10, 5, 81 }) c:
    let ax = abs(c.x)
    let nape = c.y < -3.0 and c.y > -7.6 and c.z > 64.6 and c.z < 66.2 and ax < 5.0 - (c.y + 3.0) * -0.4
    let cheek = ax > 3.8 and ax < 4.8 and c.y > 0.0 and c.y < 2.6 and c.z > 64.6 and c.z < 68.3
    let crest = abs(c.y + 0.6) < 1.6 and vw_sq(c.x / 9.0) + vw_sq((c.z - 72.0) / 7.0) <= 1.0 and c.z > 72.6  // (3 voxels thick end to end: thinner, the bake loses its tips)
    if crest: TEAM
    elif bowl(c): (if c.z < 71.9 and c.y > -1.0 and c.z > 70.0: GOLD else: METAL)
    elif nape: (if c.y < -6.0: GOLD else: METAL)
    elif cheek: GOLD
    else: 0
save("roman_centurion", cent, HEAD, "head")

// ---- the sheet's markers (#448)

// the spearman's petasus: a broad brim over the brow, a low crown on the hair
let petasus = vw_piece { "petasus", 0 }
vw_fill(petasus, int3 { -9, -10, 70 }, int3 { 9, 8, 76 }) c:
    let brim = vw_taper(c, 71.4, 72.4, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 8.0, 8.4 }, float2 { 7.6, 8.0 })
    let crown = vw_ball(c, float3 { 0.0, -0.5, 72.0 }, float3 { 4.5, 4.9, 3.4 }) and c.z > 71.4
    if crown: (if c.z < 73.0: HIDE else: LEATHER)
    elif brim: LEATHER
    else: 0
save("roman_petasus", petasus, HEAD, "head")

// the pectoral: a square bronze plate on the chest, a boss in it, on straps over the shoulders
let pectoral = vw_piece { "pectoral", 0 }
vw_fill(pectoral, int3 { -9, -8, 48 }, int3 { 9, 8, 63 }) c:
    let ax = abs(c.x)
    let shell = torso(c, 1.4) and not torso(c, 0.2)
    if shell and c.y > 2.0 and ax < 3.6 and c.z > 49.5 and c.z < 55.5: (if ax < 1.0 and c.z > 51.6 and c.z < 53.6: BRASS else: BRONZE)
    elif shell and abs(ax - 3.2) < 0.8 and c.z > 55.5 and not neck(c): LEATHER
    else: 0
save("roman_pectoral", pectoral, CHEST, "chest")

// the oval scutum: as the scutum, an oval; a pale spine down it, a long boss (drawn on its side, as the scutum)
let oval = vw_piece { "scutum_oval", 0 }
vw_fill(oval, int3 { -23, -2, -14 }, int3 { 23, 8, 14 }) c:
    let e = vw_sq(c.x / 22.5) + vw_sq(c.z / 13.5)
    let face = 4.6 * (1.0 - vw_sq(c.z / 14.0))
    let d = c.y - face
    let boss = vw_ball(c, float3 { 0.0, 5.2, 0.0 }, float3 { 4.2, 2.0, 2.6 })
    if boss: HIDE
    elif e > 1.0 or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER
    elif e > 0.86: BRONZE      // the rim
    elif abs(c.z) < 0.8: HIDE  // the spine
    else: TEAM
save("roman_scutum_oval", oval, float3_0, "hand")

// the archer's cone helmet over a brass band, and his beard (he's an auxiliary from the east: the beard is his)
let cone = vw_piece { "cone", 0 }
vw_fill(cone, int3 { -6, -7, 61 }, int3 { 6, 6, 80 }) c:
    let band = vw_taper(c, 69.6, 70.8, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 4.9, 5.3 }, float2 { 4.8, 5.2 }) and not face_cut(c)
    let top = vw_taper(c, 70.8, 78.4, float2 { 0.0, -0.5 }, float2 { 0.0, -0.6 }, float2 { 4.7, 5.1 }, float2 { 0.4, 0.4 })
    let beard = vw_ball(c, float3 { 0.0, 1.0, 64.4 }, float3 { 3.9, 4.6, 3.4 }) and c.y > 1.2 and c.z < 66.8 and
        not (abs(c.x) < 1.2 and c.z > 65.4)  // (the mouth)
    if top: METAL
    elif band: BRASS
    elif beard: HAIR
    else: 0
save("roman_cone", cone, HEAD, "head")

// the skirmisher's wolf pelt: the scalp over his head, the muzzle on his brow, ears up, the hide down his back
let wolf = vw_piece { "wolf", 0 }
vw_fill(wolf, int3 { -8, -9, 54 }, int3 { 8, 8, 79 }) c:
    let scalp = vw_ball(c, float3 { 0.0, -0.6, 69.8 }, float3 { 5.0, 5.4, 5.2 }) and not face_cut(c)
    let muzzle = vw_ball(c, float3 { 0.0, 4.6, 71.8 }, float3 { 2.0, 3.4, 1.6 })
    let ear = vw_ball(c, float3 { 2.6, -0.4, 75.0 }, float3 { 0.9, 0.7, 1.4 }) or vw_ball(c, float3 { -2.6, -0.4, 75.0 }, float3 { 0.9, 0.7, 1.4 })
    let back = vw_taper(c, 55.0, 68.0, float2 { 0.0, -4.6 }, float2 { 0.0, -3.4 }, float2 { 6.4, 2.6 }, float2 { 4.4, 2.6 }) and c.y < -2.6
    if muzzle: (if c.y > 7.2: HAIR else: WOLF)
    elif ear or scalp or back: WOLF
    else: 0
save("roman_wolf", wolf, HEAD, "head")

// the healer priest's mantle drawn over his head, down his back and shoulders, and his long white beard
let veil = vw_piece { "veil", 0 }
vw_fill(veil, int3 { -9, -8, 55 }, int3 { 9, 7, 77 }) c:
    let hood = vw_ball(c, float3 { 0.0, -0.6, 69.8 }, float3 { 5.0, 5.5, 5.5 }) and not (c.y > 0.8 and c.z < 72.0)
    let drape = vw_taper(c, 57.0, 68.0, float2 { 0.0, -0.6 }, float2 { 0.0, -0.8 }, float2 { 9.2, 5.6 }, float2 { 5.0, 5.4 }) and c.y < 0.8
    let beard = vw_ball(c, float3 { 0.0, 1.8, 62.6 }, float3 { 3.8, 4.4, 5.2 }) and c.y > 1.4 and c.z < 66.6 and
        not (abs(c.x) < 1.2 and c.z > 65.4)
    if beard: WHITE
    elif hood or drape: MANTLE
    else: 0
save("roman_veil", veil, HEAD, "head")

// the lion hood: the scalp over the head, the lion's face on the brow, its ears; the mane round the sides and back
let lion = vw_piece { "lion", 0 }
vw_fill(lion, int3 { -9, -10, 55 }, int3 { 9, 9, 80 }) c:
    let scalp = vw_ball(c, float3 { 0.0, -0.6, 70.0 }, float3 { 5.2, 5.6, 5.4 }) and not face_cut(c)
    let face = vw_ball(c, float3 { 0.0, 4.6, 72.0 }, float3 { 2.8, 3.0, 2.2 })
    let ear = vw_ball(c, float3 { 3.2, -0.2, 75.2 }, float3 { 1.0, 0.8, 1.0 }) or vw_ball(c, float3 { -3.2, -0.2, 75.2 }, float3 { 1.0, 0.8, 1.0 })
    let mane = vw_ball(c, float3 { 0.0, -1.4, 67.4 }, float3 { 7.6, 6.2, 8.4 }) and c.y < 1.4 and not vw_ball(c, float3 { 0.0, -0.6, 67.8 }, float3 { 4.6, 5.0, 6.6 })
    let dark = (c.y > 7.0 and abs(c.x) < 1.0) or (c.y > 6.0 and abs(abs(c.x) - 1.6) < 0.6 and c.z > 72.6)  // (its nose, its eyes)
    if face: (if dark: HAIR else: HIDE)
    elif ear or scalp: HIDE
    elif mane and c.z > 57.0: MANE
    else: 0
save("roman_lion", lion, HEAD, "head")

// the cavalryman's shield (#455): a flat oval, short enough to ride clear of the horse; team colour, a bronze rim, a boss
let parma = vw_piece { "parma", 0 }
vw_fill(parma, int3 { -16, -2, -11 }, int3 { 16, 6, 11 }) c:
    let e = vw_sq(c.x / 15.5) + vw_sq(c.z / 10.5)
    let d = c.y - 1.2 * (1.0 - vw_sq(c.z / 11.0))
    let boss = vw_ball(c, float3 { 0.0, 2.4, 0.0 }, float3 { 2.6, 1.8, 2.6 })
    if boss: BRASS
    elif e > 1.0 or d > 0.0 or d < -1.6: 0
    elif d < -0.8: LEATHER
    elif e > 0.82: BRONZE
    else: TEAM
save("roman_parma", parma, float3_0, "hand")
