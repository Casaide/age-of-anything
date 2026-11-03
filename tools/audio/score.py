"""What the pieces share: a piece's clock (Grid), notes as text (parse), and steps in the white-key
scale all three pieces live in (D Dorian, G Mixolydian and E Phrygian are the same seven notes).
"""
from synth import RATE, seconds, mix_into


class Grid:
    """A piece's clock: its beat and loop length, and a sound placed on a beat (tails wrap round the loop)."""
    def __init__(self, bpm, bars, per=4):
        self.beat = 60.0 / bpm
        self.per = per
        self.loop = seconds(bars * per * self.beat)

    def place(self, buf, sound, beat, rng, human=0.012):
        at = int(beat * self.beat * RATE + rng.uniform(-human, human) * RATE)
        mix_into(buf, sound, max(0, at) % self.loop, 1.0, wrap=True)


def parse(text, bar=0, per=4):
    """'D4:1 r:.5' from a bar -> [(beat, name, beats)], beat counted from the loop's start."""
    out = []
    at = bar * float(per)
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
