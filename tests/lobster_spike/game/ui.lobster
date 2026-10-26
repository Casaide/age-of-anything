// ------------------------------------------------------------------ the UI's look and widgets (src/view/ui/theme.gd, ui_box.gd, ui_materials.gd)
// One small layer every screen draws through, so the Lobster quirks are dealt with once: the
// look from data/ui.json (the "timber" direction: carved wood faces in bronze frames, lit from the
// top left, studs on the corners) and a culture's `ui` block over it; boxes (raised, flat, sunk),
// buttons (hover, pressed, focus, the primary one), and text queued and drawn last (a shape drawn
// after text comes out wrong in this build). Immediate mode: a screen calls ui_button(...) each
// frame and gets true on the frame it's pressed (a click, or A on the pad's focus). The pad moves
// the focus between the buttons drawn this frame with the d-pad or the left stick (nearest in
// that direction). Materials are painted by a shader from the pixel position, so they stay crisp
// and seamless at any size.

let UI_SHADERS = """
PIXELFUNCTIONS
    float uihash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float uinoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(uihash(i), uihash(i + vec2(1.0, 0.0)), u.x), mix(uihash(i + vec2(0.0, 1.0)), uihash(i + vec2(1.0, 1.0)), u.x), u.y);
    }
    float uifbm(vec2 p) { return uinoise(p) * 0.55 + uinoise(p * 2.1 + 7.0) * 0.3 + uinoise(p * 4.3 + 3.0) * 0.15; }

SHADER uimat
    VERTEX
        INPUTS apos:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
    PIXEL
        UNIFORM vec4 mcol
        UNIFORM float kind
        UNIFORM float win_h
        UNIFORM float px
        vec2 p = vec2(gl_FragCoord.x, win_h - gl_FragCoord.y) / px;
        float v = 1.0;
        if (kind < 0.5) {
            // wood: long grain along x, rings, planks with dark seams and a lit lip, a touch of fine noise
            float g = uifbm(vec2(p.x * 0.012, p.y * 0.09));
            float rings = 0.5 + 0.5 * sin(g * 38.0);
            v = 0.62 + 0.22 * rings + 0.16 * (uinoise(p * 0.5) - 0.5);
            float py = mod(p.y, 32.0);
            if (py < 1.0) v *= 0.42;
            else if (py < 1.6) v *= 1.18;
            v *= 0.92 + 0.08 * sin(floor(p.y / 32.0) * 2.1);
        } else if (kind < 1.5) {
            // hammered metal: soft dimples lit from the top left, a few scratches, blotches
            vec2 q = p * 0.09;
            float d = uinoise(q);
            float dl = uinoise(q - vec2(0.09, 0.09));
            v = 0.8 + (d - dl) * 1.6 + 0.12 * (uifbm(p * 0.012) - 0.5) + 0.1 * (uinoise(vec2(p.x * 0.05, p.y * 0.8)) - 0.5);
        } else {
            // lacquer: smooth, a soft sheen down its face
            v = 0.9 + 0.1 * uinoise(p * 0.02);
        }
        frag_color = vec4(mcol.rgb * v, mcol.a);
"""

class UiLook:
    frame:float4
    face:float4
    button:float4
    primary:float4
    well:float4
    accent:float4
    text:float4
    dim:float4
    title:float4
    metal:float4

var ui_look = UiLook { float4_1, float4_1, float4_1, float4_1, float4_1, float4_1, float4_1, float4_1, float4_1, float4_1 }
var ui_ready = false
var ui_warned = false

def hex4(h:string) -> float4:
    let s = if h.length and h[0] == '#': h.substring(1, h.length - 1) else: h
    def byte(i:int) -> float: return float(string_to_int(s.substring(i, 2), 16)) / 255.0
    return float4 { byte(0), byte(2), byte(4), 1.0 }

// The look: the direction in data/ui.json, a culture's `ui` block over it (families.json) if given.
def ui_setup(culture:string):
    let d = load_json(lib_root + "/ui.json")
    var dir = at(at(d, "directions"), gstr(d, "direction", "timber"))
    if culture != "":
        let cu = gobj(family(culture), "ui")
        if cu.keys.length: dir = mod_merge(dir, cu)
    def c(k:string, f:string) -> float4: return hex4(gstr(dir, k, f))
    ui_look = UiLook { c("frame_colour", "#9a7438"), c("colour", "#4a3220"), c("button_colour", "#6a4a2c"), c("primary_colour", "#7a2a18"),
                       c("well", "#17110b"), c("accent", "#f2c94c"), c("text", "#f4e9cf"), c("dim", "#c4b493"), c("title", "#f6d77a"), c("metal", "#c09048") }
    if not ui_ready:
        fatal(gl.load_materials(UI_SHADERS, true))
        ui_ready = true

// ---- drawing: shapes now, text queued

class UiText:
    at:float2
    s:string
    size:int
    col:float4

var ui_texts = []::UiText

def ui_text(at:float2, s:string, size:int, col:float4): ui_texts.push(UiText { at, s, size, col })

// About the room a line of text takes (gl.text_size doesn't match what's drawn at every scale).
def ui_text_w(s:string, size:int) -> float: return 0.52 * float(size) * float(s.length)

def ui_flush():
    for(ui_texts) t:
        gl.set_font_size(t.size)
        gl.color(t.col):
            gl.translate(t.at): gl.text(t.s)
    ui_texts = []

// A flat fill from its top-left corner (meshes in screen coordinates: gl.rect draws -size..size round its
// point in this build, and goes astray once a custom shader has been used).
// A quad in the current transform's coordinates, coloured per vertex (a raw mesh render doesn't pass
// gl.color's colour to the colour shader, so fills use color_attr).
def ui_quad(at:float2, size:float2, col:float4 = float4_1) -> resource<mesh>:
    return gl.new_mesh("PC", [float3 { at.x, at.y, 0.0 }, float3 { at.x + size.x, at.y, 0.0 }, float3 { at.x + size.x, at.y + size.y, 0.0 }, float3 { at.x, at.y + size.y, 0.0 }],
                       [col, col, col, col], []::float3, []::float2, []::float2, [0, 2, 1, 0, 3, 2])

def ui_fill(at:float2, size:float2, col:float4):
    if size.x <= 0.0 or size.y <= 0.0: return
    gl.set_shader("color_attr")
    gl.render_mesh(ui_quad(at, size, col))
    gl.set_shader("color")   // (what the callers' own shapes expect next)

def ui_mat(at:float2, size:float2, col:float4, kind:int):
    if size.x <= 0.0 or size.y <= 0.0: return
    gl.set_shader("uimat")
    let ok = gl.set_uniform("mcol", col) and gl.set_uniform("kind", float(kind)) and gl.set_uniform("win_h", float(gl.window_size().y)) and gl.set_uniform("px", max(1.0, ui()))
    if not ok and not ui_warned:
        print "ui: a uniform did not set"
        ui_warned = true
    // (a mesh in screen coordinates: gl.rect with this shader doesn't land where asked)
    gl.render_mesh(gl.new_mesh("P", [float3 { at.x, at.y, 0.0 }, float3 { at.x + size.x, at.y, 0.0 }, float3 { at.x + size.x, at.y + size.y, 0.0 }, float3 { at.x, at.y + size.y, 0.0 }],
                               []::float4, []::float3, []::float2, []::float2, [0, 2, 1, 0, 3, 2]))
    gl.set_shader("color")

// A bevel round the inside of a rect: lit top and left, shadowed bottom and right.
def ui_bevel(at:float2, size:float2, w:float, lit:float, dark:float):
    ui_fill(at, float2 { size.x, w }, float4 { 1.0, 1.0, 1.0, lit })
    ui_fill(at, float2 { w, size.y }, float4 { 1.0, 1.0, 1.0, lit * 0.7 })
    ui_fill(at + float2 { 0.0, size.y - w }, float2 { size.x, w }, float4 { 0.0, 0.0, 0.0, dark })
    ui_fill(at + float2 { size.x - w, 0.0 }, float2 { w, size.y }, float4 { 0.0, 0.0, 0.0, dark * 0.8 })

def ui_outline(at:float2, size:float2, w:float, col:float4):
    ui_fill(at, float2 { size.x, w }, col)
    ui_fill(at + float2 { 0.0, size.y - w }, float2 { size.x, w }, col)
    ui_fill(at, float2 { w, size.y }, col)
    ui_fill(at + float2 { size.x - w, 0.0 }, float2 { w, size.y }, col)

def ui_stud(c:float2, r:float, col:float4):
    gl.set_shader("color")
    gl.color(float4 { 0.0, 0.0, 0.0, 0.5 }): gl.translate(c + float2 { 0.6, 0.8 } * r * 0.4): gl.circle(r, 12)
    gl.color(col * float4 { 0.7, 0.7, 0.7, 1.0 }): gl.translate(c): gl.circle(r, 12)
    gl.color(col): gl.translate(c - float2_1 * r * 0.15): gl.circle(r * 0.75, 12)
    gl.color(float4 { 1.0, 1.0, 1.0, 0.55 }): gl.translate(c - float2_1 * r * 0.35): gl.circle(r * 0.25, 8)

// A box of the look: a bronze frame round a wood face (depth 1 raised, 0 flat, -1 sunk: a well).
def ui_box(at:float2, size:float2, depth:int, face:float4, studs:bool):
    let u = ui()
    let fw = max(3.0, 6.0 * u)
    if depth > 0:
        for(4) k: ui_fill(at + float2 { -1.0, 2.0 } * float(k + 1) * u, size, float4 { 0.0, 0.0, 0.0, 0.08 })   // a soft drop shadow
    ui_mat(at, size, ui_look.frame, 1)
    ui_bevel(at, size, max(1.0, 1.5 * u), 0.32, 0.5)
    let inner = at + float2_1 * fw
    let isz = size - float2_1 * fw * 2.0
    if depth < 0:
        ui_fill(inner, isz, ui_look.well)
        let d = clamp(isz.y * 0.25, 3.0, 12.0 * u)
        for(3) k: ui_fill(inner, float2 { isz.x, d * float(3 - k) / 3.0 }, float4 { 0.0, 0.0, 0.0, 0.25 })
    else:
        ui_mat(inner, isz, face, 0)
        if depth > 0:
            ui_fill(inner + float2 { 0.0, isz.y * 0.5 }, float2 { isz.x, isz.y * 0.5 }, float4 { 0.0, 0.0, 0.0, 0.12 })
            ui_bevel(inner, isz, clamp(min(isz.x, isz.y) * 0.08, 1.5, 4.0 * u), 0.22, 0.42)
    ui_outline(inner, isz, 1.0, float4 { 0.0, 0.0, 0.0, 0.65 })
    ui_outline(at, size, 1.0, float4 { 0.0, 0.0, 0.0, 0.8 })
    if studs:
        let m = fw * 0.5
        for([at + float2_1 * m, float2 { at.x + size.x - m, at.y + m }, at + size - float2_1 * m, float2 { at.x + m, at.y + size.y - m }]) c:
            ui_stud(c, max(2.5, fw * 0.8), ui_look.metal)

// ---- buttons, with the pad's focus

class UiHit:
    at:float2
    size:float2

var ui_hits = []::UiHit            // the buttons drawn this frame, in order (for the pad's focus)
var ui_hits_last = []::UiHit
var ui_focus = -1                  // index into last frame's buttons; -1: the mouse has it
var ui_pad_a = false
var ui_stick_ready = true

// Called once a frame before any button: the pad's d-pad / stick moves the focus and A presses (pad:
// false in a match, where the pad plays the battlefield and its own wheel does the panel's work).
def ui_frame(pad:bool):
    ui_hits_last = ui_hits
    ui_hits = []
    ui_pad_a = pad and gl.button("controller_a") == 1
    if not pad:
        ui_focus = -1
        return
    let d = float2 { (if gl.button("controller_dpright") == 1: 1.0 else: 0.0) - (if gl.button("controller_dpleft") == 1: 1.0 else: 0.0),
                     (if gl.button("controller_dpdown") == 1: 1.0 else: 0.0) - (if gl.button("controller_dpup") == 1: 1.0 else: 0.0) }
    var dir = d
    let stick = float2 { gl.controller_axis(0), gl.controller_axis(1) }
    if magnitude(stick) > 0.6:
        if ui_stick_ready: dir = normalize(stick)
        ui_stick_ready = false
    elif magnitude(stick) < 0.3: ui_stick_ready = true
    if magnitude(dir) > 0.0 and ui_hits_last.length:
        if ui_focus < 0 or ui_focus >= ui_hits_last.length: ui_focus = 0
        else:
            let here = ui_hits_last[ui_focus].at + ui_hits_last[ui_focus].size / 2.0
            var best = -1
            var best_d = 1000000000.0
            for(ui_hits_last) h, k:
                let off = h.at + h.size / 2.0 - here
                let along = dot(off, normalize(dir))
                if k != ui_focus and along > 1.0:
                    let score = along + 2.0 * magnitude(off - normalize(dir) * along)
                    if score < best_d:
                        best_d = score
                        best = k
            if best >= 0: ui_focus = best
    let m = float(gl.mouse_pos(0))
    if gl.button("mouse1") == 1 or magnitude(float(gl.mouse_delta(0))) > 2.0:
        if not (magnitude(dir) > 0.0): ui_focus = -1

// A button (primary: the lacquered one). True on the frame it's pressed.
def ui_button(at:float2, size:float2, label:string, primary:bool) -> bool:
    let u = ui()
    let k = ui_hits.length
    ui_hits.push(UiHit { at, size })
    let m = float(gl.mouse_pos(0))
    let over = m.x >= at.x and m.y >= at.y and m.x <= at.x + size.x and m.y <= at.y + size.y
    let focused = ui_focus == k
    let down = over and gl.button("mouse1") >= 1
    let face = if primary: ui_look.primary else: ui_look.button
    let lift = if down: float2 { 0.0, 1.5 * u } else: float2_0
    ui_box(at + lift, size, if down: 0 else: 1, if over or focused: face * float4 { 1.18, 1.18, 1.18, 1.0 } else: face, false)
    if over or focused or primary:
        let a = if primary and not (over or focused): 0.45 else: 1.0
        ui_outline(at + lift + float2_1 * 4.0 * u, size - float2_1 * 8.0 * u, 2.0 * u, float4 { ui_look.accent.x, ui_look.accent.y, ui_look.accent.z, a })
    if label != "":
        let fs = int(min(18.0 * u, size.y * 0.45))
        ui_text(at + lift + float2 { (size.x - ui_text_w(label, fs)) / 2.0, (size.y - float(fs)) / 2.0 - 2.0 * u }, label, fs, ui_look.text)
    return (over and gl.button("mouse1") == 1) or (focused and ui_pad_a)

// A titled panel: a raised box with a caption in the title colour.
def ui_panel(at:float2, size:float2, title:string):
    ui_box(at, size, 1, ui_look.face, true)
    if title != "":
        let u = ui()
        ui_text(at + float2 { 22.0 * u, 14.0 * u }, title, int(24.0 * u), ui_look.title)
