// Voxel buildings, an experiment (Dominic, 2026-11-03: "test a few buildings, see how close we can make them using
// voxels"; then "textures and lights real issue"). Writes data/voxel/buildings/: materials (colours, and surface
// patterns: stone blocks, planks, corrugated sheet with rust, roof tiles, worn plaster, mottle; lights that glow) and
// bodies (the voxel format's points and shapes, a shape a line) for a Roman house and Town Center, the rats' shack and
// silo, two trees and a rock. The game doesn't load the folder; voxel_buildings.lobster draws them. Body units: z up,
// y to the front, x across; a tile is about 62. Each is drawn facing as the game's baked one is (its front to the
// lower left).
//   lobster voxel_buildings_gen.lobster
import std
import vec
import dictionary
import gen.json

let OUT = "../data/voxel/buildings"

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

mat("plaster", "#e6dfd0", false, pat("wear", float2_1, 0.16, 0.55, "#8f7f63"))
mat("plaster_lit", "#f2ece0", false, pat("wear", float2_1, 0.12, 0.4, "#8f7f63"))
mat("stone", "#b3ab9b", false, pat("blocks", float2 { 6.5, 3.2 }, 0.12, 1.0, "#78705f"))
mat("paving", "#a9a395", false, pat("blocks", float2 { 7.5, 7.5 }, 0.1, 1.0, "#6f6a5e"))
mat("stone_dark", "#8c8475", false, pat("mottle", float2_1, 0.3, 0.0, "#000000"))
mat("tile", "#b4482c", true, pat("tiles", float2 { 3.0, 3.2 }, 0.14, 0.3, "#6d6236"))
mat("tile_dark", "#8a3320", false, pat("tiles", float2 { 3.0, 3.2 }, 0.1, 0.0, "#000000"))
mat("timber", "#7a5230", false, pat("planks", float2 { 4.5, 1.0 }, 0.14, 1.0, "#2e1e12"))
mat("timber_dark", "#4e321e", false, pat("planks", float2 { 3.0, 1.0 }, 0.12, 1.0, "#22160d"))
mat("crate", "#9a6c3c", false, pat("planks", float2 { 2.2, 1.0 }, 0.14, 1.0, "#3a2614"))
glow("glass", "#ffe9a0")
glow("fire", "#ffb040")
mat("shutter", "#a33f2a", false, pat("planks", float2 { 1.4, 1.0 }, 0.1, 1.0, "#5a2014"))
mat("sheet", "#b9bdc3", false, pat("ripples", float2 { 0.55, 26.0 }, 0.2, 0.6, "#9a5a30"))
let round_sheet = pat("ripples", float2 { 0.55, 40.0 }, 0.2, 0.8, "#9a5a30")
set(round_sheet, "round", jbool(true))
mat("sheet_round", "#b9bdc3", false, round_sheet)
mat("sheet_dark", "#80858d", false, pat("ripples", float2 { 0.55, 26.0 }, 0.2, 0.7, "#7a4424"))
mat("steel", "#a7acb4", false, nil)
mat("pipe", "#2c2a2a", false, nil)
mat("cheese", "#f0c23c", false, pat("mottle", float2_1, 0.12, 0.0, "#000000"))
mat("sack", "#c9b58a", false, pat("mottle", float2_1, 0.2, 0.0, "#000000"))
mat("leaf", "#3f6b29", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("leaf_dark", "#2b4c1d", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("cypress", "#24401f", true, pat("mottle", float2_1, 0.35, 0.0, "#000000"))
mat("bark", "#5a4030", false, pat("planks", float2 { 1.2, 1.0 }, 0.2, 0.6, "#2e1e12"))
mat("rock", "#c4b69a", false, pat("mottle", float2_1, 0.28, 0.0, "#000000"))
mat("rock_dark", "#8d877a", false, pat("mottle", float2_1, 0.28, 0.0, "#000000"))
mat("pot", "#b0582e", false, pat("mottle", float2_1, 0.15, 0.0, "#000000"))
mat("team", "#cc2921", false, nil)

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

def roman_house():
    box(float3 { 0.0, 0.0, 2.5 }, float3 { 38.0, 30.0, 2.5 }, FRONT, "stone", 0.5)
    wall(float3 { 0.0, 0.0, 21.0 }, float3 { 33.0, 25.0, 16.0 }, "plaster")
    gable_roof(33.0, 25.0, 37.0, 17.0, 5.0, "tile", "tile_dark", false)
    wall(float3 { -8.0, 25.6, 12.0 }, float3 { 5.0, 0.8, 9.5 }, "timber_dark")
    wall(float3 { -8.0, 26.2, 22.5 }, float3 { 6.5, 0.8, 1.2 }, "stone")
    for([ -8.0, 8.0 ]) y:  // the gable end to the lower right: two shuttered, lit windows
        box(float3 { -33.6, y, 24.0 }, float3 { 0.7, 3.0, 4.5 }, SIDE, "glass", 0.3)
        box(float3 { -33.9, y - 4.6, 24.0 }, float3 { 0.7, 1.5, 4.8 }, SIDE, "shutter", 0.3)
        box(float3 { -33.9, y + 4.6, 24.0 }, float3 { 0.7, 1.5, 4.8 }, SIDE, "shutter", 0.3)
    wall(float3 { 0.0, 25.4, 35.5 }, float3 { 33.0, 0.9, 1.2 }, "team")
    wall(float3 { 20.0, -10.0, 58.0 }, float3 { 2.6, 2.6, 9.0 }, "stone_dark")
    wall(float3 { 20.0, -10.0, 67.5 }, float3 { 3.4, 3.4, 0.8 }, "stone")
    amphora(-20.0, 31.0, 4.0)
    wall(float3 { 14.0, 31.0, 4.5 }, float3 { 3.2, 2.4, 0.5 }, "timber")  // a stool
    for([ -2.6, 2.6 ]) dx: for([ -1.8, 1.8 ]) dy:
        cap(float3 { 14.0 + dx, 31.0 + dy, 0.0 }, float3 { 14.0 + dx, 31.0 + dy, 4.2 }, float2 { 0.4, 0.4 }, "timber_dark", true)
    facet_rock(30.0, 33.0, 2.4, 3, "rock_dark")

def roman_tc():
    box(float3 { 0.0, 0.0, 3.0 }, float3 { 52.0, 62.0, 3.0 }, FRONT, "paving", 0.6)
    for(3) k: wall(float3 { 0.0, 65.0 + float(k) * 3.5, 1.0 + float(k) * 2.0 }, float3 { 30.0, 3.5 - float(k) * 0.5, 1.0 + float(k) * 2.0 }, "stone")
    wall(float3 { 0.0, -8.0, 30.0 }, float3 { 40.0, 42.0, 24.0 }, "plaster")
    gable_roof(46.0, 58.0, 54.0, 20.0, 4.0, "tile", "tile_dark", true)
    for([ -36.0, -12.0, 12.0, 36.0 ]) x:  // the portico's columns
        cap(float3 { x, 50.0, 6.0 }, float3 { x, 50.0, 52.0 }, float2 { 3.2, 2.8 }, "plaster_lit", false)
        wall(float3 { x, 50.0, 7.0 }, float3 { 4.2, 4.2, 1.2 }, "stone")
        wall(float3 { x, 50.0, 52.5 }, float3 { 4.2, 4.2, 1.2 }, "stone")
    wall(float3 { 0.0, 50.0, 55.0 }, float3 { 47.0, 4.0, 2.0 }, "plaster")
    wall(float3 { 0.0, 54.2, 55.0 }, float3 { 47.0, 0.8, 0.9 }, "team")
    disc(float3 { 0.0, 58.0, 63.0 }, float3 { 0.0, 1.0, 0.25 }, 5.0, 0.8, "team")
    wall(float3 { 0.0, 34.4, 20.0 }, float3 { 8.0, 0.8, 14.0 }, "timber_dark")
    for([ -30.0, -6.0, 18.0 ]) y: box(float3 { -40.6, y, 32.0 }, float3 { 0.7, 4.0, 6.0 }, SIDE, "glass", 0.3)  // the long side: lit windows
    box(float3 { -40.4, -8.0, 52.0 }, float3 { 0.9, 42.0, 1.4 }, SIDE, "team", 0.3)
    cap(float3 { -46.0, 66.0, 0.0 }, float3 { -46.0, 66.0, 60.0 }, float2 { 0.9, 0.7 }, "timber_dark", true)  // the flag pole
    ball(float3 { -46.0, 66.0, 61.0 }, 1.4, "pot", true)
    for([ 0.0, 120.0, 240.0 ]) a:  // a brazier on the steps, its fire alight
        cap(float3 { 22.0 + 2.4 * cos(a), 70.0 + 2.4 * sin(a), 0.0 }, float3 { 22.0, 70.0, 9.0 }, float2 { 0.4, 0.4 }, "timber_dark", true)
    disc(float3 { 22.0, 70.0, 9.5 }, UP, 3.4, 0.7, "steel")
    ball(float3 { 22.0, 70.0, 11.0 }, 2.4, "fire", true)
    amphora(-30.0, 70.0, 0.0)

def rat_shack():
    box(float3 { 0.0, 0.0, 1.0 }, float3 { 40.0, 30.0, 1.0 }, FRONT, "stone_dark", 0.4)
    wall(float3 { 0.0, 0.0, 19.0 }, float3 { 36.0, 26.0, 17.0 }, "timber")
    let ang = atan2(float2 { 31.0, 15.0 })
    for([ 1.0, -1.0 ]) side:  // the roof: two slopes of corrugated sheet
        box(float3 { 0.0, side * 15.5, 44.0 }, float3 { 41.0, 1.1, sqrt(31.0 * 31.0 + 15.0 * 15.0) / 2.0 }, float3 { 0.0, side * sin(ang), cos(ang) }, "sheet", 0.1)
    cap(float3 { -41.0, 0.0, 52.0 }, float3 { 41.0, 0.0, 52.0 }, float2 { 1.2, 1.2 }, "sheet_dark", true)
    wall(float3 { 0.0, 0.0, 40.0 }, float3 { 36.0, 12.0, 4.0 }, "timber")
    box(float3 { -36.3, 0.0, 44.0 }, float3 { 0.6, 14.0, 4.0 }, SIDE, "timber", 0.3)
    wall(float3 { -10.0, 26.4, 12.0 }, float3 { 5.0, 0.8, 10.0 }, "timber_dark")
    for(3) k: wall(float3 { -10.0, 29.0 + float(k) * 2.2, 0.6 + float(k) * 1.2 }, float3 { 6.0, 1.1, 0.6 + float(k) * 1.2 }, "timber_dark")
    wall(float3 { 14.0, 26.4, 24.0 }, float3 { 4.5, 0.6, 4.5 }, "glass")
    box(float3 { -36.6, -9.0, 24.0 }, float3 { 0.6, 4.5, 4.5 }, SIDE, "glass", 0.3)
    box(float3 { -36.6, 9.0, 24.0 }, float3 { 0.6, 4.5, 4.5 }, SIDE, "glass", 0.3)
    box(float3 { -37.0, 0.0, 15.0 }, float3 { 0.8, 7.0, 15.0 }, SIDE, "sheet_dark", 0.1)  // a patch of sheet on the gable
    cap(float3 { 22.0, -10.0, 40.0 }, float3 { 22.0, -10.0, 64.0 }, float2 { 2.6, 2.6 }, "pipe", true)
    cap(float3 { 22.0, -10.0, 64.0 }, float3 { 27.0, -10.0, 68.0 }, float2 { 2.6, 2.4 }, "pipe", true)
    disc(float3 { 34.0, 30.0, 5.0 }, float3 { 0.3, 1.0, 0.0 }, 5.5, 2.6, "cheese")
    barrel(-26.0, 31.0)
    box(float3 { -32.0, 22.0, 3.2 }, float3 { 3.2, 3.2, 3.2 }, float3 { 0.25, 1.0, 0.0 }, "crate", 0.2)
    firewood(26.0, 31.0)
    facet_rock(-18.0, 34.0, 3.6, 7, "rock")
    facet_rock(4.0, 34.0, 3.0, 11, "rock")
    ball(float3 { -40.0, 10.0, 3.0 }, 3.2, "sack", false)
    wall(float3 { 0.0, 26.2, 36.0 }, float3 { 36.0, 0.8, 1.0 }, "team")

def rat_silo():
    disc(float3 { 0.0, 0.0, 1.0 }, UP, 25.0, 1.0, "stone_dark")
    disc(float3 { 0.0, 0.0, 23.0 }, UP, 22.0, 21.0, "sheet_round")
    for([ 14.0, 32.0 ]) z: disc(float3 { 0.0, 0.0, z }, UP, 22.9, 0.9, "steel")  // two hoops
    disc(float3 { 0.0, 0.0, 44.7 }, UP, 23.2, 0.8, "sheet")                      // the flat lid, a stone on it
    facet_rock(6.0, -4.0, 3.2, 5, "rock")
    cap(float3 { -6.0, -2.0, 45.0 }, float3 { -6.0, -2.0, 54.0 }, float2 { 1.5, 1.5 }, "pipe", true)
    box(float3 { -2.0, 23.0, 14.0 }, float3 { 7.0, 1.4, 11.0 }, float3 { 0.1, 1.0, 0.0 }, "pipe", 0.2)  // the door
    box(float3 { -13.0, 23.8, 15.0 }, float3 { 4.5, 1.2, 12.0 }, float3 { 0.45, 1.0, 0.0 }, "sheet_dark", 0.1)
    box(float3 { 14.0, 18.5, 24.0 }, float3 { 2.4, 0.6, 2.0 }, float3 { 0.6, 0.8, 0.0 }, "team", 0.3)

def cypress():
    cap(float3_0, float3 { 0.0, 0.0, 10.0 }, float2 { 1.6, 1.2 }, "bark", true)
    for(9) k:
        let r = 8.5 * sin(180.0 * float(k + 1) / 10.0) + 1.2
        ball(float3 { 0.3 * float(k % 2), 0.0, 8.0 + float(k) * 6.0 }, r, if k % 3 != 0: "cypress" else: "leaf_dark", false)

def broadleaf():
    cap(float3_0, float3 { 0.0, 0.0, 22.0 }, float2 { 3.0, 2.0 }, "bark", false)
    cap(float3 { 0.0, 0.0, 18.0 }, float3 { 7.0, 3.0, 28.0 }, float2 { 1.4, 1.0 }, "bark", true)
    cap(float3 { 0.0, 0.0, 18.0 }, float3 { -6.0, -4.0, 27.0 }, float2 { 1.4, 1.0 }, "bark", true)
    for([ float4 { 0.0, 0.0, 34.0, 12.0 }, float4 { 9.0, 4.0, 30.0, 9.0 }, float4 { -9.0, -3.0, 30.0, 9.0 }, float4 { 4.0, -9.0, 32.0, 8.0 },
          float4 { -4.0, 9.0, 32.0, 8.0 }, float4 { 2.0, 2.0, 42.0, 8.0 }, float4 { -7.0, 6.0, 38.0, 7.0 }, float4 { 7.0, -6.0, 38.0, 7.0 } ]) b, k:
        ball(xyz(b), b.w, if k % 2 == 0: "leaf" else: "leaf_dark", false)

def rock():
    facet_rock(0.0, 0.0, 7.0, 1, "rock")
    facet_rock(9.0, 4.0, 4.5, 2, "rock")
    facet_rock(-7.0, 5.0, 3.5, 4, "rock")

// A body's file: its doc, size, the one point, a shape a line.
def write_body(name:string, doc:string, size:float):
    let lines = []::string
    for(shapes) o: lines.push("  " + stringify(o))
    let text = "\{\n \"_doc\": \"{json_escape(doc)}\",\n \"size\": {godot_float(size)},\n \"points\": \{\"o\": \{\"at\": [0, 0, 0]\}\},\n \"shapes\": [\n" + concat_string(lines, ",\n") + "\n ]\n\}\n"
    write_file(OUT + "/bodies/" + name + ".json", text)
    print "{name}: {shapes.length} shapes"
    shapes = []

write_file(OUT + "/materials.json", "\{\n \"_doc\": \"The voxel buildings\' materials (an experiment: the game doesn\'t load this folder). pattern: a surface texture in the colour (view/voxel.lobster, vx_patterned): blocks, planks, ripples, tiles, wear, mottle; size in body units; glow: a light.\",\n " + concat_string(mats, ",\n ") + "\n\}\n")
roman_house()
write_body("roman_house", "A Roman house (2 tiles): plaster on a stone plinth, a red tile gable roof, a door, shuttered lit windows, the team\'s band under the eaves, a chimney, an amphora and a stool.", 1.0)
roman_tc()
write_body("roman_tc", "A Roman Town Center (3 tiles): a temple on a paved podium with steps, four columns, a tiled roof along its length, lit windows, the team\'s band and disc, a flag, a brazier, an amphora.", 1.0)
rat_shack()
write_body("rat_shack", "The rats\' Town Center: a timber shack under a roof of corrugated sheet (two slopes, rust), a stove pipe, lit windows, a sheet patch on the gable, steps, a cheese wheel, a barrel, a crate, firewood, rocks and a sack at the door, the team\'s band under the eaves.", 1.0)
rat_silo()
write_body("rat_silo", "The rats\' silo: a round tank of corrugated sheet with two steel hoops, a flat corrugated lid with a stone on it, a vent pipe, a dark door with a sheet panel leant beside it, the team\'s plate.", 1.0)
cypress()
write_body("cypress", "A cypress: a dark green spire of melted balls on a short trunk.", 1.7)
broadleaf()
write_body("broadleaf", "A broadleaf tree: a crown of melted balls on a forked trunk.", 1.6)
rock()
write_body("rock", "Rocks of flat cut faces: boxes at angles, overlapping, mottled.", 2.2)
