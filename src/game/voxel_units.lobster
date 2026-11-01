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
    elif vx_has(hr, [ "spear", "pike", "lance", "javelin", "trident" ]): right = "spear"
    elif vx_has(hr, [ "sword", "blade", "gladius", "sabre", "dagger" ]): right = "sword"
    elif hr != "": right = "axe"
    if left == "" and vx_has(vx_part(r, "hand_l"), [ "shield" ]): left = "shield"
    let mount = if find_string(body, "centaur") >= 0: "horse" elif not has(r, "mount"): "" elif rstr(at(r, "mount"), "creature") == "cat": "cat" else: "horse"
    return vx_unit_def { rstr(r, "name"), rc, right, left, vx_part(r, "head_gear") != "", vx_part(r, "torso") != "", mount }

// Baked cells are cropped to what's drawn and packed in rows into shared atlases (VX_ATLAS wide); a type that looks
// like one already baked (the same race, kit and mount: most age upgrades) takes its frames.
let VX_ATLAS = 2048
var vx_pix = []::float4      // the atlas being packed, VX_ATLAS wide
var vx_at = int2_0           // where the next cell goes
var vx_row_h = 0             // the tallest cell in the row
let vx_looks = dictionary<string, int>(256)   // a look's key -> the type that baked it

def vx_flush_atlas():
    if vx_pix.length:
        let h = vx_pix.length / VX_ATLAS
        let rows = map(h) y: map(VX_ATLAS) x: vx_pix[y * VX_ATLAS + x]
        add_sheet(gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min), float2 { float(VX_ATLAS), float(h) })
    vx_pix = []::float4
    vx_at = int2_0
    vx_row_h = 0

let vx_shadow_of = dictionary<int, int>(4096)   // a unit's frame -> its ground shadow's frame

// A cell just drawn (its box in a cell cw wide, the ground at anchor), packed: its frame.
def vx_pack_cell(cell:[float4], box:int4, cw:int, anchor:int2) -> int:
    let w = box.z - box.x + 1
    let h = box.w - box.y + 1
    if vx_at.x + w > VX_ATLAS:
        vx_at = int2 { 0, vx_at.y + vx_row_h }
        vx_row_h = 0
    if vx_at.y + h > 4096: vx_flush_atlas()
    while vx_pix.length < (vx_at.y + h) * VX_ATLAS: vx_pix.push(float4_0)
    for(h) y: for(w) x: vx_pix[(vx_at.y + y) * VX_ATLAS + vx_at.x + x] = cell[(box.y + y) * cw + box.x + x]
    frames.push(Frame { sheet_tex.length, vx_at.x, vx_at.y, w, h, anchor.x - box.x, anchor.y - box.y, VX_DRAW_K })
    vx_at.x += w
    vx_row_h = max(vx_row_h, h)
    return frames.length - 1

// One type's frames: steps per mode and facing. Returns whether it baked (false: it took a look's frames).
def vx_bake_type(k:int) -> bool:
    let u = vx_def_of(k)
    let key = "{u.rc.kind} {u.rc.skin} {u.right} {u.left} {u.helm} {u.armour} {u.mount} {t_worker[k]}"
    let same = vx_looks.get(key, -1)
    if same >= 0:
        for(VX_MODES) mode: for(8) f: for(8) st:
            let fr = vx_frames.get("{same}.{mode}.{f}.{st}", -1)
            if fr >= 0: vx_frames.set("{k}.{mode}.{f}.{st}", fr)
        return false
    vx_looks.set(key, k)
    let worker = vx_unit_def { u.label, u.rc, "axe", "", u.helm, u.armour, u.mount }   // (work: chopping)
    vx_mat_cols[vx_mat_skin] = u.rc.skin
    vx_mat_cols[vx_mat_pale] = u.rc.pale
    vx_fur = u.rc.fur
    for(VX_MODES) mode:
        if mode != "work" or t_worker[k] != 0:
            vx_act = if mode == "attack" or mode == "work": "attack" else: ""
            for(if mode == "idle": 1 else: 8) st:
                let g = vx_fill(vx_unit_prims(if mode == "work": worker else: u, float(st) * 45.0), u.rc.size)
                for(8) f:
                    let fr = vx_pack_cell(vx_cell(g, f), vx_box, vx_CELL.x, vx_ANCHOR)
                    vx_frames.set("{k}.{mode}.{f}.{st}", fr)
                    vx_shadow_of.set(fr, vx_pack_cell(vx_ground_shadow(g, f), vx_sbox, vx_SCELL.x, vx_SANCHOR))
    vx_act = ""
    return true

def vx_bake_types():
    let t0 = seconds_elapsed()
    var n = 0
    var baked = 0
    vx_mat_cols[vx_mat_team] = float3 { 0.85, 0.12, 0.85 }   // (the sprite shader's team key)
    for(t_slot.length) k:
        if t_animal[k] == 0:
            if vx_bake_type(k): baked++
            n++
    vx_flush_atlas()
    print "voxel units: {n} types ({baked} looks) baked in {int((seconds_elapsed() - t0) * 1000.0)} ms"

// The frame for a unit's state (unit_state's names) facing d (dir_of's).
def vx_frame_for(k:int, state:string, d:int, n:int) -> int:
    let f = (d + 3) % 8
    let mode = if state == "attack": "attack" elif state == "walk" or find_string(state, "carry") == 0: "walk" elif find_string(state, "work") == 0: "work" else: "idle"
    let st = if mode == "idle": 0 elif mode == "attack": min(n, 7) else: n % 8
    let fr = vx_frames.get("{k}.{mode}.{f}.{st}", -1)
    return if fr >= 0: fr else: vx_frames.get("{k}.idle.{f}.0", -1)

// A voxel unit's frame's shadow on the ground (drawn under every unit), or -1.
def vx_shadow_for(f:int) -> int: return vx_shadow_of.get(f, -1)
