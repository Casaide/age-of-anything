// ------------------------------------------------------------------ Godot's RandomNumberGenerator (PCG32), for the models
// The art seeds Godot's generator to shape a fleece, a rock, a tree (cosmetic, view side: never the sim,
// which has src/rng.gd's). The same seed gives the same numbers here (rng_check.lobster holds them to
// rng_dump.gd's): PCG32 on 64-bit state (Lobster's ints wrap as unsigned ones do), floats rounded to
// 32 bits where Godot's are.

let PCG_MULT = 6364136223846793005
let PCG_INC = 1442695040888963407

class GRng:
    state = 0
    inc = 0

def shr64(x:int, n:int) -> int: return (x >> n) & ((1 << (64 - n)) - 1)   // a logical shift
def u32(x:int) -> int: return x & 0xFFFFFFFF

def pcg_next(r:GRng) -> int:
    let old = r.state
    r.state = old * PCG_MULT + (r.inc | 1)
    let xorshifted = u32(shr64(shr64(old, 18) ^ old, 27))
    let rot = shr64(old, 59)
    return u32((xorshifted >> rot) | (xorshifted << ((-rot) & 31)))

def grng(seed:int) -> GRng:      // RandomNumberGenerator.new() with .seed = seed
    let r = GRng {}
    r.state = 0
    r.inc = (PCG_INC << 1) | 1
    pcg_next(r)
    r.state += seed
    pcg_next(r)
    return r

let f32_buf = ensure_size("", 4, 0)
def f32(x:float) -> float:       // rounded to a 32-bit float
    write_float32_le(f32_buf, 0, x)
    let v, _n = read_float32_le(f32_buf, 0)
    return v

def randi(r:GRng) -> int: return pcg_next(r)

def clz32(x:int) -> int:
    var n = 0
    var b = 31
    while b >= 0 and not (x & (1 << b)):
        n++
        b--
    return n

// RandomPCG::randf: one draw for the exponent (its leading zeros), one for the fraction.
def randf(r:GRng) -> float:
    let e = pcg_next(r)
    if e == 0: return 0.0
    return f32(float(pcg_next(r) | 0x80000001)) * pow(2.0, float(-32 - clz32(e)))

// RandomPCG::randd: the same with 64 bits of fraction (rounded to a double's 53).
def randd(r:GRng) -> float:
    let e = pcg_next(r)
    if e == 0: return 0.0
    let s = (pcg_next(r) << 32) | pcg_next(r) | 0x8000000000000001
    var hi = shr64(s, 11)
    if (s & 0x7FF) > 0x400: hi++
    return float(hi) * pow(2.0, float(11 - 64 - clz32(e)))
def randf_range(r:GRng, lo:float, hi:float) -> float: return f32(randf(r) * f32(hi - lo) + lo)

def randi_range(r:GRng, lo:int, hi:int) -> int:
    if lo == hi: return lo
    let bound = abs(lo - hi) + 1
    let threshold = u32(-bound) % bound
    while true:
        let v = pcg_next(r)
        if v >= threshold: return v % bound + min(lo, hi)
    return lo

// Normal (Box-Muller), as RandomPCG::randfn.
def randfn(r:GRng, mean:float, dev:float) -> float:
    var t = randf(r)
    if t < 0.00001: t += 0.00001
    return f32(mean + dev * (sqrt(-2.0 * log(t)) * cos(360.0 * randf(r))))
