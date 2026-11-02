// ------------------------------------------------------------------ trees (scenes/art_pixel/tree_models.gd)
// Three tree_kind (broadleaf, pine, swamp), each in three looks (`style` 0-2), and `stage` 0-3 (standing, felled,
// half sawn, the stump), in world units, each function tree_models.gd's of the same name (`_card_crown` ->
// tree_card_crown: its private helpers carry the file's name), line for line; its comments are there. Seeded with
// Godot's RandomNumberGenerator, drawn in the same order.

let TREE_SPECIES = [ "broadleaf", "pine", "swamp" ]
let TREE_VIEW_UP = float3 { 0.25, 0.8, 0.45 }

var tree_rng = grng(0)

def tree_species_index(tree_kind:string) -> int:  // SPECIES.find
    for(TREE_SPECIES) s, i:
        if s == tree_kind: return i
    return -1

class TreeLook:
    height:float
    trunk:float
    bark:float3
    leaf:float3
    plain:bool

class TreeLobe:
    c:float3
    r:float3

def tree(seed_value:int, tree_kind:string, style:int = 0, stage:int = 0) -> MNode:
    tree_rng = grng(seed_value * 31 + tree_species_index(tree_kind) * 7 + style)
    let rng = tree_rng
    let size = randf_range(rng, 0.88, 1.12)
    let lx = randf_range(rng, -0.06, 0.06)
    let lz = randf_range(rng, -0.06, 0.06)
    let lean = float3 { lx, 0.0, lz }
    let fall = randf(rng) * TAU
    let n = mnode()
    let look = tree_look(tree_kind, style)
    let h = look.height * size
    if stage == 0:
        add_child(n, tree_standing(tree_kind, style, size, lean, look))
    else:
        add_child(n, tree_stump(look, size))
        if stage < 3: add_child(n, tree_felled(look, size, h, fall, stage))
    return n

def tree_look(tree_kind:string, style:int) -> TreeLook:
    switch tree_kind:
        case "pine":
            return TreeLook { [ 2.3, 2.2, 2.6 ][style], 0.085, [ float3 { 1.0, 1.0, 1.15 }, float3 { 0.9, 0.95, 1.1 }, float3 { 1.25, 1.0, 0.9 } ][style],
                              float3 { 0.32, 0.46, 0.34 }, false }
        case "swamp":
            return TreeLook { [ 2.4, 1.9, 2.0 ][style], [ 0.11, 0.1, 0.09 ][style], [ float3 { 1.2, 1.15, 1.25 }, float3 { 1.0, 1.05, 1.2 }, float3 { 1.35, 1.4, 1.5 } ][style],
                              [ float3 { 0.7, 0.72, 0.4 }, float3 { 0.6, 0.72, 0.4 }, float3 { 0.45, 0.56, 0.36 } ][style], false }
        default:
            return TreeLook { [ 2.1, 2.1, 2.3 ][style], [ 0.1, 0.1, 0.06 ][style], [ float3 { 1.05, 1.1, 1.3 }, float3 { 1.05, 1.1, 1.3 }, html("#e8e2d4") ][style],
                              [ float3 { 0.5, 0.6, 0.38 }, float3 { 0.5, 0.6, 0.38 }, float3 { 0.66, 0.74, 0.4 } ][style], style == 2 }

def tree_bark(look:TreeLook) -> MMat: return if look.plain: plain(look.bark) else: surf("bark_plate", look.bark, 2.0)

def tree_standing(tree_kind:string, style:int, size:float, lean:float3, look:TreeLook) -> MNode:
    let rng = tree_rng
    let n = mnode()
    let h = look.height * size
    let bark = tree_bark(look)
    let r = look.trunk * size
    switch tree_kind + "{style}":
        case "broadleaf0", "broadleaf1":
            let top = float3 { 0.0, h * 0.5, 0.0 } + lean * h
            tree_trunk(n, float3_0, top, r, bark)
            for(3):
                let a = randf(rng) * TAU
                let by = randf_range(rng, 0.15, 0.35)
                add_child(n, rod(top * 0.85, top + float3 { rcos(a) * 0.3, by, rsin(a) * 0.3 } * size, r * 0.6, r * 0.3, bark, false))
            let lobes = tree_lobes(top + float3 { 0.0, 0.5 * size, 0.0 }, 0.4 * size, 0.42 * size, randi_range(rng, 6, 8))
            if style == 0: tree_card_crown(n, lobes, "leaf", 0.12 * size, 1500, look.leaf)
            else: tree_painted_crown(n, lobes, look.leaf, 0.13 * size)
        case "broadleaf2":
            for(randi_range(rng, 1, 2)) k:
                let ox = randf_range(rng, -0.14, 0.14)
                let oz = randf_range(rng, -0.14, 0.14)
                let off = float3 { ox, 0.0, oz } * float(k)
                let top = off + float3 { 0.0, h * 0.8, 0.0 } + lean * h * (1.0 + float(k))
                tree_trunk(n, off, top, r, bark)
                for(6):
                    let t = randf_range(rng, 0.1, 0.8)
                    add_child(n, blob(float3 { r * 1.04, 0.012, r * 1.04 }, plain(html("#2a2420")), lerp(off, top, t)))
                let lobes = tree_lobes(lerp(off, top, 0.8), 0.22 * size, 0.3 * size, 6)
                tree_card_crown(n, lobes, "leaf", 0.09 * size, 900, look.leaf)
        case "pine0":
            tree_trunk(n, float3_0, float3 { 0.0, h * 0.82, 0.0 } + lean * h, r, bark)
            let tiers = 10
            for(tiers) t:
                let f = float(t) / float(tiers)
                let y = lerpf(0.35, 0.95, f) * h
                let spread = lerpf(0.62, 0.1, f) * size
                let at = float3 { 0.0, y, 0.0 } + lean * y
                let cards = int(lerpf(90.0, 18.0, f))
                for(cards) k:
                    let a = float(k) / float(cards) * TAU + randf_range(rng, -0.2, 0.2)
                    let out = float3 { rcos(a), 0.0, rsin(a) }
                    let len = spread * randf_range(rng, 0.8, 1.15)
                    let down = normalize(out + float3 { 0.0, -0.45, 0.0 })
                    let mid = at + down * len * 0.5
                    let shade = clamp(f * 0.6 + (0.5 + 0.5 * dot(out, float3 { -0.6, 0.0, 0.8 })) * 0.4, 0.0, 1.0)
                    let tint = tree_lerp_col(float3 { 0.22, 0.32, 0.24 }, float3 { 0.62, 0.78, 0.55 }, shade)
                    add_child(n, tree_card("reed_leaf", 0.16 * size, len, mid, TREE_VIEW_UP, down, tint))
                add_child(n, cone(0.02, spread * 0.55, spread * 0.4, plain(html("#1a2a1c")), at + float3 { 0.0, -spread * 0.12, 0.0 }))
        case "pine1":
            tree_trunk(n, float3_0, float3 { 0.0, h * 0.5, 0.0 }, r, bark)
            let fol = surf("foliage", float3 { 0.62, 0.78, 0.62 }, 0.6)
            for(4) t:
                let f = float(t) / 4.0
                let rb = lerpf(0.6, 0.22, f) * size
                let ch = lerpf(0.75, 0.55, f) * size
                let y = lerpf(0.3, 1.45, f) * size + ch * 0.5
                add_child(n, cone(0.0, rb, ch, fol, float3 { 0.0, y, 0.0 } + lean * y, float3 { 0.0, randf(rng) * 90.0, 0.0 }, 9))
                for(26):
                    let a = randf(rng) * TAU
                    let out = float3 { rcos(a), 0.0, rsin(a) }
                    let down = normalize(out + float3 { 0.0, -0.6, 0.0 })
                    let at = float3 { 0.0, y - ch * 0.4, 0.0 } + out * rb * 0.85 + lean * y
                    add_child(n, tree_card("reed_leaf", 0.14 * size, 0.22 * size, at, TREE_VIEW_UP, down, tree_lerp_col(float3 { 0.3, 0.42, 0.3 }, float3 { 0.6, 0.75, 0.55 }, randf(rng))))
        case "pine2":
            let top = float3 { 0.0, h * 0.88, 0.0 } + lean * h
            tree_trunk(n, float3_0, top, r, bark)
            for(5):
                let a = randf(rng) * TAU
                let y = randf_range(rng, 0.7, 0.95) * h
                let tip = float3 { rcos(a) * 0.38, y + 0.08, rsin(a) * 0.38 } * float3 { size, 1.0, size } + lean * y
                add_child(n, rod(float3 { 0.0, y - 0.1, 0.0 } + lean * y, tip, r * 0.45, r * 0.2, bark, false))
                let lobes = tree_lobes(tip + float3 { 0.0, 0.05, 0.0 }, 0.08 * size, 0.22 * size, 2, 0.35)
                tree_card_crown(n, lobes, "reed_leaf", 0.12 * size, 260, look.leaf, 0.3)
            tree_card_crown(n, tree_lobes(top + float3 { 0.0, 0.12, 0.0 }, 0.05, 0.24 * size, 2, 0.4), "reed_leaf", 0.12 * size, 260, look.leaf, 0.3)
        case "swamp0":
            let top = float3 { 0.0, h * 0.92, 0.0 } + lean * h
            tree_trunk(n, float3_0, top, r * 0.8, bark)
            add_child(n, cone(r * 0.9, r * 2.6, 0.45 * size, bark, float3 { 0.0, 0.22 * size, 0.0 }, float3_0, 9))
            for(randi_range(rng, 4, 7)):
                let a = randf(rng) * TAU
                let d = randf_range(rng, 0.28, 0.45)
                add_child(n, cone(0.008, 0.035, randf_range(rng, 0.08, 0.16), bark, float3 { rcos(a) * d, 0.05, rsin(a) * d }))
            let lobes = []::TreeLobe
            for(5) t:
                let f = float(t) / 5.0
                lobes.push(TreeLobe { float3 { 0.0, lerpf(0.45, 0.88, f) * h, 0.0 } + lean * h * f, float3 { 1.0, 0.7, 1.0 } * lerpf(0.42, 0.16, f) * size })
            tree_card_crown(n, lobes, "reed_leaf", 0.12 * size, 1300, look.leaf, 0.3)
        case "swamp1":
            let top = float3 { 0.0, h * 0.55, 0.0 } + lean * h
            tree_trunk(n, float3_0, top, r, bark)
            let lobes = tree_lobes(top + float3 { 0.0, 0.3 * size, 0.0 }, 0.6 * size, 0.38 * size, 6)
            tree_card_crown(n, lobes, "leaf", 0.1 * size, 1100, look.leaf)
            for(420) k:
                let l = lobes[k % lobes.length]
                let dx = randf_range(rng, -1.0, 1.0)
                let dy = randf_range(rng, -0.2, 0.6)
                let dz = randf_range(rng, -1.0, 1.0)
                let d = normalize(float3 { dx, dy, dz })
                let at = on_surface(l.c, l.r, d, -0.02)
                var len = randf_range(rng, 0.4, 0.85) * size
                len = min(len, at.y - 0.12)
                let out = normalize(float3 { d.x, 0.0, d.z })
                let tint = tree_lerp_col(float3 { 0.45, 0.55, 0.32 }, float3 { 0.9, 0.95, 0.6 }, randf(rng) * 0.5 + 0.3 * (if dot(out, float3 { -0.6, 0.0, 0.8 }) > 0.0: 1.0 else: 0.0))
                add_child(n, tree_card("reed_leaf", 0.06 * size, len, at + float3 { 0.0, -len * 0.5, 0.0 }, normalize(float3 { 0.5, 0.0, 1.0 }), float3 { 0.0, 1.0, 0.0 }, tint))
        case "swamp2":
            let top = float3 { 0.0, h * 0.55, 0.0 } + lean * h
            let foot = float3 { 0.0, 0.38 * size, 0.0 }
            tree_trunk(n, foot, top, r, bark)
            for(7) k:
                let a = float(k) / 7.0 * TAU + randf_range(rng, -0.3, 0.3)
                let ground = float3 { rcos(a), 0.0, rsin(a) } * randf_range(rng, 0.28, 0.42) * size
                let knee = lerp(foot, ground, 0.5) + float3 { 0.0, 0.16 * size, 0.0 }
                add_child(n, rod(foot + float3 { 0.0, 0.05, 0.0 }, knee, r * 0.45, r * 0.35, bark, false))
                add_child(n, rod(knee, ground, r * 0.35, r * 0.3, bark, true))
            let lobes = tree_lobes(top + float3 { 0.0, 0.4 * size, 0.0 }, 0.55 * size, 0.36 * size, 7)
            tree_card_crown(n, lobes, "leaf", 0.12 * size, 1400, look.leaf)
    return n

def tree_trunk(n:MNode, a:float3, b:float3, r:float, bark:MMat):
    add_child(n, rod(a, b, r, r * 0.6, bark, false))
    add_child(n, cone(r * 1.0, r * 1.5, r * 2.0, bark, a + float3 { 0.0, r, 0.0 }, float3_0, 10))

def tree_lobes(centre:float3, spread:float, r:float, count:int, flat:float = 0.8) -> [TreeLobe]:
    let rng = tree_rng
    let out = []::TreeLobe
    for(count):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.2, 1.0) * spread
        let rr = r * randf_range(rng, 0.8, 1.15)
        out.push(TreeLobe { centre + float3 { rcos(a) * d, randf_range(rng, -0.6, 0.7) * r, rsin(a) * d }, float3 { rr, rr * flat, rr } })
    return out

// Color.lerp (in Color's floats).
def tree_lerp_col(a:float3, b:float3, t:float) -> float3:
    let w = f32(t)
    def l(x:float, y:float) -> float: return f32(f32(x) + f32(f32(f32(y) - f32(x)) * w))
    return float3 { l(a.x, b.x), l(a.y, b.y), l(a.z, b.z) }

def tree_card_crown(n:MNode, lobes:[TreeLobe], card:string, w:float, count:int, tint:float3, aspect:float = 1.3):
    let rng = tree_rng
    var lo = 1000000000.0
    var hi = -1000000000.0
    let core = plain(float3 { tint.x * 0.42, tint.y * 0.46, tint.z * 0.34 })
    for(lobes) l:
        lo = min(lo, l.c.y - l.r.y)
        hi = max(hi, l.c.y + l.r.y)
        add_child(n, blob(l.r * 0.86, core, l.c))
    for(count) k:
        let l = lobes[k % lobes.length]
        let dx = randf_range(rng, -1.0, 1.0)
        let dy = randf_range(rng, -0.5, 1.0)
        let dz = randf_range(rng, -1.0, 1.0)
        let d = normalize(float3 { dx, dy, dz })
        let depth = randf_range(rng, -0.06, 0.02)
        let fx = randf_range(rng, -0.5, 0.5)
        let fy = randf_range(rng, 0.0, 0.6)
        let fz = randf_range(rng, -0.5, 0.5)
        let face = normalize(d + float3 { fx, fy, fz })
        let at = on_surface(l.c, l.r, d, depth)
        let lit = clamp((at.y - lo) / max(hi - lo, 0.01), 0.0, 1.0) * 0.55 + clamp(dot(d, float3 { -0.5, 0.5, 0.7 }), 0.0, 1.0) * 0.3 + (depth + 0.06) / 0.08 * 0.15
        let c = tree_lerp_col(float3 { tint.x * 0.62, tint.y * 0.66, tint.z * 0.62 }, float3 { min(tint.x * 1.8, 1.0), min(tint.y * 1.6, 1.0), min(tint.z * 1.7, 1.0) }, lit)
        add_child(n, tree_card(card, w, w * aspect, at, face, d, c))

def tree_painted_crown(n:MNode, lobes:[TreeLobe], tint:float3, w:float):
    let rng = tree_rng
    for(lobes) l:
        let m = surf("foliage", float3 { tint.x * 1.6, tint.y * 1.5, tint.z * 1.5 }, 0.45)
        add_child(n, blob(l.r, m, l.c, float3 { 0.0, randf(rng) * 180.0, 0.0 }))
    for(180) k:
        let l = lobes[k % lobes.length]
        let dx = randf_range(rng, -1.0, 1.0)
        let dy = randf_range(rng, -0.3, 1.0)
        let dz = randf_range(rng, -1.0, 1.0)
        let d = normalize(float3 { dx, dy, dz })
        let at = on_surface(l.c, l.r, d, 0.0)
        let lit = clamp(d.y * 0.5 + 0.5, 0.0, 1.0)
        add_child(n, tree_card("leaf", w, w * 1.3, at, d, float3 { 0.0, 1.0, 0.0 }, tree_lerp_col(tint * 0.8, float3 { 1.0, 1.0, 0.8 }, lit * 0.6)))

def tree_stump(look:TreeLook, size:float) -> MNode:
    let rng = tree_rng
    let n = mnode()
    let r = look.trunk * size * 1.25
    let sh = 0.13 * size
    let bark = tree_bark(look)
    add_child(n, cone(r * 0.95, r * 1.35, sh, bark, float3 { 0.0, sh * 0.5, 0.0 }, float3_0, 10))
    let tx = randf_range(rng, -8.0, 8.0)
    let tz = randf_range(rng, -8.0, 8.0)
    add_child(n, cone(r * 0.85, r * 0.9, 0.012, plain(html("#d8b880")), float3 { 0.0, sh + 0.004, 0.0 }, float3 { tx, 0.0, tz }, 10))
    let chip = plain(html("#c8a46a"))
    for(6):
        let a = randf(rng) * TAU
        let d = randf_range(rng, 0.12, 0.32)
        add_child(n, blob(float3 { 0.03, 0.008, 0.018 }, chip, float3 { rcos(a) * d, 0.006, rsin(a) * d }, float3 { 0.0, randf(rng) * 180.0, 0.0 }))
    return n

def tree_felled(look:TreeLook, size:float, h:float, fall:float, stage:int) -> MNode:
    let n = mnode()
    let r = look.trunk * size
    let dir = float3 { rcos(fall), 0.0, rsin(fall) }
    let len = (if stage == 1: 0.85 else: 0.45) * size
    let a = dir * 0.12 + float3 { 0.0, r, 0.0 }
    let b = a + dir * len
    add_child(n, rod(a, b, r, r * 0.8, tree_bark(look), true))
    let face = add_child(n, cone(r * 0.95, r * 0.95, 0.01, plain(html("#d8b880")), a - dir * 0.005))
    set_basis(face, arc(float3 { 0.0, 1.0, 0.0 }, dir))
    if stage == 1:
        let lobes = [ TreeLobe { b + float3 { 0.0, 0.1, 0.0 }, float3 { 0.18, 0.1, 0.18 } * size }, TreeLobe { b + dir * 0.14 + float3 { 0.0, 0.08, 0.0 }, float3 { 0.14, 0.08, 0.14 } * size } ]
        tree_card_crown(n, lobes, "leaf", 0.09 * size, 90, look.leaf * float3 { 1.1, 0.95, 0.75 })
    return n

// UnitModels.decal with the tint quantised to steps of 0.04 (tree_models.gd _card: cards of about the same tint
// share a material); always lit.
def tree_card(name:string, w:float, h:float, pos:float3, facing:float3, up:float3, tint:float3) -> MNode:
    def snap(x:float) -> float: return f32(floor(x / 0.04 + 0.5) * 0.04)
    let m = MMat { float3 { snap(tint.x), snap(tint.y), snap(tint.z) } }
    m.tex = name
    m.scissor = true
    m.two_sided = true
    let n = mesh_node(quad_mesh(float2 { w, h }), m)
    n.meta = name
    n.pos = pos
    let f = normalize(facing)
    let u = if abs(dot(f, normalize(up))) < 0.95: up else: float3 { 0.0, 0.0, -1.0 }
    set_basis(n, basis_looking_at(-f, u))
    return n
