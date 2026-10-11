"""Instruments: a note in, a mono buffer out. Hand-made and acoustic by design (wood, hide,
reed, bronze): the game's music and its jingles share these so the stings sit in the music.
"""
import math
from synth import (RATE, TAU, seconds, sine, saw, noise, env, decay, swell, mul, gain, add,
                   lowpass, highpass, bandpass, modal, soft_clip, mix_into, pulse_train)


def pluck(freq, dur, rng, vel=1.0, bright=0.6, sustain=0.996):
    """A plucked gut string (Karplus-Strong with a tuned fractional delay): a lute, a harp."""
    n = seconds(dur)
    L = RATE / freq - 0.5
    size = int(L) + 2
    frac = L - int(L)
    line = noise(size, rng)
    line = lowpass(line, 1200.0 + 6000.0 * bright)       # a soft pick: fewer high partials
    out = [0.0] * n
    p = 0
    prev = 0.0
    for i in range(n):
        a = line[p]
        b = line[(p + 1) % size]
        x = a + (b - a) * frac
        y = sustain * 0.5 * (x + prev)
        prev = x
        line[p] = y
        p = (p + 1) % size
        out[i] = y
    body = bandpass(out, 220.0, 0.8, 0.6)                 # the sound box
    out = add(out, body)
    tail = max(1, seconds(min(0.05, dur * 0.3)))
    for i in range(tail):
        out[n - 1 - i] *= i / tail
    return gain(out, vel * 0.9)


def flute(freq, dur, rng, vel=1.0, vib=5.5, breath=0.12):
    """A wooden flute: a near-sine with a touch of second partial, breath noise, slow vibrato."""
    n = seconds(dur)
    def f(t):
        return freq * (1.0 + 0.006 * math.sin(TAU * vib * t) * min(1.0, t * 2.5))
    tone = add(sine(n, f), gain(sine(n, lambda t: f(t) * 2.0), 0.18), gain(sine(n, lambda t: f(t) * 3.0), 0.05))
    air = bandpass(noise(n, rng), freq * 2.0, 2.0, breath * 2.5)
    chiff = mul(bandpass(noise(seconds(0.03), rng), freq * 1.5, 1.5, 1.5), decay(seconds(0.03), 90.0))
    out = add(mul(add(tone, air), swell(n, 0.06, min(0.15, dur * 0.4))), chiff)
    return gain(out, vel * 0.55)


def horn(freq, dur, rng, vel=1.0, bright=1.0):
    """A horn (an animal horn, a bronze trumpet): brass harmonics that bloom as it swells."""
    n = seconds(dur)
    sw = swell(n, 0.09, min(0.25, dur * 0.4))
    out = [0.0] * n
    sin = math.sin
    ph = 0.0
    for i in range(n):
        t = i / RATE
        ph += TAU * freq * (1.0 + 0.004 * sin(TAU * 4.8 * t)) / RATE
        e = sw[i]
        v = sin(ph) + 0.55 * e * sin(2 * ph) + 0.35 * e * bright * sin(3 * ph) + 0.22 * e * bright * sin(4 * ph) + 0.12 * e * bright * sin(5 * ph) + 0.06 * e * bright * sin(6 * ph)
        out[i] = v * e
    out = soft_clip(out, 1.3 + 0.8 * bright)
    out = lowpass(out, 2600.0 + 1400.0 * bright)
    return gain(out, vel * 0.5)


def war_horn(freq, dur, rng, vel=1.0):
    """A deep ragged horn call: a horn with a growl (a slow beat against a detuned copy)."""
    a = horn(freq, dur, rng, vel, 1.3)
    b = horn(freq * 1.006, dur, rng, vel * 0.7, 1.3)
    return gain(lowpass(add(a, b), 1800.0), 0.75)


def drone(freq, dur, rng, vel=1.0):
    """Two bowed-string-like saws a few cents apart, kept dark; a bass drone."""
    n = seconds(dur)
    a = saw(n, freq, 10)
    b = saw(n, freq * 1.004, 10)
    c = saw(n, freq * 0.5, 6)
    out = lowpass(add(a, b, gain(c, 0.7)), lambda t: 300.0 + 220.0 * math.sin(TAU * 0.11 * t))
    out = mul(out, swell(n, min(0.6, dur * 0.3), min(0.8, dur * 0.4)))
    return gain(out, vel * 0.35)


def frame_drum(rng, vel=1.0, low=True, dur=0.35):
    """A hide drum: a pitched thump falling in pitch (dum) or a sharper rim tap (tek)."""
    n = seconds(dur)
    if low:
        f0, f1 = 95.0, 62.0
        body = sine(n, lambda t: f1 + (f0 - f1) * math.exp(-t * 18.0))
        body = mul(body, decay(n, 9.0, 0.001))
        skin = mul(lowpass(noise(n, rng), 900.0), decay(n, 60.0, 0.0005))
        out = add(body, gain(skin, 0.35))
    else:
        body = modal(n, [(420.0, 28.0, 0.5), (640.0, 40.0, 0.3), (1100.0, 60.0, 0.15)], rng, 0.0)
        skin = mul(bandpass(noise(n, rng), 2400.0, 1.0, 2.0), decay(n, 70.0, 0.0005))
        out = add(body, skin)
    return gain(out, vel * 0.8)


def low_drum(rng, vel=1.0, dur=0.7):
    """A big war drum: deep, slow, a long skin tail."""
    n = seconds(dur)
    body = sine(n, lambda t: 44.0 + 40.0 * math.exp(-t * 14.0))
    body = mul(body, decay(n, 5.0, 0.002))
    thud = mul(lowpass(noise(n, rng), 400.0), decay(n, 30.0, 0.001))
    out = soft_clip(add(body, gain(thud, 0.5)), 1.4)
    return gain(out, vel * 0.9)


def shaker(rng, vel=1.0, dur=0.12):
    """Seeds in a gourd."""
    n = seconds(dur)
    out = mul(bandpass(noise(n, rng), 5200.0, 1.2, 2.5), env(n, 0.012, 0.06, 0.1, 0.03))
    return gain(out, vel * 0.5)


def bell(freq, dur, rng, vel=1.0, wood=True):
    """A struck note: a wooden tongue drum (warm, few partials) or a small bronze bell."""
    n = seconds(dur)
    if wood:
        table = [(freq, 6.0, 0.9), (freq * 2.76, 14.0, 0.3), (freq * 5.4, 28.0, 0.12)]
    else:
        table = [(freq, 3.0, 0.8), (freq * 2.0, 5.0, 0.4), (freq * 2.92, 8.0, 0.3), (freq * 4.2, 11.0, 0.15), (freq * 5.4, 15.0, 0.08)]
    out = modal(n, table, rng, 0.25 if wood else 0.5)
    return gain(out, vel * 0.7)


def note_hz(name):
    """'D4', 'C#5', 'Bb3' -> Hz (A4 = 440)."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semi = names[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        semi += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((octave - 4) + (semi - 9) / 12.0)
