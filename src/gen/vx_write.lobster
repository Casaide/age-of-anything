// Writing voxel bodies and materials as data (the voxel format: data/voxel/): shapes on a body's one point "o", a
// shape a line, and materials with their patterns. Used by the programs that write bodies from code
// (voxel_buildings_gen.lobster, voxel_engines_gen.lobster); the files they write are the data.

def jf(f:float) -> JV:  // a float, to a thousandth
    let o = JV { J_FLOAT }
    o.f = float(int(f * 1000.0 + (if f < 0.0: -0.5 else: 0.5))) / 1000.0
    return o

def jv3(v:float3) -> JV: return jarr([ jf(v.x), jf(v.y), jf(v.z) ])
def jpt(v:float3) -> JV: return jarr([ jstr("o"), jf(v.x), jf(v.y), jf(v.z) ])

def jset(o:JV, k:string, v:JV) -> JV:
    set(o, k, v)
    return o

// ---- materials: a colour, and a pattern (its kind, size in body units, depth, how much of the second colour)

let mats = []::string  // "name": {...}, in order

def mat(name:string, rgb:string, fur:bool, pat:JV?):
    let o = jset(jobj(), "rgb", jstr(rgb))
    if fur: set(o, "fur", jbool(true))
    if pat: set(o, "pattern", pat)
    mats.push("\"{name}\": {stringify(o)}")

def pat(kind:string, size:float2, depth:float, mix:float, c2:string) -> JV:
    let o = jset(jobj(), "kind", jstr(kind))
    set(o, "size", jarr([ jf(size.x), jf(size.y) ]))
    set(o, "depth", jf(depth))
    set(o, "mix", jf(mix))
    set(o, "color2", jstr(c2))
    return o

def glow(name:string, rgb:string): mats.push("\"{name}\": {stringify(jset(jset(jobj(), "rgb", jstr(rgb)), "glow", jbool(true)))}")

// ---- shapes (on the one point, "o")

var shapes = []::JV

// A box round c facing along n, half sizes across, thick and up (the format's); facing x (a side wall's), half is
// given as the world's x, y, z like the rest.
def box(c:float3, half:float3, n:float3, m:string, round:float):
    let h = if n == float3 { 1.0, 0.0, 0.0 }: float3 { half.y, half.x, half.z } else: half
    let o = jset(jobj(), "box", jpt(c))
    set(o, "n", jv3(n))
    set(o, "half", jv3(h))
    set(o, "round", jf(round))
    set(o, "mat", jstr(m))
    shapes.push(o)

let FRONT = float3 { 0.0, 1.0, 0.0 }
let SIDE = float3 { 1.0, 0.0, 0.0 }
let UP = float3 { 0.0, 0.0, 1.0 }

def wall(c:float3, half:float3, m:string): box(c, half, FRONT, m, 0.3)

def cap(a:float3, b:float3, r:float2, m:string, hard:bool):
    let o = jset(jobj(), "cap", jpt(a))
    set(o, "to", jpt(b))
    set(o, "r", jarr([ jf(r.x), jf(r.y) ]))
    set(o, "mat", jstr(m))
    set(o, "hard", jbool(hard))
    shapes.push(o)

def ball(c:float3, r:float, m:string, hard:bool):
    let o = jset(jobj(), "ball", jpt(c))
    set(o, "r", jf(r))
    set(o, "mat", jstr(m))
    set(o, "hard", jbool(hard))
    shapes.push(o)

def disc(c:float3, n:float3, r:float, thick:float, m:string):
    let o = jset(jobj(), "disc", jpt(c))
    set(o, "n", jv3(n))
    set(o, "r", jarr([ jf(r), jf(thick) ]))
    set(o, "mat", jstr(m))
    shapes.push(o)

// A gable roof over a w x d (half sizes) box from eave height z0 up `rise`, the ridge along x (or y), overhanging by
// `over`: two sloped planes (the material's pattern lays the tiles or ripples down them), a ridge, and the gable ends
// filled under it.
def gable_roof(w:float, d:float, z0:float, rise:float, over:float, m:string, ridge:string, along_y:bool):
    let run = (if along_y: w else: d) + over
    let ang = atan2(float2 { run, rise })
    let slope = sqrt(run * run + rise * rise)
    let span = (if along_y: d else: w) + over * 0.5
    def across(a:float, z:float) -> float3: return if along_y: float3 { a, 0.0, z } else: float3 { 0.0, a, z }
    for([ 1.0, -1.0 ]) s:
        let n = if along_y: float3 { s * sin(ang), 0.0, cos(ang) } else: float3 { 0.0, s * sin(ang), cos(ang) }
        box(across(s * run / 2.0, z0 + rise / 2.0), float3 { span, 1.1, slope / 2.0 }, n, m, 0.2)
        let k = 8.2
        box(across(s * (run / 2.0 - k * sin(ang)), z0 + rise / 2.0 - k * cos(ang)), float3 { span - over * 0.5, 8.0, slope / 2.0 - 2.5 }, n, "plaster", 0.0)
    let e = if along_y: float3 { 0.0, span, 0.0 } else: float3 { span, 0.0, 0.0 }
    cap(float3 { 0.0, 0.0, z0 + rise + 1.0 } - e, float3 { 0.0, 0.0, z0 + rise + 1.0 } + e, float2 { 1.8, 1.8 }, ridge, true)

// A rock of flat cut faces: boxes at angles, a few overlapping, the edges barely rounded.
def facet_rock(cx:float, cy:float, size:float, seed:int, m:string):
    var rnd = (seed * 9301 + 49297) % 233280
    def r() -> float:
        rnd = (rnd * 9301 + 49297) % 233280
        return float(rnd) / 233280.0
    for(4):
        let n = float3 { r() - 0.5, r() - 0.5, 0.6 + r() * 0.4 }
        let h = float3 { size * (0.5 + r() * 0.5), size * (0.45 + r() * 0.4), size * (0.35 + r() * 0.3) }
        let x = cx + (r() - 0.5) * size
        let y = cy + (r() - 0.5) * size
        box(float3 { x, y, h.z * 0.8 }, h, n, m, 0.25)

def barrel(x:float, y:float):
    cap(float3 { x, y, 1.04 }, float3 { x, y, 4.96 }, float2 { 2.6, 2.6 }, "timber", false)
    disc(float3 { x, y, 1.2 }, UP, 2.85, 0.35, "steel")
    disc(float3 { x, y, 4.8 }, UP, 2.85, 0.35, "steel")

def firewood(x:float, y:float):
    for(3) row: for(3 - row) k:
        let yy = y + (float(k) - float(3 - row - 1) / 2.0) * 2.3
        cap(float3 { x - 4.0, yy, 1.1 + float(row) * 2.0 }, float3 { x + 4.0, yy, 1.1 + float(row) * 2.0 }, float2 { 1.1, 1.1 }, "bark", true)

def amphora(x:float, y:float, z:float):
    ball(float3 { x, y, z + 3.5 }, 3.1, "pot", false)
    cap(float3 { x, y, z + 5.5 }, float3 { x, y, z + 9.0 }, float2 { 1.25, 1.55 }, "pot", true)

// A body's file: its doc, size, the one point, a shape a line, and any other fields (crew, seats, styles, legs...).
def vxw_body(path:string, doc:string, size:float, extra:[string]):
    let lines = []::string
    for(shapes) o: lines.push("  " + stringify(o))
    var more = ""
    for(extra) e: more += " " + e + ",\n"
    let text = "\{\n \"_doc\": \"{json_escape(doc)}\",\n \"size\": {godot_float(size)},\n" + more + " \"points\": \{\"o\": \{\"at\": [0, 0, 0]\}\},\n \"shapes\": [\n" + concat_string(lines, ",\n") + "\n ]\n\}\n"
    write_file(path, text)
    print "{path}: {shapes.length} shapes"
    shapes = []
