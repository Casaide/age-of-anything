// ------------------------------------------------------------------ the ground (src/view/art/terrain_view.gd, scenes/art_pixel/terrain.gdshader)
// One quad over the map drawn by the terrain shader: no grid. Terrain from blurred masks (R water,
// G swamp, B reed-bed ground, A rock) perturbed by noise: rolling light in dithered bands, grass
// lush by water and dry in patches, clover, clumps and worn soil, bog and standing pools, rock
// and scree, trails worn by walkers, water with a sandy bank, a wet edge, depth, the sky and
// ripples. The fog is drawn over it, per tile. Paths (each culture's: paths.gd) are still to come.

let MASK_K = 4    // mask samples per tile
let TERRAIN_SHADERS = """
PIXELFUNCTIONS
    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
    }
    float height(vec2 t) {
        return vnoise(t * 0.35) * 0.55 + vnoise(t * 0.8 + 3.0) * 0.3 + vnoise(t * 1.9 + 7.0) * 0.15;
    }
    vec3 stones(vec2 p, float jitter, out vec2 id, out vec2 off) {
        vec2 ip = floor(p);
        float d1 = 9.0;
        float d2 = 9.0;
        id = ip;
        off = vec2(0.0);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 o = ip + vec2(float(i), float(j));
                vec2 q = o + 0.5 + (vec2(hash(o), hash(o + 3.1)) - 0.5) * jitter;
                float d = length(p - q);
                if (d < d1) { d2 = d1; d1 = d; id = o; off = p - q; } else if (d < d2) { d2 = d; }
            }
        }
        return vec3(d2 - d1, hash(id + 9.0), 0.0);
    }
    vec3 bevel(vec3 col, vec2 off, float edge, float width) {
        float rim = 1.0 - smoothstep(0.0, width, edge);
        float facing = dot(normalize(off + vec2(1e-4)), normalize(vec2(-0.6, -0.8)));
        if (rim > 0.35) {
            col *= facing > 0.2 ? 1.16 : (facing < -0.2 ? 0.74 : 1.0);
        }
        return col;
    }
    vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float v) {
        float q = floor(clamp(v, 0.0, 0.999) * 4.0);
        return q < 1.0 ? a : q < 2.0 ? b : q < 3.0 ? c : d;
    }
    float bayer(ivec2 ap) {
        int k = (ap.y % 4) * 4 + (ap.x % 4);
        float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
        return BAYER[k] / 16.0 - 0.5;
    }

SHADER terrain
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
        iworld = apos.xy / 1.5;   // canvas units at scale 1 (64 x 32 a tile), from art px
    PIXEL
        INPUTS iworld:2
        UNIFORMS tex0 tex1 tex2 tex3
        UNIFORM vec2 map_size
        UNIFORM float art_px
        UNIFORM float time
        vec2 world = iworld;
        float a = world.x / 32.0;
        float b = world.y / 16.0;
        vec2 t = vec2((a + b) * 0.5, (b - a) * 0.5);
        if (t.x < 0.0 || t.y < 0.0 || t.x > map_size.x || t.y > map_size.y) discard;
        vec4 m = texture(tex0, t / map_size);
        float n = vnoise(t * 2.3) * 0.6 + vnoise(t * 6.1) * 0.4;
        float grain = vnoise(t * 9.0) * 0.55 + vnoise(t * 23.0) * 0.45;
        vec2 cell = floor(t * 22.0);
        float bay = bayer(ivec2(gl_FragCoord.xy / art_px));
        vec2 e = vec2(0.06, 0.0);
        vec2 grad = vec2(height(t + e.xy) - height(t - e.xy), height(t + e.yx) - height(t - e.yx)) / (2.0 * e.x);
        float lit = clamp(0.5 + dot(grad, vec2(-0.8, -0.25)) * 1.1, 0.0, 1.0);
        float light = mix(0.8, 1.16, floor(clamp(lit + bay * 0.3, 0.0, 0.999) * 5.0) / 4.0);
        float lush = smoothstep(0.04, 0.35, m.r);
        float dry = smoothstep(0.5, 0.78, vnoise(t * 0.45 + 17.0)) * (1.0 - lush);
        float g = clamp(grain + bay * 0.22, 0.0, 0.999);
        vec3 col = ramp4(vec3(0.24, 0.36, 0.14), vec3(0.30, 0.43, 0.17), vec3(0.36, 0.50, 0.20), vec3(0.43, 0.56, 0.24), g);
        vec3 dry_col = ramp4(vec3(0.36, 0.38, 0.16), vec3(0.44, 0.45, 0.19), vec3(0.52, 0.51, 0.24), vec3(0.60, 0.57, 0.30), g);
        vec3 lush_col = ramp4(vec3(0.16, 0.30, 0.13), vec3(0.20, 0.36, 0.15), vec3(0.24, 0.42, 0.18), vec3(0.30, 0.48, 0.20), g);
        if (dry + bay * 0.3 > 0.45) col = dry_col;
        if (lush + bay * 0.3 > 0.5) col = lush_col;
        float h = hash(cell);
        if (h > 0.965) col = col * 1.25 + vec3(0.04, 0.05, 0.0);
        else if (h < 0.03) col *= 0.7;
        if (vnoise(t * 3.1 + 40.0) > 0.78 && hash(cell + 21.0) > 0.4) col = mix(col, vec3(0.28, 0.48, 0.20), 0.6);
        float drift = vnoise(t * 0.17 + 61.0);
        col *= mix(vec3(1.06, 1.02, 0.84), vec3(0.9, 1.0, 1.06), drift);
        float clump = vnoise(t * 4.3 + 7.0) * 0.7 + vnoise(t * 11.0) * 0.3;
        if (clump > 0.66) col *= (hash(cell + 31.0) > 0.7 ? 1.12 : 0.8);
        float worn = vnoise(t * 0.7 + 33.0) * 0.8 + vnoise(t * 5.0 + 3.0) * 0.2;
        if (worn > 0.7 && hash(cell + 41.0) > 0.45) col = mix(col, vec3(0.42, 0.34, 0.22), 0.55 + 0.2 * hash(cell + 43.0));
        float reed = clamp(m.b * 1.3 + (n - 0.5) * 0.5, 0.0, 1.0);
        col = mix(col, col * vec3(0.8, 0.86, 0.72), floor(reed * 3.0) / 3.0 * 0.8);
        float swamp = m.g + (n - 0.5) * 0.4;
        if (swamp > 0.5) {
            float bog = vnoise(t * 1.6 + 5.0) * 0.6 + vnoise(t * 4.5 + 9.0) * 0.4;
            col = ramp4(vec3(0.20, 0.24, 0.13), vec3(0.25, 0.30, 0.15), vec3(0.30, 0.35, 0.17), vec3(0.36, 0.40, 0.19), grain);
            if (bog < 0.36) col = ramp4(vec3(0.26, 0.21, 0.14), vec3(0.31, 0.25, 0.16), vec3(0.36, 0.29, 0.19), vec3(0.41, 0.34, 0.22), grain);
            float pool = vnoise(t * 0.55 + 13.0) * 0.75 + vnoise(t * 2.0 + 3.0) * 0.2 + (vnoise(t * 9.0) - 0.5) * 0.05;
            if (pool > 0.6) {
                col = mix(vec3(0.20, 0.31, 0.28), vec3(0.26, 0.38, 0.35), floor(clamp(grain + bay * 0.3, 0.0, 0.999) * 3.0) / 2.0);
                if (pool < 0.615) col = vec3(0.30, 0.25, 0.16);
                else if (vnoise(t * 2.0 + vec2(0.0, 0.6)) - vnoise(t * 2.0) > 0.06) col = mix(col, vec3(0.42, 0.55, 0.56), 0.45);
                if (hash(cell + 17.0) > 0.97) col = vec3(0.45, 0.58, 0.2);
            } else {
                if (hash(cell + 7.0) > 0.93 && fract(t.y * 22.0) < 0.6) col = (hash(cell + 8.0) > 0.5) ? vec3(0.42, 0.50, 0.20) : vec3(0.14, 0.20, 0.10);
                if (vnoise(t * 6.0 + 77.0) > 0.74) col = mix(col, vec3(0.44, 0.52, 0.18), 0.5);
            }
        } else if (swamp > 0.44) {
            col = mix(col, vec3(0.20, 0.27, 0.16), 0.6);
        }
        float rock = m.a + (n - 0.5) * 0.35;
        if (rock > 0.5) {
            col = ramp4(vec3(0.27, 0.25, 0.21), vec3(0.33, 0.31, 0.26), vec3(0.40, 0.37, 0.31), vec3(0.46, 0.43, 0.36), grain);
            if (hash(cell + 13.0) > 0.88) col *= 0.72;
        } else if (rock > 0.42) {
            col = mix(col, vec3(0.32, 0.29, 0.22), 0.5);
        }
        vec4 pth = texture(tex1, t / map_size);
        vec2 wob = vec2(vnoise(t * 1.3 + 11.0), vnoise(t * 1.3 + 29.0)) - 0.5;
        float trod = 0.0;
        for (int k = 0; k < 8; k++) {
            float ak = float(k) * 0.785398;
            trod += texture(tex2, (t + wob * 0.8 + vec2(cos(ak), sin(ak)) * 0.75) / map_size).r;
        }
        trod = (trod / 8.0) * 0.6 + texture(tex2, (t + wob * 0.5) / map_size).r * 0.4;
        pth.r = max(pth.r, smoothstep(0.12, 0.5, trod) * 0.7);
        float st_trail = pth.r + (n - 0.5) * 0.45;
        float st_board = pth.g + (n - 0.5) * 0.12;
        float st_cob = pth.b + (n - 0.5) * 0.25;
        float st_road = pth.a + (n - 0.5) * 0.08;
        float jag = (hash(floor(t * 11.0)) - 0.5) * 0.12;
        float top = max(max(st_trail, st_board + jag), max(st_cob - jag, st_road + jag * 0.5));
        if (top > 0.5) {
            if (top == st_trail) {
                col = ramp4(vec3(0.38, 0.30, 0.19), vec3(0.44, 0.35, 0.22), vec3(0.50, 0.40, 0.26), vec3(0.55, 0.45, 0.30), grain);
                float across = pth.r;
                if (abs(across - 0.8) < 0.04) col *= 0.78;
                else if (across > 0.9 && vnoise(t * 7.0) > 0.55) col = mix(col, vec3(0.30, 0.40, 0.17), 0.7);
                if (hash(cell + 3.0) > 0.95) col = vec3(0.62, 0.58, 0.50);
                else if (hash(cell + 5.0) < 0.04) col = vec3(0.30, 0.24, 0.15);
            } else if (top == st_board + jag) {
                float u = texture(tex3, t / map_size).r * 3.4;
                float plank = floor(u);
                col = mix(vec3(0.42, 0.29, 0.16), vec3(0.56, 0.40, 0.23), hash(vec2(plank, 7.0)));
                col *= 0.88 + 0.24 * vnoise(vec2(plank * 5.0, (t.x - t.y) * 9.0));
                if (hash(vec2(plank, 3.0)) > 0.86) col = mix(col, vec3(0.46, 0.44, 0.38), 0.45);
                if (fract(u) < 0.13) col = vec3(0.20, 0.13, 0.07);
                if (st_board < 0.6) {
                    col = vec3(0.30, 0.20, 0.11);
                    if (mod(plank, 5.0) < 1.0) col = (fract(u) < 0.5) ? vec3(0.44, 0.31, 0.18) : vec3(0.17, 0.11, 0.06);
                }
                if (hash(cell + plank) > 0.985) col = vec3(0.70, 0.66, 0.58);
            } else if (top == st_cob - jag) {
                vec2 id;
                vec2 off;
                vec3 v = stones(t * 7.0, 0.85, id, off);
                col = mix(vec3(0.38, 0.37, 0.32), vec3(0.58, 0.55, 0.48), v.y);
                col *= mix(vec3(1.0), vec3(1.06, 0.98, 0.9), hash(id + 2.0));
                col = bevel(col, off, v.x, 0.3);
                if (v.x < 0.15) col = (hash(cell + 19.0) > 0.8) ? vec3(0.24, 0.30, 0.14) : vec3(0.25, 0.20, 0.14);
                if (st_cob < 0.58 && v.y > 0.6) col = mix(col, vec3(0.32, 0.27, 0.18), 0.7);
            } else {
                vec2 id;
                vec2 off;
                vec3 v = stones(t * vec2(3.2, 3.6), 0.55, id, off);
                col = mix(vec3(0.58, 0.55, 0.48), vec3(0.74, 0.71, 0.62), v.y);
                col *= 0.92 + 0.12 * vnoise(t * 14.0 + id);
                if (vnoise(t * 2.2 + id * 3.0) > 0.72) col *= vec3(0.86, 0.84, 0.76);
                col = bevel(col, off, v.x, 0.22);
                if (v.x < 0.07) col = vec3(0.30, 0.26, 0.19);
                if (st_road < 0.62 && hash(id + 5.0) > 0.55) col = mix(vec3(0.34, 0.30, 0.21), col, 0.25);
                else if (st_road < 0.56) col = vec3(0.46, 0.44, 0.39);
            }
        } else if (top > 0.43) {
            col = mix(col, vec3(0.30, 0.26, 0.18), 0.45);
            if (top == st_board + jag) col = mix(col, vec3(0.10, 0.08, 0.05), 0.45);
            else if (hash(cell + 51.0) > 0.7) col = mix(col, vec3(0.30, 0.42, 0.18), 0.6);
        }
        float water = m.r + (n - 0.5) * 0.3;
        col *= light;
        if (water > 0.38) {
            col = ramp4(vec3(0.42, 0.36, 0.24), vec3(0.48, 0.41, 0.27), vec3(0.54, 0.47, 0.31), vec3(0.60, 0.53, 0.36), g) * light;
        }
        if (water > 0.45) {
            col = mix(vec3(0.30, 0.25, 0.17), vec3(0.24, 0.20, 0.14), step(0.0, bay));
        }
        if (water > 0.5) {
            float depth = smoothstep(0.5, 1.0, m.r + (n - 0.5) * 0.12);
            float dd = clamp(depth + bay * 0.05, 0.0, 1.0);
            vec3 shallow = vec3(0.33, 0.45, 0.36);
            vec3 mid = vec3(0.17, 0.34, 0.37);
            vec3 deep = vec3(0.09, 0.21, 0.28);
            col = dd < 0.45 ? mix(shallow, mid, dd / 0.45) : mix(mid, deep, (dd - 0.45) / 0.55);
            col *= 0.94 + 0.12 * vnoise(t * 0.9 + 12.0);
            if (depth < 0.22) col = mix(col, vec3(0.46, 0.43, 0.30), (0.22 - depth) * 1.6 * vnoise(t * 5.0 + 4.0));
            vec2 sp = vec2(world.x * 0.018, world.y * 0.16);
            float sky = vnoise(sp + vec2(time * 0.03, 0.0)) * 0.6 + vnoise(sp * 2.3 + vec2(-time * 0.05, 3.0)) * 0.4;
            col = mix(col, vec3(0.50, 0.64, 0.66), smoothstep(0.58, 0.82, sky) * 0.35 * (0.4 + depth * 0.6));
            float rip = vnoise(vec2(world.x * 0.09 + time * 0.4, world.y * 0.6 + time * 0.15));
            float rip2 = vnoise(vec2(world.x * 0.07 - time * 0.3, world.y * 0.55 + 5.0));
            if (rip > 0.8 && rip2 > 0.55) col = mix(col, vec3(0.70, 0.82, 0.82), 0.35);
            else if (rip > 0.74 && rip2 > 0.55) col *= 0.92;
            col *= mix(0.86, 1.0, smoothstep(0.5, 0.6, water));
            float foam = 0.53 + 0.012 * sin(time * 1.1 + n * 9.0);
            if (water < foam) col = mix(col, vec3(0.70, 0.80, 0.76), 0.6 * step(0.35, vnoise(t * 14.0 + time * 0.3)));
        }
        float edge = min(min(t.x, t.y), min(map_size.x - t.x, map_size.y - t.y));
        col *= mix(0.25, 1.0, floor(clamp(edge / 0.9 + bay * 0.25, 0.0, 1.0) * 4.0) / 4.0);
        frag_color = vec4(col, 1.0);
"""

var mask_tex:resource<texture>? = nil
var paths_tex:resource<texture>? = nil
var arc_tex:resource<texture>? = nil
var wear_tex:resource<texture>? = nil
var ground_quad:resource<mesh>? = nil
var fog_mesh:resource<mesh>? = nil

def mask_channel(name:string) -> int:
    return switch name:
        case "water", "shallows", "river", "deep_river", "ford": 0
        case "swamp": 1
        case "reeds", "tree", "stump": 2
        case "rock": 3
        default: -1

def mask_weight(name:string) -> float:
    return switch name:
        case "shallows": 0.62
        case "ford": 0.56
        case "river": 0.8
        case "tree": 0.75
        case "stump": 0.35
        default: 1.0

// The masks (TerrainView.build): K samples a tile, each the weight of its terrain's channel, box
// blurred five times, as bytes.
def build_masks():
    let w = W * MASK_K
    let h = H * MASK_K
    var a = map(w * h * 4): 0.0
    for(h) y:
        for(w) x:
            let name = tr_names[terrain[(y / MASK_K) * W + x / MASK_K]]
            let ch = mask_channel(name)
            if ch >= 0: a[(y * w + x) * 4 + ch] = mask_weight(name)
    var b = map(w * h * 4): 0.0
    for(5):
        for(h) y:
            for(w) x:
                let x0 = max(x - 1, 0)
                let x1 = min(x + 1, w - 1)
                for(4) ch: b[(y * w + x) * 4 + ch] = (a[(y * w + x0) * 4 + ch] + a[(y * w + x) * 4 + ch] + a[(y * w + x1) * 4 + ch]) / 3.0
        for(h) y:
            let y0 = max(y - 1, 0)
            let y1 = min(y + 1, h - 1)
            for(w) x:
                for(4) ch: a[(y * w + x) * 4 + ch] = (b[(y0 * w + x) * 4 + ch] + b[(y * w + x) * 4 + ch] + b[(y1 * w + x) * 4 + ch]) / 3.0
    let rows = map(h) y: map(w) x: float4 { byte_of(a[(y * w + x) * 4]), byte_of(a[(y * w + x) * 4 + 1]), byte_of(a[(y * w + x) * 4 + 2]), byte_of(a[(y * w + x) * 4 + 3]) }
    mask_tex = gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap)
    let zero = map(4): map(4): float4_0
    paths_tex = gl.create_texture(zero, texture_format_clamp | texture_format_nomipmap)
    arc_tex = gl.create_texture(zero, texture_format_clamp | texture_format_nomipmap)
    let c0 = iso(0.0, 0.0)
    let c1 = iso(float(W * 1000), 0.0)
    let c2 = iso(float(W * 1000), float(H * 1000))
    let c3 = iso(0.0, float(H * 1000))
    ground_quad = gl.new_mesh("P", [float3 { c0.x, c0.y, 0.0 }, float3 { c1.x, c1.y, 0.0 }, float3 { c2.x, c2.y, 0.0 }, float3 { c3.x, c3.y, 0.0 }],
                              []::float4, []::float3, []::float2, []::float2, [0, 2, 1, 0, 3, 2])

def byte_of(v:float) -> float: return float(clamp(int(v * 255.0 + 0.5), 0, 255)) / 255.0

// The trails worn by walkers (trails.lobster's wear, per tile), for the shader.
def build_wear():
    wear_tex = gl.create_texture(map(H) y: map(W) x: float4 { float(if y * W + x < wear.length: wear[y * W + x] else: 0) / 255.0, 0.0, 0.0, 0.0 },
                                 texture_format_clamp | texture_format_nomipmap)

// The fog over the ground, per tile (explored: dimmed; never seen: dark), corners blended.
def build_fog(me:int):
    let fg = fog[me]
    let dark = map(W * H) c: if fg[c] == 0: 0.88 elif fg[c] == 1: 0.45 else: 0.0
    let corner = map((W + 1) * (H + 1)) v:
        let vx = v % (W + 1)
        let vy = v / (W + 1)
        var sum = 0.0
        var n = 0
        for([int2 { -1, -1 }, int2 { 0, -1 }, int2 { -1, 0 }, int2 { 0, 0 }]) d:
            let x = vx + d.x
            let y = vy + d.y
            if x >= 0 and y >= 0 and x < W and y < H:
                sum += dark[y * W + x]
                n++
        sum / float(max(1, n))
    let pos = []::float3
    let col = []::float4
    let idx = []::int
    for(W * H) c:
        let cx = c % W
        let cy = c / W
        let n = pos.length
        let m = iso(float(cx * 1000 + 500), float(cy * 1000 + 500))
        pos.push(float3 { m.x, m.y, 0.0 })
        col.push(float4 { 0.0, 0.0, 0.0, dark[c] })
        for([int2 { 0, 0 }, int2 { 1, 0 }, int2 { 1, 1 }, int2 { 0, 1 }]) d:
            let p = iso(float((cx + d.x) * 1000), float((cy + d.y) * 1000))
            pos.push(float3 { p.x, p.y, 0.0 })
            col.push(float4 { 0.0, 0.0, 0.0, corner[(cy + d.y) * (W + 1) + cx + d.x] })
        for([0, 2, 1, 0, 3, 2, 0, 4, 3, 0, 1, 4]) v: idx.push(n + v)
    fog_mesh = gl.new_mesh("PC", pos, col, []::float3, []::float2, []::float2, idx)

def draw_ground(art_px:float):
    let gq = ground_quad
    let mt = mask_tex
    let pt = paths_tex
    let wt = wear_tex
    let at = arc_tex
    if not gq or not mt or not pt or not wt or not at: return
    gl.set_shader("terrain")
    gl.set_uniform("map_size", float2 { float(W), float(H) })
    gl.set_uniform("art_px", art_px)
    gl.set_uniform("time", gl.time())
    gl.set_mesh_texture(gq, 0, 0, mt)
    gl.set_mesh_texture(gq, 0, 1, pt)
    gl.set_mesh_texture(gq, 0, 2, wt)
    gl.set_mesh_texture(gq, 0, 3, at)
    gl.render_mesh(gq)

def draw_fog():
    let fm = fog_mesh
    if fm:
        gl.set_shader("color_attr")
        gl.render_mesh(fm)
