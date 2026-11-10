// The Roman body's worn kit (#417), drawn around roman.vox in its voxels (2 a body unit) from the approved concept
// sheet, one model each, worn on the body point it rides (its offset printed for gear.json's `roman` fits):
//   roman_galea.vox        helm.galea: iron bowl, a brass band over the brow, cheek guards, a flared neck guard, a knob
//   roman_montefortino.vox helm.cap: a plain bronze bowl with a tall knob and a short neck lip
//   roman_leather.vox      armour.leather: a leather jerkin to the waist, strips (pteruges) at the shoulders and hips
//   roman_mail.vox         armour.bronze: mail to the hip, doubled over the shoulders
//   roman_segmentata.vox   armour.lorica: iron bands round the body and over the shoulders, a studded apron below
//   lobster tools/vox/roman_gear.lobster
import .voxwrite

let METAL, BRASS, HIDE, LEATHER, BRONZE = 1, 2, 3, 4, 5
let COLOURS = [ 0, 0x8e9298, 0xc9a24a, 0x8a6a48, 0x5e4029, 0xb8893a ]
let HEAD = float3 { 0.0, 1.0, 67.0 }
let CHEST = float3 { 0.0, 0.0, 57.0 }

// (the head's own cut, as roman.vox: the face below the brow in front, the ears and cheeks at the sides)
def face_cut(c:float3) -> bool: return (c.y > 1.0 and c.z < 70.8) or (c.y > -1.8 and c.z < 68.2)

// the torso's outline, `out` voxels out from roman.vox's
def torso(c:float3, out:float) -> bool:
    return vw_taper(c, 44.0, 57.0, float2 { 0.0, 0.0 }, float2 { 0.0, -0.3 }, float2 { 7.0 + out, 4.4 + out }, float2 { 9.4 + out, 5.0 + out }) or
        vw_taper(c, 57.0, 61.5 + out * 0.5, float2 { 0.0, -0.3 }, float2 { 0.0, -0.6 }, float2 { 9.4 + out, 5.0 + out }, float2 { 7.0 + out, 3.8 + out })

def neck(c:float3) -> bool: return c.z > 59.0 and abs(c.x) < 3.2 and c.y > -2.0

// the skirt's outline below the belt (z 23.5 to 44), `out` voxels out
def skirt(c:float3, z0:float, out:float) -> bool:
    return vw_taper(c, z0, 44.0, float2 { 0.0, -0.4 }, float2 { 0.0, 0.0 }, float2 { 8.4 + out, 5.6 + out }, float2 { 7.2 + out, 4.6 + out })

def around(c:float3) -> float: return atan2(float2 { c.x, c.y })

def save(name:string, p:vw_piece, pt:float3, pt_name:string):
    let lo = fold(p.vs, p.vs[0]) a, v: min(a, v)
    let hi = fold(p.vs, p.vs[0]) a, v: max(a, v)
    let centre = (float(lo) + float(hi - lo + int3_1) / 2.0 - pt) / 2.0  // (its box's centre from the point, in body units)
    vw_write("../../data/voxel/models/" + name + ".vox", [ p ], COLOURS)
    print "  {name}: at [\"{pt_name}\", {centre.x}, {centre.y}, {centre.z}]"

// helmets: a bowl over the hair, open in front below the brow
def bowl(c:float3) -> bool: return vw_ball(c, float3 { 0.0, -0.5, 69.6 }, float3 { 4.9, 5.3, 5.1 }) and not face_cut(c)

let galea = vw_piece { "galea", 0 }
vw_fill(galea, int3 { -6, -8, 63 }, int3 { 6, 5, 76 }) c:
    let ax = abs(c.x)
    let nape = c.y < -3.0 and c.y > -7.2 and c.z > 64.6 and c.z < 66.2 and ax < 4.6 - (c.y + 3.0) * -0.3
    let cheek = ax > 3.8 and ax < 4.8 and c.y > 0.0 and c.y < 2.6 and c.z > 64.6 and c.z < 68.3
    let knob = vw_ball(c, float3 { 0.0, -0.5, 75.0 }, float3 { 0.8, 0.8, 0.9 })
    if knob: BRASS
    elif bowl(c): (if c.z < 71.9 and c.y > -1.0 and c.z > 70.0: BRASS else: METAL)
    elif nape: (if c.y < -6.0: BRASS else: METAL)
    elif cheek: BRASS
    else: 0
save("roman_galea", galea, HEAD, "head")

let monte = vw_piece { "montefortino", 0 }
vw_fill(monte, int3 { -6, -8, 64 }, int3 { 6, 5, 78 }) c:
    let lip = c.y < -3.0 and c.y > -6.4 and c.z > 65.6 and c.z < 66.8 and abs(c.x) < 4.0
    let knob = vw_taper(c, 74.0, 77.0, float2 { 0.0, -0.5 }, float2 { 0.0, -0.5 }, float2 { 1.2, 1.2 }, float2 { 0.6, 0.6 })
    if knob or lip: BRONZE
    elif bowl(c) and c.z > 67.0: BRONZE
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
