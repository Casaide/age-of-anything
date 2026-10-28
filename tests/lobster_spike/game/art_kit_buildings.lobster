// ------------------------------------------------------------------ the buildings baked in the game (src/view/art/art_kit.gd: buildings)
// Every look of every building of a culture, as ArtKit names it, baked by the world baker (view/world_bake.lobster)
// from the Lobster models (model/buildings, buildings2) in the team key (magenta) into the pack: the body
// ("arch:type<suffix>"), its four construction stages (":stage0".. ":stage3"), a walkway's near merlons (":front"),
// its broken-up stages (":ruin1".. ":ruin4", game/ruin.lobster), a gate's open look (":open", ":open:front") and its flanking towers that stand down the screen (":tower<side>",
// ":tower<side>:front"), a wall's eight arms (":arm<k>", ":arm<k>:front", Models.LINKS order) and its picture
// (":icon"), a vane (":vane", anchored on its pivot). Suffixes: "@<age>" an age look, "#<v>" a house variant
// turned or mirrored, "^z" "^d" "^a" a gate along sim y and the two diagonals. Fills `looks` and `bfx` (the
// chimney smoke, lantern and windows, as building_fx.gd computes them). The originals: _building_jobs,
// _building_job, _bake_building, _placed, _variant_look, front_split, _bake_front, _bake_gate_parts, _hold_back,
// wall_look, _compose (art_kit.gd).
// Needs (imported by the game before this file): game/pack, game/art_kit (keep_frame, ak_rebake), model/buildings,
// model/buildings2, model/build_mats, view/world_bake, gen/datalib, game/ruin.

let AKB_HOUSE_SCALE = 1.1
let AKB_BUILD_STAGES = [0.15, 0.4, 0.45, 0.72]
let AKB_ALONG = ["", "^z", "^d", "^a"]
let AKB_SEEN = float3 { 1.0, 0.0, 1.0 }
let AKB_TEAM = float3 { 1.0, 0.0, 1.0 }              // PartShape.TEAM_KEY: the sprite shader recolours it
let AKB_NONE = float3 { -999999.0, -999999.0, -999999.0 }
let AKB_WALK_PX = 32.0 / 0.70710678 * 0.8660254      // ArtKit.WALK_PX_PER_UNIT
var akb_data:JV? = nil
var akb_baked = 0
var akb_wall_piece = false
var akb_keep_all = false   // keep every bake's pixels (checks)
let akb_px = dictionary<string, string>(256)        // a wall piece's pixels (for wall_look), by frame name
let akb_size = dictionary<string, int2>(256)
let akb_origin = dictionary<string, int2>(256)

def akb_bdata() -> JV:
    let d = akb_data
    if d: return d
    let n = load_json(lib_root + "/buildings.json")
    akb_data = n
    return n

def akb_has(s:BSpec, k:string) -> bool: return s.pts.get(k, AKB_NONE) != AKB_NONE
def akb_pt(s:BSpec, k:string) -> float3: return s.pts.get(k, float3_0)

// A culture's own scale for a type (buildings.json "scale").
def akb_scale(arch:string, type:string) -> float:
    let sc = gobj(gobj(akb_bdata(), "scale"), arch)
    return if has(sc, type): as_float(at(sc, type)) else: 1.0

// ---- where a model point lands on the bake (the camera: 30 down, 45 round), in canvas units from the anchor

def akb_project(p:float3) -> float2:
    let view = euler(float3 { -30.0, 45.0, 0.0 })
    return float2 { dot(p, view.x), -dot(p, view.y) } * (32.0 / 0.70710678)

// ---- placing a look (ArtKit._placed, _variant_look)

// The turn (and maybe mirror) of a building's variant v; false: unturned.
def akb_variant_look(spec:BSpec, name:string, v:int) -> Basis, bool:
    assert akb_has(spec, "door")
    let door = akb_pt(spec, "door")
    let window = if akb_has(spec, "window"): akb_pt(spec, "window") else: door
    assert dot(door, AKB_SEEN) > 0.0
    let mirror = Basis { float3 { 0.0, 0.0, 1.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { 1.0, 0.0, 0.0 } }
    let both = []::Basis
    let door_only = []::Basis
    for([false, true]) flip:
        for(4) q:
            let r = axis_angle(float3 { 0.0, 1.0, 0.0 }, float(q) * 90.0)
            let b = if flip: bmul(r, mirror) else: r
            if (not flip and q == 0) or dot(bxf(b, door), AKB_SEEN) <= 0.0: continue
            if dot(bxf(b, window), AKB_SEEN) > 0.0: both.push(b) else: door_only.push(b)
    let n = 1 + both.length + door_only.length
    let k = v % n
    if k == 0: return BASIS_ID, false
    let b = if k - 1 < both.length: both[k - 1] else: door_only[k - 1 - both.length]
    return b, true

def akb_hold(n:MNode?, b:Basis) -> MNode?:
    if not n: return nil
    let holder = mnode()
    add_child(holder, n)
    set_basis(holder, b)
    return holder

// A building's model at its size and turn: houses a little smaller than halls, a culture's own scale for a type,
// a variant's turn or mirror and nudge in size, a gate along its wall.
def akb_placed(arch:string, type:string, model:string, suffix:string) -> BSpec:
    let diagonal = suffix == "^d" or suffix == "^a"
    gate_span = 3.0 * (if diagonal: sqrt(2.0) else: 1.0)
    let spec = building_spec(arch, type, AKB_TEAM, model)
    gate_span = 3.0
    assert spec
    var s = (if type == "house": AKB_HOUSE_SCALE else: 1.0) * akb_scale(arch, type)
    var look = BASIS_ID
    var turned = false
    let hash_at = find_string(suffix, "#")
    let v = if hash_at >= 0: string_to_int(suffix.substring(hash_at + 1, suffix.length - hash_at - 1)) else: 0
    if v > 0:
        look, turned = akb_variant_look(spec, "{arch}:{type}", v)
        s *= [1.0, 0.94, 1.05, 0.9][v % 4]
    if suffix == "^z":
        look = axis_angle(float3 { 0.0, 1.0, 0.0 }, 90.0)
        turned = true
    elif diagonal:
        look = axis_angle(float3 { 0.0, 1.0, 0.0 }, if suffix == "^d": -45.0 else: 45.0)
        turned = true
    if s == 1.0 and not turned: return spec
    let b = bscaled_global(look, float3_1 * s)
    spec.body = akb_hold(spec.body, b) or spec.body
    spec.banner = akb_hold(spec.banner, b)
    spec.vane = akb_hold(spec.vane, b)
    spec.open = akb_hold(spec.open, b)
    for(["smoke", "lantern", "banner_pivot", "vane_pivot"]) k:
        if akb_has(spec, k): spec.pts.set(k, bxf(b, akb_pt(spec, k)))
    spec.lights = map(spec.lights) p: bxf(b, p)
    spec.doorway = map(spec.doorway) p: bxf(b, p)
    return spec

// ---- the near layer (ArtKit.front_split)

// A walkway's near merlons on `root`: hide them (front_only false) or show only them (true). How many there are.
def akb_front_split(root:MNode, front_only:bool) -> int:
    return akb_front_walk(root, node_xform(root), XF_ID, front_only)

def akb_front_walk(node:MNode, t:Xform, parent:Xform, front_only:bool) -> int:
    var n = 0
    for(node.kids) c: n += akb_front_walk(c, xmul(t, node_xform(c)), t, front_only)
    if not node.mesh: return n
    var front = false
    let tk = tokenize(node.meta, " ", "")
    if tk.length >= 4 and tk[0] == "parapet":
        var p = float3 { t.o.x, 0.0, t.o.z }
        let ai = find(tk) w: w == "about"
        if ai >= 0:
            let o = xf(parent, float3 { string_to_float(tk[ai + 1]), string_to_float(tk[ai + 2]), string_to_float(tk[ai + 3]) })
            p -= float3 { o.x, 0.0, o.z }
        var along = bxf(t.b, float3 { string_to_float(tk[1]), string_to_float(tk[2]), string_to_float(tk[3]) })
        along = float3 { along.x, 0.0, along.z }
        if magnitude(along) > 0.001:
            along = normalize(along)
            p -= along * dot(p, along)
        front = p.x + p.z > 0.04
    if front: n++
    node.visible = if front_only: front else: not front
    return n

// ---- under construction (ArtKit._hold_back)

class AkbBox:
    node:MNode
    lo:float3
    hi:float3

def akb_boxes(node:MNode, t:Xform, out:[AkbBox]) -> void:
    let m = node.mesh
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
        out.push(AkbBox { node, blo, bhi })
    for(node.kids) k: akb_boxes(k, xmul(t, node_xform(k)), out)

// A building under construction: parts held back by height (foundations first, the roof last) and a scaffold of
// poles and rails round the footprint up to just above what's built.
def akb_hold_back(body:MNode, stage:int):
    let cut = AKB_BUILD_STAGES[stage]
    let boxes = []::AkbBox
    for(body.kids) k: akb_boxes(k, node_xform(k), boxes)
    var alo = float3_1 * 1000000000.0
    var ahi = float3_1 * -1000000000.0
    for(boxes) b:
        alo = min(alo, b.lo)
        ahi = max(ahi, b.hi)
    let h = ahi.y - alo.y
    var top = 0.0
    for(boxes) b:
        let at = (if stage < 2: b.hi.y else: (b.lo.y + b.hi.y) * 0.5) - alo.y
        if at > cut * h: b.node.visible = false
        else: top = max(top, b.hi.y)
    let wood = bm("wood")
    let lo = float3 { alo.x - 0.04, 0.0, alo.z - 0.04 }
    let hi = float3 { ahi.x + 0.04, 0.0, ahi.z + 0.04 }
    let pole_h = max(top + 0.08, 0.22)
    let posts = []::float3
    for([0.0, 0.5, 1.0]) fx:
        for([0.0, 0.5, 1.0]) fz:
            if not (fx == 0.5 and fz == 0.5):
                posts.push(float3 { lo.x + (hi.x - lo.x) * fx, 0.0, lo.z + (hi.z - lo.z) * fz })
    for(posts) q: add_child(body, beam(q, q + float3 { 0.0, pole_h, 0.0 }, 0.016, wood))
    let around = [posts[0], posts[1], posts[2], posts[4], posts[7], posts[6], posts[5], posts[3]]
    let levels = if pole_h > 0.3: [pole_h * 0.5, pole_h - 0.03] else: [pole_h - 0.03]
    for(levels) y:
        for(around) a, k:
            let c = around[(k + 1) % around.length]
            add_child(body, beam(a + float3 { 0.0, y, 0.0 }, c + float3 { 0.0, y, 0.0 }, 0.011, wood))

// ---- gate parts (ArtKit._bake_gate_parts)

// The gate parts on `node` (its transform t from the bake's root): [side, x + z of its middle].
def akb_gate_parts(node:MNode, t:Xform, out:[int2]) -> void:
    let tk = tokenize(node.meta, " ", "")
    if tk.length >= 6 and tk[0] == "gate_part":
        let c = xf(t, float3 { string_to_float(tk[3]), string_to_float(tk[4]), string_to_float(tk[5]) })
        if c.x + c.z > 0.3: out.push(int2 { string_to_int(tk[1]), 0 })
    for(node.kids) k: akb_gate_parts(k, xmul(t, node_xform(k)), out)

// The meshes not of gate part `side`: hidden (shadow false) or gathered to cast shadows only (into `out`).
def akb_not_part(node:MNode, part:int, side:int, out:[MNode]) -> void:
    var p = part
    let tk = tokenize(node.meta, " ", "")
    if tk.length >= 2 and tk[0] == "gate_part": p = string_to_int(tk[1])
    if node.mesh and p != side: out.push(node)
    for(node.kids) k: akb_not_part(k, p, side, out)

// ---- baking

// One model baked into the pack as frame `name`, anchored on `pivot` (a model point; the origin by default).
def akb_keep(name:string, model:MNode, shadow:bool, pivot:float3 = float3_0, shadow_only:[MNode] = []):
    let sprite, w, h, anchor = if shadow_only.length: akb_world_bake(model, shadow, shadow_only) else: world_bake(model, shadow)
    let at = anchor + akb_project(pivot) * WB_ART
    keep_frame(name, sprite, w, h, at)
    if akb_wall_piece or akb_keep_all:
        akb_px.set(name, sprite)
        akb_size.set(name, int2 { w, h })
        akb_origin.set(name, int2 { int(at.x + 0.5), int(at.y + 0.5) })
    akb_baked++


// One look of a building, with its stages and extra parts, into the pack; its Look and BFx.
def akb_bake_look(arch:string, type:string, model:string, suffix:string):
    let name = "{arch}:{type}{suffix}"
    let spec = akb_placed(arch, type, model, suffix)
    akb_wall_piece = spec.arms.length > 0
    // where the chimney smokes, the lantern and windows glow (building_fx.gd)
    let lights = []::float2
    if akb_has(spec, "lantern"): lights.push(akb_project(akb_pt(spec, "lantern")))
    for(spec.lights) l: lights.push(akb_project(l))
    bfx.set(name, BFx { if akb_has(spec, "smoke"): akb_project(akb_pt(spec, "smoke")) else: float2_0, akb_has(spec, "smoke"), lights })
    let lk = Look { name, map(4) st: "{name}:stage{st}", "-" }
    let fronts = akb_front_split(spec.body, false)
    akb_keep(name, spec.body, true)
    if fronts > 0:
        let again = akb_placed(arch, type, model, suffix)
        akb_front_split(again.body, true)
        akb_keep(name + ":front", again.body, false)
        lk.front = name + ":front"
    let op = spec.open
    if op:
        let open_fronts = akb_front_split(op, false)
        akb_keep(name + ":open", op, true)
        if open_fronts > 0:
            let again = akb_placed(arch, type, model, suffix)
            let aop = again.open
            if aop:
                akb_front_split(aop, true)
                akb_keep(name + ":open:front", aop, false)
        let sides = []::int2
        akb_gate_parts(spec.body, node_xform(spec.body), sides)
        for(sides) sd:
            let key = "{name}:tower{sd.x}"
            let whole = akb_placed(arch, type, model, suffix)
            akb_front_split(whole.body, false)
            let others = []::MNode
            akb_not_part(whole.body, 0, sd.x, others)
            akb_keep(key, whole.body, false, float3_0, others)
            let fr = akb_placed(arch, type, model, suffix)
            akb_front_split(fr.body, true)
            let hide = []::MNode
            akb_not_part(fr.body, 0, sd.x, hide)
            for(hide) m: m.visible = false
            akb_keep(key + ":front", fr.body, false)
    if spec.arms.length:
        let with_front = []::int
        for(spec.arms) a, k:
            if akb_front_split(a, false) > 0: with_front.push(k)
        for(spec.arms) a, k: akb_keep("{name}:arm{k}", a, true)
        let ic = spec.icon
        if ic: akb_keep(name + ":icon", ic, true)
        lk.arms = map(spec.arms.length) k: "{name}:arm{k}"
        lk.arms_front = map(spec.arms.length): "-"
        if with_front.length:
            let again = akb_placed(arch, type, model, suffix)
            for(with_front) k:
                akb_front_split(again.arms[k], true)
                akb_keep("{name}:arm{k}:front", again.arms[k], false)
                lk.arms_front[k] = "{name}:arm{k}:front"
    let vane = spec.vane
    if vane: akb_keep(name + ":vane", vane, false, akb_pt(spec, "vane_pivot"))
    akb_wall_piece = false
    for(4) st:
        let p = akb_placed(arch, type, model, suffix)
        akb_hold_back(p.body, st)
        akb_keep("{name}:stage{st}", p.body, true)
    // Broken up (D-171): battered, breaking, collapsed, and the ruin it leaves (game/ruin.lobster); not for walls
    // and gates, nor what has a near layer.
    if not spec.arms.length and not op and fronts == 0:
        for(RUIN_STAGES.length - 1) k:
            let p = akb_placed(arch, type, model, suffix)
            ruin_apply(p.body, k + 1, hash_text(name))
            akb_keep("{name}:ruin{k + 1}", p.body, true)
        lk.ruins = map(RUIN_STAGES.length - 1) k: "{name}:ruin{k + 1}"
    looks.set(name, lk)

// The building types in ArtKit's order: town centre and houses first, the menus, then the rest (not planned).
def akb_types() -> [string]:
    let d = akb_bdata()
    let types = ["town_center", "house"]
    let menu = gobj(d, "menu")
    for(append(gstrs(menu, "civilian"), gstrs(menu, "military"))) t:
        if not has_s(types, t): types.push(t)
    let b = gobj(d, "buildings")
    let rest = []::string
    for(b.keys) t:
        if not has_s(types, t) and gstr(at(b, t), "status", "") != "planned": rest.push(t)
    return append(types, sorted_strs(rest))

// Every look of a building in an architecture: [model, suffix] (the base, age looks, variants, a gate's ways).
def akb_looks_of(arch:string, type:string) -> [[string]]:
    let d = akb_bdata()
    let out = [["", ""]]
    let by_age = gobj(gobj(gobj(d, "age_looks"), arch), type)
    for(by_age.keys) age: out.push([as_str(at(by_age, age)), "@" + age])
    let nv = gint(gobj(d, "variants"), type, 1)
    for(nv - 1) v: out.push(["", "#{v + 1}"])
    if gbool(at(gobj(d, "buildings"), type), "gate", false):
        for(AKB_ALONG.slice(1, -1)) sfx: out.push(["", sfx])
    return out

// Whether a building look has broken-up stages: not walls and gates, nor what has a near layer.
def akb_breaks(type:string, lk:Look) -> bool:
    return not lk.arms.length and (lk.front == "-" or lk.front == "") and not gbool(at(gobj(akb_bdata(), "buildings"), type), "gate", false)

// Bake every look of every building of these architectures the pack lacks (all with ak_rebake). Frames baked.
def bake_buildings_for(archs:[string]) -> int:
    akb_baked = 0
    bmat_matte = true
    for(sorted_strs(archs)) arch, ai:
        if ai > 0 and sorted_strs(archs)[ai - 1] == arch: continue
        for(akb_types()) type:
            for(akb_looks_of(arch, type)) ml:
                let name = "{arch}:{type}{ml[1]}"
                let lk = looks.get(name)
                let unbroken = lk and akb_breaks(type, lk) and frame_index(name + ":ruin1") < 0   // (a pack made before D-171)
                if not bake_quit and (ak_rebake or not lk or frame_index(name) < 0 or unbroken):
                    bake_breath()
                    akb_bake_look(arch, type, ml[0], ml[1])
    return akb_baked

// ---- a wall tile with its arms (ArtKit.wall_look, _compose)

// A frame's pixels: from a bake this run, else read off its pack sheet. bytes, size, origin.
let akb_sheet_px = dictionary<int, string>(16)
def akb_frame_px(name:string) -> string, int2, int2:
    let mine = akb_px.get(name)
    if mine: return mine, akb_size.get(name, int2_0), akb_origin.get(name, int2_0)
    let f = frame_index(name)
    assert f >= 0
    let fr = frames[f]
    var px = akb_sheet_px.get(fr.sheet, "")
    if px == "":
        px = gl.read_texture(sheet_tex[fr.sheet]) or ""
        akb_sheet_px.set(fr.sheet, px)
    let sw = int(sheet_dims[fr.sheet].x)
    let out = ensure_size("", fr.w * fr.h * 4, 0)
    for(fr.h) y:
        for(fr.w * 4) i: write_int8_le(out, y * fr.w * 4 + i, px[((fr.y + y) * sw + fr.x) * 4 + i])
    return out, int2 { fr.w, fr.h }, int2 { fr.ox, fr.oy }

// Baked pieces (frame names, bottom first) on one image, anchored on the same point: every piece's ground shadow
// first (the darkest wins where they overlap), then the art. Kept as frame `name`; its index.
def akb_compose(name:string, pieces:[string]) -> int:
    var lo = int2_1 * 1048576
    var hi = -lo
    let pxs = []::string
    let szs = []::int2
    let os = []::int2
    for(pieces) p:
        let px, sz, o = akb_frame_px(p)
        lo = min(lo, -o)
        hi = max(hi, sz - o)
        pxs.push(px)
        szs.push(sz)
        os.push(o)
    let w = hi.x - lo.x
    let h = hi.y - lo.y
    let out = ensure_size("", w * h * 4, 0)
    for([false, true]) pass_art:
        for(pieces) _p, pi:
            let src = pxs[pi]
            let sz = szs[pi]
            let o = os[pi]
            let at = -o - lo
            for(sz.y) y:
                for(sz.x) x:
                    let s = (y * sz.x + x) * 4
                    let a = src[s + 3]
                    if a == 0 or (a == 255) != pass_art: continue
                    let d = ((at.y + y) * w + at.x + x) * 4
                    if not pass_art and out[d + 3] >= a: continue
                    for(4) k: write_int8_le(out, d + k, src[s + k])
    keep_frame(name, out, w, h, float2 { float(-lo.x), float(-lo.y) })
    return frame_index(name)

// A wall tile's look with arms to the neighbours in `links` (bit k: BLD_LINKS[k]), made on first use and kept:
// the frame of the tile, and of its near merlons (-1: none). Arms going up the screen lie under the post, those
// coming down over it.
def wall_look(name:string, links:int) -> int, int:
    let key = "{name}|{links}"
    let known = frame_index(key)
    if known >= 0: return known, frame_index(key + ":front")
    let lk = assert looks.get(name)
    let under = []::int
    let over = []::int
    for(BLD_LINKS) d, k:
        if links & (1 << k):
            if d.x + d.y <= 0: under.push(k) else: over.push(k)
    let front = []::string
    for(append(append(under, [-1]), over)) k:
        let f = if k < 0: lk.front else: if k < lk.arms_front.length: lk.arms_front[k] else: "-"
        if f != "-" and f != "": front.push(f)
    let pieces = []::string
    for(under) k: pieces.push(lk.arms[k])
    pieces.push(lk.body)
    for(over) k: pieces.push(lk.arms[k])
    let body = akb_compose(key, pieces)
    let fr = if front.length: akb_compose(key + ":front", front) else: -1
    return body, fr

// ---- the world baker with some meshes casting shadows only (Godot's SHADOW_CASTING_SETTING_SHADOWS_ONLY, for a
// gatehouse tower's layer: the rest of the gate shadows it but isn't drawn). view/world_bake.lobster's world_bake
// line for line, but for the `shadow_only` meshes, which go only into the sun's depth map.

def akb_world_bake(model:MNode, shadow:bool, shadow_only:[MNode]) -> string, int, int, float2:
    assert not shadow   // (a tower's layer bakes without a ground shadow)
    let all = []::WDraw
    world_draws(model, XF_ID, all)
    // which draws are shadow-only: world_draws makes one per mesh in tree order; walk the same order
    let only = []::bool
    akb_mark(model, shadow_only, only)
    let wdraws = []::WDraw
    let casters = []::WDraw
    for(all) d, i:
        casters.push(d)
        if not only[i]: wdraws.push(d)
    let wcam = euler(float3 { -30.0, 45.0, 0.0 })
    let cx = wcam.x
    let cy = wcam.y
    let cz = wcam.z
    let sun = light_along(float3 { -48.0, -58.0, 0.0 })
    let px = WB_PX * float(WB_SS)
    var lo = float2_1 * 1000000000.0
    var hi = float2_1 * -1000000000.0
    var dlo = 1000000000.0
    var dhi = -1000000000.0
    for(wdraws) d:
        for(d.p) p:
            let s = float2 { dot(p, cx), -dot(p, cy) }
            lo = min(lo, s)
            hi = max(hi, s)
            dlo = min(dlo, dot(p, cz))
            dhi = max(dhi, dot(p, cz))
            if shadow and p.y > 0.0:
                let g = p + sun * (p.y / -sun.y)
                let sg = float2 { dot(g, cx), -dot(g, cy) }
                lo = min(lo, sg)
                hi = max(hi, sg)
    let room = 4.0 / px * float(WB_SS)
    lo -= float2_1 * room
    hi += float2_1 * room
    let w = int(ceiling((hi.x - lo.x) * px))
    let h = int(ceiling((hi.y - lo.y) * px))
    let kx, ky, kz = looking_at(sun, float3 { 0.0, 1.0, 0.0 })
    var llo = float2_1 * 1000000000.0
    var lhi = float2_1 * -1000000000.0
    var zlo = 1000000000.0
    var zhi = -1000000000.0
    for(casters) d:
        for(d.p) p:
            let s = float2 { dot(p, kx), -dot(p, ky) }
            llo = min(llo, s)
            lhi = max(lhi, s)
            zlo = min(zlo, dot(p, kz))
            zhi = max(zhi, dot(p, kz))
    llo -= float2_1 * 0.5
    lhi += float2_1 * 0.5
    let lpx = px * 0.5
    let lw = int(ceiling((lhi.x - llo.x) * lpx))
    let lh = int(ceiling((lhi.y - llo.y) * lpx))
    let zs = 1.8 / max(0.001, zhi - zlo)
    let spos = []::float3
    for(casters) d:
        if not d.mat.scissor:
            for(d.p) p: spos.push(float3 { (dot(p, kx) - llo.x) * lpx, (-dot(p, ky) - llo.y) * lpx, 0.9 - (dot(p, kz) - zlo) * zs })
    let smap = gl.create_blank_texture(int3 { lw, lh, 0 }, texture_format_nomipmap | texture_format_float | texture_format_clamp)
    gl.switch_to_framebuffer(smap, true)
    gl.ortho(false, true)
    gl.clear(float4_1)
    gl.set_shader("worlddepth")
    gl.render_mesh(gl.new_mesh("P", spos, []::float4, []::float3, []::float2, []::float2, map(spos.length) i: i))
    let vz = 1.8 / max(0.001, dhi - dlo + 40.0)
    let dbase = dlo - 20.0
    def to_px(p:float3) -> float3: return float3 { (dot(p, cx) - lo.x) * px, (-dot(p, cy) - lo.y) * px, 0.9 - (dot(p, cz) - dbase) * vz }
    let art = gl.create_blank_texture(int3 { w, h, 0 }, texture_format_nomipmap)
    gl.switch_to_framebuffer(art, true)
    gl.ortho(false, true)
    gl.clear(float4_0)
    for(wdraws) d:
        let m = d.mat
        let pos = map(d.p) p: to_px(p)
        let cols = map(d.c) c: float4 { c.x, c.y, c.z, 1.0 }
        let mesh = gl.new_mesh("PNTC", pos, cols, d.n, d.uv, []::float2, map(pos.length) i: i)
        let t0 = wb_texture(m.tex)
        let t2 = if m.normal_enabled: wb_texture(m.normal_tex) else: nil
        if t0: gl.set_mesh_texture(mesh, 0, 0, t0)
        gl.set_mesh_texture(mesh, 0, 1, smap)
        if t2: gl.set_mesh_texture(mesh, 0, 2, t2)
        gl.set_shader("worldlit")
        gl.set_uniform("cam_x", cx)
        gl.set_uniform("cam_y", cy)
        gl.set_uniform("cam_z", cz)
        gl.set_uniform("vmap", float4 { px, lo.x, lo.y, 0.0 })
        gl.set_uniform("dmap", float2 { dbase, vz })
        gl.set_uniform("sun_dir", sun)
        gl.set_uniform("fill_dir", light_along(float3 { -20.0, -60.0, 0.0 }))
        gl.set_uniform("rim_dir", light_along(float3 { -15.0, -135.0, 0.0 }))
        gl.set_uniform("view_dir", cz)
        gl.set_uniform("lx", float4 { kx.x * lpx, kx.y * lpx, kx.z * lpx, -llo.x * lpx })
        gl.set_uniform("ly", float4 { -ky.x * lpx, -ky.y * lpx, -ky.z * lpx, -llo.y * lpx })
        gl.set_uniform("lz", float4 { -kz.x * zs, -kz.y * zs, -kz.z * zs, 0.9 + zlo * zs })
        gl.set_uniform("lsize", float2 { float(lw), float(lh) })
        gl.set_uniform("albedo", float4 { m.albedo.x, m.albedo.y, m.albedo.z, 1.0 })
        gl.set_uniform("uvmap", float4 { m.uv_scale.x, m.uv_scale.y, m.uv_scale.z, 0.0 })
        gl.set_uniform("uvmap2", float4 { m.uv_offset.x, m.uv_offset.y, m.uv_offset.z, 0.0 })
        gl.set_uniform("mat0", float4 { if not t0: 0.0 elif m.triplanar: 2.0 else: 1.0, m.triplanar_sharpness, m.roughness, m.metallic_specular })
        gl.set_uniform("mat1", float4 { m.metallic, if t2: 1.0 else: 0.0, m.normal_scale, if m.unshaded: 1.0 else: 0.0 })
        gl.set_uniform("pass", float4 { 0.0, if m.scissor: 1.0 else: 0.0, 0.0, 0.0 })
        gl.render_mesh(mesh)
    gl.switch_to_framebuffer(nil)
    let raw = gl.read_texture(art) or ""
    let sw, sh, sprite = pixelize(raw, w, h, WB_SS, "", false)
    let anchor = float2 { (0.0 - lo.x) * px, (0.0 - lo.y) * px } / float(WB_SS)
    return sprite, sw, sh, anchor

// world_draws' order (visible meshes, depth first): whether each is in `only`.
def akb_mark(n:MNode, only:[MNode], out:[bool]) -> void:
    if not n.visible: return
    if n.mesh and n.mat: out.push(exists(only) o: o == n)
    for(n.kids) k: akb_mark(k, only, out)
