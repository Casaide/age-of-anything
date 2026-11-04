// The first piece, the theme ("Whatever"), written as stems that the game mixes by age: the lute and a frame drum from
// the start, a flute and a drone from age 2, horns from age 3, and a battle layer (war drums, a ragged horn) faded in
// while there's fighting near the camera. All stems are one loop long and in time with each other, so any mix of them
// is the same tune. music_hearth and music_march are the others, score what they share.
//
// D Dorian, 92 beats a minute, 32 bars: A A B A'. Notes are text ("D4:1 F4:.5 r:2"), a token a note (or a rest) with
// its length in beats; bars are separated by '|' for reading only.

let theme = new_grid(92, 32)
let theme_a = "D4:1 F4:.5 G4:.5 A4:2 | C5:1 A4:.5 G4:.5 A4:2 | F4:1 G4:.5 A4:.5 G4:1 F4:1 | E4:2 D4:2 | " +
    "D4:1 F4:.5 G4:.5 A4:1.5 B4:.5 | C5:1 D5:1 C5:1 A4:1 | G4:1 A4:.5 G4:.5 F4:1 E4:1 | D4:3 r:1"
let theme_b = "A4:1 D5:1 C5:1 A4:1 | B4:1.5 A4:.5 G4:2 | F4:1 G4:1 A4:1 C5:1 | D5:2 C5:1 A4:1 | " +
    "A4:1 D5:1 E5:1 D5:1 | C5:1.5 A4:.5 G4:1 A4:1 | F4:1 E4:1 D4:1 E4:1 | F4:2 E4:2"
let theme_counter = "A4:4 | C5:4 | A4:4 | A4:2 F4:2 | A4:4 | A4:4 | C5:2 B4:2 | A4:4"
let theme_roots = tokenize("D D F D D C D D D D F D D C D D D G F D D C D D D D F D D C D D", " ", "")

def theme_stem(stem:string) -> [float]:
    let g = theme
    let beat = g.beat
    let buf = zeros(g.loop)
    switch stem:
        case "pluck":
            for(tune_of([ parse(theme_a, 0), parse(theme_a, 8), parse(theme_b, 16), parse(theme_a, 24) ])) n:
                g.place(buf, pluck(note_hz(n.name), n.beats * beat + 0.6, j(0.75, 0.95), 0.55), n.on)
            for(24) i:  // from the second A: the chord's root and fifth under the tune
                let bar = i + 8
                let root = theme_roots[bar]
                let fifth = triad(root, 3)[2]
                g.place(buf, pluck(note_hz(root + "3"), 2.2, 0.55, 0.35), bar * 4.0)
                g.place(buf, pluck(note_hz(fifth), 1.8, 0.4, 0.35), bar * 4.0 + 2.0)
                if bar >= 16: g.place(buf, pluck(note_hz(root + "3"), 1.0, 0.35, 0.35), bar * 4.0 + 3.0)
        case "flute":
            for(parse(theme_counter, 8)) n: g.place(buf, flute(note_hz(n.name), n.beats * beat * 0.95, 0.7), n.on, 0.02)
            for(parse(theme_b, 16)) n: g.place(buf, flute(note_hz(n.name), n.beats * beat * 0.92, 0.8), n.on, 0.02)
            for(parse(theme_a, 24)) n:
                g.place(buf, flute(note_hz(third_up(n.name)), n.beats * beat * 0.92, 0.65), n.on, 0.02)
        case "drone":
            for(root_runs(theme_roots)) r:
                g.place(buf, drone(note_hz(theme_roots[r.x] + "2"), r.y * 4 * beat, 1.0), r.x * 4.0, 0.0)
        case "horns":
            for(8) i:  // B: stabs on 1 and 3
                let bar = i + 16
                for([ 0, 2 ]) on:
                    for(triad(theme_roots[bar], 3)) name, k:
                        g.place(buf, horn(note_hz(name), 0.8 * beat, 0.7 - 0.12 * k, 0.9), float(bar * 4 + on), 0.008)
            for(8) i:  // A': held chords, soft
                let bar = i + 24
                if bar % 2 == 0:
                    for(triad(theme_roots[bar], 3)) name, k:
                        g.place(buf, horn(note_hz(name), 7.6 * beat, 0.45 - 0.08 * k, 0.5), bar * 4.0, 0.0)
        case "drums":
            let p1 = [ float3 { 0.0, 1.0, 1.0 }, float3 { 1.5, 0.0, 0.6 }, float3 { 2.0, 1.0, 0.8 }, float3 { 3.0, 0.0, 0.7 },
                       float3 { 3.5, 0.0, 0.4 } ]
            let p2 = [ float3 { 0.0, 1.0, 1.0 }, float3 { 1.0, 0.0, 0.6 }, float3 { 1.5, 1.0, 0.7 }, float3 { 2.5, 0.0, 0.8 },
                       float3 { 3.0, 1.0, 0.9 }, float3 { 3.5, 0.0, 0.5 } ]
            for(32) bar:
                for(if bar >= 16 and bar < 24: p2 else: p1) p:
                    g.place(buf, frame_drum(p.z * j(0.9, 1.0), p.y > 0.5), bar * 4.0 + p.x, 0.006)
                if bar >= 8:
                    for(8) k:
                        g.place(buf, shaker(if k % 2 == 1: 0.5 else: 0.3), bar * 4.0 + k * 0.5, 0.006)
                if bar >= 24 and bar % 2 == 0: g.place(buf, low_drum(0.8), bar * 4.0, 0.0)
        default:  // battle
            for(32) bar:
                for([ float2 { 0.0, 1.0 }, float2 { 0.5, 0.45 }, float2 { 1.0, 0.8 }, float2 { 1.5, 0.45 }, float2 { 2.0, 1.0 }, float2 { 2.5, 0.45 },
                      float2 { 3.0, 0.9 }, float2 { 3.5, 0.6 } ]) p:
                    g.place(buf, low_drum(p.y, 0.4), bar * 4.0 + p.x, 0.004)
                if bar % 4 == 3:
                    for(6) k: g.place(buf, frame_drum(0.5 + 0.08 * k, false), bar * 4.0 + 2.5 + k * 0.25, 0.004)
                if bar % 8 == 0: g.place(buf, war_horn(note_hz("A2"), 2.0 * beat, 1.0), bar * 4.0, 0.0)
                if bar % 8 == 4: g.place(buf, war_horn(note_hz("D3"), 1.5 * beat, 0.8), bar * 4.0, 0.0)
    return buf

// stem -> pan, room size, wet mix
def theme_room(stem:string) -> float3:
    return switch stem:
        case "pluck": float3 { -0.25, 0.7, 0.22 }
        case "flute": float3 { 0.3, 0.8, 0.3 }
        case "drone": float3 { 0.0, 0.9, 0.2 }
        case "horns": float3 { 0.15, 0.9, 0.3 }
        case "drums": float3 { -0.1, 0.6, 0.18 }
        default: float3 { 0.0, 0.7, 0.2 }
