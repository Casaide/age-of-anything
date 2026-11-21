// ------------------------------------------------------------------ a building broken up (src/view/art/bake/ruin.gd; D-171, D-172)
// A building model broken up in 3D before it bakes, in stages, the way akb_hold_back holds parts back for
// construction. The art kit bakes stages 1-4 of every building look (not walls and gates); the game shows 1-3 as
// it's damaged and leaves 4 where it fell, a ruin that's only decoration and fades (game/fx.lobster).
// Stages (by damage taken): 0 whole, 1 battered (roof holed, a few pieces knocked askew, scorch), 2 breaking (the
// top half falling in, beams sagging, rubble spilling), 3 collapsed (stumps of wall in a heap, charred beams),
// 4 ruin (what lies there after it falls: footings, the heap). The same random numbers in the same order as
// Godot's, so the pieces are the same ones (building_check.sh's "ruin<s>" cases hold it to Godot's).
// Needs: gen/rng, model/kit, model/base, model/buildings (beam, bm).

// Per stage: the share of the height above which pieces may go, how many of those go, how many of the rest tilt
// (and how far, degrees), how many pieces scorch, rubble count, charred beams, and the height wall stumps are cut
// down to (0: no cut).
class RuinStage:
    above:float
    gone:float
    tilt:float
    deg:float
    scorch:float
    rubble:int
    beams:int
    cut:float

let RUIN_STAGES = [ RuinStage { 1.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0.0 },
                    RuinStage { 0.55, 0.3, 0.25, 12.0, 0.2, 26, 0, 0.0 },
                    RuinStage { 0.4, 0.6, 0.6, 26.0, 0.45, 70, 3, 0.0 },
                    RuinStage { 0.3, 1.0, 0.3, 18.0, 0.7, 140, 6, 0.42 },
                    RuinStage { 0.12, 1.0, 0.0, 0.0, 1.0, 190, 8, 0.16 } ]

class RuinMesh:
    node:MNode
    parents:Xform  // the transform of its parents, from the body
    lo:float3      // its box in body space
    hi:float3

def ruin_roll(rng:Rng) -> float: return float(next_u32(rng) % 10000) / 10000.0

// Goes up when the broken-up stages change, so a building's old bakes aren't reused (its part of the bake key; 2:
// what holds something up stays while it stands, #163).
let RUIN_LOOK = 2

// The stages a building shows while it still stands (battered, breaking): what holds something up stays upright.
let RUIN_STANDING = 2

// `up` rests on `down`: their boxes overlap across, and up's foot is at or in down's top (within `tol`), above down's
// foot (a rail post stands in its platform).
def ruin_rests_on(up:RuinMesh, down:RuinMesh, tol:float) -> bool:
    return up.lo.x < down.hi.x and down.lo.x < up.hi.x and up.lo.z < down.hi.z and down.lo.z < up.hi.z and down.lo.y < up.lo.y - tol * 0.2 and down.hi.y >= up.lo.y - tol

// Which pieces bear a load: on the ground, or with another piece resting on them.
def ruin_bearing(meshes:[RuinMesh], base:float, tol:float) -> [bool]:
    return map(meshes) d:
        d.lo.y - base <= tol or exists(meshes) u: u.node != d.node and u.node.visible and ruin_rests_on(u, d, tol)

// Every mesh under `node` (not the body itself), depth first as Godot's find_children.
def ruin_meshes(node:MNode, parents:Xform, out:[RuinMesh]) -> void:
    for(node.kids) k:
        let t = xmul(parents, node_xform(k))
        let m = k.mesh
        if m and m.p.length:
            var lo = float3_1 * 1000000000.0
            var hi = float3_1 * -1000000000.0
            for(m.p) q:
                lo = min(lo, q)
                hi = max(hi, q)
            var blo = float3_1 * 1000000000.0
            var bhi = float3_1 * -1000000000.0
            for(8) c:
                let corner = xf(t, float3 { if c & 1: hi.x else: lo.x, if c & 2: hi.y else: lo.y, if c & 4: hi.z else: lo.z })
                blo = min(blo, corner)
                bhi = max(bhi, corner)
            out.push(RuinMesh { k, parents, blo, bhi })
        ruin_meshes(k, t, out)

// A body-space transform `m` about `pivot` on a mesh whose parents' part is `parents`.
def ruin_move(mi:RuinMesh, m:Xform, pivot:float3):
    let about = xmul(xmul(Xform { BASIS_ID, pivot }, m), Xform { BASIS_ID, -pivot })
    set_xform(mi.node, xmul(xmul(xmul(xinverse(mi.parents), about), mi.parents), node_xform(mi.node)))

def ruin_scorch(n:MNode, k:float):
    let m = n.mat
    if not m: return
    let d = copy(m)
    d.albedo = darkened(d.albedo, k)
    n.mat = d

// Break `body` (a building model) to stage `s`, seeded by `seed_value` (hash_text of the look's name).
def ruin_apply(body:MNode, s:int, seed_value:int):
    let st = RUIN_STAGES[s]
    if s == 0: return
    let rng = new_rng(seed_value * 7919 + s * 104729)
    let meshes = []::RuinMesh
    ruin_meshes(body, XF_ID, meshes)
    var alo = float3_1 * 1000000000.0
    var ahi = float3_1 * -1000000000.0
    for(meshes) b:
        alo = min(alo, b.lo)
        ahi = max(ahi, b.hi)
    let asize = ahi - alo
    let h = asize.y
    let base = alo.y
    let mats = []::MMat  // what fell: the rubble is made of it
    // While it stands, a post under a platform or a tier under the next never goes or tilts (#163: a tower at half
    // health was a roof floating over stray posts).
    let bearing = ruin_bearing(meshes, base, h * 0.03)
    for(meshes) mi, mn:
        let held = s <= RUIN_STANDING and bearing[mn]
        let n = mi.node
        if not n.visible: continue
        let m = n.mat
        let mm = m
        let lit = mm and (mm.unshaded or mm.emission != float3_0)  // a lit window, a lantern: out once it's collapsing, and no rubble
        if lit and s >= 3:
            n.visible = false
            continue
        let bsize = mi.hi - mi.lo
        let centre = (mi.lo + mi.hi) * 0.5
        let roof = bsize.x > asize.x * 0.5 and bsize.z > asize.z * 0.5  // a whole roof as one piece: battered, it only slips
        let rel = (centre.y - base) / h
        var gone = false
        if st.cut > 0.0 and mi.lo.y - base < st.cut * h * 0.6 and mi.hi.y - base > st.cut * h:
            // A wall stump: what stands on the ground is squashed down from its foot to a ragged height.
            let top = base + h * st.cut * (0.55 + 0.6 * ruin_roll(rng))
            if m and (bsize.x > asize.x * 0.35 or bsize.z > asize.z * 0.35):
                n.visible = false  // a whole wall (or a hall's core) as one block: ragged stumps along its sides
                ruin_stumps(body, mi.lo, mi.hi, top, m, rng)
            else:
                let k = (top - mi.lo.y) / max(bsize.y, 0.001)
                let sq = Basis { float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, k, 0.0 }, float3 { 0.0, 0.0, 1.0 } }
                ruin_move(mi, Xform { sq, float3_0 }, float3 { centre.x, mi.lo.y, centre.z })
            if m and not lit: mats.push(m)
        elif not held and not (s == 1 and roof) and (rel > st.above or (st.cut > 0.0 and mi.hi.y - base > st.cut * h)) and ruin_roll(rng) < st.gone:
            n.visible = false
            if m and not lit: mats.push(m)
            gone = true
        elif not held and rel > st.above * 0.6 and ruin_roll(rng) < st.tilt:
            // Knocked askew: turned about its lowest edge and sagging a little.
            let ax = ruin_roll(rng) - 0.5
            let az = ruin_roll(rng) - 0.5
            let deg = st.deg * (0.5 + ruin_roll(rng))
            let sag = -h * 0.04 * float(s) * ruin_roll(rng)
            let axis = float3 { ax, 0.0, az }
            let turn = if magnitude(axis) > 0.0: axis_angle(axis, deg) else: BASIS_ID
            ruin_move(mi, Xform { turn, float3 { 0.0, sag, 0.0 } }, float3 { centre.x, mi.lo.y, centre.z })
        if not gone and ruin_roll(rng) < st.scorch:
            // (a big piece, a roof's underlay or a hall's wall, chars lightly: scorched like a beam it went black)
            ruin_scorch(n, (0.35 + 0.35 * ruin_roll(rng)) * (if bsize.x > asize.x * 0.35 or bsize.z > asize.z * 0.35: 0.35 else: 1.0))
    if not mats.length: mats.push(bm("stone"))
    ruin_rubble(body, alo, ahi, st.rubble, st.cut, mats, rng)
    let char_mat = MMat { float3 { 42.0, 36.0, 32.0 } / 255.0 }
    for(st.beams):
        let bx = 0.15 + 0.7 * ruin_roll(rng)
        let bz = 0.15 + 0.7 * ruin_roll(rng)
        let a = float3 { alo.x + (ahi.x - alo.x) * bx, 0.0, alo.z + (ahi.z - alo.z) * bz }
        let dx = ruin_roll(rng) - 0.5
        let dz = ruin_roll(rng) - 0.5
        let along = h * (0.25 + 0.3 * ruin_roll(rng))
        let flat = float3 { dx, 0.0, dz }
        var d = (if magnitude(flat) > 0.0: normalize(flat) else: float3_0) * along
        d = float3 { d.x, h * (0.12 + 0.25 * ruin_roll(rng)) * (if s < 4: 1.0 else: 0.3), d.z }
        add_child(body, beam(a, a + d, 0.022 + 0.012 * ruin_roll(rng), char_mat))

// The check (#163): pieces of a standing stage (1, 2) left in the air, every piece they rested on in the whole model
// gone or moved while they weren't. `whole` is ruin_meshes of the model before ruin_apply broke it, `seen` which of
// them showed then.
def ruin_floating(whole:[RuinMesh], seen:[bool], broken:MNode) -> int:
    let now = []::RuinMesh
    ruin_meshes(broken, XF_ID, now)
    var base = 1000000000.0
    var top = -base
    for(whole) b:
        base = min(base, b.lo.y)
        top = max(top, b.hi.y)
    let tol = (top - base) * 0.03
    def intact(i:int) -> bool: return now[i].node.visible and magnitude(now[i].lo - whole[i].lo) + magnitude(now[i].hi - whole[i].hi) < tol * 0.1
    var n = 0
    for(whole) u, i:
        if not seen[i] or not now[i].node.visible: continue
        var under = 0
        var held = 0
        for(whole) d, j:
            if j != i and seen[j] and ruin_rests_on(u, d, tol):
                under++
                if intact(j): held++
        if under > 0 and held == 0: n++
    return n

// A heap of broken pieces over the footprint, highest in the middle, spilling past the walls.
def ruin_rubble(body:MNode, alo:float3, ahi:float3, n:int, cut:float, mats:[MMat], rng:Rng):
    let c = (alo + ahi) * 0.5
    let size = ahi - alo
    let half = float2 { size.x, size.z } * 0.5
    let heap = size.y * (0.1 + cut * 0.6)
    for(n):
        let r = sqrt(ruin_roll(rng)) * 1.15
        let a = ruin_roll(rng) * 360.0
        let x = c.x + cos(a) * r * half.x
        let z = c.z + sin(a) * r * half.y
        let u = max(size.x, size.z) * 0.045  // pieces sized to the building: a hall breaks into bigger blocks
        let sx = u * (0.6 + 1.2 * ruin_roll(rng))
        let sy = u * (0.4 + 0.7 * ruin_roll(rng))
        let sz = u * (0.6 + 1.0 * ruin_roll(rng))
        let y = heap * max(0.0, 1.0 - r) * ruin_roll(rng) + sy * 0.4
        let m = mats[next_u32(rng) % mats.length]
        let rx = ruin_roll(rng) * 40.0 - 20.0
        let ry = ruin_roll(rng) * 180.0
        let rz = ruin_roll(rng) * 40.0 - 20.0
        add_child(body, box(float3 { sx, sy, sz }, m, float3 { x, y, z }, float3 { rx, ry, rz }))

// Ragged wall stumps along the sides of a box (body space): short pieces of its own material, each a different
// height up to `top`, some missing (the breaches).
def ruin_stumps(body:MNode, lo:float3, hi:float3, top:float, m:MMat, rng:Rng):
    let t = min(hi.x - lo.x, hi.z - lo.z) * 0.12
    let corners = [ float3 { lo.x, 0.0, lo.z }, float3 { hi.x, 0.0, lo.z }, float3 { hi.x, 0.0, hi.z }, float3 { lo.x, 0.0, hi.z } ]
    for(4) e:
        let a = corners[e]
        let c = corners[(e + 1) % 4]
        let run = magnitude(c - a)
        let n = max(2, int(run / (t * 2.2)))
        for(n) i:
            if ruin_roll(rng) < 0.18: continue  // a breach
            let f0 = float(i) / float(n)
            let f1 = float(i + 1) / float(n)
            let at = a + (c - a) * ((f0 + f1) * 0.5)
            let hgt = max(t, (top - lo.y) * (0.25 + 0.75 * ruin_roll(rng)))
            let along = run / float(n)
            let on_x = abs(c.x - a.x) > 0.001
            let sz = float3 { if on_x: along else: t, hgt, if on_x: t else: along }
            let rx = ruin_roll(rng) * 6.0 - 3.0
            let rz = ruin_roll(rng) * 6.0 - 3.0
            add_child(body, box(sz, m, float3 { at.x, lo.y + hgt * 0.5, at.z }, float3 { rx, 0.0, rz }))
