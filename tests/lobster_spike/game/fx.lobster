// ------------------------------------------------------------------ combat effects (src/view/combat_fx.gd)
// Played from the sim's events, view side only: sparks where a blow lands, dust (a death's puff, a
// fallen building, a stone or a charge coming down), shots that miss standing in the ground a
// while, and pale motes rising off a healed unit. Canvas units (Godot's), drawn under a 1.5 scale.
// Cosmetic, so Lobster's own random numbers.

class ShotStyle:
    arc:float
    len:float
    w:float
    col:float4

def hex_col(h:string) -> float4:
    def byte(i:int) -> float: return float(string_to_int(h.substring(i, 2), 16)) / 255.0
    return float4 { byte(0), byte(2), byte(4), 1.0 }

let SHOT_STYLES = dictionary<string, ShotStyle>(16)
for([["arrow", "0.22", "7.0", "1.0", "e8dcc0"], ["bolt", "0.08", "6.0", "1.4", "c8c0a8"], ["javelin", "0.3", "11.0", "1.3", "b08a5a"],
     ["stone", "0.18", "0.0", "2.4", "8a8a80"], ["dart", "0.04", "4.0", "0.8", "2a2a20"], ["ball", "0.02", "0.0", "1.8", "303030"],
     ["boulder", "0.42", "0.0", "4.2", "8f8a7c"], ["siege_bolt", "0.1", "13.0", "1.9", "a89a7c"], ["sling_stone", "0.5", "0.0", "5.0", "8f8a7c"]]) s:
    SHOT_STYLES.set(s[0], ShotStyle { string_to_float(s[1]), string_to_float(s[2]), string_to_float(s[3]), hex_col(s[4]) })

def shot_style(kind:string) -> ShotStyle:
    let s = SHOT_STYLES.get(kind)
    if s: return s
    let a = SHOT_STYLES.get("arrow")
    assert a
    return a

let RADIUS_PX = 64.0 * 0.5 * 1.41421356 / 1000.0   // canvas px a milli-tile of radius
let STUCK_TIME = 3.0
let HEAL_TIME = 1.0
let HEAL_MOTE = float4 { 0.894, 0.957, 0.753, 1.0 }

class Spark:
    pos:float2
    t:float
    big:bool

class Dust:
    pos:float2
    t:float
    size:float

class Stuck:
    pos:float2
    t:float
    kind:string
    tilt:float

class Heal:
    id:int
    t:float
    motes:[float4]    // offset x, y, rise speed, delay

var fx_sparks = []::Spark
var fx_dusts = []::Dust
var fx_stuck = []::Stuck
var fx_heals = []::Heal

def rnd_range(a:float, b:float) -> float: return a + rnd_float() * (b - a)

def fx_spark(at:float2, heavy:bool):
    fx_sparks.push(Spark { at + float2 { rnd_range(-2.0, 2.0), rnd_range(-2.0, 2.0) }, 0.0, heavy })

def fx_splash(at:float2, r:float):
    fx_spark(at, true)
    fx_dusts.push(Dust { at, 0.0, r * 0.45 })
    for(7) k:
        let a = 360.0 * float(k) / 7.0 + rnd_range(-17.0, 17.0)
        let d = r * rnd_range(0.4, 0.9)
        fx_dusts.push(Dust { at + float2 { cos(a) * d, sin(a) * d * 0.5 }, -rnd_float() * 0.12, rnd_range(2.5, 4.5) })

def fx_stick(at:float2, kind:string):
    fx_dusts.push(Dust { at, 0.0, 1.5 })
    if shot_style(kind).len > 0.0:
        fx_stuck.push(Stuck { at + float2 { rnd_range(-1.5, 1.5), rnd_range(-1.0, 1.0) }, 0.0, kind, rnd_range(-0.6, 0.6) })

def fx_heal(id:int):
    for(fx_heals) h:   // one glow at a time
        if h.id == id and h.t < HEAL_TIME * 0.5: return
    fx_heals.push(Heal { id, 0.0, map(3): float4 { rnd_range(-4.0, 4.0), rnd_range(-14.0, -6.0), rnd_range(9.0, 14.0), rnd_range(0.0, 0.25) } })

def fx_collapse(at:float2, size:int):
    for(6 + size * 3):
        fx_dusts.push(Dust { at + float2 { rnd_range(-20.0, 20.0), rnd_range(-10.0, 10.0) } * float(size) * 0.6, -rnd_float() * 0.4, rnd_range(8.0, 16.0) * float(size) * 0.5 })

def fx_puff(at:float2, tip:float):
    for(4): fx_dusts.push(Dust { at + float2 { tip * 8.0 + rnd_range(-5.0, 5.0), rnd_range(-3.0, 2.0) }, 0.0, rnd_range(3.0, 5.0) })

def fx_clear():
    fx_sparks = []
    fx_dusts = []
    fx_stuck = []
    fx_heals = []

def fx_tick(dt:float):
    for(fx_sparks) s: s.t += dt
    fx_sparks = filter(fx_sparks) s: s.t < 0.25
    for(fx_dusts) d: d.t += dt
    fx_dusts = filter(fx_dusts) d: d.t < 1.6
    for(fx_stuck) s: s.t += dt
    fx_stuck = filter(fx_stuck) s: s.t < STUCK_TIME
    for(fx_heals) h: h.t += dt
    fx_heals = filter(fx_heals) h: h.t < HEAL_TIME

def fx_circle(at:float2, r:float, col:float4):
    gl.color(col):
        gl.translate(at): gl.circle(r, 12)

// The glow a healed unit has now (1 for none): UnitView reads modulate alpha as shade.
def heal_glow(id:int) -> float:
    for(fx_heals) h:
        if h.id == id and h.t < HEAL_TIME * 0.5: return 1.0 + 0.35 * sin(360.0 * h.t / HEAL_TIME)
    return 1.0

// ground_of(id): a live unit's feet on the canvas, or float2 { -1000000000.0, 0 } when it's gone or unseen.
def fx_draw(ground_of):
    gl.set_shader("color")
    for(fx_stuck) s:   // half buried, leaning, fading at the end
        let st = shot_style(s.kind)
        let a = clamp((STUCK_TIME - s.t) / 0.6, 0.0, 1.0)
        let up = float2 { sin(s.tilt * 57.29578), -cos(s.tilt * 57.29578) } * st.len * 0.9
        let w = max(st.w, 1.4)
        let sh = s.pos + float2 { 0.6, 0.3 }
        gl.color(float4 { 0.0, 0.0, 0.0, 0.3 * a }): gl.line(sh, sh + float2 { up.x * 1.4, -up.y * 0.35 }, w)
        gl.color(float4 { 0.1, 0.07, 0.04, 0.8 * a }): gl.line(s.pos, s.pos + up, w + 1.2)
        gl.color(float4 { st.col.x * 0.65, st.col.y * 0.65, st.col.z * 0.65, a }): gl.line(s.pos, s.pos + up, w)
        fx_circle(s.pos + up, w * 0.9, float4 { 0.92, 0.9, 0.84, a })
    for(fx_heals) h:
        let g = ground_of(h.id)
        if g.x > -100000000.0:
            for(h.motes) m:
                let t = h.t - m.w
                if t > 0.0:
                    let a = sin(180.0 * clamp(t / (HEAL_TIME - 0.25), 0.0, 1.0))
                    let p = g + float2 { m.x, m.y } + float2 { sin((t * 5.0 + m.w * 20.0) * 57.29578) * 1.2, -m.z * t }
                    fx_circle(p, 1.6, float4 { HEAL_MOTE.x, HEAL_MOTE.y, HEAL_MOTE.z, 0.25 * a })
                    fx_circle(p, 0.7, float4 { HEAL_MOTE.x, HEAL_MOTE.y, HEAL_MOTE.z, 0.85 * a })
    for(fx_sparks) s:
        let f = 1.0 - s.t / 0.25
        let r = (if s.big: 4.0 else: 2.5) * (0.5 + f)
        gl.color(float4 { 1.0, 0.92, 0.7, f }):
            for(4) k:
                let a = float(k) * 90.0 + 22.9
                gl.line(s.pos, s.pos + float2 { cos(a), sin(a) } * r, 1.0)
    for(fx_dusts) d:
        if d.t >= 0.0:
            let f = d.t / 1.6
            fx_circle(d.pos - float2 { 0.0, f * 10.0 }, d.size * (0.6 + f), float4 { 0.62, 0.56, 0.46, 0.5 * (1.0 - f) })
