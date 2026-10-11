"""Renders the game's audio into assets/audio/: sfx/<name>_<take>.wav, voice/<creature>_<kind>_<take>.wav
and music/theme_<stem>.ogg (via ffmpeg). Deterministic: the same files every time.
Run: python3 tools/audio/render.py [all|sfx|voices|music|<sound name>...] [--out DIR]
"""
import os
import random
import subprocess
import sys
import time
from multiprocessing import Pool
from synth import normalize, trim_tail, write_wav, pan, widen, RATE, peak, rms
import sfx
import voices
import music

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")


def _seed(*parts):
    return sum((i + 1) * ord(c) for i, c in enumerate(":".join(map(str, parts))))


def render_sfx(name):
    fn, takes, peak_db = sfx.TABLE[name]
    for k in range(takes):
        buf = fn(random.Random(_seed("sfx", name, k)))
        if name != "meadow":
            buf = trim_tail(buf)
        buf = normalize(buf, peak_db)
        write_wav(os.path.join(OUT, "sfx", "%s_%d.wav" % (name, k + 1)), buf)
    return "sfx %-14s %d take(s) %.2fs" % (name, takes, len(buf) / RATE)


def render_voice(creature):
    fn = voices.CREATURES[creature]
    for kind, takes in voices.KINDS.items():
        for k in range(takes):
            buf = fn(random.Random(_seed("voice", creature, kind, k)), kind)
            buf = normalize(trim_tail(buf), voices.PEAK_DB)
            write_wav(os.path.join(OUT, "voice", "%s_%s_%d.wav" % (creature, kind, k + 1)), buf)
    return "voice %-9s %s" % (creature, " ".join("%s x%d" % kv for kv in voices.KINDS.items()))


def render_music(stem):
    loop, p = music.render_stem(stem)
    loop = normalize(loop, -3.0)
    left, right = pan(loop, p)
    left, right = widen(left, 0.003)[0], widen(right, 0.003)[1]
    wav = os.path.join(OUT, "music", "theme_%s.wav" % stem)
    write_wav(wav, left, right)
    ogg = wav[:-4] + ".ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "vorbis", "-strict", "-2", "-b:a", "160k", ogg], check=True)
    os.remove(wav)
    return "music %-8s %.1fs loop, rms %.1f dB" % (stem, len(loop) / RATE, 20 * __import__("math").log10(rms(loop) + 1e-9))


def main(args):
    global OUT
    if "--out" in args:
        i = args.index("--out")
        OUT = args[i + 1]
        del args[i:i + 2]
    for d in ("sfx", "voice", "music"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    what = args or ["all"]
    jobs = []
    if "all" in what or "sfx" in what:
        jobs += [(render_sfx, n) for n in sfx.TABLE]
    if "all" in what or "voices" in what:
        jobs += [(render_voice, c) for c in voices.CREATURES]
    if "all" in what or "music" in what:
        jobs += [(render_music, s) for s in music.STEMS]
    for w in what:
        if w in sfx.TABLE:
            jobs.append((render_sfx, w))
        elif w in voices.CREATURES:
            jobs.append((render_voice, w))
        elif w in music.STEMS:
            jobs.append((render_music, w))
    t = time.time()
    with Pool() as pool:
        for line in pool.starmap(_run, jobs):
            print(line)
    print("rendered %d jobs in %.0fs into %s" % (len(jobs), time.time() - t, OUT))


def _run(fn, arg):
    return fn(arg)


if __name__ == "__main__":
    main(sys.argv[1:])
