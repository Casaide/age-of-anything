"""Pure-Python sound synthesis for Age of Whatever (no numpy: this Mac has none).

A sound is a list of floats at RATE Hz, mono, in roughly -1..1. Everything here is
deterministic: noise comes from a random.Random you pass in, so a re-render gives the
same files. Slow is fine; this runs offline (tools/audio/render.py), never in the game.
"""
import math
import random
import struct
import wave

RATE = 44100
TAU = math.tau


def seconds(s):
    return int(s * RATE)


def silence(n):
    return [0.0] * n


def noise(n, rng):
    u = rng.uniform
    return [u(-1.0, 1.0) for _ in range(n)]


def sine(n, freq, phase=0.0):
    """A sine; freq is a number or a function of time in seconds (a pitch contour)."""
    out = [0.0] * n
    sin = math.sin
    ph = phase
    if callable(freq):
        for i in range(n):
            out[i] = sin(ph)
            ph += TAU * freq(i / RATE) / RATE
    else:
        inc = TAU * freq / RATE
        for i in range(n):
            out[i] = sin(ph)
            ph += inc
    return out


def saw(n, freq, harmonics=12):
    """A band-limited sawtooth (summed harmonics), freq a number or a function of time."""
    out = [0.0] * n
    sin = math.sin
    ph = 0.0
    amps = [1.0 / k for k in range(1, harmonics + 1)]
    for i in range(n):
        f = freq(i / RATE) if callable(freq) else freq
        ph += TAU * f / RATE
        v = 0.0
        for k in range(harmonics):
            if (k + 1) * f > RATE * 0.45:
                break
            v += amps[k] * sin(ph * (k + 1))
        out[i] = v * 0.6
    return out


def pulse_train(n, freq, width=0.3):
    """A glottal-ish pulse: a raised-cosine bump of `width` of each period (a voice source)."""
    out = [0.0] * n
    cos = math.cos
    ph = 0.0
    for i in range(n):
        f = freq(i / RATE) if callable(freq) else freq
        ph += f / RATE
        if ph >= 1.0:
            ph -= 1.0
        if ph < width:
            out[i] = 0.5 - 0.5 * cos(TAU * ph / width)
        else:
            out[i] = 0.0
    return out


# ----------------------------------------------------------------------------- envelopes

def env(n, attack, decay, sustain=0.0, release=0.0, hold=None):
    """ADSR in seconds; hold is where the release starts (default: the end minus release)."""
    out = [0.0] * n
    a = max(1, seconds(attack))
    d = max(1, seconds(decay))
    r = max(1, seconds(release))
    h = n - r if hold is None else seconds(hold)
    for i in range(n):
        if i < a:
            v = i / a
        elif i < a + d:
            v = 1.0 - (1.0 - sustain) * (i - a) / d
        else:
            v = sustain
        if i > h:
            v *= max(0.0, 1.0 - (i - h) / r)
        out[i] = v
    return out


def decay(n, rate, attack=0.002):
    """A fast attack then an exponential fall; rate in 1/s."""
    out = [0.0] * n
    a = max(1, seconds(attack))
    exp = math.exp
    for i in range(n):
        out[i] = min(1.0, i / a) * exp(-rate * i / RATE)
    return out


def swell(n, up, down):
    """Rises over `up` seconds, falls over the last `down` (a bowed or blown note)."""
    out = [0.0] * n
    a = max(1, seconds(up))
    r = max(1, seconds(down))
    for i in range(n):
        v = min(1.0, i / a)
        if i > n - r:
            v *= (n - i) / r
        out[i] = v
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def gain(a, g):
    return [x * g for x in a]


def add(*bufs):
    n = max(len(b) for b in bufs)
    out = [0.0] * n
    for b in bufs:
        for i, x in enumerate(b):
            out[i] += x
    return out


def mix_into(dst, src, at, g=1.0, wrap=False):
    """Adds src into dst starting at sample `at`; past the end it wraps (for loops) or grows."""
    n = len(dst)
    if not wrap and at + len(src) > n:
        dst.extend([0.0] * (at + len(src) - n))
        n = len(dst)
    for i, x in enumerate(src):
        j = at + i
        if j >= n:
            if not wrap:
                break
            j %= n
        dst[j] += x * g
    return dst


def concat(*bufs):
    out = []
    for b in bufs:
        out.extend(b)
    return out


def delay_start(buf, s):
    return [0.0] * seconds(s) + buf


# ----------------------------------------------------------------------------- filters

def lowpass(buf, cutoff):
    """One-pole low-pass; cutoff in Hz or a function of time."""
    out = [0.0] * len(buf)
    y = 0.0
    exp = math.exp
    if callable(cutoff):
        for i, x in enumerate(buf):
            a = 1.0 - exp(-TAU * cutoff(i / RATE) / RATE)
            y += a * (x - y)
            out[i] = y
    else:
        a = 1.0 - exp(-TAU * cutoff / RATE)
        for i, x in enumerate(buf):
            y += a * (x - y)
            out[i] = y
    return out


def highpass(buf, cutoff):
    lo = lowpass(buf, cutoff)
    return [x - y for x, y in zip(buf, lo)]


def bandpass(buf, centre, q, gain_=1.0):
    """A resonant band-pass (biquad); centre in Hz or a function of time."""
    out = [0.0] * len(buf)
    x1 = x2 = y1 = y2 = 0.0
    sin, cos = math.sin, math.cos
    if not callable(centre):
        w = TAU * centre / RATE
        alpha = sin(w) / (2.0 * q)
        b0 = alpha
        b2 = -alpha
        a0 = 1.0 + alpha
        a1 = -2.0 * cos(w)
        a2 = 1.0 - alpha
        b0 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
        for i, x in enumerate(buf):
            y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1 = x1, x
            y2, y1 = y1, y
            out[i] = y * gain_
        return out
    for i, x in enumerate(buf):
        w = TAU * centre(i / RATE) / RATE
        alpha = sin(w) / (2.0 * q)
        a0 = 1.0 + alpha
        y = (alpha * x - alpha * x2 + 2.0 * cos(w) * y1 - (1.0 - alpha) * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        out[i] = y * gain_
    return out


def formants(buf, table):
    """Sums resonant band-passes: table is [(centre_hz, q, gain), ...] (a throat, a body)."""
    out = [0.0] * len(buf)
    for centre, q, g in table:
        f = bandpass(buf, centre, q, g)
        for i, x in enumerate(f):
            out[i] += x
    return out


def modal(n, partials, rng=None, strike=0.3):
    """A struck body: decaying sine partials [(hz, decay_per_s, amp), ...] plus a click."""
    out = [0.0] * n
    sin, exp = math.sin, math.exp
    for hz, dec, amp in partials:
        inc = TAU * hz / RATE
        ph = 0.0 if rng is None else rng.uniform(0.0, TAU)
        for i in range(n):
            out[i] += amp * sin(ph) * exp(-dec * i / RATE)
            ph += inc
    if strike > 0.0 and rng is not None:
        click = mul(noise(seconds(0.004), rng), decay(seconds(0.004), 900.0, 0.0002))
        mix_into(out, click, 0, strike)
    return out


def soft_clip(buf, drive=1.5):
    th = math.tanh
    return [th(x * drive) / th(drive) for x in buf]


def reverb(buf, size=0.6, mix=0.25, damp=0.4):
    """Schroeder: four combs in parallel then two all-passes, a soft room, not a hall."""
    n = len(buf)
    wet = [0.0] * n
    exp = math.exp
    for base in (1116, 1188, 1277, 1356):
        L = int(base * (0.5 + size) * RATE / 44100)
        fb = 0.72 + 0.12 * size
        line = [0.0] * L
        p = 0
        lp = 0.0
        for i in range(n):
            y = line[p]
            lp += (1.0 - damp) * (y - lp)
            line[p] = buf[i] + lp * fb
            p += 1
            if p == L:
                p = 0
            wet[i] += y * 0.25
    for L in (int(225 * RATE / 44100), int(556 * RATE / 44100)):
        line = [0.0] * L
        p = 0
        for i in range(n):
            d = line[p]
            x = wet[i]
            line[p] = x + d * 0.5
            wet[i] = d - x * 0.5
            p += 1
            if p == L:
                p = 0
    return [d * (1.0 - mix) + w * mix for d, w in zip(buf, wet)]


def echo(buf, time, feedback, mix=0.3):
    n = len(buf)
    L = seconds(time)
    out = list(buf)
    for i in range(L, n):
        out[i] += out[i - L] * feedback
    return [d + (o - d) * mix for d, o in zip(buf, out)]


# ----------------------------------------------------------------------------- levels and files

def peak(buf):
    return max(1e-9, max(abs(x) for x in buf))


def rms(buf):
    return math.sqrt(sum(x * x for x in buf) / max(1, len(buf)))


def normalize(buf, peak_db=-1.0):
    g = 10 ** (peak_db / 20.0) / peak(buf)
    return [x * g for x in buf]


def trim_tail(buf, floor_db=-60.0, keep=0.02):
    """Cuts the silence a decay leaves at the end (keeps `keep` seconds after the last sound)."""
    th = 10 ** (floor_db / 20.0)
    last = len(buf)
    while last > 0 and abs(buf[last - 1]) < th:
        last -= 1
    return buf[:min(len(buf), last + seconds(keep))]


def fade(buf, in_s=0.0, out_s=0.0):
    out = list(buf)
    a = seconds(in_s)
    for i in range(min(a, len(out))):
        out[i] *= i / a
    r = seconds(out_s)
    n = len(out)
    for i in range(max(0, n - r), n):
        out[i] *= (n - i) / r
    return out


def write_wav(path, left, right=None):
    """16-bit PCM; mono when right is None."""
    right = left if right is None else right
    n = min(len(left), len(right))
    chans = 1 if right is left else 2
    data = bytearray(n * 2 * chans)
    pack = struct.pack_into
    k = 0
    for i in range(n):
        v = left[i]
        v = 32767 if v >= 1.0 else (-32768 if v <= -1.0 else int(v * 32767.0))
        pack("<h", data, k, v)
        k += 2
        if chans == 2:
            v = right[i]
            v = 32767 if v >= 1.0 else (-32768 if v <= -1.0 else int(v * 32767.0))
            pack("<h", data, k, v)
            k += 2
    with wave.open(path, "wb") as w:
        w.setnchannels(chans)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


def pan(buf, p):
    """Mono to a stereo pair; p from -1 (left) to 1 (right), constant power."""
    a = (p + 1.0) * math.pi / 4.0
    return gain(buf, math.cos(a)), gain(buf, math.sin(a))


def widen(buf, s=0.004):
    """A touch of stereo from a few ms of delay on one side (a room's two ears)."""
    d = seconds(s)
    return buf, [0.0] * d + buf[:-d] if d < len(buf) else list(buf)
