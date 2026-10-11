"""Every sound effect, as a recipe: a function of a seeded rng giving one take. The table at
the bottom says how many takes each has (the game plays them round-robin) and how loud it is
normalised. The palette is physical: wood, stone, hide, reed, bronze, breath. No beeps.
"""
import math
from synth import (RATE, seconds, sine, noise, env, decay, swell, mul, gain, add, mix_into, concat,
                   lowpass, highpass, bandpass, modal, soft_clip, reverb, trim_tail, delay_start, fade)
import instruments as I


def _burst(rng, dur, centre, q, rate, g=1.0):
    """A filtered noise burst with an exponential fall: the start of nearly every impact."""
    n = seconds(dur)
    return gain(mul(bandpass(noise(n, rng), centre, q), decay(n, rate, 0.0005)), g)


def _thump(rng, dur, f0, f1, rate, g=1.0):
    """A pitched thud falling from f0 to f1: a body being hit."""
    n = seconds(dur)
    return gain(mul(sine(n, lambda t: f1 + (f0 - f1) * math.exp(-t * 25.0)), decay(n, rate, 0.001)), g)


def _j(rng, lo, hi):
    return rng.uniform(lo, hi)


# ----------------------------------------------------------------------------- blows

def hit_blade(rng):
    """Metal on metal: a sharp click, a bright steel ring (inharmonic partials in close
    detuned pairs, so it shimmers, ringing a third of a second), a high 'shing' sweeping down,
    and barely any weight. Steel rings longer and higher than the pick's stone and has the
    sizzle; stone is short and gritty. (Dominic: v1 was mining, v2 with a thud was worse.)"""
    f = _j(rng, 2500, 3100)
    pairs = []
    for k, (ratio, dec, amp) in enumerate([(1.0, 11.0, 0.5), (1.47, 14.0, 0.4), (2.09, 18.0, 0.3), (2.71, 24.0, 0.2), (3.4, 30.0, 0.12)]):
        pairs.append((f * ratio, dec, amp))
        pairs.append((f * ratio * _j(rng, 1.004, 1.009), dec * 1.1, amp * 0.8))
    ring = modal(seconds(0.38), pairs, rng, 0.0)
    click = _burst(rng, 0.006, _j(rng, 5000, 7000), 0.5, 600.0, 1.4)
    n = seconds(0.13)
    f0 = _j(rng, 8500, 10500)
    shing = gain(mul(bandpass(noise(n, rng), lambda t, f0=f0: f0 - 4500.0 * (t / 0.13), 3.5), env(n, 0.003, 0.07, 0.2, 0.05)), 1.2)
    touch = _thump(rng, 0.04, 260.0, 180.0, 120.0, 0.15)
    return add(click, ring, delay_start(shing, 0.004), touch)


def hit_blunt(rng):
    """Club or hammer: a deep thump with a wooden crack."""
    crack = _burst(rng, 0.03, _j(rng, 1400, 2200), 1.2, 160.0, 1.0)
    body = _thump(rng, 0.16, _j(rng, 140, 170), 60.0, 30.0, 1.0)
    wood = modal(seconds(0.12), [(_j(rng, 380, 440), 45.0, 0.3), (_j(rng, 700, 800), 70.0, 0.15)], rng, 0.0)
    return add(crack, body, wood)


def hit_pierce(rng):
    """Spear or fang going in: a sharp point, a short dense punch into hide, the shaft's
    wood knock, a little weight. Under a tenth of a second, no pitched tone. (The first
    version, a tick and a falling sine, was "quite bad": Dominic.)"""
    point = _burst(rng, 0.008, _j(rng, 3000, 4500), 0.6, 500.0, 1.1)
    punch = _burst(rng, 0.045, _j(rng, 350, 700), 0.7, 110.0, 1.3)
    f = _j(rng, 420, 500)
    shaft = modal(seconds(0.04), [(f, 160.0, 0.35), (f * _j(rng, 2.2, 2.4), 220.0, 0.2)], rng, 0.0)
    weight = _thump(rng, 0.05, 130.0, 90.0, 90.0, 0.35)
    return add(point, delay_start(punch, 0.003), delay_start(shaft, 0.005), delay_start(weight, 0.004))


def arrow_land(rng):
    """An arrow arriving: a thin 'thwip' into something soft."""
    thwip = _burst(rng, 0.03, _j(rng, 1800, 2600), 1.0, 150.0, 0.9)
    body = _thump(rng, 0.09, 220.0, 110.0, 60.0, 0.6)
    return add(thwip, delay_start(body, 0.006))


# ----------------------------------------------------------------------------- shots

def _whoosh(rng, dur, f0, f1, g=1.0):
    n = seconds(dur)
    centre = lambda t: f0 + (f1 - f0) * (t / dur)
    return gain(mul(bandpass(noise(n, rng), centre, 1.6), env(n, dur * 0.35, dur * 0.5, 0.0)), g)


def _flight(rng, dur, f0, f1, air=1.0, whistle=0.45):
    """An arrow in the air going away from you: a band of air noise falling in pitch as it
    leaves, a thin fletching whistle inside it, loud at once and gone by the end."""
    n = seconds(dur)
    fall = lambda t: f0 + (f1 - f0) * (t / dur) ** 0.8
    shape = [min(1.0, i / seconds(0.012)) * math.exp(-4.5 * i / n) * (1.0 - (i / n) ** 3) for i in range(n)]
    out = gain(mul(bandpass(noise(n, rng), fall, 1.1), shape), air * 1.3)
    thin = gain(mul(bandpass(noise(n, rng), lambda t: fall(t) * 1.25, 7.0, 2.5), shape), whistle)
    return add(out, thin)


def shoot_arrow(rng):
    """Mostly the flight; the loose is a soft tap (Dominic: "focus on the arrow in air")."""
    tap = gain(lowpass(_burst(rng, 0.01, 1000.0, 0.8, 350.0, 1.0), 1500.0), 0.35)
    return add(tap, delay_start(_flight(rng, 0.27, _j(rng, 3000, 3600), _j(rng, 1500, 1800)), 0.006))


def shoot_bolt(rng):
    """A heavy bow: a clack, then a lower, thicker flight."""
    clack = _burst(rng, 0.015, _j(rng, 1200, 1800), 1.0, 220.0, 0.6)
    return add(clack, delay_start(_flight(rng, 0.3, _j(rng, 2200, 2600), _j(rng, 1100, 1300), 1.2, 0.35), 0.012))


def shoot_javelin(rng):
    return add(_burst(rng, 0.05, 300.0, 0.7, 50.0, 0.5), _whoosh(rng, 0.34, 400.0, 1800.0, 1.0))


def shoot_stone(rng):
    """A sling: a whirr that speeds up, then the release."""
    n = seconds(0.3)
    whirr = mul(bandpass(noise(n, rng), 700.0, 1.0), [0.5 + 0.5 * math.sin(math.tau * (6.0 * t + 12.0 * t * t)) for t in (i / RATE for i in range(n))])
    whirr = mul(whirr, swell(n, 0.12, 0.05))
    return add(gain(whirr, 0.7), delay_start(_whoosh(rng, 0.16, 500.0, 2500.0, 0.8), 0.26))


def shoot_dart(rng):
    """A blowpipe: a small puff."""
    return add(_burst(rng, 0.04, 800.0, 0.6, 80.0, 0.8), _whoosh(rng, 0.12, 2000.0, 5000.0, 0.5))


def shoot_ball(rng):
    """A primitive gun: a bang, then smoke."""
    bang = _burst(rng, 0.06, 500.0, 0.4, 70.0, 1.3)
    boom = _thump(rng, 0.3, 120.0, 45.0, 14.0, 1.0)
    hiss = _burst(rng, 0.5, 3000.0, 0.5, 9.0, 0.3)
    return soft_clip(add(bang, boom, delay_start(hiss, 0.05)), 1.8)


# ----------------------------------------------------------------------------- deaths

def fall(rng):
    """A body meeting the ground."""
    return add(_thump(rng, 0.2, 110.0, 55.0, 24.0, 1.0), _burst(rng, 0.12, 350.0, 0.7, 45.0, 0.6),
               delay_start(_burst(rng, 0.06, 900.0, 0.8, 80.0, 0.25), 0.07))


def building_fall(rng):
    """Timber and stone coming down: a rumble with crackles, then dust."""
    n = seconds(1.4)
    rumble = mul(lowpass(noise(n, rng), 160.0), env(n, 0.05, 0.9, 0.15, 0.4))
    out = gain(rumble, 2.2)
    for k in range(14):
        at = rng.uniform(0.0, 0.9)
        crack = _burst(rng, 0.05, rng.uniform(600, 2400), 1.5, 120.0, rng.uniform(0.3, 0.8))
        mix_into(out, crack, seconds(at))
    dust = mul(bandpass(noise(n, rng), 1800.0, 0.5), env(n, 0.3, 0.6, 0.2, 0.5))
    out = add(out, gain(dust, 0.25), _thump(rng, 0.5, 70.0, 35.0, 8.0, 1.0))
    return soft_clip(out, 1.5)


# ----------------------------------------------------------------------------- work

def chop(rng):
    """An axe into reed or timber. Nearly all crack: a hard bright bite, a noisy wood crack
    (noise through a wood-ish band, not a tone), a damped 'tok' at wood-block ratios that is
    gone in 30 ms, fibres splitting, and only a hint of weight underneath. (Dominic: the first
    version was a drum; the second, with three pure ringing partials, "two pipes hitting".)"""
    bite = _burst(rng, 0.01, _j(rng, 1800, 2600), 0.6, 380.0, 1.2)
    crack = _burst(rng, 0.045, _j(rng, 650, 1000), 1.1, 120.0, 1.1)
    f = _j(rng, 380, 460)
    tok = modal(seconds(0.05), [(f, 150.0, 0.5), (f * _j(rng, 2.2, 2.4), 200.0, 0.3), (f * _j(rng, 3.4, 3.8), 260.0, 0.15)], rng, 0.0)
    n = seconds(0.08)
    split = mul(bandpass(noise(n, rng), _j(rng, 1200, 2600), 0.7), [decay(n, 50.0, 0.001)[i] * (0.6 + 0.4 * (rng.random() > 0.5)) for i in range(n)])
    weight = _thump(rng, 0.05, 150.0, 105.0, 90.0, 0.25)
    return add(bite, crack, tok, delay_start(gain(split, 0.5), 0.01), weight)


def mine(rng):
    """A pick on stone: a hard click, the stone's ring, grit."""
    click = _burst(rng, 0.015, _j(rng, 4000, 6000), 1.0, 300.0, 1.0)
    ring = modal(seconds(0.22), [(_j(rng, 2200, 2500), 25.0, 0.5), (_j(rng, 3700, 4100), 35.0, 0.3), (_j(rng, 5400, 5900), 50.0, 0.15)], rng, 0.0)
    grit = delay_start(_burst(rng, 0.08, 2500.0, 0.6, 50.0, 0.3), 0.02)
    return add(click, ring, grit, _thump(rng, 0.08, 300.0, 150.0, 70.0, 0.4))


def build(rng):
    """A mallet on a frame: a wooden knock, short and dry, with a bounce."""
    knock = add(_burst(rng, 0.015, _j(rng, 1100, 1600), 1.0, 260.0, 0.9),
                modal(seconds(0.1), [(_j(rng, 330, 370), 110.0, 0.45), (_j(rng, 680, 760), 110.0, 0.5), (_j(rng, 1300, 1450), 150.0, 0.3)], rng, 0.0),
                _thump(rng, 0.05, 170.0, 110.0, 90.0, 0.2))
    bounce = gain(knock, 0.3)
    return add(knock, delay_start(bounce, _j(rng, 0.07, 0.09)))


def forage(rng):
    """Picking from a bush: leaves rustling, a stem or two snapping."""
    n = seconds(0.28)
    rustle = mul(bandpass(noise(n, rng), _j(rng, 2400, 3200), 0.6), [0.55 + 0.45 * math.sin(math.tau * 9.0 * i / RATE + rng.random()) for i in range(n)])
    rustle = gain(mul(rustle, env(n, 0.03, 0.15, 0.3, 0.1)), 0.8)
    out = rustle
    for k in range(rng.randint(1, 3)):
        mix_into(out, _burst(rng, 0.015, _j(rng, 1500, 2500), 1.2, 350.0, 0.5), seconds(rng.uniform(0.04, 0.2)))
    return out


def farm_done(rng):
    """A field gone to stubble: a dry rustle and a dull knock."""
    n = seconds(0.5)
    dry = gain(mul(bandpass(noise(n, rng), 3500.0, 0.5), env(n, 0.05, 0.3, 0.2, 0.15)), 0.5)
    knock = delay_start(add(modal(seconds(0.2), [(180.0, 30.0, 0.8), (330.0, 50.0, 0.3)], rng, 0.3), _thump(rng, 0.12, 120.0, 70.0, 40.0, 0.6)), 0.15)
    return add(dry, knock)


# ----------------------------------------------------------------------------- UI (small objects)

def ui_click(rng):
    """A wooden token set on the table."""
    return add(_burst(rng, 0.012, _j(rng, 1800, 2400), 1.0, 300.0, 0.7),
               modal(seconds(0.07), [(_j(rng, 1200, 1400), 90.0, 0.5), (_j(rng, 2600, 2900), 120.0, 0.2)], rng, 0.0))


def ui_tip(rng):
    """A page of the almanac turning."""
    n = seconds(0.22)
    sweep = lambda t: 1500.0 + 3500.0 * (t / 0.22)
    return gain(mul(bandpass(noise(n, rng), sweep, 0.9), env(n, 0.05, 0.1, 0.4, 0.07)), 0.7)


def ui_nope(rng):
    """Two dull knocks: that can't be done."""
    k = add(modal(seconds(0.12), [(240.0, 40.0, 0.8), (410.0, 60.0, 0.3)], rng, 0.4), _thump(rng, 0.1, 110.0, 70.0, 40.0, 0.5))
    return add(k, delay_start(k, 0.13))


# ----------------------------------------------------------------------------- stings (in D, like the music)

def _rev(buf, size=0.6, mix=0.22):
    return reverb(buf, size, mix)


def trained(rng):
    """A unit is ready: a tongue-drum note."""
    return _rev(I.bell(I.note_hz("D5"), 0.9, rng, 1.0), 0.5, 0.15)


def built(rng):
    """A building finished: the last two mallet knocks and a warm low note."""
    out = add(build(rng), delay_start(build(rng), 0.18))
    return _rev(add(out, delay_start(I.bell(I.note_hz("A4"), 1.1, rng, 0.8), 0.36)), 0.6, 0.18)


def research(rng):
    """Something learned: a small bronze bell, twice."""
    b = I.bell(I.note_hz("D6"), 1.0, rng, 0.6, wood=False)
    return _rev(add(b, delay_start(I.bell(I.note_hz("A6"), 1.0, rng, 0.45, wood=False), 0.2)), 0.6, 0.25)


def age(rng):
    """A new age: horns in a rising call over a drum roll."""
    out = []
    roll = []
    for k in range(12):
        mix_into(roll, I.frame_drum(rng, 0.35 + 0.05 * k), seconds(0.07 * k))
    for i, (name, at, dur) in enumerate([("D3", 0.0, 0.5), ("A3", 0.45, 0.5), ("D4", 0.9, 1.4)]):
        mix_into(out, I.horn(I.note_hz(name), dur, rng, 1.0, 0.8 + 0.1 * i), seconds(at))
    mix_into(out, I.horn(I.note_hz("F4"), 1.0, rng, 0.5, 0.9), seconds(1.3))
    mix_into(out, I.low_drum(rng, 1.0), seconds(0.9))
    mix_into(out, roll, 0, 0.5)
    return _rev(out, 0.8, 0.3)


def won(rng):
    """Victory: the theme's last phrase on horns and the lute, drums underneath."""
    out = []
    phrase = [("D4", 0.0, 0.3), ("F4", 0.3, 0.3), ("A4", 0.6, 0.3), ("D5", 0.9, 0.9), ("C5", 1.5, 0.3), ("D5", 1.8, 1.6)]
    for name, at, dur in phrase:
        mix_into(out, I.horn(I.note_hz(name), dur, rng, 0.9, 1.0), seconds(at))
        mix_into(out, I.pluck(I.note_hz(name), dur + 0.4, rng, 0.8), seconds(at))
    for name, at in [("D3", 1.8), ("A3", 1.8), ("D2", 1.8)]:
        mix_into(out, I.horn(I.note_hz(name), 1.6, rng, 0.6, 0.7), seconds(at))
    for k, at in enumerate([0.0, 0.3, 0.6, 0.9, 1.8]):
        mix_into(out, I.frame_drum(rng, 0.6 if k < 4 else 0.3), seconds(at))
    mix_into(out, I.low_drum(rng, 1.0), seconds(0.9))
    mix_into(out, I.low_drum(rng, 1.0), seconds(1.8))
    return _rev(out, 0.9, 0.32)


def lost(rng):
    """Defeat: the horns go down and a drum shuts the door."""
    out = []
    for name, at, dur in [("D4", 0.0, 0.6), ("C4", 0.55, 0.6), ("A3", 1.1, 1.8)]:
        mix_into(out, I.horn(I.note_hz(name), dur, rng, 0.8, 0.6), seconds(at))
    mix_into(out, I.drone(I.note_hz("D2"), 2.8, rng, 1.0), 0)
    mix_into(out, I.low_drum(rng, 1.0, 1.2), seconds(1.1))
    return _rev(out, 1.0, 0.35)


def alarm(rng):
    """Under attack: a war horn, twice, and the big drum."""
    out = []
    mix_into(out, I.war_horn(I.note_hz("A2"), 0.35, rng), 0)
    mix_into(out, I.war_horn(I.note_hz("A2"), 0.9, rng), seconds(0.42))
    mix_into(out, I.low_drum(rng, 1.0), 0)
    mix_into(out, I.low_drum(rng, 0.8), seconds(0.42))
    return _rev(out, 0.9, 0.25)


# ----------------------------------------------------------------------------- ambience

def meadow(rng):
    """Twenty seconds of wind over grass with a bird now and then; loops."""
    n = seconds(20.0)
    gust = [0.35 + 0.65 * (0.5 + 0.5 * math.sin(math.tau * (0.07 * i / RATE) + 1.0)) * (0.6 + 0.4 * math.sin(math.tau * 0.19 * i / RATE)) for i in range(n)]
    wind = gain(mul(lowpass(noise(n, rng), lambda t: 250.0 + 250.0 * (0.5 + 0.5 * math.sin(math.tau * 0.07 * t + 1.0))), gust), 1.6)
    grass = gain(mul(bandpass(noise(n, rng), 3000.0, 0.4), gust), 0.08)
    out = add(wind, grass)
    for k in range(5):
        at = rng.uniform(1.0, 18.0)
        f0 = rng.uniform(2200, 3600)
        for c in range(rng.randint(2, 4)):
            m = seconds(0.09)
            chirp = mul(sine(m, lambda t, f0=f0: f0 + 800.0 * math.sin(math.pi * t / 0.09)), env(m, 0.01, 0.04, 0.5, 0.03))
            mix_into(out, chirp, seconds(at + c * 0.13), 0.12, wrap=True)
    return fade(out, 0.0, 0.0)


# name -> (recipe, takes, peak dB). Stings and ambience are one take.
TABLE = {
    "hit_blade": (hit_blade, 4, -4.0), "hit_blunt": (hit_blunt, 4, -2.0), "hit_pierce": (hit_pierce, 4, -2.0),
    "arrow_land": (arrow_land, 3, -4.0),
    "shoot_arrow": (shoot_arrow, 3, -3.0), "shoot_bolt": (shoot_bolt, 2, -2.0), "shoot_javelin": (shoot_javelin, 2, -3.0),
    "shoot_stone": (shoot_stone, 2, -3.0), "shoot_dart": (shoot_dart, 2, -6.0), "shoot_ball": (shoot_ball, 2, -1.0),
    "fall": (fall, 3, -3.0), "building_fall": (building_fall, 2, -1.0),
    "chop": (chop, 4, -3.0), "mine": (mine, 4, -3.0), "build": (build, 4, -3.0), "forage": (forage, 4, -6.0),
    "farm_done": (farm_done, 2, -5.0),
    "ui_click": (ui_click, 3, -6.0), "ui_tip": (ui_tip, 1, -8.0), "ui_nope": (ui_nope, 1, -5.0),
    "trained": (trained, 1, -4.0), "built": (built, 1, -3.0), "research": (research, 1, -5.0),
    "age": (age, 1, -1.0), "won": (won, 1, -1.0), "lost": (lost, 1, -1.0), "alarm": (alarm, 1, -1.0),
    "meadow": (meadow, 1, -8.0),
}
