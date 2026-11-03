// ------------------------------------------------------------------ voxel units
// Every unit type drawn as one procedural voxel body (view/voxel.lobster, from data/voxel/): its body, gear and mount
// read from its recipe, baked into atlases of 8 facings standing, walking, working, attacking and falling dead,
// drawn as whole-unit frames (collect_units). Engines with a crew (siege, the trade cart) are still composed.
//
// A look is what a line step looks like (its body, colours, kit and mount: most of a line's steps share one). The
// start bakes what each player fields in the age it starts in, standing and walking (and working, for workers), in
// their first look; the rest (attacks and falls, the other looks, the later ages' steps, the next age first) queue
// for play, baked a slice of a frame at a time. A step drawn before it's baked asks for it first and is drawn in the
// step before meanwhile. Each bake is kept in the bake cache (a PNG and a manifest), keyed by the look and the
// voxel builder's source and data: the next start loads it.

let VX_IDLE = 0
let VX_WALK = 1
let VX_WORK = 2
let VX_ATTACK = 3
let VX_DIE = 4
let VX_MODES = [ "idle", "walk", "work", "attack", "die" ]
let VX_STEPS = [ 1, 8, 8, 8, 6 ]  // steps in each mode (a fall's last step is lying)
let VX_DRAW_K = 1.1 / ART_K       // world art px a voxel (a body unit is 1.1 world px: the composed units' size)

// A look: a unit def, drawn the same by every type and step that has it.
class vx_lk:
    key:string
    u:vx_unit_def
    worker:bool
    cycle:float   // milli-tiles a walk cycle (the walk steps by the ground covered)
    planned:bool  // its bakes are queued (or loaded)

let vx_lks = []::vx_lk
let vx_lk_ids = dictionary<string, int>(256)
let vx_frames = dictionary<int, int>(16384)     // vx_fkey -> frame
let vx_shadow_of = dictionary<int, int>(16384)  // a unit's frame -> its ground shadow's frame
var vx_type_lks = []::[int]                     // type -> its line steps' looks (-1: composed)
var vx_cur = []::int                            // type -> the look it's drawn in now
var vx_source = ""                              // the builder's source's and data's hash (the cache key's code part)

def vx_fkey(lk:int, v:int, m:int, f:int, st:int) -> int: return (((lk * 4 + v) * 5 + m) * 8 + f) * 8 + st

// Is type k a voxel body now? (Not an engine with a crew.) Is it in every step of its line?
def vx_drawn(k:int) -> bool: return voxel_units and k < vx_cur.length and vx_cur[k] >= 0
def vx_always(k:int) -> bool: return voxel_units and k < vx_type_lks.length and (find(vx_type_lks[k]) lk: lk < 0) < 0

// A palette's colours (palettes.json): its first three, zero where it has none.
def vx_palette(id:string) -> float3, float3, float3:
    let skins = at(lib_palettes, "skins")
    if not has(skins, id): return float3_0, float3_0, float3_0
    let cs = gstrs(skins, id)
    def c(i:int) -> float3: return if i < cs.length: xyz(hex_col(hex_of(cs[i]))) else: float3_0
    return c(0), c(1), c(2)

// The voxel body for a body id (bodies/<id>.json without the "body."; an engine's, siege.<kind>.<style>, its kind's),
// or its creature's, or a human's.
def vx_body_for(body_id:string, creature:string) -> string:
    let id = if starts_with(body_id, "body."): body_id.substring(5, body_id.length - 5) else: body_id
    if vx_bodies.get(id): return id
    let dot = find_string_reverse(id, ".")
    if starts_with(id, "siege.") and dot > 6 and vx_bodies.get(id.substring(0, dot)): return id.substring(0, dot)
    return if vx_bodies.get(creature): creature else: "human"

// Has the voxel kit an engine (or war beast) for this recipe? (Until it has, the composed one is drawn.)
def vx_engine_made(r:JV) -> bool: return not has(r, "crew") or starts_with(vx_body_for(rstr(r, "body"), ""), "siege.")

// An engine's colours in its style (the body's `styles`, by the id's last part; else its first).
def vx_style_of(body:string, body_id:string) -> float3, float3, float3:
    let b = vx_body_of(body)
    let style = body_id.substring(body.length + 1, max(0, body_id.length - body.length - 1))
    var k = find(b.style_names) n: n == style
    if k < 0: k = 0
    return b.style_cols[k * 3], b.style_cols[k * 3 + 1], b.style_cols[k * 3 + 2]

// A recipe as a voxel body and gear: its body (bodies/<body id>.json), the race's colours, each part's gear by
// gear.json's rules, its mount (its mount body, in its own colours).
def vx_def_of(r:JV) -> vx_unit_def:
    let body = vx_body_for(rstr(r, "body"), gstr(r, "creature", ""))
    var skin, pale, mark = vx_palette(gstr(r, "skin", ""))
    var crew:vx_unit_def? = nil
    if has(r, "crew"):  // an engine or a war beast: its frame in its style, its crew in their own colours
        assert vx_body_of(body).style_names.length
        skin, pale, mark = vx_style_of(body, rstr(r, "body"))
        crew = vx_def_of(at(r, "crew"))
    let gear = []::string
    let parts = gobj(r, "parts")
    for(sorted_strs(parts.keys)) slot:
        let id = as_str(at(parts, slot))
        let g = vx_gear_for(id, ptags_of(id), slot)
        if g != "": gear.push(g)
    var mount = ""
    var fused = false
    var coat, mane, coat_mark = float3_0, float3_0, float3_0
    if has(r, "mount"):
        let mo = at(r, "mount")
        let mc = rstr(mo, "creature")
        let c = creature(mc)
        fused = gbool(mo, "fused", false)
        mount = vx_body_for(gstr(c, "mount_body", gstr(c, "body", "")), mc)
        coat, mane, coat_mark = vx_palette(rstr(mo, "skin"))
    return vx_unit_def { gstr(r, "name", ""), body, skin, pale, mark, gear, mount, fused, coat, mane, coat_mark, crew }

// The look key of a unit def (what it's drawn as), its crew's too.
def vx_key_of(u:vx_unit_def) -> string:
    let c = u.crew
    let ck = if c: " crew \{" + vx_key_of(c) + "\}" else: ""
    return "{u.body} {u.skin} {u.pale} {u.mark} {u.gear} {u.mount} {u.fused} {u.coat} {u.mane} {u.coat_mark}{ck}"

// How far a foot swings out from under the hip, body units (the body's, or its mount's).
def vx_reach(u:vx_unit_def) -> float:
    if u.mount != "": return vx_body_of(u.mount).reach * vx_body_of(u.mount).size / vx_size_of(u)
    return vx_body_of(u.body).reach

// The look a recipe is drawn in (made the first time it's asked for; not baked until planned).
def vx_look_for(r:JV) -> int:
    let u = vx_def_of(r)
    let worker = gstr(r, "role", "") == "worker"
    let key = vx_key_of(u) + " {worker}"
    let have = vx_lk_ids.get(key, -1)
    if have >= 0: return have
    // a cycle of 8 steps is a stride (the body moves its foot's reach twice each half cycle, the planted foot fixed),
    // so its length is four times that reach; a body unit is about 1/62 of a tile along the ground
    vx_lks.push(vx_lk { key, u, worker, 4.0 * vx_reach(u) * 1000.0 / 62.0, false })
    vx_lk_ids.set(key, vx_lks.length - 1)
    return vx_lks.length - 1

// ---- the bakes: a job is one look's poses in some modes, into an atlas of its own (its cells cropped to what's
// drawn, packed in rows VX_ATLAS wide), baked a pose at a time: filled (in slices), then drawn in 8 facings

let VX_ATLAS = 2048
let VX_FORMATS = texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min

class vx_job:
    lk:int
    v:int
    modes:[int]
    stem:string
    poses:[int2]  // (mode, step)
    at:int        // the pose being baked
    facing:int    // its next facing
    filling:vx_filling?
    shape:vx_shape?
    rows:[[float4]]
    pen:int2        // where the next cell goes
    row_h:int       // the tallest cell in the row
    lines:[string]  // the manifest: "f x y w h ox oy" a cell, "m mode facing step frame shadow" a pose's facing
    cells:int
    tex:resource<texture>?

var vx_queue = []::vx_job  // the bakes left for play, the next first
var vx_doing:vx_job? = nil

def vx_new_job(lk:int, v:int, modes:[int]) -> vx_job:
    let l = vx_lks[lk]
    let stem = bake_cache_dir + "/vx_" + sha256_text("{vx_source}|{l.key}|look {v}|modes {modes}").substring(0, 20)
    let poses = []::int2
    for(modes) m: for(VX_STEPS[m]) st: poses.push(int2 { m, st })
    return vx_job { lk, v, modes, stem, poses, 0, 0, nil, nil, []::[float4], int2_0, 0, []::string, 0, nil }

// A cell just drawn (its box in a cell cw wide, the ground at anchor), packed: its index among the job's cells.
def vx_pack_cell(j:vx_job, cell:[float4], box:int4, cw:int, anchor:int2) -> int:
    let w = box.z - box.x + 1
    let h = box.w - box.y + 1
    if j.pen.x + w > VX_ATLAS:
        j.pen = int2 { 0, j.pen.y + j.row_h }
        j.row_h = 0
    while j.rows.length < j.pen.y + h: j.rows.push(map(VX_ATLAS): float4_0)
    for(h) y:
        let row = j.rows[j.pen.y + y]
        let at = (box.y + y) * cw + box.x
        for(w) x: row[j.pen.x + x] = cell[at + x]
    j.lines.push("f {j.pen.x} {j.pen.y} {w} {h} {anchor.x - box.x} {anchor.y - box.y}")
    j.pen.x += w
    j.row_h = max(j.row_h, h)
    j.cells++
    return j.cells - 1

// A job's manifest made frames on the sheet just added (the last), for its look.
def vx_publish(lk:int, v:int, manifest:[string]):
    let f0 = frames.length
    var cells = 0
    for(manifest) row:
        let t = tokenize(row, " ", "")
        if t.length and t[0] == "f":
            frames.push(Frame { sheet_tex.length - 1, string_to_int(t[1]), string_to_int(t[2]), string_to_int(t[3]), string_to_int(t[4]),
                                string_to_int(t[5]), string_to_int(t[6]), VX_DRAW_K })
            cells++
    for(manifest) row:
        let t = tokenize(row, " ", "")
        if t.length and t[0] == "m":
            let fr = f0 + string_to_int(t[4])
            vx_frames.set(vx_fkey(lk, v, string_to_int(t[1]), string_to_int(t[2]), string_to_int(t[3])), fr)
            vx_shadow_of.set(fr, f0 + string_to_int(t[5]))

// The job's frames from the cache, if they're there.
def vx_load_job(j:vx_job) -> bool:
    let text = read_file(j.stem + ".txt")
    if not text: return false
    let rows = tokenize(text, "\n", "")
    let dims = tokenize(rows[0], " ", "")
    add_sheet_later(j.stem + ".png", float2 { string_to_float(dims[0]), string_to_float(dims[1]) }, VX_FORMATS)
    vx_publish(j.lk, j.v, rows)
    return true

// Bakes on until the clock passes `until`: true when the job is done (its frames published, and kept in the cache).
def vx_job_step(j:vx_job, until:float) -> bool:
    let l = vx_lks[j.lk]
    let u = l.u
    vx_set_look(u, j.v)  // (every slice: a figure baked between them sets its own colours)
    vx_pat_scale = vx_RES * vx_size_of(u)
    while seconds_elapsed() < until:
        let fl = j.filling
        let sh = j.shape
        if sh:
            let pose = j.poses[j.at]
            let fr = vx_pack_cell(j, vx_cell(sh, j.facing), vx_box, vx_CELL.x, vx_ANCHOR)
            let sf = vx_pack_cell(j, vx_ground_shadow(sh, j.facing), vx_sbox, vx_SCELL.x, vx_SANCHOR)
            j.lines.push("m {pose.x} {j.facing} {pose.y} {fr} {sf}")
            j.facing++
            if j.facing == 8:
                j.shape = nil
                j.at++
                if j.at == j.poses.length:
                    vx_finish(j)
                    return true
        elif fl:
            if vx_fill_more(fl, until):
                j.shape = vx_fill_end(fl)
                j.filling = nil
                j.facing = 0
        else:
            let pose = j.poses[j.at]
            let m = pose.x
            vx_act = if m == VX_ATTACK or m == VX_WORK: "attack" else: ""
            vx_stand = m != VX_WALK
            var wu = u
            if m == VX_WORK:  // (work: chopping; what it wears kept)
                let tools = [ "axe" ]
                for(u.gear) g: if vx_worn_gear(g): tools.push(g)
                wu = vx_unit_def { u.label, u.body, u.skin, u.pale, u.mark, tools, u.mount, u.fused, u.coat, u.mane, u.coat_mark, u.crew }
            var parts = vx_unit_prims(wu, if m == VX_DIE: 0.0 else: float(pose.y) * 45.0)
            if m == VX_DIE: parts = vx_fallen(parts, float(pose.y + 1) / float(VX_STEPS[VX_DIE]))
            vx_act = ""
            vx_stand = false
            j.filling = vx_fill_begin(parts, vx_size_of(u), vx_flies(u) and m != VX_DIE)
    return false

// A job done: its atlas made a sheet and its frames published; kept in the cache by vx_save (in play, a frame of its
// own: writing the PNG is most of a frame's time).
var vx_unsaved:vx_job? = nil

def vx_finish(j:vx_job):
    let h = j.rows.length
    assert h <= 4096
    let tex = gl.create_texture(j.rows, VX_FORMATS)
    add_sheet(tex, float2 { float(VX_ATLAS), float(h) })
    j.lines.insert(0, "{VX_ATLAS} {h}")
    vx_publish(j.lk, j.v, j.lines)
    j.tex = tex

def vx_save(j:vx_job):
    let tex = j.tex
    if bake_cache_dir != "" and tex:
        if not gl.save_texture(tex, j.stem + ".png", false):  // (the engine's writer; GLES has none: ours, slower)
            let rgba = []::int
            for(j.rows) row: for(row) c: for(4) ch: rgba.push(clamp(int(c[ch] * 255.0 + 0.5), 0, 255))
            write_file(j.stem + ".png", bmat_png(rgba, VX_ATLAS, j.rows.length))
        write_file(j.stem + ".txt", concat_string(j.lines, "\n") + "\n")
    j.rows = []::[float4]
    j.tex = nil

// ---- what to bake, and when

// The modes a look's first bake has (what its units do from the start), and the rest.
def vx_first_modes(lk:int) -> [int]: return if vx_lks[lk].worker: [ VX_IDLE, VX_WALK, VX_WORK ] else: [ VX_IDLE, VX_WALK ]
def vx_moving_modes(lk:int) -> [int]: return if vx_lks[lk].worker: [ VX_WALK, VX_WORK ] else: [ VX_WALK ]
def vx_later_modes(lk:int) -> [[int]]: return [ [ VX_ATTACK ], [ VX_DIE ] ]  // (a job a mode: small atlases, short saves)
def vx_all_modes(lk:int) -> [[int]]:
    let ms = [ [ VX_IDLE, VX_WALK ], [ VX_ATTACK ], [ VX_DIE ] ]
    if vx_lks[lk].worker: ms.insert(1, [ VX_WORK ])
    return ms

// A job loaded from the cache, or else queued (at the front, or the back).
def vx_queue_job(j:vx_job, front:bool):
    if vx_load_job(j): return
    if front: vx_queue.insert(0, j)
    else: vx_queue.push(j)

// A look wanted now (a figure on a page, a step aged into): standing first, at the front (one pose: it shows in a
// moment), then walking (and working) and the rest at the back.
def vx_plan(lk:int, front:bool):
    if vx_lks[lk].planned: return
    vx_lks[lk].planned = true
    vx_queue_job(vx_new_job(lk, 0, vx_moving_modes(lk)), front)
    vx_queue_job(vx_new_job(lk, 0, [ VX_IDLE ]), front)  // (in front of its walk)
    for(vx_later_modes(lk)) ms: vx_queue_job(vx_new_job(lk, 0, ms), false)
    for(vx_looks_of(vx_lks[lk].u) - 1) v: for(vx_all_modes(lk)) ms: vx_queue_job(vx_new_job(lk, v + 1, ms), false)

def vx_ready(lk:int) -> bool: return vx_frames.get(vx_fkey(lk, 0, VX_IDLE, 0, 0), -1) >= 0

// A look wanted now: its first bake to the front of the queue.
def vx_want(lk:int):
    if not vx_lks[lk].planned:
        vx_plan(lk, true)
        return
    let d = vx_doing
    if d and d.lk == lk and d.v == 0: return
    let i = find(vx_queue) j: j.lk == lk and vx_first_job(j)
    if i > 0:
        let j = vx_queue[i]
        vx_queue.remove(i)
        vx_queue.insert(0, j)

// Every type's looks, at the start (and again when a race changes mid-match): what each player fields in the age
// it's in, baked now in their first look (counted on the match loader); then queued: their attacks and falls,
// their other looks, and the later ages' steps, the next age first.
// The data (the game's and each active mod's data/voxel/) and the cache key's code part, once.
def vx_init():
    if vx_source != "": return
    let dirs = [ "../data/voxel" ]
    for(mods_active) m: dirs.push(m.dir + "/data/voxel")  // (a mod's own, in its data/)
    vx_load(dirs)
    vx_source = sha256_text((read_file("view/voxel.lobster") or "") + vx_data_text())
    vx_mat_cols[vx_mat_team] = float3 { 0.85, 0.12, 0.85 }  // (the sprite shader's team key)

// A look's first bakes (standing, walking, working) taken out of the queue (and the one being baked), to be finished
// now.
def vx_first_job(j:vx_job) -> bool: return j.v == 0 and (j.modes[0] == VX_IDLE or j.modes[0] == VX_WALK)
def vx_take_first(lk:int, out:[vx_job]):
    let d = vx_doing
    if d and d.lk == lk and vx_first_job(d):
        vx_doing = nil
        out.push(d)
    for(filter(vx_queue) j: j.lk == lk and vx_first_job(j)) j: out.push(j)
    vx_queue = filter(vx_queue) j: not (j.lk == lk and vx_first_job(j))

def vx_start():
    let t0 = seconds_elapsed()
    vx_init()
    let by_age = []::[int]  // looks by how many ages ahead they are first fielded
    vx_type_lks = []::[int]
    vx_cur = []::int
    for(t_slot.length) k:
        let line = su_type_line[k]
        let lks = []::int
        for(max(1, line.length)) s:
            let r = if s < line.length: at(line[s], "recipe") else: su_type_recipe[k]
            if not vx_engine_made(r):
                lks.push(-1)
                continue
            let lk = vx_look_for(r)
            lks.push(lk)
            let age = if line.length: as_int(at(line[s], "age")) else: t_age[k]
            let ahead = max(0, age - (if t_player[k] >= 0 and t_player[k] < ages.length: ages[t_player[k]] else: 1))
            while by_age.length <= ahead: by_age.push([])
            if (find(by_age[ahead]) x: x == lk) < 0: by_age[ahead].push(lk)
        vx_type_lks.push(lks)
        vx_cur.push(lks[0])
    let now = []::vx_job
    for(by_age) lks, a:
        for(lks) lk:
            if a == 0 and vx_lks[lk].planned: vx_take_first(lk, now)  // (asked for on a lobby page, not all baked yet)
            if not vx_lks[lk].planned:
                vx_lks[lk].planned = true
                let first = vx_new_job(lk, 0, vx_first_modes(lk))
                if not vx_load_job(first): (if a == 0: now else: vx_queue).push(first)
                for(vx_later_modes(lk)) ms: vx_queue_job(vx_new_job(lk, 0, ms), false)
        for(lks) lk: for(vx_looks_of(vx_lks[lk].u) - 1) v: for(vx_all_modes(lk)) ms: vx_queue_job(vx_new_job(lk, v + 1, ms), false)
    bake_total = now.length
    bake_count = 0
    for(now) j:
        while not vx_job_step(j, seconds_elapsed() + 0.2): bake_breath()
        vx_save(j)
        bake_count++
        bake_breath()
    bake_total = 0
    if perf_for > 0.0:  // (perf: measures the drawing, not a new race's one-off bakes: all of them now)
        for(vx_queue) j:
            while not vx_job_step(j, seconds_elapsed() + 0.2): bake_breath()
            vx_save(j)
        vx_queue = []::vx_job
    vx_refresh()
    print "voxel units: {vx_lks.length} looks, {now.length} baked now, {vx_queue.length} queued, in {int((seconds_elapsed() - t0) * 1000.0)} ms"

// Each type's look as drawn now: its line step's (type_step), once that's baked (asked for first until then).
var vx_type_gen = -1
def vx_refresh():
    if vx_type_gen != type_gen and vx_type_gen >= 0:  // (a race changed mid-match: its new steps' looks)
        for(t_slot.length) k:
            let line = su_type_line[k]
            for(max(1, line.length)) s:
                let r = if s < line.length: at(line[s], "recipe") else: su_type_recipe[k]
                if s < vx_type_lks[k].length: vx_type_lks[k][s] = if vx_engine_made(r): vx_look_for(r) else: -1
    vx_type_gen = type_gen
    for(vx_cur) cur, k:
        let lks = vx_type_lks[k]
        let lk = lks[min(type_step(k), lks.length - 1)]
        if lk < 0: vx_cur[k] = -1
        elif lk != cur:
            if vx_ready(lk) or cur < 0: vx_cur[k] = lk
            else: vx_want(lk)

// In play: each type's look, then the queue baked on for up to `budget` seconds of this frame.
def vx_tick(budget:float):
    if not voxel_units: return
    vx_refresh()
    vx_bake_tick(budget)

// The queue baked on for up to `budget` seconds of this frame (in play, and on the lobby's pages).
def vx_bake_tick(budget:float):
    let us = vx_unsaved
    if us:
        vx_save(us)
        vx_unsaved = nil
        return
    let until = seconds_elapsed() + budget
    while seconds_elapsed() < until:
        var d = vx_doing
        if not d:
            if not vx_queue.length: return
            d = vx_queue[0]
            vx_queue.remove(0)
            vx_doing = d
        if vx_job_step(d, until):
            vx_doing = nil
            vx_unsaved = d
            return

// ---- drawing

let vx_walked = dictionary<int, float>(1024)  // unit id -> milli-tiles walked
let vx_last = dictionary<int, float2>(1024)   // unit id -> where it was last drawn

def vx_walk_step(id:int, k:int, x:float, y:float) -> int:
    let at = float2 { x, y }
    let was = vx_last.get(id, at)
    vx_last.set(id, at)
    let walked = vx_walked.get(id, 0.0) + magnitude(at - was)
    vx_walked.set(id, walked)
    return int(walked / vx_lks[vx_cur[k]].cycle * 8.0) % 8

// A unit's look (from its id: view only).
def vx_look_v(id:int, lk:int) -> int: return ((id * 2654435761) >> 13 & 1023) % vx_looks_of(vx_lks[lk].u)

// A look's frame in mode m, facing f, at step st, in look v; its first look's (or standing) until that's baked.
def vx_frame(lk:int, v:int, m:int, f:int, st:int) -> int:
    var fr = vx_frames.get(vx_fkey(lk, v, m, f, st), -1)
    if fr < 0: fr = vx_frames.get(vx_fkey(lk, 0, m, f, st), -1)
    if fr < 0 and m != VX_DIE: fr = vx_frames.get(vx_fkey(lk, v, VX_IDLE, f, 0), -1)
    if fr < 0 and m != VX_DIE: fr = vx_frames.get(vx_fkey(lk, 0, VX_IDLE, f, 0), -1)
    return fr

// The frame for unit id of type k in state (unit_state's names), moving or facing screen direction d (dir_of's).
def vx_frame_for(id:int, k:int, state:string, d:int, n:int) -> int:
    let lk = vx_cur[k]
    let f = (d + 2) % 8  // (facing 2 faces screen right)
    let m = if state == "attack": VX_ATTACK elif state == "walk" or find_string(state, "carry") == 0: VX_WALK elif find_string(state, "work") == 0: VX_WORK else: VX_IDLE
    let st = if m == VX_IDLE: 0 elif m == VX_ATTACK: min(n, 7) else: n % 8
    return vx_frame(lk, vx_look_v(id, lk), m, f, st)

// A dead unit's frame, t seconds after it fell: its fall, then lying.
def vx_dead_frame(id:int, k:int, d:int, t:float) -> int:
    let lk = vx_cur[k]
    return vx_frame(lk, vx_look_v(id, lk), VX_DIE, (d + 2) % 8, min(int(t * 10.0), VX_STEPS[VX_DIE] - 1))

// A voxel unit's frame's shadow on the ground (drawn under every unit), or -1.
def vx_shadow_for(f:int) -> int: return vx_shadow_of.get(f, -1)

// A recipe's figure (the panel's portraits, the tech tree's), standing facing down and to the right: its frame
// once baked (asked for first until then), or -1.
def vx_figure(recipe:JV) -> int: return vx_figure_facing(recipe, float2_1)

// The same, facing screen direction `to` (a canvas vector: the lobby's armies face each other).
def vx_figure_facing(recipe:JV, to:float2) -> int:
    vx_init()
    if not vx_engine_made(recipe): return -1
    let lk = vx_look_for(recipe)
    if not vx_ready(lk):
        vx_want(lk)
        return -1
    return vx_frame(lk, 0, VX_IDLE, (dir_of(to) + 2) % 8, 0)
