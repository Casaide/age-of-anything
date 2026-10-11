"""Creature voices: what a unit says when you pick it or give it an order, and its cry when
it dies. One small vocal synth (a pulse through the formants of a throat) plus a few animal
noisemakers, tuned per creature. This is where the game's premise shows in sound: rats
squeak, frogs croak, beetles clack. Each creature has takes for 'select', 'ack' and 'die'.
"""
import math
from synth import (RATE, TAU, seconds, sine, noise, env, decay, swell, mul, gain, add, mix_into,
                   lowpass, highpass, bandpass, formants, pulse_train, soft_clip, delay_start, trim_tail)


def _contour(f0, f1, dur, curve=1.0):
    return lambda t: f0 + (f1 - f0) * min(1.0, t / dur) ** curve


def throat(rng, dur, pitch, table, breath=0.08, width=0.35, rasp=0.0, attack=0.02, release=0.06):
    """A voice: a glottal pulse (pitch a function of time) through formant resonances."""
    n = seconds(dur)
    src = pulse_train(n, pitch, width)
    if rasp > 0.0:   # a rough edge: the pulse amplitude flickers (a croak, a growl)
        src = mul(src, [1.0 - rasp * (0.5 + 0.5 * math.sin(TAU * 27.0 * i / RATE)) for i in range(n)])
    src = add(src, gain(highpass(noise(n, rng), 1500.0), breath))
    out = formants(src, table)
    return mul(out, env(n, attack, dur * 0.3, 0.8, release))


# vowel formants (F1, F2, F3) for the humans and the centaurs
VOWELS = {"a": [(700, 7, 1.0), (1200, 9, 0.5), (2600, 10, 0.2)], "u": [(330, 7, 1.0), (800, 9, 0.35), (2300, 10, 0.1)],
          "o": [(470, 7, 1.0), (900, 9, 0.4), (2400, 10, 0.12)], "e": [(500, 7, 0.9), (1800, 9, 0.5), (2500, 10, 0.25)],
          "i": [(300, 7, 0.8), (2200, 9, 0.5), (2900, 10, 0.3)]}


def _word(rng, syllables, base, stop=True):
    """Syllables [(vowel, dur, pitch_from, pitch_to), ...] in one breath, cut by a stop."""
    out = []
    at = 0.0
    for vowel, dur, p0, p1 in syllables:
        v = throat(rng, dur, _contour(base * p0, base * p1, dur), VOWELS[vowel], 0.06, 0.4, 0.0, 0.015, 0.05)
        mix_into(out, v, seconds(at))
        at += dur * 0.9
    if stop:   # a lips-closed stop at the end
        mix_into(out, gain(mul(bandpass(noise(seconds(0.02), rng), 900.0, 1.0), decay(seconds(0.02), 250.0, 0.001)), 0.3), seconds(at))
    return out


def human(rng, kind, base=118.0):
    j = rng.uniform(0.94, 1.06)
    if kind == "select":
        return _word(rng, [("e", 0.16, 1.1, 0.95)], base * j)                 # "eh?"
    if kind == "ack":
        return rng.choice([
            lambda: _word(rng, [("u", 0.14, 1.0, 0.85)], base * j),           # "hup"
            lambda: _word(rng, [("a", 0.12, 1.15, 1.0), ("o", 0.2, 1.0, 0.8)], base * j),   # "ha-ho"
            lambda: _word(rng, [("o", 0.26, 1.05, 0.9)], base * j, False),    # "oh"
        ])()
    return _word(rng, [("a", 0.45, 1.2, 0.6)], base * j, False)               # a falling cry


def centaur(rng, kind):
    """A human voice, deeper, with a hoof stamping under the order."""
    v = human(rng, kind, 92.0)
    if kind == "ack":
        stamp = add(mul(sine(seconds(0.12), lambda t: 70.0 + 60.0 * math.exp(-t * 30.0)), decay(seconds(0.12), 35.0)),
                    gain(mul(lowpass(noise(seconds(0.06), rng), 600.0), decay(seconds(0.06), 80.0)), 0.5))
        v = add(v, delay_start(gain(stamp, 0.7), 0.02))
    return v


def frog(rng, kind):
    """A croak: a low raspy pulse, lips-closed formants; the cry is a long falling 'wraak'."""
    table = [(380, 6, 1.0), (1100, 8, 0.3), (2100, 10, 0.08)]
    if kind == "select":
        return throat(rng, 0.14, _contour(130.0, 100.0, 0.14), table, 0.03, 0.25, 0.8, 0.01, 0.04)
    if kind == "ack":
        n = rng.choice([1, 2])
        out = []
        for k in range(n):
            mix_into(out, throat(rng, 0.17, _contour(110.0 * rng.uniform(0.9, 1.1), 85.0, 0.17), table, 0.03, 0.25, 0.9, 0.01, 0.05), seconds(k * 0.2))
        return out
    return throat(rng, 0.5, _contour(150.0, 70.0, 0.5, 0.6), table, 0.05, 0.3, 0.7, 0.01, 0.1)


def rat(rng, kind):
    """A squeak: a high tone with a quick wobble; the cry is a long squeal."""
    def squeak(dur, f0, f1, wob):
        n = seconds(dur)
        tone = sine(n, lambda t: (f0 + (f1 - f0) * t / dur) * (1.0 + 0.04 * math.sin(TAU * wob * t)))
        tone = add(tone, gain(sine(n, lambda t: 2.0 * (f0 + (f1 - f0) * t / dur)), 0.25))
        return mul(tone, env(n, 0.008, dur * 0.3, 0.7, dur * 0.3))
    if kind == "select":
        return squeak(0.09, 3200.0 * rng.uniform(0.9, 1.1), 3600.0, 40.0)
    if kind == "ack":
        a = squeak(0.08, 2900.0 * rng.uniform(0.9, 1.1), 3700.0, 35.0)
        b = squeak(0.1, 3400.0, 2600.0, 30.0)
        return add(a, delay_start(b, 0.1))
    return squeak(0.45, 3300.0, 1900.0, 22.0)


def beetle(rng, kind):
    """Clacks of the jaws and a buzz of the wing cases."""
    def clacks(count, gap, pitch):
        out = []
        for k in range(count):
            c = mul(bandpass(noise(seconds(0.012), rng), pitch * rng.uniform(0.9, 1.1), 1.5, 2.0), decay(seconds(0.012), 400.0, 0.0005))
            mix_into(out, c, seconds(k * gap * rng.uniform(0.85, 1.15)))
        return out
    def buzz(dur, f):
        n = seconds(dur)
        src = mul(pulse_train(n, f, 0.2), [0.6 + 0.4 * math.sin(TAU * 61.0 * i / RATE) for i in range(n)])
        return mul(bandpass(src, 900.0, 1.2, 2.0), env(n, 0.02, dur * 0.4, 0.6, 0.06))
    if kind == "select":
        return clacks(2, 0.06, 2400.0)
    if kind == "ack":
        return add(clacks(3, 0.05, 2200.0), delay_start(gain(buzz(0.14, 165.0), 0.6), 0.12))
    return add(gain(buzz(0.45, 140.0), 0.8), clacks(5, 0.07, 1800.0))


def spider(rng, kind):
    """A chitter: a fast ripple of high clicks, and a hiss when it dies."""
    def chitter(dur, rate, f):
        n = seconds(dur)
        out = [0.0] * n
        k = 0
        at = 0.0
        while at < dur:
            c = mul(bandpass(noise(seconds(0.006), rng), f * (1.0 + 0.3 * at / dur), 2.0, 2.5), decay(seconds(0.006), 700.0, 0.0003))
            mix_into(out, c, seconds(at))
            at += (1.0 / rate) * rng.uniform(0.8, 1.2)
            k += 1
        return mul(out, env(n, 0.01, dur * 0.4, 0.7, 0.03))
    if kind == "select":
        return chitter(0.12, 45.0, 4200.0)
    if kind == "ack":
        return chitter(0.2, 38.0, 3800.0)
    hiss = mul(bandpass(noise(seconds(0.5), rng), 5000.0, 0.7, 1.5), env(seconds(0.5), 0.03, 0.2, 0.5, 0.2))
    return add(chitter(0.3, 30.0, 3000.0), gain(hiss, 0.5))


def pony(rng, kind):
    """A whinny (a glide down with a shake) for orders; a snort when picked; a scream when it dies."""
    table = [(650, 6, 1.0), (1700, 8, 0.5), (2600, 9, 0.2)]
    def whinny(dur, f0, f1):
        return throat(rng, dur, lambda t: (f0 + (f1 - f0) * (t / dur) ** 0.7) * (1.0 + 0.05 * math.sin(TAU * 13.0 * t)), table, 0.1, 0.5, 0.0, 0.03, 0.08)
    def snort(dur):
        n = seconds(dur)
        return mul(mul(lowpass(noise(n, rng), 1800.0), [0.5 + 0.5 * math.sin(TAU * 26.0 * i / RATE) for i in range(n)]), env(n, 0.01, dur * 0.4, 0.5, 0.05))
    if kind == "select":
        return gain(snort(0.18), 1.3)
    if kind == "ack":
        return whinny(0.32, 800.0 * rng.uniform(0.92, 1.08), 420.0)
    return whinny(0.6, 950.0, 300.0)


def capybara(rng, kind):
    """A soft chirruping purr."""
    def chirp(f0, f1, dur):
        n = seconds(dur)
        return mul(add(sine(n, _contour(f0, f1, dur)), gain(sine(n, _contour(f0 * 2.0, f1 * 2.0, dur)), 0.3)), env(n, 0.01, dur * 0.4, 0.5, 0.02))
    def purr(dur, f):
        n = seconds(dur)
        return gain(mul(bandpass(pulse_train(n, f, 0.15), 700.0, 1.0, 2.0), env(n, 0.03, dur * 0.4, 0.6, 0.05)), 0.8)
    if kind == "select":
        return chirp(1500.0 * rng.uniform(0.95, 1.05), 2100.0, 0.08)
    if kind == "ack":
        out = []
        for k in range(rng.choice([2, 3])):
            mix_into(out, chirp(1400.0 * rng.uniform(0.95, 1.05), 1900.0, 0.07), seconds(k * 0.1))
        return add(out, gain(purr(0.25, 24.0), 0.5))
    return add(chirp(2000.0, 900.0, 0.4), delay_start(purr(0.3, 18.0), 0.1))


CREATURES = {"frog": frog, "rat": rat, "human": human, "spider": spider, "beetle": beetle,
             "pony": pony, "centaur": centaur, "capybara": capybara}
KINDS = {"select": 2, "ack": 3, "die": 2}   # takes per kind
PEAK_DB = -4.0
