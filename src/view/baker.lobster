// ------------------------------------------------------------------ the baker's shared pieces (buildings and props:
// view/world_bake.lobster, game/art_kit_buildings.lobster): the depth and ambient-occlusion shaders, the bake camera
// (looking_at), and pixelize (a supersampled render shrunk to art pixels, hard alpha, an inner outline). Units are
// voxel bodies (view/voxel.lobster), baked by their own builder.

let BAKE_SHADERS = """
SHADER bakedepth
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        UNIFORM vec4 row_x
        UNIFORM vec4 row_y
        UNIFORM vec4 row_z
        // (the mesh is in model space, made once a part: each facing's projection to render px and depth in rows)
        vec4 q = vec4(dot(apos.xyz, row_x.xyz) + row_x.w, dot(apos.xyz, row_y.xyz) + row_y.w, dot(apos.xyz, row_z.xyz) + row_z.w, 1.0);
        gl_Position = mvp * q;
        idepth = vec2(q.z, 0.0);   // (no 1-float varyings in Lobster's shaders)
    PIXEL
        INPUTS idepth:2
        frag_color = vec4(idepth.x * 0.5 + 0.5, 0.0, 0.0, 1.0);

SHADER bakeao
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
    PIXEL
        UNIFORMS tex0
        UNIFORM vec2 aosize
        UNIFORM vec4 aoparm
        UNIFORM float aorange
        // Ambient occlusion over the view-depth map (as Godot's SSAO darkens the ambient light): round each pixel,
        // 16 samples on a spiral out to the radius (aoparm.x, render px); a sample standing nearer the camera by
        // more than a hair and less than twice the radius (aorange, part units; aoparm.y: view depth a part unit)
        // occludes, the nearer the less; intensity aoparm.z, power aoparm.w.
        vec2 uv = gl_FragCoord.xy / aosize;
        float d0 = texture(tex0, uv).r;
        float ao = 1.0;
        if (d0 < 0.999) {
            // the surface's own slope here (from its neighbours), so a curved face doesn't shade itself: a sample
            // occludes only where it stands nearer the camera than the surface's plane through this pixel
            vec2 tx = 1.0 / aosize;
            float dxp = texture(tex0, uv + vec2(tx.x, 0.0)).r;
            float dxm = texture(tex0, uv - vec2(tx.x, 0.0)).r;
            float dyp = texture(tex0, uv + vec2(0.0, tx.y)).r;
            float dym = texture(tex0, uv - vec2(0.0, tx.y)).r;
            float gx = (dxp < 0.999 && dxm < 0.999) ? (dxp - dxm) * 0.5 : 0.0;
            float gy = (dyp < 0.999 && dym < 0.999) ? (dyp - dym) * 0.5 : 0.0;
            float occ = 0.0;
            for (int k = 0; k < 16; k++) {
                float a = float(k) * 2.39996;
                vec2 opx = vec2(cos(a), sin(a)) * aoparm.x * sqrt((float(k) + 0.5) / 16.0);
                float ds = texture(tex0, uv + opx / aosize).r;
                if (ds < 0.999) {
                    float plane = d0 + gx * opx.x + gy * opx.y;
                    float dz = (plane - ds) * 2.0 / aoparm.y;
                    if (dz > 0.05) occ += clamp(1.0 - dz / (2.0 * aorange), 0.0, 1.0);
                }
            }
            ao = pow(clamp(1.0 - aoparm.z * occ / 16.0, 0.0, 1.0), aoparm.w);
        }
        frag_color = vec4(ao, ao, ao, 1.0);

"""

class BakeTri:
    p:[float3]
    n:[float3]
    c:[float3]
    uv:[float2]
    mat:int

// A material: its texture (or none) and how it's mapped (Godot's uv1 scale and offset, triplanar or not);
// in a library mesh, also the race channel its colour follows (m x the channel + b) or "" (fixed: b).
class BakeMat:
    tex:resource<texture>?
    scale:float2
    offset:float2
    triplanar:bool
    channel = "*"  // "*": the colour is on each triangle (a mesh made for one race)
    m = float3_0
    b = float3_0
    scissor = false  // alpha scissor (decals)
    unshaded = false
    emission = float3_0
    two_sided = false  // (cull disabled: a face seen from behind turns its normal to the camera)

let bake_mats = []::BakeMat

let bake_tex_cache = dictionary<string, resource<texture>>(16)

// Godot's Basis.looking_at(target, up): -Z points at the target. Returns its x, y, z columns.
def looking_at(target:float3, up:float3) -> float3, float3, float3:
    let z = normalize(-target)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    return x, y, z

def row(v:float3, w:float) -> float4: return float4 { v.x, v.y, v.z, w }

// Pixelize.run: shrink by `factor` (Godot's Image.resize with INTERPOLATE_CUBIC over premultiplied bytes: a bicubic
// sample near each block's corner, so a thin leg keeps its pixels as there), hard alpha, then an inner outline (edge
// pixels a darker shade of themselves, toward the ink). `seam` (one byte a raw pixel, rows as `raw`'s): where another
// part of the unit lies against this one: any cover there is kept, grown a pixel into it, and not outlined along it.

// Pixelize on the GPU (bakeshrink, bakejoin): the shrink's sums done there, only the small picture read back; then
// pixelize_finish as on the CPU. raw and mask are the render and its mask, as render_pass leaves them.

// Godot's _bicubic_interp_kernel (Keys, a = -0.5).
def cubic_kernel(t:float) -> float:
    let x = abs(t)
    if x <= 1.0: return (1.5 * x - 2.5) * x * x + 1.0
    if x < 2.0: return ((-0.5 * x + 2.5) * x - 4.0) * x + 2.0
    return 0.0

def pixelize(raw:string, w:int, h:int, factor:int, seam:string = "", outline:bool = true) -> int, int, string:
    let sw = max(1, w / factor)
    let sh = max(1, h / factor)
    let small = ensure_size("", sw * sh * 4, 0)  // (the write_ functions write into it in place)
    let joined = ensure_size("", sw * sh, 0)
    // premultiplied, top row first (Image.premultiply_alpha: (c a + 255) >> 8; a framebuffer reads back bottom row first)
    let pm = map(w * h * 4) i:
        let p = i / 4
        let src = ((h - 1 - p / w) * w + p % w) * 4
        let c = i % 4
        if c == 3: raw[src + 3] else: (raw[src + c] * raw[src + 3] + 255) >> 8
    let xfac = float(w) / float(sw)
    let yfac = float(h) / float(sh)
    let n = float(factor * factor)
    for(sh) y:
        let oy = float(y) * yfac - 0.5
        let oy1 = int(oy)  // (truncated toward zero, as Godot's (int))
        let dy = oy - float(oy1)
        for(sw) x:
            let ox = float(x) * xfac - 0.5
            let ox1 = int(ox)
            let dx = ox - float(ox1)
            let col = [ 0.0, 0.0, 0.0, 0.0 ]
            for(4) nn:
                let k1 = cubic_kernel(dy - float(nn - 1))
                let oy2 = clamp(oy1 + nn - 1, 0, h - 1)
                for(4) m:
                    let k2 = k1 * cubic_kernel(float(m - 1) - dx)
                    let ox2 = clamp(ox1 + m - 1, 0, w - 1)
                    let q = (oy2 * w + ox2) * 4
                    for(4) c: col[c] += float(pm[q + c]) * k2
            for(4) c: write_int8_le(small, (y * sw + x) * 4 + c, clamp(int(round(col[c])), 0, 255))
            if seam.length:
                var j = 0.0
                for(factor) sy:
                    for(factor) sx: j += float(seam[(h - 1 - (y * factor + sy)) * w + x * factor + sx])
                write_int8_le(joined, y * sw + x, int(j / n))
    return pixelize_finish(small, joined, sw, sh, seam.length > 0, outline)

// Pixelize's second half, on the shrunk image (premultiplied whole bytes, rows top first; `joined`: the seam's share
// of each pixel, with `seamed`): hard alpha, a seam's cover grown a pixel, the inner outline.
def pixelize_finish(small:string, joined:string, sw:int, sh:int, seamed:bool, outline:bool) -> int, int, string:
    let out = ensure_size("", sw * sh * 4, 0)
    for(sh) y:
        for(sw) x:
            let o = (y * sw + x) * 4
            let a = small[o + 3]
            if a >= 153 or (seamed and a >= 8 and joined[y * sw + x] >= 64):  // (0.6; along a seam, any cover)
                for(3) c: write_int8_le(out, o + c, min(255, small[o + c] * 255 / a))
                write_int8_le(out, o + 3, 255)
    if seamed:  // grow a pixel into the seam (the two parts' bakes sit on slightly different grids)
        let grown = ensure_size("", sw * sh * 4, 0)
        for(sw * sh * 4) i: write_int8_le(grown, i, out[i])
        for(sh - 2) yy:
            let y = yy + 1
            for(sw - 2) xx:
                let x = xx + 1
                let p = y * sw + x
                if out[p * 4 + 3] != 255 and joined[p] >= 64:
                    for([ p - 1, p + 1, p - sw, p + sw ]) q:
                        if grown[p * 4 + 3] != 255 and out[q * 4 + 3] == 255:
                            for(4) c: write_int8_le(grown, p * 4 + c, out[q * 4 + c])
        for(sw * sh * 4) i: write_int8_le(out, i, grown[i])
    let ink = float3 { 0.141, 0.094, 0.059 }
    let edged = ensure_size("", sw * sh * 4, 0)
    for(sw * sh * 4) i: write_int8_le(edged, i, out[i])
    for(sh) y:
        for(sw) x:
            let i = (y * sw + x) * 4
            if outline and out[i + 3] == 255:
                var edge = x == 0 or y == 0 or x == sw - 1 or y == sh - 1
                if not edge:
                    let p = y * sw + x
                    for([ p - 1, p + 1, p - sw, p + sw ]) q:
                        if out[q * 4 + 3] != 255 and (not seamed or joined[q] < 128): edge = true
                if edge:
                    for(3) c:
                        let v = float(out[i + c]) / 255.0 * 0.45
                        let inked = v + ([ ink.x, ink.y, ink.z ][c] - v) * 0.25
                        write_int8_le(edged, i + c, int(inked * 255.0))
    return sw, sh, edged
