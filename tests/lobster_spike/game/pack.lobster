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

class Look:
    body:string
    stages:[string] // the four construction stages ("-": none)
    front:string

var sheet_size = 4096
var sheet_tex = []::resource<texture>
var frames = []::Frame
var frame_at = dictionary<string, int>(32768)
var anims = dictionary<string, int>(1024)     // "<type>.<state>" -> frames
var looks = dictionary<string, Look>(512)
var arch_of = []::string                      // per player
var doodads = dictionary<string, int>(64)
var prop_of = dictionary<string, string>(64)  // terrain id -> prop kind
var ground_a = []::float4                     // per terrain: its two colours
var ground_b = []::float4
var species = []::string                      // per cell: a tree's species, or "-"
var team_rgb = []::float4                     // per player
var unit_names = dictionary<int, string>(128)
var unit_blow = dictionary<int, string>(128)  // per unit type: its melee blow's sound, its shot's
var unit_shot = dictionary<int, string>(128)
var building_names = dictionary<int, string>(64)
var research_names = dictionary<int, string>(128)
var pack_map = ""                             // the match the art was baked for: its map and races' prompts
var pack_prompts = []::string
let pack_formats = texture_format_nearest_mag | texture_format_nearest_min | texture_format_nomipmap | texture_format_clamp

def load_pack(dir:string):
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
                        sheet_tex.push(assert gl.load_texture(dir + "/sheet{s}.png", pack_formats))
                case "frame":
                    frame_at.set(t[1], frames.length)
                    frames.push(Frame { num(2), num(3), num(4), num(5), num(6), num(7), num(8) })
                case "anim": anims.set(t[1] + "." + t[2], num(3))
                case "arch": arch_of.push(t[2])
                case "look": looks.set(t[1], Look { t[2], [t[3], t[4], t[5], t[6]], t[7] })
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
// vertex colour's rgb and darkens by its alpha.

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
        vec4 t = texture(tex0, itc);
        if (t.a < 0.02) discard;
        vec3 rgb = t.rgb;
        if (min(t.r, t.b) - t.g > 0.22 && abs(t.r - t.b) < 0.3) rgb = icolor.rgb * max(t.r, t.b);
        frag_color = vec4(rgb * icolor.a, t.a);
"""

var b_pos = []::float3
var b_col = []::float4
var b_tc = []::float2
var b_idx = []::int
var b_sheet = -1

def flush_sprites():
    if b_pos.length:
        let m = gl.new_mesh("PCT", b_pos, b_col, []::float3, b_tc, []::float2, b_idx)
        gl.set_mesh_texture(m, 0, 0, sheet_tex[b_sheet])
        gl.set_shader("sprite")
        gl.render_mesh(m)
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
    let x0 = floor(x) - fr.ox
    let y0 = floor(y) - fr.oy
    let x1 = x0 + fr.w
    let y1 = y0 + fr.h
    let s = float(sheet_size)
    let u0 = fr.x / s
    let v0 = fr.y / s
    let u1 = (fr.x + fr.w) / s
    let v1 = (fr.y + fr.h) / s
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
