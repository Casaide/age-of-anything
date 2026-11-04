// The second piece ("Hearth"): the town at work, for the long building stretches of a match. Slower than the theme and
// in three: a lilt, not a stride. G Mixolydian (the theme's seven notes round G, so the stings in D still sit in it),
// 72 beats a minute, 3/4, 32 bars: A A B A', 80 seconds.
//
// The tune is on a wooden tongue drum over a lute rolling the chord; the same stems as the theme hold the same roles,
// so the game's mixes by age work on it unchanged: pluck (tongue drum tune, lute chords) | drums (a hand drum, barely
// there) | flute (a counter, the tune in B, a third below in A') | drone (bowed G and C) | horns (soft held chords) |
// battle (war drums in three, a horn call).

let hearth = new_grid(72, 32, 3)
let hearth_a = "G4:1.5 A4:.5 B4:1 | D5:2 B4:1 | C5:1 B4:1 A4:1 | G4:2 E4:1 | " +
    "F4:1.5 G4:.5 A4:1 | C5:2 A4:1 | B4:1 A4:1 F4:1 | G4:3"
let hearth_b = "E5:1.5 D5:.5 C5:1 | D5:2 G4:1 | C5:1.5 B4:.5 A4:1 | F4:2 A4:1 | " +
    "E5:1.5 D5:.5 C5:1 | B4:1 C5:1 D5:1 | A4:1.5 G4:.5 F4:1 | G4:2 r:1"
let hearth_counter = "D5:3 | D5:3 | E5:3 | E5:3 | C5:3 | C5:3 | D5:3 | B4:3"
let hearth_roots = tokenize("G G C C F F G G G G C C F F G G C G A F C G F G G G C C F F G G", " ", "")

def hearth_stem(stem:string) -> [float]:
    let g = hearth
    let beat = g.beat
    let buf = zeros(g.loop)
    switch stem:
        case "pluck":
            for(tune_of([ parse(hearth_a, 0, 3), parse(hearth_a, 8, 3), parse(hearth_b, 16, 3), parse(hearth_a, 24, 3) ])) n:
                g.place(buf, bell(note_hz(n.name), n.beats * beat + 0.9, j(0.8, 0.95)), n.on)
            for(32) bar:  // the lute rolls the chord: root, fifth, third an octave up (in eighths from bar 9)
                let t = triad(hearth_roots[bar], 3)
                let short = [ t[0], t[2], step(t[1], 7) ]
                let roll = if bar < 8: short else: [ t[0], t[2], step(t[1], 7), t[2], step(t[0], 7), t[2] ]
                let each = 3.0 / roll.length
                for(roll) name, k:
                    let vel = (if k == 0: 0.5 else: 0.32) * j(0.9, 1.0)
                    g.place(buf, pluck(note_hz(name), each * beat + 0.8, vel, 0.35), bar * 3.0 + k * each)
        case "drums":
            for(32) bar:
                g.place(buf, frame_drum(0.7 * j(0.9, 1.0), true), bar * 3.0, 0.006)
                g.place(buf, frame_drum(0.3, false), bar * 3.0 + 2.0, 0.006)
                if bar >= 16 and bar < 24: g.place(buf, frame_drum(0.25, false), bar * 3.0 + 1.5, 0.006)
                if bar >= 8:
                    g.place(buf, shaker(0.35), bar * 3.0 + 1.0, 0.006)
                    g.place(buf, shaker(0.22), bar * 3.0 + 2.5, 0.006)
        case "flute":
            for(parse(hearth_counter, 8, 3)) n: g.place(buf, flute(note_hz(n.name), n.beats * beat * 0.95, 0.55), n.on, 0.02)
            for(parse(hearth_b, 16, 3)) n:
                g.place(buf, flute(note_hz(step(n.name, -7)), n.beats * beat * 0.92, 0.75), n.on, 0.02)
            for(parse(hearth_a, 24, 3)) n:
                g.place(buf, flute(note_hz(step(n.name, -2)), n.beats * beat * 0.92, 0.6), n.on, 0.02)
        case "drone":
            for(8) i:  // a slow pedal: the first root of every four bars
                g.place(buf, drone(note_hz(hearth_roots[i * 4] + "2"), 12.0 * beat, 0.9), i * 12.0, 0.0)
        case "horns":
            for(8) i:  // B and A': soft chords held two bars
                let bar = 16 + i * 2
                for(triad(hearth_roots[bar], 3)) name, k:
                    g.place(buf, horn(note_hz(name), 5.6 * beat, 0.4 - 0.07 * k, 0.35), bar * 3.0, 0.0)
        default:  // battle
            for(32) bar:
                for([ float2 { 0.0, 1.0 }, float2 { 1.0, 0.6 }, float2 { 1.5, 0.4 }, float2 { 2.0, 0.8 }, float2 { 2.5, 0.5 } ]) p:
                    g.place(buf, low_drum(p.y, 0.4), bar * 3.0 + p.x, 0.004)
                if bar % 4 == 3:
                    for(4) k: g.place(buf, frame_drum(0.5 + 0.1 * k, false), bar * 3.0 + 1.0 + k * 0.5, 0.004)
                if bar % 8 == 0: g.place(buf, war_horn(note_hz("G2"), 2.5 * beat, 1.0), bar * 3.0, 0.0)
                if bar % 8 == 4: g.place(buf, war_horn(note_hz("D3"), 2.0 * beat, 0.8), bar * 3.0, 0.0)
    return buf

// stem -> pan, room size, wet mix: a warmer, bigger room than the theme's
def hearth_room(stem:string) -> float3:
    return switch stem:
        case "pluck": float3 { -0.2, 0.8, 0.28 }
        case "flute": float3 { 0.35, 0.85, 0.32 }
        case "drone": float3 { 0.0, 0.9, 0.22 }
        case "horns": float3 { 0.1, 0.9, 0.32 }
        case "drums": float3 { -0.15, 0.7, 0.2 }
        default: float3 { 0.0, 0.7, 0.2 }
