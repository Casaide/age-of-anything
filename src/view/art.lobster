// ------------------------------------------------------------------ the parts' bakes (PartShape's side of it)
// Every part bake in the pack: its frame, its origin (texture px of the part's 0,0) and scale
// (texture px a part unit); legs' soles and spans; the rigs the bakes made (sockets, hips, depth,
// facing directions; rigs.json); which parts have hand-built models. A part's bake is found by its
// bake key: its id and the colours of the channels its shapes use (the team's is always the key).

class Bake:
    ox:float
    oy:float
    scale:float

// The art scale (D-173, "heroic at 2x"): art pixels a canvas unit. The world stays in the art pixels it had before
// (ART_BASE: a tile is 96 x 48), so sprites baked at ART_SCALE draw at 1 / ART_K of their texture's size.
let ART_SCALE = 3.0
let ART_BASE = 1.5
let ART_K = ART_SCALE / ART_BASE

let bakes = dictionary<string, Bake>(8191)
let bake_soles = dictionary<string, [float2]>(1023)
let bake_spans = dictionary<string, [float2]>(1023)
var rigs = jobj()
let modelled = dictionary<string, int>(511)
var modelled_listed = false        // (a pack's index lists every modelled part: then what it leaves out has none)
let TEAM_KEY_HEX = "ff00ff"

def ffloat(s:string) -> float:
    return string_to_float(s)

def load_part_data(dir:string):
    let text = assert read_file(dir + "/index.txt")
    for(tokenize(text, "\n", "")) line:
        let t = filter(tokenize(line, " ", "")): _.length > 0
        if t.length:
            switch t[0]:
                case "bake": bakes.set(t[1], Bake { ffloat(t[2]), ffloat(t[3]), ffloat(t[4]) })
                case "soles": bake_soles.set(t[1], map((t.length - 2) / 2) n: float2 { ffloat(t[2 + n * 2]), ffloat(t[3 + n * 2]) })
                case "span": bake_spans.set(t[1], [float2 { ffloat(t[2]), ffloat(t[3]) }, float2 { ffloat(t[4]), ffloat(t[5]) }])
                case "modelled":
                    modelled.set(t[1], 1)
                    modelled_listed = true
                default: pass()
    rigs = load_json(dir + "/rigs.json")
    let kit = read_file(dir + "/kit_parts.json")
    if kit:
        let kp = parse_json(kit)
        for(kp.keys) id, n: set(lib_parts, id, kp.a[n])
    lib_part_ids = sorted_strs(lib_parts.keys)

def facing_suffix(k:int) -> string: return if k == 0: "" else: "#f" + string(k)

def rig(id:string) -> JV: return get(rigs, id) or jobj()
def has_rig(id:string) -> bool: return has(rigs, id)
// rigs.get(a, rigs.get(b, {}))
def rig_or(a:string, b:string) -> JV: return get(rigs, a) or get(rigs, b) or jobj()

def v2(a:JV) -> float2: return float2 { as_float(a.a[0]), as_float(a.a[1]) }
def jf(o:JV, k:string, fallback:float) -> float:
    let v = get(o, k)
    return if v: as_float(v) else: fallback

// ---- colours (UnitView.colours_for)

def hex_of(html:string) -> string:   // "#RRGGBB(AA)" -> "rrggbb", as Color.to_html(false)
    let h = if html.length and html[0] == '#': substring(html, 1, html.length - 1) else: html
    return lowercase(substring(h, 0, 6))

def rgb_of(hex:string) -> float3:
    let r, _ok1 = string_to_int(substring(hex, 0, 2), 16)
    let g, _ok2 = string_to_int(substring(hex, 2, 2), 16)
    let b, _ok3 = string_to_int(substring(hex, 4, 2), 16)
    return float3 { r / 255.0, g / 255.0, b / 255.0 }

def colours_for(skin:string, fam:string, team:float3) -> Colours:
    let d = dictionary<string, string>(31)
    let mats = at(lib_palettes, "materials")
    for(mats.keys) k, n: d.set(k, hex_of(as_str(mats.a[n])))
    let sk = gstrs(at(lib_palettes, "skins"), skin)
    d.set("skin", hex_of(sk[0]))
    d.set("skin2", hex_of(sk[1]))
    var i = 2
    while i < sk.length:
        d.set("skin" + string(i + 1), hex_of(sk[i]))
        i++
    let cloth = gstrs(family(fam), "cloth")
    d.set("cloth", hex_of(cloth[0]))
    d.set("cloth2", hex_of(cloth[1]))
    return Colours { d, team }

let SHADOW_COLOURS = Colours { dictionary<string, string>(3), float3_1 }

// ---- bake keys and lookups (PartShape)

// (at: the percent of the art scale it's baked at, its unit's drawn size; "%<at>" on the key when not 100, D-180)
def bake_key(id:string, shapes:[JV], cols:Colours?, at:int = 100) -> string:
    let chans = []::string
    for(shapes) s:
        let ch = gstr(s, "ch", "")
        if not has_s(chans, ch): chans.push(ch)
    let names = sorted_strs(chans)
    var out = id + ":"
    for(names) c, n:
        if n > 0: out += ","
        var hex = "ff00ff"
        if c == "team": hex = TEAM_KEY_HEX
        elif cols: hex = cols.hex.get(c, "ff00ff")
        out += c + "=" + hex
    return if at == 100: out else: out + "%" + string(at)

// The key a part node draws (its facing's bake when there is one; its front layer).
def draw_key(n:VNode) -> string:
    var key = bake_key(n.part_id, n.pshapes, n.cols, n.size)
    if n.facing != 0 and bakes.get(key + facing_suffix(n.facing)): key += facing_suffix(n.facing)
    return if n.front: key + "#front" else: key

// Parts drawn before they're baked (a walk step, a pose, a race just typed) are wanted: baked a part at a time
// between frames (bake_wanted_tick, game/bake_missing.lobster), the part's plain form standing in meanwhile.
class Wanted:
    id:string
    key:string
    cols:Colours

let bake_wanted = []::Wanted
let bake_wanted_set = dictionary<string, bool>(256)
var bake_gen = 0   // goes up when the wanted parts are all baked (views made before are made again, on the new rigs)

def want_bake(n:VNode):
    let cols = n.cols
    if not cols: return
    let key = bake_key(n.part_id, n.pshapes, cols, n.size)
    if bake_wanted_set.get(key, false): return
    bake_wanted_set.set(key, true)
    bake_wanted.push(Wanted { n.part_id, key, cols })

// A part without its walk step or pose ("leg.bear@w3_8~body.bear^1" -> "leg.bear~body.bear^1").
def plain_id(id:string) -> string:
    var s = id
    var at = find_string(s, "@")
    while at >= 0:
        var end = at + 1
        while end < s.length and s[end] != '~' and s[end] != '^' and s[end] != ':' and s[end] != '@': end++
        s = s.substring(0, at) + s.substring(end, s.length - end)
        at = find_string(s, "@")
    return s

// PartShape.bake_of: this node's bake (another id's: `id`), or nil.
def bake_key_of(n:VNode, id:string) -> string:
    var key = bake_key(if id == "": n.part_id else: id, n.pshapes, n.cols, n.size)
    if n.facing != 0 and bakes.get(key + facing_suffix(n.facing)): key += facing_suffix(n.facing)
    return if n.front: key + "#front" else: key

def has_bake_of(n:VNode, id:string) -> bool: return bakes.get(bake_key_of(n, id)) != nil
def soles_of(n:VNode, id:string) -> [float2]: return bake_soles.get(bake_key_of(n, id)) or []::float2

// Set a node up as a part (PartShape.setup): its shapes and colours, tinted by its team.
def part_setup(n:VNode, shapes:[JV], cols:Colours):
    n.part = true
    n.pshapes = shapes
    n.cols = cols

def new_part(id:string) -> VNode:
    let n = VNode {}
    n.part = true
    n.part_id = id
    return n
