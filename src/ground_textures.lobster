// ------------------------------------------------------------------ the ground's textures (#392, D-242)
// Paints the terrain shader's ground textures once, as an atlas of seamless 256 x 256 tiles (GT_COLS a row): each
// texel is an art px, RGB its colour and A its height, which the shader blends terrains on (the higher one shows
// through where two meet). Everything wraps, so a tile repeats without a seam. Writes a TGA for ground_textures.sh to
// turn into data/ground/atlas.png. Run: ./ground_textures.sh (from src/).
import std
import vec

let GT = 256
let GT_COLS = 4
let GT_NAMES = [ "lush", "dry", "dark", "meadow", "dirt", "rock", "sand", "wet", "mud", "earth" ]

// ---- a small rng and periodic value noise (every period divides GT, so a tile wraps)

var gt_seed = 1

def gt_rand() -> float:
    gt_seed = (gt_seed * 1103515245 + 12345) & 0x7FFFFFFF
    return float(gt_seed >> 8) / float(1 << 23)

def gt_range(a:float, b:float) -> float: return a + (b - a) * gt_rand()

def gt_hash(x:int, y:int, s:int) -> float:
    var n = x * 374761393 + y * 668265263 + s * 2246822519
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return float(n & 0xFFFFFF) / float(0xFFFFFF)

// Value noise over cells of `cell` texels, wrapping at GT.
def gt_vnoise(x:float, y:float, cell:int, s:int) -> float:
    let n = GT / cell
    let fx = x / float(cell)
    let fy = y / float(cell)
    let ix = floor(fx)
    let iy = floor(fy)
    var tx = fx - float(ix)
    var ty = fy - float(iy)
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    let x0 = (ix % n + n) % n
    let y0 = (iy % n + n) % n
    let x1 = (x0 + 1) % n
    let y1 = (y0 + 1) % n
    let a = gt_hash(x0, y0, s) + (gt_hash(x1, y0, s) - gt_hash(x0, y0, s)) * tx
    let b = gt_hash(x0, y1, s) + (gt_hash(x1, y1, s) - gt_hash(x0, y1, s)) * tx
    return a + (b - a) * ty

def gt_fbm(x:float, y:float, cell:int, s:int) -> float:
    return gt_vnoise(x, y, cell, s) * 0.5 + gt_vnoise(x, y, max(1, cell / 2), s + 1) * 0.3 + gt_vnoise(x, y, max(1, cell / 4), s + 2) * 0.2

// ---- a tile being painted

class GtTile:
    col:[float3] = map(GT * GT): float3_0
    hgt:[float] = map(GT * GT): 0.0

def gt_at(x:int, y:int) -> int: return ((y % GT + GT) % GT) * GT + (x % GT + GT) % GT

def gt_put(t:GtTile, x:int, y:int, c:float3, h:float):
    let i = gt_at(x, y)
    t.col[i] = c
    t.hgt[i] = h

def gt_hex(s:string) -> float3:
    def nib(k:int) -> float:
        let c = s[k]
        return float(if c >= 'a': c - 'a' + 10 else: c - '0')
    return float3 { nib(1) * 16.0 + nib(2), nib(3) * 16.0 + nib(4), nib(5) * 16.0 + nib(6) } / 255.0

// A ground of two colours mottled by noise at a few scales, low in contrast, and a texel's own speck.
def gt_ground(t:GtTile, a:float3, b:float3, cell:int, speck:float, h0:float, s:int):
    for(GT) y:
        for(GT) x:
            let m = gt_fbm(float(x), float(y), cell, s)
            let k = gt_hash(x, y, s + 9) - 0.5
            t.col[y * GT + x] = lerp(a, b, m) * (1.0 + k * speck)
            t.hgt[y * GT + x] = h0 + (m - 0.5) * 0.2 + k * 0.05

// A blade of grass from its root up, leaning, dark at the root and light at the tip; nearer blades drawn later.
def gt_blade(t:GtTile, x:int, y:int, len:int, lean:float, root:float3, tip:float3, h:float):
    for(len) k:
        let f = float(k) / float(max(1, len - 1))
        gt_put(t, x + int(floor(lean * f * float(len) + 0.5)), y - k, lerp(root, tip, f), h + f * 0.25)

// A clump of grass: blades of one hue fanning out from a middle, its shadow under it, painted far to near.
def gt_clumps(t:GtTile, n:int, rlo:float, rhi:float, greens:[float3], light:float, h:float):
    let mids = map(n): float2 { gt_rand() * float(GT), gt_rand() * float(GT) }
    insertion_sort(mids) p, q: p.y < q.y
    for(mids) m:
        let r = gt_range(rlo, rhi)
        let base = greens[int(gt_rand() * float(greens.length)) % greens.length] * gt_range(0.92, 1.06)
        for(int(r * 2.0)):  // (the shadow, on the ground below it)
            let i = gt_at(int(m.x + gt_range(-r, r)), int(m.y + gt_range(0.0, 1.5)))
            t.col[i] = t.col[i] * 0.8
        let blades = map(int(r * r * 1.4) + 3): float2 { gt_range(-r, r), gt_range(-r * 0.5, r * 0.5) }
        insertion_sort(blades) p, q: p.y < q.y
        for(blades) b:
            let len = 2 + int(gt_rand() * (r * 0.5 + 2.0))
            gt_blade(t, int(m.x + b.x), int(m.y + b.y), len, b.x / r * 0.6 + gt_range(-0.2, 0.2), base * 0.7, base * light * gt_range(0.95, 1.08) + float3 { 0.02, 0.025, 0.0 }, h)

def gt_blades(t:GtTile, n:int, lo:int, hi:int, greens:[float3], light:float, h:float):
    let roots = map(n): int2 { int(gt_rand() * float(GT)), int(gt_rand() * float(GT)) }
    insertion_sort(roots) p, q: p.y < q.y  // (painted far to near)
    for(roots) r:
        let base = greens[int(gt_rand() * float(greens.length)) % greens.length] * gt_range(0.9, 1.08)
        let len = lo + int(gt_rand() * float(hi - lo + 1))
        gt_blade(t, r.x, r.y, len, gt_range(-0.45, 0.45), base * 0.72, base * light + float3 { 0.02, 0.025, 0.0 }, h)

// A pebble lit from the top left, as the units are, with a soft shadow down to the right.
def gt_pebble(t:GtTile, cx:float, cy:float, r:float, c:float3, h:float):
    let ri = int(ceiling(r)) + 1
    var dy = -ri
    while dy <= ri:
        var dx = -ri
        while dx <= ri:
            let px = float(dx) + 0.5
            let py = float(dy) + 0.5
            let d = sqrt(px * px + py * py * 1.6) / r
            let x = int(floor(cx)) + dx
            let y = int(floor(cy)) + dy
            if d < 1.0:
                let lit = clamp(0.6 - (px * 0.6 + py * 0.8) / r * 0.55, 0.0, 1.0)
                gt_put(t, x, y, c * (0.7 + 0.55 * lit), h + (1.0 - d) * 0.2)
            else: if d < 1.35 and px + py > 0.0:
                let i = gt_at(x + 1, y + 1)
                t.col[i] = t.col[i] * 0.85
            dx++
        dy++

def gt_pebbles(t:GtTile, n:int, rlo:float, rhi:float, a:float3, b:float3, h:float):
    for(n): gt_pebble(t, gt_rand() * float(GT), gt_rand() * float(GT), gt_range(rlo, rhi), lerp(a, b, gt_rand()), h)

// A crack: a wandering line, darker, low.
def gt_crack(t:GtTile, x0:float, y0:float, len:int, dark:float):
    var x = x0
    var y = y0
    var a = gt_rand() * 360.0
    for(len):
        let i = gt_at(int(x), int(y))
        t.col[i] = t.col[i] * dark
        t.hgt[i] = t.hgt[i] * 0.6
        a += gt_range(-30.0, 30.0)
        x += cos(a)
        y += sin(a) * 0.7

def gt_flowers(t:GtTile, n:int, cols:[float3]):
    for(n):
        let cx = int(gt_rand() * float(GT))
        let cy = int(gt_rand() * float(GT))
        let c = cols[int(gt_rand() * float(cols.length)) % cols.length]
        for(2 + int(gt_rand() * 4.0)):
            let x = cx + int(gt_range(-4.0, 4.0))
            let y = cy + int(gt_range(-3.0, 3.0))
            gt_put(t, x, y, c, 0.95)
            if gt_rand() > 0.5: gt_put(t, x + 1, y, c * 0.8, 0.9)

// ---- the tiles

let G_LUSH = [ gt_hex("#4f6a2c"), gt_hex("#56752f"), gt_hex("#5f7d33"), gt_hex("#4a6630"), gt_hex("#66823a") ]
let G_DRY = [ gt_hex("#86913f"), gt_hex("#8f8f45"), gt_hex("#9a9650"), gt_hex("#7d863c"), gt_hex("#a39c58") ]
let G_DARK = [ gt_hex("#3e5a2a"), gt_hex("#45612d"), gt_hex("#3a5530"), gt_hex("#4b6531") ]

def gt_lush() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#3f5824"), gt_hex("#526c2e"), 32, 0.06, 0.3, 11)
    gt_clumps(t, 900, 2.5, 5.5, G_LUSH, 1.28, 0.5)
    gt_blades(t, 2500, 2, 3, G_LUSH, 1.2, 0.45)
    return t

def gt_dry() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#76783a"), gt_hex("#8e8a48"), 64, 0.1, 0.35, 21)
    gt_pebbles(t, 40, 0.6, 1.2, gt_hex("#8a7652"), gt_hex("#a08a62"), 0.4)
    gt_clumps(t, 650, 2.0, 4.5, G_DRY, 1.16, 0.5)
    gt_blades(t, 2000, 2, 3, G_DRY, 1.12, 0.45)
    return t

def gt_dark() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#2e4326"), gt_hex("#3e532b"), 32, 0.06, 0.3, 31)
    gt_pebbles(t, 120, 0.6, 1.1, gt_hex("#5a4a30"), gt_hex("#6e5a38"), 0.45)  // (leaf litter)
    gt_clumps(t, 950, 2.5, 6.0, G_DARK, 1.3, 0.5)
    gt_blades(t, 2000, 2, 3, G_DARK, 1.2, 0.45)
    return t

def gt_meadow() -> GtTile:
    let t = gt_lush()
    gt_flowers(t, 260, [ gt_hex("#e8e4cf"), gt_hex("#e3cf63"), gt_hex("#c9a0c8"), gt_hex("#f0eee0") ])
    return t

def gt_dirt() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#7a6142"), gt_hex("#9a7d55"), 64, 0.1, 0.3, 41)
    for(14): gt_crack(t, gt_rand() * float(GT), gt_rand() * float(GT), 8 + int(gt_rand() * 18.0), 0.8)
    gt_pebbles(t, 260, 0.7, 1.8, gt_hex("#857a68"), gt_hex("#ad9f86"), 0.6)
    gt_blades(t, 160, 2, 3, G_DRY, 1.15, 0.45)
    return t

def gt_rock() -> GtTile:
    let t = GtTile {}
    // weathered stone: grey mottled at a few scales, faint facets (a lit and a shaded side where the noise steps), thin
    // fissures, gravel and lichen
    let lo = gt_hex("#6d6a64")
    let hi = gt_hex("#9b968b")
    for(GT) y:
        for(GT) x:
            let m = gt_fbm(float(x), float(y), 64, 51) * 0.6 + gt_fbm(float(x), float(y), 16, 53) * 0.4
            let slope = gt_fbm(float(x) - 1.0, float(y) - 1.0, 16, 53) - gt_fbm(float(x) + 1.0, float(y) + 1.0, 16, 53)
            let c = lerp(lo, hi, 0.25 + 0.55 * m) * (1.0 + clamp(slope * 2.5, -0.07, 0.07)) * (1.0 + (gt_hash(x, y, 52) - 0.5) * 0.07)
            t.col[y * GT + x] = c
            t.hgt[y * GT + x] = 0.5 + m * 0.4
    for(26): gt_crack(t, gt_rand() * float(GT), gt_rand() * float(GT), 12 + int(gt_rand() * 30.0), 0.62)
    gt_pebbles(t, 160, 0.7, 1.6, gt_hex("#76726a"), gt_hex("#aaa598"), 0.9)
    gt_flowers(t, 40, [ gt_hex("#8a9a5a"), gt_hex("#a3a070") ])  // (lichen)
    return t

def gt_sand() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#b8a374"), gt_hex("#cdb98a"), 64, 0.07, 0.4, 61)
    for(GT) y:
        for(GT) x:
            let w = sin((float(x) * 3.0 + float(y) * 6.0) / float(GT) * 360.0 * 2.0 + gt_fbm(float(x), float(y), 32, 62) * 220.0)
            if w > 0.82: t.col[y * GT + x] = t.col[y * GT + x] * 1.05
            else: if w < -0.88: t.col[y * GT + x] = t.col[y * GT + x] * 0.94
    gt_pebbles(t, 50, 0.5, 1.0, gt_hex("#9c8e70"), gt_hex("#e0d6bd"), 0.6)
    return t

def gt_wet() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#76694a"), gt_hex("#8a7b58"), 32, 0.06, 0.25, 71)
    for(GT) y:
        for(GT) x:
            if gt_hash(x, y, 72) > 0.993: gt_put(t, x, y, gt_hex("#b8b49a"), 0.3)
    gt_pebbles(t, 40, 0.5, 1.0, gt_hex("#6a604a"), gt_hex("#8e8268"), 0.4)
    return t

def gt_mud() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#48452b"), gt_hex("#625c38"), 32, 0.1, 0.3, 81)
    for(GT) y:
        for(GT) x:
            if gt_fbm(float(x), float(y), 32, 82) > 0.68:
                let i = y * GT + x
                t.col[i] = lerp(t.col[i], gt_hex("#3d3a2a"), 0.6)
                t.hgt[i] = 0.15
    gt_blades(t, 2200, 2, 5, [ gt_hex("#4f5a2a"), gt_hex("#5c6230"), gt_hex("#46522a") ], 1.3, 0.55)
    return t

def gt_earth() -> GtTile:
    let t = GtTile {}
    gt_ground(t, gt_hex("#8a7150"), gt_hex("#a48a62"), 64, 0.09, 0.32, 91)
    for(40): gt_crack(t, gt_rand() * float(GT), gt_rand() * float(GT), 10 + int(gt_rand() * 20.0), 0.82)
    gt_pebbles(t, 120, 0.6, 1.4, gt_hex("#8e826c"), gt_hex("#b3a58a"), 0.6)
    gt_blades(t, 700, 2, 3, G_DRY, 1.15, 0.45)
    return t

// ---- the atlas, as a TGA (sips makes it a PNG)

def gt_le16(out:[int], v:int):
    out.push(v & 255)
    out.push((v >> 8) & 255)

let tiles = [ gt_lush(), gt_dry(), gt_dark(), gt_meadow(), gt_dirt(), gt_rock(), gt_sand(), gt_wet(), gt_mud(), gt_earth() ]
let aw = GT * GT_COLS
let ah = GT * ((tiles.length + GT_COLS - 1) / GT_COLS)
let out = [ 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 ]
gt_le16(out, aw)
gt_le16(out, ah)
out.push(32)
out.push(8 | 32)  // (8 alpha bits, rows from the top)
for(ah) y:
    for(aw) x:
        let k = (y / GT) * GT_COLS + x / GT
        if k < tiles.length:
            let i = (y % GT) * GT + x % GT
            let c = tiles[k].col[i]
            out.push(clamp(int(c.z * 255.0 + 0.5), 0, 255))
            out.push(clamp(int(c.y * 255.0 + 0.5), 0, 255))
            out.push(clamp(int(c.x * 255.0 + 0.5), 0, 255))
            out.push(clamp(int(tiles[k].hgt[i] * 255.0 + 0.5), 0, 255))
        else:
            for(4): out.push(0)
let path = if command_line_arguments().length: command_line_arguments()[0] else: "ground.tga"
assert write_file(path, vector_to_buffer(out, 1), 0, 1)
print "ground textures: {tiles.length} tiles of {GT}, an atlas of {aw} x {ah}: {path}"
