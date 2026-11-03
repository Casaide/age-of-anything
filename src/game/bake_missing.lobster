// ------------------------------------------------------------------ parts baked in the game (steps 6c, 6d; view/baker.lobster)
// Before a match, every part each unit type wears is looked up in the art pack in all eight facings; what
// isn't there (a new race's colours, a mod's parts, a new part) is baked here and joins the pack: its model
// built in Lobster (model/), baked with its rigs as the Godot part baker does (view/part_bake.lobster); a
// part with no model here comes from the mesh library (`meshes:<dir>`, mesh_export.gd library) if there is one.

let meshes_cache = dictionary<string, [BakeTri]>(64)

// The part nodes under a view (its whole tree).
def part_nodes(n:VNode, out:[VNode]) -> void:
    if n.part and n.part_id != "": out.push(n)
    for(n.kids) k: part_nodes(k, out)

// A bake key's colours back (bake_key writes "id:chan=hex,..."): the Colours the baker needs.
def key_colours(key:string) -> Colours:
    let d = dictionary<string, string>(15)
    let colon = find_string(key, ":")
    if colon >= 0:
        for(tokenize(key.substring(colon + 1, key.length - colon - 1), ",", " ")) kv:
            let eq = find_string(kv, "=")
            if eq > 0: d.set(kv.substring(0, eq), kv.substring(eq + 1, kv.length - eq - 1))
    // the palette's fixed materials for what the key doesn't name
    let mats = get(lib_palettes, "materials") or jobj()
    for(mats.a) v, n:
        let name = mats.keys[n]
        if not d.get(name): d.set(name, hex_of(as_str(v)))
    return Colours { d, float3 { 1.0, 0.0, 1.0 } }

// One facing of one part into the pack: a frame on its own sheet, its bake for the composer.
def add_baked(full:string, tris:[BakeTri], facing:int, cols:Colours):
    bake_colours = cols
    let sprite, w, h, origin = bake_facing(tris, facing)
    let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                            float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
    add_sheet(gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap), float2 { float(w), float(h) }, texture_format_clamp | texture_format_nomipmap)
    frame_at.set("p:" + full, frames.length)
    frames.push(Frame { sheet_tex.length - 1, 0, 0, w, h, int(origin.x + 0.5), int(origin.y + 0.5), 1.0 })
    bakes.set(full, Bake { origin.x, origin.y, BAKE_ART })
    baked_here++

// Every unit type's parts, every facing, that the pack lacks, standing and in its walk (its legs' and body's steps):
// those its player can field in the age it starts in baked now, counted on the loader; the later ages' steps
// (two thirds of the parts) queued for play to bake a facing a frame, the next age's first. Returns how many
// facings were baked now.
let WALK_SAMPLES = 16  // walk phases looked at (the most steps a leg or body has is 8)

def bake_missing_parts() -> int:
    baked_here = 0
    let todo = []::Wanted
    let later = []::[Wanted]  // by age
    let holds = []::Wanted    // the workers' work poses (raise, thrust, reach): baked first in play
    let seen = dictionary<string, bool>(1024)
    for(t_slot.length) k:
        let line = su_type_line[k]
        for(max(1, line.length)) step:
            let age = if line.length: as_int(at(line[step], "age")) else: t_age[k]
            let ahead = age - (if t_player[k] < ages.length: ages[t_player[k]] else: 1)  // (nature's animals: age 1)
            while later.length < ahead: later.push([])
            let v = make_view(k, t_player[k], step)
            for(WALK_SAMPLES + 1) w:
                if w > 0:  // (walking: the legs' and body's steps; uv_process picks them by phase)
                    v.walking = true
                    v.phase = float(w - 1) * TAU / float(WALK_SAMPLES)
                    uv_process(v, 0.0)
                let parts = []::VNode
                part_nodes(v.node, parts)
                for(parts) n:
                    let key = bake_key(n.part_id, n.pshapes, n.cols, n.size)
                    let cols = n.cols
                    if cols and not bakes.get(key) and not seen.get(key, false):
                        seen.set(key, true)
                        (if ahead > 0: later[ahead - 1] else: todo).push(Wanted { n.part_id, key, cols })
            if t_worker[k] != 0 and v.body_nodes.length:
                let b0 = v.body_nodes[0]
                let cols = b0.cols
                if cols:
                    for(WORK_HOLDS) h:
                        let id = rstr(v.recipe, "body") + "@" + h
                        let key = bake_key(id, b0.pshapes, cols, b0.size)
                        if not bakes.get(key + facing_suffix(1)) and not seen.get(key, false):
                            seen.set(key, true)
                            holds.push(Wanted { id, key, cols })
            bake_corpse_frames(v.recipe)  // (a body that lies down in 3D when it dies: its fall's frames)
            remove_child(view_stage, v.node)
            free_tree(v.node)
    bake_total = todo.length
    bake_count = 0
    for(todo) t:
        if not bakes.get(t.key) and not bake_model_part(t.id, t.key, t.cols) and mesh_dir != "" and not has_char(t.id, '~'):
            for(8) f:
                let full = t.key + facing_suffix(f)
                if not bakes.get(full):
                    var tris = meshes_cache.get(t.id)
                    if not tris:
                        let loaded = load_mesh(mesh_dir + "/" + t.id + ".mesh")
                        meshes_cache.set(t.id, loaded)
                        tris = loaded
                    let tt = tris
                    if tt and tt.length: add_baked(full, tt, f, key_colours(t.key))
        bake_count++
    bake_total = 0
    for(later.length) a:  // (the queue is taken from its end: the next age's last in)
        for(later[later.length - 1 - a]) w:
            if not bake_wanted_set.get(w.key, false):
                bake_wanted_set.set(w.key, true)
                bake_wanted.push(w)
    for(holds) w:
        if not bake_wanted_set.get(w.key, false):
            bake_wanted_set.set(w.key, true)
            bake_wanted.push(w)
    return baked_here

// The wanted parts (drawn before they were baked, view/art.lobster; the later ages'), baked a facing at a time for up
// to `budget` seconds of this frame with no progress page (play goes on; their plain forms stand in). When the last
// is baked the views are made again.
var bake_wanted_job:BakeJob? = nil

def bake_wanted_tick(budget:float):
    if not bake_wanted.length and not bake_wanted_job: return
    let t0 = seconds_elapsed()
    let live = bake_live
    bake_live = false
    while seconds_elapsed() - t0 < budget:
        let j = bake_wanted_job
        if j:
            if not bake_job_step(j): bake_wanted_job = nil
        elif bake_wanted.length:
            let w = bake_wanted.pop()
            if not bakes.get(w.key) and not bake_quit: bake_wanted_job = bake_part_job(w.id, w.key, w.cols)
        else: break
        if not bake_wanted.length and not bake_wanted_job:
            bake_gen++
            break
    bake_live = live
    gl.ortho()  // (back on the screen, a framebuffer's projection stays: the frame would draw at a bake's scale)

// The parts a view wears that the pack lacks, baked (the Race Lab's rosters with no pack). How many facings.
def bake_view_parts(n:VNode) -> int:
    let before = baked_here
    let parts = []::VNode
    part_nodes(n, parts)
    for(parts) pn:
        let key = bake_key(pn.part_id, pn.pshapes, pn.cols, pn.size)
        let cols = pn.cols
        if cols and not bakes.get(key): bake_model_part(pn.part_id, key, cols)
    return baked_here - before
