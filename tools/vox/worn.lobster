// Shapes for worn kit drawn around the culture bodies built on roman.vox's proportions (roman.vox, greek.vox: the same
// head, torso and points), in their voxels (2 a body unit), and saving a model with the offset gear.json's fit needs.
// Used by roman_gear.lobster and greek_gear.lobster (#451).
import .voxwrite

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

def worn_save(name:string, p:vw_piece, pt:float3, pt_name:string, colours:[int]):
    let lo = fold(p.vs, p.vs[0]) a, v: min(a, v)
    let hi = fold(p.vs, p.vs[0]) a, v: max(a, v)
    let centre = (float(lo) + float(hi - lo + int3_1) / 2.0 - pt) / 2.0  // (its box's centre from the point, in body units)
    vw_write("../../data/voxel/models/" + name + ".vox", [ p ], colours)
    print "  {name}: at [\"{pt_name}\", {centre.x}, {centre.y}, {centre.z}]"

// helmets: a bowl over the hair, open in front below the brow
def bowl(c:float3) -> bool: return vw_ball(c, float3 { 0.0, -0.5, 69.6 }, float3 { 4.9, 5.3, 5.1 }) and not face_cut(c)
