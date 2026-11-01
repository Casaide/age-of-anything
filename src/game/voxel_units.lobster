// ------------------------------------------------------------------ voxel units (the `voxels` option: a trial)
// Every unit type drawn as one procedural voxel body (view/voxel.lobster) instead of composed parts: its race and
// kit read from its recipe, baked at the match start into an atlas of 8 facings standing, walking, attacking and
// working, drawn as whole-unit frames (collect_units). Wild animals and the dead aren't made yet.

let VX_MODES = [ "idle", "walk", "attack", "work" ]
let vx_frames = dictionary<string, int>(4096)   // "kind.mode.facing.step" -> frame
let VX_DRAW_K = 2.2 / (ART_K * vx_RES)   // world art px a voxel (2.2 body units: the composed units' size)

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
    let rc = if find_string(body, "rat") >= 0: vx_RAT elif find_string(body, "frog") >= 0: vx_FROG elif find_string(body, "bear") >= 0: vx_BEAR else: vx_HUMAN
    let hr = vx_part(r, "hand_r")
    var right = ""
    var left = ""
    if vx_has(hr, [ "bow", "sling" ]): left = "bow"
    elif vx_has(hr, [ "spear", "pike", "lance", "javelin", "trident" ]): right = "spear"
    elif vx_has(hr, [ "sword", "blade", "gladius", "sabre", "dagger" ]): right = "sword"
    elif hr != "": right = "axe"
    if left == "" and vx_has(vx_part(r, "hand_l"), [ "shield" ]): left = "shield"
    let mount = if find_string(body, "centaur") >= 0: "centaur" elif not has(r, "mount"): "" elif rstr(at(r, "mount"), "creature") == "cat": "cat" else: "horse"
    return vx_unit_def { rstr(r, "name"), rc, right, left, vx_part(r, "head_gear") != "", vx_part(r, "torso") != "", mount }

// One type's atlas: a row of steps per mode and facing.
def vx_bake_type(k:int):
    let u = vx_def_of(k)
    let worker = vx_unit_def { u.label, u.rc, "axe", "", u.helm, u.armour, u.mount }   // (work: chopping)
    vx_mat_cols[vx_mat_skin] = u.rc.skin
    vx_mat_cols[vx_mat_pale] = u.rc.pale
    let cw = vx_CELL.x
    let ch = vx_CELL.y
    let w = cw * 8
    let h = ch * 8 * VX_MODES.length
    let pix = map(w * h): float4_0
    let sheet = sheet_tex.length
    for(VX_MODES) mode, mi:
        if mode != "work" or t_worker[k] != 0:
            vx_act = if mode == "attack" or mode == "work": "attack" else: ""
            for(if mode == "idle": 1 else: 8) st:
                let g = vx_fill(vx_unit_prims(if mode == "work": worker else: u, float(st) * 45.0), u.rc.size)
                for(8) f:
                    let cell = vx_cell(g, f)
                    let x0 = st * cw
                    let y0 = (mi * 8 + f) * ch
                    for(ch) y: for(cw) x: pix[(y0 + y) * w + x0 + x] = cell[y * cw + x]
                    vx_frames.set("{k}.{mode}.{f}.{st}", frames.length)
                    frames.push(Frame { sheet, x0, y0, cw, ch, vx_ANCHOR.x, vx_ANCHOR.y, VX_DRAW_K })
    vx_act = ""
    let rows = map(h) y: map(w) x: pix[y * w + x]
    add_sheet(gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min), float2 { float(w), float(h) })

def vx_bake_types():
    let t0 = seconds_elapsed()
    var n = 0
    vx_mat_cols[vx_mat_team] = float3 { 0.85, 0.12, 0.85 }   // (the sprite shader's team key)
    for(t_slot.length) k:
        if t_animal[k] == 0:
            vx_bake_type(k)
            n++
    print "voxel units: {n} types baked in {int((seconds_elapsed() - t0) * 1000.0)} ms"

// The frame for a unit's state (unit_state's names) facing d (dir_of's).
def vx_frame_for(k:int, state:string, d:int, n:int) -> int:
    let f = (d + 2) % 8
    let mode = if state == "attack": "attack" elif state == "walk" or find_string(state, "carry") == 0: "walk" elif find_string(state, "work") == 0: "work" else: "idle"
    let st = if mode == "idle": 0 elif mode == "attack": min(n, 7) else: n % 8
    let fr = vx_frames.get("{k}.{mode}.{f}.{st}", -1)
    return if fr >= 0: fr else: vx_frames.get("{k}.idle.{f}.0", -1)
