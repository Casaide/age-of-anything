"""Every sound effect, as a recipe: a function of a seeded rng giving one take. The table at
the bottom says how many takes each has (the game plays them round-robin) and how loud it is
normalised. The palette is physical: wood, stone, hide, reed, bronze, breath. No beeps.
"""
import math
from synth import (RATE, seconds, sine, noise, env, decay, swell, mul, gain, add, mix_into, concat,
                   lowpass, highpass, bandpass, modal, soft_clip, reverb, trim_tail, delay_start, fade, pulse_train)
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


# ----------------------------------------------------------------------------- siege engines (milestone 13)
# Big timber machines: every sound has weight first (a low body), then the material on top
# (timber knocks, rope, iron fittings). Nothing metallic beyond a fitting; no booms but the sapper's.

def _creak(rng, dur, f0, f1, g=1.0):
    """A timber joint or a rope under load: a slow buzzy stick-slip (a pulse train sliding in pitch)
    through a wood resonance, swelling and dying."""
    n = seconds(dur)
    src = pulse_train(n, lambda t: f0 + (f1 - f0) * (t / dur) + 6.0 * math.sin(math.tau * 7.0 * t), 0.18)
    body = add(bandpass(src, _j(rng, 650, 850), 3.5), gain(bandpass(src, _j(rng, 1500, 1900), 5.0), 0.5))
    return gain(mul(body, env(n, dur * 0.3, dur * 0.4, 0.4, dur * 0.25)), g)


def ram_hit(rng):
    """The ram's blow: the frame creaks as the log swings back, then a huge dull thud of timber on
    a wall (a falling low body, a woody crack, grit off the stones), the log's own boom ringing a
    moment, the frame creaking as it settles."""
    swing = _creak(rng, 0.32, _j(rng, 55, 70), _j(rng, 90, 110), 0.45)
    thud = _thump(rng, 0.55, _j(rng, 95, 115), 38.0, 9.0, 1.5)
    crack = _burst(rng, 0.06, _j(rng, 600, 900), 0.8, 70.0, 2.0)
    log = modal(seconds(0.4), [(_j(rng, 72, 82), 9.0, 0.6), (_j(rng, 190, 215), 16.0, 0.3), (_j(rng, 410, 450), 28.0, 0.15)], rng, 0.0)
    grit = _burst(rng, 0.35, _j(rng, 1800, 2600), 0.5, 12.0, 0.45)
    settle = _creak(rng, 0.4, _j(rng, 100, 120), _j(rng, 60, 75), 0.3)
    hit = add(thud, crack, log, delay_start(grit, 0.02))
    return soft_clip(add(swing, delay_start(hit, 0.3), delay_start(settle, 0.55)), 1.4)


def catapult_release(rng):
    """The catapult looses: the skein lets go with a rope's groan, the arm slams into its padded
    crossbar (a heavy wooden knock with a thick low body), the whole frame jolts, and the stone's
    air goes up and away."""
    groan = _creak(rng, 0.14, _j(rng, 120, 140), _j(rng, 200, 240), 0.35)
    slam = add(_burst(rng, 0.03, _j(rng, 900, 1300), 0.9, 140.0, 1.1),
               modal(seconds(0.3), [(_j(rng, 150, 170), 18.0, 0.7), (_j(rng, 330, 370), 30.0, 0.35), (_j(rng, 720, 800), 55.0, 0.15)], rng, 0.0),
               _thump(rng, 0.35, _j(rng, 120, 140), 50.0, 14.0, 1.2))
    rattle = _burst(rng, 0.12, _j(rng, 1200, 1600), 1.0, 30.0, 0.25)
    whoosh = _whoosh(rng, 0.45, _j(rng, 300, 380), _j(rng, 900, 1200), 0.6)
    return soft_clip(add(groan, delay_start(slam, 0.11), delay_start(rattle, 0.14), delay_start(whoosh, 0.13)), 1.3)


def catapult_impact(rng):
    """A thrown stone comes down: a deep thud into the ground, earth and gravel thrown about (a
    spray of small crackles over a dull rumble), a stone or two skittering."""
    thud = _thump(rng, 0.45, _j(rng, 80, 100), 34.0, 10.0, 1.6)
    burst = _burst(rng, 0.08, _j(rng, 450, 750), 0.7, 50.0, 1.8)
    n = seconds(0.7)
    earth = gain(mul(lowpass(noise(n, rng), 700.0), env(n, 0.01, 0.25, 0.25, 0.3)), 0.7)
    out = add(thud, burst, earth)
    for k in range(rng.randint(7, 11)):
        mix_into(out, _burst(rng, 0.02, _j(rng, 1500, 3500), 1.4, 260.0, _j(rng, 0.25, 0.6)), seconds(_j(rng, 0.03, 0.5)))
    return soft_clip(out, 1.5)


def bolt_release(rng):
    """The bolt thrower snaps: a hard double crack of the bow arms hitting their stops, the thick
    cord's twang (a low plucked note dying fast), the stock's knock, then the bolt's heavy whoosh,
    lower and thicker than an arrow's."""
    snap = add(_burst(rng, 0.012, _j(rng, 2500, 3500), 0.8, 450.0, 1.3),
               delay_start(_burst(rng, 0.01, _j(rng, 2000, 3000), 0.8, 500.0, 0.9), _j(rng, 0.008, 0.016)))
    cord = gain(I.pluck(_j(rng, 95, 115), 0.25, rng, 1.0, 0.8, 0.985), 0.9)
    knock = add(modal(seconds(0.12), [(_j(rng, 240, 280), 40.0, 0.5), (_j(rng, 560, 640), 70.0, 0.25)], rng, 0.0),
                _thump(rng, 0.12, 160.0, 80.0, 40.0, 0.6))
    flight = _flight(rng, 0.42, _j(rng, 1600, 1900), _j(rng, 700, 850), 1.5, 0.25)
    return add(snap, cord, knock, delay_start(flight, 0.015))


def sling_release(rng):
    """The great sling throws: the long arm's rope sling whirls round once (a deep sweeping 'whum'),
    a crack as the sling's loop slips free, the counterweight's frame lurching (a big wooden knock),
    and the stone's slow rush away."""
    n = seconds(0.55)
    whum = mul(bandpass(noise(n, rng), lambda t: 180.0 + 500.0 * (t / 0.55), 1.4), swell(n, 0.4, 0.12))
    loop = _burst(rng, 0.015, _j(rng, 1800, 2400), 0.9, 380.0, 0.9)
    lurch = add(modal(seconds(0.4), [(_j(rng, 110, 125), 12.0, 0.7), (_j(rng, 260, 290), 22.0, 0.3)], rng, 0.0),
                _thump(rng, 0.4, 100.0, 40.0, 10.0, 1.2), _creak(rng, 0.35, 70.0, 50.0, 0.4))
    rush = _whoosh(rng, 0.6, _j(rng, 250, 320), _j(rng, 700, 900), 0.6)
    return soft_clip(add(gain(whum, 1.1), delay_start(loop, 0.5), delay_start(lurch, 0.52), delay_start(rush, 0.52)), 1.3)


def blast(rng):
    """The sapper's charge goes off (a fire pot of pitch and powder, not a cannon): a sharp crack, a
    deep thump that shakes, a roar of fire sucking air, timber and stone thrown about, then flames
    crackling down."""
    crack = _burst(rng, 0.02, _j(rng, 1200, 1800), 0.5, 200.0, 1.6)
    thump = _thump(rng, 0.8, _j(rng, 80, 95), 28.0, 5.0, 1.8)
    n = seconds(1.2)
    roar = gain(mul(lowpass(noise(n, rng), lambda t: 900.0 - 600.0 * min(1.0, t / 1.2)), env(n, 0.02, 0.5, 0.3, 0.5)), 1.4)
    out = add(crack, thump, roar)
    for k in range(rng.randint(10, 14)):   # debris
        mix_into(out, _burst(rng, 0.03, _j(rng, 700, 2600), 1.3, 150.0, _j(rng, 0.2, 0.5)), seconds(_j(rng, 0.05, 0.8)))
    for k in range(rng.randint(8, 12)):   # flames crackling down
        mix_into(out, _burst(rng, 0.008, _j(rng, 2500, 5000), 1.0, 600.0, _j(rng, 0.08, 0.2)), seconds(_j(rng, 0.4, 1.5)))
    return soft_clip(reverb(out, 0.7, 0.25), 1.6)


def trade_paid(rng):
    """A cart home with its gold: a few coins poured into a chest (bright little rings, each with a
    click), a lid's soft knock."""
    out = []
    t = 0.0
    for k in range(rng.randint(5, 8)):
        f = _j(rng, 3200, 4600)
        coin = add(_burst(rng, 0.004, _j(rng, 6000, 8000), 0.7, 900.0, 0.7),
                   modal(seconds(0.18), [(f, 22.0, 0.4), (f * _j(rng, 1.42, 1.5), 30.0, 0.25), (f * _j(rng, 2.1, 2.3), 40.0, 0.12)], rng, 0.0))
        mix_into(out, gain(coin, _j(rng, 0.5, 1.0)), seconds(t))
        t += _j(rng, 0.03, 0.08)
    lid = add(modal(seconds(0.12), [(_j(rng, 230, 260), 40.0, 0.5), (_j(rng, 520, 580), 60.0, 0.2)], rng, 0.0), _thump(rng, 0.08, 150.0, 90.0, 40.0, 0.4))
    mix_into(out, lid, seconds(t + 0.1))
    return _rev(out, 0.4, 0.15)


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


def ui_hover(rng):
    """The pointer over a button: the faintest knock of a fingertip on carved wood."""
    return add(_burst(rng, 0.006, _j(rng, 2600, 3200), 1.4, 700.0, 0.5),
               modal(seconds(0.04), [(_j(rng, 1900, 2100), 160.0, 0.25)], rng, 0.0))


def ui_start(rng):
    """To battle: a war horn's call over two heavy drum strokes."""
    out = []
    mix_into(out, I.low_drum(rng, 1.0), 0)
    mix_into(out, I.low_drum(rng, 0.9), seconds(0.32))
    mix_into(out, I.war_horn(I.note_hz("D3"), 1.3, rng, 0.9), seconds(0.3))
    mix_into(out, I.horn(I.note_hz("A3"), 1.1, rng, 0.5, 0.8), seconds(0.5))
    return _rev(out, 0.8, 0.3)


def ui_tip(rng):
    """A page of the almanac turning."""
    n = seconds(0.22)
    sweep = lambda t: 1500.0 + 3500.0 * (t / 0.22)
    return gain(mul(bandpass(noise(n, rng), sweep, 0.9), env(n, 0.05, 0.1, 0.4, 0.07)), 0.7)


def dice_roll(rng):
    """Two bone dice thrown on a wooden table: a quick rattle as they leave the hand, then
    each one tumbling, its knocks coming faster and softer as it settles, a last little
    rock. Every knock is a click (the edge), a bright bone ring and a touch of the table."""
    out = [0.0] * seconds(0.95)

    def knock(g, bright):
        f = _j(rng, 2300, 3300) * bright
        ring = modal(seconds(0.05), [(f, 110.0, 0.5), (f * _j(rng, 1.5, 1.7), 150.0, 0.25)], rng, 0.0)
        table = modal(seconds(0.08), [(_j(rng, 260, 320), 60.0, 0.35), (_j(rng, 560, 640), 80.0, 0.15)], rng, 0.0)
        return gain(add(_burst(rng, 0.006, _j(rng, 4000, 6000), 0.7, 700.0, 0.9), ring, table), g)

    for k in range(rng.randint(3, 4)):   # the rattle in the hand, the dice against each other
        mix_into(out, knock(0.35, 1.25), seconds(0.01 + k * _j(rng, 0.028, 0.04)))
    for die in range(2):
        t = _j(rng, 0.14, 0.2) + die * _j(rng, 0.02, 0.05)
        gap = _j(rng, 0.11, 0.15)
        g = 0.9
        while gap > 0.018 and t < 0.85:
            mix_into(out, knock(g, _j(rng, 0.9, 1.1)), seconds(t))
            t += gap
            gap *= _j(rng, 0.6, 0.72)
            g *= 0.8
    return fade(out, 0.0, 0.03)


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


def heal(rng):
    """A healer tends a wound: a soft rustle of herbs and a quiet wooden chime, no fanfare."""
    n = seconds(0.6)
    rustle = gain(mul(bandpass(noise(n, rng), _j(rng, 2600, 3200), 0.6), env(n, 0.18, 0.2, 0.3, 0.2)), 0.35)
    chime = delay_start(I.bell(I.note_hz(rng.choice(["A5", "D6"])), 0.8, rng, 0.35), 0.08)
    return _rev(add(rustle, chime), 0.6, 0.25)


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
    """Forty seconds of a soft breeze over grass with a bird now and then; loops. Dominic: the
    first version (20 s, a 3 kHz grass hiss, a swell every ~5 s) sounded like static, came round
    too often and too loud. Now: a deep, slow breeze (one long swell in each 20 s half, never
    silent), the grass a faint rustle well below hiss, sparse birds."""
    n = seconds(40.0)
    t_of = lambda i: i / RATE
    # Two gentle swells per loop (0.05 Hz) and a slower drift (0.025 Hz); whole cycles, so it loops.
    gust = [0.45 + 0.55 * (0.5 + 0.5 * math.sin(math.tau * 0.05 * t_of(i) + 1.0)) * (0.75 + 0.25 * math.sin(math.tau * 0.025 * t_of(i)))
        for i in range(n)]
    wind = gain(mul(lowpass(lowpass(noise(n, rng), lambda t: 140.0 + 120.0 * (0.5 + 0.5 * math.sin(math.tau * 0.05 * t + 1.0))), 400.0), gust), 1.4)
    grass = gain(mul(lowpass(bandpass(noise(n, rng), 1400.0, 0.5), 2200.0), gust), 0.025)
    out = add(wind, grass)
    for k in range(4):
        at = rng.uniform(1.0, 38.0)
        f0 = rng.uniform(2200, 3400)
        for c in range(rng.randint(2, 3)):
            m = seconds(0.09)
            chirp = mul(sine(m, lambda t, f0=f0: f0 + 700.0 * math.sin(math.pi * t / 0.09)), env(m, 0.01, 0.04, 0.5, 0.03))
            mix_into(out, chirp, seconds(at + c * 0.14), 0.08, wrap=True)
    return fade(out, 0.0, 0.0)


def _murmur(rng, dur):
    """One far-off voice saying something: a buzzy pulse with a wandering pitch through two
    vowel formants that slide from syllable to syllable, low-passed by the distance. Words
    can't be made out; it's people somewhere over there."""
    n = seconds(dur)
    f0 = rng.uniform(110, 230)
    contour = [rng.uniform(-0.12, 0.12) for _ in range(6)]
    src = pulse_train(n, lambda t: f0 * (1.0 + contour[min(5, int(t / dur * 6))] + 0.04 * math.sin(math.tau * 3.0 * t)), 0.35)
    vowels = [(730, 1090), (270, 2290), (530, 1840), (570, 840), (300, 870)]
    syl = max(0.12, dur / rng.randint(3, 7))
    seq = [rng.choice(vowels) for _ in range(int(dur / syl) + 2)]
    f1 = bandpass(src, lambda t: seq[int(t / syl)][0], 4.0, 1.0)
    f2 = bandpass(src, lambda t: seq[int(t / syl)][1], 6.0, 0.5)
    voice = add(f1, f2)
    beat = [0.35 + 0.65 * abs(math.sin(math.pi * (i / RATE) / syl)) for i in range(n)]   # syllables
    return lowpass(mul(mul(voice, beat), env(n, 0.05, 0.1, 1.0, 0.15)), 900.0)


def _far(buf, g):
    """Push a sound away: duller and quieter (the room tail comes from the mix's reverb)."""
    return gain(lowpass(buf, 1800.0), g)


def _town(rng, busy):
    """Twenty-four seconds of a town at work, heard from a little way off; loops. People
    talking somewhere (a murmur, never words), a mallet on a frame, a log split, a broom, a
    bucket set down, a door. `busy` has more of everything (the town grows into it)."""
    dur = 24.0
    n = seconds(dur)
    out = gain(lowpass(noise(n, rng), 300.0), 0.05)   # the air of a place with people in it
    voices = 9 if busy else 4
    for k in range(voices):
        talk = _murmur(rng, rng.uniform(0.8, 2.2))
        mix_into(out, talk, seconds(rng.uniform(0.0, dur)), rng.uniform(0.10, 0.2), wrap=True)
    knocks = 12 if busy else 5
    for k in range(knocks):   # someone building: three or four knocks in a run
        at = rng.uniform(0.0, dur)
        for r in range(rng.randint(2, 4)):
            mix_into(out, _far(build(rng), 0.22), seconds(at + r * rng.uniform(0.42, 0.55)), wrap=True)
    for k in range(4 if busy else 2):   # a log split
        mix_into(out, _far(chop(rng), 0.18), seconds(rng.uniform(0.0, dur)), wrap=True)
    for k in range(3 if busy else 1):   # a broom: swish, swish
        at = rng.uniform(0.0, dur)
        for r in range(rng.randint(3, 5)):
            m = seconds(0.32)
            sw = mul(bandpass(noise(m, rng), lambda t: 2200.0 + 1800.0 * t / 0.32, 0.8), env(m, 0.08, 0.1, 0.6, 0.12))
            mix_into(out, sw, seconds(at + r * 0.45), 0.10, wrap=True)
    for k in range(2 if busy else 1):   # a wooden bucket set down
        m = seconds(0.2)
        clunk = add(modal(m, [(_j(rng, 210, 250), 30.0, 0.5), (_j(rng, 520, 600), 45.0, 0.3)], rng, 0.0), _thump(rng, 0.08, 160.0, 90.0, 40.0, 0.4))
        mix_into(out, _far(clunk, 0.3), seconds(rng.uniform(0.0, dur)), wrap=True)
    if busy:   # a door on its hinge
        m = seconds(0.6)
        creak = mul(bandpass(pulse_train(m, lambda t: 90.0 + 60.0 * math.sin(math.pi * t / 0.6), 0.2), 900.0, 3.0), env(m, 0.05, 0.2, 0.7, 0.2))
        mix_into(out, creak, seconds(rng.uniform(2.0, dur - 2.0)), 0.12, wrap=True)
    return fade(reverb(out, 0.7, 0.3), 0.0, 0.0)


def town_quiet(rng):
    return _town(rng, False)


def town_busy(rng):
    return _town(rng, True)


# name -> (recipe, takes, peak dB). Stings and ambience are one take.
TABLE = {
    "hit_blade": (hit_blade, 4, -4.0), "hit_blunt": (hit_blunt, 4, -2.0), "hit_pierce": (hit_pierce, 4, -2.0),
    "arrow_land": (arrow_land, 3, -4.0),
    "shoot_arrow": (shoot_arrow, 3, -3.0), "shoot_bolt": (shoot_bolt, 2, -2.0), "shoot_javelin": (shoot_javelin, 2, -3.0),
    "shoot_stone": (shoot_stone, 2, -3.0), "shoot_dart": (shoot_dart, 2, -6.0), "shoot_ball": (shoot_ball, 2, -1.0),
    "ram_hit": (ram_hit, 3, -1.5), "catapult_release": (catapult_release, 2, -2.0), "catapult_impact": (catapult_impact, 3, -1.5),
    "bolt_release": (bolt_release, 2, -2.0), "sling_release": (sling_release, 2, -2.0), "blast": (blast, 2, -1.0),
    "trade_paid": (trade_paid, 2, -10.0),
    "fall": (fall, 3, -3.0), "building_fall": (building_fall, 2, -1.0),
    "chop": (chop, 4, -3.0), "mine": (mine, 4, -3.0), "build": (build, 4, -3.0), "forage": (forage, 4, -6.0),
    "farm_done": (farm_done, 2, -5.0),
    "ui_click": (ui_click, 3, -6.0), "ui_tip": (ui_tip, 1, -8.0), "ui_hover": (ui_hover, 2, -14.0), "ui_start": (ui_start, 1, -2.0), "ui_nope": (ui_nope, 1, -5.0),
    "dice_roll": (dice_roll, 3, -6.0),
    "trained": (trained, 1, -4.0), "built": (built, 1, -3.0), "research": (research, 1, -5.0),
    "heal": (heal, 2, -12.0),
    "age": (age, 1, -1.0), "won": (won, 1, -1.0), "lost": (lost, 1, -1.0), "alarm": (alarm, 1, -1.0),
    "meadow": (meadow, 1, -14.0), "town_quiet": (town_quiet, 1, -12.0), "town_busy": (town_busy, 1, -10.0),
}
