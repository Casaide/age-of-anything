// ------------------------------------------------------------------ rocks, stone and gold as voxel grids (#410)
// The boulders, the field stones, and the stone and gold deposits with their stages as they're mined, built voxel by
// voxel (view/voxel_grid.lobster) in design units as Dominic's approved mockup (2026-11-10) has them, scaled to their
// size in the world. A stone is an ellipsoid cut by planes into facets, its surface roughened by noise.

let ROCK_GRANITE = [ float3 { 0.20, 0.20, 0.23 }, float3 { 0.31, 0.30, 0.31 }, float3 { 0.43, 0.41, 0.39 }, float3 { 0.56, 0.53, 0.48 },
                     float3 { 0.68, 0.65, 0.58 } ]
let ROCK_LIMESTONE = [ float3 { 0.25, 0.22, 0.20 }, float3 { 0.40, 0.36, 0.31 }, float3 { 0.55, 0.50, 0.43 }, float3 { 0.69, 0.64, 0.55 },
                       float3 { 0.81, 0.76, 0.66 } ]
let ROCK_DARK = [ float3 { 0.17, 0.16, 0.17 }, float3 { 0.27, 0.25, 0.25 }, float3 { 0.38, 0.35, 0.33 }, float3 { 0.49, 0.45, 0.41 },
                  float3 { 0.60, 0.56, 0.50 } ]

let ROCK_UNIT = 0.0105     // world units a design unit: boulders and field stones
let DEPOSIT_UNIT = 0.0125  // stone and gold

// One stone: inside its ellipsoid (rad, its edge's slope `edge`) and below every plane (normal xyz, distance w).
class rstone:
    c:float3
    rad:float3
    edge:float
    planes:[float4]
    cuts:int    // the last of the planes are cuts (fresh stone)
    fresh:bool  // all of it fresh (scree)

def rstone_sdf(s:rstone, p:float3) -> float:
    let q = p - s.c
    var d = (magnitude(q / s.rad) - 1.0) * s.edge
    for(s.planes) f: d = max(d, dot(q, xyz(f)) - f.w)
    return d

// Planes round a stone: count of them, tilted up by lift (the mockup's n.z = |n.z| * up + lift), at about
// near..far of the way out.
def rstone_cut(rng:Pcg, rad:float3, count:int, up:float, lift:float, near:float, far:float) -> [float4]:
    return map(count):
        let g = vg_gauss3(rng)
        let n = normalize(float3 { g.x, g.y, abs(g.z) * up + lift })
        float4 { n.x, n.y, n.z, magnitude(n * rad) * randf_range(rng, near, far) }

// A faceted block the deposits are made of (the mockup's blocks()).
def rstone_block(rng:Pcg, c:float3, rad:float3, planes:int) -> rstone:
    return rstone { c, rad, min(rad.x, min(rad.y, rad.z)), rstone_cut(rng, rad, planes, 1.3, 0.15, 0.7, 0.88), 0, false }

def rock_look(tones:[float3], strata:bool) -> vglook: return vglook { [], [], tones, strata, false, false }

// The stones into the grid, roughened: fresh where they're cut, gold in veins through them (veins).
def rock_fill(g:vgrid, stones:[rstone], veins:bool):
    let coarse = vg_field(g, 6.0, g.seed + 1)
    let fine = vg_field(g, 2.0, g.seed + 2)
    let vein = vg_field(g, 5.0, g.seed + 3)
    let skin = 1.5 / g.k
    for(stones) s:
        let reach = s.rad * 1.1 + float3_1 * 2.0
        vg_solid(g, s.c - reach, s.c + reach) p:
            let q = p * g.k - float(g.lo)
            let d = rstone_sdf(s, p) + (vg_at(coarse, q.x, q.y, q.z) - 0.5) * 0.9 + (vg_at(fine, q.x, q.y, q.z) - 0.5) * 0.45
            var cut = s.fresh
            for(s.cuts) j:
                let f = s.planes[s.planes.length - 1 - j]
                if dot(p - s.c, xyz(f)) - f.w > -skin: cut = true
            if d >= 0.0: 0
            elif veins and (abs(vg_at(vein, q.x, q.y, q.z) - 0.5) < 0.035 or vg_hash(g.seed + 4, int(q.x), int(q.y), int(q.z)) < 0.004): VG_GOLD
            elif cut: VG_CUT
            else: VG_ROCK

// A boulder of granite with a split block leaning on it, a crack through it, pebbles round it.
def boulders(seed_value:int) -> vgrid:
    let rng = grng(seed_value)
    let g = vg_new(rock_look(ROCK_GRANITE, false), float3 { -62.0, -56.0, 0.0 }, float3 { 62.0, 56.0, 58.0 }, vg_k(ROCK_UNIT), seed_value)
    let turn = randf(rng) * TAU
    def spun(x:float, y:float, z:float) -> float3: return float3 { x * rcos(turn) - y * rsin(turn), x * rsin(turn) + y * rcos(turn), z }
    let big = randf_range(rng, 0.85, 1.1)
    let rad = float3 { 30.0, 24.0, 46.0 } * big
    let planes = map(14) i:
        let gs = vg_gauss3(rng)
        let n0 = normalize(float3 { gs.x, gs.y, abs(gs.z) * 1.2 + (if i < 10: 0.2 else: -0.6) })
        let n = spun(n0.x, n0.y, n0.z)
        float4 { n.x, n.y, n.z, magnitude(n0 * rad) * randf_range(rng, 0.78, 0.95) }
    let main = rstone { float3 { 0.0, 0.0, -6.0 }, float3 { 33.0, 26.0, 52.0 } * big, 22.0, planes, 0, false }
    let split = rstone { spun(24.0, 10.0, -2.0), float3 { 13.0, 11.0, 14.0 }, 12.0, rstone_cut(rng, float3_1 * 12.0, 10, 1.0, 0.3, 0.8, 1.0), 0, false }
    let stones = [ main, split ]
    for(randi_range(rng, 2, 4)):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 34.0, 48.0)
        let r = randf_range(rng, 3.0, 5.5)
        stones.push(rstone_block(rng, float3 { rcos(a) * d, rsin(a) * d, -1.0 }, float3 { r * 1.2, r, r * 0.8 }, 6))
    rock_fill(g, stones, false)
    let cn = normalize(spun(0.8, -0.3, 0.25))
    let at = spun(-6.0, 0.0, 0.0)
    vg_empty(g, float(g.lo) / g.k, float(g.lo + g.n) / g.k) p: p.z > 10.0 and abs(dot(p - at, cn)) < 0.9 and magnitude(p - at) < 40.0
    return g

// A few small stones flat in the grass (no shadow of their own: they lie under everything).
def field_stones(seed_value:int) -> vgrid:
    let rng = grng(seed_value)
    let g = vg_new(rock_look(ROCK_GRANITE, false), float3 { -26.0, -26.0, 0.0 }, float3 { 26.0, 26.0, 12.0 }, vg_k(ROCK_UNIT), seed_value)
    let stones = map(randi_range(rng, 2, 4)):
        let r = randf_range(rng, 4.5, 10.0)
        let px = randf_range(rng, -14.0, 14.0)
        let py = randf_range(rng, -14.0, 14.0)
        rstone_block(rng, float3 { px, py, -r * 0.3 }, float3 { r * randf_range(rng, 1.0, 1.5), r, r * 0.6 }, 7)
    rock_fill(g, stones, false)
    return g

// A deposit of warm limestone blocks with bedding lines, or (gold) dark rock with veins and flecks of gold, in its
// stage as it's mined: 0 whole, 1 and 2 cut down with blocks lying by it, 3 only scree.
def deposit(seed_value:int, stage:int, ore:string) -> vgrid:
    let rng = grng(seed_value + (if ore == "gold": 77 else: 0))
    let gold = ore == "gold"
    let g = vg_new(rock_look(if gold: ROCK_DARK else: ROCK_LIMESTONE, not gold), float3 { -52.0, -50.0, 0.0 }, float3 { 52.0, 50.0, 40.0 },
                   vg_k(DEPOSIT_UNIT), seed_value)
    let turn = randf(rng) * TAU
    def spun(x:float, y:float, z:float) -> float3: return float3 { x * rcos(turn) - y * rsin(turn), x * rsin(turn) + y * rcos(turn), z }
    let gold_layout = [ float4 { -6.0, -4.0, -5.0, 0.0 }, float4 { 14.0, 14.0, -2.0, 1.0 } ]
    let stone_layout = [ float4 { -6.0, -3.0, -4.0, 0.0 }, float4 { 18.0, 9.0, -3.0, 1.0 }, float4 { -16.0, 17.0, -2.0, 2.0 }, float4 { 12.0, -17.0, -2.0, 3.0 } ]
    let gold_sizes = [ float3 { 25.0, 21.0, 36.0 }, float3 { 12.0, 11.0, 16.0 } ]
    let stone_sizes = [ float3 { 24.0, 20.0, 34.0 }, float3 { 15.0, 13.0, 22.0 }, float3 { 11.0, 10.0, 15.0 }, float3 { 9.0, 8.0, 11.0 } ]
    let layout = if gold: gold_layout else: stone_layout
    let sizes = if gold: gold_sizes else: stone_sizes
    let keep = [ 1.0, 0.65, 0.35, 0.0 ][stage]
    let stones = []::rstone
    let scree = []::rstone
    for(layout) l, i:
        let s = sizes[i] * randf_range(rng, 0.88, 1.12)
        let c = spun(l.x + vg_gauss(rng) * 2.0, l.y + vg_gauss(rng) * 2.0, l.z)
        let block = rstone_block(rng, c, s, if i == 0: 10 else: 7)
        let stays = randf(rng) < keep
        if i == 0 and stage < 3:
            // the face worked down: a flat cut across its top, lower each stage, and a sheer cut on its near side
            let top = s.z * (1.0 - 0.3 * float(stage)) - 6.0
            if stage > 0:
                block.planes.push(float4 { 0.0, 0.0, 1.0, top })
                let face_n = normalize(spun(0.6, 0.8, 0.0))
                block.planes.push(float4 { face_n.x, face_n.y, face_n.z, s.x * (0.95 - 0.2 * float(stage)) })
            stones.push(block)
        elif stays and i > 0:
            stones.push(block)
    // dressed blocks and scree, more of it each stage
    for(stage * 3 + 2):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 22.0, 42.0)
        let r = randf_range(rng, 2.5, 5.0) + (if stage == 3: 2.0 else: 0.0)
        scree.push(rstone_block(rng, float3 { rcos(a) * d, rsin(a) * d, -r * 0.3 }, float3 { r * 1.3, r, r * 0.8 }, 6))
    if not gold and stage > 0 and stage < 3:
        for(stage) j:
            let c = spun(-26.0 + float(j) * 12.0, 24.0, 4.0)
            let h = float3 { 5.5, 4.0, 4.0 }
            let face = [ float4 { 1.0, 0.0, 0.0, h.x }, float4 { -1.0, 0.0, 0.0, h.x }, float4 { 0.0, 1.0, 0.0, h.y }, float4 { 0.0, -1.0, 0.0, h.y },
                         float4 { 0.0, 0.0, 1.0, h.z }, float4 { 0.0, 0.0, -1.0, h.z } ]
            let planes = map(face) f:
                let n = spun(f.x, f.y, f.z)
                float4 { n.x, n.y, n.z, f.w }
            scree.push(rstone { c, h * 1.6, 4.0, planes, 0, true })
    for(scree) r: r.fresh = true
    rock_fill(g, stones, gold)
    rock_fill(g, scree, gold)
    return g
