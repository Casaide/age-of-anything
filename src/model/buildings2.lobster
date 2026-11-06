// ------------------------------------------------------------------ buildings, part 2 (src/view/art/bake/models.gd, lines 2178-3196)
// Universities and castles (each culture's tower, wall and keep), walls, palisades, gates, gatehouses, wall towers,
// ladders, rubble; and the entry points: building(type, arch, team), look(type, arch, name, team), model_by_name
// (models.call(name, team)), building_spec (ArtKit._spec). Line for line with models.gd (its comments are there).
// Godot's node metadata goes in MNode.meta, as words: a parapet mesh "parapet <along x y z> [about <x y z>]
// [roof]"; a gatehouse's tower node "gate_part <side> gate_centre <x y z>".

let UNIVERSITY_LOOKS = [ "observatory", "cloister", "builders" ]
let CASTLE_LOOKS = [ "curtain", "motte", "great_tower" ]

def university_look(arch:string) -> string:
    switch arch:
        case "stone", "thatch": return "cloister"
        case "junk", "tent": return "builders"
        default: return "observatory"

def castle_look(arch:string) -> string:
    switch arch:
        case "stone", "tent": return "curtain"
        case "thatch": return "motte"
        default: return "great_tower"

def bld_university(arch:string, team:float3) -> BSpec: return bld_university_look(university_look(arch), arch, team)
def bld_castle(arch:string, team:float3) -> BSpec: return bld_castle_look(castle_look(arch), arch, team)

def bld_index(l:[string], s:string) -> int:
    for(l) x, i:
        if x == s: return i
    return -1

// A dark arrow slit on a wall facing `turn` degrees (0: +z), centred on `at`.
def bld_slit(body:MNode, at:float3, turn:float, h:float = 0.18):
    add_child(body, bbox(bv(0.035, h, 0.02), bflat(html("#1a140e"), 1.0), at, bv(0.0, turn, 0.0)))

// Merlons round a circle of radius r at height y.
def bld_merlon_ring(body:MNode, at:float3, r:float, y:float, m:MMat, n:int = 8):
    for(n) k:
        let a = TAU * (float(k) + 0.5) / float(n)
        add_child(body, bbox(bv(0.11, 0.12, 0.09), m, at + bv(rsin(a) * r, y + 0.06, rcos(a) * r), bv(0.0, rad(a), 0.0)))

// A tower in the culture's own way on `at`, radius r, h to its fighting top. Returns the height of its very top.
def bld_fort_tower(body:MNode, arch:string, at:float3, r:float, h:float) -> float:
    let wood = bm("wood")
    switch arch:
        case "stone":
            let stone = bm("stone")
            add_child(body, bcyl(r, r * 1.08, h, stone, at + bv(0.0, h / 2.0, 0.0), float3_0, 20))
            add_child(body, bring(r * 1.0, r * 1.07, stone, at + bv(0.0, h * 0.62, 0.0)))
            add_child(body, bcyl(r + 0.05, r + 0.03, 0.1, stone, at + bv(0.0, h + 0.05, 0.0), float3_0, 20))
            bld_merlon_ring(body, at, r + 0.0, h + 0.1, stone, 8)
            for([ 0.0, 90.0 ]) turn:
                bld_slit(body, at + bv(sin(turn), 0.0, cos(turn)) * (r * 1.02) + bv(0.0, h * 0.45, 0.0), turn)
            return h + 0.22
        case "thatch":
            let mud = bm("mud")
            bld_footing(body, arch, r * 2.0 + 0.1, r * 2.0 + 0.1, 0.1, at)
            add_child(body, bbox(bv(r * 2.0, h, r * 2.0), mud, at + bv(0.0, h / 2.0 + 0.1, 0.0)))
            for([ -1.0, 1.0 ]) x:
                for([ -1.0, 1.0 ]) z:
                    add_child(body, bbox(bv(0.08, h, 0.08), wood, at + bv(x * r, h / 2.0 + 0.1, z * r)))
            add_child(body, beam(at + bv(-r, 0.15, r + 0.01), at + bv(r, h * 0.8, r + 0.01), 0.03, wood, 4))   // a brace across the front
            add_child(body, bbox(bv(r * 2.0 + 0.16, 0.3, r * 2.0 + 0.16), wood, at + bv(0.0, h + 0.25, 0.0)))  // the jetty
            bld_slit(body, at + bv(0.0, h + 0.25, r + 0.09), 0.0, 0.14)
            let rr = (r + 0.18) * 1.414
            add_child(body, bcyl(0.0, rr, r * 1.5, bm("thatch"), at + bv(0.0, h + 0.4 + r * 0.75, 0.0), bv(0.0, 45.0, 0.0), 4))
            return h + 0.4 + r * 1.5
        case "junk":
            let tin = bm("tin")
            let band = bflat(html("#9a9c96"), 0.5, 0.5)
            add_child(body, bcyl(r * 1.08, r * 1.12, 0.3, bm("brick"), at + bv(0.0, 0.15, 0.0), float3_0, 16))
            var y = 0.3
            var k = 0
            while y < h - 0.05:
                let ch = min(0.55, h - y)
                let cr = r * (1.0 - 0.06 * float(k))
                add_child(body, bcyl(cr, cr, ch, tin, at + bv(0.02 * float(k % 2), y + ch / 2.0, 0.0), bv(0.0, 30.0 * float(k), 0.0), 18))
                add_child(body, bring(cr - 0.01, cr + 0.03, band, at + bv(0.02 * float(k % 2), y + ch - 0.04, 0.0)))
                y += ch
                k += 1
            bld_slit(body, at + bv(0.0, h * 0.55, r * 0.95), 0.0)
            add_child(body, bcyl(0.0, r + 0.12, r * 0.9, tin, at + bv(0.0, y + r * 0.45, 0.0), float3_0, 18))  // the funnel roof
            add_child(body, bcyl(0.05, 0.05, r * 1.4, bflat(html("#4a4a48"), 0.5, 0.6), at + bv(r * 0.35, y + r * 0.7, 0.0), float3_0, 8))
            return y + r * 0.9
        case "tent":
            let felt = bm("felt")
            for([ -1.0, 1.0 ]) x:
                for([ -1.0, 1.0 ]) z:
                    add_child(body, beam(at + bv(x * r * 1.15, 0.0, z * r * 1.15), at + bv(x * r * 0.85, h, z * r * 0.85), 0.04, wood))
            add_child(body, bcyl(r * 1.02, r * 1.12, h * 0.55, felt, at + bv(0.0, h * 0.275, 0.0), bv(0.0, 45.0, 0.0), 4))
            add_child(body, bbox(bv(r * 2.0 + 0.1, 0.07, r * 2.0 + 0.1), wood, at + bv(0.0, h, 0.0)))
            add_child(body, bcyl(r * 0.85, r * 0.85, 0.28, felt, at + bv(0.0, h + 0.17, 0.0), float3_0, 20))
            add_child(body, bcyl(r * 0.15, r + 0.05, r * 0.6, felt, at + bv(0.0, h + 0.31 + r * 0.3, 0.0), float3_0, 20))
            return h + 0.31 + r * 0.6
        case "reed":
            let deck_y = bld_stilt_deck(body, at, r * 2.0 + 0.2, r * 2.0 + 0.2)
            let weave = bm("weave")
            add_child(body, bcyl(r * 0.88, r, h - deck_y, weave, at + bv(0.0, deck_y + (h - deck_y) / 2.0, 0.0), float3_0, 22))
            for([ 0.25, 0.7 ]) t:
                add_child(body, bring(r * (1.0 - 0.12 * t) - 0.02, r * (1.0 - 0.12 * t) + 0.04, bm("mud"), at + bv(0.0, deck_y + (h - deck_y) * t, 0.0)))
            bld_slit(body, at + bv(0.0, deck_y + (h - deck_y) * 0.5, r * 0.95), 0.0)
            add_child(body, bdome(r * 0.98, bm("thatch"), at + bv(0.0, h - 0.02, 0.0), bv(1.0, 1.0, 1.0)))
            return h + r * 0.98
        case "mound":
            let mud = bm("mud")
            add_child(body, bcyl(r * 0.28, r * 1.05, h, mud, at + bv(0.0, h / 2.0, 0.0), float3_0, 14))
            for(4) k:
                let a = TAU * float(k) / 4.0 + 0.6
                let y = h * (0.25 + 0.15 * float(k))
                let ra = r * 1.05 - (r * 0.77) * y / h
                add_child(body, bball(r * 0.32, mud, at + bv(rsin(a) * ra * 0.8, y, rcos(a) * ra * 0.8), bv(1.0, 1.3, 1.0)))
            add_child(body, bball(r * 0.3, mud, at + bv(0.0, h, 0.0), bv(1.0, 1.4, 1.0)))
            bld_burrow_door(body, at + bv(0.0, h * 0.5, r * 0.62), r * 0.18, 0.0)
            return h + r * 0.4
        default:
            assert false
    return h

// A stretch of curtain wall h high from a to b, in the culture's stuff.
def bld_fort_wall(body:MNode, arch:string, a:float3, b:float3, h:float, thick:float = 0.22):
    let holder = mnode()
    holder.pos = (a + b) / 2.0
    set_basis(holder, axis_angle(BLD_UP, atan2(float2 { b.x - a.x, -(b.z - a.z) })))
    add_child(body, holder)
    let l = f32(magnitude(b - a))  // (Godot's distance_to is a 32-bit float: 3.1 / 0.1 stakes is 30 there)
    let wood = bm("wood")
    switch arch:
        case "stone":
            let stone = bm("stone")
            add_child(holder, bbox(bv(l, h, thick), stone, bv(0.0, h / 2.0, 0.0)))
            add_child(holder, bbox(bv(l, 0.05, thick + 0.06), stone, bv(0.0, h + 0.025, 0.0)))
            let n = max(1, int(l / 0.24))
            for(n) k:
                add_child(holder, bbox(bv(0.12, 0.11, thick * 0.6), stone, bv(-l / 2.0 + (float(k) + 0.5) * l / float(n), h + 0.1, 0.0)))
        case "thatch", "tent":
            if arch == "thatch":
                add_child(holder, bbox(bv(l + 0.1, 0.16, thick + 0.3), bm("mud"), bv(0.0, 0.08, 0.0)))
            let base = if arch == "thatch": 0.14 else: 0.0
            let n = max(2, int(l / 0.11))
            for(n) k:
                let x = -l / 2.0 + (float(k) + 0.5) * l / float(n)
                let sh = h - base + (if k % 2 == 0: 0.04 else: -0.02)
                add_child(holder, bcyl(0.05, 0.055, sh, wood, bv(x, base + sh / 2.0, 0.0), bv(randf_range(brng, -3.0, 3.0), 0.0, 0.0), 7))
                add_child(holder, bcyl(0.0, 0.05, 0.1, wood, bv(x, base + sh + 0.05, 0.0), float3_0, 7))
            add_child(holder, bbox(bv(l, 0.04, 0.03), wood, bv(0.0, base + (h - base) * 0.7, thick * 0.3)))  // a rail binding them
            if arch == "tent":
                add_child(holder, bbox(bv(l, h * 0.42, 0.03), bm("felt"), bv(0.0, h * 0.3, 0.07)))
        case "junk":
            add_child(holder, bbox(bv(l, h * 0.45, thick), bm("brick"), bv(0.0, h * 0.225, 0.0)))
            let n = max(1, int(l / 0.42))
            for(n) k:
                let x = -l / 2.0 + (float(k) + 0.5) * l / float(n)
                let sh = h * 0.6 + randf_range(brng, -0.05, 0.08)
                let mat = if k % 3 != 1: bm("tin") else: bflat(lerp3(html("#6e4a2c"), html("#8a7050"), randf(brng)), 0.9)
                let pz = randf_range(brng, -0.02, 0.02)
                let rz = randf_range(brng, -4.0, 4.0)
                add_child(holder, bbox(bv(l / float(n) + 0.03, sh, 0.05), mat, bv(x, h * 0.4 + sh / 2.0, pz), bv(0.0, 0.0, rz)))
        case "reed":
            add_child(holder, bbox(bv(l + 0.1, 0.12, thick + 0.2), bm("mud"), bv(0.0, 0.06, 0.0)))
            let reed = bm("thatch")
            let n = max(2, int(l / 0.1))
            for(n) k:
                let x = -l / 2.0 + (float(k) + 0.5) * l / float(n)
                let rx = randf_range(brng, -5.0, 5.0)
                let rz = randf_range(brng, -4.0, 4.0)
                add_child(holder, bcyl(0.04, 0.055, h - 0.1, reed, bv(x, 0.1 + (h - 0.1) / 2.0, 0.0), bv(rx, 0.0, rz), 7))
            for([ 0.35, 0.75 ]) y:
                add_child(holder, bbox(bv(l, 0.035, thick * 0.5), wood, bv(0.0, h * y, 0.0)))
        case "mound":
            let mud = bm("mud")
            add_child(holder, bbox(bv(l, h - thick / 2.0, thick + 0.1), mud, bv(0.0, (h - thick / 2.0) / 2.0, 0.0)))
            add_child(holder, bcyl(thick / 2.0 + 0.05, thick / 2.0 + 0.05, l, mud, bv(0.0, h - thick / 2.0, 0.0), bv(0.0, 0.0, 90.0), 10))

// The culture's great hall or keep, centred on `at`, its door on the front (+z). Returns its top.
def bld_keep(body:MNode, arch:string, at:float3, w:float, d:float, h:float, team:float3) -> float:
    let holder = mnode()
    holder.pos = at
    add_child(body, holder)
    switch arch:
        case "stone":
            let stone = bm("stone")
            add_child(holder, bbox(bv(w + 0.12, 0.14, d + 0.12), stone, bv(0.0, 0.07, 0.0)))
            add_child(holder, bbox(bv(w, h, d), stone, bv(0.0, h / 2.0, 0.0)))
            add_child(holder, bbox(bv(w + 0.08, 0.08, d + 0.08), stone, bv(0.0, h + 0.04, 0.0)))
            for(4) side:
                let along = if side % 2 == 0: w else: d
                let n = max(2, int(along / 0.24))
                for(n) k:
                    let t = -along / 2.0 + (float(k) + 0.5) * along / float(n)
                    let p = if side == 0: bv(t, h + 0.14, d / 2.0) elif side == 1: bv(w / 2.0, h + 0.14, t) elif side == 2: bv(t, h + 0.14, -d / 2.0) else: bv(-w / 2.0, h + 0.14, t)
                    add_child(holder, bbox(bv(if side % 2 == 0: 0.11 else: 0.09, 0.12, if side % 2 == 0: 0.09 else: 0.11), stone, p))
            for([ -1.0, 1.0 ]) x:
                for([ -1.0, 1.0 ]) z:
                    add_child(holder, bcyl(0.13, 0.13, h + 0.35, stone, bv(x * w / 2.0, (h + 0.35) / 2.0, z * d / 2.0), float3_0, 12))
                    add_child(holder, bcyl(0.0, 0.17, 0.3, bm("terracotta"), bv(x * w / 2.0, h + 0.5, z * d / 2.0), float3_0, 12))
            for([ -w * 0.25, w * 0.25 ]) x:
                bld_slit(holder, bv(x, h * 0.7, d / 2.0 + 0.01), 0.0)
            bld_slit(holder, bv(w / 2.0 + 0.01, h * 0.6, 0.0), 90.0)
            add_child(holder, bbox(bv(0.36, 0.5, 0.04), bflat(html("#3a2416"), 0.9), bv(0.0, 0.39, d / 2.0 + 0.02)))  // the door
            add_child(holder, bbox(bv(0.2, 0.42, 0.02), bcloth(team), bv(w * 0.3, h * 0.55, d / 2.0 + 0.02)))         // a banner hung on the face
            return at.y + h + 0.65
        case "tent":
            return at.y + bld_yurt(holder, float3_0, min(w, d) / 2.0 + 0.15, h * 0.55, team)
        case "reed":
            let deck_y = bld_stilt_deck(holder, float3_0, w + 0.2, d + 0.2)
            let r = min(w, d) / 2.0
            let top = bld_reed_dome(holder, bv(0.0, deck_y, 0.0), r, team)
            add_child(holder, bcyl(r * 0.36, r * 0.44, 0.22, bm("weave"), bv(0.0, top - 0.06, 0.0), float3_0, 20))
            add_child(holder, bdome(r * 0.44, bm("thatch"), bv(0.0, top + 0.05, 0.0), bv(1.0, 1.1, 1.0)))
            return at.y + top + r * 0.5
        case "mound":
            let mud = bm("mud")
            let r = min(w, d) / 2.0
            add_child(holder, bdome(r, mud, float3_0, bv(w / (2.0 * r), h / r, d / (2.0 * r))))
            add_child(holder, bdome(r * 0.45, mud, bv(0.0, h * 0.85, 0.0), bv(1.0, 1.0, 1.0)))
            bld_burrow_door(holder, bv(0.0, h * 0.25, d / 2.0 - 0.05), r * 0.22, 0.0, team)
            return at.y + h * 0.85 + r * 0.45
        default: pass()
    let base = bld_hall(holder, arch, w, d, h)
    let rise = bld_roof(holder, arch, bv(0.0, base + h, 0.0), w, d)
    add_child(holder, bbox(bv(0.36, 0.5, 0.04), bflat(html("#2a1e14"), 0.9), bv(0.0, base + 0.25, d / 2.0 + 0.02)))
    add_child(holder, bbox(bv(0.42, 0.07, 0.06), bcloth(team), bv(0.0, base + 0.53, d / 2.0 + 0.03)))  // a team cloth over the door
    return at.y + base + h + rise

// A standard on a pole at `at`, `tall` high: the live banner and its pivot.
def bld_standard(body:MNode, at:float3, tall:float, team:float3) -> MNode, float3:
    let wood = bm("wood")
    add_child(body, bcyl(0.025, 0.03, tall, wood, at + bv(0.0, tall / 2.0, 0.0), float3_0, 8))
    let banner = mnode()
    let flag_top = at + bv(0.03, tall - 0.08, 0.0)
    add_child(banner, bbox(bv(0.46, 0.04, 0.03), wood, flag_top + bv(0.23, 0.0, 0.0)))
    add_child(banner, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.56, -0.2 }, float2 { 0.0, -0.44 }, 0.02, bcloth(team)))
    last_kid(banner).pos = flag_top
    return banner, flag_top

// A castle (4 x 4 tiles): curtain, motte or great_tower.
def bld_castle_look(name:string, arch:string, team:float3) -> BSpec:
    brng = grng(400 + bld_index(CASTLE_LOOKS, name))
    let body = mnode()
    let wood = bm("wood")
    var top = 0.0
    var banner = mnode()
    var pivot = float3_0
    let c = 1.55
    switch name:
        case "curtain":
            let tr = 0.34
            let th = 1.25
            for([ -1.0, 1.0 ]) x:
                for([ -1.0, 1.0 ]) z:
                    bld_fort_tower(body, arch, bv(x * c, 0.0, z * c), tr, th + (if z < 0.0: 0.15 else: 0.0))
            let wh = 0.82
            bld_fort_wall(body, arch, bv(-c, 0.0, -c), bv(c, 0.0, -c), wh)
            bld_fort_wall(body, arch, bv(-c, 0.0, -c), bv(-c, 0.0, c), wh)
            bld_fort_wall(body, arch, bv(c, 0.0, -c), bv(c, 0.0, c), wh)
            bld_fort_wall(body, arch, bv(-c, 0.0, c), bv(-0.42, 0.0, c), wh)
            bld_fort_wall(body, arch, bv(0.42, 0.0, c), bv(c, 0.0, c), wh)
            bld_gate(body, arch, bv(0.0, 0.0, c), wh, team)
            top = bld_keep(body, arch, bv(0.0, 0.0, -0.35), 1.45, 1.15, 1.45, team)
            if arch == "stone":
                banner, pivot = bld_standard(body, bv(0.3, 1.53, -0.35), 0.9, team)
            else:
                banner, pivot = bld_standard(body, bv(-0.95, 0.0, -0.95), top + 0.4, team)
        case "motte":
            let mx = bv(-0.35, 0.0, -0.45)
            let mr = 1.25
            let mh = 0.55
            add_child(body, bdome(mr, bm("mud"), mx, bv(1.0, mh / mr, 1.0)))
            bld_grass_tufts(body, mx + bv(0.0, mh * 0.6, 0.5), 0.45, 8)
            top = bld_keep(body, arch, mx + bv(0.0, mh - 0.1, 0.0), 1.2, 1.05, 1.4, team)
            for(5) k:  // steps up the mound's front
                add_child(body, bbox(bv(0.36, 0.06, 0.16), wood, mx + bv(0.45, mh * (float(k) + 0.5) / 5.0, mr * 0.95 - float(k) * 0.14), bv(0.0, 25.0, 0.0)))
            let wh = 0.62
            let fz = 1.6
            bld_fort_tower(body, arch, bv(-c, 0.0, fz), 0.3, 1.0)
            bld_fort_tower(body, arch, bv(c, 0.0, fz), 0.3, 1.0)
            bld_fort_tower(body, arch, bv(c, 0.0, -c), 0.28, 0.9)
            bld_fort_wall(body, arch, bv(-c, 0.0, fz), bv(-0.42, 0.0, fz), wh)
            bld_fort_wall(body, arch, bv(0.42, 0.0, fz), bv(c, 0.0, fz), wh)
            bld_fort_wall(body, arch, bv(c, 0.0, -c), bv(c, 0.0, fz), wh)
            bld_fort_wall(body, arch, bv(-c, 0.0, fz), bv(-c, 0.0, 0.35), wh)
            bld_fort_wall(body, arch, bv(-0.9, 0.0, -c), bv(c, 0.0, -c), wh)
            bld_gate(body, arch, bv(0.0, 0.0, fz), wh, team)
            crate(bv(0.95, 0.0, 0.75), body, 20.0)
            barrel(bv(0.75, 0.0, 1.05), body)
            banner, pivot = bld_standard(body, mx + bv(0.4, mh, -0.4), top - mh + 0.5, team)
        case "great_tower":
            let tx = bv(-0.55, 0.0, -0.55)
            top = bld_fort_tower(body, arch, tx, 0.78, 2.5)
            bld_keep(body, arch, bv(0.75, 0.0, -0.65), 1.2, 1.0, 0.8, team)
            let wh = 0.6
            bld_fort_tower(body, arch, bv(c, 0.0, c), 0.26, 0.95)
            bld_fort_tower(body, arch, bv(-c, 0.0, c), 0.26, 0.95)
            bld_fort_wall(body, arch, bv(-c, 0.0, c), bv(-0.4, 0.0, c), wh)
            bld_fort_wall(body, arch, bv(0.4, 0.0, c), bv(c, 0.0, c), wh)
            bld_fort_wall(body, arch, bv(c, 0.0, c), bv(c, 0.0, 0.0), wh)
            bld_fort_wall(body, arch, bv(-c, 0.0, c), bv(-c, 0.0, 0.3), wh)
            bld_gate(body, arch, bv(0.0, 0.0, c), wh, team)
            woodpile(bv(0.6, 0.0, 0.55), body)
            banner, pivot = bld_standard(body, tx + bv(0.0, top - 0.05, 0.0), 0.8, team)
        default: assert false
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    bteam(sp, team)
    bpt(sp, "lantern", bv(0.0, 0.9, 1.7))
    return bpt(sp, "smoke", bv(0.0, top, -0.35))

// A gateway in a front wall (+z face) at `at`: two piers, a lintel, the doors shut.
def bld_gate(body:MNode, arch:string, at:float3, h:float, team:float3):
    let post = bm(if arch == "stone": "stone" elif arch == "junk": "brick" elif arch == "mound": "mud" else: "wood")
    let gh = h + 0.3
    for([ -0.42, 0.42 ]) x:
        add_child(body, bbox(bv(0.2, gh, 0.32), post, at + bv(x, gh / 2.0, 0.0)))
    add_child(body, bbox(bv(1.04, 0.2, 0.34), post, at + bv(0.0, gh - 0.1, 0.0)))
    if arch == "stone":
        for([ -0.42, 0.0, 0.42 ]) x:
            add_child(body, bbox(bv(0.12, 0.12, 0.1), post, at + bv(x, gh + 0.06, 0.12)))
    add_child(body, bbox(bv(0.62, gh - 0.22, 0.05), bflat(html("#3a2416"), 0.9), at + bv(0.0, (gh - 0.22) / 2.0, 0.02)))  // the doors, shut
    add_child(body, bbox(bv(0.6, 0.04, 0.06), bm("wood"), at + bv(0.0, (gh - 0.22) * 0.3, 0.05)))
    add_child(body, bbox(bv(0.6, 0.04, 0.06), bm("wood"), at + bv(0.0, (gh - 0.22) * 0.75, 0.05)))
    add_child(body, bbox(bv(0.16, 0.24, 0.02), bcloth(team), at + bv(-0.42, gh * 0.6, 0.17)))  // a small team cloth on a pier

// A University (3 x 3 tiles): observatory, cloister or builders.
def bld_university_look(name:string, arch:string, team:float3) -> BSpec:
    brng = grng(300 + bld_index(UNIVERSITY_LOOKS, name))
    let body = mnode()
    let wood = bm("wood")
    let k = bkit(arch)
    let stone_like = bm(if arch == "stone": "stone" elif arch == "junk": "brick" elif arch == "mound" or arch == "reed": "mud" elif arch == "tent": "wood" else: "stone")
    var top = 0.0
    let lights = []::float3
    switch name:
        case "observatory":
            top = bld_uni_hall(body, arch, bv(-0.35, 0.0, 0.05), 1.8, 1.1, 0.8, team)
            let at = bv(0.8, 0.0, -0.85)
            let r = 0.42
            let th = 2.0
            var scope_from = at + bv(0.0, th + r * 0.45, r * 0.45)
            if arch == "mound":  // a spire with a glass poking out near its top
                top = max(top, bld_fort_tower(body, arch, at, r, th))
                scope_from = at + bv(0.0, th * 0.8, r * 0.35)
            elif arch == "reed":  // the woven tower, under its own reed dome
                top = max(top, bld_fort_tower(body, arch, at, r, th))
            else:
                bld_plain_tower(body, arch, at, r, th)
                let dome_mat = if arch == "stone": bflat(html("#6a9a86"), 0.5, 0.4) elif arch == "junk": bm("tin") elif arch == "tent": bm("felt") else: bm("thatch")
                add_child(body, bdome(r + 0.06, dome_mat, at + bv(0.0, th, 0.0)))
                add_child(body, bbox(bv(0.1, r * 0.8, 0.03), bflat(html("#1a140e"), 1.0), at + bv(0.0, th + r * 0.35, r * 0.62), bv(-35.0, 0.0, 0.0)))  // the slot in the dome
                top = max(top, th + r + 0.06)
            add_child(body, beam(scope_from, scope_from + bv(0.12, 0.32, 0.3), 0.04, bflat(html("#b07a36"), 0.4, 0.7), 10))  // the brass glass
            add_child(body, bcyl(0.13, 0.15, 0.3, stone_like, bv(0.95, 0.15, 0.85), float3_0, 12))
            add_child(body, bcyl(0.18, 0.18, 0.03, bflat(html("#c8b48a"), 0.6), bv(0.95, 0.315, 0.85), float3_0, 16))
            add_child(body, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.14, 0.0 }, float2 { 0.0, 0.12 }, 0.012, bflat(html("#b07a36"), 0.4, 0.7)))
            last_kid(body).pos = bv(0.93, 0.33, 0.85)
            bld_books(body, bv(-0.4, 0.0, 1.05))
            lights.push(at + bv(r * 0.9, th * 0.6, r * 0.4))
        case "cloister":
            top = bld_uni_hall(body, arch, bv(0.0, 0.0, -0.85), 2.4, 0.8, 0.8, team)
            for([ -1.0, 1.0 ]) side:  // the covered walks down the sides, open to the yard
                bld_walk(body, arch, bv(side * 1.1, 0.0, 0.25), 0.5, 1.5, true)
            bld_walk(body, arch, bv(0.0, 0.0, 1.15), 1.7, 0.42, false)
            add_child(body, bcyl(0.05, 0.06, 0.4, wood, bv(0.15, 0.2, 0.25), float3_0, 8))  // a tree in the yard
            add_child(body, bball(0.32, bflat(html("#4e7a30"), 0.9), bv(0.15, 0.62, 0.25), bv(1.0, 0.9, 1.0)))
            add_child(body, bball(0.2, bflat(html("#5e8a38"), 0.9), bv(0.0, 0.75, 0.35)))
            add_child(body, bcyl(0.12, 0.14, 0.12, stone_like, bv(-0.35, 0.06, 0.3), float3_0, 12))  // a well
            let bt = bv(-1.05, 0.0, -1.05)
            let bh = 1.55
            add_child(body, bbox(bv(0.5, bh, 0.5), bm(k.wall), bt + bv(0.0, bh / 2.0, 0.0)))
            for([ -1.0, 1.0 ]) x:
                for([ -1.0, 1.0 ]) z:
                    add_child(body, bbox(bv(0.07, 0.42, 0.07), bm(k.frame), bt + bv(x * 0.22, bh + 0.21, z * 0.22)))
            add_child(body, bcyl(0.05, 0.1, 0.14, bflat(html("#b07a36"), 0.4, 0.7), bt + bv(0.0, bh + 0.22, 0.0), float3_0, 12))
            add_child(body, bcyl(0.0, 0.45, 0.4, bld_roof_mat(k), bt + bv(0.0, bh + 0.62, 0.0), bv(0.0, 45.0, 0.0), 4))
            top = max(top, bh + 0.82)
        case "builders":
            top = bld_uni_hall(body, arch, bv(-0.5, 0.0, -0.6), 1.6, 1.1, 0.85, team)
            let f = bv(0.8, 0.0, 0.15)
            for([ -0.35, 0.35 ]) z:
                add_child(body, beam(f + bv(-0.45, 0.0, z), f + bv(0.0, 1.75, z * 0.3), 0.055, wood))
                add_child(body, beam(f + bv(0.45, 0.0, z), f + bv(0.0, 1.75, z * 0.3), 0.055, wood))
            add_child(body, beam(f + bv(0.0, 1.72, -0.15), f + bv(0.0, 1.72, 0.15), 0.04, wood))
            add_child(body, beam(f + bv(0.0, 1.72, 0.0), f + bv(0.0, 0.84, 0.0), 0.015, bflat(html("#8a6a3c"), 0.9), 4))
            add_child(body, bbox(bv(0.42, 0.28, 0.3), stone_like, f + bv(0.0, 0.7, 0.0)))
            add_child(body, bcyl(0.1, 0.1, 0.5, wood, f + bv(-0.3, 0.3, 0.0), bv(90.0, 0.0, 0.0), 10))  // the winding drum
            for([ bv(-0.2, 0.11, 0.85), bv(0.15, 0.11, 0.9), bv(-0.03, 0.33, 0.87) ]) p:
                add_child(body, bbox(bv(0.32, 0.22, 0.24), stone_like, p, bv(0.0, randf_range(brng, -8.0, 8.0), 0.0)))
            for([ -1.05, -0.55 ]) x:
                add_child(body, bbox(bv(0.16, 0.5, 0.18), stone_like, bv(x, 0.25, 0.7)))
            add_child(body, bbox(bv(0.66, 0.14, 0.18), stone_like, bv(-0.8, 0.57, 0.7)))
            add_child(body, bbox(bv(0.3, 0.03, 0.22), bflat(html("#e8dcc0"), 0.9), bv(0.45, 0.42, 1.05), bv(0.0, 10.0, 0.0)))  // a plan on a trestle
            for([ 0.33, 0.57 ]) x:
                add_child(body, beam(bv(x, 0.0, 0.98), bv(x, 0.4, 1.06), 0.015, wood, 4))
                add_child(body, beam(bv(x, 0.0, 1.14), bv(x, 0.4, 1.06), 0.015, wood, 4))
            top = max(top, 1.75)
        default: assert false
    let sp = bspec(body)
    blights(sp, lights)
    bteam(sp, team)
    bpt(sp, "lantern", bv(0.0, 0.5, 0.9))
    return bpt(sp, "smoke", bv(-0.3, top, -0.45))

// A University's hall, centred on `at`, a team cloth over the door. Returns its top.
def bld_uni_hall(body:MNode, arch:string, at:float3, w:float, d:float, h:float, team:float3) -> float:
    if arch == "reed" or arch == "mound" or arch == "tent":
        return bld_keep(body, arch, at, w, d, h, team)
    let holder = mnode()
    holder.pos = at
    add_child(body, holder)
    let base = bld_hall(holder, arch, w, d, h)
    let rise = bld_roof(holder, arch, bv(0.0, base + h, 0.0), w, d)
    add_child(holder, bbox(bv(0.36, 0.5, 0.04), bflat(html("#2a1e14"), 0.9), bv(-w * 0.2, base + 0.25, d / 2.0 + 0.02)))
    add_child(holder, bbox(bv(0.42, 0.07, 0.06), bcloth(team), bv(-w * 0.2, base + 0.53, d / 2.0 + 0.03)))
    for([ w * 0.1, w * 0.32 ]) x:  // tall windows: a place of reading
        add_child(holder, bbox(bv(0.14, 0.32, 0.03), bglow(html("#ffcf6a"), 1.2), bv(x, base + h * 0.55, d / 2.0 + 0.01)))
    return at.y + base + h + rise

// A plain round or square tower of the culture's walls, h to its top.
def bld_plain_tower(body:MNode, arch:string, at:float3, r:float, h:float) -> float:
    let k = bkit(arch)
    if arch == "stone":
        add_child(body, bcyl(r, r * 1.05, h, bm("plaster"), at + bv(0.0, h / 2.0, 0.0), float3_0, 20))
        add_child(body, bring(r, r * 1.06, bm("stone"), at + bv(0.0, h - 0.05, 0.0)))
        add_child(body, bring(r * 1.02, r * 1.08, bm("stone"), at + bv(0.0, 0.06, 0.0)))
    elif arch == "junk":
        add_child(body, bcyl(r, r, h, bm("tin"), at + bv(0.0, h / 2.0, 0.0), float3_0, 20))
        for([ 0.3, 0.75 ]) y:
            add_child(body, bring(r - 0.01, r + 0.03, bflat(html("#9a9c96"), 0.5, 0.5), at + bv(0.0, h * y, 0.0)))
    elif arch == "tent":
        add_child(body, bcyl(r, r * 1.1, h, bm("felt"), at + bv(0.0, h / 2.0, 0.0), float3_0, 20))
        for([ 0.3, 0.7 ]) y:
            add_child(body, bring(r * 1.02, r * 1.08, bflat(html("#8a6a3c"), 0.9), at + bv(0.0, h * y, 0.0)))
    else:
        add_child(body, bcyl(r, r * 1.05, h, bm(k.wall), at + bv(0.0, h / 2.0, 0.0), float3_0, 20))
        for([ 0.0, 120.0, 240.0 ]) a:
            add_child(body, bbox(bv(0.07, h, 0.07), bm(k.frame), at + bv(sin(a) * r, h / 2.0, cos(a) * r)))
    add_child(body, bbox(bv(0.1, 0.24, 0.03), bglow(html("#ffcf6a"), 1.2), at + bv(0.0, h * 0.6, r + 0.005)))
    return at.y + h

// A covered walk: a row of posts under a lean-to roof of the culture's roofing, w x d.
def bld_walk(body:MNode, arch:string, at:float3, w:float, d:float, along_z:bool):
    let k = bkit(arch)
    let post = bm(if arch == "stone": "stone" else: k.frame)
    let h = 0.5
    let n = max(2, int((if along_z: d else: w) / 0.38) + 1)
    for(n) i:
        let t = -0.5 + float(i) / float(n - 1)
        let p = at + (if along_z: bv(0.0, 0.0, t * d) else: bv(t * w, 0.0, 0.0))
        if arch == "stone":
            add_child(body, bcyl(0.04, 0.05, h, post, p + bv(0.0, h / 2.0, 0.0), float3_0, 10))
        else:
            add_child(body, bbox(bv(0.06, h, 0.06), post, p + bv(0.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(w + 0.1, 0.05, d + 0.1), bld_roof_mat(k), at + bv(0.0, h + 0.06, 0.0), float3_0))

// A stack of books and a scroll on a little bench.
def bld_books(body:MNode, at:float3):
    let wood = bm("wood")
    add_child(body, bbox(bv(0.5, 0.04, 0.18), wood, at + bv(0.0, 0.2, 0.0)))
    for([ -0.2, 0.2 ]) x:
        add_child(body, bbox(bv(0.04, 0.2, 0.14), wood, at + bv(x, 0.1, 0.0)))
    let covers = [ html("#7a2a22"), html("#2a4a6a"), html("#5a6a2a") ]
    for(3) i:
        add_child(body, bbox(bv(0.16, 0.04, 0.12), bflat(covers[i], 0.8), at + bv(-0.08, 0.24 + float(i) * 0.04, 0.0), bv(0.0, float(i) * 12.0, 0.0)))
    add_child(body, bcyl(0.03, 0.03, 0.18, bflat(html("#e8dcc0"), 0.9), at + bv(0.14, 0.25, 0.0), bv(0.0, 30.0, 90.0), 8))

// ------------------------------------------------------------------ walls and gates

// How high units on a walkway stand, per building type (WALK_H); every wall height times wall_rescale.
def walk_h(type:string) -> float:
    switch type:
        case "wall_tower": return 2.32
        default: return 1.36  // wall, stone_gate
let wall_rescale = 1.0
let BLD_NONE = float3 { -999.0, -999.0, -999.0 }  // no `about` point
let WALL_D = 0.72                                 // the curtain's thickness
let TOWER_W = 1.0                                 // a wall tower fills its tile
let HOARD_H = 0.3                                 // a tower's hoarding, this high
let HOARD_POST = 0.8                              // the posts from the floor up to the roof's eaves
let GATE_TOWER_W = 0.6
let GATE_TOWER_D = 1.1
let GATE_ARCH = 0.95  // the passage's height under the walk

def gate_tower_from(span:float) -> float: return span / 2.0 - GATE_TOWER_W

def bld_wh(type:string) -> float: return walk_h(type) * wall_rescale

// Tag a mesh as parapet: its wall's direction here (`along`; zero for a post or tower), and the point it's in
// front of when on the near side (`about`).
def parapet(mi:MNode, along:float3 = float3_0, about:float3 = BLD_NONE) -> MNode:
    mi.meta = "parapet {along.x} {along.y} {along.z}"
    if about != BLD_NONE: mi.meta += " about {about.x} {about.y} {about.z}"
    return mi

def merlon(size:float3, m:MMat, pos:float3, along:float3 = float3_0, about:float3 = BLD_NONE) -> MNode:
    return parapet(bbox(size, m, pos), along, about)

def bld_roof_tag(mi:MNode, about:float3 = BLD_NONE) -> MNode:
    parapet(mi, float3_0, about)
    mi.meta += " roof"
    return mi

// What a culture builds its stone wall of.
def wall_stone(arch:string) -> string:
    switch arch:
        case "junk": return "brick"
        case "reed", "mound": return "mud"
        default: return "stone"

// One crenel's worth of parapet: a merlon, or for the earth walls a pair of sharpened stakes.
def bld_crenel(body:MNode, arch:string, m:MMat, size:float3, pos:float3, along:float3 = float3_0, about:float3 = BLD_NONE):
    if wall_stone(arch) != "mud":
        add_child(body, merlon(size, m, pos + bv(0.0, size.y / 2.0, 0.0), along, about))
        return
    let wood = bm("wood")
    let dir = if magnitude(along) > 0.001: along else: bv(1.0, 0.0, 0.0)
    for([ -1.0, 1.0 ]) s:
        let h = size.y * (if s < 0.0: 1.25 else: 1.1)
        let p = pos + dir * (s * size.x * 0.25)
        add_child(body, parapet(bcyl(0.04, 0.045, h, wood, p + bv(0.0, h / 2.0, 0.0), float3_0, 7), along, about))
        add_child(body, parapet(bcyl(0.0, 0.04, 0.08, wood, p + bv(0.0, h + 0.04, 0.0), float3_0, 7), along, about))

// What a culture roofs and hangs its towers' hoardings with: roof, hoarding.
def bld_tower_dress(arch:string) -> string, string:
    switch arch:
        case "stone": return "terracotta", "wood"
        case "junk": return "tin", "tin"
        case "tent": return "felt", "wood"
        case "reed", "mound": return "thatch", "weave"
        default: return "thatch", "wood"

// A tower's top, w x d, its floor at h, about `at`: the hoarding, corner posts, a hipped roof.
def bld_tower_top(body:MNode, arch:string, at:float3, w:float, d:float, h:float):
    let roof_name, hoard_name = bld_tower_dress(arch)
    let hoard = bm(hoard_name)
    let wood = bm("wood")
    let dark = bflat(html("#1e1a16"), 1.0)
    let about = at + bv(0.0, h, 0.0)
    let t = 0.05
    for([ -1.0, 1.0 ]) side:  // the gallery
        add_child(body, parapet(bbox(bv(w + 0.02, HOARD_H, t), hoard, at + bv(0.0, h + HOARD_H / 2.0, side * (d / 2.0 - t / 2.0 + 0.01))), float3_0, about))
        add_child(body, parapet(bbox(bv(t, HOARD_H, d + 0.02), hoard, at + bv(side * (w / 2.0 - t / 2.0 + 0.01), h + HOARD_H / 2.0, 0.0)), float3_0, about))
        add_child(body, parapet(bbox(bv(min(0.14, w * 0.3), 0.09, 0.01), dark, at + bv(0.0, h + HOARD_H * 0.55, side * (d / 2.0 + 0.016))), float3_0, about))
        add_child(body, parapet(bbox(bv(0.01, 0.09, min(0.14, d * 0.3)), dark, at + bv(side * (w / 2.0 + 0.016), h + HOARD_H * 0.55, 0.0)), float3_0, about))
    for([ -1.0, 1.0 ]) x:  // the corner posts up to the eaves
        for([ -1.0, 1.0 ]) z:
            add_child(body, parapet(bbox(bv(0.06, HOARD_POST, 0.06), wood, at + bv(x * (w / 2.0 - 0.03), h + HOARD_POST / 2.0, z * (d / 2.0 - 0.03))), float3_0, about))
    let eave = h + HOARD_POST
    for([ -1.0, 1.0 ]) side:  // the wall plates the roof sits on
        add_child(body, bld_roof_tag(bbox(bv(w + 0.04, 0.05, 0.05), wood, at + bv(0.0, eave, side * (d / 2.0 - 0.03))), about - bv(5.0, 0.0, 5.0)))
        add_child(body, bld_roof_tag(bbox(bv(0.05, 0.05, d + 0.04), wood, at + bv(side * (w / 2.0 - 0.03), eave, 0.0)), about - bv(5.0, 0.0, 5.0)))
    let rise = max(w, d) * 0.5
    let holder = mnode()
    holder.pos = at + bv(0.0, eave + 0.025 + rise / 2.0, 0.0)
    holder.scl = bv((w + 0.12) / 1.4142, 1.0, (d + 0.12) / 1.4142)
    add_child(body, holder)
    add_child(holder, bld_roof_tag(bcyl(0.0, 1.0, rise, bm(roof_name), float3_0, bv(0.0, 45.0, 0.0), 4), bv(-1.0, 0.0, -1.0)))

let BLD_LINKS = [ int2 { 1, 0 }, int2 { 1, 1 }, int2 { 0, 1 }, int2 { -1, 1 }, int2 { -1, 0 }, int2 { -1, -1 }, int2 { 0, -1 }, int2 { 1, -1 } ]

// Does the arm in direction k own the stake or merlon on its far edge?
def owns(k:int) -> bool:
    let d = BLD_LINKS[k]
    return d.x + d.y > 0 or (d.x + d.y == 0 and d.x > 0)

// An arm's holder, turned so its +x runs towards neighbour k; and its length.
def bld_arm(k:int) -> MNode, float:
    let d = BLD_LINKS[k]
    let holder = mnode()
    set_basis(holder, axis_angle(BLD_UP, atan2(float2 { float(d.x), -float(d.y) })))
    return holder, (if d.x == 0 or d.y == 0: 0.5 else: 0.70710678)

// A wall spec: the post as the body, the eight arms, and a short straight run for its picture (stakes: a
// palisade's, else the stone wall's).
def bld_wall_post(arch:string, stakes:bool) -> MNode: return if stakes: bld_stake_post(arch) else: bld_stone_post(arch)
def bld_wall_arm(arch:string, stakes:bool, k:int) -> MNode: return if stakes: bld_stake_arm(arch, k) else: bld_stone_arm(arch, k)

def bld_wall_spec(arch:string, stakes:bool, team:float3) -> BSpec:
    let arms = map(BLD_LINKS.length) k: bld_wall_arm(arch, stakes, k)
    let icon = mnode()
    add_child(icon, bld_wall_post(arch, stakes))
    add_child(icon, bld_wall_arm(arch, stakes, 0))
    add_child(icon, bld_wall_arm(arch, stakes, 4))
    let sp = bspec(bld_wall_post(arch, stakes))
    sp.arms = arms
    sp.icon = icon
    return bteam(sp, team)

// Stone Wall: the tall curtain, crenellated arms in the culture's stone, a walk along the top.
def bld_wall(arch:string, team:float3) -> BSpec:
    return bld_wall_spec(arch, false, team)

// Fortified Wall (the University's Fortified Walls, age 3): the same curtain raised on a sloped stone foot,
// faced in dressed blocks (earth walls are refaced in stone), a string course, stone corbels carrying a deeper
// parapet and buttress piers at the posts. Same height and walk as the Stone Wall, so lines and gates still meet.
def fort_stone(arch:string) -> string: return if wall_stone(arch) == "mud": "stone" else: wall_stone(arch)

def bld_fortified_wall(arch:string, team:float3) -> BSpec:
    let arms = map(BLD_LINKS.length) k: bld_fort_arm(arch, k)
    let icon = mnode()
    add_child(icon, bld_fort_post(arch))
    add_child(icon, bld_fort_arm(arch, 0))
    add_child(icon, bld_fort_arm(arch, 4))
    let sp = bspec(bld_fort_post(arch))
    sp.arms = arms
    sp.icon = icon
    return bteam(sp, team)

def fort_trim(arch:string) -> MMat: return bflat(if fort_stone(arch) == "brick": html("#8a5a44") else: html("#b8ad98"), 0.85)

def bld_fort_post(arch:string) -> MNode:
    let body = mnode()
    let m = bm(fort_stone(arch))
    let trim = fort_trim(arch)
    let h = bld_wh("fortified_wall")
    add_child(body, bbox(bv(WALL_D, h, WALL_D), m, bv(0.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(WALL_D - 0.24, 0.01, WALL_D - 0.24), bm("stone"), bv(0.0, h + 0.003, 0.0)))
    add_child(body, bbox(bv(WALL_D + 0.18, 0.22, WALL_D + 0.18), m, bv(0.0, 0.11, 0.0)))  // the sloped foot, in two steps
    add_child(body, bbox(bv(WALL_D + 0.09, 0.2, WALL_D + 0.09), m, bv(0.0, 0.32, 0.0)))
    for([ -1.0, 1.0 ]) z:  // a buttress pier on each face, capped in the trim stone
        add_child(body, bbox(bv(0.26, h * 0.78, 0.12), m, bv(0.0, h * 0.39, z * (WALL_D / 2.0 + 0.06))))
        add_child(body, bbox(bv(0.3, 0.06, 0.16), trim, bv(0.0, h * 0.78 + 0.03, z * (WALL_D / 2.0 + 0.06))))
    return body

def bld_fort_arm(arch:string, k:int) -> MNode:
    let body, l = bld_arm(k)
    let m = bm(fort_stone(arch))
    let trim = fort_trim(arch)
    let dark = bflat(html("#1e1a16"), 1.0)
    let h = bld_wh("fortified_wall")
    let right = bv(1.0, 0.0, 0.0)
    add_child(body, bbox(bv(l, h, WALL_D), m, bv(l / 2.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(l, 0.01, WALL_D - 0.24), bm("stone"), bv(l / 2.0, h + 0.003, 0.0)))  // the walk
    add_child(body, bbox(bv(l, 0.22, WALL_D + 0.18), m, bv(l / 2.0, 0.11, 0.0)))                 // the sloped foot
    add_child(body, bbox(bv(l, 0.2, WALL_D + 0.09), m, bv(l / 2.0, 0.32, 0.0)))
    for([ -1.0, 1.0 ]) z:
        add_child(body, bbox(bv(l, 0.05, 0.04), trim, bv(l / 2.0, h * 0.55, z * (WALL_D / 2.0 + 0.02))))  // the string course
        let n = max(1, int(roundf(l / 0.25)))
        for(n) c:  // the corbels under the parapet
            add_child(body, bbox(bv(0.07, 0.1, 0.08), trim, bv((float(c) + 0.5) * l / float(n), h - 0.1, z * (WALL_D / 2.0 + 0.04))))
        add_child(body, merlon(bv(l, 0.06, 0.08), trim, bv(l / 2.0, h - 0.02, z * (WALL_D / 2.0 + 0.04)), right))  // the parapet's lip, proud
        add_child(body, merlon(bv(l, 0.1, 0.14), m, bv(l / 2.0, h + 0.05, z * (WALL_D / 2.0 - 0.04)), right))
        bld_crenel(body, "stone", m, bv(0.2, 0.3, 0.14), bv(l / 2.0, h + 0.1, z * (WALL_D / 2.0 - 0.04)), right)
        if k == 0:  // an arrow loop with its cross slit
            add_child(body, bbox(bv(0.05, 0.3, 0.02), dark, bv(l * 0.5, h * 0.72, z * (WALL_D / 2.0 + 0.005))))
            add_child(body, bbox(bv(0.14, 0.04, 0.02), dark, bv(l * 0.5, h * 0.74, z * (WALL_D / 2.0 + 0.005))))
    return body

def bld_walk_mat(arch:string) -> MMat: return bm(if wall_stone(arch) != "mud": "stone" else: "wood")

def bld_stone_post(arch:string) -> MNode:
    let body = mnode()
    let m = bm(wall_stone(arch))
    let h = bld_wh("wall")
    add_child(body, bbox(bv(WALL_D, h, WALL_D), m, bv(0.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(WALL_D - 0.24, 0.01, WALL_D - 0.24), bld_walk_mat(arch), bv(0.0, h + 0.003, 0.0)))
    return body

def bld_stone_arm(arch:string, k:int) -> MNode:
    let body, l = bld_arm(k)
    let m = bm(wall_stone(arch))
    let h = bld_wh("wall")
    let mud = wall_stone(arch) == "mud"
    let right = bv(1.0, 0.0, 0.0)
    add_child(body, bbox(bv(l, h, WALL_D), m, bv(l / 2.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(l, 0.01, WALL_D - 0.24), bld_walk_mat(arch), bv(l / 2.0, h + 0.003, 0.0)))  // the walk
    for([ -1.0, 1.0 ]) z:
        add_child(body, bbox(bv(l, 0.16, 0.06), m, bv(l / 2.0, 0.08, z * (WALL_D / 2.0 + 0.03))))
        if not mud:
            add_child(body, merlon(bv(l, 0.08, 0.12), m, bv(l / 2.0, h + 0.04, z * (WALL_D / 2.0 - 0.06)), right))
        else:
            add_child(body, merlon(bv(l, 0.03, 0.03), bm("wood"), bv(l / 2.0, h + 0.15, z * (WALL_D / 2.0 - 0.06)), right))
        bld_crenel(body, arch, m, bv(0.18, 0.24, 0.12), bv(l / 2.0, h, z * (WALL_D / 2.0 - 0.06)), right)
    brng = grng(93 + k)
    if arch == "junk" and k == 5:  // a tin patch nailed over the brick
        add_child(body, bbox(bv(0.3, 0.3, 0.02), bm("tin"), bv(l * 0.5, h * 0.45, WALL_D / 2.0 + 0.01), bv(0.0, 0.0, 6.0)))
    elif mud:  // field stones pressed into the earth
        for(2) n:
            let side = if n == 0: 1.0 else: -1.0
            let px = randf_range(brng, 0.1, l - 0.1)
            let py = randf_range(brng, 0.2, h - 0.25)
            add_child(body, bball(0.08, bm("stone"), bv(px, py, (WALL_D / 2.0) * side), bv(1.2, 0.8, 0.6)))
    elif k == 0:  // an arrow loop down each face, once a tile
        for([ -1.0, 1.0 ]) z:
            add_child(body, bbox(bv(0.05, 0.28, 0.02), bflat(html("#1e1a16"), 1.0), bv(l * 0.5, h * 0.55, z * (WALL_D / 2.0 + 0.005))))
    return body

// Palisade Wall: sharpened stakes and two lashed rails, with the culture's touch.
def bld_palisade(arch:string, team:float3) -> BSpec:
    return bld_wall_spec(arch, true, team)

def bld_stake_post(arch:string) -> MNode:
    let body = mnode()
    brng = grng(91)
    bld_stake(body, float3_0, 0.88, bm("wood"), 0.095)
    bld_palisade_dress(body, arch, [ float3_0 ], 0.0)
    return body

def bld_stake_arm(arch:string, k:int) -> MNode:
    let body, l = bld_arm(k)
    let wood = bm("wood")
    brng = grng(101 + k)
    let n = if l < 0.6: 3 else: 4
    let spots = []::float3
    for(n + (if owns(k): 1 else: 0) - 1) j1:
        let j = j1 + 1
        spots.push(bv(l * float(j) / float(n), 0.0, 0.1))
    for(n) j:
        spots.push(bv(l * (float(j) + 0.5) / float(n), 0.0, -0.1))
    for(spots) p:
        bld_stake(body, p, randf_range(brng, 0.72, 0.86), wood)
    for([ 0.25, 0.55 ]) y:
        for([ -0.18, 0.18 ]) z:  // rails lashed on both faces
            add_child(body, bbox(bv(l, 0.04, 0.04), wood, bv(l / 2.0, y, z)))
    bld_palisade_dress(body, arch, spots, l, k)
    return body

// One sharpened stake, leaning a touch.
def bld_stake(body:MNode, at:float3, h:float, wood:MMat, r:float = 0.08):
    let p = at + bv(0.0, h / 2.0, 0.0)
    let rx = randf_range(brng, -3.0, 3.0)
    let rz = randf_range(brng, -3.0, 3.0)
    add_child(body, bcyl(r, r + 0.01, h, wood, p, bv(rx, 0.0, rz), 8))
    add_child(body, bcyl(0.0, r, 0.13, wood, p + bv(0.0, h / 2.0 + 0.065, 0.0), float3_0, 8))

// A culture's touch on a stretch of stake fence `l` long along x (0: the post), its stakes at `spots`.
def bld_palisade_dress(body:MNode, arch:string, spots:[float3], l:float, k:int = 0):
    let run = max(l, 0.24)
    let mid = bv(l / 2.0, 0.0, 0.0)
    switch arch:
        case "stone":  // a dry-stone footing the stakes are set in
            add_child(body, bbox(bv(run, 0.14, 0.46), bm("stone"), mid + bv(0.0, 0.07, 0.0)))
        case "junk":  // tin sheets nailed on where the stakes ran short (a few arms only)
            if l > 0.0 and (k == 1 or k == 5):
                add_child(body, bbox(bv(0.3, 0.24, 0.02), bm("tin"), mid + bv(0.0, 0.42, 0.2), bv(0.0, 0.0, 8.0)))
        case "reed":  // every stake bound with reed at two heights
            for(spots) p:
                for([ 0.3, 0.6 ]) y:
                    add_child(body, bcyl(0.1, 0.1, 0.06, bm("thatch"), p + bv(0.0, y, 0.0), float3_0, 8))
        case "tent":  // a felt strip along the top rail
            if l > 0.0:
                add_child(body, bbox(bv(l, 0.08, 0.03), bm("felt"), mid + bv(0.0, 0.6, 0.2)))
        case "mound":  // an earth bank heaped against the foot
            add_child(body, bbox(bv(run, 0.2, 0.56), bm("mud"), mid + bv(0.0, 0.08, 0.0)))
        default: pass()

// Palisade Gate, closed in body, open in open.
let GATE_POST = 0.14
let GATE_POST_R = 0.13
let GATE_TOP = 1.16

def bld_palisade_gate(arch:string, team:float3) -> BSpec:
    let sp = bspec(bld_stake_gate(arch, team, false))
    sp.open = bld_stake_gate(arch, team, true)
    return bteam(sp, team)

def bld_stake_gate(arch:string, team:float3, open:bool) -> MNode:
    let body = mnode()
    brng = grng(95)
    let wood = bm("wood")
    let post = gate_span / 2.0 - GATE_POST
    let posts = [ bv(-post, 0.0, 0.0), bv(post, 0.0, 0.0) ]
    for(posts) p, k:  // the gate posts, propped from behind: parts of their own, each sorted at its own footprint (ArtKit)
        let part = mnode()
        part.meta = "gate_part {k * 2 - 1} gate_centre {p.x} 0.0 0.0"
        add_child(body, part)
        add_child(part, bcyl(GATE_POST_R, GATE_POST_R + 0.01, GATE_TOP + 0.13, wood, p + bv(0.0, (GATE_TOP + 0.13) / 2.0, 0.0), float3_0, 10))
        add_child(part, bcyl(0.0, GATE_POST_R, 0.16, wood, p + bv(0.0, GATE_TOP + 0.21, 0.0), float3_0, 10))  // its point
        add_child(part, beam(p + bv(0.0, 0.0, -0.42), p + bv(0.0, 0.72, -GATE_POST_R + 0.02), 0.045, wood))   // a prop
    let over = mnode()                                                                                        // the beam and banner over the passage: a part at the gate's middle (a unit in front of it over it, behind under it)
    over.meta = "gate_part 2 gate_centre 0.0 0.0 0.0"
    add_child(body, over)
    add_child(over, bbox(bv(2.0 * (post - GATE_POST_R), 0.13, 0.17), wood, bv(0.0, GATE_TOP + 0.065, 0.0)))  // (ends at each post: a model stops before the next)
    for([ -1.0, 1.0 ]) side:
        add_child(over, beam(bv(side * (post - GATE_POST_R + 0.02), GATE_TOP - 0.36, 0.0), bv(side * (post - 0.46), GATE_TOP + 0.01, 0.0), 0.035, wood))
    let batten = GATE_TOP - 0.08
    for([ -0.2, 0.2 ]) x:
        add_child(over, beam(bv(x, GATE_TOP + 0.01, 0.07), bv(x, batten, 0.07), 0.012, bm("thatch"), 4))
    add_child(over, bbox(bv(0.52, 0.04, 0.04), wood, bv(0.0, batten, 0.07)))
    add_child(over, bbox(bv(0.44, 0.32, 0.02), bcloth(team), bv(0.0, batten - 0.18, 0.07)))
    let leaf_w = post - GATE_POST_R
    for([ -1.0, 1.0 ]) side:
        let leaf = mnode()  // hinged on its post; it swings back when open
        leaf.pos = bv(side * leaf_w, 0.0, 0.0)
        leaf.rot = bv(0.0, if open: 90.0 * -side else: 0.0, 0.0)
        add_child(body, leaf)
        for(int(leaf_w / 0.12)) k:
            let x = -side * (0.06 + float(k) * 0.12)
            add_child(leaf, bcyl(0.05, 0.055, 0.76, wood, bv(x, 0.4, 0.0), float3_0, 6))
            add_child(leaf, bcyl(0.0, 0.05, 0.1, wood, bv(x, 0.83, 0.0), float3_0, 6))
        for([ 0.22, 0.6 ]) y:
            add_child(leaf, bbox(bv(leaf_w - 0.05, 0.05, 0.03), wood, bv(-side * (leaf_w / 2.0 - 0.015), y, 0.05)))
        add_child(leaf, beam(bv(-side * 0.05, 0.22, 0.06), bv(-side * (leaf_w - 0.11), 0.6, 0.06), 0.022, wood))  // a brace across
    for(posts) p, k:                                                                                              // the culture's touch at each post's foot (of the post's part: no centre, it has one)
        let part = mnode()
        part.meta = "gate_part {k * 2 - 1}"
        add_child(body, part)
        let foot = mnode()
        foot.pos = p
        bld_palisade_dress(foot, arch, [ float3_0 ], 0.0)
        add_child(part, foot)
        if arch == "reed":
            for([ 0.3, 0.6, 0.95 ]) y:
                add_child(part, bcyl(GATE_POST_R + 0.025, GATE_POST_R + 0.025, 0.06, bm("thatch"), p + bv(0.0, y, 0.0), float3_0, 8))
    return body

// Wall Tower: a square tower filling its tile, a storey over the walk, the hoarding and a hipped roof.
def bld_wall_tower(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let m = bm(wall_stone(arch))
    let h = bld_wh("wall_tower")
    let dark = bflat(html("#1e1a16"), 1.0)
    add_child(body, bbox(bv(TOWER_W, h, TOWER_W), m, bv(0.0, h / 2.0, 0.0)))
    add_child(body, bbox(bv(TOWER_W - 0.2, 0.01, TOWER_W - 0.2), bld_walk_mat(arch), bv(0.0, h + 0.003, 0.0)))  // its floor
    let about = bv(0.0, h, 0.0)
    for([ -1.0, 1.0 ]) side:  // a corbel band under the hoarding
        add_child(body, parapet(bbox(bv(TOWER_W + 0.04, 0.1, 0.04), m, bv(0.0, h - 0.07, side * (TOWER_W / 2.0))), float3_0, about))
        add_child(body, parapet(bbox(bv(0.04, 0.1, TOWER_W + 0.04), m, bv(side * (TOWER_W / 2.0), h - 0.07, 0.0)), float3_0, about))
    add_child(body, parapet(bbox(bv(TOWER_W, h - 0.02, 0.002), m, bv(0.0, (h - 0.02) / 2.0, TOWER_W / 2.0 + 0.001)), float3_0, about))
    add_child(body, parapet(bbox(bv(0.002, h - 0.02, TOWER_W), m, bv(TOWER_W / 2.0 + 0.001, (h - 0.02) / 2.0, 0.0)), float3_0, about))
    for([ h * 0.32, h * 0.62 ]) y:  // arrow loops on the two faces towards the camera
        add_child(body, parapet(bbox(bv(0.06, 0.26, 0.02), dark, bv(0.0, y, TOWER_W / 2.0 + 0.005)), float3_0, about))
        add_child(body, parapet(bbox(bv(0.02, 0.26, 0.06), dark, bv(TOWER_W / 2.0 + 0.005, y, 0.0)), float3_0, about))
    add_child(body, parapet(bbox(bv(0.26, 0.36, 0.02), bcloth(team), bv(-0.2, h - 0.34, TOWER_W / 2.0 + 0.03)), float3_0, about))
    bld_tower_top(body, arch, float3_0, TOWER_W, TOWER_W, h)
    return bteam(bspec(body), team)

// Siege Ladder (placeholder): two rails and rungs leaning towards -x onto the next tile's wall face.
def bld_ladder(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let h = bld_wh("wall") + 0.2
    let head = bv(-(1.0 - WALL_D / 2.0 - 0.02), h, 0.0)
    for([ -0.14, 0.14 ]) z:
        add_child(body, beam(bv(0.0, 0.0, z), head + bv(0.0, 0.0, z), 0.03, wood, 6))
    let rungs = int(h / 0.14)
    for(rungs) k1:
        let k = k1 + 1
        add_child(body, bbox(bv(0.03, 0.03, 0.3), wood, head * (float(k) / float(rungs + 1))))
    add_child(body, bbox(bv(0.02, 0.14, 0.1), bcloth(team), head * 0.8 + bv(0.0, 0.0, 0.17)))
    return bteam(bspec(body), team)

// Wall tower looks: squat (the one in play), drum, hoard.
def bld_wall_tower_look(name:string, arch:string, team:float3) -> BSpec:
    if name == "squat": return bld_wall_tower(arch, team)
    let body = mnode()
    let m = bm(wall_stone(arch))
    let wood = bm("wood")
    let dark = bflat(html("#1e1a16"), 1.0)
    if name == "drum":
        let h = 1.35
        add_child(body, bcyl(0.46, 0.5, h, m, bv(0.0, h / 2.0, 0.0), float3_0, 14))
        for(8) k:
            let a = TAU * float(k) / 8.0
            add_child(body, bbox(bv(0.14, 0.16, 0.14), m, bv(rcos(a) * 0.4, h + 0.08, rsin(a) * 0.4)))
        add_child(body, bbox(bv(0.03, 0.24, 0.07), dark, bv(0.49, 0.8, 0.0)))
        add_child(body, bbox(bv(0.07, 0.24, 0.03), dark, bv(0.0, 0.8, 0.49)))
        add_child(body, bbox(bv(0.22, 0.3, 0.02), bcloth(team), bv(-0.15, h - 0.25, 0.47)))
    else:
        let h = 1.55
        add_child(body, bbox(bv(0.8, h, 0.8), m, bv(0.0, h / 2.0, 0.0)))
        add_child(body, bbox(bv(1.02, 0.34, 1.02), wood, bv(0.0, h + 0.1, 0.0)))  // the hoarding
        for([ -0.45, 0.45 ]) x:
            for([ -0.45, 0.45 ]) z:
                add_child(body, bbox(bv(0.05, 0.4, 0.05), wood, bv(x, h - 0.12, z)))
        add_child(body, bcyl(0.0, 0.78, 0.5, bld_roof_mat(bkit(arch)), bv(0.0, h + 0.52, 0.0), bv(0.0, 45.0, 0.0), 4))
        add_child(body, bbox(bv(0.07, 0.24, 0.03), dark, bv(0.0, 0.8, 0.41)))
        add_child(body, bbox(bv(0.24, 0.32, 0.02), bcloth(team), bv(0.2, h - 0.15, 0.52)))
    return bteam(bspec(body), team)

// Ladder looks: plain (the one in play), hooked, mantlet.
def bld_ladder_look(name:string, arch:string, team:float3) -> BSpec:
    let spec = bld_ladder(arch, team)
    if name == "plain": return spec
    let body = spec.body
    let iron = bflat(html("#4a4c50"), 0.5, 0.7)
    if name == "hooked":
        for([ -0.14, 0.14 ]) z:
            add_child(body, bbox(bv(0.12, 0.03, 0.03), iron, bv(-0.3, 1.04, z)))
            add_child(body, bbox(bv(0.03, 0.08, 0.03), iron, bv(-0.36, 1.0, z)))
        add_child(body, bcyl(0.012, 0.012, 0.9, bflat(html("#c8b48a"), 0.9), bv(0.1, 0.5, 0.2), bv(0.0, 0.0, 20.0), 5))
    else:
        let wicker = bm("weave")
        add_child(body, bbox(bv(0.06, 0.62, 0.62), wicker, bv(0.28, 0.36, 0.0), bv(0.0, 0.0, -8.0)))
        for([ -0.26, 0.26 ]) z:
            add_child(body, bbox(bv(0.04, 0.5, 0.04), bm("wood"), bv(0.42, 0.22, z), bv(0.0, 0.0, 25.0)))
    return spec

// A breach's rubble: heap or stub.
def bld_wall_rubble_look(name:string, arch:string, team:float3) -> BSpec:
    let body = mnode()
    let m = bm(wall_stone(arch))
    brng = grng(1600)
    if name == "stub":
        add_child(body, bbox(bv(0.6, 0.22, 0.5), m, bv(0.0, 0.11, 0.0)))
        add_child(body, bbox(bv(0.3, 0.16, 0.3), m, bv(0.12, 0.3, -0.05), bv(0.0, 20.0, 8.0)))
    for(if name == "heap": 9 else: 6):
        let ax = randf_range(brng, -0.42, 0.42)
        let az = randf_range(brng, -0.42, 0.42)
        let at = bv(ax, 0.05, az)
        let sz = randf_range(brng, 0.1, 0.2)
        let rx = randf_range(brng, -20.0, 20.0)
        let ry = randf_range(brng, 0.0, 90.0)
        let rz = randf_range(brng, -20.0, 20.0)
        add_child(body, bbox(bv(sz, sz * 0.7, sz), m, at + bv(0.0, sz * 0.3, 0.0), bv(rx, ry, rz)))
    if name == "heap":
        add_child(body, bbox(bv(0.7, 0.1, 0.6), m, bv(0.0, 0.04, 0.0), bv(0.0, 10.0, 0.0)))
    return bteam(bspec(body), team)

def bld_stone_gate(arch:string, team:float3) -> BSpec:
    let sp = bspec(bld_gatehouse(arch, team, false))
    sp.open = bld_gatehouse(arch, team, true)
    return bteam(sp, team)

// Fortified Gate: the gatehouse on the fortified wall's sloped foot, refaced in stone, with an iron portcullis
// (down behind the shut leaves, up in the passage's head when open) and a trim band at the walk.
def bld_fortified_gate(arch:string, team:float3) -> BSpec:
    let sp = bspec(bld_fort_gatehouse(arch, team, false))
    sp.open = bld_fort_gatehouse(arch, team, true)
    return bteam(sp, team)

def bld_fort_gatehouse(arch:string, team:float3, open:bool) -> MNode:
    let body = bld_gatehouse(if wall_stone(arch) == "mud": "stone" else: arch, team, open)
    let m = bm(fort_stone(arch))
    let trim = fort_trim(arch)
    let iron = bflat(html("#3e4044"), 0.5, 0.7)
    let h = bld_wh("fortified_gate")
    let half = gate_span / 2.0
    let inner = half - GATE_TOWER_W
    let arch_h = GATE_ARCH * wall_rescale
    for([ -1, 1 ]) side:  // the foot under each tower
        let cx = float(side) * (half - GATE_TOWER_W / 2.0)
        add_child(body, bbox(bv(GATE_TOWER_W + 0.16, 0.24, GATE_TOWER_D + 0.16), m, bv(cx, 0.12, 0.0)))
    for([ -1.0, 1.0 ]) z:
        add_child(body, bbox(bv(2.0 * inner, 0.06, 0.05), trim, bv(0.0, h - 0.03, z * (WALL_D / 2.0 + 0.05))))
    let pz = -WALL_D / 2.0 + 0.12
    let py = if open: arch_h - 0.12 else: 0.0
    let ph = if open: 0.1 else: arch_h - 0.02
    let bars = max(4, int(roundf(2.0 * inner / 0.14)))
    for(bars) i:
        add_child(body, bbox(bv(0.03, ph, 0.03), iron, bv(-inner + (float(i) + 0.5) * 2.0 * inner / float(bars), py + ph / 2.0, pz)))
    if not open:
        for([ 0.3, 0.65 ]) f:
            add_child(body, bbox(bv(2.0 * inner, 0.03, 0.03), iron, bv(0.0, arch_h * f, pz)))
    return body

// Stone Gate, built into the wall: the curtain over the passage, flanking towers, the iron-banded leaves.
def bld_gatehouse(arch:string, team:float3, open:bool) -> MNode:
    let body = mnode()
    let m = bm(wall_stone(arch))
    let wood = bm("wood")
    let iron = bflat(html("#4a4c50"), 0.5, 0.7)
    let dark = bflat(html("#1e1a16"), 1.0)
    let mud = wall_stone(arch) == "mud"
    let h = bld_wh("stone_gate")
    let ht = bld_wh("wall_tower")
    let half = gate_span / 2.0
    let inner = half - GATE_TOWER_W
    let arch_h = GATE_ARCH * wall_rescale
    let right = bv(1.0, 0.0, 0.0)
    add_child(body, bbox(bv(2.0 * inner, h - arch_h, WALL_D), m, bv(0.0, (arch_h + h) / 2.0, 0.0)))
    add_child(body, bbox(bv(2.0 * inner, 0.01, WALL_D - 0.24), bld_walk_mat(arch), bv(0.0, h + 0.003, 0.0)))  // the walk's floor over the passage
    for([ -1.0, 1.0 ]) z:
        add_child(body, bbox(bv(2.0 * inner, 0.05, 0.04), if not mud: bm("stone") else: wood, bv(0.0, arch_h + 0.025, z * (WALL_D / 2.0 - 0.02))))  // the lintel's soffit
        if not mud:
            add_child(body, merlon(bv(2.0 * inner, 0.08, 0.12), m, bv(0.0, h + 0.04, z * (WALL_D / 2.0 - 0.06)), right))
        else:
            add_child(body, merlon(bv(2.0 * inner, 0.03, 0.03), wood, bv(0.0, h + 0.15, z * (WALL_D / 2.0 - 0.06)), right))
        let n = max(2, int(roundf(2.0 * inner / 0.5)))
        for(n) k:
            bld_crenel(body, arch, m, bv(0.18, 0.24, 0.12), bv(-inner + (float(k) + 0.5) * 2.0 * inner / float(n), h, z * (WALL_D / 2.0 - 0.06)), right)
        add_child(body, bbox(bv(2.0 * inner - 0.1, 0.08, 0.08), m, bv(0.0, h - 0.1, z * (WALL_D / 2.0 + 0.04))))
        for(n * 2) k:
            add_child(body, bbox(bv(0.06, 0.12, 0.07), m, bv(-inner + 0.05 + (float(k) + 0.5) * (2.0 * inner - 0.1) / float(n * 2), h - 0.2, z * (WALL_D / 2.0 + 0.035))))
    let tl = GATE_TOWER_W
    let proud = (GATE_TOWER_D - WALL_D) / 2.0
    for([ -1, 1 ]) side:
        let cx = float(side) * (half - tl / 2.0)
        let tower = mnode()  // a part of its own: ArtKit bakes it apart
        tower.meta = "gate_part {side} gate_centre {cx} 0.0 0.0"
        add_child(body, tower)
        bld_gate_tower(tower, arch, cx, tl, ht, proud, m, dark)
    add_child(body, bbox(bv(0.46, 0.03, 0.03), wood, bv(0.0, h - 0.27, WALL_D / 2.0 + 0.03)))
    add_child(body, bbox(bv(0.36, 0.3, 0.02), bcloth(team), bv(0.0, h - 0.43, WALL_D / 2.0 + 0.03)))
    let leaf_w = inner
    let leaf_z = WALL_D / 2.0 - 0.08
    for([ -1.0, 1.0 ]) side:
        let leaf = mnode()
        leaf.pos = bv(side * inner, 0.0, leaf_z)
        leaf.rot = bv(0.0, if open: 90.0 * -side else: 0.0, 0.0)
        add_child(body, leaf)
        add_child(leaf, bbox(bv(leaf_w, arch_h - 0.02, 0.08), wood, bv(-side * leaf_w / 2.0, (arch_h - 0.02) / 2.0, -0.04)))
        for([ arch_h * 0.2, arch_h * 0.7 ]) y:
            add_child(leaf, bbox(bv(leaf_w, 0.05, 0.02), iron, bv(-side * leaf_w / 2.0, y, 0.005)))
        add_child(leaf, bball(0.035, iron, bv(-side * (leaf_w - 0.14), arch_h * 0.46, 0.01)))  // the ring pull
    return body

// One of a gatehouse's flanking towers, its middle at x = cx.
def bld_gate_tower(body:MNode, arch:string, cx:float, tl:float, ht:float, proud:float, m:MMat, dark:MMat):
    let right = bv(1.0, 0.0, 0.0)
    add_child(body, bbox(bv(tl, ht, WALL_D), m, bv(cx, ht / 2.0, 0.0)))
    add_child(body, merlon(bv(tl, ht, proud), m, bv(cx, ht / 2.0, WALL_D / 2.0 + proud / 2.0), right))  // the near half
    add_child(body, bbox(bv(tl, ht, proud), m, bv(cx, ht / 2.0, -WALL_D / 2.0 - proud / 2.0)))
    add_child(body, bbox(bv(tl - 0.2, 0.01, GATE_TOWER_D - 0.2), bld_walk_mat(arch), bv(cx, ht + 0.003, 0.0)))                 // its floor
    add_child(body, merlon(bv(tl + 0.04, 0.1, 0.02 + proud), m, bv(cx, ht - 0.07, WALL_D / 2.0 + proud / 2.0 + 0.02), right))  // the corbel band, near
    add_child(body, bbox(bv(tl + 0.04, 0.1, WALL_D + proud + 0.02), m, bv(cx, ht - 0.07, -proud / 2.0 - 0.01)))
    for([ ht * 0.3, ht * 0.62 ]) y:  // arrow loops on the tower's front
        add_child(body, merlon(bv(0.06, 0.24, 0.02), dark, bv(cx, y, GATE_TOWER_D / 2.0 + 0.005), right))
    bld_tower_top(body, arch, bv(cx, 0.0, 0.0), tl, GATE_TOWER_D, ht)

// ------------------------------------------------------------------ the entry points

// A building's model: its own function if it has one (barracks_reed...), else the type's builder in this
// architecture (models.gd building). Also the outpost looks by name (outpost_pole...). nil: no such type.
def building(type:string, arch0:string, team:float3) -> BSpec?:
    if arch0 == "future":
        switch type:
            case "barracks": return future_barracks(team)
            case "watchtower": return future_tower(team)
            case "mill": return future_mill(team)
            case "mining_camp": return future_mining_camp(team)
            case "lumber_camp": return future_lumber_camp(team)
            case "armoury": return future_armoury(team)
            default: pass()
    let arch = if arch0 == "future": "stone" else: arch0  // (the future's other buildings: stone's, until they have their own)
    switch type:
        case "barracks": return bld_barracks(arch, team)
        case "stable": return bld_stable(arch, team)
        case "watchtower": return bld_tower(arch, team)
        case "wonder":
            switch arch:
                case "stone": return wonder_stone(team)
                case "thatch": return wonder_thatch(team)
                case "junk": return wonder_junk(team)
                case "tent": return wonder_tent(team)
                case "reed": return wonder_reed(team)
                case "mound": return wonder_mound(team)
                default: return nil
        case "archery_range": return bld_archery_range(arch, team)
        case "armoury": return bld_armoury(arch, team)
        case "pen": return bld_pen(arch, team)
        case "lumber_camp": return bld_lumber_camp(arch, team)
        case "mill": return bld_mill(arch, team)
        case "mining_camp": return bld_mining_camp(arch, team)
        case "market": return bld_market(arch, team)
        case "siege_workshop": return bld_siege_workshop(arch, team)
        case "university": return bld_university(arch, team)
        case "castle": return bld_castle(arch, team)
        case "wall": return bld_wall(arch, team)
        case "palisade": return bld_palisade(arch, team)
        case "palisade_gate": return bld_palisade_gate(arch, team)
        case "stone_gate": return bld_stone_gate(arch, team)
        case "fortified_wall": return bld_fortified_wall(arch, team)
        case "fortified_gate": return bld_fortified_gate(arch, team)
        case "wall_tower": return bld_wall_tower(arch, team)
        case "ladder": return bld_ladder(arch, team)
        case "outpost": return bld_outpost(arch, team)
        case "outpost_pole": return bld_outpost_pole(arch, team)
        case "outpost_deck": return bld_outpost_deck(arch, team)
        case "outpost_beacon": return bld_outpost_beacon(arch, team)
        case "bastion": return bld_bastion(arch, team)
        default: return nil

// A building type's model in one of its concept looks (models.gd look: the building sheet's type:arch:look).
def look(type:string, arch:string, name:string, team:float3) -> BSpec?:
    switch type:
        case "castle": return bld_castle_look(name, arch, team)
        case "university": return bld_university_look(name, arch, team)
        case "pen": return bld_pen_look(name, arch, team)
        case "wall_tower": return bld_wall_tower_look(name, arch, team)
        case "ladder": return bld_ladder_look(name, arch, team)
        case "wall_rubble": return bld_wall_rubble_look(name, arch, team)
        default: return nil

// A named builder (models.call(name, team): the town centres, houses, the farm, age looks, concepts).
def model_by_name(name:string, team:float3) -> BSpec?:
    switch name:
        case "town_center": return town_center(team)
        case "stilt_house": return stilt_house(team)
        case "junk_town_center": return junk_town_center(team)
        case "junk_town_center_small": return junk_town_center_small(team)
        case "junk_town_center_pride": return junk_town_center_pride(team)
        case "tin_can_house": return tin_can_house(team)
        case "stone_town_center": return stone_town_center(team)
        case "villa_house": return villa_house(team)
        case "tent_town_center": return tent_town_center(team)
        case "tent_house": return tent_house(team)
        case "farm_plot": return farm_plot(team)
        case "reed_house": return reed_house(team)
        case "reed_town_center": return reed_town_center(team)
        case "mound_house": return mound_house(team)
        case "mound_town_center": return mound_town_center(team)
        case "future_town_center": return future_town_center(team)
        case "future_house": return future_house(team)
        case "concept_junk_tc_small": return concept_junk_tc_small(team)
        case "concept_junk_tc_low": return concept_junk_tc_low(team)
        case "concept_junk_tc_berm": return concept_junk_tc_berm(team)
        case "concept_pen_hurdles": return concept_pen_hurdles(team)
        case "concept_pen_rails": return concept_pen_rails(team)
        case "concept_pen_wall": return concept_pen_wall(team)
        case "wonder_stone": return wonder_stone(team)
        case "wonder_thatch": return wonder_thatch(team)
        case "wonder_junk": return wonder_junk(team)
        case "wonder_tent": return wonder_tent(team)
        case "wonder_reed": return wonder_reed(team)
        case "wonder_mound": return wonder_mound(team)
        default:  // barracks_thatch, stable_stone, watchtower_tent...: the type and its architecture
            let last = find_string_reverse(name, "_")
            if last < 0: return nil
            return building(name.substring(0, last), name.substring(last + 1, name.length - last - 1), team)

// The model function for a building type in an architecture (ArtKit._model: TOWN, HOUSE, farm_plot, type_arch).
def building_model(arch:string, type:string) -> string:
    switch type:
        case "town_center":
            switch arch:
                case "junk": return "junk_town_center_small"
                case "stone": return "stone_town_center"
                case "tent": return "tent_town_center"
                case "reed": return "reed_town_center"
                case "mound": return "mound_town_center"
                case "future": return "future_town_center"
                default: return "town_center"
        case "house":
            switch arch:
                case "junk": return "tin_can_house"
                case "stone": return "villa_house"
                case "tent": return "tent_house"
                case "reed": return "reed_house"
                case "mound": return "mound_house"
                case "future": return "future_house"
                default: return "stilt_house"
        case "farm": return "farm_plot"
        default: return type + "_" + arch

// A building's model spec as ArtKit._spec makes it: by model name when given (an age look), the town centre,
// house and farm by name, the rest by type and culture.
def building_spec(arch:string, type:string, team:float3, model:string = "") -> BSpec?:
    if model != "": return model_by_name(model, team)
    if type == "town_center" or type == "house" or type == "farm": return model_by_name(building_model(arch, type), team)
    return building(type, arch, team)

// not ported (concept-only, not reachable from building(), look() or the game): models.gd's reeds, bug_bush
// (the props' own are model/props.lobster's), concept_rat_house_can_side, concept_rat_house_stack,
// concept_rat_house_reel, concept_rat_barracks_sardine, concept_rat_barracks_crates, concept_rat_barracks_drain.
