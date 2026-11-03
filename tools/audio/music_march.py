"""The third piece ("March"): the war, for when a match turns into a long fight. Faster than the
theme, driven by a lute ostinato that never lets go of its root, and dark: E Phrygian (the theme's
seven notes round E, the half step F over E is the tension). 112 beats a minute, 4/4, 32 bars:
an A of ostinato and drums alone, A with the tune, B climbing, A' with the horns on the tune.
About 69 seconds.

The same stems as the theme hold the same roles:
pluck (the ostinato, the tune on a bright lute from bar 9) | drums (a march on the frame drum) |
flute (high held notes, the tune in B, a third over it in A') | drone (bowed roots) |
horns (stabs in B, the tune itself in A') | battle (war drums in sixteenths, a horn every four bars).
"""
import instruments as I
from score import Grid, parse, step, third_up, triad

G = Grid(112, 32)
BEAT = G.beat

MELODY_A = ("E4:1.5 F4:.5 E4:1 B3:1 | C4:1 D4:1 E4:2 | G4:1.5 F4:.5 E4:1 D4:1 | E4:3 r:1 | "
            "E4:1.5 F4:.5 G4:1 A4:1 | B4:1 C5:1 B4:1 A4:1 | G4:1.5 F4:.5 E4:1 F4:1 | E4:4")
MELODY_B = ("A4:1 A4:.5 B4:.5 C5:2 | B4:1 A4:1 G4:2 | F4:1 G4:1 A4:1 B4:1 | C5:3 r:1 | "
            "D5:1 C5:1 B4:1 A4:1 | G4:1.5 A4:.5 F4:2 | E4:1 F4:1 G4:1 F4:1 | E4:2 r:2")
HIGH = "B5:4 | C6:4 | B5:4 | B5:4 | B5:4 | A5:4 | B5:2 A5:2 | B5:4"
ROOTS_A = ["E", "C", "G", "E", "E", "A", "F", "E"]
ROOTS_B = ["A", "G", "F", "C", "D", "D", "F", "E"]
ROOTS = ROOTS_A + ROOTS_A + ROOTS_B + ROOTS_A
BARS = len(ROOTS)
OSTINATO = [0, 0, 1, 0, 0, 2, 1, 0]   # scale steps over the bar's root, in eighths


def stem_pluck(rng):
    buf = [0.0] * G.loop
    for bar in range(BARS):
        base = ROOTS[bar] + ("2" if ROOTS[bar] in "AG" else "3")
        for k, s in enumerate(OSTINATO):
            vel = (0.6 if k % 4 == 0 else 0.4) * rng.uniform(0.9, 1.0)
            G.place(buf, I.pluck(I.note_hz(step(base, s)), 0.5 * BEAT + 0.12, rng, vel, 0.3, 0.99), bar * 4 + k * 0.5, rng, 0.004)
    tune = parse(MELODY_A, 8) + parse(MELODY_B, 16) + parse(MELODY_A, 24)
    for beat, name, dur in tune:
        G.place(buf, I.pluck(I.note_hz(step(name, 7)), dur * BEAT + 0.4, rng, rng.uniform(0.75, 0.9), 0.8), beat, rng, 0.006)
    return buf


def stem_drums(rng):
    buf = [0.0] * G.loop
    for bar in range(BARS):
        for beat, low, vel in [(0, True, 1.0), (1, False, 0.7), (2, True, 0.85), (2.5, True, 0.5), (3, False, 0.75)]:
            G.place(buf, I.frame_drum(rng, vel * rng.uniform(0.9, 1.0), low), bar * 4 + beat, rng, 0.004)
        if bar % 4 == 3:   # a roll into the next phrase
            for k in range(4):
                G.place(buf, I.frame_drum(rng, 0.4 + 0.12 * k, False), bar * 4 + 3 + k * 0.25, rng, 0.004)
        if bar >= 8:
            for k in range(8):
                G.place(buf, I.shaker(rng, 0.45 if k % 2 else 0.25), bar * 4 + k * 0.5, rng, 0.004)
        if bar >= 24 and bar % 2 == 0:
            G.place(buf, I.low_drum(rng, 0.8), bar * 4, rng, 0.0)
    return buf


def stem_flute(rng):
    buf = [0.0] * G.loop
    for beat, name, dur in parse(HIGH, 8):
        G.place(buf, I.flute(I.note_hz(step(name, -7)), dur * BEAT * 0.95, rng, 0.6), beat, rng, 0.015)
    for beat, name, dur in parse(MELODY_B, 16):
        G.place(buf, I.flute(I.note_hz(step(name, 7)), dur * BEAT * 0.9, rng, 0.7), beat, rng, 0.015)
    for beat, name, dur in parse(MELODY_A, 24):
        G.place(buf, I.flute(I.note_hz(third_up(step(name, 7))), dur * BEAT * 0.9, rng, 0.55), beat, rng, 0.015)
    return buf


def stem_drone(rng):
    buf = [0.0] * G.loop
    bar = 0
    while bar < BARS:
        end = bar + 1
        while end < BARS and ROOTS[end] == ROOTS[bar]:
            end += 1
        G.place(buf, I.drone(I.note_hz(ROOTS[bar] + "2"), (end - bar) * 4 * BEAT, rng, 1.0), bar * 4, rng, 0.0)
        bar = end
    return buf


def stem_horns(rng):
    buf = [0.0] * G.loop
    for bar in range(16, 24):   # B: stabs on 1 and the and of 2
        for beat in (0, 1.5):
            for k, name in enumerate(triad(ROOTS[bar], 3)):
                G.place(buf, I.horn(I.note_hz(name), 0.6 * BEAT, rng, 0.7 - 0.12 * k, 1.0), bar * 4 + beat, rng, 0.006)
    for beat, name, dur in parse(MELODY_A, 24):   # A': the tune as a horn call, the root under it
        G.place(buf, I.horn(I.note_hz(name), dur * BEAT * 0.9, rng, 0.7, 0.9), beat, rng, 0.006)
    for bar in range(24, BARS):
        G.place(buf, I.horn(I.note_hz(ROOTS[bar] + "2"), 3.8 * BEAT, rng, 0.45, 0.6), bar * 4, rng, 0.0)
    return buf


def stem_battle(rng):
    buf = [0.0] * G.loop
    for bar in range(BARS):
        for k in range(16):
            vel = 1.0 if k % 4 == 0 else (0.55 if k % 2 == 0 else 0.3)
            G.place(buf, I.low_drum(rng, vel, 0.35), bar * 4 + k * 0.25, rng, 0.003)
        if bar % 2 == 1:
            for k in range(4):
                G.place(buf, I.frame_drum(rng, 0.55 + 0.1 * k, False), bar * 4 + 3 + k * 0.25, rng, 0.003)
        if bar % 4 == 0:
            G.place(buf, I.war_horn(I.note_hz("E2" if bar % 8 == 0 else "F2"), 2.5 * BEAT, rng, 1.0), bar * 4, rng, 0.0)
    return buf


# name -> (stem, pan, room size, wet mix): a drier, closer room than the theme's
STEMS = {
    "pluck": (stem_pluck, -0.25, 0.6, 0.18),
    "flute": (stem_flute, 0.3, 0.75, 0.25),
    "drone": (stem_drone, 0.0, 0.85, 0.18),
    "horns": (stem_horns, 0.15, 0.85, 0.26),
    "drums": (stem_drums, -0.1, 0.55, 0.15),
    "battle": (stem_battle, 0.0, 0.6, 0.18),
}
