// The Steppe body's worn kit (#465), drawn around steppe.vox (the Roman body's proportions) in its voxels (2 a body unit)
// from the approved concept sheet (human-redesign/steppe-foot.png, steppe-riders.png), one model each, worn on the body
// point it rides (its offset printed for gear.json's `steppe` fits):
//   steppe_quilted.vox      armour.leather: a quilted coat in team colour to mid-thigh
//   steppe_lamellar.vox     armour.lamellar: red-brown lacquered lamellar to mid-thigh, broad shoulder guards
//   steppe_lamellar_iron.vox armour.lamellar_iron: the same in iron
//   steppe_spike.vox        helm.spike, helm.steppe_spike: a spiked iron helmet, a red pennant, lamellar flaps over the neck
//   steppe_fur.vox          hat.fur: a red felt crown in a fur brim, the fur ear flaps down
//   steppe_felt.vox         hat.felt: the archer's white felt hat, a pointed crown, the brim turned up
//   steppe_sheepskin.vox    armour.sheepskin: a sheepskin over the shoulders, the skirmisher's
//   steppe_shaman.vox       hat.shaman: the shaman's headdress: a red band, black feathers standing up, a fringe over the eyes
//   lobster tools/vox/steppe_gear.lobster
import .voxwrite
import .worn

let IRON, IRON2, WHITE, TEAM, LEATHER, LAC, LAC2, SASH, HAIR, FUR, FLEECE, TRIM = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
let COLOURS = [ 0, 0x8e9298, 0x4a4a50, 0xece6d6, 0xc8a064, 0x5e4029, 0x7a2e1e, 0x36211f, 0xa83228, 0x1f1714, 0x6b4423, 0x6e5442, 0x8a6a3a ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- body armour

// the quilted coat: team cloth stitched in rows, from the neck to mid-thigh
let quilt = vw_piece { "quilted", 0 }
vw_fill(quilt, int3 { -13, -9, 29 }, int3 { 13, 9, 63 }) c:
    let seam = (int(floor(c.z)) % 3) == 0
    if (torso(c, 1.6) and c.z > 44.0 and not neck(c)) or (skirt(c, 30.0, 2.2) and c.z <= 44.0): (if seam: TRIM else: TEAM)
    else: 0
save("steppe_quilted", quilt, CHEST, "chest")

// lamellar: small plates laced in rows (a light plate, its dark lacing below), from the neck to mid-thigh over the deel, a
// trimmed opening down the front, broad guards over the shoulders; the sash stays over it
def lamellar(c:float3, plate:int, lace:int) -> int:
    let row = (int(floor(c.z)) % 3) == 0
    let shoulder = vw_taper(c, 51.0, 59.0, float2 { 0.0, -0.2 }, float2 { 0.0, -0.4 }, float2 { 11.6, 5.8 }, float2 { 10.4, 5.6 }) and abs(c.x) > 6.0
    let coat = (torso(c, 1.6) and c.z > 44.6 and not neck(c)) or (skirt(c, 30.0, 2.2) and c.z <= 44.6 and not (c.z > 40.4))
    if shoulder or coat:
        if c.y > 3.0 and abs(c.x) < 0.7 and not shoulder: return TRIM
        return if row: lace else: plate
    if skirt(c, 30.0, 2.2) and c.z > 40.4 and c.z <= 44.6: return SASH
    return 0

let lam = vw_piece { "lamellar", 0 }
vw_fill(lam, int3 { -14, -9, 29 }, int3 { 14, 9, 63 }) c: lamellar(c, LAC, LAC2)
save("steppe_lamellar", lam, CHEST, "chest")
let lami = vw_piece { "lamellar_iron", 0 }
vw_fill(lami, int3 { -14, -9, 29 }, int3 { 14, 9, 63 }) c: lamellar(c, IRON, IRON2)
save("steppe_lamellar_iron", lami, CHEST, "chest")

// the sheepskin: fleece over the shoulders and down the back and chest, a ragged edge
let sheep = vw_piece { "sheepskin", 0 }
vw_fill(sheep, int3 { -13, -9, 44 }, int3 { 13, 9, 63 }) c:
    let rag = (int(floor(c.x + 20.0)) % 3) * 0.8
    if torso(c, 1.4) and c.z > 51.0 - rag and not neck(c): FLEECE
    elif vw_taper(c, 50.0 - rag, 59.0, float2 { 0.0, -0.2 }, float2 { 0.0, -0.4 }, float2 { 11.2, 5.8 }, float2 { 10.2, 5.6 }) and abs(c.x) > 6.0: FLEECE
    else: 0
save("steppe_sheepskin", sheep, CHEST, "chest")

// ---- helmets and hats

// the spiked helmet: an iron bowl rising to a spike, a red pennant at its tip, lamellar flaps over the ears and the neck
let spike = vw_piece { "spike", 0 }
vw_fill(spike, int3 { -8, -8, 61 }, int3 { 8, 8, 86 }) c:
    let cone = vw_taper(c, 70.4, 80.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.6 }, float2 { 5.0, 5.4 }, float2 { 0.8, 0.8 })
    let tip = abs(c.x) < 0.5 and abs(c.y + 0.6) < 0.5 and c.z >= 80.0 and c.z < 82.0
    let pennant = c.z > 81.0 and c.z < 84.0 and abs(c.y + 0.6) < 0.5 and c.x > 0.0 and c.x < 3.0 - (c.z - 81.0) * 0.6
    let flaps = vw_ball(c, float3 { 0.0, -0.5, 68.0 }, float3 { 5.6, 6.0, 7.0 }) and c.z > 62.4 and c.z < 70.8 and not (c.y > 0.6)
    if cone or tip: IRON
    elif pennant: SASH
    elif flaps: (if (int(floor(c.z)) % 3) == 0: LAC2 else: LAC)
    else: 0
save("steppe_spike", spike, HEAD, "head")

// the fur hat: a tall rounded red felt crown with a knob, a thick fur brim round it, the ear flaps of fur down by the cheeks
let fur = vw_piece { "fur", 0 }
vw_fill(fur, int3 { -8, -8, 61 }, int3 { 8, 8, 82 }) c:
    let crown = vw_taper(c, 71.0, 78.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 4.2, 4.6 }, float2 { 3.0, 3.4 })
    let knob = vw_ball(c, float3 { 0.0, -0.5, 78.6 }, float3 { 0.8, 0.8, 0.8 })
    let brim = vw_taper(c, 69.4, 72.6, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.6, 6.0 }, float2 { 5.6, 6.0 })
    let flap = abs(c.x) > 3.6 and abs(c.x) < 5.6 and c.y > -2.0 and c.y < 1.6 and c.z > 63.0 and c.z < 70.0
    if crown or knob: SASH
    elif brim or flap: FUR
    else: 0
save("steppe_fur", fur, HEAD, "head")

// the felt hat: white felt, a pointed crown, a band, the brim turned up all round
let felt = vw_piece { "felt", 0 }
vw_fill(felt, int3 { -9, -9, 64 }, int3 { 9, 9, 84 }) c:
    let r = sqrt(c.x * c.x + vw_sq(c.y + 0.5))
    let crown = vw_taper(c, 70.4, 81.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.8 }, float2 { 4.8, 5.2 }, float2 { 0.6, 0.6 })
    let band = vw_taper(c, 70.4, 71.6, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.0, 5.4 }, float2 { 4.9, 5.3 })
    let brim = r > 4.6 and r < 7.6 and abs(c.z - (70.4 + (r - 4.6) * 0.7)) < 0.7
    if band: TEAM
    elif crown or brim: WHITE
    else: 0
save("steppe_felt", felt, HEAD, "head")

// the shaman's headdress: a red band round the brow, black feathers standing in a ring above it, a black fringe over the eyes
let shaman = vw_piece { "shaman", 0 }
vw_fill(shaman, int3 { -8, -8, 63 }, int3 { 8, 9, 86 }) c:
    let r = sqrt(c.x * c.x + vw_sq(c.y + 0.4))
    let band = r < 5.2 and c.z > 70.0 and c.z < 72.0 and not (r < 4.2)
    // (eight feathers splaying out from the band, every other one taller)
    let k = (around(c) + 3.14159) / 6.28318 * 8.0
    let n = int(floor(k + 0.5))
    let lean = (c.z - 72.0) * 0.3
    let feather = abs(k - n) < 0.2 and r > 3.4 + lean and r < 4.4 + lean and c.z >= 72.0 and c.z < 79.0 + (n % 2) * 3.0
    let fringe = c.y > 3.6 and c.y < 5.2 and abs(c.x) < 3.4 and c.z > 65.0 and c.z < 70.0 and (int(floor(c.x + 20.0)) % 2) == 0
    if band: SASH
    elif feather or fringe: HAIR
    else: 0
save("steppe_shaman", shaman, HEAD, "head")
