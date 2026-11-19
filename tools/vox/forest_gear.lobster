// The forest body's kit (#497), drawn around forest.vox (the Roman body's proportions) in its voxels (2 a body unit) from the
// approved concept sheet (culture-kits-animals/forest-look.png), one model each, worn on the body point it rides (its offset
// printed for gear.json):
//   forest_acorn.vox  helm.acorn: an acorn's scaly cap as the helmet, its stalk on top, the nut's shell as cheek guards
//   forest_leaf.vox   hat.leaf: one broad leaf laid over the crown, its ends falling to the sides, the stem up
//   forest_hood.vox   hat.hood: the archer's hood of overlapping leaves, the face open, a short leaf mantle
//   forest_druid.vox  hat.shaman: the healer's moss hood with two small antler branches and a long white beard
//   forest_bark.vox   armour.bark: bark plates over the chest and back with their grain, rounded bark shoulders
//   lobster tools/vox/forest_gear.lobster
import .voxwrite
import .worn

let CAP, NUT, BARK, BARK_L, LEAF, LEAF_L, MOSS, MOSS_D, WHITE, TEAM = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
let COLOURS = [ 0, 0x7a5a32, 0xc8843a, 0x6a4a2e, 0x8e6a44, 0x4e8a34, 0x7ab048, 0x3f6b3a, 0x2d4a29, 0xece6d6, 0xb8302a ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- head gear

// the acorn cap: a dome a little wider than the head, its scales in rows (light and dark in turn), a short stalk, and the
// nut's smooth shell down the cheeks
let acorn = vw_piece { "acorn", 0 }
vw_fill(acorn, int3 { -8, -8, 63 }, int3 { 8, 8, 82 }) c:
    let dome = vw_ball(c, float3 { 0.0, -0.4, 70.0 }, float3 { 5.8, 6.2, 6.4 }) and c.z > 69.6
    let rim = vw_taper(c, 69.0, 70.4, float2 { 0.0, -0.4 }, float2 { 0.0, -0.4 }, float2 { 6.2, 6.6 }, float2 { 6.0, 6.4 })
    let stalk = vw_taper(c, 75.8, 79.4, float2 { 0.0, -0.4 }, float2 { 0.6, -0.4 }, float2 { 0.9, 0.9 }, float2 { 0.7, 0.7 })
    let cheek = abs(c.x) > 3.4 and abs(c.x) < 5.0 and c.y > -1.0 and c.y < 3.4 and c.z > 64.4 and c.z < 69.4 and
        vw_ball(c, float3 { 0.0, 0.6, 68.0 }, float3 { 5.0, 4.6, 5.6 })
    let scale = (int(floor(c.z + 40.0)) + int(floor(around(c) / 30.0 + 40.0))) % 2 == 0
    if stalk: BARK
    elif rim: CAP
    elif dome and not face_cut(c): (if scale: CAP else: BARK)
    elif cheek: NUT
    else: 0
save("forest_acorn", acorn, HEAD, "head")

// the leaf hat: a leaf from side to side, curved over the crown and falling at its ends, a dark rib along it, the stem up
let leafhat = vw_piece { "leaf", 0 }
vw_fill(leafhat, int3 { -10, -7, 64 }, int3 { 10, 7, 80 }) c:
    let x = c.x / 9.0
    let w = 5.6 * (1.0 - x * x)
    let top = 75.4 - vw_sq(c.x) * 0.11 - vw_sq(c.y + 0.6) * 0.06  // the leaf's surface, following the crown
    let sheet = abs(x) < 1.0 and abs(c.y + 0.6) < w and c.z < top + 0.5 and c.z > top - 1.3
    let stem = abs(c.x - 0.8) < 0.7 and abs(c.y + 0.6) < 0.7 and c.z > top and c.z < top + 3.0
    if stem: BARK
    elif sheet and abs(c.y + 0.6) < 0.6: MOSS_D
    elif sheet: (if c.x > 0.0: LEAF else: LEAF_L)
    else: 0
save("forest_leaf", leafhat, HEAD, "head")

// the leaf hood: overlapping leaves round the head and down to the shoulders, light and dark in turn, the face open
let hood = vw_piece { "hood", 0 }
vw_fill(hood, int3 { -12, -9, 52 }, int3 { 12, 9, 78 }) c:
    let shell = vw_ball(c, float3 { 0.0, -0.8, 69.4 }, float3 { 5.6, 6.0, 6.4 }) and c.z > 61.0 and not (c.y > 0.4 and c.z < 72.4)
    let mantle = torso(c, 1.4) and c.z > 55.0 - abs(sin(around(c) * 3.0)) * 2.0 and not neck(c)
    let k = int(floor(around(c) / 40.0 + 40.0)) + int(floor(c.z / 3.0))
    if shell or mantle: (if k % 2 == 0: LEAF else: MOSS)
    else: 0
save("forest_hood", hood, HEAD, "head")

// the druid: a moss hood, two small antler branches out of it, a long white beard over the chest
let druid = vw_piece { "druid", 0 }
vw_fill(druid, int3 { -11, -9, 48 }, int3 { 11, 9, 84 }) c:
    let ax = abs(c.x)
    let shell = vw_ball(c, float3 { 0.0, -0.8, 69.4 }, float3 { 5.4, 5.8, 6.2 }) and c.z > 60.0 and not (c.y > 0.6 and c.z < 72.2 and c.z > 61.0)
    let mantle = torso(c, 1.4) and c.z > 53.0 and not neck(c)
    let beam = c.y > -2.2 and c.y < -0.6 and abs(ax - 3.4 - (c.z - 74.0) * 0.6) < 0.8 and c.z > 74.0 and c.z < 81.0
    let tine = c.y > -2.2 and c.y < -0.6 and abs(ax - 4.6 + (c.z - 77.0) * 0.4) < 0.7 and c.z > 77.0 and c.z < 81.0
    let beard = (vw_ball(c, float3 { 0.0, 2.6, 62.4 }, float3 { 3.4, 2.8, 4.2 }) and c.y > 1.0) or
        (vw_taper(c, 50.0, 60.0, float2 { 0.0, 4.0 }, float2 { 0.0, 3.4 }, float2 { 0.8, 0.8 }, float2 { 2.4, 1.6 }) and c.y > 3.0)
    if beard: WHITE
    elif beam or tine: BARK_L
    elif shell: MOSS
    elif mantle: MOSS_D
    else: 0
save("forest_druid", druid, HEAD, "head")

// ---- body

// bark plates: over the chest and back to the waist, the grain running down them, and rounded bark over each shoulder
let bark = vw_piece { "bark", 0 }
vw_fill(bark, int3 { -14, -9, 45 }, int3 { 14, 9, 64 }) c:
    let plate = torso(c, 1.2) and c.z > 47.0 and c.z < 59.6 and not neck(c) and abs(c.x) < 7.4
    let shoulder = vw_ball(c, float3 { if c.x > 0.0: 9.6 else: -9.6, -0.2, 58.4 }, float3 { 3.6, 3.6, 2.8 }) and c.z > 56.4
    let grain = (int(floor(c.x + 40.0)) % 3) == 0
    if shoulder: (if c.z < 57.4: BARK else: BARK_L)
    elif plate: (if grain or c.z < 48.4: BARK else: BARK_L)
    else: 0
save("forest_bark", bark, CHEST, "chest")
