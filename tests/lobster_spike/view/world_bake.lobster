// ------------------------------------------------------------------ buildings and props baked to pixel art (src/view/art/bake/baker.gd, pixel mode)
// A model in world units (1 = a tile) rendered as the building baker does: the 2:1 isometric camera (30 down,
// 45 round), a sun from the screen's upper left with its shadow, a cool fill, a warm rim, ambient light;
// each material as Godot's StandardMaterial3D lights it (its texture by UV or triplanar, its normal map, a
// Schlick-GGX highlight by roughness and specular), Godot's filmic tone at exposure 0.95; supersampled and
// pixelized without the units' outline. With ground shadows: where the sun's shadow falls on the ground
// (the sun shadow), and a contact band under the model (the occlusion where it meets the ground).

let WB_SS = 4                                   // ArtKit.SS
let WB_ART = 1.5                                // ArtKit.ART_SCALE: art px a canvas unit
let WB_PX = 32.0 / 0.70710678 * WB_ART          // art px a world unit (Baker.PX_PER_UNIT x the art scale)

let WORLD_SHADERS = """
SHADER worlddepth
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
        idepth = vec2(apos.z, 0.0);
    PIXEL
        INPUTS idepth:2
        frag_color = vec4(idepth.x * 0.5 + 0.5, 0.0, 0.0, 1.0);

SHADER worldlit
    VERTEX
        INPUTS apos:4 anormal:3 atc:2 acolor:4
        UNIFORMS mvp
        UNIFORM vec3 cam_x
        UNIFORM vec3 cam_y
        UNIFORM vec3 cam_z
        UNIFORM vec4 vmap
        UNIFORM vec2 dmap
        gl_Position = mvp * apos;
        inorm = anormal;
        float d = dmap.x + (0.9 - apos.z) / dmap.y;
        iobj = vec4(cam_x * (apos.x / vmap.x + vmap.y) - cam_y * (apos.y / vmap.x + vmap.z) + cam_z * d, 1.0);
        iuv = atc;
        icol = acolor;
    PIXEL
        INPUTS inorm:3 iobj:4 iuv:2 icol:4
        UNIFORMS tex0 tex1 tex2
        UNIFORM vec4 albedo
        UNIFORM vec4 uvmap
        UNIFORM vec4 uvmap2
        UNIFORM vec4 mat0
        UNIFORM vec4 mat1
        UNIFORM vec3 sun_dir
        UNIFORM vec3 fill_dir
        UNIFORM vec3 rim_dir
        UNIFORM vec3 view_dir
        UNIFORM vec4 lx
        UNIFORM vec4 ly
        UNIFORM vec4 lz
        UNIFORM vec2 lsize
        UNIFORM vec4 pass
        // mat0: mapping (0 none, 1 UV, 2 triplanar), triplanar sharpness, roughness, specular (metallic_specular)
        // mat1: metallic, normal map (0/1), normal scale, unshaded; pass: x 1 = only the sun (the ground's shadow
        // mask), y 1 = alpha scissor
        vec3 n = normalize(inorm);
        if (dot(n, view_dir) < 0.0) n = -n;   // (seen from behind: cull disabled where it shows)
        vec4 t = vec4(1.0);
        if (mat0.x > 1.5) {
            // Godot's triplanar: weights from the normal to the sharpness, pos x scale + offset, y flipped
            vec3 w = pow(abs(n), vec3(mat0.y));
            w /= dot(w, vec3(1.0));
            vec3 p = iobj.xyz * uvmap.xyz + uvmap2.xyz;
            p *= vec3(1.0, -1.0, 1.0);
            t = texture(tex0, p.xy) * w.z + texture(tex0, p.zy) * w.x + texture(tex0, p.xz * vec2(1.0, -1.0)) * w.y;
        } else if (mat0.x > 0.5) {
            t = texture(tex0, iuv * uvmap.xy + uvmap2.xy);
            if (mat1.y > 0.5) {
                // the normal map in a tangent frame from the UVs' screen derivatives
                vec3 dp1 = dFdx(iobj.xyz);
                vec3 dp2 = dFdy(iobj.xyz);
                vec2 du1 = dFdx(iuv);
                vec2 du2 = dFdy(iuv);
                vec3 dp2perp = cross(dp2, n);
                vec3 dp1perp = cross(n, dp1);
                vec3 tg = dp2perp * du1.x + dp1perp * du2.x;
                vec3 bt = dp2perp * du1.y + dp1perp * du2.y;
                float invmax = inversesqrt(max(dot(tg, tg), dot(bt, bt)) + 0.0000001);
                vec3 nm = texture(tex2, iuv * uvmap.xy + uvmap2.xy).xyz * 2.0 - 1.0;
                nm.xy *= mat1.z;
                n = normalize(tg * invmax * nm.x - bt * invmax * nm.y + n * nm.z);
            }
        }
        if (pass.y > 0.5 && t.a < 0.5) discard;   // alpha scissor (cards, decals)
        vec3 base = albedo.rgb * icol.rgb * t.rgb;
        vec3 lin_base = pow(base, vec3(2.2));
        // the sun's shadow (its depth map, seen from the sun)
        vec3 lp = vec3(dot(iobj.xyz, lx.xyz) + lx.w, dot(iobj.xyz, ly.xyz) + ly.w, dot(iobj.xyz, lz.xyz) + lz.w);
        float nearest = texture(tex1, vec2(lp.x / lsize.x, 1.0 - lp.y / lsize.y)).r * 2.0 - 1.0;
        float lit = lp.z > nearest + 0.004 ? 0.0 : 1.0;
        if (nearest > 0.999 || lp.x < 0.0 || lp.y < 0.0 || lp.x > lsize.x || lp.y > lsize.y) lit = 1.0;   // (nothing between it and the sun there)
        if (pass.x > 0.5) {   // the ground's sun mask: white lit by the sun alone, shadowed
            frag_color = vec4(vec3(lit * max(0.0, dot(n, -sun_dir))), 1.0);
        } else {
            vec3 v = normalize(view_dir);
            float rough = max(mat0.z, 0.04);
            float a = rough * rough;
            float a2 = a * a;
            vec3 f0 = mix(vec3(0.16 * mat0.w * mat0.w), lin_base, mat1.x);
            vec3 diffuse = vec3(0.0);
            vec3 spec = vec3(0.0);
            vec3 dirs[3] = vec3[3](sun_dir, fill_dir, rim_dir);
            vec3 cols[3] = vec3[3](vec3(1.0) * 1.05, vec3(0.481, 0.578, 1.0) * 0.25, vec3(1.0, 0.871, 0.631) * 0.3);
            for (int k = 0; k < 3; k++) {
                vec3 l = -dirs[k];
                float nl = max(0.0, dot(n, l));
                if (nl <= 0.0) continue;
                float sh = k == 0 ? lit : 1.0;
                vec3 h = normalize(l + v);
                float nh = max(0.0, dot(n, h));
                float nv = max(0.0001, dot(n, v));
                float dd = nh * nh * (a2 - 1.0) + 1.0;
                float D = a2 / (3.14159265 * dd * dd);
                float gv = nl * sqrt(nv * nv * (1.0 - a2) + a2);
                float gl = nv * sqrt(nl * nl * (1.0 - a2) + a2);
                float V = 0.5 / max(gv + gl, 0.0001);
                float lh = max(0.0, dot(l, h));
                vec3 F = f0 + (1.0 - f0) * pow(1.0 - lh, 5.0);
                diffuse += cols[k] * nl * sh;
                spec += cols[k] * nl * sh * D * V * F * 3.14159265;
            }
            vec3 ambient = vec3(0.578, 0.631, 0.745) * 0.28;
            vec3 lin = lin_base * (1.0 - mat1.x) * (diffuse + ambient) + spec;
            if (mat1.w > 0.5) lin = lin_base;
            // Godot's filmic tone (exposure 0.95, white 1), then sRGB
            lin *= 0.95;
            vec3 A = vec3(0.22 * 4.0); vec3 B = vec3(0.30 * 2.0);
            vec3 c = ((lin * (A * lin + 0.10 * B) + 0.20 * 0.01) / (lin * (A * lin + B) + 0.20 * 0.30)) - 0.01 / 0.30;
            float wt = ((1.0 * (0.88 * 1.0 + 0.06) + 0.002) / (1.0 * (0.88 * 1.0 + 0.6) + 0.06)) - 0.01 / 0.30;
            c /= wt;
            frag_color = vec4(pow(clamp(c, 0.0, 1.0), vec3(1.0 / 2.2)), 1.0);
        }
"""

// ---- the model as draws: one per mesh, its MMat whole (the building materials carry more than BakeMat)

class WDraw:
    mat:MMat
    p:[float3]
    n:[float3]
    uv:[float2]
    c:[float3]

def world_draws(n:MNode, parent:Xform, out:[WDraw]) -> void:
    if not n.visible: return
    let t = xmul(parent, node_xform(n))
    let mesh = n.mesh
    let mat = n.mat
    if mesh and mat:
        let nb = btransposed(binverse(t.b))
        let d = WDraw { mat, [], [], [], [] }
        for(mesh.idx) i:
            d.p.push(xf(t, mesh.p[i]))
            d.n.push(normalize(bxf(nb, mesh.n[i])))
            d.uv.push(mesh.uv[i])
            d.c.push(if mat.vertex_colours and mesh.c.length > i: mesh.c[i] else: float3_1)
        out.push(d)
    for(n.kids) kid: world_draws(kid, t, out)

let wb_tex = dictionary<string, resource<texture>>(64)
def wb_texture(name:string) -> resource<texture>?:
    if name == "": return nil
    let file = if find_string(name, "/") >= 0: name + ".png" else: model_tex_dir + "/" + name + ".png"
    let known = wb_tex.get(file)
    if known: return known
    let t = gl.load_texture(file)
    assert t
    wb_tex.set(file, t)
    return t

// Godot's DirectionalLight3D shines along its -z: rotation_degrees -> where the light goes.
def light_along(r:float3) -> float3: return -euler(r).z

// One model baked: its pixel sprite (RGBA bytes), w, h, and where its anchor (the world origin) is on it.
// shadow: paint its ground shadows; reach: room for them (trees cast long ones: 2).
def world_bake(model:MNode, shadow:bool, reach:float = 1.0) -> string, int, int, float2:
    let draws = []::WDraw
    world_draws(model, XF_ID, draws)
    let cam = euler(float3 { -30.0, 45.0, 0.0 })
    let cx = cam.x
    let cy = cam.y
    let cz = cam.z
    let sun = light_along(float3 { -48.0, -58.0, 0.0 })
    let px = WB_PX * float(WB_SS)
    // the box on screen: the model, and where its shadow falls on the ground
    var lo = float2_1 * 1000000000.0
    var hi = float2_1 * -1000000000.0
    var dlo = 1000000000.0
    var dhi = -1000000000.0
    var ylo = 1000000000.0
    for(draws) d:
        for(d.p) p:
            let s = float2 { dot(p, cx), -dot(p, cy) }
            lo = min(lo, s)
            hi = max(hi, s)
            dlo = min(dlo, dot(p, cz))
            dhi = max(dhi, dot(p, cz))
            ylo = min(ylo, p.y)
            if shadow and p.y > 0.0:
                let g = p + sun * (p.y / -sun.y)   // its shadow on the ground
                let sg = float2 { dot(g, cx), -dot(g, cy) }
                lo = min(lo, sg)
                hi = max(hi, sg)
    let room = 4.0 / px * float(WB_SS)
    lo -= float2_1 * room
    hi += float2_1 * room
    // the ground plane's patch under it all (shadows land on it): its corners on screen as y = 0 points
    let w = int(ceiling((hi.x - lo.x) * px))
    let h = int(ceiling((hi.y - lo.y) * px))
    // ---- the sun's depth map
    let kx, ky, kz = looking_at(sun, float3 { 0.0, 1.0, 0.0 })
    var llo = float2_1 * 1000000000.0
    var lhi = float2_1 * -1000000000.0
    var zlo = 1000000000.0
    var zhi = -1000000000.0
    for(draws) d:
        for(d.p) p:
            let s = float2 { dot(p, kx), -dot(p, ky) }
            llo = min(llo, s)
            lhi = max(lhi, s)
            zlo = min(zlo, dot(p, kz))
            zhi = max(zhi, dot(p, kz))
    llo -= float2_1 * 0.5
    lhi += float2_1 * 0.5
    let lpx = px * 0.5
    let lw = int(ceiling((lhi.x - llo.x) * lpx))
    let lh = int(ceiling((lhi.y - llo.y) * lpx))
    let zs = 1.8 / max(0.001, zhi - zlo)
    let spos = []::float3
    for(draws) d:
        if not d.mat.scissor:
            for(d.p) p: spos.push(float3 { (dot(p, kx) - llo.x) * lpx, (-dot(p, ky) - llo.y) * lpx, 0.9 - (dot(p, kz) - zlo) * zs })
    let smap = gl.create_blank_texture(int3 { lw, lh, 0 }, texture_format_nomipmap | texture_format_float | texture_format_clamp)
    gl.switch_to_framebuffer(smap, true)
    gl.ortho(false, true)
    gl.clear(float4_1)
    gl.set_shader("worlddepth")
    gl.render_mesh(gl.new_mesh("P", spos, []::float4, []::float3, []::float2, []::float2, map(spos.length) i: i))
    // ---- the lit pass (and, for the ground shadow, the sun mask on a ground plane)
    let vz = 1.8 / max(0.001, dhi - dlo + 40.0)
    let dbase = dlo - 20.0
    def vz_of(p:float3) -> float: return 0.9 - (dot(p, cz) - dbase) * vz
    def to_px(p:float3) -> float3: return float3 { (dot(p, cx) - lo.x) * px, (-dot(p, cy) - lo.y) * px, vz_of(p) }
    def set_common():
        gl.set_uniform("cam_x", cx)
        gl.set_uniform("cam_y", cy)
        gl.set_uniform("cam_z", cz)
        gl.set_uniform("vmap", float4 { px, lo.x, lo.y, 0.0 })
        gl.set_uniform("dmap", float2 { dbase, vz })
        gl.set_uniform("sun_dir", sun)
        gl.set_uniform("fill_dir", light_along(float3 { -20.0, -60.0, 0.0 }))
        gl.set_uniform("rim_dir", light_along(float3 { -15.0, -135.0, 0.0 }))
        gl.set_uniform("view_dir", cz)
        gl.set_uniform("lx", float4 { kx.x * lpx, kx.y * lpx, kx.z * lpx, -llo.x * lpx })
        gl.set_uniform("ly", float4 { -ky.x * lpx, -ky.y * lpx, -ky.z * lpx, -llo.y * lpx })
        gl.set_uniform("lz", float4 { -kz.x * zs, -kz.y * zs, -kz.z * zs, 0.9 + zlo * zs })
        gl.set_uniform("lsize", float2 { float(lw), float(lh) })
    def draw_model(sun_only:bool):
        for(draws) d:
            let m = d.mat
            let pos = map(d.p) p: to_px(p)
            let cols = map(d.c) c: float4 { c.x, c.y, c.z, 1.0 }
            let mesh = gl.new_mesh("PNTC", pos, cols, d.n, d.uv, []::float2, map(pos.length) i: i)
            let t0 = wb_texture(m.tex)
            let t2 = if m.normal_enabled: wb_texture(m.normal_tex) else: nil
            if t0: gl.set_mesh_texture(mesh, 0, 0, t0)
            gl.set_mesh_texture(mesh, 0, 1, smap)
            if t2: gl.set_mesh_texture(mesh, 0, 2, t2)
            gl.set_shader("worldlit")
            set_common()
            gl.set_uniform("albedo", float4 { m.albedo.x, m.albedo.y, m.albedo.z, 1.0 })
            gl.set_uniform("uvmap", float4 { m.uv_scale.x, m.uv_scale.y, m.uv_scale.z, 0.0 })
            gl.set_uniform("uvmap2", float4 { m.uv_offset.x, m.uv_offset.y, m.uv_offset.z, 0.0 })
            gl.set_uniform("mat0", float4 { if not t0: 0.0 elif m.triplanar: 2.0 else: 1.0, m.triplanar_sharpness, m.roughness, m.metallic_specular })
            gl.set_uniform("mat1", float4 { m.metallic, if t2: 1.0 else: 0.0, m.normal_scale, if m.unshaded: 1.0 else: 0.0 })
            gl.set_uniform("pass", float4 { if sun_only: 1.0 else: 0.0, if m.scissor: 1.0 else: 0.0, 0.0, 0.0 })
            gl.render_mesh(mesh)
    let art = gl.create_blank_texture(int3 { w, h, 0 }, texture_format_nomipmap)
    gl.switch_to_framebuffer(art, true)
    gl.ortho(false, true)
    gl.clear(float4_0)
    draw_model(false)
    gl.switch_to_framebuffer(nil)
    let raw = gl.read_texture(art) or ""
    var mask = ""
    if shadow:
        // the ground: a plane at y 0 under the whole frame, white, lit by the sun alone, the model only
        // shadowing it (not drawn: its own pixels are masked out below by the art's alpha)
        let gpts = []::float3
        for([float2 { lo.x, lo.y }, float2 { hi.x, lo.y }, float2 { hi.x, hi.y }, float2 { lo.x, hi.y }]) s:
            // the ground point seen at screen point s: along the view from x cx + y up the screen onto y = 0
            let o = cx * s.x - cy * s.y
            let g = o - cz * (o.y / cz.y)
            gpts.push(g + float3 { 0.0, 0.003, 0.0 })
        let gm = gl.create_blank_texture(int3 { w, h, 0 }, texture_format_nomipmap)
        gl.switch_to_framebuffer(gm, true)
        gl.ortho(false, true)
        gl.clear(float4_0)
        let gpos = map(gpts) p: to_px(p)
        let ground = gl.new_mesh("PNTC", gpos, map(4): float4_1, map(4): float3 { 0.0, 1.0, 0.0 }, map(4): float2_0, []::float2, [0, 1, 2, 0, 2, 3])
        gl.set_mesh_texture(ground, 0, 1, smap)
        gl.set_shader("worldlit")
        set_common()
        gl.set_uniform("albedo", float4_1)
        gl.set_uniform("mat0", float4 { 0.0, 1.0, 1.0, 0.5 })
        gl.set_uniform("mat1", float4_0)
        gl.set_uniform("pass", float4 { 1.0, 0.0, 0.0, 0.0 })
        gl.render_mesh(ground)
        gl.switch_to_framebuffer(nil)
        mask = gl.read_texture(gm) or ""
    let sw, sh, sprite = pixelize(raw, w, h, WB_SS, "", false)
    if shadow: paint_ground_shadows(sprite, sw, sh, mask, w, h)
    // the anchor (the world origin) on the sprite, in art px
    let anchor = float2 { (0.0 - lo.x) * px, (0.0 - lo.y) * px } / float(WB_SS)
    return sprite, sw, sh, anchor

// Baker._paint_shadows: the sun's shadow where the mask went dark, and the hand-drawn contact band (a short
// dark strip of ground right below the lowest pixels in every column) so things sit on the ground.
let WB_SHADOW = [15, 13, 8, 107]     // Pixelize.SHADOW (0.06, 0.05, 0.03, 0.42)
let WB_CONTACT = [15, 13, 8, 61]     // Pixelize.CONTACT (alpha 0.24)
def paint_ground_shadows(art:string, w:int, h:int, mask:string, mw:int, mh:int):
    let bottom = map(w) x:
        var b = -1
        var y = h - 1
        while y >= 0:
            if art[(y * w + x) * 4 + 3] == 255:
                b = y
                break
            y--
        b
    for(h) y:
        for(w) x:
            let i = (y * w + x) * 4
            if art[i + 3] == 0:
                // the mask, box-filtered down to this art pixel (it reads back bottom row first)
                var lum = 0.0
                var a = 0.0
                for(WB_SS) dy:
                    for(WB_SS) dx:
                        let j = ((mh - 1 - (y * WB_SS + dy)) * mw + x * WB_SS + dx) * 4
                        lum += (float(mask[j]) * 0.3 + float(mask[j + 1]) * 0.59 + float(mask[j + 2]) * 0.11) / 255.0
                        a += float(mask[j + 3]) / 255.0
                let n = float(WB_SS * WB_SS)
                var c = []::int
                if a / n > 0.5 and lum / n < 0.35: c = WB_SHADOW
                elif bottom[x] >= 0 and y > bottom[x] and y <= bottom[x] + 3: c = WB_CONTACT
                if c.length:
                    for(4) k: write_int8_le(art, i + k, c[k])
