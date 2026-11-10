// ------------------------------------------------------------------ the buildings' materials (src/view/art/bake/materials.gd)
// bmat(name) is Materials.get_mat (cached; bmat_matte is its `matte`), bflat(c, rough, metal) is Materials.flat.
// The authored ones (bld_*.svg, wicker, thatch) point at textures/<name>.png (tex_png.gd); the noise ones make
// their textures here as Godot's NoiseTexture2D does (FastNoiseLite 2D, a seamless image of bytes, the colour ramp
// sampled as Gradient does, the normal map as Image.bump_map_to_normal_map), written once as PNGs into
// textures/bmat_<name>_<albedo|normal>.png (bmat_dir) and named in MMat.tex / MMat.normal_tex.
// mat_check.sh holds them to Godot's (mat_dump.gd) pixel by pixel.
// Needs model/kit (MMat), model/props (FastNoiseLite's hash, gradients, OpenSimplex2S), view/node (f32).

var bmat_matte = false     // pixel-art bakes: no gloss, no clearcoat (art_kit.gd sets it)
let bmat_dir = "textures"  // where the noise textures are written (relative, as model_tex_dir)
let BMAT_VERSION = 1       // in the file names: bump it when the textures change
let bmat_cache = dictionary<string, MMat>(32)

// ------------------------------------------------------------------ FastNoiseLite, 2D (Godot's: FBm, gain 0.5, lacunarity 2)

let BMAT_RV2 = [
    -0.270022220, -0.962854091, 0.386309263, -0.922369315, 0.044448590, -0.999011673, -0.599252316, -0.800560218,
    -0.781928029, 0.623368717, 0.946467227, 0.322799920, -0.651414680, -0.758721896, 0.937847229, 0.347048376,
    -0.849787596, -0.527125262, -0.879042592, 0.476743245, -0.892300288, -0.451442351, -0.379844434, -0.925050380,
    -0.995165083, 0.098216379, 0.772439781, -0.635088014, 0.757328332, -0.653034300, -0.992800453, -0.119780055,
    -0.053266571, 0.998580329, 0.975425373, -0.220330076, -0.766501816, 0.642242139, 0.991636706, 0.129060618,
    -0.994696838, 0.102850379, -0.537920551, -0.842995540, 0.502281547, -0.864704139, 0.455982146, -0.889988923,
    -0.865913122, -0.500194427, 0.087945841, -0.996125258, -0.505168498, 0.863020735, 0.775318523, -0.631570415,
    -0.692194461, 0.721711042, -0.519165945, -0.854673459, 0.897862288, -0.440276404, -0.170677411, 0.985326962,
    -0.935343011, -0.353742071, -0.999240480, 0.038967468, -0.288206402, -0.957568311, -0.966381133, 0.257113800,
    -0.875971424, -0.482363001, -0.830312302, -0.557298377, 0.051101338, -0.998693473, -0.855837328, -0.517245075,
    0.098870253, 0.995100333, 0.918901609, 0.394486798, -0.243937589, -0.969790932, -0.812140939, -0.583461306,
    -0.991043136, 0.133542135, 0.849242399, -0.528003171, -0.971783899, -0.235872959, 0.994945721, 0.100414207,
    0.624106551, -0.781339243, 0.662910307, 0.748698821, -0.719741818, 0.694241828, -0.814337077, -0.580392216,
    0.104521054, -0.994522674, -0.106592611, -0.994302778, 0.445799684, -0.895132751, 0.105547406, 0.994414272,
    -0.992790267, 0.119864448, -0.833436641, 0.552615025, 0.911556156, -0.411175600, 0.828554491, -0.559908435,
    0.721709765, -0.692195792, 0.494049268, -0.869433908, -0.365232127, -0.930916480, -0.969660676, 0.244454850,
    0.089255097, -0.996008799, 0.535407128, -0.844594108, -0.105357619, 0.994434398, -0.989028459, 0.147725110,
    0.004856105, 0.999988209, 0.988559848, 0.150829133, 0.928612956, -0.371049832, -0.583239386, -0.812300325,
    0.301520751, 0.953459615, -0.957511053, 0.288396574, 0.971580215, -0.236710551, 0.229981792, 0.973194932,
    0.955763816, -0.294135221, 0.740956116, 0.671553448, -0.997151379, -0.075426308, 0.690571066, -0.723264545,
    -0.290713703, -0.956810087, 0.591277779, -0.806467971, -0.945459221, -0.325740481, 0.666445568, 0.745553690,
    0.623613491, 0.781732827, 0.912699385, -0.408631659, -0.819176201, 0.573541935, -0.881274576, -0.472604615,
    0.995331363, 0.096516727, 0.985565085, -0.169296970, -0.849598089, 0.527430647, 0.617485395, -0.786582346,
    0.850815637, 0.525464320, 0.998503245, -0.054692499, 0.197137156, -0.980375919, 0.660785575, -0.750574729,
    -0.030974941, 0.999520161, -0.673166080, 0.739491331, -0.719501836, -0.694490538, 0.972751169, 0.231851598,
    0.999705909, -0.024250691, 0.442178743, -0.896926953, 0.998135096, -0.061043673, -0.917366080, -0.398044565,
    -0.815005664, -0.579452991, -0.878933130, 0.476945020, 0.015860583, 0.999874213, -0.809546447, 0.587055832,
    -0.916589891, -0.399828679, -0.802354257, 0.596848094, -0.517673792, 0.855578077, -0.815440731, -0.578840578,
    0.402201035, -0.915551379, -0.905255687, -0.424867204, 0.731744562, 0.681578973, -0.564763220, -0.825252995,
    -0.840327633, -0.542078840, -0.931428153, 0.363925262, 0.523819847, 0.851829072, 0.743280387, -0.668980019,
    -0.985371561, -0.170419737, 0.460146873, 0.887842810, 0.825855404, 0.563881948, 0.618236610, 0.785992045,
    0.833150286, -0.553046653, 0.150030751, 0.988681331, -0.662330369, -0.749211907, -0.668598664, 0.743623444,
    0.702560628, 0.711623892, -0.541938976, -0.840417840, -0.338861646, 0.940836216, 0.833153031, 0.553042517,
    -0.298972066, -0.954261863, 0.263852299, 0.964563095, 0.124108739, -0.992268623, -0.728264931, -0.685295696,
    0.696250015, 0.717799357, -0.918353537, 0.395761016, -0.632610227, -0.774470335, -0.933189186, -0.359385508,
    -0.115377936, -0.993321666, 0.951497479, -0.307656542, -0.089879774, -0.995952622, 0.667849692, 0.744296170,
    0.795240039, -0.606294714, -0.646200740, -0.763167481, -0.273359875, 0.961911835, 0.966959023, -0.254931851,
    -0.979289460, 0.202465193, -0.536950299, -0.843613878, -0.270036471, -0.962850094, -0.640027713, 0.768351825,
    -0.785453749, -0.618920357, 0.060059054, -0.998194826, -0.024557704, 0.999698414, -0.659836230, 0.751409442,
    -0.625389447, -0.780312783, -0.621040885, -0.783778170, 0.834888849, 0.550418577, -0.159227524, 0.987241913,
    0.836762249, 0.547566379, -0.867575392, -0.497305681, -0.202266263, -0.979330567, 0.939918994, 0.341397547,
    0.987740481, -0.156104909, -0.903445566, 0.428702822, 0.126980422, -0.991905223, -0.381960085, 0.924178821,
    0.975462589, 0.220165249, -0.320401586, -0.947281808, -0.987476088, 0.157768739, 0.025353485, -0.999678549,
    0.483513079, -0.875337136, -0.285079992, -0.958503729, -0.068055160, -0.997681560, -0.788524405, -0.615003466,
    0.318539213, -0.947909685, 0.888004309, 0.459835131, 0.647692149, -0.761902146, 0.982024130, 0.188755419,
    0.935727513, -0.352723719, -0.889489541, 0.456955529, 0.792279130, 0.610158815, 0.748381826, 0.663268153,
    -0.728892975, -0.684627658, 0.872903278, -0.487893294, 0.828834578, 0.559493737, 0.080745671, 0.996734737,
    0.979914822, -0.199416505, -0.580730673, -0.814095747, -0.470004979, -0.882663764, 0.240949298, 0.970537704,
    0.943781676, -0.330569431, -0.892799864, -0.450453553, -0.806962230, 0.590603047, 0.062589732, 0.998039341,
    -0.931259747, 0.364355985, 0.577744978, 0.816217336, -0.336009585, -0.941858566, 0.697932075, -0.716163961,
    -0.002008157, -0.999997984, -0.182729431, -0.983163239, -0.652391172, 0.757882417, -0.430262691, -0.902703726,
    -0.998512629, -0.054520913, -0.010281022, -0.999947149, -0.494607113, 0.869116680, -0.299935019, 0.953959634,
    0.816547196, 0.577278682, 0.269746047, 0.962931498, -0.730628739, -0.682774960, -0.759095206, -0.650979622,
    -0.907053853, 0.421014617, -0.510486106, -0.859886001, 0.861335060, 0.508037316, 0.500788159, -0.865569881,
    -0.654158152, 0.756357794, -0.838275531, -0.545246856, 0.694007083, 0.719968172, 0.069509360, 0.997581299,
    0.170294219, -0.985393261, 0.269597327, 0.962973147, 0.551961219, -0.833869782, 0.225657487, -0.974206702,
    0.421526285, -0.906816184, 0.488187331, -0.872738867, -0.368385500, -0.929673127, -0.982539058, 0.186056443,
    0.812564710, 0.582870991, 0.319646093, -0.947537005, 0.957091386, 0.289786264, -0.687665550, -0.726027611,
    -0.998877092, -0.047376731, -0.125017903, 0.992154486, -0.828013362, 0.560708367, 0.932486377, -0.361205145,
    0.639465318, 0.768819944, -0.016238471, -0.999868147, -0.995501467, -0.094746135, -0.814533150, 0.580117012,
    0.403732798, -0.914876947, 0.994426337, 0.105433677, -0.162471165, 0.986713292, -0.994948781, -0.100383875,
    -0.699530256, 0.714602981, 0.526341492, -0.850273270, -0.539522148, 0.841971408, 0.657937032, 0.753072946,
    0.014267588, -0.999898213, -0.673438399, 0.739243345, 0.639412098, -0.768864207, 0.921157142, 0.389190852,
    -0.146637214, -0.989190339, -0.782318098, 0.622879116, -0.503961084, -0.863726360, -0.774312019, -0.632803996 ]

let BMAT_SIMPLEX = 0         // FastNoiseLite.TYPE_SIMPLEX (OpenSimplex2)
let BMAT_SIMPLEX_SMOOTH = 1  // TYPE_SIMPLEX_SMOOTH (OpenSimplex2S)
let BMAT_CELLULAR = 2        // TYPE_CELLULAR (euclidean distance, jitter 1)
let BMAT_CELL_VALUE = 0      // cellular return types, as FastNoiseLite numbers them
let BMAT_DISTANCE = 1
let BMAT_DISTANCE2_DIV = 6

class BNoise:
    kind:int
    freq:float
    seed:int
    octaves:int
    cell_return:int  // (Godot's default: BMAT_DISTANCE)

// A double rounded to a float32's 24 bits (Veltkamp's split: to nearest; far quicker than f32, for the hot loops)
def b32(x:float) -> float:
    let c = x * 536870913.0
    return c - (c - x)

def bmat_round(f:float) -> int: return if f >= 0.0: int(f + 0.5) else: int(f - 0.5)

// float32 constants of OpenSimplex2's 2D case (FastNoiseLite's, in float)
let BMAT_S3 = b32(FNL_SQRT3)
let BMAT_G2 = b32(b32(3.0 - BMAT_S3) / 6.0)
let BMAT_F2 = b32(0.5 * b32(BMAT_S3 - 1.0))
let BMAT_C1 = b32(b32(b32(2.0 * b32(1.0 - b32(2.0 * BMAT_G2))) * b32(b32(1.0 / BMAT_G2) - 2.0)))
let BMAT_C2 = b32(b32(-2.0 * b32(1.0 - b32(2.0 * BMAT_G2))) * b32(1.0 - b32(2.0 * BMAT_G2)))
let BMAT_G2M = b32(2.0 * BMAT_G2 - 1.0)

def bmat_grad2(seed:int, xp:int, yp:int, xd:float, yd:float) -> float:
    var h = fnl_hash(seed, xp, yp, 0)
    h ^= h >> 15
    h &= 127 << 1
    return b32(b32(xd * FNL_G2D[h]) + b32(yd * FNL_G2D[h | 1]))

def bmat_corner(a:float) -> float: return b32(b32(a * a) * b32(a * a))

// OpenSimplex2, 2D (FastNoiseLite SingleSimplex, in float32; x, y already skewed)
def bmat_os2_2d(seed:int, x:float, y:float) -> float:
    let G2 = BMAT_G2
    var i = fnl_floor(x)
    var j = fnl_floor(y)
    let xi = b32(x - float(i))
    let yi = b32(y - float(j))
    let t = b32(b32(xi + yi) * G2)
    let x0 = b32(xi - t)
    let y0 = b32(yi - t)
    i *= FNL_PX
    j *= FNL_PY
    var n0 = 0.0
    var n1 = 0.0
    var n2 = 0.0
    let a = b32(b32(0.5 - b32(x0 * x0)) - b32(y0 * y0))
    if a > 0.0: n0 = b32(bmat_corner(a) * bmat_grad2(seed, i, j, x0, y0))
    let c = b32(b32(BMAT_C1 * t) + b32(BMAT_C2 + a))
    if c > 0.0:
        let x2 = b32(x0 + BMAT_G2M)
        let y2 = b32(y0 + BMAT_G2M)
        n2 = b32(bmat_corner(c) * bmat_grad2(seed, i + FNL_PX, j + FNL_PY, x2, y2))
    if y0 > x0:
        let x1 = b32(x0 + G2)
        let y1 = b32(y0 + b32(G2 - 1.0))
        let b = b32(b32(0.5 - b32(x1 * x1)) - b32(y1 * y1))
        if b > 0.0: n1 = b32(bmat_corner(b) * bmat_grad2(seed, i, j + FNL_PY, x1, y1))
    else:
        let x1 = b32(x0 + b32(G2 - 1.0))
        let y1 = b32(y0 + G2)
        let b = b32(b32(0.5 - b32(x1 * x1)) - b32(y1 * y1))
        if b > 0.0: n1 = b32(bmat_corner(b) * bmat_grad2(seed, i + FNL_PX, j, x1, y1))
    return b32(b32(b32(n0 + n1) + n2) * b32(99.83685446303647))

// Cellular, 2D, euclidean (FastNoiseLite SingleCellular)
def bmat_cellular_2d(seed:int, x:float, y:float, ret:int) -> float:
    let xr = bmat_round(x)
    let yr = bmat_round(y)
    var d0 = 10000000000.0
    var d1 = 10000000000.0
    var closest = 0
    let jitter = b32(0.43701595)
    var xp = (xr - 1) * FNL_PX
    let ypb = (yr - 1) * FNL_PY
    var xi = xr - 1
    while xi <= xr + 1:
        var yp = ypb
        var yi = yr - 1
        while yi <= yr + 1:
            let h = fnl_hash(seed, xp, yp, 0)
            let idx = h & (255 << 1)
            let vx = b32(b32(float(xi) - x) + b32(BMAT_RV2[idx] * jitter))
            let vy = b32(b32(float(yi) - y) + b32(BMAT_RV2[idx | 1] * jitter))
            let nd = b32(b32(vx * vx) + b32(vy * vy))
            d1 = max(min(d1, nd), d0)
            if nd < d0:
                d0 = nd
                closest = h
            yp += FNL_PY
            yi++
        xp += FNL_PX
        xi++
    if ret >= BMAT_DISTANCE:
        d0 = sqrt(d0)
        if ret >= 2: d1 = sqrt(d1)
    switch ret:
        case 0: return b32(float(closest) * (1.0 / 2147483648.0))
        case 1: return d0 - 1.0
        case 2: return d1 - 1.0
        case 3: return (d1 + d0) * 0.5 - 1.0
        case 4: return d1 - d0 - 1.0
        case 5: return d1 * d0 * 0.5 - 1.0
        default: return d0 / d1 - 1.0

// FastNoiseLite.get_noise_2d (FBm over the octaves)
def bmat_noise(n:BNoise, px:float, py:float) -> float:
    let fr = f32(n.freq)
    var x = b32(px * fr)
    var y = b32(py * fr)
    if n.kind != BMAT_CELLULAR:
        let t = b32(b32(x + y) * BMAT_F2)
        x = b32(x + t)
        y = b32(y + t)
    var amp_fractal = 1.0
    var g = 0.5
    for(n.octaves - 1):
        amp_fractal += g
        g *= 0.5
    var amp = b32(1.0 / amp_fractal)
    var s = n.seed
    var sum = 0.0
    for(n.octaves):
        var v = 0.0
        if n.kind == BMAT_SIMPLEX: v = bmat_os2_2d(s, x, y)
        elif n.kind == BMAT_SIMPLEX_SMOOTH: v = b32(fnl_os2s_2d(s, x, y))
        else: v = bmat_cellular_2d(s, x, y, n.cell_return)
        sum = b32(sum + b32(v * amp))
        s++
        x *= 2.0
        y *= 2.0
        amp *= 0.5
    return f32(sum)

// ------------------------------------------------------------------ NoiseTexture2D (seamless, normalised, its skirt 0.1)

// Noise.get_image's bytes over w x h (normalised to the min and max, as real_t)
def bmat_bytes(n:BNoise, w:int, h:int) -> [int]:
    let vals = []::float
    var lo = 1000000000.0
    var hi = -1000000000.0
    for(h) y:
        for(w) x:
            let v = bmat_noise(n, float(x), float(y))
            vals.push(v)
            if v > hi: hi = v
            if v < lo: lo = v
    let span = f32(hi - lo)
    return map(vals) v: if hi == lo: 0 else: int(clamp(f32(f32(f32(v - lo) / span) * 255.0), 0.0, 255.0))

def bmat_blend(bg:int, fg:int, alpha:int) -> int: return ((alpha + 1) * fg + (256 - alpha) * bg) >> 8

def bmat_skirt_alpha(i:int, skirt:int) -> int:
    let s = clamp(f32(f32(f32(float(i) / float(skirt)) - f32(0.1)) / f32(f32(0.9) - f32(0.1))), 0.0, 1.0)
    let ss = f32(f32(s * s) * f32(3.0 - f32(2.0 * s)))
    return int(f32(255.0 * f32(1.0 - ss)))

// Noise.get_seamless_image: a bigger image, its quadrants swapped, the skirt blended over the seams
def bmat_seamless(n:BNoise, w:int, h:int) -> [int]:
    let sw = max(1, int(float(w) * f32(0.1)))
    let sh = max(1, int(float(h) * f32(0.1)))
    let srcw = w + sw
    let srch = h + sh
    let src = bmat_bytes(n, srcw, srch)
    let hw = w / 2
    let hh = h / 2
    let ex = hw + sw
    let ey = hh + sh
    def rd(x:int, y:int, mode:int) -> int:  // 0 default, 1 alt x, 2 alt y, 3 alt xy (Noise.img_buff)
        let mx = if mode == 1 or mode == 3: w else: srcw
        let my = if mode == 2 or mode == 3: h else: srch
        return src[(x + hw) % mx + ((y + hh) % my) * srcw]
    let dest = map(w * h) i: rd(i % w, i / w, 3)
    for(sw) k:
        let x = hw + k
        let alpha = bmat_skirt_alpha(k, sw)
        for(h) y:
            if y < hh or y >= ey: dest[x + y * w] = bmat_blend(dest[x + y * w], rd(x, y, 2), alpha)
    for(sh) k:
        let y = hh + k
        let alpha = bmat_skirt_alpha(k, sh)
        for(w) x:
            if x < hw or x >= ex: dest[x + y * w] = bmat_blend(dest[x + y * w], rd(x, y, 1), alpha)
    for(sh) ky:
        let y = hh + ky
        let ypos = bmat_skirt_alpha(ky, sh)
        for(sw) kx:
            let x = hw + kx
            let xpos = bmat_skirt_alpha(kx, sw)
            let top = bmat_blend(rd(x, y, 1), rd(x, y, 0), xpos)
            let bottom = bmat_blend(rd(x, y, 3), rd(x, y, 2), xpos)
            dest[x + y * w] = bmat_blend(bottom, top, ypos)
    return dest

// The colour ramp (Gradient.get_color_at_offset: linear, sRGB) at each byte's luminance, as RGBA8 bytes
def bmat_ramp_lut(offs:[float], hexes:[string]) -> [[int]]:
    let o = map(offs) f: f32(f)
    let cs = map(hexes) hx: v32(html(hx))
    let np = o.length
    return map(256) byte:
        let l = f32(float(byte) / 255.0)
        let p = f32(f32(f32(f32(0.2126) * l) + f32(f32(0.7152) * l)) + f32(f32(0.0722) * l))
        var lo_i = 0
        var hi_i = np - 1
        var middle = 0
        var c = float3_0
        var found = false
        while lo_i <= hi_i and not found:
            middle = (lo_i + hi_i) / 2
            if o[middle] > p: hi_i = middle - 1
            elif o[middle] < p: lo_i = middle + 1
            else:
                c = cs[middle]
                found = true
        if not found:
            if o[middle] > p: middle--
            if middle + 1 >= np: c = cs[np - 1]
            elif middle < 0: c = cs[0]
            else:
                let wt = f32(f32(p - o[middle]) / f32(o[middle + 1] - o[middle]))
                let ca = cs[middle]
                let cb = cs[middle + 1]
                c = float3 { f32(ca.x + f32(wt * f32(cb.x - ca.x))), f32(ca.y + f32(wt * f32(cb.y - ca.y))), f32(ca.z + f32(wt * f32(cb.z - ca.z))) }
        [ int(clamp(c.x * 255.0, 0.0, 255.0)), int(clamp(c.y * 255.0, 0.0, 255.0)), int(clamp(c.z * 255.0, 0.0, 255.0)), 255 ]

def bmat_albedo(img:[int], offs:[float], hexes:[string]) -> [int]:
    let lut = bmat_ramp_lut(offs, hexes)
    let out = []::int
    for(img) b: for(lut[b]) ch: out.push(ch)
    return out

// Image.bump_map_to_normal_map(bump) on the bytes (w x h, wrapping), as RGBA8 bytes
def bmat_normal(img:[int], w:int, h:int, bump:float) -> [int]:
    let lv = map(256) b: f32(float(b) / 255.0)
    let bs = f32(bump)
    let out = []::int
    for(h) ty:
        let py = (ty + 1) % h
        for(w) tx:
            let px = (tx + 1) % w
            let here = lv[img[ty * w + tx]]
            let right = lv[img[ty * w + px]]
            let above = lv[img[py * w + tx]]
            let nx = -f32(f32(right - here) * bs)
            let ny = -f32(f32(here - above) * bs)
            let l = f32(sqrt(f32(f32(f32(nx * nx) + f32(ny * ny)) + 1.0)))
            out.push(int(127.5 + f32(nx / l) * 127.5))
            out.push(int(127.5 + f32(ny / l) * 127.5))
            out.push(int(127.5 + f32(1.0 / l) * 127.5))
            out.push(255)
    return out

// ------------------------------------------------------------------ the materials

// A noise material's recipe (materials.gd _make): its noise, colour ramp, uv scale, bump
class BRecipe:
    noise:BNoise
    offs:[float]
    hexes:[string]
    uv:float3
    bump:float

// A noise texture's pixels ("albedo" or "normal"): RGBA8 bytes, 512 x 512, made from the recipe's image of bytes
def bmat_pixels(r:BRecipe, img:[int], slot:string) -> [int]:
    return if slot == "albedo": bmat_albedo(img, r.offs, r.hexes) else: bmat_normal(img, 512, 512, r.bump)

def bmat_image(r:BRecipe) -> [int]: return bmat_seamless(r.noise, 512, 512)

def bmat_tex_path(name:string, slot:string) -> string: return "{bmat_dir}/bmat{BMAT_VERSION}_{name}_{slot}"

// Each noise texture is made once and kept as a PNG (both slots from one image of bytes)
def bmat_textures(name:string, r:BRecipe):
    let a = bmat_tex_path(name, "albedo")
    let nm = bmat_tex_path(name, "normal")
    if exists_file(a + ".png") and exists_file(nm + ".png"): return
    let img = bmat_image(r)
    assert write_file(a + ".png", png_bytes(bmat_pixels(r, img, "albedo"), 512, 512))
    assert write_file(nm + ".png", png_bytes(bmat_pixels(r, img, "normal"), 512, 512))

// Materials.flat
def bflat(c:float3, rough:float = 0.6, metal:float = 0.0) -> MMat:
    let m = MMat { c }
    m.roughness = rough
    m.metallic = metal
    return m

def bmat_thatch() -> MMat:
    let m = MMat { float3 { 0.86, 0.82, 0.76 } }
    m.tex = "thatch"
    m.uv_scale = float3 { 9.0, 2.5, 1.0 }
    m.roughness = 1.0
    m.metallic_specular = 0.15
    m.texture_filter = 5
    return m

// the authored ones (materials.gd AUTHORED): name -> texture, world units a tile covers, tint
def bmat_authored(name:string) -> MMat?:
    var tex = ""
    var tile = 1.0
    var tint = float3_1
    switch name:
        case "wood":
            tex = "bld_wood"
            tile = 0.7
        case "stone":
            tex = "bld_stone"
            tile = 1.1
        case "mud":
            tex = "bld_daub"
        case "tin":
            tex = "bld_tin"
            tile = 0.8
        case "brick":
            tex = "bld_brick"
            tile = 0.9
        case "plaster":
            tex = "bld_plaster"
            tile = 1.4
        case "terracotta":
            tex = "bld_tiles"
            tile = 0.6
        case "terracotta_dark":
            tex = "bld_tiles"
            tile = 0.6
            tint = float3 { 0.55, 0.5, 0.5 }
        case "felt":
            tex = "bld_felt"
            tile = 1.2
        case "weave":
            tex = "wicker"
            tile = 0.35
        default: return nil
    let m = MMat { tint }
    m.tex = tex
    m.triplanar = true
    m.world_triplanar = true
    m.triplanar_sharpness = 4.0
    m.uv_scale = float3_1 * f32(1.0 / f32(tile))
    m.roughness = 1.0
    m.metallic_specular = 0.15
    m.texture_filter = 5
    return m

// The noise materials' recipes, setting what else the material takes (materials.gd _make's match)
def bmat_recipe(name:string, m:MMat) -> BRecipe:
    switch name:
        case "grass":
            m.roughness = 0.95
            return BRecipe { BNoise { BMAT_SIMPLEX, 0.04, 13, 5, BMAT_DISTANCE }, [ 0.0, 0.5, 0.8, 1.0 ], [ "#36521e", "#4c6e28", "#628634", "#7a9840" ], float3_1, 3.0 }
        case "swamp":
            m.roughness = 0.2
            m.metallic_specular = 0.7
            return BRecipe { BNoise { BMAT_SIMPLEX, 0.012, 17, 3, BMAT_DISTANCE }, [ 0.0, 0.5, 0.8, 1.0 ], [ "#1e3430", "#2a4438", "#3a5440", "#4a6044" ], float3_1, 1.0 }
        case "frog":
            m.roughness = 0.35
            m.clearcoat_enabled = true
            m.clearcoat = 0.5
            return BRecipe { BNoise { BMAT_CELLULAR, 0.05, 19, 4, BMAT_CELL_VALUE },
                             [ 0.0, 0.55, 0.56, 0.7, 0.71, 1.0 ], [ "#4f8a3a", "#5e9c44", "#3f6e30", "#3f6e30", "#64a64a", "#6cb052" ], float3_1, 4.0 }
        default:
            assert false  // an unknown material (or one of the unreachable recipes listed at the end)
            return BRecipe { BNoise { 0, 0.0, 0, 0, 0 }, [], [], float3_1, 0.0 }

def bmat_noise_names() -> [string]: return [ "grass", "swamp", "frog" ]

def bmat_make(name:string) -> MMat:
    if name == "thatch": return bmat_thatch()
    let au = bmat_authored(name)
    if au: return au
    let m = MMat { float3_1 }
    let r = bmat_recipe(name, m)
    bmat_textures(name, r)
    m.tex = bmat_tex_path(name, "albedo")
    m.normal_enabled = true
    m.normal_tex = bmat_tex_path(name, "normal")
    m.uv_scale = r.uv
    m.texture_filter = 5
    if bmat_matte:
        m.roughness = 1.0
        m.metallic_specular = 0.2
        m.clearcoat_enabled = false
    return m

// Materials.get_mat
def bmat(name:string) -> MMat:
    let key = if bmat_matte: name + "|matte" else: name
    let known = bmat_cache.get(key)
    if known: return known
    let m = bmat_make(name)
    bmat_cache.set(key, m)
    return m

// Not ported (unreachable from get_mat: AUTHORED and _thatch answer these names first): materials.gd's noise
// recipes for wood, thatch, mud, stone, tin, brick, plaster, terracotta, terracotta_dark, felt and weave. The noise
// kinds and the cellular return type they'd need are here (BMAT_SIMPLEX_SMOOTH, BMAT_DISTANCE2_DIV) should they return.
