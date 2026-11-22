// The game's own ground under a stage in the lobby (#191; Dominic, 2026-11-04: "just put them on our ground texture"): the terrain shader
// over a patch of plain grass (blank masks: no paths, reeds, swamp or rock), at the units' scale (k screen px a world
// px), each side's patch a different stretch of it.
var fe_turf_tex:resource<texture>? = nil
def fe_turf(at:float2, size:float2, k:float, side:int):
    if not fe_turf_tex: fe_turf_tex = gl.create_texture(map(2): map(2): float4_0, texture_format_clamp | texture_format_nomipmap)
    let tex = fe_turf_tex
    ui_batch_flush()
    let local = size / k
    let o = float2 { float(side) * 200.0 - 300.0, 1400.0 }  // (world px: well inside the 128 x 128 map it says)
    gl.set_shader("terrain")
    gl.set_uniform("map_size", float2 { 128.0, 128.0 })
    gl.set_uniform("art_px", k / ART_K)  // (screen px an art px, as the match passes it)
    gl.set_uniform("dev_px", k)
    gl.set_uniform("time", 0.0)
    // (every uniform the shader reads, as the match's ground sets them: left unset, they're 0 until a match has drawn,
    // and a tile_h of 0 puts every pixel off the map, #191; the atlas as it is, not one turning in)
    gl.set_uniform("bank_px", ground_bank_px)
    gl.set_uniform("water_edge", ground_water_edge)
    gl.set_uniform("shore_soft", ground_shore_soft)
    gl.set_uniform("tile_h", iso_k * 2000.0 / 3.0)
    gl.set_uniform("litter_fringe", ground_litter_fringe)
    gl.set_uniform("water_shallow", ground_water_shallow)
    gl.set_uniform("water_deep", ground_water_deep)
    gl.set_uniform("water_ripples", ground_water_ripples)
    gl.set_uniform("atlas_mix", 0.0)
    for(4) u: gl.set_primitive_texture(u, tex)
    gl.set_primitive_texture(4, ground_atlas())
    gl.set_primitive_texture(5, tex)
    gl.set_primitive_texture(6, ground_atlas())
    gl.translate(at):
        gl.scale(k):
            gl.translate(-o):
                gl.draw_mesh("PT", [ float3 { o.x, o.y, 0.0 }, float3 { o.x + local.x, o.y, 0.0 }, float3 { o.x + local.x, o.y + local.y, 0.0 }, float3 { o.x, o.y + local.y, 0.0 } ],
                             []::float4, []::float3, map(4): float2_0, []::float2, [ 0, 2, 1, 0, 3, 2 ])
    gl.set_shader("color")
