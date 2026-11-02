// ------------------------------------------------------------------ map bridges (scenes/art_pixel/bridge_models.gd)
// Timber bridges along +x, `length` tiles of water and a little onto each bank, `wide` tiles across, in three looks
// (`style` 0 trestle, 1 log bridge on cribs, 2 humped with rope rails), `broken` 1 for what's left after one's been
// broken; bridge_models.gd's functions line for line (its private helpers carry the file's name: `_crib` ->
// bridge_crib); its comments are there. Seeded with Godot's RandomNumberGenerator, drawn in the same order.

let BRIDGE_DECK = 0.16
let BRIDGE_WIDTH = 0.78

var bridge_rng = grng(0)

def bridge(seed_value:int, length:int, style:int = 0, broken:int = 0, wide:int = 1) -> MNode:
    bridge_rng = grng(seed_value)
    let rng = bridge_rng
    let n = mnode()
    let half = float(length) * 0.5 + 0.45
    let width = BRIDGE_WIDTH + float(wide - 1)
    let wood = surf("wood_grain", float3 { 0.78, 0.74, 0.66 }, 0.6)
    let dark = surf("wood_grain", float3 { 0.5, 0.47, 0.42 }, 0.6)
    def gone(x:float) -> bool: return broken == 1 and abs(x) < half - 0.7
    if style == 1:
        for(length - 1) k0:
            let x = -float(length) * 0.5 + float(k0 + 1)
            if broken == 1 and abs(x) < 0.6: bridge_crib(n, x, 0.6, dark, width)
            else: bridge_crib(n, x, 1.0, dark, width)
        let logs = int(half * 2.0 / 0.11)
        for(logs) k:
            let x = -half + (float(k) + 0.5) * half * 2.0 / float(logs)
            if not (gone(x) and randf(rng) < 0.9):
                let r = randf_range(rng, 0.045, 0.06)
                let y = BRIDGE_DECK + bridge_hump(x, half, 0.0) + r
                let ax = randf_range(rng, -0.01, 0.01)
                let az = randf_range(rng, 0.0, 0.06)
                let a = float3 { x + ax, y, -width * 0.5 - az }
                let bx = randf_range(rng, -0.01, 0.01)
                let bz = randf_range(rng, 0.0, 0.06)
                let b = float3 { x + bx, y, width * 0.5 + bz }
                add_child(n, rod(a, b, r, r * 0.95, if k % 3 != 0: wood else: dark, true))
    else:
        let rise = if style == 2: 0.14 else: 0.0
        for([ -1.0, 1.0 ]) side:
            let z = side * width * 0.36
            let segs = 8
            for(segs) k:
                let x0 = -half + float(k) * half * 2.0 / float(segs)
                let x1 = x0 + half * 2.0 / float(segs)
                if not gone((x0 + x1) * 0.5):
                    add_child(n, rod(float3 { x0, BRIDGE_DECK - 0.04 + bridge_hump(x0, half, rise), z }, float3 { x1, BRIDGE_DECK - 0.04 + bridge_hump(x1, half, rise), z }, 0.04, 0.04, dark, false))
        for(length + 1) k:
            let x = -float(length) * 0.5 + float(k)
            let top = BRIDGE_DECK + bridge_hump(x, half, rise)
            let stub = gone(x)
            for([ -1.0, 1.0 ]) side:
                let z = side * width * 0.42
                let h = (if stub: 0.12 else: top + 0.02) + 0.25
                add_child(n, rod(float3 { x, -0.1, z }, float3 { x, h - 0.25, z }, 0.045, 0.04, dark, true))
            if not stub and style == 0:
                add_child(n, rod(float3 { x, -0.1, -width * 0.42 }, float3 { x, top - 0.04, width * 0.42 }, 0.02, 0.02, dark, false))
        let planks = int(half * 2.0 / 0.085)
        for(planks) k:
            let x = -half + (float(k) + 0.5) * half * 2.0 / float(planks)
            if not (gone(x) and randf(rng) < 0.92):
                let y = BRIDGE_DECK + bridge_hump(x, half, rise)
                let deep = width + randf_range(rng, -0.04, 0.04)
                let m = if randf(rng) < 0.75: wood else: dark
                let pz = randf_range(rng, -0.02, 0.02)
                let ry = randf_range(rng, -0.04, 0.04)
                add_child(n, box(float3 { 0.075, 0.025, deep }, m, float3 { x, y, pz }, float3 { 0.0, rad(ry), atan2(float2 { 1.0, bridge_slope(x, half, rise) }) }))
        for([ -1.0, 1.0 ]) side:
            let z = side * width * 0.47
            let posts = length + 2
            var prev = float3_0
            var has_prev = false
            for(posts) k:
                let x = -half + 0.12 + float(k) * (half * 2.0 - 0.24) / float(posts - 1)
                let y = BRIDGE_DECK + bridge_hump(x, half, rise)
                let top = float3 { x, y + 0.24, z }
                if gone(x):
                    has_prev = false
                else:
                    add_child(n, rod(float3 { x, y, z }, top, 0.022, 0.02, dark, true))
                    if has_prev:
                        if style == 2:
                            let mid = (prev + top) * 0.5 - float3 { 0.0, 0.05, 0.0 }
                            let rope = plain(html("#b8a070"))
                            add_child(n, rod(prev, mid, 0.008, 0.008, rope, false))
                            add_child(n, rod(mid, top, 0.008, 0.008, rope, false))
                        else:
                            add_child(n, rod(prev, top, 0.018, 0.018, wood, true))
                    prev = top
                    has_prev = true
    if broken == 1:
        for(4):
            let deep = width * randf_range(rng, 0.5, 0.9)
            let px = randf_range(rng, -0.8, 0.8)
            let pz = randf_range(rng, -0.5, 0.5)
            let rx = randf_range(rng, -0.2, 0.2)
            let ry = randf_range(rng, 0.0, MPI)
            add_child(n, box(float3 { 0.075, 0.02, deep }, wood, float3 { px, -0.01, pz }, float3 { rad(rx), rad(ry), 0.0 }))
    return n

def bridge_crib(n:MNode, x:float, h:float, wood:MMat, width:float):
    let rng = bridge_rng
    let top = (BRIDGE_DECK - 0.03) * h
    let layers = 4
    for(layers) k:
        let y = -0.15 + float(k) * (top + 0.15) / float(layers)
        if k % 2 == 0:
            for([ -width * 0.4, width * 0.4 ]) z:
                add_child(n, rod(float3 { x - 0.2, y, z }, float3 { x + 0.2, y, z }, 0.035, 0.035, wood, true))
        else:
            for([ -0.17, 0.17 ]) dx:
                add_child(n, rod(float3 { x + dx, y, -width * 0.45 }, float3 { x + dx, y, width * 0.45 }, 0.035, 0.035, wood, true))
    let stone = surf("rock", float3 { 0.7, 0.68, 0.6 }, 0.5)
    for(5):
        let sx = randf_range(rng, -0.1, 0.1)
        let sz = randf_range(rng, -0.25, 0.25)
        add_child(n, blob(float3 { 0.09, 0.06, 0.09 }, stone, float3 { x + sx, top - 0.02, sz }))

def bridge_hump(x:float, half:float, rise:float) -> float:
    let f = clamp(1.0 - abs(x) / half, 0.0, 1.0)
    return rise * sin(f * 90.0)

def bridge_slope(x:float, half:float, rise:float) -> float:
    return (bridge_hump(x + 0.01, half, rise) - bridge_hump(x - 0.01, half, rise)) / 0.02
