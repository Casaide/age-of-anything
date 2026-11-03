// The engines with a crew as voxel bodies (data/voxel/bodies/siege.*.json): the ram, catapult, bolt thrower, siege
// tower, great sling and trade cart, each in every culture's style (its frame, iron and cloth colours: `styles`), with
// its crew's spots; and the war beasts (elephant, boar, heron, mantis, tarantula) with their howdahs and seats. The
// crew is the race's own creature in its own kit (the recipe's `crew`). Body units: z up, y to the front, x across.
//   lobster voxel_engines_gen.lobster
import std
import vec
import dictionary
import gen.json
import gen.vx_write

let OUT = "../data/voxel/bodies/"

// Each style's frame (planks), iron and cloth.
let STYLES = "\"styles\": \{\"timber\": \{\"skin\": \"#8c6133\", \"pale\": \"#4a4a50\", \"mark\": \"#9a7a50\"\}, \"junk\": \{\"skin\": \"#7a6a58\", \"pale\": \"#8a5a3a\", \"mark\": \"#8a9098\"\}, \"frog\": \{\"skin\": \"#8a8a40\", \"pale\": \"#4f5e2a\", \"mark\": \"#5e8a3a\"\}, \"forest\": \{\"skin\": \"#6b4a2a\", \"pale\": \"#3e4a2c\", \"mark\": \"#4a6a30\"\}, \"spooky\": \{\"skin\": \"#d8d0bc\", \"pale\": \"#3a3238\", \"mark\": \"#5a3a5a\"\}\}"
let HOWDAH = "\"styles\": \{\"howdah\": \{\"skin\": \"#8c6133\", \"pale\": \"#4a3a2a\", \"mark\": \"#8a3a2a\"\}\}"

def spots(name:string, ps:[float3]) -> string: return "\"{name}\": " + stringify(jarr(map(ps) p: jv3(p)))

// A mirrored pair: the shape at x and at -x.
def pair_cap(a:float3, b:float3, r:float2, m:string, hard:bool):
    cap(a, b, r, m, hard)
    cap(a * float3 { -1.0, 1.0, 1.0 }, b * float3 { -1.0, 1.0, 1.0 }, r, m, hard)

def wheel(c:float3, r:float):
    disc(c, SIDE, r, 1.1, "frame2")
    disc(c + float3 { if c.x > 0.0: 0.6 else: -0.6, 0.0, 0.0 }, SIDE, r * 0.3, 1.0, "frame")

// A pair of legs on "o" (the format's legs), as a JSON object.
def leg(hip:float3, foot:float3, bones:float2, pole:float3, r:float4, ms:[string], stride:float, lift:float, phase:float) -> JV:
    let o = jset(jobj(), "hip", jarr([ jstr("o"), jf(hip.x), jf(hip.y), jf(hip.z) ]))
    set(o, "foot", jv3(foot))
    set(o, "bones", jarr([ jf(bones.x), jf(bones.y) ]))
    set(o, "pole", jv3(pole))
    set(o, "r", jarr([ jf(r.x), jf(r.y), jf(r.z), jf(r.w) ]))
    set(o, "mats", jstrs(ms))
    set(o, "stride", jf(stride))
    set(o, "lift", jf(lift))
    set(o, "phase", jf(phase))
    return o

// A leg's foot (on its ankle): a ball of radius r, flattened to a pad when `pad`.
def with_foot(l:JV, r:float, m:string, pad:bool) -> JV:
    let f = jobj()
    if pad:
        set(f, "disc", jarr([ jstr("ankle"), jf(0.0), jf(0.4), jf(-1.2) ]))
        set(f, "n", jv3(UP))
        set(f, "r", jarr([ jf(r), jf(1.2) ]))
    else:
        set(f, "ball", jarr([ jstr("ankle"), jf(0.0), jf(0.3), jf(-0.2) ]))
        set(f, "r", jf(r))
    set(f, "mat", jstr(m))
    set(l, "shapes", jarr([ f ]))
    return l

def legs(ls:[JV]) -> string: return "\"legs\": " + stringify(jarr(ls))

// ---- engines

def ram():  // a shed on wheels over a hanging log with an iron head; its crew inside, pushing
    for([ -7.0, 7.0 ]) x: wall(float3 { x, 0.0, 6.0 }, float3 { 1.3, 17.0, 1.3 }, "frame")
    for([ -14.0, 14.0 ]) y: wall(float3 { 0.0, y, 6.0 }, float3 { 8.3, 1.2, 1.2 }, "frame")
    for([ -9.0, 9.0 ]) x: for([ -11.0, 11.0 ]) y: wheel(float3 { x, y, 5.0 }, 5.0)
    for([ -7.0, 7.0 ]) x: for([ -14.0, 14.0 ]) y: cap(float3 { x, y, 6.0 }, float3 { x, y, 46.0 }, float2 { 1.0, 1.0 }, "frame", true)
    let ang = atan2(float2 { 11.0, 12.0 })
    for([ 1.0, -1.0 ]) s: box(float3 { s * 5.5, 0.0, 52.0 }, float3 { 18.0, 0.9, sqrt(11.0 * 11.0 + 12.0 * 12.0) / 2.0 }, float3 { s * sin(ang), 0.0, cos(ang) }, "trim", 0.2)
    cap(float3 { 0.0, -18.0, 58.5 }, float3 { 0.0, 18.0, 58.5 }, float2 { 1.2, 1.2 }, "frame", true)
    cap(float3 { 0.0, -20.0, 16.0 }, float3 { 0.0, 22.0, 16.0 }, float2 { 2.4, 2.4 }, "frame", true)  // the log
    cap(float3 { 0.0, 22.0, 16.0 }, float3 { 0.0, 26.5, 16.0 }, float2 { 3.2, 2.6 }, "frame2", true)  // its iron head
    for([ -10.0, 10.0 ]) y: cap(float3 { 0.0, y, 57.0 }, float3 { 0.0, y, 17.5 }, float2 { 0.4, 0.4 }, "frame2", true)
    box(float3 { 7.8, 0.0, 30.0 }, float3 { 0.5, 6.0, 1.5 }, SIDE, "team", 0.3)
    box(float3 { -7.8, 0.0, 30.0 }, float3 { 0.5, 6.0, 1.5 }, SIDE, "team", 0.3)
    vxw_body(OUT + "siege.ram.json", "A ram: a hide-roofed shed on four wheels over a log with an iron head, hung on chains; its crew inside, pushing. Its style: frame (skin), iron (pale), hide (mark).", 1.25, [ STYLES, spots("crew", [ float3 { -3.0, -8.0, 0.0 }, float3 { 3.0, 4.0, 0.0 } ]) ])

def catapult():  // a frame on wheels, a throwing arm wound back with a stone in its bucket
    for([ -6.0, 6.0 ]) x: wall(float3 { x, 0.0, 5.0 }, float3 { 1.4, 15.0, 1.4 }, "frame")
    for([ -12.0, 12.0 ]) y: wall(float3 { 0.0, y, 5.0 }, float3 { 7.4, 1.2, 1.2 }, "frame")
    for([ -8.0, 8.0 ]) x: for([ -10.0, 10.0 ]) y: wheel(float3 { x, y, 4.0 }, 4.2)
    for([ -5.5, 5.5 ]) x:
        cap(float3 { x, -2.0, 6.0 }, float3 { x, 4.0, 22.0 }, float2 { 1.2, 1.0 }, "frame", true)
        cap(float3 { x, 10.0, 6.0 }, float3 { x, 4.0, 22.0 }, float2 { 1.2, 1.0 }, "frame", true)
    cap(float3 { -6.0, 4.0, 22.0 }, float3 { 6.0, 4.0, 22.0 }, float2 { 1.2, 1.2 }, "frame", true)  // the stop bar
    cap(float3 { -5.0, 4.0, 7.5 }, float3 { 5.0, 4.0, 7.5 }, float2 { 2.0, 2.0 }, "rope", true)     // the twisted skein
    cap(float3 { 0.0, 4.0, 7.5 }, float3 { 0.0, -14.0, 11.0 }, float2 { 1.3, 1.1 }, "frame", true)  // the arm, wound back
    ball(float3 { 0.0, -15.5, 12.0 }, 2.6, "frame2", true)
    ball(float3 { 0.0, -15.5, 13.5 }, 2.0, "frame2", true)
    box(float3 { 0.0, 13.4, 9.0 }, float3 { 5.0, 0.5, 2.0 }, FRONT, "team", 0.3)
    vxw_body(OUT + "siege.catapult.json", "A catapult: a frame on four wheels, its arm wound back against a twisted skein, a stone in its bucket, a stop bar to throw against. Its style: frame (skin), iron (pale), rope (mark).", 1.5, [ STYLES, spots("crew", [ float3 { -10.0, -17.0, 0.0 }, float3 { 10.0, -17.0, 0.0 } ]) ])

def bolt():  // a great crossbow on two wheels and a trail
    for([ -8.0, 8.0 ]) x: wheel(float3 { x, -2.0, 6.0 }, 6.0)
    cap(float3 { -8.0, -2.0, 6.0 }, float3 { 8.0, -2.0, 6.0 }, float2 { 0.8, 0.8 }, "frame2", true)
    cap(float3 { 0.0, -2.0, 6.0 }, float3 { 0.0, -18.0, 1.0 }, float2 { 1.3, 1.0 }, "frame", true)  // the trail
    cap(float3 { 0.0, 0.0, 6.0 }, float3 { 0.0, 1.0, 12.0 }, float2 { 1.2, 1.2 }, "frame", true)
    box(float3 { 0.0, 3.0, 13.0 }, float3 { 1.6, 12.0, 1.2 }, FRONT, "frame", 0.3)                         // the stock
    pair_cap(float3 { 0.0, 13.0, 13.5 }, float3 { 13.0, 9.0, 14.0 }, float2 { 1.0, 0.7 }, "frame2", true)  // the bow's arms
    pair_cap(float3 { 13.0, 9.0, 14.0 }, float3 { 0.0, -6.0, 14.0 }, float2 { 0.3, 0.3 }, "trim", true)    // its string, drawn
    cap(float3 { 0.0, -6.0, 14.6 }, float3 { 0.0, 17.0, 14.6 }, float2 { 0.55, 0.55 }, "frame", true)      // the bolt
    cap(float3 { 0.0, 17.0, 14.6 }, float3 { 0.0, 19.5, 14.6 }, float2 { 0.9, 0.2 }, "frame2", true)
    box(float3 { 0.0, -3.0, 9.0 }, float3 { 3.0, 0.5, 1.5 }, FRONT, "team", 0.3)
    vxw_body(OUT + "siege.bolt.json", "A bolt thrower: a great crossbow on two wheels and a trail, its string drawn, a bolt laid. Its style: frame (skin), iron (pale), string (mark).", 1.6, [ STYLES, spots("crew", [ float3 { -5.0, -21.0, 0.0 }, float3 { 5.0, -21.0, 0.0 } ]) ])

def tower():  // a tall tower on wheels, hides on its face, a drawbridge at the top
    wall(float3 { 0.0, 0.0, 41.0 }, float3 { 12.0, 12.0, 37.0 }, "frame")
    for([ 26.0, 52.0, 78.0 ]) z: wall(float3 { 0.0, 0.0, z }, float3 { 12.8, 12.8, 1.0 }, "frame2")
    for([ -10.0, 10.0 ]) x: for([ -10.0, 10.0 ]) y: wall(float3 { x, y, 81.5 }, float3 { 2.2, 2.2, 2.5 }, "frame")
    wall(float3 { 0.0, 12.6, 40.0 }, float3 { 11.0, 0.6, 28.0 }, "trim")                                 // hides on its face
    box(float3 { 0.0, 14.5, 64.0 }, float3 { 8.0, 0.9, 11.0 }, float3 { 0.0, 1.0, 0.15 }, "frame", 0.2)  // the drawbridge
    for([ -13.0, 13.0 ]) x: for([ -8.0, 8.0 ]) y: wheel(float3 { x, y, 5.0 }, 5.0)
    cap(float3 { 9.0, -9.0, 84.0 }, float3 { 9.0, -9.0, 98.0 }, float2 { 0.5, 0.5 }, "frame", true)
    box(float3 { 9.0, -6.0, 95.5 }, float3 { 0.3, 3.0, 2.0 }, SIDE, "team", 0.2)
    vxw_body(OUT + "siege.tower.json", "A siege tower: three storeys of planks on four wheels, hides hung on its face, a drawbridge at the top, a flag; its crew behind, pushing. Its style: frame (skin), iron bands (pale), hides (mark).", 1.1, [ STYLES, spots("crew", [ float3 { -6.0, -17.0, 0.0 }, float3 { 6.0, -17.0, 0.0 } ]) ])

def sling():  // a great sling: an A-frame, a long arm with a sling at its end and a counterweight at the other
    for([ -7.0, 7.0 ]) x: wall(float3 { x, 0.0, 3.0 }, float3 { 1.4, 18.0, 1.4 }, "frame")
    for([ -16.0, 16.0 ]) y: wall(float3 { 0.0, y, 3.0 }, float3 { 8.4, 1.2, 1.2 }, "frame")
    for([ -7.0, 7.0 ]) x:
        cap(float3 { x, -9.0, 4.0 }, float3 { x * 0.8, 0.0, 34.0 }, float2 { 1.3, 1.1 }, "frame", true)
        cap(float3 { x, 9.0, 4.0 }, float3 { x * 0.8, 0.0, 34.0 }, float2 { 1.3, 1.1 }, "frame", true)
    cap(float3 { -6.5, 0.0, 34.0 }, float3 { 6.5, 0.0, 34.0 }, float2 { 1.0, 1.0 }, "frame2", true)  // the axle
    cap(float3 { 0.0, -28.0, 50.0 }, float3 { 0.0, 9.0, 27.0 }, float2 { 1.4, 1.2 }, "frame", true)  // the arm
    box(float3 { 0.0, 10.0, 22.0 }, float3 { 4.5, 3.5, 5.0 }, FRONT, "frame2", 0.4)                  // the counterweight
    cap(float3 { 0.0, -28.0, 50.0 }, float3 { 0.0, -30.0, 38.0 }, float2 { 0.3, 0.3 }, "trim", true)
    ball(float3 { 0.0, -30.0, 37.0 }, 1.8, "trim", true)
    box(float3 { 0.0, 17.4, 6.0 }, float3 { 5.0, 0.5, 2.0 }, FRONT, "team", 0.3)
    vxw_body(OUT + "siege.sling.json", "A great sling: an A-frame on skids, a long arm with a sling at its end and a heavy counterweight at the other. Its style: frame (skin), iron and weight (pale), sling (mark).", 1.35, [ STYLES, spots("crew", [ float3 { -11.0, 12.0, 0.0 }, float3 { 11.0, 12.0, 0.0 } ]) ])

def cart():  // a trade cart: a bed on two big wheels, piled with goods, pulled between its shafts
    wall(float3 { 0.0, 0.0, 10.0 }, float3 { 8.0, 12.0, 1.0 }, "frame")
    for([ -8.4, 8.4 ]) x: box(float3 { x, 0.0, 13.0 }, float3 { 0.6, 12.0, 3.0 }, SIDE, "frame", 0.2)
    for([ -12.4, 12.4 ]) y: wall(float3 { 0.0, y, 13.0 }, float3 { 8.0, 0.6, 3.0 }, "frame")
    for([ -10.0, 10.0 ]) x: wheel(float3 { x, -2.0, 7.0 }, 7.0)
    pair_cap(float3 { 4.0, 12.0, 10.0 }, float3 { 4.0, 28.0, 8.5 }, float2 { 0.7, 0.6 }, "frame", true)  // the shafts
    ball(float3 { -3.0, -5.0, 15.0 }, 3.6, "trim", false)                                                // the goods: sacks, a crate, a barrel
    ball(float3 { 2.0, -7.0, 14.5 }, 3.0, "trim", false)
    box(float3 { 3.0, 4.0, 14.0 }, float3 { 3.0, 3.0, 3.0 }, float3 { 0.2, 1.0, 0.0 }, "frame", 0.2)
    cap(float3 { -3.5, 6.0, 11.5 }, float3 { -3.5, 6.0, 18.0 }, float2 { 2.6, 2.6 }, "frame2", false)
    cap(float3 { -7.0, -11.0, 11.0 }, float3 { -7.0, -11.0, 26.0 }, float2 { 0.4, 0.4 }, "frame", true)
    box(float3 { -7.0, -9.0, 24.0 }, float3 { 0.3, 2.0, 1.6 }, SIDE, "team", 0.2)
    vxw_body(OUT + "siege.cart.json", "A trade cart: a plank bed on two big wheels, piled with sacks, a crate and a barrel, a pennant; its trader walking between the shafts. Its style: frame (skin), iron (pale), sacks (mark).", 1.2, [ STYLES, spots("crew", [ float3 { 0.0, 31.0, 0.0 } ]) ])

// ---- war beasts: each with a howdah (frame, iron, cloth) and its crew sat in it

def howdah(c:float3, half:float2, h:float):
    wall(c, float3 { half.x, half.y, 1.5 }, "frame")
    for([ -1.0, 1.0 ]) sx: box(c + float3 { sx * half.x, 0.0, 2.5 }, float3 { 0.6, half.y, 2.5 }, SIDE, "frame", 0.2)
    for([ -1.0, 1.0 ]) sy: wall(c + float3 { 0.0, sy * half.y, 2.5 }, float3 { half.x, 0.6, 2.5 }, "frame")
    for([ -1.0, 1.0 ]) sx: for([ -1.0, 1.0 ]) sy:
        cap(c + float3 { sx * (half.x - 0.5), sy * (half.y - 0.5), 4.0 }, c + float3 { sx * (half.x - 0.5), sy * (half.y - 0.5), h }, float2 { 0.5, 0.5 }, "frame2", true)
    wall(c + float3 { 0.0, 0.0, h }, float3 { half.x + 1.0, half.y + 1.0, 0.7 }, "trim")                                             // the canopy
    for([ -1.0, 1.0 ]) sx: box(c + float3 { sx * (half.x + 1.2), 0.0, -6.0 }, float3 { 0.6, half.y + 1.0, 6.0 }, SIDE, "trim", 0.2)  // the drape
    for([ -1.0, 1.0 ]) sx: box(c + float3 { sx * (half.x + 1.6), 0.0, -10.5 }, float3 { 0.5, half.y + 1.0, 1.0 }, SIDE, "team", 0.2)

def elephant():
    cap(float3 { 0.0, -12.0, 31.0 }, float3 { 0.0, 10.0, 31.0 }, float2 { 13.0, 13.5 }, "elephant", false)  // the body
    ball(float3 { 0.0, 21.0, 34.0 }, 9.0, "elephant", false)                                                // the head
    cap(float3 { 0.0, 27.0, 31.0 }, float3 { 0.0, 31.0, 22.0 }, float2 { 3.4, 2.8 }, "elephant", false)     // the trunk
    cap(float3 { 0.0, 31.0, 22.0 }, float3 { 0.0, 32.0, 11.0 }, float2 { 2.8, 2.0 }, "elephant", false)
    cap(float3 { 0.0, 32.0, 11.0 }, float3 { 0.0, 34.0, 3.4 }, float2 { 2.0, 1.6 }, "elephant", false)         // (its tip near the ground)
    for([ -1.0, 1.0 ]) s: disc(float3 { s * 8.5, 18.0, 35.0 }, float3 { s, 0.35, 0.0 }, 7.5, 0.8, "elephant")  // the ears
    pair_cap(float3 { 3.5, 26.5, 27.0 }, float3 { 4.8, 33.0, 23.0 }, float2 { 1.1, 0.6 }, "white", true)       // the tusks
    for([ -1.0, 1.0 ]) s: ball(float3 { s * 6.0, 26.5, 37.0 }, 0.6, "eye", true)
    cap(float3 { 0.0, -24.0, 33.0 }, float3 { 0.0, -27.0, 20.0 }, float2 { 0.8, 0.5 }, "elephant", true)  // the tail
    howdah(float3 { 0.0, -2.0, 46.0 }, float2 { 8.0, 9.5 }, 14.0)
    let ls = map([ leg(float3 { 8.0, 7.0, 24.5 }, float3 { 8.0, 9.0, 1.0 }, float2 { 11.8, 11.8 }, FRONT, float4 { 5.2, 4.6, 4.4, 4.2 }, [ "elephant", "elephant" ], 4.0, 2.0, 0.0),
                   leg(float3 { 8.5, -10.0, 24.5 }, float3 { 8.5, -11.0, 1.0 }, float2 { 11.8, 11.8 }, float3 { 0.0, -1.0, 0.0 }, float4 { 5.4, 4.8, 4.4, 4.2 }, [ "elephant", "elephant" ], 4.0, 2.0, 180.0) ]) l: with_foot(l, 4.8, "elephant", true)
    vxw_body(OUT + "siege.beast.elephant.json", "A war elephant: a great grey body on four pillar legs, a long trunk, broad ears, white tusks; a howdah on its back, its drape in the team colour, its crew sat in it.", 1.0, [ HOWDAH, legs(ls), "\"reach\": 4.0", spots("seats", [ float3 { 0.0, 2.0, 47.5 }, float3 { 0.0, -6.0, 47.5 } ]) ])

def heron():
    cap(float3 { 0.0, -8.0, 27.0 }, float3 { 0.0, 7.0, 30.0 }, float2 { 6.5, 5.5 }, "heron", false)                                    // the body
    cap(float3 { 0.0, -8.0, 27.0 }, float3 { 0.0, -15.0, 25.0 }, float2 { 3.0, 1.2 }, "heron", false)                                  // the tail
    for([ -1.0, 1.0 ]) s: cap(float3 { s * 5.5, -7.0, 30.0 }, float3 { s * 5.0, 8.0, 31.0 }, float2 { 2.2, 1.6 }, "heron_dark", true)  // the wings, folded
    cap(float3 { 0.0, 8.0, 31.0 }, float3 { 0.0, 11.0, 42.0 }, float2 { 2.2, 1.8 }, "heron", false)                                    // the neck, in an S
    cap(float3 { 0.0, 11.0, 42.0 }, float3 { 0.0, 13.0, 52.0 }, float2 { 1.8, 1.6 }, "heron", false)
    ball(float3 { 0.0, 14.0, 53.0 }, 2.5, "heron", false)
    cap(float3 { 0.0, 15.5, 53.0 }, float3 { 0.0, 25.0, 51.0 }, float2 { 0.9, 0.3 }, "beak", true)  // the dagger bill
    cap(float3 { 0.0, 13.0, 54.5 }, float3 { 0.0, 8.0, 56.0 }, float2 { 0.5, 0.3 }, "hair", true)   // the crest
    for([ -1.0, 1.0 ]) s: ball(float3 { s * 1.9, 15.5, 53.8 }, 0.5, "eye", true)
    wall(float3 { 0.0, -1.0, 34.5 }, float3 { 3.5, 4.0, 1.0 }, "frame")  // a saddle
    for([ -1.0, 1.0 ]) s: box(float3 { s * 4.2, -1.0, 31.0 }, float3 { 0.5, 4.0, 3.5 }, SIDE, "trim", 0.2)
    for([ -1.0, 1.0 ]) s: box(float3 { s * 4.6, -1.0, 28.0 }, float3 { 0.4, 4.0, 0.8 }, SIDE, "team", 0.2)
    let ls = [ leg(float3 { 2.5, 0.0, 24.0 }, float3 { 2.5, 0.0, 1.0 }, float2 { 11.8, 11.8 }, float3 { 0.0, -1.0, 0.0 }, float4 { 1.5, 0.9, 0.8, 0.7 }, [ "heron", "beak" ], 4.5, 2.5, 0.0) ]
    vxw_body(OUT + "siege.beast.heron.json", "A war heron: a white body on long stilt legs (the joint you see bends back), an S of a neck, a dagger bill, grey wings folded; a saddle on its back, its crew sat on it.", 1.0, [ HOWDAH, legs(ls), "\"reach\": 4.5", spots("seats", [ float3 { 0.0, -1.0, 35.5 } ]) ])

def mantis():
    cap(float3 { 0.0, -6.0, 12.0 }, float3 { 0.0, -24.0, 10.0 }, float2 { 5.5, 3.0 }, "mantis", false)  // the abdomen
    cap(float3 { 0.0, -6.0, 12.0 }, float3 { 0.0, 6.0, 14.0 }, float2 { 3.2, 3.0 }, "mantis", false)    // the thorax
    cap(float3 { 0.0, 6.0, 14.0 }, float3 { 0.0, 11.0, 26.0 }, float2 { 2.2, 1.8 }, "mantis", false)    // reared up
    ball(float3 { 0.0, 12.0, 29.0 }, 3.0, "mantis", false)
    for([ -1.0, 1.0 ]) s: ball(float3 { s * 2.6, 13.0, 30.0 }, 1.3, "gold", true)                               // the eyes
    box(float3 { 0.0, -14.0, 16.0 }, float3 { 4.2, 10.0, 0.6 }, float3 { 0.0, 0.08, 1.0 }, "mantis_dark", 0.3)  // the wings, folded
    for([ -1.0, 1.0 ]) s:                                                                                       // the folded claws, held up in front
        cap(float3 { s * 2.0, 10.0, 24.0 }, float3 { s * 4.0, 17.0, 18.0 }, float2 { 1.3, 1.1 }, "mantis", true)
        cap(float3 { s * 4.0, 17.0, 18.0 }, float3 { s * 3.0, 15.0, 27.0 }, float2 { 1.1, 0.6 }, "mantis_dark", true)
    wall(float3 { 0.0, -6.0, 16.0 }, float3 { 3.0, 4.0, 1.0 }, "frame")  // a saddle
    for([ -1.0, 1.0 ]) s: box(float3 { s * 3.8, -6.0, 13.0 }, float3 { 0.5, 4.0, 3.0 }, SIDE, "trim", 0.2)
    let ls = map([ leg(float3 { 2.5, 2.0, 12.0 }, float3 { 11.0, 7.0, 0.8 }, float2 { 8.0, 8.0 }, UP, float4 { 1.0, 0.8, 0.7, 0.5 }, [ "mantis", "mantis" ], 2.6, 1.6, 0.0),
                   leg(float3 { 2.5, -4.0, 12.0 }, float3 { 12.0, -14.0, 0.8 }, float2 { 8.5, 8.5 }, UP, float4 { 1.0, 0.8, 0.7, 0.5 }, [ "mantis", "mantis" ], 2.6, 1.6, 180.0) ]) l: with_foot(l, 1.0, "mantis", false)
    vxw_body(OUT + "siege.beast.mantis.json", "A war mantis: a long green body reared up at the front, a triangle head with great gold eyes, its claws folded up before it, four thin legs, wings folded on its back; a saddle, its crew sat on it.", 1.0, [ HOWDAH, legs(ls), "\"reach\": 2.6", spots("seats", [ float3 { 0.0, -6.0, 17.0 } ]) ])

elephant()
heron()
mantis()
ram()
catapult()
bolt()
tower()
sling()
cart()
