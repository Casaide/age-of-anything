// ------------------------------------------------------------------ landscape props (scenes/art_pixel/prop_models.gd)
// Reed beds, bug bushes, grass tufts, field stones, lily pads, rock outcrops, quarries (stone and gold), carcasses,
// crops and paddies, in world units (1 = a tile), each builder prop_models.gd's of the same name, line for line
// (its comments are there), seeded with Godot's RandomNumberGenerator (model/grng.lobster) drawn in the same order.
// stone_mesh needs Godot's FastNoiseLite (OpenSimplex2S, FBm, its defaults): ported here, as fnl_noise3/fnl_noise2.

def mix3(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t  // Color.lerp

// ------------------------------------------------------------------ FastNoiseLite (Godot's: OpenSimplex2S, FBm, 5 octaves, gain 0.5, lacunarity 2)

let FNL_PX = 501125321
let FNL_PY = 1136930381
let FNL_PZ = 1720413743

def fnl_i32(x:int) -> int: return ((x + 0x80000000) & 0xFFFFFFFF) - 0x80000000

let FNL_G2D = [
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.38268343236509, 0.923879532511287, 0.923879532511287, 0.38268343236509, 0.923879532511287, -0.38268343236509, 0.38268343236509, -0.923879532511287,
    -0.38268343236509, -0.923879532511287, -0.923879532511287, -0.38268343236509, -0.923879532511287, 0.38268343236509, -0.38268343236509, 0.923879532511287 ]
let FNL_G3D = [
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
    1.0, 1.0, 0.0, 0.0, 0.0, -1.0, 1.0, 0.0,
    -1.0, 1.0, 0.0, 0.0, 0.0, -1.0, -1.0, 0.0 ]

def fnl_hash(seed:int, xp:int, yp:int, zp:int) -> int: return fnl_i32(fnl_i32(seed ^ xp ^ yp ^ zp) * 0x27d4eb2d)

def fnl_grad3(seed:int, xp:int, yp:int, zp:int, xd:float, yd:float, zd:float) -> float:
    var h = fnl_hash(seed, xp, yp, zp)
    h ^= h >> 15
    h &= 63 << 2
    return xd * FNL_G3D[h] + yd * FNL_G3D[h | 1] + zd * FNL_G3D[h | 2]

def fnl_grad2(seed:int, xp:int, yp:int, xd:float, yd:float) -> float:
    var h = fnl_hash(seed, xp, yp, 0)
    h ^= h >> 15
    h &= 127 << 1
    return xd * FNL_G2D[h] + yd * FNL_G2D[h | 1]

def fnl_floor(f:float) -> int: return if f >= 0.0: int(f) else: int(f) - 1

def fnl_os2s_3d(seed:int, x:float, y:float, z:float) -> float:
    var i = fnl_floor(x)
    var j = fnl_floor(y)
    var k = fnl_floor(z)
    let xi = x - float(i)
    let yi = y - float(j)
    let zi = z - float(k)
    i *= FNL_PX
    j *= FNL_PY
    k *= FNL_PZ
    let seed2 = seed + 1293373
    let xm = if xi >= 0.5: -1 else: 0  // (int)(-0.5f - xi)
    let ym = if yi >= 0.5: -1 else: 0
    let zm = if zi >= 0.5: -1 else: 0
    def m(mask:int, p:int) -> int: return if mask != 0: p else: 0   // mask & p
    def nm(mask:int, p:int) -> int: return if mask != 0: 0 else: p  // ~mask & p
    let x0 = xi + float(xm)
    let y0 = yi + float(ym)
    let z0 = zi + float(zm)
    let a0 = 0.75 - x0 * x0 - y0 * y0 - z0 * z0
    var value = (a0 * a0) * (a0 * a0) * fnl_grad3(seed, i + m(xm, FNL_PX), j + m(ym, FNL_PY), k + m(zm, FNL_PZ), x0, y0, z0)
    let x1 = xi - 0.5
    let y1 = yi - 0.5
    let z1 = zi - 0.5
    let a1 = 0.75 - x1 * x1 - y1 * y1 - z1 * z1
    value += (a1 * a1) * (a1 * a1) * fnl_grad3(seed2, i + FNL_PX, j + FNL_PY, k + FNL_PZ, x1, y1, z1)
    let xo = float(xm | 1)
    let yo = float(ym | 1)
    let zo = float(zm | 1)
    let xf0 = xo * 2.0 * x1
    let yf0 = yo * 2.0 * y1
    let zf0 = zo * 2.0 * z1
    let xf1 = float(-2 - (xm << 2)) * x1 - 1.0
    let yf1 = float(-2 - (ym << 2)) * y1 - 1.0
    let zf1 = float(-2 - (zm << 2)) * z1 - 1.0
    var skip5 = false
    let a2 = xf0 + a0
    if a2 > 0.0:
        value += (a2 * a2) * (a2 * a2) * fnl_grad3(seed, i + nm(xm, FNL_PX), j + m(ym, FNL_PY), k + m(zm, FNL_PZ), x0 - xo, y0, z0)
    else:
        let a3 = yf0 + zf0 + a0
        if a3 > 0.0:
            value += (a3 * a3) * (a3 * a3) * fnl_grad3(seed, i + m(xm, FNL_PX), j + nm(ym, FNL_PY), k + nm(zm, FNL_PZ), x0, y0 - yo, z0 - zo)
        let a4 = xf1 + a1
        if a4 > 0.0:
            value += (a4 * a4) * (a4 * a4) * fnl_grad3(seed2, i + m(xm, FNL_PX * 2), j + FNL_PY, k + FNL_PZ, xo + x1, y1, z1)
            skip5 = true
    var skip9 = false
    let a6 = yf0 + a0
    if a6 > 0.0:
        value += (a6 * a6) * (a6 * a6) * fnl_grad3(seed, i + m(xm, FNL_PX), j + nm(ym, FNL_PY), k + m(zm, FNL_PZ), x0, y0 - yo, z0)
    else:
        let a7 = xf0 + zf0 + a0
        if a7 > 0.0:
            value += (a7 * a7) * (a7 * a7) * fnl_grad3(seed, i + nm(xm, FNL_PX), j + m(ym, FNL_PY), k + nm(zm, FNL_PZ), x0 - xo, y0, z0 - zo)
        let a8 = yf1 + a1
        if a8 > 0.0:
            value += (a8 * a8) * (a8 * a8) * fnl_grad3(seed2, i + FNL_PX, j + m(ym, FNL_PY << 1), k + FNL_PZ, x1, yo + y1, z1)
            skip9 = true
    var skipd = false
    let aa = zf0 + a0
    if aa > 0.0:
        value += (aa * aa) * (aa * aa) * fnl_grad3(seed, i + m(xm, FNL_PX), j + m(ym, FNL_PY), k + nm(zm, FNL_PZ), x0, y0, z0 - zo)
    else:
        let ab = xf0 + yf0 + a0
        if ab > 0.0:
            value += (ab * ab) * (ab * ab) * fnl_grad3(seed, i + nm(xm, FNL_PX), j + nm(ym, FNL_PY), k + m(zm, FNL_PZ), x0 - xo, y0 - yo, z0)
        let ac = zf1 + a1
        if ac > 0.0:
            value += (ac * ac) * (ac * ac) * fnl_grad3(seed2, i + FNL_PX, j + FNL_PY, k + m(zm, FNL_PZ << 1), x1, y1, zo + z1)
            skipd = true
    if not skip5:
        let a5 = yf1 + zf1 + a1
        if a5 > 0.0:
            value += (a5 * a5) * (a5 * a5) * fnl_grad3(seed2, i + FNL_PX, j + m(ym, FNL_PY << 1), k + m(zm, FNL_PZ << 1), x1, yo + y1, zo + z1)
    if not skip9:
        let a9 = xf1 + zf1 + a1
        if a9 > 0.0:
            value += (a9 * a9) * (a9 * a9) * fnl_grad3(seed2, i + m(xm, FNL_PX * 2), j + FNL_PY, k + m(zm, FNL_PZ << 1), xo + x1, y1, zo + z1)
    if not skipd:
        let ad = xf1 + yf1 + a1
        if ad > 0.0:
            value += (ad * ad) * (ad * ad) * fnl_grad3(seed2, i + m(xm, FNL_PX << 1), j + m(ym, FNL_PY << 1), k + FNL_PZ, xo + x1, yo + y1, z1)
    return value * 9.046026385208288

let FNL_SQRT3 = 1.7320508075688772935274463415059
let FNL_G2 = (3.0 - FNL_SQRT3) / 6.0

def fnl_os2s_2d(seed:int, x:float, y:float) -> float:
    let G2 = FNL_G2
    var i = fnl_floor(x)
    var j = fnl_floor(y)
    let xi = x - float(i)
    let yi = y - float(j)
    i *= FNL_PX
    j *= FNL_PY
    let i1 = i + FNL_PX
    let j1 = j + FNL_PY
    let t = (xi + yi) * G2
    let x0 = xi - t
    let y0 = yi - t
    let a0 = (2.0 / 3.0) - x0 * x0 - y0 * y0
    var value = (a0 * a0) * (a0 * a0) * fnl_grad2(seed, i, j, x0, y0)
    let a1 = (2.0 * (1.0 - 2.0 * G2) * (1.0 / G2 - 2.0)) * t + ((-2.0 * (1.0 - 2.0 * G2) * (1.0 - 2.0 * G2)) + a0)
    let x1 = x0 - (1.0 - 2.0 * G2)
    let y1 = y0 - (1.0 - 2.0 * G2)
    value += (a1 * a1) * (a1 * a1) * fnl_grad2(seed, i1, j1, x1, y1)
    def corner(xc:float, yc:float, ip:int, jp:int):
        let a = (2.0 / 3.0) - xc * xc - yc * yc
        if a > 0.0: value += (a * a) * (a * a) * fnl_grad2(seed, ip, jp, xc, yc)
    let xmyi = xi - yi
    if t > G2:
        if xi + xmyi > 1.0: corner(x0 + (3.0 * G2 - 2.0), y0 + (3.0 * G2 - 1.0), i + (FNL_PX << 1), j + FNL_PY)
        else: corner(x0 + G2, y0 + (G2 - 1.0), i, j + FNL_PY)
        if yi - xmyi > 1.0: corner(x0 + (3.0 * G2 - 1.0), y0 + (3.0 * G2 - 2.0), i + FNL_PX, j + (FNL_PY << 1))
        else: corner(x0 + (G2 - 1.0), y0 + G2, i + FNL_PX, j)
    else:
        if xi + xmyi < 0.0: corner(x0 + (1.0 - G2), y0 - G2, i - FNL_PX, j)
        else: corner(x0 + (G2 - 1.0), y0 + G2, i + FNL_PX, j)
        if yi < xmyi: corner(x0 - G2, y0 - (G2 - 1.0), i, j - FNL_PY)
        else: corner(x0 + G2, y0 + (G2 - 1.0), i, j + FNL_PY)
    return value * 18.24196194486065

let FNL_BOUNDING = 1.0 / (1.0 + 0.5 + 0.25 + 0.125 + 0.0625)

// FastNoiseLite.get_noise_3d at a point (seed, frequency; the rest Godot's defaults).
def fnl_noise3(seed:int, freq:float, p:float3) -> float:
    var x = p.x * freq
    var y = p.y * freq
    var z = p.z * freq
    let r = (x + y + z) * (2.0 / 3.0)
    x = r - x
    y = r - y
    z = r - z
    var s = seed
    var sum = 0.0
    var amp = FNL_BOUNDING
    for(5):
        sum += fnl_os2s_3d(s, x, y, z) * amp
        s++
        x *= 2.0
        y *= 2.0
        z *= 2.0
        amp *= 0.5
    return f32(sum)

def fnl_noise2(seed:int, freq:float, px:float, py:float) -> float:
    var x = px * freq
    var y = py * freq
    let t = (x + y) * (0.5 * (FNL_SQRT3 - 1.0))
    x += t
    y += t
    var s = seed
    var sum = 0.0
    var amp = FNL_BOUNDING
    for(5):
        sum += fnl_os2s_2d(s, x, y) * amp
        s++
        x *= 2.0
        y *= 2.0
        amp *= 0.5
    return f32(sum)

// ------------------------------------------------------------------ float32 vectors (Godot's Vector3 maths, where rounding decides)

def v32(v:float3) -> float3: return float3 { f32(v.x), f32(v.y), f32(v.z) }
def sub32(a:float3, b:float3) -> float3: return v32(a - b)
def cross32(a:float3, b:float3) -> float3:
    return float3 { f32(f32(a.y * b.z) - f32(a.z * b.y)), f32(f32(a.z * b.x) - f32(a.x * b.z)), f32(f32(a.x * b.y) - f32(a.y * b.x)) }
def normalized32(v:float3) -> float3:
    let l2 = f32(f32(f32(v.x * v.x) + f32(v.y * v.y)) + f32(v.z * v.z))
    if l2 == 0.0: return float3_0
    let l = f32(sqrt(l2))
    return float3 { f32(v.x / l), f32(v.y / l), f32(v.z / l) }

// ------------------------------------------------------------------ the props

def reed_clump(seed_value:int, size:float = 1.0, stage:int = 0) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let keep = [ 1.0, 0.55, 0.22, 0.0 ][stage]
    let clumps = []::float3  // x, z of the centre and its radius and height (y unused): [at, r, h]
    let clump_r = []::float
    let clump_h = []::float
    for(randi_range(rng, 5, 7)):
        let ax = randf_range(rng, -0.36, 0.36)
        let az = randf_range(rng, -0.36, 0.36)
        clumps.push(float3 { ax, 0.0, az } * size)
        clump_r.push(randf_range(rng, 0.1, 0.18) * size)
        clump_h.push(randf_range(rng, 0.7, 1.1))
    let cut = plain(html("#a38a52"))
    let cut_top = plain(html("#d8c48a"))
    let blades = int(190.0 * size)
    for(blades) k:
        let ci = k % clumps.length
        let a = randf(rng) * TAU
        let r = sqrt(randf(rng)) * clump_r[ci]
        let base = clumps[ci] + float3 { rcos(a) * r, 0.0, rsin(a) * r }
        var h = randf_range(rng, 0.3, 1.0) * clump_h[ci] * size
        let low = randf(rng) < 0.3
        if low: h *= 0.35
        let yaw = randf(rng) * TAU
        let out = float3 { rcos(yaw), 0.0, rsin(yaw) }
        let lean = randf_range(rng, 0.04, 0.35) + (if randf(rng) < 0.08: 0.6 else: 0.0)
        let dry = randf(rng) < 0.14
        let face_turn = randf_range(rng, -1.0, 1.0)
        let shade = randf(rng)
        let width = randf_range(rng, 0.035, 0.055)
        let cut_roll = randf(rng)
        let sh = randf_range(rng, 0.04, 0.12) * size
        let stays = randf(rng) < keep or low and stage < 3
        if not stays:
            if cut_roll < 0.55 and not low:
                add_child(n, rod(base, base + float3 { 0.0, sh, 0.0 }, 0.012 * size, 0.011 * size, cut, false))
                add_child(n, blob(float3 { 0.012, 0.004, 0.012 } * size, cut_top, base + float3 { 0.0, sh, 0.0 }))
        else:
            let up = normalize(float3 { 0.0, 1.0, 0.0 } + out * lean)
            var facing = normalize(float3 { 0.6 + face_turn * 0.5, 0.0, 1.0 })
            facing = normalize(facing - up * dot(facing, up))
            let lit = clamp(h / (1.05 * size), 0.0, 1.0)
            var tint = mix3(float3 { 0.38, 0.46, 0.3 }, float3 { 1.0, 1.0, 0.86 }, lit * 0.8 + shade * 0.2)
            if dry: tint = mix3(float3 { 1.25, 1.05, 0.6 }, float3 { 1.4, 1.25, 0.8 }, lit)
            add_child(n, decal("reed_leaf", width * size, h, base + up * h * 0.5, facing, true, up, tint))
    let stem = plain(html("#7a8a3a"))
    let velvet = plain(html("#5a361c"))
    for(int(float(randi_range(rng, 4, 8)) * size)):
        let ci = randi(rng) % clumps.length
        let bx = randf_range(rng, -0.08, 0.08)
        let bz = randf_range(rng, -0.08, 0.08)
        let base = clumps[ci] + float3 { bx, 0.0, bz } * size
        let h = randf_range(rng, 0.6, 1.15) * clump_h[ci] * size
        let tx = randf_range(rng, -0.09, 0.09)
        let tz = randf_range(rng, -0.09, 0.09)
        let top = base + float3 { tx, h, tz } * float3 { size, 1.0, size }
        if randf(rng) < keep:
            add_child(n, rod(base, top, 0.011, 0.009, stem, false))
            let head = randf_range(rng, 0.07, 0.12)
            add_child(n, blob(float3 { 0.026, head, 0.026 }, velvet, top - float3 { 0.0, head * 0.9, 0.0 }))
            add_child(n, rod(top, top + float3 { 0.0, 0.08, 0.0 }, 0.005, 0.003, stem, false))
    return n

def bug_bush(seed_value:int, stage:int = 0) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let size = randf_range(rng, 0.8, 1.2)
    let squash = randf_range(rng, 0.8, 1.15)
    let lc = []::float3  // lobes: centres and radii
    let lr = []::float3
    for(randi_range(rng, 4, 7)):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.0, 0.22) * size
        let r = randf_range(rng, 0.13, 0.21) * size
        lc.push(float3 { rcos(a) * d, randf_range(rng, 0.14, 0.3) * size * squash, rsin(a) * d })
        lr.push(float3 { r, r * 0.8 * squash, r })
    for(lc) c, i: add_child(n, blob(lr[i] * 0.8, plain(mix3(html("#1c2c12"), html("#3a2c16"), float(stage) / 3.0)), c))
    var top = 0.0
    for(lc) c, i: top = max(top, c.y + lr[i].y)
    let leaves = [ 1.0, 0.85, 0.7, 0.55 ][stage]
    let brown = [ 0.0, 0.18, 0.36, 0.55 ][stage]
    for(340) k:
        let li = k % lc.length
        let dx = randf_range(rng, -1.0, 1.0)
        let dy = randf_range(rng, -0.3, 1.0)
        let dz = randf_range(rng, -1.0, 1.0)
        let d = normalize(float3 { dx, dy, dz })
        let depth = randf_range(rng, -0.05, 0.015)
        let fx = randf_range(rng, -0.5, 0.5)
        let fy = randf_range(rng, 0.0, 0.6)
        let fz = randf_range(rng, -0.5, 0.5)
        let face = normalize(d + float3 { fx, fy, fz })
        let wither = randf(rng)
        if randf(rng) <= leaves:
            let at = on_surface(lc[li], lr[li], d, depth)
            let lit = clamp(at.y / top, 0.0, 1.0) * 0.7 + (depth + 0.05) / 0.065 * 0.3
            var tint = mix3(float3 { 0.42, 0.5, 0.36 }, float3 { 0.95, 1.0, 0.78 }, lit)
            if wither < brown: tint = tint * float3 { 1.35, 0.95, 0.55 }
            add_child(n, decal("leaf", 0.06 * size, 0.08 * size, at, face, true, d, tint))
    let berry = plain(html("#c8221a"))
    let berries = [ 1.0, 0.5, 0.2, 0.0 ][stage]
    for(46):
        let li = randi(rng) % lc.length
        let dx = randf_range(rng, -1.0, 1.0)
        let dy = randf_range(rng, -0.1, 1.0)
        let dz = randf_range(rng, -1.0, 1.0)
        let d = normalize(float3 { dx, dy, dz })
        if randf(rng) <= berries:
            add_child(n, blob(float3_1 * 0.024 * size, berry, on_surface(lc[li], lr[li], d, 0.012)))
    return n

def grass_tuft(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let size = randf_range(rng, 0.7, 1.3)
    for(randi_range(rng, 22, 32)):
        let a = randf(rng) * TAU
        let r = sqrt(randf(rng)) * 0.08 * size
        let base = float3 { rcos(a) * r, 0.0, rsin(a) * r }
        let h = randf_range(rng, 0.1, 0.26) * size
        let out = float3 { rcos(a), 0.0, rsin(a) }
        let up = normalize(float3 { 0.0, 1.0, 0.0 } + out * randf_range(rng, 0.1, 0.7))
        var facing = normalize(float3 { randf_range(rng, -0.4, 0.8), 0.0, 1.0 })
        facing = normalize(facing - up * dot(facing, up))
        let tint = mix3(float3 { 0.5, 0.62, 0.36 }, float3 { 1.0, 1.0, 0.82 }, randf(rng) * 0.6 + h / (0.2 * size) * 0.4)
        add_child(n, decal("reed_leaf", 0.034, h, base + up * h * 0.5, facing, true, up, tint))
    return n

// A stone's mesh node: its material, scale, turn (degrees) and place.
def prop_stone(mesh:MMesh, m:MMat, scl:float3, rot:float3, pos:float3) -> MNode:
    let mi = mesh_node(mesh, m)
    mi.scl = scl
    mi.rot = rot
    mi.pos = pos
    return mi

def field_stones(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    for(randi_range(rng, 2, 4)) k:
        let r = randf_range(rng, 0.05, 0.12)
        let mesh = stone_mesh(seed_value * 17 + k)
        let m = surf("rock", mix3(float3 { 0.74, 0.74, 0.66 }, float3 { 0.6, 0.62, 0.55 }, randf(rng)), 0.5)
        let sx = r * randf_range(rng, 1.0, 1.5)
        let sy = r * randf_range(rng, 0.5, 0.8)
        let rx = randf_range(rng, -10.0, 10.0)
        let ry = randf_range(rng, 0.0, 180.0)
        let rz = randf_range(rng, -10.0, 10.0)
        let px = randf_range(rng, -0.16, 0.16)
        let pz = randf_range(rng, -0.16, 0.16)
        add_child(n, prop_stone(mesh, m, float3 { sx, sy, r }, float3 { rx, ry, rz }, float3 { px, r * 0.2, pz }))
    return n

def lily_pads(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    for(randi_range(rng, 2, 4)) k:
        let px = randf_range(rng, -0.3, 0.3)
        let pz = randf_range(rng, -0.3, 0.3)
        let p = float3 { px, 0.004 + float(k) * 0.001, pz }
        let s = randf_range(rng, 0.16, 0.26)
        add_child(n, decal("lily_pad", s, s, p, float3 { 0.0, 1.0, 0.0 }, true, float3 { rcos(float(k) * 2.1), 0.0, rsin(float(k) * 2.1) }, float3_1))
        if k % 2 == 0:
            add_child(n, decal("water_lily", s * 0.55, s * 0.55, p + float3 { 0.02, 0.03, 0.02 }, normalize(float3 { 0.15, 1.0, 0.25 }), false))
    return n

// Godot's SphereMesh (radius 1, height 2, 12 segments, 8 rings) in float32, its vertices by row.
let STONE_RADIAL = 12
let STONE_RINGS = 8
let stone_sphere_p = []::float3
let stone_sphere_uv = []::float2
let stone_sphere_idx = []::int

def stone_sphere():
    if stone_sphere_p.length: return
    var thisrow = 0
    var prevrow = 0
    var point = 0
    for(STONE_RINGS + 2) j:
        let v = f32(float(j) / float(STONE_RINGS + 1))
        let w = if j == 0 or j == STONE_RINGS + 1: 0.0 else: f32(sin(180.0 * v))  // (Godot's poles and seam meet exactly)
        let y = f32(cos(180.0 * v))
        for(STONE_RADIAL + 1) i:
            let u = f32(float(i) / float(STONE_RADIAL))
            let x = if i == STONE_RADIAL: 0.0 else: f32(sin(u * 360.0))
            let z = if i == STONE_RADIAL: 1.0 else: f32(cos(u * 360.0))
            stone_sphere_p.push(float3 { f32(x * w), y, f32(z * w) })
            stone_sphere_uv.push(float2 { u, v })
            point++
            if i > 0 and j > 0:
                append_into(stone_sphere_idx, [ prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1 ])
        prevrow = thisrow
        thisrow = point

// An irregular stone: the sphere's vertices pushed about by noise, deindexed, normals generated as SurfaceTool's
// (each face's plane normal, summed over the vertices at the same place: the poles' rows and the seam).
def stone_mesh(seed_value:int, cut:bool = false) -> MMesh:
    stone_sphere()
    let pts = map(stone_sphere_p) v:
        var p = v32(v * (1.0 + fnl_noise3(seed_value, f32(1.3), v32(v * f32(1.7))) * 0.45))
        if cut:
            p = float3 { p.x, f32(min(p.y, 0.5 + fnl_noise2(seed_value, f32(1.3), f32(v.x * 3.0), f32(v.z * 3.0)) * 0.06)), p.z }
            p = float3 { f32(min(p.x, 0.65)), p.y, p.z }
        p
    let group = map(stone_sphere_p.length) i:
        var g = i
        for(i) j:
            if g == i and magnitude(stone_sphere_p[j] - stone_sphere_p[i]) < 0.000001: g = j
        g
    let sums = map(stone_sphere_p.length) i: float3_0
    let m = new_mesh()
    var k = 0
    while k + 2 < stone_sphere_idx.length:
        let a = pts[stone_sphere_idx[k]]
        let b = pts[stone_sphere_idx[k + 1]]
        let c = pts[stone_sphere_idx[k + 2]]
        let nrm = normalized32(cross32(sub32(a, c), sub32(a, b)))
        for(3) j:
            let g = group[stone_sphere_idx[k + j]]
            sums[g] = sums[g] + nrm
        k += 3
    for(stone_sphere_idx) i:
        add_vertex(m, pts[i], normalized32(v32(sums[group[i]])), stone_sphere_uv[i])
    m.idx = map(m.p.length) i: i
    return m

def boulders(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let tints = [ float3 { 0.72, 0.7, 0.66 }, float3 { 0.62, 0.6, 0.56 }, float3 { 0.8, 0.77, 0.7 }, float3 { 0.66, 0.66, 0.62 } ]
    let sx0 = randf_range(rng, -0.08, 0.08)
    let sz0 = randf_range(rng, -0.08, 0.08)
    let at = [ float3 { sx0, 0.0, sz0 } ]
    let rs = [ randf_range(rng, 0.26, 0.34) ]
    for(randi_range(rng, 6, 9)):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.2, 0.45)
        at.push(float3 { rcos(a) * d, 0.0, rsin(a) * d })
        rs.push(randf_range(rng, 0.06, 0.15))
    for(at.length) k:
        let r = rs[k]
        let mesh = stone_mesh(seed_value * 31 + k)
        let m = surf("rock", tints[k % tints.length], 0.6)
        let sx = r * randf_range(rng, 1.0, 1.4)
        let sy = r * randf_range(rng, 0.7, 1.0)
        let rx = randf_range(rng, -15.0, 15.0)
        let ry = randf_range(rng, 0.0, 180.0)
        let rz = randf_range(rng, -15.0, 15.0)
        add_child(n, prop_stone(mesh, m, float3 { sx, sy, r }, float3 { rx, ry, rz }, at[k] + float3 { 0.0, r * 0.35, 0.0 }))
    let lichen = [ plain(html("#b8b46a")), plain(html("#d8d6c8")), plain(html("#5e7a34")) ]
    for(at.length) k:
        let r = rs[k]
        for(if k == 0: 8 else: 2) d:
            let a = randf(rng) * TAU
            let up = randf_range(rng, 0.3, 0.75)
            let p = at[k] + float3 { rcos(a) * r * 0.7 * (1.0 - up * 0.4), r * 0.35 + r * up * 0.7, rsin(a) * r * 0.7 * (1.0 - up * 0.4) }
            let sz = r * randf_range(rng, 0.14, 0.26)
            add_child(n, blob(float3 { sz * 1.4, sz * 0.3, sz }, lichen[(k + d) % 3], p))
        if k == 0:
            for(3):
                let a = randf_range(rng, -0.6, 1.6)
                let p = at[k] + float3 { rcos(a) * r * 0.95, r * 0.55, rsin(a) * r * 0.95 }
                let rx = randf_range(rng, -20.0, 20.0)
                let rz = randf_range(rng, -25.0, 25.0)
                add_child(n, box(float3 { 0.012, r * 0.6, 0.012 }, plain(html("#2a2622")), p, float3 { rx, 0.0, rz }))
    for(12) k:
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.3, 0.55)
        if k % 3 == 0:
            let root = float3 { rcos(a) * d, 0.0, rsin(a) * d }
            for(4) g:
                let lx = randf_range(rng, -0.03, 0.03)
                let ly = randf_range(rng, 0.07, 0.12)
                let lz = randf_range(rng, -0.03, 0.03)
                add_child(n, rod(root, root + float3 { lx, ly, lz }, 0.012, 0.003, plain(if g % 2 == 0: html("#4e7a2c") else: html("#6a9238")), false))
        else:
            let pr = randf_range(rng, 0.015, 0.035)
            add_child(n, prop_stone(stone_mesh(seed_value * 13 + k), surf("rock", tints[k % tints.length], 0.6), float3 { pr * 1.3, pr * 0.7, pr },
                                    float3_0, float3 { rcos(a) * d, pr * 0.3, rsin(a) * d }))
    return n

def quarry(seed_value:int, stage:int = 0, ore:string = "stone") -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let gold = ore == "gold"
    var tints = [ float3 { 0.98, 0.88, 0.7 }, float3 { 0.9, 0.79, 0.62 }, float3 { 1.0, 0.93, 0.8 }, float3 { 0.86, 0.75, 0.6 } ]
    if gold: tints = [ float3 { 0.62, 0.56, 0.5 }, float3 { 0.55, 0.5, 0.46 }, float3 { 0.68, 0.62, 0.55 }, float3 { 0.5, 0.46, 0.42 } ]
    let metal = plain(html("#f2c440"))
    metal.emission = html("#7a5a10")
    let keep = [ 1.0, 0.65, 0.35, 0.0 ][stage]
    let rat = []::float3
    let rr = []::float
    let rturn = []::float
    let rstretch = []::float
    let rkeep = []::bool
    for(randi_range(rng, 5, 7)) k:
        let a = randf(rng) * TAU
        let d = if k == 0: 0.0 else: randf_range(rng, 0.16, 0.38)
        let r = if k == 0: randf_range(rng, 0.3, 0.36) else: randf_range(rng, 0.09, 0.17)
        rat.push(float3 { rcos(a) * d, 0.0, rsin(a) * d })
        rr.push(r)
        rturn.push(randf_range(rng, 0.0, 360.0))
        rstretch.push(randf_range(rng, 1.0, 1.3))
        rkeep.push(randf(rng) < keep)
    for(rat.length) k:
        let r = rr[k] * (if k == 0: 1.0 - 0.25 * float(stage) else: 1.0)
        if rkeep[k] or k == 0 and stage < 3:
            let mi = add_child(n, prop_stone(stone_mesh(seed_value * 31 + k, true), surf("rock", tints[k % tints.length], 0.6),
                                             float3 { r * rstretch[k], r * 0.9, r }, float3 { 0.0, rturn[k], 0.0 }, rat[k] + float3 { 0.0, r * 0.3, 0.0 }))
            if gold:
                let count = if k == 0: 11 else: 3
                for(count) g:
                    let a = if k == 0: (float(g) / float(count)) * MPI * 1.4 - 0.2 else: randf(rng) * TAU
                    let h = if k == 0: 0.1 + 0.3 * abs(rsin(float(g) * 1.7)) else: randf_range(rng, 0.05, 0.35)
                    let gr = r * (if k == 0: 0.17 else: randf_range(rng, 0.18, 0.24))
                    let local = float3 { rcos(a) * 0.68, h, rsin(a) * 0.68 }
                    add_child(n, prop_stone(stone_mesh(seed_value * 7 + k * 5 + g), metal, float3 { gr * 1.3, gr * 0.8, gr }, float3_0, mi.pos + bxf(node_basis(mi), local)))
    if not gold and stage < 3:
        let br = rr[0] * (1.0 - 0.25 * float(stage))
        add_child(n, box(float3 { 0.02, br * 0.9, br * 1.1 }, surf("rock", float3 { 1.0, 0.97, 0.9 }, 0.4), rat[0] + float3 { br * 0.55, br * 0.75, br * 0.45 }, float3 { 0.0, 30.0, -50.0 }))
        let blocks = [ float3 { 0.36, 0.05, 0.3 }, float3 { 0.48, 0.05, 0.2 }, float3 { 0.42, 0.14, 0.26 } ]
        for(3 - stage) b:
            add_child(n, box(float3 { 0.13, 0.09, 0.09 }, surf("rock", tints[b % tints.length], 0.6), blocks[b], float3 { 0.0, 20.0 + float(b) * 25.0, 0.0 }))
    for(9 - stage) k:
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.15, 0.48)
        let r = randf_range(rng, 0.025, 0.05)
        let m = if gold and k % 3 == 0: metal else: surf("rock", tints[k % tints.length], 0.6)
        add_child(n, prop_stone(stone_mesh(seed_value * 17 + k, true), m, float3 { r * 1.3, r * 0.8, r }, float3_0, float3 { rcos(a) * d, r * 0.3, rsin(a) * d }))
    return n

def carcass(seed_value:int, stage:int = 0) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    let hide = plain(html("#6a4a30"))
    let meat = plain(html("#b04a3a"))
    let fat = plain(html("#e8c8b0"))
    let bone = plain(html("#f0e8d8"))
    add_child(n, blob(float3 { 0.34 - float(stage) * 0.06, 0.03, 0.24 - float(stage) * 0.04 }, hide, float3 { 0.0, 0.02, 0.0 }, float3 { 0.0, randf_range(rng, 0.0, 90.0), 0.0 }))
    let cuts = [ 4, 3, 2, 0 ][stage]
    for(4) k:
        let a = randf(rng) * TAU
        let p = float3 { rcos(a) * 0.12, 0.06, rsin(a) * 0.1 }
        if k < cuts:
            add_child(n, blob(float3 { 0.07, 0.045, 0.05 }, meat, p, float3 { 0.0, randf_range(rng, 0.0, 180.0), 0.0 }))
            add_child(n, blob(float3 { 0.05, 0.02, 0.035 }, fat, p + float3 { 0.01, 0.035, 0.0 }))
    for(2 + stage):
        let a = randf(rng) * TAU
        let p = float3 { rcos(a) * 0.2, 0.03, rsin(a) * 0.15 }
        let ex = randf_range(rng, -0.1, 0.1)
        let ez = randf_range(rng, -0.08, 0.08)
        add_child(n, rod(p, p + float3 { ex, 0.01, ez }, 0.015, 0.012, bone))
    return n

def crops(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    add_child(n, box(float3 { 0.98, 0.04, 0.98 }, plain(html("#5e4228")), float3 { 0.0, 0.02, 0.0 }))
    let leaves = [ plain(html("#5e8a2c")), plain(html("#4a7424")), plain(html("#76a038")) ]
    let ear = plain(html("#d8b44a"))
    for(6) row:
        let z = -0.4 + float(row) * 0.16
        add_child(n, blob(float3 { 0.48, 0.025, 0.045 }, plain(html("#6e4e30")), float3 { 0.0, 0.045, z }))
        for(8) k:
            let x = -0.42 + float(k) * 0.12 + randf_range(rng, -0.02, 0.02)
            let base = float3 { x, 0.06, z + randf_range(rng, -0.015, 0.015) }
            let h = randf_range(rng, 0.12, 0.2)
            for(3) l:
                let a = float(l) * TAU / 3.0 + randf(rng)
                add_child(n, blob(float3 { 0.045, 0.014, 0.022 }, leaves[(row + k + l) % 3], base + float3 { rcos(a) * 0.03, h * (0.35 + float(l) * 0.22), rsin(a) * 0.03 }, float3 { 0.0, rad(a), 30.0 }))
            if randf(rng) < 0.55:
                add_child(n, blob(float3 { 0.02, 0.04, 0.02 }, ear, base + float3 { 0.0, h + 0.03, 0.0 }))
        for(3):
            add_child(n, blob(float3 { 0.02, 0.012, 0.018 }, plain(html("#4a3420")), float3 { randf_range(rng, -0.45, 0.45), 0.045, z + 0.08 }))
    return n

def paddy(seed_value:int) -> MNode:
    let rng = grng(seed_value)
    let n = mnode()
    add_child(n, box(float3 { 0.98, 0.02, 0.98 }, plain(html("#3e6e6a")), float3 { 0.0, 0.01, 0.0 }))
    for([ -1.0, 1.0 ]) side:
        add_child(n, blob(float3 { 0.5, 0.03, 0.04 }, plain(html("#5a4630")), float3 { 0.0, 0.02, side * 0.47 }))
    let shoot = plain(html("#7aa83e"))
    for(5) row:
        for(6) k:
            let base = float3 { -0.4 + float(k) * 0.16 + randf_range(rng, -0.03, 0.03), 0.02, -0.38 + float(row) * 0.19 }
            for(3):
                let tx = randf_range(rng, -0.04, 0.04)
                let ty = randf_range(rng, 0.1, 0.16)
                let tz = randf_range(rng, -0.04, 0.04)
                add_child(n, rod(base, base + float3 { tx, ty, tz }, 0.008, 0.004, shoot, false))
    return n
