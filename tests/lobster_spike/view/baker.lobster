// ------------------------------------------------------------------ the part baker in Lobster (step 6c; src/view/art/bake/baker.gd, part_baker.gd, pixelize.gd)
// A part's 3D model rendered as the bake camera sees it (orthographic, 30 degrees up, turned to a
// facing: azimuth 35 + 45 a facing), lit by the part baker's rig (a warm key from the camera's upper
// left, a cool fill, ambient), supersampled 4x, then pixelized: shrunk, hard alpha, an inner
// outline of darker edge pixels. Stage 1: the meshes come from Godot (mesh_export.gd); the models in
// Lobster are the next stage. No shadows or ambient occlusion yet.

let BAKE_SS = 4
let BAKE_ART = 1.5                  // art px a part unit
let PX_PER_UNIT = 32.0 / 0.70710678 // the baker's screen px a world unit (Baker.PX_PER_UNIT)

let BAKE_SHADERS = """
SHADER bakelit
    VERTEX
        INPUTS apos:4 anormal:3 acolor:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
        inorm = anormal;
        icol = acolor;
    PIXEL
        INPUTS inorm:3 icol:4
        UNIFORM vec3 key_dir
        UNIFORM vec3 fill_dir
        vec3 n = normalize(inorm);
        // PartBaker's rig: a warm key from the camera's upper left, a cool fill from the other side,
        // ambient; linear tone (Godot's linear tonemap, sRGB out).
        vec3 light = vec3(0.784, 0.816, 0.878) * 0.28;
        // (Lambert as Godot shades it: the lights' energy over pi)
        light += vec3(1.0, 0.957, 0.878) * 1.7 * max(0.0, dot(n, -key_dir)) / 3.14159;
        light += vec3(0.722, 0.784, 1.0) * 0.3 * max(0.0, dot(n, -fill_dir)) / 3.14159;
        vec3 lin = pow(icol.rgb, vec3(2.2)) * light;
        vec3 c = pow(clamp(lin, 0.0, 1.0), vec3(1.0 / 2.2));
        frag_color = vec4(c, 1.0);
"""

var bake_debug = ""                 // a path stem: save each raw render there (checks)

class BakeTri:
    p:[float3]
    n:[float3]
    c:[float3]

def load_mesh(path:string) -> [BakeTri]:
    let out = []::BakeTri
    let text = read_file(path)
    if not text: return out
    for(tokenize(text, "\n", "")) line:
        if starts_with(line, "tri "):
            let v = map(tokenize(line.substring(4, line.length - 4), " ", "")) t: string_to_float(t)
            let tri = BakeTri { [], [], [] }
            for(3) k:
                let o = k * 9
                tri.p.push(float3 { v[o], v[o + 1], v[o + 2] })
                tri.n.push(float3 { v[o + 3], v[o + 4], v[o + 5] })
                tri.c.push(float3 { v[o + 6], v[o + 7], v[o + 8] })
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
def bake_facing(tris:[BakeTri], facing:int) -> string, int, int, float2:
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
    let order = map(tris.length) i: i
    let depth = map(tris) t: dot(t.p[0] + t.p[1] + t.p[2], cz)
    qsort_in_place(order) a, b: depth[a] < depth[b]
    let pos = []::float3
    let nor = []::float3
    let col = []::float4
    for(order) ti:
        let t = tris[ti]
        for(3) k:
            let p = t.p[k]
            pos.push(float3 { (dot(p, cx) - lo.x) * px, (-dot(p, cy) - lo.y) * px, 0.0 })
            nor.push(t.n[k])
            col.push(float4 { t.c[k].x, t.c[k].y, t.c[k].z, 1.0 })
    let m = gl.new_mesh("PNC", pos, col, nor, []::float2, []::float2, map(pos.length) i: i)
    let tex = gl.create_blank_texture(int3 { w, h, 0 }, texture_format_nomipmap)
    gl.switch_to_framebuffer(tex)
    gl.clear(float4 { 0.0, 0.0, 0.0, 0.0 })
    // (the framebuffer keeps the window's 2D projection: scaled to the texture here)
    let ws = float(gl.window_size())
    gl.scale(ws / float2 { float(w), float(h) }):
        gl.set_shader("bakelit")
        gl.set_uniform("key_dir", key)
        gl.set_uniform("fill_dir", normalize(float3 { -0.6, -0.3, 0.7 }))
        gl.render_mesh(m)
    gl.switch_to_framebuffer(nil)
    if bake_debug != "": gl.save_texture(tex, bake_debug + "_f{facing}.png")
    let raw = gl.read_texture(tex) or ""
    let sw, sh, sprite = pixelize(raw, w, h, BAKE_SS)
    return sprite, sw, sh, (float2_0 - lo) * BAKE_ART

// Pixelize.run: shrink by `factor` (a box filter over premultiplied colour), hard alpha, then an
// inner outline (edge pixels a darker shade of themselves, toward the ink).
def pixelize(raw:string, w:int, h:int, factor:int) -> int, int, string:
    let sw = max(1, w / factor)
    let sh = max(1, h / factor)
    let out = ensure_size("", sw * sh * 4, 0)   // (the write_ functions write into it in place)
    let n = float(factor * factor)
    for(sh) y:
        for(sw) x:
            var r = 0.0
            var g = 0.0
            var b = 0.0
            var a = 0.0
            for(factor) dy:
                for(factor) dx:
                    let i = ((h - 1 - (y * factor + dy)) * w + x * factor + dx) * 4   // (a framebuffer reads back bottom row first)
                    let pa = float(raw[i + 3]) / 255.0
                    r += float(raw[i]) * pa
                    g += float(raw[i + 1]) * pa
                    b += float(raw[i + 2]) * pa
                    a += pa
            let o = (y * sw + x) * 4
            if a / n >= 0.6:
                write_int8_le(out, o, int(min(255.0, r / a)))
                write_int8_le(out, o + 1, int(min(255.0, g / a)))
                write_int8_le(out, o + 2, int(min(255.0, b / a)))
                write_int8_le(out, o + 3, 255)
    let ink = float3 { 0.141, 0.094, 0.059 }
    let edged = ensure_size("", sw * sh * 4, 0)
    for(sw * sh * 4) i: write_int8_le(edged, i, out[i])
    for(sh) y:
        for(sw) x:
            let i = (y * sw + x) * 4
            if out[i + 3] == 255:
                let edge = x == 0 or y == 0 or x == sw - 1 or y == sh - 1 or out[i - 1] != 255 or out[i + 7] != 255 or out[i - sw * 4 + 3] != 255 or out[i + sw * 4 + 3] != 255
                if edge:
                    for(3) c:
                        let v = float(out[i + c]) / 255.0 * 0.45
                        let inked = v + ([ink.x, ink.y, ink.z][c] - v) * 0.25
                        write_int8_le(edged, i + c, int(inked * 255.0))
    return sw, sh, edged
