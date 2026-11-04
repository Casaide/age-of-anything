// Creature voices: what a unit says when you pick it or give it an order, and its cry when it dies. One small vocal synth
// (a pulse through the formants of a throat) plus a few animal noisemakers, tuned per creature. This is where the game's
// premise shows in sound: rats squeak, frogs croak, beetles clack. Each creature has takes for select, ack and die.

def contour(f0:float, f1:float, dur:float, cur = 1.0) -> [float]:
    return curve(seconds(dur)) t: f0 + (f1 - f0) * pow(min(1.0, t / dur), cur)

// A voice: a glottal pulse (pitch a contour) through formant resonances. aspirate: seconds of breath before the voice
// comes in (an 'h'); dark: a low-pass in Hz.
def throat(dur:float, pitch:[float], table:[float3], breath = 0.08, width = 0.35, rasp = 0.0, attack = 0.02, release = 0.06, aspirate = 0.0, dark = 0.0) -> [float]:
    let n = seconds(dur)
    var src = pulsec(pitch, width)
    if rasp > 0.0:  // a rough edge: the pulse amplitude flickers (a croak, a growl)
        src = mul(src, map(n) i: 1.0 - rasp * (0.5 + 0.5 * rsin(TAU * 27.0 * i / RATE)))
    if aspirate > 0.0:
        let a = seconds(aspirate)
        src = map(src) x, i: (if i < a: float(i) / a else: 1.0) * x
        src = add([ src, map(noise(n)) y, i: (if i < a: (1.0 - float(i) / a) * 0.9 else: 0.0) * y ])
    src = add([ src, gain(highpass(noise(n), 1500.0), breath) ])
    var out = formants(src, table)
    if dark > 0.0: out = lowpass(out, dark)
    return mul(out, env(n, attack, dur * 0.3, 0.8, release))

// vowel formants (F1, F2, F3) for the humans and the centaurs; narrow enough to tell apart
def vowel(v:string) -> [float3]:
    return switch v:
        case "a": [ p3(750.0, 10.0, 1.0), p3(1250.0, 12.0, 0.6), p3(2600.0, 12.0, 0.25) ]
        case "u": [ p3(350.0, 10.0, 1.0), p3(850.0, 12.0, 0.3), p3(2300.0, 12.0, 0.1) ]
        case "o": [ p3(500.0, 10.0, 1.0), p3(950.0, 12.0, 0.45), p3(2500.0, 12.0, 0.15) ]
        case "e": [ p3(550.0, 10.0, 0.9), p3(1850.0, 12.0, 0.6), p3(2550.0, 12.0, 0.3) ]
        default: [ p3(320.0, 10.0, 0.8), p3(2250.0, 12.0, 0.6), p3(2950.0, 12.0, 0.35) ]

class Syllable:
    v:string
    dur:float
    p0:float
    p1:float

// Syllables in one breath, cut by a stop. A shout, not a murmur: a breathy 'h' onset, a brighter pulse, pitch up around
// 170 Hz.
def word(syllables:[Syllable], base:float, stop = true) -> [float]:
    let out = []::float
    var at = 0.0
    for(syllables) s, k:
        let v = throat(s.dur, contour(base * s.p0, base * s.p1, s.dur), vowel(s.v), 0.05, 0.26, 0.0, 0.012, 0.05, if k == 0: 0.035 else: 0.0)
        mix_into(out, v, seconds(at))
        at += s.dur * 0.9
    if stop:  // a lips-closed stop at the end
        mix_into(out, gain(mul(bandpass(noise(seconds(0.02)), 900.0, 1.0), decay(seconds(0.02), 250.0, 0.001)), 0.3), seconds(at))
    return out

def human(kind:string, base = 172.0) -> [float]:
    let b = base * j(0.94, 1.06)
    if kind == "select": return word([ Syllable { "e", 0.18, 0.95, 1.15 } ], b)  // "eh?" (rising: a question)
    if kind == "ack":
        return switch randbelow(3):
            case 0: word([ Syllable { "u", 0.14, 1.1, 0.9 } ], b)                                             // "hup"
            case 1: word([ Syllable { "a", 0.12, 1.2, 1.05 }, Syllable { "o", 0.2, 1.0, 0.8 } ], b)           // "ha-ho"
            default: word([ Syllable { "i", 0.07, 1.1, 1.15 }, Syllable { "a", 0.2, 1.15, 0.9 } ], b, false)  // "yah"
    return word([ Syllable { "a", 0.45, 1.25, 0.6 } ], b, false)                                              // a falling cry

// A human voice, deeper, with a hoof stamping under the order.
def centaur(kind:string) -> [float]:
    let v = human(kind, 135.0)
    if kind != "ack": return v
    let hoof = sinec(curve(seconds(0.12)) t: 70.0 + 60.0 * exp(-t * 30.0))
    let stamp = add([ mul(hoof, decay(seconds(0.12), 35.0)), gain(mul(lowpass(noise(seconds(0.06)), 600.0), decay(seconds(0.06), 80.0)), 0.5) ])
    return add([ v, delay_start(gain(stamp, 0.7), 0.02) ])

// A croak: a low raspy pulse, lips-closed formants; the cry is a long falling 'wraak'.
def frog(kind:string) -> [float]:
    let table = [ p3(340.0, 6.0, 1.0), p3(1000.0, 8.0, 0.3), p3(2100.0, 10.0, 0.06) ]
    if kind == "select": return throat(0.14, contour(95.0, 72.0, 0.14), table, 0.03, 0.3, 0.8, 0.01, 0.04, 0.0, 1800.0)
    if kind == "ack":
        let out = []::float
        for(1 + randbelow(2)) k:
            mix_into(out, throat(0.17, contour(82.0 * j(0.9, 1.1), 62.0, 0.17), table, 0.03, 0.3, 0.9, 0.01, 0.05, 0.0, 1800.0), seconds(k * 0.2))
        return out
    return throat(0.5, contour(110.0, 50.0, 0.5, 0.6), table, 0.05, 0.3, 0.7, 0.01, 0.1, 0.0, 1800.0)

// A squeak: a high tone with a quick wobble; the cry is a long squeal.
def squeak(dur:float, f0:float, f1:float, wob:float) -> [float]:
    let n = seconds(dur)
    let tone = sinec(curve(n) t: (f0 + (f1 - f0) * t / dur) * (1.0 + 0.04 * rsin(TAU * wob * t)))
    let over = gain(sinec(curve(n) t: 2.0 * (f0 + (f1 - f0) * t / dur)), 0.25)
    return mul(add([ tone, over ]), env(n, 0.008, dur * 0.3, 0.7, dur * 0.3))

def rat(kind:string) -> [float]:
    if kind == "select": return squeak(0.09, 3200.0 * j(0.9, 1.1), 3600.0, 40.0)
    if kind == "ack":
        let a = squeak(0.08, 2900.0 * j(0.9, 1.1), 3700.0, 35.0)
        return add([ a, delay_start(squeak(0.1, 3400.0, 2600.0, 30.0), 0.1) ])
    return squeak(0.45, 3300.0, 1900.0, 22.0)

// Clacks of the jaws and a buzz of the wing cases.
def clacks(count:int, gap:float, pitch:float) -> [float]:
    let out = []::float
    for(count) k:
        let c = mul(bandpass(noise(seconds(0.012)), pitch * j(0.9, 1.1), 1.5, 2.0), decay(seconds(0.012), 400.0, 0.0005))
        mix_into(out, c, seconds(k * gap * j(0.85, 1.15)))
    return out

def buzz(dur:float, f:float) -> [float]:
    let n = seconds(dur)
    let src = mul(pulse(n, f, 0.2), map(n) i: 0.6 + 0.4 * rsin(TAU * 61.0 * i / RATE))
    return mul(bandpass(src, 900.0, 1.2, 2.0), env(n, 0.02, dur * 0.4, 0.6, 0.06))

def beetle(kind:string) -> [float]:
    if kind == "select": return clacks(2, 0.06, 2400.0)
    if kind == "ack": return add([ clacks(3, 0.05, 2200.0), delay_start(gain(buzz(0.14, 165.0), 0.6), 0.12) ])
    return add([ gain(buzz(0.45, 140.0), 0.8), clacks(5, 0.07, 1800.0) ])

// A chitter: a fast ripple of high clicks, and a hiss when it dies.
def chitter(dur:float, rate:float, f:float) -> [float]:
    let n = seconds(dur)
    let out = zeros(n)
    var at = 0.0
    while at < dur:
        let c = mul(bandpass(noise(seconds(0.006)), f * (1.0 + 0.3 * at / dur), 2.0, 2.5), decay(seconds(0.006), 700.0, 0.0003))
        mix_into(out, c, seconds(at))
        at += (1.0 / rate) * j(0.8, 1.2)
    return mul(out, env(n, 0.01, dur * 0.4, 0.7, 0.03))

def spider(kind:string) -> [float]:
    if kind == "select": return chitter(0.12, 45.0, 4200.0)
    if kind == "ack": return chitter(0.2, 38.0, 3800.0)
    let hiss = mul(bandpass(noise(seconds(0.5)), 5000.0, 0.7, 1.5), env(seconds(0.5), 0.03, 0.2, 0.5, 0.2))
    return add([ chitter(0.3, 30.0, 3000.0), gain(hiss, 0.5) ])

// A whinny (a glide down with a shake) for orders; a snort when picked; a scream when it dies.
def whinny(dur:float, f0:float, f1:float) -> [float]:
    let pitch = curve(seconds(dur)) t: (f0 + (f1 - f0) * pow(t / dur, 0.7)) * (1.0 + 0.05 * rsin(TAU * 13.0 * t))
    return throat(dur, pitch, [ p3(650.0, 6.0, 1.0), p3(1700.0, 8.0, 0.5), p3(2600.0, 9.0, 0.2) ], 0.1, 0.5, 0.0, 0.03, 0.08)

def pony(kind:string) -> [float]:
    if kind == "select":
        let n = seconds(0.18)
        let flutter = map(n) i: 0.5 + 0.5 * rsin(TAU * 26.0 * i / RATE)
        return gain(mul(mul(lowpass(noise(n), 1800.0), flutter), env(n, 0.01, 0.18 * 0.4, 0.5, 0.05)), 1.3)
    if kind == "ack": return whinny(0.32, 800.0 * j(0.92, 1.08), 420.0)
    return whinny(0.6, 950.0, 300.0)

// A soft chirruping purr.
def chirp(f0:float, f1:float, dur:float) -> [float]:
    let n = seconds(dur)
    return mul(add([ sinec(contour(f0, f1, dur)), gain(sinec(contour(f0 * 2.0, f1 * 2.0, dur)), 0.3) ]), env(n, 0.01, dur * 0.4, 0.5, 0.02))

def purr(dur:float, f:float) -> [float]:
    let n = seconds(dur)
    return gain(mul(bandpass(pulse(n, f, 0.15), 700.0, 1.0, 2.0), env(n, 0.03, dur * 0.4, 0.6, 0.05)), 0.8)

def capybara(kind:string) -> [float]:
    if kind == "select": return chirp(1500.0 * j(0.95, 1.05), 2100.0, 0.08)
    if kind == "ack":
        let out = []::float
        for(2 + randbelow(2)) k: mix_into(out, chirp(1400.0 * j(0.95, 1.05), 1900.0, 0.07), seconds(k * 0.1))
        return add([ out, gain(purr(0.25, 24.0), 0.5) ])
    return add([ chirp(2000.0, 900.0, 0.4), delay_start(purr(0.3, 18.0), 0.1) ])

def huff(dur:float) -> [float]:
    let n = seconds(dur)
    return mul(bandpass(noise(n), 600.0, 0.8, 1.5), env(n, 0.015, dur * 0.3, 0.5, dur * 0.4))

// A bear: a deep chesty 'hrrm' through a big throat (low, rough, dark), a huff of breath when picked, and a long falling
// roar when it dies. Dignified, not snarling: the clever ones.
def bear(kind:string) -> [float]:
    let table = [ p3(420.0, 7.0, 1.0), p3(820.0, 9.0, 0.45), p3(2200.0, 10.0, 0.08) ]  // a round, closed 'o' in a big throat
    let b = j(0.93, 1.07)
    if kind == "select":  // a huff, then a short rising 'hm?'
        return add([ gain(huff(0.12), 0.7), delay_start(throat(0.2, contour(88.0 * b, 104.0 * b, 0.2), table, 0.06, 0.32, 0.35, 0.02, 0.06, 0.0, 1600.0), 0.07) ])
    if kind == "ack":  // 'hrrm-hm': one or two low grunts, falling
        let out = []::float
        for(1 + randbelow(2)) k:
            mix_into(out, throat(0.2, contour(96.0 * b * j(0.95, 1.05), 74.0 * b, 0.2), table, 0.05, 0.32, 0.55, 0.015, 0.06, if k == 0: 0.03 else: 0.0, 1500.0), seconds(k * 0.22))
        return out
    let roar = throat(0.7, contour(150.0 * b, 58.0, 0.7, 0.6), [ p3(560.0, 6.0, 1.0), p3(1050.0, 8.0, 0.5), p3(2300.0, 10.0, 0.12) ], 0.12, 0.4, 0.6, 0.03, 0.15, 0.04, 2200.0)
    return add([ roar, delay_start(gain(huff(0.3), 0.5), 0.55) ])

// Sharp little 'tsip' chips over the low hum of its wings.
def chip(f0:float, f1:float, dur:float) -> [float]:
    let n = seconds(dur)
    return mul(add([ sinec(contour(f0, f1, dur)), gain(sinec(contour(f0 * 1.5, f1 * 1.5, dur)), 0.2) ]), env(n, 0.003, dur * 0.5, 0.3, 0.01))

def hum(dur:float, f:float) -> [float]:
    let n = seconds(dur)
    let wob = curve(n) t: f * (1.0 + 0.04 * rsin(TAU * 7.0 * t))
    return gain(mul(lowpass(pulsec(wob, 0.4), 900.0), env(n, 0.04, dur * 0.4, 0.7, 0.08)), 0.7)

def hummingbird(kind:string) -> [float]:
    let f = 4200.0 * j(0.94, 1.06)
    if kind == "select": return add([ gain(hum(0.22, 62.0), 0.6), chip(f, f * 1.25, 0.05) ])
    if kind == "ack":
        let out = gain(hum(0.32, 66.0), 0.6)
        for(2 + randbelow(2)) k: mix_into(out, chip(f * j(0.95, 1.05), f * 1.3, 0.04), seconds(0.03 + k * 0.07))
        return out
    let out = gain(hum(0.5, 70.0), 0.5)  // the hum winds down under a falling squeak
    mix_into(out, chip(f * 1.1, f * 0.55, 0.28), 0)
    return out

let creatures = [ "frog", "rat", "human", "spider", "beetle", "pony", "centaur", "capybara", "hummingbird", "bear" ]
let voice_kinds = [ "select", "ack", "die" ]
let voice_takes = [ 2, 3, 2 ]

def voice_take(creature:string, kind:string) -> [float]:
    return switch creature:
        case "frog": frog(kind)
        case "rat": rat(kind)
        case "human": human(kind)
        case "spider": spider(kind)
        case "beetle": beetle(kind)
        case "pony": pony(kind)
        case "centaur": centaur(kind)
        case "capybara": capybara(kind)
        case "hummingbird": hummingbird(kind)
        default: bear(kind)
