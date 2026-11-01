// ------------------------------------------------------------------ voxel units (the `voxels` option: a trial)
// Every unit type drawn as one procedural voxel body (view/voxel.lobster) instead of composed parts: its race and
// kit read from its recipe, baked at the match start into an atlas of 8 facings standing, walking, attacking and
// working, drawn as whole-unit frames (collect_units). Wild animals and the dead aren't made yet.

let VX_MODES = [ "idle", "walk", "attack", "work" ]
let vx_frames = dictionary<string, int>(4096)   // "kind.mode.facing.step" -> frame
let VX_DRAW_K = 1.1 / ART_K   // world art px a voxel (a body unit is 1.1 world px: the composed units' size)

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
    let kind = if find_string(body, "rat") >= 0: vx_RAT elif find_string(body, "frog") >= 0: vx_FROG else: vx_HUMAN   // (no voxel bears yet)
    let skins = at(lib_palettes, "skins")
    let skin = rstr(r, "skin")
    var rc = kind
    if has(skins, skin):   // the race's own colours (palettes.json)
        let cs = gstrs(skins, skin)
        rc = vx_race { kind.kind, xyz(hex_col(hex_of(cs[0]))), xyz(hex_col(hex_of(cs[1]))), kind.size, kind.fur }
    let hr = vx_part(r, "hand_r")
    var right = ""
    var left = ""
    if vx_has(hr, [ "bow", "sling" ]): left = "bow"
    elif vx_has(hr, [ "spear", "pike", "lance", "javelin", "trident", "pilum" ]): right = "spear"
    elif vx_has(hr, [ "gladius" ]): right = "gladius"
    elif vx_has(hr, [ "sword", "blade", "sabre", "dagger" ]): right = "sword"
    elif hr != "": right = "axe"
    if left == "" and vx_has(vx_part(r, "hand_l"), [ "shield" ]): left = if vx_has(vx_part(r, "hand_l"), [ "scutum" ]): "scutum" else: "shield"
    let torso = vx_part(r, "torso")
    let armour = if vx_has(torso, [ "lorica" ]): "lorica" elif vx_has(torso, [ "bronze" ]): "bronze" elif vx_has(torso, [ "leather" ]): "leather" else: ""
    let mount = if find_string(body, "centaur") >= 0: "horse" elif not has(r, "mount"): "" elif rstr(at(r, "mount"), "creature") == "cat": "cat" else: "horse"
    return vx_unit_def { rstr(r, "name"), rc, right, left, vx_part(r, "head_gear") != "", torso != "", mount,
                         if vx_has(vx_part(r, "head_gear"), [ "galea" ]): "galea" else: "", armour }

// A look (the same race, kit and mount: most age upgrades share one) is baked into an atlas of its own, its cells
// cropped to what's drawn and packed in rows VX_ATLAS wide, and kept in the bake cache (a PNG and a manifest, as the
// composed parts are), keyed by the look and the voxel builder's source: the next start loads it, and any change to
// the builder bakes it again.
let VX_ATLAS = 2048
let VX_FORMATS = texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min
var vx_rows = []::[float4]   // the atlas being packed: its rows, VX_ATLAS wide
var vx_at = int2_0           // where the next cell goes
var vx_row_h = 0             // the tallest cell in the row
var vx_lines = []::string    // the look's manifest
var vx_frame0 = 0            // the look's first frame
let vx_looks = dictionary<string, int>(256)   // a look's key -> the type that baked it
let vx_shadow_of = dictionary<int, int>(4096)   // a unit's frame -> its ground shadow's frame
var vx_source = ""           // the builder's source's hash (the cache key's part that changes with the code)

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
def vx_load_look(k:int, stem:string) -> bool:
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
            vx_frames.set("{k}.{t[1]}", f0 + string_to_int(t[2]))
            vx_shadow_of.set(f0 + string_to_int(t[2]), f0 + string_to_int(t[3]))
    return true

// One type's frames: steps per mode and facing. Returns whether it baked (false: it took a look's frames).
def vx_bake_type(k:int) -> bool:
    let u = vx_def_of(k)
    let key = "{u.rc.kind} {u.rc.skin} {u.right} {u.left} {u.helm} {u.armour} {u.mount} {u.helm_kind} {u.armour_kind} {t_worker[k]}"
    let same = vx_looks.get(key, -1)
    if same >= 0:
        for(VX_MODES) mode: for(8) f: for(8) st:
            let fr = vx_frames.get("{same}.{mode}.{f}.{st}", -1)
            if fr >= 0: vx_frames.set("{k}.{mode}.{f}.{st}", fr)
        return false
    vx_looks.set(key, k)
    let stem = bake_cache_dir + "/vx_" + sha256_text("{vx_source}|{key}").substring(0, 20)
    if vx_load_look(k, stem): return false
    let worker = vx_unit_def { u.label, u.rc, "axe", "", u.helm, u.armour, u.mount, u.helm_kind, u.armour_kind }   // (work: chopping)
    vx_mat_cols[vx_mat_skin] = u.rc.skin
    vx_mat_cols[vx_mat_pale] = u.rc.pale
    vx_fur = u.rc.fur
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
                    vx_frames.set("{k}.{mode}.{f}.{st}", fr)
                    vx_shadow_of.set(fr, sf)
                    maps.push("m {mode}.{f}.{st} {fr - vx_frame0} {sf - vx_frame0}")
    vx_act = ""
    let h = vx_rows.length
    assert h <= 4096
    add_sheet(gl.create_texture(vx_rows, VX_FORMATS), float2 { float(VX_ATLAS), float(h) })
    if bake_cache_dir != "":   // (kept for the next start)
        let rgba = []::int
        for(vx_rows) row: for(row) c: for(4) ch: rgba.push(clamp(int(c[ch] * 255.0 + 0.5), 0, 255))
        write_file(stem + ".png", bmat_png(rgba, VX_ATLAS, h))
        write_file(stem + ".txt", "{VX_ATLAS} {h}\n" + concat_string(vx_lines, "\n") + "\n" + concat_string(maps, "\n") + "\n")
    vx_rows = []::[float4]
    return true

def vx_bake_types():
    let t0 = seconds_elapsed()
    var n = 0
    var baked = 0
    vx_source = sha256_text(read_file("view/voxel.lobster") or "")
    vx_mat_cols[vx_mat_team] = float3 { 0.85, 0.12, 0.85 }   // (the sprite shader's team key)
    for(t_slot.length) k:
        if t_animal[k] == 0:
            if vx_bake_type(k): baked++
            n++
    print "voxel units: {n} types, {baked} looks baked (the rest shared or from the cache) in {int((seconds_elapsed() - t0) * 1000.0)} ms"

// The frame for a unit's state (unit_state's names) facing d (dir_of's).
def vx_frame_for(k:int, state:string, d:int, n:int) -> int:
    let f = (d + 2) % 8   // (d: the screen direction it moves in, dir_of; facing 2 faces screen right)
    let mode = if state == "attack": "attack" elif state == "walk" or find_string(state, "carry") == 0: "walk" elif find_string(state, "work") == 0: "work" else: "idle"
    let st = if mode == "idle": 0 elif mode == "attack": min(n, 7) else: n % 8
    let fr = vx_frames.get("{k}.{mode}.{f}.{st}", -1)
    return if fr >= 0: fr else: vx_frames.get("{k}.idle.{f}.0", -1)

// A voxel unit's frame's shadow on the ground (drawn under every unit), or -1.
def vx_shadow_for(f:int) -> int: return vx_shadow_of.get(f, -1)
