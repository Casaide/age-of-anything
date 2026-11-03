"""The second piece ("Hearth"): the town at work, for the long building stretches of a match. Slower
than the theme and in three: a lilt, not a stride. G Mixolydian (the theme's seven notes round G, so
the stings in D still sit in it), 72 beats a minute, 3/4, 32 bars: A A B A', 80 seconds.

The tune is on a wooden tongue drum over a lute rolling the chord; the same stems as the theme hold
the same roles, so the game's mixes by age work on it unchanged:
pluck (tongue drum tune, lute chords) | drums (a hand drum, barely there) | flute (a counter, the
tune in B, a third below in A') | drone (bowed G and C) | horns (soft held chords) | battle (war
drums in three, a horn call).
"""
import instruments as I
from score import Grid, parse, step, triad

G = Grid(72, 32, 3)
BEAT = G.beat

MELODY_A = ("G4:1.5 A4:.5 B4:1 | D5:2 B4:1 | C5:1 B4:1 A4:1 | G4:2 E4:1 | "
            "F4:1.5 G4:.5 A4:1 | C5:2 A4:1 | B4:1 A4:1 F4:1 | G4:3")
MELODY_B = ("E5:1.5 D5:.5 C5:1 | D5:2 G4:1 | C5:1.5 B4:.5 A4:1 | F4:2 A4:1 | "
            "E5:1.5 D5:.5 C5:1 | B4:1 C5:1 D5:1 | A4:1.5 G4:.5 F4:1 | G4:2 r:1")
COUNTER = "D5:3 | D5:3 | E5:3 | E5:3 | C5:3 | C5:3 | D5:3 | B4:3"
ROOTS_A = ["G", "G", "C", "C", "F", "F", "G", "G"]
ROOTS_B = ["C", "G", "A", "F", "C", "G", "F", "G"]
ROOTS = ROOTS_A + ROOTS_A + ROOTS_B + ROOTS_A
BARS = len(ROOTS)


def tune():
    return parse(MELODY_A, 0, 3) + parse(MELODY_A, 8, 3) + parse(MELODY_B, 16, 3) + parse(MELODY_A, 24, 3)


def stem_pluck(rng):
    buf = [0.0] * G.loop
    for beat, name, dur in tune():
        G.place(buf, I.bell(I.note_hz(name), dur * BEAT + 0.9, rng, rng.uniform(0.8, 0.95)), beat, rng)
    for bar in range(BARS):   # the lute rolls the chord: root, fifth, third an octave up (in eighths from bar 9)
        root, third, fifth = triad(ROOTS[bar], 3)
        roll = [root, fifth, step(third, 7)] if bar < 8 else [root, fifth, step(third, 7), fifth, step(root, 7), fifth]
        each = 3.0 / len(roll)
        for k, name in enumerate(roll):
            vel = (0.5 if k == 0 else 0.32) * rng.uniform(0.9, 1.0)
            G.place(buf, I.pluck(I.note_hz(name), each * BEAT + 0.8, rng, vel, 0.35), bar * 3 + k * each, rng)
    return buf


def stem_drums(rng):
    buf = [0.0] * G.loop
    for bar in range(BARS):
        G.place(buf, I.frame_drum(rng, 0.7 * rng.uniform(0.9, 1.0), True), bar * 3, rng, 0.006)
        G.place(buf, I.frame_drum(rng, 0.3, False), bar * 3 + 2, rng, 0.006)
        if 16 <= bar < 24:
            G.place(buf, I.frame_drum(rng, 0.25, False), bar * 3 + 1.5, rng, 0.006)
        if bar >= 8:
            G.place(buf, I.shaker(rng, 0.35), bar * 3 + 1, rng, 0.006)
            G.place(buf, I.shaker(rng, 0.22), bar * 3 + 2.5, rng, 0.006)
    return buf


def stem_flute(rng):
    buf = [0.0] * G.loop
    for beat, name, dur in parse(COUNTER, 8, 3):
        G.place(buf, I.flute(I.note_hz(name), dur * BEAT * 0.95, rng, 0.55), beat, rng, 0.02)
    for beat, name, dur in parse(MELODY_B, 16, 3):
        G.place(buf, I.flute(I.note_hz(step(name, -7)), dur * BEAT * 0.92, rng, 0.75), beat, rng, 0.02)
    for beat, name, dur in parse(MELODY_A, 24, 3):
        G.place(buf, I.flute(I.note_hz(step(name, -2)), dur * BEAT * 0.92, rng, 0.6), beat, rng, 0.02)
    return buf


def stem_drone(rng):
    buf = [0.0] * G.loop
    for bar in range(0, BARS, 4):   # a slow pedal: the first root of every four bars
        G.place(buf, I.drone(I.note_hz(ROOTS[bar] + "2"), 12 * BEAT, rng, 0.9), bar * 3, rng, 0.0)
    return buf


def stem_horns(rng):
    buf = [0.0] * G.loop
    for bar in range(16, BARS, 2):   # B and A': soft chords held two bars
        for k, name in enumerate(triad(ROOTS[bar], 3)):
            G.place(buf, I.horn(I.note_hz(name), 5.6 * BEAT, rng, 0.4 - 0.07 * k, 0.35), bar * 3, rng, 0.0)
    return buf


def stem_battle(rng):
    buf = [0.0] * G.loop
    for bar in range(BARS):
        for beat, vel in [(0, 1.0), (1, 0.6), (1.5, 0.4), (2, 0.8), (2.5, 0.5)]:
            G.place(buf, I.low_drum(rng, vel, 0.4), bar * 3 + beat, rng, 0.004)
        if bar % 4 == 3:
            for k in range(4):
                G.place(buf, I.frame_drum(rng, 0.5 + 0.1 * k, False), bar * 3 + 1 + k * 0.5, rng, 0.004)
        if bar % 8 == 0:
            G.place(buf, I.war_horn(I.note_hz("G2"), 2.5 * BEAT, rng, 1.0), bar * 3, rng, 0.0)
        if bar % 8 == 4:
            G.place(buf, I.war_horn(I.note_hz("D3"), 2.0 * BEAT, rng, 0.8), bar * 3, rng, 0.0)
    return buf


# name -> (stem, pan, room size, wet mix): a warmer, bigger room than the theme's
STEMS = {
    "pluck": (stem_pluck, -0.2, 0.8, 0.28),
    "flute": (stem_flute, 0.35, 0.85, 0.32),
    "drone": (stem_drone, 0.0, 0.9, 0.22),
    "horns": (stem_horns, 0.1, 0.9, 0.32),
    "drums": (stem_drums, -0.15, 0.7, 0.2),
    "battle": (stem_battle, 0.0, 0.7, 0.2),
}
