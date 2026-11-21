// Every sound effect, as a recipe: a function of the seeded rng giving one take. The table at the bottom says how many
// takes each has (the game plays them round-robin) and how loud it is normalised. The palette is physical: wood, stone,
// hide, reed, bronze, breath. No beeps.

// A filtered noise burst with an exponential fall: the start of nearly every impact.
def burst(dur:float, centre:float, q:float, rate:float, g = 1.0) -> [float]:
    let n = seconds(dur)
    return gain(mul(bandpass(noise(n), centre, q), decay(n, rate, 0.0005)), g)

// A pitched thud falling from f0 to f1: a body being hit.
def thump(dur:float, f0:float, f1:float, rate:float, g = 1.0) -> [float]:
    let n = seconds(dur)
    return gain(mul(sinec(curve(n) t: f1 + (f0 - f1) * exp(-t * 25.0)), decay(n, rate, 0.001)), g)

def rev(buf:[float], size:float, mix:float) -> [float]: return reverb(buf, size, mix)

// ------------------------------------------------------------------ blows

// Metal on metal: a sharp click, a bright steel ring (inharmonic partials in close detuned pairs, so it shimmers, ringing
// a third of a second), a high 'shing' sweeping down, and barely any weight. Steel rings longer and higher than the
// pick's stone and has the sizzle; stone is short and gritty. (Dominic: v1 was mining, v2 with a thud was worse.)
def hit_blade() -> [float]:
    let f = j(2500.0, 3100.0)
    let pairs = []::float3
    for([ p3(1.0, 11.0, 0.5), p3(1.47, 14.0, 0.4), p3(2.09, 18.0, 0.3), p3(2.71, 24.0, 0.2), p3(3.4, 30.0, 0.12) ]) p:
        pairs.push(p3(f * p.x, p.y, p.z))
        pairs.push(p3(f * p.x * j(1.004, 1.009), p.y * 1.1, p.z * 0.8))
    let ring = modal(seconds(0.38), pairs, 0.0)
    let click = burst(0.006, j(5000.0, 7000.0), 0.5, 600.0, 1.4)
    let n = seconds(0.13)
    let f0 = j(8500.0, 10500.0)
    let sweep = bandpassc(noise(n), curve(n) t: f0 - 4500.0 * (t / 0.13), 3.5)
    let shing = gain(mul(sweep, env(n, 0.003, 0.07, 0.2, 0.05)), 1.2)
    let touch = thump(0.04, 260.0, 180.0, 120.0, 0.15)
    return add([ click, ring, delay_start(shing, 0.004), touch ])

// Club or hammer: a deep thump with a wooden crack.
def hit_blunt() -> [float]:
    let crack = burst(0.03, j(1400.0, 2200.0), 1.2, 160.0, 1.0)
    let body = thump(0.16, j(140.0, 170.0), 60.0, 30.0, 1.0)
    let wood = modal(seconds(0.12), [ p3(j(380.0, 440.0), 45.0, 0.3), p3(j(700.0, 800.0), 70.0, 0.15) ], 0.0)
    return add([ crack, body, wood ])

// Spear or fang going in: a sharp point, a short dense punch into hide, the shaft's wood knock, a little weight. Under a
// tenth of a second, no pitched tone. (The first version, a tick and a falling sine, was "quite bad": Dominic.)
def hit_pierce() -> [float]:
    let point = burst(0.008, j(3000.0, 4500.0), 0.6, 500.0, 1.1)
    let punch = burst(0.045, j(350.0, 700.0), 0.7, 110.0, 1.3)
    let f = j(420.0, 500.0)
    let shaft = modal(seconds(0.04), [ p3(f, 160.0, 0.35), p3(f * j(2.2, 2.4), 220.0, 0.2) ], 0.0)
    let weight = thump(0.05, 130.0, 90.0, 90.0, 0.35)
    return add([ point, delay_start(punch, 0.003), delay_start(shaft, 0.005), delay_start(weight, 0.004) ])

// An arrow arriving: a thin 'thwip' into something soft.
def arrow_land() -> [float]:
    let thwip = burst(0.03, j(1800.0, 2600.0), 1.0, 150.0, 0.9)
    return add([ thwip, delay_start(thump(0.09, 220.0, 110.0, 60.0, 0.6), 0.006) ])

// ------------------------------------------------------------------ shots

def whoosh(dur:float, f0:float, f1:float, g = 1.0) -> [float]:
    let n = seconds(dur)
    return gain(mul(bandpassc(noise(n), curve(n) t: f0 + (f1 - f0) * (t / dur), 1.6), env(n, dur * 0.35, dur * 0.5, 0.0)), g)

// An arrow in the air going away from you: a band of air noise falling in pitch as it leaves, a thin fletching whistle
// inside it, loud at once and gone by the end.
def flight(dur:float, f0:float, f1:float, air = 1.0, whistle = 0.45) -> [float]:
    let n = seconds(dur)
    let drop = curve(n) t: f0 + (f1 - f0) * pow(t / dur, 0.8)
    let on = seconds(0.012)
    let shape = map(n) i:
        min(1.0, float(i) / on) * exp(-4.5 * i / n) * (1.0 - pow(float(i) / n, 3.0))
    let out = gain(mul(bandpassc(noise(n), drop, 1.1), shape), air * 1.3)
    let thin = gain(mul(bandpassc(noise(n), map(drop) x: x * 1.25, 7.0, 2.5), shape), whistle)
    return add([ out, thin ])

// Mostly the flight; the loose is a soft tap (Dominic: "focus on the arrow in air").
def shoot_arrow() -> [float]:
    let tap = gain(lowpass(burst(0.01, 1000.0, 0.8, 350.0, 1.0), 1500.0), 0.35)
    return add([ tap, delay_start(flight(0.27, j(3000.0, 3600.0), j(1500.0, 1800.0)), 0.006) ])

// A heavy bow: a clack, then a lower, thicker flight.
def shoot_bolt() -> [float]:
    let clack = burst(0.015, j(1200.0, 1800.0), 1.0, 220.0, 0.6)
    return add([ clack, delay_start(flight(0.3, j(2200.0, 2600.0), j(1100.0, 1300.0), 1.2, 0.35), 0.012) ])

def shoot_javelin() -> [float]: return add([ burst(0.05, 300.0, 0.7, 50.0, 0.5), whoosh(0.34, 400.0, 1800.0, 1.0) ])

// A sling: a whirr that speeds up, then the release.
def shoot_stone() -> [float]:
    let n = seconds(0.3)
    let spin = curve(n) t: 0.5 + 0.5 * rsin(TAU * (6.0 * t + 12.0 * t * t))
    let whirr = mul(mul(bandpass(noise(n), 700.0, 1.0), spin), swell(n, 0.12, 0.05))
    return add([ gain(whirr, 0.7), delay_start(whoosh(0.16, 500.0, 2500.0, 0.8), 0.26) ])

// A blowpipe: a small puff.
def shoot_dart() -> [float]: return add([ burst(0.04, 800.0, 0.6, 80.0, 0.8), whoosh(0.12, 2000.0, 5000.0, 0.5) ])

// A primitive gun: a bang, then smoke.
def shoot_ball() -> [float]:
    let bang = burst(0.06, 500.0, 0.4, 70.0, 1.3)
    let boom = thump(0.3, 120.0, 45.0, 14.0, 1.0)
    let hiss = burst(0.5, 3000.0, 0.5, 9.0, 0.3)
    return soft_clip(add([ bang, boom, delay_start(hiss, 0.05) ]), 1.8)

// ------------------------------------------------------------------ siege engines (milestone 13)
// Big timber machines: every sound has weight first (a low body), then the material on top (timber knocks, rope, iron
// fittings). Nothing metallic beyond a fitting; no booms but the sapper's.

// A timber joint or a rope under load: a slow buzzy stick-slip (a pulse train sliding in pitch) through a wood resonance,
// swelling and dying.
def creak(dur:float, f0:float, f1:float, g = 1.0) -> [float]:
    let n = seconds(dur)
    let src = pulsec(curve(n) t: f0 + (f1 - f0) * (t / dur) + 6.0 * rsin(TAU * 7.0 * t), 0.18)
    let body = add([ bandpass(src, j(650.0, 850.0), 3.5), gain(bandpass(src, j(1500.0, 1900.0), 5.0), 0.5) ])
    return gain(mul(body, env(n, dur * 0.3, dur * 0.4, 0.4, dur * 0.25)), g)

// The ram's blow: the frame creaks as the log swings back, then a huge dull thud of timber on a wall (a falling low body,
// a woody crack, grit off the stones), the log's own boom ringing a moment, the frame creaking as it settles.
def ram_hit() -> [float]:
    let swing = creak(0.32, j(55.0, 70.0), j(90.0, 110.0), 0.45)
    let thud = thump(0.55, j(95.0, 115.0), 38.0, 9.0, 1.5)
    let crack = burst(0.06, j(600.0, 900.0), 0.8, 70.0, 2.0)
    let boom = modal(seconds(0.4), [ p3(j(72.0, 82.0), 9.0, 0.6), p3(j(190.0, 215.0), 16.0, 0.3), p3(j(410.0, 450.0), 28.0, 0.15) ], 0.0)
    let grit = burst(0.35, j(1800.0, 2600.0), 0.5, 12.0, 0.45)
    let settle = creak(0.4, j(100.0, 120.0), j(60.0, 75.0), 0.3)
    let hit = add([ thud, crack, boom, delay_start(grit, 0.02) ])
    return soft_clip(add([ swing, delay_start(hit, 0.3), delay_start(settle, 0.55) ]), 1.4)

// The catapult looses: the skein lets go with a rope's groan, the arm slams into its padded crossbar (a heavy wooden knock
// with a thick low body), the whole frame jolts, and the stone's air goes up and away.
def catapult_release() -> [float]:
    let groan = creak(0.14, j(120.0, 140.0), j(200.0, 240.0), 0.35)
    let slam = add([ burst(0.03, j(900.0, 1300.0), 0.9, 140.0, 1.1),
                     modal(seconds(0.3), [ p3(j(150.0, 170.0), 18.0, 0.7), p3(j(330.0, 370.0), 30.0, 0.35), p3(j(720.0, 800.0), 55.0, 0.15) ], 0.0),
                     thump(0.35, j(120.0, 140.0), 50.0, 14.0, 1.2) ])
    let rattle = burst(0.12, j(1200.0, 1600.0), 1.0, 30.0, 0.25)
    let air = whoosh(0.45, j(300.0, 380.0), j(900.0, 1200.0), 0.6)
    return soft_clip(add([ groan, delay_start(slam, 0.11), delay_start(rattle, 0.14), delay_start(air, 0.13) ]), 1.3)

// A thrown stone comes down: a deep thud into the ground, earth and gravel thrown about (a spray of small crackles over a
// dull rumble), a stone or two skittering.
def catapult_impact() -> [float]:
    let thud = thump(0.45, j(80.0, 100.0), 34.0, 10.0, 1.6)
    let hit = burst(0.08, j(450.0, 750.0), 0.7, 50.0, 1.8)
    let n = seconds(0.7)
    let earth = gain(mul(lowpass(noise(n), 700.0), env(n, 0.01, 0.25, 0.25, 0.3)), 0.7)
    let out = add([ thud, hit, earth ])
    for(randint(7, 11)):
        mix_into(out, burst(0.02, j(1500.0, 3500.0), 1.4, 260.0, j(0.25, 0.6)), seconds(j(0.03, 0.5)))
    return soft_clip(out, 1.5)

// The bolt thrower snaps: a hard double crack of the bow arms hitting their stops, the thick cord's twang (a low plucked
// note dying fast), the stock's knock, then the bolt's heavy whoosh, lower and thicker than an arrow's.
def bolt_release() -> [float]:
    let snap = add([ burst(0.012, j(2500.0, 3500.0), 0.8, 450.0, 1.3),
                     delay_start(burst(0.01, j(2000.0, 3000.0), 0.8, 500.0, 0.9), j(0.008, 0.016)) ])
    let cord = gain(pluck(j(95.0, 115.0), 0.25, 1.0, 0.8, 0.985), 0.9)
    let knock = add([ modal(seconds(0.12), [ p3(j(240.0, 280.0), 40.0, 0.5), p3(j(560.0, 640.0), 70.0, 0.25) ], 0.0),
                      thump(0.12, 160.0, 80.0, 40.0, 0.6) ])
    let air = flight(0.42, j(1600.0, 1900.0), j(700.0, 850.0), 1.5, 0.25)
    return add([ snap, cord, knock, delay_start(air, 0.015) ])

// The great sling throws: the long arm's rope sling whirls round once (a deep sweeping 'whum'), a crack as the sling's
// loop slips free, the counterweight's frame lurching (a big wooden knock), and the stone's slow rush away.
def sling_release() -> [float]:
    let n = seconds(0.55)
    let whum = mul(bandpassc(noise(n), curve(n) t: 180.0 + 500.0 * (t / 0.55), 1.4), swell(n, 0.4, 0.12))
    let loop = burst(0.015, j(1800.0, 2400.0), 0.9, 380.0, 0.9)
    let lurch = add([ modal(seconds(0.4), [ p3(j(110.0, 125.0), 12.0, 0.7), p3(j(260.0, 290.0), 22.0, 0.3) ], 0.0),
                      thump(0.4, 100.0, 40.0, 10.0, 1.2), creak(0.35, 70.0, 50.0, 0.4) ])
    let rush = whoosh(0.6, j(250.0, 320.0), j(700.0, 900.0), 0.6)
    return soft_clip(add([ gain(whum, 1.1), delay_start(loop, 0.5), delay_start(lurch, 0.52), delay_start(rush, 0.52) ]), 1.3)

// The sapper's charge goes off (a fire pot of pitch and powder, not a cannon): a sharp crack, a deep thump that shakes, a
// roar of fire sucking air, timber and stone thrown about, then flames crackling down.
def blast() -> [float]:
    let crack = burst(0.02, j(1200.0, 1800.0), 0.5, 200.0, 1.6)
    let boom = thump(0.8, j(80.0, 95.0), 28.0, 5.0, 1.8)
    let n = seconds(1.2)
    let roar = gain(mul(lowpassc(noise(n), curve(n) t: 900.0 - 600.0 * min(1.0, t / 1.2)), env(n, 0.02, 0.5, 0.3, 0.5)), 1.4)
    let out = add([ crack, boom, roar ])
    for(randint(10, 14)):  // debris
        mix_into(out, burst(0.03, j(700.0, 2600.0), 1.3, 150.0, j(0.2, 0.5)), seconds(j(0.05, 0.8)))
    for(randint(8, 12)):  // flames crackling down
        mix_into(out, burst(0.008, j(2500.0, 5000.0), 1.0, 600.0, j(0.08, 0.2)), seconds(j(0.4, 1.5)))
    return soft_clip(reverb(out, 0.7, 0.25), 1.6)

// A cart home with its gold: a few coins poured into a chest (bright little rings, each with a click), a lid's soft knock.
def trade_paid() -> [float]:
    let out = []::float
    var t = 0.0
    for(randint(5, 8)):
        let f = j(3200.0, 4600.0)
        let coin = add([ burst(0.004, j(6000.0, 8000.0), 0.7, 900.0, 0.7),
                         modal(seconds(0.18), [ p3(f, 22.0, 0.4), p3(f * j(1.42, 1.5), 30.0, 0.25), p3(f * j(2.1, 2.3), 40.0, 0.12) ], 0.0) ])
        mix_into(out, gain(coin, j(0.5, 1.0)), seconds(t))
        t += j(0.03, 0.08)
    let lid = add([ modal(seconds(0.12), [ p3(j(230.0, 260.0), 40.0, 0.5), p3(j(520.0, 580.0), 60.0, 0.2) ], 0.0),
                    thump(0.08, 150.0, 90.0, 40.0, 0.4) ])
    mix_into(out, lid, seconds(t + 0.1))
    return rev(out, 0.4, 0.15)

// ------------------------------------------------------------------ deaths

// A body meeting the ground.
def body_fall() -> [float]:
    return add([ thump(0.2, 110.0, 55.0, 24.0, 1.0), burst(0.12, 350.0, 0.7, 45.0, 0.6),
                 delay_start(burst(0.06, 900.0, 0.8, 80.0, 0.25), 0.07) ])

// Timber and stone coming down: a rumble with crackles, then dust.
def building_fall() -> [float]:
    let n = seconds(1.4)
    let out = gain(mul(lowpass(noise(n), 160.0), env(n, 0.05, 0.9, 0.15, 0.4)), 2.2)
    for(14):
        let at = j(0.0, 0.9)
        let crack = burst(0.05, j(600.0, 2400.0), 1.5, 120.0, j(0.3, 0.8))
        mix_into(out, crack, seconds(at))
    let dust = mul(bandpass(noise(n), 1800.0, 0.5), env(n, 0.3, 0.6, 0.2, 0.5))
    return soft_clip(add([ out, gain(dust, 0.25), thump(0.5, 70.0, 35.0, 8.0, 1.0) ]), 1.5)

// ------------------------------------------------------------------ work

// An axe into reed or timber. Nearly all crack: a hard bright bite, a noisy wood crack (noise through a wood-ish band, not
// a tone), a damped 'tok' at wood-block ratios that is gone in 30 ms, fibres splitting, and only a hint of weight
// underneath. (Dominic: the first version was a drum; the second, with three pure ringing partials, "two pipes hitting".)
def chop() -> [float]:
    let bite = burst(0.01, j(1800.0, 2600.0), 0.6, 380.0, 1.2)
    let crack = burst(0.045, j(650.0, 1000.0), 1.1, 120.0, 1.1)
    let f = j(380.0, 460.0)
    let tok = modal(seconds(0.05), [ p3(f, 150.0, 0.5), p3(f * j(2.2, 2.4), 200.0, 0.3), p3(f * j(3.4, 3.8), 260.0, 0.15) ], 0.0)
    let n = seconds(0.08)
    let band = bandpass(noise(n), j(1200.0, 2600.0), 0.7)
    let fall = decay(n, 50.0, 0.001)
    let split = mul(band, map(n) i: fall[i] * (if rand01() > 0.5: 1.0 else: 0.6))
    let weight = thump(0.05, 150.0, 105.0, 90.0, 0.25)
    return add([ bite, crack, tok, delay_start(gain(split, 0.5), 0.01), weight ])

// A pick on stone: a hard click, the stone's ring, grit.
def mine() -> [float]:
    let click = burst(0.015, j(4000.0, 6000.0), 1.0, 300.0, 1.0)
    let ring = modal(seconds(0.22), [ p3(j(2200.0, 2500.0), 25.0, 0.5), p3(j(3700.0, 4100.0), 35.0, 0.3), p3(j(5400.0, 5900.0), 50.0, 0.15) ], 0.0)
    let grit = delay_start(burst(0.08, 2500.0, 0.6, 50.0, 0.3), 0.02)
    return add([ click, ring, grit, thump(0.08, 300.0, 150.0, 70.0, 0.4) ])

// A mallet on a frame: a wooden knock, short and dry, with a bounce.
def mallet() -> [float]:
    let knock = add([ burst(0.015, j(1100.0, 1600.0), 1.0, 260.0, 0.9),
                      modal(seconds(0.1), [ p3(j(330.0, 370.0), 110.0, 0.45), p3(j(680.0, 760.0), 110.0, 0.5), p3(j(1300.0, 1450.0), 150.0, 0.3) ], 0.0),
                      thump(0.05, 170.0, 110.0, 90.0, 0.2) ])
    return add([ knock, delay_start(gain(knock, 0.3), j(0.07, 0.09)) ])

// Picking from a bush: leaves rustling, a stem or two snapping.
def forage() -> [float]:
    let n = seconds(0.28)
    let band = bandpass(noise(n), j(2400.0, 3200.0), 0.6)
    let flutter = map(n) i: 0.55 + 0.45 * rsin(TAU * 9.0 * i / RATE + rand01())
    let out = gain(mul(mul(band, flutter), env(n, 0.03, 0.15, 0.3, 0.1)), 0.8)
    for(randint(1, 3)):
        mix_into(out, burst(0.015, j(1500.0, 2500.0), 1.2, 350.0, 0.5), seconds(j(0.04, 0.2)))
    return out

// A field gone to stubble: a dry rustle and a dull knock.
def farm_done() -> [float]:
    let n = seconds(0.5)
    let dry = gain(mul(bandpass(noise(n), 3500.0, 0.5), env(n, 0.05, 0.3, 0.2, 0.15)), 0.5)
    let knock = add([ modal(seconds(0.2), [ p3(180.0, 30.0, 0.8), p3(330.0, 50.0, 0.3) ], 0.3), thump(0.12, 120.0, 70.0, 40.0, 0.6) ])
    return add([ dry, delay_start(knock, 0.15) ])

// ------------------------------------------------------------------ UI (small objects)

// A wooden token set on the table.
def ui_click() -> [float]:
    return add([ burst(0.012, j(1800.0, 2400.0), 1.0, 300.0, 0.7),
                 modal(seconds(0.07), [ p3(j(1200.0, 1400.0), 90.0, 0.5), p3(j(2600.0, 2900.0), 120.0, 0.2) ], 0.0) ])

// The pointer over a button: the faintest knock of a fingertip on carved wood.
def ui_hover() -> [float]:
    return add([ burst(0.006, j(2600.0, 3200.0), 1.4, 700.0, 0.5), modal(seconds(0.04), [ p3(j(1900.0, 2100.0), 160.0, 0.25) ], 0.0) ])

// To battle: a war horn's call over two heavy drum strokes.
def ui_start() -> [float]:
    let out = []::float
    mix_into(out, low_drum(1.0), 0)
    mix_into(out, low_drum(0.9), seconds(0.32))
    mix_into(out, war_horn(note_hz("D3"), 1.3, 0.9), seconds(0.3))
    mix_into(out, horn(note_hz("A3"), 1.1, 0.5, 0.8), seconds(0.5))
    return rev(out, 0.8, 0.3)

// A page of the almanac turning.
def ui_tip() -> [float]:
    let n = seconds(0.22)
    return gain(mul(bandpassc(noise(n), curve(n) t: 1500.0 + 3500.0 * (t / 0.22), 0.9), env(n, 0.05, 0.1, 0.4, 0.07)), 0.7)

// Two bone dice thrown on a wooden table: a quick rattle as they leave the hand, then each one tumbling, its knocks coming
// faster and softer as it settles, a last little rock. Every knock is a click (the edge), a bright bone ring and a touch
// of the table.
def dice_roll() -> [float]:
    let out = zeros(seconds(0.95))
    def knock(g:float, bright:float) -> [float]:
        let f = j(2300.0, 3300.0) * bright
        let ring = modal(seconds(0.05), [ p3(f, 110.0, 0.5), p3(f * j(1.5, 1.7), 150.0, 0.25) ], 0.0)
        let table = modal(seconds(0.08), [ p3(j(260.0, 320.0), 60.0, 0.35), p3(j(560.0, 640.0), 80.0, 0.15) ], 0.0)
        return gain(add([ burst(0.006, j(4000.0, 6000.0), 0.7, 700.0, 0.9), ring, table ]), g)
    for(randint(3, 4)) k:  // the rattle in the hand, the dice against each other
        mix_into(out, knock(0.35, 1.25), seconds(0.01 + k * j(0.028, 0.04)))
    for(2) die:
        var t = j(0.14, 0.2) + die * j(0.02, 0.05)
        var gap = j(0.11, 0.15)
        var g = 0.9
        while gap > 0.018 and t < 0.85:
            mix_into(out, knock(g, j(0.9, 1.1)), seconds(t))
            t += gap
            gap *= j(0.6, 0.72)
            g *= 0.8
    return fade_out(out, 0.03)

// Two dull knocks: that can't be done.
def ui_nope() -> [float]:
    let k = add([ modal(seconds(0.12), [ p3(240.0, 40.0, 0.8), p3(410.0, 60.0, 0.3) ], 0.4), thump(0.1, 110.0, 70.0, 40.0, 0.5) ])
    return add([ k, delay_start(k, 0.13) ])

// ------------------------------------------------------------------ stings (in D, like the music)

// A unit is ready: a tongue-drum note.
def trained() -> [float]: return rev(bell(note_hz("D5"), 0.9, 1.0), 0.5, 0.15)

// A building finished: the last two mallet knocks and a warm low note.
def built() -> [float]:
    let out = add([ mallet(), delay_start(mallet(), 0.18) ])
    return rev(add([ out, delay_start(bell(note_hz("A4"), 1.1, 0.8), 0.36) ]), 0.6, 0.18)

// A healer tends a wound: a soft rustle of herbs and a quiet wooden chime, no fanfare.
def heal() -> [float]:
    let n = seconds(0.6)
    let rustle = gain(mul(bandpass(noise(n), j(2600.0, 3200.0), 0.6), env(n, 0.18, 0.2, 0.3, 0.2)), 0.35)
    let chime = delay_start(bell(note_hz([ "A5", "D6" ][randbelow(2)]), 0.8, 0.35), 0.08)
    return rev(add([ rustle, chime ]), 0.6, 0.25)

// Something learned: a small bronze bell, twice.
def research() -> [float]:
    let b = bell(note_hz("D6"), 1.0, 0.6, false)
    return rev(add([ b, delay_start(bell(note_hz("A6"), 1.0, 0.45, false), 0.2) ]), 0.6, 0.25)

// A new age: horns in a rising call over a drum roll.
def new_age() -> [float]:
    let out = []::float
    let roll = []::float
    for(12) k: mix_into(roll, frame_drum(0.35 + 0.05 * k), seconds(0.07 * k))
    mix_into(out, horn(note_hz("D3"), 0.5, 1.0, 0.8), 0)
    mix_into(out, horn(note_hz("A3"), 0.5, 1.0, 0.9), seconds(0.45))
    mix_into(out, horn(note_hz("D4"), 1.4, 1.0, 1.0), seconds(0.9))
    mix_into(out, horn(note_hz("F4"), 1.0, 0.5, 0.9), seconds(1.3))
    mix_into(out, low_drum(1.0), seconds(0.9))
    mix_into(out, roll, 0, 0.5)
    return rev(out, 0.8, 0.3)

// Victory: the theme's last phrase on horns and the lute, drums underneath.
def won() -> [float]:
    let out = []::float
    let names = [ "D4", "F4", "A4", "D5", "C5", "D5" ]
    let ats = [ 0.0, 0.3, 0.6, 0.9, 1.5, 1.8 ]
    let durs = [ 0.3, 0.3, 0.3, 0.9, 0.3, 1.6 ]
    for(names) name, i:
        mix_into(out, horn(note_hz(name), durs[i], 0.9, 1.0), seconds(ats[i]))
        mix_into(out, pluck(note_hz(name), durs[i] + 0.4, 0.8), seconds(ats[i]))
    for([ "D3", "A3", "D2" ]) name: mix_into(out, horn(note_hz(name), 1.6, 0.6, 0.7), seconds(1.8))
    for([ 0.0, 0.3, 0.6, 0.9, 1.8 ]) at, k: mix_into(out, frame_drum(if k < 4: 0.6 else: 0.3), seconds(at))
    mix_into(out, low_drum(1.0), seconds(0.9))
    mix_into(out, low_drum(1.0), seconds(1.8))
    return rev(out, 0.9, 0.32)

// Defeat: the horns go down and a drum shuts the door.
def lost() -> [float]:
    let out = []::float
    mix_into(out, horn(note_hz("D4"), 0.6, 0.8, 0.6), 0)
    mix_into(out, horn(note_hz("C4"), 0.6, 0.8, 0.6), seconds(0.55))
    mix_into(out, horn(note_hz("A3"), 1.8, 0.8, 0.6), seconds(1.1))
    mix_into(out, drone(note_hz("D2"), 2.8, 1.0), 0)
    mix_into(out, low_drum(1.0, 1.2), seconds(1.1))
    return rev(out, 1.0, 0.35)

// Call to arms: the town centre's big bronze bell, struck hard four times.
def town_bell() -> [float]:
    let out = []::float
    for(4) k:
        let at = k * 0.42
        mix_into(out, bell(note_hz("D3"), 2.2, 1.0 - 0.08 * k, false), seconds(at))
        mix_into(out, bell(note_hz("D4"), 1.2, 0.35, false), seconds(at))
    return rev(out, 1.0, 0.3)

// Back to work: the same bell, two slow soft strokes, a fourth up.
def town_bell_clear() -> [float]:
    let out = []::float
    mix_into(out, bell(note_hz("D3"), 2.4, 0.7, false), 0)
    mix_into(out, bell(note_hz("G3"), 2.4, 0.6, false), seconds(0.7))
    return rev(out, 1.0, 0.3)

// Under attack: a war horn, twice, and the big drum.
def alarm() -> [float]:
    let out = []::float
    mix_into(out, war_horn(note_hz("A2"), 0.35), 0)
    mix_into(out, war_horn(note_hz("A2"), 0.9), seconds(0.42))
    mix_into(out, low_drum(1.0), 0)
    mix_into(out, low_drum(0.8), seconds(0.42))
    return rev(out, 0.9, 0.25)

// A hero takes the field (or is revived): a short bright horn call over a drum, a bell at the top.
def hero_up() -> [float]:
    let out = []::float
    mix_into(out, horn(note_hz("A3"), 0.22, 0.9, 1.0), 0)
    mix_into(out, horn(note_hz("D4"), 0.22, 0.9, 1.0), seconds(0.2))
    mix_into(out, horn(note_hz("F4"), 0.22, 0.9, 1.0), seconds(0.4))
    mix_into(out, horn(note_hz("A4"), 0.9, 0.9, 1.0), seconds(0.6))
    mix_into(out, horn(note_hz("D3"), 1.1, 0.5, 0.7), seconds(0.6))
    mix_into(out, frame_drum(0.7), 0)
    mix_into(out, frame_drum(0.5), seconds(0.4))
    mix_into(out, low_drum(0.8), seconds(0.6))
    mix_into(out, bell(note_hz("A5"), 1.0, 0.35, false), seconds(0.62))
    return rev(out, 0.8, 0.28)

// A hero falls: one long low horn that sags at the end, a muffled drum under it.
def hero_fell() -> [float]:
    let out = []::float
    mix_into(out, horn(note_hz("A3"), 0.5, 0.8, 0.6), 0)
    mix_into(out, horn(note_hz("F3"), 0.5, 0.75, 0.55), seconds(0.45))
    mix_into(out, horn(note_hz("D3"), 1.4, 0.7, 0.5), seconds(0.9))
    mix_into(out, low_drum(0.9, 1.0), seconds(0.9))
    return rev(out, 0.9, 0.32)

// ------------------------------------------------------------------ ambience

// Forty seconds of a soft breeze over grass with a bird now and then; loops. Dominic: the first version (20 s, a 3 kHz
// grass hiss, a swell every ~5 s) sounded like static, came round too often and too loud. Now: a deep, slow breeze (one
// long swell in each 20 s half, never silent), the grass a faint rustle well below hiss, sparse birds.
def meadow() -> [float]:
    let n = seconds(40.0)
    // Two gentle swells per loop (0.05 Hz) and a slower drift (0.025 Hz); whole cycles, so it loops.
    let gust = curve(n) t: 0.45 + 0.55 * (0.5 + 0.5 * rsin(TAU * 0.05 * t + 1.0)) * (0.75 + 0.25 * rsin(TAU * 0.025 * t))
    let moving = lowpassc(noise(n), curve(n) t: 140.0 + 120.0 * (0.5 + 0.5 * rsin(TAU * 0.05 * t + 1.0)))
    let wind = gain(mul(lowpass(moving, 400.0), gust), 1.4)
    let grass = gain(mul(lowpass(bandpass(noise(n), 1400.0, 0.5), 2200.0), gust), 0.025)
    let out = add([ wind, grass ])
    for(4):
        let at = j(1.0, 38.0)
        let f0 = j(2200.0, 3400.0)
        for(randint(2, 3)) c:
            let m = seconds(0.09)
            let chirp = mul(sinec(curve(m) t: f0 + 700.0 * rsin(PI * t / 0.09)), env(m, 0.01, 0.04, 0.5, 0.03))
            mix_into(out, chirp, seconds(at + c * 0.14), 0.08, true)
    return out

// One far-off voice saying something: a buzzy pulse with a wandering pitch through two vowel formants that slide from
// syllable to syllable, low-passed by the distance. Words can't be made out; it's people somewhere over there.
def murmur(dur:float) -> [float]:
    let n = seconds(dur)
    let f0 = j(110.0, 230.0)
    let contour = map(6): j(-0.12, 0.12)
    let src = pulsec(curve(n) t: f0 * (1.0 + contour[min(5, int(t / dur * 6.0))] + 0.04 * rsin(TAU * 3.0 * t)), 0.35)
    let vowels = [ int2 { 730, 1090 }, int2 { 270, 2290 }, int2 { 530, 1840 }, int2 { 570, 840 }, int2 { 300, 870 } ]
    let syl = max(0.12, dur / randint(3, 7))
    let seq = map(int(dur / syl) + 2): vowels[randbelow(5)]
    let f1 = bandpassc(src, curve(n) t: float(seq[int(t / syl)].x), 4.0, 1.0)
    let f2 = bandpassc(src, curve(n) t: float(seq[int(t / syl)].y), 6.0, 0.5)
    let beat = curve(n) t: 0.35 + 0.65 * abs(rsin(PI * t / syl))  // syllables
    return lowpass(mul(mul(add([ f1, f2 ]), beat), env(n, 0.05, 0.1, 1.0, 0.15)), 900.0)

// Push a sound away: duller and quieter (the room tail comes from the mix's reverb).
def far(buf:[float], g:float) -> [float]: return gain(lowpass(buf, 1800.0), g)

// Twenty-four seconds of a town at work, heard from a little way off; loops. People talking somewhere (a murmur, never
// words), a mallet on a frame, a log split, a broom, a bucket set down, a door. `busy` has more of everything (the town
// grows into it).
def town(busy:bool) -> [float]:
    let dur = 24.0
    let n = seconds(dur)
    let out = gain(lowpass(noise(n), 300.0), 0.05)  // the air of a place with people in it
    for(if busy: 9 else: 4):
        let talk = murmur(j(0.8, 2.2))
        mix_into(out, talk, seconds(j(0.0, dur)), j(0.1, 0.2), true)
    for(if busy: 12 else: 5):  // someone building: three or four knocks in a run
        let at = j(0.0, dur)
        for(randint(2, 4)) r:
            mix_into(out, far(mallet(), 0.22), seconds(at + r * j(0.42, 0.55)), 1.0, true)
    for(if busy: 4 else: 2):  // a log split
        mix_into(out, far(chop(), 0.18), seconds(j(0.0, dur)), 1.0, true)
    for(if busy: 3 else: 1):  // a broom: swish, swish
        let at = j(0.0, dur)
        for(randint(3, 5)) r:
            let m = seconds(0.32)
            let sw = mul(bandpassc(noise(m), curve(m) t: 2200.0 + 1800.0 * t / 0.32, 0.8), env(m, 0.08, 0.1, 0.6, 0.12))
            mix_into(out, sw, seconds(at + r * 0.45), 0.1, true)
    for(if busy: 2 else: 1):  // a wooden bucket set down
        let m = seconds(0.2)
        let clunk = add([ modal(m, [ p3(j(210.0, 250.0), 30.0, 0.5), p3(j(520.0, 600.0), 45.0, 0.3) ], 0.0), thump(0.08, 160.0, 90.0, 40.0, 0.4) ])
        mix_into(out, far(clunk, 0.3), seconds(j(0.0, dur)), 1.0, true)
    if busy:  // a door on its hinge
        let m = seconds(0.6)
        let hinge = bandpass(pulsec(curve(m) t: 90.0 + 60.0 * rsin(PI * t / 0.6), 0.2), 900.0, 3.0)
        mix_into(out, mul(hinge, env(m, 0.05, 0.2, 0.7, 0.2)), seconds(j(2.0, dur - 2.0)), 0.12, true)
    return reverb(out, 0.7, 0.3)

// ------------------------------------------------------------------ vehicles (#182): loops and the tank's gun

// A loop: its tail faded over its head, so it comes round without a click.
def looped(buf:[float], over:int) -> [float]:
    let n = buf.length - over
    return map(n) i: if i < over: buf[i] * (float(i) / float(over)) + buf[n + i] * (1.0 - float(i) / float(over)) else: buf[i]

// An engine standing: a slow, low thud of cylinders and a rumble under it.
def engine_idle() -> [float]:
    let n = seconds(4.5)
    let beat = lowpass(pulsec(curve(n) t: 29.0 + 1.2 * rsin(TAU * 0.5 * t), 0.3), 240.0)
    return soft_clip(looped(add([ gain(beat, 0.7), gain(lowpass(noise(n), 130.0), 1.6) ]), seconds(0.5)), 1.4)

// An engine working, and the tracks: a harder, higher note, links clattering over the sprocket and a thin squeal.
def engine_move() -> [float]:
    let n = seconds(4.5)
    let beat = lowpass(pulsec(curve(n) t: 58.0 + 2.5 * rsin(TAU * 0.5 * t) + 1.0 * rsin(TAU * 1.5 * t), 0.35), 620.0)
    let out = add([ gain(beat, 0.6), gain(lowpass(noise(n), 420.0), 0.9), gain(bandpass(noise(n), 2300.0, 7.0), 0.1) ])
    for(int(4.5 * 13.0)) k:
        let m = seconds(0.03)
        mix_into(out, mul(bandpass(noise(m), j(900.0, 1500.0), 3.0), env(m, 0.002, 0.024)), seconds(max(0.0, float(k) / 13.0 + j(-0.008, 0.008))), 0.5, true)
    return soft_clip(looped(out, seconds(0.5)), 1.3)

// A turret traversing: a small electric whine.
def turret_servo() -> [float]:
    let n = seconds(2.3)
    let whine = add([ sine(n, 420.0), gain(sine(n, 840.0), 0.35), gain(sine(n, 1265.0), 0.12) ])
    return looped(gain(add([ whine, gain(bandpass(noise(n), 700.0, 3.0), 0.4) ]), 0.6), seconds(0.3))

// A cart or an engine on wooden wheels, a quiet bed under the mix (#169): the soft knock of each rim joint coming round,
// two wheels a little out of step, now and then a stone under a wheel and a dry creak at the hub, over a low rumble with
// the hiss filtered right off (the old one was mostly filtered noise and read as wind). Two turns of the wheels a loop, so
// it repeats like a wheel does.
def wood_knock(g:float) -> [float]:
    let f = j(150.0, 190.0)
    let body = modal(seconds(0.12), [ p3(f, 38.0, 1.0), p3(f * 2.3, 55.0, 0.45), p3(f * 5.1, 110.0, 0.12) ], 0.0)
    return gain(lowpass(body, 1400.0), g)

def hub_creak() -> [float]:
    let n = seconds(j(0.28, 0.4))
    let f0 = j(32.0, 40.0)
    let rub = pulsec(curve(n) t: f0 + 40.0 * t, 0.12)
    let wood = formants(rub, [ p3(j(380.0, 440.0), 7.0, 1.0), p3(j(880.0, 980.0), 9.0, 0.5), p3(1500.0, 10.0, 0.2) ])
    return mul(wood, swell(n, 0.12, 0.2))

def cart_roll() -> [float]:
    let n = seconds(4.0)
    var bed = noise(seconds(4.5))
    for(3): bed = lowpass(bed, 95.0)
    let out = gain(highpass(looped(bed, seconds(0.5)), 30.0), 6.0)
    let joints = 6
    let turn = 2.0
    for(2) w:
        let start = if w == 0: 0.0 else: j(0.12, 0.2)
        let lean = map(joints): j(-0.025, 0.025)
        let loud = map(joints): j(0.55, 1.0)
        for(2) r:
            for(joints) k:
                let at = start + float(r) * turn + float(k) * turn / float(joints) + lean[k]
                mix_into(out, wood_knock(loud[k] * (if w == 0: 1.0 else: 0.8)), seconds(at + 4.0), 1.0, true)
    for(3):
        let at = j(0.0, 4.0)
        mix_into(out, wood_knock(1.6), seconds(at), 1.0, true)
        mix_into(out, burst(0.05, j(1600.0, 2400.0), 1.5, 70.0, 0.15), seconds(at), 1.0, true)
    mix_into(out, hub_creak(), seconds(j(0.5, 3.0)), 0.6, true)
    return out.slice(0, n)

// A tank's gun: a hard crack, a heavy boom, the echo rolling off.
def shell_boom() -> [float]:
    let crack = burst(0.05, 1500.0, 0.5, 90.0, 1.5)
    let boom = thump(0.55, 110.0, 34.0, 8.0, 1.5)
    let roll = lowpass(burst(1.1, 300.0, 0.4, 3.2, 0.6), 700.0)
    return soft_clip(add([ crack, boom, delay_start(roll, 0.04) ]), 2.2)

// A shell coming down: the bang and the metal or dirt thrown up.
def shell_hit() -> [float]:
    let bang = burst(0.08, 900.0, 0.4, 40.0, 1.4)
    let boom = thump(0.4, 90.0, 40.0, 11.0, 1.2)
    let bits = burst(0.5, 2600.0, 1.2, 7.0, 0.3)
    return soft_clip(add([ bang, boom, delay_start(bits, 0.03) ]), 2.0)

// name -> takes, peak dB. Stings and ambience are one take.
let sfx_names = [ "hit_blade", "hit_blunt", "hit_pierce", "arrow_land", "shoot_arrow", "shoot_bolt", "shoot_javelin",
                  "shoot_stone", "shoot_dart", "shoot_ball", "ram_hit", "catapult_release", "catapult_impact",
                  "bolt_release", "sling_release", "blast", "trade_paid", "fall", "building_fall", "chop", "mine",
                  "build", "forage", "farm_done", "ui_click", "ui_tip", "ui_hover", "ui_start", "ui_nope", "dice_roll",
                  "trained", "built", "research", "heal", "age", "won", "lost", "alarm", "town_bell", "town_bell_clear",
                  "hero_up", "hero_fell", "meadow", "town_quiet", "town_busy", "engine_idle", "engine_move", "turret_servo", "cart_roll", "shell_boom", "shell_hit" ]
let sfx_takes = [ 4, 4, 4, 3, 3, 2, 2, 2, 2, 2, 3, 2, 3, 2, 2, 2, 2, 3, 2, 4, 4, 4, 4, 2, 3, 1, 2, 1, 1, 3, 1, 1, 1, 2,
                  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3 ]
let sfx_peaks = [ -4.0, -2.0, -2.0, -4.0, -3.0, -2.0, -3.0, -3.0, -6.0, -1.0, -1.5, -2.0, -1.5, -2.0, -2.0, -1.0, -10.0,
                  -3.0, -1.0, -3.0, -3.0, -3.0, -6.0, -5.0, -6.0, -8.0, -14.0, -2.0, -5.0, -6.0, -4.0, -3.0, -5.0, -12.0,
                  -1.0, -1.0, -1.0, -1.0, -1.5, -4.0, -2.0, -2.0, -14.0, -12.0, -10.0, -10.0, -8.0, -14.0, -18.0, -1.0, -2.0 ]

def sfx_take(name:string) -> [float]:
    return switch name:
        case "hit_blade": hit_blade()
        case "hit_blunt": hit_blunt()
        case "hit_pierce": hit_pierce()
        case "arrow_land": arrow_land()
        case "shoot_arrow": shoot_arrow()
        case "shoot_bolt": shoot_bolt()
        case "shoot_javelin": shoot_javelin()
        case "shoot_stone": shoot_stone()
        case "shoot_dart": shoot_dart()
        case "shoot_ball": shoot_ball()
        case "ram_hit": ram_hit()
        case "catapult_release": catapult_release()
        case "catapult_impact": catapult_impact()
        case "bolt_release": bolt_release()
        case "sling_release": sling_release()
        case "blast": blast()
        case "trade_paid": trade_paid()
        case "fall": body_fall()
        case "building_fall": building_fall()
        case "chop": chop()
        case "mine": mine()
        case "build": mallet()
        case "forage": forage()
        case "farm_done": farm_done()
        case "ui_click": ui_click()
        case "ui_tip": ui_tip()
        case "ui_hover": ui_hover()
        case "ui_start": ui_start()
        case "ui_nope": ui_nope()
        case "dice_roll": dice_roll()
        case "trained": trained()
        case "built": built()
        case "research": research()
        case "heal": heal()
        case "age": new_age()
        case "won": won()
        case "lost": lost()
        case "alarm": alarm()
        case "town_bell": town_bell()
        case "town_bell_clear": town_bell_clear()
        case "hero_up": hero_up()
        case "hero_fell": hero_fell()
        case "meadow": meadow()
        case "engine_idle": engine_idle()
        case "engine_move": engine_move()
        case "turret_servo": turret_servo()
        case "cart_roll": cart_roll()
        case "shell_boom": shell_boom()
        case "shell_hit": shell_hit()
        case "town_quiet": town(false)
        default: town(true)
