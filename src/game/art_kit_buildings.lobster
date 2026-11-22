// ------------------------------------------------------------------ the buildings baked in the game (src/view/art/art_kit.gd: buildings)
// Every look of every building of a culture, as ArtKit names it, baked as voxels (view/voxel_mesh.lobster, D-203)
// from the Lobster models (model/buildings, buildings2) in the team key (magenta) into the pack: the body
// ("arch:type<suffix>"), its four construction stages (":stage0".. ":stage3"), a walkway's near merlons (":front"),
// its broken-up stages (":ruin1".. ":ruin4", game/ruin.lobster), a gate's open look (":open", ":open:front") and its flanking towers that stand down the screen (":tower<side>",
// ":tower<side>:front"), a wall's eight arms (":arm<k>", ":arm<k>:front", Models.LINKS order) and its picture
// (":icon"), a vane (":vane", anchored on its pivot). Suffixes: "@<age>" an age look, "#<v>" a house variant
// turned or mirrored, "^z" "^d" "^a" a gate along sim y and the two diagonals. Fills `looks` and `bfx` (the
// chimney smoke, lantern and windows, as building_fx.gd computes them). The originals: _building_jobs,
// _building_job, _bake_building, _placed, _variant_look, front_split, _bake_front, _bake_gate_parts, _hold_back,
// (art_kit.gd).
// Needs (imported by the game before this file): game/pack, game/art_kit (keep_frame, ak_rebake), model/buildings,
// model/buildings2, model/build_mats, model/build_stages, view/voxel_mesh, gen/datalib, game/ruin.

let AKB_HOUSE_SCALE = 1.1
let AKB_ALONG = [ "", "^z", "^d", "^a" ]
let AKB_PICTURE_K = 0.4  // a building's picture alone (akb_picture) at this share of the bake's density
let AKB_SEEN = float3 { 1.0, 0.0, 1.0 }
let AKB_TEAM = float3 { 1.0, 0.0, 1.0 }  // PartShape.TEAM_KEY: the sprite shader recolours it
let AKB_NONE = float3 { -999999.0, -999999.0, -999999.0 }
var akb_data:JV? = nil
var akb_baked = 0

def akb_bdata() -> JV:
    let d = akb_data
    if d: return d
    let n = lib_data("buildings.json")
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
    for([ false, true ]) flip:
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
    let own = if model == "": building_spec(arch, type, AKB_TEAM) else: nil                                   // (an architecture with its own model of a mod's building, #125)
    let spec = own or building_spec(arch, model_type(gobj(akb_bdata(), "buildings"), type), AKB_TEAM, model)  // (else the model of the one it extends, #58)
    gate_span = 3.0
    assert spec
    var s = (if type == "house": AKB_HOUSE_SCALE else: 1.0) * akb_scale(arch, type)
    var look = BASIS_ID
    var turned = false
    let hash_at = find_string(suffix, "#")
    let v = if hash_at >= 0: string_to_int(suffix.substring(hash_at + 1, suffix.length - hash_at - 1)) else: 0
    if v > 0:
        look, turned = akb_variant_look(spec, "{arch}:{type}", v)
        s *= [ 1.0, 0.94, 1.05, 0.9 ][v % 4]
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
    spec.turn = akb_hold(spec.turn, b)
    spec.open = akb_hold(spec.open, b)
    for([ "smoke", "lantern", "banner_pivot", "vane_pivot" ]) k:
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

// ---- gate parts (ArtKit._bake_gate_parts)

// A gate's middle without its towers (its doors, or the open passage and the arch over it).
def akb_hide_towers(n:MNode):
    let towers = []::MNode
    akb_not_part(n, 0, 0, towers)
    for(towers) m: m.visible = false

def akb_keep_mid(name:string, n:MNode):
    akb_hide_towers(n)
    akb_keep(name, n, true)

// Each gate tower's middle on the screen from the gate's (art px) and its side: [x, y, side].
def akb_gate_centres(node:MNode, t:Xform, out:[float3]) -> void:
    let tk = tokenize(node.meta, " ", "")
    if tk.length >= 6 and tk[0] == "gate_part":
        let c = xf(t, float3 { string_to_float(tk[3]), string_to_float(tk[4]), string_to_float(tk[5]) })
        let sp = akb_project(c) * WB_ART
        out.push(float3 { sp.x, sp.y, float(string_to_int(tk[1])) })
    for(node.kids) k: akb_gate_centres(k, xmul(t, node_xform(k)), out)

// The meshes not of gate part `side`: hidden (shadow false) or gathered to cast shadows only (into `out`).
def akb_not_part(node:MNode, part:int, side:int, out:[MNode]) -> void:
    var p = part
    let tk = tokenize(node.meta, " ", "")
    if tk.length >= 2 and tk[0] == "gate_part": p = string_to_int(tk[1])
    if node.mesh and p != side: out.push(node)
    for(node.kids) k: akb_not_part(k, p, side, out)

// ---- baking

// One model baked into the pack as frame `name`, anchored on `pivot` (a model point; the origin by default).
// The building bake cache (as the parts', view/part_bake.lobster: bake_cache/, emptied when BAKE_VERSION changes):
// each look's frames as PNGs, and one record of its frames, its Look and its BFx. A match start bakes what's new.
class AkbFrame:
    name:string
    file:string
    w:int
    h:int
    ax:int
    ay:int

class AkbCached:
    frames:[AkbFrame]
    look:Look
    fx:BFx

var akb_cache_frames = []::AkbFrame
var akb_cache_stem = ""  // the look being baked ("" while not recording)

let AKB_VERSION = 5  // the game's own bakes of buildings, beside Creel's BAKE_VERSION (5: the mound as termite spires, #205; 4: mud built up in lifts; 3: thatch laid in courses, #197; 2: Steading's set in textured courses, #156; 1: the roof goes on last at sites, #155)
def akb_stem_in(dir:string, name:string) -> string: return dir + "/b" + sha256_text("{BAKE_VERSION}.{AKB_VERSION}|building|{name}|k {ART_K}|ruin {RUIN_LOOK}").substring(0, 20)
def akb_stem(name:string) -> string: return akb_stem_in(bake_cache_dir, name)

// A look from the shipped bakes or the cache, if it's there (its frames, Look and BFx in place): whether it was.
def akb_load_cached(name:string) -> bool:
    if bake_cache_dir == "": return false
    let shipped = if bake_shipped_dir != "": read_file(akb_stem_in(bake_shipped_dir, name) + ".bin", true) else: nil
    let data = shipped or read_file(akb_stem(name) + ".bin", true)
    if not data: return false
    let rec, err = flexbuffers_binary_to_value(typeof AkbCached, data)
    let c = rec
    if err or not c: return false
    for(c.frames) f:
        add_sheet_later(f.file, float2 { float(f.w), float(f.h) }, pack_formats)
        frame_named(f.name)
        frames.push(Frame { sheet_tex.length - 1, 0, 0, f.w, f.h, f.ax, f.ay, 1.0 / ART_K })
    looks.set(c.look.body, c.look)
    bfx.set(c.look.body, c.fx)
    return true

// A wall's pieces keep their ground shadow apart ("<frame>~shadow", drawn on the ground under every piece): in one
// sprite, a piece drawn over its neighbour painted its shadow on the neighbour's face (Dominic: "all the shadows
// bugged for the walls").
var akb_split_shadows = false
var akb_check_dump = ""                          // a folder: each failing look's picture saved there (vbcheck dump:<folder>), a look's frames (lookframes:)
let akb_src = dictionary<string, [string]>(256)  // a look's name -> what it's made from (arch, type, model, suffix)

def akb_keep(name:string, model:MNode, shadow:bool, pivot:float3 = float3_0, shadow_only:[MNode] = []):
    // (shadow_only: the rest of a gate, left out of a tower's frame: baked in, the whole shut gate was drawn in front of
    // the units in its archway, Dominic: "the unit is sitting behind the left side of the gate")
    for(shadow_only) m: m.visible = false
    let sprite, w, h, anchor = voxel_bake(model, shadow)  // (D-203: as voxels)
    for(shadow_only) m: m.visible = true
    let at = anchor + akb_project(pivot) * WB_ART
    if akb_split_shadows and shadow:
        let art, shade = vm_split_shadow(sprite, w, h)
        akb_keep_frame(name, art, w, h, at)
        akb_keep_frame(name + "~shadow", shade, w, h, at)
    else: akb_keep_frame(name, sprite, w, h, at)
    akb_baked++

def akb_keep_frame(name:string, sprite:string, w:int, h:int, at:float2):
    if akb_check_dump != "" and w > 0 and h > 0:  // (sheet: every frame of a look as a PNG)
        write_file("{akb_check_dump}/{tokenize(name, ":", "")[tokenize(name, ":", "").length - 1]}.png", png_bytes(map(sprite.length) i: sprite[i], w, h), 0, 1)
    keep_frame(name, sprite, w, h, at)
    bake_pulse()
    if akb_cache_stem != "" and w > 0 and h > 0:
        let file = "{akb_cache_stem}_{akb_cache_frames.length}.png"
        write_file(file, png_bytes(map(sprite.length) i: sprite[i], w, h))
        bake_pulse()
        akb_cache_frames.push(AkbFrame { name, file, w, h, int(at.x + 0.5), int(at.y + 0.5) })

// One look of a building, with its stages and extra parts, into the pack; its Look and BFx.
def akb_bake_look(arch:string, type:string, model:string, suffix:string):
    let name = "{arch}:{type}{suffix}"
    akb_src.set(name, [ arch, type, model, suffix ])  // (a wall's whole tiles are made from it later: akb_wall_tile)
    if not ak_rebake and akb_load_cached(name): return
    akb_cache_stem = if bake_cache_dir != "": akb_stem(name) else: ""
    akb_cache_frames = []
    let spec = akb_placed(arch, type, model, suffix)
    // where the chimney smokes, the lantern and windows glow (building_fx.gd)
    let lights = []::float2
    if akb_has(spec, "lantern"): lights.push(akb_project(akb_pt(spec, "lantern")))
    for(spec.lights) l: lights.push(akb_project(l))
    bfx.set(name, BFx { if akb_has(spec, "smoke"): akb_project(akb_pt(spec, "smoke")) else: float2_0, akb_has(spec, "smoke"), lights })
    let lk = Look { name, map(4) st: "{name}:stage{st}", "-" }
    let fronts = akb_front_split(spec.body, false)
    akb_split_shadows = spec.arms.length > 0  // (a wall's finished pieces; its stages draw whole)
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
        // each tower a frame of its own, sorted at its own footprint, and the gate without them, shut and open (drawn as
        // one, a unit beside a tower or in the archway was wholly in front of the gate or wholly behind it: Dominic)
        akb_split_shadows = true  // (their shadows on the ground, apart: as a wall's)
        let tower_at = []::float3
        akb_gate_centres(spec.body, node_xform(spec.body), tower_at)
        for(tower_at) c:
            let side = int(c.z)  // (akb_gate_centres: x, y on the screen, the side)
            let tw = akb_placed(arch, type, model, suffix)
            let hide = []::MNode
            akb_not_part(tw.body, 0, side, hide)
            for(hide) m: m.visible = false
            akb_keep("{name}:tower{side}", tw.body, true)
            lk.towers.push("{name}:tower{side}")
            lk.tower_dy.push(c.y / ART_K)
        let shut_mid = akb_placed(arch, type, model, suffix)
        akb_keep_mid(name + ":shut:mid", shut_mid.body)
        let open_mid = akb_placed(arch, type, model, suffix)
        let om = open_mid.open
        if om: akb_keep_mid(name + ":open:mid", om)
        let open_front = akb_placed(arch, type, model, suffix)
        let of = open_front.open
        if of:
            if akb_front_split(of, true) > 0:  // (its near parapets alone, the towers' left out: over a unit in the passage)
                akb_hide_towers(of)
                akb_keep(name + ":open:mid:front", of, false)
        akb_split_shadows = false
    if spec.arms.length:
        let with_front = []::int
        for(spec.arms) a, k:
            if akb_front_split(a, false) > 0: with_front.push(k)
        for(spec.arms) a, k: akb_keep("{name}:arm{k}", a, true)
        let ic = spec.icon
        if ic: akb_keep(name + ":icon", ic, true)
        // its post turned 45 degrees, for a tile on a diagonal run (joined only corner to corner): the square post's
        // corners stuck out of the run's face and its sides crossed it, a sawtooth of piers (Dominic)
        // (shrunk to sit inside its arms: a corner tile, one arm straight and one diagonal, has neither face's corner
        // sticking out)
        let turned = akb_placed(arch, type, model, suffix)
        let pivot = mnode()
        pivot.rot = float3 { 0.0, 45.0, 0.0 }
        pivot.scl = float3 { 0.71, 1.0, 0.71 }
        add_child(pivot, turned.body)
        akb_keep(name + ":diag", pivot, true)
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
    if spec.turn:  // a turning part (a mill's sails), a quarter turn in steps (4 sails look the same each quarter)
        for(TURN_FRAMES) k:
            bld_turn = float(k) * 90.0 / float(TURN_FRAMES)
            let tn = akb_placed(arch, type, model, suffix).turn
            if tn: akb_keep("{name}:turn{k}", tn, false)
        bld_turn = 0.0
        lk.turns = map(TURN_FRAMES) k: "{name}:turn{k}"
    akb_split_shadows = false
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
    if akb_cache_stem != "":
        let fx = bfx.get(name)
        if fx: write_file(akb_cache_stem + ".bin", flexbuffers_value_to_binary(AkbCached { akb_cache_frames, lk, fx }, 1000))
        akb_cache_stem = ""

// The building types in ArtKit's order: town centre and houses first, the menus, then the rest (not planned).
def akb_types() -> [string]:
    let d = akb_bdata()
    let types = [ "town_center", "house" ]
    let menu = gobj(d, "menu")
    for(append(gstrs(menu, "civilian"), gstrs(menu, "military"))) t:
        if not has_s(types, t): types.push(t)
    let b = gobj(d, "buildings")
    let rest = []::string
    for(b.keys) t:
        if not has_s(types, t) and gstr(at(b, t), "status", "") != "planned": rest.push(t)
    return filter(append(types, sorted_strs(rest))) t: has(b, t) and not akb_road_plan(t)  // (a mod can take out what the menus name)

// A road plan, or any plan laid a cell at a time (a field, #122), has no look: it's painted on the ground (game/roads, #68).
def akb_road_plan(type:string) -> bool:
    let o = gobj(gobj(akb_bdata(), "buildings"), type)
    return gstr(o, "road", "") != "" or gbool(o, "drag", false)

// Every look of a building in an architecture: [model, suffix] (the base, age looks, variants, a gate's ways).
def akb_looks_of(arch:string, type:string) -> [[string]]:
    let d = akb_bdata()
    let out = [ [ "", "" ] ]
    let by_age = gobj(gobj(gobj(d, "age_looks"), arch), type)
    for(by_age.keys) age: out.push([ as_str(at(by_age, age)), "@" + age ])
    let nv = gint(gobj(d, "variants"), type, 1)
    for(nv - 1) v: out.push([ "", "#{v + 1}" ])
    if gbool(at(gobj(d, "buildings"), type), "gate", false):
        for(AKB_ALONG.slice(1, -1)) sfx: out.push([ "", sfx ])
    return out

// Whether a building look has broken-up stages: not walls and gates, nor what has a near layer.
def akb_breaks(type:string, lk:Look) -> bool:
    return not lk.arms.length and (lk.front == "-" or lk.front == "") and not gbool(at(gobj(akb_bdata(), "buildings"), type), "gate", false)

// A building's base look as a picture (the lobby's tech tree, #430): from the shipped bakes or the cache when they have
// it, else its whole frame alone, not its stages and ruins (a match's start bakes the look, with its loader).
// (at AKB_PICTURE_K of the density: a page's frame is some 60 px, and a wonder at the whole was 3.5 s)
def akb_picture(arch:string, type:string):
    let name = "{arch}:{type}"
    if akb_road_plan(type) or looks.get(name) or frame_index(name + ":picture") >= 0 or akb_load_cached(name): return
    bmat_matte = true
    let px = WB_PX
    WB_PX *= AKB_PICTURE_K
    akb_keep(name + ":picture", akb_placed(arch, type, "", "").body, true)
    WB_PX = px

// Bake every look of every building of these architectures the pack lacks (all with ak_rebake). Frames baked.
def bake_buildings_for(archs:[string]) -> int:
    akb_baked = 0
    bmat_matte = true
    for(sorted_strs(archs)) arch, ai:
        if ai > 0 and sorted_strs(archs)[ai - 1] == arch: continue
        for(akb_types()) type:
            for(akb_looks_of(arch, type)) ml:
                bake_pulse()
                let name = "{arch}:{type}{ml[1]}"
                let lk = looks.get(name)
                let unbroken = lk and akb_breaks(type, lk) and frame_index(name + ":ruin1") < 0  // (a pack made before D-171)
                if not bake_quit and (ak_rebake or not lk or frame_index(name) < 0 or unbroken):
                    bake_breath()
                    akb_bake_look(arch, type, ml[0], ml[1])
    return akb_baked

// ---- the buildings' checks as voxels (`vbcheck`, milestone 24): every look of every building in every architecture
// baked as voxels (its whole look, not its stages): no specks (an island of a few pixels apart from the rest), its
// team colour showing (the sprite shader's key) where its model has some: a NOTE where it doesn't, the model's own
// doing (the same camera as the old bake). Prints a line an architecture, FAIL and NOTE lines, and
// returns how many failed.
def akb_specks(sprite:string, w:int, h:int) -> int:
    let seen = map(w * h): false
    var specks = 0
    for(w * h) p:
        if not seen[p] and sprite[p * 4 + 3] == 255:
            var n = 0
            let todo = [ p ]
            seen[p] = true
            while todo.length:
                let q = todo.pop()
                n++
                let x = q % w
                let y = q / w
                for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 } ]) o:
                    let xx = x + o.x
                    let yy = y + o.y
                    if xx >= 0 and yy >= 0 and xx < w and yy < h:
                        let r = yy * w + xx
                        if not seen[r] and sprite[r * 4 + 3] == 255:
                            seen[r] = true
                            todo.push(r)
            if n < 4: specks++
    return specks

def akb_team_px(sprite:string, w:int, h:int) -> int:
    var n = 0
    for(w * h) p:
        let r = sprite[p * 4]
        let g = sprite[p * 4 + 1]
        let b = sprite[p * 4 + 2]
        if sprite[p * 4 + 3] == 255 and r > 50 and b > 50 and abs(r - b) * 4 < r + b and g * 3 < min(r, b): n++  // (the key's hue, shaded)
    return n

def akb_check(archs:[string]) -> int:
    var failed = 0
    var hidden = 0  // (the model's own: a tree in front of a house's shutters, a gate's band facing away; for the art review)
    var looks_n = 0
    for(archs) arch:
        let t0 = seconds_elapsed()
        for(akb_types()) type:
            for(akb_looks_of(arch, type)) ml:
                let spec = akb_placed(arch, type, ml[0], ml[1])
                let sprite, w, h, _at = voxel_bake(spec.body, false)
                let specks = akb_specks(sprite, w, h)
                let team = akb_team_px(sprite, w, h)
                looks_n++
                let name = "{arch}:{type}{ml[1]}"
                if specks > 0:
                    print "FAIL {name}: {specks} specks (islands of under 4 pixels)"
                    failed++
                if not spec.arms.length and not spec.open:  // its standing broken-up stages hold up what they keep (#163)
                    for(RUIN_STANDING) k:
                        let broken = akb_placed(arch, type, ml[0], ml[1])
                        let whole = []::RuinMesh
                        ruin_meshes(broken.body, XF_ID, whole)
                        let seen = map(whole) mi: mi.node.visible
                        ruin_apply(broken.body, k + 1, hash_text(name))
                        let floating = ruin_floating(whole, seen, broken.body)
                        if floating > 0:
                            print "FAIL {name}:ruin{k + 1}: {floating} pieces left in the air over what fell"
                            failed++
                if team == 0:  // (its model's team colour, if it has any, showing: walls, farms, palisades have none)
                    let shell = vm_fill(spec.body, VM_PX / WB_PX)
                    let tv = (filter(shell.col) c: c.x > 0.5 and c.z > 0.5 and c.y < 0.3).length
                    if tv > 0:
                        print "NOTE {name}: its model\'s team colour ({tv} voxels) doesn\'t show from the game\'s view"
                        hidden++
                        if akb_check_dump != "": write_file("{akb_check_dump}/{arch}_{type}{ml[1]}.png", png_bytes(map(sprite.length) i: sprite[i], w, h), 0, 1)
        print "vbcheck {arch}: looks checked in {int(seconds_elapsed() - t0)} s"
    print "vbcheck: {looks_n} looks, {failed} failed, {hidden} with their team colour out of sight (NOTE lines)"
    return failed

// ---- a wall tile whole (Dominic: "the wall models are clearly overlapping and sticking into each other... they MUST
// end before the next model"): its post and the arms it has, one model baked as one picture, so a tile ends at its
// edge. Drawn piece by piece (a post and an arm a neighbour), the pieces of a diagonal run's tiles, all at one depth
// on the screen, overlapped in no fixed order, each with its own ends, lip and texture. Made the first time a tile's
// joins are drawn (one a frame, akb_wall_tick; a wall bakes in about 50 ms), kept in the bake cache.
let akb_tile_wanted = []::string  // "<look>@L<links>" to make
let akb_tile_asked = dictionary<string, bool>(256)

def akb_tile_name(look:string, links:int) -> string: return "{look}@L{links}"

// The frame of a wall tile with these joins, or -1 (then asked for).
def akb_wall_tile(look:string, links:int) -> int:
    let key = akb_tile_name(look, links)
    let f = frame_index(key)
    if f < 0 and not akb_tile_asked.get(key, false):
        akb_tile_asked.set(key, true)
        akb_tile_wanted.push(key)
    return f

def akb_wall_tick():
    if not akb_tile_wanted.length: return
    let key = akb_tile_wanted.pop()
    let at = find_string(key, "@L")
    let look = key.substring(0, at)
    let links = string_to_int(key.substring(at + 2, key.length - at - 2))
    let src = akb_src.get(look) or []::string
    if src.length < 4: return
    let stem = ak_stem(key)
    let data = if bake_cache_dir != "": read_file(stem + ".bin", true) else: nil
    if data:
        let rec, err = flexbuffers_binary_to_value(typeof [AkFrame], data)
        let fs = rec
        if not err and fs and ak_load_frames(fs): return
    let kept = []::AkFrame
    for([ false, true ]) front:  // (the tile, and its near merlons: drawn over what walks behind them)
        let spec = akb_placed(src[0], src[1], src[2], src[3])
        let tile = mnode()
        if (links & 0xAA) != 0:  // (a diagonal join: its post turned along the run; shrunk inside its arms where a straight
            let pivot = mnode()  // run meets it too, a corner: full size at a run's end, where it is the wall's end)
            pivot.rot = float3 { 0.0, 45.0, 0.0 }
            if (links & 0x55) != 0: pivot.scl = float3 { 0.71, 1.0, 0.71 }
            add_child(pivot, spec.body)
            add_child(tile, pivot)
        else: add_child(tile, spec.body)
        for(spec.arms) a, n: if (links >> n) & 1: add_child(tile, a)
        let fronts = akb_front_split(tile, front)
        if front and fronts == 0: break
        let sprite, w, h, anchor = voxel_bake(tile, not front)
        let name = key + (if front: ":front" else: "")
        if front: akb_keep_tile(stem, kept, name, sprite, w, h, anchor)
        else:
            let art, shade = vm_split_shadow(sprite, w, h)
            akb_keep_tile(stem, kept, name, art, w, h, anchor)
            akb_keep_tile(stem, kept, name + "~shadow", shade, w, h, anchor)
    if stem != "" and kept.length: write_file(stem + ".bin", flexbuffers_value_to_binary(kept, 1000))

def akb_keep_tile(stem:string, kept:[AkFrame], name:string, sprite:string, w:int, h:int, at:float2):
    keep_frame(name, sprite, w, h, at)
    if bake_cache_dir != "" and w > 0 and h > 0: kept.push(ak_cache_frame(stem, kept.length, name, sprite, w, h, at))
