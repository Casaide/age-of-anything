// The boot screen: what the window shows while the game starts, before the title (concept C, Dominic 2026-10-30:
// docs/concepts/boot/). Cheap to draw, as nothing is baked yet: the game's icon in gold inlay on the UI's painted wood
// (icons/game_icon_ink.png, from assets/art/ui/game_icon.svg), the title, a bar over the start's steps.

// The icon's ink (white, the yellow cut out) tinted col, side px square, centred on c.
def boot_icon(c:float2, side:float, col:float4):
    let t = tb_icon_tex("game_icon_ink")
    if not t: return
    let o = c - float2_1 * side / 2.0
    let m = gl.new_mesh("PCT", [float3 { o.x, o.y, 0.0 }, float3 { o.x + side, o.y, 0.0 }, float3 { o.x + side, o.y + side, 0.0 }, float3 { o.x, o.y + side, 0.0 }],
                        [col, col, col, col], []::float3, [float2 { 0.0, 0.0 }, float2 { 1.0, 0.0 }, float2 { 1.0, 1.0 }, float2 { 0.0, 1.0 }], []::float2, [0, 2, 1, 0, 3, 2])
    gl.set_mesh_texture(m, 0, 0, t)
    gl.set_shader("textured_color")
    gl.color(float4_1): gl.render_mesh(m)
    gl.set_shader("color")

// One frame of the boot screen: what's loading and how far the start has got (0..1).
def boot_draw(what:string, done:float):
    let ws = float(gl.window_size())
    let k = min(ws.y / 950.0, ws.x / 1600.0)
    let c = float2 { ws.x / 2.0, ws.y * 0.4 }
    let gold = float4 { 0.93, 0.8, 0.5, 1.0 }
    fe_backdrop()
    boot_icon(c + float2 { 0.0, 4.0 * k }, 330.0 * k, float4 { 0.0, 0.0, 0.0, 0.6 })
    boot_icon(c, 330.0 * k, gold)
    ui_text_c(c.x, c.y + 195.0 * k, "Age of Anything", int(70.0 * k), gold, 2, 3.0 * k)
    let bar = float2 { c.x - 150.0 * k, c.y + 310.0 * k }
    ui_fill(bar, float2 { 300.0, 4.0 } * k, float4 { 0.0, 0.0, 0.0, 0.5 })
    ui_fill(bar, float2 { 300.0 * clamp(done, 0.0, 1.0), 4.0 } * k, gold)
    ui_text_c(c.x, c.y + 330.0 * k, what, int(20.0 * k), float4 { 0.7, 0.64, 0.54, 1.0 }, 0, 0.0)
    ui_flush()
