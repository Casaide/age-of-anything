// ------------------------------------------------------------------ parts baked in the game (steps 6c, 6d; view/baker.lobster)
// Before a match, every part each unit type wears is looked up in the art pack in all eight facings; what
// isn't there (a new race's colours, a mod's parts, a new part) is baked here and joins the pack: its model
// built in Lobster (model/), baked with its rigs as the Godot part baker does (view/part_bake.lobster); a
// part with no model here comes from the mesh library (`meshes:<dir>`, mesh_export.gd library) if there is one.

var meshes_cache = dictionary<string, [BakeTri]>(64)

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
    sheet_tex.push(gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap))
    sheet_dims.push(float2 { float(w), float(h) })
    frame_at.set("p:" + full, frames.length)
    frames.push(Frame { sheet_tex.length - 1, 0, 0, w, h, int(origin.x + 0.5), int(origin.y + 0.5) })
    bakes.set(full, Bake { origin.x, origin.y, BAKE_ART })
    baked_here++

// Every unit type's parts, every facing, that the pack lacks: baked now. Returns how many.
def bake_missing_parts() -> int:
    baked_here = 0
    for(t_slot.length) k:
        let line = su_type_line[k]
        for(max(1, line.length)) step:
            let v = make_view(k, t_player[k], step)
            let parts = []::VNode
            part_nodes(v.node, parts)
            for(parts) n:
                let key = bake_key(n.part_id, n.pshapes, n.cols, n.size)
                let cols = n.cols
                if cols and not bakes.get(key) and bake_model_part(n.part_id, key, cols): continue
                if mesh_dir != "" and not has_char(n.part_id, '~'):
                    for(8) f:
                        let full = key + facing_suffix(f)
                        if not bakes.get(full):
                            var tris = meshes_cache.get(n.part_id)
                            if not tris:
                                let loaded = load_mesh(mesh_dir + "/" + n.part_id + ".mesh")
                                meshes_cache.set(n.part_id, loaded)
                                tris = loaded
                            let tt = tris
                            if tt and tt.length: add_baked(full, tt, f, key_colours(key))
            remove_child(view_stage, v.node)
            free_tree(v.node)
    return baked_here

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
