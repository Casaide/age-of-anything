// ------------------------------------------------------------------ the match pack (art_pack.gd)
// The sheets and index.txt: every frame (sheet, rect, anchor), the units' animations, the building
// looks, the doodad counts, the resource props, the ground colours and the tree cells' species.
// Art pixels throughout: a tile is 96 x 48 (Iso.to_screen * 1.5).

class Frame:
    sheet:int
    x:int
    y:int
    w:int
    h:int
    ox:int          // the anchor inside the frame
    oy:int
    k:float         // world art px a texture px (world art baked at ART_SCALE: 1 / ART_K)

class Look:
    body:string
    stages:[string] // the four construction stages ("-": none)
    front:string
    arms:[string] = []        // a wall's arm towards each neighbour (Models.LINKS order), "-": none
    arms_front:[string] = []  // their near merlons
    ruins:[string] = []       // broken up (game/ruin.lobster): battered, breaking, collapsed, the ruin it leaves

var sheet_size = 4096
let sheet_tex = []::resource<texture>
let sheet_dims = []::float2        // each sheet's size in px (the pack's are all sheet_size; a part baked in the game is its own)
let sheet_file = []::string        // a sheet not loaded yet: its PNG, loaded when it's first drawn ("": loaded)
let sheet_formats = []::int        // and the texture formats to load it with
let sheet_none = []::resource<texture>   // (the one stand-in texture for sheets not loaded yet)

// A sheet: its texture now, or its PNG (shipped or cached art) to load when it's first drawn.
def add_sheet(tex:resource<texture>, dims:float2):
    sheet_tex.push(tex)
    sheet_dims.push(dims)
    sheet_file.push("")
    sheet_formats.push(0)

def add_sheet_later(file:string, dims:float2, formats:int):
    if not sheet_none.length: sheet_none.push(gl.create_texture([[float4_0]], texture_format_nomipmap))
    sheet_tex.push(sheet_none[0])
    sheet_dims.push(dims)
    sheet_file.push(file)
    sheet_formats.push(formats)

def sheet_texture(i:int) -> resource<texture>:
    if sheet_file[i] != "":
        sheet_tex[i] = assert gl.load_texture(sheet_file[i], sheet_formats[i])
        sheet_file[i] = ""
    return sheet_tex[i]
let frames = []::Frame
let frame_at = dictionary<string, int>(32768)
let anims = dictionary<string, int>(1024)     // "<type>.<state>" -> frames
let looks = dictionary<string, Look>(512)
var arch_of = []::string                      // per player
let doodads = dictionary<string, int>(64)
var pack_rules = "default"                   // the host rules the pack's races were made with
var pack_mods = []::string                   // the mods they were made with
let prop_of = dictionary<string, string>(64)  // terrain id -> prop kind
let ground_a = []::float4                     // per terrain: its two colours
let ground_b = []::float4
var species = []::string                      // per cell: a tree's species, or "-"
let team_rgb = []::float4                     // per player
let unit_names = dictionary<int, string>(128)
let unit_blow = dictionary<int, string>(128)  // per unit type: its melee blow's sound, its shot's
let unit_shot = dictionary<int, string>(128)
let unit_shotk = dictionary<int, string>(128)   // the shot each unit type looses (combat_fx.shot_kind)
let building_names = dictionary<int, string>(64)
let research_names = dictionary<int, string>(128)
var pack_map = ""                             // the match the art was baked for: its map and races' prompts
let pack_prompts = []::string
var pack_library = false                      // the pack is the part library: every race's units, any race
let pack_formats = texture_format_nearest_mag | texture_format_nearest_min | texture_format_nomipmap | texture_format_clamp

// Where a building look's chimney smokes, its lantern and windows glow (canvas units from its anchor;
// fx.txt, from building_fx.gd).
class BFx:
    smoke:float2
    has_smoke:bool
    lights:[float2]               // the lantern first, if it has one

let bfx = dictionary<string, BFx>(256)

def load_bfx(dir:string):
    let text = read_file(dir + "/fx.txt")
    if not text: return
    for(tokenize(text, "\n", "")) line:
        let t = filter(tokenize(line, " ", "")): _.length > 0
        if t.length >= 6 and t[0] == "bfx":
            def f(k:int) -> float: return string_to_float(t[k])
            let lights = []::float2
            if t[4] != "-": lights.push(float2 { f(4), f(5) })
            var k = 6
            while k + 1 < t.length:
                lights.push(float2 { f(k), f(k + 1) })
                k += 2
            bfx.set(t[1], BFx { if t[2] != "-": float2 { f(2), f(3) } else: float2_0, t[2] != "-", lights })

def load_pack(dir:string):
    load_bfx(dir)
    let text = assert read_file(dir + "/index.txt")
    for(tokenize(text, "\n", "")) line:
        let t = filter(tokenize(line, " ", "")): _.length > 0
        if t.length:
            def num(k:int) -> int:
                let v, ok = string_to_int(t[k])
                assert ok
                return v
            switch t[0]:
                case "sheets":
                    sheet_size = num(2)
                    for(num(1)) s:
                        add_sheet(assert gl.load_texture(dir + "/sheet{s}.png", pack_formats), float2_1 * float(sheet_size))
                case "frame":
                    frame_at.set(t[1], frames.length)
                    frames.push(Frame { num(2), num(3), num(4), num(5), num(6), num(7), num(8), 1.0 })
                case "anim": anims.set(t[1] + "." + t[2], num(3))
                case "arch": arch_of.push(t[2])
                case "look": looks.set(t[1], Look { t[2], [t[3], t[4], t[5], t[6]], t[7] })
                case "arms":
                    let lk = looks.get(t[1])
                    if lk: lk.arms = t.slice(2, -1)
                case "armsf":
                    let lk = looks.get(t[1])
                    if lk: lk.arms_front = t.slice(2, -1)
                case "ruins":
                    let lk = looks.get(t[1])
                    if lk: lk.ruins = t.slice(2, -1)
                case "rules": pack_rules = t[1]
                case "mods": pack_mods = tokenize(t[1], ",", " ")
                case "doodad": doodads.set(t[1], num(2))
                case "prop": prop_of.set(t[1], t[2])
                case "ground":
                    ground_a.push(float4 { num(2) / 255.0, num(3) / 255.0, num(4) / 255.0, 1.0 })
                    ground_b.push(float4 { num(5) / 255.0, num(6) / 255.0, num(7) / 255.0, 1.0 })
                case "species": species = t.slice(1, -1)
                case "team": team_rgb.push(float4 { num(2) / 255.0, num(3) / 255.0, num(4) / 255.0, 1.0 })
                case "voice": voice_of.push(t[2])
                case "uname": unit_names.set(num(1), spaced(t[2]))
                case "usound":
                    unit_blow.set(num(1), t[2])
                    unit_shot.set(num(1), t[3])
                case "bname": building_names.set(num(1), spaced(t[2]))
                case "rname": research_names.set(num(1), spaced(t[2]))
                case "sound": sounds.set(t[1], Sound { num(2), num(3) / 1000.0, t[4] })
                case "bus": buses.set(t[1], float(num(2)))
                case "voicekind": voice_takes.set(t[1], num(2))
                case "match": pack_map = t[1]
                case "library": pack_library = true
                case "prompt": pack_prompts.push(if t.length > 2: spaced(t[2]) else: "")
                default: pass()

def frame_index(name:string) -> int: return frame_at.get(name, -1)

def spaced(s:string) -> string: return concat_string(tokenize(s, "_", ""), " ")

// ArtKit.building_key: the newest age look at or below the age, else a variant (houses), else the base.
def building_key(arch:string, type:string, age:int, pick:int) -> string:
    var a = age
    while a > 1:
        let key = "{arch}:{type}@{a}"
        if looks.get(key): return key
        a--
    let variant = "{arch}:{type}#{pick}"
    return if pick > 0 and looks.get(variant): variant else: "{arch}:{type}"

// ArtKit.staged: a doodad's bake name.
def staged(kind:string, variant:int, stage:int) -> string:
    return if stage == 0: "{kind}{variant}" else: "{kind}{variant}.{stage}"

// ArtKit.resource_stage: whole, started, nearly gone, used up.
def resource_stage(kind:string, left:int, full:int) -> int:
    let staged_kind = kind == "reeds" or kind == "bush" or kind == "quarry" or kind == "gold" or kind == "carcass" or
        kind == "tree_broadleaf" or kind == "tree_pine" or kind == "tree_swamp"
    if not staged_kind: return 0
    if left <= 0: return 3
    if left >= full: return 0
    if kind == "bush": return if left * 2 > full: 1 else: 2
    return if left * 100 > full * 45: 1 else: 2

// ------------------------------------------------------------------ drawing sprites
// Quads gathered into one mesh a sheet change; the sprite shader recolours the team key with the
// vertex colour's rgb and darkens by its alpha (sprite_faded: one fading out).

let SPRITE_SHADERS = """
SHADER sprite
    VERTEX
        INPUTS apos:4 atc:2 acolor:4
        UNIFORMS mvp
        gl_Position = mvp * apos;
        itc = atc;
        icolor = acolor;
    PIXEL
        INPUTS itc:2 icolor:4
        UNIFORMS tex0
        UNIFORM float gone
        vec4 t = texture(tex0, itc);
        if (t.a < 0.02) discard;
        vec3 rgb = t.rgb;
        if (min(t.r, t.b) - t.g > 0.22 && abs(t.r - t.b) < 0.3) rgb = icolor.rgb * max(t.r, t.b) * 1.08;
        frag_color = vec4(rgb * icolor.a, t.a * (1.0 - gone));
"""

var b_pos = []::float3
var b_col = []::float4
var b_tc = []::float2
var b_idx = []::int
var b_sheet = -1

def flush_sprites():
    if b_pos.length:
        gl.set_shader("sprite")
        gl.set_primitive_texture(0, sheet_texture(b_sheet))
        gl.draw_mesh("PCT", b_pos, b_col, []::float3, b_tc, []::float2, b_idx)
    b_pos = []::float3
    b_col = []::float4
    b_tc = []::float2
    b_idx = []::int

// Frame f with its anchor at (x, y) (art px), team colour and shade in col; flip: mirrored.
def sprite(f:int, x:float, y:float, col:float4):
    let fr = frames[f]
    if fr.sheet != b_sheet:
        flush_sprites()
        b_sheet = fr.sheet
    let x0 = floor(x) - float(fr.ox) * fr.k
    let y0 = floor(y) - float(fr.oy) * fr.k
    let x1 = x0 + float(fr.w) * fr.k
    let y1 = y0 + float(fr.h) * fr.k
    let s = sheet_dims[fr.sheet]
    let u0 = fr.x / s.x
    let v0 = fr.y / s.y
    let u1 = (fr.x + fr.w) / s.x
    let v1 = (fr.y + fr.h) / s.y
    let n = b_pos.length
    b_pos.push(float3 { x0, y0, 0.0 })
    b_pos.push(float3 { x1, y0, 0.0 })
    b_pos.push(float3 { x1, y1, 0.0 })
    b_pos.push(float3 { x0, y1, 0.0 })
    b_tc.push(float2 { u0, v0 })
    b_tc.push(float2 { u1, v0 })
    b_tc.push(float2 { u1, v1 })
    b_tc.push(float2 { u0, v1 })
    for(4): b_col.push(col)
    b_idx.push(n)
    b_idx.push(n + 2)
    b_idx.push(n + 1)
    b_idx.push(n)
    b_idx.push(n + 3)
    b_idx.push(n + 2)

// One sprite fading out (a ruin): drawn alone, how far it's gone a uniform (0 by default: the vertex colour is bytes,
// it can't carry it). fade: 1 whole .. 0 gone.
def sprite_faded(f:int, x:float, y:float, col:float4, fade:float):
    flush_sprites()
    gl.set_shader("sprite")
    gl.set_uniform("gone", 1.0 - fade)
    b_sheet = frames[f].sheet
    sprite(f, x, y, col)
    flush_sprites()
    gl.set_shader("sprite")
    gl.set_uniform("gone", 0.0)
    b_sheet = -1

// Frame f drawn through an affine transform from its texture px to art px ([xx, xy, yx, yy, ox, oy]:
// a composed unit's part, turned and scaled as its rig says).
def sprite_xf(f:int, xf:[float], col:float4):
    let fr = frames[f]
    if fr.sheet != b_sheet:
        flush_sprites()
        b_sheet = fr.sheet
    let s = sheet_dims[fr.sheet]
    let n = b_pos.length
    for([float2 { 0.0, 0.0 }, float2 { float(fr.w), 0.0 }, float2 { float(fr.w), float(fr.h) }, float2 { 0.0, float(fr.h) }]) c:
        b_pos.push(float3 { xf[0] * c.x + xf[2] * c.y + xf[4], xf[1] * c.x + xf[3] * c.y + xf[5], 0.0 })
    b_tc.push(float2 { fr.x / s.x, fr.y / s.y })
    b_tc.push(float2 { (fr.x + fr.w) / s.x, fr.y / s.y })
    b_tc.push(float2 { (fr.x + fr.w) / s.x, (fr.y + fr.h) / s.y })
    b_tc.push(float2 { fr.x / s.x, (fr.y + fr.h) / s.y })
    for(4): b_col.push(col)
    for([n, n + 2, n + 1, n, n + 3, n + 2]) k: b_idx.push(k)
