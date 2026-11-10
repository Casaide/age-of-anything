// ------------------------------------------------------------------ trees as voxel grids (#410)
// Three tree_kind (broadleaf: an oak; pine; swamp: a willow), each in three looks (`style` 0-2), and `stage` 0-3
// (standing, felled, half sawn, the stump), built voxel by voxel (view/voxel_grid.lobster) in design units: a
// voxel each in Dominic's approved mockup (2026-11-10), scaled to the trees' size in the world.

let TREE_SPECIES = [ "broadleaf", "pine", "swamp" ]

def tree_species_index(tree_kind:string) -> int:  // SPECIES.find
    for(TREE_SPECIES) s, i:
        if s == tree_kind: return i
    return -1

let TREE_BARK = [ float3 { 0.20, 0.15, 0.12 }, float3 { 0.36, 0.29, 0.22 }, float3 { 0.52, 0.45, 0.36 }, float3 { 0.66, 0.60, 0.50 } ]
let TREE_BIRCH = [ float3 { 0.22, 0.20, 0.19 }, float3 { 0.58, 0.56, 0.52 }, float3 { 0.80, 0.78, 0.73 }, float3 { 0.92, 0.91, 0.87 } ]

// World units a design unit: the trees keep the size they had on the map.
def tree_unit(tree_kind:string) -> float:
    return switch tree_kind:
        case "pine": 0.0148
        case "swamp": 0.0195
        default: 0.0177

def tree_look(tree_kind:string, style:int) -> vglook:
    let leaf = switch tree_kind:
        case "pine": [ float3 { 0.55, 0.62, 0.36 }, float3 { 0.24, 0.37, 0.24 }, float3 { 0.06, 0.13, 0.12 }, float3 { 0.48, 0.47, 0.26 } ]
        case "swamp": [ float3 { 0.74, 0.74, 0.40 }, float3 { 0.45, 0.52, 0.26 }, float3 { 0.14, 0.21, 0.14 }, float3 { 0.70, 0.64, 0.34 } ]
        default:
            if style == 2: [ float3 { 0.72, 0.72, 0.34 }, float3 { 0.40, 0.50, 0.22 }, float3 { 0.12, 0.19, 0.13 }, float3 { 0.70, 0.62, 0.28 } ]
            else: [ float3 { 0.62, 0.66, 0.32 }, float3 { 0.32, 0.43, 0.20 }, float3 { 0.09, 0.16, 0.13 }, float3 { 0.62, 0.55, 0.26 } ]
    return vglook { leaf, if tree_kind == "broadleaf" and style == 2: TREE_BIRCH else: TREE_BARK, [], false, true, true }

def tree(seed_value:int, tree_kind:string, style:int = 0, stage:int = 0) -> vgrid:
    let rng = grng(seed_value * 31 + tree_species_index(tree_kind) * 7 + style)
    let size = randf_range(rng, 0.88, 1.12)
    let k = vg_k(tree_unit(tree_kind) * size)
    let look = tree_look(tree_kind, style)
    if stage > 0:
        look.standing = false
        return tree_cut(rng, look, k, tree_kind, stage)
    return switch tree_kind:
        case "pine": tree_pine(rng, look, k, style)
        case "swamp": tree_willow(rng, look, k, style)
        default: tree_oak(rng, look, k, style)

def tree_roots(g:vgrid, count:int, spread:float, top:float, ra:float, rb:float, turn:float):
    for(count) i:
        let a = float(i) / float(count) * TAU + turn
        vg_capsule(g, float3 { rcos(a) * spread, rsin(a) * spread, 0.0 }, float3 { 0.0, 0.0, top }, ra, rb, VG_BARK)

// Leaf clumps at the tips, each a ragged blob with holes in its own tone.
def tree_clumps(g:vgrid, rng:Pcg, tips:[float3], rlo:float, rhi:float):
    let nz = vg_field(g, 3.0, g.seed + 11)
    let gaps = vg_field(g, 7.0, g.seed + 21)
    for(tips) t:
        let r = randf_range(rng, rlo, rhi)
        vg_blob(g, t + float3 { 0.0, 0.0, r * 0.25 }, r, 1.35, 0.9, nz, VG_LEAF, randf_range(rng, -1.0, 1.0), 0.18, gaps, 0.66)

// The oak: a flared, ridged trunk, branches forking four deep, clumped leaves (style 1 taller and narrower, style 2 a
// pale-barked birch with smaller clumps).
def tree_oak(rng:Pcg, look:vglook, k:float, style:int) -> vgrid:
    let g = vg_new(look, float3 { -58.0, -58.0, 0.0 }, float3 { 58.0, 58.0, 160.0 }, k, randi_range(rng, 0, 1000000000))
    let tips = []::float3
    let slim = if style == 2: 0.7 else: 1.0
    def branch(p:float3, d0:float3, length:float, r:float, depth:int) -> void:
        let d = normalize(d0)
        let q = p + d * length
        let m = (p + q) / 2.0 + vg_gauss3(rng) * length * 0.08
        vg_capsule(g, p, m, r, r * 0.85, VG_BARK)
        vg_capsule(g, m, q, r * 0.85, r * 0.7, VG_BARK)
        if depth == 0 or r < 0.9:
            tips.push(q)
            return
        for(if depth < 3: 2 else: 3):
            let nd = d + vg_gauss3(rng) * 0.55
            branch(q, float3 { nd.x, nd.y, abs(nd.z) * 0.8 + 0.25 }, length * randf_range(rng, 0.6, 0.78), r * 0.68, depth - 1)
        if depth <= 2: tips.push(q)
    tree_roots(g, 5, 7.0 * slim, 9.0, 2.2 * slim, 3.5 * slim, 0.4)
    let rise = if style == 1: 54.0 elif style == 2: 48.0 else: 40.0
    let top = float3 { 2.0, -1.0, rise }
    vg_capsule(g, float3_0, float3 { 1.0, 0.0, rise * 0.55 }, 6.0 * slim, 5.0 * slim, VG_BARK)
    vg_capsule(g, float3 { 1.0, 0.0, rise * 0.55 }, top, 5.0 * slim, 4.0 * slim, VG_BARK)
    let limbs = if style == 1: 3 else: 4
    let reach = if style == 1: 19.0 elif style == 2: 20.0 else: 24.0
    for(limbs) i:
        let a = float(i) / float(limbs) * TAU + 0.3
        branch(top, float3 { rcos(a), rsin(a), if style == 1: 1.4 else: 0.9 }, reach, 3.3 * slim, 4)
    let lead = top + float3 { 0.0, 0.0, 30.0 }
    vg_capsule(g, top, lead, 3.0 * slim, 1.2, VG_BARK)
    tips.push(lead)
    if style == 2: tree_clumps(g, rng, tips, 7.0, 10.0)
    else: tree_clumps(g, rng, tips, 9.0, 13.0)
    return g

// The pine: a straight trunk, whorls of drooping branches carrying flat needle pads from a third up (style 1 shorter
// and fuller, style 2 tall with its crown only near the top).
def tree_pine(rng:Pcg, look:vglook, k:float, style:int) -> vgrid:
    let g = vg_new(look, float3 { -42.0, -42.0, 0.0 }, float3 { 42.0, 42.0, 180.0 }, k, randi_range(rng, 0, 1000000000))
    let h = if style == 1: 140.0 else: 165.0
    let base = if style == 2: 92.0 elif style == 1: 34.0 else: 48.0
    let wide = if style == 1: 1.15 else: 1.0
    tree_roots(g, 4, 5.0, 6.0, 1.6, 2.6, 0.7)
    vg_capsule(g, float3_0, float3 { 1.0, 0.0, h - 6.0 }, 4.2, 0.8, VG_BARK)
    let nz = vg_field(g, 3.0, g.seed + 31)
    var z = base
    while z < h - 4.0:
        let f = (h - z) / (h - base)
        let reach = (6.0 + 22.0 * pow(f, 0.9)) * wide
        let nb = 5 + int(3.0 * f)
        let off = randf_range(rng, 0.0, TAU)
        for(nb) i:
            let a = off + float(i) / float(nb) * TAU + vg_gauss(rng) * 0.25
            let d = float3 { rcos(a), rsin(a), 0.0 }
            let at = float3 { 0.0, 0.0, z }
            vg_capsule(g, at, at + d * reach + float3 { 0.0, 0.0, -reach * 0.35 }, 1.2, 0.5, VG_BARK)
            for(4) j:
                let s = 0.35 + 0.65 * float(j) / 3.0
                let c = at + d * reach * s + float3 { 0.0, 0.0, -reach * 0.35 * s + 1.5 }
                vg_blob(g, c, 3.2 + 3.0 * s * f + 0.8, 2.3, 0.8, nz, VG_LEAF, randf_range(rng, -1.0, 0.3), 0.15, nil, 1.0)
        z += randf_range(rng, 9.0, 12.0)
    return g

// The willow: a buttressed trunk, a dome of leaves, curtains of leaf strands hanging from it (style 1 taller, style 2
// lower with longer curtains).
def tree_willow(rng:Pcg, look:vglook, k:float, style:int) -> vgrid:
    let g = vg_new(look, float3 { -66.0, -66.0, 0.0 }, float3 { 66.0, 66.0, 130.0 }, k, randi_range(rng, 0, 1000000000))
    let rise = if style == 1: 46.0 elif style == 2: 28.0 else: 34.0
    tree_roots(g, if style == 2: 8 else: 6, 10.0, 12.0, 2.6, 4.5, 0.0)
    let top = float3 { -3.0, 2.0, rise }
    vg_capsule(g, float3_0, top, 7.5, 5.5, VG_BARK)
    let tips = []::float3
    for(6) i:
        let a = float(i) / 6.0 * TAU + vg_gauss(rng) * 0.3
        let d = float3 { rcos(a), rsin(a), 0.0 }
        let m = top + d * 16.0 + float3 { 0.0, 0.0, 22.0 }
        let e = top + d * 34.0 + float3 { 0.0, 0.0, 28.0 }
        vg_capsule(g, top, m, 3.6, 2.4, VG_BARK)
        vg_capsule(g, m, e, 2.4, 1.2, VG_BARK)
        tips.push(m)
        tips.push(e)
        tips.push((m + e) / 2.0)
    let nz = vg_field(g, 3.0, g.seed + 41)
    for(tips) t: vg_blob(g, t, randf_range(rng, 10.0, 13.0), 1.5, 0.8, nz, VG_LEAF, randf_range(rng, -0.6, 1.0), 0.0, nil, 1.0)
    // the curtains: from the dome's outer leaves, about as many as the mockup's whatever the scale
    let longer = if style == 2: 1.3 else: 1.0
    let pick = 0.012 / (g.k * g.k * g.k)
    let hang = []::float3
    vg_box(g, float(g.lo) / g.k, float(g.lo + g.n) / g.k) i, p:
        if g.mat[i] == VG_LEAF and magnitude(float2 { p.x, p.y }) > 22.0 and vg_hash(g.seed + 3, i, 0, 0) < pick: hang.push(p)
    for(hang) p:
        let ln = randf_range(rng, 14.0, 34.0) * longer
        let dx = vg_gauss(rng)
        let dy = vg_gauss(rng)
        vg_capsule(g, p, p + float3 { dx, dy, -min(ln, p.z - 2.0) }, 1.0, 0.7, VG_LEAF, true, 0.6)
    vg_thin(g, VG_LEAF, 0.12)
    return g

// What's left once a worker has started: the stump, and (stage 1) the felled trunk with its crown or (2) half of it
// sawn away; (3) the stump alone. Chips round it all.
def tree_cut(rng:Pcg, look:vglook, k:float, tree_kind:string, stage:int) -> vgrid:
    let g = vg_new(look, float3 { -70.0, -70.0, 0.0 }, float3 { 70.0, 70.0, 34.0 }, k, randi_range(rng, 0, 1000000000))
    let r = if tree_kind == "pine": 4.6 elif tree_kind == "swamp": 7.5 else: 6.0
    let fall = randf(rng) * TAU
    let dir = float3 { rcos(fall), rsin(fall), 0.0 }
    let side = float3 { -dir.y, dir.x, 0.0 }
    // the stump: its roots, the trunk cut a little above them, the cut end pale
    tree_roots(g, 5, r * 1.3, r * 1.2, r * 0.38, r * 0.55, fall)
    let sh = r * 1.5
    vg_cylinder(g, float3_0, float3 { 0.0, 0.0, sh }, r * 1.12, r, VG_BARK)
    vg_cylinder(g, float3 { 0.0, 0.0, sh - 0.7 }, float3 { 0.0, 0.0, sh + 0.2 }, r * 0.88, r * 0.86, VG_WOOD, true)
    if stage < 3:
        let len = if stage == 1: 62.0 else: 32.0
        let a = dir * (r * 1.6) + float3 { 0.0, 0.0, r * 0.9 }
        let b = a + dir * len
        vg_cylinder(g, a, b, r * 0.9, r * 0.75, VG_BARK)
        vg_cylinder(g, a - dir * 0.2, a + dir * 0.7, r * 0.8, r * 0.8, VG_WOOD, true)
        if stage == 1:
            let nz = vg_field(g, 3.0, g.seed + 51)
            for(3) j:
                let t = b + dir * (float(j) * 6.0 - 2.0) + side * vg_gauss(rng) * 4.0
                vg_capsule(g, b, t + float3 { 0.0, 0.0, 3.0 }, r * 0.4, 1.0, VG_BARK)
            for(7):
                let c = b + dir * randf_range(rng, -4.0, 14.0) + side * vg_gauss(rng) * 6.0 + float3 { 0.0, 0.0, randf_range(rng, 5.0, 9.0) }
                vg_blob(g, c, randf_range(rng, 6.0, 9.0), 1.5, 0.9, nz, VG_LEAF, randf_range(rng, -1.0, 1.0), 0.18, nil, 1.0)
        else:
            vg_cylinder(g, b - dir * 0.7, b + dir * 0.2, r * 0.7, r * 0.7, VG_WOOD, true)
    // chips and sawdust
    for(4 + stage):
        let a = randf(rng) * TAU
        let d = randf_range(rng, r * 1.8, r * 4.5)
        let p = float3 { rcos(a) * d, rsin(a) * d, 0.6 }
        let q = p + float3 { rcos(a + 1.3), rsin(a + 1.3), 0.0 } * randf_range(rng, 0.8, 2.0)
        vg_capsule(g, p, q, 0.6, 0.45, VG_WOOD)
    return g
