// ------------------------------------------------------------------ Steading's buildings (#125)
// The `steading` architecture (the Steading mod's culture): one complete set for a medieval working town, each
// building its own model with one clear signature (a windmill's sails, a bakery's oven dome, a furnace, a quarry's
// crane, a mine's spoil), from the concept sheet Dominic picked (2026-11-20). Another culture's set (a desert town)
// is another architecture beside it. Types are the mod's own (school, sawmill, iron_smelter...), not what they
// extend. x right, y up, z to the front (the door); a size-2 building stands in about 1.5 x 1.5.

def st_col(h:string, rough:float = 0.85) -> MMat: return bflat(html(h), rough)

// One of the base set's textured stuffs (bmat_authored: "wood", "stone", "brick", "terracotta"...) in a tint of
// Steading's own, cached by name as bm's are (#156: flat colours read as placeholders beside the base set).
def st_tex(name:string, base:string, tint:string, tile:float = 0.0) -> MMat:
    let have = bld_mat_cache.get(name)
    if have: return have
    let m = bmat_authored(base) or bflat(html(tint))
    m.albedo = html(tint)
    if tile > 0.0: m.uv_scale = float3_1 * f32(1.0 / f32(tile))
    bld_mat_cache.set(name, m)
    return m

def st_shingle() -> MMat: return st_tex("st_shingle", "wood", "#a08a72", 0.35)  // weathered oak shingles
def st_shingle_dark() -> MMat: return st_tex("st_shingle_dark", "wood", "#7e6a56", 0.35)
def st_tile() -> MMat: return bm("terracotta")
def st_timber() -> MMat: return st_tex("st_timber", "wood", "#6a4c34", 0.5)
def st_dark() -> MMat: return st_col("#1a1410", 1.0)
def st_window() -> MMat: return bglow(html("#ffc870"), 1.6)
def st_stone_a() -> MMat: return st_tex("st_stone_a", "stone", "#d8d2c4", 0.6)
def st_stone_b() -> MMat: return st_tex("st_stone_b", "stone", "#b8b0a2", 0.6)
def st_board() -> MMat: return st_tex("st_board", "wood", "#c49a6c", 0.6)
def st_board_dark() -> MMat: return st_tex("st_board_dark", "wood", "#a07a52", 0.6)
def st_log() -> MMat: return st_tex("st_log", "wood", "#b88a5c", 0.45)
def st_rock_a() -> MMat: return st_tex("st_rock_a", "stone", "#9a968c", 0.9)
def st_rock_b() -> MMat: return st_tex("st_rock_b", "stone", "#7e7a72", 0.9)

// A small fixed hash (0..1023) for the irregular bits (block lengths, rocks): models are the same every bake.
def st_hash(i:int) -> int: return ((i * 1103515245 + 12345) >> 9) & 1023
def st_rand(i:int) -> float: return float(st_hash(i)) / 1023.0

// A gabled roof over a w x d box whose walls end at y, its ridge along x, rising `rise`; gable ends in `gable`. Laid
// in courses as the real thing is (#156): shingles staggered piece by piece in two tones, thatch in thick overlapping
// rows under a rounded ridge, tiles as rounded runs down the slope; barge boards up the gables and a ridge cap.
def st_roof(body:MNode, at:float3, w:float, d:float, rise:float, m:MMat, gable:MMat, thick:float = 0.06, eave:float = 0.14):
    let half = d / 2.0 + eave
    let slope = magnitude(float2 { half, rise })
    let ang = atan2(float2 { half, rise })
    let span = w + eave * 2.0
    let thatched = m == bm("thatch")
    let tiled = m == bm("terracotta")
    let rows = max(3, int(slope / (if thatched: 0.16 else: 0.12)))
    let step = slope / float(rows)
    for([ -1.0, 1.0 ]) side:
        let tilt = bv(side * ang, 0.0, 0.0)
        let n = bv(0.0, half, side * rise) / slope  // out of this slope
        add_child(body, bld_roof_tag(bbox(bv(span, thick, slope), if thatched or tiled: m else: st_shingle_dark(), at + bv(0.0, rise / 2.0, side * half / 2.0), tilt)))
        if tiled:
            var x = -span / 2.0 + 0.07
            while x < span / 2.0 - 0.04:
                add_child(body, bld_roof_tag(beam(at + bv(x, 0.0, side * half) + n * (thick * 0.5 + 0.03), at + bv(x, rise, 0.0) + n * (thick * 0.5 + 0.03), 0.045, m, 6)))
                x += 0.15
        else:
            for(rows) k:
                let t = (float(k) + 0.55) / float(rows)
                let c = at + bv(0.0, rise * t, side * half * (1.0 - t)) + n * (thick * 0.5 + (if thatched: 0.035 else: 0.012) + 0.008 * float(k))
                if thatched:
                    add_child(body, bld_roof_tag(bbox(bv(span + 0.04, 0.07, step * 1.5), m, c, tilt)))
                else:
                    let piece = 0.2
                    let pieces = max(1, int(span / piece))
                    let shift = if k % 2 == 1: piece * 0.5 else: 0.0
                    for(pieces + 1) p:
                        let x0 = max(-span / 2.0, -span / 2.0 + float(p) * piece - shift)
                        let x1 = min(span / 2.0, -span / 2.0 + float(p + 1) * piece - shift)
                        if x1 - x0 > 0.04:
                            let tone = if st_hash(k * 31 + p * 7) % 3 == 0: st_shingle_dark() else: st_shingle()
                            add_child(body, bld_roof_tag(bbox(bv(x1 - x0 - 0.014, 0.025, step * 1.3), tone, c + bv((x0 + x1) / 2.0, 0.0, 0.0), tilt)))
        for([ -1.0, 1.0 ]) e:  // the barge boards up the gable's edge
            if not thatched: add_child(body, bld_roof_tag(bbox(bv(0.03, 0.07, slope + 0.02), st_timber(), at + bv(e * (span / 2.0 + 0.015), rise / 2.0, side * half / 2.0) + n * 0.03, tilt)))
    for([ -1.0, 1.0 ]) side:
        let g = add_child(body, slab_tri(float2 { -d / 2.0, 0.0 }, float2 { d / 2.0, 0.0 }, float2 { 0.0, rise }, 0.05, gable))
        g.pos = at + bv(side * w / 2.0, 0.0, 0.0)
        g.rot = bv(0.0, 90.0, 0.0)
    if thatched:
        add_child(body, bld_roof_tag(bcyl(0.1, 0.1, span + 0.06, m, at + bv(0.0, rise + 0.02, 0.0), bv(0.0, 0.0, 90.0), 10)))
    elif tiled:
        add_child(body, bld_roof_tag(beam(at + bv(-span / 2.0, rise + 0.05, 0.0), at + bv(span / 2.0, rise + 0.05, 0.0), 0.06, m, 8)))
    else:
        add_child(body, bld_roof_tag(bbox(bv(span + 0.04, 0.06, 0.12), st_timber(), at + bv(0.0, rise + 0.03, 0.0))))

// Walls w x d x h standing on y0, with timber posts at the corners. Stone is laid in courses of blocks and wood in
// boards on the faces the camera sees (front +z, right +x), on a stone footing (#156: plain boxes read as crates).
def st_walls(body:MNode, w:float, d:float, h:float, m:MMat, y0:float = 0.0, at:float3 = float3_0, posts:bool = true):
    add_child(body, bbox(bv(w, h, d), m, at + bv(0.0, y0 + h / 2.0, 0.0)))
    let stone = m == bm("stone")
    let wood = m == bm("wood")
    if stone or wood:
        let course = if stone: 0.11 else: 0.09
        let rows = max(1, int(h / course))
        let ch = h / float(rows)
        for([ 0, 1 ]) face:  // 0: the front, along x; 1: the right side, along z
            let len = if face == 0: w else: d
            for(rows) r:
                var s = 0.0
                var k = 0
                if stone and r % 2 == 1: s = -0.09
                while s < len:
                    let piece = if stone: 0.16 + 0.14 * st_rand(r * 53 + k * 11 + face * 7) else: len
                    let a = max(0.0, s)
                    let b = min(len, s + piece)
                    if b - a > 0.03:
                        let mid = -len / 2.0 + (a + b) / 2.0
                        let y = y0 + ch * (float(r) + 0.5)
                        let tone = if stone: (if st_hash(r * 17 + k * 5 + face) % 2 == 0: st_stone_a() else: st_stone_b()) else: (if r % 2 == 0: st_board() else: st_board_dark())
                        let gap = if stone: 0.016 else: 0.0
                        if face == 0: add_child(body, bbox(bv(b - a - gap, ch - 0.014, 0.03), tone, at + bv(mid, y, d / 2.0 + 0.005)))
                        else: add_child(body, bbox(bv(0.03, ch - 0.014, b - a - gap), tone, at + bv(w / 2.0 + 0.005, y, mid)))
                    s += piece
                    k++
    if y0 <= 0.0 and not stone:  // a footing of stone under timber or plaster
        add_child(body, bbox(bv(w + 0.06, 0.1, d + 0.06), st_stone_b(), at + bv(0.0, 0.05, 0.0)))
    if posts:
        for([ -1.0, 1.0 ]) x:
            for([ -1.0, 1.0 ]) z: add_child(body, bbox(bv(0.08, h + 0.02, 0.08), st_timber(), at + bv(x * w / 2.0, y0 + h / 2.0, z * d / 2.0)))

// A heap of loose lumps (spoil, coal, ore), r across and h high: rings of small stones, fewer up the pile.
def st_heap(body:MNode, at:float3, r:float, h:float, m:MMat, seed:int):
    let rings = 6
    for(rings) rk:
        let rr = r * (1.0 - float(rk) / float(rings))
        let y = h * float(rk) / float(rings)
        let n = max(1, int(rr * 34.0))
        for(n) i:
            let a = (float(i) + st_rand(seed + rk * 41 + i)) / float(n) * 360.0
            let lump = 0.03 + 0.025 * st_rand(seed + rk * 13 + i * 3)
            add_child(body, bball(lump, m, at + bv(sin(a) * rr * 0.8, y + lump * 0.6, cos(a) * rr * 0.8), bv(1.2, 0.8, 1.0)))
    add_child(body, bball(r * 0.15, m, at + bv(0.0, h, 0.0), bv(1.2, 0.7, 1.0)))

// A rock outcrop w x d, h high at its back: blocks of rock tumbled into a mound, tilted, in two greys.
def st_rocks(body:MNode, at:float3, w:float, d:float, h:float, seed:int):
    let n = 16
    for(n) i:
        let u = st_rand(seed + i * 7) - 0.5
        let v = st_rand(seed + i * 13 + 1)
        let x = u * w
        let z = -v * d
        let hy = h * (0.35 + 0.65 * v) * (1.0 - abs(u) * 1.2)
        let s = 0.22 + 0.22 * st_rand(seed + i * 3 + 2)
        let tone = if i % 3 == 0: st_rock_b() else: st_rock_a()
        add_child(body, bbox(bv(s * 1.4, max(0.1, hy), s), tone, at + bv(x, max(0.1, hy) / 2.0, z), bv(8.0 * (st_rand(seed + i) - 0.5), 60.0 * (st_rand(seed + i * 5) - 0.5), 10.0 * (st_rand(seed + i * 9) - 0.5))))

// Half-timbering on the front (+z) and right (+x) faces of a w x d storey from y0, h high.
def st_frame(body:MNode, w:float, d:float, h:float, y0:float, at:float3 = float3_0):
    let t = st_timber()
    for([ 0.0, 1.0 ]) k: add_child(body, bbox(bv(w + 0.02, 0.05, 0.02), t, at + bv(0.0, y0 + k * h, d / 2.0 + 0.01)))
    for(4) i: add_child(body, bbox(bv(0.05, h, 0.02), t, at + bv(-w / 2.0 + w * (float(i) + 0.5) / 4.0, y0 + h / 2.0, d / 2.0 + 0.01)))
    add_child(body, bbox(bv(0.02, 0.05, d + 0.02), t, at + bv(w / 2.0 + 0.01, y0 + h * 0.5, 0.0)))
    for(3) i: add_child(body, bbox(bv(0.02, h, 0.05), t, at + bv(w / 2.0 + 0.01, y0 + h / 2.0, -d / 2.0 + d * (float(i) + 0.5) / 3.0)))

// A door on the front face at x, its foot at y0; a window lit from inside.
def st_door(body:MNode, x:float, z:float, w:float, h:float, y0:float = 0.0):
    add_child(body, bbox(bv(w, h, 0.03), st_timber(), bv(x, y0 + h / 2.0, z + 0.015)))
    add_child(body, bbox(bv(w - 0.06, h - 0.05, 0.02), st_dark(), bv(x, y0 + (h - 0.05) / 2.0, z + 0.03)))
def st_lit(body:MNode, at:float3, w:float, h:float, side:bool = false) -> float3:
    add_child(body, bbox(if side: bv(0.02, h, w) else: bv(w, h, 0.02), st_window(), at))
    return at

// A team cloth hung over a rail on the front, the side's colour.
def st_cloth(body:MNode, at:float3, team:float3):
    add_child(body, bbox(bv(0.24, 0.16, 0.02), bcloth(team), at))

def st_chimney(body:MNode, at:float3, h:float, m:MMat) -> float3:
    add_child(body, bbox(bv(0.16, h, 0.16), m, at + bv(0.0, h / 2.0, 0.0)))
    return at + bv(0.0, h + 0.05, 0.0)

def st_done(body:MNode, team:float3, door:float3, dw:float, dh:float) -> BSpec:
    return bdoorway(bteam(bspec(body), team), bld_doorway(door, dw, dh))

// The storehouse: a long timber barn under shingles, wide double doors, a hoist beam, crates, barrels and sacks.
def steading_storehouse(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    add_child(body, bbox(bv(2.5, 0.08, 1.8), bm("stone"), bv(0.0, 0.04, -0.2)))
    st_walls(body, 2.3, 1.6, 1.0, wood, 0.08, bv(0.0, 0.0, -0.2))
    for(6) i: add_child(body, bbox(bv(2.32, 0.02, 0.02), st_timber(), bv(0.0, 0.2 + float(i) * 0.15, 0.61)))
    st_roof(body, bv(0.0, 1.08, -0.2), 2.3, 1.6, 0.7, st_shingle(), wood)
    st_door(body, 0.0, 0.6, 0.7, 0.75, 0.08)
    add_child(body, bbox(bv(0.04, 0.75, 0.04), st_timber(), bv(0.0, 0.46, 0.65)))
    add_child(body, bbox(bv(0.08, 0.08, 0.5), st_timber(), bv(0.0, 1.55, 0.75)))  // the hoist beam out of the gable
    add_child(body, beam(bv(0.0, 1.5, 0.98), bv(0.0, 1.0, 0.98), 0.01, bm("weave"), 4))
    let crate = st_board_dark()
    for([ bv(0.95, 0.12, 0.85), bv(1.2, 0.12, 0.6), bv(1.05, 0.35, 0.72) ]) p: add_child(body, bbox(bv(0.24, 0.24, 0.24), crate, p))
    for([ bv(-1.0, 0.0, 0.8), bv(-0.78, 0.0, 0.9) ]) p: barrel(p, body)
    let sack = st_col("#d8c8a0", 1.0)
    for([ bv(-0.5, 0.1, 0.92), bv(-0.35, 0.1, 0.98) ]) p: add_child(body, bball(0.11, sack, p, bv(1.0, 1.2, 0.9)))
    st_cloth(body, bv(-0.6, 0.85, 0.62), team)
    let sp = st_done(body, team, bv(0.0, 0.08, 0.62), 0.6, 0.7)
    blights(sp, [ st_lit(body, bv(0.75, 0.6, 0.61), 0.18, 0.16) ])
    return sp

// The school: a stone ground floor, a half-timbered storey, a tiled roof and a bell in a little cupola.
def steading_school(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.5, 1.1, 0.55, bm("stone"), 0.0, float3_0, false)
    st_walls(body, 1.56, 1.16, 0.5, bm("plaster"), 0.55, float3_0, false)
    st_frame(body, 1.56, 1.16, 0.5, 0.55)
    st_roof(body, bv(0.0, 1.05, 0.0), 1.56, 1.16, 0.55, st_tile(), bm("plaster"))
    add_child(body, bbox(bv(0.24, 0.3, 0.24), bm("plaster"), bv(0.0, 1.62, 0.0)))  // the cupola and its bell
    add_child(body, bball(0.07, bflat(html("#c8a040"), 0.3, 0.8), bv(0.0, 1.6, 0.0)))
    st_roof(body, bv(0.0, 1.77, 0.0), 0.24, 0.24, 0.16, st_tile(), bm("plaster"), 0.04, 0.05)
    st_door(body, -0.3, 0.55, 0.28, 0.42)
    let lights = [ st_lit(body, bv(0.3, 0.28, 0.56), 0.18, 0.18), st_lit(body, bv(0.3, 0.8, 0.59), 0.16, 0.16), st_lit(body, bv(-0.3, 0.8, 0.59), 0.16, 0.16) ]
    st_cloth(body, bv(0.0, 0.48, 0.57), team)
    let sp = st_done(body, team, bv(-0.3, 0.0, 0.56), 0.26, 0.4)
    blights(sp, lights)
    return sp

// The woodcutter's hut: a log cabin, its logs crossing at the corners, under shingles; a log pile with cut ends, a
// sawhorse, and a chopping block with an axe in it (#156).
def steading_woodcutter(team:float3) -> BSpec:
    let body = mnode()
    let log = st_log()
    let end = st_col("#d8b07a")
    add_child(body, bbox(bv(1.06, 0.1, 0.96), st_stone_b(), bv(0.0, 0.05, -0.05)))
    for(6) i:
        let y = 0.16 + float(i) * 0.11
        let o = if i % 2 == 0: 0.0 else: 0.03
        add_child(body, bcyl(0.06, 0.06, 1.14 + o, log, bv(0.0, y, 0.38), bv(0.0, 0.0, 90.0), 8))
        add_child(body, bcyl(0.06, 0.06, 0.98 - o, log, bv(0.5, y + 0.055, -0.05), bv(90.0, 0.0, 0.0), 8))
        for([ -1.0, 1.0 ]) e: add_child(body, bcyl(0.05, 0.05, 0.01, end, bv(e * (0.575 + o * 0.5), y, 0.38), bv(0.0, 0.0, 90.0), 8))
    add_child(body, bbox(bv(0.96, 0.7, 0.8), st_timber(), bv(0.0, 0.45, -0.05)))
    st_roof(body, bv(0.0, 0.8, -0.05), 1.0, 0.9, 0.42, st_shingle(), log)
    st_door(body, -0.15, 0.44, 0.22, 0.42, 0.1)
    st_lit(body, bv(0.25, 0.45, 0.44), 0.14, 0.12)
    for(3) row:
        for(3 - row) i:
            let z = 0.1 + float(i) * 0.15 + float(row) * 0.075
            add_child(body, bcyl(0.07, 0.07, 0.6, log, bv(0.98, 0.07 + float(row) * 0.12, z - 0.3), bv(90.0, 0.0, 0.0), 8))
            add_child(body, bcyl(0.06, 0.06, 0.01, end, bv(0.98, 0.07 + float(row) * 0.12, z), bv(90.0, 0.0, 0.0), 8))
    for([ -0.1, 0.1 ]) x:  // the sawhorse, a log across it
        add_child(body, beam(bv(-0.75 + x, 0.0, 0.55), bv(-0.75, 0.25, 0.65), 0.018, st_timber(), 4))
        add_child(body, beam(bv(-0.75 + x, 0.0, 0.75), bv(-0.75, 0.25, 0.65), 0.018, st_timber(), 4))
    add_child(body, bcyl(0.055, 0.055, 0.5, log, bv(-0.75, 0.3, 0.65), bv(0.0, 0.0, 90.0), 8))
    add_child(body, bcyl(0.12, 0.13, 0.16, log, bv(0.45, 0.08, 0.7), float3_0, 10))  // the block, an axe in it
    add_child(body, bcyl(0.11, 0.11, 0.01, end, bv(0.45, 0.165, 0.7), float3_0, 10))
    add_child(body, beam(bv(0.47, 0.16, 0.7), bv(0.55, 0.42, 0.74), 0.015, st_timber(), 4))
    add_child(body, bbox(bv(0.1, 0.06, 0.02), bflat(html("#8a8e94"), 0.35, 0.8), bv(0.47, 0.17, 0.7), bv(0.0, 0.0, -20.0)))
    st_cloth(body, bv(0.3, 0.68, 0.45), team)
    return st_done(body, team, bv(-0.15, 0.1, 0.45), 0.2, 0.38)

// The quarry: the cut face stepped into a rock outcrop behind, a lean shed, shear-legs lifting a block, and dressed
// blocks stacked with their bevelled edges (#156).
def steading_quarry(team:float3) -> BSpec:
    let body = mnode()
    st_rocks(body, bv(0.0, 0.0, -0.45), 1.8, 0.7, 0.9, 51)
    for(3) k:  // the cut benches, square and pale where the blocks came out
        add_child(body, bbox(bv(0.9 - float(k) * 0.2, 0.22, 0.24), st_stone_a(), bv(0.25, 0.11 + float(k) * 0.22, -0.3 - float(k) * 0.16)))
    st_walls(body, 0.6, 0.5, 0.45, bm("wood"), 0.0, bv(-0.45, 0.0, 0.05))
    st_roof(body, bv(-0.45, 0.45, 0.05), 0.6, 0.5, 0.25, st_shingle(), bm("wood"))
    for([ bv(0.2, 0.1, 0.55), bv(0.45, 0.1, 0.55), bv(0.32, 0.3, 0.55), bv(0.75, 0.1, 0.45) ]) p:
        let m = if p.x > 0.4: st_stone_b() else: st_stone_a()
        add_child(body, bbox(bv(0.22, 0.17, 0.18), m, p))
        add_child(body, bbox(bv(0.18, 0.02, 0.14), m, p + bv(0.0, 0.095, 0.0)))  // the dressed bevel
    let top = bv(0.45, 1.1, 0.05)
    for([ bv(0.15, 0.0, -0.2), bv(0.75, 0.0, -0.2), bv(0.45, 0.0, 0.35) ]) f: add_child(body, beam(f, top, 0.028, st_timber(), 5))
    add_child(body, beam(top, bv(0.45, 0.42, 0.05), 0.008, bm("weave"), 4))
    add_child(body, bbox(bv(0.22, 0.18, 0.18), st_stone_a(), bv(0.45, 0.32, 0.05)))
    for([ bv(0.95, 0.03, 0.2), bv(1.0, 0.03, 0.05), bv(0.9, 0.03, -0.05) ]) p: add_child(body, bbox(bv(0.06, 0.05, 0.05), st_stone_b(), p, bv(0.0, 30.0 * p.z, 0.0)))  // chips
    st_cloth(body, bv(-0.45, 0.3, 0.31), team)
    return st_done(body, team, bv(-0.45, 0.0, 0.3), 0.2, 0.36)

// The sawmill: an open shed on posts, a log on the saw trestle with the blade down through it, planks stacked.
def steading_sawmill(team:float3) -> BSpec:
    let body = mnode()
    for([ -0.6, 0.6 ]) x:
        for([ -0.45, 0.45 ]) z: add_child(body, bbox(bv(0.08, 0.75, 0.08), st_timber(), bv(x - 0.15, 0.375, z)))
    st_roof(body, bv(-0.15, 0.75, 0.0), 1.3, 1.0, 0.4, st_shingle(), bm("wood"))
    add_child(body, bbox(bv(1.0, 0.3, 0.3), st_board_dark(), bv(-0.15, 0.15, 0.0)))  // the trestle
    add_child(body, bcyl(0.1, 0.1, 1.1, st_log(), bv(-0.15, 0.4, 0.0), bv(0.0, 0.0, 90.0), 10))
    add_child(body, bbox(bv(0.02, 0.6, 0.18), bflat(html("#c8ccd0"), 0.3, 0.8), bv(-0.1, 0.45, 0.0)))  // the blade in its frame
    add_child(body, bbox(bv(0.04, 0.04, 0.3), st_timber(), bv(-0.1, 0.75, 0.0)))
    for(4) k:  // planks stacked on bearers
        for(3) p: add_child(body, bbox(bv(0.12, 0.045, 0.9), if (k + p) % 2 == 0: st_board() else: st_board_dark(), bv(0.59 + float(p) * 0.13, 0.05 + float(k) * 0.05, 0.1)))
    st_cloth(body, bv(-0.15, 0.68, 0.46), team)
    return st_done(body, team, bv(-0.15, 0.0, 0.5), 0.5, 0.5)

// The farm: a thatched farmhouse at the back, plastered between its timbers, and a hay rick.
def steading_farm(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.5, 0.9, 0.55, bm("plaster"), 0.0, bv(-0.3, 0.0, -0.6))
    st_frame(body, 1.5, 0.9, 0.55, 0.0, bv(-0.3, 0.0, -0.6))
    st_roof(body, bv(-0.3, 0.55, -0.6), 1.5, 0.9, 0.6, bm("thatch"), bm("plaster"), 0.16, 0.2)
    st_door(body, -0.4, -0.15, 0.24, 0.4)
    let hay = bm("thatch")
    add_child(body, bcyl(0.3, 0.36, 0.4, hay, bv(0.9, 0.2, -0.5), float3_0, 12))
    add_child(body, bdome(0.32, bm("thatch"), bv(0.9, 0.4, -0.5), bv(1.0, 0.8, 1.0)))
    for(5) i: add_child(body, bbox(bv(0.05, 0.12, 0.05), st_timber(), bv(-1.1 + float(i) * 0.55, 0.06, 0.15)))  // the yard's low rail
    add_child(body, bbox(bv(2.2, 0.03, 0.03), st_timber(), bv(0.0, 0.1, 0.15)))
    st_cloth(body, bv(0.1, 0.45, -0.14), team)
    let sp = st_done(body, team, bv(-0.4, 0.0, -0.14), 0.22, 0.38)
    blights(sp, [ st_lit(body, bv(0.1, 0.3, -0.14), 0.14, 0.12) ])
    return sp

// The vineyard: the winegrower's house, low plaster under a tiled roof, with the press in its yard (a vat under a
// screw beam) and casks of wine stacked by the wall (#122).
def steading_vineyard(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.2, 0.9, 0.55, bm("plaster"), 0.0, bv(-0.45, 0.0, -0.55))
    st_frame(body, 1.2, 0.9, 0.55, 0.0, bv(-0.45, 0.0, -0.55))
    st_roof(body, bv(-0.45, 0.55, -0.55), 1.2, 0.9, 0.45, st_tile(), bm("plaster"), 0.06, 0.16)
    st_door(body, -0.5, -0.1, 0.24, 0.4)
    let oak = st_col("#7a4e2a")
    let hoop = st_col("#3a3a3c", 0.6)
    add_child(body, bcyl(0.32, 0.32, 0.28, oak, bv(0.75, 0.14, 0.2), float3_0, 14))  // the press: its vat
    add_child(body, bcyl(0.33, 0.33, 0.04, hoop, bv(0.75, 0.2, 0.2), float3_0, 14))
    add_child(body, bcyl(0.27, 0.27, 0.02, st_col("#5a2e6e", 1.0), bv(0.75, 0.28, 0.2), float3_0, 14))  // grapes in it
    for([ -0.3, 0.3 ]) x: add_child(body, bbox(bv(0.06, 0.75, 0.06), st_timber(), bv(0.75 + x, 0.37, 0.2)))
    add_child(body, bbox(bv(0.72, 0.08, 0.08), st_timber(), bv(0.75, 0.72, 0.2)))  // its beam and screw
    add_child(body, bcyl(0.035, 0.035, 0.42, st_dark(), bv(0.75, 0.48, 0.2), float3_0, 6))
    for([ bv(0.55, 0.14, -0.55), bv(0.9, 0.14, -0.55), bv(0.72, 0.4, -0.55) ]) at:  // casks by the wall, on their sides
        add_child(body, bcyl(0.14, 0.14, 0.32, oak, at, bv(0.0, 0.0, 90.0), 10))
        add_child(body, bcyl(0.15, 0.15, 0.03, hoop, at, bv(0.0, 0.0, 90.0), 10))
    st_cloth(body, bv(-0.15, 0.45, -0.09), team)
    let sp = st_done(body, team, bv(-0.5, 0.0, -0.09), 0.22, 0.38)
    blights(sp, [ st_lit(body, bv(-0.85, 0.3, -0.09), 0.14, 0.12) ])
    return sp

// The mill: a post windmill: a trestle under a weatherboarded body, a pitched roof, and four sails on the front
// (to turn as the mill works, next).
def steading_mill(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    for([ bv(-0.5, 0.0, -0.5), bv(0.5, 0.0, -0.5), bv(-0.5, 0.0, 0.5), bv(0.5, 0.0, 0.5) ]) f: add_child(body, beam(f, bv(0.0, 0.55, 0.0), 0.035, st_timber(), 5))
    add_child(body, bcyl(0.08, 0.1, 0.8, st_timber(), bv(0.0, 0.4, 0.0), float3_0, 8))
    st_walls(body, 0.7, 0.9, 0.8, bm("wood"), 0.75, float3_0, false)
    // the piers
    for([ bv(-0.5, 0.0, -0.5), bv(0.5, 0.0, -0.5), bv(-0.5, 0.0, 0.5), bv(0.5, 0.0, 0.5) ]) f: add_child(body, bbox(bv(0.16, 0.12, 0.16), st_stone_b(), f + bv(0.0, 0.06, 0.0)))
    // the tail pole, and the ladder up to the door
    add_child(body, bbox(bv(0.04, 0.04, 0.8), st_timber(), bv(0.0, 0.62, -0.75), bv(-40.0, 0.0, 0.0)))
    for([ -0.12, 0.12 ]) x: add_child(body, beam(bv(x, 0.0, -1.0), bv(x, 0.75, -0.48), 0.018, st_timber(), 4))
    for(6) i: add_child(body, bbox(bv(0.24, 0.02, 0.02), st_timber(), bv(0.0, 0.1 + float(i) * 0.11, -0.93 + float(i) * 0.075)))
    let r = mnode()
    r.rot = bv(0.0, 90.0, 0.0)
    add_child(body, r)
    st_roof(r, bv(0.0, 1.55, 0.0), 0.9, 0.7, 0.4, st_shingle(), wood, 0.06, 0.08)
    st_door(body, 0.0, -0.45, 0.2, 0.32, 0.75)  // (the door at the back, up the ladder)
    let hub = bv(0.0, 1.35, 0.5)
    add_child(body, bcyl(0.06, 0.06, 0.2, st_timber(), hub - bv(0.0, 0.0, 0.08), bv(90.0, 0.0, 0.0), 8))
    let sails = mnode()
    let cloth = st_col("#efe8d8", 1.0)
    for(4) k:
        let arm = mnode()
        arm.pos = hub + bv(0.0, 0.0, 0.04)
        arm.rot = bv(0.0, 0.0, 20.0 + float(k) * 90.0 + bld_turn)
        add_child(sails, arm)
        add_child(arm, bbox(bv(0.05, 1.15, 0.04), st_timber(), bv(0.0, 0.6, 0.0)))
        add_child(arm, bbox(bv(0.24, 0.85, 0.015), cloth, bv(0.14, 0.72, 0.02)))
        for(4) j: add_child(arm, bbox(bv(0.26, 0.02, 0.03), st_timber(), bv(0.13, 0.35 + float(j) * 0.25, 0.03)))
    st_cloth(body, bv(0.0, 0.9, 0.46), team)
    let s = st_done(body, team, bv(0.0, 0.0, 0.5), 0.3, 0.4)
    s.turn = sails  // (they turn in the wind: its own part, baked through a quarter turn in steps)
    return s

// The bakery: a brick house under tiles, its bread oven a dome beside it, smoke from the chimney, a rack of loaves.
def steading_bakery(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.0, 0.9, 0.6, bm("brick"), 0.0, bv(-0.25, 0.0, -0.1), false)
    st_roof(body, bv(-0.25, 0.6, -0.1), 1.0, 0.9, 0.42, st_tile(), bm("brick"))
    st_door(body, -0.4, 0.35, 0.24, 0.42)
    add_child(body, bcyl(0.36, 0.38, 0.22, st_stone_a(), bv(0.55, 0.11, -0.1), float3_0, 14))  // the oven
    add_child(body, bdome(0.36, st_stone_a(), bv(0.55, 0.22, -0.1), bv(1.0, 0.8, 1.0)))
    add_child(body, bbox(bv(0.14, 0.12, 0.04), bglow(html("#ff8a30"), 2.2), bv(0.55, 0.13, 0.27)))
    let smoke = st_chimney(body, bv(-0.55, 0.6, -0.3), 0.55, bm("brick"))
    add_child(body, bbox(bv(0.5, 0.25, 0.18), bm("wood"), bv(0.0, 0.12, 0.6)))
    for(3) i: add_child(body, bball(0.07, st_col("#c07a3a"), bv(-0.15 + float(i) * 0.15, 0.27, 0.6), bv(1.2, 0.7, 1.0)))
    st_cloth(body, bv(-0.05, 0.48, 0.36), team)
    let sp = st_done(body, team, bv(-0.4, 0.0, 0.36), 0.22, 0.4)
    blights(sp, [ st_lit(body, bv(-0.05, 0.3, 0.36), 0.14, 0.12) ])
    return bpt(sp, "smoke", smoke)

// The inn: two storeys, stone below and timbered plaster above, a thatched roof, a hanging sign, benches outside.
def steading_inn(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.4, 1.0, 0.5, bm("stone"), 0.0, bv(0.0, 0.0, -0.15), false)
    st_walls(body, 1.5, 1.1, 0.5, bm("plaster"), 0.5, bv(0.0, 0.0, -0.15), false)
    st_frame(body, 1.5, 1.1, 0.5, 0.5, bv(0.0, 0.0, -0.15))
    st_roof(body, bv(0.0, 1.0, -0.15), 1.5, 1.1, 0.6, bm("thatch"), bm("plaster"), 0.16, 0.2)
    let smoke = st_chimney(body, bv(0.5, 1.0, -0.4), 0.55, bm("stone"))
    st_door(body, -0.15, 0.35, 0.26, 0.42)
    add_child(body, bbox(bv(0.4, 0.04, 0.04), st_timber(), bv(0.72, 0.85, 0.42), bv(0.0, 90.0, 0.0)))  // the sign on its bracket
    add_child(body, bbox(bv(0.02, 0.2, 0.26), st_col("#c8a040", 0.5), bv(0.72, 0.7, 0.55)))
    add_child(body, bbox(bv(0.7, 0.05, 0.22), bm("wood"), bv(0.0, 0.22, 0.72)))  // a table between benches
    for([ 0.56, 0.88 ]) z: add_child(body, bbox(bv(0.7, 0.04, 0.1), bm("wood"), bv(0.0, 0.13, z)))
    st_cloth(body, bv(0.35, 0.42, 0.36), team)
    let lights = [ st_lit(body, bv(0.4, 0.25, 0.36), 0.16, 0.14), st_lit(body, bv(-0.4, 0.75, 0.41), 0.16, 0.14), st_lit(body, bv(0.35, 0.75, 0.41), 0.16, 0.14) ]
    let sp = st_done(body, team, bv(-0.15, 0.0, 0.36), 0.24, 0.4)
    blights(sp, lights)
    return bpt(sp, "smoke", smoke)

// The pig farm: a low thatched sty, a muddy yard fenced round, a trough, and pigs.
def steading_pig_farm(team:float3) -> BSpec:
    let body = mnode()
    add_child(body, bbox(bv(2.4, 0.02, 2.2), st_col("#6e5638", 1.0), bv(0.0, 0.01, 0.0)))
    st_walls(body, 1.1, 0.7, 0.35, bm("wood"), 0.0, bv(-0.55, 0.0, -0.65))
    st_roof(body, bv(-0.55, 0.35, -0.65), 1.1, 0.7, 0.35, bm("thatch"), bm("wood"), 0.14, 0.15)
    for(9) i:
        let t = -1.15 + float(i) * 0.2875
        add_child(body, bbox(bv(0.05, 0.3, 0.05), st_timber(), bv(t, 0.15, 1.05)))
        add_child(body, bbox(bv(0.05, 0.3, 0.05), st_timber(), bv(1.15, 0.15, t)))
    for([ 0.12, 0.24 ]) y:
        add_child(body, bbox(bv(2.3, 0.03, 0.03), st_timber(), bv(0.0, y, 1.05)))
        add_child(body, bbox(bv(0.03, 0.03, 2.3), st_timber(), bv(1.15, y, 0.0)))
    add_child(body, bbox(bv(0.5, 0.1, 0.16), bm("wood"), bv(-0.4, 0.05, 0.1)))
    let pig = st_col("#e3a3a0", 0.8)
    for([ bv(0.2, 0.0, 0.3), bv(0.6, 0.0, -0.2), bv(0.55, 0.0, 0.6) ]) p:
        add_child(body, bball(0.16, pig, p + bv(0.0, 0.15, 0.0), bv(1.6, 1.0, 1.0)))
        add_child(body, bball(0.09, pig, p + bv(0.28, 0.18, 0.0)))
    st_cloth(body, bv(-0.55, 0.25, -0.29), team)
    return st_done(body, team, bv(-0.55, 0.0, -0.29), 0.24, 0.3)

// The butcher's: a plastered shop, an open counter under a striped awning, sausages and hams hanging.
def steading_butcher(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.2, 0.9, 0.7, bm("plaster"), 0.0, bv(0.0, 0.0, -0.1))
    st_roof(body, bv(0.0, 0.7, -0.1), 1.2, 0.9, 0.42, st_tile(), bm("plaster"))
    add_child(body, bbox(bv(0.6, 0.3, 0.03), st_dark(), bv(-0.2, 0.45, 0.36)))  // the open shop front
    add_child(body, bbox(bv(0.66, 0.24, 0.2), bm("wood"), bv(-0.2, 0.12, 0.45)))
    for(6) i: add_child(body, bbox(bv(0.12, 0.03, 0.34), st_col(if i % 2 == 0: "#b03a30" else: "#efe8e0"), bv(-0.5 + float(i) * 0.12, 0.66, 0.5), bv(-15.0, 0.0, 0.0)))
    for(4) i: add_child(body, bcyl(0.035, 0.035, 0.16, st_col("#97452f"), bv(-0.4 + float(i) * 0.13, 0.52, 0.42), float3_0, 6))
    st_door(body, 0.35, 0.35, 0.22, 0.42)
    st_cloth(body, bv(0.35, 0.55, 0.36), team)
    return st_done(body, team, bv(0.35, 0.0, 0.36), 0.2, 0.4)

// A mine: a timbered adit into a rocky hillside, a little roof over its mouth, rails out to a cart, and its spoil
// heaped in lumps (coal, iron or gold by its colour; #156: no domes).
def steading_mine(kind:string, team:float3) -> BSpec:
    let body = mnode()
    st_rocks(body, bv(-0.1, 0.0, -0.1), 1.9, 1.1, 1.0, if kind == "coal": 11 elif kind == "iron": 23 else: 37)
    add_child(body, bbox(bv(1.6, 0.5, 0.7), st_rock_b(), bv(-0.1, 0.25, -0.55)))  // the hill's core behind the rocks
    // the adit's mouth
    add_child(body, bbox(bv(0.44, 0.52, 0.3), st_dark(), bv(-0.1, 0.26, 0.24)))
    for([ -0.29, 0.09 ]) x:
        add_child(body, bbox(bv(0.08, 0.58, 0.08), st_timber(), bv(x, 0.29, 0.4)))
        add_child(body, beam(bv(x, 0.0, 0.52), bv(x, 0.3, 0.42), 0.025, st_timber(), 5))  // a strut
    add_child(body, bbox(bv(0.52, 0.08, 0.1), st_timber(), bv(-0.1, 0.6, 0.4)))
    st_roof(body, bv(-0.1, 0.64, 0.36), 0.56, 0.36, 0.2, st_shingle(), st_timber(), 0.04, 0.06)
    for([ -0.19, -0.01 ]) x: add_child(body, bbox(bv(0.02, 0.025, 0.7), bflat(html("#4a4a4e"), 0.4, 0.8), bv(x, 0.04, 0.72)))
    for(5) i: add_child(body, bbox(bv(0.3, 0.025, 0.05), st_board_dark(), bv(-0.1, 0.015, 0.44 + float(i) * 0.14)))
    let cart = bv(-0.1, 0.0, 0.86)  // the mine cart on the rails, heaped with what it brought out
    add_child(body, bbox(bv(0.28, 0.16, 0.22), st_board(), cart + bv(0.0, 0.14, 0.0)))
    for([ -0.08, 0.08 ]) z:
        for([ -0.15, 0.15 ]) x: add_child(body, bcyl(0.05, 0.05, 0.02, bflat(html("#3a3a3c"), 0.5, 0.8), cart + bv(x, 0.05, z), bv(0.0, 0.0, 90.0), 8))
    let spoil = if kind == "coal": st_col("#2a282c", 0.9) elif kind == "iron": st_col("#8a5a44", 0.9) else: st_col("#9a9284", 0.9)
    for(4) i: add_child(body, bball(0.045, spoil, cart + bv(-0.08 + float(i) * 0.055, 0.24, 0.02 * float(i % 2)), bv(1.2, 0.8, 1.0)))
    st_heap(body, bv(0.55, 0.0, 0.45), 0.34, 0.26, spoil, 3)
    if kind == "coal": st_heap(body, bv(0.65, 0.0, -0.05), 0.26, 0.2, spoil, 9)
    if kind == "iron":  // the ore sorter's shed
        st_walls(body, 0.4, 0.35, 0.32, bm("wood"), 0.0, bv(0.6, 0.0, -0.2))
        st_roof(body, bv(0.6, 0.32, -0.2), 0.4, 0.35, 0.18, st_shingle(), bm("wood"), 0.05, 0.06)
    if kind == "gold":  // a headframe and its wheel over a shaft, glints in the spoil
        let top = bv(0.6, 1.05, -0.2)
        for([ bv(0.38, 0.0, -0.38), bv(0.82, 0.0, -0.38), bv(0.6, 0.0, 0.02) ]) f: add_child(body, beam(f, top, 0.03, st_timber(), 5))
        add_child(body, bring(0.12, 0.16, st_timber(), top, bv(90.0, 0.0, 0.0)))
        for([ bv(0.5, 0.2, 0.55), bv(0.62, 0.17, 0.4), bv(0.45, 0.12, 0.35) ]) p: add_child(body, bball(0.03, bflat(html("#f0cc40"), 0.3, 0.8), p))
    st_cloth(body, bv(-0.1, 0.5, 0.45), team)
    return st_done(body, team, bv(-0.1, 0.0, 0.4), 0.3, 0.45)

// The iron smelter: a tall stone bloomery furnace, its mouth aglow, a bellows shed behind, charcoal and ore heaped.
def steading_iron_smelter(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 0.7, 0.6, 0.45, bm("wood"), 0.0, bv(-0.45, 0.0, -0.4))
    st_roof(body, bv(-0.45, 0.45, -0.4), 0.7, 0.6, 0.28, st_shingle(), bm("wood"))
    add_child(body, bcyl(0.24, 0.42, 1.2, st_stone_b(), bv(0.3, 0.6, 0.0), float3_0, 12))  // the furnace, banded
    for(3) k: add_child(body, bcyl(0.43 - float(k) * 0.07, 0.43 - float(k) * 0.07, 0.04, bflat(html("#3a3a3c"), 0.5, 0.8), bv(0.3, 0.15 + float(k) * 0.4, 0.0), float3_0, 12))
    add_child(body, bring(0.16, 0.25, st_rock_b(), bv(0.3, 1.2, 0.0)))
    add_child(body, bball(0.14, bglow(html("#ff7a20"), 3.0), bv(0.3, 0.2, 0.36), bv(1.0, 1.2, 0.4)))
    add_child(body, beam(bv(-0.1, 0.25, -0.2), bv(0.15, 0.25, -0.05), 0.04, bm("felt"), 6))  // the bellows' pipe
    st_heap(body, bv(-0.5, 0.0, 0.45), 0.26, 0.18, st_col("#2a282c", 0.9), 5)
    st_heap(body, bv(0.75, 0.0, 0.5), 0.2, 0.14, st_col("#8a5a44", 0.9), 7)
    st_cloth(body, bv(-0.45, 0.3, -0.09), team)
    let sp = st_done(body, team, bv(-0.45, 0.0, -0.09), 0.22, 0.36)
    blights(sp, [ bv(0.3, 0.2, 0.42) ])
    return bpt(sp, "smoke", bv(0.3, 1.25, 0.0))

// The gold smelter: a stone house with a tall chimney, a small furnace with a glowing crucible, a gilt sign.
def steading_gold_smelter(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 1.1, 0.9, 0.6, bm("stone"), 0.0, bv(-0.2, 0.0, -0.15), false)
    st_roof(body, bv(-0.2, 0.6, -0.15), 1.1, 0.9, 0.36, st_tile(), bm("stone"))
    let smoke = st_chimney(body, bv(0.2, 0.6, -0.4), 0.7, bm("stone"))
    st_door(body, -0.4, 0.3, 0.24, 0.42)
    add_child(body, bbox(bv(0.36, 0.3, 0.36), st_stone_b(), bv(0.6, 0.15, 0.45)))
    add_child(body, bcyl(0.08, 0.06, 0.08, bglow(html("#ffc030"), 3.0), bv(0.6, 0.34, 0.45), float3_0, 10))
    add_child(body, bbox(bv(0.4, 0.12, 0.02), bflat(html("#e0b840"), 0.3, 0.9), bv(-0.2, 0.55, 0.31)))
    st_cloth(body, bv(0.05, 0.35, 0.31), team)
    let sp = st_done(body, team, bv(-0.4, 0.0, 0.31), 0.22, 0.4)
    blights(sp, [ bv(0.6, 0.36, 0.45) ])
    return bpt(sp, "smoke", smoke)

// The smithy: a stone forge room, a lean-to over the anvil and the forge's glowing hearth, a rack of tools.
def steading_smithy(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 0.8, 1.0, 0.6, bm("stone"), 0.0, bv(-0.4, 0.0, -0.1), false)
    let r = mnode()
    r.rot = bv(0.0, 90.0, 0.0)
    r.pos = bv(-0.4, 0.0, -0.1)
    add_child(body, r)
    st_roof(r, bv(0.0, 0.6, 0.0), 1.0, 0.8, 0.36, st_shingle(), bm("stone"))
    let smoke = st_chimney(body, bv(-0.55, 0.6, -0.35), 0.6, bm("stone"))
    for([ -0.45, 0.35 ]) z: add_child(body, bbox(bv(0.06, 0.55, 0.06), st_timber(), bv(0.6, 0.27, z)))
    add_child(body, bbox(bv(0.7, 0.04, 1.0), st_shingle(), bv(0.3, 0.6, -0.05), bv(0.0, 0.0, -12.0)))
    add_child(body, bbox(bv(0.36, 0.3, 0.36), bm("stone"), bv(0.15, 0.15, -0.3)))  // the hearth, aglow
    add_child(body, bbox(bv(0.24, 0.04, 0.24), bglow(html("#ff6a1a"), 2.8), bv(0.15, 0.31, -0.3)))
    add_child(body, bbox(bv(0.12, 0.2, 0.1), st_timber(), bv(0.35, 0.1, 0.25)))  // the anvil on its block
    add_child(body, bbox(bv(0.24, 0.07, 0.1), bflat(html("#4a4e54"), 0.4, 0.8), bv(0.35, 0.23, 0.25)))
    for(3) i: add_child(body, beam(bv(-0.75 + float(i) * 0.12, 0.05, 0.42), bv(-0.75 + float(i) * 0.12, 0.45, 0.42), 0.015, bm("wood"), 4))
    st_door(body, -0.4, 0.4, 0.24, 0.42)
    st_cloth(body, bv(-0.15, 0.48, 0.41), team)
    let sp = st_done(body, team, bv(-0.4, 0.0, 0.41), 0.22, 0.4)
    blights(sp, [ bv(0.15, 0.33, -0.3) ])
    return bpt(sp, "smoke", smoke)

// The fisherman's hut (#149): a small board hut on the bank under shingles, nets hung to dry on a frame, a rack of fish
// drying, an upturned boat and a barrel of salt.
def steading_fishermans_hut(team:float3) -> BSpec:
    let body = mnode()
    st_walls(body, 0.8, 0.7, 0.5, bm("wood"), 0.0, bv(-0.3, 0.0, -0.25))
    st_roof(body, bv(-0.3, 0.5, -0.25), 0.8, 0.7, 0.32, st_shingle(), bm("wood"))
    st_door(body, -0.4, 0.1, 0.22, 0.38)
    let net = st_col("#6a6a5a", 1.0)
    for([ 0.35, 0.95 ]) x: add_child(body, bbox(bv(0.05, 0.6, 0.05), st_timber(), bv(x, 0.3, -0.35)))  // the net frame
    add_child(body, bbox(bv(0.66, 0.04, 0.04), st_timber(), bv(0.65, 0.6, -0.35)))
    for(5) i: add_child(body, bbox(bv(0.1, 0.42, 0.015), net, bv(0.42 + float(i) * 0.115, 0.38, -0.35), bv(0.0, 0.0, if i % 2 == 0: 4.0 else: -4.0)))
    for([ 0.32, 0.6, 0.88 ]) x: add_child(body, bball(0.025, st_col("#c8a040", 0.6), bv(x, 0.2, -0.33)))  // its floats
    // the drying rack, fish hung on it
    let rack = bv(0.6, 0.0, 0.35)
    for([ -0.25, 0.25 ]) x: add_child(body, bbox(bv(0.04, 0.42, 0.04), st_timber(), rack + bv(x, 0.21, 0.0)))
    add_child(body, bbox(bv(0.56, 0.03, 0.03), st_timber(), rack + bv(0.0, 0.41, 0.0)))
    let fish = st_col("#a8bcc6", 0.4)
    for(5) i: add_child(body, bball(0.035, fish, rack + bv(-0.2 + float(i) * 0.1, 0.32, 0.0), bv(0.6, 1.8, 0.4)))
    // the boat, upturned on the bank
    let boat = mnode()
    boat.pos = bv(-0.55, 0.0, 0.55)
    boat.rot = bv(0.0, 20.0, 0.0)
    add_child(body, boat)
    add_child(boat, bball(0.3, st_board_dark(), bv(0.0, 0.0, 0.0), bv(1.9, 0.45, 0.75)))
    add_child(boat, bbox(bv(1.1, 0.03, 0.05), st_timber(), bv(0.0, 0.135, 0.0)))
    barrel(bv(0.05, 0.0, 0.35), body)
    st_cloth(body, bv(-0.1, 0.38, 0.11), team)
    let sp = st_done(body, team, bv(-0.4, 0.0, 0.1), 0.2, 0.36)
    blights(sp, [ st_lit(body, bv(-0.1, 0.25, 0.11), 0.12, 0.1) ])
    return sp

// The marketplace (#43): an open square of trestle stalls under striped awnings round a set of scales on a post, crates
// and sacks of goods between them, a small counting house at the back.
def steading_marketplace(team:float3) -> BSpec:
    let body = mnode()
    add_child(body, bbox(bv(2.3, 0.04, 2.3), st_stone_b(), bv(0.0, 0.02, 0.0)))  // the square's paving
    st_walls(body, 0.9, 0.6, 0.55, bm("plaster"), 0.0, bv(-0.55, 0.0, -0.75))
    st_frame(body, 0.9, 0.6, 0.55, 0.0, bv(-0.55, 0.0, -0.75))
    st_roof(body, bv(-0.55, 0.55, -0.75), 0.9, 0.6, 0.32, st_tile(), bm("plaster"))
    st_door(body, -0.55, -0.45, 0.22, 0.38)
    let stripes = [ [ "#b03a30", "#efe8e0" ], [ "#3a6a9a", "#efe8e0" ], [ "#c8a040", "#5a3a2a" ] ]
    for([ bv(0.6, 0.0, -0.6), bv(0.75, 0.0, 0.35), bv(-0.45, 0.0, 0.6) ]) at, n:
        add_child(body, bbox(bv(0.62, 0.05, 0.3), st_board(), at + bv(0.0, 0.26, 0.0)))  // the stall's counter on trestles
        for([ -0.26, 0.26 ]) x: add_child(body, bbox(bv(0.04, 0.26, 0.26), st_timber(), at + bv(x, 0.13, 0.0)))
        for([ -0.3, 0.3 ]) x: add_child(body, bbox(bv(0.035, 0.62, 0.035), st_timber(), at + bv(x, 0.31, -0.16)))
        for(5) i: add_child(body, bbox(bv(0.13, 0.02, 0.42), st_col(stripes[n][i % 2]), at + bv(-0.26 + float(i) * 0.13, 0.6, 0.02), bv(-18.0, 0.0, 0.0)))
    // loaves
    for([ bv(0.45, 0.33, -0.6), bv(0.7, 0.33, -0.6) ]) p: add_child(body, bball(0.07, st_col("#c07a3a"), p, bv(1.2, 0.7, 1.0)))
    // fish
    for(3) i: add_child(body, bcyl(0.035, 0.035, 0.12, st_col("#a8bcc6", 0.4), bv(0.6 + float(i) * 0.1, 0.31, 0.35), bv(0.0, 0.0, 90.0), 6))
    // iron bars, tools
    add_child(body, bbox(bv(0.12, 0.1, 0.1), bflat(html("#9aa4ae"), 0.4, 0.8), bv(-0.5, 0.33, 0.6)))
    add_child(body, bbox(bv(0.14, 0.06, 0.08), bflat(html("#7f8890"), 0.4, 0.8), bv(-0.32, 0.31, 0.6)))
    let post = bv(0.05, 0.0, -0.05)  // the scales on their post
    add_child(body, bbox(bv(0.06, 0.8, 0.06), st_timber(), post + bv(0.0, 0.4, 0.0)))
    add_child(body, bbox(bv(0.6, 0.03, 0.03), st_timber(), post + bv(0.0, 0.8, 0.0)))
    let brass = bflat(html("#c8a040"), 0.3, 0.8)
    for([ -0.27, 0.27 ]) x:
        add_child(body, beam(post + bv(x, 0.79, 0.0), post + bv(x, 0.55, 0.0), 0.006, bm("weave"), 3))
        add_child(body, bcyl(0.09, 0.07, 0.03, brass, post + bv(x, 0.54, 0.0), float3_0, 10))
    for([ bv(0.25, 0.12, 0.85), bv(0.48, 0.12, 0.9) ]) p: add_child(body, bbox(bv(0.22, 0.22, 0.22), st_board_dark(), p))
    for([ bv(-0.9, 0.1, 0.1), bv(-0.8, 0.1, 0.25) ]) p: add_child(body, bball(0.11, st_col("#d8c8a0", 1.0), p, bv(1.0, 1.2, 0.9)))
    barrel(bv(0.95, 0.0, -0.1), body)
    st_cloth(body, bv(-0.3, 0.38, -0.44), team)
    let sp = st_done(body, team, bv(-0.55, 0.0, -0.44), 0.2, 0.36)
    blights(sp, [ st_lit(body, bv(-0.3, 0.25, -0.44), 0.12, 0.1) ])
    return sp

// A Steading building by its type (the mod's own ids): nil for one this set has no model of.
def steading_building(type:string, team:float3) -> BSpec?:
    switch type:
        case "town_center": return steading_storehouse(team)
        case "school": return steading_school(team)
        case "lumber_camp": return steading_woodcutter(team)
        case "mining_camp": return steading_quarry(team)
        case "sawmill": return steading_sawmill(team)
        case "farm": return steading_farm(team)
        case "vineyard": return steading_vineyard(team)
        case "mill": return steading_mill(team)
        case "bakery": return steading_bakery(team)
        case "inn": return steading_inn(team)
        case "fishermans_hut": return steading_fishermans_hut(team)
        case "marketplace": return steading_marketplace(team)
        case "pig_farm": return steading_pig_farm(team)
        case "butcher": return steading_butcher(team)
        case "coal_mine": return steading_mine("coal", team)
        case "iron_mine": return steading_mine("iron", team)
        case "gold_mine": return steading_mine("gold", team)
        case "iron_smelter": return steading_iron_smelter(team)
        case "gold_smelter": return steading_gold_smelter(team)
        case "armoury": return steading_smithy(team)
        default: return nil
