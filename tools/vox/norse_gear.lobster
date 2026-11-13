// The Norse body's kit (#473), drawn around norse.vox (the Roman body's proportions) in its voxels (2 a body unit) from the
// approved concept sheet (human-redesign/norse-foot.png, norse-riders.png), one model each, worn on the body point it rides or
// held in the hand (its offset printed for gear.json); the mail shirt is the Royal body's (royal_mail.vox):
//   norse_cap.vox        helm.norse_fur: a red wool cap rising to a soft point, a fur brim
//   norse_iron.vox       helm.norse_conical: a plain conical iron cap with a band round its rim
//   norse_spectacle.vox  helm.norse_spectacle: a round iron helmet, a guard round the eyes and down the nose
//   norse_jerkin.vox     armour.leather: a sleeveless leather jerkin to the hips
//   norse_cape.vox       armour.fur_cape: a short fur cape over the shoulders
//   norse_seer.vox       hat.seer: the seer's fur-lined hood, a long blue cloak to the ankles, a long white beard, amber beads
//   norse_shield.vox     shield.norse: a round shield painted in halves, team and white, an iron boss, a leather rim
//   lobster tools/vox/norse_gear.lobster
import .voxwrite
import .worn

let IRON, IRON2, RED, FUR, LEATHER, LEATHER2, SEER, WHITE, AMBER, TEAM, WOOD = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
let COLOURS = [ 0, 0x8e9298, 0x4a4a50, 0xa83228, 0x6b4423, 0x6b4729, 0x4a3020, 0x3a5a8a, 0xece6d6, 0xd89a30, 0x2a4a7a, 0x8a6a42 ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- helmets and caps

let cap = vw_piece { "cap", 0 }
vw_fill(cap, int3 { -7, -7, 66 }, int3 { 7, 7, 82 }) c:
    let crown = vw_taper(c, 71.0, 79.0, float2 { 0.0, -0.6 }, float2 { 0.0, -1.4 }, float2 { 4.6, 5.0 }, float2 { 1.4, 1.4 }) and not face_cut(c)
    let brim = vw_taper(c, 69.6, 72.0, float2 { 0.0, -0.6 }, float2 { 0.0, -0.6 }, float2 { 5.4, 5.8 }, float2 { 5.3, 5.7 })
    if brim: FUR
    elif crown: RED
    else: 0
save("norse_cap", cap, HEAD, "head")

let iron = vw_piece { "iron", 0 }
vw_fill(iron, int3 { -7, -7, 66 }, int3 { 7, 7, 81 }) c:
    let cone = vw_taper(c, 70.4, 78.4, float2 { 0.0, -0.5 }, float2 { 0.0, -0.6 }, float2 { 5.0, 5.4 }, float2 { 0.8, 0.8 })
    let band = vw_taper(c, 69.8, 71.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.2, 5.6 }, float2 { 5.1, 5.5 })
    if band: IRON2
    elif cone: IRON
    else: 0
save("norse_iron", iron, HEAD, "head")

let spec = vw_piece { "spectacle", 0 }
vw_fill(spec, int3 { -7, -7, 64 }, int3 { 7, 7, 78 }) c:
    let dome = vw_ball(c, float3 { 0.0, -0.5, 70.4 }, float3 { 5.0, 5.4, 5.4 }) and c.z > 70.0
    let band = vw_taper(c, 69.6, 71.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 5.2, 5.6 }, float2 { 5.1, 5.5 })
    let ex = abs(c.x) - 1.5
    let ring = c.y > 3.6 and c.y < 5.2 and abs(sqrt(ex * ex + vw_sq(c.z - 68.8)) - 1.5) < 0.5
    let nose = abs(c.x) < 0.6 and c.y > 4.0 and c.y < 5.6 and c.z > 65.6 and c.z < 70.0
    if dome or ring or nose: IRON
    elif band: IRON2
    else: 0
save("norse_spectacle", spec, HEAD, "head")

// the seer: a hood lined with fur round his face, a long blue cloak from it to the ankles, open down the front over a red
// edge; a long white beard over his own, amber beads at the throat
let seer = vw_piece { "seer", 0 }
vw_fill(seer, int3 { -14, -10, 4 }, int3 { 14, 10, 78 }) c:
    let hood = vw_ball(c, float3 { 0.0, -0.8, 69.4 }, float3 { 5.4, 5.8, 6.2 }) and c.z > 62.0 and not (c.y > 0.6 and c.z < 72.2 and c.z > 62.4)
    let lining = hood and c.y > -0.4
    let cloak = (torso(c, 1.4) and c.z > 44.0 and not neck(c)) or
        vw_taper(c, 5.0, 44.0, float2 { 0.0, -0.8 }, float2 { 0.0, 0.0 }, float2 { 10.2, 7.4 }, float2 { 8.8, 6.0 })
    let open = c.y > 3.0 and abs(c.x) < 1.4 and c.z < 58.0
    let beard = (vw_ball(c, float3 { 0.0, 2.6, 62.4 }, float3 { 3.6, 2.8, 4.2 }) and c.y > 1.0) or
        (vw_taper(c, 50.0, 60.0, float2 { 0.0, 4.0 }, float2 { 0.0, 3.4 }, float2 { 0.8, 0.8 }, float2 { 2.4, 1.6 }) and c.y > 3.0)
    let bead = c.y > 4.4 and c.z > 57.0 and c.z < 58.4 and abs(c.x) > 1.2 and abs(c.x) < 4.0 and (int(floor(c.x + 20.0)) % 2) == 0
    if beard: WHITE
    elif bead: AMBER
    elif lining: FUR
    elif hood: SEER
    elif cloak and open: 0
    elif cloak: SEER
    else: 0
save("norse_seer", seer, HEAD, "head")

// ---- body

let jerkin = vw_piece { "jerkin", 0 }
vw_fill(jerkin, int3 { -13, -9, 36 }, int3 { 13, 9, 63 }) c:
    if (torso(c, 1.4) and c.z > 44.0 and not neck(c) and c.z < 59.4) or (skirt(c, 37.0, 1.8) and c.z <= 44.0):
        if c.z > 41.6 and c.z < 43.8: LEATHER2 elif c.y > 3.6 and abs(c.x) < 0.6: LEATHER2 else: LEATHER
    else: 0
save("norse_jerkin", jerkin, CHEST, "chest")

let cape = vw_piece { "cape", 0 }
vw_fill(cape, int3 { -13, -9, 44 }, int3 { 13, 9, 63 }) c:
    let rag = (int(floor(c.x + 20.0)) % 3) * 0.8
    if torso(c, 1.4) and c.z > 50.0 - rag and not neck(c): FUR
    elif vw_taper(c, 49.0 - rag, 59.0, float2 { 0.0, -0.2 }, float2 { 0.0, -0.4 }, float2 { 11.2, 5.8 }, float2 { 10.2, 5.6 }) and abs(c.x) > 6.0: FUR
    else: 0
save("norse_cape", cape, CHEST, "chest")

// ---- the shield (drawn as the hand's frame holds it: x up, z across, the face out along +y)

let shield = vw_piece { "shield", 0 }
vw_fill(shield, int3 { -10, -2, -10 }, int3 { 10, 3, 10 }) c:
    let r = sqrt(c.x * c.x + c.z * c.z)
    let d = c.y - 0.8 * (1.0 - vw_sq(r / 10.0))
    let boss = vw_ball(c, float3 { 0.0, 1.0, 0.0 }, float3 { 1.8, 1.4, 1.8 })
    if boss: IRON
    elif r > 9.4 or d > 0.0 or d < -1.2: 0
    elif r > 8.4: LEATHER2
    elif c.z > 0.0: TEAM
    else: WHITE
save("norse_shield", shield, float3_0, "hand")
