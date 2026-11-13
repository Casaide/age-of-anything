// The Han body's kit (#469), drawn around han.vox (the Roman body's proportions) in its voxels (2 a body unit) from the
// approved concept sheet (human-redesign/han-foot.png, han-riders.png), one model each, worn on the body point it rides or
// held in the hand (its offset printed for gear.json):
//   han_wrap.vox      helm.han_topknot: a white cloth bound over the hair and the topknot
//   han_red_wrap.vox  hat.headwrap: the same in dark red, the archer's
//   han_cap.vox       helm.han_cap: an iron cap, a knob at its top, a riveted band
//   han_hood.vox      helm.han_lamellar: an iron cap with a lamellar hood down over the ears and the neck
//   han_black.vox     armour.leather: black lacquered lamellar laced in red, to the hips, broad shoulder guards
//   han_iron.vox      armour.han_iron: iron lamellar, to the hips, broad shoulder guards
//   han_straw.vox     hat.straw: a wide conical straw hat
//   han_daoist.vox    hat.daoist: the Daoist's tall black gauze cap and jade pin, a long slate-blue robe edged in white
//   han_lacquer.vox   shield.lacquer: a tall shield rounded at the top, team lacquer, gold bands, a boss
//   han_rattan.vox    shield.rattan: a round shield of coiled rattan, a red centre
//   lobster tools/vox/han_gear.lobster
import .voxwrite
import .worn

let IRON, IRON2, WHITE, TEAM, BLACK, LACE, STRAW, STRAW2, SLATE, GOLD, JADE, DARK = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
let COLOURS = [ 0, 0x8e9298, 0x4a4a50, 0xf0ebe0, 0x9a2a24, 0x2a2422, 0xa83228, 0xd8bc6c, 0xa88a52, 0x3a5a7a, 0xe2b44c, 0x4aa07a, 0x7a2e1e ]
def save(name:string, p:vw_piece, pt:float3, pt_name:string): worn_save(name, p, pt, pt_name, COLOURS)

// ---- headwraps, caps and hats

// a cloth bound over the hair and round the topknot
def wrap(c:float3) -> bool:
    let over = vw_ball(c, float3 { 0.0, -0.5, 69.2 }, float3 { 4.5, 4.9, 5.0 }) and c.z > 68.6 and not (c.y > 1.8 and c.z < 71.6)
    let knot = vw_ball(c, float3 { 0.0, -0.6, 74.2 }, float3 { 2.0, 2.0, 1.9 })
    return over or knot

let wrap_w = vw_piece { "wrap", 0 }
vw_fill(wrap_w, int3 { -6, -7, 66 }, int3 { 6, 6, 78 }) c: if wrap(c): WHITE else: 0
save("han_wrap", wrap_w, HEAD, "head")
let wrap_r = vw_piece { "red_wrap", 0 }
vw_fill(wrap_r, int3 { -6, -7, 66 }, int3 { 6, 6, 78 }) c: if wrap(c): DARK else: 0
save("han_red_wrap", wrap_r, HEAD, "head")

let cap = vw_piece { "cap", 0 }
vw_fill(cap, int3 { -7, -7, 66 }, int3 { 7, 7, 79 }) c:
    let knob = vw_ball(c, float3 { 0.0, -0.5, 75.4 }, float3 { 0.8, 0.8, 1.0 })
    if knob: IRON
    elif bowl(c) and c.z > 69.4: (if c.z < 70.8: (if (int(floor(around(c) * 4.0 + 20.0)) % 3) == 0: GOLD else: IRON2) else: IRON)
    else: 0
save("han_cap", cap, HEAD, "head")

let hood = vw_piece { "hood", 0 }
vw_fill(hood, int3 { -7, -8, 60 }, int3 { 7, 7, 79 }) c:
    let knob = vw_ball(c, float3 { 0.0, -0.5, 75.4 }, float3 { 0.8, 0.8, 1.0 })
    let flaps = vw_ball(c, float3 { 0.0, -0.5, 68.0 }, float3 { 5.6, 6.0, 7.0 }) and c.z > 61.6 and c.z < 70.4 and not (c.y > 1.0)
    if knob or (bowl(c) and c.z > 69.4): IRON
    elif flaps: (if (int(floor(c.z)) % 2) == 0: IRON2 else: IRON)
    else: 0
save("han_hood", hood, HEAD, "head")

let straw = vw_piece { "straw", 0 }
vw_fill(straw, int3 { -10, -11, 66 }, int3 { 10, 10, 82 }) c:
    let r = sqrt(c.x * c.x + vw_sq(c.y + 0.5))
    let cone = r < 9.8 and abs(c.z - (77.6 - r * 0.62)) < 0.7
    if cone: (if (int(floor(r * 1.4)) % 3) == 0: STRAW2 else: STRAW)
    else: 0
save("han_straw", straw, HEAD, "head")

// the Daoist: a tall black cap, flat on top, a jade pin through it; a long slate-blue robe from the chest to the ankles,
// its white edge from the neck down the right side
let dao = vw_piece { "daoist", 0 }
vw_fill(dao, int3 { -14, -10, 4 }, int3 { 14, 10, 81 }) c:
    let capd = vw_taper(c, 69.6, 78.6, float2 { 0.0, -0.6 }, float2 { 0.0, -0.8 }, float2 { 4.6, 5.0 }, float2 { 3.4, 3.6 }) and not face_cut(c)
    let pin = abs(c.y + 0.7) < 0.6 and abs(c.z - 76.0) < 0.6 and abs(c.x) < 5.0
    let robe = (torso(c, 1.0) and c.z > 44.0 and c.z < 58.6 and not neck(c)) or
        vw_taper(c, 5.0, 44.0, float2 { 0.0, -0.6 }, float2 { 0.0, 0.0 }, float2 { 10.0, 7.2 }, float2 { 8.4, 5.8 })
    let edgel = c.y > 1.6 and ((c.z > 48.0 and abs(c.x - (-2.6 + (60.6 - c.z) * 0.62)) < 0.8) or (c.z <= 48.0 and abs(c.x - 5.2) < 0.8))
    if pin: JADE
    elif capd: BLACK
    elif robe: (if edgel or (c.z > 42.0 and c.z < 44.0): WHITE else: SLATE)
    else: 0
save("han_daoist", dao, HEAD, "head")

// ---- body armour

// lamellar: rows of small plates laced together, from the neck to the hips, broad guards over the shoulders
def lamellar(c:float3, plate:int, lace:int) -> int:
    let shoulder = vw_taper(c, 51.0, 59.0, float2 { 0.0, -0.2 }, float2 { 0.0, -0.4 }, float2 { 11.6, 5.8 }, float2 { 10.4, 5.6 }) and abs(c.x) > 6.0
    let coat = (torso(c, 1.6) and c.z > 44.6 and not neck(c)) or (skirt(c, 35.0, 2.0) and c.z <= 44.6 and not (c.z > 41.0))
    if not (shoulder or coat): return 0
    return if (int(floor(c.z)) % 3) == 0: lace else: plate

let black = vw_piece { "black", 0 }
vw_fill(black, int3 { -14, -9, 34 }, int3 { 14, 9, 63 }) c: lamellar(c, BLACK, LACE)
save("han_black", black, CHEST, "chest")
let iron = vw_piece { "iron", 0 }
vw_fill(iron, int3 { -14, -9, 34 }, int3 { 14, 9, 63 }) c: lamellar(c, IRON, IRON2)
save("han_iron", iron, CHEST, "chest")

// ---- shields (drawn as the hand's frame holds them: x up, z across, the face out along +y)

// the tall lacquered shield: round at the top, straight below, gold bands near the top and the bottom, a boss
let lac = vw_piece { "lacquer", 0 }
vw_fill(lac, int3 { -22, -2, -9 }, int3 { 15, 4, 9 }) c:
    let top = c.x > 8.0 and vw_sq((c.x - 8.0) / 6.0) + vw_sq(c.z / 7.4) <= 1.0
    let shape = top or (c.x <= 8.0 and c.x > -21.0 and abs(c.z) < 7.4)
    let d = c.y - 0.8 * (1.0 - vw_sq(c.z / 8.4))
    let band = abs(c.x - 9.0) < 0.6 or abs(c.x + 18.0) < 0.6
    let boss = vw_ball(c, float3 { -2.0, 1.2, 0.0 }, float3 { 2.0, 1.4, 1.6 })
    if boss: GOLD
    elif not shape or d > 0.0 or d < -1.6: 0
    elif band: GOLD
    else: TEAM
save("han_lacquer", lac, float3_0, "hand")

// the rattan shield: round, coiled in rings, a red boss
let rat = vw_piece { "rattan", 0 }
vw_fill(rat, int3 { -10, -2, -10 }, int3 { 10, 4, 10 }) c:
    let r = sqrt(c.x * c.x + c.z * c.z)
    let d = c.y - 1.4 * (1.0 - vw_sq(r / 10.0))
    if r > 9.4 or d > 0.0 or d < -1.4: 0
    elif r < 1.8: LACE
    elif (int(floor(r * 1.2)) % 2) == 0: STRAW2
    else: STRAW
save("han_rattan", rat, float3_0, "hand")
