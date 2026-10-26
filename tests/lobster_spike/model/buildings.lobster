// ------------------------------------------------------------------ buildings (src/view/art/bake/models.gd, lines 1-2200)
// Every building in every architecture, in world units (1 = a tile; y up; sim x = world x, sim y = world z), each
// builder models.gd's of the same name without the leading underscore where it has no clash (`_barracks` ->
// barracks; private helpers that could clash carry a bld_ prefix: `_footing` -> bld_footing), line for line (its
// comments are there). The rest of the file (castles, universities, walls, gates, building() and look()) is in
// model/buildings2.lobster. A builder returns a BSpec (models.gd's dictionary: the body, the live bits, the points
// the 2D side needs); the props and flags return an MNode, as there.
// Materials: bm(name) is mats.get_mat(name) (cached, as Godot's), bflat/bmat from model/build_mats.lobster.
// The shared generator: models.gd's one `rng`, here brng (seeded where models.gd seeds it; where it doesn't, it
// carries on from whatever drew from it last, as there).

let BLD_UP = float3 { 0.0, 1.0, 0.0 }
var brng = grng(0)
var gate_span = 3.0   // a gate's length end to end in tiles (ArtKit sets it: 3 x sqrt 2 on a diagonal)

def bv(x:float, y:float, z:float) -> float3: return float3 { x, y, z }

// models.gd's dictionary: the body, the live parts (banner, vane), the open state (gates), a wall's arms and icon,
// its points (anchor, banner_pivot, vane_pivot, smoke, lantern, door, window), lights, doorway, team.
class BSpec:
    body:MNode
    banner:MNode? = nil
    vane:MNode? = nil
    open:MNode? = nil
    icon:MNode? = nil
    arms = []::MNode
    pts = dictionary<string, float3>(11)
    lights = []::float3
    doorway = []::float3
    has_doorway = false
    team = float3_0
    has_team = false

def bspec(body:MNode) -> BSpec:
    let s = BSpec { body }
    s.pts.set("anchor", float3_0)
    return s

def bpt(s:BSpec, k:string, v:float3) -> BSpec:
    s.pts.set(k, v)
    return s

def bteam(s:BSpec, team:float3) -> BSpec:
    s.team = team
    s.has_team = true
    return s

def blights(s:BSpec, l:[float3]) -> BSpec:
    s.lights = l
    return s

def bdoorway(s:BSpec, d:[float3]) -> BSpec:
    s.doorway = d
    s.has_doorway = true
    return s

def bbanner(s:BSpec, banner:MNode, pivot:float3) -> BSpec:
    s.banner = banner
    return bpt(s, "banner_pivot", pivot)

def bvane(s:BSpec, vane:MNode, pivot:float3) -> BSpec:
    s.vane = vane
    return bpt(s, "vane_pivot", pivot)

// ---- materials (models.gd: mats.get_mat, Materials.flat, cloth, glow)

let bld_mat_cache = dictionary<string, MMat>(31)

def bm(name:string) -> MMat:
    let m = bld_mat_cache.get(name)
    if m: return m
    let n = bmat(name)
    bld_mat_cache.set(name, n)
    return n

// The name a material was got by (bm), or "" for a flat one.
def bm_name(m:MMat) -> string:
    for(bld_mat_cache.get_keys()) k:
        if bld_mat_cache.get(k) == m: return k
    return ""

def bcloth(team:float3) -> MMat:
    let m = bflat(team, 0.85)
    m.two_sided = true
    return m

def bglow(c:float3, energy:float = 2.5) -> MMat:
    let m = bflat(c, 0.5)
    m.emission = c * energy
    return m

// ---- shapes (models.gd's box, cyl, ball, dome, ring: Godot's primitives with these segments)

def bmi(mesh:MMesh, m:MMat, pos:float3, rot:float3, scl:float3) -> MNode:
    let n = mesh_node(mesh, m)
    n.pos = pos
    n.rot = rot
    n.scl = scl
    return n

def bbox(size:float3, m:MMat, pos:float3 = float3_0, rot:float3 = float3_0) -> MNode:
    return bmi(box_mesh(size, 0, 0, 0), m, pos, rot, float3_1)

def bcyl(r_top:float, r_bot:float, h:float, m:MMat, pos:float3 = float3_0, rot:float3 = float3_0, seg:int = 16) -> MNode:
    return bmi(cylinder_mesh(r_top, r_bot, h, seg, 4, true, true), m, pos, rot, float3_1)

def bball(r:float, m:MMat, pos:float3 = float3_0, scl:float3 = float3_1, rot:float3 = float3_0) -> MNode:
    return bmi(sphere_mesh(r, r * 2.0, 32, 16, false), m, pos, rot, scl)

def bdome(r:float, m:MMat, pos:float3 = float3_0, scl:float3 = float3_1) -> MNode:
    return bmi(sphere_mesh(r, r, 32, 10, true), m, pos, float3_0, scl)

def bring(inner:float, outer:float, m:MMat, pos:float3 = float3_0, rot:float3 = float3_0, scl:float3 = float3_1) -> MNode:
    return bmi(torus_mesh(inner, outer, 32, 12), m, pos, rot, scl)

// The last child added (Godot's get_child(get_child_count() - 1)).
def last_kid(n:MNode) -> MNode: return n.kids[n.kids.length - 1]

// ------------------------------------------------------------------ props

def barrel(at:float3, parent:MNode):
    let wood = bm("wood")
    let band = bflat(html("#3a3430"), 0.4, 0.7)
    add_child(parent, bcyl(0.13, 0.13, 0.34, wood, at + bv(0.0, 0.17, 0.0)))
    add_child(parent, bball(0.15, wood, at + bv(0.0, 0.17, 0.0), bv(1.0, 1.15, 1.0)))
    for([0.06, 0.28]) y:
        add_child(parent, bring(0.14, 0.16, band, at + bv(0.0, y, 0.0)))
    add_child(parent, bcyl(0.12, 0.12, 0.02, wood, at + bv(0.0, 0.35, 0.0)))

def crate(at:float3, parent:MNode, turn:float = 0.0):
    let wood = bm("wood")
    let c = mnode()
    c.pos = at
    c.rot = bv(0.0, turn, 0.0)
    add_child(parent, c)
    add_child(c, bbox(bv(0.3, 0.26, 0.3), wood, bv(0.0, 0.13, 0.0)))
    let dark = bflat(html("#4a2f1c"), 0.9)
    for([-0.151, 0.151]) z:
        add_child(c, bbox(bv(0.31, 0.04, 0.01), dark, bv(0.0, 0.22, z)))
        add_child(c, bbox(bv(0.31, 0.04, 0.01), dark, bv(0.0, 0.04, z)))
        add_child(c, bbox(bv(0.36, 0.035, 0.01), dark, bv(0.0, 0.13, z), bv(0.0, 0.0, 38.0)))

def woodpile(at:float3, parent:MNode):
    let wood = bm("wood")
    let ends = bflat(html("#c8a06a"), 0.9)
    let ys = [0.06, 0.17, 0.28]
    let zs = [[-0.15, 0.0, 0.15], [-0.075, 0.075], [0.0]]
    for(3) r:
        for(zs[r]) z:
            add_child(parent, bcyl(0.065, 0.065, 0.55, wood, at + bv(0.0, ys[r], z), bv(0.0, 0.0, 90.0), 10))
            add_child(parent, bcyl(0.06, 0.06, 0.01, ends, at + bv(0.276, ys[r], z), bv(0.0, 0.0, 90.0), 10))

// ------------------------------------------------------------------ buildings

def bld_doorway(foot:float3, w:float, h:float, round:bool = false) -> [float3]:
    let out = [foot + bv(-w / 2.0, 0.0, 0.0), foot + bv(w / 2.0, 0.0, 0.0), foot + bv(-w / 2.0, h, 0.0)]
    if round: out.push(float3_0)   // a fourth point marks it round
    return out

def town_center(team:float3) -> BSpec:
    brng = grng(42)
    let body = mnode()
    let stone = bm("stone")
    let wood = bm("wood")
    let mud = bm("mud")
    let thatch = bm("thatch")
    bld_footing(body, "thatch", 2.8, 2.8, 0.22)
    let w = 2.1
    let h = 1.15
    let base = 0.22
    add_child(body, bbox(bv(w, h, w), mud, bv(0.0, base + h / 2.0, 0.0)))
    for([-1, 0, 1]) x:
        for([-1, 0, 1]) z:
            if not (x == 0 and z == 0):
                if abs(x) == 1 or abs(z) == 1:
                    if x == 0 or z == 0 or (abs(x) == 1 and abs(z) == 1):
                        add_child(body, bbox(bv(0.12, h + 0.04, 0.12), wood, bv(float(x) * w / 2.0, base + h / 2.0, float(z) * w / 2.0)))
    for([base + 0.05, base + h * 0.55, base + h - 0.04]) y:
        for([-1.0, 1.0]) side:
            add_child(body, bbox(bv(w + 0.1, 0.09, 0.1), wood, bv(0.0, y, side * w / 2.0)))
            add_child(body, bbox(bv(0.1, 0.09, w + 0.1), wood, bv(side * w / 2.0, y, 0.0)))
    for([-1.0, 1.0]) d:
        add_child(body, bbox(bv(0.08, 0.62, 0.06), wood, bv(d * 0.52, base + h * 0.28, w / 2.0 + 0.02), bv(0.0, 0.0, d * 38.0)))
        add_child(body, bbox(bv(0.06, 0.62, 0.08), wood, bv(w / 2.0 + 0.02, base + h * 0.28, d * 0.52), bv(d * 38.0, 0.0, 0.0)))
    let door_wood = bflat(html("#3e2616"), 0.8)
    add_child(body, bbox(bv(0.46, 0.7, 0.05), door_wood, bv(-0.15, base + 0.35, w / 2.0 + 0.03)))
    add_child(body, bcyl(0.23, 0.23, 0.05, door_wood, bv(-0.15, base + 0.7, w / 2.0 + 0.03), bv(90.0, 0.0, 0.0)))
    for([-0.42, 0.12]) x:
        add_child(body, bbox(bv(0.07, 0.95, 0.08), wood, bv(x, base + 0.47, w / 2.0 + 0.05)))
    add_child(body, bbox(bv(0.65, 0.09, 0.1), wood, bv(-0.15, base + 0.97, w / 2.0 + 0.05)))
    add_child(body, bbox(bv(0.05, 0.05, 0.02), bflat(html("#b89a5a"), 0.3, 0.8), bv(0.0, base + 0.36, w / 2.0 + 0.065)))
    let lights = []::float3
    for([-0.5, 0.45]) z:
        add_child(body, bbox(bv(0.04, 0.3, 0.3), bglow(html("#ffcf6a"), 1.6), bv(w / 2.0 + 0.01, base + 0.78, z)))
        add_child(body, bbox(bv(0.05, 0.34, 0.06), wood, bv(w / 2.0 + 0.04, base + 0.78, z + 0.18)))
        add_child(body, bbox(bv(0.05, 0.34, 0.06), wood, bv(w / 2.0 + 0.04, base + 0.78, z - 0.18)))
        add_child(body, bbox(bv(0.05, 0.05, 0.42), wood, bv(w / 2.0 + 0.04, base + 0.96, z)))
        add_child(body, bbox(bv(0.12, 0.32, 0.03), door_wood, bv(w / 2.0 + 0.1, base + 0.78, z + 0.24), bv(0.0, -55.0, 0.0)))
        lights.push(bv(w / 2.0 + 0.05, base + 0.78, z))
    let roof_y = base + h
    add_child(body, bcyl(0.0, 1.95, 1.35, thatch, bv(0.0, roof_y + 0.6, 0.0), bv(0.0, 45.0, 0.0), 4))
    add_child(body, bcyl(0.0, 1.62, 1.15, thatch, bv(0.0, roof_y + 0.92, 0.0), bv(0.0, 45.0, 0.0), 4))
    add_child(body, bcyl(0.0, 0.32, 0.32, bflat(html("#5a4220"), 0.9), bv(0.0, roof_y + 1.42, 0.0), bv(0.0, 45.0, 0.0), 4))
    let chim = bv(-0.55, roof_y + 1.0, -0.55)
    add_child(body, bbox(bv(0.3, 1.0, 0.3), stone, chim))
    add_child(body, bbox(bv(0.36, 0.08, 0.36), stone, chim + bv(0.0, 0.5, 0.0)))
    barrel(bv(0.75, base, 1.25), body)
    barrel(bv(1.05, base, 1.05), body)
    crate(bv(-0.85, base, 1.2), body, 20.0)
    woodpile(bv(1.25, base, -0.35), body)
    let pole_at = bv(-1.25, 0.22, 1.25)
    add_child(body, bcyl(0.035, 0.04, 2.2, wood, pole_at + bv(0.0, 1.1, 0.0), float3_0, 8))
    add_child(body, bball(0.06, bflat(html("#b89a5a"), 0.3, 0.8), pole_at + bv(0.0, 2.22, 0.0)))
    let banner = mnode()
    let flag_top = pole_at + bv(0.04, 2.1, 0.0)
    add_child(banner, bbox(bv(0.62, 0.85, 0.02), bcloth(team), flag_top + bv(0.33, -0.42, 0.0)))
    add_child(banner, bbox(bv(0.64, 0.06, 0.03), wood, flag_top + bv(0.33, 0.0, 0.0)))
    add_child(banner, bball(0.13, bcloth(html("#e8e4d8")), flag_top + bv(0.33, -0.4, 0.015), bv(1.0, 1.0, 0.1)))
    let vane = mnode()
    let apex = bv(0.0, roof_y + 1.58, 0.0)
    let metal = bflat(html("#5e6a66"), 0.35, 0.8)
    add_child(vane, bcyl(0.012, 0.012, 0.4, metal, apex + bv(0.0, 0.2, 0.0), float3_0, 6))
    add_child(vane, bcyl(0.025, 0.025, 0.4, metal, apex + bv(0.0, 0.38, 0.0), bv(0.0, 0.0, 90.0), 6))
    for([-1.0, 1.0]) s:
        add_child(vane, bball(0.12, bflat(html("#7fb6c8"), 0.2, 0.3), apex + bv(0.05, 0.4, s * 0.1), bv(0.5, 0.06, 1.0)))
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bvane(sp, vane, apex)
    bpt(sp, "smoke", chim + bv(0.0, 0.55, 0.0))
    blights(sp, lights)
    bpt(sp, "lantern", bv(0.18, base + 0.75, w / 2.0 + 0.15))
    return bdoorway(sp, bld_doorway(bv(-0.15, base, w / 2.0 + 0.06), 0.46, 0.82))

def stilt_house(team:float3) -> BSpec:
    brng = grng(7)
    let body = mnode()
    let wood = bm("wood")
    let mud = bm("mud")
    let thatch = bm("thatch")
    for([-0.6, 0.6]) x:
        for([-0.6, 0.6]) z:
            let rx = randf_range(brng, -4.0, 4.0)
            let rz = randf_range(brng, -4.0, 4.0)
            add_child(body, bcyl(0.06, 0.07, 0.45, wood, bv(x, 0.22, z), bv(rx, 0.0, rz), 10))
    for(7) k:
        add_child(body, bbox(bv(1.55, 0.06, 0.21), wood, bv(0.0, 0.47, -0.66 + float(k) * 0.22), bv(0.0, randf_range(brng, -2.0, 2.0), 0.0)))
    add_child(body, bcyl(0.6, 0.62, 0.72, mud, bv(0.0, 0.86, 0.0), float3_0, 24))
    for([0.55, 1.18]) y:
        add_child(body, bring(0.6, 0.66, wood, bv(0.0, y, 0.0)))
    for(6) k:
        let a = 360.0 * float(k) / 6.0
        add_child(body, bbox(bv(0.07, 0.72, 0.07), wood, bv(cos(a) * 0.62, 0.86, sin(a) * 0.62)))
    add_child(body, bbox(bv(0.32, 0.5, 0.05), bflat(html("#3e2616"), 0.8), bv(0.05, 0.75, 0.6), bv(0.0, 8.0, 0.0)))
    add_child(body, bcyl(0.0, 0.95, 0.85, thatch, bv(0.0, 1.62, 0.0), float3_0, 24))
    add_child(body, bcyl(0.0, 0.8, 0.5, thatch, bv(0.0, 1.95, 0.0), bv(0.0, 17.0, 0.0), 24))
    add_child(body, bcyl(0.05, 0.05, 0.25, bflat(html("#3a3430"), 0.4, 0.7), bv(0.35, 1.95, -0.2), float3_0, 8))
    let foot = bv(0.0, 0.0, 1.12)
    let top = bv(0.0, 0.5, 0.8)
    let along = top - foot
    let tilt = atan2(float2 { along.y, along.z })
    for([-0.12, 0.22]) x:
        add_child(body, bbox(bv(0.04, magnitude(along), 0.04), wood, lerp3(foot, top, 0.5) + bv(x, 0.0, 0.0), bv(tilt, 0.0, 0.0)))
    for(4) k:
        add_child(body, bbox(bv(0.36, 0.03, 0.03), wood, lerp3(foot, top, float(k + 1) / 5.0) + bv(0.05, 0.0, 0.0)))
    let sp = bspec(body)
    bpt(sp, "smoke", bv(0.35, 2.1, -0.2))
    bpt(sp, "lantern", bv(0.32, 0.95, 0.66))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bteam(sp, team)

// ------------------------------------------------------------------ the frog

def flowers(seed_value:int) -> MNode:
    brng = grng(seed_value)
    let n = mnode()
    let stem = bflat(html("#4e7a2c"), 1.0)
    let petals = [html("#f4f0e0"), html("#f2c94c"), html("#e07a9a"), html("#a08ae0")][randi_range(brng, 0, 3)]
    for(randi_range(brng, 3, 6)):
        let px = randf_range(brng, -0.18, 0.18)
        let pz = randf_range(brng, -0.18, 0.18)
        let p = bv(px, 0.0, pz)
        let h = randf_range(brng, 0.08, 0.15)
        add_child(n, bcyl(0.006, 0.008, h, stem, p + bv(0.0, h / 2.0, 0.0), float3_0, 5))
        add_child(n, bball(0.045, bflat(petals, 1.0), p + bv(0.0, h, 0.0), bv(1.0, 0.5, 1.0)))
        add_child(n, bball(0.035, stem, p + bv(0.02, 0.015, 0.0), bv(1.4, 0.4, 0.8)))   // a leaf
        add_child(n, bball(0.012, bflat(html("#e0a020"), 1.0), p + bv(0.0, h + 0.01, 0.0)))
    return n

// A rat Town Center built from scrap (h: wall height; pitch: roof slope; berm: earth banked against the walls).
def junk_town_center(team:float3, h:float = 1.05, pitch:float = 32.0, berm:bool = false, plinth:bool = true) -> BSpec:
    brng = grng(66)
    let body = mnode()
    let brick = bm("brick")
    let wood = bm("wood")
    let tin = bm("tin")
    let iron = bflat(html("#4a4a48"), 0.5, 0.6)
    var base = 0.25
    if berm or not plinth:
        base = 0.02
    else:
        add_child(body, bbox(bv(2.8, 0.25, 2.8), brick, bv(0.0, 0.12, 0.0)))
    let w = 2.1
    for([-1.0, 1.0]) side:
        for(7) k:
            let t = -w / 2.0 + 0.15 + float(k) * 0.3
            let hh = h + randf_range(brng, -0.12, 0.08)
            let tint = bflat(lerp3(html("#6e4a2c"), html("#8a7050"), randf(brng)), 0.9)
            add_child(body, bbox(bv(0.28, hh, 0.08), tint, bv(t, base + hh / 2.0, side * w / 2.0), bv(0.0, 0.0, randf_range(brng, -3.0, 3.0))))
            add_child(body, bbox(bv(0.08, hh, 0.28), tint, bv(side * w / 2.0, base + hh / 2.0, t), bv(randf_range(brng, -3.0, 3.0), 0.0, 0.0)))
    add_child(body, bbox(bv(w - 0.1, h, w - 0.1), wood, bv(0.0, base + h / 2.0, 0.0)))
    add_child(body, bbox(bv(0.6, 0.5, 0.02), tin, bv(0.5, base + 0.4, w / 2.0 + 0.06), bv(0.0, 0.0, 8.0)))
    add_child(body, bbox(bv(0.02, 0.55, 0.7), tin, bv(w / 2.0 + 0.06, base + 0.65, -0.4), bv(-6.0, 0.0, 0.0)))
    add_child(body, bbox(bv(0.45, 0.7, 0.05), bflat(html("#2a1e16"), 0.9), bv(-0.35, base + 0.35, w / 2.0 + 0.08)))
    let lights = []::float3
    for([-0.55, 0.35]) z:
        add_child(body, bbox(bv(0.04, 0.26, 0.3), bglow(html("#ffcf6a"), 1.4), bv(w / 2.0 + 0.07, base + 0.7, z)))
        lights.push(bv(w / 2.0 + 0.1, base + 0.7, z))
    let roof_y = base + h
    let ridge = sin(pitch) / cos(pitch) * 1.375
    for([-1.0, 1.0]) side:
        add_child(body, bbox(bv(2.7, 0.05, 1.6), tin, bv(0.0, roof_y + ridge * 0.5, side * 0.68), bv(side * pitch, 0.0, 0.0)))
    add_child(body, bbox(bv(2.75, 0.08, 0.16), iron, bv(0.0, roof_y + ridge, 0.0)))
    for([-1.0, 1.0]) side:
        let gable = add_child(body, slab_tri(float2 { -1.1, 0.0 }, float2 { 1.1, 0.0 }, float2 { 0.0, ridge }, 0.06, wood))
        gable.pos = bv(side * 1.05, roof_y, 0.0)
        gable.rot = bv(0.0, 90.0, 0.0)
    let pipe = bv(0.6, roof_y + ridge * 0.7, -0.55)
    add_child(body, bcyl(0.11, 0.11, 0.9, iron, pipe))
    add_child(body, bcyl(0.11, 0.11, 0.35, iron, pipe + bv(0.12, 0.5, 0.0), bv(0.0, 0.0, -50.0)))
    add_child(body, bcyl(0.15, 0.13, 0.1, iron, pipe + bv(0.28, 0.62, 0.0), bv(0.0, 0.0, -50.0)))
    add_child(body, bbox(bv(0.6, 0.03, 0.4), bflat(html("#1e1c1a"), 0.6), bv(0.6, 0.27, 1.15)))
    for(5) k:
        add_child(body, bbox(bv(0.04, 0.05, 0.4), iron, bv(0.38 + float(k) * 0.11, 0.29, 1.15)))
    let cheese = bflat(html("#f2c94c"), 0.7)
    add_child(body, bcyl(0.3, 0.3, 0.2, cheese, bv(-1.0, 0.36, 1.05), float3_0, 20))
    add_child(body, bcyl(0.3, 0.3, 0.02, bflat(html("#c99a1e"), 0.8), bv(-1.0, 0.47, 1.05), float3_0, 20))
    barrel(bv(1.15, base, 0.95), body)
    crate(bv(1.2, base, -1.0), body, 35.0)
    if berm:
        let earth = bm("mud")
        let turf = bflat(html("#5e7a34"), 0.95)
        add_child(body, bcyl(1.13 * 1.414, 1.55 * 1.414, 0.45, earth, bv(0.0, 0.225, 0.0), bv(0.0, 45.0, 0.0), 4))
        add_child(body, bcyl(1.12 * 1.414, 1.3 * 1.414, 0.12, turf, bv(0.0, 0.41, 0.0), bv(0.0, 45.0, 0.0), 4))
        for(3) k:
            add_child(body, bcyl(0.11, 0.11, 0.5, iron, bv(-1.3 + float(k) * 0.55, 0.18, -1.3), bv(70.0, float(k) * 25.0, 0.0)))
        add_child(body, bbox(bv(0.5, 0.03, 0.4), tin, bv(1.3, 0.3, 0.4), bv(20.0, 30.0, 10.0)))
    let pole_at = bv(-1.2, 0.25, -1.1)
    add_child(body, bcyl(0.03, 0.035, 1.9, wood, pole_at + bv(0.0, 0.95, 0.0), float3_0, 8))
    let banner = mnode()
    let flag_top = pole_at + bv(0.03, 1.8, 0.0)
    add_child(banner, bbox(bv(0.55, 0.55, 0.02), bcloth(darkened(team, 0.15)), flag_top + bv(0.3, -0.28, 0.0), bv(0.0, 0.0, -4.0)))
    add_child(banner, bbox(bv(0.2, 0.2, 0.025), bcloth(html("#e8dcc0")), flag_top + bv(0.18, -0.4, 0.01)))
    let vane = mnode()
    add_child(vane, bcyl(0.01, 0.01, 0.3, iron, bv(0.0, roof_y + ridge + 0.19, 0.0), float3_0, 6))
    add_child(vane, bball(0.07, bflat(html("#f2c94c"), 0.6), bv(0.0, roof_y + ridge + 0.36, 0.0)))
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bvane(sp, vane, bv(0.0, roof_y + ridge + 0.04, 0.0))
    bpt(sp, "smoke", pipe + bv(0.32, 0.68, 0.0))
    blights(sp, lights)
    bpt(sp, "lantern", bv(0.05, base + 0.8, w / 2.0 + 0.15))
    return bdoorway(sp, bld_doorway(bv(-0.35, base, w / 2.0 + 0.11), 0.45, 0.7))

def tin_can_house(team:float3) -> BSpec:
    let body = mnode()
    let tin = bm("tin")
    add_child(body, bcyl(0.7, 0.7, 1.05, tin, bv(0.0, 0.53, 0.0), float3_0, 28))
    for([0.12, 0.5, 0.92]) y:
        add_child(body, bring(0.69, 0.75, bflat(html("#9a9c96"), 0.5, 0.5), bv(0.0, y, 0.0)))
    add_child(body, bbox(bv(0.36, 0.55, 0.05), bflat(html("#1e1612"), 0.9), bv(0.1, 0.3, 0.69), bv(0.0, 8.0, 0.0)))
    add_child(body, bbox(bv(0.36, 0.55, 0.03), tin, bv(0.38, 0.3, 0.78), bv(0.0, -40.0, 0.0)))   // the cut flap
    add_child(body, bcyl(0.78, 0.78, 0.06, tin, bv(0.08, 1.12, 0.02), bv(6.0, 0.0, -5.0), 28))      // the lid
    add_child(body, bball(0.16, bm("stone"), bv(-0.15, 1.24, -0.1), bv(1.2, 0.8, 1.0)))
    add_child(body, bcyl(0.06, 0.06, 0.35, bflat(html("#4a4a48"), 0.5, 0.6), bv(0.35, 1.3, -0.3), float3_0, 8))
    add_child(body, bbox(bv(0.25, 0.04, 0.12), bcloth(team), bv(-0.5, 0.75, 0.48), bv(0.0, 40.0, 10.0)))   // a team rag
    let sp = bspec(body)
    bpt(sp, "smoke", bv(0.35, 1.5, -0.3))
    bpt(sp, "lantern", bv(0.4, 0.75, 0.75))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bteam(sp, team)

// A triangle in xy given a thickness (both faces, no sides), as models.gd's SurfaceTool builds it.
def slab_tri(a:float2, b:float2, c:float2, thick:float, m:MMat) -> MNode:
    let mesh = new_mesh()
    for([1.0, -1.0]) face:
        for(if face > 0.0: [a, b, c] else: [a, c, b]) p:
            add_vertex(mesh, bv(p.x, p.y, thick * 0.5 * face), bv(0.0, 0.0, face), float2_0)
    mesh.idx = map(mesh.p.length) i: i
    return mesh_node(mesh, m)

// ------------------------------------------------------------------ stone culture (imperial, hellenic, royal)

// A cylinder from a to b.
def beam(a:float3, b:float3, r:float, m:MMat, seg:int = 8) -> MNode:
    let mi = bcyl(r, r, magnitude(b - a), m, (a + b) * 0.5, float3_0, seg)
    let d = normalize(b - a)
    // Godot's Quaternion(UP, -UP) turns half way round (1, 0, 0) x UP, the z axis
    set_basis(mi, if dot(d, BLD_UP) < -1.0 + 0.00001: axis_angle(float3 { 0.0, 0.0, 1.0 }, 180.0) else: arc(BLD_UP, d))
    return mi

// A terracotta gable roof, ridge along z. Returns its rise.
def tile_roof(parent:MNode, centre:float3, half_span:float, length:float, pitch_deg:float, front_gable:MMat, back_gable:MMat) -> float:
    let tile = bm("terracotta")
    let rise = half_span * sin(pitch_deg) / cos(pitch_deg)
    let slope = half_span / cos(pitch_deg)
    for([-1.0, 1.0]) side:
        add_child(parent, bbox(bv(slope + 0.06, 0.05, length), bm("terracotta_dark"), centre + bv(side * half_span / 2.0, rise / 2.0, 0.0), bv(0.0, 0.0, -side * pitch_deg)))
        var z = -length / 2.0 + 0.07
        while z < length / 2.0 - 0.04:
            let top = centre + bv(0.0, rise + 0.03, z)
            let eave = centre + bv(side * (half_span + 0.03), 0.0, z)
            add_child(parent, beam(top, eave, 0.05, tile))
            z += 0.17
    add_child(parent, beam(centre + bv(0.0, rise + 0.05, -length / 2.0 - 0.02), centre + bv(0.0, rise + 0.05, length / 2.0 + 0.02), 0.06, tile))
    for([1.0, -1.0]) e:
        let g = add_child(parent, slab_tri(float2 { -half_span, 0.0 }, float2 { half_span, 0.0 }, float2 { 0.0, rise }, 0.08, if e > 0.0: front_gable else: back_gable))
        g.pos = centre + bv(0.0, 0.0, e * (length / 2.0 - 0.05))
    return rise

def stone_town_center(team:float3) -> BSpec:
    let body = mnode()
    let stone = bm("stone")
    let plaster = bm("plaster")
    let marble = bflat(html("#e6e0d2"), 0.75)
    let bronze = bflat(html("#b07a36"), 0.4, 0.7)
    add_child(body, bbox(bv(2.9, 0.14, 2.9), stone, bv(0.0, 0.07, 0.0)))
    add_child(body, bbox(bv(2.6, 0.14, 2.6), stone, bv(0.0, 0.21, 0.0)))
    let base = 0.28
    let w = 1.9
    let d = 1.55
    let h = 1.0
    let hall_z = -0.35
    add_child(body, bbox(bv(w + 0.06, 0.14, d + 0.06), stone, bv(0.0, base + 0.07, hall_z)))
    add_child(body, bbox(bv(w, h, d), plaster, bv(0.0, base + h / 2.0, hall_z)))
    add_child(body, bbox(bv(w + 0.03, 0.12, d + 0.03), bcloth(team), bv(0.0, base + h - 0.16, hall_z)))   // frieze
    add_child(body, bbox(bv(w + 0.08, 0.07, d + 0.08), marble, bv(0.0, base + h - 0.035, hall_z)))
    let lights = []::float3
    for([-0.75, 0.05]) z:
        add_child(body, bbox(bv(0.04, 0.32, 0.22), bglow(html("#ffcf6a"), 1.4), bv(w / 2.0 + 0.01, base + 0.55, hall_z + z + 0.35)))
        add_child(body, bbox(bv(0.08, 0.05, 0.3), marble, bv(w / 2.0 + 0.03, base + 0.37, hall_z + z + 0.35)))
        lights.push(bv(w / 2.0 + 0.04, base + 0.55, hall_z + z + 0.35))
    let front_wall = hall_z + d / 2.0
    add_child(body, bbox(bv(0.5, 0.74, 0.04), bflat(html("#4a2a18"), 0.8), bv(0.0, base + 0.37, front_wall + 0.02)))
    add_child(body, bbox(bv(0.6, 0.08, 0.06), marble, bv(0.0, base + 0.78, front_wall + 0.03)))
    for(6) k:
        add_child(body, bball(0.022, bronze, bv(-0.15 + float(k % 3) * 0.15, base + 0.25 + float(k / 3) * 0.3, front_wall + 0.045)))
    let porch_z = front_wall + 0.5
    for(4) k:
        let x = -0.78 + float(k) * 0.52
        add_child(body, bcyl(0.075, 0.09, h - 0.12, marble, bv(x, base + h / 2.0, porch_z), float3_0, 14))
        add_child(body, bbox(bv(0.22, 0.06, 0.22), marble, bv(x, base + 0.03, porch_z)))
        add_child(body, bbox(bv(0.24, 0.07, 0.24), marble, bv(x, base + h - 0.035, porch_z)))
    add_child(body, bbox(bv(w + 0.12, 0.14, porch_z - front_wall + 0.2), marble, bv(0.0, base + h + 0.07, (porch_z + front_wall) / 2.0)))
    let roof_c = bv(0.0, base + h + 0.14, (hall_z - d / 2.0 - 0.12 + porch_z + 0.16) / 2.0)
    let length = (porch_z + 0.16) - (hall_z - d / 2.0 - 0.12)
    let rise = tile_roof(body, roof_c, w / 2.0 + 0.14, length, 24.0, marble, plaster)
    add_child(body, bball(0.13, bcloth(team), roof_c + bv(0.0, rise * 0.4, length / 2.0 - 0.0), bv(1.0, 1.0, 0.3)))
    add_child(body, bring(0.12, 0.16, bronze, roof_c + bv(0.0, rise * 0.4, length / 2.0 + 0.01), bv(90.0, 0.0, 0.0)))
    for([-w / 2.0 - 0.1, 0.0, w / 2.0 + 0.1]) x:   // little finials on the pediment
        add_child(body, bball(0.06, marble, roof_c + bv(x, if x == 0.0: rise + 0.08 else: 0.06, length / 2.0)))
    let bowl = bv(1.05, base, 1.05)
    for(3) k:
        let a = 360.0 * float(k) / 3.0
        add_child(body, beam(bowl + bv(cos(a) * 0.12, 0.0, sin(a) * 0.12), bowl + bv(0.0, 0.42, 0.0), 0.015, bronze))
    add_child(body, bcyl(0.16, 0.08, 0.1, bronze, bowl + bv(0.0, 0.46, 0.0), float3_0, 16))
    add_child(body, bcyl(0.13, 0.13, 0.02, bglow(html("#ff9a3a"), 2.0), bowl + bv(0.0, 0.51, 0.0), float3_0, 16))
    for([bv(-1.05, base, 0.95), bv(-0.9, base, 1.12)]) p:
        let clay = bm("terracotta")
        add_child(body, bball(0.1, clay, p + bv(0.0, 0.14, 0.0), bv(1.0, 1.4, 1.0)))
        add_child(body, bcyl(0.035, 0.045, 0.1, clay, p + bv(0.0, 0.31, 0.0), float3_0, 10))
    let wood = bm("wood")
    let pole_at = bv(-1.25, base, 1.25)
    add_child(body, bcyl(0.035, 0.04, 2.1, wood, pole_at + bv(0.0, 1.05, 0.0), float3_0, 8))
    add_child(body, bball(0.07, bronze, pole_at + bv(0.0, 2.13, 0.0)))
    let banner = mnode()
    let flag_top = pole_at + bv(0.04, 2.0, 0.0)
    add_child(banner, bbox(bv(0.66, 0.06, 0.03), wood, flag_top + bv(0.33, 0.0, 0.0)))
    add_child(banner, bbox(bv(0.6, 0.8, 0.02), bcloth(team), flag_top + bv(0.33, -0.42, 0.0)))
    add_child(banner, bring(0.1, 0.15, bcloth(html("#f2c94c")), flag_top + bv(0.33, -0.38, 0.015), bv(90.0, 0.0, 0.0)))
    let vane = mnode()
    let apex = roof_c + bv(0.0, rise + 0.08, -length / 2.0 + 0.25)
    add_child(vane, bcyl(0.012, 0.012, 0.35, bronze, apex + bv(0.0, 0.17, 0.0), float3_0, 6))
    add_child(vane, bbox(bv(0.36, 0.02, 0.02), bronze, apex + bv(0.0, 0.33, 0.0)))
    add_child(vane, slab_tri(float2 { 0.1, 0.0 }, float2 { 0.24, 0.06 }, float2 { 0.24, -0.06 }, 0.02, bronze))
    last_kid(vane).pos = apex + bv(0.0, 0.33, 0.0)
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bvane(sp, vane, apex)
    bpt(sp, "smoke", bowl + bv(0.0, 0.6, 0.0))
    blights(sp, lights)
    return bpt(sp, "lantern", bowl + bv(0.0, 0.52, 0.0))

def villa_house(team:float3) -> BSpec:
    let body = mnode()
    let stone = bm("stone")
    let plaster = bm("plaster")
    let w = 1.15
    let d = 1.0
    let h = 0.72
    add_child(body, bbox(bv(w + 0.14, 0.12, d + 0.14), stone, bv(0.0, 0.06, 0.0)))
    add_child(body, bbox(bv(w, h, d), plaster, bv(0.0, 0.12 + h / 2.0, 0.0)))
    add_child(body, bbox(bv(w + 0.02, 0.1, d + 0.02), stone, bv(0.0, 0.17, 0.0)))
    let front = d / 2.0
    add_child(body, bbox(bv(0.28, 0.48, 0.04), bflat(html("#4a2a18"), 0.8), bv(-0.22, 0.12 + 0.24, front + 0.02)))
    add_child(body, bbox(bv(0.36, 0.06, 0.06), stone, bv(-0.22, 0.12 + 0.5, front + 0.03)))
    add_child(body, bbox(bv(0.04, 0.2, 0.18), bglow(html("#ffcf6a"), 1.2), bv(w / 2.0 + 0.01, 0.12 + 0.42, 0.05)))
    for([-1.0, 1.0]) s:
        add_child(body, bbox(bv(0.1, 0.22, 0.02), bcloth(team), bv(w / 2.0 + 0.06, 0.12 + 0.42, 0.05 + s * 0.15), bv(0.0, s * 60.0, 0.0)))
    let rise = tile_roof(body, bv(0.0, 0.12 + h, 0.0), w / 2.0 + 0.1, d + 0.16, 26.0, plaster, plaster)
    let clay = bm("terracotta")
    add_child(body, bball(0.08, clay, bv(0.2, 0.12 + 0.1, front + 0.14), bv(1.0, 1.4, 1.0)))
    add_child(body, bcyl(0.03, 0.035, 0.08, clay, bv(0.2, 0.12 + 0.24, front + 0.14), float3_0, 10))
    let cypress = bflat(html("#2e4a26"), 0.95)
    add_child(body, bcyl(0.03, 0.04, 0.3, bm("wood"), bv(-0.72, 0.15, 0.4), float3_0, 6))
    add_child(body, bball(0.17, cypress, bv(-0.72, 0.75, 0.4), bv(1.0, 3.4, 1.0)))
    add_child(body, bcyl(0.05, 0.05, 0.3, stone, bv(0.3, 0.12 + h + rise + 0.05, -0.2), float3_0, 8))   // chimney
    let sp = bspec(body)
    bpt(sp, "smoke", bv(0.3, 0.12 + h + rise + 0.25, -0.2))
    bpt(sp, "lantern", bv(-0.22, 0.12 + 0.62, front + 0.1))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    bpt(sp, "window", bv(1.0, 0.0, 0.0))
    return bteam(sp, team)

// ------------------------------------------------------------------ tent culture (steppe)

// A felt tent. Returns its height.
def bld_yurt(parent:MNode, at:float3, r:float, wall_h:float, team:float3) -> float:
    let felt = bm("felt")
    let rope = bflat(html("#8a6a3c"), 0.9)
    add_child(parent, bcyl(r, r, wall_h, felt, at + bv(0.0, wall_h / 2.0, 0.0), float3_0, 28))
    for([0.3, 0.7]) y:
        add_child(parent, bring(r - 0.01, r + 0.03, rope, at + bv(0.0, wall_h * y, 0.0)))
    let roof_h = r * 0.55
    add_child(parent, bcyl(r * 0.18, r + 0.06, roof_h, felt, at + bv(0.0, wall_h + roof_h / 2.0, 0.0), float3_0, 28))
    add_child(parent, bcyl(r * 0.2, r * 0.2, 0.06, bm("wood"), at + bv(0.0, wall_h + roof_h + 0.02, 0.0), float3_0, 16))
    for(8) k:   // roof ropes
        let a = 360.0 * float(k) / 8.0
        add_child(parent, beam(at + bv(cos(a) * r * 0.2, wall_h + roof_h, sin(a) * r * 0.2), at + bv(cos(a) * (r + 0.05), wall_h, sin(a) * (r + 0.05)), 0.012, rope, 4))
    let door = at + bv(0.0, 0.0, r)
    add_child(parent, bbox(bv(0.3, wall_h * 0.8, 0.03), bcloth(team), door + bv(0.0, wall_h * 0.4, 0.01)))
    add_child(parent, bbox(bv(0.36, 0.05, 0.05), bm("wood"), door + bv(0.0, wall_h * 0.82, 0.02)))
    return wall_h + roof_h

def tent_town_center(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let top = bld_yurt(body, bv(-0.15, 0.0, -0.15), 1.05, 0.75, team)
    bld_yurt(body, bv(0.95, 0.0, 0.75), 0.42, 0.42, team)
    let cart = bv(-0.95, 0.06, 0.95)
    add_child(body, bbox(bv(0.55, 0.06, 0.35), wood, cart + bv(0.0, 0.26, 0.0)))
    for([-0.2, 0.2]) z:
        add_child(body, bring(0.13, 0.17, wood, cart + bv(0.0, 0.17, z), bv(90.0, 0.0, 0.0)))
    add_child(body, beam(cart + bv(0.27, 0.26, 0.0), cart + bv(0.7, 0.06, 0.05), 0.02, wood))
    for(3) k:
        add_child(body, bball(0.08, bm("weave"), cart + bv(-0.15 + float(k) * 0.15, 0.36, 0.0)))
    for([0.2, 0.9]) x:
        add_child(body, bcyl(0.025, 0.025, 0.3, wood, bv(x, 0.21, 1.3), float3_0, 6))
    add_child(body, beam(bv(0.2, 0.33, 1.3), bv(0.9, 0.33, 1.3), 0.02, wood))
    let pole_at = bv(-1.2, 0.06, -0.9)
    add_child(body, bcyl(0.03, 0.035, 2.0, wood, pole_at + bv(0.0, 1.0, 0.0), float3_0, 8))
    let banner = mnode()
    let flag_top = pole_at + bv(0.03, 1.9, 0.0)
    add_child(banner, bbox(bv(0.5, 0.05, 0.03), wood, flag_top + bv(0.25, 0.0, 0.0)))
    add_child(banner, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.62, -0.22 }, float2 { 0.0, -0.5 }, 0.02, bcloth(team)))
    last_kid(banner).pos = flag_top
    let vane = mnode()
    let apex = bv(-0.15, top + 0.04, -0.15)
    add_child(vane, bcyl(0.012, 0.012, 0.3, wood, apex + bv(0.0, 0.15, 0.0), float3_0, 6))
    add_child(vane, bbox(bv(0.3, 0.02, 0.02), bflat(html("#b07a36"), 0.4, 0.7), apex + bv(0.0, 0.28, 0.0)))
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bvane(sp, vane, apex)
    bpt(sp, "smoke", apex + bv(0.0, 0.1, 0.0))
    bpt(sp, "lantern", bv(-0.15, 0.5, 0.95))
    return bdoorway(sp, bld_doorway(bv(-0.15, 0.0, 0.94), 0.3, 0.6))

def tent_house(team:float3) -> BSpec:
    let body = mnode()
    let top = bld_yurt(body, float3_0, 0.62, 0.48, team)
    woodpile(bv(0.7, 0.0, -0.3), body)
    let sp = bspec(body)
    bpt(sp, "smoke", bv(0.0, top + 0.1, 0.0))
    bpt(sp, "lantern", bv(0.0, 0.35, 0.7))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bteam(sp, team)

// A farm going in: a tilled plot in a post-and-rail fence, seed sacks by the gate.
def farm_plot(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    add_child(body, bbox(bv(1.8, 0.05, 1.8), bm("mud"), bv(0.0, 0.025, 0.0)))
    for(6) k:   // furrows
        add_child(body, bbox(bv(1.6, 0.04, 0.07), bflat(html("#4e3820"), 1.0), bv(0.0, 0.06, -0.72 + float(k) * 0.29)))
    let half = 0.92
    for(4) side:
        for(5) k:
            let t = -half + float(k) * half * 0.5
            let p = if side == 0: bv(t, 0.0, half) elif side == 1: bv(half, 0.0, t) elif side == 2: bv(t, 0.0, -half) else: bv(-half, 0.0, t)
            if not (side == 0 and k == 2):   // (the gate)
                add_child(body, bcyl(0.03, 0.035, 0.32, wood, p + bv(0.0, 0.16, 0.0), float3_0, 6))
        let a = if side == 0: bv(-half, 0.24, half) elif side == 1: bv(half, 0.24, half) elif side == 2: bv(half, 0.24, -half) else: bv(-half, 0.24, -half)
        let b = if side == 0: bv(half, 0.24, half) elif side == 1: bv(half, 0.24, -half) elif side == 2: bv(-half, 0.24, -half) else: bv(-half, 0.24, half)
        add_child(body, bbox(bv(magnitude(b - a), 0.035, 0.035), wood, (a + b) * 0.5, bv(0.0, -atan2(float2 { b.x - a.x, b.z - a.z }), 0.0)))
    for(2) k:
        add_child(body, bball(0.09, bflat(html("#b8a074"), 1.0), bv(0.55 + float(k) * 0.17, 0.11, 1.08), bv(1.0, 1.2, 1.0)))
    return bteam(bspec(body), team)

// ------------------------------------------------------------------ military buildings, per culture

// models.gd's KIT: an architecture's walls, frame, roof and base, and whether it domes and stands on stilts.
class BKit:
    wall:string
    frame:string
    roof:string
    base:string
    dome:bool
    stilts:bool

def bkit(arch:string) -> BKit:
    switch arch:
        case "thatch": return BKit { "mud", "wood", "thatch", "timber", false, false }
        case "junk": return BKit { "tin", "wood", "tin", "brick", false, false }
        case "stone": return BKit { "plaster", "stone", "tiles", "stone", false, false }
        case "tent": return BKit { "felt", "wood", "felt", "", false, false }
        case "reed": return BKit { "weave", "wood", "thatch", "", true, true }
        case "mound": return BKit { "mud", "wood", "mud", "", true, false }
        default:
            assert false
            return BKit { "", "", "", "", false, false }

// The culture's roof stuff for a small roof ("tiles" are terracotta).
def bld_roof_mat(k:BKit) -> MMat: return bm(if k.roof == "tiles": "terracotta" else: k.roof)

// A roof over a w x d box, ridge along x. Returns the ridge height.
def bld_roof(body:MNode, arch:string, at:float3, w:float, d:float) -> float:
    let k = bkit(arch)
    if k.dome:
        let rise = d * 0.5
        add_child(body, bdome(1.0, bm(k.roof), at - bv(0.0, 0.05, 0.0), bv(w / 2.0 + 0.18, rise, d / 2.0 + 0.18)))
        return rise
    if k.roof == "tiles":
        let holder = mnode()
        holder.rot = bv(0.0, 90.0, 0.0)
        holder.pos = at
        add_child(body, holder)
        return tile_roof(holder, float3_0, d / 2.0 + 0.12, w + 0.2, 26.0, bm("plaster"), bm("plaster"))
    let mat = bm(k.roof)
    let rise = d * (if k.roof == "thatch": 0.42 else: 0.3)
    let slope = magnitude(float2 { d / 2.0 + 0.15, rise })
    let ang = atan2(float2 { d / 2.0 + 0.15, rise })
    let thick = if k.roof == "thatch": 0.16 else: 0.05
    for([-1.0, 1.0]) side:
        add_child(body, bbox(bv(w + 0.3, thick, slope), mat, at + bv(0.0, rise / 2.0, side * (d / 4.0 + 0.07)), bv(side * ang, 0.0, 0.0)))
    for([-1.0, 1.0]) side:   // gable ends
        let g = add_child(body, slab_tri(float2 { -d / 2.0, 0.0 }, float2 { d / 2.0, 0.0 }, float2 { 0.0, rise }, 0.06, bm(k.wall)))
        g.pos = at + bv(side * w / 2.0, 0.0, 0.0)
        g.rot = bv(0.0, 90.0, 0.0)
    add_child(body, bbox(bv(w + 0.34, 0.08, 0.1), bm("wood"), at + bv(0.0, rise + 0.02, 0.0)))
    return rise

// A hall's walls on a plinth, the culture's frame at the corners. Returns its floor height.
def bld_hall(body:MNode, arch:string, w:float, d:float, h:float) -> float:
    let k = bkit(arch)
    var base = 0.0
    if k.base != "":
        bld_footing(body, arch, w + 0.3, d + 0.3, 0.16)
        base = 0.16
    if k.stilts:
        base = bld_stilt_deck(body, float3_0, w + 0.3, d + 0.3)
    add_child(body, bbox(bv(w, h, d), bm(k.wall), bv(0.0, base + h / 2.0, 0.0)))
    for([-1.0, 1.0]) x:
        for([-1.0, 1.0]) z:
            add_child(body, bbox(bv(0.12, h + 0.04, 0.12), bm(k.frame), bv(x * w / 2.0, base + h / 2.0, z * d / 2.0)))
    return base

// A footing h high under a w x d building: a plinth, or (KIT base "timber") sills on packed earth.
def bld_footing(body:MNode, arch:string, w:float, d:float, h:float, at:float3 = float3_0):
    let k = bkit(arch)
    if k.base != "timber":
        add_child(body, bbox(bv(w, h, d), bm(k.base), at + bv(0.0, h / 2.0, 0.0)))
        return
    let wood = bm("wood")
    let s = min(h, 0.16)
    add_child(body, bbox(bv(w - 0.02, h - 0.02, d - 0.02), bm("mud"), at + bv(0.0, (h - 0.02) / 2.0, 0.0)))   // packed earth
    for([-1.0, 1.0]) side:
        add_child(body, bbox(bv(w + 0.08, s, s), wood, at + bv(0.0, h - s / 2.0, side * (d - s) / 2.0)))
        add_child(body, bbox(bv(s * 0.9, s * 0.9, d + 0.08), wood, at + bv(side * (w - s) / 2.0, h - s * 0.55, 0.0)))
    let n = max(int((w - 2.0 * s) / 0.22), 1)
    for(n) i:
        let x = -w / 2.0 + s + (float(i) + 0.5) * (w - 2.0 * s) / float(n)
        add_child(body, bbox(bv((w - 2.0 * s) / float(n) - 0.02, 0.03, d - 2.0 * s), wood, at + bv(x, h - 0.012, 0.0)))

def barracks_thatch(team:float3) -> BSpec: return bld_barracks("thatch", team)
def barracks_junk(team:float3) -> BSpec: return bld_barracks("junk", team)
def barracks_stone(team:float3) -> BSpec: return bld_barracks("stone", team)
def barracks_tent(team:float3) -> BSpec: return bld_barracks("tent", team)
def barracks_reed(team:float3) -> BSpec: return bld_barracks("reed", team)
def barracks_mound(team:float3) -> BSpec: return bld_barracks("mound", team)

// A training hall with a fenced yard: a straw target, a dummy, a weapon rack.
def bld_barracks(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let w = 2.3
    let d = 1.3
    let h = 0.85
    let hall = mnode()
    hall.pos = bv(0.0, 0.0, -0.55)
    add_child(body, hall)
    let base = bld_hall(hall, arch, w, d, h)
    let rise = bld_roof(hall, arch, bv(0.0, base + h, 0.0), w, d)
    add_child(hall, bbox(bv(0.5, 0.62, 0.04), bcloth(team), bv(-0.3, base + 0.31, d / 2.0 + 0.02)))
    let lights = []::float3
    add_child(body, bbox(bv(0.04, 0.22, 0.32), bglow(html("#ffcf6a"), 1.3), bv(w / 2.0 + 0.01, base + 0.55, -0.55)))
    lights.push(bv(w / 2.0 + 0.03, base + 0.55, -0.55))
    for(6) k:
        let x = -1.25 + float(k) * 0.5
        add_child(body, bcyl(0.025, 0.03, 0.26, wood, bv(x, 0.13, 1.3), float3_0, 6))
    add_child(body, bbox(bv(2.55, 0.03, 0.03), wood, bv(0.0, 0.22, 1.3)))
    add_child(body, bcyl(0.2, 0.2, 0.07, bm("thatch"), bv(0.75, 0.38, 0.75), bv(80.0, 0.0, 0.0), 20))   // the target
    add_child(body, bring(0.06, 0.1, bcloth(html("#c03030")), bv(0.75, 0.38, 0.79), bv(80.0, 0.0, 0.0)))
    add_child(body, bcyl(0.025, 0.025, 0.42, wood, bv(0.75, 0.21, 0.72), bv(-10.0, 0.0, 0.0), 6))
    add_child(body, bcyl(0.03, 0.03, 0.5, wood, bv(-0.6, 0.25, 0.75), float3_0, 6))          // the dummy
    add_child(body, bball(0.12, bm("felt"), bv(-0.6, 0.48, 0.75), bv(1.0, 1.4, 1.0)))
    add_child(body, bball(0.07, bm("felt"), bv(-0.6, 0.66, 0.75)))
    add_child(body, bbox(bv(0.46, 0.03, 0.03), wood, bv(-0.6, 0.5, 0.75)))
    for(4) k:   // the rack
        add_child(body, beam(bv(-1.1 + float(k) * 0.08, 0.05, 0.25), bv(-1.04 + float(k) * 0.08, 0.72, 0.18), 0.012, wood))
    add_child(body, bbox(bv(0.36, 0.03, 0.05), wood, bv(-0.98, 0.5, 0.22)))
    let sp = bspec(body)
    bpt(sp, "smoke", bv(0.6, base + h + rise, -0.75))
    bpt(sp, "lantern", bv(-0.3, base + 0.72, 0.2))
    blights(sp, lights)
    bteam(sp, team)
    return bdoorway(sp, bld_doorway(bv(-0.3, base, -0.55 + d / 2.0 + 0.05), 0.5, 0.62))

def stable_thatch(team:float3) -> BSpec: return bld_stable("thatch", team)
def stable_junk(team:float3) -> BSpec: return bld_stable("junk", team)
def stable_stone(team:float3) -> BSpec: return bld_stable("stone", team)
def stable_tent(team:float3) -> BSpec: return bld_stable("tent", team)
def stable_reed(team:float3) -> BSpec: return bld_stable("reed", team)
def stable_mound(team:float3) -> BSpec: return bld_stable("mound", team)

// An open-fronted barn: stalls, hay bales, a trough, a team blanket over the rail.
def bld_stable(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let k = bkit(arch)
    let wood = bm("wood")
    let w = 2.4
    let d = 1.6
    let h = 0.8
    var base = 0.0
    if k.base != "":
        bld_footing(body, arch, w + 0.3, d + 0.3, 0.12, bv(0.0, 0.0, -0.3))
        base = 0.12
    add_child(body, bbox(bv(w, h, 0.08), bm(k.wall), bv(0.0, base + h / 2.0, -0.3 - d / 2.0)))   // back wall
    for([-1.0, 1.0]) side:
        add_child(body, bbox(bv(0.08, h, d), bm(k.wall), bv(side * w / 2.0, base + h / 2.0, -0.3)))
    for([-1.2, -0.4, 0.4, 1.2]) x:   // posts and stall boards
        add_child(body, bbox(bv(0.1, h, 0.1), bm(k.frame), bv(x, base + h / 2.0, -0.3 + d / 2.0)))
        if abs(x) < 1.0:
            add_child(body, bbox(bv(0.05, h * 0.6, d * 0.8), wood, bv(x, base + h * 0.3, -0.35)))
    add_child(body, bbox(bv(w, 0.06, 0.06), wood, bv(0.0, base + h * 0.55, -0.3 + d / 2.0)))   // the rail
    add_child(body, bbox(bv(0.5, 0.18, 0.03), bcloth(team), bv(0.0, base + h * 0.45, -0.3 + d / 2.0 + 0.04)))
    bld_roof(body, arch, bv(0.0, base + h, -0.3), w, d)
    let hay = bflat(html("#d6b45a"), 1.0)
    for([bv(-0.9, 0.12, 0.85), bv(-0.55, 0.12, 0.95), bv(-0.75, 0.32, 0.9)]) p:
        add_child(body, bbox(bv(0.32, 0.2, 0.22), hay, p + bv(0.0, base, 0.0)))
    add_child(body, bbox(bv(0.6, 0.14, 0.18), wood, bv(0.8, base + 0.07, 0.75)))   // trough
    add_child(body, bbox(bv(0.54, 0.02, 0.12), bflat(html("#4e7a86"), 0.4), bv(0.8, base + 0.13, 0.75)))
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.0, base + h * 0.75, 0.55))
    return bteam(sp, team)

def watchtower_thatch(team:float3) -> BSpec: return bld_tower("thatch", team)
def watchtower_junk(team:float3) -> BSpec: return bld_tower("junk", team)
def watchtower_stone(team:float3) -> BSpec: return bld_tower("stone", team)
def watchtower_tent(team:float3) -> BSpec: return bld_tower("tent", team)
def watchtower_reed(team:float3) -> BSpec: return bld_tower("reed", team)
def watchtower_mound(team:float3) -> BSpec: return bld_tower("mound", team)

// A lookout tower on a one-tile footing: a railed platform, a little roof, a team flag.
def bld_tower(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let k = bkit(arch)
    let wood = bm("wood")
    let top = 1.7
    if arch == "mound":   // a termite spire
        add_child(body, bcyl(0.12, 0.42, top, bm("mud"), bv(0.0, top / 2.0, 0.0), float3_0, 12))
    elif arch == "stone" or arch == "thatch":
        add_child(body, bbox(bv(0.62, top, 0.62), bm(if arch == "stone": "stone" else: k.wall), bv(0.0, top / 2.0, 0.0)))
        for([-0.31, 0.31]) z:
            add_child(body, bbox(bv(0.08, top, 0.08), bm(k.frame), bv(0.31, top / 2.0, z)))
    else:
        for([-0.28, 0.28]) x:
            for([-0.28, 0.28]) z:
                add_child(body, beam(bv(x * 1.15, 0.0, z * 1.15), bv(x, top, z), 0.04, wood))
        add_child(body, beam(bv(-0.3, 0.5, 0.3), bv(0.3, 1.2, 0.3), 0.025, wood))   // cross braces
        add_child(body, beam(bv(0.3, 0.5, -0.3), bv(0.3, 1.2, 0.3), 0.025, wood))
    add_child(body, bbox(bv(0.86, 0.08, 0.86), wood, bv(0.0, top, 0.0)))   // the platform
    for(4) side:
        let p = if side == 0: bv(0.0, top + 0.16, 0.42) elif side == 1: bv(0.42, top + 0.16, 0.0) elif side == 2: bv(0.0, top + 0.16, -0.42) else: bv(-0.42, top + 0.16, 0.0)
        add_child(body, bbox(bv(if side % 2 == 0: 0.86 else: 0.04, 0.04, if side % 2 == 0: 0.04 else: 0.86), wood, p))
    for([-0.4, 0.4]) x:
        for([-0.4, 0.4]) z:
            add_child(body, bcyl(0.025, 0.025, 0.5, wood, bv(x, top + 0.25, z), float3_0, 6))
    let roof_mat = bld_roof_mat(k)
    if k.dome:
        add_child(body, bdome(0.5, roof_mat, bv(0.0, top + 0.5, 0.0), bv(1.0, 0.7, 1.0)))
    else:
        add_child(body, bcyl(0.0, 0.62, 0.38, roof_mat, bv(0.0, top + 0.68, 0.0), bv(0.0, 45.0, 0.0), 4))
    add_child(body, bbox(bv(0.22, 0.12, 0.02), bcloth(team), bv(0.1, top + 0.18, 0.47)))   // a team rag on the rail
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.3, top + 0.3, 0.3))
    return bteam(sp, team)

// ------------------------------------------------------------------ outposts and bastions

def outpost_look(arch:string) -> string:
    switch arch:
        case "junk", "tent": return "pole"
        case "stone": return "beacon"
        default: return "deck"

def bld_outpost(arch:string, team:float3) -> BSpec:
    switch outpost_look(arch):
        case "pole": return bld_outpost_pole(arch, team)
        case "beacon": return bld_outpost_beacon(arch, team)
        default: return bld_outpost_deck(arch, team)

// A spotter's mast on three raking legs, a crow's nest, the team's pennant.
def bld_outpost_pole(arch:string, team:float3) -> BSpec:
    brng = grng(41)
    let body = mnode()
    let wood = bm("wood")
    let top = 1.45
    var post_mat = wood
    if arch == "reed":
        post_mat = bm("thatch")
    elif arch == "junk":
        post_mat = bflat(html("#5a5c5e"), 0.5, 0.6)   // a pipe
    if arch == "mound":
        add_child(body, bcyl(0.05, 0.3, top, bm("mud"), bv(0.0, top / 2.0, 0.0), float3_0, 10))
    else:
        add_child(body, bcyl(0.045, 0.06, top, post_mat, bv(0.0, top / 2.0, 0.0), float3_0, 8))
        for(3) k:   // the raking legs
            let a = TAU * float(k) / 3.0 + 0.4
            add_child(body, beam(bv(rcos(a) * 0.42, 0.0, rsin(a) * 0.42), bv(0.0, top * 0.55, 0.0), 0.025, post_mat, 6))
        for(6) k:   // peg rungs
            add_child(body, bbox(bv(0.2, 0.025, 0.025), wood, bv(0.0, 0.2 + float(k) * 0.18, 0.05), bv(0.0, 30.0 * float(k % 2), 0.0)))
    if arch == "junk":
        add_child(body, bcyl(0.2, 0.2, 0.36, bflat(html("#7a3a2a"), 0.6, 0.4), bv(0.0, 0.18, 0.0), float3_0, 14))   // an oil drum foot
        add_child(body, bring(0.19, 0.21, bflat(html("#4a2a20"), 0.6), bv(0.0, 0.3, 0.0)))
    let nest = if arch == "junk": bm("tin") elif arch == "tent": bm("felt") elif arch == "mound": bm("mud") else: bm("weave")
    add_child(body, bcyl(0.2, 0.15, 0.22, nest, bv(0.0, top, 0.0), float3_0, 14))
    add_child(body, bring(0.18, 0.22, if arch != "junk": wood else: bm("tin"), bv(0.0, top + 0.11, 0.0)))
    add_child(body, bcyl(0.16, 0.16, 0.012, bflat(html("#2a1e14"), 0.95), bv(0.0, top + 0.12, 0.0), float3_0, 14))   // open: you look into it
    add_child(body, bcyl(0.012, 0.012, 0.45, wood, bv(0.12, top + 0.32, -0.08), float3_0, 5))   // the pennant's staff
    add_child(body, bbox(bv(0.22, 0.1, 0.01), bcloth(team), bv(0.24, top + 0.48, -0.08)))
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.0, top + 0.1, 0.18))
    return bteam(sp, team)

// A low look-out deck: four short legs, a ladder, a railing and a sunshade, a horn on the rail.
def bld_outpost_deck(arch:string, team:float3) -> BSpec:
    brng = grng(42)
    let body = mnode()
    let k = bkit(arch)
    let wood = bm("wood")
    let h = 0.75
    let legs = if arch == "reed": bm("thatch") else: wood
    for([-0.32, 0.32]) x:
        for([-0.32, 0.32]) z:
            let rx = randf_range(brng, -3.0, 3.0)
            let rz = randf_range(brng, -3.0, 3.0)
            add_child(body, bcyl(0.035, 0.045, h, legs, bv(x, h / 2.0, z), bv(rx, 0.0, rz), 8))
    if arch == "mound":
        add_child(body, bcyl(0.3, 0.46, h, bm("mud"), bv(0.0, h / 2.0, 0.0), float3_0, 14))   // a packed-earth plinth
    add_child(body, bbox(bv(0.82, 0.06, 0.82), wood, bv(0.0, h, 0.0)))
    for(4) side:   // the rail, open at the ladder (front)
        if side != 0:
            let p = if side == 1: bv(0.39, h + 0.2, 0.0) elif side == 2: bv(0.0, h + 0.2, -0.39) else: bv(-0.39, h + 0.2, 0.0)
            add_child(body, bbox(bv(if side % 2 == 0: 0.8 else: 0.03, 0.03, if side % 2 == 0: 0.03 else: 0.8), wood, p))
    for([-0.12, 0.12]) x:   // the ladder
        add_child(body, beam(bv(x, 0.0, 0.72), bv(x, h, 0.4), 0.018, wood, 5))
    for(3) n:
        add_child(body, bbox(bv(0.26, 0.02, 0.02), wood, lerp3(bv(0.0, 0.0, 0.72), bv(0.0, h, 0.4), float(n + 1) / 4.0)))
    for([-0.36, 0.36]) x:
        add_child(body, bcyl(0.02, 0.02, 0.62, wood, bv(x, h + 0.31, -0.36), float3_0, 6))
    let shade = bld_roof_mat(k)
    if k.dome:
        add_child(body, bdome(0.42, shade, bv(0.0, h + 0.56, -0.12), bv(1.05, 0.35, 0.8)))
    else:
        add_child(body, bbox(bv(0.88, 0.04, 0.6), shade, bv(0.0, h + 0.6, -0.14), bv(-14.0, 0.0, 0.0)))
    add_child(body, bbox(bv(0.24, 0.1, 0.015), bcloth(team), bv(0.18, h + 0.13, -0.4)))   // a team rag on the rail
    let horn = bflat(html("#d8c8a0"), 0.6)
    add_child(body, bcyl(0.012, 0.045, 0.22, horn, bv(-0.39, h + 0.12, 0.05), bv(0.0, 0.0, 70.0), 8))
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.2, h + 0.3, 0.1))
    return bteam(sp, team)

// A beacon cairn of the culture's stuff with a lit fire basket on a post.
def bld_outpost_beacon(arch:string, team:float3) -> BSpec:
    brng = grng(43)
    let body = mnode()
    let wood = bm("wood")
    var h = 0.55
    switch arch:
        case "junk":
            add_child(body, bbox(bv(0.5, 0.3, 0.5), wood, bv(-0.05, 0.15, 0.02), bv(0.0, 8.0, 0.0)))
            add_child(body, bbox(bv(0.36, 0.26, 0.36), wood, bv(0.02, 0.43, -0.02), bv(0.0, -12.0, 0.0)))
            add_child(body, bcyl(0.13, 0.13, 0.3, bflat(html("#7a3a2a"), 0.6, 0.4), bv(0.3, 0.15, 0.25), float3_0, 12))
        case "reed", "thatch", "tent":
            let sheaf = if arch != "tent": bm("thatch") else: bm("felt")
            add_child(body, bcyl(0.18, 0.42, h, sheaf, bv(0.0, h / 2.0, 0.0), float3_0, 16))
            add_child(body, bring(0.3, 0.34, wood, bv(0.0, 0.22, 0.0)))
        case "mound":
            add_child(body, bcyl(0.16, 0.45, h + 0.1, bm("mud"), bv(0.0, (h + 0.1) / 2.0, 0.0), float3_0, 14))
            h += 0.1
        default:   // dressed stones, stacked in rings
            let stone = bm("stone")
            for(4) row:
                let r = 0.42 - float(row) * 0.09
                let n = 8 - row
                for(n) s:
                    let a = TAU * float(s) / float(n) + float(row) * 0.4
                    let rx = randf_range(brng, -6.0, 6.0)
                    let rz = randf_range(brng, -4.0, 4.0)
                    add_child(body, bbox(bv(0.2, 0.14, 0.16), stone, bv(rcos(a) * r * 0.7, 0.07 + float(row) * 0.13, rsin(a) * r * 0.7), bv(rx, -rad(a), rz)))
            add_child(body, bcyl(0.12, 0.3, h, stone, bv(0.0, h / 2.0, 0.0), float3_0, 10))
    add_child(body, bcyl(0.035, 0.04, 0.7, wood, bv(0.0, h + 0.35, 0.0), float3_0, 8))
    let iron = bflat(html("#3a3634"), 0.5, 0.7)
    add_child(body, bcyl(0.16, 0.08, 0.14, iron, bv(0.0, h + 0.76, 0.0), float3_0, 12))   // the fire basket
    add_child(body, bcyl(0.13, 0.13, 0.03, bglow(html("#c04018"), 1.5), bv(0.0, h + 0.83, 0.0), float3_0, 12))   // the embers
    add_child(body, bcyl(0.0, 0.11, 0.26, bglow(html("#ff8a20"), 2.2), bv(0.0, h + 0.97, 0.0), bv(0.0, 0.0, 6.0), 8))   // the flame
    add_child(body, bcyl(0.0, 0.06, 0.18, bglow(html("#ffd860"), 2.6), bv(0.02, h + 0.94, 0.03), bv(0.0, 0.0, -8.0), 8))
    add_child(body, bbox(bv(0.2, 0.12, 0.015), bcloth(team), bv(0.12, h + 0.45, 0.04)))   // a team rag tied to the post
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.0, h + 0.86, 0.0))
    blights(sp, [bv(0.0, h + 0.86, 0.0)])
    return bteam(sp, team)

// The Bastion: a Watchtower rebuilt heavy and tall, one look per culture.
def bld_bastion(arch:string, team:float3) -> BSpec:
    brng = grng(44)
    let body = mnode()
    let wood = bm("wood")
    let slit = bflat(html("#1c140e"), 0.95)
    var top = 2.2
    var lantern = bv(0.3, top, 0.4)
    switch arch:
        case "stone":
            let stone = bm("stone")
            add_child(body, bbox(bv(0.96, 0.24, 0.96), stone, bv(0.0, 0.12, 0.0)))   // a battered foot
            add_child(body, bbox(bv(0.82, top - 0.2, 0.82), stone, bv(0.0, 0.24 + (top - 0.24 - 0.2) / 2.0, 0.0)))
            add_child(body, bbox(bv(0.94, 0.12, 0.94), stone, bv(0.0, top - 0.14, 0.0)))   // the corbel course
            for(4) s:   // merlons round the top
                for(3) m:
                    let t = -0.33 + float(m) * 0.33
                    let p = if s == 0: bv(t, top + 0.04, 0.42) elif s == 1: bv(0.42, top + 0.04, t) elif s == 2: bv(t, top + 0.04, -0.42) else: bv(-0.42, top + 0.04, t)
                    add_child(body, bbox(if s % 2 == 0: bv(0.18, 0.2, 0.12) else: bv(0.12, 0.2, 0.18), stone, p))
            add_child(body, bcyl(0.015, 0.015, 0.7, wood, bv(-0.2, top + 0.3, -0.2), float3_0, 5))
            add_child(body, bbox(bv(0.3, 0.18, 0.01), bcloth(team), bv(-0.04, top + 0.55, -0.2)))
            for([0.8, 1.45]) y:
                add_child(body, bbox(bv(0.05, 0.22, 0.02), slit, bv(0.1, y, 0.415)))
                add_child(body, bbox(bv(0.02, 0.22, 0.05), slit, bv(0.415, y, -0.1)))
            add_child(body, bbox(bv(0.24, 0.36, 0.03), bflat(html("#3a2416"), 0.9), bv(-0.15, 0.42, 0.42)))   // the door
        case "thatch":
            add_child(body, bbox(bv(0.84, 0.14, 0.84), bm("mud"), bv(0.0, 0.07, 0.0)))
            let h = top - 0.55
            add_child(body, bbox(bv(0.74, h, 0.74), bm("mud"), bv(0.0, 0.14 + h / 2.0, 0.0)))
            for([-0.37, 0.37]) x:
                for([-0.37, 0.37]) z:
                    add_child(body, bbox(bv(0.09, h + 0.1, 0.09), wood, bv(x, 0.14 + h / 2.0, z)))
            for([0.7, 1.25]) y:   // timber bands and braces
                add_child(body, bbox(bv(0.78, 0.06, 0.78), wood, bv(0.0, y, 0.0)))
            add_child(body, beam(bv(-0.37, 0.18, 0.375), bv(0.37, 0.68, 0.375), 0.025, wood, 5))
            add_child(body, beam(bv(0.375, 0.18, 0.37), bv(0.375, 0.68, -0.37), 0.025, wood, 5))
            let g = 0.14 + h   // the fighting gallery, jutting out over the walls
            add_child(body, bbox(bv(1.04, 0.07, 1.04), wood, bv(0.0, g, 0.0)))
            for(4) s:
                let p = if s == 0: bv(0.0, g + 0.17, 0.5) elif s == 1: bv(0.5, g + 0.17, 0.0) elif s == 2: bv(0.0, g + 0.17, -0.5) else: bv(-0.5, g + 0.17, 0.0)
                add_child(body, bbox(bv(if s % 2 == 0: 1.02 else: 0.05, 0.28, if s % 2 == 0: 0.05 else: 1.02), wood, p))
            add_child(body, bcyl(0.0, 0.78, 0.6, bm("thatch"), bv(0.0, g + 0.62, 0.0), bv(0.0, 45.0, 0.0), 4))
            add_child(body, bbox(bv(0.26, 0.14, 0.02), bcloth(team), bv(0.12, g + 0.12, 0.53)))
            add_child(body, bbox(bv(0.05, 0.2, 0.02), slit, bv(-0.1, 0.95, 0.375)))
            top = g + 0.9
            lantern = bv(0.35, g + 0.25, 0.45)
        case "junk":
            let brick = bm("brick")
            add_child(body, bbox(bv(0.84, 1.0, 0.84), brick, bv(0.0, 0.5, 0.0)))
            add_child(body, bbox(bv(0.9, 0.9, 0.9), bm("tin"), bv(0.0, 1.45, 0.0), bv(0.0, 3.0, 0.0)))   // riveted tin upper
            let band = bflat(html("#4a4440"), 0.5, 0.6)
            for([1.05, 1.85]) y:
                add_child(body, bbox(bv(0.93, 0.05, 0.93), band, bv(0.0, y, 0.0), bv(0.0, 3.0, 0.0)))
            for(4) s:   // crate merlons
                let a = float(s) * 90.0
                let p = bv(sin(a) * 0.34, 2.0, cos(a) * 0.34)
                add_child(body, bbox(bv(0.22, 0.2, 0.22), wood, p, bv(0.0, randf_range(brng, -15.0, 15.0), 0.0)))
            add_child(body, bbox(bv(0.95, 0.04, 0.6), bm("tin"), bv(0.0, 2.32, -0.15), bv(-12.0, 3.0, 0.0)))   // a sheet of tin for a roof
            for([-0.4, 0.4]) x:
                add_child(body, bcyl(0.015, 0.015, 0.4, wood, bv(x, 2.15, -0.38), float3_0, 5))
            add_child(body, bbox(bv(0.05, 0.2, 0.02), slit, bv(0.12, 1.45, 0.455)))
            add_child(body, bbox(bv(0.28, 0.18, 0.02), bcloth(team), bv(-0.15, 1.6, 0.46)))
            top = 2.35
        case "tent":
            for([-0.36, 0.36]) x:
                for([-0.36, 0.36]) z:
                    add_child(body, bcyl(0.06, 0.07, top, wood, bv(x, top / 2.0, z), float3_0, 8))
            for([0.45, 1.1]) y:
                add_child(body, beam(bv(-0.36, y, 0.36), bv(0.36, y + 0.55, 0.36), 0.025, wood, 5))
                add_child(body, beam(bv(0.36, y, 0.36), bv(0.36, y + 0.55, -0.36), 0.025, wood, 5))
            add_child(body, bbox(bv(0.9, 0.08, 0.9), wood, bv(0.0, top - 0.5, 0.0)))
            add_child(body, bbox(bv(0.86, 0.46, 0.86), bm("felt"), bv(0.0, top - 0.23, 0.0)))   // felt hung round the fighting floor
            for(4) s:
                let p = if s == 0: bv(0.0, top - 0.25, 0.44) elif s == 1: bv(0.44, top - 0.25, 0.0) elif s == 2: bv(0.0, top - 0.25, -0.44) else: bv(-0.44, top - 0.25, 0.0)
                add_child(body, bbox(bv(if s % 2 == 0: 0.1 else: 0.02, 0.16, if s % 2 == 0: 0.02 else: 0.1), slit, p))
            add_child(body, bcyl(0.0, 0.66, 0.62, bm("felt"), bv(0.0, top + 0.31, 0.0), float3_0, 16))
            add_child(body, bcyl(0.015, 0.015, 0.35, wood, bv(0.0, top + 0.75, 0.0), float3_0, 5))
            add_child(body, bbox(bv(0.24, 0.12, 0.01), bcloth(team), bv(0.13, top + 0.85, 0.0)))
            top += 0.6
        case "reed":
            let deck = bld_stilt_deck(body, float3_0, 0.96, 0.96)
            let h = 1.45
            add_child(body, bcyl(0.36, 0.42, h, bm("weave"), bv(0.0, deck + h / 2.0, 0.0), float3_0, 24))
            add_child(body, bcyl(0.43, 0.45, 0.3, bm("mud"), bv(0.0, deck + 0.15, 0.0), float3_0, 24))   // mud-plastered skirt
            for([0.65, 1.2]) y:
                add_child(body, bring(0.37, 0.41, bm("wood"), bv(0.0, deck + y, 0.0)))
            bld_reed_fence(body, bv(0.0, deck + h, 0.0), 0.4)
            add_child(body, bdome(0.46, bm("thatch"), bv(0.0, deck + h + 0.28, 0.0), bv(1.0, 0.7, 1.0)))
            for([-0.4, 0.4]) x:
                add_child(body, bcyl(0.02, 0.02, 0.3, wood, bv(x, deck + h + 0.15, 0.1), float3_0, 5))
            add_child(body, bbox(bv(0.05, 0.18, 0.02), slit, bv(0.12, deck + 0.95, 0.4), bv(0.0, 15.0, 0.0)))
            add_child(body, bbox(bv(0.26, 0.12, 0.02), bcloth(team), bv(-0.1, deck + h - 0.1, 0.42)))
            top = deck + h + 0.6
        case "mound":
            let mud = bm("mud")
            add_child(body, bcyl(0.14, 0.52, top, mud, bv(0.0, top / 2.0, 0.0), float3_0, 14))
            for(5) s:   // buttress spires leaning on the main one
                let a = TAU * float(s) / 5.0 + 0.3
                let hh = randf_range(brng, 0.9, 1.4)
                add_child(body, bcyl(0.04, 0.2, hh, mud, bv(rcos(a) * 0.36, hh / 2.0, rsin(a) * 0.36), bv(rsin(a) * 8.0, 0.0, -rcos(a) * 8.0), 10))
            for(6) s:   // vent holes to shoot from
                let a = TAU * float(s) / 6.0
                let y = 1.0 + float(s % 2) * 0.45
                let r = 0.52 - y / top * 0.38
                add_child(body, bball(0.05, slit, bv(rcos(a) * r, y, rsin(a) * r), bv(1.0, 1.4, 1.0)))
            add_child(body, bbox(bv(0.26, 0.12, 0.02), bcloth(team), bv(0.0, 1.2, 0.36), bv(0.0, 0.0, 4.0)))
            top += 0.1
    let sp = bspec(body)
    bpt(sp, "lantern", lantern)
    return bteam(sp, team)

// ------------------------------------------------------------------ amphibians: reed domes on stilts

// A plank deck on log stilts, w x d, at `at`. Returns the deck's top height.
def bld_stilt_deck(body:MNode, at:float3, w:float, d:float) -> float:
    let wood = bm("wood")
    let h = 0.4
    let nx = max(2, int(w / 0.7) + 1)
    let nz = max(2, int(d / 0.7) + 1)
    for(nx) i:
        for(nz) j:
            let p = at + bv(-w / 2.0 + 0.08 + float(i) * (w - 0.16) / float(nx - 1), h / 2.0, -d / 2.0 + 0.08 + float(j) * (d - 0.16) / float(nz - 1))
            let rx = randf_range(brng, -4.0, 4.0)
            let rz = randf_range(brng, -4.0, 4.0)
            add_child(body, bcyl(0.05, 0.06, h, wood, p, bv(rx, 0.0, rz), 8))
    let planks = int(d / 0.2)
    for(planks) k:
        add_child(body, bbox(bv(w, 0.06, d / float(planks) - 0.015), wood, at + bv(0.0, h + 0.03, -d / 2.0 + (float(k) + 0.5) * d / float(planks)), bv(0.0, randf_range(brng, -1.5, 1.5), 0.0)))
    return h + 0.06

// A lily pad laid over a roof's crown, notched.
def bld_lily_cap(body:MNode, at:float3, r:float):
    let c = at + bv(-r * 0.25, -0.03, r * 0.15)
    let rr = r * 0.75
    add_child(body, bcyl(rr, rr, 0.025, bflat(html("#3d6a2c"), 0.8), c, bv(10.0, 30.0, -8.0), 20))
    add_child(body, bbox(bv(rr, 0.035, 0.04), bflat(html("#2e5222"), 0.85), c + bv(rr * 0.5, 0.015, 0.0), bv(10.0, 30.0, -8.0)))   // the notch's vein

// A woven dome on a short wall, a mud band, a dark door, maybe a lily cap. Returns its top.
def bld_reed_dome(body:MNode, at:float3, r:float, team:float3, door_turn:float = 0.0, cap:bool = false) -> float:
    let weave = bm("weave")
    let wall_h = r * 0.35
    add_child(body, bcyl(r, r * 1.04, wall_h, weave, at + bv(0.0, wall_h / 2.0, 0.0), float3_0, 28))
    add_child(body, bring(r - 0.02, r + 0.05, bm("mud"), at + bv(0.0, 0.04, 0.0)))
    add_child(body, bdome(r, bm("thatch"), at + bv(0.0, wall_h - 0.02, 0.0), bv(1.04, 0.95, 1.04)))
    let door = at + bv(sin(door_turn) * r, wall_h * 0.5 + 0.02, cos(door_turn) * r)
    add_child(body, bbox(bv(r * 0.42, wall_h + r * 0.25, 0.05), bflat(html("#2a1e14"), 0.9), door, bv(0.0, door_turn, 0.0)))
    add_child(body, bbox(bv(r * 0.5, 0.06, 0.08), bcloth(team), door + bv(0.0, wall_h * 0.5 + r * 0.14, 0.0), bv(0.0, door_turn, 0.0)))
    let top = at.y + wall_h + r * 0.95
    if cap:
        bld_lily_cap(body, bv(at.x, top - 0.04, at.z), r * 0.45)
    return top

// Reed bundles standing round a deck's edge, tied in the middle.
def bld_reed_fence(body:MNode, at:float3, half:float, gap_side:int = 0):
    let reed = bm("thatch")
    let tie = bm("wood")
    for(4) side:
        if side != gap_side:
            for(6) k:
                let t = -half + (float(k) + 0.5) * half * 2.0 / 6.0
                let p = if side == 0: bv(t, 0.0, half) elif side == 1: bv(half, 0.0, t) elif side == 2: bv(t, 0.0, -half) else: bv(-half, 0.0, t)
                let rx = randf_range(brng, -6.0, 6.0)
                let rz = randf_range(brng, -6.0, 6.0)
                add_child(body, bcyl(0.035, 0.05, 0.36, reed, at + p + bv(0.0, 0.18, 0.0), bv(rx, 0.0, rz), 8))
                add_child(body, bring(0.04, 0.06, tie, at + p + bv(0.0, 0.2, 0.0)))

def reed_house(team:float3) -> BSpec:
    brng = grng(11)
    let body = mnode()
    let deck = bld_stilt_deck(body, float3_0, 1.5, 1.5)
    bld_reed_dome(body, bv(0.0, deck, 0.0), 0.58, team)
    let wood = bm("wood")
    for([-0.12, 0.12]) x:
        add_child(body, beam(bv(x, 0.0, 1.05), bv(x, deck, 0.72), 0.02, wood, 6))
    for(3) k:
        add_child(body, bbox(bv(0.28, 0.025, 0.025), wood, lerp3(bv(0.0, 0.0, 1.05), bv(0.0, deck, 0.72), float(k + 1) / 4.0)))
    add_child(body, beam(bv(0.6, deck, 0.4), bv(0.95, deck + 0.9, -0.1), 0.012, wood, 4))
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.3, deck + 0.2, 0.65))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bteam(sp, team)

def reed_town_center(team:float3) -> BSpec:
    brng = grng(12)
    let body = mnode()
    let deck = bld_stilt_deck(body, float3_0, 2.5, 2.5)
    var top = bld_reed_dome(body, bv(-0.25, deck, -0.25), 0.92, team)
    add_child(body, bcyl(0.34, 0.4, 0.22, bm("weave"), bv(-0.25, top - 0.05, -0.25), float3_0, 20))
    add_child(body, bdome(0.4, bm("thatch"), bv(-0.25, top + 0.05, -0.25), bv(1.0, 1.1, 1.0)))
    bld_lily_cap(body, bv(-0.25, top + 0.45, -0.25), 0.2)
    top += 0.5
    bld_reed_dome(body, bv(0.8, deck, 0.75), 0.36, team, 40.0)
    bld_reed_fence(body, bv(0.0, deck, 0.0), 1.2)
    let wood = bm("wood")
    for(3) k:
        add_child(body, bbox(bv(0.5, 0.05, 0.16), wood, bv(-0.2, deck * (float(k) + 0.5) / 3.0, 1.55 - float(k) * 0.14)))
    add_child(body, beam(bv(-1.0, deck, 0.8), bv(-1.0, deck + 0.45, 0.8), 0.02, wood, 6))
    add_child(body, beam(bv(-0.6, deck, 0.8), bv(-0.6, deck + 0.45, 0.8), 0.02, wood, 6))
    add_child(body, beam(bv(-1.0, deck + 0.42, 0.8), bv(-0.6, deck + 0.42, 0.8), 0.015, wood, 4))
    for(3) k:
        add_child(body, bball(0.05, bflat(html("#8aa0a8"), 0.4, 0.3), bv(-0.92 + float(k) * 0.12, deck + 0.32, 0.8), bv(0.6, 1.8, 0.6)))
    let pole_at = bv(1.0, deck, -0.95)
    add_child(body, bcyl(0.03, 0.035, 1.6, wood, pole_at + bv(0.0, 0.8, 0.0), float3_0, 8))
    let banner = mnode()
    let flag_top = pole_at + bv(0.03, 1.5, 0.0)
    add_child(banner, bbox(bv(0.5, 0.05, 0.03), wood, flag_top + bv(0.25, 0.0, 0.0)))
    add_child(banner, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.62, -0.22 }, float2 { 0.0, -0.5 }, 0.02, bcloth(team)))
    last_kid(banner).pos = flag_top
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bpt(sp, "smoke", bv(-0.25, top, -0.25))
    bpt(sp, "lantern", bv(-0.25, deck + 0.4, 0.75))
    return bdoorway(sp, bld_doorway(bv(-0.25, deck + 0.04, -0.25 + 0.92 + 0.06), 0.92 * 0.42, 0.92 * 0.35 + 0.92 * 0.25 - 0.04, true))

// ------------------------------------------------------------------ bugs: earth mounds, logs, husks

// A round dark doorway in a mound, facing out along `turn` degrees (a team cloth over it unless team is black).
def bld_burrow_door(body:MNode, at:float3, r:float, turn:float = 0.0, team:float3 = float3_0):
    add_child(body, bcyl(r, r, 0.06, bflat(html("#1e140c"), 1.0), at, bv(90.0, turn, 0.0), 16))
    add_child(body, bring(r, r + 0.05, bm("wood"), at + bv(sin(turn), 0.0, cos(turn)) * 0.01, bv(90.0, turn, 0.0)))
    if team != float3_0:
        add_child(body, bbox(bv(r * 2.4, r * 0.7, 0.04), bcloth(team), at + bv(sin(turn), 0.0, cos(turn)) * 0.04 + bv(0.0, r * 1.05, 0.0), bv(-12.0, turn, 0.0)))

// A seed husk propped up as a shed.
def bld_husk(body:MNode, at:float3, r:float, turn:float = 0.0):
    let shell = bflat(html("#b08a52"), 0.8)
    add_child(body, bball(r, shell, at + bv(0.0, r * 0.9, 0.0), bv(1.0, 1.5, 0.8), bv(0.0, turn, 18.0)))
    for(3) k:
        add_child(body, bring(r * (0.55 + 0.15 * float(k)), r * (0.6 + 0.15 * float(k)), bflat(html("#8a6a3a"), 0.9), at + bv(0.0, r * 0.9, 0.0), bv(0.0, turn, 18.0 + 90.0), bv(1.0, 1.0, 1.5)))

def bld_grass_tufts(body:MNode, at:float3, spread:float, n:int):
    let grass = bflat(html("#5e8a34"), 0.9)
    for(n):
        let px = randf_range(brng, -spread, spread)
        let pz = randf_range(brng, -spread, spread)
        let p = at + bv(px, 0.0, pz)
        let rx = randf_range(brng, -12.0, 12.0)
        let rz = randf_range(brng, -12.0, 12.0)
        add_child(body, bcyl(0.0, 0.05, 0.22, grass, p + bv(0.0, 0.1, 0.0), bv(rx, 0.0, rz), 5))

def mound_house(team:float3) -> BSpec:
    brng = grng(21)
    let body = mnode()
    let mud = bm("mud")
    add_child(body, bdome(0.72, mud, float3_0, bv(1.0, 0.95, 1.0)))
    add_child(body, bdome(0.3, mud, bv(0.0, 0.62, 0.0), bv(1.0, 0.9, 1.0)))   // the crown, a second lump
    bld_burrow_door(body, bv(0.05, 0.2, 0.66), 0.17, 0.0, team)
    bld_husk(body, bv(0.75, 0.0, -0.35), 0.24, -30.0)
    bld_grass_tufts(body, bv(0.0, 0.62, 0.0), 0.25, 5)
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.25, 0.35, 0.62))
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bteam(sp, team)

def mound_town_center(team:float3) -> BSpec:
    brng = grng(22)
    let body = mnode()
    let mud = bm("mud")
    let wood = bm("wood")
    add_child(body, bdome(1.15, mud, bv(-0.2, 0.0, -0.2), bv(1.0, 0.85, 1.0)))
    add_child(body, bdome(0.55, mud, bv(-0.2, 0.85, -0.2), bv(1.0, 0.9, 1.0)))
    add_child(body, bdome(0.6, mud, bv(0.95, 0.0, 0.55), bv(1.0, 0.8, 1.0)))
    bld_burrow_door(body, bv(-0.1, 0.26, 0.86), 0.24, 0.0, team)
    bld_burrow_door(body, bv(0.75, 0.2, 0.56), 0.14, 60.0, team)
    bld_burrow_door(body, bv(-0.85, 0.55, 0.45), 0.1, -40.0)
    let log_at = bv(-1.0, 0.24, 1.05)
    add_child(body, bcyl(0.24, 0.24, 1.2, wood, log_at, bv(0.0, -20.0, 90.0), 16))
    for([-1.0, 1.0]) e:
        let ed = log_at + bv(cos(20.0), 0.0, sin(20.0)) * 0.6 * e
        add_child(body, bcyl(0.18, 0.18, 0.02, bflat(html("#2a1c10"), 1.0), ed + bv(cos(20.0), 0.0, sin(20.0)) * 0.01 * e, bv(0.0, -20.0, 90.0), 14))
    bld_husk(body, bv(1.2, 0.0, -0.75), 0.32, -50.0)
    bld_grass_tufts(body, bv(-0.2, 1.2, -0.2), 0.3, 7)
    let pole_at = bv(0.6, 0.0, -1.2)
    add_child(body, bcyl(0.03, 0.035, 2.0, wood, pole_at + bv(0.0, 1.0, 0.0), float3_0, 8))
    let banner = mnode()
    let flag_top = pole_at + bv(0.03, 1.9, 0.0)
    add_child(banner, bbox(bv(0.5, 0.05, 0.03), wood, flag_top + bv(0.25, 0.0, 0.0)))
    add_child(banner, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.62, -0.22 }, float2 { 0.0, -0.5 }, 0.02, bcloth(team)))
    last_kid(banner).pos = flag_top
    let sp = bspec(body)
    bbanner(sp, banner, flag_top)
    bpt(sp, "smoke", bv(-0.2, 1.35, -0.2))
    bpt(sp, "lantern", bv(0.2, 0.4, 0.95))
    return bdoorway(sp, bld_doorway(bv(-0.1, 0.26 - 0.2, 0.92), 0.4, 0.4, true))

// ------------------------------------------------------------------ concept options (building sheets)

def concept_junk_tc_small(team:float3) -> BSpec: return junk_town_center_small(team)
def concept_junk_tc_low(team:float3) -> BSpec: return junk_town_center(team, 0.72, 24.0, false)
def concept_junk_tc_berm(team:float3) -> BSpec: return junk_town_center(team, 0.72, 24.0, true)

// A painted oil drum, hooped.
def bld_drum(body:MNode, at:float3, r:float, h:float, paint:float3):
    let m = bflat(paint, 0.7, 0.3)
    add_child(body, bcyl(r, r, h, m, at + bv(0.0, h / 2.0, 0.0), float3_0, 18))
    for([0.15, 0.5, 0.85]) y:
        add_child(body, bring(r - 0.01, r + 0.025, bflat(darkened(paint, 0.35), 0.6, 0.4), at + bv(0.0, h * y, 0.0)))
    add_child(body, bcyl(r * 0.98, r * 0.98, 0.02, bflat(darkened(paint, 0.2), 0.6, 0.3), at + bv(0.0, h + 0.01, 0.0), float3_0, 18))

// Age 3, the pride step: a porch on oil-drum columns under a cracked dinner plate, crockery before it.
def junk_town_center_pride(team:float3) -> BSpec:
    let spec = junk_town_center_small(team)
    let root = spec.body
    let paint = [html("#8a3a2a"), html("#3a5a7a"), html("#8a3a2a"), html("#6a6a5a")]
    for(4) k:   // four columns, each two drums stacked
        let at = bv(-0.75 + float(k) * 0.5, 0.0, 1.05)
        bld_drum(root, at, 0.13, 0.38, paint[k])
        bld_drum(root, at + bv(0.0, 0.38, 0.0), 0.13, 0.38, paint[(k + 1) % 4])
    add_child(root, bbox(bv(1.85, 0.07, 0.4), bm("wood"), bv(0.0, 0.8, 1.05)))   // the beam across them
    let plate = add_child(root, slab_tri(float2 { -0.95, 0.0 }, float2 { 0.95, 0.0 }, float2 { 0.0, 0.42 }, 0.04, bflat(html("#f0ece0"), 0.4)))
    plate.pos = bv(0.0, 0.84, 1.15)
    add_child(root, bbox(bv(0.02, 0.36, 0.05), bflat(html("#5a5048"), 0.8), bv(0.18, 0.98, 1.18), bv(0.0, 0.0, 25.0)))   // the crack
    add_child(root, bring(0.12, 0.15, bflat(html("#4a6aa0"), 0.5), bv(0.0, 1.0, 1.19), bv(90.0, 0.0, 0.0)))   // the plate's blue rim pattern
    brng = grng(71)
    for(14) k:   // the crockery forecourt
        let px = randf_range(brng, -0.9, 0.9)
        let pz = randf_range(brng, 1.3, 1.6)
        let p = bv(px, 0.015, pz)
        let sx = randf_range(brng, 0.12, 0.22)
        let sz = randf_range(brng, 0.1, 0.18)
        add_child(root, bbox(bv(sx, 0.02, sz), bflat(if k % 3 != 0: html("#e8e4d8") else: html("#7a9ac0"), 0.4), p, bv(0.0, randf_range(brng, 0.0, 90.0), 0.0)))
    return spec

// The rat Town Centre in play: the no-plinth hall, smaller, with scrap and weeds low round its base.
def junk_town_center_small(team:float3) -> BSpec:
    let spec = junk_town_center(team, 0.7, 26.0, false, false)
    let k = 0.78
    let hall = spec.body
    hall.scl = bv(k, 1.0, k)
    let root = mnode()
    add_child(root, hall)
    brng = grng(67)
    let earth = bm("mud")
    let weeds = bflat(html("#5e7a34"), 0.95)
    let tin = bm("tin")
    for(22) i:   // rubble, weeds and scrap round the base, low: the ground creeping up
        let ang = TAU * float(i) / 22.0 + randf_range(brng, -0.12, 0.12)
        let r = randf_range(brng, 0.95, 1.25)
        let at = bv(rcos(ang) * r, 0.0, rsin(ang) * r)
        switch i % 3:
            case 0:
                add_child(root, bball(randf_range(brng, 0.14, 0.24), earth, at, bv(1.4, 0.5, 1.2)))
            case 1:
                let wh = randf_range(brng, 0.18, 0.3)
                let rx = randf_range(brng, -15.0, 15.0)
                let rz = randf_range(brng, -15.0, 15.0)
                add_child(root, bcyl(0.0, 0.07, wh, weeds, at + bv(0.0, 0.1, 0.0), bv(rx, 0.0, rz), 5))
            default:
                let sx = randf_range(brng, 0.15, 0.3)
                let sz = randf_range(brng, 0.1, 0.2)
                let rx = randf_range(brng, -12.0, 12.0)
                let ry = randf_range(brng, 0.0, 90.0)
                add_child(root, bbox(bv(sx, 0.02, sz), tin, at + bv(0.0, 0.03, 0.0), bv(rx, ry, 0.0)))
    spec.body = root
    for(["banner_pivot", "vane_pivot", "smoke", "lantern"]) key:
        let p = spec.pts.get(key, float3_0)
        spec.pts.set(key, bv(p.x * k, p.y, p.z * k))
    spec.lights = map(spec.lights) p: bv(p.x * k, p.y, p.z * k)
    spec.doorway = map(spec.doorway) p: bv(p.x * k, p.y, p.z * k)
    for([spec.banner, spec.vane]) part:
        if part: part.scl = bv(k, 1.0, k)
    return spec

// The rally point's flag: a staff in a little cairn, a team cloth in a gentle wave, a brass finial.
def rally_flag(team:float3) -> MNode:
    brng = grng(77)
    let n = mnode()
    let wood = bm("wood")
    let stone = bm("stone")
    for(5) k:   // the cairn
        let a = float(k) * TAU / 5.0
        add_child(n, bball(0.06 + randf(brng) * 0.02, stone, bv(rcos(a) * 0.07, 0.03, rsin(a) * 0.07), bv(1.2, 0.8, 1.0)))
    add_child(n, bball(0.05, stone, bv(0.0, 0.08, 0.0), bv(1.2, 0.8, 1.0)))
    add_child(n, bcyl(0.016, 0.02, 0.8, wood, bv(0.0, 0.4, 0.0), float3_0, 8))
    add_child(n, bball(0.03, bflat(html("#c89a40"), 0.3, 0.8), bv(0.0, 0.82, 0.0)))
    add_child(n, bcyl(0.008, 0.008, 0.36, wood, bv(0.18, 0.76, 0.0), bv(0.0, 0.0, 90.0), 6))   // the cross-bar the cloth hangs from
    let strips = 12
    for(strips) k:   // the cloth as one gentle wave
        let f = float(k) / float(strips)
        let x = 0.02 + f * 0.34
        let z = rsin(f * 7.0) * 0.025 * (0.3 + f)
        let slope = rcos(f * 7.0) * 7.0 * 0.025 * (0.3 + f) / 0.34
        add_child(n, bbox(bv(0.034, 0.27 - f * 0.03, 0.01), bcloth(team), bv(x, 0.625 - f * 0.012, z), bv(0.0, -atan2(float2 { 1.0, slope }), 0.0)))
    return n

// A unit's waypoint: a short stake in a tuft of earth, a swallow-tailed team pennant, a brass cap.
def waypoint_flag(team:float3) -> MNode:
    brng = grng(78)
    let n = mnode()
    let wood = bm("wood")
    let stone = bm("stone")
    add_child(n, bball(0.06, bflat(html("#5a4630"), 0.95), float3_0, bv(1.3, 0.35, 1.1)))   // the kicked-up earth
    for(3) k:   // a few stones wedging it
        let a = float(k) * TAU / 3.0 + 0.4
        add_child(n, bball(0.028 + randf(brng) * 0.01, stone, bv(rcos(a) * 0.05, 0.02, rsin(a) * 0.05), bv(1.2, 0.8, 1.0)))
    add_child(n, bcyl(0.012, 0.016, 0.44, wood, bv(0.0, 0.22, 0.0), float3_0, 8))
    add_child(n, bball(0.022, bflat(html("#c89a40"), 0.3, 0.8), bv(0.0, 0.455, 0.0)))
    let strips = 8
    for(strips) k:   // the pennant: tapering to a swallow tail, with a little wave
        let f = float(k) / float(strips)
        let x = 0.016 + f * 0.2
        let z = rsin(f * 6.0) * 0.015 * (0.3 + f)
        let h = 0.13 * (1.0 - f * 0.55)
        let y = 0.375 - f * 0.01
        if k >= strips - 2:   // the notch of the tail: two points, not a block
            add_child(n, bbox(bv(0.026, h * 0.38, 0.008), bcloth(team), bv(x, y + h * 0.31, z)))
            add_child(n, bbox(bv(0.026, h * 0.38, 0.008), bcloth(team), bv(x, y - h * 0.31, z)))
        else:
            add_child(n, bbox(bv(0.026, h, 0.008), bcloth(team), bv(x, y, z)))
    return n

// ------------------------------------------------------------------ milestone 11 buildings (one builder per type, in each KIT)

// Posts at the corners of a w x d footprint under the culture's roof: an open shed. Returns the roof's rise.
def bld_lean_to(body:MNode, arch:string, at:float3, w:float, d:float, h:float) -> float:
    let k = bkit(arch)
    for([-1.0, 1.0]) x:
        for([-1.0, 1.0]) z:
            add_child(body, bbox(bv(0.09, h, 0.09), bm(k.frame), at + bv(x * (w / 2.0 - 0.05), h / 2.0, z * (d / 2.0 - 0.05))))
    add_child(body, bbox(bv(w, h * 0.5, 0.06), bm(k.wall), at + bv(0.0, h * 0.25, -d / 2.0 + 0.03)))   // a back wall, waist high
    return bld_roof(body, arch, at + bv(0.0, h, 0.0), w, d)

def bld_log_stack(body:MNode, at:float3, rows:int):
    let wood = bm("wood")
    let cut = bflat(html("#d8b47a"), 0.9)
    for(rows) row:
        for(rows - row + 1) k:
            let p = at + bv(0.0, 0.07 + float(row) * 0.12, -0.2 + (float(k) + float(row) * 0.5) * 0.13)
            add_child(body, bcyl(0.065, 0.065, 0.62, wood, p, bv(0.0, 0.0, 90.0), 10))
            add_child(body, bcyl(0.06, 0.06, 0.01, cut, p + bv(0.315, 0.0, 0.0), bv(0.0, 0.0, 90.0), 10))

// Archery Range: an open long shed behind a lane of targets.
def bld_archery_range(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    bld_lean_to(body, arch, bv(0.0, 0.0, -0.85), 2.5, 0.8, 0.62)
    add_child(body, bbox(bv(0.36, 0.22, 0.03), bcloth(team), bv(-0.9, 0.5, -0.45)))   // a team rag on a post
    for(3) k:   // bows racked under the shed
        add_child(body, beam(bv(0.6 + float(k) * 0.14, 0.02, -1.05), bv(0.65 + float(k) * 0.14, 0.55, -1.12), 0.012, wood, 4))
    for(3) k:   // the targets, down a lane of trodden earth
        let at = bv(-0.85 + float(k) * 0.85, 0.0, 0.85)
        add_child(body, beam(at + bv(-0.12, 0.0, -0.08), at + bv(0.0, 0.42, 0.0), 0.02, wood, 6))
        add_child(body, beam(at + bv(0.12, 0.0, -0.08), at + bv(0.0, 0.42, 0.0), 0.02, wood, 6))
        add_child(body, bcyl(0.2, 0.2, 0.08, bm("thatch"), at + bv(0.0, 0.42, 0.04), bv(80.0, 0.0, 0.0), 20))
        add_child(body, bring(0.05, 0.09, bcloth(html("#c03030")), at + bv(0.0, 0.42, 0.09), bv(80.0, 0.0, 0.0)))
    add_child(body, bbox(bv(2.6, 0.015, 0.5), bm("mud"), bv(0.0, 0.008, 0.2)))   // the shooting lane
    let sp = bspec(body)
    bpt(sp, "lantern", bv(0.0, 0.5, -0.5))
    return bteam(sp, team)

// Armoury: a squat smithy under a tall chimney stack, the forge glowing in an open side.
def bld_armoury(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let iron = bflat(html("#4a4c50"), 0.5, 0.7)
    let hall = mnode()
    hall.pos = bv(-0.25, 0.0, -0.2)
    add_child(body, hall)
    let base = bld_hall(hall, arch, 1.2, 1.1, 0.55)   // low and squat
    bld_roof(hall, arch, bv(0.0, base + 0.55, 0.0), 1.2, 1.1)
    add_child(hall, bbox(bv(0.34, 0.42, 0.04), bcloth(team), bv(-0.3, base + 0.21, 0.57)))
    let stone = bm("stone")
    let stack_mat = if arch == "reed" or arch == "mound": bm("mud") elif arch == "junk": bflat(html("#4a4a48"), 0.5, 0.6) elif arch == "tent": bm("felt") elif arch == "thatch": bm("brick") else: stone
    if arch == "junk":
        add_child(body, bcyl(0.14, 0.14, 1.5, stack_mat, bv(0.55, 0.75, -0.55), float3_0, 12))
        add_child(body, bcyl(0.18, 0.16, 0.12, stack_mat, bv(0.55, 1.5, -0.55), float3_0, 12))
    elif arch == "reed" or arch == "mound":
        add_child(body, bcyl(0.16, 0.24, 1.5, stack_mat, bv(0.55, 0.75, -0.55), float3_0, 12))   // a tapering clay flue
    else:
        add_child(body, bbox(bv(0.36, 1.5, 0.36), stack_mat, bv(0.55, 0.75, -0.55)))
        add_child(body, bbox(bv(0.42, 0.08, 0.42), stack_mat, bv(0.55, 1.5, -0.55)))
    add_child(body, bbox(bv(0.44, 0.34, 0.4), if arch == "thatch": stack_mat else: stone, bv(0.6, 0.17, 0.25)))   // the forge
    add_child(body, bbox(bv(0.3, 0.04, 0.26), bglow(html("#ff8a30"), 2.2), bv(0.6, 0.35, 0.25)))
    add_child(body, bbox(bv(0.22, 0.1, 0.1), iron, bv(0.1, 0.26, 0.62)))   // the anvil on its stump
    add_child(body, bcyl(0.08, 0.09, 0.2, wood, bv(0.1, 0.1, 0.62), float3_0, 10))
    let sp = bspec(body)
    bpt(sp, "lantern", bv(-0.3, base + 0.45, 0.45))
    blights(sp, [bv(0.6, 0.38, 0.25)])
    bteam(sp, team)
    return bpt(sp, "smoke", bv(0.55, 1.6, -0.55))

// Pen: a fold round a 3 x 3 patch, a gate gap on the front. PEN_LOOK: each culture's style and fence material.
def pen_style(arch:string) -> string:
    switch arch:
        case "stone", "mound": return "wall"
        case "tent": return "rails"
        default: return "hurdles"

def pen_panel(arch:string) -> string:
    switch arch:
        case "thatch", "reed": return "weave"
        case "junk": return "tin"
        case "stone": return "stone"
        case "mound": return "mud"
        default: return "wood"

def bld_pen(arch:string, team:float3) -> BSpec: return bld_pen_look(pen_style(arch), arch, team)
def concept_pen_hurdles(team:float3) -> BSpec: return bld_pen_look("hurdles", "thatch", team)
def concept_pen_rails(team:float3) -> BSpec: return bld_pen_look("rails", "thatch", team)
def concept_pen_wall(team:float3) -> BSpec: return bld_pen_look("wall", "stone", team)

def bld_pen_look(style:string, arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let panel = bm(pen_panel(arch))
    let half = 1.42
    let h = 0.24
    for(4) side:   // front (+z), right (+x), back (-z), left (-x)
        let along = if side % 2 == 0: bv(1.0, 0.0, 0.0) else: bv(0.0, 0.0, 1.0)
        let out = if side == 0: bv(0.0, 0.0, half) elif side == 1: bv(half, 0.0, 0.0) elif side == 2: bv(0.0, 0.0, -half) else: bv(-half, 0.0, 0.0)
        let rot = bv(0.0, if side % 2 == 0: 0.0 else: 90.0, 0.0)
        for(3) k:   // a tile of fence at a time; the front's middle one is the gate
            let mid = out + along * float(k - 1) * (half * 2.0 / 3.0)
            if not (side == 0 and k == 1):
                switch style:
                    case "hurdles":   // a woven panel between two stakes
                        add_child(body, bbox(bv(0.9, h, 0.05), panel, mid + bv(0.0, h * 0.5 + 0.02, 0.0), rot))
                        for([-0.47, 0.47]) e:
                            add_child(body, bcyl(0.025, 0.03, h + 0.1, wood, mid + along * e + bv(0.0, (h + 0.1) * 0.5, 0.0), float3_0, 6))
                    case "rails":   // post and two rails
                        for([-0.47, 0.47]) e:
                            add_child(body, bcyl(0.03, 0.035, h + 0.06, wood, mid + along * e + bv(0.0, (h + 0.06) * 0.5, 0.0), float3_0, 6))
                        for([0.1, 0.21]) y:
                            add_child(body, bbox(bv(0.96, 0.035, 0.035), wood, mid + bv(0.0, y, 0.0), rot))
                    case "wall":   // a low dry-stone wall, capped
                        add_child(body, bbox(bv(0.98, h * 0.8, 0.16), panel, mid + bv(0.0, h * 0.4, 0.0), rot))
                        add_child(body, bbox(bv(0.98, 0.04, 0.2), panel, mid + bv(0.0, h * 0.8 + 0.02, 0.0), rot))
    let gate_post = bv(half / 3.0, 0.0, half)
    add_child(body, bcyl(0.035, 0.04, h + 0.2, wood, gate_post + bv(0.0, (h + 0.2) * 0.5, 0.0), float3_0, 6))
    add_child(body, bbox(bv(0.03, 0.16, 0.14), bcloth(team), gate_post + bv(0.04, h + 0.08, 0.08)))   // a team rag on the gate post
    if style == "hurdles":   // the gate hurdle, swung open against the fence
        add_child(body, bbox(bv(0.85, h, 0.05), panel, bv(half / 3.0 + 0.1, h * 0.5 + 0.02, half + 0.42), bv(0.0, 80.0, 0.0)))
    add_child(body, bbox(bv(0.16, 0.1, 0.62), wood, bv(half + 0.16, 0.06, -0.3)))
    add_child(body, bbox(bv(0.11, 0.03, 0.56), bflat(html("#c8b060"), 1.0), bv(half + 0.16, 0.115, -0.3)))
    add_child(body, bball(0.2, bm("thatch"), bv(-half / 3.0 - 0.1, 0.06, half + 0.32), bv(1.3, 0.6, 1.0)))
    return bteam(bspec(body), team)

// Lumber Camp: an open shed over a stack of logs, a chopping block with an axe in it.
def bld_lumber_camp(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    bld_lean_to(body, arch, bv(0.0, 0.0, -0.2), 1.3, 0.9, 0.62)
    bld_log_stack(body, bv(-0.2, 0.0, 0.35), 3)
    add_child(body, bcyl(0.13, 0.14, 0.22, wood, bv(0.55, 0.11, 0.55), float3_0, 12))   // the block
    add_child(body, bbox(bv(0.03, 0.3, 0.03), wood, bv(0.58, 0.34, 0.55), bv(0.0, 0.0, -25.0)))   // the axe
    add_child(body, bbox(bv(0.1, 0.07, 0.02), bflat(html("#9aa0a6"), 0.4, 0.6), bv(0.53, 0.25, 0.55), bv(0.0, 0.0, -25.0)))
    add_child(body, bbox(bv(0.36, 0.04, 0.26), bcloth(team), bv(-0.5, 0.02, 0.5), bv(0.0, 20.0, 0.0)))   // a team tarp on the ground
    return bteam(bspec(body), team)

// Mill: a raised platform of drying racks hung with produce, sacks and a basket of berries.
def bld_mill(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let k = bkit(arch)
    for([-0.6, 0.6]) x:   // the platform on short posts
        for([-0.6, 0.3]) z:
            add_child(body, bbox(bv(0.08, 0.3, 0.08), bm(k.frame), bv(x, 0.15, z)))
    add_child(body, bbox(bv(1.4, 0.06, 1.1), wood, bv(0.0, 0.33, -0.15)))
    let produce = [html("#c8302a"), html("#d8b44a"), html("#7a9a3a")]
    for([-0.5, -0.1, 0.3]) z:   // the racks: rails with bundles hanging to dry
        for([-0.55, 0.55]) x:
            add_child(body, bbox(bv(0.05, 0.6, 0.05), wood, bv(x, 0.66, z)))
        add_child(body, bbox(bv(1.2, 0.04, 0.04), wood, bv(0.0, 0.95, z)))
        for(5) n:
            var i = (n + int(z * 10.0)) % 3
            if i < 0: i += 3   // (GDScript indexes from the end)
            add_child(body, bball(0.05, bflat(produce[i], 0.8), bv(-0.45 + float(n) * 0.22, 0.85, z), bv(0.8, 1.6, 0.8)))
    add_child(body, bbox(bv(0.36, 0.12, 0.03), bcloth(team), bv(0.0, 0.98, 0.32)))   // a team cloth over a rail
    if arch == "stone" or arch == "thatch":   // builders' towns: on their own footing under their own roof
        bld_footing(body, arch, 1.5, 1.2, 0.3, bv(0.0, 0.0, -0.15))
        bld_roof(body, arch, bv(0.0, 1.0, -0.15), 1.4, 1.1)
    let sack = bflat(html("#c8b48a"), 1.0)
    for([bv(-0.55, 0.12, 0.6), bv(-0.3, 0.12, 0.68), bv(-0.42, 0.3, 0.64)]) p:
        add_child(body, bball(0.13, sack, p, bv(1.0, 1.15, 0.9)))
    add_child(body, bcyl(0.13, 0.1, 0.16, bm("weave"), bv(0.45, 0.08, 0.6), float3_0, 14))
    let sp = bteam(bspec(body), team)
    return bpt(sp, "lantern", bv(0.0, 0.5, 0.4))

// Mining Camp: a lean-to over a dug pit (a ladder down into it), a cart of stone and gold.
def bld_mining_camp(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    bld_lean_to(body, arch, bv(-0.4, 0.0, -0.4), 1.0, 0.8, 0.58)
    add_child(body, bcyl(0.38, 0.32, 0.04, bflat(html("#1a1410"), 1.0), bv(0.35, 0.02, 0.15), float3_0, 16))   // the pit, dark
    add_child(body, bring(0.38, 0.5, bm("mud"), bv(0.35, 0.03, 0.15)))   // its spoil heap rim
    for([-0.06, 0.06]) x:
        add_child(body, beam(bv(0.35 + x, -0.1, 0.15), bv(0.35 + x, 0.42, -0.05), 0.012, wood, 4))   // the ladder out
    add_child(body, bbox(bv(0.5, 0.15, 0.3), wood, bv(-0.35, 0.2, 0.6)))   // the cart
    for([-0.55, -0.15]) x:
        add_child(body, bcyl(0.1, 0.1, 0.04, wood, bv(x, 0.1, 0.77), bv(90.0, 0.0, 0.0), 12))
    let stone = bflat(html("#e6d4b0"), 0.9)
    let gold = bflat(html("#f2c440"), 0.3, 0.8)
    for(5) n:
        add_child(body, bball(0.06, if n % 3 != 0: stone else: gold, bv(-0.5 + float(n % 3) * 0.13, 0.32 + float(n / 3) * 0.05, 0.56 + float(n % 2) * 0.07), bv(1.2, 0.8, 1.0)))
    add_child(body, bbox(bv(0.3, 0.12, 0.02), bcloth(team), bv(-0.4, 0.38, -0.01)))
    return bteam(bspec(body), team)

// Market: three stalls under striped awnings round a square, crates, barrels and sacks.
def bld_market(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let k = bkit(arch)
    let wood = bm("wood")
    if k.base != "":
        bld_footing(body, arch, 2.7, 2.7, 0.06)
    let awnings = [html("#c8a040"), html("#7a9a5a"), html("#e8dcc0")]
    let spots = [bv(-0.8, 0.0, -0.8), bv(0.85, 0.0, -0.75), bv(-0.8, 0.0, 0.75)]
    let turns = [0.0, -90.0, 90.0]
    let goods = [html("#d8402a"), html("#e8c050"), html("#7aa040")]
    for(3) i:
        let st = mnode()
        st.pos = spots[i]
        st.rot = bv(0.0, turns[i], 0.0)
        add_child(body, st)
        for([-1.0, 1.0]) x:
            for([-1.0, 1.0]) z:
                add_child(st, bbox(bv(0.06, 0.62, 0.06), bm(k.frame), bv(x * 0.38, 0.31, z * 0.26)))
        add_child(st, bbox(bv(0.8, 0.22, 0.4), wood, bv(0.0, 0.11, 0.05)))   // the counter
        add_child(st, bbox(bv(0.9, 0.04, 0.66), bcloth(awnings[i]), bv(0.0, 0.66, 0.0), bv(-12.0, 0.0, 0.0)))
        for(3) g:
            add_child(st, bball(0.06, bflat(goods[g], 0.7), bv(-0.22 + float(g) * 0.22, 0.27, 0.05)))
    barrel(bv(0.75, 0.0, 0.7), body)
    crate(bv(0.45, 0.0, 0.9), body, 15.0)
    crate(bv(0.95, 0.0, 0.35), body, -10.0)
    let sp = bteam(bspec(body), team)
    return bpt(sp, "lantern", bv(0.0, 0.6, 0.0))

// ------------------------------------------------------------------ siege workshop and wonder

// Siege Workshop: an open shed, a bench, a catapult half built and the bare rafters of a ram's shed.
def bld_siege_workshop(arch:string, team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let raw = bflat(html("#c8a06a"), 0.85)
    let iron = bflat(html("#4a4c50"), 0.5, 0.7)
    add_child(body, bbox(bv(2.8, 0.015, 2.6), bm("mud"), bv(0.0, 0.008, 0.05)))   // the trodden yard
    let rise = bld_lean_to(body, arch, bv(-0.2, 0.0, -1.0), 2.3, 0.75, 0.72)
    add_child(body, bbox(bv(0.4, 0.26, 0.03), bcloth(team), bv(-1.1, 0.5, -0.6)))   // a team cloth on the shed post
    add_child(body, bbox(bv(1.0, 0.06, 0.3), wood, bv(-0.2, 0.36, -1.1)))   // the bench, a tool on it
    for([-0.62, 0.22]) x:
        add_child(body, bbox(bv(0.06, 0.33, 0.25), wood, bv(x, 0.17, -1.1)))
    add_child(body, bbox(bv(0.22, 0.06, 0.06), iron, bv(-0.35, 0.42, -1.05)))
    for(3) k:   // sawn beams stacked under the shed's end
        add_child(body, bbox(bv(0.9, 0.08, 0.08), raw, bv(0.75, 0.04 + float(k / 2) * 0.08, -1.1 + float(k % 2) * 0.1 + float(k / 2) * 0.05)))
    let e = bv(-0.45, 0.24, 0.45)
    for([-0.26, 0.26]) z:
        add_child(body, bbox(bv(1.2, 0.1, 0.1), raw, e + bv(0.0, 0.0, z)))
    for([-0.55, 0.55]) x:
        add_child(body, bbox(bv(0.1, 0.09, 0.62), raw, e + bv(x, 0.02, 0.0)))
    bld_engine_wheel(body, arch, e + bv(-0.4, -0.03, -0.36), bv(90.0, 0.0, 0.0))
    bld_engine_wheel(body, arch, e + bv(0.4, -0.03, -0.36), bv(90.0, 0.0, 0.0))
    bld_engine_wheel(body, arch, e + bv(-0.4, -0.03, 0.36), bv(90.0, 0.0, 0.0))
    bld_engine_wheel(body, arch, e + bv(0.35, -0.04, 0.62), bv(70.0, 0.0, -10.0))   // the fourth, leaning by its axle
    let apex = e + bv(0.1, 0.62, 0.0)
    for([-0.26, 0.26]) z:
        add_child(body, beam(e + bv(-0.35, 0.05, z), apex + bv(0.0, 0.0, z), 0.035, raw, 6))
        add_child(body, beam(e + bv(0.5, 0.05, z), apex + bv(0.0, 0.0, z), 0.035, raw, 6))
    add_child(body, bbox(bv(0.08, 0.08, 0.66), raw, apex + bv(0.0, 0.02, 0.0)))
    add_child(body, beam(e + bv(-0.85, -0.18, 0.02), apex + bv(0.18, 0.12, 0.02), 0.04, raw, 6))
    add_child(body, bcyl(0.11, 0.07, 0.07, wood, e + bv(-0.9, -0.17, 0.02), bv(0.0, 0.0, 20.0), 12))
    add_child(body, bbox(bv(0.03, 0.14, 0.12), bcloth(team), apex + bv(0.05, 0.12, 0.34)))   // a team rag tied on
    let r = bv(0.85, 0.0, 0.35)
    for([-0.3, 0.3]) x:
        add_child(body, bbox(bv(0.09, 0.09, 1.3), raw, r + bv(x, 0.045, 0.0)))
    let ridge_h = 0.75
    for(4) k:
        let z = -0.55 + float(k) * 0.37
        for([-0.3, 0.3]) x:
            add_child(body, beam(r + bv(x, 0.08, z), r + bv(0.0, ridge_h, z), 0.03, raw, 6))
    add_child(body, bbox(bv(0.07, 0.07, 1.36), raw, r + bv(0.0, ridge_h, 0.0)))
    add_child(body, bcyl(0.09, 0.09, 1.1, wood, r + bv(0.0, 0.22, 0.05), bv(90.0, 0.0, 0.0), 12))   // the ram's log, slung under
    add_child(body, bcyl(0.11, 0.1, 0.12, iron, r + bv(0.0, 0.22, 0.62), bv(90.0, 0.0, 0.0), 12))     // its iron head
    let sp = bspec(body)
    bpt(sp, "lantern", bv(-0.2, rise * 0.3 + 0.6, -0.65))
    return bteam(sp, team)

// An engine's wheel in the culture's stuff.
def bld_engine_wheel(body:MNode, arch:string, at:float3, rot:float3):
    let holder = mnode()
    holder.pos = at
    holder.rot = rot
    add_child(body, holder)
    let wood = bm("wood")
    if arch == "junk":
        add_child(holder, bcyl(0.2, 0.2, 0.04, bflat(html("#b8bcc0"), 0.35, 0.8), float3_0, float3_0, 18))
        add_child(holder, bring(0.18, 0.22, bflat(html("#c84030"), 0.5, 0.4)))
    elif arch == "reed" or arch == "mound":
        add_child(holder, bcyl(0.2, 0.2, 0.07, wood, float3_0, float3_0, 16))
        add_child(holder, bcyl(0.17, 0.17, 0.075, bflat(html("#d8b47a"), 0.9), float3_0, float3_0, 16))
    else:
        add_child(holder, bring(0.17, 0.21, wood))
        for(3) s:
            add_child(holder, bbox(bv(0.36, 0.03, 0.03), wood, float3_0, bv(0.0, float(s) * 60.0, 0.0)))
        add_child(holder, bcyl(0.04, 0.04, 0.06, wood, float3_0, float3_0, 8))

// A pole with a team pennant, the live banner a Wonder flies: the banner and its pivot.
def bld_pennant(body:MNode, foot:float3, h:float, team:float3, finial:MMat? = nil) -> MNode, float3:
    let wood = bm("wood")
    add_child(body, bcyl(0.03, 0.04, h, wood, foot + bv(0.0, h / 2.0, 0.0), float3_0, 8))
    if finial:
        add_child(body, bball(0.06, finial, foot + bv(0.0, h + 0.03, 0.0)))
    let banner = mnode()
    let flag_top = foot + bv(0.03, h - 0.1, 0.0)
    add_child(banner, bbox(bv(0.5, 0.05, 0.03), wood, flag_top + bv(0.25, 0.0, 0.0)))
    add_child(banner, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.62, -0.22 }, float2 { 0.0, -0.5 }, 0.02, bcloth(team)))
    last_kid(banner).pos = flag_top
    return banner, flag_top

// The builders' Wonder (stone): a great temple on a stepped podium, a colonnade, a bronze figure.
def wonder_stone(team:float3) -> BSpec:
    let body = mnode()
    let stone = bm("stone")
    let plaster = bm("plaster")
    let marble = bflat(html("#e6e0d2"), 0.75)
    let gold = bflat(html("#e0b040"), 0.3, 0.85)
    let bronze = bflat(html("#b07a36"), 0.4, 0.7)
    var y = 0.0
    for(3) s:   // the podium, three steps
        let wd = 4.7 - float(s) * 0.35
        add_child(body, bbox(bv(wd, 0.18, wd), stone, bv(0.0, y + 0.09, -float(s) * 0.12)))
        y += 0.18
    let cz = -0.25
    let w = 3.3
    let d = 3.6
    add_child(body, bbox(bv(w - 0.7, 1.5, d - 0.8), plaster, bv(0.0, y + 0.75, cz)))   // the hall
    add_child(body, bbox(bv(w - 0.68, 0.14, d - 0.78), bcloth(team), bv(0.0, y + 1.32, cz)))   // a frieze in the team colour
    add_child(body, bbox(bv(0.6, 0.9, 0.04), bflat(html("#3a2414"), 0.8), bv(0.0, y + 0.45, cz + (d - 0.8) / 2.0 + 0.02)))   // the doors
    for(6) k:
        add_child(body, bball(0.03, gold, bv(-0.15 + float(k % 3) * 0.15, y + 0.3 + float(k / 3) * 0.35, cz + (d - 0.8) / 2.0 + 0.05)))
    let colh = 1.55
    for(6) i:   // the colonnade
        for([-1.0, 1.0]) side:
            let x = -w / 2.0 + 0.15 + float(i) * (w - 0.3) / 5.0
            add_child(body, bcyl(0.085, 0.1, colh, marble, bv(x, y + colh / 2.0, cz + side * (d / 2.0 - 0.15)), float3_0, 14))
    for(5) i1:
        let i = i1 + 1
        for([-1.0, 1.0]) side:
            let z = cz - d / 2.0 + 0.15 + float(i) * (d - 0.3) / 6.0
            add_child(body, bcyl(0.085, 0.1, colh, marble, bv(side * (w / 2.0 - 0.15), y + colh / 2.0, z), float3_0, 14))
    add_child(body, bbox(bv(w + 0.1, 0.2, d + 0.1), marble, bv(0.0, y + colh + 0.1, cz)))   // the entablature
    add_child(body, bbox(bv(w + 0.12, 0.07, d + 0.12), bcloth(team), bv(0.0, y + colh + 0.06, cz)))
    let holder = mnode()
    holder.pos = bv(0.0, y + colh + 0.2, cz)
    add_child(body, holder)
    let rise = tile_roof(holder, float3_0, w / 2.0 + 0.12, d + 0.2, 22.0, marble, plaster)
    let ry = y + colh + 0.2
    add_child(body, bbox(bv(0.1, 0.08, d + 0.25), gold, bv(0.0, ry + rise + 0.03, cz)))   // the gilded ridge
    for([-1.0, 1.0]) z:
        add_child(body, bball(0.09, gold, bv(0.0, ry + rise + 0.1, cz + z * (d / 2.0 + 0.1))))
    add_child(body, bball(0.17, bcloth(team), bv(0.0, ry + rise * 0.4, cz + d / 2.0 + 0.12), bv(1.0, 1.0, 0.3)))
    add_child(body, bring(0.16, 0.21, gold, bv(0.0, ry + rise * 0.4, cz + d / 2.0 + 0.13), bv(90.0, 0.0, 0.0)))
    for([-0.7, 0.7]) x:
        add_child(body, bcyl(0.16, 0.08, 0.12, bronze, bv(x, y + 0.06, 1.62), float3_0, 14))
        add_child(body, bcyl(0.13, 0.13, 0.02, bglow(html("#ff9a3a"), 2.0), bv(x, y + 0.12, 1.62), float3_0, 14))
    let fig = bv(-1.85, y, 1.5)
    add_child(body, bbox(bv(0.4, 0.5, 0.4), marble, fig + bv(0.0, 0.25, 0.0)))
    add_child(body, bcyl(0.1, 0.14, 0.55, bronze, fig + bv(0.0, 0.78, 0.0), float3_0, 12))
    add_child(body, bball(0.08, bronze, fig + bv(0.0, 1.12, 0.0)))
    add_child(body, beam(fig + bv(0.1, 0.95, 0.0), fig + bv(0.2, 1.45, 0.05), 0.02, bronze, 6))   // a raised spear
    let banner, pivot = bld_pennant(body, bv(1.9, y, 1.55), 2.6, team, gold)
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    blights(sp, [bv(-0.7, y + 0.14, 1.62), bv(0.7, y + 0.14, 1.62)])
    bpt(sp, "smoke", bv(0.7, y + 0.3, 1.62))
    return bpt(sp, "lantern", bv(0.0, y + 0.6, cz + d / 2.0 + 0.1))

// The timber towns' Wonder (thatch): the elders' great hall, a stave tower, carved posts, a fire pit.
def wonder_thatch(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let thatch = bm("thatch")
    let dark = bflat(html("#3a2414"), 0.8)
    let hall = mnode()
    hall.pos = bv(0.0, 0.0, -0.3)
    add_child(body, hall)
    let base = bld_hall(hall, "thatch", 3.6, 2.4, 0.85)
    let rise = bld_roof(hall, "thatch", bv(0.0, base + 0.85, 0.0), 3.6, 2.4)
    add_child(hall, bbox(bv(0.6, 0.7, 0.04), bcloth(team), bv(0.0, base + 0.35, 1.22)))
    var y = base + 0.85 + rise * 0.55
    let sizes = [1.3, 1.0, 0.7]
    let hs = [0.6, 0.45, 0.4]
    for(3) s:
        let sz = sizes[s]
        let hh = hs[s]
        add_child(hall, bbox(bv(sz, hh, sz), wood, bv(0.0, y + hh / 2.0, 0.0)))
        for([-1.0, 1.0]) x:
            for([-1.0, 1.0]) z:
                add_child(hall, bbox(bv(0.07, hh + 0.04, 0.07), dark, bv(x * sz / 2.0, y + hh / 2.0, z * sz / 2.0)))
        add_child(hall, bcyl(0.0, sz * 0.95, sz * 0.55, thatch, bv(0.0, y + hh + sz * 0.22, 0.0), bv(0.0, 45.0, 0.0), 4))
        y += hh + sz * 0.3
    add_child(hall, beam(bv(0.0, y + 0.05, 0.0), bv(0.0, y + 0.5, 0.0), 0.02, wood, 6))
    add_child(hall, bbox(bv(0.24, 0.16, 0.02), bcloth(team), bv(0.12, y + 0.42, 0.0)))
    for([bv(-2.15, 0.0, 1.55), bv(2.15, 0.0, 1.55), bv(-2.15, 0.0, -1.8), bv(2.15, 0.0, -1.8)]) p:
        let h = 1.5
        add_child(body, bcyl(0.11, 0.14, h, wood, p + bv(0.0, h / 2.0, 0.0), float3_0, 10))
        for(3) r:
            add_child(body, bring(0.1, 0.15, dark, p + bv(0.0, 0.4 + float(r) * 0.35, 0.0)))
        add_child(body, bbox(bv(0.26, 0.3, 0.26), wood, p + bv(0.0, h + 0.15, 0.0)))   // the carved head
        add_child(body, bbox(bv(0.28, 0.07, 0.28), bcloth(team), p + bv(0.0, h + 0.05, 0.0)))   // painted in the team colour
        add_child(body, bbox(bv(0.1, 0.08, 0.16), dark, p + bv(0.0, h + 0.12, 0.18), bv(-15.0, 0.0, 0.0)))   // its beak
        add_child(body, bbox(bv(0.34, 0.05, 0.08), dark, p + bv(0.0, h + 0.32, 0.0)))   // a crest
        for([-0.07, 0.07]) x:   // its eyes
            add_child(body, bball(0.035, bflat(html("#f0e6c8"), 0.6), p + bv(x, h + 0.22, 0.13)))
    let pit = bv(0.0, 0.0, 1.6)
    add_child(body, bring(0.24, 0.36, bm("stone"), pit + bv(0.0, 0.04, 0.0)))
    add_child(body, bcyl(0.22, 0.22, 0.03, bglow(html("#ff8a30"), 2.2), pit + bv(0.0, 0.04, 0.0), float3_0, 14))
    for([-0.8, 0.8]) x:
        add_child(body, bbox(bv(0.7, 0.08, 0.16), wood, bv(x, 0.18, 1.7)))
        for([-0.25, 0.25]) e:
            add_child(body, bbox(bv(0.08, 0.16, 0.12), wood, bv(x + e, 0.08, 1.7)))
    let sp = bspec(body)
    blights(sp, [pit + bv(0.0, 0.06, 0.0)])
    bpt(sp, "smoke", pit + bv(0.0, 0.2, 0.0))
    bpt(sp, "lantern", bv(0.5, base + 0.5, 0.95))
    return bteam(sp, team)

// The junk-rats' Wonder: the Great Cheese on a giant tin can, ringed with painted oil drums.
def wonder_junk(team:float3) -> BSpec:
    brng = grng(91)
    let body = mnode()
    let brick = bm("brick")
    let tin = bm("tin")
    let wood = bm("wood")
    let gold = bflat(html("#e0b040"), 0.3, 0.85)
    add_child(body, bbox(bv(4.5, 0.3, 4.5), brick, bv(0.0, 0.15, 0.0)))
    add_child(body, bbox(bv(3.6, 0.2, 3.6), brick, bv(0.0, 0.4, 0.0)))
    let paint = [html("#8a3a2a"), html("#3a5a7a"), html("#6a6a5a"), html("#7a6a2a")]
    var n = 0
    for(4) side:   // oil drums round the plinth's top
        for(3) k:
            let t = -1.2 + float(k) * 1.2
            let at = if side == 0: bv(t, 0.5, 1.6) elif side == 1: bv(1.6, 0.5, -t) elif side == 2: bv(-t, 0.5, -1.6) else: bv(-1.6, 0.5, t)
            if not (side == 0 and k == 1):   // (the way in)
                bld_drum(body, at, 0.22, 0.5, paint[n % 4])
                n++
    let can_h = 1.0
    add_child(body, bcyl(1.15, 1.15, can_h, tin, bv(0.0, 0.5 + can_h / 2.0, -0.1), float3_0, 32))   // the great can
    for([0.2, 0.5, 0.8]) y:
        add_child(body, bring(1.13, 1.2, bflat(html("#9a9c96"), 0.5, 0.5), bv(0.0, 0.5 + can_h * y, -0.1)))
    add_child(body, bcyl(1.0, 1.0, 0.04, bflat(html("#c8ccd0"), 0.35, 0.8), bv(0.0, 0.5 + can_h + 0.02, -0.1), float3_0, 32))
    add_child(body, bbox(bv(0.5, 0.7, 0.04), bflat(html("#2a1e16"), 0.9), bv(0.0, 0.85, 1.07)))   // a door cut in the can
    add_child(body, bbox(bv(1.0, 0.18, 0.03), bcloth(team), bv(0.0, 1.3, 1.06)))   // a label in the team colour
    let cheese = bflat(html("#f2c94c"), 0.7)
    let rind = bflat(html("#c99a1e"), 0.8)
    let c = bv(0.0, 0.5 + can_h + 0.92, -0.1)
    for([-0.4, 0.4]) x:
        add_child(body, bbox(bv(0.12, 0.3, 0.9), wood, bv(x, 0.5 + can_h + 0.15, -0.1)))
    add_child(body, bcyl(0.9, 0.9, 0.62, cheese, c, bv(90.0, 0.0, 0.0), 32))
    for([0.3, -0.3]) z:
        add_child(body, bring(0.86, 0.94, rind, c + bv(0.0, 0.0, z), bv(90.0, 0.0, 0.0)))
    for(7):   // holes on the face
        let a = randf(brng) * TAU
        let r = randf_range(brng, 0.15, 0.7)
        let top_r = 0.06 + randf(brng) * 0.06
        add_child(body, bcyl(top_r, 0.06, 0.02, bflat(html("#c8961e"), 0.9), c + bv(rcos(a) * r, rsin(a) * r, 0.315), bv(90.0, 0.0, 0.0), 12))
    let cap = c + bv(0.0, 0.95, 0.0)
    add_child(body, bcyl(0.3, 0.3, 0.08, gold, cap, float3_0, 20))
    for(12) k:
        let a = TAU * float(k) / 12.0
        add_child(body, bbox(bv(0.06, 0.12, 0.05), gold, cap + bv(rcos(a) * 0.3, -0.03, rsin(a) * 0.3), bv(0.0, -rad(a), 0.0)))
    bld_pennant(body, bv(1.6, 0.5, -1.6), 2.0, team)   // a still pole at the back (its banner dropped)
    add_child(body, slab_tri(float2 { 0.0, 0.0 }, float2 { 0.5, -0.18 }, float2 { 0.0, -0.4 }, 0.02, bcloth(team)))
    last_kid(body).pos = bv(1.63, 2.35, -1.6)
    let banner, pivot = bld_pennant(body, bv(-1.6, 0.5, 1.6), 2.2, team)
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    bpt(sp, "lantern", bv(0.4, 1.0, 1.15))
    return bteam(sp, team)

// The tent people's Wonder: the great pavilion, four tents round it, horse-tail standards.
def wonder_tent(team:float3) -> BSpec:
    let body = mnode()
    let wood = bm("wood")
    let felt = bm("felt")
    let gold = bflat(html("#e0b040"), 0.3, 0.85)
    add_child(body, bcyl(1.85, 1.95, 0.14, wood, bv(0.0, 0.07, -0.1), float3_0, 32))   // the floor
    let top = bld_yurt(body, bv(0.0, 0.14, -0.1), 1.6, 1.0, team)
    add_child(body, bcyl(0.62, 0.62, 0.45, felt, bv(0.0, 0.14 + top + 0.2, -0.1), float3_0, 24))   // the upper storey
    add_child(body, bring(0.6, 0.66, bcloth(team), bv(0.0, 0.14 + top + 0.35, -0.1)))
    add_child(body, bcyl(0.12, 0.7, 0.42, felt, bv(0.0, 0.14 + top + 0.62, -0.1), float3_0, 24))
    let crown = bv(0.0, 0.14 + top + 0.86, -0.1)
    add_child(body, bcyl(0.14, 0.14, 0.08, gold, crown, float3_0, 16))
    add_child(body, bcyl(0.0, 0.06, 0.4, gold, crown + bv(0.0, 0.24, 0.0), float3_0, 8))
    add_child(body, bball(0.07, gold, crown + bv(0.0, 0.12, 0.0)))
    for([bv(-1.75, 0.0, 1.55), bv(1.75, 0.0, 1.55), bv(-1.85, 0.0, -1.65), bv(1.85, 0.0, -1.65)]) at:
        bld_yurt(body, at, 0.42, 0.42, team)
    let hair = bflat(html("#2a2018"), 0.95)
    for(6) k:
        let a = TAU * (float(k) + 0.5) / 6.0
        let foot = bv(rcos(a) * 2.15, 0.0, rsin(a) * 2.0 - 0.1)
        if not (foot.z > 1.2 and abs(foot.x) < 0.8):   // (the way in stays open)
            add_child(body, bcyl(0.025, 0.03, 2.1, wood, foot + bv(0.0, 1.05, 0.0), float3_0, 6))
            add_child(body, bcyl(0.0, 0.04, 0.16, gold, foot + bv(0.0, 2.18, 0.0), float3_0, 6))
            add_child(body, bball(0.1, hair, foot + bv(0.0, 1.9, 0.0), bv(1.0, 1.8, 1.0)))
    let banner, pivot = bld_pennant(body, bv(-0.75, 0.14, 1.75), 2.5, team, gold)
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    bpt(sp, "smoke", crown + bv(0.0, 0.1, 0.0))
    bpt(sp, "lantern", bv(0.0, 0.6, 1.6))
    return bteam(sp, team)

// The frogs' Wonder: the Lily Spire, a pink water lily the size of a hut on a spire of woven drums.
def wonder_reed(team:float3) -> BSpec:
    brng = grng(92)
    let body = mnode()
    let weave = bm("weave")
    let thatch = bm("thatch")
    let deck = bld_stilt_deck(body, float3_0, 4.5, 4.5)
    let top = bld_reed_dome(body, bv(0.0, deck, -0.2), 1.35, team)
    var y = top - 0.15
    let radii = [0.7, 0.52, 0.38]
    for(3) s:   // the spire: drum, cap, drum, cap ...
        let r = radii[s]
        add_child(body, bcyl(r * 0.92, r, 0.4, weave, bv(0.0, y + 0.2, -0.2), float3_0, 24))
        add_child(body, bring(r - 0.02, r + 0.04, if s == 0: bcloth(team) else: bm("mud"), bv(0.0, y + 0.08, -0.2)))
        add_child(body, bdome(r + 0.08, thatch, bv(0.0, y + 0.38, -0.2), bv(1.0, 0.45, 1.0)))
        y += 0.52
    let heart = bv(0.0, y + 0.1, -0.2)
    add_child(body, bcyl(0.75, 0.75, 0.03, bflat(html("#3d6a2c"), 0.8), heart - bv(0.0, 0.12, 0.0), float3_0, 24))
    for(2) rk:
        let count = if rk == 0: 8 else: 6
        for(count) k:
            let a = TAU * (float(k) + float(rk) * 0.5) / float(count)
            let lean = if rk == 0: 55.0 else: 25.0
            let petal = mnode()   // turned to face out, then tipped outwards
            petal.pos = heart + bv(rcos(a), 0.0, rsin(a)) * (0.3 - float(rk) * 0.13) + bv(0.0, 0.12 + float(rk) * 0.08, 0.0)
            petal.rot = bv(0.0, -rad(a) + 90.0, 0.0)
            add_child(body, petal)
            add_child(petal, bball(0.32 - float(rk) * 0.06, bflat(if rk == 0: html("#e890b0") else: html("#f4c0d0"), 0.6), float3_0, bv(0.45, 1.0, 0.22), bv(lean, 0.0, 0.0)))
    add_child(body, bball(0.13, bflat(html("#f2c94c"), 0.5), heart + bv(0.0, 0.2, 0.0)))
    for([bv(-1.7, deck, -1.7), bv(1.65, deck, 1.6), bv(1.75, deck, -1.7)]) at:
        bld_reed_dome(body, at, 0.42, team, 20.0 * signf(at.x))
    bld_reed_fence(body, bv(0.0, deck, 0.0), 2.15)
    let wood = bm("wood")
    for(3) k:   // steps down at the front
        add_child(body, bbox(bv(0.6, 0.05, 0.16), wood, bv(0.0, deck * (float(k) + 0.5) / 3.0, 2.55 - float(k) * 0.14)))
    let banner, pivot = bld_pennant(body, bv(-1.9, deck, 1.9), 2.2, team)
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    bpt(sp, "lantern", bv(0.0, deck + 0.4, 1.3))
    return bteam(sp, team)

// The bugs' Wonder: the great termite spires, round doors, amber glowing in the walls, a shell trophy.
def wonder_mound(team:float3) -> BSpec:
    brng = grng(93)
    let body = mnode()
    let mud = bm("mud")
    add_child(body, bdome(2.0, mud, bv(0.0, 0.0, -0.1), bv(1.05, 0.55, 1.0)))
    let spire_at = [bv(-0.1, 0.0, -0.35), bv(-0.95, 0.0, 0.35), bv(0.85, 0.0, -0.85), bv(0.9, 0.0, 0.6), bv(-1.0, 0.0, -1.1)]
    let spire_r = [0.75, 0.5, 0.55, 0.45, 0.42]
    let spire_h = [3.4, 2.3, 2.6, 1.8, 1.7]
    for(5) i:
        let at = spire_at[i]
        let r = spire_r[i]
        let h = spire_h[i]
        let rx = randf_range(brng, -3.0, 3.0)
        let rz = randf_range(brng, -3.0, 3.0)
        add_child(body, bcyl(r * 0.12, r, h, mud, at + bv(0.0, h / 2.0, 0.0), bv(rx, 0.0, rz), 14))
        for(3) k:   // flutes: lumps up its sides
            let a = TAU * float(k) / 3.0 + randf(brng)
            add_child(body, bcyl(r * 0.05, r * 0.4, h * 0.6, mud, at + bv(rcos(a) * r * 0.55, h * 0.3, rsin(a) * r * 0.55), float3_0, 8))
    bld_burrow_door(body, bv(0.0, 0.32, 1.8), 0.3, 0.0, team)
    bld_burrow_door(body, bv(-1.6, 0.25, 1.0), 0.16, -50.0, team)
    bld_burrow_door(body, bv(1.75, 0.25, 0.6), 0.16, 60.0)
    let amber = bglow(html("#ffb040"), 1.6)
    let lights = []::float3
    for([bv(-0.55, 0.65, 1.55), bv(0.6, 0.7, 1.45), bv(-0.1, 1.6, 0.25), bv(0.95, 1.2, -0.45)]) p:
        add_child(body, bball(0.08, amber, p, bv(1.0, 1.3, 0.7)))
        lights.push(p)
    let shell = bflat(html("#2e5a4a"), 0.25, 0.6)
    add_child(body, bball(0.32, shell, bv(0.0, 0.95, 1.62), bv(1.0, 0.55, 0.5), bv(-25.0, 0.0, 0.0)))
    add_child(body, bbox(bv(0.03, 0.17, 0.2), bflat(html("#1a3028"), 0.3), bv(0.0, 0.96, 1.75), bv(-25.0, 0.0, 0.0)))
    bld_grass_tufts(body, bv(0.0, 0.6, 0.0), 1.4, 12)
    let banner, pivot = bld_pennant(body, bv(1.85, 0.0, -1.8), 2.4, team)
    let sp = bspec(body)
    bbanner(sp, banner, pivot)
    blights(sp, lights)
    bpt(sp, "lantern", bv(0.3, 0.5, 1.9))
    return bteam(sp, team)
