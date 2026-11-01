// Procedural voxel units, a prototype: a body as capsules blended on a posed skeleton, filled into a voxel grid at
// one voxel per art pixel, drawn in the game's 3/4 view in 8 facings with face shading and an outline.
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter point -resize 400% out.png)
import std
import vec

let ELEV = 30.0              // the camera's elevation, degrees
let CELL = int2 { 48, 66 }   // a sprite cell at game scale
let BLEND = 2.2              // how far shapes melt into each other, voxels

enum mat_kind:
    mat_skin, mat_tunic, mat_trousers, mat_leather, mat_hair, mat_wood, mat_metal, mat_coat, mat_mane, mat_team, mat_eye

let MAT_COLS = [
    float3 { 0.86, 0.66, 0.50 },   // skin
    float3 { 0.60, 0.55, 0.42 },   // tunic (undyed)
    float3 { 0.36, 0.30, 0.24 },   // trousers
    float3 { 0.45, 0.30, 0.17 },   // leather
    float3 { 0.42, 0.25, 0.12 },   // hair
    float3 { 0.55, 0.38, 0.20 },   // wood
    float3 { 0.70, 0.72, 0.76 },   // metal
    float3 { 0.50, 0.32, 0.19 },   // a horse's coat
    float3 { 0.20, 0.14, 0.10 },   // mane and tail
    float3 { 0.80, 0.16, 0.13 },   // team colour
    float3 { 0.12, 0.08, 0.06 },   // eyes
]

enum team_look:
    team_tunic, team_trim, team_sash

var team_style = team_tunic   // (Dominic, 2026-11-01: the whole tunic)

def cloth() -> int: return if team_style == team_tunic: mat_team else: mat_tunic

class prim:
    a:float3
    b:float3
    ra:float
    rb:float
    mat:int
    hard:bool   // gear: no melting into the body

def dist(p:float3, s:prim) -> float:
    let ba = s.b - s.a
    let l2 = dot(ba, ba)
    let h = if l2 > 0.0: clamp(dot(p - s.a, ba) / l2, 0.0, 1.0) else: 0.0
    return magnitude(p - s.a - ba * h) - (s.ra + (s.rb - s.ra) * h)

def smin(a:float, b:float, k:float) -> float:
    let h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

// A limb bent forward by `deg` (0 hangs straight down).
def down(deg:float) -> float3: return float3 { 0.0, sin(deg), -cos(deg) }

// ---- bodies: parts as capsules on a posed skeleton (z up, y forward, x right)

// Legs from hips: thigh swing and knee bend for a walk phase; returns the lowest point to stand on.
def leg(out:[prim], hip:float3, swing:float, bend:float, thigh:float, shin:float, r:float, m:int, boot:int):
    let knee = hip + down(swing) * thigh
    let ankle = knee + down(swing - bend) * shin
    out.push(prim { hip, knee, r, r * 0.8, m, false })
    out.push(prim { knee, ankle, r * 0.8, r * 0.6, boot, false })
    out.push(prim { ankle, ankle + float3 { 0.0, 2.6, -0.6 }, r * 0.65, r * 0.55, boot, false })

def arm(out:[prim], shoulder:float3, side:float, swing:float, bend:float, r:float) -> float3:
    let elbow = shoulder + down(swing) * 7.5 + float3 { side * 0.6, 0.0, 0.0 }
    let wrist = elbow + down(swing + bend) * 7.0
    out.push(prim { shoulder, elbow, r, r * 0.85, cloth(), false })
    out.push(prim { elbow, wrist, r * 0.85, r * 0.7, mat_skin, false })
    out.push(prim { wrist, wrist + down(swing + bend) * 1.2, 1.3, 1.1, mat_skin, false })
    return wrist + down(swing + bend) * 0.8

// A heroic human from the hips up, its pelvis at p (the centaur's torso too).
def torso(out:[prim], p:float3, ph:float, lean:float) -> float3:
    let chest = p + float3 { 0.0, sin(lean) * 11.0, cos(lean) * 11.0 }
    out.push(prim { p, chest, 4.0, 4.7, cloth(), false })
    let yoke = if team_style == team_trim: mat_team else: cloth()
    out.push(prim { chest + float3 { -5.4, 0.0, -0.6 }, chest + float3 { 5.4, 0.0, -0.6 }, 2.1, 2.1, yoke, false })
    if team_style == team_sash:
        out.push(prim { chest + float3 { -3.6, 0.0, 0.2 }, p + float3 { 3.4, 0.0, -0.4 }, 4.75, 4.15, mat_team, true })
    let neck = chest + float3 { 0.0, 0.3, 2.2 }
    out.push(prim { chest, neck + float3 { 0.0, 0.0, 0.8 }, 1.9, 1.7, mat_skin, false })
    let head = neck + float3 { 0.0, 0.5, 3.6 }   // the head's centre: a little taller than wide, the jaw forward
    out.push(prim { head + float3 { 0.0, 0.5, -1.2 }, head + float3 { 0.0, 0.0, 0.8 }, 2.7, 3.1, mat_skin, false })
    out.push(prim { head + float3 { 0.0, 3.0, -0.3 }, head + float3 { 0.0, 3.3, -0.7 }, 0.6, 0.5, mat_skin, false })   // nose
    for([ -1.0, 1.0 ]) side:   // eyes, a pixel each
        out.push(prim { head + float3 { side * 1.15, 2.75, 0.35 }, head + float3 { side * 1.15, 2.75, 0.35 }, 0.45, 0.45, mat_eye, true })
    out.push(prim { head + float3 { 0.0, -0.7, 0.9 }, head + float3 { 0.0, -0.9, 0.4 }, 3.35, 3.35, mat_hair, true })   // hair: a cap on the top and back
    let sw = 22.0 * sin(ph)
    arm(out, chest + float3 { -5.6, 0.0, -0.8 }, -1.0, -sw, 15.0, 1.8)
    return arm(out, chest + float3 { 5.6, 0.0, -0.8 }, 1.0, sw, 25.0, 1.8)

def axe(out:[prim], hand:float3, tilt:float):
    let d = float3 { 0.0, sin(tilt), cos(tilt) }
    let top = hand + d * 9.0
    out.push(prim { hand - d * 2.5, top, 0.55, 0.55, mat_wood, true })
    out.push(prim { top - d * 1.0 + float3 { 0.0, 0.6, 0.0 }, top + float3 { 0.0, 3.2, -0.6 }, 1.1, 1.8, mat_metal, true })

def human(ph:float) -> [prim]:
    let out = []::prim
    let s = 26.0 * sin(ph)
    let bend = 40.0 * max(0.0, sin(ph + 90.0))
    let bend2 = 40.0 * max(0.0, sin(ph - 90.0))
    let hip = float3 { 0.0, 0.0, 21.0 + 0.6 * abs(sin(ph * 2.0)) }
    leg(out, hip + float3 { -2.9, 0.0, 0.0 }, s, bend, 10.5, 10.0, 2.6, mat_trousers, mat_leather)
    leg(out, hip + float3 { 2.9, 0.0, 0.0 }, -s, bend2, 10.5, 10.0, 2.6, mat_trousers, mat_leather)
    out.push(prim { hip + float3 { 0.0, 0.0, -1.0 }, hip + float3 { 0.0, 0.0, 2.0 }, 4.3, 4.4, if team_style == team_trim: mat_team else: mat_leather, false })   // belt
    let hand = torso(out, hip + float3 { 0.0, 0.0, 1.0 }, ph, 4.0)
    axe(out, hand, 60.0 + 20.0 * sin(ph))
    return out

def centaur(ph:float) -> [prim]:
    let out = []::prim
    let front = float3 { 0.0, 7.5, 20.0 }
    let back = float3 { 0.0, -8.5, 20.5 }
    out.push(prim { back, front, 6.2, 6.6, mat_coat, false })                                              // barrel
    out.push(prim { back + float3 { 0.0, -1.5, 1.5 }, back + float3 { 0.0, -6.0, -5.0 }, 1.4, 0.9, mat_mane, true })   // tail
    let s = 24.0 * sin(ph)
    for([ -1.0, 1.0 ]) side:
        let lift = 30.0 * max(0.0, sin(ph + 90.0 * side))
        leg(out, front + float3 { side * 3.2, 1.0, -2.0 }, s * side, lift, 9.0, 9.5, 2.3, mat_coat, mat_mane)
        leg(out, back + float3 { side * 3.4, -1.0, -2.0 }, -s * side, lift * 0.8, 9.5, 9.0, 2.6, mat_coat, mat_mane)
    out.push(prim { front + float3 { 0.0, 1.0, 1.0 }, front + float3 { 0.0, 1.8, 7.0 }, 5.2, 4.4, mat_coat, false })   // where horse meets man
    let hand = torso(out, front + float3 { 0.0, 2.0, 7.0 }, ph, 6.0)
    axe(out, hand, 70.0)
    return out

// ---- the voxel grid: one voxel per art pixel

let GRID = int3 { 40, 44, 60 }
let ORIGIN = float3 { -20.0, -22.0, -1.0 }

// The whole shape's distance at p, and the material of the part nearest it.
def field(ps:[prim], p:float3) -> float, int:
    var body = 1000.0
    var gear = 1000.0
    var near = 1000.0
    var m = -1
    for(ps) s:
        let d = dist(p, s)
        if s.hard: gear = min(gear, d)
        else: body = smin(body, d, BLEND)
        if d < near:
            near = d
            m = s.mat
    return min(body, gear), m

var normals = []::float3   // per filled voxel: the shape's smooth normal (the grid's stairs would speckle the shading)

def fill(ps:[prim]) -> [int]:
    let g = map(GRID.x * GRID.y * GRID.z): -1
    normals = map(GRID.x * GRID.y * GRID.z): float3_0
    var low = 1000.0
    for(ps) s: low = min(low, min(s.a.z - s.ra, s.b.z - s.rb))
    for(GRID.z) z: for(GRID.y) y: for(GRID.x) x:
        let p = ORIGIN + float(int3 { x, y, z }) + float3_1 * 0.5 + float3 { 0.0, 0.0, low }
        let d, m = field(ps, p)
        if d <= 0.0:
            let i = (z * GRID.y + y) * GRID.x + x
            g[i] = m
            if d > -1.8:
                let e = 0.5
                let dx, mx = field(ps, p + float3 { e, 0.0, 0.0 })
                let dy, my = field(ps, p + float3 { 0.0, e, 0.0 })
                let dz, mz = field(ps, p + float3 { 0.0, 0.0, e })
                normals[i] = normalize(float3 { dx - d, dy - d, dz - d })
    return g

def at(g:[int], v:int3) -> int:
    if any(v < int3_0) or any(v >= GRID): return -1
    return g[(v.z * GRID.y + v.y) * GRID.x + v.x]

// ---- drawing: a ray per pixel through the grid; the face it enters gives the shade

def draw(g:[int], facing:int, img:[float3], iw:int, cx:int, cy:int):
    let yaw = float(facing) * 45.0
    let fwd = float3 { 0.0, cos(ELEV), -sin(ELEV) }
    let upv = float3 { 0.0, sin(ELEV), cos(ELEV) }
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let centre = float3 { 0.0, 0.0, 25.0 } - ORIGIN
    let light = normalize(float3 { -0.75, -0.45, 0.6 })
    let shade = map(CELL.x * CELL.y): -1
    let cols = map(CELL.x * CELL.y): float3_0
    for(CELL.y) py: for(CELL.x) px:
        let u = float(px - CELL.x / 2)
        let v = float(CELL.y / 2 - py) - 2.0
        var o = centre + rot(float3 { u, 0.0, 0.0 } + upv * v - fwd * 60.0)
        let d = rot(fwd) * 0.25
        var last = int3 { -9, -9, -9 }
        for(500):
            let c = int3 { int(floor(o.x)), int(floor(o.y)), int(floor(o.z)) }
            if c != last:
                let m = at(g, c)
                if m >= 0:
                    let n = normals[(c.z * GRID.y + c.y) * GRID.x + c.x]
                    let k = dot(n, rot(light)) * 0.5 + 0.5
                    let band = if k > 0.8: 1.15 elif k > 0.58: 0.95 elif k > 0.36: 0.75 else: 0.56
                    cols[py * CELL.x + px] = MAT_COLS[m] * band
                    shade[py * CELL.x + px] = m
                    break
                last = c
            o += d
    for(CELL.y) py: for(CELL.x) px:
        let i = py * CELL.x + px
        var col = img[(cy + py) * iw + cx + px]
        if shade[i] >= 0: col = cols[i]
        else:
            for([ int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 } ]) dd:
                let q = int2 { px, py } + dd
                if q.x >= 0 and q.y >= 0 and q.x < CELL.x and q.y < CELL.y and shade[q.y * CELL.x + q.x] >= 0:
                    col = MAT_COLS[shade[q.y * CELL.x + q.x]] * 0.3
        img[(cy + py) * iw + cx + px] = col

// ---- the sheet: per unit a row of 8 facings standing, a row of the walk in facing 1

let out_path = if command_line_arguments().length: command_line_arguments()[0] else: "voxel_proto.ppm"
class row:
    body:string
    look:team_look
    walk:bool

let rows = [ row { "human", team_tunic, false }, row { "human", team_tunic, true }, row { "centaur", team_tunic, false },
             row { "centaur", team_tunic, true } ]
let iw = CELL.x * 8
let ih = CELL.y * rows.length
let img = map(iw * ih): float3 { 0.33, 0.47, 0.18 }
for(rows) rw, r:
    let name = rw.body
    team_style = rw.look
    let make = fn(ph:float) -> [prim]: if name == "human": human(ph) else: centaur(ph)
    if not rw.walk:
        let stand = fill(make(0.0))
        for(8) f: draw(stand, f, img, iw, f * CELL.x, r * CELL.y)
    else:
        for(8) k: draw(fill(make(float(k) * 45.0)), 1, img, iw, k * CELL.x, r * CELL.y)
let ppm = "P6\n{iw} {ih}\n255\n"
let bytes = []::int
for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
print "wrote {out_path}"
