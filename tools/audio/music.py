"""The theme ("Whatever"), written as stems that the game mixes by age: the lute and a frame
drum from the start, a flute and a drone from age 2, horns from age 3, and a battle layer
(war drums, a ragged horn) faded in while there's fighting near the camera. All stems are
one loop long and in time with each other, so any mix of them is the same tune.

D Dorian, 92 beats a minute, 32 bars: A A B A'. Notes are text ("D4:1 F4:.5 r:2"), a token a
note (or a rest) with its length in beats; bars are separated by '|' for reading only.
"""
import math
import random
from synth import (RATE, seconds, mix_into, concat, reverb, gain, pan, widen, add, fade)
import instruments as I

BPM = 92
BARS = 32
BEAT = 60.0 / BPM
LOOP = seconds(BARS * 4 * BEAT)
SCALE = ["D", "E", "F", "G", "A", "B", "C"]          # D Dorian

MELODY_A = ("D4:1 F4:.5 G4:.5 A4:2 | C5:1 A4:.5 G4:.5 A4:2 | F4:1 G4:.5 A4:.5 G4:1 F4:1 | E4:2 D4:2 | "
            "D4:1 F4:.5 G4:.5 A4:1.5 B4:.5 | C5:1 D5:1 C5:1 A4:1 | G4:1 A4:.5 G4:.5 F4:1 E4:1 | D4:3 r:1")
MELODY_B = ("A4:1 D5:1 C5:1 A4:1 | B4:1.5 A4:.5 G4:2 | F4:1 G4:1 A4:1 C5:1 | D5:2 C5:1 A4:1 | "
            "A4:1 D5:1 E5:1 D5:1 | C5:1.5 A4:.5 G4:1 A4:1 | F4:1 E4:1 D4:1 E4:1 | F4:2 E4:2")
COUNTER = "A4:4 | C5:4 | A4:4 | A4:2 F4:2 | A4:4 | A4:4 | C5:2 B4:2 | A4:4"
ROOTS_A = ["D", "D", "F", "D", "D", "C", "D", "D"]
ROOTS_B = ["D", "G", "F", "D", "D", "C", "D", "D"]
ROOTS = ROOTS_A + ROOTS_A + ROOTS_B + ROOTS_A


def parse(text, bar=0):
    """'D4:1 r:.5' from a bar -> [(beat, name, beats)], beat counted from the loop's start."""
    out = []
    at = bar * 4.0
    for tok in text.replace("|", " ").split():
        name, dur = tok.split(":")
        dur = float(dur)
        if name != "r":
            out.append((at, name, dur))
        at += dur
    return out


NATURALS = "CDEFGAB"   # the scale is all naturals; octave numbers turn over at C


def step(name, degrees):
    """A note some scale steps up (or down) from another: 'A4', 2 -> 'C5'."""
    i = NATURALS.index(name[0]) + int(name[1:]) * 7 + degrees
    return "%s%d" % (NATURALS[i % 7], i // 7)


def third_up(name):
    return step(name, 2)


def triad(root, octave):
    base = root + str(octave)
    return [base, step(base, 2), step(base, 4)]


def _place(buf, sound, beat, rng, human=0.012):
    at = int(beat * BEAT * RATE + rng.uniform(-human, human) * RATE)
    mix_into(buf, sound, max(0, at) % LOOP, 1.0, wrap=True)


# ----------------------------------------------------------------------------- the stems

def stem_pluck(rng):
    buf = [0.0] * LOOP
    tune = parse(MELODY_A, 0) + parse(MELODY_A, 8) + parse(MELODY_B, 16) + parse(MELODY_A, 24)
    for beat, name, dur in tune:
        _place(buf, I.pluck(I.note_hz(name), dur * BEAT + 0.6, rng, rng.uniform(0.75, 0.95), 0.55), beat, rng)
    for bar in range(8, BARS):   # from the second A: the chord's root and fifth under the tune
        root = ROOTS[bar]
        fifth = triad(root, 3)[2]
        _place(buf, I.pluck(I.note_hz(root + "3"), 2.2, rng, 0.55, 0.35), bar * 4, rng)
        _place(buf, I.pluck(I.note_hz(fifth), 1.8, rng, 0.4, 0.35), bar * 4 + 2, rng)
        if bar >= 16:
            _place(buf, I.pluck(I.note_hz(root + "3"), 1.0, rng, 0.35, 0.35), bar * 4 + 3, rng)
    return buf


def stem_flute(rng):
    buf = [0.0] * LOOP
    for beat, name, dur in parse(COUNTER, 8):
        _place(buf, I.flute(I.note_hz(name), dur * BEAT * 0.95, rng, 0.7), beat, rng, 0.02)
    for beat, name, dur in parse(MELODY_B, 16):
        _place(buf, I.flute(I.note_hz(name), dur * BEAT * 0.92, rng, 0.8), beat, rng, 0.02)
    for beat, name, dur in parse(MELODY_A, 24):
        _place(buf, I.flute(I.note_hz(third_up(name)), dur * BEAT * 0.92, rng, 0.65), beat, rng, 0.02)
    return buf


def stem_drone(rng):
    buf = [0.0] * LOOP
    bar = 0
    while bar < BARS:
        end = bar + 1
        while end < BARS and ROOTS[end] == ROOTS[bar]:
            end += 1
        dur = (end - bar) * 4 * BEAT
        _place(buf, I.drone(I.note_hz(ROOTS[bar] + "2"), dur, rng, 1.0), bar * 4, rng, 0.0)
        bar = end
    return buf


def stem_horns(rng):
    buf = [0.0] * LOOP
    for bar in range(16, 24):   # B: stabs on 1 and 3
        for beat in (0, 2):
            for k, name in enumerate(triad(ROOTS[bar], 3)):
                _place(buf, I.horn(I.note_hz(name), 0.8 * BEAT, rng, 0.7 - 0.12 * k, 0.9), bar * 4 + beat, rng, 0.008)
    for bar in range(24, BARS):   # A': held chords, soft
        if bar % 2 == 0:
            for k, name in enumerate(triad(ROOTS[bar], 3)):
                _place(buf, I.horn(I.note_hz(name), 7.6 * BEAT, rng, 0.45 - 0.08 * k, 0.5), bar * 4, rng, 0.0)
    return buf


def stem_drums(rng):
    buf = [0.0] * LOOP
    p1 = [(0, True, 1.0), (1.5, False, 0.6), (2, True, 0.8), (3, False, 0.7), (3.5, False, 0.4)]
    p2 = [(0, True, 1.0), (1, False, 0.6), (1.5, True, 0.7), (2.5, False, 0.8), (3, True, 0.9), (3.5, False, 0.5)]
    for bar in range(BARS):
        pat = p2 if 16 <= bar < 24 else p1
        for beat, low, vel in pat:
            _place(buf, I.frame_drum(rng, vel * rng.uniform(0.9, 1.0), low), bar * 4 + beat, rng, 0.006)
        if bar >= 8:
            for k in range(8):
                _place(buf, I.shaker(rng, 0.5 if k % 2 else 0.3), bar * 4 + k * 0.5, rng, 0.006)
        if bar >= 24 and bar % 2 == 0:
            _place(buf, I.low_drum(rng, 0.8), bar * 4, rng, 0.0)
    return buf


def stem_battle(rng):
    buf = [0.0] * LOOP
    for bar in range(BARS):
        for beat, vel in [(0, 1.0), (0.5, 0.45), (1, 0.8), (1.5, 0.45), (2, 1.0), (2.5, 0.45), (3, 0.9), (3.5, 0.6)]:
            _place(buf, I.low_drum(rng, vel, 0.4), bar * 4 + beat, rng, 0.004)
        if bar % 4 == 3:
            for k in range(6):
                _place(buf, I.frame_drum(rng, 0.5 + 0.08 * k, False), bar * 4 + 2.5 + k * 0.25, rng, 0.004)
        if bar % 8 == 0:
            _place(buf, I.war_horn(I.note_hz("A2"), 2.0 * BEAT, rng, 1.0), bar * 4, rng, 0.0)
        if bar % 8 == 4:
            _place(buf, I.war_horn(I.note_hz("D3"), 1.5 * BEAT, rng, 0.8), bar * 4, rng, 0.0)
    return buf


# name -> (stem, pan, room size, wet mix)
STEMS = {
    "pluck": (stem_pluck, -0.25, 0.7, 0.22),
    "flute": (stem_flute, 0.3, 0.8, 0.3),
    "drone": (stem_drone, 0.0, 0.9, 0.2),
    "horns": (stem_horns, 0.15, 0.9, 0.3),
    "drums": (stem_drums, -0.1, 0.6, 0.18),
    "battle": (stem_battle, 0.0, 0.7, 0.2),
}


def render_stem(name, seed=7):
    """A seamless loop: tails wrap, and the room's tail from the end lands on the start."""
    fn, p, size, wet = STEMS[name]
    rng = random.Random(seed + hash(name) % 1000 if False else seed + sum(map(ord, name)))
    dry = fn(rng)
    twice = reverb(concat(dry, dry), size, wet)
    loop = twice[LOOP:]
    return loop, p
