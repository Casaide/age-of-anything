// ------------------------------------------------------------------ voxel units (the `voxels` option: a trial)
// Every unit type drawn as one procedural voxel body (view/voxel.lobster) instead of composed parts: its race and
// kit read from its recipe, baked at the match start into an atlas of 8 facings standing, walking, attacking and
// working, drawn as whole-unit frames (collect_units). Wild animals and the dead aren't made yet.

let VX_MODES = [ "idle", "walk", "attack", "work" ]
let vx_frames = dictionary<string, int>(4096)  // "kind.mode.facing.step" -> frame
let VX_DRAW_K = 1.1 / ART_K                    // world art px a voxel (a body unit is 1.1 world px: the composed units' size)

def vx_has(id:string, words:[string]) -> bool:
    for(words) w: if find_string(id, w) >= 0: return true
    return false

def vx_part(r:JV, slot:string) -> string:
    let parts = gobj(r, "parts")
    return if has(parts, slot): as_str(at(parts, slot)) else: ""

// A unit type as a voxel race and kit.
def vx_def_of(k:int) -> vx_unit_def:
    let r = su_type_recipe[k]
    let body = rstr(r, "body")
    let kind = if find_string(body, "rat") >= 0: vx_RAT elif find_string(body, "frog") >= 0: vx_FROG else: vx_HUMAN  // (no voxel bears yet)
    let skins = at(lib_palettes, "skins")
    let skin = rstr(r, "skin")
    var rc = kind
    if has(skins, skin):  // the race's own colours (palettes.json)
        let cs = gstrs(skins, skin)
        rc = vx_race { kind.kind, xyz(hex_col(hex_of(cs[0]))), xyz(hex_col(hex_of(cs[1]))), kind.size, kind.fur }
    let hr = vx_part(r, "hand_r")
    var right = ""
    var left = ""
    if vx_has(hr, [ "bow", "sling" ]): left = "bow"
    elif vx_has(hr, [ "pike" ]): right = "pike"
    elif vx_has(hr, [ "pilum" ]): right = "pilum"
    elif vx_has(hr, [ "spear", "lance", "javelin", "trident" ]): right = "spear"
    elif vx_has(hr, [ "club" ]): right = if vx_has(hr, [ "bone" ]): "bone_club" else: "club"
    elif vx_has(hr, [ "staff" ]): right = "staff"
    elif vx_has(hr, [ "gladius" ]): right = "gladius"
    elif vx_has(hr, [ "sword", "blade", "sabre", "dagger" ]): right = "sword"
    elif hr != "": right = "axe"
    if left == "" and vx_has(vx_part(r, "hand_l"), [ "shield" ]): left = if vx_has(vx_part(r, "hand_l"), [ "scutum" ]): "scutum" else: "shield"
    let torso = vx_part(r, "torso")
    let armour = if vx_has(torso, [ "lorica" ]): "lorica" elif vx_has(torso, [ "bronze" ]): "bronze" elif vx_has(torso, [ "leather" ]): "leather" else: ""
    let mount = if find_string(body, "centaur") >= 0: "horse" elif not has(r, "mount"): "" elif rstr(at(r, "mount"), "creature") == "cat": "cat" else: "horse"
    var coat = float3_0  // a horse's or pony's coat (palettes.json); the cat keeps its own
    if mount == "horse" and has(r, "mount") and has(skins, rstr(at(r, "mount"), "skin")): coat = xyz(hex_col(hex_of(gstrs(skins, rstr(at(r, "mount"), "skin"))[0])))
    return vx_unit_def { rstr(r, "name"), rc, right, left, vx_part(r, "head_gear") != "", torso != "", mount,
                         if vx_has(vx_part(r, "head_gear"), [ "galea" ]): "galea" else: "", armour,
                         if vx_has(vx_part(r, "back"), [ "quiver" ]): "quiver" else: "", coat }

// The walk steps by the ground covered: a cycle of 8 steps is a stride (the body moves its foot's reach twice each
// half cycle, the planted foot fixed), so its length is four times that reach. A body unit is about 1/62 of a tile
// along the ground (a tile is 96 x 48 iso px; a body unit 1.1 px).
let vx_cycle = dictionary<int, float>(256)    // type -> milli-tiles a walk cycle
let vx_walked = dictionary<int, float>(1024)  // unit id -> milli-tiles walked
let vx_last = dictionary<int, float2>(1024)   // unit id -> where it was last drawn

def vx_reach(u:vx_unit_def) -> float:  // how far a foot swings out from under the hip, body units (as the builders step)
    if u.mount == "cat": return 3.4 * vx_CAT_SIZE
    if u.mount == "horse": return 4.0
    return (if u.rc.kind == "rat": 5.5 elif u.rc.kind == "frog": 2.0 else: 4.6) * u.rc.size

// A look (the same race, kit and mount: most age upgrades share one) is baked into an atlas of its own, its cells
// cropped to what's drawn and packed in rows VX_ATLAS wide, and kept in the bake cache (a PNG and a manifest, as the
// composed parts are), keyed by the look and the voxel builder's source: the next start loads it, and any change to
// the builder bakes it again.
let VX_ATLAS = 2048
let VX_FORMATS = texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min
var vx_rows = []::[float4]                     // the atlas being packed: its rows, VX_ATLAS wide
var vx_at = int2_0                             // where the next cell goes
var vx_row_h = 0                               // the tallest cell in the row
var vx_lines = []::string                      // the look's manifest
var vx_frame0 = 0                              // the look's first frame
let vx_looks = dictionary<string, int>(256)    // a look's key -> the type that baked it
let vx_shadow_of = dictionary<int, int>(4096)  // a unit's frame -> its ground shadow's frame
var vx_source = ""                             // the builder's source's hash (the cache key's part that changes with the code)

// A cell just drawn (its box in a cell cw wide, the ground at anchor), packed: its frame.
def vx_pack_cell(cell:[float4], box:int4, cw:int, anchor:int2) -> int:
    let w = box.z - box.x + 1
    let h = box.w - box.y + 1
    if vx_at.x + w > VX_ATLAS:
        vx_at = int2 { 0, vx_at.y + vx_row_h }
        vx_row_h = 0
    while vx_rows.length < vx_at.y + h: vx_rows.push(map(VX_ATLAS): float4_0)
    for(h) y:
        let row = vx_rows[vx_at.y + y]
        let at = (box.y + y) * cw + box.x
        for(w) x: row[vx_at.x + x] = cell[at + x]
    let fr = Frame { sheet_tex.length, vx_at.x, vx_at.y, w, h, anchor.x - box.x, anchor.y - box.y, VX_DRAW_K }
    frames.push(fr)
    vx_lines.push("f {fr.x} {fr.y} {w} {h} {fr.ox} {fr.oy}")
    vx_at.x += w
    vx_row_h = max(vx_row_h, h)
    return frames.length - 1

// The look's frames for type k from the cache, if they're there.
def vx_load_look(k:int, v:int, stem:string) -> bool:
    let text = read_file(stem + ".txt")
    if not text: return false
    let rows = tokenize(text, "\n", "")
    let dims = tokenize(rows[0], " ", "")
    add_sheet_later(stem + ".png", float2 { string_to_float(dims[0]), string_to_float(dims[1]) }, VX_FORMATS)
    let f0 = frames.length
    for(rows) row:
        let t = tokenize(row, " ", "")
        if t.length and t[0] == "f":
            frames.push(Frame { sheet_tex.length - 1, string_to_int(t[1]), string_to_int(t[2]), string_to_int(t[3]), string_to_int(t[4]),
                                string_to_int(t[5]), string_to_int(t[6]), VX_DRAW_K })
        if t.length and t[0] == "m":
            vx_frames.set("{k}.{v}.{t[1]}", f0 + string_to_int(t[2]))
            vx_shadow_of.set(f0 + string_to_int(t[2]), f0 + string_to_int(t[3]))
    return true

let vx_nlooks = dictionary<int, int>(256)  // type -> how many looks it has (humans 3, the rest 1)

// One type's frames, in each of its looks: steps per mode and facing. Returns how many looks it baked (a type that
// looks like one baked before takes its frames; a look in the cache is loaded).
def vx_bake_type(k:int) -> int:
    let u = vx_def_of(k)
    vx_cycle.set(k, 4.0 * vx_reach(u) * 1000.0 / 62.0)
    let nlooks = if u.rc.kind == "human": vx_LOOKS else: 1
    vx_nlooks.set(k, nlooks)
    let key = "{u.rc.kind} {u.rc.skin} {u.right} {u.left} {u.helm} {u.armour} {u.mount} {u.helm_kind} {u.armour_kind} {u.back} {u.coat} {t_worker[k]}"
    let same = vx_looks.get(key, -1)
    if same >= 0:
        for(nlooks) v: for(VX_MODES) mode: for(8) f: for(8) st:
            let fr = vx_frames.get("{same}.{v}.{mode}.{f}.{st}", -1)
            if fr >= 0: vx_frames.set("{k}.{v}.{mode}.{f}.{st}", fr)
        return 0
    vx_looks.set(key, k)
    var baked = 0
    for(nlooks) v:
        let stem = bake_cache_dir + "/vx_" + sha256_text("{vx_source}|{key}|look {v}").substring(0, 20)
        if not vx_load_look(k, v, stem):
            vx_bake_look(k, u, v, stem)
            baked++
    return baked

def vx_bake_look(k:int, u:vx_unit_def, v:int, stem:string):
    let worker = vx_unit_def { u.label, u.rc, "axe", "", u.helm, u.armour, u.mount, u.helm_kind, u.armour_kind, u.back, u.coat }  // (work: chopping)
    vx_set_look(u.rc, v)
    vx_rows = []::[float4]
    vx_at = int2_0
    vx_row_h = 0
    vx_lines = []::string
    vx_frame0 = frames.length
    let maps = []::string
    for(VX_MODES) mode:
        if mode != "work" or t_worker[k] != 0:
            vx_act = if mode == "attack" or mode == "work": "attack" else: ""
            for(if mode == "idle": 1 else: 8) st:
                let g = vx_fill(vx_unit_prims(if mode == "work": worker else: u, float(st) * 45.0), u.rc.size)
                for(8) f:
                    let fr = vx_pack_cell(vx_cell(g, f), vx_box, vx_CELL.x, vx_ANCHOR)
                    let sf = vx_pack_cell(vx_ground_shadow(g, f), vx_sbox, vx_SCELL.x, vx_SANCHOR)
                    vx_frames.set("{k}.{v}.{mode}.{f}.{st}", fr)
                    vx_shadow_of.set(fr, sf)
                    maps.push("m {mode}.{f}.{st} {fr - vx_frame0} {sf - vx_frame0}")
    vx_act = ""
    vx_variant = 0
    let h = vx_rows.length
    assert h <= 4096
    add_sheet(gl.create_texture(vx_rows, VX_FORMATS), float2 { float(VX_ATLAS), float(h) })
    if bake_cache_dir != "":  // (kept for the next start)
        let rgba = []::int
        for(vx_rows) row: for(row) c: for(4) ch: rgba.push(clamp(int(c[ch] * 255.0 + 0.5), 0, 255))
        write_file(stem + ".png", bmat_png(rgba, VX_ATLAS, h))
        write_file(stem + ".txt", "{VX_ATLAS} {h}\n" + concat_string(vx_lines, "\n") + "\n" + concat_string(maps, "\n") + "\n")
    vx_rows = []::[float4]

def vx_bake_types():
    let t0 = seconds_elapsed()
    var n = 0
    var baked = 0
    vx_source = sha256_text(read_file("view/voxel.lobster") or "")
    vx_mat_cols[vx_mat_team] = float3 { 0.85, 0.12, 0.85 }  // (the sprite shader's team key)
    for(t_slot.length) k:
        if t_animal[k] == 0:
            baked += vx_bake_type(k)
            n++
    print "voxel units: {n} types, {baked} looks baked (the rest shared or from the cache) in {int((seconds_elapsed() - t0) * 1000.0)} ms"

def vx_walk_step(id:int, k:int, x:float, y:float) -> int:
    let at = float2 { x, y }
    let was = vx_last.get(id, at)
    vx_last.set(id, at)
    let walked = vx_walked.get(id, 0.0) + magnitude(at - was)
    vx_walked.set(id, walked)
    return int(walked / vx_cycle.get(k, 350.0) * 8.0) % 8

// The frame for unit id's state (unit_state's names) facing d (dir_of's), in its look (from its id: view only).
def vx_frame_for(id:int, k:int, state:string, d:int, n:int) -> int:
    let v = ((id * 2654435761) >> 13 & 1023) % vx_nlooks.get(k, 1)
    let f = (d + 2) % 8  // (d: the screen direction it moves in, dir_of; facing 2 faces screen right)
    let mode = if state == "attack": "attack" elif state == "walk" or find_string(state, "carry") == 0: "walk" elif find_string(state, "work") == 0: "work" else: "idle"
    let st = if mode == "idle": 0 elif mode == "attack": min(n, 7) else: n % 8
    let fr = vx_frames.get("{k}.{v}.{mode}.{f}.{st}", -1)
    return if fr >= 0: fr else: vx_frames.get("{k}.{v}.idle.{f}.0", -1)

// A voxel unit's frame's shadow on the ground (drawn under every unit), or -1.
def vx_shadow_for(f:int) -> int: return vx_shadow_of.get(f, -1)
