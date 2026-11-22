// ------------------------------------------------------------------ the props baked in the game (src/view/art/art_kit.gd: doodads)
// Every prop the map draws, as ArtKit names and seeds them, baked as voxels (view/voxel_mesh.lobster, D-203)
// from the Lobster models (model/props, trees, town_props) into the pack: reed beds, bug bushes, rocks,
// quarries (stone and gold), carcasses and trees in each variant and stage; field stones, tufts, shore reeds,
// lily pads, crops, paddies flat on the ground; drop-off piles, yards, gardens, the tether post. A tree's long
// ground shadow is kept apart ("<name>~shadow"), to lie under everything. Only what the pack lacks is baked
// (all of it when `rebake` is on), so a pack made without art still plays.

let AK_DOODADS = [ [ "reeds", "6" ], [ "bush", "6" ], [ "rock", "6" ], [ "quarry", "4" ], [ "gold", "4" ], [ "carcass", "3" ], [ "stones", "6" ],
                   [ "tuft", "6" ], [ "flowers", "6" ], [ "shore", "4" ], [ "lily", "4" ], [ "crops", "4" ], [ "paddy", "4" ], [ "ploughed", "3" ], [ "sprouts", "3" ], [ "ripe_wheat", "3" ], [ "vine_row", "3" ], [ "vine_row_ripe", "3" ],
                   [ "tree_broadleaf", "4" ], [ "tree_pine", "4" ], [ "tree_swamp", "4" ] ]
let AK_STAGES = 4
let AK_PILE_STYLE = [ [ "food", "a" ], [ "wood", "a" ], [ "stone", "b" ], [ "gold", "a" ] ]
var ak_rebake = false
var ak_baked = 0

def ak_count(kind:string) -> int:
    for(AK_DOODADS) d:
        if d[0] == kind: return string_to_int(d[1])
    return 0

// One sprite into the pack as a named frame (its anchor the frame's origin), on a sheet of its own.
def keep_frame(name:string, sprite:string, w:int, h:int, anchor:float2):
    if w == 0 or h == 0: return
    let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                            float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
    add_sheet(gl.create_texture(rows, pack_formats), float2 { float(w), float(h) }, pack_formats)
    frame_named(name)
    frames.push(Frame { sheet_tex.length - 1, 0, 0, w, h, int(anchor.x + 0.5), int(anchor.y + 0.5), 1.0 / ART_K })

// ArtKit._split_shadow: the opaque art, and the see-through ground shadow, as two sprites the same size.
def split_shadow(sprite:string, w:int, h:int) -> string, string:
    let art = ensure_size("", w * h * 4, 0)
    let shade = ensure_size("", w * h * 4, 0)
    for(w * h) p:
        let o = p * 4
        let into = if sprite[o + 3] == 255: art else: shade
        for(4) k: write_int8_le(into, o + k, sprite[o + k])
    return art, shade

// The props' bake cache (as the parts', view/part_bake.lobster: bake_cache/, emptied when BAKE_VERSION changes): a
// prop's frames (its art, and a tree's see-through shadow) as PNGs and one record of their sizes and anchors.
class AkFrame:
    name:string
    file:string
    w:int
    h:int
    ax:int
    ay:int

def ak_stem_in(dir:string, name:string) -> string: return dir + "/d" + sha256_text("{BAKE_VERSION}|prop|{name}|k {ART_K}").substring(0, 20)
def ak_stem(name:string) -> string: return ak_stem_in(bake_cache_dir, name)

// Frames from the cache (a prop's, a building look's), on sheets of their own: whether they were all there.
def ak_load_frames(fs:[AkFrame]) -> bool:
    for(fs) f:
        add_sheet_later(f.file, float2 { float(f.w), float(f.h) }, pack_formats)
        frame_named(f.name)
        frames.push(Frame { sheet_tex.length - 1, 0, 0, f.w, f.h, f.ax, f.ay, 1.0 / ART_K })
    return true

// A frame kept for the cache: its PNG beside the stem.
def ak_cache_frame(stem:string, n:int, name:string, sprite:string, w:int, h:int, anchor:float2) -> AkFrame:
    let file = "{stem}_{n}.png"
    write_file(file, png_bytes(map(sprite.length) i: sprite[i], w, h))
    return AkFrame { name, file, w, h, int(anchor.x + 0.5), int(anchor.y + 0.5) }

var ak_dump = ""  // propframes dump:<folder>: every prop as a PNG (art review)

// Whether a prop needn't be baked: it's in the pack, or its frames were in the shipped bakes or the cache (now loaded).
def ak_have(name:string) -> bool:
    bake_pulse()
    if bake_quit or (not ak_rebake and frame_index(name) >= 0): return true
    let stem = if bake_cache_dir != "": ak_stem(name) else: ""
    if stem != "" and not ak_rebake:
        let shipped = if bake_shipped_dir != "": read_file(ak_stem_in(bake_shipped_dir, name) + ".bin", true) else: nil
        let data = shipped or read_file(stem + ".bin", true)
        if data:
            let rec, err = flexbuffers_binary_to_value(typeof [AkFrame], data)
            let fs = rec
            if not err and fs and ak_load_frames(fs): return true
    bake_breath()
    return false

// A prop's sprite into the pack and the cache (reach > 1: its long ground shadow kept apart, to lie under everything).
def ak_keep(name:string, sprite:string, w:int, h:int, anchor:float2, reach:float):
    let stem = if bake_cache_dir != "": ak_stem(name) else: ""
    if ak_dump != "" and w > 0 and h > 0: write_file("{ak_dump}/{ak_baked}_{name}.png", png_bytes(map(sprite.length) i: sprite[i], w, h), 0, 1)
    let kept = []::AkFrame
    if reach > 1.0:
        let art, shade = split_shadow(sprite, w, h)
        keep_frame(name, art, w, h, anchor)
        keep_frame(name + "~shadow", shade, w, h, anchor)
        if stem != "" and w > 0 and h > 0:
            kept.push(ak_cache_frame(stem, 0, name, art, w, h, anchor))
            kept.push(ak_cache_frame(stem, 1, name + "~shadow", shade, w, h, anchor))
    else:
        keep_frame(name, sprite, w, h, anchor)
        if stem != "" and w > 0 and h > 0: kept.push(ak_cache_frame(stem, 0, name, sprite, w, h, anchor))
    if stem != "" and kept.length: write_file(stem + ".bin", flexbuffers_value_to_binary(kept, 1000))
    ak_baked++

// A prop from its model, as voxels (D-203).
def ak_bake(name:string, model:MNode, shadow:bool, reach:float = 1.0):
    if ak_have(name): return
    let sprite, w, h, anchor = voxel_bake(model, shadow)
    ak_keep(name, sprite, w, h, anchor, reach)

// A prop built voxel by voxel (view/voxel_grid.lobster, #410): the grid made only when it has to be baked.
def ak_grid(name:string, shadow:bool, reach:float, gridf):
    if ak_have(name): return
    let sprite, w, h, anchor = vg_sprite(gridf(), shadow)
    ak_keep(name, sprite, w, h, anchor, reach)

// Every doodad and town prop the pack lacks. Returns how many were baked.
def bake_doodads() -> int:
    ak_baked = 0
    bmat_matte = true
    for(AK_DOODADS) d:
        if doodads.get(d[0], 0) == 0: doodads.set(d[0], string_to_int(d[1]))
    for(ak_count("reeds")) v:
        for(AK_STAGES) st: ak_bake(staged("reeds", v, st), reed_clump(300 + v, 1.0, st), true)
    for(ak_count("bush")) v:
        for(AK_STAGES) st: ak_bake(staged("bush", v, st), bug_bush(400 + v, st), true)
    for(ak_count("rock")) v: ak_grid("rock{v}", true, 1.0): boulders(1000 + v)
    for(ak_count("quarry")) v:
        for(AK_STAGES) st:
            ak_grid(staged("quarry", v, st), true, 1.0): deposit(1300 + v, st, "stone")
            ak_grid(staged("gold", v, st), true, 1.0): deposit(1300 + v, st, "gold")
    for([ "broadleaf", "pine", "swamp" ]) sp:
        let kind = "tree_" + sp
        for(ak_count(kind)) v:
            for(AK_STAGES) st: ak_grid(staged(kind, v, st), true, 2.0): tree(1500 + v, sp, v % 3, st)
    for(ak_count("carcass")) v:
        for(AK_STAGES) st: ak_bake(staged("carcass", v, st), carcass(1400 + v, st), true)
    for(ak_count("stones")) v: ak_grid("stones{v}", false, 1.0): field_stones(500 + v)
    for(ak_count("tuft")) v: ak_bake("tuft{v}", grass_tuft(600 + v), false)
    for(ak_count("shore")) v: ak_bake("shore{v}", reed_clump(700 + v, 0.55, 0), false)
    for(ak_count("lily")) v: ak_bake("lily{v}", lily_pads(900 + v), false)
    for(ak_count("crops")) v: ak_bake("crops{v}", crops(1100 + v), false)
    for(ak_count("paddy")) v: ak_bake("paddy{v}", paddy(1200 + v), false)
    for(ak_count("ploughed")) v: ak_bake("ploughed{v}", furrows(1700 + v), false)  // a field's stages, a vine row's (#154; renamed when the earth lay flat, #186, so old bakes go)
    for(ak_count("sprouts")) v: ak_bake("sprouts{v}", shoots(1710 + v), false)
    for(ak_count("ripe_wheat")) v: ak_bake("ripe_wheat{v}", wheat(1720 + v), false)
    for(ak_count("vine_row")) v: ak_bake("vine_row{v}", vines(1730 + v, false), true)
    for(ak_count("vine_row_ripe")) v: ak_bake("vine_row_ripe{v}", vines(1740 + v, true), true)
    for(AK_PILE_STYLE) ps:
        for(3) s: ak_bake("pile.{ps[0]}.{s + 1}", pile(ps[0], s + 1, ps[1]), true)
    for(3) s:
        ak_bake("yard{s + 1}", yard(s + 1, 0), true)
        ak_bake("garden{s + 1}", garden(s + 1, 0), false)
    ak_bake("tether_post", tether_post(), true)
    for(br_id.length) k:
        for(2) broken:
            let len, wide, along = bridge_shape(k)
            let name = bridge_frame_name(k, broken)
            ak_bake(name, bridge_turned(1700 + len, len, broken, wide, along), true)
    return ak_baked

// Map bridges (#194): one bake per size the match's bridges use (length and width in tiles), along sim x or along sim y
// ("^z"), standing or broken (".1"). A bridge runs along its longer side, along y when square.
def bridge_shape(k:int) -> int, int, int:
    let sx = (br_x1[k] - br_x0[k] + 1) / TILE
    let sy = (br_y1[k] - br_y0[k] + 1) / TILE
    return max(sx, sy), min(sx, sy), if sy >= sx: 1 else: 0

def bridge_frame_name(k:int, broken:int) -> string:
    let len, wide, along = bridge_shape(k)
    return "bridge{len}x{wide}{if along == 1: "^z" else: ""}{if broken == 1: ".1" else: ""}"

def bridge_turned(seed_value:int, len:int, broken:int, wide:int, along:int) -> MNode:
    let m = bridge(seed_value, len, 0, broken, wide)
    if along == 0: return m
    let n = mnode()
    n.rot = float3 { 0.0, 90.0, 0.0 }  // (running along sim y)
    add_child(n, m)
    return n
