// ------------------------------------------------------------------ town life props (scenes/art_pixel/town_props.gd)
// Drop-off piles by resource (stages 1-3, styles "a" and "b"), a house's yard and garden growing with its age, the
// stable's tether post; in world units, each function town_props.gd's of the same name (its private helpers carry
// the file's name: `_bundle` -> town_bundle), line for line; its comments are there. Seeded with Godot's
// RandomNumberGenerator, drawn in the same order. The rocks are model/props.lobster's stone_mesh.

let TOWN_PILE_KINDS = ["food", "wood", "stone", "gold"]
let TOWN_GROWTH = ["yard", "garden"]
let TOWN_STAGES = 3

var town_rng = grng(0)
let town_wood_mat:MMat? = nil        // the building materials' wood (town_props.gd `models`, set by the baker's owner); nil: plain

def town_wood() -> MMat:
    let w = town_wood_mat
    if w: return w
    return plain(html("#7a5634"))

def pile(kind:string, stage:int, style:string = "a") -> MNode:
    var k = 0
    for(TOWN_PILE_KINDS) s, i:
        if s == kind: k = i
    town_rng = grng(7000 + k * 100 + stage * 10 + (if style == "a": 0 else: 5))
    switch kind + "_" + style:
        case "wood_a": return town_pile_wood_a(stage)
        case "wood_b": return town_pile_wood_b(stage)
        case "food_a": return town_pile_food_a(stage)
        case "food_b": return town_pile_food_b(stage)
        case "stone_a": return town_pile_stone_a(stage)
        case "stone_b": return town_pile_stone_b(stage)
        case "gold_a": return town_pile_gold_a(stage)
        default: return town_pile_gold_b(stage)

// ---- reeds (wood)

def town_bundle(n:MNode, a:float3, b:float3, r:float):
    let rng = town_rng
    let stalk = surf("reed_stalk", float3 { 1.0, 0.84, 0.55 }, 0.08)
    let tie = plain(html("#5a3a20"))
    let dir = b - a
    let across = normalize(cross(dir, float3 { 0.0, 1.0, 0.0 }))
    for(5) k:
        let ang = float(k) * TAU / 5.0 + randf(rng) * 0.4
        let side = across * rcos(ang) * r * 0.5 + float3 { 0.0, 1.0, 0.0 } * rsin(ang) * r * 0.5
        let spread = across * rcos(ang) * r * 0.25
        add_child(n, rod(a + side - spread, b + side + spread, r * 0.55, r * 0.4, stalk, false))
    for([0.3, 0.7]) f:
        add_child(n, ring(r * 0.75, r * 1.0, tie, lerp(a, b, f), float3 { 0.0, -atan2(float2 { dir.x, dir.z }), 90.0 }))
    let tuft = plain(html("#d8c48a"))
    add_child(n, blob(float3 { r * 0.9, r * 0.9, r * 0.9 }, tuft, b + normalize(dir) * r * 0.4))

def town_pile_wood_a(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    let counts = [0, 3, 6, 10]
    var placed = 0
    var layer = 0
    let r = 0.045
    while placed < counts[stage]:
        let across = 4 - layer
        for(across) k:
            if placed < counts[stage]:
                let z = (float(k) - float(across - 1) * 0.5) * r * 2.1
                let x0 = -0.24 + randf_range(rng, -0.03, 0.03)
                let y = r + float(layer) * r * 1.7
                let ey = randf_range(rng, -0.01, 0.01)
                let ez = randf_range(rng, -0.04, 0.04)
                town_bundle(n, float3 { x0, y, z }, float3 { x0 + 0.48, y + ey, z + ez }, r)
                placed++
        layer++
    return n

def town_pile_wood_b(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    let spots = [float3_0, float3 { 0.2, 0.0, 0.12 }, float3 { -0.18, 0.0, 0.15 }]
    for(stage) s:
        let c = spots[s]
        for(6) k:
            let a = float(k) * TAU / 6.0 + randf(rng) * 0.3
            let foot = c + float3 { rcos(a), 0.0, rsin(a) } * 0.12
            town_bundle(n, foot + float3 { 0.0, 0.03, 0.0 }, c + float3 { rcos(a) * 0.02, 0.42, rsin(a) * 0.02 }, 0.035)
    return n

// ---- bugs and berries (food)

def town_basket(n:MNode, at:float3, full:bool):
    let rng = town_rng
    let weave = surf("wicker", float3_1, 0.25)
    let b = add_child(n, mesh_node(cylinder_mesh(0.09, 0.07, 0.12, 16, 4, true, true), weave))
    b.pos = at + float3 { 0.0, 0.06, 0.0 }
    add_child(n, ring(0.08, 0.1, plain(html("#c8a070")), at + float3 { 0.0, 0.12, 0.0 }))
    if full:
        for(7) k:
            let a = float(k) * TAU / 7.0 + randf(rng)
            let rr = if k > 0: 0.05 else: 0.0
            let bug = plain([html("#c8302a"), html("#e0607f"), html("#b04a3a")][k % 3])
            add_child(n, blob(float3 { 0.028, 0.022, 0.026 }, bug, at + float3 { rcos(a) * rr, 0.13 + (if k == 0: 0.03 else: 0.0), rsin(a) * rr }))

def town_pile_food_a(stage:int) -> MNode:
    let n = mnode()
    let spots = [float3_0, float3 { 0.19, 0.0, 0.04 }, float3 { -0.1, 0.0, 0.16 }, float3 { 0.1, 0.0, 0.2 }, float3 { -0.17, 0.0, -0.06 }]
    for([0, 1, 3, 5][stage]) k: town_basket(n, spots[k], true)
    if stage == 3: town_basket(n, spots[0] + float3 { 0.02, 0.12, 0.01 }, true)
    return n

def town_pile_food_b(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    add_child(n, box(float3 { 0.5, 0.012, 0.42 }, surf("wicker", html("#d8b880"), 0.3), float3 { 0.0, 0.006, 0.0 }))
    let r = [0.0, 0.09, 0.14, 0.19][stage]
    for([0, 20, 40, 70][stage]) k:
        let a = randf(rng) * TAU
        let d = sqrt(randf(rng)) * r
        let h = (1.0 - d / r) * r * 0.9
        let bug = plain([html("#c8302a"), html("#e0607f"), html("#b04a3a"), html("#7a9a3a")][k % 4])
        add_child(n, blob(float3 { 0.026, 0.02, 0.024 }, bug, float3 { rcos(a) * d, 0.02 + h, rsin(a) * d * 0.85 }))
    return n

// ---- stone

def town_pile_stone_a(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    let r = [0.0, 0.12, 0.17, 0.22][stage]
    for([0, 6, 12, 20][stage]) k:
        let a = randf(rng) * TAU
        let d = sqrt(randf(rng)) * r
        let mi = add_child(n, mesh_node(stone_mesh(8000 + k), surf("rock", float3 { 1.0, 0.96, 0.88 }, 0.2)))
        let s = randf_range(rng, 0.05, 0.075)
        mi.scl = float3 { s, s * 0.8, s }
        mi.pos = float3 { rcos(a) * d, s * 0.6 + (1.0 - d / r) * r * 0.55, rsin(a) * d }
        let rx = randf(rng)
        let ry = randf(rng) * TAU
        let rz = randf(rng)
        mi.rot = float3 { rad(rx), rad(ry), rad(rz) }
    return n

def town_pile_stone_b(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    let rock = surf("rock", float3 { 0.88, 0.84, 0.76 }, 0.2)
    let spots = [float3 { -0.08, 0.0, 0.0 }, float3 { 0.08, 0.0, 0.0 }, float3 { -0.08, 0.0, 0.13 }, float3 { 0.08, 0.0, 0.13 },
                 float3 { 0.0, 0.09, 0.0 }, float3 { 0.0, 0.09, 0.13 }, float3 { 0.22, 0.0, 0.06 }, float3 { 0.0, 0.18, 0.06 }]
    for([0, 3, 6, 8][stage]) k:
        add_child(n, box(float3 { 0.15, 0.09, 0.12 }, rock, spots[k] + float3 { 0.0, 0.045, 0.0 }, float3 { 0.0, rad(randf_range(rng, -0.12, 0.12)), 0.0 }))
    return n

// ---- gold

def town_nugget(n:MNode, at:float3, s:float):
    let rng = town_rng
    add_child(n, blob(float3 { s, s * 0.7, s * 0.85 }, surf("rock", float3 { 0.6, 0.55, 0.5 }, 0.2), at))
    let gold = plain(html("#f2c440"))
    for(4) k:
        let a = float(k) * TAU / 4.0 + randf(rng) * 0.8
        add_child(n, blob(float3 { s * 0.45, s * 0.35, s * 0.45 }, gold, at + float3 { rcos(a) * s * 0.55, s * 0.4, rsin(a) * s * 0.55 }))

def town_pile_gold_a(stage:int) -> MNode:
    let rng = town_rng
    let n = mnode()
    let wood = town_wood()
    let w = 0.3
    let d = 0.22
    let h = 0.12
    for([-1.0, 1.0]) side:
        add_child(n, box(float3 { w, h, 0.02 }, wood, float3 { 0.0, h / 2.0, side * d / 2.0 }))
        add_child(n, box(float3 { 0.02, h, d }, wood, float3 { side * w / 2.0, h / 2.0, 0.0 }))
    add_child(n, box(float3 { w, 0.02, d }, wood, float3 { 0.0, 0.01, 0.0 }))
    let fill = [0.0, 0.05, 0.1, 0.15][stage]
    for([0, 4, 7, 11][stage]):
        let x = randf_range(rng, -w * 0.35, w * 0.35)
        let y = fill + randf_range(rng, 0.0, 0.03)
        let z = randf_range(rng, -d * 0.3, d * 0.3)
        town_nugget(n, float3 { x, y, z }, 0.04)
    return n

def town_pile_gold_b(stage:int) -> MNode:
    let n = mnode()
    let sack = surf("cloth", html("#c8b48a"), 0.3)
    let spots = [float3_0, float3 { 0.16, 0.0, 0.06 }, float3 { -0.12, 0.0, 0.12 }]
    for(stage) k:
        let p = spots[k]
        add_child(n, blob(float3 { 0.08, 0.1, 0.07 }, sack, p + float3 { 0.0, 0.09, 0.0 }))
        add_child(n, blob(float3 { 0.03, 0.025, 0.03 }, sack, p + float3 { 0.0, 0.2, 0.0 }))
    town_nugget(n, float3 { 0.05, 0.03, 0.15 }, 0.04)
    return n

// ---- a house's yard and garden

def yard(stage:int, seed_value:int = 0) -> MNode:
    town_rng = grng(9000 + seed_value)
    let n = mnode()
    let wood = town_wood()
    let clay = plain(html("#b8643e"))
    add_child(n, blob(float3 { 0.06, 0.07, 0.06 }, clay, float3 { 0.0, 0.07, 0.0 }))
    add_child(n, ring(0.03, 0.045, clay, float3 { 0.0, 0.135, 0.0 }))
    add_child(n, box(float3 { 0.12, 0.02, 0.12 }, wood, float3 { 0.14, 0.1, -0.04 }))
    for([-1.0, 1.0]) x:
        for([-1.0, 1.0]) z:
            add_child(n, box(float3 { 0.015, 0.1, 0.015 }, wood, float3 { 0.14 + x * 0.045, 0.05, -0.04 + z * 0.045 }))
    if stage >= 2:
        let ends = plain(html("#c8a06a"))
        for(3) row:
            for(4 - row) k:
                let z = -0.2 + 0.04 + (float(k) + float(row) * 0.5) * 0.065
                let p = float3 { -0.18, 0.03 + float(row) * 0.055, z }
                add_child(n, rod(p - float3 { 0.11, 0.0, 0.0 }, p + float3 { 0.11, 0.0, 0.0 }, 0.03, 0.03, wood))
                add_child(n, blob(float3 { 0.004, 0.026, 0.026 }, ends, p + float3 { 0.112, 0.0, 0.0 }))
    if stage >= 3:
        for([-0.04, 0.2]) x:
            add_child(n, rod(float3 { x, 0.0, -0.22 }, float3 { x, 0.28, -0.22 }, 0.012, 0.01, wood))
        add_child(n, rod(float3 { -0.06, 0.27, -0.22 }, float3 { 0.22, 0.27, -0.22 }, 0.01, 0.01, wood))
        let cloth = surf("cloth", html("#d8ccb0"), 0.3)
        add_child(n, box(float3 { 0.18, 0.14, 0.01 }, cloth, float3 { 0.08, 0.2, -0.22 }))
    return n

def garden(stage:int, seed_value:int = 0) -> MNode:
    town_rng = grng(9500 + seed_value)
    let rng = town_rng
    let n = mnode()
    let wood = town_wood()
    let w = 0.42
    let d = 0.3
    add_child(n, box(float3 { w, 0.025, d }, plain(html("#5e4228")), float3 { 0.0, 0.012, 0.0 }))
    let leaves = [plain(html("#5e8a2c")), plain(html("#76a038")), plain(html("#4a7424"))]
    for(3) row:
        add_child(n, blob(float3 { w * 0.46, 0.012, 0.025 }, plain(html("#6e4e30")), float3 { 0.0, 0.028, -d * 0.3 + float(row) * d * 0.3 }))
        for(5) k:
            let base = float3 { -w * 0.38 + float(k) * w * 0.19, 0.03, -d * 0.3 + float(row) * d * 0.3 }
            let s = if stage == 1: 0.02 else: 0.035
            for(3) l:
                let a = float(l) * TAU / 3.0 + randf(rng)
                add_child(n, blob(float3 { s, s * 0.35, s * 0.55 }, leaves[(row + k + l) % 3], base + float3 { rcos(a) * s * 0.6, s * 0.6, rsin(a) * s * 0.6 }, float3 { 0.0, rad(a), 25.0 }))
    if stage >= 2:
        let stake = plain(html("#6a4a2c"))
        let weave = surf("wicker", html("#b89a6a"), 0.25)
        let hw = w / 2.0 + 0.03
        let hd = d / 2.0 + 0.03
        for(5) x:
            let fx = -hw + float(x) * hw * 0.5
            add_child(n, rod(float3 { fx, 0.0, -hd }, float3 { fx, 0.1, -hd }, 0.008, 0.007, stake))
        for(3) z:
            let fz = -hd + float(z) * hd
            for([-1.0, 1.0]) sx:
                add_child(n, rod(float3 { sx * hw, 0.0, fz }, float3 { sx * hw, 0.1, fz }, 0.008, 0.007, stake))
        add_child(n, box(float3 { hw * 2.0, 0.05, 0.012 }, weave, float3 { 0.0, 0.06, -hd }))
        for([-1.0, 1.0]) sx:
            add_child(n, box(float3 { 0.012, 0.05, hd * 2.0 }, weave, float3 { sx * hw, 0.06, 0.0 }))
    if stage >= 3:
        for(3) k:
            let foot = float3 { -0.14 + float(k) * 0.14, 0.0, -0.1 }
            add_child(n, rod(foot + float3 { -0.03, 0.0, 0.0 }, foot + float3 { 0.0, 0.3, 0.02 }, 0.007, 0.005, wood))
            add_child(n, rod(foot + float3 { 0.03, 0.0, 0.0 }, foot + float3 { 0.0, 0.3, 0.02 }, 0.007, 0.005, wood))
            for(4) l:
                add_child(n, blob(float3 { 0.018, 0.012, 0.018 }, leaves[l % 3], foot + float3 { randf_range(rng, -0.02, 0.02), 0.08 + float(l) * 0.055, 0.01 }))
        let gourd = plain(html("#d8902a"))
        for([float3 { -0.12, 0.035, 0.08 }, float3 { 0.1, 0.035, 0.1 }]) p:
            add_child(n, blob(float3 { 0.035, 0.03, 0.035 }, gourd, p))
    return n

def tether_post() -> MNode:
    let n = mnode()
    let wood = town_wood()
    add_child(n, rod(float3_0, float3 { 0.0, 0.26, 0.0 }, 0.025, 0.022, wood))
    add_child(n, ring(0.015, 0.024, plain(html("#4a4c50")), float3 { 0.02, 0.21, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    let rope = plain(html("#c8b48a"))
    add_child(n, rod(float3 { 0.02, 0.21, 0.0 }, float3 { 0.14, 0.12, 0.05 }, 0.006, 0.006, rope, false))
    return n
