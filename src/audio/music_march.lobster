// The third piece ("March"): the war, for when a match turns into a long fight. Faster than the theme, driven by a lute
// ostinato that never lets go of its root, and dark: E Phrygian (the theme's seven notes round E, the half step F over
// E is the tension). 112 beats a minute, 4/4, 32 bars: an A of ostinato and drums alone, A with the tune, B climbing, A'
// with the horns on the tune. About 69 seconds.
//
// The same stems as the theme hold the same roles: pluck (the ostinato, the tune on a bright lute from bar 9) | drums (a
// march on the frame drum) | flute (high held notes, the tune in B, a third over it in A') | drone (bowed roots) | horns
// (stabs in B, the tune itself in A') | battle (war drums in sixteenths, a horn every four bars).

let march = new_grid(112, 32)
let march_a = "E4:1.5 F4:.5 E4:1 B3:1 | C4:1 D4:1 E4:2 | G4:1.5 F4:.5 E4:1 D4:1 | E4:3 r:1 | " +
    "E4:1.5 F4:.5 G4:1 A4:1 | B4:1 C5:1 B4:1 A4:1 | G4:1.5 F4:.5 E4:1 F4:1 | E4:4"
let march_b = "A4:1 A4:.5 B4:.5 C5:2 | B4:1 A4:1 G4:2 | F4:1 G4:1 A4:1 B4:1 | C5:3 r:1 | " +
    "D5:1 C5:1 B4:1 A4:1 | G4:1.5 A4:.5 F4:2 | E4:1 F4:1 G4:1 F4:1 | E4:2 r:2"
let march_high = "B5:4 | C6:4 | B5:4 | B5:4 | B5:4 | A5:4 | B5:2 A5:2 | B5:4"
let march_roots = tokenize("E C G E E A F E E C G E E A F E A G F C D D F E E C G E E A F E", " ", "")
let march_ostinato = [ 0, 0, 1, 0, 0, 2, 1, 0 ]  // scale steps over the bar's root, in eighths

def march_stem(stem:string) -> [float]:
    let g = march
    let beat = g.beat
    let buf = zeros(g.loop)
    switch stem:
        case "pluck":
            for(32) bar:
                let root = march_roots[bar]
                let base = root + (if root == "A" or root == "G": "2" else: "3")
                for(march_ostinato) s, k:
                    let vel = (if k % 4 == 0: 0.6 else: 0.4) * j(0.9, 1.0)
                    g.place(buf, pluck(note_hz(step(base, s)), 0.5 * beat + 0.12, vel, 0.3, 0.99), bar * 4.0 + k * 0.5, 0.004)
            for(tune_of([ parse(march_a, 8), parse(march_b, 16), parse(march_a, 24) ])) n:
                g.place(buf, pluck(note_hz(step(n.name, 7)), n.beats * beat + 0.4, j(0.75, 0.9), 0.8), n.on, 0.006)
        case "drums":
            let pat = [ float3 { 0.0, 1.0, 1.0 }, float3 { 1.0, 0.0, 0.7 }, float3 { 2.0, 1.0, 0.85 }, float3 { 2.5, 1.0, 0.5 },
                        float3 { 3.0, 0.0, 0.75 } ]
            for(32) bar:
                for(pat) p: g.place(buf, frame_drum(p.z * j(0.9, 1.0), p.y > 0.5), bar * 4.0 + p.x, 0.004)
                if bar % 4 == 3:  // a roll into the next phrase
                    for(4) k: g.place(buf, frame_drum(0.4 + 0.12 * k, false), bar * 4.0 + 3.0 + k * 0.25, 0.004)
                if bar >= 8:
                    for(8) k: g.place(buf, shaker(if k % 2 == 1: 0.45 else: 0.25), bar * 4.0 + k * 0.5, 0.004)
                if bar >= 24 and bar % 2 == 0: g.place(buf, low_drum(0.8), bar * 4.0, 0.0)
        case "flute":
            for(parse(march_high, 8)) n:
                g.place(buf, flute(note_hz(step(n.name, -7)), n.beats * beat * 0.95, 0.6), n.on, 0.015)
            for(parse(march_b, 16)) n:
                g.place(buf, flute(note_hz(step(n.name, 7)), n.beats * beat * 0.9, 0.7), n.on, 0.015)
            for(parse(march_a, 24)) n:
                g.place(buf, flute(note_hz(third_up(step(n.name, 7))), n.beats * beat * 0.9, 0.55), n.on, 0.015)
        case "drone":
            for(root_runs(march_roots)) r:
                g.place(buf, drone(note_hz(march_roots[r.x] + "2"), r.y * 4 * beat, 1.0), r.x * 4.0, 0.0)
        case "horns":
            for(8) i:  // B: stabs on 1 and the and of 2
                let bar = i + 16
                for([ 0.0, 1.5 ]) on:
                    for(triad(march_roots[bar], 3)) name, k:
                        g.place(buf, horn(note_hz(name), 0.6 * beat, 0.7 - 0.12 * k, 1.0), bar * 4.0 + on, 0.006)
            for(parse(march_a, 24)) n:  // A': the tune as a horn call, the root under it
                g.place(buf, horn(note_hz(n.name), n.beats * beat * 0.9, 0.7, 0.9), n.on, 0.006)
            for(8) i:
                let bar = i + 24
                g.place(buf, horn(note_hz(march_roots[bar] + "2"), 3.8 * beat, 0.45, 0.6), bar * 4.0, 0.0)
        default:  // battle
            for(32) bar:
                for(16) k:
                    let vel = if k % 4 == 0: 1.0 else: (if k % 2 == 0: 0.55 else: 0.3)
                    g.place(buf, low_drum(vel, 0.35), bar * 4.0 + k * 0.25, 0.003)
                if bar % 2 == 1:
                    for(4) k: g.place(buf, frame_drum(0.55 + 0.1 * k, false), bar * 4.0 + 3.0 + k * 0.25, 0.003)
                if bar % 4 == 0:
                    g.place(buf, war_horn(note_hz(if bar % 8 == 0: "E2" else: "F2"), 2.5 * beat, 1.0), bar * 4.0, 0.0)
    return buf

// stem -> pan, room size, wet mix: a drier, closer room than the theme's
def march_room(stem:string) -> float3:
    return switch stem:
        case "pluck": float3 { -0.25, 0.6, 0.18 }
        case "flute": float3 { 0.3, 0.75, 0.25 }
        case "drone": float3 { 0.0, 0.85, 0.18 }
        case "horns": float3 { 0.15, 0.85, 0.26 }
        case "drums": float3 { -0.1, 0.55, 0.15 }
        default: float3 { 0.0, 0.6, 0.18 }
