"""Looks at a rendered sound by numbers: length, peak, RMS, a pitch guess (autocorrelation
over the middle of the sound), so a re-render can be sanity-checked without ears.
Run: python3 tools/audio/check.py file.wav [...]
"""
import math
import struct
import sys
import wave


def read(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        ch = w.getnchannels()
        rate = w.getframerate()
        raw = w.readframes(n)
    vals = struct.unpack("<%dh" % (n * ch), raw)
    mono = [vals[i * ch] / 32768.0 for i in range(n)]
    return mono, rate


def pitch(buf, rate, lo=40.0, hi=3000.0):
    mid = len(buf) // 3
    win = buf[mid:mid + min(4096, len(buf) - mid)]
    if len(win) < 512:
        return 0.0
    best, best_r = 0.0, 0.0
    e = sum(x * x for x in win) + 1e-9
    for lag in range(int(rate / hi), int(rate / lo)):
        r = sum(win[i] * win[i + lag] for i in range(len(win) - lag)) / e
        if r > best_r:
            best_r, best = r, rate / lag
    return best if best_r > 0.3 else 0.0


def bands(buf, rate):
    """Share of the energy below 300 Hz, 300-1500, above 1500 (one-pole splits; rough but telling)."""
    import math as m
    def lowpass(b, fc):
        a = 1.0 - m.exp(-m.tau * fc / rate)
        y = 0.0
        out = []
        for x in b:
            y += a * (x - y)
            out.append(y)
        return out
    lo = lowpass(buf, 300.0)
    mid_all = lowpass(buf, 1500.0)
    e = lambda b: sum(x * x for x in b) + 1e-12
    el = e(lo)
    em = e(mid_all) - el
    eh = e(buf) - e(mid_all)
    tot = max(1e-12, el + em + eh)
    return el / tot, em / tot, eh / tot


def describe(path):
    buf, rate = read(path)
    pk = max(abs(x) for x in buf)
    rms = math.sqrt(sum(x * x for x in buf) / len(buf))
    p = pitch(buf, rate)
    lo, mid, hi = bands(buf, rate)
    return "%-28s %5.2fs peak %5.1f dB  rms %5.1f dB  low/mid/high %2.0f/%2.0f/%2.0f%%  pitch %s" % (
        path.split("/")[-1], len(buf) / rate, 20 * math.log10(pk + 1e-9), 20 * math.log10(rms + 1e-9),
        lo * 100, mid * 100, hi * 100, ("%.0f Hz" % p) if p else "-")


if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(describe(f))
