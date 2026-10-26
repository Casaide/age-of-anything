// ------------------------------------------------------------------ the part baker in Lobster (step 6c; src/view/art/bake/baker.gd, part_baker.gd, pixelize.gd)
// A part's 3D model rendered as the bake camera sees it (orthographic, 30 degrees up, turned to a
// facing: azimuth 35 + 45 a facing), lit by the part baker's rig (a warm key from the camera's upper
// left, a cool fill, ambient), supersampled 4x, then pixelized: shrunk, hard alpha, an inner
// outline of darker edge pixels. The part shadows itself (a shadow map from the key light). Stage 1: the
// meshes come from Godot (mesh_export.gd); the models in Lobster are the next stage. No ambient occlusion yet.

let BAKE_SS = 4
let BAKE_ART = 1.5 * 0.85           // art px a part unit (ArtKit: ART_SCALE x UNIT_SCALE: baked at the size drawn)
let PX_PER_UNIT = 32.0 / 0.70710678 // the baker's screen px a world unit (Baker.PX_PER_UNIT)

let BAKE_SHADERS = """
SHADER bakedepth
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
        idepth = vec2(apos.z, 0.0);   // (no 1-float varyings in Lobster's shaders)
    PIXEL
        INPUTS idepth:2
        frag_color = vec4(idepth.x * 0.5 + 0.5, 0.0, 0.0, 1.0);

SHADER bakelit
    VERTEX
        INPUTS apos:4 anormal:3 atc:2 atc2:2
        UNIFORMS mvp
        UNIFORM vec3 cam_x
        UNIFORM vec3 cam_y
        UNIFORM vec3 cam_z
        UNIFORM vec4 vmap
        gl_Position = mvp * apos;
        inorm = anormal;
        // the model-space position back from the screen's (render px from the box's corner) and the depth
        // (vmap: px a unit, the box's corner, the nearest depth; atc2.x: the depth's scale: view_z)
        float d = vmap.w + (0.9 - apos.z) / atc2.x;
        iobj = vec4(cam_x * (apos.x / vmap.x + vmap.y) - cam_y * (apos.y / vmap.x + vmap.z) + cam_z * d, 1.0);
        iuv = atc;
    PIXEL
        INPUTS inorm:3 iobj:4 iuv:2
        UNIFORMS tex0 tex1
        UNIFORM vec3 key_dir
        UNIFORM vec4 lx
        UNIFORM vec4 ly
        UNIFORM vec4 lz
        UNIFORM vec2 lsize
        UNIFORM vec3 fill_dir
        UNIFORM vec4 albedo
        UNIFORM vec4 uvmap
        UNIFORM float mapping
        UNIFORM vec4 emis
        UNIFORM vec4 mflags
        vec3 n = normalize(inorm);
        // The material's texture as Godot maps it: none, its UVs, or triplanar (the model's position
        // times the scale, each axis's plane weighted by the normal).
        vec4 t = vec4(1.0);
        if (mapping > 1.5) {
            vec3 p = iobj.xyz * uvmap.x + vec3(uvmap.z, uvmap.w, 0.0);
            vec3 w = abs(n) * abs(n);   // (UnitModels.surf: triplanar sharpness 2)
            w /= (w.x + w.y + w.z);
            p *= vec3(1.0, -1.0, 1.0);
            t = texture(tex0, p.zy) * w.x + texture(tex0, p.xz) * w.y + texture(tex0, vec2(-p.x, p.y)) * w.z;
        } else if (mapping > 0.5) {
            t = texture(tex0, iuv * uvmap.xy + uvmap.zw);
        }
        vec4 icol = albedo * t;
        if (mflags.x > 0.5 && t.a < 0.5) discard;   // alpha scissor (decals)
        if (mflags.z > 0.5) icol = albedo;           // a mask: the flat colour (a decal's texture only cuts)
        // PartBaker's rig: a warm key from the camera's upper left, a cool fill from the other side,
        // ambient; linear tone (Godot's linear tonemap, sRGB out).
        vec3 light = vec3(0.784, 0.816, 0.878) * 0.28;
        // In the key light's shadow? Its depth map, seen from the light (lx, ly: map px; lz: depth -1..1).
        vec3 lp = vec3(dot(iobj.xyz, lx.xyz) + lx.w, dot(iobj.xyz, ly.xyz) + ly.w, dot(iobj.xyz, lz.xyz) + lz.w);
        float lit = 1.0;
        float nearest = texture(tex1, vec2(lp.x / lsize.x, 1.0 - lp.y / lsize.y)).r * 2.0 - 1.0;   // (a framebuffer texture is bottom-up)
        if (lp.z > nearest + 0.02) lit = 0.0;
        light += vec3(1.0, 0.957, 0.878) * 1.7 * max(0.0, dot(n, -key_dir)) * lit;
        light += vec3(0.722, 0.784, 1.0) * 0.3 * max(0.0, dot(n, -fill_dir));
        vec3 lin = pow(icol.rgb, vec3(2.2)) * light;
        if (mflags.y > 0.5) lin = pow(icol.rgb, vec3(2.2));   // unshaded
        lin += pow(emis.rgb, vec3(2.2));
        vec3 c = pow(clamp(lin, 0.0, 1.0), vec3(1.0 / 2.2));
        frag_color = vec4(c, 1.0);
        if (mapping < -0.5) frag_color = vec4(nearest * 0.5 + 0.5, lp.z * 0.5 + 0.5, lp.x / lsize.x, 1.0);
"""

var bake_shadow_debug = false
var bake_debug = ""                 // a path stem: save each raw render there (checks)

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
    channel = "*"                   // "*": the colour is on each triangle (a mesh made for one race)
    m = float3_0
    b = float3_0
    scissor = false                 // alpha scissor (decals)
    unshaded = false
    emission = float3_0

var bake_mats = []::BakeMat

let bake_tex_cache = dictionary<string, resource<texture>>(16)

def load_mesh(path:string) -> [BakeTri]:
    let out = []::BakeTri
    let text = read_file(path)
    if not text: return out
    let dir = substring(path, 0, find_string_reverse(path, "/"))
    let bin = read_file(substring(path, 0, path.length - 5) + ".bin", true) or ""   // (the vertices: 11 floats each)
    var at = 0
    var mat = -1
    for(tokenize(text, "\n", "")) line:
        if starts_with(line, "mat "):
            let halves = tokenize(line.substring(4, line.length - 4), "|", " ")
            let all = tokenize(halves[0], " ", "")
            let t = filter(all) x: not starts_with(x, "@") and not starts_with(x, "#")
            var tris = 0
            for(all) x:
                if starts_with(x, "#"): tris = string_to_int(x.substring(1, x.length - 1))
            var tex:resource<texture>? = nil
            if t[0] != "-":
                let file = dir + "/" + t[0]
                tex = bake_tex_cache.get(file)
                if not tex:
                    let loaded = gl.load_texture(file)   // (mipmapped, as UnitModels.tex: a part is small on screen)
                    if loaded: bake_tex_cache.set(file, loaded)
                    tex = loaded
            let f = map(t.slice(1, -1)) x: string_to_float(x)
            let bm = if f.length >= 5: BakeMat { tex, float2 { f[0], f[1] }, float2 { f[2], f[3] }, f[4] > 0.5 } else: BakeMat { tex, float2_1, float2_0, false }
            if halves.length > 1:   // "ch <channel> m.r m.g m.b b.r b.g b.b", or "ch - r g b"
                let c = tokenize(halves[1], " ", "")
                let num = map(c.slice(2, -1)) x: string_to_float(x)
                if c[1] == "-":
                    bm.channel = ""
                    bm.b = float3 { num[0], num[1], num[2] }
                else:
                    bm.channel = c[1]
                    bm.m = float3 { num[0], num[1], num[2] }
                    bm.b = float3 { num[3], num[4], num[5] }
            bake_mats.push(bm)
            mat = bake_mats.length - 1
            for(tris):   // its triangles from the .bin
                let tri = BakeTri { [], [], [], [], mat }
                for(3):
                    def f(k:int) -> float:
                        let v, _n = read_float32_le(bin, at + k * 4)
                        return v
                    tri.p.push(float3 { f(0), f(1), f(2) })
                    tri.n.push(float3 { f(3), f(4), f(5) })
                    tri.c.push(float3 { f(6), f(7), f(8) })
                    tri.uv.push(float2 { f(9), f(10) })
                    at += 44
                out.push(tri)
        elif starts_with(line, "tri "):
            let v = map(tokenize(line.substring(4, line.length - 4), " ", "")) t: string_to_float(t)
            let tri = BakeTri { [], [], [], [], mat }
            let stride = v.length / 3
            for(3) k:
                let o = k * stride
                tri.p.push(float3 { v[o], v[o + 1], v[o + 2] })
                tri.n.push(float3 { v[o + 3], v[o + 4], v[o + 5] })
                tri.c.push(float3 { v[o + 6], v[o + 7], v[o + 8] })
                tri.uv.push(if stride >= 11: float2 { v[o + 9], v[o + 10] } else: float2_0)
            out.push(tri)
    return out

// Godot's Basis.looking_at(target, up): -Z points at the target. Returns its x, y, z columns.
def looking_at(target:float3, up:float3) -> float3, float3, float3:
    let z = normalize(-target)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    return x, y, z

// A light's direction (where it shines) from Godot's euler degrees (YXZ): its -Z.
def light_dir(rx:float, ry:float) -> float3:
    // basis = Ry * Rx; -Z column
    let cx = cos(rx)
    let sx = sin(rx)
    let cy = cos(ry)
    let sy = sin(ry)
    return float3 { -sy * cx, sx, -cy * cx }

// One facing of a mesh: its pixel sprite (RGBA bytes, w, h) and where the model's origin is on it.
// A channel's colour for a race (the team channel: the team key, recoloured per team when drawn).
def channel_colour(cols:Colours?, ch:string) -> float3:
    let c = cols
    if not c or ch == "team": return float3 { 1.0, 0.0, 1.0 }
    let hex = c.hex.get(ch, "ff00ff")
    def byte(i:int) -> float: return float(string_to_int(hex.substring(i, 2), 16)) / 255.0
    return float3 { byte(0), byte(2), byte(4) }

var bake_colours:Colours? = nil     // the race's colours for library meshes (set before bake_facing)

def mat_albedo(mat:int, tri_c:float3) -> float3:
    if mat < 0: return tri_c
    let bm = bake_mats[mat]
    if bm.channel == "*": return tri_c
    if bm.channel == "": return bm.b
    return bm.m * channel_colour(bake_colours, bm.channel) + bm.b

// `hide`: what hides the part (the body a leg is cut by, the wearer of armour): framed, lit and shadowing
// with it, then cut away (a mask pass, the part white and `hide` black, unlit: only the white is kept).
// `join_r` > 0: where `hide` covers the part within join_r of `join` is a seam (a neck running into its
// head): no outline there, so the two join without a line.
def bake_facing(part:[BakeTri], facing:int, hide:[BakeTri] = [], join:float3 = float3_0, join_r:float = 0.0) -> string, int, int, float2:
    let tris = append(part, hide)
    let az = 35.0 + 45.0 * float(facing)
    let el = 30.0
    let view = float3 { sin(az) * cos(el), sin(el), cos(az) * cos(el) }
    let cx, cy, cz = looking_at(-view, float3 { 0.0, 1.0, 0.0 })
    let key = normalize(cx * 0.55 + cy * -0.75 + cz * -1.0)   // cam.basis * (0.55, -0.75, -1): from the screen's upper left
    // The model's box on screen (part units), with room.
    var lo = float2 { 1000000000.0, 1000000000.0 }
    var hi = float2 { -1000000000.0, -1000000000.0 }
    var dlo = 1000000000.0
    var dhi = -1000000000.0
    for(tris) t:
        for(t.p) p:
            let s = float2 { dot(p, cx), -dot(p, cy) }
            lo = min(lo, s)
            hi = max(hi, s)
            dlo = min(dlo, dot(p, cz))
            dhi = max(dhi, dot(p, cz))
    lo -= float2_1 * 2.0
    hi += float2_1 * 2.0
    let px = BAKE_ART * float(BAKE_SS)   // render px a part unit
    let w = int(ceiling((hi.x - lo.x) * px))
    let h = int(ceiling((hi.y - lo.y) * px))
    // The mesh in render px (x right, y down), its triangles drawn far to near (the painter's way: the
    // framebuffer here has no depth test in 2D).
    // The shadow map: the part's depth as the key light sees it (orthographic along the light), in
    // a float texture; the lit pass looks each point up in it.
    let kx, ky, kz = looking_at(key, float3 { 0.0, 1.0, 0.0 })
    var llo = float2 { 1000000000.0, 1000000000.0 }
    var lhi = float2 { -1000000000.0, -1000000000.0 }
    var zlo = 1000000000.0
    var zhi = -1000000000.0
    for(tris) t:
        for(t.p) p:
            let s = float2 { dot(p, kx), -dot(p, ky) }
            llo = min(llo, s)
            lhi = max(lhi, s)
            zlo = min(zlo, dot(p, kz))
            zhi = max(zhi, dot(p, kz))
    llo -= float2_1
    lhi += float2_1
    let lpx = px
    let lw = int(ceiling((lhi.x - llo.x) * lpx))
    let lh = int(ceiling((lhi.y - llo.y) * lpx))
    let zs = 1.8 / max(0.001, zhi - zlo)   // depth to -0.9..0.9: nearer the light (larger z, toward it) smaller
    def light_z(p:float3) -> float: return 0.9 - (dot(p, kz) - zlo) * zs
    // (a depth test keeps the nearest: the framebuffer has a depth buffer, gl.ortho turns the test on)
    let lorder = map(tris.length) i: i
    let ldepth = map(tris) t: dot(t.p[0] + t.p[1] + t.p[2], kz)
    qsort_in_place(lorder) a, b: ldepth[a] < ldepth[b]
    let all_pos = []::float3
    for(lorder) ti:
        // (a decal casts no shadow here: its quad would, where Godot's alpha scissor casts only its picture)
        if tris[ti].mat < 0 or not bake_mats[tris[ti].mat].scissor:
            for(tris[ti].p) p: all_pos.push(float3 { (dot(p, kx) - llo.x) * lpx, (-dot(p, ky) - llo.y) * lpx, light_z(p) })
    let smesh = gl.new_mesh("P", all_pos, []::float4, []::float3, []::float2, []::float2, map(all_pos.length) i: i)
    let smap = gl.create_blank_texture(int3 { lw, lh, 0 }, texture_format_nomipmap | texture_format_float | texture_format_clamp)
    gl.switch_to_framebuffer(smap, true)
    gl.ortho(false, true)   // (in a framebuffer: its own pixels, depth tested)
    gl.clear(float4 { 1.0, 1.0, 1.0, 1.0 })
    gl.set_shader("bakedepth")
    gl.render_mesh(smesh)
    if bake_debug != "": gl.save_texture(smap, bake_debug + "_shadow{facing}.png")
    // The lit pass, depth tested, in runs of one material and colour (a draw each); with `mask`, the part
    // white and what hides it black, unlit.
    let vz = 1.8 / max(0.001, dhi - dlo)
    def view_z(p:float3) -> float: return 0.9 - (dot(p, cz) - dlo) * vz   // nearer the camera smaller
    let order = map(tris.length) i: i
    let depth = map(tris) t: dot(t.p[0] + t.p[1] + t.p[2], cz)
    qsort_in_place(order) a, b: depth[a] < depth[b]
    def render_pass(mask:bool) -> string:
        let tex = gl.create_blank_texture(int3 { w, h, 0 }, texture_format_nomipmap)
        gl.switch_to_framebuffer(tex, true)
        gl.ortho(false, true)
        gl.clear(float4 { 0.0, 0.0, 0.0, 0.0 })
        var at = 0
        while at < order.length:
            let first = tris[order[at]]
            let first_hidden = order[at] >= part.length
            var end = at
            while end < order.length and tris[order[end]].mat == first.mat and tris[order[end]].c[0] == first.c[0] and (order[end] >= part.length) == first_hidden: end++
            let pos = []::float3
            let nor = []::float3
            let obj = []::float2
            let uvs = []::float2
            for(end - at) n:
                let t = tris[order[at + n]]
                for(3) k:
                    let p = t.p[k]
                    pos.push(float3 { (dot(p, cx) - lo.x) * px, (-dot(p, cy) - lo.y) * px, view_z(p) })
                    nor.push(t.n[k])
                    obj.push(float2 { vz, 0.0 })
                    uvs.push(t.uv[k])
            let m = gl.new_mesh("PNTT", pos, []::float4, nor, uvs, obj, map(pos.length) i: i)
            let bm = if first.mat >= 0: bake_mats[first.mat] else: BakeMat { nil, float2_1, float2_0, false }
            let bt = bm.tex
            if bt: gl.set_mesh_texture(m, 0, 0, bt)
            gl.set_mesh_texture(m, 0, 1, smap)
            gl.set_shader("bakelit")
            gl.set_uniform("cam_x", cx)
            gl.set_uniform("cam_y", cy)
            gl.set_uniform("cam_z", cz)
            gl.set_uniform("vmap", float4 { px, lo.x, lo.y, dlo })
            gl.set_uniform("key_dir", key)
            gl.set_uniform("fill_dir", normalize(float3 { -0.6, -0.3, 0.7 }))
            let al = if mask: (if first_hidden: float3_0 else: float3_1) else: mat_albedo(first.mat, first.c[0])
            gl.set_uniform("albedo", float4 { al.x, al.y, al.z, 1.0 })
            gl.set_uniform("uvmap", float4 { bm.scale.x, bm.scale.y, bm.offset.x, bm.offset.y })
            let em = if mask: float3_0 else: bm.emission
            gl.set_uniform("emis", float4 { em.x, em.y, em.z, 0.0 })
            gl.set_uniform("mflags", float4 { if bm.scissor: 1.0 else: 0.0, if bm.unshaded or mask: 1.0 else: 0.0, if mask: 1.0 else: 0.0, 0.0 })
            gl.set_uniform("mapping", if bake_shadow_debug: -1.0 elif not bt: 0.0 elif bm.triplanar: 2.0 else: 1.0)
            gl.set_uniform("lx", float4 { kx.x * lpx, kx.y * lpx, kx.z * lpx, -llo.x * lpx })
            gl.set_uniform("ly", float4 { -ky.x * lpx, -ky.y * lpx, -ky.z * lpx, -llo.y * lpx })
            gl.set_uniform("lz", float4 { -kz.x * zs, -kz.y * zs, -kz.z * zs, 0.9 + zlo * zs })
            gl.set_uniform("lsize", float2 { float(lw), float(lh) })
            gl.render_mesh(m)
            at = end
        gl.switch_to_framebuffer(nil)
        if bake_debug != "": gl.save_texture(tex, bake_debug + (if mask: "_mask" else: "_f") + "{facing}.png")
        return gl.read_texture(tex) or ""
    let raw = render_pass(false)
    var seam = ""
    if hide.length:   // only what the mask shows white is kept
        let mask = render_pass(true)
        let jc = float2 { (dot(join, cx) - lo.x) * px, (-dot(join, cy) - lo.y) * px }
        let reach = join_r * px
        if join_r > 0.0: seam = ensure_size("", w * h, 0)
        var i = 0
        while i + 3 < raw.length:
            if mask[i] < 128 or mask[i + 3] < 128:
                write_int8_le(raw, i + 3, 0)
                if join_r > 0.0 and mask[i + 3] >= 128:   // (the mask reads back bottom row first, as the render)
                    let pix = i / 4
                    let at = float2 { float(pix % w) + 0.5, float(h - 1 - pix / w) + 0.5 }
                    if magnitude(at - jc) <= reach: write_int8_le(seam, pix, 255)
            i += 4
    let sw, sh, sprite = pixelize(raw, w, h, BAKE_SS, seam)
    return sprite, sw, sh, (float2_0 - lo) * BAKE_ART

// Pixelize.run: shrink by `factor` (a box filter over premultiplied colour), hard alpha, then an
// inner outline (edge pixels a darker shade of themselves, toward the ink). `seam` (one byte a raw pixel,
// rows as `raw`'s): where another part of the unit lies against this one: any cover there is kept, grown a
// pixel into it, and not outlined along it.
def pixelize(raw:string, w:int, h:int, factor:int, seam:string = "") -> int, int, string:
    let sw = max(1, w / factor)
    let sh = max(1, h / factor)
    let out = ensure_size("", sw * sh * 4, 0)   // (the write_ functions write into it in place)
    let joined = ensure_size("", sw * sh, 0)
    let n = float(factor * factor)
    for(sh) y:
        for(sw) x:
            var r = 0.0
            var g = 0.0
            var b = 0.0
            var a = 0.0
            var j = 0.0
            for(factor) dy:
                for(factor) dx:
                    let p = (h - 1 - (y * factor + dy)) * w + x * factor + dx   // (a framebuffer reads back bottom row first)
                    let i = p * 4
                    let pa = float(raw[i + 3]) / 255.0
                    r += float(raw[i]) * pa
                    g += float(raw[i + 1]) * pa
                    b += float(raw[i + 2]) * pa
                    a += pa
                    if seam.length: j += float(seam[p])
            let o = (y * sw + x) * 4
            if seam.length: write_int8_le(joined, y * sw + x, int(j / n))
            if a / n >= 0.6 or (seam.length and a / n >= 0.03 and j / n >= 64.0):
                write_int8_le(out, o, int(min(255.0, r / a)))
                write_int8_le(out, o + 1, int(min(255.0, g / a)))
                write_int8_le(out, o + 2, int(min(255.0, b / a)))
                write_int8_le(out, o + 3, 255)
    if seam.length:   // grow a pixel into the seam (the two parts' bakes sit on slightly different grids)
        let grown = ensure_size("", sw * sh * 4, 0)
        for(sw * sh * 4) i: write_int8_le(grown, i, out[i])
        for(sh - 2) yy:
            let y = yy + 1
            for(sw - 2) xx:
                let x = xx + 1
                let p = y * sw + x
                if out[p * 4 + 3] != 255 and joined[p] >= 64:
                    for([p - 1, p + 1, p - sw, p + sw]) q:
                        if grown[p * 4 + 3] != 255 and out[q * 4 + 3] == 255:
                            for(4) c: write_int8_le(grown, p * 4 + c, out[q * 4 + c])
        for(sw * sh * 4) i: write_int8_le(out, i, grown[i])
    let ink = float3 { 0.141, 0.094, 0.059 }
    let edged = ensure_size("", sw * sh * 4, 0)
    for(sw * sh * 4) i: write_int8_le(edged, i, out[i])
    for(sh) y:
        for(sw) x:
            let i = (y * sw + x) * 4
            if out[i + 3] == 255:
                var edge = x == 0 or y == 0 or x == sw - 1 or y == sh - 1
                if not edge:
                    let p = y * sw + x
                    for([p - 1, p + 1, p - sw, p + sw]) q:
                        if out[q * 4 + 3] != 255 and (not seam.length or joined[q] < 128): edge = true
                if edge:
                    for(3) c:
                        let v = float(out[i + c]) / 255.0 * 0.45
                        let inked = v + ([ink.x, ink.y, ink.z][c] - v) * 0.25
                        write_int8_le(edged, i + c, int(inked * 255.0))
    return sw, sh, edged
