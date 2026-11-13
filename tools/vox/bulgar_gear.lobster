// The Bulgar body's worn kit (#477), drawn around bulgar.vox (the Roman body's proportions) in its voxels (2 a body unit)
// from the approved concept sheet (human-redesign/bulgar-foot.png, bulgar-riders.png), one model each, worn on the body
// point it rides (its offset printed for gear.json's `bulgar` fits):
//   bulgar_kalpak.vox     hat.fur: the black fur kalpak with a dark red band
//   bulgar_kalpak_red.vox hat.felt: the archer's kalpak, a red cloth crown on top
//   bulgar_spike.vox      helm.spike, helm.steppe_spike: a tall pointed iron helmet, a gilt band, a mail drop at the sides and back
//   bulgar_lamellar.vox   armour.lamellar: iron lamellar over the coat to the hip, shoulder guards, the red sash and belt over it
//   bulgar_lamellar_gilt.vox armour.lamellar_iron: the same with gilt edges
//   bulgar_yamurluk.vox   armour.sheepskin: the hooded goat-hair cloak to the knee, the skirmisher's
//   bulgar_fleece.vox     armour.fur_cape: a sheepskin worn fleece-out over the shoulders, crossed silver chains and coins: the haidut's
//   bulgar_priest.vox     hat.kamilavka: the Orthodox priest: a tall black hat, a long grey beard, a black cassock, a silver cross
//   lobster tools/vox/bulgar_gear.lobster
import .voxwrite
import .worn

let IRON, IRON2, FUR, BAND, RED, TEAM, GOLD, LEATHER, GOAT, GOAT2, FLEECE, CASSOCK, BEARD = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
let COLOURS = [ 0, 0x8e9298, 0x5e6268, 0x2b2622, 0x5a2a22, 0xa8322b, 0xc8a064, 0xd8b04a, 0x6b4a2c, 0x6a5a48, 0x4e4236, 0xc8b490, 0x1e1c22, 0xc8c2b6 ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- caps and helmets

// the kalpak: black fur, straight-sided and a little wider at the top, flat-topped, a dark red band at the brow; `crown`
// puts a red cloth top on it
def kalpak(c:float3, crown:bool) -> int:
    let cap = vw_taper(c, 69.6, 79.4, float2 { 0.0, -0.5 }, float2 { 0.0, -0.7 }, float2 { 5.0, 5.4 }, float2 { 5.4, 5.7 })
    let top = crown and vw_taper(c, 79.4, 80.8, float2 { 0.0, -0.6 }, float2 { 0.0, -0.6 }, float2 { 4.0, 4.3 }, float2 { 3.0, 3.3 })
    if top: return RED
    if not cap: return 0
    if c.z < 72.0: return BAND
    if crown and c.z > 78.4 and c.x * c.x + vw_sq(c.y + 0.6) < 3.6 * 3.6: return RED
    return FUR

let kal = vw_piece { "kalpak", 0 }
vw_fill(kal, int3 { -7, -7, 68 }, int3 { 7, 7, 81 }) c: kalpak(c, false)
save("bulgar_kalpak", kal, HEAD, "head")
let kalr = vw_piece { "kalpak_red", 0 }
vw_fill(kalr, int3 { -7, -7, 68 }, int3 { 7, 7, 82 }) c: kalpak(c, true)
save("bulgar_kalpak_red", kalr, HEAD, "head")

// the spiked helmet: an iron cone rising tall to a point, a gilt band at its rim, a mail drop over the ears and the neck
let spike = vw_piece { "spike", 0 }
vw_fill(spike, int3 { -8, -8, 61 }, int3 { 8, 8, 86 }) c:
    let cone = vw_taper(c, 70.8, 83.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.6 }, float2 { 5.0, 5.4 }, float2 { 0.5, 0.5 })
    let band = vw_taper(c, 69.8, 71.2, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.3, 5.7 }, float2 { 5.2, 5.6 })
    let drop = vw_ball(c, float3 { 0.0, -0.5, 68.0 }, float3 { 5.6, 6.0, 7.0 }) and c.z > 62.0 and c.z < 70.4 and not (c.y > 0.4)
    if cone: IRON
    elif band: GOLD
    elif drop: (if ((int(floor(c.z)) + int(floor(c.x + 20.0))) % 2) == 0: IRON2 else: IRON)
    else: 0
save("bulgar_spike", spike, HEAD, "head")

// ---- body armour

// lamellar: iron plates laced in rows over the coat from the neck to the hip, broad guards over the shoulders; the sash and
// the belt worn over it; `gilt` edges it in gold
def lamellar(c:float3, gilt:bool) -> int:
    let shoulder = vw_taper(c, 51.0, 59.0, float2 { 0.0, -0.2 }, float2 { 0.0, -0.4 }, float2 { 11.6, 5.8 }, float2 { 10.4, 5.6 }) and abs(c.x) > 6.0
    let coat = (torso(c, 1.6) and c.z > 44.0 and not neck(c)) or (skirt(c, 33.0, 2.2) and c.z <= 44.0)
    if not (shoulder or coat): return 0
    if not shoulder and skirt(c, 33.0, 2.2) and c.z > 40.8 and c.z <= 45.0: return RED
    if not shoulder and skirt(c, 33.0, 2.2) and c.z > 38.6 and c.z <= 40.8: return LEATHER
    if gilt and (c.z < 34.4 or (shoulder and c.z < 52.2) or (c.z > 59.6)): return GOLD
    return if (int(floor(c.z)) % 3) == 0: IRON2 else: IRON

let lam = vw_piece { "lamellar", 0 }
vw_fill(lam, int3 { -14, -9, 32 }, int3 { 14, 9, 63 }) c: lamellar(c, false)
save("bulgar_lamellar", lam, CHEST, "chest")
let lamg = vw_piece { "lamellar_gilt", 0 }
vw_fill(lamg, int3 { -14, -9, 32 }, int3 { 14, 9, 63 }) c: lamellar(c, true)
save("bulgar_lamellar_gilt", lamg, CHEST, "chest")

// the yamurluk: a cloak of brown goat hair from the shoulders to the knee, open down the front, in shaggy upright strands,
// its hood up over the head and coming to a point behind
let yam = vw_piece { "yamurluk", 0 }
vw_fill(yam, int3 { -14, -10, 24 }, int3 { 14, 9, 81 }) c:
    let ax = abs(c.x)
    let cloak = (torso(c, 1.8) and c.z > 44.0 and not neck(c)) or (skirt(c, 25.0, 3.0) and c.z <= 44.0)
    let open = c.y > 1.6 and ax < 3.4 + (52.0 - c.z) * 0.1
    let hood = (vw_ball(c, float3 { 0.0, -0.6, 69.0 }, float3 { 5.4, 5.8, 6.6 }) or
        vw_taper(c, 73.0, 79.0, float2 { 0.0, -1.4 }, float2 { 0.0, -2.6 }, float2 { 3.6, 3.8 }, float2 { 0.6, 0.6 })) and
        not (c.y > 0.6 and c.z > 62.6 and c.z < 72.2) and c.z > 60.0
    if hood: GOAT
    elif cloak and not open: (if (int(floor(c.x + 20.0)) % 3) == 0: GOAT2 else: GOAT)
    else: 0
save("bulgar_yamurluk", yam, CHEST, "chest")

// the fleece: a sheepskin worn fleece-out over the shoulders and down the back to the hip, open in front; over the shirt
// two silver chains crossed on the chest, coins where they cross
let fl = vw_piece { "fleece", 0 }
vw_fill(fl, int3 { -14, -9, 36 }, int3 { 14, 9, 63 }) c:
    let ax = abs(c.x)
    let rag = (int(floor(c.x + 20.0)) % 3) * 0.7
    let skin = ((torso(c, 1.6) and c.z > 44.0) or (skirt(c, 37.0 + rag, 2.0) and c.z <= 44.0 and c.z > 40.0)) and not neck(c)
    let open = c.y > 1.4 and ax < 4.0
    let front = torso(c, 0.6) and not torso(c, -0.2) and c.y > 2.6 and c.z > 46.0 and c.z < 58.0
    let chain = front and (abs(c.x - (c.z - 52.0) * 0.6) < 0.6 or abs(c.x + (c.z - 52.0) * 0.6) < 0.6)
    let coin = front and ax < 1.2 and abs(c.z - 52.0) < 1.6
    if skin and not open: (if (int(floor(c.z + c.x * 0.5 + 40.0)) % 4) == 0: GOAT else: FLEECE)
    elif coin: GOLD
    elif chain: IRON
    else: 0
save("bulgar_fleece", fl, CHEST, "chest")

// the priest: a tall black hat with a flat rim at its top, a long grey beard down the chest, a black cassock to the ankles,
// a silver cross on a chain below the beard
let pr = vw_piece { "priest", 0 }
vw_fill(pr, int3 { -14, -10, 4 }, int3 { 14, 10, 82 }) c:
    let ax = abs(c.x)
    let hat = vw_taper(c, 70.2, 79.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 4.9, 5.3 }, float2 { 4.9, 5.3 }) or
        vw_taper(c, 79.0, 80.2, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.8, 6.2 }, float2 { 5.8, 6.2 })
    let beard = c.y > 1.2 and (vw_taper(c, 53.0, 66.4, float2 { 0.0, 3.6 }, float2 { 0.0, 2.6 }, float2 { 1.4, 1.0 }, float2 { 3.4, 2.2 }) or
        (vw_ball(c, float3 { 0.0, 0.3, 67.8 }, float3 { 3.9, 4.3, 5.5 }) and c.z < 66.2 and not (ax < 1.2 and c.z > 64.4 and c.z < 65.4)))
    let cassock = (torso(c, 1.2) and c.z > 44.0 and not neck(c)) or
        vw_taper(c, 6.0, 44.0, float2 { 0.0, -0.9 }, float2 { 0.0, 0.0 }, float2 { 11.6, 8.8 }, float2 { 9.0, 6.2 })
    let cross = c.y > 3.0 and ((ax < 0.6 and c.z > 46.0 and c.z < 52.6) or (ax < 1.8 and c.z > 50.0 and c.z < 51.2))
    if hat: CASSOCK
    elif beard: BEARD
    elif cassock: (if cross: IRON else: CASSOCK)
    else: 0
save("bulgar_priest", pr, HEAD, "head")
