// ------------------------------------------------------------------ combat effects (src/view/combat_fx.gd)
// Played from the sim's events, view side only: sparks where a blow lands, dust (a death's puff, a
// stone or a charge coming down), shots that miss standing in the ground a while, and pale motes
// rising off a healed unit. A building that falls leaves its ruin under a cloud of pixel dust; the
// ruin is only decoration (D-172): it burns out, fades after a while, and goes at once when something
// is built over it (drawn in game/town.lobster). Canvas units (Godot's), drawn under a 1.5 scale.
// Cosmetic, so Lobster's own random numbers.

class ShotStyle:
    arc:float
    len:float
    w:float
    col:float4
    glow = float4_0  // a soft halo round it (a mod's bolt of light); alpha 0: none
    sticks = true    // a miss stands in the ground (false: a bolt of light)

def hex_col(h:string) -> float4:
    def byte(i:int) -> float: return float(string_to_int(h.substring(i, 2), 16)) / 255.0
    return float4 { byte(0), byte(2), byte(4), 1.0 }

let SHOT_STYLES = dictionary<string, ShotStyle>(16)
for([ [ "arrow", "0.22", "7.0", "1.0", "e8dcc0" ], [ "bolt", "0.08", "6.0", "1.4", "c8c0a8" ], [ "javelin", "0.3", "11.0", "1.3", "b08a5a" ],
      [ "stone", "0.18", "0.0", "2.4", "8a8a80" ], [ "dart", "0.04", "4.0", "0.8", "2a2a20" ], [ "ball", "0.02", "0.0", "1.8", "303030" ],
      [ "boulder", "0.42", "0.0", "4.2", "8f8a7c" ], [ "siege_bolt", "0.1", "13.0", "1.9", "a89a7c" ], [ "sling_stone", "0.5", "0.0", "5.0", "8f8a7c" ] ]) s:
    SHOT_STYLES.set(s[0], ShotStyle { string_to_float(s[1]), string_to_float(s[2]), string_to_float(s[3]), hex_col(s[4]) })

def shot_style(kind:string) -> ShotStyle:
    let s = SHOT_STYLES.get(kind)
    if s: return s
    let m = get(mod_shots, kind)  // a mod's look (its shots.json: colours as "#rrggbb")
    if m:
        def num(k:string, f:float) -> float: return if has(m, k): as_float(at(m, k)) else: f
        let made = ShotStyle { num("arc", 0.0), num("len", 0.0), num("w", 1.0), hex_col(substring(gstr(m, "col", "#ffffff"), 1, 6)) }
        if has(m, "glow"): made.glow = hex_col(substring(gstr(m, "glow", "#ffffff"), 1, 6))
        made.sticks = gbool(m, "sticks", true)
        SHOT_STYLES.set(kind, made)
        return made
    let a = SHOT_STYLES.get("arrow")
    assert a
    return a

let RADIUS_PX = 64.0 * 0.5 * 1.41421356 / 1000.0  // canvas px a milli-tile of radius
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
    motes:[float4]  // offset x, y, rise speed, delay

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
    if shot_style(kind).len > 0.0 and shot_style(kind).sticks:
        fx_stuck.push(Stuck { at + float2 { rnd_range(-1.5, 1.5), rnd_range(-1.0, 1.0) }, 0.0, kind, rnd_range(-0.6, 0.6) })

def fx_heal(id:int):
    for(fx_heals) h:  // one glow at a time
        if h.id == id and h.t < HEAL_TIME * 0.5: return
    fx_heals.push(Heal { id, 0.0, map(3): float4 { rnd_range(-4.0, 4.0), rnd_range(-14.0, -6.0), rnd_range(9.0, 14.0), rnd_range(0.0, 0.25) } })

// A fallen building's ruin (BuildingArt.fall): its last broken-up stage where it stood, burning a while.
class RuinFx:
    frame:string  // the ruin's bake
    body:string   // the building's bake (where its fires are)
    id:int        // the building's (its fires' spots)
    at:float2     // its anchor, art px (lifted)
    sort_y:float
    flat:bool  // (a pen: lies low)
    owner:int
    cells:int4  // its footprint: x, y, w, h (sim cells)
    fires:int   // how many of its fires burn
    t0:float    // when it fell (seconds of play shown, as the dead's)

// A puff of a fallen building's dust: canvas units.
class Puff3:
    pos:float2
    t:float
    r:float
    rise:float
    drift:float

let RUIN_BURN = 8.0    // a ruin's fires burn this long after it falls
let RUIN_STAYS = 45.0  // then it lies there this long...
let RUIN_FADE = 5.0    // ...and fades away
let PUFF_TIME = 2.6
let PUFF_SIZES = [ 3, 4, 5, 7, 9, 12, 15, 19, 24 ]                                                                                 // art pixels: a puff grows through these
let PUFF_DUST = [ float4 { 0.886, 0.839, 0.737, 1.0 }, float4 { 0.725, 0.663, 0.541, 1.0 }, float4 { 0.522, 0.467, 0.380, 1.0 } ]  // lit, mid, shade
let FX_ART_PX = ART_SCALE                                                                                                          // art px a canvas unit: the dust's grid
var fx_ruins = []::RuinFx
var fx_puffs = []::Puff3
let fx_puff_tex = dictionary<int, resource<texture>>(16)

// A fallen building (size: its side in tiles): a cloud of pixel dust over its footprint (its ruin, if it has one,
// is left by the game: fx_ruins).
def fx_collapse(at:float2, size:int):
    for(14 + size * 10):
        let off = float2 { rnd_range(-1.0, 1.0) * 24.0, rnd_range(-1.0, 1.0) * 12.0 - 8.0 } * float(size)
        fx_puffs.push(Puff3 { at + off, -rnd_float() * 0.5, rnd_range(4.0, 8.0) * (1.0 + float(size) * 0.3), rnd_range(6.0, 18.0), rnd_range(-6.0, 6.0) })

// Something stands on these cells (x, y, w, h): a ruin there goes at once.
def fx_clear_ruins(cells:int4):
    def apart(r:RuinFx) -> bool: return r.cells.x >= cells.x + cells.z or cells.x >= r.cells.x + r.cells.z or r.cells.y >= cells.y + cells.w or cells.y >= r.cells.y + r.cells.w
    let near = exists(fx_ruins) r: not apart(r)
    if near: fx_ruins = filter(fx_ruins) r: apart(r)

// A ruin's fade at `now` (1 whole .. 0 gone).
def ruin_fade(r:RuinFx, now:float) -> float: return 1.0 - clamp((now - r.t0 - RUIN_STAYS) / RUIN_FADE, 0.0, 1.0)

// A puff's shape `r` art pixels across: a disc, its edge ragged and dithered, in white (drawn tinted).
def puff_tex(r:int) -> resource<texture>:
    let have = fx_puff_tex.get(r)
    if have: return have
    let rows = map(2 * r + 1) y: map(2 * r + 1) x:
        let f = sqrt(float((x - r) * (x - r) + (y - r) * (y - r))) / float(r)
        let noise = float(((x * 73856093) ^ (y * 19349663) ^ (r * 83492791)) & 1023) / 1023.0
        if f > 1.0 or f + noise * 0.2 > 1.05 or (f > 0.8 and (x + y) % 2 == 0): float4_0 else: float4_1
    let made = gl.create_texture(rows, texture_format_nearest_mag | texture_format_nearest_min | texture_format_nomipmap | texture_format_clamp)
    fx_puff_tex.set(r, made)
    return made

// The fallen buildings' dust as one cloud: every puff in shade, then every puff in the mid tone up and to the left
// of it, then a smaller highlight further up-left (the light from the upper left), so the puffs merge into billows
// lit as one instead of reading as separate balls. On the art grid.
def draw_puffs():
    if not fx_puffs.length: return
    gl.set_shader("textured")
    for(3) band:
        for(fx_puffs) p:
            if p.t >= 0.0:
                let k = p.t / PUFF_TIME
                let want = p.r * FX_ART_PX * (0.6 + 0.8 * k) * [ 1.0, 0.92, 0.55 ][band]
                var r = PUFF_SIZES[0]
                for(PUFF_SIZES) n:
                    if float(n) <= want: r = n
                var at = p.pos + float2 { p.drift * k, -p.rise * k } - float2_1 * p.r * [ 0.0, 0.18, 0.4 ][band]
                at = float(floor(at * FX_ART_PX)) / FX_ART_PX
                let half = float2_1 * float(r) / FX_ART_PX
                let c = PUFF_DUST[2 - band]
                gl.set_primitive_texture(0, puff_tex(r))
                gl.color(float4 { c.x, c.y, c.z, 1.0 - k * k * k }):
                    gl.translate(at - half): gl.rect(half * 2.0 + float2_1 / FX_ART_PX)
    gl.set_shader("color")

def fx_puff(at:float2, tip:float):
    for(4): fx_dusts.push(Dust { at + float2 { tip * 8.0 + rnd_range(-5.0, 5.0), rnd_range(-3.0, 2.0) }, 0.0, rnd_range(3.0, 5.0) })

def fx_clear():
    fx_sparks = []
    fx_dusts = []
    fx_stuck = []
    fx_heals = []
    fx_puffs = []
    fx_ruins = []

def fx_tick(dt:float):
    for(fx_sparks) s: s.t += dt
    fx_sparks = filter(fx_sparks) s: s.t < 0.25
    for(fx_dusts) d: d.t += dt
    fx_dusts = filter(fx_dusts) d: d.t < 1.6
    for(fx_stuck) s: s.t += dt
    fx_stuck = filter(fx_stuck) s: s.t < STUCK_TIME
    for(fx_heals) h: h.t += dt
    fx_heals = filter(fx_heals) h: h.t < HEAL_TIME
    for(fx_puffs) p: p.t += dt
    fx_puffs = filter(fx_puffs) p: p.t < PUFF_TIME

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
    for(fx_stuck) s:  // half buried, leaning, fading at the end
        let st = shot_style(s.kind)
        let a = clamp((STUCK_TIME - s.t) / 0.6, 0.0, 1.0)
        let up = float2 { sin(s.tilt * 57.29578), -cos(s.tilt * 57.29578) } * st.len * 0.9
        let w = max(st.w, 1.4)
        let sh = s.pos + float2 { 0.6, 0.3 }
        ui_line(sh, sh + float2 { up.x * 1.4, -up.y * 0.35 }, w, float4 { 0.0, 0.0, 0.0, 0.3 * a })
        ui_line(s.pos, s.pos + up, w + 1.2, float4 { 0.1, 0.07, 0.04, 0.8 * a })
        ui_line(s.pos, s.pos + up, w, float4 { st.col.x * 0.65, st.col.y * 0.65, st.col.z * 0.65, a })
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
                ui_line(s.pos, s.pos + float2 { cos(a), sin(a) } * r, 1.0, float4 { 1.0, 0.92, 0.7, f })
    draw_puffs()
    for(fx_dusts) d:
        if d.t >= 0.0:
            let f = d.t / 1.6
            fx_circle(d.pos - float2 { 0.0, f * 10.0 }, d.size * (0.6 + f), float4 { 0.62, 0.56, 0.46, 0.5 * (1.0 - f) })
